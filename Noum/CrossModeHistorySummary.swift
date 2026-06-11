import Foundation

// MARK: - CrossModeHistorySummary
//
// Pure helper for the "All" filter on the session-history list — the
// one place the per-mode track-record pattern (Timed history, IM
// history, …) had no equivalent. Produces one compact row per mode
// the user has actually practiced: rep count, average score, and the
// same 7-day vs prior-7-day score trend the Timed card reads.
//
// Reuses `TimedHistorySummary.trendComparison` rather than declaring
// a parallel trend implementation: that helper is mode-agnostic (it
// windows by date and averages `session.score`), and reusing it means
// the All view and the Timed card can never disagree about what
// "up vs last week" means.
//
// Vision-aligned (docs/VISION.md pillar #4 — Believable progress):
// modes with zero sessions produce no row (no "0 reps" noise), modes
// with no scored reps carry a nil average (rendered as "—", never a
// fabricated number), and the trend is nil unless both 7-day windows
// hold at least one scored rep.

@available(iOS 17.0, *)
struct CrossModeHistoryModeRow: Equatable, Identifiable {
    let mode: PracticeMode
    /// Sessions recorded in this mode — scored or not. A saved rep is
    /// a rep, even when the user bailed before the summary.
    let repCount: Int
    /// Mean of `session.score` across scored reps, rounded to one
    /// decimal place. `nil` when no rep in this mode is scored.
    let averageScore: Double?
    /// 7-day vs prior-7-day mean score delta, reusing the Timed
    /// helper's windows and 0.3-point steady band. `nil` unless both
    /// windows hold ≥1 scored rep.
    let trend: TimedHistorySummaryStats.TrendComparison?
    /// Date of the most-recent session in this mode. Drives the sort:
    /// the mode the user touched last renders first, matching the
    /// per-difficulty / per-scenario ordering on the SD and IM cards.
    let lastPlayed: Date

    var id: PracticeMode { mode }
}

@available(iOS 17.0, *)
enum CrossModeHistorySummary {

    /// One row per mode with ≥1 session, most-recently played first.
    /// Empty input produces an empty array — the card self-hides.
    static func rows(
        from sessions: [PracticeSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CrossModeHistoryModeRow] {
        let grouped = Dictionary(grouping: sessions, by: \.mode)
        let rows: [CrossModeHistoryModeRow] = grouped.compactMap { (mode, modeSessions) in
            guard let lastPlayed = modeSessions.map(\.date).max() else { return nil }

            let scores = modeSessions.compactMap(\.score)
            let averageScore: Double? = {
                guard !scores.isEmpty else { return nil }
                let mean = Double(scores.reduce(0, +)) / Double(scores.count)
                return (mean * 10).rounded() / 10
            }()

            return CrossModeHistoryModeRow(
                mode: mode,
                repCount: modeSessions.count,
                averageScore: averageScore,
                trend: TimedHistorySummary.trendComparison(
                    sessions: modeSessions,
                    now: now,
                    calendar: calendar
                ),
                lastPlayed: lastPlayed
            )
        }
        return rows.sorted { $0.lastPlayed > $1.lastPlayed }
    }

    /// Total session count across every mode — the card header's
    /// counterpart to the per-mode cards' "N reps" label.
    static func totalRepCount(from sessions: [PracticeSession]) -> Int {
        sessions.count
    }
}
