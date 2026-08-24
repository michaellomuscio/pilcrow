//  StudioModules.swift
//  Cast, Notes, Evidence.
//
//  Entity is both the character sheet and the source library — same object,
//  different field template. The Evidence Ledger is the one thing here that
//  has no fiction equivalent, and it is the reason a nonfiction author would
//  choose this over anything else on the market.

import SwiftUI
import AppKit

// MARK: - Cast

struct CastView: View {
    @Bindable var store: ProjectStore
    @State private var selected: UUID?

    private var labels: LabelPack { store.labels }
    private var defaultKind: EntityKind {
        store.manifest.kind == .nonfiction ? .source : .character
    }

    var body: some View {
        HStack(spacing: 0) {
            list
            VRule()
            if let id = selected, let idx = store.manifest.cast.firstIndex(where: { $0.id == id }) {
                EntityCard(entity: Binding(
                    get: { store.manifest.cast[idx] },
                    set: { store.manifest.cast[idx] = $0; store.touchManifest() }),
                           store: store,
                           delete: {
                               store.manifest.cast.removeAll { $0.id == id }
                               selected = store.manifest.cast.first?.id
                               store.touchManifest()
                           })
            } else {
                EmptyState(symbol: defaultKind.symbol,
                           title: "No \(labels.cast.lowercased()) selected",
                           message: store.manifest.kind == .nonfiction
                           ? "Sources carry citations, quotes with page anchors, and a permission status that Compile checks before it lets an unreleased quote out the door."
                           : "A character card holds the arc fields that matter \u{2014} want, need, the lie they believe, the wound underneath it.")
            }
        }
        .background(LL.ground)
        .onAppear { if selected == nil { selected = store.manifest.cast.first?.id } }
    }

