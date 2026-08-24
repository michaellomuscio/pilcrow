import Foundation
import AppKit

var fails = 0
func check(_ ok: Bool, _ what: String, _ d: String = "") {
    print(ok ? "  ok    \(what)" : "  FAIL  \(what)  \(d)")
    if !ok { fails += 1 }
}

@MainActor func run() {
    // Build a throwaway project so this harness depends on nothing.
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pilcrow-export-\(UUID().uuidString.prefix(8))")
    defer { try? FileManager.default.removeItem(at: root) }
    let folder = root.appendingPathComponent("Test Book")
    guard let store = try? ProjectStore.create(at: folder, title: "Test Book",
                                               author: "M. Lomuscio", kind: .nonfiction) else {
        check(false, "create project"); return
    }
    check(true, "create project")

    let ch = store.manifest.root.children.first!.id
    let seed = store.manifest.root.documents.first!.id
    store.setBody(seed, """
    The house was quiet in the way that only a house full of sleeping people can be.

    She had been awake since *four*, and the manuscript had not moved a word since **Tuesday**.

    ---

    Somewhere below, the furnace turned over and settled again.
    """)
    let two = store.addDocument(title: "Second Section", parent: ch)
    store.setBody(two, "A second section, so the compiler has more than one thing to walk.\n")

    // Give it a real source and a real citation in the prose.
    var src = Entity(kind: .source, name: "'Write every day!': a mantra dismantled")
    src.citekey = "sword2016"
    src.csl = CSLItem(id: "sword2016", type: "article-journal",
                      title: "'Write every day!': a mantra dismantled",
                      authors: [CSLName(family: "Sword", given: "Helen")],
                      containerTitle: "International Journal for Academic Development",
                      issued: "2016", volume: "21", issue: "4", page: "312-322",
                      doi: "10.1080/1360144X.2016.1210153")
    src.permission = .onRecord
    store.manifest.cast.append(src)

    let first = seed
    store.setBody(first, store.body(first)
        + "\n\nOnly about one in eight writers works daily [@sword2016, p. 316].\n")
    try? store.saveNow()

    var opts = CompileOptions()

    // ── EPUB ────────────────────────────────────────────────────────
    opts.format = .epub
    guard let epub = try? Compiler.compile(store: store, options: opts) else {
        check(false, "epub compiles"); return
    }
    check(epub.count > 1000, "epub produced bytes", "\(epub.count)")
    let epubURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pilcrow-test.epub")
    try? epub.write(to: epubURL)

    func shell(_ exe: String, _ args: [String]) -> (Int32, String) {
        let t = Process(); t.executableURL = URL(fileURLWithPath: exe); t.arguments = args
        let out = Pipe(); t.standardOutput = out; t.standardError = Pipe()
        try? t.run(); t.waitUntilExit()
        let d = out.fileHandleForReading.readDataToEndOfFile()
        return (t.terminationStatus, String(data: d, encoding: .utf8) ?? "")
    }

    let (code, listing) = shell("/usr/bin/unzip", ["-l", epubURL.path])
    check(code == 0, "epub is a valid archive", "exit \(code)")
    for entry in ["mimetype", "META-INF/container.xml", "OEBPS/content.opf",
                  "OEBPS/nav.xhtml", "OEBPS/style.css"] {
        check(listing.contains(entry), "epub contains \(entry)")
    }
    let (_, chapters) = shell("/usr/bin/unzip", ["-p", epubURL.path, "OEBPS/ch001.xhtml"])
    check(chapters.contains("<h1>"), "chapter has a heading")
    check(chapters.contains("house was quiet"), "chapter has the prose")
    check(chapters.contains("<em>"), "italics survived to XHTML")
    check(!chapters.contains("[@"), "citation markers resolved", 
          String(chapters.prefix(80)))
    let (_, notes) = shell("/usr/bin/unzip", ["-p", epubURL.path, "OEBPS/notes.xhtml"])
    check(notes.contains("Sword"), "note references the source")
    check(notes.contains("Bibliography"), "bibliography rendered")
    let (_, mime) = shell("/usr/bin/unzip", ["-p", epubURL.path, "mimetype"])
    check(mime.trimmingCharacters(in: .whitespacesAndNewlines) == "application/epub+zip",
          "mimetype correct")

    // ── PDF ─────────────────────────────────────────────────────────
    opts.format = .pdfBook
    var pdfOpts = PDFBook.Options()
    pdfOpts.page = .trade6x9
    guard let pdf = try? Compiler.compile(store: store, options: opts, pdf: pdfOpts) else {
        check(false, "pdf compiles"); return
    }
    check(pdf.prefix(5) == Data("%PDF-".utf8), "pdf magic bytes")
    check(pdf.count > 5000, "pdf produced bytes", "\(pdf.count)")
    if let doc = PDFDocumentShim.pageCount(pdf) {
        check(doc >= 3, "pdf has pages", "\(doc) pages")
    } else {
        check(false, "pdf readable")
    }

    // ── RTF still works ─────────────────────────────────────────────
    opts.format = .manuscriptRTF
    let rtf = try? Compiler.compile(store: store, options: opts)
    check((rtf?.count ?? 0) > 500, "manuscript rtf still compiles")

    // ── Warnings surface unresolved keys ────────────────────────────
    store.setBody(first, store.body(first) + "\n\nA claim with a bad key [@nosuchkey].\n")
    let g = Citations.gather(store: store, options: opts)
    check(g.unresolved.contains("nosuchkey"), "unresolved citation key detected")
    check(g.numbers.count >= 1, "resolved citation numbered")

    try? FileManager.default.removeItem(at: epubURL)
}

import Quartz
enum PDFDocumentShim {
    static func pageCount(_ data: Data) -> Int? {
        PDFDocument(data: data)?.pageCount
    }
}

MainActor.assumeIsolated { run() }
print(fails == 0 ? "\nALL PASSED" : "\n\(fails) FAILED")
exit(fails == 0 ? 0 : 1)
