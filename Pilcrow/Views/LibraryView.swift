//  LibraryView.swift
//  The welcome window: start a book, open a book, or pick up where you left off.

import SwiftUI
import AppKit

struct LibraryView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var recents: [RecentProjects.Entry] = RecentProjects.all()
    @State private var error: String?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VRule()
            recentsPane
        }
        .background(LL.ground)
        .onAppear { recents = RecentProjects.all() }
        .alert("Couldn\u{2019}t open that", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }

    // MARK: Left

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PILCROW")
                    .font(PilcrowFonts.displayF(52))
                    .tracking(1.5)
                    .foregroundStyle(LL.ink)
                LabsBadge().padding(.top, 2)
            }
            .padding(.bottom, 22)

            Text("A gathering of folded sheets \u{2014} the unit a manuscript is assembled from.")
                .font(PilcrowFonts.bodyF(13))
                .foregroundStyle(LL.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 26)

            VStack(alignment: .leading, spacing: 9) {
                Button {
                    NewProjectPanel.present { url in
                        recents = RecentProjects.all()
                        openWindow(id: "project", value: url)
                    }
                } label: {
                    Label("Start a New Book", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .llButton(.accent)

                Button {
                    ProjectChooser.openFlow(openWindow)
                } label: {
                    Label("Open a Project Folder\u{2026}", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .llButton(.secondary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Rule()
                Text("Your writing is saved as plain Markdown files in a folder you choose. No database, no cloud, nothing to lock you in.")
                    .font(PilcrowFonts.bodyF(11))
                    .foregroundStyle(LL.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                HStack(spacing: 10) {
                    Button("Terms") {
                        DocumentWindow.show(title: "Terms of Use",
                                            markdown: Terms.document("TERMS"))
                    }
                    Button("Licence") {
                        DocumentWindow.show(title: "Licence",
                                            markdown: Terms.document("LICENSE"))
                    }
                }
                .buttonStyle(.plain)
                .font(PilcrowFonts.bodyF(10.5))
                .foregroundStyle(LL.ink3)
                .padding(.top, 2)
            }
        }
        .padding(30)
        .frame(width: 340)
    }

    // MARK: Right

    private var recentsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Recent")
            if recents.isEmpty {
                EmptyState(symbol: "book.closed",
                           title: "No books yet",
                           message: "Start one. Phase one is a chapter and a blank page \u{2014} everything else can wait until you need it.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(recents) { entry in
                            RecentRow(entry: entry) {
                                guard entry.exists else {
                                    error = "That folder has moved or been deleted.\n\n\(entry.path)"
                                    RecentProjects.forget(entry.path)
                                    recents = RecentProjects.all()
                                    return
                                }
                                openWindow(id: "project", value: entry.url)
                            } forget: {
                                RecentProjects.forget(entry.path)
                                recents = RecentProjects.all()
                            }
                            Rule()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LL.surface)
    }
}

private struct RecentRow: View {
    let entry: RecentProjects.Entry
    let open: () -> Void
    let forget: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(systemName: entry.kind.symbol)
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(entry.exists ? LL.accent : LL.ink3)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(PilcrowFonts.headingF(14.5, .bold))
                        .foregroundStyle(entry.exists ? LL.ink : LL.ink3)
                    Text(entry.url.deletingLastPathComponent().path
                        .replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(PilcrowFonts.monoF(10))
                        .foregroundStyle(LL.ink3)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer(minLength: 8)
                if !entry.exists {
                    Pill(text: "missing", tint: LL.crit)
                } else {
                    Text(entry.opened.formatted(.relative(presentation: .named)))
                        .font(PilcrowFonts.monoF(9.5))
                        .foregroundStyle(LL.ink3)
                }
                if hovering {
                    IconButton(symbol: "xmark", help: "Remove from this list", action: forget)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .background(hovering ? LL.accentSoft.opacity(0.6) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - New project

@MainActor
enum NewProjectPanel {
    private static var window: NSWindow?

    static func present(completion: @escaping (URL) -> Void) {
        if let w = window { w.makeKeyAndOrderFront(nil); return }
        let view = NewProjectView { url in
            window?.close(); window = nil
            if let url { completion(url) }
        }
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.title = "New Book"
        w.styleMask = [.titled, .closable]
        w.setContentSize(NSSize(width: 560, height: 520))
        w.center()
        w.isReleasedWhenClosed = false
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct NewProjectView: View {
    let done: (URL?) -> Void

    @State private var title = ""
    @State private var subtitle = ""
    @State private var author = NSFullUserName()
    @State private var kind: ProjectKind = .fiction
    @State private var parent: URL? = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask).first
    @State private var error: String?

    private var folderURL: URL? {
        guard let parent, !cleanTitle.isEmpty else { return nil }
        return parent.appendingPathComponent(Slug.make(cleanTitle))
    }
    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NEW BOOK")
                .font(PilcrowFonts.displayF(30)).tracking(1.2)
                .foregroundStyle(LL.ink)
                .padding(.bottom, 16)

            field("Title") {
                TextField("", text: $title, prompt: Text("The Cartographer's Error"))
                    .textFieldStyle(.plain)
                    .font(PilcrowFonts.headingF(17, .semibold))
            }
            field("Subtitle \u{2014} optional") {
                TextField("", text: $subtitle).textFieldStyle(.plain)
                    .font(PilcrowFonts.bodyF(13))
            }
            field("Author") {
                TextField("", text: $author).textFieldStyle(.plain)
                    .font(PilcrowFonts.bodyF(13))
            }

            Eyebrow(text: "What kind of book").padding(.top, 16).padding(.bottom, 8)
            HStack(spacing: 8) {
                ForEach(ProjectKind.allCases) { k in
                    kindCard(k)
                }
            }

            Eyebrow(text: "Where it lives").padding(.top, 18).padding(.bottom, 8)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(folderURL?.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
                         ?? "Choose a location\u{2026}")
                        .font(PilcrowFonts.monoF(10.5))
                        .foregroundStyle(folderURL == nil ? LL.ink3 : LL.ink)
                        .lineLimit(2)
                        .truncationMode(.head)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("Choose\u{2026}") { chooseParent() }.llButton(.secondary, compact: true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 6).fill(LL.recessed))

            if let error {
                Text(error)
                    .font(PilcrowFonts.bodyF(11.5))
                    .foregroundStyle(LL.crit)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            HStack {
                Text("A folder is created with your manuscript inside it as Markdown files.")
                    .font(PilcrowFonts.bodyF(10.5))
                    .foregroundStyle(LL.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button("Cancel") { done(nil) }.llButton(.ghost)
                Button("Create") { create() }
                    .llButton(.accent)
                    .disabled(cleanTitle.isEmpty || parent == nil)
            }
        }
        .padding(26)
        .frame(width: 560, height: 520)
        .background(LL.ground)
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Eyebrow(text: label)
            content()
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 5).fill(LL.surface))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(LL.rule, lineWidth: 1))
        }
        .padding(.bottom, 11)
    }

    private func kindCard(_ k: ProjectKind) -> some View {
        Button { kind = k } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: k.symbol)
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(kind == k ? LL.accent : LL.ink3)
                Text(k.label)
                    .font(PilcrowFonts.headingF(13.5, .bold))
                    .foregroundStyle(LL.ink)
                Text(k.blurb)
                    .font(PilcrowFonts.bodyF(10.5))
                    .foregroundStyle(LL.ink2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 6).fill(kind == k ? LL.accentSoft : LL.surface))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(kind == k ? LL.accent : LL.rule, lineWidth: kind == k ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func chooseParent() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Where should this book live?"
        if let parent { panel.directoryURL = parent }
        if panel.runModal() == .OK { self.parent = panel.url }
    }

    private func create() {
        guard let folderURL else { return }
        if FileManager.default.fileExists(atPath: folderURL.path) {
            error = "There\u{2019}s already something at \(folderURL.lastPathComponent). Pick another title or another location."
            return
        }
        do {
            let store = try ProjectStore.create(at: folderURL, title: cleanTitle,
                                               author: author, kind: kind)
            store.manifest.subtitle = subtitle
            store.touchManifest()
            try? store.saveNow()
            done(folderURL)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
