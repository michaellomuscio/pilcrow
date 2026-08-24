//  Project.swift
//  A project is a folder you choose. Everything below describes what
//  lives in it. The manifest is the authority on order and metadata;
//  the .md files are the authority on prose. Either can rebuild the other.

import Foundation
import SwiftUI

// MARK: - Kind

enum ProjectKind: String, Codable, CaseIterable, Identifiable {
    case fiction, nonfiction, hybrid
    var id: String { rawValue }

    var label: String {
        switch self {
        case .fiction:    return "Fiction"
        case .nonfiction: return "Nonfiction"
        case .hybrid:     return "Hybrid"
        }
    }

    var blurb: String {
        switch self {
        case .fiction:
            return "Plot lines, characters, worldbuilding. Beat sheets and a continuity ledger."
        case .nonfiction:
            return "Argument threads, sources, evidence. Structure patterns and a claim ledger."
        case .hybrid:
            return "Both sets, on at once. For memoir and narrative nonfiction."
        }
    }

    var symbol: String {
        switch self {
        case .fiction:    return "books.vertical"
        case .nonfiction: return "text.book.closed"
        case .hybrid:     return "square.stack.3d.up"
        }
    }
}

// MARK: - Label pack
//
// The whole fiction/nonfiction fork is a vocabulary swap over one data
// model. Plot lines and argument threads are the same object: a promise
// made to the reader and eventually paid off.

struct LabelPack {
    let spine: String
    let spineOne: String
    let spineBoard: String
    let promise: String
    let payoff: String
    let cast: String
    let castOne: String
    let notes: String
    let notesOne: String
    let ledger: String
    let leaf: String          // what a leaf document is called
    let container: String     // what a container is called
    let beatVerbs: [String]

    static func pack(for kind: ProjectKind) -> LabelPack {
        switch kind {
        case .fiction, .hybrid:
            return LabelPack(
                spine: "Plot", spineOne: "Plot line", spineBoard: "Plot Grid",
                promise: "Promise", payoff: "Payoff",
                cast: "Characters", castOne: "Character",
                notes: "Story Notes", notesOne: "Note",
                ledger: "Continuity",
                leaf: "Scene", container: "Chapter",
                beatVerbs: ["Setup", "Turn", "Escalate", "Reveal", "Reversal", "Payoff", "Aftermath"])
        case .nonfiction:
            return LabelPack(
                spine: "Argument", spineOne: "Argument thread", spineBoard: "Argument Board",
                promise: "Claim", payoff: "Resolution",
                cast: "Sources", castOne: "Source",
                notes: "Concepts", notesOne: "Concept",
                ledger: "Evidence",
                leaf: "Section", container: "Chapter",
                beatVerbs: ["Introduce", "Support", "Complicate", "Qualify", "Rebut", "Apply", "Conclude"])
        }
    }
}

// MARK: - Status

enum NodeStatus: String, Codable, CaseIterable, Identifiable {
    case outline, drafting, revised, done, cut
    var id: String { rawValue }

    var label: String {
        switch self {
        case .outline:  return "Outline"
        case .drafting: return "Drafting"
        case .revised:  return "Revised"
        case .done:     return "Done"
        case .cut:      return "Cut"
        }
    }

    var tint: Color {
        switch self {
        case .outline:  return LL.ink3
        case .drafting: return LL.chartColor(5)   // sky
        case .revised:  return LL.chartColor(3)   // gold
        case .done:     return LL.ok
        case .cut:      return LL.crit
        }
    }
}

// MARK: - Node

enum NodeKind: String, Codable { case folder, document }

