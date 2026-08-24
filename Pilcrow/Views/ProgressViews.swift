//  ProgressViews.swift
//  The Progress Log and the Rhythm Report.
//
//  Amabile & Kramer coded ~12,000 daily diaries and found the strongest
//  predictor of a good workday in creative work was a sense of progress on
//  meaningful work. So this pane reports what you *did*. Words cut sit
//  beside words added, at the same weight, because in revision they are
//  the same thing.
//
//  There is no streak here. Sword (2016, n=1,323) found daily writing is
//  neither a marker nor a predictor of productivity, and a broken streak
//  is the thing that stops people opening the app.

import SwiftUI

struct ProgressPane: View {
    @Bindable var store: ProjectStore

    private var rhythm: Rhythm { Rhythm.compute(store.log.sessions) }
    private var done: [WritingSession] {
        store.log.sessions.filter { $0.ended != nil }.sorted { $0.started > $1.started }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if done.isEmpty {
                    EmptyState(symbol: "chart.xyaxis.line",
                               title: "No sessions logged yet",
                               message: "Close a sprint and it lands here \u{2014} what you did, not just how many words survived it.")
                        .frame(height: 260)
                } else {
                    totals
                    recentBars
                    rhythmSection
                    logList
                }
            }
            .padding(20)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(LL.ground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("PROGRESS").font(PilcrowFonts.displayF(30)).tracking(1.2).foregroundStyle(LL.ink)
            Text("What you did, session by session.")
                .font(PilcrowFonts.bodyF(13)).foregroundStyle(LL.ink2)
        }
    }

    private var totals: some View {
        HStack(spacing: 0) {
            stat("\(rhythm.totalSessions)", "sessions")
            divider
            stat("\(rhythm.totalMinutes / 60)h \(rhythm.totalMinutes % 60)m", "at the desk")
            divider
            stat("+\(rhythm.totalAdded.grouped)", "words added", LL.ok)
            divider
            stat("\u{2212}\(rhythm.totalCut.grouped)", "words cut", LL.accent)
            divider
            stat(store.totalWords.grouped, "in the book now")
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    private var divider: some View { Rectangle().fill(LL.rule).frame(width: 1, height: 44) }

    private func stat(_ v: String, _ c: String, _ tint: Color = LL.ink) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(v).font(PilcrowFonts.headingF(20, .heavy)).foregroundStyle(tint).monospacedDigit()
            Eyebrow(text: c)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private var recentBars: some View {
        let recent = Array(done.prefix(40).reversed())
        return VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Work done, last \(recent.count) sessions")
            Sparkbars(values: recent.map { Double($0.touched) }, tint: LL.accent, height: 54)
            Text("Height is words touched \u{2014} added and cut together. A tall bar on a day the book got shorter is still a tall bar.")
                .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    @ViewBuilder
    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: "Your rhythm")
                Spacer()
                if !rhythm.hasSignal {
                    Pill(text: "needs more sessions", tint: LL.ink3)
                }
            }

            if rhythm.hasSignal {
                if let h = rhythm.bestHour, let d = rhythm.bestWeekday {
                    Text("Your most productive hour is around **\(h.label)**, and your strongest day is **\(d.label)**. Median session: **\(rhythm.medianSessionMinutes) minutes**.")
                        .font(PilcrowFonts.bodyF(12.5)).foregroundStyle(LL.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("This is a description of what you have already done, not a prescription for what you should do next.")
                    .font(PilcrowFonts.bodyF(11)).foregroundStyle(LL.ink3)

                HStack(alignment: .top, spacing: 26) {
                    VStack(alignment: .leading, spacing: 5) {
                        Eyebrow(text: "By hour")
                        ForEach(rhythm.byHour.filter { $0.sessions > 0 }) { b in
                            BarRow(label: b.label, value: Double(b.words),
                                   max: Double(rhythm.byHour.map(\.words).max() ?? 1),
                                   caption: "\(b.sessions)\u{00D7}", tint: LL.accent)
                        }
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Eyebrow(text: "By day")
                        ForEach(rhythm.byWeekday) { b in
                            BarRow(label: b.label, value: Double(b.words),
                                   max: Double(rhythm.byWeekday.map(\.words).max() ?? 1),
                                   caption: "\(b.sessions)\u{00D7}", tint: LL.chartColor(1))
                        }
                    }
                }
            } else {
                Text("After eight or so logged sessions there'll be enough here to say something honest about when you write best. Until then, anything shown would be noise.")
                    .font(PilcrowFonts.bodyF(12)).foregroundStyle(LL.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }

    private var logList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "The log").padding(.bottom, 8)
            ForEach(done.prefix(50)) { s in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(s.started.formatted(date: .abbreviated, time: .shortened))
                            .font(PilcrowFonts.monoF(10.5)).foregroundStyle(LL.ink3)
                        if !s.goalNote.isEmpty {
                            Text(s.goalNote).font(PilcrowFonts.bodyF(12, .medium))
                                .foregroundStyle(LL.ink).lineLimit(1)
                        }
                        Spacer(minLength: 6)
                        Text("\(s.minutes)m").font(PilcrowFonts.monoF(10)).foregroundStyle(LL.ink3)
                        Text("+\(s.wordsAdded.grouped)").font(PilcrowFonts.monoF(10)).foregroundStyle(LL.ok)
                        Text("\u{2212}\(s.wordsCut.grouped)").font(PilcrowFonts.monoF(10)).foregroundStyle(LL.accent)
                    }
                    if !s.progressNote.isEmpty, s.progressNote != s.goalNote {
                        Text(s.progressNote)
                            .font(PilcrowFonts.bodyF(12)).foregroundStyle(LL.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 9)
                Rule()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 6).fill(LL.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LL.rule, lineWidth: 1))
    }
}
