import Foundation

// MARK: - TimedHistorySummary
//
// Pure helper for summarizing Timed reps. Mirrors
// `AhCounterHistorySummary` and `SuddenDeathHistorySummary` so the
// History surface reads as one design language across every mode:
// filter to a mode → see a per-mode hero card above the generic
// session rows.
//
// Timed is the mode where the user's job is "answer this prompt
// inside the bell" — so the per-mode signal is delivery quality:
// score, pace (WPM), and whether the rep landed inside the WPM zone
// the engine defines for the mode (130–160 WPM per
// `Noum/Noum/WPMEvaluator.swift` Timed band). No per-difficulty
// breakdown because difficulty isn't persisted on `PracticeSession`;
// the score the evaluator emits already reflects difficulty (the
// duration assessment + xpMultiplier are folded into it). What the
// user reads here is the same number the engine emitted at finalize.
//
// Vision-aligned (docs/VISION.md pillar #3 — Conversational
// intelligence + pillar #4 — Believable progress): the numbers
// come from the records the engine wrote. No invented stats; no
// narrative; just the data the user produced, surfaced where they
// go to look back.

@available(iOS 17.0, *)
struct TimedHistorySummaryStats: Equatable {
    let runCount: Int
    /// Mean of `session.score` across reps that have a score. Rounded
    /// to one decimal place. `nil` when no qualifying rep is scored
    /// (older sessions can carry `score == nil`).
    let averageScore: Double?
    /// Highest-scoring rep + date + the WPM at that rep. `nil` when no
    /// rep has been scored. Tiebreak by most-recent date so the user
    /// reads "today's peak" before "last month's peak" when both tie.
    let best: BestRep?
    /// Mean of `wordsPerMinute` across reps with a non-zero word
    /// count and measurable duration. Rounded to nearest integer.
    /// `nil` when no rep has measurable pace.
    let averageWPM: Int?
    /// Number of reps whose `wordsPerMinute` lands in the Timed zone
    /// (130–160 WPM, matching `WPMEvaluator` Timed band). Useful as a
    /// "delivery on-rails" signal without leaking the evaluator's
    /// internal scoring weights.
    let inZoneRepCount: Int
    /// 7-day vs prior-7-day mean score delta. Only set when BOTH
    /// windows have ≥1 scored rep; otherwise nil so the surface omits
    /// the trend rather than fabricating it.
    let trend: TrendComparison?

    struct BestRep: Equatable {
        let sessionID: UUID
        let date: Date
        let score: Int
        let wordsPerMinute: Int
    }

    struct TrendComparison: Equatable {
        let recentSevenDayAverage: Double
        let priorSevenDayAverage: Double

        /// Positive when the recent window has a HIGHER score
        /// (improving), negative when lower (declining). Zero when
        /// identical. Note the sign convention differs from
        /// `AhCounterHistorySummary.TrendComparison`: higher score is
        /// good, higher filler rate is bad — the direction enum below
        /// normalises this so callers always read `.improving`/
        /// `.worsening`/`.steady` the same way.
        var deltaScore: Double { recentSevenDayAverage - priorSevenDayAverage }

        /// Bucketed against a 0.3-point threshold so a single high or
        /// low rep doesn't flip the user's read. Timed scores are
        /// integer 1–10, so the realistic per-week mean shift is
        /// fractional; 0.3 filters single-rep noise without erasing
        /// real movement.
        var direction: Direction {
            if abs(deltaScore) < 0.3 { return .steady }
            return deltaScore > 0 ? .improving : .worsening
        }

        enum Direction: Equatable {
            case improving
            case worsening
            case steady
        }
    }
}

@available(iOS 17.0, *)
enum TimedHistorySummary {

