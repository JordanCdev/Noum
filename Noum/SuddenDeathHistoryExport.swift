import Foundation

// MARK: - SuddenDeathHistoryExport
//
// Pure formatter for the user's Sudden Death run history. Produces a
// plain-text table the user can paste into Notes, Messages, an email
// thread — anywhere they want a record of their track record outside
// the app.
//
// Vision-aligned (docs/VISION.md anti-goals): the user's transcripts
// are NEVER part of this export — only the engine's own outcome
// numbers (tier reached, rounds cleared, the named outcome that ended
// the run, the date). That mirrors the leaderboard rule: "never publishes
// raw transcripts." A History export should match the same posture
// since the user might share it with anyone.
//
// Two surface shapes:
//   • `formatPlainText(runs:difficulty:)` — single-difficulty
//     filtered export, used by the per-difficulty drill-down view.
//   • `formatPlainText(runs:)` — full-history export across all
//     difficulties, grouped by difficulty header.

@available(iOS 17.0, *)
enum SuddenDeathHistoryExport {

    // MARK: - Public API

    /// Format a single-difficulty run list as a plain-text table.
    /// Empty input returns the same "no runs yet" copy as the cross-
    /// difficulty variant so callers can hand a `ShareLink` the result
    /// unconditionally — the user gets honest copy when they tap
    /// Share before ever finishing a run.
    static func formatPlainText(
        runs: [SuddenDeathRunRecord],
        difficulty: SuddenDeathDifficulty
    ) -> String {
        let filtered = runs
            .filter { $0.difficulty == difficulty }
            .sorted { $0.completedAt > $1.completedAt }
        guard !filtered.isEmpty else {
            return "Noum · Sudden Death · \(difficulty.title)\nNo runs at this difficulty yet."
        }
        var lines: [String] = []
        lines.append("Noum · Sudden Death · \(difficulty.title)")
        lines.append("\(filtered.count) run\(filtered.count == 1 ? "" : "s") · best \(maxRounds(filtered)) round\(maxRounds(filtered) == 1 ? "" : "s")")
        lines.append("")
        lines.append(headerRow())
        for run in filtered {
            lines.append(formatRow(run))
        }
        return lines.joined(separator: "\n")
    }

    /// Format the entire run history across every difficulty,
    /// grouped by difficulty header. Used by the Result-screen-level
    /// export affordance.
    static func formatPlainText(runs: [SuddenDeathRunRecord]) -> String {
        guard !runs.isEmpty else {
            return "Noum · Sudden Death history\nNo runs yet."
        }
        var lines: [String] = []
        lines.append("Noum · Sudden Death history")
        lines.append("\(runs.count) total run\(runs.count == 1 ? "" : "s")")

        let grouped = Dictionary(grouping: runs, by: \.difficulty)
        // Stable difficulty order so the export reads the same way
        // every time even when the user has runs in different
        // difficulties — Easy first, then Medium, then Hard.
        let order: [SuddenDeathDifficulty] = [.easy, .medium, .hard]
        for difficulty in order {
            guard let group = grouped[difficulty], !group.isEmpty else { continue }
            let sorted = group.sorted { $0.completedAt > $1.completedAt }
            lines.append("")
            lines.append("--- \(difficulty.title) (\(sorted.count) run\(sorted.count == 1 ? "" : "s") · best \(maxRounds(sorted))) ---")
            lines.append(headerRow())
            for run in sorted {
                lines.append(formatRow(run))
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Internal helpers (exposed for tests)

    /// One header row used by both single- and full-history exports
    /// so the column shape is identical across surfaces.
    static func headerRow() -> String {
        "Date | Tier | Cleared | Outcome"
    }

    /// Format a single run as one row in the table. Pure — no
    /// localization, no relative-date phrasing (the export should
    /// read the same a year later if the user pastes it from an
    /// archive).
    static func formatRow(_ run: SuddenDeathRunRecord) -> String {
        let date = isoDate(run.completedAt)
        let outcome = outcomeLabel(run.finalOutcome)
        let best = run.wasNewBestAtTime ? " (best)" : ""
        return "\(date) | \(tierReached(in: run)) | \(run.roundsSurvived) | \(outcome)\(best)"
    }

    static func outcomeLabel(_ outcome: RoundOutcome) -> String {
        switch outcome {
        case .survived:            return "Survived"
        case .timeoutBeforeStart:  return "Timeout"
        case .fillerOverload:      return "Filler overload"
        case .tooShort:            return "Too short"
        }
    }

    // MARK: - Private

    private static func maxRounds(_ runs: [SuddenDeathRunRecord]) -> Int {
        runs.map(\.roundsSurvived).max() ?? 0
    }

    private static func tierReached(in run: SuddenDeathRunRecord) -> Int {
        max(1, run.roundsSurvived + (run.finalOutcome.isFailed ? 1 : 0))
    }

    /// `yyyy-MM-dd` in the user's local calendar. ISO so the export
    /// reads cleanly regardless of system locale.
    private static func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
