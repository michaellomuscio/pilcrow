//  Compiler.swift
//  Getting the book out.
//
//  Standard manuscript format is what agents and editors still ask for,
//  and getting it wrong reads as amateur before anyone reads a line:
//  12pt serif, double spaced, first-line indent, scene breaks as #,
//  a title block with a running word count.

import AppKit
import Foundation

enum CompileFormat: String, CaseIterable, Identifiable {
    case manuscriptRTF, wordDOC, epub, pdfBook, markdown, plainText, html
    var id: String { rawValue }

    var label: String {
        switch self {
        case .manuscriptRTF: return "Standard Manuscript (.rtf)"
        case .wordDOC:       return "Word (.doc)"
        case .epub:          return "EPUB (.epub)"
        case .pdfBook:       return "Typeset book (.pdf)"
        case .markdown:      return "Markdown (.md)"
        case .plainText:     return "Plain text (.txt)"
        case .html:          return "HTML (.html)"
        }
    }
    var ext: String {
        switch self {
        case .manuscriptRTF: return "rtf"
        case .wordDOC:       return "doc"
        case .epub:          return "epub"
        case .pdfBook:       return "pdf"
        case .markdown:      return "md"
        case .plainText:     return "txt"
        case .html:          return "html"
        }
    }
    var note: String {
        switch self {
        case .manuscriptRTF:
            return "Times 12pt, double spaced, indented paragraphs, scene breaks as #. What an agent expects. Opens in Word, Pages, and Google Docs."
        case .wordDOC:
            return "Same layout, Word\u{2019}s own format."
        case .epub:
            return "A real ebook. Reflows to any screen, with a table of contents and linked notes. Opens in Books, Kindle (via conversion), and every e-reader."
        case .pdfBook:
            return "Typeset with CoreText \u{2014} trim size, mirrored margins, running heads, folios, chapters opening on a fresh right-hand page. What a finished book looks like."
        case .markdown:
            return "One file, chapter headings as #. The format your book is already stored in."
        case .plainText:
            return "No formatting at all. For pasting anywhere."
        case .html:
            return "For the web, or for anything that reads HTML."
        }
    }
}

struct CompileOptions {
    var format: CompileFormat = .manuscriptRTF
    var includeTitlePage = true
    var chapterBreaks = true
    var includeSynopses = false
    var onlyIncluded = true
    /// Resolve [@citekey] markers into notes and a bibliography.
    var resolveCitations = true
}

@MainActor
enum Compiler {

    // MARK: Entry point

    static func compile(store: ProjectStore, options: CompileOptions,
                        pdf: PDFBook.Options = PDFBook.Options()) throws -> Data {
        Citations.ensureKeys(store)
        switch options.format {
        case .epub:
            return EPUBExport.build(store: store, options: options)
        case .pdfBook:
            return PDFBook.build(store: store, compile: options, options: pdf)
        case .markdown, .plainText:
            return Data(plainOutput(store: store, options: options).utf8)
        case .manuscriptRTF, .wordDOC, .html:
            let attributed = manuscript(store: store, options: options)
            let range = NSRange(location: 0, length: attributed.length)
            let type: NSAttributedString.DocumentType
            switch options.format {
            case .wordDOC: type = .docFormat
            case .html:    type = .html
            default:       type = .rtf
            }
            return try attributed.data(from: range, documentAttributes: [
                .documentType: type,
                .characterEncoding: String.Encoding.utf8.rawValue
            ])
        }
    }

    // MARK: Plain

    private static func plainOutput(store: ProjectStore, options: CompileOptions) -> String {
        var out = ""
        let m = store.manifest
        if options.includeTitlePage {
            if options.format == .markdown {
                out += "# \(m.title)\n\n"
                if !m.subtitle.isEmpty { out += "*\(m.subtitle)*\n\n" }
                if !m.author.isEmpty { out += "\(m.author)\n\n" }
                out += "---\n\n"
            } else {
                out += "\(m.title.uppercased())\n"
                if !m.subtitle.isEmpty { out += "\(m.subtitle)\n" }
                if !m.author.isEmpty { out += "by \(m.author)\n" }
                out += "\n\n"
            }
        }
        walk(store.manifest.root, depth: 0, options: options) { node, depth in
            let body = store.body(node.id)
            if node.isFolder {
                if options.format == .markdown {
                    out += String(repeating: "#", count: min(3, depth + 1)) + " \(node.title)\n\n"
                } else {
                    out += "\n\n\(node.title.uppercased())\n\n"
                }
            } else if options.chapterBreaks && depth == 0 {
                out += "\n\n\(node.title)\n\n"
            }
            if options.includeSynopses && !node.synopsis.isEmpty {
                out += options.format == .markdown ? "> \(node.synopsis)\n\n" : "[\(node.synopsis)]\n\n"
            }
            if !body.isEmpty {
                out += (options.format == .plainText ? stripMarkup(body) : body) + "\n\n"
            }
        }
        return out
    }

    private static func stripMarkup(_ s: String) -> String {
        var t = s
        for pattern in ["\\*\\*\\*", "\\*\\*", "\\*", "^#{1,3} "] {
            t = t.replacingOccurrences(of: pattern, with: "",
                                       options: [.regularExpression])
        }
        return t.replacingOccurrences(of: MarkdownCodec.sceneBreakDisk, with: "#")
    }

