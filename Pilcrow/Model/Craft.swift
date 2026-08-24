//  Craft.swift
//  Timeline, continuity facts, and anchored comments.

import Foundation
import SwiftUI

// MARK: - Timeline
//
// Two tracks: the order the reader experiences events, and the order they
// happened. For a book with flashbacks that gap is the whole craft problem.

struct TimelineEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    /// Where it appears in the manuscript. Nil for events that happen
    /// off-page but still need a slot in the chronology.
    var nodeID: UUID? = nil
    var entityIDs: [UUID] = []
    /// The in-world date as you'd write it. Free text on purpose — "the
    /// summer before" is a real answer.
    var storyDate: String = ""
    /// Sort key for chronological order. Lower is earlier.
    var storyOrder: Double = 0
    var note: String = ""
    var colorIndex: Int = 0

    var color: Color { LL.chartColor(colorIndex) }
}

// MARK: - Continuity
//
// A village has forty-one houses in chapter two and thirty-nine in chapter nine.
// The app flags it; it never silently corrects it. A contradiction is
// sometimes the point.

struct Fact: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var entityID: UUID
    /// "eyes", "age", "the year they met"
    var key: String
    var value: String
    var nodeID: UUID? = nil
    /// Set when you've looked at a flag and decided it's fine.
    var accepted: Bool = false
}

struct ContinuityIssue: Identifiable {
    enum Kind {
        case contradiction      // two recorded values for one attribute
        case unrecordedValue    // prose says something the ledger doesn't know
        case nameDrift          // two entities whose names are near-identical
        case termBeforeDefined  // a coined term used before its definition
    }
    let id = UUID()
    let kind: Kind
    let entityName: String
    let detail: String
    let where_: [String]
    let severity: Int          // 0 worst

    var label: String {
        switch kind {
        case .contradiction:     return "Contradiction"
        case .unrecordedValue:   return "Unrecorded"
        case .nameDrift:         return "Name drift"
        case .termBeforeDefined: return "Used before defined"
        }
    }
    var tint: Color {
        switch kind {
        case .contradiction:     return LL.crit
        case .unrecordedValue:   return LL.warn
        case .nameDrift:         return LL.warn
        case .termBeforeDefined: return LL.chartColor(5)
        }
    }
}

enum ContinuityCheck {

    static func run(facts: [Fact],
                    cast: [Entity],
                    notes: [NoteCard],
                    documents: [Node],
                    body: (UUID) -> String) -> [ContinuityIssue] {
        var issues: [ContinuityIssue] = []
        let nameOf = { (id: UUID) in cast.first { $0.id == id }?.name ?? "Unknown" }

        // 1. Two recorded values for the same attribute.
        let byEntityKey = Dictionary(grouping: facts.filter { !$0.accepted }) {
            "\($0.entityID)|\($0.key.lowercased())"
        }
        for (_, group) in byEntityKey {
            let values = Set(group.map { $0.value.trimmingCharacters(in: .whitespaces).lowercased() })
            guard values.count > 1, let first = group.first else { continue }
            let places = group.compactMap { f -> String? in
                guard let n = f.nodeID, let doc = documents.first(where: { $0.id == n }) else {
                    return "\u{201C}\(f.value)\u{201D}"
                }
                return "\u{201C}\(f.value)\u{201D} in \(doc.title)"
            }
            issues.append(ContinuityIssue(
                kind: .contradiction,
                entityName: nameOf(first.entityID),
                detail: "\(first.key) has \(values.count) recorded values",
                where_: places, severity: 0))
        }

        // 2. A recorded attribute value appearing in a scene the ledger
        //    doesn't have a fact for — usually fine, occasionally the drift.
        for f in facts where !f.accepted && !f.value.isEmpty {
            let owner = nameOf(f.entityID)
            let firstName = owner.split(separator: " ").first.map(String.init) ?? owner
            var seenIn: [String] = []
            for doc in documents {
                guard doc.id != f.nodeID else { continue }
                let text = body(doc.id)
                guard text.localizedCaseInsensitiveContains(firstName) else { continue }
                // Look for a *different* recorded value of the same key nearby.
                let siblings = facts.filter {
                    $0.entityID == f.entityID
                    && $0.key.lowercased() == f.key.lowercased()
                    && $0.value.lowercased() != f.value.lowercased()
                }
                for s in siblings where text.localizedCaseInsensitiveContains(s.value) {
                    seenIn.append("\u{201C}\(s.value)\u{201D} in \(doc.title)")
                }
            }
            if !seenIn.isEmpty {
                issues.append(ContinuityIssue(
                    kind: .unrecordedValue,
                    entityName: owner,
                    detail: "prose mentions another \(f.key) for \(owner)",
                    where_: Array(Set(seenIn)).sorted(), severity: 1))
            }
        }

        // 3. Two cast names one edit apart — usually a typo that will
        //    survive all the way to a proof.
        let names = cast.map { $0.name }
        for i in names.indices {
            for j in names.indices where j > i {
                let a = names[i], b = names[j]
                guard a.count > 3, b.count > 3, a.lowercased() != b.lowercased() else { continue }
                if editDistance(a.lowercased(), b.lowercased()) == 1 {
                    issues.append(ContinuityIssue(
                        kind: .nameDrift, entityName: a,
                        detail: "\u{201C}\(a)\u{201D} and \u{201C}\(b)\u{201D} differ by one character",
                        where_: [], severity: 1))
                }
            }
        }

        // 4. A coined term used before the note that defines it.
        let order = Dictionary(uniqueKeysWithValues: documents.enumerated().map { ($0.element.id, $0.offset) })
        for note in notes where note.title.count > 3 && !note.linkedNodeIDs.isEmpty {
            let definedAt = note.linkedNodeIDs.compactMap { order[$0] }.min()
            guard let definedAt else { continue }
            let earlier = documents.enumerated().filter { idx, doc in
                idx < definedAt && body(doc.id).localizedCaseInsensitiveContains(note.title)
            }.map { $0.element.title }
            if !earlier.isEmpty {
                issues.append(ContinuityIssue(
                    kind: .termBeforeDefined, entityName: note.title,
                    detail: "used before the note that defines it",
                    where_: earlier, severity: 2))
            }
        }

        return issues.sorted { $0.severity < $1.severity }
    }

