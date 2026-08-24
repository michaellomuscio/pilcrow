//  Typography.swift
//  The font shelf and the page metrics.
//
//  Six faces, curated rather than a picker with eight hundred. Five are
//  bundled under the SIL Open Font License; Charter ships with macOS.
//  The measure is expressed in characters, not pixels, because a pixel
//  width is wrong the moment the reader changes the font size.

import SwiftUI
import AppKit
import CoreText

// MARK: - The shelf

struct PageFace: Identifiable, Hashable {
    let id: String
    let family: String        // family name as registered with the system
    let display: String
    let note: String
    /// Faces with a small x-height need to be set larger to stay comfortable.
    let sizeAdjust: CGFloat
    /// Drafting faces are offered in Draft mode; serifs carry Revise mode.
    let isDrafting: Bool
    let fallback: String

    func nsFont(size: CGFloat, weight: NSFont.Weight = .regular, italic: Bool = false) -> NSFont {
        PilcrowFonts.resolve(family: family, fallback: fallback,
                           size: size * sizeAdjust, weight: weight, italic: italic)
    }
}

enum PilcrowFonts {

    // MARK: Shelf

    static let shelf: [PageFace] = [
        PageFace(id: "literata", family: "Literata", display: "Literata",
                 note: "Built for long-form reading on screens. The safe default.",
                 sizeAdjust: 1.00, isDrafting: false, fallback: "Georgia"),

        PageFace(id: "newsreader", family: "Newsreader", display: "Newsreader",
                 note: "More voice, and genuinely beautiful italics.",
                 sizeAdjust: 1.02, isDrafting: false, fallback: "Georgia"),

        PageFace(id: "sourceserif", family: "Source Serif 4", display: "Source Serif 4",
                 note: "Even-toned and silent. Best for nonfiction.",
                 sizeAdjust: 1.00, isDrafting: false, fallback: "Georgia"),

        PageFace(id: "ebgaramond", family: "EB Garamond", display: "EB Garamond",
                 note: "A true book face. Low x-height, so it sets larger.",
                 sizeAdjust: 1.12, isDrafting: false, fallback: "Palatino"),

        PageFace(id: "charter", family: "Charter", display: "Charter",
                 note: "Matthew Carter, built for low resolution. Ships with macOS.",
                 sizeAdjust: 1.00, isDrafting: false, fallback: "Georgia"),

        PageFace(id: "quattro", family: "iA Writer Quattro S", display: "iA Writer Quattro",
                 note: "Duospace. Honest and unfinished — good for bad first drafts.",
                 sizeAdjust: 0.94, isDrafting: true, fallback: "Menlo")
    ]

    static func face(_ id: String) -> PageFace {
        shelf.first { $0.id == id } ?? shelf[0]
    }

    // MARK: Registration

    private static var didRegister = false

