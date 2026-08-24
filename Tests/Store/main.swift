import Foundation
import AppKit

var fails = 0
func check(_ ok: Bool, _ what: String, _ detail: String = "") {
    print(ok ? "  ok    \(what)" : "  FAIL  \(what)  \(detail)")
    if !ok { fails += 1 }
}

@MainActor func run() {
    let root = URL(fileURLWithPath: "/tmp/pilcrow-test-\(UUID().uuidString.prefix(8))")
    let folder = root.appendingPathComponent("The Cartographer's Error")
    defer { try? FileManager.default.removeItem(at: root) }

    // 1. Create
    guard let store = try? ProjectStore.create(at: folder, title: "The Cartographer's Error",
                                               author: "M. Lomuscio", kind: .fiction) else {
        check(false, "create project"); return
    }
    check(true, "create project")

    let fm = FileManager.default
    check(fm.fileExists(atPath: folder.appendingPathComponent("Pilcrow Project.json").path),
          "manifest written")
    check(fm.fileExists(atPath: folder.appendingPathComponent("Manuscript").path),
          "Manuscript/ created")

    // 2. Write prose
    let firstID = store.manifest.root.documents.first!.id
    let prose = "The house was quiet in the way that only a house full of sleeping people can be.\n\nShe had been awake since *four*, and the manuscript had not moved a word since **Tuesday**.\n"
    store.setBody(firstID, prose)
    try? store.saveNow()
    check(store.node(firstID)?.wordCount == 33, "word count",
          "got \(store.node(firstID)?.wordCount ?? -1)")

    // 3. The file on disk is real Markdown a human can read
    let sceneURL = store.url(for: firstID)!
    let raw = (try? String(contentsOf: sceneURL, encoding: .utf8)) ?? ""
    check(raw.contains("The house was quiet"), "prose is on disk as plain text")
    check(raw.contains("pilcrow-id:"), "front matter carries identity")
    check(raw.contains("**Tuesday**"), "emphasis survives as markdown")
    check(sceneURL.pathExtension == "md", "file is .md", sceneURL.lastPathComponent)

    // 4. Add structure
    let ch2 = store.addFolder(title: "Chapter Two", parent: nil)
    let sc2 = store.addDocument(title: "The Store", parent: ch2)
    store.setBody(sc2, "The ledger went back further than the surveys did.\n")
    var t = SpineThread(name: "Ardmore & the maps")
    t.promise = "Whose house is it really"
    store.manifest.threads.append(t)
    store.setBeat(node: sc2, thread: t.id, text: "She finds the second set of keys.", verb: "Reveal")
    try? store.saveNow()

    // 5. An orphan file dropped into a chapter folder in Finder
    let orphan = folder.appendingPathComponent("Manuscript/Chapter Two/Dropped In.md")
    try? "A scene written somewhere else entirely.\n".write(to: orphan, atomically: true, encoding: .utf8)

    // 6. Reopen from disk — a cold load, nothing cached
    guard let reopened = try? ProjectStore.open(at: folder) else {
        check(false, "reopen"); return
    }
    check(true, "reopen from disk")
    check(reopened.manifest.title == "The Cartographer's Error", "title survived")
    check(reopened.manifest.kind == .fiction, "kind survived")
    check(reopened.body(firstID).contains("since **Tuesday**"), "prose survived round trip")
    check(reopened.body(firstID) == prose, "prose is byte-identical",
          reopened.body(firstID).debugDescription.prefix(60).description)
    check(reopened.manifest.threads.first?.promise == "Whose house is it really", "thread survived")
    check(reopened.manifest.beats.first?.verb == "Reveal", "beat survived")
    check(reopened.orderedDocuments.contains { $0.title == "Dropped In" },
          "orphan .md adopted into the book")
    check(reopened.totalWords == 33 + 9 + 6, "total word count",
          "got \(reopened.totalWords)")

    // 7. Lenient decoding: a manifest missing almost everything must still open
    let bare = """
    { "title": "Bare Bones", "kind": "nonfiction" }
    """
    let bareFolder = root.appendingPathComponent("Bare")
    try? fm.createDirectory(at: bareFolder.appendingPathComponent("Manuscript"),
                            withIntermediateDirectories: true)
    try? bare.write(to: bareFolder.appendingPathComponent("Pilcrow Project.json"),
                    atomically: true, encoding: .utf8)
    let bareStore = try? ProjectStore.open(at: bareFolder)
    check(bareStore != nil, "minimal manifest opens (forward/backward compatible)")
    check(bareStore?.manifest.title == "Bare Bones", "minimal manifest keeps its title")
    check(bareStore?.manifest.pageStyle.faceID == "literata", "missing pageStyle falls back")
    check(bareStore?.labels.spine == "Argument", "nonfiction label pack applied")

    // 8. Snapshots
    reopened.snapshot(firstID, label: "test")
    check(reopened.snapshots(firstID).count == 1, "snapshot written")

    // 9. Compile
    var opts = CompileOptions(); opts.format = .markdown
    let md = (try? Compiler.compile(store: reopened, options: opts)).flatMap {
        String(data: $0, encoding: .utf8) } ?? ""
    check(md.contains("The house was quiet"), "compile to markdown includes prose")
    opts.format = .manuscriptRTF
    let rtf = try? Compiler.compile(store: reopened, options: opts)
    check((rtf?.count ?? 0) > 400, "compile to RTF produces a document",
          "\(rtf?.count ?? 0) bytes")

    // 10. Delete moves to Trash, never destroys
    reopened.delete(sc2)
    check(reopened.node(sc2) == nil, "deleted node leaves the tree")
    check(!fm.fileExists(atPath: folder.appendingPathComponent("Manuscript/Chapter Two/The Store.md").path),
          "deleted file left the folder")
}

MainActor.assumeIsolated { run() }
print(fails == 0 ? "\nALL PASSED" : "\n\(fails) FAILED")
exit(fails == 0 ? 0 : 1)