    /// Levenshtein, bounded — we only ever care whether it's exactly 1.
    static func editDistance(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if abs(x.count - y.count) > 1 { return 2 }
        var prev = Array(0...y.count)
        var cur = [Int](repeating: 0, count: y.count + 1)
        for i in 1...max(1, x.count) {
            guard i <= x.count else { break }
            cur[0] = i
            for j in 1...max(1, y.count) {
                guard j <= y.count else { break }
                cur[j] = x[i-1] == y[j-1] ? prev[j-1]
                       : 1 + min(prev[j], cur[j-1], prev[j-1])
            }
            prev = cur
        }
        return prev[y.count]
    }
}

// MARK: - Anchored comments
//
// Attached to a range of text, not floating beside it. They survive edits,
// never print, and can be resolved.

struct Annotation: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var nodeID: UUID
    /// The text it was anchored to. This is what re-finds the anchor after
    /// an edit shifts every offset in the document.
    var quoted: String
    var location: Int
    var body: String = ""
    var resolved: Bool = false
    var created: Date = Date()
    var author: String = ""

    /// Re-locates the anchor in `text`. Offsets go stale on every keystroke;
    /// the quoted string doesn't.
    ///
    /// `location` arrives from a JSON file on disk, so it is treated as
    /// untrusted: it may be negative, past the end, or NSNotFound. Every
    /// comparison below is written to be overflow-safe rather than assuming
    /// it is sane — `location + q.length` traps on Int.max, which is exactly
    /// what a stale NSNotFound looks like.
    func range(in text: NSString) -> NSRange? {
        guard !quoted.isEmpty else { return nil }
        let q = quoted as NSString
        guard q.length > 0, q.length <= text.length else { return nil }
        let maxStart = text.length - q.length

        // Fast path: still exactly where we left it.
        if location >= 0, location <= maxStart,
           text.substring(with: NSRange(location: location, length: q.length)) == quoted {
            return NSRange(location: location, length: q.length)
        }

        // Otherwise take the occurrence nearest where it used to be. Clamp
        // first so the distance subtraction can't overflow either.
        let anchor = min(max(0, location), maxStart)
        var best: NSRange?
        var bestDistance = Int.max
        var searchFrom = 0
        while searchFrom < text.length {
            let found = text.range(of: quoted,
                                   options: [],
                                   range: NSRange(location: searchFrom,
                                                  length: text.length - searchFrom))
            guard found.location != NSNotFound else { break }
            let d = abs(found.location - anchor)
            if d < bestDistance { bestDistance = d; best = found }
            searchFrom = found.location + max(1, found.length)
        }
        return best
    }
}
