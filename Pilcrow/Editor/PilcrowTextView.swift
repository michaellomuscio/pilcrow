//  PilcrowTextView.swift
//  The page.
//
//  Deliberate choices, each one earning its keep:
//    · The caret does not blink. A blinking caret is a moving object in
//      peripheral vision — removing it is the single largest comfort win
//      available and almost nobody does it.
//    · Typewriter scrolling pins the caret at 42% of the viewport, so your
//      eyes stop tracking down the screen.
//    · The measure is set in characters, centred in the window, because a
//      pixel width is wrong the moment the reader changes the font size.
//    · Focus dimming uses temporary attributes, so it never touches the
//      text storage and never lands in the undo stack.

import AppKit

final class PilcrowTextView: NSTextView {

    var style = PageStyle() {
        didSet { applyStyleChrome() }
    }
    var onCaretMove: (() -> Void)?
    /// Ranges carrying a comment. Drawn as a tint, never as stored attributes.
    var annotationRanges: [NSRange] = [] { didSet { refreshOverlays() } }
    /// The word currently being spoken aloud.
    var spokenRange: NSRange? {
        didSet {
            refreshOverlays()
            if let r = spokenRange, NSMaxRange(r) <= (textStorage?.length ?? 0) {
                scrollRangeToVisible(r)
            }
        }
    }

    private var commandToken: NSObjectProtocol?

