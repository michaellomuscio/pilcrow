//  Structure.swift
//  Beat sheets and structure patterns, and the overlay that shows where a
//  beat *should* land against where it actually does.
//
//  Every template here is a starting point that can be edited, partially
//  applied, or deleted. Planners and pantsers both finish books; forcing
//  either into the other's method is how you stop finishing them.

import Foundation
import SwiftUI

// MARK: - Templates

struct TemplateBeat {
    let name: String
    /// Where the beat conventionally lands, as a fraction of total length.
    let at: Double
    let note: String
}

struct StructureTemplate: Identifiable {
    let id: String
    let name: String
    let attribution: String
    let kinds: Set<ProjectKind>
    let blurb: String
    let beats: [TemplateBeat]

    static func all(for kind: ProjectKind) -> [StructureTemplate] {
        catalogue.filter { $0.kinds.contains(kind) }
    }
    static func find(_ id: String) -> StructureTemplate? {
        catalogue.first { $0.id == id }
    }

    static let catalogue: [StructureTemplate] = [

        // ── Fiction ────────────────────────────────────────────────────

        StructureTemplate(
            id: "blank", name: "Blank", attribution: "",
            kinds: [.fiction, .nonfiction, .hybrid],
            blurb: "No beats. Add your own, or work without any.",
            beats: []),

        StructureTemplate(
            id: "three-act", name: "Three-Act", attribution: "classical",
            kinds: [.fiction, .hybrid],
            blurb: "The default shape of Western drama. Least prescriptive of the lot.",
            beats: [
                TemplateBeat(name: "Setup", at: 0.00, note: "The world before."),
                TemplateBeat(name: "Inciting Incident", at: 0.12, note: "The thing that makes the story necessary."),
                TemplateBeat(name: "First Plot Point", at: 0.25, note: "No going back."),
                TemplateBeat(name: "Midpoint", at: 0.50, note: "The reversal that changes what the story is about."),
                TemplateBeat(name: "Second Plot Point", at: 0.75, note: "The last piece arrives."),
                TemplateBeat(name: "Climax", at: 0.90, note: "The question gets answered."),
                TemplateBeat(name: "Denouement", at: 0.97, note: "The world after.")
            ]),

        StructureTemplate(
            id: "save-the-cat", name: "Save the Cat!", attribution: "Blake Snyder",
            kinds: [.fiction, .hybrid],
            blurb: "Fifteen beats with tight page targets. Popular, and rigid by design.",
            beats: [
                TemplateBeat(name: "Opening Image", at: 0.00, note: "A snapshot of the before."),
                TemplateBeat(name: "Theme Stated", at: 0.05, note: "Someone says what the book is about, usually to a hero who isn't listening."),
                TemplateBeat(name: "Set-Up", at: 0.07, note: "The world, the flaw, the thing that must change."),
                TemplateBeat(name: "Catalyst", at: 0.10, note: "The knock at the door."),
                TemplateBeat(name: "Debate", at: 0.13, note: "Should they? The last chance to refuse."),
                TemplateBeat(name: "Break Into Two", at: 0.20, note: "They choose. The new world begins."),
                TemplateBeat(name: "B Story", at: 0.22, note: "The relationship that carries the theme."),
                TemplateBeat(name: "Fun and Games", at: 0.30, note: "The promise of the premise."),
                TemplateBeat(name: "Midpoint", at: 0.50, note: "False victory or false defeat. Stakes go up."),
                TemplateBeat(name: "Bad Guys Close In", at: 0.60, note: "Pressure from outside and inside."),
                TemplateBeat(name: "All Is Lost", at: 0.75, note: "The whiff of death."),
                TemplateBeat(name: "Dark Night of the Soul", at: 0.78, note: "The bottom."),
                TemplateBeat(name: "Break Into Three", at: 0.80, note: "The synthesis. They see it now."),
                TemplateBeat(name: "Finale", at: 0.85, note: "Storm the castle."),
                TemplateBeat(name: "Final Image", at: 0.99, note: "The after, answering the opening.")
            ]),

        StructureTemplate(
            id: "heros-journey", name: "Hero's Journey", attribution: "Campbell / Vogler",
            kinds: [.fiction, .hybrid],
            blurb: "Twelve stages. Loose enough to fit most quests, vague enough to fit anything.",
            beats: [
                TemplateBeat(name: "Ordinary World", at: 0.00, note: "Before the call."),
                TemplateBeat(name: "Call to Adventure", at: 0.10, note: "The disruption."),
                TemplateBeat(name: "Refusal of the Call", at: 0.15, note: "Fear, duty, or plain reluctance."),
                TemplateBeat(name: "Meeting the Mentor", at: 0.20, note: "Guidance, or a map."),
                TemplateBeat(name: "Crossing the Threshold", at: 0.25, note: "Into the special world."),
                TemplateBeat(name: "Tests, Allies, Enemies", at: 0.32, note: "Learning the new rules."),
                TemplateBeat(name: "Approach to the Inmost Cave", at: 0.45, note: "Preparation, and dread."),
                TemplateBeat(name: "The Ordeal", at: 0.52, note: "A death of some kind."),
                TemplateBeat(name: "Reward", at: 0.62, note: "Seizing the sword."),
                TemplateBeat(name: "The Road Back", at: 0.75, note: "Chased home."),
                TemplateBeat(name: "Resurrection", at: 0.87, note: "The final test, on the theme."),
                TemplateBeat(name: "Return with the Elixir", at: 0.95, note: "Changed, and carrying something back.")
            ]),

        StructureTemplate(
            id: "story-circle", name: "Story Circle", attribution: "Dan Harmon",
            kinds: [.fiction, .hybrid],
            blurb: "Eight steps around a circle. The tightest useful summary of the Journey.",
            beats: [
                TemplateBeat(name: "You", at: 0.00, note: "A character in a zone of comfort."),
                TemplateBeat(name: "Need", at: 0.12, note: "But they want something."),
                TemplateBeat(name: "Go", at: 0.25, note: "They enter an unfamiliar situation."),
                TemplateBeat(name: "Search", at: 0.37, note: "Adapt to it."),
                TemplateBeat(name: "Find", at: 0.50, note: "Get what they wanted."),
                TemplateBeat(name: "Take", at: 0.62, note: "Pay its price."),
                TemplateBeat(name: "Return", at: 0.75, note: "And go back to where they started."),
                TemplateBeat(name: "Change", at: 0.87, note: "Having changed.")
            ]),

        StructureTemplate(
            id: "seven-point", name: "Seven-Point", attribution: "Dan Wells",
            kinds: [.fiction, .hybrid],
            blurb: "Written backwards from the resolution. Good for plotting under pressure.",
            beats: [
                TemplateBeat(name: "Hook", at: 0.00, note: "The opposite of the resolution."),
                TemplateBeat(name: "Plot Turn 1", at: 0.25, note: "The call. The world changes."),
                TemplateBeat(name: "Pinch 1", at: 0.37, note: "Pressure. Force them to act."),
                TemplateBeat(name: "Midpoint", at: 0.50, note: "From reaction to action."),
                TemplateBeat(name: "Pinch 2", at: 0.62, note: "Harder pressure. Something is lost."),
                TemplateBeat(name: "Plot Turn 2", at: 0.75, note: "They get the last piece they needed."),
                TemplateBeat(name: "Resolution", at: 0.95, note: "The hook, inverted.")
            ]),

        StructureTemplate(
            id: "kishotenketsu", name: "Kish\u{014D}tenketsu", attribution: "classical East Asian",
            kinds: [.fiction, .hybrid],
            blurb: "Four acts, no conflict required. The structure Western sheets can't describe.",
            beats: [
                TemplateBeat(name: "Ki \u{2014} Introduction", at: 0.00, note: "Establish."),
                TemplateBeat(name: "Sh\u{014D} \u{2014} Development", at: 0.25, note: "Deepen, without conflict."),
                TemplateBeat(name: "Ten \u{2014} Twist", at: 0.60, note: "An unrelated element recontextualises everything."),
                TemplateBeat(name: "Ketsu \u{2014} Conclusion", at: 0.85, note: "Reconcile the two.")
            ]),

        StructureTemplate(
            id: "romancing-beat", name: "Romancing the Beat", attribution: "Gwen Hayes",
            kinds: [.fiction, .hybrid],
            blurb: "The romance arc, which runs on its own clock regardless of the plot.",
            beats: [
                TemplateBeat(name: "No Mate in Sight", at: 0.00, note: "The wound that makes love impossible."),
                TemplateBeat(name: "Meet Cute", at: 0.08, note: "First contact."),
                TemplateBeat(name: "Adhesion", at: 0.18, note: "A reason they cannot simply walk away."),
                TemplateBeat(name: "Inkling of Desire", at: 0.25, note: "Against their better judgement."),
                TemplateBeat(name: "Deepening Desire", at: 0.35, note: "Maybe this could work."),
                TemplateBeat(name: "Midpoint of Love", at: 0.50, note: "The high. It feels solved."),
                TemplateBeat(name: "Inkling of Doubt", at: 0.60, note: "The wound stirs."),
                TemplateBeat(name: "Retreating", at: 0.70, note: "Old defences, back up."),
                TemplateBeat(name: "Dark Moment", at: 0.80, note: "The break."),
                TemplateBeat(name: "Grand Gesture", at: 0.90, note: "Proof of change, at cost."),
                TemplateBeat(name: "Happily Ever After", at: 0.97, note: "Earned.")
            ]),

        // ── Nonfiction ─────────────────────────────────────────────────

        StructureTemplate(
            id: "problem-solution", name: "Problem \u{2192} Solution", attribution: "",
            kinds: [.nonfiction, .hybrid],
            blurb: "The default nonfiction shape. Works when the reader already feels the problem.",
            beats: [
                TemplateBeat(name: "The Problem", at: 0.00, note: "Named precisely, in the reader's own terms."),
                TemplateBeat(name: "What It Costs", at: 0.14, note: "Make the stakes concrete and countable."),
                TemplateBeat(name: "Why the Usual Fixes Fail", at: 0.28, note: "Earn the right to propose something else."),
                TemplateBeat(name: "The Idea", at: 0.44, note: "State it in one sentence before defending it."),
                TemplateBeat(name: "The Evidence", at: 0.56, note: "The load-bearing part."),
                TemplateBeat(name: "Objections", at: 0.70, note: "The strongest ones, stated fairly."),
                TemplateBeat(name: "How to Apply It", at: 0.85, note: "What the reader does Monday."),
                TemplateBeat(name: "What Changes", at: 0.95, note: "The world if this is right.")
            ]),

        StructureTemplate(
            id: "what-why-how", name: "What / Why / How / What-If", attribution: "prescriptive",
            kinds: [.nonfiction, .hybrid],
            blurb: "For how-to and practitioner books. Maps to how adults actually learn.",
            beats: [
                TemplateBeat(name: "What", at: 0.00, note: "Define the thing plainly."),
                TemplateBeat(name: "Why It Matters", at: 0.15, note: "The reader's reason to keep reading."),
                TemplateBeat(name: "How It Works", at: 0.35, note: "The mechanism, not the recipe."),
                TemplateBeat(name: "How To Do It", at: 0.58, note: "The recipe."),
                TemplateBeat(name: "What If", at: 0.80, note: "Edge cases, failure modes, when not to."),
                TemplateBeat(name: "What Now", at: 0.94, note: "The first step.")
            ]),

        StructureTemplate(
            id: "big-idea", name: "Big-Idea Book", attribution: "trade nonfiction",
            kinds: [.nonfiction, .hybrid],
            blurb: "Claim, evidence, mechanism, objection, application. The business-book spine.",
            beats: [
                TemplateBeat(name: "Hook", at: 0.00, note: "A story that contains the whole argument in miniature."),
                TemplateBeat(name: "The Claim", at: 0.10, note: "One sentence. Falsifiable."),
                TemplateBeat(name: "The Evidence", at: 0.25, note: "Strongest first."),
                TemplateBeat(name: "The Mechanism", at: 0.45, note: "*Why* it's true, not just that it is."),
                TemplateBeat(name: "Objections", at: 0.65, note: "Steelman them or lose the sceptics."),
                TemplateBeat(name: "Cases", at: 0.78, note: "It working in the wild."),
                TemplateBeat(name: "Application", at: 0.90, note: "What to do with it."),
                TemplateBeat(name: "Implication", at: 0.97, note: "What it means if taken seriously.")
            ]),

        StructureTemplate(
            id: "narrative-nf", name: "Narrative Nonfiction", attribution: "",
            kinds: [.nonfiction, .hybrid],
            blurb: "Story shape carrying an argument. Scene-driven, thesis-anchored.",
            beats: [
                TemplateBeat(name: "Opening Scene", at: 0.00, note: "In motion. No throat-clearing."),
                TemplateBeat(name: "The Question", at: 0.10, note: "What the book is actually asking."),
                TemplateBeat(name: "Background", at: 0.20, note: "Only what the reader needs to feel the stakes."),
                TemplateBeat(name: "Complication", at: 0.35, note: "It's harder than it looked."),
                TemplateBeat(name: "The Turn", at: 0.50, note: "New information changes the question."),
                TemplateBeat(name: "Consequences", at: 0.65, note: "Who paid."),
                TemplateBeat(name: "Reckoning", at: 0.80, note: "The judgement the book has been building toward."),
                TemplateBeat(name: "Where It Stands", at: 0.93, note: "Now, honestly.")
            ]),

        StructureTemplate(
            id: "memoir", name: "Memoir Arc", attribution: "",
            kinds: [.nonfiction, .hybrid],
            blurb: "The self as evidence. The reckoning is the book, not the rupture.",
            beats: [
                TemplateBeat(name: "Before", at: 0.00, note: "The self that didn't know yet."),
                TemplateBeat(name: "The Rupture", at: 0.12, note: "The break in the world."),
                TemplateBeat(name: "Aftermath", at: 0.25, note: "Living inside it."),
                TemplateBeat(name: "Searching", at: 0.40, note: "Wrong answers, honestly rendered."),
                TemplateBeat(name: "False Summit", at: 0.55, note: "The resolution that doesn't hold."),
                TemplateBeat(name: "The Real Reckoning", at: 0.72, note: "The thing that was actually true."),
                TemplateBeat(name: "Integration", at: 0.86, note: "Not healed. Carried."),
                TemplateBeat(name: "Now", at: 0.95, note: "Written from here.")
            ]),

        StructureTemplate(
            id: "thesis-antithesis", name: "Thesis \u{2192} Antithesis \u{2192} Synthesis", attribution: "",
            kinds: [.nonfiction, .hybrid],
            blurb: "For arguments where the counter-case is genuinely strong.",
            beats: [
                TemplateBeat(name: "Thesis", at: 0.00, note: "The position."),
                TemplateBeat(name: "Elaboration", at: 0.15, note: "What follows if it's right."),
                TemplateBeat(name: "Antithesis", at: 0.35, note: "The opposing case, in its own best words."),
                TemplateBeat(name: "The Strongest Counter", at: 0.50, note: "The one that actually worries you."),
                TemplateBeat(name: "Tension", at: 0.65, note: "Sit in it. Don't resolve early."),
                TemplateBeat(name: "Synthesis", at: 0.80, note: "What survives from both."),
                TemplateBeat(name: "Consequences", at: 0.93, note: "What to do now.")
            ]),

        StructureTemplate(
            id: "imrad", name: "IMRaD", attribution: "academic",
            kinds: [.nonfiction, .hybrid],
            blurb: "Introduction, Methods, Results, Discussion. Journal convention.",
            beats: [
                TemplateBeat(name: "Introduction", at: 0.00, note: "Gap in the literature; the question."),
                TemplateBeat(name: "Methods", at: 0.20, note: "Replicable."),
                TemplateBeat(name: "Results", at: 0.45, note: "Findings, without interpretation."),
                TemplateBeat(name: "Discussion", at: 0.70, note: "Meaning, limits, threats to validity."),
                TemplateBeat(name: "Conclusion", at: 0.92, note: "What's now known that wasn't.")
            ]),

        StructureTemplate(
            id: "braided", name: "Braided Essay", attribution: "",
            kinds: [.nonfiction, .hybrid],
            blurb: "Three strands that only reveal their relation late.",
            beats: [
                TemplateBeat(name: "Strand A", at: 0.00, note: "The personal one, usually."),
                TemplateBeat(name: "Strand B", at: 0.18, note: "The researched one."),
                TemplateBeat(name: "Strand C", at: 0.32, note: "The oblique one."),
                TemplateBeat(name: "A Returns", at: 0.48, note: "Changed by what B and C did."),
                TemplateBeat(name: "B Returns", at: 0.60, note: "Deeper."),
                TemplateBeat(name: "Convergence", at: 0.76, note: "The reader sees the braid."),
                TemplateBeat(name: "Synthesis", at: 0.92, note: "One strand, at the end.")
            ])
    ]
}