    /// The WPM band the engine treats as "Timed zone" — sourced from
    /// `WPMEvaluator` (see `docs/CURRENT_STATE.md` "Speech & feedback"
    /// section). Exposed here as a constant pair so the in-zone
    /// counter and the test contract can reference the same range
    /// without re-declaring magic numbers.
    static let zoneMinWPM: Int = 130
    static let zoneMaxWPM: Int = 160

    /// Produce the summary stats from a list of `PracticeSession`
    /// rows. Callers pass already-filtered Timed sessions; defensive
    /// in any case — sessions whose `mode != .timed` are dropped
    /// silently so an upstream filter mistake produces an empty
    /// result, not a mixed-mode aggregate.
    static func summarize(
        sessions: [PracticeSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimedHistorySummaryStats? {
        let timedRuns = sessions.filter { $0.mode == .timed }
        guard !timedRuns.isEmpty else { return nil }

        // Average score across scored reps only — older sessions may
        // not have a score, and the average should reflect what the
        // engine actually emitted.
        let scoredRuns = timedRuns.compactMap { session -> (PracticeSession, Int)? in
            guard let score = session.score else { return nil }
            return (session, score)
        }
        let averageScore: Double? = {
            guard !scoredRuns.isEmpty else { return nil }
            let total = scoredRuns.map { Double($0.1) }.reduce(0, +)
            let mean = total / Double(scoredRuns.count)
            return (mean * 10).rounded() / 10
        }()

        // Best rep: highest score, tiebreak by most recent date.
        let best = scoredRuns
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.date > rhs.0.date
            }
            .first
            .map { (session, score) in
                TimedHistorySummaryStats.BestRep(
                    sessionID: session.id,
                    date: session.date,
                    score: score,
                    wordsPerMinute: session.wordsPerMinute
                )
            }

        // Average WPM across reps with measurable pace (skips
        // zero-duration or zero-word reps; same defensive contract as
        // the Ah-Counter helper's rate-per-minute path).
        let paceRuns = timedRuns.filter { $0.duration > 0 && $0.wordCount > 0 }
        let averageWPM: Int? = {
            guard !paceRuns.isEmpty else { return nil }
            let total = paceRuns.map { Double($0.wordsPerMinute) }.reduce(0, +)
            return Int((total / Double(paceRuns.count)).rounded())
        }()

        let inZoneRepCount = timedRuns.reduce(0) { count, session in
            let wpm = session.wordsPerMinute
            return wpm >= zoneMinWPM && wpm <= zoneMaxWPM ? count + 1 : count
        }

        let trend = trendComparison(
            sessions: timedRuns,
            now: now,
            calendar: calendar
        )

        return TimedHistorySummaryStats(
            runCount: timedRuns.count,
            averageScore: averageScore,
            best: best,
            averageWPM: averageWPM,
            inZoneRepCount: inZoneRepCount,
            trend: trend
        )
    }

    // MARK: - Trend helpers (internal — exposed for tests)

    /// 7-day vs prior 7-day mean-score comparison. Both windows must
    /// have ≥1 scored rep — otherwise `nil` so the UI omits the
    /// trend chip rather than rendering a single-point "direction."
    static func trendComparison(
        sessions: [PracticeSession],
        now: Date,
        calendar: Calendar
    ) -> TimedHistorySummaryStats.TrendComparison? {
        let recentWindowStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let priorWindowStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let recent = sessions.filter { $0.date >= recentWindowStart && $0.date <= now }
        let prior = sessions.filter { $0.date >= priorWindowStart && $0.date < recentWindowStart }
        guard !recent.isEmpty, !prior.isEmpty else { return nil }

        guard let recentMean = meanScore(sessions: recent),
              let priorMean = meanScore(sessions: prior) else {
            return nil
        }
        return TimedHistorySummaryStats.TrendComparison(
            recentSevenDayAverage: recentMean,
            priorSevenDayAverage: priorMean
        )
    }

    private static func meanScore(sessions: [PracticeSession]) -> Double? {
        let scores = sessions.compactMap { $0.score }.map(Double.init)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }
}