    private var list: some View {
        VStack(spacing: 0) {
            PanelHeader(labels.cast) {
                Menu {
                    ForEach(EntityKind.allCases) { k in
                        Button(k.label) { add(k) }
                    }
                    Divider()
                    Button("Import CSL-JSON\u{2026}") { PilcrowCommand.importSources.post() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(LL.ink2)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22)
                .help("Add")
            }
            Rule()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.manifest.cast) { e in
                        Button { selected = e.id } label: {
                            HStack(spacing: 9) {
                                ZStack {
                                    Circle().fill(e.color.opacity(0.18)).frame(width: 26, height: 26)
                                    Image(systemName: e.kind.symbol)
                                        .font(.system(size: 10)).foregroundStyle(e.color)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(e.name).font(PilcrowFonts.bodyF(12.5, .medium))
                                        .foregroundStyle(LL.ink).lineLimit(1)
                                    if !e.role.isEmpty {
                                        Text(e.role).font(PilcrowFonts.bodyF(10.5))
                                            .foregroundStyle(LL.ink3).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 4)
                                if e.permission.isBlocking {
                                    Pill(text: "release", tint: LL.warn)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selected == e.id ? LL.accentSoft : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 260)
        .background(LL.surface)
    }

    private func add(_ kind: EntityKind) {
        var e = Entity(kind: kind, name: "New \(kind.label)")
        e.fields = Entity.template(for: kind)
        e.colorIndex = store.manifest.cast.count % 8
        if kind == .person || kind == .source { e.permission = .onRecord }
        store.manifest.cast.append(e)
        selected = e.id
        store.touchManifest()
    }
}

private struct EntityCard: View {
    @Binding var entity: Entity
    @Bindable var store: ProjectStore
    let delete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(entity.color.opacity(0.18)).frame(width: 46, height: 46)
                        Image(systemName: entity.kind.symbol)
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(entity.color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        TextField("", text: $entity.name)
                            .textFieldStyle(.plain)
                            .font(PilcrowFonts.headingF(22, .bold))
                            .foregroundStyle(LL.ink)
                        TextField("", text: $entity.role, prompt: Text("Role"))
                            .textFieldStyle(.plain)
                            .font(PilcrowFonts.bodyF(12))
                            .foregroundStyle(LL.ink2)
                    }
                    Spacer()
                    Menu {
                        ForEach(0..<8, id: \.self) { i in
                            Button("Colour \(i + 1)") { entity.colorIndex = i }
                        }
                        Divider()
                        Button("Delete", role: .destructive, action: delete)
                    } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton).frame(width: 30)
                }

                appearances

                if entity.kind == .source || entity.kind == .person {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: "Cite key")
                        HStack(spacing: 8) {
                            TextField("", text: $entity.citekey, prompt: Text("sword2016"))
                                .textFieldStyle(.plain)
                                .font(PilcrowFonts.monoF(12))
                                .padding(.horizontal, 9).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 5).fill(LL.surface))
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(LL.rule, lineWidth: 1))
                                .frame(width: 190)
                            if !entity.citekey.isEmpty {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString("[@\(entity.citekey)]",
                                                                   forType: .string)
                                } label: {
                                    Text("Copy [@\(entity.citekey)]")
                                        .font(PilcrowFonts.monoF(10.5))
                                }.llButton(.ghost, compact: true)
                            }
                            Spacer()
                        }
                        Text("Type [@\(entity.citekey.isEmpty ? "key" : entity.citekey)] in your prose \u{2014} or [@\(entity.citekey.isEmpty ? "key" : entity.citekey), p. 34] \u{2014} and Compile turns it into a note and a bibliography entry.")
                            .font(PilcrowFonts.bodyF(10.5)).foregroundStyle(LL.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !entity.csl.title.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Eyebrow(text: "As it will appear")
                            Text(CitationFormatter.bibliography(entity.csl,
                                                                style: store.manifest.citationStyle)
                                    .replacingOccurrences(of: "*", with: ""))
                                .font(PilcrowFonts.bodyF(11.5)).foregroundStyle(LL.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 5).fill(LL.recessed))
                    }
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow(text: "Permission")
                            Picker("", selection: $entity.permission) {
                                ForEach(PermissionStatus.allCases) { Text($0.label).tag($0) }
                            }.labelsHidden().controlSize(.small).frame(width: 150)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow(text: "Link")
                            TextField("", text: $entity.url, prompt: Text("https://"))
                                .textFieldStyle(.roundedBorder).controlSize(.small)
                                .font(PilcrowFonts.monoF(10.5))
                        }
                    }
                    field("Citation", text: $entity.citation, long: true)
                }

                field("Summary", text: $entity.summary, long: true)

                ForEach($entity.fields) { $f in
                    field(f.key, text: $f.value, long: f.long)
                }

                Button {
                    entity.fields.append(EntityField(key: "New field"))
                } label: { Label("Add a field", systemImage: "plus") }
                    .llButton(.ghost, compact: true)
            }
            .padding(22)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Which scenes this entity appears in — the fiction screen-time strip
    /// and the nonfiction "where does this source carry weight" view, same code.
    private var appearances: some View {
        let docs = store.orderedDocuments
        // Prose says "Nell"; the card says "Nell Kerrigan". Match the full
        // name, every name part long enough to be distinctive, and any alias.
        let needles: [String] = {
            var out = [entity.name]
            out += entity.name.split(separator: " ").map(String.init).filter { $0.count >= 3 }
            out += entity.aliases.filter { !$0.isEmpty }
            return Array(Set(out.filter { !$0.isEmpty }))
        }()
        let hits = docs.map { d in
            needles.contains {
                d.title.localizedCaseInsensitiveContains($0) ||
                store.body(d.id).localizedCaseInsensitiveContains($0)
            }
        }
        let count = hits.filter { $0 }.count
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Eyebrow(text: "Appears in")
                Spacer()
                Text("\(count) of \(docs.count)")
                    .font(PilcrowFonts.monoF(10)).foregroundStyle(LL.ink3)
            }
            HStack(spacing: 1.5) {
                ForEach(Array(hits.enumerated()), id: \.offset) { i, hit in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(hit ? entity.color : LL.rule)
                        .frame(height: 16)
                        .help(docs[i].title)
                }
            }
            if count > 0, let gap = longestGap(hits), gap >= 8 {
                Text("Absent for \(gap) consecutive sections. Worth a look.")
                    .font(PilcrowFonts.bodyF(10.5)).foregroundStyle(LL.warn)
            }
        }
    }

    private func longestGap(_ hits: [Bool]) -> Int? {
        var best = 0, run = 0, seen = false
        for h in hits {
            if h { seen = true; best = max(best, run); run = 0 }
            else if seen { run += 1 }
        }
        return best
    }

    private func field(_ title: String, text: Binding<String>, long: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: title)
            if long {
                TextEditor(text: text)
                    .font(PilcrowFonts.bodyF(12.5))
                    .scrollContentBackground(.hidden)
                    .frame(height: 54)
                    .padding(7)
                    .background(RoundedRectangle(cornerRadius: 5).fill(LL.surface))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(LL.rule, lineWidth: 1))
            } else {
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .font(PilcrowFonts.bodyF(12.5))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 5).fill(LL.surface))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(LL.rule, lineWidth: 1))
            }
        }
    }
}