// MARK: - Applied structure

struct StructureBeat: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// Where convention puts it, 0...1 of total words.
    var targetAt: Double
    var note: String = ""
    /// Where it actually landed. Nil until you place it.
    var nodeID: UUID? = nil
    var done: Bool = false
}

struct StoryStructure: Codable, Hashable {
    var templateID: String = "blank"
    var beats: [StructureBeat] = []

    var isEmpty: Bool { beats.isEmpty }

    static func from(_ t: StructureTemplate) -> StoryStructure {
        StoryStructure(templateID: t.id,
                       beats: t.beats.map {
                           StructureBeat(name: $0.name, targetAt: $0.at, note: $0.note)
                       })
    }
}

// MARK: - The overlay
//
// Your midpoint sitting at 61% is a fact you want in week three, not in
// draft four.

struct BeatPlacement: Identifiable {
    let beat: StructureBeat
    let node: Node?
    /// Actual position as a fraction of total words, nil if unplaced.
    let actualAt: Double?
    var id: UUID { beat.id }

    var drift: Double? {
        guard let actualAt else { return nil }
        return actualAt - beat.targetAt
    }
    /// More than eight points of the book away from convention.
    var isAdrift: Bool { abs(drift ?? 0) > 0.08 }

    var driftLabel: String {
        guard let d = drift else { return "not placed" }
        let pts = Int((d * 100).rounded())
        if pts == 0 { return "on the mark" }
        return pts > 0 ? "\(pts) pts late" : "\(-pts) pts early"
    }
}

enum StructureAnalysis {
    /// Walks the manuscript once, accumulating words, so each placed beat
    /// gets a real position rather than a chapter index.
    static func placements(structure: StoryStructure,
                           documents: [Node],
                           bodyWords: (UUID) -> Int) -> [BeatPlacement] {
        var cumulativeBefore: [UUID: Int] = [:]
        var running = 0
        for doc in documents {
            cumulativeBefore[doc.id] = running
            running += bodyWords(doc.id)
        }
        let total = max(1, running)

        return structure.beats.map { beat in
            guard let nid = beat.nodeID, let node = documents.first(where: { $0.id == nid }) else {
                return BeatPlacement(beat: beat, node: nil, actualAt: nil)
            }
            // Measure to the middle of the scene the beat sits in.
            let before = cumulativeBefore[nid] ?? 0
            let mid = Double(before) + Double(bodyWords(nid)) / 2
            return BeatPlacement(beat: beat, node: node, actualAt: mid / Double(total))
        }
    }
}
