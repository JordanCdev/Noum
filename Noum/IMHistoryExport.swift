import Foundation

// MARK: - IMHistoryExport
//
// Pure formatter for the user's IM Mode track record. Mirrors the
// shape of `SuddenDeathHistoryExport` — a plain-text table the user
// can paste anywhere they want a record of their conversational
// practice outside the app.
//
// Vision-aligned (docs/VISION.md anti-goals): the user's transcripts
// are NEVER part of this export. The IM mode produces rich
// conversation turns (`IMConversationTurn`) — those stay strictly
// inside the app. The export carries only the engine's outcome
// numbers (score, trust, tension at the final beat, target tone, the
// scenario, the date). Anyone the user shares this with sees their
// track record, never their words.
//
// Two surface shapes:
//   • `formatPlainText(sessions:scenario:)` — single-scenario
//     filtered export, used by the per-scenario drill-down view.
//   • `formatPlainText(sessions:)` — full-history export across all
//     scenarios, grouped by scenario header.

@available(iOS 17.0, *)
enum IMHistoryExport {

    // MARK: - Public API

    /// Format a single-scenario rep list as a plain-text table.
    /// Empty input returns the same "no reps yet" copy as the
    /// cross-scenario variant so callers can hand a `ShareLink` the
    /// result unconditionally.
    static func formatPlainText(
        sessions: [PracticeSession],
        scenario: IMConversationScenario
    ) -> String {
        let filtered = sessions
            .filter { $0.mode == .imConversation
                      && $0.imConversationDetails?.setup.scenario == scenario }
            .sorted { $0.date > $1.date }
        guard !filtered.isEmpty else {
            return "Noum — Conversation Practice — \(scenario.title)\nNo reps in this scenario yet."
        }
        var lines: [String] = []
        lines.append("Noum — Conversation Practice — \(scenario.title)")
        lines.append(headerSummaryLine(filtered))
        lines.append("")
        lines.append(headerRow())
        for session in filtered {
            lines.append(formatRow(session))
        }
        return lines.joined(separator: "\n")
    }

    /// Format the entire IM history across every scenario, grouped
    /// by scenario header. Stable scenario order so the export reads
    /// the same way every time.
    static func formatPlainText(sessions: [PracticeSession]) -> String {
        let imSessions = sessions.filter {
            $0.mode == .imConversation && $0.imConversationDetails != nil
        }
        guard !imSessions.isEmpty else {
            return "Noum — Conversation Practice history\nNo reps yet."
        }
        var lines: [String] = []
        lines.append("Noum — Conversation Practice history")
        lines.append("\(imSessions.count) total rep\(imSessions.count == 1 ? "" : "s")")

        let grouped = Dictionary(grouping: imSessions) {
            $0.imConversationDetails?.setup.scenario ?? .socialCatchUp
        }
        let order: [IMConversationScenario] = [
            .socialCatchUp, .workUpdate, .difficultConversation, .networking
        ]
        for scenario in order {
            guard let group = grouped[scenario], !group.isEmpty else { continue }
            let sorted = group.sorted { $0.date > $1.date }
            lines.append("")
            lines.append("--- \(scenario.title) (\(sorted.count) rep\(sorted.count == 1 ? "" : "s")\(bestTail(sorted))) ---")
            lines.append(headerRow())
            for session in sorted {
                lines.append(formatRow(session))
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Internal helpers (exposed for tests)

    /// One header row used by both single- and full-history exports
    /// so the column shape is identical across surfaces.
    static func headerRow() -> String {
        "Date | Score | Trust | Tension | Target tone"
    }

    /// Format a single rep as one row in the table. Pure — no
    /// localization, no relative-date phrasing (the export should
    /// read the same a year later if the user pastes it from an
    /// archive).
    static func formatRow(_ session: PracticeSession) -> String {
        let date = isoDate(session.date)
        let score = session.score.map { "\($0)/10" } ?? "—"
        let trust = session.imConversationDetails?.finalState
            .map { "\($0.normalizedTrust)/10" } ?? "—"
        let tension = session.imConversationDetails?.finalState
            .map { "\($0.normalizedTension)/10" } ?? "—"
        let tone = session.imConversationDetails?.setup.targetTone.title ?? "—"
        return "\(date) | \(score) | \(trust) | \(tension) | \(tone)"
    }

    /// `yyyy-MM-dd` in the user's local calendar. ISO so the export
    /// reads cleanly regardless of system locale.
    static func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Private

    private static func headerSummaryLine(_ sessions: [PracticeSession]) -> String {
        let count = sessions.count
        let bestScore = sessions.compactMap(\.score).max()
        let countCopy = "\(count) rep\(count == 1 ? "" : "s")"
        guard let bestScore else { return countCopy }
        return "\(countCopy) · best \(bestScore)/10"
    }

    private static func bestTail(_ sessions: [PracticeSession]) -> String {
        guard let bestScore = sessions.compactMap(\.score).max() else { return "" }
        return " · best \(bestScore)/10"
    }
}
