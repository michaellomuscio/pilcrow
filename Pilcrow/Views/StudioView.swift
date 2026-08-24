//  StudioView.swift
//  The right rail: the session, and everything true about the document
//  you're standing in.

import SwiftUI

struct StudioView: View {
    @Bindable var store: ProjectStore
    var session: SessionEngine
    var stats: EditorStats
    var reader: ReadAloud
    var startSprint: () -> Void
    var closeSession: () -> Void

    private var labels: LabelPack { store.labels }
    private var node: Node? { store.node(store.selection) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                sessionPanel
                Rule()
                if let node { inspector(node) }
                Rule()
                if let node { commentsPanel(node) }
                Rule()
                readAloudPanel
                Rule()
                pageControls
                Rule()
                if let node { snapshotPanel(node) }
            }
        }
        .background(LL.surface)
    }

    // MARK: Session

    private var sessionPanel: some View {
        VStack(spacing: 0) {
            PanelHeader("Session") {
                if session.active != nil {
                    IconButton(symbol: session.isPaused ? "play.fill" : "pause.fill",
                               help: session.isPaused ? "Resume" : "Pause") {
                        session.isPaused ? session.resume() : session.pause()
                    }
                }
            }

            if let s = session.active {
                HStack(spacing: 14) {
                    ZStack {
                        ProgressRing(progress: session.goalProgress, size: 64, lineWidth: 5,
                                     tint: session.goalReached ? LL.ok : LL.accent)
                        VStack(spacing: 0) {
                            Text(session.readout)
                                .font(PilcrowFonts.monoF(15, .medium))
                                .foregroundStyle(LL.ink)
                                .monospacedDigit()
                            Text(session.readoutUnit)
                                .font(PilcrowFonts.monoF(7.5))
                                .foregroundStyle(LL.ink3)
                        }
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        if !s.goalNote.isEmpty {
                            Text(s.goalNote)
                                .font(PilcrowFonts.bodyF(12, .medium))
                                .foregroundStyle(LL.ink)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("+\(s.wordsAdded.grouped)")
                                    .font(PilcrowFonts.monoF(12, .medium))
                                    .foregroundStyle(LL.ok)
                                Eyebrow(text: "added")
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\u{2212}\(s.wordsCut.grouped)")
                                    .font(PilcrowFonts.monoF(12, .medium))
                                    .foregroundStyle(LL.accent)
                                Eyebrow(text: "cut")
                            }
                        }
                        if session.goalReached {
                            Pill(text: "goal met \u{00B7} keep going if you like",
                                 tint: LL.ok)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.bottom, 10)

                Button("Close the Session\u{2026}") { closeSession() }
                    .llButton(.primary, compact: true)
                    .padding(.horizontal, 14).padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    Button {
                        startSprint()
                    } label: {
                        Label("Start a Sprint", systemImage: "timer")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .llButton(.accent, compact: true)

                    todayLine
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
            }
        }
    }

    /// Today, stated as work done rather than a quota missed. There is no
    /// streak here and nothing turns red.
    private var todayLine: some View {
        let today = store.log.today
        let added = today.reduce(0) { $0 + $1.wordsAdded }
        let cut = today.reduce(0) { $0 + $1.wordsCut }
        let mins = store.log.minutesToday
        return VStack(alignment: .leading, spacing: 4) {
            if today.isEmpty {
                Text("No session logged today. That is a perfectly ordinary way for a day to go.")
                    .font(PilcrowFonts.bodyF(11))
                    .foregroundStyle(LL.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 12) {
                    KeyValueRow(key: "Sat for", value: "\(mins) min")
                    Spacer()
                }
                KeyValueRow(key: "Added", value: "+\(added.grouped)", tint: LL.ok)
                KeyValueRow(key: "Cut", value: "\u{2212}\(cut.grouped)", tint: LL.accent)
            }
        }
    }

    // MARK: Inspector

    private func inspector(_ node: Node) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(node.isFolder ? labels.container : labels.leaf)

            VStack(alignment: .leading, spacing: 10) {
                labelled("Synopsis") {
                    TextEditor(text: Binding(
                        get: { node.synopsis },
                        set: { v in
                            _ = store.manifest.root.update(node.id) { $0.synopsis = v }
                            store.touchManifest()
                        }))
                    .font(PilcrowFonts.bodyF(11.5))
                    .scrollContentBackground(.hidden)
                    .frame(height: 58)
                }

                HStack(spacing: 8) {
                    labelled("Status") {
                        Picker("", selection: Binding(
                            get: { node.status },
                            set: { v in
                                _ = store.manifest.root.update(node.id) { $0.status = v }
                                store.touchManifest()
                            })) {
                                ForEach(NodeStatus.allCases) { Text($0.label).tag($0) }
                            }
                            .labelsHidden().controlSize(.small)
                    }
                    labelled("Target") {
                        TextField("", value: Binding(
                            get: { node.target },
                            set: { v in
                                _ = store.manifest.root.update(node.id) { $0.target = max(0, v) }
                                store.touchManifest()
                            }), format: .number)
                        .textFieldStyle(.roundedBorder).controlSize(.small)
                        .font(PilcrowFonts.monoF(11))
                    }
                }

                HStack(spacing: 12) {
                    KeyValueRow(key: "Words", value: (node.isFolder ? node.totalWords : node.wordCount).grouped)
                }
                if node.target > 0 {
                    let ratio = Double(node.isFolder ? node.totalWords : node.wordCount) / Double(node.target)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(LL.rule).frame(height: 4)
                            Capsule().fill(ratio >= 1 ? LL.ok : LL.accent)
                                .frame(width: g.size.width * min(1, ratio), height: 4)
                        }
                    }.frame(height: 4)
                }

                if !store.manifest.threads.isEmpty {
                    labelled(labels.spine) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(store.manifest.threads.filter { !$0.archived }) { t in
                                let b = store.beat(node: node.id, thread: t.id)
                                HStack(spacing: 6) {
                                    Circle().fill(t.color).frame(width: 6, height: 6)
                                    Text(t.name)
                                        .font(PilcrowFonts.bodyF(11))
                                        .foregroundStyle(b == nil ? LL.ink3 : LL.ink)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    if let b, !b.verb.isEmpty { Pill(text: b.verb, tint: t.color) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 13)
        }
    }

    private func labelled<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Comments

    private func commentsPanel(_ node: Node) -> some View {
        let text = store.body(node.id) as NSString
        let mine = store.manifest.annotations.filter { $0.nodeID == node.id }
        let open = mine.filter { !$0.resolved }
        return VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Comments") {
                if !open.isEmpty { Pill(text: "\(open.count)", tint: LL.accent) }
            }
            VStack(alignment: .leading, spacing: 9) {
                if mine.isEmpty {
                    Text("Select a phrase and press \u{21E7}\u{2318}K. Comments anchor to the words, not the position, so they survive edits \u{2014} and they never print.")
                        .font(PilcrowFonts.bodyF(10.5))
                        .foregroundStyle(LL.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(mine) { note in
                        let lost = note.range(in: text) == nil
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Rectangle()
                                    .fill(note.resolved ? LL.ink3 : LL.accent)
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                                Text("\u{201C}\(note.quoted.prefix(60))\u{201D}")
                                    .font(PilcrowFonts.bodyF(10.5))
                                    .foregroundStyle(lost ? LL.crit : LL.ink3)
                                    .italic()
                                    .lineLimit(2)
                                Spacer(minLength: 2)
                            }
                            .fixedSize(horizontal: false, vertical: true)

                            TextEditor(text: Binding(
                                get: { note.body },
                                set: { v in
                                    if let i = store.manifest.annotations
                                        .firstIndex(where: { $0.id == note.id }) {
                                        store.manifest.annotations[i].body = v
                                        store.touchManifest()
                                    }
                                }))
                                .font(PilcrowFonts.bodyF(11.5))
                                .scrollContentBackground(.hidden)
                                .frame(height: 44)
                                .padding(5)
                                .background(RoundedRectangle(cornerRadius: 4).fill(LL.recessed))

                            HStack(spacing: 6) {
                                if lost {
                                    Text("anchor lost \u{2014} the text changed")
                                        .font(PilcrowFonts.monoF(9)).foregroundStyle(LL.crit)
                                }
                                Spacer()
                                Button(note.resolved ? "Reopen" : "Resolve") {
                                    if let i = store.manifest.annotations
                                        .firstIndex(where: { $0.id == note.id }) {
                                        store.manifest.annotations[i].resolved.toggle()
                                        store.touchManifest()
                                    }
                                }.llButton(.ghost, compact: true)
                                IconButton(symbol: "trash", help: "Delete") {
                                    store.manifest.annotations.removeAll { $0.id == note.id }
                                    store.touchManifest()
                                }
                            }
                        }
                        .opacity(note.resolved ? 0.55 : 1)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 13)
        }
    }

    // MARK: Read aloud

    private var readAloudPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Read aloud") {
                if reader.isSpeaking {
                    IconButton(symbol: reader.isPaused ? "play.fill" : "pause.fill",
                               help: reader.isPaused ? "Resume" : "Pause") {
                        reader.togglePause()
                    }
                }
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Button {
                        if reader.isSpeaking { reader.stop() }
                        else if let id = store.selection { reader.speak(store.body(id)) }
                    } label: {
                        Label(reader.isSpeaking ? "Stop" : "Read this aloud",
                              systemImage: reader.isSpeaking ? "stop.fill" : "speaker.wave.2")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .llButton(reader.isSpeaking ? .secondary : .accent, compact: true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow(text: "Voice")
                    Picker("", selection: Binding(
                        get: { reader.voiceID },
                        set: { reader.voiceID = $0 })) {
                            ForEach(ReadAloud.voices(), id: \.identifier) { v in
                                Text("\(v.name) \u{00B7} \(ReadAloud.qualityLabel(v))")
                                    .tag(v.identifier)
                            }
                        }.labelsHidden().controlSize(.small)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Eyebrow(text: "Pace")
                        Spacer()
                        Text(String(format: "%.2f", reader.rate))
                            .font(PilcrowFonts.monoF(9.5)).foregroundStyle(LL.ink3)
                    }
                    Slider(value: Binding(get: { Double(reader.rate) },
                                          set: { reader.rate = Float($0) }),
                           in: 0.3...0.7).controlSize(.mini)
                }
                Text("The ear catches what the eye skips. Everything runs on-device \u{2014} no word of this leaves the machine.")
                    .font(PilcrowFonts.bodyF(10.5)).foregroundStyle(LL.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14).padding(.bottom, 13)
        }
    }

    // MARK: Page controls

    private var pageControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("The Page")
            VStack(alignment: .leading, spacing: 10) {
                labelled(store.manifest.pageStyle.mode == .draft ? "Drafting face" : "Reading face") {
                    Picker("", selection: Binding(
                        get: { store.manifest.pageStyle.activeFaceID },
                        set: { v in
                            if store.manifest.pageStyle.mode == .draft {
                                store.manifest.pageStyle.draftFaceID = v
                            } else {
                                store.manifest.pageStyle.faceID = v
                            }
                            store.touchManifest()
                        })) {
                            ForEach(PilcrowFonts.shelf) { f in Text(f.display).tag(f.id) }
                        }
                        .labelsHidden().controlSize(.small)
                }
                Text(PilcrowFonts.face(store.manifest.pageStyle.activeFaceID).note)
                    .font(PilcrowFonts.bodyF(10.5))
                    .foregroundStyle(LL.ink3)
                    .fixedSize(horizontal: false, vertical: true)

                slider("Size", value: Binding(
                    get: { store.manifest.pageStyle.fontSize },
                    set: { store.manifest.pageStyle.fontSize = $0; store.touchManifest() }),
                       range: 13...30, unit: "pt")

                slider("Leading", value: Binding(
                    get: { store.manifest.pageStyle.lineHeight },
                    set: { store.manifest.pageStyle.lineHeight = $0; store.touchManifest() }),
                       range: 1.3...2.2, unit: "\u{00D7}", decimals: 2)

                slider("Measure", value: Binding(
                    get: { CGFloat(store.manifest.pageStyle.measure) },
                    set: { store.manifest.pageStyle.measure = Int($0); store.touchManifest() }),
                       range: 55...75, unit: "ch")

                HStack(spacing: 8) {
                    labelled("Focus") {
                        Picker("", selection: Binding(
                            get: { store.manifest.pageStyle.focus },
                            set: { store.manifest.pageStyle.focus = $0; store.touchManifest() })) {
                                ForEach(FocusMode.allCases) { Text($0.label).tag($0) }
                            }.labelsHidden().controlSize(.small)
                    }
                    labelled("Paper") {
                        Picker("", selection: Binding(
                            get: { store.manifest.pageStyle.theme },
                            set: { store.manifest.pageStyle.theme = $0; store.touchManifest() })) {
                                ForEach(PageTheme.allCases) { Text($0.label).tag($0) }
                            }.labelsHidden().controlSize(.small)
                    }
                }

                Toggle(isOn: Binding(
                    get: { store.manifest.pageStyle.typewriter },
                    set: { store.manifest.pageStyle.typewriter = $0; store.touchManifest() })) {
                        Text("Typewriter scrolling").font(PilcrowFonts.bodyF(11.5))
                    }
                    .toggleStyle(.checkbox).controlSize(.small)

                Toggle(isOn: Binding(
                    get: { store.manifest.pageStyle.blinkCaret },
                    set: { store.manifest.pageStyle.blinkCaret = $0; store.touchManifest() })) {
                        Text("Blink the caret").font(PilcrowFonts.bodyF(11.5))
                    }
                    .toggleStyle(.checkbox).controlSize(.small)
                    .help("Off by default. A blinking caret is a moving object in peripheral vision.")
            }
            .padding(.horizontal, 14).padding(.bottom, 13)
        }
    }

    private func slider(_ title: String, value: Binding<CGFloat>,
                        range: ClosedRange<CGFloat>, unit: String, decimals: Int = 0) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Eyebrow(text: title)
                Spacer()
                Text(String(format: "%.\(decimals)f\(unit)", value.wrappedValue))
                    .font(PilcrowFonts.monoF(9.5)).foregroundStyle(LL.ink3)
            }
            Slider(value: value, in: range).controlSize(.mini)
        }
    }

    // MARK: Snapshots

    private func snapshotPanel(_ node: Node) -> some View {
        let snaps = store.snapshots(node.id)
        return VStack(alignment: .leading, spacing: 0) {
            PanelHeader("History") {
                IconButton(symbol: "camera", help: "Take a snapshot (\u{21E7}\u{2318}S)") {
                    store.snapshot(node.id, label: "manual")
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                if snaps.isEmpty {
                    Text("Snapshots are taken automatically when you close a session. They are what let you cut boldly.")
                        .font(PilcrowFonts.bodyF(10.5))
                        .foregroundStyle(LL.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(snaps.prefix(6), id: \.url) { snap in
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 9)).foregroundStyle(LL.ink3)
                            Text(snap.date.formatted(date: .abbreviated, time: .shortened))
                                .font(PilcrowFonts.monoF(10)).foregroundStyle(LL.ink2)
                            Spacer(minLength: 4)
                            Button("Restore") { store.restore(from: snap.url, into: node.id) }
                                .llButton(.ghost, compact: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 16)
        }
    }
}

// MARK: - Sprint sheet

struct SprintSheet: View {
    let labels: LabelPack
    let start: (GoalKind, Int, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var kind: GoalKind = .unit
    @State private var minutes = 25
    @State private var words = 500
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("A SPRINT").font(PilcrowFonts.displayF(28)).tracking(1.1)
                .foregroundStyle(LL.ink)
            Text("Name the work, not the number. \u{201C}Finish the Ardmore \(labels.leaf.lowercased())\u{201D} is a goal that survives a revision session; \u{201C}500 words\u{201D} is not.")
                .font(PilcrowFonts.bodyF(12)).foregroundStyle(LL.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4).padding(.bottom, 18)

            Eyebrow(text: "What are you going after")
            TextField("", text: $note, prompt: Text("Finish the opening of \(labels.container.lowercased()) four"))
                .textFieldStyle(.plain)
                .font(PilcrowFonts.bodyF(14))
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 5).fill(LL.surface))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(LL.rule, lineWidth: 1))
                .padding(.top, 5).padding(.bottom, 16)

            Eyebrow(text: "How you'll know you're done")
            Picker("", selection: $kind) {
                ForEach(GoalKind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            .padding(.top, 5)

            Text(kind.help)
                .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            HStack(spacing: 8) {
                if kind == .words {
                    Stepper("\(words) words", value: $words, in: 50...5000, step: 50)
                        .font(PilcrowFonts.bodyF(12))
                } else {
                    Stepper("\(minutes) minutes", value: $minutes, in: 5...180, step: 5)
                        .font(PilcrowFonts.bodyF(12))
                }
            }
            .padding(.top, 10)

            Spacer(minLength: 16)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.llButton(.ghost)
                Button("Begin") {
                    start(kind, kind == .words ? words : minutes,
                          note.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }.llButton(.accent)
            }
        }
        .padding(24)
        .frame(width: 470, height: 400)
        .background(LL.ground)
    }
}

