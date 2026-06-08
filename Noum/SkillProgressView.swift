import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)

/// Expandable skill trend visualization for the summary screen.
/// Shows trend lines per skill area with direction indicators.
struct SkillProgressView: View {
    let trends: [SkillTrend]
    let drillHistory: [DrillHistoryStore.Entry]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            Text("Skill Progress")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            if trends.isEmpty {
                Text("Complete a few more sessions to see your skill trends.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Show trends sorted by priority: weakest first
                let sorted = trends.sorted { levelOrder($0.currentLevel) < levelOrder($1.currentLevel) }

                ForEach(sorted, id: \.id) { trend in
                    skillRow(trend)
                }
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Skill Row

    private func skillRow(_ trend: SkillTrend) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Skill icon
                Image(systemName: trend.skillArea.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(trend.skillArea.tint)
                    .frame(width: 28, height: 28)
                    .background(trend.skillArea.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Name and direction
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(trend.skillArea.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        directionBadge(trend.direction)
                    }

                    // Level bar
                    HStack(spacing: 4) {
                        levelBar(trend.currentLevel, tint: trend.skillArea.tint)

                        Text(trend.currentLevel.rawValue.capitalized)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Streak indicator
                let streak = drillStreak(for: trend.skillArea)
                if streak >= 2 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("\(streak)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Trend context line — human-readable trajectory summary
            Text(TrendFramingCopy.trendContext(
                direction: trend.direction,
                confidence: trend.confidence,
                sessionsInWindow: trend.windowSize
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 40) // align with text, past the icon
        }
    }

    // MARK: - Components

    private func directionBadge(_ direction: TrendDirection) -> some View {
        Group {
            switch direction {
            case .improving:
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                    Text("Improving")
                        .font(Typography.figtree(size: 9, weight: .bold, relativeTo: .caption2))
                }
                .foregroundStyle(AppColor.positive)
            case .declining:
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                    Text("Slipping")
                        .font(Typography.figtree(size: 9, weight: .bold, relativeTo: .caption2))
                }
                .foregroundStyle(AppColor.caution)
            case .newIssue:
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 8, weight: .bold))
                    Text("New")
                        .font(Typography.figtree(size: 9, weight: .bold, relativeTo: .caption2))
                }
                .foregroundStyle(AppColor.warning)
            case .resolved:
                HStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                    Text("Resolved")
                        .font(Typography.figtree(size: 9, weight: .bold, relativeTo: .caption2))
                }
                .foregroundStyle(AppColor.positive)
            case .stable:
                EmptyView()
            }
        }
    }

    private func levelBar(_ level: SkillLevel, tint: Color) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index < levelFillCount(level) ? tint : tint.opacity(0.12))
                    .frame(width: 16, height: 4)
            }
        }
    }

    // MARK: - Helpers

    private func levelFillCount(_ level: SkillLevel) -> Int {
        switch level {
        case .weak: return 1
        case .developing: return 2
        case .solid: return 3
        case .strong: return 4
        }
    }

    private func levelOrder(_ level: SkillLevel) -> Int {
        switch level {
        case .weak: return 0
        case .developing: return 1
        case .solid: return 2
        case .strong: return 3
        }
    }

    private func drillStreak(for skillArea: SkillArea) -> Int {
        var count = 0
        for entry in drillHistory where entry.skillArea == skillArea {
            if entry.succeeded { count += 1 } else { break }
        }
        return count
    }
}

#endif
