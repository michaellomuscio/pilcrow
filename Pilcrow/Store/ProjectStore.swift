//  ProjectStore.swift
//  A project is a folder you choose. This reads and writes it.
//
//  Layout on disk:
//    <Folder>/
//      Pilcrow Project.json          manifest — order and metadata
//      Manuscript/
//        Chapter One/              a container node is a directory
//          _chapter.md             the container's own prose, if any
//          Opening.md              a leaf node is a Markdown file
//      .pilcrow/sessions.json
//      .pilcrow/snapshots/<node>/<timestamp>.md
//
//  The manifest is the authority on order. The files are the authority on
//  prose. Each file carries its id in front matter, so either can rebuild
//  the other — and dropping a .md into a chapter folder in Finder adds it
//  to the book.

import Foundation
import AppKit
import Observation

// MARK: - Front matter

enum FrontMatter {
    static let fence = "---"

    static func split(_ raw: String) -> (fields: [String: String], body: String) {
        let lines = raw.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == fence else {
            return ([:], raw)
        }
        var fields: [String: String] = [:]
        var i = 1
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces) == fence {
                let body = lines[(i + 1)...].joined(separator: "\n")
                return (fields, stripLeadingBlank(body))
            }
            if let colon = line.firstIndex(of: ":") {
                let k = String(line[line.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                let v = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if !k.isEmpty { fields[k] = decode(v) }
            }
            i += 1
        }
        return ([:], raw)   // unterminated fence: treat the whole thing as prose
    }

    static func compose(_ fields: [(String, String)], body: String) -> String {
        guard !fields.isEmpty else { return body }
        var out = fence + "\n"
        for (k, v) in fields where !v.isEmpty {
            out += "\(k): \(encode(v))\n"
        }
        out += fence + "\n\n"
        return out + body
    }

    private static func encode(_ v: String) -> String {
        v.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\n", with: "\\n")
    }
    private static func decode(_ v: String) -> String {
        var out = ""
        var esc = false
        for ch in v {
            if esc {
                out.append(ch == "n" ? "\n" : ch)
                esc = false
            } else if ch == "\\" { esc = true }
            else { out.append(ch) }
        }
        return out
    }
    private static func stripLeadingBlank(_ s: String) -> String {
        var t = s
        while t.hasPrefix("\n") { t.removeFirst() }
        return t
    }
}

// MARK: - Store

@Observable
@MainActor
final class ProjectStore {

    // Names on disk
    static let manifestName   = "Pilcrow Project.json"
    static let manuscriptDir  = "Manuscript"
    static let internalDir    = ".pilcrow"
    static let containerBody  = "_chapter.md"

    let folder: URL
    var manifest: ProjectManifest
    var log: SessionLog

    /// Every document body, keyed by node id. A book is a few megabytes;
    /// holding it all makes counting, searching, and compiling trivial.
    private(set) var bodies: [UUID: String] = [:]

    var selection: UUID?
    var lastSaved: Date?
    var saveError: String?
    private var dirtyNodes: Set<UUID> = []
    private var manifestDirty = false
    private var saveTimer: Timer?

    // MARK: Lifecycle

    private init(folder: URL, manifest: ProjectManifest, log: SessionLog) {
        self.folder = folder
        self.manifest = manifest
        self.log = log
    }

    // MARK: Create

    static func create(at folder: URL, title: String, author: String,
                       kind: ProjectKind) throws -> ProjectStore {
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try fm.createDirectory(at: folder.appendingPathComponent(manuscriptDir),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: folder.appendingPathComponent(internalDir),
                               withIntermediateDirectories: true)

        var m = ProjectManifest(title: title, kind: kind)
        m.author = author

        // A starting shape, not a prescription — every part of it is deletable.
        let labels = LabelPack.pack(for: kind)
        var ch1 = Node.folder("\(labels.container) One")
        var first = Node.document(kind == .fiction ? "Opening" : "Introduction")
        first.status = .drafting
        ch1.children = [first]
        m.root.children = [ch1]

        let store = ProjectStore(folder: folder, manifest: m, log: SessionLog())
        store.bodies[first.id] = ""
        store.manifestDirty = true
        store.dirtyNodes.insert(first.id)
        try store.saveNow()
        RecentProjects.remember(folder: folder, title: title, kind: kind)
        return store
    }

