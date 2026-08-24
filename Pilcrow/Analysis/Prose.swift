//  Prose.swift
//  Revise-mode diagnostics.
//
//  Every number here is descriptive. None of it is a score, and none of it
//  is a rule — Cormac McCarthy would fail most of these and Hemingway would
//  fail the rest. The point is to show you patterns you cannot see from
//  inside the sentence you are currently writing.

import Foundation
import NaturalLanguage

struct ProseReport {
    var words = 0
    var sentences = 0
    var paragraphs = 0
    var syllables = 0

    var sentenceLengths: [Int] = []
    var meanSentence: Double = 0
    var sentenceStdDev: Double = 0
    /// Long runs of same-length sentences are what monotony actually is.
    var longestMonotoneRun = 0

    var adverbs: [(String, Int)] = []
    var adverbRate: Double = 0          // per 1,000 words
    var filterWords: [(String, Int)] = []
    var filterRate: Double = 0
    var crutchWords: [(String, Int)] = []
    var passiveCount = 0
    var passiveRate: Double = 0
    var repetitions: [Repetition] = []

    var dialogueShare: Double = 0       // 0...1 of characters inside quotes
    var fleschEase: Double = 0
    var gradeLevel: Double = 0

    var longestSentence: String = ""

    struct Repetition: Identifiable {
        let id = UUID()
        let word: String
        let gap: Int
        let context: String
    }

    var readingTimeMinutes: Int { Int((Double(words) / 240.0).rounded()) }
}

enum Prose {

    // MARK: Word lists

    /// Words that put a pane of glass between the reader and the thing.
    static let filters: Set<String> = [
        "just","very","really","quite","actually","somewhat","rather","simply",
        "basically","literally","suddenly","perhaps","maybe","almost","nearly",
        "seemed","seems","felt","feel","knew","know","realized","realised",
        "wondered","thought","looked","saw","heard","watched","noticed","decided",
        "began","started","managed","tried","kind","sort","little","bit","things",
        "stuff","somehow","anyway","totally","definitely","certainly","probably"
    ]

    static let stopwords: Set<String> = [
        "the","a","an","and","or","but","if","of","to","in","on","at","by","for",
        "with","from","as","is","was","were","be","been","being","are","am","it",
        "its","he","she","they","them","his","her","their","him","i","me","my",
        "we","us","our","you","your","that","this","these","those","not","no",
        "so","than","then","there","here","what","which","who","whom","when",
        "where","how","all","any","both","each","few","more","most","other","some",
        "such","only","own","same","too","can","will","would","could","should",
        "do","does","did","done","have","has","had","having","up","down","out",
        "off","over","under","again","once","into","about","after","before",
        "because","while","during","through","between","against","above","below"
    ]

    private static let beVerbs: Set<String> = [
        "is","are","was","were","be","been","being","am","get","gets","got","gotten"
    ]

    private static let irregularParticiples: Set<String> = [
        "made","done","said","seen","taken","given","known","found","told","held",
        "brought","written","shown","left","put","kept","begun","broken","chosen",
        "driven","eaten","fallen","forgotten","gotten","hidden","spoken","stolen",
        "thrown","worn","born","built","caught","cut","felt","hit","hurt","laid",
        "led","lost","meant","met","paid","read","run","sent","set","shot","sold",
        "sung","sat","slept","spent","stood","struck","taught","torn","understood","won"
    ]

    // MARK: Entry point

    static func analyse(_ raw: String) -> ProseReport {
        var r = ProseReport()
        let text = stripMarkup(raw)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return r }

        r.paragraphs = raw.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count

        let sentences = splitSentences(text)
        r.sentences = sentences.count

        var lengths: [Int] = []
        var allWords: [String] = []
        var longest = ("", 0)

        for s in sentences {
            let w = words(in: s)
            guard !w.isEmpty else { continue }
            lengths.append(w.count)
            allWords.append(contentsOf: w)
            if w.count > longest.1 { longest = (s, w.count) }
        }

        r.words = allWords.count
        r.sentenceLengths = lengths
        r.longestSentence = longest.0.trimmingCharacters(in: .whitespacesAndNewlines)

        if !lengths.isEmpty {
            let mean = Double(lengths.reduce(0, +)) / Double(lengths.count)
            r.meanSentence = mean
            let variance = lengths.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(lengths.count)
            r.sentenceStdDev = variance.squareRoot()
            r.longestMonotoneRun = monotoneRun(lengths)
        }

        // Frequencies
        var counts: [String: Int] = [:]
        for w in allWords { counts[w, default: 0] += 1 }

        r.adverbs = counts.filter { $0.key.hasSuffix("ly") && $0.key.count > 4 }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(20).map { ($0.key, $0.value) }
        r.filterWords = counts.filter { filters.contains($0.key) }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(20).map { ($0.key, $0.value) }
        r.crutchWords = counts
            .filter { !stopwords.contains($0.key) && !filters.contains($0.key)
                      && $0.key.count > 3 && !$0.key.hasSuffix("ly") }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(20).map { ($0.key, $0.value) }

        let per1k = r.words > 0 ? 1000.0 / Double(r.words) : 0
        r.adverbRate = Double(r.adverbs.reduce(0) { $0 + $1.1 }) * per1k
        r.filterRate = Double(r.filterWords.reduce(0) { $0 + $1.1 }) * per1k

        r.passiveCount = countPassive(allWords)
        r.passiveRate = r.sentences > 0 ? Double(r.passiveCount) / Double(r.sentences) : 0

        r.repetitions = findRepetitions(allWords)
        r.dialogueShare = dialogueShare(text)

