import Foundation

// MARK: - AhCounterHistorySummary
//
// Pure helper for summarizing Ah-Counter reps. Lives next to
// `SuddenDeathHistorySummary` so the History surface has a consistent
// shape across modes: filter to a mode → see a per-mode hero card
// above the generic session rows.
//
// Ah-Counter is "the filler-eradication classic" — the only signal
// that matters is how many fillers leaked through, normalised against
// how long the user spoke. So the per-mode summary distils to four
// numbers the user actually reads:
//   • Total reps recorded in this mode
//   • Cleanest rep (fewest fillers per minute, with the absolute
//     filler count surfaced too — "0 fillers · 1:24" beats "0.0/min")
//   • Average fillers per minute across all reps in the mode
//   • Clean-rep count (zero fillers — the "clutch" wins)
//   • 7-day vs prior-7-day delta — the honest direction signal
//
// The 7-day/prior-7-day comparison is the only "trend" the helper
// computes — and only when both windows have at least one rep. No
// invented direction copy when there isn't enough data to read one.
//
// Vision-aligned (docs/VISION.md pillar #4 — Believable progress):
// the user sees their actual track record in their filler-fighting
// mode, computed from the session records the engine wrote at
// finalize time. No narrative. No coach voice. Numbers only.

@available(iOS 17.0, *)
struct AhCounterHistorySummaryStats: Equatable {
    let runCount: Int
    /// Reps whose filler mechanics clear the shared historical comparison
    /// boundary. `runCount` stays factual; this denominator explains how many
    /// of those saved reps may support filler-rate progress claims.
    let fillerMeasuredRepCount: Int
    /// Mean of (fillerWordCount / durationMinutes) across qualified reps. ≥ 0.
    /// `nil` when no rep carries comparable filler evidence.
    let averageFillersPerMinute: Double?
    /// The rep with the lowest fillers-per-minute. `nil` on empty
    /// input. When there's a multi-way tie, the most-recent qualifying
    /// rep wins (user reads "today's clean rep" before "last month's
    /// clean rep").
    let cleanest: CleanestRep?
    /// Number of qualified reps with `fillerWordCount == 0`. An unqualified
    /// zero is still inspectable on its saved row, but cannot become a clean
    /// progress claim.
    let cleanRepCount: Int
    /// Per-minute filler rate over the most recent 7 calendar days,
    /// and over the 7 days before that. Only set when BOTH windows
    /// have ≥1 qualified filler-rate rep; otherwise nil so the surface
    /// omits the trend rather than fabricating it.
    let trend: TrendComparison?
    /// `true` when `cleanest.date` lands inside the current 7-day
    /// window (`now - 7d` ≤ date ≤ `now`). Drives the "Cleanest this
    /// week" chip on the breakdown card — gives the user the "is my
    /// best rep current or stale?" read in one glance. Independent of
    /// the trend chip (which compares average rate, not best-rep dates).
    let cleanestIsThisWeek: Bool

    struct CleanestRep: Equatable {
        let sessionID: UUID
        let date: Date
        let fillerCount: Int
        let durationSeconds: TimeInterval
        let fillersPerMinute: Double
    }

    struct TrendComparison: Equatable {
        let recentSevenDayRate: Double
        let priorSevenDayRate: Double

        /// Positive when the recent window has a HIGHER filler rate
        /// (worse), negative when lower (better). Zero when identical.
        var deltaRate: Double { recentSevenDayRate - priorSevenDayRate }

        /// "improving" / "worsening" / "steady" — used for the
        /// caption copy. Bucketed against a 0.5-fillers-per-minute
        /// threshold so a 0.1/min swing reads as steady rather than
        /// movement (a 30-second rep with one filler shifts the rate
        /// by ~2/min; the threshold filters that noise).
        var direction: Direction {
            if abs(deltaRate) < 0.5 { return .steady }
            return deltaRate < 0 ? .improving : .worsening
        }

        enum Direction: Equatable {
            case improving
            case worsening
            case steady
        }
    }
}

