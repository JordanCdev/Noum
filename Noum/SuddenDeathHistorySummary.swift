import Foundation

// MARK: - SuddenDeathHistorySummary
//
// Pure helper for summarizing Sudden Death runs by difficulty. Lives
// here so the breakdown card on `SessionHistoryView` (and any future
// surface that wants the same read) can call a single function and
// test against a fixed set of inputs.
//
// The Sudden Death runs are stored in `SuddenDeathRunHistoryStore`
// separately from the generic `PracticeSessionStore` (the rich engine-
// specific stats — rounds survived, finalOutcome, etc. — don't live on
// `PracticeSession`). The History surface filters `PracticeSession`
// rows by mode, which renders each Sudden Death rep generically. The
// breakdown produced here is the bridge: when the user filters to
// Sudden Death, the breakdown card surfaces the per-difficulty track
// record above the generic rows so the engine's honest data is
// reachable from History instead of only from the per-run Result
// screen.
//
// Vision-aligned (docs/VISION.md pillar #4 — Believable progress):
// the user sees their own track record, computed from the records the
// engine wrote at finalize time. No invented trend, no narrative.

@available(iOS 17.0, *)
struct SuddenDeathDifficultyBreakdown: Equatable, Identifiable {
    let difficulty: SuddenDeathDifficulty
    let runCount: Int
    let bestRounds: Int
    /// Mean of `roundsSurvived` across runs at this difficulty,
    /// rounded to one decimal place.
    let averageRounds: Double
    /// Number of runs with `totalFillers == 0` — the honest "clean
    /// runs" signal in a mode that's all about filler eradication.
    let cleanRunCount: Int
    /// `completedAt` of the most-recent run at this difficulty. Used
    /// to sort the breakdown so the difficulty the user touched last
    /// renders first.
    let lastPlayed: Date

    var id: SuddenDeathDifficulty { difficulty }
}

@available(iOS 17.0, *)
enum SuddenDeathHistorySummary {

    /// Produce per-difficulty breakdowns from the full run history.
    /// Empty inputs produce an empty array. Sort order: most-recently
    /// played first (so a user who's been grinding Hard sees Hard at
    /// the top even when they have older Medium runs).
    static func breakdowns(from runs: [SuddenDeathRunRecord]) -> [SuddenDeathDifficultyBreakdown] {
        guard !runs.isEmpty else { return [] }
        let grouped = Dictionary(grouping: runs, by: \.difficulty)
        let summaries: [SuddenDeathDifficultyBreakdown] = grouped.compactMap { (difficulty, runs) in
            guard let lastPlayed = runs.map(\.completedAt).max() else { return nil }
            let best = runs.map(\.roundsSurvived).max() ?? 0
            let total = runs.reduce(0) { $0 + $1.roundsSurvived }
            let avgRaw = Double(total) / Double(runs.count)
            let avgRounded = (avgRaw * 10).rounded() / 10
            let cleanCount = runs.reduce(0) { $0 + ($1.totalFillers == 0 ? 1 : 0) }
            return SuddenDeathDifficultyBreakdown(
                difficulty: difficulty,
                runCount: runs.count,
                bestRounds: best,
                averageRounds: avgRounded,
                cleanRunCount: cleanCount,
                lastPlayed: lastPlayed
            )
        }
        return summaries.sorted { $0.lastPlayed > $1.lastPlayed }
    }

    /// Total run count across every difficulty. Used by the card
    /// header so the user can read "12 total runs" at a glance
    /// without summing per-difficulty.
    static func totalRunCount(from runs: [SuddenDeathRunRecord]) -> Int {
        runs.count
    }

    /// Most recent `completedAt` across the entire run set, or nil
    /// when empty. Used to decide whether to render the card at all
    /// (and for the "Last played" subtitle).
    static func mostRecentDate(from runs: [SuddenDeathRunRecord]) -> Date? {
        runs.map(\.completedAt).max()
    }

