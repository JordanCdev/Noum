import Foundation

// MARK: - Composure Read
//
// Per VISION § Strategic roadmap #2 (Delivery intelligence):
//   "Make pause quality, prosody/intonation, pitch range, breathing,
//    emphasis, vocal energy, authority/tension, structure, confidence
//    markers, and word-choice precision reliable session evidence."
//
// "Authority/tension" is one of the listed dimensions a real coach reads
// across a single rep — the felt sense of whether the speaker held it
// together or unraveled. Today Noum captures the constituent signals
// (vocal energy steadiness via M26, pitch variation via PitchMetrics,
// pause filled-vs-unfilled ratio via PauseMetrics, hedging rate in
// CommunicationBaseline) — but never composes them into one read.
//
// `ComposureRead` is the derived score. Pure function over what already
// exists in the session + baseline. Not a new sensing layer — a coach-
// facing read built from sensed inputs. Per VISION § Dev instructions:
//   - "Every recommendation must have evidence, purpose, an observable
//      target, and an honest evidence threshold for changing the plan."
//   - "Weak evidence must produce tentative language."
//
// Anti-overclaim:
//   - When a constituent signal is missing (e.g., pitch failed to
//     detect on a short rep), the read either omits that contribution
//     or reports nil overall. Never fabricates a number from one
//     present input.
//   - The qualitative label is voice-aware in copy register but the
//     UNDERLYING score is voice-neutral — the user's "authoritative"
//     register doesn't make their objective steadiness any different.

/// Per-session composure score + the qualitative read.
/// `score` is 0-1: 1.0 = held composure clearly across the rep;
/// 0.0 = visibly unsettled across multiple channels.
struct ComposureRead: Codable, Equatable {
    /// 0-1 composite score. Mean of the available channel scores.
    let score: Double
    /// Number of input channels that contributed. Missing channels are
    /// not counted; the floor is 2 (below that we return nil at the
    /// engine level). Lets the UI distinguish "1 channel said X" from
    /// "all 4 channels agreed on X".
    let contributingChannels: Int
    /// Which signals contributed. Useful for UI surfaces that want to
    /// say "based on your pace, pauses, and energy" or to omit
    /// missing channels honestly.
    let inputs: Inputs
    /// Coach-voice readout. Short, hedged, references the contributing
    /// channels. Used by CoachContextBuilder to surface the read in
    /// the AI coach's CONTEXT block.
    let readout: String

    /// Bag of bools recording which channels participated. Codable so
    /// it persists alongside the score when needed.
    struct Inputs: Codable, Equatable {
        let vocalEnergyContributed: Bool
        let pitchContributed: Bool
        let pauseQualityContributed: Bool
        let hedgingContributed: Bool
    }
}

/// Pure-function engine. Reads what the session + baseline have
/// available and composes the score. No I/O. Easy to unit test.
enum ComposureReadEngine {

    /// Minimum number of contributing channels before we produce a
    /// read. Below this, we return nil — honesty about thin signal.
    /// Two channels (any pair) is enough to triangulate; one channel
    /// alone risks reading composure off a single noisy input.
    static let minimumContributingChannels: Int = 2

