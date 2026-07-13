import Foundation
#if canImport(SwiftUI)
import SwiftUI

enum GoalOutcomeEngine {
    /// A goal outcome is only a tailored read when the user actually chose a
    /// voice. `speakingStyleGoal` always has an effective fallback so older
    /// screens can render, but using that fallback here would present invented
    /// personalization as a user-selected outcome.
    static func selectedGoal(from profile: CoachingProfile?) -> SpeakingStyleGoal? {
        profile?.chosenStyleGoal
    }

    static func read(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        rating: SpeakingRating,
        sessions: [PracticeSession],
        coachMemory: CoachMemory?,
        outcomes: [RecommendationOutcome],
        locale: PracticeLocale? = nil
    ) -> GoalOutcomeRead? {
        let effectiveLocale = locale ?? currentLocale()
        guard effectiveLocale.aiSupported else { return nil }
        guard let style = selectedGoal(from: profile), !sessions.isEmpty else { return nil }
        let trajectory = UserTrajectoryCache.shared.snapshot(
            profile: profile,
            baseline: baseline,
            rating: rating,
            sessions: sessions,
            coachMemory: coachMemory
        ).snapshot
        let assessment = CoachReasoningPass.assess(
            turnDepth: .groundedRead,
            userQuestion: "How is my latest rep moving toward my speaking goal?",
            trajectory: trajectory,
            rubric: ActiveGoalRubric(
                rubric: GoalRubricStore.rubric(for: style),
                voice: style
            ),
            surface: .text
        )
        return GoalOutcomeRead.make(style: style, assessment: assessment, outcomes: outcomes)
    }

    /// `GoalOutcomeEngine.read` is synchronous because it is consumed by
    /// synchronous SwiftUI projections and deterministic tests. The existing
    /// locale manager remains the sole production owner; explicit locale
    /// injection bypasses this hop in tests.
    private static func currentLocale() -> PracticeLocale {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                LocaleSettingsManager.shared.current
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                LocaleSettingsManager.shared.current
            }
        }
    }
}

/// Deliberately small, privacy-safe share text for a real goal milestone. It
/// never includes a transcript excerpt, raw metric, account detail, or a claim
/// that a recommendation caused the outcome.
enum GoalMilestoneShare {
    static func isAvailable(for read: GoalOutcomeRead) -> Bool {
        guard read.evidenceLevel == .established else { return false }
        switch read.movement {
        case .improving, .holding: return true
        case .emerging, .mixed: return false
        }
    }

    static func message(for read: GoalOutcomeRead) -> String {
        let movement: String
        switch read.movement {
        case .improving:
            movement = "Recent practice is showing early improvement."
        case .holding:
            movement = "The pattern is holding across recent practice."
        case .mixed:
            movement = "The signal is mixed, so I am keeping the next rep focused."
        case .emerging:
            movement = "I am building the first useful signal."
        }
        let next = read.nextDimension?.label.lowercased() ?? "my next speaking target"
        return "Noum practice update\nI am practising \(read.style.title.lowercased()) communication. \(movement) Next I am working on \(next)."
    }
}

struct GoalOutcomeCard: View {
    let read: GoalOutcomeRead
    var actionTitle: String? = nil
    var onPractice: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "scope")
                    .foregroundStyle(AppColor.brandBlue)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Toward your \(read.style.title.lowercased()) voice")
                        .font(Typography.cardTitle)
                    Text(statusLine)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("goalOutcome.status")
                }
                Spacer(minLength: 0)
                Text(evidenceLabel)
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
            }

            if let citation = read.evidenceCitation, read.evidenceLevel != .insufficient {
                Text(citation)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Noum needs another comparable rep before calling this a pattern.")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
            }

            if let next = read.nextDimension {
                Text("Next: \(next.label)")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(read.prescribedNextAction)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if GoalMilestoneShare.isAvailable(for: read) {
                ShareLink(item: GoalMilestoneShare.message(for: read)) {
                    Label("Share this milestone", systemImage: "square.and.arrow.up")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("goalOutcome.share")
                .accessibilityHint("Shares a progress note without your transcript or detailed scores.")
            }

            if let actionTitle, let onPractice {
                Button(action: onPractice) {
                    Label(actionTitle, systemImage: "arrow.right.circle.fill")
                        .font(Typography.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.brandBlue)
                .accessibilityIdentifier("goalOutcome.practice")
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.brandBlue.opacity(0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goalOutcome.card")
    }

    private var evidenceLabel: String {
        switch read.evidenceLevel {
        case .insufficient: return "More evidence"
        case .forming: return "Forming"
        case .established: return "Established"
        }
    }

    private var statusLine: String {
        if let followUp = read.latestFollowUpResult {
            switch followUp {
            case .held:
                return "This rep showed the target held after practice."
            case .earlyImprovement:
                return "This rep showed early improvement after practice."
            case .mixed:
                return "This rep showed mixed evidence after practice."
            case .needsMoreEvidence:
                return "This rep needs more comparable evidence."
            }
        }
        switch read.movement {
        case .emerging: return "The first useful signal is emerging."
        case .holding: return "The pattern is holding across the available evidence."
        case .improving: return "Recent reps show early improvement."
        case .mixed: return "Recent evidence is mixed; the next rep should isolate the target."
        }
    }
}
#endif
