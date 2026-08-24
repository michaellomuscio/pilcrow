//  BoardViews.swift
//  Spine Board, Corkboard, Outliner.
//
//  The Spine Board is one component with two label packs. In fiction the
//  columns are plot lines; in nonfiction they are argument threads. They
//  are the same object — a promise made to the reader and eventually paid
//  off — so they get the same grid.

import SwiftUI

// MARK: - Spine Board

struct SpineBoardView: View {
    @Bindable var store: ProjectStore
    @State private var editing: (node: UUID, thread: UUID)?
    @State private var newThreadName = ""
    @State private var showAdd = false

    private var labels: LabelPack { store.labels }
    private var threads: [SpineThread] { store.manifest.threads.filter { !$0.archived } }
    private var docs: [Node] { store.orderedDocuments }

    private let colWidth: CGFloat = 190
    private let rowHeight: CGFloat = 74
    private let gutter: CGFloat = 190

    var body: some View {
        VStack(spacing: 0) {
            bar
            Rule()
            if threads.isEmpty {
                EmptyState(symbol: "chart.bar.doc.horizontal",
                           title: "No \(labels.spine.lowercased()) threads yet",
                           message: threadsBlurb,
                           actionLabel: "Add the first one") { showAdd = true }
            } else if docs.isEmpty {
                EmptyState(symbol: "doc.text", title: "Nothing to plot yet",
                           message: "Add a \(labels.leaf.lowercased()) in the binder and it will appear as a row here.")
            } else {
                board
            }
        }
        .background(LL.ground)
        .sheet(isPresented: $showAdd) { addThreadSheet }
        .sheet(item: Binding(
            get: { editing.map { BeatRef(node: $0.node, thread: $0.thread) } },
            set: { if $0 == nil { editing = nil } })) { ref in
                beatEditor(ref)
            }
    }

    private var threadsBlurb: String {
        store.manifest.kind == .nonfiction
        ? "An argument thread is a claim that runs through the book. Each section either introduces it, supports it, complicates it, or resolves it. Threads that go quiet for six chapters get flagged."
        : "A plot line is a promise you make to the reader and eventually pay off. Each scene advances one or several. Threads that go quiet for twelve scenes get flagged."
    }

