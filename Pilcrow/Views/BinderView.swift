//  BinderView.swift
//  The left rail: the shape of the book.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct BinderView: View {
    @Bindable var store: ProjectStore
    var session: SessionEngine

    @State private var expanded: Set<UUID> = []
    @State private var renaming: UUID?
    @State private var draft = ""
    @State private var filter = ""
    @State private var dropTarget: UUID?

    private var labels: LabelPack { store.labels }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rule()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleRows, id: \.node.id) { r in
                        row(r.node, depth: r.depth)
                    }
                }
                .padding(.vertical, 4)
            }
            Rule()
            footer
        }
        .background(LL.surface)
        .onAppear {
            // Chapters open by default — the shape of the book should be
            // visible the moment you sit down.
            expanded = Set(store.manifest.root.children.filter(\.isFolder).map(\.id))
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Eyebrow(text: "Manuscript")
                Spacer()
                IconButton(symbol: "plus.rectangle", help: "New \(labels.leaf) (\u{2318}N)") {
                    PilcrowCommand.newScene.post()
                }
                IconButton(symbol: "folder.badge.plus", help: "New \(labels.container)") {
                    PilcrowCommand.newChapter.post()
                }
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 7)

            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 9))
                    .foregroundStyle(LL.ink3)
                TextField("", text: $filter, prompt: Text("Filter").font(PilcrowFonts.bodyF(11)))
                    .textFieldStyle(.plain)
                    .font(PilcrowFonts.bodyF(11.5))
                if !filter.isEmpty {
                    IconButton(symbol: "xmark.circle.fill", help: "Clear") { filter = "" }
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5).fill(LL.recessed))
            .padding(.horizontal, 10).padding(.bottom, 9)
        }
    }

    // MARK: Rows
    //
    // Flattened rather than recursive: a recursive `some View` can't name its
    // own opaque type, and a flat list is what LazyVStack actually wants.

    private struct VisibleRow { let node: Node; let depth: Int }

    private var visibleRows: [VisibleRow] {
        var out: [VisibleRow] = []
        let searching = !filter.isEmpty

        func matches(_ n: Node) -> Bool {
            guard searching else { return true }
            return n.title.localizedCaseInsensitiveContains(filter)
                || n.flattened.contains { $0.title.localizedCaseInsensitiveContains(filter) }
        }
        func walk(_ n: Node, _ d: Int) {
            for child in n.children where matches(child) {
                out.append(VisibleRow(node: child, depth: d))
                if child.isFolder && (expanded.contains(child.id) || searching) {
                    walk(child, d + 1)
                }
            }
        }
        walk(store.manifest.root, 0)
        return out
    }

    private func row(_ node: Node, depth: Int) -> some View {
        BinderRow(
            node: node, depth: depth,
            selected: store.selection == node.id,
            expanded: expanded.contains(node.id),
            dropping: dropTarget == node.id,
            renaming: renaming == node.id,
            draft: $draft,
            labels: labels,
            toggle: {
                if expanded.contains(node.id) { expanded.remove(node.id) }
                else { expanded.insert(node.id) }
            },
            select: { store.selection = node.id },
            commitRename: {
                let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { store.rename(node.id, to: t) }
                renaming = nil
            }
        )
        .contextMenu { menu(node) }
        .draggable(node.id.uuidString) {
            Text(node.title).font(PilcrowFonts.bodyF(12)).padding(6)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let dragged = UUID(uuidString: raw),
                  dragged != node.id else { return false }
            // Never drop a folder into its own subtree.
            if store.node(dragged)?.find(node.id) != nil { return false }
            if node.isFolder && expanded.contains(node.id) {
                store.move(dragged, to: node.id, at: 0)
            } else {
                let parent = store.manifest.root.parentID(of: node.id)
                let siblings = (parent.flatMap { store.node($0) } ?? store.manifest.root).children
                let idx = (siblings.firstIndex { $0.id == node.id } ?? 0) + 1
                store.move(dragged, to: parent, at: idx)
            }
            return true
        } isTargeted: { dropTarget = $0 ? node.id : nil }
    }

    @ViewBuilder
    private func menu(_ node: Node) -> some View {
        Button("Rename") { draft = node.title; renaming = node.id }
        if node.isFolder {
            Button("New \(labels.leaf) Inside") {
                store.selection = store.addDocument(title: "Untitled \(labels.leaf)", parent: node.id)
            }
        }
        Divider()
        Menu("Status") {
            ForEach(NodeStatus.allCases) { s in
                Button(s.label) {
                    _ = store.manifest.root.update(node.id) { $0.status = s }
                    store.touchManifest()
                }
            }
        }
        Button(node.includeInCompile ? "Exclude from Compile" : "Include in Compile") {
            _ = store.manifest.root.update(node.id) { $0.includeInCompile.toggle() }
            store.touchManifest()
        }
        Divider()
        Button("Reveal in Finder") {
            if let u = store.url(for: node.id) {
                NSWorkspace.shared.activateFileViewerSelecting([u])
            }
        }
        Divider()
        Button("Move to Trash", role: .destructive) { store.delete(node.id) }
    }

    // MARK: Footer

    private var footer: some View {
        let total = store.totalWords
        let target = store.manifest.wordTarget
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(total.grouped)
                    .font(PilcrowFonts.monoF(13, .medium))
                    .foregroundStyle(LL.ink)
                Text("words")
                    .font(PilcrowFonts.bodyF(10.5)).foregroundStyle(LL.ink3)
                Spacer()
                if target > 0 {
                    Text("\(Int(Double(total) / Double(target) * 100))%")
                        .font(PilcrowFonts.monoF(10.5))
                        .foregroundStyle(LL.accent)
                }
            }
            if target > 0 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(LL.rule).frame(height: 4)
                        Capsule().fill(LL.accent)
                            .frame(width: g.size.width * min(1, Double(total) / Double(target)),
                                   height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }
}

