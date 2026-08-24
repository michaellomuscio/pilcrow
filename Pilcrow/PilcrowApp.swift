//  PilcrowApp.swift
//  Pilcrow — a book-writing environment.
//  Lomuscio Labs.

import SwiftUI
import AppKit
import Observation

// MARK: - Command bus
//
// Menu commands are broadcast and handled by whichever project window is
// frontmost. Simpler than threading focused values through every view, and
// it keeps the menu definitions declarative.

enum PilcrowCommand: String {
    case newScene, newChapter, deleteNode
    case bold, italic, h1, h2, h3, body, sceneBreak
    case toggleMode, focusOff, focusParagraph, focusSentence, toggleTypewriter
    case startSprint, endSession, snapshot
    case zoomIn, zoomOut, zoomReset
    case toggleBinder, toggleStudio, zenMode
    case compile, revealInFinder, saveNow
    case addComment, readAloud, stopReading, importSources
    case viewPage, viewCork, viewOutline, viewSpine, viewCast, viewNotes, viewEvidence, viewProgress
    case viewStructure, viewTimeline, viewContinuity, viewDiagnostics, viewAppointments

    static let name = Notification.Name("PilcrowCommand")
    func post() { NotificationCenter.default.post(name: Self.name, object: self.rawValue) }
}

extension View {
    func onPilcrowCommand(_ handler: @escaping (PilcrowCommand) -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: PilcrowCommand.name)) { note in
            if let raw = note.object as? String, let cmd = PilcrowCommand(rawValue: raw) {
                handler(cmd)
            }
        }
    }
}

// MARK: - App state

@Observable
@MainActor
final class AppState {
    var openStores: [String: ProjectStore] = [:]
    var lastError: String?

    func store(for url: URL) -> ProjectStore? { openStores[url.path] }

    func register(_ store: ProjectStore) { openStores[store.folder.path] = store }
    func unregister(_ url: URL) { openStores.removeValue(forKey: url.path) }
}

// MARK: - Opening from outside the app
//
// `open -a Pilcrow ~/Documents/Seven\ Days` and `Pilcrow --open <path>` both
// work, so a project folder can be opened from Finder or the shell.

enum PendingOpen {
    static let name = Notification.Name("PilcrowOpenFolder")
    static func request(_ url: URL) {
        NotificationCenter.default.post(name: name, object: url)
    }
}

final class PilcrowAppDelegate: NSObject, NSApplicationDelegate {
    /// Queued until a window exists to receive them.
    static var queued: [URL] = []

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.hasDirectoryPath {
            Self.queued.append(url)
            PendingOpen.request(url)
        }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
#if DEBUG
        maybeCaptureAndQuit()
#endif
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--open"), i + 1 < args.count {
            let url = URL(fileURLWithPath: (args[i + 1] as NSString).expandingTildeInPath)
            Self.queued.append(url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                PendingOpen.request(url)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }

#if DEBUG
    /// `--shot <dir> [--view <name>] [--delay <s>]` renders each open window to
    /// PNG and quits. The app drawing itself needs no screen-recording grant,
    /// which makes it the only reliable way to eyeball a build from a script.
    func maybeCaptureAndQuit() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--shot"), i + 1 < args.count else { return }
        let dir = args[i + 1]
        var delay = 4.0
        if let d = args.firstIndex(of: "--delay"), d + 1 < args.count,
           let v = Double(args[d + 1]) { delay = v }