    private var bar: some View {
        HStack(spacing: 10) {
            Text(labels.spineBoard.uppercased())
                .font(PilcrowFonts.displayF(20)).tracking(0.9)
                .foregroundStyle(LL.ink)
            Spacer()
            ForEach(healthFlags, id: \.self) { flag in
                Pill(text: flag, tint: LL.warn)
            }
            Button { showAdd = true } label: {
                Label("Add \(labels.spineOne)", systemImage: "plus")
            }.llButton(.accent, compact: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    /// A thread that goes a long stretch with no beat is a dropped thread,
    /// and a promise with no payoff is the note your editor was going to
    /// write. Better to see it in week three.
    private var healthFlags: [String] {
        var out: [String] = []
        let ids = docs.map(\.id)
        for t in threads {
            let hits = ids.enumerated().filter { store.beat(node: $0.element, thread: t.id) != nil }
                .map(\.offset)
            guard !hits.isEmpty else { continue }
            var gap = hits[0]
            for i in 1..<max(1, hits.count) { gap = max(gap, hits[i] - hits[i-1] - 1) }
            gap = max(gap, ids.count - 1 - (hits.last ?? 0))
            if gap >= 8 { out.append("\(t.name): \(gap) \(labels.leaf.lowercased())s quiet") }
            if !t.promise.isEmpty && t.payoff.isEmpty { out.append("\(t.name): no \(labels.payoff.lowercased())") }
        }
        return Array(out.prefix(2))
    }

    private var board: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                ForEach(Array(docs.enumerated()), id: \.element.id) { i, doc in
                    beatRow(doc, index: i)
                }
            }
        }
        // A grid smaller than its scroll view should sit top-left, not float
        // in the middle of the window.
        .defaultScrollAnchor(.topLeading)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text(labels.leaf.uppercased())
                .font(PilcrowFonts.monoF(9.5)).tracking(1.2)
                .foregroundStyle(LL.ink3)
                .frame(width: gutter, alignment: .leading)
                .padding(.leading, 16)
            ForEach(threads) { t in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Circle().fill(t.color).frame(width: 7, height: 7)
                        Text(t.name)
                            .font(PilcrowFonts.headingF(12.5, .bold))
                            .foregroundStyle(LL.ink).lineLimit(1)
                    }
                    if !t.promise.isEmpty {
                        Text(t.promise)
                            .font(PilcrowFonts.bodyF(10))
                            .foregroundStyle(LL.ink3).lineLimit(2)
                    }
                }
                .frame(width: colWidth, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 9)
                .contextMenu {
                    Button("Edit\u{2026}") { editThread = t }
                    Button("Archive", role: .destructive) {
                        if let i = store.manifest.threads.firstIndex(where: { $0.id == t.id }) {
                            store.manifest.threads[i].archived = true
                            store.touchManifest()
                        }
                    }
                }
            }
        }
        .frame(height: 58)
        .background(LL.recessed)
        .overlay(alignment: .bottom) { Rule() }
    }

    @State private var editThread: SpineThread?

    private func beatRow(_ doc: Node, index: Int) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    StatusDot(status: doc.status)
                    Text(doc.title)
                        .font(PilcrowFonts.bodyF(12, .medium))
                        .foregroundStyle(LL.ink).lineLimit(1)
                }
                Text("\(doc.wordCount.grouped) words")
                    .font(PilcrowFonts.monoF(9)).foregroundStyle(LL.ink3)
            }
            .frame(width: gutter, alignment: .leading)
            .padding(.leading, 16).padding(.trailing, 8)
            .contentShape(Rectangle())
            .onTapGesture { store.selection = doc.id }

            ForEach(threads) { t in
                beatCell(doc: doc, thread: t)
            }
        }
        .frame(height: rowHeight)
        .background(index % 2 == 0 ? Color.clear : LL.recessed.opacity(0.4))
        .overlay(alignment: .bottom) { Rule() }
    }

    private func beatCell(doc: Node, thread: SpineThread) -> some View {
        let b = store.beat(node: doc.id, thread: thread.id)
        return Button {
            editing = (doc.id, thread.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                if let b {
                    if !b.verb.isEmpty { Pill(text: b.verb, tint: thread.color) }
                    Text(b.text)
                        .font(PilcrowFonts.bodyF(11))
                        .foregroundStyle(LL.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("\u{2014}").font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .frame(width: colWidth, height: rowHeight, alignment: .topLeading)
            .padding(.horizontal, 10).padding(.top, 9)
            .background(b == nil ? Color.clear : thread.color.opacity(0.09))
            .overlay(alignment: .leading) {
                if b != nil { Rectangle().fill(thread.color).frame(width: 2) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private struct BeatRef: Identifiable {
        let node: UUID, thread: UUID
        var id: String { "\(node)-\(thread)" }
    }

    private func beatEditor(_ ref: BeatRef) -> some View {
        let thread = store.manifest.threads.first { $0.id == ref.thread }
        let doc = store.node(ref.node)
        let existing = store.beat(node: ref.node, thread: ref.thread)
        return BeatEditor(
            threadName: thread?.name ?? "",
            docTitle: doc?.title ?? "",
            verbs: labels.beatVerbs,
            text: existing?.text ?? "",
            verb: existing?.verb ?? "") { text, verb in
                store.setBeat(node: ref.node, thread: ref.thread, text: text, verb: verb)
                editing = nil
            } cancel: { editing = nil }
    }

    private var addThreadSheet: some View {
        ThreadEditor(labels: labels, existing: nil) { name, promise, payoff, color in
            var t = SpineThread(name: name)
            t.promise = promise; t.payoff = payoff
            t.colorIndex = color
            t.order = store.manifest.threads.count
            store.manifest.threads.append(t)
            store.touchManifest()
            showAdd = false
        } cancel: { showAdd = false }
    }
}

// MARK: Beat editor

private struct BeatEditor: View {
    let threadName: String
    let docTitle: String
    let verbs: [String]
    @State var text: String
    @State var verb: String
    let save: (String, String) -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: threadName)
                Text(docTitle).font(PilcrowFonts.headingF(18, .bold)).foregroundStyle(LL.ink)
            }
            Eyebrow(text: "What this does for the thread")
            HStack(spacing: 5) {
                ForEach(verbs, id: \.self) { v in
                    Button { verb = (verb == v ? "" : v) } label: {
                        Text(v)
                            .font(PilcrowFonts.monoF(9.5)).tracking(0.6)
                            .foregroundStyle(verb == v ? LL.onAccent : LL.ink2)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(verb == v ? LL.accent : LL.recessed))
                    }.buttonStyle(.plain)
                }
            }
            TextEditor(text: $text)
                .font(PilcrowFonts.bodyF(13))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 5).fill(LL.surface))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(LL.rule, lineWidth: 1))
                .frame(height: 110)
            HStack {
                Button("Clear") { save("", "") }.llButton(.ghost)
                Spacer()
                Button("Cancel") { cancel() }.llButton(.ghost)
                Button("Save") { save(text.trimmingCharacters(in: .whitespacesAndNewlines), verb) }
                    .llButton(.accent)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(LL.ground)
    }
}

