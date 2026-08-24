//  MarkdownCodec.swift
//  Markdown <-> NSAttributedString, restricted to the subset a manuscript
//  actually needs: emphasis, strong, headings, and scene breaks.
//
//  The restriction is the point. A small, total, round-trippable subset
//  beats a large lossy one — your prose on disk stays prose.

import AppKit

extension NSAttributedString.Key {
    /// 1...3 for heading levels. Absent on body paragraphs.
    static let pilcrowHeading = NSAttributedString.Key("pilcrowHeading")
    /// Marks the paragraph as a scene break.
    static let pilcrowSceneBreak = NSAttributedString.Key("pilcrowSceneBreak")
}

enum MarkdownCodec {

    /// What a scene break looks like on the page. On disk it is `---`.
    static let sceneBreakGlyph = "\u{2042}"   // ⁂ asterism
    static let sceneBreakDisk  = "---"

    // MARK: - Parse

    static func attributed(from markdown: String, style: PageStyle) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        var firstBody = true

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == sceneBreakDisk || trimmed == "***" || trimmed == "* * *" {
                out.append(sceneBreak(style: style))
                firstBody = true
            } else if let (level, text) = headingParts(trimmed) {
                out.append(heading(text, level: level, style: style))
                firstBody = true
            } else {
                out.append(paragraph(line, style: style, first: firstBody))
                if !trimmed.isEmpty { firstBody = false }
            }
            if i < lines.count - 1 {
                out.append(NSAttributedString(string: "\n"))
            }
        }
        if out.length == 0 {
            out.append(paragraph("", style: style, first: true))
        }
        return out
    }

    private static func headingParts(_ line: String) -> (Int, String)? {
        var level = 0
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == "#", level < 3 {
            level += 1
            idx = line.index(after: idx)
        }
        guard level > 0, idx < line.endIndex, line[idx] == " " else { return nil }
        return (level, String(line[line.index(after: idx)...]))
    }

    private static func sceneBreak(style: PageStyle) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        p.lineHeightMultiple = style.activeLineHeight
        p.paragraphSpacingBefore = style.fontSize * 0.9
        p.paragraphSpacing = style.fontSize * 0.9
        return NSAttributedString(string: sceneBreakGlyph, attributes: [
            .font: style.activeFace.nsFont(size: style.fontSize),
            .foregroundColor: LL.pageInk(style.theme).withAlphaComponent(0.5),
            .paragraphStyle: p,
            .kern: style.fontSize * 0.35,
            .pilcrowSceneBreak: true
        ])
    }

    private static func heading(_ text: String, level: Int, style: PageStyle) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.lineHeightMultiple = 1.25
        p.paragraphSpacingBefore = style.fontSize * (level == 1 ? 1.6 : 1.2)
        p.paragraphSpacing = style.fontSize * 0.5
        p.alignment = level == 1 ? .center : .left
        let scale: CGFloat = level == 1 ? 1.7 : (level == 2 ? 1.32 : 1.12)
        let f = style.activeFace.nsFont(size: style.fontSize * scale,
                                        weight: level == 1 ? .regular : .semibold)
        let s = NSMutableAttributedString(string: text, attributes: [
            .font: f,
            .foregroundColor: LL.pageInk(style.theme),
            .paragraphStyle: p,
            .pilcrowHeading: level
        ])
        applyInline(to: s, style: style, baseFont: f)
        return s
    }

    private static func paragraph(_ line: String, style: PageStyle, first: Bool) -> NSAttributedString {
        let f = style.activeFace.nsFont(size: style.fontSize)
        let s = NSMutableAttributedString(string: line, attributes: [
            .font: f,
            .foregroundColor: LL.pageInk(style.theme),
            .paragraphStyle: style.paragraphStyle(firstParagraph: first)
        ])
        applyInline(to: s, style: style, baseFont: f)
        return s
    }

    // MARK: - Inline emphasis

    private struct Mark { let range: NSRange; let bold: Bool; let italic: Bool; let delim: Int }

    /// Finds emphasis runs, applies traits, then removes the delimiters
    /// back-to-front so earlier ranges stay valid.
    private static func applyInline(to s: NSMutableAttributedString, style: PageStyle, baseFont: NSFont) {
        let text = s.string as NSString
        var marks: [Mark] = []
        var i = 0
        let n = text.length

        func isEscaped(_ at: Int) -> Bool {
            var slashes = 0, k = at - 1
            while k >= 0, text.character(at: k) == 92 { slashes += 1; k -= 1 }
            return slashes % 2 == 1
        }

        while i < n {
            let c = text.character(at: i)
            guard c == 42 || c == 95, !isEscaped(i) else { i += 1; continue }  // * or _
            var runLen = 1
            while i + runLen < n, text.character(at: i + runLen) == c, runLen < 3 { runLen += 1 }

            // Underscores only count at word boundaries (snake_case stays intact).
            if c == 95 {
                let before = i > 0 ? text.character(at: i - 1) : 32
                if isWordChar(before) { i += runLen; continue }
            }

            // Find the matching closing run of the same length.
            var j = i + runLen
            var close = -1
            while j < n {
                if text.character(at: j) == c, !isEscaped(j) {
                    var l = 1
                    while j + l < n, text.character(at: j + l) == c, l < 3 { l += 1 }
                    if l >= runLen {
                        if c == 95 {
                            let after = j + l < n ? text.character(at: j + l) : 32
                            if isWordChar(after) { j += l; continue }
                        }
                        close = j
                        break
                    }
                    j += l
                } else {
                    j += 1
                }
            }
            guard close > i + runLen else { i += runLen; continue }

            let inner = NSRange(location: i + runLen, length: close - i - runLen)
            marks.append(Mark(range: NSRange(location: i, length: close + runLen - i),
                              bold: runLen >= 2, italic: runLen == 1 || runLen == 3,
                              delim: runLen))
            _ = inner
            i = close + runLen
        }

        for m in marks.reversed() {
            let innerLoc = m.range.location + m.delim
            let innerLen = m.range.length - 2 * m.delim
            guard innerLen > 0 else { continue }
            let inner = NSRange(location: innerLoc, length: innerLen)
            var traits: NSFontDescriptor.SymbolicTraits = []
            if m.bold { traits.insert(.bold) }
            if m.italic { traits.insert(.italic) }
            let f = emphasised(baseFont, traits: traits)
            s.addAttribute(.font, value: f, range: inner)
            // Delete the closing run first so the opening range stays valid.
            s.deleteCharacters(in: NSRange(location: inner.location + inner.length, length: m.delim))
            s.deleteCharacters(in: NSRange(location: m.range.location, length: m.delim))
        }

        unescape(s)
    }

    private static func isWordChar(_ u: unichar) -> Bool {
        (u >= 48 && u <= 57) || (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95
    }

    private static func emphasised(_ base: NSFont, traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        guard !traits.isEmpty else { return base }
        let d = base.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: d, size: base.pointSize) ?? base
    }

    private static func unescape(_ s: NSMutableAttributedString) {
        let pattern = try! NSRegularExpression(pattern: "\\\\([*_#\\\\])")
        let matches = pattern.matches(in: s.string, range: NSRange(location: 0, length: s.length))
        for m in matches.reversed() {
            s.deleteCharacters(in: NSRange(location: m.range.location, length: 1))
        }
    }

    // MARK: - Serialize

    static func markdown(from attributed: NSAttributedString) -> String {
        let ns = attributed.string as NSString
        var out = ""
        var lineStart = 0

        while lineStart < ns.length {
            let lineRange = ns.lineRange(for: NSRange(location: lineStart, length: 0))
            let newlineLen = trailingNewlineLength(ns, lineRange)
            let contentLen = max(0, lineRange.length - newlineLen)
            let content = NSRange(location: lineRange.location, length: contentLen)

            if contentLen > 0, attributed.attribute(.pilcrowSceneBreak, at: content.location,
                                                    effectiveRange: nil) != nil {
                out += sceneBreakDisk
            } else {
                var prefix = ""
                if contentLen > 0,
                   let lvl = attributed.attribute(.pilcrowHeading, at: content.location,
                                                  effectiveRange: nil) as? Int {
                    prefix = String(repeating: "#", count: max(1, min(3, lvl))) + " "
                }
                out += prefix + inlineMarkdown(attributed, in: content)
            }

            // Emit the separator only when one was actually there, so a file
            // that ends in a newline keeps it and one that doesn't stays put.
            if newlineLen > 0 { out += "\n" }
            lineStart = lineRange.location + lineRange.length
        }
        return out
    }

    private static func trailingNewlineLength(_ ns: NSString, _ r: NSRange) -> Int {
        guard r.length > 0 else { return 0 }
        let last = ns.character(at: r.location + r.length - 1)
        if last == 10 || last == 13 || last == 0x2028 || last == 0x2029 { return 1 }
        return 0
    }

    private static func inlineMarkdown(_ s: NSAttributedString, in range: NSRange) -> String {
        guard range.length > 0 else { return "" }
        var out = ""
        s.enumerateAttribute(.font, in: range, options: []) { value, sub, _ in
            let raw = (s.string as NSString).substring(with: sub)
            let escaped = escape(raw)
            guard let f = value as? NSFont else { out += escaped; return }
            let t = f.fontDescriptor.symbolicTraits
            let bold = t.contains(.bold), italic = t.contains(.italic)
            let d = bold && italic ? "***" : (bold ? "**" : (italic ? "*" : ""))
            if d.isEmpty || raw.trimmingCharacters(in: .whitespaces).isEmpty {
                out += escaped
            } else {
                // Keep surrounding whitespace outside the delimiters so the
                // markup stays valid.
                let lead = raw.prefix(while: { $0 == " " })
                let trail = raw.reversed().prefix(while: { $0 == " " }).reversed()
                let core = raw.dropFirst(lead.count).dropLast(trail.count)
                out += String(lead) + d + escape(String(core)) + d + String(trail)
            }
        }
        return out
    }

    private static func escape(_ s: String) -> String {
        var r = ""
        for ch in s {
            if ch == "*" || ch == "_" || ch == "\\" { r.append("\\") }
            r.append(ch)
        }
        return r
    }

    // MARK: - Counting

    /// Words, counted the way a manuscript counts them.
    static func wordCount(_ s: String) -> Int {
        var n = 0
        var inWord = false
        for ch in s.unicodeScalars {
            let isSep = CharacterSet.whitespacesAndNewlines.contains(ch)
            if isSep { inWord = false }
            else if !inWord { inWord = true; n += 1 }
        }
        return n
    }
}