        // Comma-separated, fired in order, so a sheet that needs prior state
        // (the session close sheet needs a running sprint) can be reached.
        if let v = args.firstIndex(of: "--view"), v + 1 < args.count {
            let steps = args[v + 1].split(separator: ",").compactMap {
                PilcrowCommand(rawValue: String($0))
            }
            for (i, cmd) in steps.enumerated() {
                let at = delay * 0.45 + Double(i) * 0.9
                DispatchQueue.main.asyncAfter(deadline: .now() + at) { cmd.post() }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            for (n, w) in NSApp.windows.enumerated() where w.isVisible && w.frame.width > 200 {
                guard let view = w.contentView,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                rep.size = view.bounds.size
                view.cacheDisplay(in: view.bounds, to: rep)
                guard let data = rep.representation(using: .png, properties: [:]) else { continue }
                let safe = w.title.isEmpty ? "window" : Slug.make(w.title)
                let url = URL(fileURLWithPath: dir).appendingPathComponent("\(n)-\(safe).png")
                try? data.write(to: url)
            }
            // exit() rather than NSApp.terminate(): a modal sheet blocks
            // termination, and sheets are exactly what we want to photograph.
            UserDefaults.standard.synchronize()
            exit(0)
        }
    }
#endif
}

// MARK: - App

@main
struct PilcrowApp: App {
    @State private var app = AppState()
    @NSApplicationDelegateAdaptor(PilcrowAppDelegate.self) private var delegate
    @Environment(\.openWindow) private var openWindow

    init() {
        PilcrowFonts.registerBundledFonts()
    }

    var body: some Scene {
        Window("Pilcrow", id: "library") {
            AcceptanceGate {
                LibraryView()
                    .environment(app)
                    .frame(minWidth: 820, minHeight: 560)
            }
                .onReceive(NotificationCenter.default.publisher(for: PendingOpen.name)) { note in
                    if let url = note.object as? URL {
                        openWindow(id: "project", value: url)
                    }
                }
                .task {
                    for url in PilcrowAppDelegate.queued { openWindow(id: "project", value: url) }
                    PilcrowAppDelegate.queued.removeAll()
                }
        }
        .defaultSize(width: 940, height: 620)
        .windowResizability(.contentMinSize)
        .commands { PilcrowCommands() }

        WindowGroup(id: "project", for: URL.self) { $url in
            AcceptanceGate {
                ProjectHost(url: url)
                    .environment(app)
                    .frame(minWidth: 900, minHeight: 600)
            }
        }
        .defaultSize(width: 1320, height: 880)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands { PilcrowCommands() }

        Settings {
            PreferencesView().environment(app)
        }
    }
}

// MARK: - Menus