@available(iOS 17.0, *)
enum AhCounterHistorySummary {

    /// Produce the summary stats from a list of `PracticeSession`
    /// rows. Callers pass already-filtered Ah-Counter sessions;
    /// defensive in any case — sessions whose `mode != .ahCounter` are
    /// dropped silently so an upstream filter mistake produces an
    /// empty result, not a misleading mixed-mode aggregate.
    static func summarize(
        sessions: [PracticeSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AhCounterHistorySummaryStats? {
        let ahCounterRuns = sessions.filter { $0.mode == .ahCounter }
        guard !ahCounterRuns.isEmpty else { return nil }

        // Cleanest rep: lowest qualified fillers-per-minute, tiebreak by most
        // recent date so the user reads their freshest clean rep first.
        let withRate: [(PracticeSession, Double)] = ahCounterRuns.compactMap { session in
            guard let rate = FillerBurden.quantityQualified(session)?.ratePerMinute else {
                return nil
            }
            return (session, rate)
        }
        let cleanest = withRate
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.date > rhs.0.date
            }
            .first
            .map { (session, rate) in
                AhCounterHistorySummaryStats.CleanestRep(
                    sessionID: session.id,
                    date: session.date,
                    fillerCount: session.fillerWordCount,
                    durationSeconds: session.duration,
                    fillersPerMinute: rate
                )
            }

        let averageFillersPerMinute: Double? = {
            guard !withRate.isEmpty else { return nil }
            let total = withRate.map(\.1).reduce(0, +)
            let mean = total / Double(withRate.count)
            return (mean * 10).rounded() / 10
        }()

        let cleanRepCount = withRate.reduce(0) { count, entry in
            count + (entry.0.fillerWordCount == 0 ? 1 : 0)
        }

        let trend = trendComparison(
            sessions: ahCounterRuns,
            now: now,
            calendar: calendar
        )

        let cleanestIsThisWeek = cleanest.map { isThisWeek(date: $0.date, now: now, calendar: calendar) } ?? false

        return AhCounterHistorySummaryStats(
            runCount: ahCounterRuns.count,
            fillerMeasuredRepCount: withRate.count,
            averageFillersPerMinute: averageFillersPerMinute,
            cleanest: cleanest,
            cleanRepCount: cleanRepCount,
            trend: trend,
            cleanestIsThisWeek: cleanestIsThisWeek
        )
    }

    /// Pure 7-day window test, exposed for tests. A date counts as
    /// "this week" when it lands inside the most-recent 7 days from
    /// `now` (inclusive). Same shape as `TimedHistorySummary.isThisWeek`
    /// so the two surfaces agree on the boundary.
    static func isThisWeek(
        date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let windowStart = calendar.date(byAdding: .day, value: -7, to: now) else {
            return false
        }
        return date >= windowStart && date <= now
    }

    // MARK: - Trend helpers (internal — exposed for tests)

    /// 7-day vs prior 7-day mean filler-rate comparison. Both windows
    /// must have ≥1 qualified rep — otherwise `nil` so the UI omits
    /// the trend chip rather than rendering a single-point "direction."
    static func trendComparison(
        sessions: [PracticeSession],
        now: Date,
        calendar: Calendar
    ) -> AhCounterHistorySummaryStats.TrendComparison? {
        let recentWindowStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let priorWindowStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let recent = sessions.filter { $0.date >= recentWindowStart && $0.date <= now }
        let prior = sessions.filter { $0.date >= priorWindowStart && $0.date < recentWindowStart }
        let recentRate = meanRate(sessions: recent)
        let priorRate = meanRate(sessions: prior)
        guard let recentRate, let priorRate else { return nil }
        return AhCounterHistorySummaryStats.TrendComparison(
            recentSevenDayRate: recentRate,
            priorSevenDayRate: priorRate
        )
    }

    private static func meanRate(sessions: [PracticeSession]) -> Double? {
        let rates = FillerBurden.quantityQualifiedRatesPerMinute(in: sessions)
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }
}
