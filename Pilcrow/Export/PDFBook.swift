//  PDFBook.swift
//  A typeset book, drawn with CoreText.
//
//  Not "print the editor to PDF" — real book pages: trim size, mirrored
//  margins, running heads on verso and recto, folios, chapters opening on a
//  fresh recto, and endnotes at the back.

import AppKit
import CoreText

enum PageSize: String, CaseIterable, Identifiable {
    case trade6x9, digest5_5x8_5, letter, a4
    var id: String { rawValue }

    var label: String {
        switch self {
        case .trade6x9:      return "Trade 6 \u{00D7} 9 in"
        case .digest5_5x8_5: return "Digest 5.5 \u{00D7} 8.5 in"
        case .letter:        return "US Letter"
        case .a4:            return "A4"
        }
    }
    /// In points, 72 to the inch.
    var size: CGSize {
        switch self {
        case .trade6x9:      return CGSize(width: 432, height: 648)
        case .digest5_5x8_5: return CGSize(width: 396, height: 612)
        case .letter:        return CGSize(width: 612, height: 792)
        case .a4:            return CGSize(width: 595, height: 842)
        }
    }
    var isManuscript: Bool { self == .letter || self == .a4 }
}

@MainActor
enum PDFBook {

    struct Options {
        var page: PageSize = .trade6x9
        var faceID: String = "literata"
        var bodySize: CGFloat = 11
        var leading: CGFloat = 1.42
        var runningHeads = true
        var folios = true
        var chaptersOpenRecto = true
    }

    // MARK: Build

    static func build(store: ProjectStore, compile: CompileOptions,
                      options: Options) -> Data {
        let m = store.manifest
        let pageSize = options.page
        let trim = pageSize.size
        let out = NSMutableData()
        guard let consumer = CGDataConsumer(data: out) else { return Data() }
        var mediaBox = CGRect(origin: .zero, size: trim)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        // Generous inner margin so text doesn't disappear into the gutter.
        let inner: CGFloat = trim.width * 0.155
        let outer: CGFloat = trim.width * 0.115
        let top: CGFloat = trim.height * 0.095
        let bottom: CGFloat = trim.height * 0.105

        let face = PilcrowFonts.face(options.faceID)
        let body = face.nsFont(size: options.bodySize)
        let italicHead = PilcrowFonts.resolve(family: face.family, fallback: face.fallback,
                                              size: options.bodySize * 0.78,
                                              weight: .regular, italic: true)

        Citations.ensureKeys(store)
        let notes = Citations.gather(store: store, options: compile)
        let chapters = chapters(store: store, compile: compile)

        var pageNumber = 1
        var currentChapter = ""

        func drawFurniture(_ isRecto: Bool) {
            guard options.runningHeads || options.folios else { return }
            let head = isRecto ? currentChapter : m.title
            if options.runningHeads && pageNumber > 1 && !head.isEmpty {
                draw(head.uppercased(), font: italicHead, tracking: 1.1,
                     centre: trim.width / 2, y: trim.height - top * 0.62, ctx: ctx,
                     colour: NSColor.black.withAlphaComponent(0.55))
            }
            if options.folios && pageNumber > 1 {
                draw("\(pageNumber)", font: italicHead, tracking: 0,
                     centre: trim.width / 2, y: bottom * 0.5, ctx: ctx,
                     colour: NSColor.black.withAlphaComponent(0.65))
            }
        }

        // ── Title page ─────────────────────────────────────────────
        ctx.beginPDFPage(nil)
        let titleFont = face.nsFont(size: options.bodySize * 2.4)
        draw(m.title, font: titleFont, tracking: 0.6, centre: trim.width / 2,
             y: trim.height * 0.60, ctx: ctx, colour: .black)
        if !m.subtitle.isEmpty {
            draw(m.subtitle, font: face.nsFont(size: options.bodySize * 1.15),
                 tracking: 0.3, centre: trim.width / 2,
                 y: trim.height * 0.545, ctx: ctx, colour: NSColor.black.withAlphaComponent(0.75))
        }
        if !m.author.isEmpty {
            draw(m.author, font: face.nsFont(size: options.bodySize),
                 tracking: 0.8, centre: trim.width / 2,
                 y: trim.height * 0.28, ctx: ctx, colour: .black)
        }
        ctx.endPDFPage()
        pageNumber += 1

        // ── Chapters ───────────────────────────────────────────────
        for chapter in chapters {
            currentChapter = chapter.title
            let attributed = chapterAttributed(chapter, face: face, body: body,
                                               options: options, style: m.citationStyle,
                                               notes: notes)
            guard attributed.length > 0 else { continue }

            if options.chaptersOpenRecto && pageNumber % 2 == 1 {
                // Blank verso so the chapter opens on a right-hand page.
                ctx.beginPDFPage(nil); ctx.endPDFPage(); pageNumber += 1
            }

            let setter = CTFramesetterCreateWithAttributedString(attributed)
            var cursor = 0
            var firstPageOfChapter = true

            while cursor < attributed.length {
                let isRecto = pageNumber % 2 == 0
                let left = isRecto ? inner : outer
                let right = isRecto ? outer : inner
                // Drop the chapter opening down the page, the way books do.
                let sink: CGFloat = firstPageOfChapter ? trim.height * 0.14 : 0
                let frameRect = CGRect(x: left, y: bottom,
                                       width: trim.width - left - right,
                                       height: trim.height - top - bottom - sink)

                ctx.beginPDFPage(nil)
                if !firstPageOfChapter || true { drawFurniture(isRecto) }

                let path = CGPath(rect: frameRect, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    setter, CFRange(location: cursor, length: 0), path, nil)
                ctx.saveGState()
                ctx.textMatrix = .identity
                CTFrameDraw(frame, ctx)
                ctx.restoreGState()

                let visible = CTFrameGetVisibleStringRange(frame)
                ctx.endPDFPage()
                pageNumber += 1
                firstPageOfChapter = false
                if visible.length <= 0 { break }
                cursor += visible.length
            }
        }

        // ── Notes and bibliography ─────────────────────────────────
        let back = backMatter(notes: notes, style: m.citationStyle,
                              face: face, options: options)
        if back.length > 0 {
            currentChapter = "Notes"
            let setter = CTFramesetterCreateWithAttributedString(back)
            var cursor = 0
            while cursor < back.length {
                let isRecto = pageNumber % 2 == 0
                let left = isRecto ? inner : outer
                let right = isRecto ? outer : inner
                let frameRect = CGRect(x: left, y: bottom,
                                       width: trim.width - left - right,
                                       height: trim.height - top - bottom)
                ctx.beginPDFPage(nil)
                drawFurniture(isRecto)
                let frame = CTFramesetterCreateFrame(
                    setter, CFRange(location: cursor, length: 0),
                    CGPath(rect: frameRect, transform: nil), nil)
                ctx.saveGState(); ctx.textMatrix = .identity
                CTFrameDraw(frame, ctx); ctx.restoreGState()
                let visible = CTFrameGetVisibleStringRange(frame)
                ctx.endPDFPage()
                pageNumber += 1
                if visible.length <= 0 { break }
                cursor += visible.length
            }
        }

        ctx.closePDF()
        return out as Data
    }

