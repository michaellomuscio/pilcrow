import Foundation
import AppKit

var fails = 0
func check(_ ok: Bool, _ what: String, _ detail: String = "") {
    print(ok ? "  ok    \(what)" : "  FAIL  \(what)  \(detail)")
    if !ok { fails += 1 }
}

// ── Prose diagnostics ───────────────────────────────────────────────
@MainActor func testProse() {
    let text = """
    The house was quiet. She had been awake since four, and the manuscript had not moved.
    "Are you coming down?" he said. "It's nearly six."
    She really did not want to. She just sat there, quietly, and considered the manuscript.
    The door was opened by someone else entirely.
    """
    let r = Prose.analyse(text)
    check(r.sentences >= 6, "sentences split", "got \(r.sentences)")
    check(r.words > 40, "words counted", "got \(r.words)")
    check(r.adverbs.contains { $0.0 == "quietly" }, "adverb found")
    check(r.filterWords.contains { $0.0 == "really" }, "filter word found")
    check(r.filterWords.contains { $0.0 == "just" }, "second filter word found")
    check(r.passiveCount >= 1, "passive construction detected", "got \(r.passiveCount)")
    check(r.dialogueShare > 0.05, "dialogue detected", "got \(r.dialogueShare)")
    check(r.sentenceStdDev > 0, "variance computed")

    // Markup must not leak into the word list.
    let marked = Prose.analyse("She was **utterly** still [@sword2016]. ## Heading")
    check(!marked.crutchWords.contains { $0.0.contains("*") }, "asterisks stripped")
    check(!marked.crutchWords.contains { $0.0 == "sword2016" }, "citation keys stripped")

    // snake_case survives the underscore stripper.
    let snake = Prose.stripMarkup("the snake_case_name stays")
    check(snake.contains("snake_case_name"), "snake_case survives", snake)

    check(Prose.syllables("manuscript") == 3, "syllables: manuscript",
          "\(Prose.syllables("manuscript"))")
    check(Prose.syllables("the") == 1, "syllables: the")
}

// ── Citations ───────────────────────────────────────────────────────
@MainActor func testCitations() {
    let json = """
    [{"id":"sword2016","type":"article-journal",
      "title":"'Write every day!': a mantra dismantled",
      "author":[{"family":"Sword","given":"Helen"}],
      "container-title":"International Journal for Academic Development",
      "volume":"21","issue":"4","page":"312-322",
      "issued":{"date-parts":[[2016,8,11]]},"DOI":"10.1080/1360144X.2016.1210153"},
     {"id":"boice1989","type":"article-journal","title":"Procrastination, busyness and bingeing",
      "author":[{"family":"Boice","given":"Robert"}],
      "container-title":"Behaviour Research and Therapy",
      "issued":{"date-parts":[[1989]]}}]
    """
    guard let items = try? CSLImport.parse(Data(json.utf8)), items.count == 2 else {
        check(false, "CSL-JSON parses"); return
    }
    check(true, "CSL-JSON parses")
    let sword = items[0]
    check(sword.authors.first?.family == "Sword", "author parsed")
    check(sword.year == "2016", "year from date-parts", sword.year)
    check(sword.volume == "21", "volume parsed")
    check(sword.doi.contains("1360144X"), "DOI parsed")

    for style in CitationStyle.allCases {
        let bib = CitationFormatter.bibliography(sword, style: style)
        check(bib.contains("Sword"), "\(style.rawValue): author in bibliography")
        check(bib.contains("2016"), "\(style.rawValue): year in bibliography")
        check(!bib.contains("  "), "\(style.rawValue): no double spaces", bib)
    }
    let apa = CitationFormatter.inText(sword, locator: "p. 314", style: .apa)
    check(apa.hasPrefix("(Sword, 2016"), "APA in-text", apa)
    let mla = CitationFormatter.inText(sword, locator: "314", style: .mla)
    check(mla == "(Sword 314)", "MLA in-text", mla)
    let note = CitationFormatter.note(sword, locator: "314", short: false)
    check(note.contains("Helen Sword") && note.hasSuffix("."), "Chicago note", note)
    let short = CitationFormatter.note(sword, locator: "9", short: true)
    check(short.hasPrefix("Sword,"), "Chicago short note", short)

    // Scanner
    let prose = "Only 12% write daily [@sword2016, p. 316], against Boice [@boice1989]."
    let refs = CitationScanner.scan(prose)
    check(refs.count == 2, "two citations found", "got \(refs.count)")
    check(refs.first?.key == "sword2016", "key parsed")
    check(refs.first?.locator == "p. 316", "locator parsed", refs.first?.locator ?? "")
    let replaced = CitationScanner.replace(in: prose) { "[\($0.key)]" }
    check(!replaced.contains("[@"), "markers replaced", replaced)
    check(replaced.contains("[sword2016]") && replaced.contains("[boice1989]"),
          "both replaced", replaced)

    // Key generation must not collide.
    var taken = Set<String>()
    let k1 = CSLItem.makeKey([CSLName(family: "Sword", given: "Helen")], "2016", taken: taken)
    taken.insert(k1)
    let k2 = CSLItem.makeKey([CSLName(family: "Sword", given: "Helen")], "2016", taken: taken)
    check(k1 == "sword2016", "citekey generated", k1)
    check(k2 != k1, "collision avoided", k2)
}

