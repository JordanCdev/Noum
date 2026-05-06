#if canImport(SwiftUI)
import SwiftUI

// MARK: - Pause Summary Card
//
// Surfaces pause statistics for the just-finished session. Hides itself
// when there's nothing to read (no word timings captured) — better silence
// than fake certainty.
//
// Layout matches the rest of the summary cards: a tinted icon, on-voice
// headline + body, and a row of three concrete numbers (count, mean,
// longest). Filled-vs-unfilled ratio surfaces only when at least one
// pause was filled — otherwise it would just say "0% filled" which adds
// no signal.

@available(iOS 17.0, macOS 12.0, *)
struct PauseSummaryCard: View {
    let metrics: PauseMetrics

    private let tint: Color = AppColor.brandBlue

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pauses")
                        .font(Typography.micro)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text(metrics.headline)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(metrics.coachLine)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if metrics.count > 0 {
                HStack(spacing: 0) {
                    statCell(value: "\(metrics.count)", label: "Count")
                    divider
                    statCell(value: formatSeconds(metrics.meanSeconds), label: "Mean")
                    divider
                    statCell(value: formatSeconds(metrics.longestSeconds), label: "Longest")
                    if metrics.filledRatio > 0 {
                        divider
                        statCell(value: "\(Int((metrics.filledRatio * 100).rounded()))%", label: "Filled")
                    }
                }
                .padding(.vertical, Spacing.sm)
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityIdentifier("summary.pauseCard")
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.05))
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    private func formatSeconds(_ value: Double) -> String {
        if value >= 10 { return String(format: "%.0fs", value) }
        return String(format: "%.1fs", value)
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Pause card — clean") {
    PauseSummaryCard(metrics: PauseMetrics(
        count: 4,
        meanSeconds: 0.9,
        longestSeconds: 1.4,
        filledRatio: 0
    ))
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Pause card — filled-heavy") {
    PauseSummaryCard(metrics: PauseMetrics(
        count: 6,
        meanSeconds: 0.7,
        longestSeconds: 1.1,
        filledRatio: 0.67
    ))
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Pause card — none") {
    PauseSummaryCard(metrics: PauseMetrics.empty)
        .padding()
        .background(AppColor.screenBackground)
}
#endif

#endif
