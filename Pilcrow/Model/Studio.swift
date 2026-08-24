//  Studio.swift
//  Threads, beats, cast, notes, claims, sessions.
//
//  SpineThread + Beat *is* both the plot grid and the argument board —
//  one component, two label packs. Entity is both the character sheet
//  and the source library.

import Foundation
import SwiftUI

// MARK: - Spine (plot lines | argument threads)

struct SpineThread: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorIndex: Int = 0
    /// "Promise" in fiction, "Claim" in nonfiction. Same field.
    var promise: String = ""
    /// "Payoff" in fiction, "Resolution" in nonfiction.
    var payoff: String = ""
    var order: Int = 0
    var archived: Bool = false

    var color: Color { LL.chartColor(colorIndex) }
}

struct Beat: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var nodeID: UUID
    var threadID: UUID
    var text: String = ""
    /// One of the label pack's beat verbs — Setup/Turn/Reveal, or
    /// Introduce/Support/Rebut on the nonfiction side.
    var verb: String = ""
}

// MARK: - Cast (characters | sources & subjects)

enum EntityKind: String, Codable, CaseIterable, Identifiable {
    case character, source, person, place, group
    var id: String { rawValue }

    var label: String {
        switch self {
        case .character: return "Character"
        case .source:    return "Source"
        case .person:    return "Person"
        case .place:     return "Place"
        case .group:     return "Group"
        }
    }
    var symbol: String {
        switch self {
        case .character: return "person.fill"
        case .source:    return "doc.text.fill"
        case .person:    return "person.crop.square.fill"
        case .place:     return "mappin.circle.fill"
        case .group:     return "person.3.fill"
        }
    }
}

struct EntityField: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var key: String
    var value: String = ""
    /// Long fields get a multi-line editor.
    var long: Bool = false
}

enum PermissionStatus: String, Codable, CaseIterable, Identifiable {
    case notApplicable, onRecord, onBackground, needsRelease, signed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .notApplicable: return "—"
        case .onRecord:      return "On record"
        case .onBackground:  return "On background"
        case .needsRelease:  return "Needs release"
        case .signed:        return "Signed"
        }
    }
    var isBlocking: Bool { self == .needsRelease }
}

struct Entity: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: EntityKind = .character
    var name: String
    var aliases: [String] = []
    var role: String = ""
    var summary: String = ""
    var fields: [EntityField] = []
    var colorIndex: Int = 0

    // Nonfiction source specifics
    var citation: String = ""
    var url: String = ""
    var permission: PermissionStatus = .notApplicable
    var quotes: [SourceQuote] = []
    /// The key you type in prose: [@sword2016].
    var citekey: String = ""
    /// Structured bibliographic data, when imported from CSL-JSON.
    var csl: CSLItem = CSLItem()

    var color: Color { LL.chartColor(colorIndex) }

    /// Field templates. A character gets arc fields; a source gets
    /// bibliographic ones. Both are editable and neither is repilcrowd.
    static func template(for kind: EntityKind) -> [EntityField] {
        switch kind {
        case .character:
            return [
                EntityField(key: "Age"), EntityField(key: "Occupation"),
                EntityField(key: "Appearance", long: true),
                EntityField(key: "Voice", long: true),
                EntityField(key: "Want", long: true),
                EntityField(key: "Need", long: true),
                EntityField(key: "Lie they believe", long: true),
                EntityField(key: "Wound", long: true),
                EntityField(key: "Arc", long: true)
            ]
        case .source:
            return [
                EntityField(key: "Author"), EntityField(key: "Year"),
                EntityField(key: "Publication"), EntityField(key: "Pages"),
                EntityField(key: "Credibility", long: true),
                EntityField(key: "What it supports", long: true)
            ]
        case .person:
            return [
                EntityField(key: "Role"), EntityField(key: "Affiliation"),
                EntityField(key: "Contact"),
                EntityField(key: "Interview notes", long: true)
            ]
        case .place:
            return [EntityField(key: "Region"), EntityField(key: "Description", long: true)]
        case .group:
            return [EntityField(key: "Kind"), EntityField(key: "Description", long: true)]
        }
    }
}

struct SourceQuote: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var locator: String = ""     // page / timestamp
    var note: String = ""
}

// MARK: - Evidence ledger (nonfiction)

