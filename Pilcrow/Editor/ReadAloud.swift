//  ReadAloud.swift
//  The ear catches what the eye skips.
//
//  System speech rather than a cloud voice: it works on a plane, costs
//  nothing, needs no key, and never sends a word of an unpublished
//  manuscript to anybody's server. macOS ships genuinely good voices —
//  the Siri and Premium ones are worth downloading in System Settings.

import AVFoundation
import Observation
import AppKit

@Observable
@MainActor
final class ReadAloud: NSObject, AVSpeechSynthesizerDelegate {

    private let synth = AVSpeechSynthesizer()

    var isSpeaking = false
    var isPaused = false
    /// The word being spoken, in the coordinates of the text handed in.
    var spokenRange: NSRange?
    var rate: Float = 0.48
    var voiceID: String = ReadAloud.preferredVoiceID()

    private var offset = 0

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Voices worth listing: English, best quality first.
    static func voices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted {
                if $0.quality.rawValue != $1.quality.rawValue {
                    return $0.quality.rawValue > $1.quality.rawValue
                }
                return $0.name < $1.name
            }
    }

    static func preferredVoiceID() -> String {
        let all = voices()
        return all.first(where: { $0.quality == .premium })?.identifier
            ?? all.first(where: { $0.quality == .enhanced })?.identifier
            ?? all.first?.identifier
            ?? AVSpeechSynthesisVoice(language: "en-US")?.identifier ?? ""
    }

    static func qualityLabel(_ v: AVSpeechSynthesisVoice) -> String {
        switch v.quality {
        case .premium:  return "Premium"
        case .enhanced: return "Enhanced"
        default:        return "Standard"
        }
    }

    // MARK: Control

    /// Speaks `text` from `startAt`. Markup is stripped so the reader
    /// doesn't hear "asterisk asterisk Tuesday".
    func speak(_ text: String, from startAt: Int = 0) {
        stop()
        let clean = Prose.stripMarkup(text)
        let ns = clean as NSString
        let start = min(max(0, startAt), ns.length)
        offset = start
        let slice = ns.substring(from: start)
        guard !slice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let utterance = AVSpeechUtterance(string: slice)
        if let v = AVSpeechSynthesisVoice(identifier: voiceID) { utterance.voice = v }
        utterance.rate = rate
        utterance.postUtteranceDelay = 0
        // A touch of extra breath between sentences reads more like speech.
        utterance.preUtteranceDelay = 0
        isSpeaking = true
        isPaused = false
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
        isPaused = false
        spokenRange = nil
    }

    func togglePause() {
        if isPaused { synth.continueSpeaking(); isPaused = false }
        else if synth.isSpeaking { synth.pauseSpeaking(at: .word); isPaused = true }
    }

    // MARK: Delegate

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer,
                                       willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.spokenRange = NSRange(location: characterRange.location + self.offset,
                                       length: characterRange.length)
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.isPaused = false
            self.spokenRange = nil
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.isPaused = false
            self.spokenRange = nil
        }
    }
}