    /// Compose a `ComposureRead` from the available session + baseline
    /// signals. Returns nil when fewer than `minimumContributingChannels`
    /// inputs are available.
    static func derive(
        session: PracticeSession,
        hedgingPerMinute: Double?
    ) -> ComposureRead? {
        var scores: [Double] = []
        var inputs = ComposureRead.Inputs(
            vocalEnergyContributed: false,
            pitchContributed: false,
            pauseQualityContributed: false,
            hedgingContributed: false
        )

        // Channel 1 — vocal energy steadiness (M26).
        // Direct 0-1; higher = steadier.
        var vocalContrib = false
        if let ve = session.vocalEnergyMetrics, ve.sampleCount >= 30 {
            scores.append(ve.steadiness)
            vocalContrib = true
        }

        // Channel 2 — pitch variation (some variation is good; monotone
        // OR runaway pitch variability both lower composure). Map
        // pitch coefficient of variation to a composure bucket:
        //   CV ≤ 0.10 (very monotone, reads as detached) → 0.4
        //   CV 0.10-0.30 (steady-with-life, ideal range)  → 1.0
        //   CV 0.30-0.50 (varied — engaging but trending) → 0.7
        //   CV > 0.50 (wildly variable — often nervous)   → 0.3
        var pitchContrib = false
        if let pm = session.pitchMetrics,
           let mean = pm.meanHz, mean > 0,
           let std = pm.stdHz {
            let cv = std / mean
            let pitchScore: Double
            switch cv {
            case ..<0.10:   pitchScore = 0.4
            case 0.10..<0.30: pitchScore = 1.0
            case 0.30..<0.50: pitchScore = 0.7
            default:        pitchScore = 0.3
            }
            scores.append(pitchScore)
            pitchContrib = true
        }

        // Channel 3 — pause quality (lower filled-pause ratio = more
        // deliberate pauses = more composed). 0 filled = score 1.0;
        // 50% filled = score 0.5; all filled = score 0.0.
        var pauseContrib = false
        if let pm = session.pauseMetrics, pm.count > 0 {
            let pauseScore = max(0, 1.0 - pm.filledRatio)
            scores.append(pauseScore)
            pauseContrib = true
        }

        // Channel 4 — hedging rate (per-min). High hedging reads as
        // tentative / uncertain. Map:
        //   0 hedges/min → 1.0; 1 → 0.85; 3 → 0.55; 5 → 0.30; ≥7 → 0.10
        var hedgingContrib = false
        if let hedging = hedgingPerMinute, hedging >= 0 {
            // Linear inverse with a floor; capped at 7 per minute.
            let capped = min(hedging, 7)
            let hedgeScore = max(0.10, 1.0 - (capped / 7.0) * 0.90)
            scores.append(hedgeScore)
            hedgingContrib = true
        }

        guard scores.count >= minimumContributingChannels else { return nil }

        let composite = scores.reduce(0, +) / Double(scores.count)
        let readoutInputs = ComposureRead.Inputs(
            vocalEnergyContributed: vocalContrib,
            pitchContributed: pitchContrib,
            pauseQualityContributed: pauseContrib,
            hedgingContributed: hedgingContrib
        )
        return ComposureRead(
            score: composite,
            contributingChannels: scores.count,
            inputs: readoutInputs,
            readout: readoutCopy(score: composite, inputs: readoutInputs)
        )
    }

    /// Voice-neutral, hedged readout. The UNDERLYING score is what it
    /// is; copy register hedges based on how many channels contributed
    /// (fewer channels → softer language; more channels → more
    /// declarative). Per VISION dev rule.
    static func readoutCopy(score: Double, inputs: ComposureRead.Inputs) -> String {
        let label = qualitativeLabel(score: score)
        let inputCount = [
            inputs.vocalEnergyContributed,
            inputs.pitchContributed,
            inputs.pauseQualityContributed,
            inputs.hedgingContributed
        ].filter { $0 }.count
        let prefix = inputCount >= 3 ? "Composure" : "Early composure read"
        let channelTail = readChannelList(inputs: inputs)
        return "\(prefix): \(label) (from \(channelTail))"
    }

    static func qualitativeLabel(score: Double) -> String {
        switch score {
        case 0.80...:   return "held — steady across channels"
        case 0.60..<0.80: return "mostly held — a couple of channels wobbled"
        case 0.40..<0.60: return "mixed — visible tension on some channels"
        case 0.20..<0.40: return "thin — multiple channels read as unsettled"
        default:        return "unsettled — composure faltered across channels"
        }
    }

    /// "vocal energy, pitch variation, pause quality" — used in the
    /// readout copy so the AI coach knows which signals fed the score.
    /// Honest about which channels actually contributed.
    static func readChannelList(inputs: ComposureRead.Inputs) -> String {
        var labels: [String] = []
        if inputs.vocalEnergyContributed { labels.append("vocal energy") }
        if inputs.pitchContributed { labels.append("pitch") }
        if inputs.pauseQualityContributed { labels.append("pause quality") }
        if inputs.hedgingContributed { labels.append("hedging rate") }
        switch labels.count {
        case 0:  return "no channels"
        case 1:  return labels[0]
        case 2:  return "\(labels[0]) + \(labels[1])"
        default: return labels.dropLast().joined(separator: ", ") + " + " + labels.last!
        }
    }
}