// MARK: - Notes

struct NotesView: View {
    @Bindable var store: ProjectStore
    @State private var canvas = false
    @State private var selected: UUID?

    private var labels: LabelPack { store.labels }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(labels.notes.uppercased())
                    .font(PilcrowFonts.displayF(20)).tracking(0.9).foregroundStyle(LL.ink)
                Spacer()
                Picker("", selection: $canvas) {
                    Text("Cards").tag(false)
                    Text("Mind Map").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 156)
                Button { add() } label: { Label("New", systemImage: "plus") }
                    .llButton(.accent, compact: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Rule()

            if store.manifest.notes.isEmpty {
                EmptyState(symbol: "lightbulb", title: "No \(labels.notes.lowercased()) yet",
                           message: "The idea-shaped view that comes before structure. Cards here can link to each other and to \(labels.leaf.lowercased())s.",
                           actionLabel: "Write one down") { add() }
            } else if canvas {
                mindMap
            } else {
                cards
            }
        }
        .background(LL.ground)
    }

    private var cards: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 300), spacing: 14)],
                      spacing: 14) {
                ForEach($store.manifest.notes) { $note in
                    NoteCardView(note: $note, onCommit: { store.touchManifest() },
                                 onDelete: {
                                     store.manifest.notes.removeAll { $0.id == note.id }
                                     store.touchManifest()
                                 })
                }
            }
            .padding(18)
        }
    }

    private var mindMap: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { ctx, _ in
                    // Links first so cards sit on top of their own threads.
                    for n in store.manifest.notes {
                        for target in n.linkedNoteIDs {
                            guard let t = store.manifest.notes.first(where: { $0.id == target }) else { continue }
                            var path = Path()
                            path.move(to: CGPoint(x: n.x + 90, y: n.y + 40))
                            path.addLine(to: CGPoint(x: t.x + 90, y: t.y + 40))
                            ctx.stroke(path, with: .color(LL.ruleStrong), lineWidth: 1)
                        }
                    }
                }
                ForEach($store.manifest.notes) { $note in
                    MindMapCard(note: $note, selected: selected == note.id) {
                        selected = (selected == note.id ? nil : note.id)
                    } moved: { store.touchManifest() } link: {
                        if let s = selected, s != note.id {
                            if let i = store.manifest.notes.firstIndex(where: { $0.id == s }) {
                                if store.manifest.notes[i].linkedNoteIDs.contains(note.id) {
                                    store.manifest.notes[i].linkedNoteIDs.removeAll { $0 == note.id }
                                } else {
                                    store.manifest.notes[i].linkedNoteIDs.append(note.id)
                                }
                                store.touchManifest()
                            }
                        }
                    }
                    .position(x: note.x + 90, y: note.y + 40)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture { selected = nil }
        }
    }

    private func add() {
        var n = NoteCard(title: "Untitled \(labels.notesOne)")
        n.colorIndex = store.manifest.notes.count % 8
        n.x = Double.random(in: 60...420)
        n.y = Double.random(in: 60...300)
        store.manifest.notes.append(n)
        store.touchManifest()
    }
}