        r.syllables = allWords.reduce(0) { $0 + syllables($1) }
        if r.sentences > 0 && r.words > 0 {
            let wps = Double(r.words) / Double(r.sentences)
            let spw = Double(r.syllables) / Double(r.words)
            r.fleschEase = 206.835 - 1.015 * wps - 84.6 * spw
            r.gradeLevel = 0.39 * wps + 11.8 * spw - 15.59
        }
        return r
    }

    // MARK: Pieces

    /// Removes emphasis markers, headings, scene breaks, and citation keys so
    /// they don't pollute word counts and frequency tables.
    static func stripMarkup(_ s: String) -> String {
        var t = s
        t = t.replacingOccurrences(of: #"\[@[^\]]+\]"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?m)^\s*(---|#{1,3}\s*)"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\*{1,3}"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?<![A-Za-z0-9])_(?=\S)|(?<=\S)_(?![A-Za-z0-9])"#,
                                   with: "", options: .regularExpression)
        return t
    }

    static func splitSentences(_ text: String) -> [String] {
        let tk = NLTokenizer(unit: .sentence)
        tk.string = text
        var out: [String] = []
        tk.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { out.append(s) }
            return true
        }
        return out
    }

    static func words(in text: String) -> [String] {
        let tk = NLTokenizer(unit: .word)
        tk.string = text
        var out: [String] = []
        tk.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let w = text[range].lowercased()
                .trimmingCharacters(in: CharacterSet.punctuationCharacters)
            if !w.isEmpty && w.rangeOfCharacter(from: .letters) != nil { out.append(w) }
            return true
        }
        return out
    }

    /// Longest run of consecutive sentences within two words of each other in
    /// length. Four 4,000-word scenes of identical rhythm is a shape you can
    /// see in two seconds and can't feel while writing them.
    private static func monotoneRun(_ lengths: [Int]) -> Int {
        guard lengths.count > 1 else { return lengths.count }
        var best = 1, run = 1
        for i in 1..<lengths.count {
            if abs(lengths[i] - lengths[i-1]) <= 2 { run += 1; best = max(best, run) }
            else { run = 1 }
        }
        return best
    }

    /// Heuristic, and labelled as one: a form of *to be* followed within two
    /// words by a past participle.
    private static func countPassive(_ words: [String]) -> Int {
        var n = 0
        for i in words.indices where beVerbs.contains(words[i]) {
            for j in (i+1)...(i+2) where j < words.count {
                let w = words[j]
                if irregularParticiples.contains(w) || (w.hasSuffix("ed") && w.count > 4) {
                    n += 1
                    break
                }
            }
        }
        return n
    }

    /// The same distinctive word twice inside sixty words. Every writer has
    /// tics; almost nobody can see their own.
    private static func findRepetitions(_ words: [String]) -> [ProseReport.Repetition] {
        var last: [String: Int] = [:]
        var out: [ProseReport.Repetition] = []
        for (i, w) in words.enumerated() {
            guard w.count > 5, !stopwords.contains(w), !filters.contains(w) else { continue }
            if let prev = last[w], i - prev <= 60 {
                let lo = max(0, prev - 3), hi = min(words.count, i + 4)
                out.append(.init(word: w, gap: i - prev,
                                 context: "\u{2026}" + words[lo..<hi].joined(separator: " ") + "\u{2026}"))
            }
            last[w] = i
        }
        return Array(out.sorted { $0.gap < $1.gap }.prefix(25))
    }

    private static func dialogueShare(_ text: String) -> Double {
        let ns = text as NSString
        guard ns.length > 0 else { return 0 }
        var inside = 0, open = false, run = 0
        for i in 0..<ns.length {
            let c = ns.character(at: i)
            // straight ", curly “ ”
            if c == 34 || c == 0x201C || c == 0x201D {
                if open { inside += run; run = 0; open = false }
                else { open = true; run = 0 }
            } else if open {
                run += 1
                // An unclosed quote shouldn't swallow the rest of the book.
                if run > 2000 { open = false; run = 0 }
            }
        }
        return min(1, Double(inside) / Double(ns.length))
    }

    static func syllables(_ word: String) -> Int {
        let w = word.lowercased().filter { $0.isLetter }
        guard !w.isEmpty else { return 0 }
        let vowels = Set("aeiouy")
        var count = 0, prevVowel = false
        for ch in w {
            let v = vowels.contains(ch)
            if v && !prevVowel { count += 1 }
            prevVowel = v
        }
        if w.hasSuffix("e") && !w.hasSuffix("le") && count > 1 { count -= 1 }
        return max(1, count)
    }
}

// MARK: - Pacing across the book

struct PacingPoint: Identifiable {
    let id: UUID
    let title: String
    let words: Int
    let dialogueShare: Double
    let meanSentence: Double
}

enum Pacing {
    static func across(documents: [Node], body: (UUID) -> String) -> [PacingPoint] {
        documents.map { doc in
            let text = body(doc.id)
            // Cheap per-scene pass — the full report is too slow book-wide.
            let sentences = Prose.splitSentences(Prose.stripMarkup(text))
            let words = Prose.words(in: Prose.stripMarkup(text))
            let mean = sentences.isEmpty ? 0 : Double(words.count) / Double(sentences.count)
            return PacingPoint(id: doc.id, title: doc.title, words: doc.wordCount,
                               dialogueShare: quickDialogue(text), meanSentence: mean)
        }
    }

    private static func quickDialogue(_ text: String) -> Double {
        let r = Prose.analyse(text)
        return r.dialogueShare
    }
}