enum Strength: String, Codable, CaseIterable, Identifiable {
    case unsupported, thin, solid, refuted
    var id: String { rawValue }
    var label: String {
        switch self {
        case .unsupported: return "Unsupported"
        case .thin:        return "Thin"
        case .solid:       return "Solid"
        case .refuted:     return "Refuted"
        }
    }
    var tint: Color {
        switch self {
        case .unsupported: return LL.crit
        case .thin:        return LL.warn
        case .solid:       return LL.ok
        case .refuted:     return LL.crit
        }
    }
    /// Sort order for the Weak Links view — worst first.
    var severity: Int {
        switch self {
        case .refuted: return 0
        case .unsupported: return 1
        case .thin: return 2
        case .solid: return 3
        }
    }
}

enum FactStatus: String, Codable, CaseIterable, Identifiable {
    case unverified, verified, contested, cut
    var id: String { rawValue }
    var label: String {
        switch self {
        case .unverified: return "Unverified"
        case .verified:   return "Verified"
        case .contested:  return "Contested"
        case .cut:        return "Cut it"
        }
    }
    var tint: Color {
        switch self {
        case .unverified: return LL.ink3
        case .verified:   return LL.ok
        case .contested:  return LL.warn
        case .cut:        return LL.crit
        }
    }
}

struct Claim: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var nodeID: UUID? = nil
    var threadID: UUID? = nil
    var sourceIDs: [UUID] = []
    var strength: Strength = .unsupported
    var status: FactStatus = .unverified
    var note: String = ""

    /// A claim is load-bearing if it sits on a thread and has no solid support.
    var isWeak: Bool { strength != .solid }
}

// MARK: - Notes

struct NoteCard: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var body: String = ""
    var tags: [String] = []
    var x: Double = 0
    var y: Double = 0
    var colorIndex: Int = 0
    var linkedNodeIDs: [UUID] = []
    var linkedNoteIDs: [UUID] = []

    var color: Color { LL.chartColor(colorIndex) }
}

// MARK: - Sessions

enum GoalKind: String, Codable, CaseIterable, Identifiable {
    case unit, time, words
    var id: String { rawValue }
    var label: String {
        switch self {
        case .unit:  return "A unit of work"
        case .time:  return "Time"
        case .words: return "Words"
        }
    }
    var help: String {
        switch self {
        case .unit:  return "\"Finish the Ardmore scene.\" The only goal that survives a revision session."
        case .time:  return "Sit for a fixed stretch. What you produce is not the measure."
        case .words: return "A word count. Good for drafting, misleading for revising."
        }
    }
}

/// One writing session. `wordsCut` and `nextLine` are first-class columns
/// because the Progress Log and the resumption prompt depend on them —
/// a schema that only stores wordsAdded can never build either.
struct WritingSession: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var started: Date = Date()
    var ended: Date? = nil
    var wordsAdded: Int = 0
    var wordsCut: Int = 0
    var nodeIDs: [UUID] = []

    var goalKind: GoalKind = .unit
    var goalValue: Int = 25          // minutes, or words
    var goalNote: String = ""
    var goalMet: Bool = false

    var mood: Int? = nil             // 1...5, optional, two taps
    var energy: Int? = nil
    var place: String = ""

    /// Captured at close, shown at open. Backed by the resumption half of
    /// the Zeigarnik literature — the half that replicated.
    var nextLine: String = ""
    /// What you actually did. Progress, not word count.
    var progressNote: String = ""

    var duration: TimeInterval { (ended ?? Date()).timeIntervalSince(started) }
    var minutes: Int { Int(duration / 60) }
    /// Both directions count. In revision, cutting is the work.
    var netWords: Int { wordsAdded - wordsCut }
    var touched: Int { wordsAdded + wordsCut }
}

struct SessionLog: Codable {
    var sessions: [WritingSession] = []

    var today: [WritingSession] {
        let cal = Calendar.current
        return sessions.filter { cal.isDateInToday($0.started) }
    }
    var wordsToday: Int { today.reduce(0) { $0 + $1.netWords } }
    var minutesToday: Int { today.reduce(0) { $0 + $1.minutes } }
    var lastNextLine: String {
        sessions.last(where: { !$0.nextLine.isEmpty })?.nextLine ?? ""
    }
}
