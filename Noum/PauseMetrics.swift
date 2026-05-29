import Foundation

// MARK: - Pause Metrics
//
// Computes pause statistics from word-level timings produced by any
// `TranscriptionProvider`. Pauses are the third leg of speech quality
// (after fillers and pace), and the most differentiating signal under
// pressure: composure shows up as deliberate spacing, not as silence.
//
// What counts as a pause:
// - The gap between two consecutive words is ≥ `minPauseSeconds` (0.5s).
// - Anything shorter is normal sentence rhythm, not a pause.
//
// Filled vs unfilled:
// - "Filled" = a pause that contains a filler word inside it ("um", "uh",
//   "like" used as disfluency). The filler detector already classifies
//   these — we just count how many of the user's pauses were verbal-clutter
//   pauses vs true silence.
// - "Unfilled" = silent pause. This is the composed pause we coach toward.
//
// The metrics are intentionally small (4 numbers) so they can persist on
// every `PracticeSession` without blowing up UserDefaults.

struct PauseMetrics: Codable, Equatable {
    /// Total number of pauses ≥ `minPauseSeconds`.
    let count: Int
    /// Mean pause length across all pauses, in seconds. 0 when count is 0.
    let meanSeconds: Double
    /// Longest single pause in the session, in seconds. 0 when count is 0.
    let longestSeconds: Double
    /// Fraction of pauses that contained a filler word, 0...1.
    /// 0 when count is 0; lower is better (more silent / deliberate pauses).
    let filledRatio: Double

    /// Threshold below which a gap counts as sentence rhythm, not a pause.
    static let minPauseSeconds: Double = 0.5

    static let empty = PauseMetrics(
        count: 0,
        meanSeconds: 0,
        longestSeconds: 0,
        filledRatio: 0
    )

    /// Compute from word-level timings. `fillerWords` is a set of lowercased
    /// tokens classified as fillers by `FillerWordDetector`; a pause is
    /// considered "filled" when a filler word's `startTime` falls inside
    /// the gap between two non-filler words.
    static func compute(
        words: [TranscriptUpdate.WordTiming],
        fillerStartTimes: [TimeInterval]
    ) -> PauseMetrics {
        guard words.count >= 2 else { return .empty }
        let sorted = words.sorted(by: { $0.startTime < $1.startTime })
        var gaps: [(start: TimeInterval, end: TimeInterval)] = []
        for index in 1..<sorted.count {
            let prev = sorted[index - 1]
            let curr = sorted[index]
            let gap = curr.startTime - prev.endTime
            if gap >= minPauseSeconds {
                gaps.append((start: prev.endTime, end: curr.startTime))
            }
        }
        guard !gaps.isEmpty else { return .empty }

        let durations = gaps.map { $0.end - $0.start }
        let mean = durations.reduce(0, +) / Double(durations.count)
        let longest = durations.max() ?? 0

        let fillerSet = Set(fillerStartTimes)
        let filledCount = gaps.filter { gap in
            // Any filler whose start lands inside this gap marks it filled.
            fillerSet.contains(where: { $0 >= gap.start && $0 <= gap.end })
        }.count
        let filledRatio = Double(filledCount) / Double(gaps.count)

        return PauseMetrics(
            count: gaps.count,
            meanSeconds: mean,
            longestSeconds: longest,
            filledRatio: filledRatio
        )
    }
}

// MARK: - Coaching read

extension PauseMetrics {
    /// Short, on-voice headline for the summary card. Avoids fake certainty
    /// when sample size is tiny.
    var headline: String {
        guard count > 0 else { return "No pauses to read this rep" }
        if count == 1 { return "One deliberate pause" }
        if filledRatio >= 0.5 { return "Pauses landing — but filled" }
        if filledRatio >= 0.25 { return "Mostly clean pauses" }
        return "Clean, composed pauses"
    }

    /// One-sentence body explaining what the numbers mean for coaching.
    var coachLine: String {
        guard count > 0 else {
            return "Long answers benefit from at least one held beat. The next rep is a chance to try one."
        }
        if filledRatio >= 0.5 {
            return "Your pauses are the right length, but most are filled with \"um\" or \"uh\". Replace one filler with a true silent beat next rep."
        }
        if longestSeconds >= 1.5 {
            return "You held a beat for \(formatSeconds(longestSeconds)). Listeners read that as composure — keep it."
        }
        return "Pauses are landing where they should — silent beats that let the point breathe."
    }

    private func formatSeconds(_ value: Double) -> String {
        if value >= 10 { return String(format: "%.0fs", value) }
        return String(format: "%.1fs", value)
    }
}