    /// Registers every bundled font file. Safe to call more than once.
    static func registerBundledFonts() {
        guard !didRegister else { return }
        didRegister = true
        guard let resources = Bundle.main.resourceURL else { return }
        let candidates = [resources.appendingPathComponent("Fonts"), resources]
        var seen = Set<String>()
        for dir in candidates {
            guard let items = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for url in items where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
                guard seen.insert(url.lastPathComponent).inserted else { continue }
                var err: Unmanaged<CFError>?
                // A duplicate registration is not a failure worth reporting.
                _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err)
            }
        }
    }

    // MARK: Resolution

    /// Resolves a family + weight + slant, honouring variable-font axes and
    /// falling back cleanly when a face is missing.
    static func resolve(family: String, fallback: String, size: CGFloat,
                        weight: NSFont.Weight, italic: Bool) -> NSFont {
        for name in [family, fallback] {
            var attrs: [NSFontDescriptor.AttributeName: Any] = [
                .family: name,
                .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue]
            ]
            if italic {
                attrs[.traits] = [
                    NSFontDescriptor.TraitKey.weight: weight.rawValue,
                    NSFontDescriptor.TraitKey.symbolic: NSFontDescriptor.SymbolicTraits.italic.rawValue
                ]
            }
            var desc = NSFontDescriptor(fontAttributes: attrs)
            if italic { desc = desc.withSymbolicTraits(.italic) }
            if let f = NSFont(descriptor: desc, size: size),
               f.familyName?.caseInsensitiveCompare(name) == .orderedSame {
                return f
            }
        }
        let sys = NSFont.systemFont(ofSize: size, weight: weight)
        guard italic else { return sys }
        return NSFont(descriptor: sys.fontDescriptor.withSymbolicTraits(.italic), size: size) ?? sys
    }

    // MARK: Brand chrome faces

    /// Bebas Neue — wordmark and impact text only, always uppercase.
    static func display(_ size: CGFloat) -> NSFont {
        resolve(family: "Bebas Neue", fallback: "Impact", size: size, weight: .regular, italic: false)
    }
    /// Urbanist — headings, panel titles, nav, buttons.
    static func heading(_ size: CGFloat, _ weight: NSFont.Weight = .bold) -> NSFont {
        resolve(family: "Urbanist", fallback: "Avenir Next", size: size, weight: weight, italic: false)
    }
    /// Figtree — UI body copy.
    static func body(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        resolve(family: "Figtree", fallback: "Helvetica Neue", size: size, weight: weight, italic: false)
    }
    /// IBM Plex Mono — counts, timers, metadata labels.
    static func mono(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        resolve(family: "IBM Plex Mono", fallback: "Menlo", size: size, weight: weight, italic: false)
    }

    // SwiftUI conveniences
    static func displayF(_ s: CGFloat) -> Font { Font(display(s)) }
    static func headingF(_ s: CGFloat, _ w: NSFont.Weight = .bold) -> Font { Font(heading(s, w)) }
    static func bodyF(_ s: CGFloat, _ w: NSFont.Weight = .regular) -> Font { Font(body(s, w)) }
    static func monoF(_ s: CGFloat, _ w: NSFont.Weight = .regular) -> Font { Font(mono(s, w)) }

    // MARK: Measure

    private static var measureCache: [String: CGFloat] = [:]

    /// A paragraph of ordinary English — normal capitalisation, normal
    /// punctuation, normal letter frequencies. Estimating from the alphabet
    /// overshoots (too many m's and w's); estimating from lowercase-only
    /// prose undershoots (no capitals). Only real text gets it right.
    private static let proseSample = """
    The house was quiet in the way that only a house full of sleeping people     can be, a quiet with weight to it, pressing down through the floorboards.     She had been awake since four, and the manuscript on the kitchen table had     not moved a word since Tuesday. Somewhere below her the furnace turned over,     caught, and settled again into its long familiar silence.
    """

    /// Width in points that actually fits `characters` characters of running
    /// text in `font`. Solved by laying the sample out and correcting, rather
    /// than by multiplying an average advance — an average is wrong by five to
    /// ten percent, and differently wrong for every face. Cached per face+size.
    static func measureWidth(font: NSFont, characters: Int) -> CGFloat {
        let key = "\(font.fontName)|\(font.pointSize)|\(characters)"
        if let hit = measureCache[key] { return hit }

        // Seed from the crude average, then converge on the real thing.
        let alphabet = "abcdefghijklmnopqrstuvwxyz "
        let avg = (alphabet as NSString).size(withAttributes: [.font: font]).width
                / CGFloat(alphabet.count)
        var width = max(120, avg * CGFloat(characters))

        for _ in 0..<10 {
            let cpl = averageCharactersPerLine(font: font, width: width)
            guard cpl > 1 else { break }
            let error = CGFloat(characters) / cpl
            if abs(error - 1) < 0.006 { break }
            width *= error
        }
        width = width.rounded()
        measureCache[key] = width
        return width
    }

    private static func averageCharactersPerLine(font: NSFont, width: CGFloat) -> CGFloat {
        let storage = NSTextStorage(string: proseSample, attributes: [.font: font])
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: width, height: 100_000))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)

        var lengths: [Int] = []
        var glyph = 0
        while glyph < layout.numberOfGlyphs {
            var lineRange = NSRange()
            _ = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &lineRange)
            let chars = layout.characterRange(forGlyphRange: lineRange, actualGlyphRange: nil)
            lengths.append(chars.length)
            glyph = NSMaxRange(lineRange)
        }
        // The last line is a partial one and would drag the average down.
        let full = lengths.dropLast()
        guard !full.isEmpty else { return 0 }
        return CGFloat(full.reduce(0, +)) / CGFloat(full.count)
    }
}

// MARK: - Page style

enum FocusMode: String, Codable, CaseIterable, Identifiable {
    case off, paragraph, sentence
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off: return "Off"
        case .paragraph: return "Paragraph"
        case .sentence: return "Sentence"
        }
    }
}

enum WriteMode: String, Codable, CaseIterable, Identifiable {
    case draft, revise
    var id: String { rawValue }
    var label: String { self == .draft ? "Draft" : "Revise" }
    var help: String {
        self == .draft
        ? "Spellcheck, counts, and every analysis panel are hidden. Generate; don't evaluate."
        : "Everything on. Diagnostics, spellcheck, counts."
    }
}

/// Everything about how the page looks and behaves. Persisted per project.
struct PageStyle: Codable, Equatable {
    var faceID: String = "literata"
    /// Draft mode changes what the app *shows you*, not what the page looks
    /// like. Quattro is on the shelf for anyone who wants the typewriter
    /// feel while drafting, but the default is the same good serif in both
    /// modes — there is no reason a first draft should be uglier.
    var draftFaceID: String = "literata"
    var fontSize: CGFloat = 19
    var lineHeight: CGFloat = 1.72
    var draftLineHeight: CGFloat = 1.85
    var measure: Int = 66              // characters; clamped to 55...75
    var firstLineIndent: CGFloat = 1.6 // em
    var paragraphSpacing: CGFloat = 0  // book convention, not web convention
    var theme: PageTheme = .paper
    var typewriter: Bool = true
    var typewriterAnchor: CGFloat = 0.42
    var focus: FocusMode = .off
    var mode: WriteMode = .draft
    var blinkCaret: Bool = false       // a blinking caret is a moving object
    var smartSubstitutions: Bool = true
    var showPageShadow: Bool = true

    var activeFaceID: String { mode == .draft ? draftFaceID : faceID }
    var activeFace: PageFace { PilcrowFonts.face(activeFaceID) }
    var activeLineHeight: CGFloat { mode == .draft ? draftLineHeight : lineHeight }

    var clampedMeasure: Int { min(75, max(55, measure)) }

    func bodyFont() -> NSFont { activeFace.nsFont(size: fontSize) }

    /// Paragraph style implementing book conventions: first-line indent,
    /// no space between paragraphs, generous leading.
    func paragraphStyle(firstParagraph: Bool = false) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        let f = bodyFont()
        p.lineHeightMultiple = activeLineHeight
        p.paragraphSpacing = paragraphSpacing
        p.firstLineHeadIndent = firstParagraph ? 0 : firstLineIndent * f.pointSize
        p.lineBreakMode = .byWordWrapping
        p.alignment = .left
        return p
    }
}
