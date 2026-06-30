import Foundation

// MARK: - Rep Event Locations
//
// WHERE the notable events of a single rep actually fell — the positional
// companion to the whole-rep averages the app already keeps (PauseMetrics
// count, filler count, ConversationalPaceBand). A real coach says "you rushed
// right at the close" or "the long silence was in your opening", not just
// "your average pace was a little high". Until now Noum could only report the
// averages; the positional signal lived in the per-word timings that
// `SpeechRecognizerViewModel` computed once for `PauseMetrics` and then
// discarded.
//
// `RepEventLocations` is the small, persisted, coach-facing summary derived
// (offline, deterministically) from `TranscriptTimeline`. It:
//
// - **Reuses the timeline's classification** — pauses, bursts, and fillers are
//   exactly what `TranscriptTimeline` already produces from the existing
//   `PauseMetrics.minPauseSeconds` / `ConversationalPaceBand.maxWPM` edges. No
//   new pace or pause threshold is introduced. The only positional construct
//   is a coarse opening/middle/close third, a readout aid — not a tuning knob.
// - **Is honest by construction** — every field is optional and the engine
//   returns nil unless at least one credible positional signal exists (a
//   qualifying pause, a rushed burst, or a filler CLUSTER of >= 2 in one zone).
//   A single stray filler never becomes a "you cluster fillers at the close"
//   claim (CLAUDE.md: avoid fake certainty from small samples).
// - **Reads markers, not the person** — the readout is positional and factual
//   ("the fastest stretch was in the close"), never a whole-style verdict.

struct RepEventLocations: Codable, Equatable {
    /// A coarse third of the rep. Deliberately blunt: it answers "early,
    /// middle, or late?", the resolution a coach actually talks in.
    enum Zone: String, Codable, Equatable, CaseIterable {
        case opening, middle, close

        var label: String {
            switch self {
            case .opening: return "opening"
            case .middle: return "middle"
            case .close: return "close"
            }
        }

        /// The third a normalized 0...1 timeline position falls in.
        static func of(position: Double) -> Zone {
            if position < 1.0 / 3.0 { return .opening }
            if position < 2.0 / 3.0 { return .middle }
            return .close
        }
    }

    /// Zone + length of the single longest qualifying pause, when any pause was
    /// detected this rep.
    let longestPauseZone: Zone?
    let longestPauseSeconds: Double?
    /// Zone + local pace of the fastest rushed burst, when any phrase ran over
    /// the conversational band's upper edge.
    let rushedBurstZone: Zone?
    let rushedBurstWPM: Double?
    /// Zone holding the most fillers + that count, only when >= 2 fillers
    /// landed in a single zone (sample-size guard).
    let fillerClusterZone: Zone?
    let fillerClusterCount: Int?
    /// Coach-voice readout naming ONLY the present signals. Used by
    /// `CoachContextBuilder` to give the coach a positional read of the
    /// most-recent rep.
    let readout: String
}

enum RepEventLocationsEngine {
    /// Pure derive over the rep's timeline. Returns nil when the timeline
    /// carries no credible positional signal, so the coach context omits the
    /// block rather than padding it with a non-finding.
    static func derive(timeline: TranscriptTimeline) -> RepEventLocations? {
        guard !timeline.isEmpty, timeline.duration > 0 else { return nil }

        // Longest pause -------------------------------------------------------
        var longestPauseZone: RepEventLocations.Zone?
        var longestPauseSeconds: Double?
        if let longest = timeline.pauses.max(by: { $0.duration < $1.duration }) {
            longestPauseZone = .of(position: longest.position)
            longestPauseSeconds = longest.duration
        }

        // Fastest rushed burst ------------------------------------------------
        var rushedBurstZone: RepEventLocations.Zone?
        var rushedBurstWPM: Double?
        if let fastest = timeline.bursts.max(by: { $0.wpm < $1.wpm }) {
            rushedBurstZone = .of(position: fastest.position)
            rushedBurstWPM = fastest.wpm
        }

        // Filler cluster (>= 2 in one zone) -----------------------------------
        // Tally per zone in a fixed order so ties resolve deterministically
        // (earlier zone wins), keeping the read test-stable.
        var fillerCounts: [RepEventLocations.Zone: Int] = [:]
        for word in timeline.words where word.isFiller {
            fillerCounts[.of(position: word.position), default: 0] += 1
        }
        var fillerClusterZone: RepEventLocations.Zone?
        var fillerClusterCount: Int?
        for zone in RepEventLocations.Zone.allCases {
            let count = fillerCounts[zone] ?? 0
            if count >= 2, count > (fillerClusterCount ?? 0) {
                fillerClusterZone = zone
                fillerClusterCount = count
            }
        }

        guard longestPauseZone != nil
            || rushedBurstZone != nil
            || fillerClusterZone != nil else {
            return nil
        }

        let readout = buildReadout(
            longestPauseZone: longestPauseZone,
            longestPauseSeconds: longestPauseSeconds,
            rushedBurstZone: rushedBurstZone,
            rushedBurstWPM: rushedBurstWPM,
            fillerClusterZone: fillerClusterZone,
            fillerClusterCount: fillerClusterCount
        )

        return RepEventLocations(
            longestPauseZone: longestPauseZone,
            longestPauseSeconds: longestPauseSeconds,
            rushedBurstZone: rushedBurstZone,
            rushedBurstWPM: rushedBurstWPM,
            fillerClusterZone: fillerClusterZone,
            fillerClusterCount: fillerClusterCount,
            readout: readout
        )
    }

    private static func buildReadout(
        longestPauseZone: RepEventLocations.Zone?,
        longestPauseSeconds: Double?,
        rushedBurstZone: RepEventLocations.Zone?,
        rushedBurstWPM: Double?,
        fillerClusterZone: RepEventLocations.Zone?,
        fillerClusterCount: Int?
    ) -> String {
        var clauses: [String] = []
        if let zone = rushedBurstZone, let wpm = rushedBurstWPM {
            clauses.append("the fastest stretch (~\(Int(wpm.rounded())) wpm) ran in the \(zone.label)")
        }
        if let zone = longestPauseZone, let seconds = longestPauseSeconds {
            clauses.append("the longest silence (\(String(format: "%.1f", seconds))s) fell in the \(zone.label)")
        }
        if let zone = fillerClusterZone, let count = fillerClusterCount {
            clauses.append("fillers clustered in the \(zone.label) (\(count))")
        }
        return "Positional read (most-recent rep): " + clauses.joined(separator: "; ") + "."
    }
}