    // MARK: Open

    static func open(at folder: URL) throws -> ProjectStore {
        let fm = FileManager.default
        let manifestURL = folder.appendingPathComponent(manifestName)
        guard fm.fileExists(atPath: manifestURL.path) else {
            throw PilcrowError.notAProject(folder.lastPathComponent)
        }
        let data = try Data(contentsOf: manifestURL)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        var manifest = try dec.decode(ProjectManifest.self, from: data)

        var log = SessionLog()
        let logURL = folder.appendingPathComponent(internalDir).appendingPathComponent("sessions.json")
        if let d = try? Data(contentsOf: logURL), let l = try? dec.decode(SessionLog.self, from: d) {
            log = l
        }

        let store = ProjectStore(folder: folder, manifest: manifest, log: log)
        store.loadBodies(&manifest.root, at: folder.appendingPathComponent(manuscriptDir))
        store.adoptOrphans(&manifest.root, at: folder.appendingPathComponent(manuscriptDir))
        store.recount(&manifest.root)
        store.manifest = manifest
        store.selection = manifest.root.documents.first?.id
        RecentProjects.remember(folder: folder, title: manifest.title, kind: manifest.kind)
        return store
    }

    /// Reads prose for every node the manifest knows about.
    private func loadBodies(_ node: inout Node, at dir: URL) {
        for i in node.children.indices {
            let child = node.children[i]
            if child.isFolder {
                let sub = dir.appendingPathComponent(child.slug)
                let bodyURL = sub.appendingPathComponent(Self.containerBody)
                if let raw = try? String(contentsOf: bodyURL, encoding: .utf8) {
                    bodies[child.id] = FrontMatter.split(raw).body
                }
                loadBodies(&node.children[i], at: sub)
            } else {
                let f = dir.appendingPathComponent(child.slug + ".md")
                if let raw = try? String(contentsOf: f, encoding: .utf8) {
                    bodies[child.id] = FrontMatter.split(raw).body
                } else {
                    bodies[child.id] = bodies[child.id] ?? ""
                }
            }
        }
    }

