//  ProjectWindow.swift
//  Three zones: the binder, the page, the studio.
//  The page is the only one that matters; the other two get out of its way.

import SwiftUI
import AppKit

enum MainView: String, CaseIterable, Identifiable {
    case page, corkboard, outliner
    case spine, structure, timeline
    case cast, notes, evidence, continuity
    case diagnostics, progress, appointments
    var id: String { rawValue }

    /// Thin dividers in the tab bar, so thirteen panes read as four jobs.
    var startsGroup: Bool {
        self == .spine || self == .cast || self == .diagnostics
    }

    var symbol: String {
        switch self {
        case .page:      return "doc.text"
        case .corkboard: return "rectangle.grid.2x2"
        case .outliner:  return "list.bullet.rectangle"
        case .spine:     return "chart.bar.doc.horizontal"
        case .cast:      return "person.2"
        case .notes:     return "lightbulb"
        case .evidence:  return "checkmark.seal"
        case .progress:  return "chart.xyaxis.line"
        case .structure: return "ruler"
        case .timeline:  return "calendar.day.timeline.left"
        case .continuity: return "checkmark.rectangle.stack"
        case .diagnostics: return "waveform.path.ecg"
        case .appointments: return "calendar.badge.clock"
        }
    }

    func label(_ l: LabelPack) -> String {
        switch self {
        case .page:      return "Page"
        case .corkboard: return "Corkboard"
        case .outliner:  return "Outliner"
        case .spine:     return l.spineBoard
        case .cast:      return l.cast
        case .notes:     return l.notes
        case .evidence:  return l.ledger
        case .progress:  return "Progress"
        case .structure: return "Structure"
        case .timeline:  return "Timeline"
        case .continuity: return l.ledger == "Evidence" ? "Consistency" : "Continuity"
        case .diagnostics: return "Diagnostics"
        case .appointments: return "Appointments"
        }
    }

    /// Nonfiction hides the fiction-only ledger; fiction hides the evidence one.
    func applies(to kind: ProjectKind) -> Bool {
        switch self {
        case .evidence: return kind != .fiction
        default: return true
        }
    }
}

// MARK: - Host

struct ProjectHost: View {
    let url: URL?
    @Environment(AppState.self) private var app
    @State private var store: ProjectStore?
    @State private var failure: String?

    var body: some View {
        Group {
            if let store {
                ProjectWindow(store: store)
            } else if let failure {
                EmptyState(symbol: "exclamationmark.triangle",
                           title: "Couldn\u{2019}t open this project",
                           message: failure)
                .background(LL.ground)
            } else {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LL.ground)
            }
        }
        .task(id: url) { load() }
    }

    private func load() {
        guard let url else { failure = "No project was specified."; return }
        if let existing = app.store(for: url) { store = existing; return }
        do {
            let s = try ProjectStore.open(at: url)
            app.register(s)
            store = s
        } catch {
            failure = error.localizedDescription
        }
    }
}

// MARK: - Window

struct ProjectWindow: View {
    @Bindable var store: ProjectStore
    @State private var session = SessionEngine()
    @State private var main: MainView = .page
    @State private var showBinder = true
    @State private var showStudio = true
    @State private var stats = EditorStats()
    @State private var sprintSheet = false
    @State private var closeSheet = false
    @State private var compileSheet = false
    @State private var zen = false
    @State private var toast: String?
    @State private var hostWindow: NSWindow?
    @State private var reader = ReadAloud()

    private var labels: LabelPack { store.labels }
    private var selected: Node? { store.node(store.selection) }