private struct NoteCardView: View {
    @Binding var note: NoteCard
    let onCommit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1).fill(note.color).frame(width: 3, height: 15)
                TextField("", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(PilcrowFonts.headingF(13.5, .bold))
                    .foregroundStyle(LL.ink)
                    .onSubmit(onCommit)
                Menu {
                    ForEach(0..<8, id: \.self) { i in Button("Colour \(i + 1)") { note.colorIndex = i; onCommit() } }
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).frame(width: 22)
            }
            TextEditor(text: $note.body)
                .font(PilcrowFonts.bodyF(11.5))
                .scrollContentBackground(.hidden)
                .frame(height: 96)
                .onChange(of: note.body) { _, _ in onCommit() }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }
}

private struct MindMapCard: View {
    @Binding var note: NoteCard
    let selected: Bool
    let tap: () -> Void
    let moved: () -> Void
    let link: () -> Void

    @State private var drag: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(PilcrowFonts.headingF(12.5, .bold))
                .foregroundStyle(LL.ink).lineLimit(1)
            Text(note.body)
                .font(PilcrowFonts.bodyF(10.5))
                .foregroundStyle(LL.ink2).lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(9)
        .frame(width: 180, height: 80, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6)
            .strokeBorder(selected ? LL.accent : note.color.opacity(0.5),
                          lineWidth: selected ? 2 : 1))
        .offset(drag)
        .gesture(
            DragGesture()
                .onChanged { drag = $0.translation }
                .onEnded { v in
                    note.x += v.translation.width
                    note.y += v.translation.height
                    drag = .zero
                    moved()
                }
        )
        .onTapGesture(count: 2, perform: link)
        .onTapGesture(perform: tap)
    }
}

// MARK: - Evidence ledger

struct EvidenceView: View {
    @Bindable var store: ProjectStore
    @State private var weakOnly = false
    @State private var editing: Claim?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("EVIDENCE").font(PilcrowFonts.displayF(20)).tracking(0.9)
                    .foregroundStyle(LL.ink)
                if weakCount > 0 {
                    Pill(text: "\(weakCount) weak", tint: LL.warn, filled: true)
                }
                Spacer()
                Toggle(isOn: $weakOnly) {
                    Text("Weak links only").font(PilcrowFonts.bodyF(11.5))
                }.toggleStyle(.checkbox).controlSize(.small)
                Button { addClaim() } label: { Label("Add claim", systemImage: "plus") }
                    .llButton(.accent, compact: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Rule()

            if store.manifest.claims.isEmpty {
                EmptyState(symbol: "checkmark.seal",
                           title: "No claims logged yet",
                           message: "Every claim your book makes, mapped to the sources that support it. Then one view shows you which ones are carrying more weight than their evidence can bear \u{2014} before a fact-checker does.",
                           actionLabel: "Log the first claim") { addClaim() }
            } else {
                table
            }
        }
        .background(LL.ground)
        .sheet(item: $editing) { claim in
            ClaimEditor(claim: claim, store: store) { updated in
                if let i = store.manifest.claims.firstIndex(where: { $0.id == updated.id }) {
                    store.manifest.claims[i] = updated
                    store.touchManifest()
                }
                editing = nil
            } delete: {
                store.manifest.claims.removeAll { $0.id == claim.id }
                store.touchManifest()
                editing = nil
            }
        }
    }

    private var weakCount: Int { store.manifest.claims.filter(\.isWeak).count }

    private var shown: [Claim] {
        let base = weakOnly ? store.manifest.claims.filter(\.isWeak) : store.manifest.claims
        return base.sorted { $0.strength.severity < $1.strength.severity }
    }

    private var table: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    head("Claim", 400)
                    head("Where", 150)
                    head("Sources", 160)
                    head("Support", 110)
                    head("Status", 110)
                }
                .frame(height: 34).background(LL.recessed)
                .overlay(alignment: .bottom) { Rule() }

                ForEach(Array(shown.enumerated()), id: \.element.id) { i, c in
                    Button { editing = c } label: {
                        HStack(spacing: 0) {
                            Text(c.text.isEmpty ? "Untitled claim" : c.text)
                                .font(PilcrowFonts.bodyF(12)).foregroundStyle(LL.ink)
                                .lineLimit(2).multilineTextAlignment(.leading)
                                .frame(width: 400, alignment: .leading).padding(.horizontal, 12)
                            Text(store.node(c.nodeID ?? UUID())?.title ?? "\u{2014}")
                                .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink2)
                                .lineLimit(1).frame(width: 150, alignment: .leading).padding(.horizontal, 10)
                            Text(sourceNames(c))
                                .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink2)
                                .lineLimit(2).frame(width: 160, alignment: .leading).padding(.horizontal, 10)
                            HStack { Pill(text: c.strength.label, tint: c.strength.tint) }
                                .frame(width: 110, alignment: .leading).padding(.horizontal, 10)
                            HStack { Pill(text: c.status.label, tint: c.status.tint) }
                                .frame(width: 110, alignment: .leading).padding(.horizontal, 10)
                        }
                        .frame(height: 46)
                        .background(i % 2 == 0 ? Color.clear : LL.recessed.opacity(0.4))
                        .overlay(alignment: .bottom) { Rule() }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sourceNames(_ c: Claim) -> String {
        let names = c.sourceIDs.compactMap { id in
            store.manifest.cast.first { $0.id == id }?.name
        }
        return names.isEmpty ? "\u{2014}" : names.joined(separator: ", ")
    }

    private func head(_ t: String, _ w: CGFloat) -> some View {
        Text(t.uppercased()).font(PilcrowFonts.monoF(9.5)).tracking(1.1)
            .foregroundStyle(LL.ink3)
            .frame(width: w, alignment: .leading).padding(.horizontal, 12)
    }

    private func addClaim() {
        let c = Claim(text: "", nodeID: store.selection)
        store.manifest.claims.append(c)
        store.touchManifest()
        editing = c
    }
}