    // MARK: - Sessions-based fallback (runs store empty, sessions exist)
    //
    // `SuddenDeathRunRecord` rows are written only when the Result
    // screen appears (`SuddenDeathResultView`), so a device can hold
    // real Pressure Drill `PracticeSession` rows with an empty run
    // store — observed on the owner's device in the 2026-06-10
    // feedback video, where the Pressure Drill filter showed no
    // summary card at all. This fallback summarizes what the generic
    // session store *does* hold for the mode — rep count, average
    // score, best rep — so the filter still opens with an honest
    // track record instead of nothing.
    //
    // Score-based, not rounds-based: rounds survived live only on the
    // run records. No invented rounds; the card switches to the
    // richer per-difficulty breakdown the moment a run record exists.

    struct SessionFallbackStats: Equatable {
        /// Pressure Drill sessions recorded — scored or not. A saved
        /// rep is a rep, even when the user bailed before the summary.
        let repCount: Int
        /// Mean of `session.score` across scored reps, rounded to one
        /// decimal place. `nil` when no rep is scored.
        let averageScore: Double?
        /// Highest-scoring rep, tiebreak by most-recent date. `nil`
        /// when no rep is scored.
        let best: BestRep?

        struct BestRep: Equatable {
            let sessionID: UUID
            let date: Date
            let score: Int
        }
    }

    /// Summarize Pressure Drill `PracticeSession` rows. Defensive on
    /// mode — non-Sudden-Death sessions are dropped silently so an
    /// upstream filter mistake produces an empty result, not a
    /// mixed-mode aggregate. Returns nil when no Pressure Drill
    /// session exists (the card self-hides; same cold-start contract
    /// as the run-based breakdown).
    static func sessionFallback(from sessions: [PracticeSession]) -> SessionFallbackStats? {
        let reps = sessions.filter { $0.mode == .suddenDeath }
        guard !reps.isEmpty else { return nil }

        let scored = reps.compactMap { session -> (PracticeSession, Int)? in
            guard let score = session.score else { return nil }
            return (session, score)
        }
        let averageScore: Double? = {
            guard !scored.isEmpty else { return nil }
            let mean = scored.map { Double($0.1) }.reduce(0, +) / Double(scored.count)
            return (mean * 10).rounded() / 10
        }()
        let best = scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.date > rhs.0.date
            }
            .first
            .map { (session, score) in
                SessionFallbackStats.BestRep(
                    sessionID: session.id,
                    date: session.date,
                    score: score
                )
            }

        return SessionFallbackStats(
            repCount: reps.count,
            averageScore: averageScore,
            best: best
        )
    }

    /// "Best rep of the current 7-day window" — the highest
    /// rounds-survived among runs whose `completedAt` lands inside
    /// the most-recent 7 days from `now`. Tiebreak by most-recent
    /// date so the user reads "today's best" before "Tuesday's best"
    /// when both tie at the same round count. Returns nil when no
    /// run falls inside the window. Mirrors the shape of the per-mode
    /// `bestIsThisWeek` / `cleanestIsThisWeek` flags on the other
    /// helpers — used by the SD breakdown card to surface a "Best
    /// this week: N · <difficulty>" chip when there's a current peak.
    static func bestThisWeek(
        from runs: [SuddenDeathRunRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SuddenDeathRunRecord? {
        guard let windowStart = calendar.date(byAdding: .day, value: -7, to: now) else {
            return nil
        }
        let inWindow = runs.filter { $0.completedAt >= windowStart && $0.completedAt <= now }
        guard !inWindow.isEmpty else { return nil }
        return inWindow.sorted { lhs, rhs in
            if lhs.roundsSurvived != rhs.roundsSurvived {
                return lhs.roundsSurvived > rhs.roundsSurvived
            }
            return lhs.completedAt > rhs.completedAt
        }.first
    }
}