    // Format commands arrive from the menu bar. Only the text view that is
    // actually first responder acts on them, so two open books never fight.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            if let t = commandToken { NotificationCenter.default.removeObserver(t) }
            commandToken = nil
        } else if commandToken == nil {
            commandToken = NotificationCenter.default.addObserver(
                forName: PilcrowCommand.name, object: nil, queue: .main) { [weak self] note in
                    MainActor.assumeIsolated {
                        guard let self,
                              let raw = note.object as? String,
                              let cmd = PilcrowCommand(rawValue: raw),
                              self.window?.isKeyWindow == true,
                              self.window?.firstResponder === self else { return }
                        self.handleFormat(cmd)
                    }
                }
        }
    }

    private func handleFormat(_ cmd: PilcrowCommand) {
        switch cmd {
        case .bold:       toggleTrait(.bold)
        case .italic:     toggleTrait(.italic)
        case .h1:         setHeading(1)
        case .h2:         setHeading(2)
        case .h3:         setHeading(3)
        case .body:       setHeading(0)
        case .sceneBreak: insertSceneBreak()
        default: break
        }
    }

    deinit {
        if let t = commandToken { NotificationCenter.default.removeObserver(t) }
    }

    private var caretWidth: CGFloat { max(2, style.fontSize * 0.11) }

    // MARK: Caret

    override func updateInsertionPointStateAndRestartTimer(_ restartFlag: Bool) {
        // Passing false draws the caret solid and never starts the blink timer.
        super.updateInsertionPointStateAndRestartTimer(style.blinkCaret ? restartFlag : false)
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        var r = rect
        r.size.width = caretWidth
        super.drawInsertionPoint(in: r, color: color, turnedOn: style.blinkCaret ? flag : true)
    }

    // MARK: Layout

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity,
                                    stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        applyFocusDimming()
        onCaretMove?()
        if !stillSelecting { scrollCaretToAnchor(animated: false) }
    }

    override func didChangeText() {
        super.didChangeText()
        applyFocusDimming()
        scrollCaretToAnchor(animated: false)
    }

    /// Re-centres the text column and gives the document enough tail room
    /// that the last line can still reach the typewriter anchor.
    func applyStyleChrome() {
        guard let container = textContainer, let scroll = enclosingScrollView else { return }
        let font = style.bodyFont()
        let measure = PilcrowFonts.measureWidth(font: font, characters: style.clampedMeasure)
        let available = scroll.contentSize.width
        let side = max(28, (available - measure) / 2)
        let clampedMeasure = min(measure, max(200, available - 56))

        container.containerSize = NSSize(width: clampedMeasure, height: .greatestFiniteMagnitude)
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0

        let tail = style.typewriter ? scroll.contentSize.height * (1 - style.typewriterAnchor) : 80
        textContainerInset = NSSize(width: side, height: 60)
        // Tail room lives on the scroll view so it doesn't shift the top inset.
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: max(80, tail), right: 0)

        backgroundColor = LL.paper(style.theme)
        insertionPointColor = LL.accentNS.withAlphaComponent(0.85)
        selectedTextAttributes = [
            .backgroundColor: LL.accentNS.withAlphaComponent(0.20)
        ]
        isContinuousSpellCheckingEnabled = style.mode == .revise
        isGrammarCheckingEnabled = style.mode == .revise
        isAutomaticQuoteSubstitutionEnabled = style.smartSubstitutions
        isAutomaticDashSubstitutionEnabled = style.smartSubstitutions
        isAutomaticTextReplacementEnabled = style.smartSubstitutions
        isAutomaticSpellingCorrectionEnabled = false
        needsDisplay = true
    }

    // MARK: Typewriter scrolling

    func scrollCaretToAnchor(animated: Bool) {
        guard style.typewriter,
              let scroll = enclosingScrollView,
              let lm = layoutManager, let tc = textContainer else { return }
        let sel = selectedRange()
        guard sel.length == 0 else { return }

        let glyph = lm.glyphRange(forCharacterRange: NSRange(location: sel.location, length: 0),
                                  actualCharacterRange: nil)
        var caret = lm.boundingRect(forGlyphRange: glyph, in: tc)
        if caret.height == 0 { caret.size.height = style.fontSize * style.activeLineHeight }
        caret.origin.y += textContainerInset.height

        let clip = scroll.contentView
        let target = caret.midY - clip.bounds.height * style.typewriterAnchor
        let docHeight = scroll.documentView?.frame.height ?? 0
        let maxY = max(0, docHeight + scroll.contentInsets.bottom - clip.bounds.height)
        let y = min(max(0, target), maxY)
        guard abs(clip.bounds.origin.y - y) > 0.5 else { return }
        clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: y))
        scroll.reflectScrolledClipView(clip)
    }

    // MARK: Focus dimming

    /// Focus dimming, comment tints, and the read-aloud highlight, all as
    /// temporary attributes so the text storage stays exactly what you typed
    /// and none of this reaches the undo stack or the file on disk.
    func refreshOverlays() {
        guard let lm = layoutManager, let storage = textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
        lm.removeTemporaryAttribute(.underlineStyle, forCharacterRange: full)
        lm.removeTemporaryAttribute(.underlineColor, forCharacterRange: full)
        guard storage.length > 0 else { return }
        let ink = LL.pageInk(style.theme)

        if style.focus != .off {
            lm.addTemporaryAttribute(.foregroundColor,
                                     value: ink.withAlphaComponent(0.32),
                                     forCharacterRange: full)
            let live = focusRange()
            if live.length > 0 {
                lm.addTemporaryAttribute(.foregroundColor, value: ink, forCharacterRange: live)
            }
        }

        for r in annotationRanges where NSMaxRange(r) <= storage.length && r.length > 0 {
            lm.addTemporaryAttribute(.underlineStyle,
                                     value: NSUnderlineStyle.thick.rawValue, forCharacterRange: r)
            lm.addTemporaryAttribute(.underlineColor,
                                     value: LL.accentNS.withAlphaComponent(0.42),
                                     forCharacterRange: r)
        }

        if let sp = spokenRange, NSMaxRange(sp) <= storage.length, sp.length > 0 {
            lm.addTemporaryAttribute(.backgroundColor,
                                     value: LL.accentNS.withAlphaComponent(0.22),
                                     forCharacterRange: sp)
            lm.addTemporaryAttribute(.foregroundColor, value: ink, forCharacterRange: sp)
        }
    }

    /// Kept as the old name so callers reading like prose still work.
    func applyFocusDimming() { refreshOverlays() }

    private func focusRange() -> NSRange {
        guard let storage = textStorage else { return NSRange(location: 0, length: 0) }
        let ns = storage.string as NSString
        let caret = min(selectedRange().location, max(0, ns.length))
        let para = ns.paragraphRange(for: NSRange(location: caret, length: 0))
        guard style.focus == .sentence else { return para }

        // Walk back and forward to sentence terminators inside the paragraph.
        let terminators = CharacterSet(charactersIn: ".!?\u{2026}")
        var start = para.location
        var i = caret - 1
        while i >= para.location {
            let ch = ns.character(at: i)
            if let scalar = Unicode.Scalar(ch), terminators.contains(scalar) {
                start = i + 1
                break
            }
            i -= 1
        }
        var end = para.location + para.length
        var j = caret
        while j < para.location + para.length {
            let ch = ns.character(at: j)
            if let scalar = Unicode.Scalar(ch), terminators.contains(scalar) {
                end = j + 1
                break
            }
            j += 1
        }
        // Trim the leading space a sentence inherits from its predecessor.
        while start < end, ns.character(at: start) == 32 { start += 1 }
        return NSRange(location: start, length: max(0, end - start))
    }

    // MARK: Smart substitutions the system doesn't cover

    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard style.smartSubstitutions,
              let s = string as? String, s == ".",
              let storage = textStorage else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        let loc = replacementRange.location == NSNotFound ? selectedRange().location
                                                          : replacementRange.location
        let ns = storage.string as NSString
        if loc >= 2, ns.substring(with: NSRange(location: loc - 2, length: 2)) == ".." {
            let r = NSRange(location: loc - 2, length: 2)
            if shouldChangeText(in: r, replacementString: "\u{2026}") {
                storage.replaceCharacters(in: r, with: "\u{2026}")
                didChangeText()
                setSelectedRange(NSRange(location: r.location + 1, length: 0))
            }
            return
        }
        super.insertText(string, replacementRange: replacementRange)
    }

    // MARK: Emphasis

    func toggleTrait(_ trait: NSFontDescriptor.SymbolicTraits) {
        guard let storage = textStorage else { return }
        let sel = selectedRange()
        guard sel.length > 0 else { return }
        guard shouldChangeText(in: sel, replacementString: nil) else { return }

        // If any of the selection lacks the trait, add it everywhere;
        // otherwise strip it. Matches how every other editor behaves.
        var allHave = true
        storage.enumerateAttribute(.font, in: sel, options: []) { v, _, stop in
            if let f = v as? NSFont, !f.fontDescriptor.symbolicTraits.contains(trait) {
                allHave = false; stop.pointee = true
            }
        }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: sel, options: []) { v, sub, _ in
            guard let f = v as? NSFont else { return }
            var t = f.fontDescriptor.symbolicTraits
            if allHave { t.remove(trait) } else { t.insert(trait) }
            if let nf = NSFont(descriptor: f.fontDescriptor.withSymbolicTraits(t), size: f.pointSize) {
                storage.addAttribute(.font, value: nf, range: sub)
            }
        }
        storage.endEditing()
        didChangeText()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), !event.modifierFlags.contains(.option) {
            switch event.charactersIgnoringModifiers {
            case "b": toggleTrait(.bold); return true
            case "i": toggleTrait(.italic); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
