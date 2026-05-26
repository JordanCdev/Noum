#if canImport(SwiftUI)
import SwiftUI

// MARK: - Sudden Death Recent Runs Card

@available(iOS 17.0, *)
struct SuddenDeathRecentRunsCard: View {

    let currentRunID: UUID
    let runs: [SuddenDeathRunRecord]

    private let accentColor = AppColor.modeSuddenDeath

    var body: some View {
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
            Text("Recent Runs")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
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
            Image(systemName: run.wasNewBestAtTime ? "trophy.fill" : "bolt.fill")
                .font(.subheadline)
                .foregroundStyle(run.wasNewBestAtTime ? Color.yellow : accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Tier \(reachedTier(for: run))")
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

            if run.gamePoints > 0 {
                Text("\(run.gamePoints.formatted()) pts")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(accentColor)
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

    // MARK: - Footer hint

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
        let points = runs.compactMap { $0.gamePoints > 0 ? $0.gamePoints : nil }
        guard points.count >= 3 else { return nil }
        guard let current = points.first else { return nil }
        let prior = Array(points.dropFirst())
        let priorSorted = prior.sorted()
        let median: Double
        if priorSorted.count % 2 == 1 {
            median = Double(priorSorted[priorSorted.count / 2])
        } else {
            let mid = priorSorted.count / 2
            median = Double(priorSorted[mid - 1] + priorSorted[mid]) / 2.0
        }
        let threshold = median * 0.3
        if Double(current) >= median + threshold {
            return "Above your usual run."
        }
        if Double(current) <= median - threshold {
            return "Below your usual run. One rep, not a trend."
        }
        return nil
    }

    // MARK: - Helpers

    private func reachedTier(for run: SuddenDeathRunRecord) -> Int {
        max(1, run.roundsSurvived + (run.finalOutcome.isFailed ? 1 : 0))
    }

    private func relativeDateLabel(for date: Date, isCurrent: Bool) -> String {
        if isCurrent { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
#endif