    var body: some View {
        VStack(spacing: 0) {
            viewBar
            Rule()
            HStack(spacing: 0) {
                if showBinder && !zen {
                    BinderView(store: store, session: session)
                        .frame(width: 258)
                    VRule()
                }
                mainPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showStudio && !zen && main == .page {
                    VRule()
                    StudioView(store: store, session: session, stats: stats,
                               reader: reader,
                               startSprint: { sprintSheet = true },
                               closeSession: { closeSheet = true })
                        .frame(width: 306)
                }
            }
            Rule()
            statusBar
        }
        .background(LL.ground)
        .toolbar { toolbarContent }
        .navigationTitle(store.manifest.title)
        .navigationSubtitle(zen ? "" : (selected?.title ?? ""))
        .sheet(isPresented: $sprintSheet) {
            SprintSheet(labels: labels) { kind, value, note in
                session.start(goalKind: kind, goalValue: value, note: note,
                              place: "", currentWords: store.totalWords)
            }
        }
        .sheet(isPresented: $closeSheet) {
            SessionCloseSheet(session: session, suggestion: selected?.title ?? "") { record in
                if let record {
                    store.log.sessions.append(record)
                    store.touchManifest()
                    if let id = store.selection { store.snapshot(id, label: "session") }
                    flash("Session logged \u{00B7} \(record.wordsAdded.grouped) added, \(record.wordsCut.grouped) cut")
                }
            }
        }
        .sheet(isPresented: $compileSheet) {
            CompileSheet(store: store)
        }
        .overlay(alignment: .bottom) { toastView }
        .background(WindowAccessor { hostWindow = $0 })
        .onPilcrowCommand(handle)
        .onDisappear { try? store.saveNow() }
    }

    // MARK: View bar

    private var viewBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(MainView.allCases) { v in
                        if v.applies(to: store.manifest.kind) {
                            if v.startsGroup {
                                Rectangle().fill(LL.rule)
                                    .frame(width: 1, height: 18).padding(.horizontal, 6)
                            }
                            viewTab(v)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            if zen {
                Button("Leave Zen") { zen = false }
                    .llButton(.ghost, compact: true).padding(.trailing, 10)
            }
        }
        .padding(.vertical, 6)
        .background(LL.ground)
    }