// MARK: Thread editor

struct ThreadEditor: View {
    let labels: LabelPack
    let existing: SpineThread?
    let save: (String, String, String, Int) -> Void
    let cancel: () -> Void

    @State private var name = ""
    @State private var promise = ""
    @State private var payoff = ""
    @State private var color = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(labels.spineOne.uppercased())
                .font(PilcrowFonts.displayF(24)).tracking(1)
                .foregroundStyle(LL.ink)

            field("Name") {
                TextField("", text: $name, prompt: Text(labels.spine == "Plot" ? "Ardmore & the maps" : "Schools misread their own demand"))
                    .textFieldStyle(.plain).font(PilcrowFonts.headingF(15, .semibold))
            }
            field(labels.promise) {
                TextField("", text: $promise, prompt: Text("What you're promising the reader"), axis: .vertical)
                    .textFieldStyle(.plain).font(PilcrowFonts.bodyF(12.5)).lineLimit(2...3)
            }
            field(labels.payoff) {
                TextField("", text: $payoff, prompt: Text("How it lands"), axis: .vertical)
                    .textFieldStyle(.plain).font(PilcrowFonts.bodyF(12.5)).lineLimit(2...3)
            }

            Eyebrow(text: "Colour")
            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { i in
                    Button { color = i } label: {
                        Circle().fill(LL.chartColor(i))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(LL.ink, lineWidth: color == i ? 2 : 0))
                    }.buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { cancel() }.llButton(.ghost)
                Button("Save") {
                    let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !n.isEmpty else { return }
                    save(n, promise, payoff, color)
                }.llButton(.accent)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(width: 450)
        .background(LL.ground)
        .onAppear {
            if let e = existing {
                name = e.name; promise = e.promise; payoff = e.payoff; color = e.colorIndex
            }
        }
    }

    private func field<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: title)
            content()
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 5).fill(LL.surface))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(LL.rule, lineWidth: 1))
        }
    }
}

// MARK: - Corkboard

struct CorkboardView: View {
    @Bindable var store: ProjectStore
    let open: (UUID) -> Void

