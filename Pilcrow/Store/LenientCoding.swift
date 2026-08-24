//  LenientCoding.swift
//  Forward and backward compatible decoding for everything stored on disk.
//
//  Swift's synthesized `init(from:)` throws when a key is missing, default
//  value or not. That would mean: add one field to Pilcrow, and every project
//  written by the previous version fails to open. For an app whose whole
//  promise is that your book lives in a folder you own, that is the worst
//  failure mode available.
//
//  So every persisted type decodes field by field with a fallback. A file
//  from an older version opens; a file from a newer version opens and
//  quietly ignores what it doesn't understand.

import Foundation

extension KeyedDecodingContainer {
    /// Decodes `key`, falling back to `def` if it's absent, null, or the
    /// wrong shape. Never throws.
    func lenient<T: Decodable>(_ key: Key, _ def: T) -> T {
        guard let v = try? decodeIfPresent(T.self, forKey: key) else { return def }
        return v ?? def
    }
    func lenientOpt<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}

// MARK: - Manuscript

extension Node {
    enum CK: String, CodingKey {
        case id, title, kind, children, synopsis, status, target
        case povID, threadIDs, includeInCompile, slug, wordCount
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        let title = c.lenient(.title, "Untitled")
        self.init(id: c.lenient(.id, UUID()),
                  title: title,
                  kind: c.lenient(.kind, NodeKind.document),
                  children: c.lenient(.children, [Node]()),
                  synopsis: c.lenient(.synopsis, ""),
                  status: c.lenient(.status, NodeStatus.outline),
                  target: c.lenient(.target, 0),
                  povID: c.lenientOpt(.povID),
                  threadIDs: c.lenient(.threadIDs, [UUID]()),
                  includeInCompile: c.lenient(.includeInCompile, true),
                  slug: {
                      let s: String = c.lenient(.slug, "")
                      return s.isEmpty ? Slug.make(title) : s
                  }(),
                  wordCount: c.lenient(.wordCount, 0))
    }
}

extension ProjectManifest {
    enum CK: String, CodingKey {
        case formatVersion, id, title, author, subtitle, kind, created, modified
        case root, threads, beats, cast, notes, claims, pageStyle, wordTarget, deadline
        case structure, timeline, facts, annotations, citationStyle, appointments
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(formatVersion: c.lenient(.formatVersion, 1),
                  id: c.lenient(.id, UUID()),
                  title: c.lenient(.title, "Untitled"),
                  author: c.lenient(.author, ""),
                  subtitle: c.lenient(.subtitle, ""),
                  kind: c.lenient(.kind, ProjectKind.fiction),
                  created: c.lenient(.created, Date()),
                  modified: c.lenient(.modified, Date()),
                  root: c.lenient(.root, Node(title: "Manuscript", kind: .folder,
                                              slug: "Manuscript")),
                  threads: c.lenient(.threads, [SpineThread]()),
                  beats: c.lenient(.beats, [Beat]()),
                  cast: c.lenient(.cast, [Entity]()),
                  notes: c.lenient(.notes, [NoteCard]()),
                  claims: c.lenient(.claims, [Claim]()),
                  structure: c.lenient(.structure, StoryStructure()),
                  timeline: c.lenient(.timeline, [TimelineEvent]()),
                  facts: c.lenient(.facts, [Fact]()),
                  annotations: c.lenient(.annotations, [Annotation]()),
                  citationStyle: c.lenient(.citationStyle, CitationStyle.chicagoNotes),
                  appointments: c.lenient(.appointments, [Appointment]()),
                  pageStyle: c.lenient(.pageStyle, PageStyle()),
                  wordTarget: c.lenient(.wordTarget, 0),
                  deadline: c.lenientOpt(.deadline))
    }
}

// MARK: - Page

extension PageStyle {
    enum CK: String, CodingKey {
        case faceID, draftFaceID, fontSize, lineHeight, draftLineHeight, measure
        case firstLineIndent, paragraphSpacing, theme, typewriter, typewriterAnchor
        case focus, mode, blinkCaret, smartSubstitutions, showPageShadow
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        let d = PageStyle()
        self.init(faceID: c.lenient(.faceID, d.faceID),
                  draftFaceID: c.lenient(.draftFaceID, d.draftFaceID),
                  fontSize: c.lenient(.fontSize, d.fontSize),
                  lineHeight: c.lenient(.lineHeight, d.lineHeight),
                  draftLineHeight: c.lenient(.draftLineHeight, d.draftLineHeight),
                  measure: c.lenient(.measure, d.measure),
                  firstLineIndent: c.lenient(.firstLineIndent, d.firstLineIndent),
                  paragraphSpacing: c.lenient(.paragraphSpacing, d.paragraphSpacing),
                  theme: c.lenient(.theme, d.theme),
                  typewriter: c.lenient(.typewriter, d.typewriter),
                  typewriterAnchor: c.lenient(.typewriterAnchor, d.typewriterAnchor),
                  focus: c.lenient(.focus, d.focus),
                  mode: c.lenient(.mode, d.mode),
                  blinkCaret: c.lenient(.blinkCaret, d.blinkCaret),
                  smartSubstitutions: c.lenient(.smartSubstitutions, d.smartSubstitutions),
                  showPageShadow: c.lenient(.showPageShadow, d.showPageShadow))
    }
}