// MARK: - Session close

struct SessionCloseSheet: View {
    var session: SessionEngine
    let suggestion: String
    let done: (WritingSession?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var nextLine = ""
    @State private var progress = ""
    @State private var mood: Int?
    @State private var energy: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CLOSING UP").font(PilcrowFonts.displayF(28)).tracking(1.1)
                .foregroundStyle(LL.ink)

            if let s = session.active {
                HStack(spacing: 20) {
                    BigStat(value: "\(session.minutesElapsed)", caption: "minutes")
                    BigStat(value: "+\(s.wordsAdded.grouped)", caption: "added", tint: LL.ok)
                    BigStat(value: "\u{2212}\(s.wordsCut.grouped)", caption: "cut", tint: LL.accent)
                }
                .padding(.top, 14).padding(.bottom, 4)
                Text("Both columns are work. In revision, the right-hand one is the work.")
                    .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3)
                    .padding(.bottom, 16)
            }

            Eyebrow(text: "What happens next")
            TextField("", text: $nextLine, prompt: Text("She opens the door and it isn\u{2019}t him."), axis: .vertical)
                .textFieldStyle(.plain)
                .font(PilcrowFonts.bodyF(13))
                .lineLimit(2...3)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 5).fill(LL.surface))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(LL.accent.opacity(0.4), lineWidth: 1))
                .padding(.top, 5)
            Text("This sits above your cursor next time you open the book.")
                .font(PilcrowFonts.bodyF(10.5)).foregroundStyle(LL.ink3)
                .padding(.top, 4).padding(.bottom, 14)

            Eyebrow(text: "What you did \u{2014} for the progress log")
            TextField("", text: $progress, prompt: Text("Cut the flashback. It was never the problem the scene had."), axis: .vertical)
                .textFieldStyle(.plain)
                .font(PilcrowFonts.bodyF(13))
                .lineLimit(2...3)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 5).fill(LL.surface))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(LL.rule, lineWidth: 1))
                .padding(.top, 5).padding(.bottom, 14)

            HStack(spacing: 22) {
                taps("Mood", value: $mood)
                taps("Energy", value: $energy)
            }

            Spacer(minLength: 14)

            HStack {
                Button("Discard this session") {
                    session.discard(); done(nil); dismiss()
                }.llButton(.ghost)
                Spacer()
                Button("Log it") {
                    done(session.finish(nextLine: nextLine.trimmingCharacters(in: .whitespacesAndNewlines),
                                        progressNote: progress.trimmingCharacters(in: .whitespacesAndNewlines),
                                        mood: mood, energy: energy))
                    dismiss()
                }.llButton(.accent)
            }
        }
        .padding(24)
        .frame(width: 520, height: 560)
        .background(LL.ground)
        .onAppear { if progress.isEmpty && !suggestion.isEmpty { progress = "" } }
    }

    private func taps(_ title: String, value: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Eyebrow(text: title)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        value.wrappedValue = value.wrappedValue == i ? nil : i
                    } label: {
                        Circle()
                            .fill(value.wrappedValue == i ? LL.accent : LL.rule)
                            .frame(width: 15, height: 15)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

extension SessionEngine {
    var minutesElapsed: Int { Int(elapsed / 60) }
}
