import Foundation

// MARK: - Pitch Metrics (M10)
//
// Captures end-of-session pitch statistics computed on-device from raw
// audio samples. Drives the "monotone vs varied" surface in SummaryView
// and (eventually) the trend pill on the profile.
//
// All computation is local — no audio leaves the device. The audio
// engine's installTap callback feeds samples into PitchAnalyzer; at
// session end we run autocorrelation-based f0 detection across the
// captured buffer and produce these aggregates.
//
// Honest gaps in v1:
//   • Hum/music false-positive: closed at the call site
//     (`SpeechRecognizerViewModel.currentSessionPitchMetrics()`). That
//     method now returns nil when the rep produced fewer than 8
//     transcribed words or ran for under 4 seconds — without that
//     transcript evidence we can't credibly attribute voiced f0 to the
//     user's voice rather than background audio. `isReliable` below
//     stays a pure value-type predicate and assumes the call site has
//     already vetted that the metrics came from real speech.
//   • We use voiced-frame stdev as the variation metric. This conflates
//     intentional vocal variety with transcription jitter on whispered
//     speech. Trend analysis will smooth out short-term noise.

struct PitchMetrics: Codable, Equatable {
    /// Mean fundamental frequency across confidently-voiced windows (Hz).
    /// nil when no window passed the voicing threshold (e.g., silent rep,
    /// audio capture failure). UI uses nil to hide the card honestly.
    let meanHz: Double?

    /// Standard deviation of f0 across voiced windows (Hz). Higher = more
    /// pitch variation; lower = more monotone. nil when meanHz is nil.
    let stdHz: Double?

    /// Fraction of analysis windows where pitch was confidently detected,
    /// 0–1. Below ~0.20 is suspicious (very short rep, mostly silence,
    /// or detection failure) — UI should treat low values as "not enough
    /// signal" rather than "very monotone".
    let voicedRatio: Double

    /// Number of analysis windows the metrics were computed across. Used
    /// to decide whether the reading is reliable.
    let windowCount: Int

    static let empty = PitchMetrics(
        meanHz: nil,
        stdHz: nil,
        voicedRatio: 0,
        windowCount: 0
    )

    /// True when the metrics carry enough signal to surface in UI.
    /// Below the threshold we hide the card rather than mislead.
    var isReliable: Bool {
        guard let mean = meanHz, let _ = stdHz else { return false }
        // Need enough voiced windows AND a reasonable mean (filters out
        // pure silence and mic noise that would land outside vocal range).
        return windowCount >= 10 && voicedRatio >= 0.20 && mean >= 70 && mean <= 400
    }

    /// 0 (very varied) to 1 (very monotone). Calibrated so that:
    ///   stdHz ≥ 35Hz → 0   (clearly varied)
    ///   stdHz ≤ 8Hz  → 1   (very monotone)
    /// Linear in between. Returns 0.5 when not reliable so the UI doesn't
    /// drift to either extreme on insufficient data.
    var monotoneScore: Double {
        guard isReliable, let std = stdHz else { return 0.5 }
        let upperBound: Double = 35.0
        let lowerBound: Double = 8.0
        if std >= upperBound { return 0.0 }
        if std <= lowerBound { return 1.0 }
        return (upperBound - std) / (upperBound - lowerBound)
    }

    /// Short coaching headline for the summary card.
    var headline: String {
        guard isReliable else { return "Pitch — not enough signal" }
        let m = monotoneScore
        if m < 0.30 { return "Varied delivery" }
        if m < 0.65 { return "Mixed pitch range" }
        return "Pitch sat flat"
    }

    /// One-line coach line tailored to the score. Voice rules: no chirpy
    /// filler, second-person, ≤ 22 words. M14: stripped raw Hz numbers
    /// per real-device feedback — "what does 141 Hz mean?" — so the
    /// copy reads as coaching, not a DSP readout.
    var coachLine: String {
        guard isReliable else {
            return "Speak a little longer next rep so we have a clean read on your pitch."
        }
        let m = monotoneScore
        if m < 0.30 {
            return "Your voice moved across the line — that's how listeners stay with you. Keep the variation."
        }
        if m < 0.65 {
            return "There's room to lean into emphasis on the lines that matter — try lifting key words, settling on closes."
        }
        return "Your pitch sat flat across the rep. Try varying it on key words — questions go up, conclusions land down."
    }
}