// MARK: - Row

private struct BinderRow: View {
    let node: Node
    let depth: Int
    let selected: Bool
    let expanded: Bool
    let dropping: Bool
    let renaming: Bool
    @Binding var draft: String
    let labels: LabelPack
    let toggle: () -> Void
    let select: () -> Void
    let commitRename: () -> Void

    @State private var hovering = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 5) {
            if node.isFolder {
                Button(action: toggle) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(LL.ink3)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 11)
                }
                .buttonStyle(.plain)
            } else {
                StatusDot(status: node.status).frame(width: 11)
            }

            Image(systemName: node.isFolder ? "folder" : "doc.text")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(selected ? LL.accent : LL.ink3)

            if renaming {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(PilcrowFonts.bodyF(12))
                    .focused($fieldFocused)
                    .onSubmit(commitRename)
                    .onAppear { fieldFocused = true }
                    .onExitCommand(perform: commitRename)
            } else {
                Text(node.title)
                    .font(PilcrowFonts.bodyF(12, node.isFolder ? .semibold : .regular))
                    .foregroundStyle(selected ? LL.ink : (node.includeInCompile ? LL.ink : LL.ink3))
                    .lineLimit(1)
                    .strikethrough(!node.includeInCompile, color: LL.ink3)
            }

            Spacer(minLength: 4)

            if hovering || selected {
                Text((node.isFolder ? node.totalWords : node.wordCount).grouped)
                    .font(PilcrowFonts.monoF(9))
                    .foregroundStyle(LL.ink3)
            }
        }
        .padding(.leading, CGFloat(depth) * 13 + 10)
        .padding(.trailing, 9)
        .padding(.vertical, 4.5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(selected ? LL.accentSoft : (hovering ? LL.recessed.opacity(0.7) : .clear))
                .padding(.horizontal, 4)
        )
        .overlay(alignment: .bottom) {
            if dropping {
                Rectangle().fill(LL.accent).frame(height: 2).padding(.horizontal, 6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if node.isFolder { toggle() } }
        .onTapGesture { select() }
        .onHover { hovering = $0 }
    }
}
