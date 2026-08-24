//  EPUB.swift
//  A valid EPUB 3, written without a zip library.
//
//  Entries are stored rather than deflated. That is legal EPUB — and the
//  `mimetype` entry is *required* to be stored anyway — so the only cost is
//  file size, which for a book of text is a rounding error next to not
//  taking on a compression dependency.

import Foundation

// MARK: - Minimal ZIP

struct ZipWriter {
    private struct Entry {
        let name: String
        let data: Data
        let crc: UInt32
        let offset: UInt32
    }
    private var entries: [Entry] = []
    private var out = Data()

    mutating func add(_ name: String, _ data: Data) {
        let crc = CRC32.compute(data)
        let offset = UInt32(out.count)
        var header = Data()
        header.append(le32(0x04034b50))          // local file header
        header.append(le16(20))                   // version needed
        header.append(le16(0))                    // flags
        header.append(le16(0))                    // method: stored
        header.append(le16(0)); header.append(le16(0))   // time, date
        header.append(le32(crc))
        header.append(le32(UInt32(data.count)))   // compressed
        header.append(le32(UInt32(data.count)))   // uncompressed
        let nameData = Data(name.utf8)
        header.append(le16(UInt16(nameData.count)))
        header.append(le16(0))                    // extra length
        header.append(nameData)
        out.append(header)
        out.append(data)
        entries.append(Entry(name: name, data: data, crc: crc, offset: offset))
    }

    mutating func finish() -> Data {
        let dirStart = UInt32(out.count)
        for e in entries {
            var h = Data()
            h.append(le32(0x02014b50))            // central directory header
            h.append(le16(20)); h.append(le16(20))
            h.append(le16(0)); h.append(le16(0))
            h.append(le16(0)); h.append(le16(0))
            h.append(le32(e.crc))
            h.append(le32(UInt32(e.data.count)))
            h.append(le32(UInt32(e.data.count)))
            let nameData = Data(e.name.utf8)
            h.append(le16(UInt16(nameData.count)))
            h.append(le16(0)); h.append(le16(0))
            h.append(le16(0)); h.append(le16(0))
            h.append(le32(0))
            h.append(le32(e.offset))
            h.append(nameData)
            out.append(h)
        }
        let dirSize = UInt32(out.count) - dirStart
        var end = Data()
        end.append(le32(0x06054b50))
        end.append(le16(0)); end.append(le16(0))
        end.append(le16(UInt16(entries.count)))
        end.append(le16(UInt16(entries.count)))
        end.append(le32(dirSize))
        end.append(le32(dirStart))
        end.append(le16(0))
        out.append(end)
        return out
    }

    private func le16(_ v: UInt16) -> Data {
        Data([UInt8(v & 0xff), UInt8((v >> 8) & 0xff)])
    }
    private func le32(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xff), UInt8((v >> 8) & 0xff),
              UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)])
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }
    static func compute(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for b in data { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFFFFFF
    }
}

// MARK: - EPUB

@MainActor
enum EPUBExport {

    static func build(store: ProjectStore, options: CompileOptions) -> Data {
        let m = store.manifest
        var zip = ZipWriter()
        // mimetype must come first and be stored uncompressed.
        zip.add("mimetype", Data("application/epub+zip".utf8))
        zip.add("META-INF/container.xml", Data(container.utf8))

        let chapters = collect(store: store, options: options)
        let notes = Citations.gather(store: store, options: options)

        var manifestItems = ""
        var spineItems = ""
        var navItems = ""

        for (i, ch) in chapters.enumerated() {
            let file = String(format: "ch%03d.xhtml", i + 1)
            zip.add("OEBPS/\(file)", Data(chapterXHTML(ch, style: m.citationStyle,
                                                       notes: notes).utf8))
            manifestItems += "    <item id=\"ch\(i)\" href=\"\(file)\" media-type=\"application/xhtml+xml\"/>\n"
            spineItems += "    <itemref idref=\"ch\(i)\"/>\n"
            navItems += "        <li><a href=\"\(file)\">\(esc(ch.title))</a></li>\n"
        }

        if !notes.ordered.isEmpty {
            zip.add("OEBPS/notes.xhtml", Data(notesXHTML(notes, style: m.citationStyle,
                                                          title: m.citationStyle.bibliographyTitle).utf8))
            manifestItems += "    <item id=\"notes\" href=\"notes.xhtml\" media-type=\"application/xhtml+xml\"/>\n"
            spineItems += "    <itemref idref=\"notes\"/>\n"
            navItems += "        <li><a href=\"notes.xhtml\">Notes</a></li>\n"
        }

        zip.add("OEBPS/style.css", Data(css.utf8))
        zip.add("OEBPS/nav.xhtml", Data(nav(title: m.title, items: navItems).utf8))
        zip.add("OEBPS/content.opf", Data(opf(m: m, manifestItems: manifestItems,
                                              spineItems: spineItems,
                                              words: store.totalWords).utf8))
        return zip.finish()
    }

    // MARK: Pieces

    struct Chapter { let title: String; let paragraphs: [String]; let level: Int }