// ── Continuity ──────────────────────────────────────────────────────
@MainActor func testContinuity() {
    let eleanor = Entity(kind: .character, name: "Nell Kerrigan")
    let elenor  = Entity(kind: .character, name: "Nel Kerrigan")   // one edit away
    let facts = [
        Fact(entityID: eleanor.id, key: "eyes", value: "brown"),
        Fact(entityID: eleanor.id, key: "eyes", value: "green")
    ]
    let issues = ContinuityCheck.run(facts: facts, cast: [eleanor, elenor],
                                     notes: [], documents: [], body: { _ in "" })
    check(issues.contains { $0.kind == .contradiction }, "contradiction flagged")
    check(issues.contains { $0.kind == .nameDrift }, "name drift flagged")

    // Accepted facts stop nagging.
    var accepted = facts
    accepted[0].accepted = true; accepted[1].accepted = true
    let quiet = ContinuityCheck.run(facts: accepted, cast: [eleanor],
                                    notes: [], documents: [], body: { _ in "" })
    check(!quiet.contains { $0.kind == .contradiction }, "accepted facts stop flagging")

    check(ContinuityCheck.editDistance("eleanor", "elenor") == 1, "edit distance 1")
    check(ContinuityCheck.editDistance("eleanor", "zachary") >= 2, "edit distance far")
}

// ── Structure overlay ───────────────────────────────────────────────
@MainActor func testStructure() {
    let t = StructureTemplate.find("save-the-cat")!
    check(t.beats.count == 15, "Save the Cat has 15 beats", "\(t.beats.count)")
    check(t.beats.contains { $0.name == "Midpoint" && $0.at == 0.5 }, "midpoint at 50%")

    var st = StoryStructure.from(t)
    // Four scenes, 1000 words each; put the midpoint in the last one.
    let docs = (0..<4).map { i -> Node in
        var n = Node.document("Scene \(i)"); n.wordCount = 1000; return n
    }
    if let i = st.beats.firstIndex(where: { $0.name == "Midpoint" }) {
        st.beats[i].nodeID = docs[3].id
    }
    let places = StructureAnalysis.placements(structure: st, documents: docs,
                                              bodyWords: { id in
                                                  docs.first { $0.id == id }?.wordCount ?? 0 })
    let mid = places.first { $0.beat.name == "Midpoint" }!
    check(mid.actualAt != nil, "midpoint placed")
    // Middle of the 4th of four equal scenes = 87.5% of the book.
    check(abs((mid.actualAt ?? 0) - 0.875) < 0.01, "position measured in words",
          "\(mid.actualAt ?? -1)")
    check(mid.isAdrift, "drift detected")
    check(mid.driftLabel.contains("late"), "drift described", mid.driftLabel)

    let unplaced = places.first { $0.node == nil }
    check(unplaced?.actualAt == nil, "unplaced beats stay unplaced")
}