    /// Any .md sitting in the folder that the manifest doesn't know about is
    /// adopted into the book. Dropping a file into a chapter folder in Finder
    /// is a legitimate way to add a scene.
    private func adoptOrphans(_ node: inout Node, at dir: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]) else { return }

        let knownDirs = Set(node.children.filter(\.isFolder).map { $0.slug.lowercased() })
        let knownFiles = Set(node.children.filter { !$0.isFolder }.map { $0.slug.lowercased() })

        for url in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let name = url.deletingPathExtension().lastPathComponent
            if isDir {
                if !knownDirs.contains(name.lowercased()) {
                    var adopted = Node.folder(name)
                    adopted.slug = name
                    node.children.append(adopted)
                    let idx = node.children.count - 1
                    loadBodies(&node.children[idx], at: url)
                    adoptOrphans(&node.children[idx], at: url)
                }
            } else if url.pathExtension.lowercased() == "md",
                      name != Self.containerBody.replacingOccurrences(of: ".md", with: ""),
                      !knownFiles.contains(name.lowercased()) {
                guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let (fields, body) = FrontMatter.split(raw)
                var adopted = Node.document(name)
                adopted.slug = name
                if let ids = fields["pilcrow-id"], let uuid = UUID(uuidString: ids) {
                    adopted.id = uuid
                }
                if let s = fields["status"], let st = NodeStatus(rawValue: s) { adopted.status = st }
                if let s = fields["synopsis"] { adopted.synopsis = s }
                if let t = fields["target"], let n = Int(t) { adopted.target = n }
                bodies[adopted.id] = body
                node.children.append(adopted)
            }
        }
        // Recurse into folders the manifest already knew about.
        for i in node.children.indices where node.children[i].isFolder {
            adoptOrphans(&node.children[i], at: dir.appendingPathComponent(node.children[i].slug))
        }
    }

    private func recount(_ node: inout Node) {
        node.wordCount = MarkdownCodec.wordCount(bodies[node.id] ?? "")
        for i in node.children.indices { recount(&node.children[i]) }
    }

    // MARK: Bodies

    func body(_ id: UUID) -> String { bodies[id] ?? "" }

    func setBody(_ id: UUID, _ text: String) {
        guard bodies[id] != text else { return }
        bodies[id] = text
        _ = manifest.root.update(id) { $0.wordCount = MarkdownCodec.wordCount(text) }
        dirtyNodes.insert(id)
        scheduleSave()
    }

    func touchManifest() {
        manifestDirty = true
        scheduleSave()
    }

    // MARK: Saving

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            Task { @MainActor in try? self?.saveNow() }
        }
    }

    func saveNow() throws {
        saveTimer?.invalidate()
        saveTimer = nil
        let fm = FileManager.default
        let msDir = folder.appendingPathComponent(Self.manuscriptDir)
        try fm.createDirectory(at: msDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: folder.appendingPathComponent(Self.internalDir),
                               withIntermediateDirectories: true)

        do {
            try writeTree(manifest.root, at: msDir, onlyDirty: !manifestDirty)
            if manifestDirty || !dirtyNodes.isEmpty {
                manifest.modified = Date()
                let enc = JSONEncoder()
                enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                enc.dateEncodingStrategy = .iso8601
                try atomicWrite(try enc.encode(manifest),
                                to: folder.appendingPathComponent(Self.manifestName))
                try atomicWrite(try enc.encode(log),
                                to: folder.appendingPathComponent(Self.internalDir)
                                    .appendingPathComponent("sessions.json"))
            }
            dirtyNodes.removeAll()
            manifestDirty = false
            lastSaved = Date()
            saveError = nil
        } catch {
            saveError = error.localizedDescription
            throw error
        }
    }

    private func writeTree(_ node: Node, at dir: URL, onlyDirty: Bool) throws {
        let fm = FileManager.default
        for child in node.children {
            if child.isFolder {
                let sub = dir.appendingPathComponent(child.slug)
                try fm.createDirectory(at: sub, withIntermediateDirectories: true)
                let text = bodies[child.id] ?? ""
                let bodyURL = sub.appendingPathComponent(Self.containerBody)
                if !text.isEmpty {
                    if !onlyDirty || dirtyNodes.contains(child.id) {
                        try atomicWrite(Data(fileContents(child, text).utf8), to: bodyURL)
                    }
                } else if fm.fileExists(atPath: bodyURL.path) {
                    try? fm.removeItem(at: bodyURL)
                }
                try writeTree(child, at: sub, onlyDirty: onlyDirty)
            } else {
                guard !onlyDirty || dirtyNodes.contains(child.id) else { continue }
                let f = dir.appendingPathComponent(child.slug + ".md")
                try atomicWrite(Data(fileContents(child, bodies[child.id] ?? "").utf8), to: f)
            }
        }
    }

    private func fileContents(_ node: Node, _ body: String) -> String {
        var fields: [(String, String)] = [("pilcrow-id", node.id.uuidString)]
        if node.status != .outline { fields.append(("status", node.status.rawValue)) }
        if !node.synopsis.isEmpty { fields.append(("synopsis", node.synopsis)) }
        if node.target > 0 { fields.append(("target", String(node.target))) }
        return FrontMatter.compose(fields, body: body)
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    // MARK: Structure editing

    func addDocument(title: String, parent: UUID?, after: UUID? = nil) -> UUID {
        var node = Node.document(title)
        node.slug = uniqueSlug(node.slug, in: parent)
        let idx = after.flatMap { indexOf($0, in: parent).map { $0 + 1 } }
        _ = manifest.root.insert(node, into: parent ?? manifest.root.id, at: idx)
        bodies[node.id] = ""
        dirtyNodes.insert(node.id)
        touchManifest()
        return node.id
    }

    func addFolder(title: String, parent: UUID?) -> UUID {
        var node = Node.folder(title)
        node.slug = uniqueSlug(node.slug, in: parent)
        _ = manifest.root.insert(node, into: parent ?? manifest.root.id, at: nil)
        bodies[node.id] = ""
        touchManifest()
        return node.id
    }

    /// Renaming a document renames its file too, so Finder keeps matching the
    /// binder. If you renamed the file yourself, that wins and we leave it —
    /// your folder, your names.
    func rename(_ id: UUID, to title: String) {
        guard let node = manifest.root.find(id) else { return }
        let oldSlug = node.slug
        let tracksTitle = oldSlug.caseInsensitiveCompare(Slug.make(node.title)) == .orderedSame

        _ = manifest.root.update(id) { $0.title = title }

        if tracksTitle {
            let parent = manifest.root.parentID(of: id)
            let siblings = (parent.flatMap { manifest.root.find($0) } ?? manifest.root)
                .children.filter { $0.id != id }
            let wanted = Slug.unique(Slug.make(title),
                                     taken: Set(siblings.map { $0.slug.lowercased() }))
            if wanted.caseInsensitiveCompare(oldSlug) != .orderedSame,
               let from = url(for: id) {
                _ = manifest.root.update(id) { $0.slug = wanted }
                if let to = url(for: id) {
                    do {
                        if FileManager.default.fileExists(atPath: from.path) {
                            try FileManager.default.moveItem(at: from, to: to)
                        }
                    } catch {
                        // Couldn't move it — keep the old name rather than
                        // pointing the manifest at a file that isn't there.
                        _ = manifest.root.update(id) { $0.slug = oldSlug }
                    }
                }
            }
        }
        dirtyNodes.insert(id)
        touchManifest()
    }

    /// Deleting removes the node from the book and moves its file to the
    /// Trash — never an unrecoverable delete.
    func delete(_ id: UUID) {
        guard let node = manifest.root.find(id) else { return }
        if let url = url(for: id) {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        for n in node.flattened { bodies.removeValue(forKey: n.id) }
        manifest.beats.removeAll { $0.nodeID == id }
        _ = manifest.root.remove(id)
        if selection == id { selection = manifest.root.documents.first?.id }
        touchManifest()
    }

    func move(_ id: UUID, to parent: UUID?, at index: Int?) {
        guard let node = manifest.root.remove(id) else { return }
        _ = manifest.root.insert(node, into: parent ?? manifest.root.id, at: index)
        manifestDirty = true
        dirtyNodes.formUnion(node.flattened.map(\.id))
        touchManifest()
    }

    private func indexOf(_ id: UUID, in parent: UUID?) -> Int? {
        let p = parent.flatMap { manifest.root.find($0) } ?? manifest.root
        return p.children.firstIndex { $0.id == id }
    }

    private func uniqueSlug(_ slug: String, in parent: UUID?) -> String {
        let p = parent.flatMap { manifest.root.find($0) } ?? manifest.root
        return Slug.unique(slug, taken: Set(p.children.map { $0.slug.lowercased() }))
    }

    /// Absolute URL of a node's file or directory.
    func url(for id: UUID) -> URL? {
        var path: [String] = []
        func walk(_ node: Node) -> Bool {
            for child in node.children {
                if child.id == id {
                    path.append(child.isFolder ? child.slug : child.slug + ".md")
                    return true
                }
                if walk(child) { path.insert(child.slug, at: 0); return true }
            }
            return false
        }
        guard walk(manifest.root) else { return nil }
        return path.reduce(folder.appendingPathComponent(Self.manuscriptDir)) {
            $0.appendingPathComponent($1)
        }
    }

    // MARK: Snapshots

    func snapshot(_ id: UUID, label: String = "") {
        guard let node = manifest.root.find(id) else { return }
        let dir = folder.appendingPathComponent(Self.internalDir)
            .appendingPathComponent("snapshots").appendingPathComponent(id.uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let name = label.isEmpty ? stamp : "\(stamp) \(Slug.make(label))"
        let text = FrontMatter.compose([("title", node.title), ("taken", Date().description)],
                                       body: bodies[id] ?? "")
        try? Data(text.utf8).write(to: dir.appendingPathComponent(name + ".md"), options: .atomic)
    }

    func snapshots(_ id: UUID) -> [(name: String, url: URL, date: Date)] {
        let dir = folder.appendingPathComponent(Self.internalDir)
            .appendingPathComponent("snapshots").appendingPathComponent(id.uuidString)
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        return items.filter { $0.pathExtension == "md" }.map {
            let d = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date.distantPast
            return ($0.deletingPathExtension().lastPathComponent, $0, d)
        }.sorted { $0.date > $1.date }
    }

    func restore(from url: URL, into id: UUID) {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return }
        snapshot(id, label: "before restore")
        setBody(id, FrontMatter.split(raw).body)
    }

    // MARK: Derived

    var totalWords: Int { manifest.root.totalWords }
    var labels: LabelPack { manifest.labels }

    func node(_ id: UUID?) -> Node? { id.flatMap { manifest.root.find($0) } }

    var orderedDocuments: [Node] { manifest.root.documents }

    func beat(node: UUID, thread: UUID) -> Beat? {
        manifest.beats.first { $0.nodeID == node && $0.threadID == thread }
    }

    func setBeat(node: UUID, thread: UUID, text: String, verb: String) {
        if let i = manifest.beats.firstIndex(where: { $0.nodeID == node && $0.threadID == thread }) {
            if text.isEmpty && verb.isEmpty {
                manifest.beats.remove(at: i)
            } else {
                manifest.beats[i].text = text
                manifest.beats[i].verb = verb
            }
        } else if !text.isEmpty || !verb.isEmpty {
            manifest.beats.append(Beat(nodeID: node, threadID: thread, text: text, verb: verb))
        }
        touchManifest()
    }
}

// MARK: - Errors

enum PilcrowError: LocalizedError {
    case notAProject(String)
    var errorDescription: String? {
        switch self {
        case .notAProject(let name):
            return "\u{201C}\(name)\u{201D} isn\u{2019}t a Pilcrow project — it has no \u{201C}Pilcrow Project.json\u{201D} in it."
        }
    }
}

// MARK: - Recent projects

enum RecentProjects {
    struct Entry: Codable, Identifiable, Hashable {
        var path: String
        var title: String
        var kind: ProjectKind
        var opened: Date
        var id: String { path }
        var url: URL { URL(fileURLWithPath: path) }
        var exists: Bool { FileManager.default.fileExists(atPath: path) }
    }

    private static let key = "pilcrow.recentProjects"

    static func all() -> [Entry] {
        guard let d = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([Entry].self, from: d) else { return [] }
        return list.sorted { $0.opened > $1.opened }
    }

    static func remember(folder: URL, title: String, kind: ProjectKind) {
        var list = all().filter { $0.path != folder.path }
        list.insert(Entry(path: folder.path, title: title, kind: kind, opened: Date()), at: 0)
        list = Array(list.prefix(12))
        if let d = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    static func forget(_ path: String) {
        let list = all().filter { $0.path != path }
        if let d = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }
}
