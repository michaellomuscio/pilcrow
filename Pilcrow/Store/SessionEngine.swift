//  SessionEngine.swift
//  Sprints, session records, and the Progress Log.
//
//  The design constraint that shapes this whole file: no guilt surface.
//  No streak that can break, no red number, no "you haven't written in
//  six days." Sword (2016, n=1,323) found ~12% of productive academic
//  writers write daily; the evidence does not support the shame, and the
//  shame is what makes people stop opening the app.
//
//  Words cut count as work. In revision they *are* the work — a tracker
//  that only counts words added punishes the days a book gets good.

import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class SessionEngine {

    var active: WritingSession?
    var elapsed: TimeInterval = 0
    var isRunning: Bool { active != nil && !isPaused }
    var isPaused = false

    /// Filled at close; shown above the cursor at the next open.
    var pendingNextLine: String = ""

    private var timer: Timer?
    private var lastSample: Int = 0
    private var lastTick: Date?

    // MARK: Sprint

    func start(goalKind: GoalKind, goalValue: Int, note: String, place: String,
               currentWords: Int) {
        var s = WritingSession()
        s.goalKind = goalKind
        s.goalValue = goalValue
        s.goalNote = note
        s.place = place
        active = s
        elapsed = 0
        isPaused = false
        lastSample = currentWords
        lastTick = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() { isPaused = true; lastTick = nil }
    func resume() { isPaused = false; lastTick = Date() }

    private func tick() {
        guard active != nil, !isPaused else { return }
        let now = Date()
        elapsed += now.timeIntervalSince(lastTick ?? now)
        lastTick = now
    }

    /// Called whenever the project's word total changes. Positive deltas
    /// accumulate as added, negative as cut — both are work.
    func sample(totalWords: Int, nodeID: UUID?) {
        guard var s = active else { lastSample = totalWords; return }
        let delta = totalWords - lastSample
        if delta > 0 { s.wordsAdded += delta }
        else if delta < 0 { s.wordsCut += -delta }
        lastSample = totalWords
        if let n = nodeID, !s.nodeIDs.contains(n) { s.nodeIDs.append(n) }
        active = s
    }

    // MARK: Goal

    var goalProgress: Double {
        guard let s = active else { return 0 }
        switch s.goalKind {
        case .time:  return min(1, elapsed / Double(max(1, s.goalValue) * 60))
        case .words: return min(1, Double(s.wordsAdded) / Double(max(1, s.goalValue)))
        case .unit:  return min(1, elapsed / Double(max(1, s.goalValue) * 60))
        }
    }

    var goalReached: Bool { goalProgress >= 1 }

    /// What the ring reads out. Never a countdown to failure.
    var readout: String {
        guard let s = active else { return "--:--" }
        switch s.goalKind {
        case .words:
            return "\(s.wordsAdded)"
        case .time, .unit:
            let total = Int(elapsed)
            return String(format: "%d:%02d", total / 60, total % 60)
        }
    }

    var readoutUnit: String {
        guard let s = active else { return "" }
        return s.goalKind == .words ? "words" : "minutes"
    }

    // MARK: Close

    /// Ends the sprint and returns the completed record for the log.
    func finish(nextLine: String, progressNote: String,
                mood: Int?, energy: Int?) -> WritingSession? {
        timer?.invalidate()
        timer = nil
        guard var s = active else { return nil }
        s.ended = Date()
        s.goalMet = goalReached
        s.nextLine = nextLine
        s.progressNote = progressNote
        s.mood = mood
        s.energy = energy
        active = nil
        elapsed = 0
        isPaused = false
        pendingNextLine = nextLine
        return s
    }

    func discard() {
        timer?.invalidate(); timer = nil
        active = nil; elapsed = 0; isPaused = false
    }
}

// MARK: - Rhythm
//
// Descriptive, never prescriptive. It reports what your own data says
// about when you write well. It does not recommend a schedule.

struct Rhythm {
    struct Bucket: Identifiable {
        var id: Int
        var label: String
        var sessions: Int
        var words: Int
        var minutes: Int
        var wordsPerMinute: Double { minutes > 0 ? Double(words) / Double(minutes) : 0 }
    }

    let byHour: [Bucket]
    let byWeekday: [Bucket]
    let totalSessions: Int
    let totalMinutes: Int
    let totalAdded: Int
    let totalCut: Int
    let medianSessionMinutes: Int

    var bestHour: Bucket? {
        byHour.filter { $0.sessions >= 2 }.max { $0.wordsPerMinute < $1.wordsPerMinute }
    }
    var bestWeekday: Bucket? {
        byWeekday.filter { $0.sessions >= 2 }.max { $0.wordsPerMinute < $1.wordsPerMinute }
    }
    /// Enough data to say anything honest?
    var hasSignal: Bool { totalSessions >= 8 }

    static func compute(_ sessions: [WritingSession]) -> Rhythm {
        let cal = Calendar.current
        let done = sessions.filter { $0.ended != nil }

        var hourS = Array(repeating: 0, count: 24)
        var hourW = Array(repeating: 0, count: 24)
        var hourM = Array(repeating: 0, count: 24)
        var dayS = Array(repeating: 0, count: 7)
        var dayW = Array(repeating: 0, count: 7)
        var dayM = Array(repeating: 0, count: 7)

        for s in done {
            let h = cal.component(.hour, from: s.started)
            let d = cal.component(.weekday, from: s.started) - 1
            hourS[h] += 1; hourW[h] += s.touched; hourM[h] += max(1, s.minutes)
            dayS[d] += 1;  dayW[d] += s.touched;  dayM[d] += max(1, s.minutes)
        }

        let hourFmt = DateFormatter()
        hourFmt.dateFormat = "ha"
        let dayNames = cal.shortWeekdaySymbols

        let hours = (0..<24).map { h -> Bucket in
            var c = DateComponents(); c.hour = h
            let label = cal.date(from: c).map { hourFmt.string(from: $0) } ?? "\(h)"
            return Bucket(id: h, label: label, sessions: hourS[h], words: hourW[h], minutes: hourM[h])
        }
        let days = (0..<7).map { d in
            Bucket(id: d, label: dayNames[d], sessions: dayS[d], words: dayW[d], minutes: dayM[d])
        }

        let mins = done.map { max(0, $0.minutes) }.sorted()
        let median = mins.isEmpty ? 0 : mins[mins.count / 2]

        return Rhythm(byHour: hours, byWeekday: days,
                      totalSessions: done.count,
                      totalMinutes: done.reduce(0) { $0 + $1.minutes },
                      totalAdded: done.reduce(0) { $0 + $1.wordsAdded },
                      totalCut: done.reduce(0) { $0 + $1.wordsCut },
                      medianSessionMinutes: median)
    }
}
