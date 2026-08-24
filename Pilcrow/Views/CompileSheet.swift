//  CompileSheet.swift
//  Getting the book out, and the app's preferences.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CompileSheet: View {
    @Bindable var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    @State private var options = CompileOptions()
    @State private var pdf = PDFBook.Options()
    @State private var error: String?
    @State private var working = false

    private var warnings: [String] {
        var w = Compiler.warnings(store: store)
        let g = Citations.gather(store: store, options: options)
        if !g.unresolved.isEmpty {
            w.append("\(g.unresolved.count) citation key\(g.unresolved.count == 1 ? "" : "s") in the text match no source: "
                     + g.unresolved.sorted().prefix(4).joined(separator: ", "))
        }
        return w
    }

    private var citationCount: Int {
        store.orderedDocuments.reduce(0) {
            $0 + CitationScanner.scan(store.body($1.id)).count
        }
    }
    private var included: Int {
        store.orderedDocuments.filter { $0.includeInCompile && $0.status != .cut }.count
    }
    private var words: Int {
        store.orderedDocuments
            .filter { $0.includeInCompile && $0.status != .cut }
            .reduce(0) { $0 + $1.wordCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("COMPILE").font(PilcrowFonts.displayF(28)).tracking(1.1).foregroundStyle(LL.ink)
            Text("\(included) documents \u{00B7} \(words.grouped) words")
                .font(PilcrowFonts.bodyF(12)).foregroundStyle(LL.ink2)
                .padding(.top, 3).padding(.bottom, 16)

            Eyebrow(text: "Format")
            VStack(spacing: 6) {
                ForEach(CompileFormat.allCases) { f in
                    Button { options.format = f } label: {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: options.format == f ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(options.format == f ? LL.accent : LL.ink3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.label).font(PilcrowFonts.headingF(12.5, .semibold))
                                    .foregroundStyle(LL.ink)
                                Text(f.note).font(PilcrowFonts.bodyF(10.5))
                                    .foregroundStyle(LL.ink3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .fill(options.format == f ? LL.accentSoft : .clear))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            .padding(.top, 5).padding(.bottom, 14)

            if options.format == .pdfBook {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow(text: "Trim size")
                            Picker("", selection: $pdf.page) {
                                ForEach(PageSize.allCases) { Text($0.label).tag($0) }
                            }.labelsHidden().controlSize(.small)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow(text: "Face")
                            Picker("", selection: $pdf.faceID) {
                                ForEach(PilcrowFonts.shelf.filter { !$0.isDrafting }) {
                                    Text($0.display).tag($0.id)
                                }
                            }.labelsHidden().controlSize(.small)
                        }
                    }
                    HStack(spacing: 14) {
                        Stepper("Body \(String(format: "%.0f", pdf.bodySize))pt",
                                value: $pdf.bodySize, in: 8...16, step: 0.5)
                            .font(PilcrowFonts.bodyF(11.5))
                        Toggle("Running heads", isOn: $pdf.runningHeads)
                            .toggleStyle(.checkbox).controlSize(.small)
                        Toggle("Folios", isOn: $pdf.folios)
                            .toggleStyle(.checkbox).controlSize(.small)
                    }
                    .font(PilcrowFonts.bodyF(11.5))
                }
                .padding(.top, 4).padding(.bottom, 12)
            }

            if citationCount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Citations")
                    HStack(spacing: 8) {
                        Picker("", selection: Binding(
                            get: { store.manifest.citationStyle },
                            set: { store.manifest.citationStyle = $0; store.touchManifest() })) {
                                ForEach(CitationStyle.allCases) { Text($0.label).tag($0) }
                            }.labelsHidden().controlSize(.small)
                        Pill(text: "\(citationCount) in text", tint: LL.accent)
                    }
                }
                .padding(.bottom, 12)
            }

            Eyebrow(text: "Include")
            VStack(alignment: .leading, spacing: 3) {
                Toggle("Title page", isOn: $options.includeTitlePage)
                Toggle("Start each chapter on a new page", isOn: $options.chapterBreaks)
                Toggle("Synopses", isOn: $options.includeSynopses)
                Toggle("Skip anything excluded or cut", isOn: $options.onlyIncluded)
            }
            .toggleStyle(.checkbox).controlSize(.small)
            .font(PilcrowFonts.bodyF(11.5))
            .padding(.top, 5)

            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Before this leaves the building", tint: LL.warn)
                    ForEach(warnings, id: \.self) { w in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9)).foregroundStyle(LL.warn)
                            Text(w).font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 5).fill(LL.warn.opacity(0.10)))
                .padding(.top, 14)
            }

            if let error {
                Text(error).font(PilcrowFonts.bodyF(11.5)).foregroundStyle(LL.crit)
                    .padding(.top, 10).fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 14)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.llButton(.ghost)
                Button(working ? "Working\u{2026}" : "Save\u{2026}") { save() }
                    .llButton(.accent).disabled(working)
            }
        }
        .padding(24)
        .frame(width: 540, height: 700)
        .background(LL.ground)
    }

    private func save() {
        working = true
        defer { working = false }
        do {
            let data = try Compiler.compile(store: store, options: options, pdf: pdf)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "\(Slug.make(store.manifest.title)).\(options.format.ext)"
            panel.directoryURL = store.folder
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            dismiss()
        } catch {
            self.error = "Couldn\u{2019}t compile: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preferences

struct PreferencesView: View {
    @AppStorage("pilcrow.defaultFace") private var defaultFace = "literata"
    @AppStorage("pilcrow.defaultDraftFace") private var defaultDraftFace = "quattro"
    @AppStorage("pilcrow.defaultSize") private var defaultSize = 19.0
    @AppStorage("pilcrow.defaultMeasure") private var defaultMeasure = 66
    @AppStorage("pilcrow.autosaveSeconds") private var autosave = 1.2
    @AppStorage("pilcrow.author") private var author = NSFullUserName()

    var body: some View {
        TabView {
            page.tabItem { Label("The Page", systemImage: "doc.text") }
            about.tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 400)
    }

    private var page: some View {
        Form {
            Picker("Reading face", selection: $defaultFace) {
                ForEach(PilcrowFonts.shelf.filter { !$0.isDrafting }) { Text($0.display).tag($0.id) }
            }
            Picker("Drafting face", selection: $defaultDraftFace) {
                ForEach(PilcrowFonts.shelf) { Text($0.display).tag($0.id) }
            }
            Slider(value: $defaultSize, in: 13...30, step: 1) {
                Text("Size \u{2014} \(Int(defaultSize))pt")
            }
            Stepper("Measure \u{2014} \(defaultMeasure) characters",
                    value: $defaultMeasure, in: 55...75)
            TextField("Author", text: $author)
            Text("These apply to new projects. Each book keeps its own page settings once it exists.")
                .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3)
        }
        .formStyle(.grouped)
        .padding()
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PILCROW").font(PilcrowFonts.displayF(40)).tracking(1.4).foregroundStyle(LL.ink)
            Text("A gathering of folded sheets \u{2014} the unit a manuscript is assembled from.")
                .font(PilcrowFonts.bodyF(12.5)).foregroundStyle(LL.ink2)
            Rule()
            Text("Your writing lives as plain Markdown files in a folder you chose. Nothing is stored anywhere else. Open the folder in Finder, put it in git, back it up however you like \u{2014} the book is never trapped.")
                .font(PilcrowFonts.bodyF(12)).foregroundStyle(LL.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Rule()
            Text("Set in Literata, Newsreader, Source Serif 4, EB Garamond, Charter and iA Writer Quattro. Chrome in Bebas Neue, Urbanist, Figtree and IBM Plex Mono.")
                .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Terms of Use") {
                    DocumentWindow.show(title: "Terms of Use", markdown: Terms.document("TERMS"))
                }
                Button("Licence") {
                    DocumentWindow.show(title: "Licence", markdown: Terms.document("LICENSE"))
                }
                Button("Trademarks") {
                    DocumentWindow.show(title: "Trademarks",
                                        markdown: Terms.document("TRADEMARKS"))
                }
            }
            .buttonStyle(.plain)
            .font(PilcrowFonts.bodyF(11))
            .foregroundStyle(LL.accentInk)
            if let on = Terms.acceptedOn {
                Text("Terms v\(Terms.version) accepted \(on.formatted(date: .abbreviated, time: .omitted))")
                    .font(PilcrowFonts.monoF(9.5)).foregroundStyle(LL.ink3)
            }
            Spacer()
            LabsBadge()
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
