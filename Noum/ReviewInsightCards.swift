import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Review Coach Read

/// The "what's working / what needs work" read at the top of Review —
/// the general-across-everything view a coach opens a review session with,
/// computed from the existing TrendAnalyzer skill trends.
///
/// Honesty contract: rows render only at medium+ confidence; weak evidence
/// hides the card rather than dressing noise as a read. The focus row is
/// framed as the next gain, never as a failure — and it renders in the
/// brand blue, not a warning color.
enum ReviewCoachRead {

    static func improvingTrend(in trends: [SkillTrend]) -> SkillTrend? {
        trends
            .filter { ($0.direction == .improving || $0.direction == .resolved) && $0.confidence != .low }
            .max { confidenceRank($0.confidence) < confidenceRank($1.confidence) }
    }

    static func focusTrend(in trends: [SkillTrend]) -> SkillTrend? {
        trends
            .filter { ($0.direction == .declining || $0.direction == .newIssue) && $0.confidence != .low }
            .max { confidenceRank($0.confidence) < confidenceRank($1.confidence) }
    }

    static func improvingLine(for trend: SkillTrend) -> String {
        let base: String
        switch trend.direction {
        case .resolved:
            base = "\(trend.skillArea.displayName) has come back into form"
        default:
            base = "\(trend.skillArea.displayName) is trending up"
        }
        if let delta = trend.recentDelta {
            return "\(base) — \(delta)"
        }
        return base
    }

    static func focusLine(for trend: SkillTrend) -> String {
        switch trend.direction {
        case .newIssue:
            return "\(trend.skillArea.displayName) has started slipping — catch it early"
        default:
            return "\(trend.skillArea.displayName) is where the next gain is — worth one focused rep"
        }
    }

    static func evidenceCaption(improving: SkillTrend?, focus: SkillTrend?) -> String? {
        let hasEvidence = [improving, focus]
            .compactMap { $0?.windowSize }
            .contains { $0 > 0 }

        guard hasEvidence else {
            return nil
        }

        return "Uses your newest measured reps"
    }

    static func confidenceRank(_ confidence: TrendConfidence) -> Int {
        switch confidence {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}

#if canImport(SwiftUI)

struct ReviewCoachReadCard: View {
    let trends: [SkillTrend]

    private var improving: SkillTrend? { ReviewCoachRead.improvingTrend(in: trends) }
    private var focus: SkillTrend? { ReviewCoachRead.focusTrend(in: trends) }

    private var evidenceCaption: String? {
        ReviewCoachRead.evidenceCaption(improving: improving, focus: focus)
    }

    var body: some View {
        if improving == nil && focus == nil {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach's read")
                    .font(.headline)

                if let improving {
                    readRow(
                        icon: "arrow.up.right",
                        tint: AppColor.positive,
                        text: ReviewCoachRead.improvingLine(for: improving)
                    )
                }

                if let focus {
                    readRow(
                        icon: "target",
                        tint: AppColor.brandBlue,
                        text: ReviewCoachRead.focusLine(for: focus)
                    )
                }

                if let evidenceCaption {
                    Text(evidenceCaption)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .accessibilityIdentifier("review.coachRead")
        }
    }

    private func readRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Review Highlight Row

struct ReviewHighlightRow: View {
    let highlight: ReviewHighlightsEngine.Highlight
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: highlight.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(width: 30, height: 30)
                    .background(AppColor.brandBlue.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(highlight.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(highlight.line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("review.highlight.\(highlight.kind.rawValue)")
    }
}

#endif