struct PilcrowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project\u{2026}") { ProjectChooser.createFlow(openWindow) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Open Project\u{2026}") { ProjectChooser.openFlow(openWindow) }
                .keyboardShortcut("o")
            Divider()
            Button("New Scene") { PilcrowCommand.newScene.post() }
                .keyboardShortcut("n")
            Button("New Chapter") { PilcrowCommand.newChapter.post() }
                .keyboardShortcut("n", modifiers: [.command, .option])
            Divider()
            Button("Save Now") { PilcrowCommand.saveNow.post() }
                .keyboardShortcut("s")
            Button("Take Snapshot") { PilcrowCommand.snapshot.post() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Compile\u{2026}") { PilcrowCommand.compile.post() }
                .keyboardShortcut("e")
            Button("Reveal Project in Finder") { PilcrowCommand.revealInFinder.post() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .help) {
            Button("Pilcrow on the Web") {
                NSWorkspace.shared.open(URL(string: "https://michaellomuscio.com")!)
            }
            Divider()
            Button("Terms of Use") {
                DocumentWindow.show(title: "Terms of Use", markdown: Terms.document("TERMS"))
            }
            Button("Licence") {
                DocumentWindow.show(title: "Licence", markdown: Terms.document("LICENSE"))
            }
            Button("Trademark Policy") {
                DocumentWindow.show(title: "Trademarks", markdown: Terms.document("TRADEMARKS"))
            }
            Button("Notices \u{2014} Bundled Typefaces") {
                DocumentWindow.show(title: "Notices", markdown: Terms.document("NOTICE"))
            }
        }

        CommandMenu("Format") {
            Button("Bold") { PilcrowCommand.bold.post() }.keyboardShortcut("b")
            Button("Italic") { PilcrowCommand.italic.post() }.keyboardShortcut("i")
            Divider()
            Button("Title") { PilcrowCommand.h1.post() }.keyboardShortcut("1", modifiers: [.command, .option])
            Button("Heading") { PilcrowCommand.h2.post() }.keyboardShortcut("2", modifiers: [.command, .option])
            Button("Subheading") { PilcrowCommand.h3.post() }.keyboardShortcut("3", modifiers: [.command, .option])
            Button("Body") { PilcrowCommand.body.post() }.keyboardShortcut("0", modifiers: [.command, .option])
            Divider()
            Button("Scene Break") { PilcrowCommand.sceneBreak.post() }
                .keyboardShortcut(.return, modifiers: [.command])
            Divider()
            Button("Add Comment") { PilcrowCommand.addComment.post() }
                .keyboardShortcut("k", modifiers: [.command, .shift])
        }

        CommandMenu("Session") {
            Button("Start a Sprint\u{2026}") { PilcrowCommand.startSprint.post() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Button("Close the Session\u{2026}") { PilcrowCommand.endSession.post() }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Divider()
            Button("Read Aloud") { PilcrowCommand.readAloud.post() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Stop Reading") { PilcrowCommand.stopReading.post() }
            Divider()
            Button("Import Sources (CSL-JSON)\u{2026}") { PilcrowCommand.importSources.post() }
        }

        CommandGroup(after: .toolbar) {
            Button("Draft / Revise") { PilcrowCommand.toggleMode.post() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Divider()
            Button("The Page") { PilcrowCommand.viewPage.post() }.keyboardShortcut("1")
            Button("Corkboard") { PilcrowCommand.viewCork.post() }.keyboardShortcut("2")
            Button("Outliner") { PilcrowCommand.viewOutline.post() }.keyboardShortcut("3")
            Button("Spine Board") { PilcrowCommand.viewSpine.post() }.keyboardShortcut("4")
            Button("Cast") { PilcrowCommand.viewCast.post() }.keyboardShortcut("5")
            Button("Notes") { PilcrowCommand.viewNotes.post() }.keyboardShortcut("6")
            Button("Evidence") { PilcrowCommand.viewEvidence.post() }.keyboardShortcut("7")
            Button("Progress") { PilcrowCommand.viewProgress.post() }.keyboardShortcut("8")
            Button("Structure") { PilcrowCommand.viewStructure.post() }.keyboardShortcut("9")
            Button("Timeline") { PilcrowCommand.viewTimeline.post() }.keyboardShortcut("0")
            Button("Continuity") { PilcrowCommand.viewContinuity.post() }
            Button("Diagnostics") { PilcrowCommand.viewDiagnostics.post() }
            Button("Appointments") { PilcrowCommand.viewAppointments.post() }
            Divider()
            Button("Focus: Off") { PilcrowCommand.focusOff.post() }
            Button("Focus: Paragraph") { PilcrowCommand.focusParagraph.post() }
            Button("Focus: Sentence") { PilcrowCommand.focusSentence.post() }
            Button("Typewriter Scrolling") { PilcrowCommand.toggleTypewriter.post() }
            Divider()
            Button("Hide Binder") { PilcrowCommand.toggleBinder.post() }
                .keyboardShortcut("\\", modifiers: [.command])
            Button("Hide Studio") { PilcrowCommand.toggleStudio.post() }
                .keyboardShortcut("\\", modifiers: [.command, .shift])
            Button("Nothing But the Page") { PilcrowCommand.zenMode.post() }
                .keyboardShortcut("f", modifiers: [.command, .option])
            Divider()
            Button("Bigger Type") { PilcrowCommand.zoomIn.post() }.keyboardShortcut("+")
            Button("Smaller Type") { PilcrowCommand.zoomOut.post() }.keyboardShortcut("-")
        }
    }
}

// MARK: - Open / create flows

enum ProjectChooser {

    @MainActor
    static func openFlow(_ openWindow: OpenWindowAction) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a Pilcrow project folder."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openWindow(id: "project", value: url)
    }

    @MainActor
    static func createFlow(_ openWindow: OpenWindowAction) {
        NewProjectPanel.present { url in
            openWindow(id: "project", value: url)
        }
    }
}
