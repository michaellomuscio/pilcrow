//  CraftViews.swift
//  Continuity, Diagnostics, Appointments.

import SwiftUI
import AppKit

// MARK: - Continuity

struct ContinuityView: View {
    @Bindable var store: ProjectStore
    @State private var adding = false

    private var labels: LabelPack { store.labels }

    private var issues: [ContinuityIssue] {
        ContinuityCheck.run(facts: store.manifest.facts,
                            cast: store.manifest.cast,
                            notes: store.manifest.notes,
                            documents: store.orderedDocuments,
                            body: { store.body($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("CONTINUITY").font(PilcrowFonts.displayF(20)).tracking(0.9)
                    .foregroundStyle(LL.ink)
                if issues.isEmpty && !store.manifest.facts.isEmpty {
                    Pill(text: "nothing flagged", tint: LL.ok)
                } else if !issues.isEmpty {
                    Pill(text: "\(issues.count) to look at", tint: LL.warn)
                }
                Spacer()
                Button { adding = true } label: { Label("Record a fact", systemImage: "plus") }
                    .llButton(.accent, compact: true)
                    .disabled(store.manifest.cast.isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Rule()

            if store.manifest.cast.isEmpty {
                EmptyState(symbol: "person.fill.questionmark",
                           title: "No \(labels.cast.lowercased()) yet",
                           message: "Continuity is tracked against the cast. Add a \(labels.castOne.lowercased()) first, then record what's true about them \u{2014} eye colour, age, the year they met.")
            } else if store.manifest.facts.isEmpty {
                EmptyState(symbol: "checkmark.rectangle.stack",
                           title: "Nothing recorded yet",
                           message: "Record what has to stay true. Pilcrow flags contradictions, near-identical names, and terms used before you define them \u{2014} it never corrects anything for you, because a contradiction is sometimes the point.",
                           actionLabel: "Record the first fact") { adding = true }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !issues.isEmpty { issueList }
                        factTable
                    }
                    .padding(18)
                    .frame(maxWidth: 900, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(LL.ground)
        .sheet(isPresented: $adding) { factEditor }
    }

    private var issueList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Worth a look").padding(.bottom, 8)
            ForEach(issues) { issue in
                HStack(alignment: .top, spacing: 10) {
                    Pill(text: issue.label, tint: issue.tint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(issue.entityName) \u{2014} \(issue.detail)")
                            .font(PilcrowFonts.bodyF(12.5, .medium))
                            .foregroundStyle(LL.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if !issue.where_.isEmpty {
                            Text(issue.where_.joined(separator: "  \u{00B7}  "))
                                .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 9)
                Rule()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    private var factTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "The ledger").padding(.bottom, 8)
            ForEach(store.manifest.facts) { fact in
                let name = store.manifest.cast.first { $0.id == fact.entityID }?.name ?? "\u{2014}"
                HStack(spacing: 10) {
                    Text(name).font(PilcrowFonts.bodyF(12, .medium))
                        .foregroundStyle(LL.ink).frame(width: 130, alignment: .leading)
                    Text(fact.key).font(PilcrowFonts.monoF(10.5))
                        .foregroundStyle(LL.ink3).frame(width: 110, alignment: .leading)
                    Text(fact.value).font(PilcrowFonts.bodyF(12))
                        .foregroundStyle(LL.ink)
                    Spacer(minLength: 6)
                    if let n = fact.nodeID, let doc = store.node(n) {
                        Text(doc.title).font(PilcrowFonts.monoF(9.5))
                            .foregroundStyle(LL.ink3).lineLimit(1)
                    }
                    Toggle("", isOn: Binding(
                        get: { fact.accepted },
                        set: { v in
                            if let i = store.manifest.facts.firstIndex(where: { $0.id == fact.id }) {
                                store.manifest.facts[i].accepted = v
                                store.touchManifest()
                            }
                        }))
                        .toggleStyle(.checkbox).controlSize(.mini)
                        .help("Accepted \u{2014} stop flagging this one")
                    IconButton(symbol: "trash", help: "Remove") {
                        store.manifest.facts.removeAll { $0.id == fact.id }
                        store.touchManifest()
                    }
                }
                .padding(.vertical, 7)
                Rule()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    @State private var newEntity: UUID?
    @State private var newKey = ""
    @State private var newValue = ""

    private var factEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A FACT").font(PilcrowFonts.displayF(24)).tracking(1).foregroundStyle(LL.ink)
            Text("Something that has to stay true across four hundred pages.")
                .font(PilcrowFonts.bodyF(12)).foregroundStyle(LL.ink2)

            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: labels.castOne)
                Picker("", selection: Binding(
                    get: { newEntity ?? store.manifest.cast.first?.id ?? UUID() },
                    set: { newEntity = $0 })) {
                        ForEach(store.manifest.cast) { Text($0.name).tag($0.id) }
                    }.labelsHidden().controlSize(.small)
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Attribute")
                    TextField("", text: $newKey, prompt: Text("eyes"))
                        .textFieldStyle(.roundedBorder).controlSize(.small)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Value")
                    TextField("", text: $newValue, prompt: Text("brown"))
                        .textFieldStyle(.roundedBorder).controlSize(.small)
                }
            }
            Text("Record a second value for the same attribute and Pilcrow will flag the pair. It never edits your prose.")
                .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel") { adding = false }.llButton(.ghost)
                Button("Record") {
                    let eid = newEntity ?? store.manifest.cast.first?.id
                    guard let eid, !newKey.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    store.manifest.facts.append(Fact(
                        entityID: eid,
                        key: newKey.trimmingCharacters(in: .whitespaces),
                        value: newValue.trimmingCharacters(in: .whitespaces),
                        nodeID: store.selection))
                    store.touchManifest()
                    newKey = ""; newValue = ""; adding = false
                }.llButton(.accent)
            }
        }
        .padding(22)
        .frame(width: 460)
        .background(LL.ground)
    }
}

// MARK: - Diagnostics

struct DiagnosticsView: View {
    @Bindable var store: ProjectStore
    @State private var wholeBook = false
    @State private var report = ProseReport()
    @State private var pacing: [PacingPoint] = []
    @State private var working = false

    private var target: Node? { store.node(store.selection) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("DIAGNOSTICS").font(PilcrowFonts.displayF(20)).tracking(0.9)
                    .foregroundStyle(LL.ink)
                Spacer()
                Picker("", selection: $wholeBook) {
                    Text(target?.title ?? "This document").tag(false)
                    Text("Whole book").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 260)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Rule()

            if working {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if report.words == 0 {
                EmptyState(symbol: "waveform.path.ecg",
                           title: "Nothing to measure yet",
                           message: "Write something and this pane will show you the patterns you can't see from inside the sentence you're currently writing.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headline
                        rhythm
                        HStack(alignment: .top, spacing: 14) {
                            wordList("Crutch words", report.crutchWords, LL.accent,
                                     "Your most-used distinctive words. Not wrong \u{2014} just yours.")
                            wordList("Filter words", report.filterWords, LL.warn,
                                     "Words that put a pane of glass between the reader and the thing.")
                            wordList("Adverbs", report.adverbs, LL.chartColor(5),
                                     "\(Int(report.adverbRate)) per 1,000 words.")
                        }
                        if !report.repetitions.isEmpty { repetitions }
                        if wholeBook && !pacing.isEmpty { pacingCurve }
                        caveat
                    }
                    .padding(18)
                    .frame(maxWidth: 980, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(LL.ground)
        .task(id: taskKey) { await run() }
    }

    private var taskKey: String {
        "\(wholeBook)|\(store.selection?.uuidString ?? "")|\(store.totalWords)"
    }

    private func run() async {
        working = true
        let text: String = wholeBook
            ? store.orderedDocuments.map { store.body($0.id) }.joined(separator: "\n\n")
            : store.body(store.selection ?? UUID())
        let docs = store.orderedDocuments
        let bodies = Dictionary(uniqueKeysWithValues: docs.map { ($0.id, store.body($0.id)) })
        let wantPacing = wholeBook

        // Analysis on a book-sized string is too slow for the main thread.
        let result: (ProseReport, [PacingPoint]) = await Task.detached(priority: .userInitiated) {
            let r = Prose.analyse(text)
            let p = wantPacing ? Pacing.across(documents: docs, body: { bodies[$0] ?? "" }) : []
            return (r, p)
        }.value

        report = result.0
        pacing = result.1
        working = false
    }

    private var headline: some View {
        HStack(spacing: 0) {
            stat(report.words.grouped, "words")
            div; stat("\(report.sentences.grouped)", "sentences")
            div; stat(String(format: "%.1f", report.meanSentence), "mean length")
            div; stat(String(format: "%.1f", report.sentenceStdDev), "variance",
                      report.sentenceStdDev < 4 ? LL.warn : LL.ink)
            div; stat("\(Int(report.dialogueShare * 100))%", "dialogue")
            div; stat("\(report.readingTimeMinutes)m", "to read aloud")
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    private var div: some View { Rectangle().fill(LL.rule).frame(width: 1, height: 40) }

    private func stat(_ v: String, _ c: String, _ tint: Color = LL.ink) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(v).font(PilcrowFonts.headingF(18, .heavy)).foregroundStyle(tint)
                .monospacedDigit()
            Eyebrow(text: c)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 13)
    }

    private var rhythm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: "Sentence rhythm")
                Spacer()
                if report.longestMonotoneRun >= 6 {
                    Pill(text: "\(report.longestMonotoneRun) in a row, same length", tint: LL.warn)
                }
            }
            Sparkbars(values: report.sentenceLengths.map(Double.init),
                      tint: LL.accent, height: 56, highlightLast: false)
            HStack(spacing: 16) {
                Text("Longest: \(report.sentenceLengths.max() ?? 0) words")
                    .font(PilcrowFonts.monoF(10)).foregroundStyle(LL.ink3)
                Text("Shortest: \(report.sentenceLengths.min() ?? 0)")
                    .font(PilcrowFonts.monoF(10)).foregroundStyle(LL.ink3)
                Text("Passive: \(report.passiveCount) (\(Int(report.passiveRate * 100))% of sentences, heuristic)")
                    .font(PilcrowFonts.monoF(10)).foregroundStyle(LL.ink3)
                Spacer()
            }
            if report.sentenceStdDev < 4 && report.sentences > 12 {
                Text("Low variance. Every sentence is about the same length, which reads as flat even when each one is good.")
                    .font(PilcrowFonts.bodyF(11.5)).foregroundStyle(LL.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !report.longestSentence.isEmpty && (report.sentenceLengths.max() ?? 0) > 45 {
                Text("\u{201C}\(report.longestSentence.prefix(180))\u{2026}\u{201D}")
                    .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    private func wordList(_ title: String, _ items: [(String, Int)],
                          _ tint: Color, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Eyebrow(text: title)
            if items.isEmpty {
                Text("None.").font(PilcrowFonts.bodyF(11.5)).foregroundStyle(LL.ink3)
            } else {
                let maxN = Double(items.first?.1 ?? 1)
                ForEach(items.prefix(8), id: \.0) { w, n in
                    BarRow(label: "\(n)", value: Double(n), max: maxN,
                           caption: w, tint: tint, labelWidth: 22, captionWidth: 96)
                }
            }
            Text(caption).font(PilcrowFonts.bodyF(10.5)).foregroundStyle(LL.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    private var repetitions: some View {
        VStack(alignment: .leading, spacing: 7) {
            Eyebrow(text: "Repetition radar")
            ForEach(report.repetitions.prefix(8)) { r in
                HStack(alignment: .top, spacing: 8) {
                    Pill(text: r.word, tint: LL.chartColor(2))
                    Text(r.context).font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink2)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Text("\(r.gap) words apart")
                        .font(PilcrowFonts.monoF(9.5)).foregroundStyle(LL.ink3)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    private var pacingCurve: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Pacing across the book")
            Sparkbars(values: pacing.map { Double($0.words) }, tint: LL.accent,
                      height: 52, highlightLast: false)
            Text("Scene length.")
                .font(PilcrowFonts.monoF(9.5)).foregroundStyle(LL.ink3)
            Sparkbars(values: pacing.map { $0.dialogueShare }, tint: LL.chartColor(1),
                      height: 40, highlightLast: false)
            Text("Dialogue share. A long run of near-zero bars is a stretch with nobody speaking.")
                .font(PilcrowFonts.monoF(9.5)).foregroundStyle(LL.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    private var caveat: some View {
        Text("Every number here is descriptive, not a score. Cormac McCarthy would fail the punctuation checks and Hemingway would fail the variance one. The point is to show you patterns, not to grade you against a style you didn't choose.")
            .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Appointments

struct AppointmentsView: View {
    @Bindable var store: ProjectStore
    @State private var book = AppointmentBook()
    @State private var adding = false

    private var upcoming: [Appointment] {
        store.manifest.appointments.filter { !$0.isPast || $0.weekly }
            .sorted { $0.when < $1.when }
    }
    private var past: [Appointment] {
        store.manifest.appointments.filter { $0.isPast && !$0.weekly }
            .sorted { $0.when > $1.when }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("APPOINTMENTS").font(PilcrowFonts.displayF(20)).tracking(0.9)
                    .foregroundStyle(LL.ink)
                Spacer()
                if !book.authorised {
                    Button("Allow calendar access") { Task { await book.requestAccess() } }
                        .llButton(.secondary, compact: true)
                }
                Button { adding = true } label: { Label("Make an appointment", systemImage: "plus") }
                    .llButton(.accent, compact: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Rule()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    rationale
                    if upcoming.isEmpty && past.isEmpty {
                        EmptyState(symbol: "calendar.badge.clock",
                                   title: "Nothing scheduled",
                                   message: "Name a time, a place, and which document. Not a word count \u{2014} a cue.",
                                   actionLabel: "Make the first one") { adding = true }
                            .frame(height: 220)
                    } else {
                        if !upcoming.isEmpty { list("Coming up", upcoming) }
                        if !past.isEmpty { list("Kept", past) }
                    }
                }
                .padding(18)
                .frame(maxWidth: 800, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(LL.ground)
        .onAppear { book.refreshAuthorisation() }
        .sheet(isPresented: $adding) {
            AppointmentSheet(store: store, book: book) { a in
                store.manifest.appointments.append(a)
                store.touchManifest()
            }
        }
    }

    private var rationale: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The highest-evidence feature in the app.")
                .font(PilcrowFonts.headingF(14, .bold)).foregroundStyle(LL.ink)
            Text("Gollwitzer & Sheeran's meta-analysis puts implementation intentions \u{2014} \u{201C}if [situation], then I will [behaviour]\u{201D} \u{2014} at roughly d = 0.65 across hundreds of studies. What does the work is the cue: a time and a place. Not a target.")
                .font(PilcrowFonts.bodyF(12)).foregroundStyle(LL.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if !book.authorised {
                Text(book.accessDescription)
                    .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.accentSoft))
    }

    private func list(_ title: String, _ items: [Appointment]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: title).padding(.bottom, 8)
            ForEach(items) { a in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(a.when.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                            .font(PilcrowFonts.monoF(10.5)).foregroundStyle(LL.ink3)
                        Text(a.when.formatted(date: .omitted, time: .shortened))
                            .font(PilcrowFonts.headingF(14, .bold)).foregroundStyle(LL.ink)
                    }
                    .frame(width: 82, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(a.sentence(documentTitle: store.node(a.nodeID ?? UUID())?.title))
                            .font(PilcrowFonts.bodyF(12.5)).foregroundStyle(LL.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            if a.weekly { Pill(text: "weekly", tint: LL.accent) }
                            if !a.eventID.isEmpty { Pill(text: "on calendar", tint: LL.ok) }
                        }
                    }
                    Spacer(minLength: 4)
                    IconButton(symbol: "trash", help: "Remove") {
                        book.remove(eventID: a.eventID)
                        store.manifest.appointments.removeAll { $0.id == a.id }
                        store.touchManifest()
                    }
                }
                .padding(.vertical, 10)
                Rule()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }
}

private struct AppointmentSheet: View {
    @Bindable var store: ProjectStore
    var book: AppointmentBook
    let save: (Appointment) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var when = Calendar.current.date(
        bySettingHour: 6, minute: 30, second: 0,
        of: Date().addingTimeInterval(86400)) ?? Date()
    @State private var minutes = 30
    @State private var place = ""
    @State private var intention = ""
    @State private var nodeID: UUID?
    @State private var weekly = false

    private var preview: Appointment {
        Appointment(when: when, minutes: minutes, place: place,
                    nodeID: nodeID, intention: intention, weekly: weekly)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AN APPOINTMENT").font(PilcrowFonts.displayF(24)).tracking(1)
                .foregroundStyle(LL.ink)

            DatePicker("When", selection: $when).controlSize(.small)
            HStack(spacing: 12) {
                Stepper("\(minutes) minutes", value: $minutes, in: 10...240, step: 5)
                    .font(PilcrowFonts.bodyF(12))
                Toggle("Every week", isOn: $weekly)
                    .toggleStyle(.checkbox).controlSize(.small)
                    .font(PilcrowFonts.bodyF(12))
            }

            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "Where \u{2014} half the cue")
                TextField("", text: $place, prompt: Text("the kitchen table"))
                    .textFieldStyle(.roundedBorder).controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "Which document")
                Picker("", selection: Binding(
                    get: { nodeID ?? none },
                    set: { nodeID = ($0 == none ? nil : $0) })) {
                        Text("Whatever's open").tag(none)
                        ForEach(store.orderedDocuments) { Text($0.title).tag($0.id) }
                    }.labelsHidden().controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "Then I will\u{2026}")
                TextField("", text: $intention, prompt: Text("finish the opening"))
                    .textFieldStyle(.roundedBorder).controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "The plan")
                Text(preview.sentence(documentTitle: store.node(nodeID ?? UUID())?.title))
                    .font(PilcrowFonts.bodyF(12.5)).foregroundStyle(LL.accentInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 5).fill(LL.accentSoft))

            if let err = book.lastError {
                Text(err).font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.crit)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.llButton(.ghost)
                Button("Schedule") {
                    Task {
                        if !book.authorised { await book.requestAccess() }
                        var a = preview
                        let title = store.node(nodeID ?? UUID())?.title
                        if let id = book.add(a, documentTitle: title,
                                             bookTitle: store.manifest.title) {
                            a.eventID = id
                        }
                        save(a)
                        dismiss()
                    }
                }.llButton(.accent)
            }
        }
        .padding(22)
        .frame(width: 500)
        .background(LL.ground)
    }

    private let none = UUID()
}
