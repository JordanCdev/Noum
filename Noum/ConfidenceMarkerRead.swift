import Foundation

// MARK: - Confidence Marker Read
//
// Per VISION § Strategic roadmap #2 (Delivery intelligence):
//   "Pause quality, prosody/intonation, pitch range, breathing,
//    emphasis, vocal energy, authority/tension, structure, **confidence
//    markers**, and word-choice precision reliable session evidence."
//
// "Confidence markers" is the third derived read after Composure (M27)
// and Vocal Energy (M26). It composes the *linguistic* signals of
// uncertainty — hedging density, filler clustering, pace consistency —
// alongside the just-shipped composure read, into a single
// 0-1 confidence score the coach can quote back.
//
// Anti-overclaim rules from VISION:
//   - "Inferred psychological or interpersonal patterns must be framed
//     as coach hypotheses, never facts or diagnoses."
//   - "Weak evidence must produce tentative language."
//   - This engine never says "the user is unconfident" — it reads
//     CONFIDENCE MARKERS in the rep and labels the markers, not the
//     person. Copy says "this rep read as tentative" not "you sound
//     unconfident".
//
// Per VISION's strong distinction: clarity vs over-polish vs avoidance
// vs timidity. This read flags markers that read as TENTATIVE (the
// user qualifying claims, clustering fillers around uncertainty points,
// pace dropping when content depth thins). It does NOT distinguish
// "humble but clear" from "timid" — the coach interprets that based
// on the user's stated voice register.

/// Per-rep confidence-marker score with channel attribution.
/// `score` is 0-1: 1.0 = clean of tentative markers; 0.0 = heavy
/// tentative markers across multiple channels.
struct ConfidenceMarkerRead: Codable, Equatable {
    /// 0-1 composite. Mean of the available channel scores.
    let score: Double
    /// Number of channels that contributed. 2-channel minimum at the
    /// engine level; below that → nil.
    let contributingChannels: Int
    /// Which signals contributed. Honest about thin data.
    let inputs: Inputs
    /// Coach-voice readout. Hedged; reads markers, not the person.
    let readout: String

    struct Inputs: Codable, Equatable {
        let hedgingContributed: Bool
        let fillerDensityContributed: Bool
        let paceConsistencyContributed: Bool
        let composureContributed: Bool
    }
}

enum ConfidenceMarkerEngine {

    /// 2-channel minimum. One channel risks reading confidence off a
    /// single noisy signal (a user with 3 fillers/min isn't
    /// necessarily timid — they might just have an accent or a habit).
    static let minimumContributingChannels: Int = 2

