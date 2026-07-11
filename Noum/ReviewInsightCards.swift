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
            return "\(trend.skillArea.displayName) appeared in the newest measured reps — worth one confirming rep"
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

// MARK: - Review Story

/// One presentation-only focus shared by Home, Train, Review, and Profile.
/// The trend store remains the owner of evidence; this resolver only turns its
/// strongest supported focus into consistent user-facing copy and a suitable
/// existing practice mode.
struct CurrentCoachingFocusPresentation: Equatable {
    let skillArea: SkillArea
    let observation: String
    let instruction: String
    let recommendedMode: PracticeMode
    let evidenceCaption: String

    static func make(
        trends: [SkillTrend],
        sessionCount: Int
    ) -> CurrentCoachingFocusPresentation? {
        guard sessionCount >= 3,
              let focus = ReviewCoachRead.focusTrend(in: trends) else {
            return nil
        }

        let evidenceCount = min(sessionCount, min(max(1, focus.windowSize), 12))
        let focusName = focus.skillArea.displayName.lowercased()
        let observation = evidenceCount <= 4
            ? "An early read points to \(focusName)."
            : "Recent reps point to \(focusName) as the clearest next focus."

        return CurrentCoachingFocusPresentation(
            skillArea: focus.skillArea,
            observation: observation,
            instruction: instruction(for: focus.skillArea),
            recommendedMode: recommendedMode(for: focus.skillArea),
            evidenceCaption: ReviewStoryPresentation.evidenceCaption(for: evidenceCount)
        )
    }

    func applying(to blueprint: RecommendationBiasBlueprint) -> RecommendationBiasBlueprint {
        let modeChanged = recommendedMode != blueprint.recommendedMode
        let playbook = RecommendationBiasEngine.playbook.first { entry in
            entry.mode == recommendedMode
        }
        return RecommendationBiasBlueprint(
            recommendedMode: recommendedMode,
            recommendedTone: nil,
            recommendedScenario: nil,
            focus: skillArea.displayName,
            target: instruction,
            modeBenefit: modeChanged ? (playbook?.benefit ?? "") : blueprint.modeBenefit,
            whyMode: observation,
            whyNow: observation,
            suggestedTimedDifficulty: recommendedMode == .timed
                ? (modeChanged ? .medium : blueprint.suggestedTimedDifficulty)
                : nil,
            suggestedTheme: modeChanged ? .all : blueprint.suggestedTheme,
            source: blueprint.source
        )
    }

    private static func recommendedMode(for skillArea: SkillArea) -> PracticeMode {
        switch skillArea {
        case .fillerReduction, .pauseUsage:
            return .ahCounter
        case .openingStrength, .closingStrength, .paceControl, .structure,
             .answerDevelopment, .conciseSpeaking, .vocalEmphasis, .confidence:
            return .timed
        }
    }

    private static func instruction(for skillArea: SkillArea) -> String {
        switch skillArea {
        case .fillerReduction:
            return "Replace the next filler with a silent beat."
        case .openingStrength:
            return "Open with the answer in the first sentence."
        case .closingStrength:
            return "End on the decision, then stop."
        case .paceControl:
            return "Leave one full beat before the explanation."
        case .structure:
            return "Give the answer, one reason, then the next step."
        case .answerDevelopment:
            return "Develop one idea with one concrete example."
        case .conciseSpeaking:
            return "Make the point in one sentence, then stop."
        case .pauseUsage:
            return "Use one silent beat before the key point."
        case .vocalEmphasis:
            return "Stress the key phrase and soften the setup."
        case .confidence:
            return "State the point without a hedge."
        }
    }
}

/// One bounded story for the Review root: what moved, what that means, and
/// the next focus. It deliberately reads only the trend engine's supported
/// rows plus saved-session depth; no view owns or recomputes coaching state.
struct ReviewStoryPresentation: Equatable {
    let movement: String
    let meaning: String
    let nextFocus: String
    let evidenceCaption: String
    let latestSessionID: UUID

