//  TermsGate.swift
//  Shown once, before anything else, and again whenever the terms change.
//
//  The agreement is real: the button stays disabled until the document has
//  actually been scrolled to the end. A checkbox you can tick without reading
//  is theatre, and this app's whole promise is that it doesn't hold your work
//  hostage — the least it can do is not pretend about the paperwork.

import SwiftUI
import AppKit

enum Terms {
    /// Bump this when TERMS.md changes materially; everyone re-accepts.
    static let version = "1.0"
    static let acceptedKey = "pilcrow.termsAcceptedVersion"

    static var isAccepted: Bool {
        UserDefaults.standard.string(forKey: acceptedKey) == version
    }
    static func accept() {
        UserDefaults.standard.set(version, forKey: acceptedKey)
        UserDefaults.standard.set(Date(), forKey: "pilcrow.termsAcceptedOn")
    }
    static var acceptedOn: Date? {
        UserDefaults.standard.object(forKey: "pilcrow.termsAcceptedOn") as? Date
    }

    /// Reads a bundled document. Falls back to a short notice rather than an
    /// empty window if the resource is somehow missing.
    static func document(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "md")
                ?? Bundle.main.url(forResource: name, withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return """
            # Terms of Use

            This build is missing its bundled terms document.

            Pilcrow is free and open source, provided **as is**, with no warranty
            and no liability. You use it at your own risk and are responsible for
            your own backups. Full terms: https://github.com/michaellomuscio/pilcrow
            """
        }
        return text
    }
}

// MARK: - Gate

struct AcceptanceGate<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var accepted = Terms.isAccepted

    var body: some View {
        Group {
            if accepted {
                content
            } else {
                TermsGate { Terms.accept(); accepted = true }
            }
        }
    }
}

struct TermsGate: View {
    let onAccept: () -> Void
    @State private var readToEnd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rule()
            MarkdownDocument(text: Terms.document("TERMS"), didReachEnd: $readToEnd)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rule()
            footer
        }
        .background(LL.ground)
        .frame(minWidth: 700, minHeight: 620)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PILCROW")
                    .font(PilcrowFonts.displayF(38)).tracking(1.4)
                    .foregroundStyle(LL.ink)
                LabsBadge()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Eyebrow(text: "Before you start")
                Text("Version \(Terms.version)")
                    .font(PilcrowFonts.monoF(10.5)).foregroundStyle(LL.ink3)
            }
        }
        .padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 16)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 12) {
                docLink("Licence", "LICENSE")
                docLink("Trademarks", "TRADEMARKS")
                docLink("Notices", "NOTICE")
            }
            Spacer()
            if !readToEnd {
                Text("Scroll to the end to continue")
                    .font(PilcrowFonts.bodyF(11.5)).foregroundStyle(LL.ink3)
            }
            Button("Quit") { NSApp.terminate(nil) }.llButton(.ghost)
            Button("I agree") { onAccept() }
                .llButton(.accent)
                .disabled(!readToEnd)
        }
        .padding(.horizontal, 26).padding(.vertical, 14)
    }

    private func docLink(_ label: String, _ resource: String) -> some View {
        Button(label) { DocumentWindow.show(title: label, markdown: Terms.document(resource)) }
            .buttonStyle(.plain)
            .font(PilcrowFonts.bodyF(11.5))
            .foregroundStyle(LL.accentInk)
            .underline()
    }
}

// MARK: - Brand mark

/// Wherever Lomuscio Labs appears, it goes somewhere.
struct LabsBadge: View {
    var tint: Color = LL.ink3
    @State private var hovering = false