/// One entry in the manuscript tree. A folder holds children and may also
/// hold its own prose (stored as `_chapter.md` inside its directory).
struct Node: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var kind: NodeKind
    var children: [Node] = []

    var synopsis: String = ""
    var status: NodeStatus = .outline
    var target: Int = 0
    var povID: UUID? = nil
    var threadIDs: [UUID] = []
    var includeInCompile: Bool = true

    /// Path component on disk, relative to the parent. Stable once created;
    /// reordering does not rename files.
    var slug: String = ""
    /// Cached — recomputed on load and on every save.
    var wordCount: Int = 0

    var isFolder: Bool { kind == .folder }

    static func document(_ title: String) -> Node {
        Node(title: title, kind: .document, slug: Slug.make(title))
    }
    static func folder(_ title: String) -> Node {
        Node(title: title, kind: .folder, slug: Slug.make(title))
    }

    // Recursive helpers

    var flattened: [Node] {
        [self] + children.flatMap(\.flattened)
    }
    /// Documents only, in manuscript order.
    var documents: [Node] {
        (kind == .document ? [self] : []) + children.flatMap(\.documents)
    }
    var totalWords: Int {
        wordCount + children.reduce(0) { $0 + $1.totalWords }
    }
    var totalTarget: Int {
        target + children.reduce(0) { $0 + $1.totalTarget }
    }

    func find(_ id: UUID) -> Node? {
        if self.id == id { return self }
        for c in children { if let f = c.find(id) { return f } }
        return nil
    }

    mutating func update(_ id: UUID, _ body: (inout Node) -> Void) -> Bool {
        if self.id == id { body(&self); return true }
        for i in children.indices {
            if children[i].update(id, body) { return true }
        }
        return false
    }

    @discardableResult
    mutating func remove(_ id: UUID) -> Node? {
        if let i = children.firstIndex(where: { $0.id == id }) {
            return children.remove(at: i)
        }
        for i in children.indices {
            if let r = children[i].remove(id) { return r }
        }
        return nil
    }

    mutating func insert(_ node: Node, into parentID: UUID?, at index: Int?) -> Bool {
        if parentID == nil || parentID == id {
            let i = min(index ?? children.count, children.count)
            children.insert(node, at: max(0, i))
            return true
        }
        for i in children.indices {
            if children[i].insert(node, into: parentID, at: index) { return true }
        }
        return false
    }

    /// The id of the node that contains `childID`, or nil if it's a root child.
    func parentID(of childID: UUID) -> UUID? {
        if children.contains(where: { $0.id == childID }) { return id }
        for c in children { if let p = c.parentID(of: childID) { return p } }
        return nil
    }
}

// MARK: - Manifest

struct ProjectManifest: Codable {
    var formatVersion: Int = 1
    var id: UUID = UUID()
    var title: String
    var author: String = ""
    var subtitle: String = ""
    var kind: ProjectKind
    var created: Date = Date()
    var modified: Date = Date()

    var root: Node = Node(title: "Manuscript", kind: .folder, slug: "Manuscript")
    var threads: [SpineThread] = []
    var beats: [Beat] = []
    var cast: [Entity] = []
    var notes: [NoteCard] = []
    var claims: [Claim] = []
    var structure: StoryStructure = StoryStructure()
    var timeline: [TimelineEvent] = []
    var facts: [Fact] = []
    var annotations: [Annotation] = []
    var citationStyle: CitationStyle = .chicagoNotes
    var appointments: [Appointment] = []

    var pageStyle: PageStyle = PageStyle()
    var wordTarget: Int = 0
    var deadline: Date? = nil

    var labels: LabelPack { LabelPack.pack(for: kind) }
}

// MARK: - Slugs

enum Slug {
    private static let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|\u{0}")

    static func make(_ title: String) -> String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = t.components(separatedBy: illegal).joined(separator: "-")
        let collapsed = cleaned.replacingOccurrences(
            of: " {2,}", with: " ", options: .regularExpression)
        let final = String(collapsed.prefix(80))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A leading dot would hide the file; an empty name is unusable.
        if final.isEmpty { return "Untitled" }
        return final.hasPrefix(".") ? "_" + final : final
    }

    /// Ensures `slug` does not collide with anything in `taken`.
    static func unique(_ slug: String, taken: Set<String>) -> String {
        guard taken.contains(slug.lowercased()) else { return slug }
        var n = 2
        while taken.contains("\(slug) \(n)".lowercased()) { n += 1 }
        return "\(slug) \(n)"
    }
}

// MARK: - Formatting

extension Int {
    /// 1,076 — the way a manuscript counts.
    var grouped: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