// MARK: - Studio

extension SpineThread {
    enum CK: String, CodingKey { case id, name, colorIndex, promise, payoff, order, archived }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), name: c.lenient(.name, "Untitled"),
                  colorIndex: c.lenient(.colorIndex, 0), promise: c.lenient(.promise, ""),
                  payoff: c.lenient(.payoff, ""), order: c.lenient(.order, 0),
                  archived: c.lenient(.archived, false))
    }
}

extension Beat {
    enum CK: String, CodingKey { case id, nodeID, threadID, text, verb }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), nodeID: c.lenient(.nodeID, UUID()),
                  threadID: c.lenient(.threadID, UUID()), text: c.lenient(.text, ""),
                  verb: c.lenient(.verb, ""))
    }
}

extension EntityField {
    enum CK: String, CodingKey { case id, key, value, long }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), key: c.lenient(.key, ""),
                  value: c.lenient(.value, ""), long: c.lenient(.long, false))
    }
}

extension SourceQuote {
    enum CK: String, CodingKey { case id, text, locator, note }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), text: c.lenient(.text, ""),
                  locator: c.lenient(.locator, ""), note: c.lenient(.note, ""))
    }
}

extension Entity {
    enum CK: String, CodingKey {
        case id, kind, name, aliases, role, summary, fields, colorIndex
        case citation, url, permission, quotes, citekey, csl
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), kind: c.lenient(.kind, EntityKind.character),
                  name: c.lenient(.name, "Unnamed"), aliases: c.lenient(.aliases, [String]()),
                  role: c.lenient(.role, ""), summary: c.lenient(.summary, ""),
                  fields: c.lenient(.fields, [EntityField]()),
                  colorIndex: c.lenient(.colorIndex, 0), citation: c.lenient(.citation, ""),
                  url: c.lenient(.url, ""),
                  permission: c.lenient(.permission, PermissionStatus.notApplicable),
                  quotes: c.lenient(.quotes, [SourceQuote]()),
                  citekey: c.lenient(.citekey, ""),
                  csl: c.lenient(.csl, CSLItem()))
    }
}

extension Claim {
    enum CK: String, CodingKey { case id, text, nodeID, threadID, sourceIDs, strength, status, note }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), text: c.lenient(.text, ""),
                  nodeID: c.lenientOpt(.nodeID), threadID: c.lenientOpt(.threadID),
                  sourceIDs: c.lenient(.sourceIDs, [UUID]()),
                  strength: c.lenient(.strength, Strength.unsupported),
                  status: c.lenient(.status, FactStatus.unverified),
                  note: c.lenient(.note, ""))
    }
}

extension NoteCard {
    enum CK: String, CodingKey {
        case id, title, body, tags, x, y, colorIndex, linkedNodeIDs, linkedNoteIDs
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), title: c.lenient(.title, "Untitled"),
                  body: c.lenient(.body, ""), tags: c.lenient(.tags, [String]()),
                  x: c.lenient(.x, 0), y: c.lenient(.y, 0),
                  colorIndex: c.lenient(.colorIndex, 0),
                  linkedNodeIDs: c.lenient(.linkedNodeIDs, [UUID]()),
                  linkedNoteIDs: c.lenient(.linkedNoteIDs, [UUID]()))
    }
}

extension WritingSession {
    enum CK: String, CodingKey {
        case id, started, ended, wordsAdded, wordsCut, nodeIDs
        case goalKind, goalValue, goalNote, goalMet, mood, energy, place
        case nextLine, progressNote
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), started: c.lenient(.started, Date()),
                  ended: c.lenientOpt(.ended), wordsAdded: c.lenient(.wordsAdded, 0),
                  wordsCut: c.lenient(.wordsCut, 0), nodeIDs: c.lenient(.nodeIDs, [UUID]()),
                  goalKind: c.lenient(.goalKind, GoalKind.unit),
                  goalValue: c.lenient(.goalValue, 25), goalNote: c.lenient(.goalNote, ""),
                  goalMet: c.lenient(.goalMet, false), mood: c.lenientOpt(.mood),
                  energy: c.lenientOpt(.energy), place: c.lenient(.place, ""),
                  nextLine: c.lenient(.nextLine, ""),
                  progressNote: c.lenient(.progressNote, ""))
    }
}

extension SessionLog {
    enum CK: String, CodingKey { case sessions }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(sessions: c.lenient(.sessions, [WritingSession]()))
    }
}