    private static func collect(store: ProjectStore, options: CompileOptions) -> [Chapter] {
        var out: [Chapter] = []
        func walk(_ node: Node, depth: Int) {
            for child in node.children {
                if options.onlyIncluded && !child.includeInCompile { continue }
                if child.status == .cut { continue }
                let body = store.body(child.id)
                let paras = body.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if child.isFolder {
                    out.append(Chapter(title: child.title, paragraphs: paras, level: depth))
                } else if depth == 0 || out.isEmpty {
                    out.append(Chapter(title: child.title, paragraphs: paras, level: depth))
                } else {
                    // A scene folds into the chapter it belongs to.
                    let last = out.removeLast()
                    out.append(Chapter(title: last.title,
                                       paragraphs: last.paragraphs
                                        + (last.paragraphs.isEmpty ? [] : ["---"])
                                        + paras,
                                       level: last.level))
                }
                walk(child, depth: depth + 1)
            }
        }
        walk(store.manifest.root, depth: 0)
        return out.filter { !$0.paragraphs.isEmpty || !$0.title.isEmpty }
    }

    private static func chapterXHTML(_ ch: Chapter, style: CitationStyle,
                                     notes: Citations.Gathered) -> String {
        var body = "<h1>\(esc(ch.title))</h1>\n"
        var first = true
        for p in ch.paragraphs {
            if p == "---" || p == MarkdownCodec.sceneBreakDisk {
                body += "<p class=\"break\">\u{2042}</p>\n"; first = true; continue
            }
            if let (level, text) = heading(p) {
                body += "<h\(min(3, level + 1))>\(inline(text, style: style, notes: notes))</h\(min(3, level + 1))>\n"
                first = true; continue
            }
            body += "<p class=\"\(first ? "first" : "")\">\(inline(p, style: style, notes: notes))</p>\n"
            first = false
        }
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="en">
        <head><title>\(esc(ch.title))</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
        <body>
        \(body)</body></html>
        """
    }

    private static func notesXHTML(_ notes: Citations.Gathered, style: CitationStyle,
                                   title: String) -> String {
        var body = ""
        if style.isNumbered && !notes.ordered.isEmpty {
            body += "<h1>Notes</h1>\n<ol class=\"notes\">\n"
            for n in notes.ordered {
                body += "<li id=\"n\(n.number)\">\(esc(n.text))</li>\n"
            }
            body += "</ol>\n"
        }
        let bib = notes.bibliography(style: style)
        if !bib.isEmpty {
            body += "<h1>\(esc(title))</h1>\n"
            for line in bib { body += "<p class=\"bib\">\(esc(line))</p>\n" }
        }
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" lang="en">
        <head><title>Notes</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
        <body>
        \(body)</body></html>
        """
    }

    private static func heading(_ line: String) -> (Int, String)? {
        var level = 0
        var i = line.startIndex
        while i < line.endIndex, line[i] == "#", level < 3 { level += 1; i = line.index(after: i) }
        guard level > 0, i < line.endIndex, line[i] == " " else { return nil }
        return (level, String(line[line.index(after: i)...]))
    }

    /// Emphasis + citation markers, in that order, then XML-escaped.
    private static func inline(_ s: String, style: CitationStyle,
                               notes: Citations.Gathered) -> String {
        let withCites = CitationScanner.replace(in: s) { ref in
            guard let n = notes.number(for: ref) else { return "" }
            if style.isNumbered {
                return "\u{0001}sup\u{0001}\(n)\u{0001}/sup\u{0001}"
            }
            return notes.inTextString(for: ref, style: style)
        }
        var out = esc(withCites)
        out = out.replacingOccurrences(of: #"\*\*\*(.+?)\*\*\*"#, with: "<strong><em>$1</em></strong>",
                                       options: .regularExpression)
        out = out.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>",
                                       options: .regularExpression)
        out = out.replacingOccurrences(of: #"\*(.+?)\*"#, with: "<em>$1</em>",
                                       options: .regularExpression)
        // Restore the superscript markers we protected from escaping.
        out = out.replacingOccurrences(of: "\u{0001}sup\u{0001}", with: "<sup>")
                 .replacingOccurrences(of: "\u{0001}/sup\u{0001}", with: "</sup>")
        return out
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static let container = """
    <?xml version="1.0" encoding="UTF-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
    </container>
    """

    private static let css = """
    @page { margin: 5%; }
    body { font-family: Georgia, 'Iowan Old Style', serif; line-height: 1.6; margin: 0 5%; }
    h1 { font-size: 1.5em; font-weight: normal; text-align: center;
         margin: 3em 0 1.5em; page-break-before: always; }
    h2 { font-size: 1.2em; margin: 2em 0 0.6em; }
    p { margin: 0; text-indent: 1.5em; text-align: justify; }
    p.first { text-indent: 0; }
    p.break { text-indent: 0; text-align: center; margin: 1.4em 0; letter-spacing: 0.4em; }
    p.bib { text-indent: -1.5em; margin-left: 1.5em; margin-bottom: 0.7em; text-align: left; }
    ol.notes li { margin-bottom: 0.6em; }
    sup { font-size: 0.7em; vertical-align: super; }
    """

    private static func nav(title: String, items: String) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="en">
        <head><title>\(esc(title))</title></head>
        <body><nav epub:type="toc" id="toc"><h1>Contents</h1><ol>
        \(items)      </ol></nav></body></html>
        """
    }

    private static func opf(m: ProjectManifest, manifestItems: String,
                            spineItems: String, words: Int) -> String {
        let date = ISO8601DateFormatter().string(from: Date())
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">urn:uuid:\(m.id.uuidString.lowercased())</dc:identifier>
            <dc:title>\(esc(m.title))</dc:title>
            <dc:creator>\(esc(m.author))</dc:creator>
            <dc:language>en</dc:language>
            <meta property="dcterms:modified">\(date.prefix(19))Z</meta>
          </metadata>
          <manifest>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="css" href="style.css" media-type="text/css"/>
        \(manifestItems)  </manifest>
          <spine>
        \(spineItems)  </spine>
        </package>
        """
    }
}
