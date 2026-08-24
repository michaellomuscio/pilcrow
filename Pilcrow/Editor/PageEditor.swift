//  PageEditor.swift
//  SwiftUI wrapper around PilcrowTextView. Owns the Markdown <-> attributed
//  round trip and keeps the two from fighting each other.

import SwiftUI
import AppKit

struct EditorStats {
    var words: Int = 0
    var characters: Int = 0
    var paragraphs: Int = 0
}

struct PageEditor: NSViewRepresentable {
    let nodeID: UUID
    let markdown: String
    let style: PageStyle
    /// Comment anchors for this document, already resolved to ranges.
    var annotationRanges: [NSRange] = []
    /// The word being spoken aloud, if the reader is running.
    var spokenRange: NSRange? = nil
    var onChange: (String) -> Void
    var onStats: (EditorStats) -> Void
    /// Called with the selected text and its offset when you ask for a comment.
    var onAddComment: ((String, Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)

        let tv = PilcrowTextView(frame: .zero, textContainer: container)
        tv.isEditable = true
        tv.isRichText = true
        tv.allowsUndo = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                            height: CGFloat.greatestFiniteMagnitude)
        tv.textContainerInset = NSSize(width: 40, height: 60)
        tv.delegate = context.coordinator
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.style = style
        tv.onCaretMove = { [weak tv] in
            guard let tv else { return }
            context.coordinator.reportStats(tv)
        }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = LL.paper(style.theme)
        scroll.documentView = tv
        scroll.contentView.postsFrameChangedNotifications = true

        tv.annotationRanges = annotationRanges
        tv.spokenRange = spokenRange
        context.coordinator.textView = tv
        context.coordinator.scrollView = scroll
        context.coordinator.observeComments()
        context.coordinator.observeResize(scroll)
        context.coordinator.load(markdown: markdown, style: style, nodeID: nodeID)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        context.coordinator.parent = self

        let styleChanged = context.coordinator.appliedStyle != style
        let nodeChanged  = context.coordinator.appliedNodeID != nodeID
        // Only reload from the model when the change came from outside the
        // editor — otherwise every keystroke would reset the caret.
        let externalEdit = markdown != context.coordinator.lastEmitted

        if nodeChanged || styleChanged || externalEdit {
            tv.style = style
            scroll.backgroundColor = LL.paper(style.theme)
            context.coordinator.load(markdown: markdown, style: style,
                                     nodeID: nodeID, keepSelection: !nodeChanged)
        }
        if tv.annotationRanges != annotationRanges { tv.annotationRanges = annotationRanges }
        if tv.spokenRange != spokenRange { tv.spokenRange = spokenRange }
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PageEditor
        weak var textView: PilcrowTextView?
        weak var scrollView: NSScrollView?

        var appliedNodeID: UUID?
        var appliedStyle: PageStyle?
        var lastEmitted: String = ""
        private var loading = false
        private var resizeToken: NSObjectProtocol?
        private var commentToken: NSObjectProtocol?
        private var debounce: Timer?

        init(_ parent: PageEditor) { self.parent = parent }

        func observeResize(_ scroll: NSScrollView) {
            resizeToken = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: scroll.contentView, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.textView?.applyStyleChrome()
                    }
                }
        }

        func observeComments() {
            guard commentToken == nil else { return }
            commentToken = NotificationCenter.default.addObserver(
                forName: PilcrowCommand.name, object: nil, queue: .main) { [weak self] note in
                    MainActor.assumeIsolated {
                        guard let self,
                              let raw = note.object as? String,
                              raw == PilcrowCommand.addComment.rawValue,
                              let tv = self.textView,
                              tv.window?.isKeyWindow == true else { return }
                        let sel = tv.selectedRange()
                        guard sel.length > 0, let storage = tv.textStorage else { return }
                        let quoted = (storage.string as NSString).substring(with: sel)
                        self.parent.onAddComment?(quoted, sel.location)
                    }
                }
        }

        func stopObserving() {
            if let t = resizeToken { NotificationCenter.default.removeObserver(t) }
            if let t = commentToken { NotificationCenter.default.removeObserver(t) }
            debounce?.invalidate()
        }

        func load(markdown: String, style: PageStyle, nodeID: UUID, keepSelection: Bool = false) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            loading = true
            let sel = tv.selectedRange()
            let attributed = MarkdownCodec.attributed(from: markdown, style: style)
            storage.setAttributedString(attributed)
            tv.typingAttributes = [
                .font: style.bodyFont(),
                .foregroundColor: LL.pageInk(style.theme),
                .paragraphStyle: style.paragraphStyle()
            ]
            tv.applyStyleChrome()
            if keepSelection, sel.location <= storage.length {
                tv.setSelectedRange(NSRange(location: min(sel.location, storage.length), length: 0))
            } else {
                tv.setSelectedRange(NSRange(location: 0, length: 0))
                tv.scroll(NSPoint(x: 0, y: 0))
            }
            tv.applyFocusDimming()
            appliedNodeID = nodeID
            appliedStyle = style
            lastEmitted = markdown
            loading = false
            reportStats(tv)
        }

        func textDidChange(_ notification: Notification) {
            guard !loading, let tv = textView, let storage = tv.textStorage else { return }
            reportStats(tv)
            // Serialising on every keystroke is wasted work; a short debounce
            // keeps typing at full speed and still saves within the second.
            debounce?.invalidate()
            debounce = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    let md = MarkdownCodec.markdown(from: storage)
                    guard md != self.lastEmitted else { return }
                    self.lastEmitted = md
                    self.parent.onChange(md)
                }
            }
        }

        func reportStats(_ tv: PilcrowTextView) {
            let s = tv.string
            parent.onStats(EditorStats(
                words: MarkdownCodec.wordCount(s),
                characters: s.count,
                paragraphs: s.isEmpty ? 0 : s.components(separatedBy: "\n")
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count))
        }

        /// Flushes any pending edit immediately — used before switching
        /// documents, closing, or compiling.
        func flush() {
            debounce?.invalidate()
            guard let storage = textView?.textStorage else { return }
            let md = MarkdownCodec.markdown(from: storage)
            guard md != lastEmitted else { return }
            lastEmitted = md
            parent.onChange(md)
        }
    }
}