    private let columns = [GridItem(.adaptive(minimum: 216, maximum: 260), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(store.orderedDocuments) { doc in
                    card(doc)
                }
            }
            .padding(18)
        }
        .background(LL.ground)
    }

    private func card(_ doc: Node) -> some View {
        Button { open(doc.id) } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    StatusDot(status: doc.status)
                    Text(doc.title)
                        .font(PilcrowFonts.headingF(13.5, .bold))
                        .foregroundStyle(LL.ink).lineLimit(1)
                    Spacer(minLength: 4)
                }
                Text(doc.synopsis.isEmpty ? "No synopsis yet." : doc.synopsis)
                    .font(PilcrowFonts.bodyF(11.5))
                    .foregroundStyle(doc.synopsis.isEmpty ? LL.ink3 : LL.ink2)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    ForEach(threadDots(doc), id: \.self) { i in
                        Circle().fill(LL.chartColor(i)).frame(width: 6, height: 6)
                    }
                    Spacer()
                    Text(doc.wordCount.grouped)
                        .font(PilcrowFonts.monoF(9.5)).foregroundStyle(LL.ink3)
                }
            }
            .padding(13)
            .frame(height: 156, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(store.selection == doc.id ? LL.accent : LL.rule,
                              lineWidth: store.selection == doc.id ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func threadDots(_ doc: Node) -> [Int] {
        store.manifest.beats.filter { $0.nodeID == doc.id }.compactMap { b in
            store.manifest.threads.first { $0.id == b.threadID }?.colorIndex
        }
    }
}

// MARK: - Outliner

struct OutlinerView: View {
    @Bindable var store: ProjectStore
    let open: (UUID) -> Void

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(Array(rows.enumerated()), id: \.element.node.id) { i, r in
                    row(r, index: i)
                }
            }
        }
        .defaultScrollAnchor(.topLeading)
        .background(LL.ground)
    }

    private struct Row { let node: Node; let depth: Int }

    private var rows: [Row] {
        func walk(_ n: Node, _ d: Int) -> [Row] {
            n.children.flatMap { [Row(node: $0, depth: d)] + walk($0, d + 1) }
        }
        return walk(store.manifest.root, 0)
    }

    private var header: some View {
        HStack(spacing: 0) {
            cell("Title", width: 260, mono: true)
            cell("Synopsis", width: 340, mono: true)
            cell("Status", width: 92, mono: true)
            cell("Words", width: 72, mono: true, trailing: true)
            cell("Target", width: 72, mono: true, trailing: true)
        }
        .frame(height: 34)
        .background(LL.recessed)
        .overlay(alignment: .bottom) { Rule() }
    }

    private func row(_ r: Row, index: Int) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                if !r.node.isFolder { StatusDot(status: r.node.status) }
                Image(systemName: r.node.isFolder ? "folder" : "doc.text")
                    .font(.system(size: 9)).foregroundStyle(LL.ink3)
                Text(r.node.title)
                    .font(PilcrowFonts.bodyF(12, r.node.isFolder ? .semibold : .regular))
                    .foregroundStyle(LL.ink).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(r.depth) * 14 + 12)
            .frame(width: 260, alignment: .leading)

            Text(r.node.synopsis)
                .font(PilcrowFonts.bodyF(11.5)).foregroundStyle(LL.ink2)
                .lineLimit(2).frame(width: 340, alignment: .leading)
                .padding(.horizontal, 10)

            Text(r.node.isFolder ? "" : r.node.status.label)
                .font(PilcrowFonts.monoF(10)).foregroundStyle(r.node.status.tint)
                .frame(width: 92, alignment: .leading).padding(.horizontal, 10)

            Text((r.node.isFolder ? r.node.totalWords : r.node.wordCount).grouped)
                .font(PilcrowFonts.monoF(10.5)).foregroundStyle(LL.ink)
                .frame(width: 72, alignment: .trailing).padding(.horizontal, 10)

            Text(r.node.totalTarget > 0 ? r.node.totalTarget.grouped : "\u{2014}")
                .font(PilcrowFonts.monoF(10.5)).foregroundStyle(LL.ink3)
                .frame(width: 72, alignment: .trailing).padding(.horizontal, 10)
        }
        .frame(height: 38)
        .background(index % 2 == 0 ? Color.clear : LL.recessed.opacity(0.4))
        .overlay(alignment: .bottom) { Rule() }
        .contentShape(Rectangle())
        .onTapGesture { if !r.node.isFolder { open(r.node.id) } else { store.selection = r.node.id } }
    }

    private func cell(_ t: String, width: CGFloat, mono: Bool, trailing: Bool = false) -> some View {
        Text(t.uppercased())
            .font(PilcrowFonts.monoF(9.5)).tracking(1.1)
            .foregroundStyle(LL.ink3)
            .frame(width: width, alignment: trailing ? .trailing : .leading)
            .padding(.horizontal, trailing ? 10 : 12)
    }
}