private struct ClaimEditor: View {
    @State var claim: Claim
    @Bindable var store: ProjectStore
    let save: (Claim) -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("CLAIM").font(PilcrowFonts.displayF(24)).tracking(1).foregroundStyle(LL.ink)

            TextEditor(text: $claim.text)
                .font(PilcrowFonts.bodyF(14))
                .scrollContentBackground(.hidden)
                .frame(height: 70).padding(8)
                .background(RoundedRectangle(cornerRadius: 5).fill(LL.surface))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(LL.rule, lineWidth: 1))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Support strength")
                    Picker("", selection: $claim.strength) {
                        ForEach(Strength.allCases) { Text($0.label).tag($0) }
                    }.labelsHidden().controlSize(.small).frame(width: 150)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Fact-check status")
                    Picker("", selection: $claim.status) {
                        ForEach(FactStatus.allCases) { Text($0.label).tag($0) }
                    }.labelsHidden().controlSize(.small).frame(width: 150)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "Where it appears")
                Picker("", selection: Binding(
                    get: { claim.nodeID ?? UUID() },
                    set: { claim.nodeID = $0 })) {
                        Text("\u{2014}").tag(UUID())
                        ForEach(store.orderedDocuments) { Text($0.title).tag($0.id) }
                    }.labelsHidden().controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 5) {
                Eyebrow(text: "Supported by")
                if store.manifest.cast.filter({ $0.kind == .source || $0.kind == .person }).isEmpty {
                    Text("No sources in the cast yet. Add one there and it becomes selectable here.")
                        .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3)
                } else {
                    ForEach(store.manifest.cast.filter { $0.kind == .source || $0.kind == .person }) { s in
                        Toggle(isOn: Binding(
                            get: { claim.sourceIDs.contains(s.id) },
                            set: { on in
                                if on { claim.sourceIDs.append(s.id) }
                                else { claim.sourceIDs.removeAll { $0 == s.id } }
                            })) {
                                Text(s.name).font(PilcrowFonts.bodyF(11.5))
                            }.toggleStyle(.checkbox).controlSize(.small)
                    }
                }
            }

            HStack {
                Button("Delete", role: .destructive, action: delete).llButton(.ghost)
                Spacer()
                Button("Save") { save(claim) }.llButton(.accent)
            }
        }
        .padding(22)
        .frame(width: 480)
        .background(LL.ground)
    }
}