    // MARK: Manuscript

    private static func manuscript(store: ProjectStore, options: CompileOptions) -> NSAttributedString {
        let m = store.manifest
        let out = NSMutableAttributedString()
        let bodyFont = NSFont(name: "Times New Roman", size: 12)
            ?? NSFont.systemFont(ofSize: 12)

        let bodyPara = NSMutableParagraphStyle()
        bodyPara.lineHeightMultiple = 2.0          // double spaced
        bodyPara.firstLineHeadIndent = 36          // half an inch
        bodyPara.alignment = .left

        let flushPara = NSMutableParagraphStyle()
        flushPara.lineHeightMultiple = 2.0
        flushPara.alignment = .left

        let centred = NSMutableParagraphStyle()
        centred.lineHeightMultiple = 2.0
        centred.alignment = .center

        func append(_ s: String, _ para: NSParagraphStyle, _ font: NSFont) {
            out.append(NSAttributedString(string: s, attributes: [
                .font: font, .paragraphStyle: para, .foregroundColor: NSColor.black
            ]))
        }

        if options.includeTitlePage {
            let words = store.totalWords
            append("\(m.author)\n", flushPara, bodyFont)
            append("about \(roundWords(words).grouped) words\n\n\n\n\n\n", flushPara, bodyFont)
            append("\(m.title.uppercased())\n", centred, bodyFont)
            if !m.subtitle.isEmpty { append("\(m.subtitle)\n", centred, bodyFont) }
            if !m.author.isEmpty { append("by \(m.author)\n", centred, bodyFont) }
            append("\u{000C}\n", centred, bodyFont)     // page break
        }

        walk(store.manifest.root, depth: 0, options: options) { node, depth in
            if node.isFolder || (options.chapterBreaks && depth == 0) {
                if out.length > 0 && options.chapterBreaks {
                    append("\u{000C}\n", centred, bodyFont)
                }
                append("\(node.title)\n\n", centred, bodyFont)
            }
            let body = store.body(node.id)
            guard !body.isEmpty else { return }
            for (i, line) in body.components(separatedBy: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == MarkdownCodec.sceneBreakDisk {
                    append("#\n", centred, bodyFont)
                } else if trimmed.isEmpty {
                    continue
                } else {
                    let inline = MarkdownCodec.attributed(
                        from: trimmed,
                        style: manuscriptStyle())
                    let piece = NSMutableAttributedString(attributedString: inline)
                    let full = NSRange(location: 0, length: piece.length)
                    // Re-cast to the manuscript face, preserving bold/italic.
                    piece.enumerateAttribute(.font, in: full, options: []) { v, sub, _ in
                        let traits = (v as? NSFont)?.fontDescriptor.symbolicTraits ?? []
                        var keep: NSFontDescriptor.SymbolicTraits = []
                        if traits.contains(.bold) { keep.insert(.bold) }
                        if traits.contains(.italic) { keep.insert(.italic) }
                        let f = keep.isEmpty ? bodyFont
                            : (NSFont(descriptor: bodyFont.fontDescriptor.withSymbolicTraits(keep),
                                      size: 12) ?? bodyFont)
                        piece.addAttributes([.font: f, .foregroundColor: NSColor.black], range: sub)
                    }
                    piece.addAttribute(.paragraphStyle,
                                       value: i == 0 ? flushPara : bodyPara, range: full)
                    out.append(piece)
                    out.append(NSAttributedString(string: "\n", attributes: [
                        .font: bodyFont, .paragraphStyle: bodyPara
                    ]))
                }
            }
        }
        return out
    }

    private static func manuscriptStyle() -> PageStyle {
        var s = PageStyle()
        s.faceID = "literata"
        s.mode = .revise
        s.fontSize = 12
        return s
    }

    private static func roundWords(_ n: Int) -> Int {
        n < 1500 ? (n / 100) * 100 : Int((Double(n) / 1000).rounded()) * 1000
    }

    // MARK: Walk

    private static func walk(_ node: Node, depth: Int, options: CompileOptions,
                             _ visit: (Node, Int) -> Void) {
        for child in node.children {
            if options.onlyIncluded && !child.includeInCompile { continue }
            if child.status == .cut { continue }
            visit(child, depth)
            walk(child, depth: depth + 1, options: options, visit)
        }
    }

    // MARK: Warnings
    //
    // Compile is the last gate before something leaves the building, so it
    // is the right place to catch a quote you never got permission for.

    static func warnings(store: ProjectStore) -> [String] {
        var out: [String] = []
        let blocked = store.manifest.cast.filter { $0.permission.isBlocking }
        for s in blocked where !s.quotes.isEmpty || !s.name.isEmpty {
            let used = store.orderedDocuments.contains {
                store.body($0.id).localizedCaseInsensitiveContains(s.name)
            }
            if used { out.append("\u{201C}\(s.name)\u{201D} is marked Needs release and appears in the manuscript.") }
        }
        let naked = store.manifest.claims.filter { $0.strength == .unsupported }.count
        if naked > 0 { out.append("\(naked) claim\(naked == 1 ? "" : "s") in the Evidence ledger have no source attached.") }
        let refuted = store.manifest.claims.filter { $0.strength == .refuted }.count
        if refuted > 0 { out.append("\(refuted) claim\(refuted == 1 ? " is" : "s are") marked Refuted and still in the book.") }
        return out
    }
}