// MARK: - Block commands
//
// Headings and scene breaks are commands rather than markdown-as-you-type.
// Typing "## " and watching it transform is a party trick that fights you
// the moment you actually want two hash marks.

extension PilcrowTextView {

    func setHeading(_ level: Int) {
        guard let storage = textStorage else { return }
        let ns = storage.string as NSString
        let para = ns.paragraphRange(for: selectedRange())
        guard shouldChangeText(in: para, replacementString: nil) else { return }

        let content = NSRange(location: para.location,
                              length: max(0, para.length - trailingNewline(ns, para)))
        storage.beginEditing()
        if level == 0 {
            storage.removeAttribute(.pilcrowHeading, range: content)
            storage.addAttributes([
                .font: style.bodyFont(),
                .paragraphStyle: style.paragraphStyle()
            ], range: content)
        } else {
            let p = NSMutableParagraphStyle()
            p.lineHeightMultiple = 1.25
            p.paragraphSpacingBefore = style.fontSize * (level == 1 ? 1.6 : 1.2)
            p.paragraphSpacing = style.fontSize * 0.5
            p.alignment = level == 1 ? .center : .left
            let scale: CGFloat = level == 1 ? 1.7 : (level == 2 ? 1.32 : 1.12)
            storage.addAttributes([
                .font: style.activeFace.nsFont(size: style.fontSize * scale,
                                               weight: level == 1 ? .regular : .semibold),
                .paragraphStyle: p,
                .pilcrowHeading: level
            ], range: content)
        }
        storage.endEditing()
        didChangeText()
    }

    func insertSceneBreak() {
        guard let storage = textStorage else { return }
        let sel = selectedRange()
        let glyph = MarkdownCodec.sceneBreakGlyph
        let insert = "\n" + glyph + "\n"
        guard shouldChangeText(in: sel, replacementString: insert) else { return }

        let p = NSMutableParagraphStyle()
        p.alignment = .center
        p.lineHeightMultiple = style.activeLineHeight
        p.paragraphSpacingBefore = style.fontSize * 0.9
        p.paragraphSpacing = style.fontSize * 0.9

        let attributed = NSMutableAttributedString(string: insert, attributes: [
            .font: style.bodyFont(),
            .foregroundColor: LL.pageInk(style.theme),
            .paragraphStyle: style.paragraphStyle()
        ])
        let glyphRange = NSRange(location: 1, length: (glyph as NSString).length)
        attributed.addAttributes([
            .paragraphStyle: p,
            .kern: style.fontSize * 0.35,
            .foregroundColor: LL.pageInk(style.theme).withAlphaComponent(0.5),
            .pilcrowSceneBreak: true
        ], range: glyphRange)

        storage.replaceCharacters(in: sel, with: attributed)
        didChangeText()
        setSelectedRange(NSRange(location: sel.location + attributed.length, length: 0))
    }

    private func trailingNewline(_ ns: NSString, _ r: NSRange) -> Int {
        guard r.length > 0 else { return 0 }
        let c = ns.character(at: r.location + r.length - 1)
        return (c == 10 || c == 13) ? 1 : 0
    }
}