    private func viewTab(_ v: MainView) -> some View {
        Button { main = v } label: {
            HStack(spacing: 5) {
                Image(systemName: v.symbol).font(.system(size: 10.5, weight: .medium))
                Text(v.label(labels)).font(PilcrowFonts.headingF(11.5, .semibold))
            }
            .foregroundStyle(main == v ? LL.ink : LL.ink3)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 5)
                .fill(main == v ? LL.surface : .clear))
            .overlay(alignment: .bottom) {
                Rectangle().fill(main == v ? LL.accent : .clear).frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Main pane

    @ViewBuilder
    private var mainPane: some View {
        switch main {
        case .page:
            if let node = selected, !node.isFolder || !store.body(node.id).isEmpty || node.isFolder {
                pageView(node)
            } else {
                EmptyState(symbol: "doc.text",
                           title: "Nothing selected",
                           message: "Pick a \(labels.leaf.lowercased()) in the binder, or make a new one with \u{2318}N.")
            }
        case .corkboard: CorkboardView(store: store, open: { store.selection = $0; main = .page })
        case .outliner:  OutlinerView(store: store, open: { store.selection = $0; main = .page })
        case .spine:     SpineBoardView(store: store)
        case .cast:      CastView(store: store)
        case .notes:     NotesView(store: store)
        case .evidence:  EvidenceView(store: store)
        case .progress:  ProgressPane(store: store)
        case .structure: StructureView(store: store)
        case .timeline:  TimelineView(store: store)
        case .continuity: ContinuityView(store: store)
        case .diagnostics: DiagnosticsView(store: store)
        case .appointments: AppointmentsView(store: store)
        }
    }

    /// Comment anchors, re-found against the current text — offsets go stale
    /// on every keystroke, the quoted string doesn't.
    private func annotationRanges(_ node: Node) -> [NSRange] {
        let text = store.body(node.id) as NSString
        return store.manifest.annotations
            .filter { $0.nodeID == node.id && !$0.resolved }
            .compactMap { $0.range(in: text) }
    }

    private func pageView(_ node: Node) -> some View {
        ZStack(alignment: .top) {
            PageEditor(
                nodeID: node.id,
                markdown: store.body(node.id),
                style: store.manifest.pageStyle,
                annotationRanges: annotationRanges(node),
                spokenRange: reader.spokenRange,
                onChange: { md in
                    store.setBody(node.id, md)
                    session.sample(totalWords: store.totalWords, nodeID: node.id)
                },
                onStats: { stats = $0 },
                onAddComment: { quoted, loc in
                    store.manifest.annotations.append(
                        Annotation(nodeID: node.id, quoted: quoted, location: loc,
                                   author: store.manifest.author))
                    store.touchManifest()
                    showStudio = true
                    flash("Comment added")
                }
            )
            .id(node.id)

            if !session.pendingNextLine.isEmpty || nextLineFromLog != nil {
                nextLineBanner
            }
        }
    }

    private var nextLineFromLog: String? {
        let s = store.log.lastNextLine
        return s.isEmpty ? nil : s
    }

    /// Shown above the cursor when you sit back down. Backed by the
    /// resumption half of the Zeigarnik literature — the half that replicated.
    private var nextLineBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LL.accent)
            VStack(alignment: .leading, spacing: 1) {
                Eyebrow(text: "What happens next")
                Text(session.pendingNextLine.isEmpty ? (nextLineFromLog ?? "") : session.pendingNextLine)
                    .font(PilcrowFonts.bodyF(12.5))
                    .foregroundStyle(LL.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            IconButton(symbol: "xmark", help: "Dismiss") {
                session.pendingNextLine = ""
                store.log.sessions.indices.forEach { store.log.sessions[$0].nextLine = "" }
                store.touchManifest()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.accentSoft))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.accent.opacity(0.35), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: 620)
        .transition(.opacity)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { showBinder.toggle() } label: {
                Image(systemName: "sidebar.left")
            }.help("Hide or show the binder (\u{2318}\\)")
        }
        ToolbarItemGroup {
            Picker("", selection: Binding(
                get: { store.manifest.pageStyle.mode },
                set: { store.manifest.pageStyle.mode = $0; store.touchManifest() })) {
                    ForEach(WriteMode.allCases) { m in Text(m.label).tag(m) }
                }
                .pickerStyle(.segmented)
                .frame(width: 132)
                .help(store.manifest.pageStyle.mode.help)

            Button { sprintSheet = true } label: {
                Image(systemName: session.isRunning ? "timer.circle.fill" : "timer")
            }
            .help("Start a sprint (\u{21E7}\u{2318}T)")
            .disabled(session.active != nil)

            Button { compileSheet = true } label: { Image(systemName: "square.and.arrow.up") }
                .help("Compile (\u{2318}E)")

            Button { showStudio.toggle() } label: { Image(systemName: "sidebar.right") }
                .help("Hide or show the studio (\u{21E7}\u{2318}\\)")
        }
    }

    // MARK: Status bar

    private var statusBar: some View {
        HStack(spacing: 14) {
            Text(store.manifest.title)
                .font(PilcrowFonts.headingF(11, .semibold))
                .foregroundStyle(LL.ink2)
            Pill(text: store.manifest.kind.label, tint: LL.accent)

            Spacer()

            if store.manifest.pageStyle.mode == .revise || session.active != nil {
                counter("\(stats.words.grouped)", "in this \(labels.leaf.lowercased())")
                counter("\(store.totalWords.grouped)", "in the book")
            }
            if store.log.wordsToday != 0 {
                counter(signed(store.log.wordsToday), "today")
            }
            if let saved = store.lastSaved {
                Text("saved \(saved.formatted(date: .omitted, time: .standard))")
                    .font(PilcrowFonts.monoF(9.5))
                    .foregroundStyle(LL.ink3)
            }
            if let err = store.saveError {
                Pill(text: "save failed", tint: LL.crit, filled: true)
                    .help(err)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(LL.ground)
    }

    private func counter(_ value: String, _ caption: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(PilcrowFonts.monoF(11, .medium)).foregroundStyle(LL.ink)
            Text(caption).font(PilcrowFonts.bodyF(10.5)).foregroundStyle(LL.ink3)
        }
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n.grouped)" : n.grouped }

    // MARK: Toast

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(PilcrowFonts.bodyF(12))
                .foregroundStyle(LL.ground)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Capsule().fill(LL.ink))
                .padding(.bottom, 34)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func flash(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeIn(duration: 0.25)) { toast = nil }
        }
    }

    // MARK: Commands

    private func handle(_ cmd: PilcrowCommand) {
        // Menu commands broadcast to every open book, so only the frontmost
        // one acts. If nothing is key at all (app launched but not activated)
        // there is nothing to compete with, so go ahead.
        if let key = NSApp.keyWindow, let mine = hostWindow, key !== mine { return }
        var style = store.manifest.pageStyle
        switch cmd {
        case .newScene:
            let parent = selected.map { $0.isFolder ? $0.id : (store.manifest.root.parentID(of: $0.id) ?? store.manifest.root.id) }
            let id = store.addDocument(title: "Untitled \(labels.leaf)", parent: parent,
                                       after: selected?.isFolder == true ? nil : store.selection)
            store.selection = id
            main = .page
        case .newChapter:
            let id = store.addFolder(title: "\(labels.container) \(store.manifest.root.children.count + 1)",
                                     parent: nil)
            store.selection = id
        case .deleteNode:
            if let id = store.selection { store.delete(id) }
        case .toggleMode:
            style.mode = style.mode == .draft ? .revise : .draft
        case .focusOff:        style.focus = .off
        case .focusParagraph:  style.focus = .paragraph
        case .focusSentence:   style.focus = .sentence
        case .toggleTypewriter: style.typewriter.toggle()
        case .zoomIn:  style.fontSize = min(30, style.fontSize + 1)
        case .zoomOut: style.fontSize = max(13, style.fontSize - 1)
        case .zoomReset: style.fontSize = 19
        case .toggleBinder: showBinder.toggle()
        case .toggleStudio: showStudio.toggle()
        case .zenMode: zen.toggle()
        case .startSprint: sprintSheet = true
        case .endSession: closeSheet = true
        case .snapshot:
            if let id = store.selection {
                store.snapshot(id, label: "manual")
                flash("Snapshot taken")
            }
        case .compile: compileSheet = true
        case .saveNow:
            try? store.saveNow()
            flash("Saved to \(store.folder.lastPathComponent)")
        case .revealInFinder:
            NSWorkspace.shared.activateFileViewerSelecting([store.folder])
        case .viewPage:     main = .page
        case .viewCork:     main = .corkboard
        case .viewOutline:  main = .outliner
        case .viewSpine:    main = .spine
        case .viewCast:     main = .cast
        case .viewNotes:    main = .notes
        case .viewEvidence: main = .evidence
        case .viewProgress: main = .progress
        case .viewStructure: main = .structure
        case .viewTimeline: main = .timeline
        case .viewContinuity: main = .continuity
        case .viewDiagnostics: main = .diagnostics
        case .viewAppointments: main = .appointments
        case .readAloud:
            if let id = store.selection { reader.speak(store.body(id)) }
        case .stopReading:
            reader.stop()
        case .importSources:
            importSources()
        case .addComment:
            return   // handled by the editor, which knows the selection
        case .bold, .italic, .h1, .h2, .h3, .body, .sceneBreak:
            return   // handled by the text view itself
        }
        if style != store.manifest.pageStyle {
            store.manifest.pageStyle = style
            store.touchManifest()
        }
    }
}


