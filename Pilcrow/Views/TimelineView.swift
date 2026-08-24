//  TimelineView.swift
//  Two tracks: the order the reader meets events, and the order they happened.
//  For a book with flashbacks, the gap between them is the craft problem.

import SwiftUI

struct TimelineView: View {
    @Bindable var store: ProjectStore
    @State private var editing: TimelineEvent?

    private var labels: LabelPack { store.labels }

    /// Narrative order: manuscript position, with unplaced events last.
    private var narrative: [TimelineEvent] {
        let order = Dictionary(uniqueKeysWithValues:
            store.orderedDocuments.enumerated().map { ($0.element.id, $0.offset) })
        return store.manifest.timeline.sorted {
            let a = $0.nodeID.flatMap { order[$0] } ?? Int.max
            let b = $1.nodeID.flatMap { order[$0] } ?? Int.max
            return a == b ? $0.title < $1.title : a < b
        }
    }
    private var chronological: [TimelineEvent] {
        store.manifest.timeline.sorted {
            $0.storyOrder == $1.storyOrder ? $0.title < $1.title : $0.storyOrder < $1.storyOrder
        }
    }

    /// Events whose two positions disagree — the ones doing the work.
    private var displaced: Set<UUID> {
        let n = narrative.map(\.id), c = chronological.map(\.id)
        return Set(n.indices.filter { n[$0] != c[$0] }.map { n[$0] })
    }

    var body: some View {
        VStack(spacing: 0) {
            bar
            Rule()
            if store.manifest.timeline.isEmpty {
                EmptyState(symbol: "calendar.day.timeline.left",
                           title: "No events yet",
                           message: "An event is anything that happened, whether or not it happens on the page. Give it a place in the story's chronology and Pilcrow will show you how far it sits from where the reader meets it.",
                           actionLabel: "Add the first event") { add() }
            } else {
                columns
            }
        }
        .background(LL.ground)
        .sheet(item: $editing) { e in editor(e) }
    }

    private var bar: some View {
        HStack(spacing: 10) {
            Text("TIMELINE").font(PilcrowFonts.displayF(20)).tracking(0.9)
                .foregroundStyle(LL.ink)
            if !displaced.isEmpty {
                Pill(text: "\(displaced.count) out of sequence", tint: LL.chartColor(5))
            }
            Spacer()
            Button { add() } label: { Label("Add event", systemImage: "plus") }
                .llButton(.accent, compact: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: 0) {
            track(title: "As the reader meets it", events: narrative,
                  caption: { store.node($0.nodeID ?? UUID())?.title ?? "off the page" },
                  reorderable: false)
            VRule()
            track(title: "As it happened", events: chronological,
                  caption: { $0.storyDate.isEmpty ? "no date set" : $0.storyDate },
                  reorderable: true)
        }
    }

    private func track(title: String, events: [TimelineEvent],
                       caption: @escaping (TimelineEvent) -> String,
                       reorderable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title)
            Rule()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { i, e in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(spacing: 0) {
                                Circle().fill(e.color).frame(width: 9, height: 9)
                                if i < events.count - 1 {
                                    Rectangle().fill(LL.rule).frame(width: 1)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Text(e.title)
                                        .font(PilcrowFonts.bodyF(12.5, .medium))
                                        .foregroundStyle(LL.ink).lineLimit(1)
                                    if displaced.contains(e.id) {
                                        Image(systemName: "arrow.left.arrow.right")
                                            .font(.system(size: 8))
                                            .foregroundStyle(LL.chartColor(5))
                                    }
                                }
                                Text(caption(e))
                                    .font(PilcrowFonts.monoF(9.5)).foregroundStyle(LL.ink3)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            if reorderable {
                                VStack(spacing: 1) {
                                    IconButton(symbol: "chevron.up", help: "Earlier") { nudge(e, -1) }
                                    IconButton(symbol: "chevron.down", help: "Later") { nudge(e, 1) }
                                }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = e }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: Editing

    private func add() {
        var e = TimelineEvent(title: "New event")
        e.nodeID = store.selection
        e.storyOrder = (store.manifest.timeline.map(\.storyOrder).max() ?? 0) + 1
        e.colorIndex = store.manifest.timeline.count % 8
        store.manifest.timeline.append(e)
        store.touchManifest()
        editing = e
    }

    /// Swaps chronological position with the neighbour, rather than nudging
    /// a float that would eventually collide.
    private func nudge(_ e: TimelineEvent, _ delta: Int) {
        let sorted = chronological
        guard let idx = sorted.firstIndex(where: { $0.id == e.id }) else { return }
        let target = idx + delta
        guard target >= 0, target < sorted.count else { return }
        let a = sorted[idx].id, b = sorted[target].id
        guard let ia = store.manifest.timeline.firstIndex(where: { $0.id == a }),
              let ib = store.manifest.timeline.firstIndex(where: { $0.id == b }) else { return }
        let tmp = store.manifest.timeline[ia].storyOrder
        store.manifest.timeline[ia].storyOrder = store.manifest.timeline[ib].storyOrder
        store.manifest.timeline[ib].storyOrder = tmp
        store.touchManifest()
    }

    private func editor(_ e: TimelineEvent) -> some View {
        let idx = store.manifest.timeline.firstIndex { $0.id == e.id }
        return VStack(alignment: .leading, spacing: 12) {
            Text("EVENT").font(PilcrowFonts.displayF(24)).tracking(1)
                .foregroundStyle(LL.ink)
            if let idx {
                field("Title") {
                    TextField("", text: Binding(
                        get: { store.manifest.timeline[idx].title },
                        set: { store.manifest.timeline[idx].title = $0; store.touchManifest() }))
                    .textFieldStyle(.plain).font(PilcrowFonts.headingF(15, .semibold))
                }
                field("When, in the story") {
                    TextField("", text: Binding(
                        get: { store.manifest.timeline[idx].storyDate },
                        set: { store.manifest.timeline[idx].storyDate = $0; store.touchManifest() }),
                        prompt: Text("The summer before \u{2014} or a real date"))
                    .textFieldStyle(.plain).font(PilcrowFonts.bodyF(12.5))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Where the reader meets it")
                    Picker("", selection: Binding(
                        get: { store.manifest.timeline[idx].nodeID ?? noNode },
                        set: {
                            store.manifest.timeline[idx].nodeID = ($0 == noNode ? nil : $0)
                            store.touchManifest()
                        })) {
                            Text("Off the page").tag(noNode)
                            ForEach(store.orderedDocuments) { Text($0.title).tag($0.id) }
                        }.labelsHidden().controlSize(.small)
                }
                field("Note") {
                    TextEditor(text: Binding(
                        get: { store.manifest.timeline[idx].note },
                        set: { store.manifest.timeline[idx].note = $0; store.touchManifest() }))
                    .font(PilcrowFonts.bodyF(12)).scrollContentBackground(.hidden)
                    .frame(height: 56)
                }
            }
            HStack {
                Button("Delete", role: .destructive) {
                    store.manifest.timeline.removeAll { $0.id == e.id }
                    store.touchManifest(); editing = nil
                }.llButton(.ghost)
                Spacer()
                Button("Done") { editing = nil }.llButton(.accent)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(LL.ground)
    }

    private let noNode = UUID()

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
