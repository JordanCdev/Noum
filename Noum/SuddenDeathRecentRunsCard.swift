#if canImport(SwiftUI)
import SwiftUI

// MARK: - Sudden Death Recent Runs Card
//
// Compact "last N runs at this difficulty" surface for the Result
// screen. Honest evidence: each row is the actual run record the
// engine wrote at finalize — rounds survived, fillers, the outcome
// that ended the run, and the day. No invented trend lines, no
// "you're improving!" copy unless the data actually supports it.
//
// Vision-aligned: this is the "believable progress" pillar — the
// user sees their own track record, not a coach-narrated story
// about it. The current run renders FIRST and is visually anchored
// ("Just now" + filled-in badge) so the user has a clear "this run
// vs. those" comparison without having to read.

@available(iOS 17.0, *)
struct SuddenDeathRecentRunsCard: View {

    let currentRunID: UUID
    let runs: [SuddenDeathRunRecord]
    let difficulty: SuddenDeathDifficulty

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accentColor = AppColor.modeSuddenDeath

    var body: some View {
        // Only render when there are at least 2 runs (the current one
        // plus at least one prior). A single-row history is just a
        // restatement of the stats row above — no signal.
        if runs.count >= 2 {
            VStack(alignment: .leading, spacing: 12) {
                header
                rowsSection
                footerHint
            }
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Text("Recent runs · \(difficulty.title)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            Text("\(runs.count) shown")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Rows

    private var rowsSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(runs.enumerated()), id: \.element.id) { index, run in
                runRow(run: run, isCurrent: run.id == currentRunID)
                if index < runs.count - 1 {
                    Divider()
                        .padding(.vertical, 6)
                }
            }
        }
    }

    private func runRow(run: SuddenDeathRunRecord, isCurrent: Bool) -> some View {
        HStack(spacing: 10) {
            // Outcome indicator
            Image(systemName: run.finalOutcome.isFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(run.finalOutcome.isFailed ? AppColor.warning : AppColor.positive)
                .frame(width: 18)

            // Rounds + date column
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(run.roundsSurvived) round\(run.roundsSurvived == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if run.wasNewBestAtTime {
                        bestBadge
                    }
                }
                Text(relativeDateLabel(for: run.completedAt, isCurrent: isCurrent))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Inline stats
            HStack(spacing: 12) {
                statChip(value: "\(run.totalFillers)", label: "fillers", tint: run.totalFillers == 0 ? AppColor.positive : .secondary)
                statChip(value: "\(run.score)/10", label: "score", tint: .secondary)
            }
        }
        .padding(.vertical, 4)
        .background(
            isCurrent
                ? accentColor.opacity(0.06)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
        )
        .padding(.horizontal, isCurrent ? 6 : 0)
    }

    private var bestBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "trophy.fill")
                .font(.caption2.weight(.bold))
            Text("BEST")
                .font(.caption2.weight(.bold))
                .tracking(0.4)
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(Color.yellow.opacity(0.12), in: Capsule())
    }

    private func statChip(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Footer hint

    /// One-line honest read of the last 5 runs. Only emits a phrase
    /// when the data clearly supports it; otherwise stays silent so
    /// nothing fake makes it onto the screen.
    @ViewBuilder
    private var footerHint: some View {
        if let hint = honestTrendHint() {
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func honestTrendHint() -> String? {
        let rounds = runs.map { $0.roundsSurvived }
        guard rounds.count >= 3 else { return nil }
        // Compare current (newest) to median of prior runs at this
        // difficulty. The store is sorted newest-first.
        guard let current = rounds.first else { return nil }
        let prior = Array(rounds.dropFirst())
        let priorSorted = prior.sorted()
        let median: Double
        if priorSorted.count % 2 == 1 {
            median = Double(priorSorted[priorSorted.count / 2])
        } else {
            let mid = priorSorted.count / 2
            median = Double(priorSorted[mid - 1] + priorSorted[mid]) / 2.0
        }
        if Double(current) >= median + 2 {
            return "Above your usual run at \(difficulty.title)."
        }
        if Double(current) <= median - 2 {
            return "Below your usual run at \(difficulty.title). One rep — not a trend."
        }
        return nil
    }

    // MARK: - Helpers

    private func relativeDateLabel(for date: Date, isCurrent: Bool) -> String {
        if isCurrent { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
#endif