    // MARK: Text

    private struct Chapter { let title: String; let lines: [String] }

    private static func chapters(store: ProjectStore, compile: CompileOptions) -> [Chapter] {
        var out: [Chapter] = []
        func walk(_ node: Node, depth: Int) {
            for child in node.children {
                if compile.onlyIncluded && !child.includeInCompile { continue }
                if child.status == .cut { continue }
                let lines = store.body(child.id).components(separatedBy: "\n")
                if child.isFolder || depth == 0 || out.isEmpty {
                    out.append(Chapter(title: child.title, lines: lines))
                } else {
                    let last = out.removeLast()
                    var merged = last.lines
                    if !merged.isEmpty && !lines.isEmpty { merged.append(MarkdownCodec.sceneBreakDisk) }
                    merged.append(contentsOf: lines)
                    out.append(Chapter(title: last.title, lines: merged))
                }
                walk(child, depth: depth + 1)
            }
        }
        walk(store.manifest.root, depth: 0)
        return out
    }

    private static func chapterAttributed(_ ch: Chapter, face: PageFace, body: NSFont,
                                          options: Options, style: CitationStyle,
                                          notes: Citations.Gathered) -> NSAttributedString {
        let out = NSMutableAttributedString()

        let titlePara = NSMutableParagraphStyle()
        titlePara.alignment = .center
        titlePara.paragraphSpacing = options.bodySize * 2.2
        out.append(NSAttributedString(string: ch.title + "\n", attributes: [
            .font: face.nsFont(size: options.bodySize * 1.55),
            .paragraphStyle: titlePara, .foregroundColor: NSColor.black,
            .kern: 0.4
        ]))

        let bodyPara = NSMutableParagraphStyle()
        bodyPara.lineHeightMultiple = options.leading
        bodyPara.firstLineHeadIndent = options.bodySize * 1.5
        bodyPara.alignment = .justified
        bodyPara.hyphenationFactor = 0.9

        let flushPara = NSMutableParagraphStyle()
        flushPara.lineHeightMultiple = options.leading
        flushPara.alignment = .justified
        flushPara.hyphenationFactor = 0.9

        let breakPara = NSMutableParagraphStyle()
        breakPara.alignment = .center
        breakPara.paragraphSpacingBefore = options.bodySize * 0.9
        breakPara.paragraphSpacing = options.bodySize * 0.9

        var firstOfSection = true
        for raw in ch.lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line == MarkdownCodec.sceneBreakDisk || line == "***" {
                out.append(NSAttributedString(string: "\u{2042}\n", attributes: [
                    .font: body, .paragraphStyle: breakPara,
                    .foregroundColor: NSColor.black.withAlphaComponent(0.6),
                    .kern: options.bodySize * 0.35
                ]))
                firstOfSection = true
                continue
            }

            // Resolve citations before styling so the marker never survives.
            let resolved = CitationScanner.replace(in: line) { ref in
                if style.isNumbered {
                    guard let n = notes.number(for: ref) else { return "" }
                    return "\u{2060}\(n)"    // marked below as superscript
                }
                return notes.inTextString(for: ref, style: style)
            }

            let piece = MarkdownCodec.attributed(from: resolved, style: pageStyleFor(options))
            let m = NSMutableAttributedString(attributedString: piece)
            let full = NSRange(location: 0, length: m.length)
            m.enumerateAttribute(.font, in: full, options: []) { v, sub, _ in
                let traits = (v as? NSFont)?.fontDescriptor.symbolicTraits ?? []
                var keep: NSFontDescriptor.SymbolicTraits = []
                if traits.contains(.bold) { keep.insert(.bold) }
                if traits.contains(.italic) { keep.insert(.italic) }
                let f = keep.isEmpty ? body
                    : (NSFont(descriptor: body.fontDescriptor.withSymbolicTraits(keep),
                              size: body.pointSize) ?? body)
                m.addAttributes([.font: f, .foregroundColor: NSColor.black], range: sub)
            }
            m.addAttribute(.paragraphStyle,
                           value: firstOfSection ? flushPara : bodyPara, range: full)
            superscriptNoteMarkers(m, body: body)
            m.append(NSAttributedString(string: "\n", attributes: [
                .font: body, .paragraphStyle: bodyPara
            ]))
            out.append(m)
            firstOfSection = false
        }
        return out
    }

    /// U+2060 marks a note number; raise and shrink whatever follows it.
    private static func superscriptNoteMarkers(_ m: NSMutableAttributedString, body: NSFont) {
        let ns = m.string as NSString
        var i = ns.length - 1
        while i >= 0 {
            if ns.character(at: i) == 0x2060 {
                var end = i + 1
                while end < ns.length, let s = Unicode.Scalar(ns.character(at: end)),
                      CharacterSet.decimalDigits.contains(s) { end += 1 }
                let digits = NSRange(location: i + 1, length: end - i - 1)
                if digits.length > 0 {
                    m.addAttributes([
                        .font: NSFont(descriptor: body.fontDescriptor, size: body.pointSize * 0.68)
                                ?? body,
                        .baselineOffset: body.pointSize * 0.36
                    ], range: digits)
                }
                m.deleteCharacters(in: NSRange(location: i, length: 1))
            }
            i -= 1
        }
    }

    private static func backMatter(notes: Citations.Gathered, style: CitationStyle,
                                   face: PageFace, options: Options) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let body = face.nsFont(size: options.bodySize * 0.88)

        let head = NSMutableParagraphStyle()
        head.alignment = .center
        head.paragraphSpacing = options.bodySize * 1.6

        let item = NSMutableParagraphStyle()
        item.lineHeightMultiple = 1.24
        item.paragraphSpacing = options.bodySize * 0.5
        item.headIndent = options.bodySize * 1.6
        item.firstLineHeadIndent = 0

        if style.isNumbered && !notes.ordered.isEmpty {
            out.append(NSAttributedString(string: "Notes\n", attributes: [
                .font: face.nsFont(size: options.bodySize * 1.35),
                .paragraphStyle: head, .foregroundColor: NSColor.black]))
            for n in notes.ordered {
                out.append(NSAttributedString(string: "\(n.number). \(plain(n.text))\n",
                                              attributes: [.font: body,
                                                           .paragraphStyle: item,
                                                           .foregroundColor: NSColor.black]))
            }
        }
        let bib = notes.bibliography(style: style)
        if !bib.isEmpty {
            out.append(NSAttributedString(string: "\n\(style.bibliographyTitle)\n", attributes: [
                .font: face.nsFont(size: options.bodySize * 1.35),
                .paragraphStyle: head, .foregroundColor: NSColor.black]))
            let hanging = NSMutableParagraphStyle()
            hanging.lineHeightMultiple = 1.24
            hanging.paragraphSpacing = options.bodySize * 0.5
            hanging.headIndent = options.bodySize * 1.6
            for line in bib {
                out.append(NSAttributedString(string: plain(line) + "\n", attributes: [
                    .font: body, .paragraphStyle: hanging, .foregroundColor: NSColor.black]))
            }
        }
        return out
    }

    private static func plain(_ s: String) -> String {
        s.replacingOccurrences(of: "*", with: "")
    }

    private static func pageStyleFor(_ o: Options) -> PageStyle {
        var s = PageStyle()
        s.faceID = o.faceID
        s.draftFaceID = o.faceID
        s.mode = .revise
        s.fontSize = o.bodySize
        return s
    }

    // MARK: Drawing helpers

    private static func draw(_ text: String, font: NSFont, tracking: CGFloat,
                             centre: CGFloat, y: CGFloat, ctx: CGContext,
                             colour: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: colour, .kern: tracking
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attrs))
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: centre - bounds.width / 2, y: y)
        CTLineDraw(line, ctx)
    }
}