    static func make(
        trends: [SkillTrend],
        sessions: [PracticeSession]
    ) -> ReviewStoryPresentation? {
        guard let latest = sessions.max(by: { $0.date < $1.date }) else {
            return nil
        }

        let improving = ReviewCoachRead.improvingTrend(in: trends)
        let focus = ReviewCoachRead.focusTrend(in: trends)
        let supportedWindows = [improving?.windowSize, focus?.windowSize]
            .compactMap { $0 }
            .filter { $0 > 0 }
        // A trend window can outlive locally retained history (or be seeded
        // independently in UI tests). Never claim more visible evidence than
        // the user can actually open from Review.
        let evidenceCount = min(
            sessions.count,
            min(supportedWindows.max() ?? sessions.count, 12)
        )

        let movement: String
        let meaning: String
        let nextFocus: String

        switch (improving, focus) {
        case let (improving?, focus?):
            movement = sentence(ReviewCoachRead.improvingLine(for: improving))
            meaning = "That gain creates room to work on \(focus.skillArea.displayName.lowercased())."
            nextFocus = "Next focus: \(focus.skillArea.displayName.lowercased())."

        case let (improving?, nil):
            movement = sentence(ReviewCoachRead.improvingLine(for: improving))
            meaning = "The change is consistent enough to keep building on."
            nextFocus = "Next focus: repeat the conditions that produced it."

        case let (nil, focus?):
            movement = evidenceCount <= 4
                ? "The picture is still forming."
                : "Your recent reps are holding mostly steady."
            meaning = sentence(ReviewCoachRead.focusLine(for: focus))
            nextFocus = "Next focus: \(focus.skillArea.displayName.lowercased())."

        case (nil, nil):
            if evidenceCount <= 2 {
                movement = evidenceCount == 1
                    ? "Your latest rep is the starting point."
                    : "Your latest reps are still a starting point."
                meaning = "There is not enough evidence to call a pattern yet."
            } else {
                movement = "Your recent reps are holding steady."
                meaning = "No clear shift is strong enough to call yet."
            }
            nextFocus = "Next focus: carry one concrete move into the next rep."
        }

        return ReviewStoryPresentation(
            movement: movement,
            meaning: meaning,
            nextFocus: nextFocus,
            evidenceCaption: evidenceCaption(for: evidenceCount),
            latestSessionID: latest.id
        )
    }

    static func evidenceCaption(for evidenceCount: Int) -> String {
        switch evidenceCount {
        case ...0:
            return "No measured rep evidence yet."
        case 1:
            return "Based on your latest rep."
        case 2:
            return "Based on your latest two reps."
        case 3...4:
            return "Early read from \(evidenceCount) recent reps."
        case 5...9:
            return "Seen across \(evidenceCount) recent reps."
        default:
            return "Repeated across \(evidenceCount) recent reps."
        }
    }

    private static func sentence(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".!?".contains(last) else {
            return trimmed
        }
        return trimmed + "."
    }
}

enum ReviewProgressDisclosure {
    static let defaultExpanded = false
}

enum ReviewHighlightLimit {
    static let maximumVisibleRows = 2

    static func visible(_ highlights: [ReviewHighlightsEngine.Highlight]) -> [ReviewHighlightsEngine.Highlight] {
        Array(highlights.prefix(maximumVisibleRows))
    }
}

#if canImport(SwiftUI)

struct ReviewStoryCard: View {
    let presentation: ReviewStoryPresentation
    let onReviewLatest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "waveform.path.ecg")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .accessibilityHidden(true)
                Text("Your recent movement")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(presentation.movement)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.meaning)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: Spacing.xs) {
                Image(systemName: "scope")
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
                Text(presentation.nextFocus)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(presentation.evidenceCaption)
                .font(Typography.captionSmall)
                .foregroundStyle(.tertiary)

            Button(action: onReviewLatest) {
                Label("Review latest rep", systemImage: "arrow.right")
                    .font(Typography.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppColor.brandBlue, in: Capsule(style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("review.latestRep")
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.brandBlue.opacity(0.10), AppColor.cardBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.brandBlue.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.story")
    }
}

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
                        .fixedSize(horizontal: false, vertical: true)
                    Text(highlight.line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.quaternary)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("review.highlight.\(highlight.kind.rawValue)")
    }
}

#endif