// MARK: - Enums
//
// An unknown enum case from a newer version falls back rather than throwing.

extension NodeKind {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = NodeKind(rawValue: raw) ?? .document
    }
}
extension NodeStatus {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = NodeStatus(rawValue: raw) ?? .outline
    }
}
extension ProjectKind {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = ProjectKind(rawValue: raw) ?? .fiction
    }
}
extension PageTheme {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = PageTheme(rawValue: raw) ?? .paper
    }
}
extension FocusMode {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = FocusMode(rawValue: raw) ?? .off
    }
}
extension WriteMode {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = WriteMode(rawValue: raw) ?? .draft
    }
}
extension EntityKind {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = EntityKind(rawValue: raw) ?? .character
    }
}
extension PermissionStatus {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = PermissionStatus(rawValue: raw) ?? .notApplicable
    }
}
extension Strength {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Strength(rawValue: raw) ?? .unsupported
    }
}
extension FactStatus {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = FactStatus(rawValue: raw) ?? .unverified
    }
}
extension GoalKind {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = GoalKind(rawValue: raw) ?? .unit
    }
}


// MARK: - Craft types

extension StructureBeat {
    enum CK: String, CodingKey { case id, name, targetAt, note, nodeID, done }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), name: c.lenient(.name, "Beat"),
                  targetAt: c.lenient(.targetAt, 0), note: c.lenient(.note, ""),
                  nodeID: c.lenientOpt(.nodeID), done: c.lenient(.done, false))
    }
}

extension StoryStructure {
    enum CK: String, CodingKey { case templateID, beats }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(templateID: c.lenient(.templateID, "blank"),
                  beats: c.lenient(.beats, [StructureBeat]()))
    }
}

extension TimelineEvent {
    enum CK: String, CodingKey {
        case id, title, nodeID, entityIDs, storyDate, storyOrder, note, colorIndex
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), title: c.lenient(.title, "Event"),
                  nodeID: c.lenientOpt(.nodeID), entityIDs: c.lenient(.entityIDs, [UUID]()),
                  storyDate: c.lenient(.storyDate, ""), storyOrder: c.lenient(.storyOrder, 0),
                  note: c.lenient(.note, ""), colorIndex: c.lenient(.colorIndex, 0))
    }
}

extension Fact {
    enum CK: String, CodingKey { case id, entityID, key, value, nodeID, accepted }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), entityID: c.lenient(.entityID, UUID()),
                  key: c.lenient(.key, ""), value: c.lenient(.value, ""),
                  nodeID: c.lenientOpt(.nodeID), accepted: c.lenient(.accepted, false))
    }
}

extension Annotation {
    enum CK: String, CodingKey {
        case id, nodeID, quoted, location, body, resolved, created, author
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), nodeID: c.lenient(.nodeID, UUID()),
                  quoted: c.lenient(.quoted, ""), location: c.lenient(.location, 0),
                  body: c.lenient(.body, ""), resolved: c.lenient(.resolved, false),
                  created: c.lenient(.created, Date()), author: c.lenient(.author, ""))
    }
}

extension CSLName {
    enum CK: String, CodingKey { case family, given }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(family: c.lenient(.family, ""), given: c.lenient(.given, ""))
    }
}

extension CSLItem {
    enum CK: String, CodingKey {
        case id, type, title, authors, editors, containerTitle, publisher
        case publisherPlace, issued, volume, issue, page, doi, url, accessed, edition
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, ""), type: c.lenient(.type, "book"),
                  title: c.lenient(.title, ""), authors: c.lenient(.authors, [CSLName]()),
                  editors: c.lenient(.editors, [CSLName]()),
                  containerTitle: c.lenient(.containerTitle, ""),
                  publisher: c.lenient(.publisher, ""),
                  publisherPlace: c.lenient(.publisherPlace, ""),
                  issued: c.lenient(.issued, ""), volume: c.lenient(.volume, ""),
                  issue: c.lenient(.issue, ""), page: c.lenient(.page, ""),
                  doi: c.lenient(.doi, ""), url: c.lenient(.url, ""),
                  accessed: c.lenient(.accessed, ""), edition: c.lenient(.edition, ""))
    }
}

extension CitationStyle {
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = CitationStyle(rawValue: raw) ?? .chicagoNotes
    }
}


extension Appointment {
    enum CK: String, CodingKey {
        case id, when, minutes, place, nodeID, intention, weekly, eventID
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        self.init(id: c.lenient(.id, UUID()), when: c.lenient(.when, Date()),
                  minutes: c.lenient(.minutes, 30), place: c.lenient(.place, ""),
                  nodeID: c.lenientOpt(.nodeID), intention: c.lenient(.intention, ""),
                  weekly: c.lenient(.weekly, false), eventID: c.lenient(.eventID, ""))
    }
}