// MARK: - Window access
//
// SwiftUI doesn't hand you the NSWindow, and command routing needs to know
// which book is frontmost.

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { onWindow(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { onWindow(view.window) }
    }
}


// MARK: - Source import

extension ProjectWindow {

    /// Reads a CSL-JSON export from Zotero, Mendeley, or pandoc and turns each
    /// entry into a citable source in the cast.
    func importSources() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a CSL-JSON file exported from Zotero or another reference manager."
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        do {
            let items = try CSLImport.parse(data)
            guard !items.isEmpty else { flash("No entries found in that file"); return }
            var taken = Set(store.manifest.cast.map(\.citekey).filter { !$0.isEmpty })
            var added = 0, updated = 0
            for item in items {
                var csl = item
                let key = csl.id.isEmpty
                    ? CSLItem.makeKey(csl.authors, csl.year, taken: taken)
                    : csl.id
                csl.id = key
                taken.insert(key)
                if let i = store.manifest.cast.firstIndex(where: { $0.citekey == key }) {
                    store.manifest.cast[i].csl = csl
                    if !csl.title.isEmpty { store.manifest.cast[i].name = csl.title }
                    updated += 1
                } else {
                    var e = Entity(kind: .source, name: csl.title.isEmpty ? key : csl.title)
                    e.role = csl.authors.first.map { $0.full } ?? ""
                    e.citekey = key
                    e.csl = csl
                    e.url = csl.url
                    e.permission = .onRecord
                    e.colorIndex = store.manifest.cast.count % 8
                    e.fields = Entity.template(for: .source)
                    store.manifest.cast.append(e)
                    added += 1
                }
            }
            store.touchManifest()
            try? store.saveNow()
            let tail = updated > 0 ? ", updated \(updated)" : ""
            flash("Imported \(added) source\(added == 1 ? "" : "s")\(tail) \u{00B7} cite with [@key]")
        } catch {
            flash("Couldn't read that file: \(error.localizedDescription)")
        }
    }
}
