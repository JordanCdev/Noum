import SwiftUI

/// "Your trajectory" — the fuller, self-serve view behind the Ask Noum memory
/// pill. Shows exactly what's feeding personalization: goals, the most recent
/// reps, and week-over-week deltas with a concrete example rep behind each
/// one. Every section either renders bounded, real data from
/// `TrajectorySummaryBuilder` or an honest "not enough yet" state — nothing
/// here is invented. Editing routes through the existing goal-refresh flow
/// (`GoalRefreshManager` / `GoalRefreshInlineCard`) rather than a parallel
/// editor; there is no per-rep delete here because rep history is not owned
/// by this surface.
struct TrajectoryView: View {
    let snapshot: MemoryTrajectorySnapshot

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var goalRefresh = GoalRefreshManager.shared

    private var hasGoal: Bool { !snapshot.activeGoals.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    usingCard

                    if goalRefresh.shouldPresent {
                        GoalRefreshInlineCard()
                            .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
                    }

                    section(title: "Your goal", icon: "scope") {
                        if hasGoal {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(snapshot.activeGoals.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(Typography.body)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            editGoalButton
                        } else {
                            emptyRow("No goal set yet. Noum stays generic until you set one.")
                            editGoalButton
                        }
                    }

                    section(title: "Recent reps", icon: "waveform") {
                        if snapshot.recentReps.isEmpty {
                            emptyRow("No reps yet — your practice history will show up here.")
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(snapshot.recentReps) { rep in
                                    repRow(rep)
                                }
                            }
                        }
                    }

                    section(title: "Weekly trend", icon: "chart.line.uptrend.xyaxis") {
                        if snapshot.trendSignals.isEmpty {
                            emptyRow("Not enough reps this week and last week to compare yet.")
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(snapshot.trendSignals) { signal in
                                    trendRow(signal)
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .background(AppColor.screenBackground.ignoresSafeArea())
            .navigationTitle("Your trajectory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("trajectory.done")
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: goalRefresh.shouldPresent)
    }

    // MARK: - Sections

    private var usingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Using in this answer")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(snapshot.userVisibility)
                .font(Typography.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let days = snapshot.evidenceFreshnessDays {
                Text(freshnessLabel(days: days))
                    .font(Typography.caption)
                    .foregroundStyle(snapshot.isStale ? AppColor.caution : .secondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.pro.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func section<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            content()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private func repRow(_ rep: MemoryRepEvidence) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rep.summaryLine)
                    .font(Typography.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Text(relativeDayLabel(rep.daysAgo))
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func trendRow(_ signal: MemoryTrendSignal) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: trendIcon(for: signal.direction))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(trendTint(for: signal.direction))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(signal.metricLabel)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(signal.deltaLine)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                if let example = signal.exampleEvidenceLine {
                    Text(example)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var editGoalButton: some View {
        Button {
            goalRefresh.requestReview()
        } label: {
            Label("Edit goal", systemImage: "pencil.line")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .accessibilityIdentifier("trajectory.editGoal")
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Formatting

    private func relativeDayLabel(_ days: Int) -> String {
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days) days ago"
        }
    }

    private func freshnessLabel(days: Int) -> String {
        if snapshot.isStale {
            return "Most recent rep: \(relativeDayLabel(days).lowercased()) — may be out of date."
        }
        return "Most recent rep: \(relativeDayLabel(days).lowercased())."
    }

    private func trendIcon(for direction: TrendDirection) -> String {
        switch direction {
        case .improving, .resolved: return "arrow.up.forward"
        case .declining, .newIssue: return "arrow.down.forward"
        case .stable: return "minus"
        }
    }

    private func trendTint(for direction: TrendDirection) -> Color {
        switch direction {
        case .improving, .resolved: return AppColor.positive
        case .declining, .newIssue: return AppColor.caution
        case .stable: return .secondary
        }
    }
}