    var body: some View {
        Link(destination: URL(string: "https://michaellomuscio.com")!) {
            HStack(spacing: 5) {
                Rectangle().fill(LL.accent).frame(width: 14, height: 2)
                Text("LOMUSCIO LABS")
                    .font(PilcrowFonts.monoF(9.5, .medium))
                    .tracking(1.3)
                    .foregroundStyle(hovering ? LL.accentInk : tint)
                    .underline(hovering)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("michaellomuscio.com")
    }
}

// MARK: - Markdown rendering
//
// Enough of the syntax to render the project's own documents faithfully:
// headings, paragraphs, lists, rules, links, emphasis, and inline code.

struct MarkdownDocument: View {
    let text: String
    var didReachEnd: Binding<Bool>? = nil

    /// Reports where the end-of-document marker sits inside the fixed
    /// container. `onAppear` is no good here: a ScrollView builds all of its
    /// children up front, so the marker "appears" instantly and the gate opens
    /// before anyone has read a word.
    private struct EndMarkerY: PreferenceKey {
        static var defaultValue: CGFloat = .greatestFiniteMagnitude
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = min(value, nextValue())
        }
    }

    var body: some View {
        GeometryReader { outer in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        block.view
                    }
                    Color.clear
                        .frame(height: 1)
                        .background(
                            GeometryReader { marker in
                                Color.clear.preference(
                                    key: EndMarkerY.self,
                                    value: marker.frame(in: .named("doc")).minY)
                            })
                }
                .padding(.horizontal, 28).padding(.vertical, 20)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .onPreferenceChange(EndMarkerY.self) { y in
                // Scrolled far enough that the last line is on screen.
                if y <= outer.size.height + 4 {
                    didReachEnd?.wrappedValue = true
                }
            }
        }
        .coordinateSpace(name: "doc")
        .frame(maxWidth: .infinity)
    }

    private enum Block {
        case h1(String), h2(String), h3(String)
        case para(String), bullet(String), ordered(Int, String), rule

        @ViewBuilder var view: some View {
            switch self {
            case .h1(let s):
                Text(s).font(PilcrowFonts.headingF(24, .heavy))
                    .foregroundStyle(LL.ink)
                    .padding(.top, 18).padding(.bottom, 8)
            case .h2(let s):
                Text(s).font(PilcrowFonts.headingF(17, .bold))
                    .foregroundStyle(LL.ink)
                    .padding(.top, 20).padding(.bottom, 6)
            case .h3(let s):
                Text(s).font(PilcrowFonts.headingF(14, .semibold))
                    .foregroundStyle(LL.ink)
                    .padding(.top, 14).padding(.bottom, 4)
            case .para(let s):
                Text(MarkdownDocument.inline(s))
                    .font(PilcrowFonts.bodyF(13))
                    .foregroundStyle(LL.ink2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
            case .bullet(let s):
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\u{00B7}").font(PilcrowFonts.bodyF(13)).foregroundStyle(LL.accent)
                    Text(MarkdownDocument.inline(s))
                        .font(PilcrowFonts.bodyF(13)).foregroundStyle(LL.ink2)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 6).padding(.bottom, 6)
            case .ordered(let n, let s):
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(n).").font(PilcrowFonts.monoF(11)).foregroundStyle(LL.accent)
                        .frame(width: 18, alignment: .trailing)
                    Text(MarkdownDocument.inline(s))
                        .font(PilcrowFonts.bodyF(13)).foregroundStyle(LL.ink2)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 6)
            case .rule:
                Rectangle().fill(LL.rule).frame(height: 1).padding(.vertical, 14)
            }
        }
    }

    private var blocks: [Block] {
        var out: [Block] = []
        var paragraph: [String] = []

        func flush() {
            let joined = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !joined.isEmpty { out.append(.para(joined)) }
            paragraph.removeAll()
        }

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("### ") { flush(); out.append(.h3(String(line.dropFirst(4)))) }
            else if line.hasPrefix("## ") { flush(); out.append(.h2(String(line.dropFirst(3)))) }
            else if line.hasPrefix("# ") { flush(); out.append(.h1(String(line.dropFirst(2)))) }
            else if line == "---" || line == "***" { flush(); out.append(.rule) }
            else if line.hasPrefix("- ") { flush(); out.append(.bullet(String(line.dropFirst(2)))) }
            else if let m = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                flush()
                let n = Int(line[line.startIndex..<m.upperBound]
                    .trimmingCharacters(in: CharacterSet(charactersIn: ". "))) ?? 1
                out.append(.ordered(n, String(line[m.upperBound...])))
            }
            else { paragraph.append(line) }
        }
        flush()
        return out
    }

    /// Inline emphasis, code, and links, via the system Markdown parser.
    static func inline(_ s: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        guard var a = try? AttributedString(markdown: s, options: options) else {
            return AttributedString(s)
        }
        for run in a.runs where run.link != nil {
            a[run.range].foregroundColor = LL.accentInk
            a[run.range].underlineStyle = .single
        }
        return a
    }
}

// MARK: - Document window

@MainActor
enum DocumentWindow {
    private static var windows: [String: NSWindow] = [:]

    static func show(title: String, markdown: String) {
        if let w = windows[title] { w.makeKeyAndOrderFront(nil); return }
        let host = NSHostingController(
            rootView: MarkdownDocument(text: markdown)
                .background(LL.ground)
                .frame(minWidth: 620, minHeight: 520))
        let w = NSWindow(contentViewController: host)
        w.title = title
        w.styleMask = [.titled, .closable, .resizable]
        w.setContentSize(NSSize(width: 720, height: 620))
        w.center()
        w.isReleasedWhenClosed = false
        windows[title] = w
        w.makeKeyAndOrderFront(nil)
    }
}