// ── ZIP / EPUB container ────────────────────────────────────────────
@MainActor func testZip() {
    var z = ZipWriter()
    z.add("mimetype", Data("application/epub+zip".utf8))
    z.add("META-INF/container.xml", Data("<x/>".utf8))
    let data = z.finish()
    check(data.count > 60, "zip produced bytes", "\(data.count)")
    check(data.prefix(4) == Data([0x50, 0x4b, 0x03, 0x04]), "local file header signature")
    // mimetype must be the first entry, stored, uncompressed.
    let head = String(data: data.prefix(64), encoding: .isoLatin1) ?? ""
    check(head.contains("mimetype"), "mimetype first")
    check(head.contains("application/epub+zip"), "mimetype stored uncompressed")
    check(data.suffix(22).prefix(4) == Data([0x50, 0x4b, 0x05, 0x06]),
          "end of central directory")
    check(CRC32.compute(Data("123456789".utf8)) == 0xCBF43926, "CRC32 matches the standard check value")

    // Round-trip through the system unzip to prove it's a real archive.
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pilcrow-zip-\(UUID().uuidString).zip")
    try? data.write(to: tmp)
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    task.arguments = ["-t", tmp.path]
    task.standardOutput = Pipe(); task.standardError = Pipe()
    try? task.run(); task.waitUntilExit()
    check(task.terminationStatus == 0, "system unzip validates the archive",
          "exit \(task.terminationStatus)")
    try? FileManager.default.removeItem(at: tmp)
}

// ── Comment anchors ─────────────────────────────────────────────────
// Regression: a location of NSNotFound (Int.max) used to overflow and trap
// the whole app during layout. Anchor offsets come off disk — treat every
// one of them as hostile.
@MainActor func testAnchors() {
    let text = "The house was quiet in the way that only a house full of sleeping people can be." as NSString

    let good = Annotation(nodeID: UUID(), quoted: "sleeping people", location: 55)
    check(good.range(in: text) != nil, "anchor found at a valid offset")

    let moved = Annotation(nodeID: UUID(), quoted: "sleeping people", location: 3)
    check(moved.range(in: text)?.location == text.range(of: "sleeping people").location,
          "stale offset re-finds the quote")

    for (name, loc) in [("NSNotFound", NSNotFound), ("Int.max", Int.max),
                        ("Int.min", Int.min), ("negative", -42),
                        ("past the end", 100_000)] {
        let bad = Annotation(nodeID: UUID(), quoted: "sleeping people", location: loc)
        let r = bad.range(in: text)
        check(r != nil, "hostile offset survives: \(name)")
        if let r { check(NSMaxRange(r) <= text.length, "\(name) yields an in-bounds range") }
    }

    let absent = Annotation(nodeID: UUID(), quoted: "not in this text at all", location: NSNotFound)
    check(absent.range(in: text) == nil, "missing quote returns nil, not a crash")

    let tooLong = Annotation(nodeID: UUID(),
                             quoted: String(repeating: "x", count: 500), location: 0)
    check(tooLong.range(in: text) == nil, "quote longer than the text returns nil")

    let empty = Annotation(nodeID: UUID(), quoted: "", location: 0)
    check(empty.range(in: "" as NSString) == nil, "empty quote and empty text return nil")
}

MainActor.assumeIsolated {
    print("── prose");      testProse()
    print("── citations");  testCitations()
    print("── continuity"); testContinuity()
    print("── structure");  testStructure()
    print("── zip/epub");   testZip()
    print("── anchors");   testAnchors()
}
print(fails == 0 ? "\nALL PASSED" : "\n\(fails) FAILED")
exit(fails == 0 ? 0 : 1)
