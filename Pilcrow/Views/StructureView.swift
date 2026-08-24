//  StructureView.swift
//  A beat sheet, and the overlay that shows where each beat actually landed.
//
//  Your midpoint sitting at 61% of the book is a fact you want in week
//  three, not in draft four. The template is a convention, not a rule —
//  drift is information, not a failure.

import SwiftUI

struct StructureView: View {
    @Bindable var store: ProjectStore
    @State private var picking = false
    @State private var placing: StructureBeat?

    private var labels: LabelPack { store.labels }
    private var docs: [Node] { store.orderedDocuments }

    private var placements: [BeatPlacement] {
        StructureAnalysis.placements(structure: store.manifest.structure,
                                     documents: docs,
                                     bodyWords: { store.node($0)?.wordCount ?? 0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            bar
            Rule()
            if store.manifest.structure.isEmpty {
                EmptyState(symbol: "ruler",
                           title: "No structure applied",
                           message: store.manifest.kind == .nonfiction
                           ? "Pick a structure pattern and Pilcrow will show you where each move should land against where it actually does. Or work without one \u{2014} plenty of good books have."
                           : "Pick a beat sheet and Pilcrow will show you where each beat should land against where it actually does. Or work without one \u{2014} plenty of good books have.",
                           actionLabel: "Choose a template") { picking = true }
            } else {
                content
            }
        }
        .background(LL.ground)
        .sheet(isPresented: $picking) { templatePicker }
        .sheet(item: $placing) { beat in placementSheet(beat) }
    }

    private var bar: some View {
        HStack(spacing: 10) {
            Text("STRUCTURE").font(PilcrowFonts.displayF(20)).tracking(0.9)
                .foregroundStyle(LL.ink)
            if let t = StructureTemplate.find(store.manifest.structure.templateID),
               t.id != "blank" {
                Pill(text: t.name, tint: LL.accent)
            }
            let adrift = placements.filter(\.isAdrift).count
            if adrift > 0 { Pill(text: "\(adrift) adrift", tint: LL.warn) }
            Spacer()
            Button { picking = true } label: {
                Label(store.manifest.structure.isEmpty ? "Choose template" : "Change template",
                      systemImage: "ruler")
            }.llButton(store.manifest.structure.isEmpty ? .accent : .secondary, compact: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: The overlay

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ruler
                VStack(spacing: 0) {
                    ForEach(Array(placements.enumerated()), id: \.element.id) { i, p in
                        beatRow(p, index: i)
                        Rule()
                    }
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))

                Text("Position is measured in words, not chapters \u{2014} a beat that lands in chapter twelve of twenty can still be sitting at 61% of the book. Drift under eight points is normal.")
                    .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: 940, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Target vs actual on one track. Reading it takes about a second,
    /// which is the whole point.
    private var ruler: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Target \u{25CB}  \u{00B7}  Actual \u{25CF}")
            GeometryReader { g in
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(LL.rule)
                        .frame(height: 2).offset(y: 21)
                    ForEach(placements) { p in
                        Circle().stroke(LL.ink3, lineWidth: 1.5)
                            .frame(width: 9, height: 9)
                            .offset(x: g.size.width * p.beat.targetAt - 4.5, y: 17)
                        if let a = p.actualAt {
                            Circle().fill(p.isAdrift ? LL.warn : LL.accent)
                                .frame(width: 9, height: 9)
                                .offset(x: g.size.width * a - 4.5, y: 31)
                        }
                    }
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { t in
                        Text("\(Int(t * 100))%")
                            .font(PilcrowFonts.monoF(8.5)).foregroundStyle(LL.ink3)
                            .offset(x: min(g.size.width - 22, max(0, g.size.width * t - 10)), y: 0)
                    }
                }
            }
            .frame(height: 46)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    private func beatRow(_ p: BeatPlacement, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                toggleDone(p.beat)
            } label: {
                Image(systemName: p.beat.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(p.beat.done ? LL.ok : LL.ink3)
            }.buttonStyle(.plain).padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(p.beat.name)
                    .font(PilcrowFonts.headingF(14, .bold))
                    .foregroundStyle(LL.ink)
                if !p.beat.note.isEmpty {
                    Text(p.beat.note)
                        .font(PilcrowFonts.bodyF(11.5)).foregroundStyle(LL.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(p.beat.targetAt * 100))%")
                    .font(PilcrowFonts.monoF(10.5)).foregroundStyle(LL.ink3)
                if let a = p.actualAt {
                    Text("\(Int(a * 100))%")
                        .font(PilcrowFonts.monoF(11, .medium))
                        .foregroundStyle(p.isAdrift ? LL.warn : LL.ink)
                }
            }
            .frame(width: 46)

            VStack(alignment: .leading, spacing: 3) {
                Button {
                    placing = p.beat
                } label: {
                    Text(p.node?.title ?? "Place\u{2026}")
                        .font(PilcrowFonts.bodyF(11.5, .medium))
                        .foregroundStyle(p.node == nil ? LL.accent : LL.ink)
                        .lineLimit(1)
                }.buttonStyle(.plain)
                Text(p.driftLabel)
                    .font(PilcrowFonts.monoF(9.5))
                    .foregroundStyle(p.isAdrift ? LL.warn : LL.ink3)
            }
            .frame(width: 150, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(index % 2 == 0 ? Color.clear : LL.recessed.opacity(0.35))
    }

    private func toggleDone(_ beat: StructureBeat) {
        guard let i = store.manifest.structure.beats.firstIndex(where: { $0.id == beat.id })
        else { return }
        store.manifest.structure.beats[i].done.toggle()
        store.touchManifest()
    }

    // MARK: Sheets

    private var templatePicker: some View {
        let options = StructureTemplate.all(for: store.manifest.kind)
        return VStack(alignment: .leading, spacing: 0) {
            Text("STRUCTURE").font(PilcrowFonts.displayF(26)).tracking(1.1)
                .foregroundStyle(LL.ink)
            Text("A starting point, not a rule. Beats can be edited, skipped, or deleted, and applying one never touches your manuscript.")
                .font(PilcrowFonts.bodyF(12)).foregroundStyle(LL.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4).padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 7) {
                    ForEach(options) { t in
                        Button { apply(t) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 7) {
                                    Text(t.name)
                                        .font(PilcrowFonts.headingF(14, .bold))
                                        .foregroundStyle(LL.ink)
                                    if !t.attribution.isEmpty {
                                        Text(t.attribution)
                                            .font(PilcrowFonts.bodyF(10.5))
                                            .foregroundStyle(LL.ink3)
                                    }
                                    Spacer()
                                    if !t.beats.isEmpty {
                                        Pill(text: "\(t.beats.count) beats", tint: LL.ink3)
                                    }
                                }
                                Text(t.blurb)
                                    .font(PilcrowFonts.bodyF(11.5)).foregroundStyle(LL.ink2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(11)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(store.manifest.structure.templateID == t.id
                                      ? LL.accentSoft : LL.surface))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(
                                store.manifest.structure.templateID == t.id ? LL.accent : LL.rule,
                                lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Done") { picking = false }.llButton(.secondary)
            }.padding(.top, 12)
        }
        .padding(22)
        .frame(width: 560, height: 580)
        .background(LL.ground)
    }

    private func apply(_ t: StructureTemplate) {
        // Keep placements for beats whose names survive the swap.
        let old = Dictionary(store.manifest.structure.beats.map { ($0.name, $0) },
                             uniquingKeysWith: { a, _ in a })
        var fresh = StoryStructure.from(t)
        for i in fresh.beats.indices {
            if let prior = old[fresh.beats[i].name] {
                fresh.beats[i].nodeID = prior.nodeID
                fresh.beats[i].done = prior.done
            }
        }
        store.manifest.structure = fresh
        store.touchManifest()
        picking = false
    }

    private func placementSheet(_ beat: StructureBeat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Where does this land")
            Text(beat.name).font(PilcrowFonts.headingF(19, .bold)).foregroundStyle(LL.ink)
            if !beat.note.isEmpty {
                Text(beat.note).font(PilcrowFonts.bodyF(12)).foregroundStyle(LL.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                VStack(spacing: 0) {
                    Button { place(beat, nil) } label: {
                        rowLabel("\u{2014} not placed yet", selected: beat.nodeID == nil)
                    }.buttonStyle(.plain)
                    ForEach(docs) { doc in
                        Button { place(beat, doc.id) } label: {
                            rowLabel(doc.title, selected: beat.nodeID == doc.id)
                        }.buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 260)
            HStack { Spacer(); Button("Close") { placing = nil }.llButton(.secondary) }
        }
        .padding(20)
        .frame(width: 420)
        .background(LL.ground)
    }

    private func rowLabel(_ text: String, selected: Bool) -> some View {
        HStack {
            Text(text).font(PilcrowFonts.bodyF(12.5))
                .foregroundStyle(selected ? LL.accentInk : LL.ink)
            Spacer()
            if selected { Image(systemName: "checkmark").font(.system(size: 10)) }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(selected ? LL.accentSoft : .clear)
        .contentShape(Rectangle())
    }

    private func place(_ beat: StructureBeat, _ nodeID: UUID?) {
        guard let i = store.manifest.structure.beats.firstIndex(where: { $0.id == beat.id })
        else { return }
        store.manifest.structure.beats[i].nodeID = nodeID
        store.touchManifest()
        placing = nil
    }
}