    /// Compose the read. Returns nil when fewer than the minimum
    /// number of channels are present.
    static func derive(
        session: PracticeSession,
        hedgingPerMinute: Double?,
        paceWPM: Double?,
        composure: ComposureRead?
    ) -> ConfidenceMarkerRead? {
        var scores: [Double] = []
        var hedgingContrib = false
        var fillerContrib = false
        var paceContrib = false
        var composureContrib = false

        // Channel 1 — hedging density. Same mapping as ComposureRead
        // hedging channel: 0/min → 1.0, 7+/min → 0.10. Linear inverse
        // with a floor.
        if let hedging = hedgingPerMinute, hedging >= 0 {
            let capped = min(hedging, 7)
            let hedgeScore = max(0.10, 1.0 - (capped / 7.0) * 0.90)
            scores.append(hedgeScore)
            hedgingContrib = true
        }

        // Channel 2 — filler DENSITY (not just count). Fillers per
        // minute, derived from session.fillerWordCount + duration.
        // Tentative markers cluster around uncertainty points so high
        // density reads tentative. Same curve shape as hedging.
        //   0/min → 1.0; 8+/min → 0.15.
        if session.duration > 0 {
            let minutes = session.duration / 60.0
            let fillersPerMin = Double(session.fillerWordCount) / minutes
            let capped = min(fillersPerMin, 8)
            let fillerScore = max(0.15, 1.0 - (capped / 8.0) * 0.85)
            scores.append(fillerScore)
            fillerContrib = true
        }

        // Channel 3 — pace consistency. When the user is uncertain,
        // pace often DROPS at the moment of uncertainty (searching for
        // the next idea). Map session pace vs the user's baseline:
        // pace within 10% of baseline → 1.0; ±25% → 0.5; ≥40% delta → 0.2.
        // Reads RELATIVE drift — slow speakers don't get penalized
        // just for being slow.
        if let paceBaseline = paceWPM, paceBaseline > 0 {
            // We don't have per-rep WPM directly on PracticeSession,
            // but we can derive it from word-count estimate (transcript
            // words ÷ minutes). Conservative: if we can't derive
            // reliably, skip this channel.
            let words = Self.estimatedWordCount(transcript: session.transcript)
            let minutes = session.duration / 60.0
            if minutes > 0.25, words >= 10 {  // floor: ≥15s rep, ≥10 words
                let repPace = Double(words) / minutes
                let deltaPct = abs(repPace - paceBaseline) / paceBaseline
                let paceScore: Double
                switch deltaPct {
                case ..<0.10:  paceScore = 1.0
                case 0.10..<0.25: paceScore = 0.7
                case 0.25..<0.40: paceScore = 0.45
                default:       paceScore = 0.20
                }
                scores.append(paceScore)
                paceContrib = true
            }
        }

        // Channel 4 — composure carryover. When composure was high,
        // confidence markers also tend to read as present. Direct
        // borrow — no remapping.
        if let composure = composure {
            scores.append(composure.score)
            composureContrib = true
        }

        guard scores.count >= minimumContributingChannels else { return nil }

        let composite = scores.reduce(0, +) / Double(scores.count)
        let inputs = ConfidenceMarkerRead.Inputs(
            hedgingContributed: hedgingContrib,
            fillerDensityContributed: fillerContrib,
            paceConsistencyContributed: paceContrib,
            composureContributed: composureContrib
        )
        return ConfidenceMarkerRead(
            score: composite,
            contributingChannels: scores.count,
            inputs: inputs,
            readout: readoutCopy(score: composite, inputs: inputs)
        )
    }

    /// Coach-voice readout. Reads MARKERS, not the person — VISION's
    /// anti-diagnosis rule. "This rep read as tentative" never "you
    /// sound timid".
    static func readoutCopy(score: Double, inputs: ConfidenceMarkerRead.Inputs) -> String {
        let label = qualitativeLabel(score: score)
        let channels = channelList(inputs: inputs)
        return "Confidence markers: \(label) (from \(channels))"
    }

    static func qualitativeLabel(score: Double) -> String {
        switch score {
        case 0.80...:    return "clean — few tentative markers in this rep"
        case 0.60..<0.80: return "mostly clean — a couple of tentative beats"
        case 0.40..<0.60: return "mixed — tentative markers present across the rep"
        case 0.20..<0.40: return "heavy — tentative markers landing repeatedly"
        default:         return "very heavy — markers clustering across multiple channels"
        }
    }

    static func channelList(inputs: ConfidenceMarkerRead.Inputs) -> String {
        var labels: [String] = []
        if inputs.hedgingContributed { labels.append("hedging density") }
        if inputs.fillerDensityContributed { labels.append("filler density") }
        if inputs.paceConsistencyContributed { labels.append("pace consistency") }
        if inputs.composureContributed { labels.append("composure carryover") }
        switch labels.count {
        case 0:  return "no channels"
        case 1:  return labels[0]
        case 2:  return "\(labels[0]) + \(labels[1])"
        default: return labels.dropLast().joined(separator: ", ") + " + " + labels.last!
        }
    }

    /// Cheap word count from a transcript. Splits on whitespace; drops
    /// empties. Good enough for the pace-consistency channel; we're
    /// not trying to match the WPMEvaluator's stricter rules.
    static func estimatedWordCount(transcript: String) -> Int {
        transcript
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { !$0.isEmpty }
            .count
    }
}
