#if canImport(SwiftUI)
import SwiftUI

// MARK: - SuddenDeathHistoryBreakdownCard
//
// Per-difficulty Sudden Death track record, rendered on the History
// screen when the user filters to Sudden Death. Reads from the
// `SuddenDeathRunHistoryStore` — the same source the Result-screen
// "Recent Runs" card pulls from — so the History view, the Result
// screen, and the high-score store can never drift.
//
// Each row is one difficulty. Reads:
//   • Best rounds survived (peak)
//   • Average rounds across runs (rounded to 1dp)
//   • Number of clean runs (zero fillers)
//   • Run count + most-recent run timestamp
//
// Self-hides when there are no Sudden Death runs yet (cold start) —
// rendering "0 runs" would just be visual noise on the History screen
// for a user who hasn't touched the mode.
//
// Vision-aligned (docs/VISION.md pillar #4): honest evidence from the
// engine's own write path. No narrative. No coach voice. Just the
// numbers the user produced, surfaced where they go to look back.

@available(iOS 17.0, *)
struct SuddenDeathHistoryBreakdownCard: View {

    let runs: [SuddenDeathRunRecord]
    /// Tap handler for a difficulty row. When `nil`, rows render
    /// read-only (no chevron, no button affordance). When provided,
    /// each row becomes a button + chevron and invokes the handler
    /// on tap. Existing read-only call sites (tests, previews) work
    /// unchanged by omitting the argument.
    var onSelectDifficulty: ((SuddenDeathDifficulty) -> Void)? = nil

    private var breakdowns: [SuddenDeathDifficultyBreakdown] {
        SuddenDeathHistorySummary.breakdowns(from: runs)
    }

    private var isInteractive: Bool { onSelectDifficulty != nil }

    private var totalRuns: Int {
        SuddenDeathHistorySummary.totalRunCount(from: runs)
    }

    private var mostRecent: Date? {
        SuddenDeathHistorySummary.mostRecentDate(from: runs)
    }

    /// Highest-round run inside the most-recent 7 days, when any. Used
    /// to surface a "Best this week: N · <difficulty>" chip in the
    /// card header so the user reads "your current peak" at a glance
    /// without having to scan all three difficulty rows. Mirrors the
    /// `bestIsThisWeek` / `cleanestIsThisWeek` chips on the Timed +
    /// Ah-Counter cards.
    private var bestThisWeek: SuddenDeathRunRecord? {
        SuddenDeathHistorySummary.bestThisWeek(from: runs)
    }

    private let accent = AppColor.modeSuddenDeath

    var body: some View {
        if !breakdowns.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                header
                rowsSection
            }
            .padding(Spacing.lg)
            .background(cardBackground)
            .shadow(color: accent.opacity(0.14), radius: 14, x: 0, y: 6)
            .accessibilityIdentifier("history.suddenDeath.breakdown")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                Text("Pressure Drill history")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(runCountLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let mostRecent {
                Text("Last run \(mostRecent.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if let best = bestThisWeek {
                bestThisWeekChip(best)
            }
        }
    }

    /// "BEST THIS WEEK · N · <difficulty>" capsule. Renders only when
    /// at least one run lives inside the 7-day window. Visual register
    /// matches the Timed/Ah-Counter "THIS WEEK" chip but carries the
    /// data point (rounds + difficulty) on the same line because SD's
    /// breakdown rows are per-difficulty — the chip is the only place
    /// the user reads "current peak" at a glance without scanning.
    private func bestThisWeekChip(_ run: SuddenDeathRunRecord) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.caption2.weight(.bold))
            Text(bestThisWeekChipCopy(run))
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(accent.opacity(0.12), in: Capsule())
        .accessibilityLabel("Best this week: \(run.roundsSurvived) rounds at \(run.difficulty.title).")
        .accessibilityIdentifier("history.suddenDeath.bestThisWeek")
    }

    private func bestThisWeekChipCopy(_ run: SuddenDeathRunRecord) -> String {
        let unit = run.roundsSurvived == 1 ? "round" : "rounds"
        return "Best this week · \(run.roundsSurvived) \(unit) · \(run.difficulty.title)"
    }

    private var runCountLabel: String {
        totalRuns == 1 ? "1 run" : "\(totalRuns) runs"
    }

    // MARK: - Rows

    private var rowsSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(breakdowns.enumerated()), id: \.element.id) { index, breakdown in
                wrappedRow(breakdown)
                if index < breakdowns.count - 1 {
                    Divider()
                        .padding(.vertical, 10)
                }
            }
        }
    }

    /// Wraps `breakdownRow` in a `Button` when an interactive handler
    /// is supplied, so the row picks up `.pressable` press feedback
    /// + voice-over button semantics. Stays as a plain row when no
    /// handler is provided.
    @ViewBuilder
    private func wrappedRow(_ breakdown: SuddenDeathDifficultyBreakdown) -> some View {
        if let onSelectDifficulty {
            Button {
                onSelectDifficulty(breakdown.difficulty)
            } label: {
                breakdownRow(breakdown)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("history.suddenDeath.row.\(breakdown.difficulty.rawValue)")
        } else {
            breakdownRow(breakdown)
        }
    }

    @ViewBuilder
    private func breakdownRow(_ breakdown: SuddenDeathDifficultyBreakdown) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(breakdown.difficulty.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(runCountText(for: breakdown))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            statColumn(value: "\(breakdown.bestRounds)", label: "best")
            statColumn(value: averageLabel(for: breakdown.averageRounds), label: "avg")
            statColumn(value: "\(breakdown.cleanRunCount)", label: "clean")
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: breakdown))
        .accessibilityHint(isInteractive ? "Open the full run list at this difficulty." : "")
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(minWidth: 44, alignment: .center)
    }

    private func runCountText(for breakdown: SuddenDeathDifficultyBreakdown) -> String {
        let unit = breakdown.runCount == 1 ? "run" : "runs"
        return "\(breakdown.runCount) \(unit)"
    }

    private func averageLabel(for value: Double) -> String {
        // Whole numbers render without the trailing ".0" so "8 best /
        // 6 avg" reads cleanly; non-whole shows one decimal place.
        if value == value.rounded() {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private func accessibilityLabel(for breakdown: SuddenDeathDifficultyBreakdown) -> String {
        let cleanLabel = breakdown.cleanRunCount == 1 ? "1 clean run" : "\(breakdown.cleanRunCount) clean runs"
        return "\(breakdown.difficulty.title): \(breakdown.runCount) runs, best \(breakdown.bestRounds), average \(averageLabel(for: breakdown.averageRounds)) rounds, \(cleanLabel)"
    }

    // MARK: - Background
    //
    // Mirrors the M14 hero treatment used elsewhere on the History
    // surface (`heroBackground` on summary strip, `heroCardBackground`
    // on detail). Mode-tinted radial wash + tint border. Lifts the
    // surface so it reads as a hero card rather than a list row.

    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [accent.opacity(0.18), accent.opacity(0.05), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 320
                )
            )
            shape.strokeBorder(accent.opacity(0.25), lineWidth: 1)
        }
    }
}

#endif
