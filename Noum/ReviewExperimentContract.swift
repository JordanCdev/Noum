import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Review outcome-loop experiment

/// The two presentations supported by the existing post-rep Summary. The
/// control keeps the factual review and offers a neutral replay; the treatment
/// keeps Noum's current goal-outcome read and finalizer-owned prescription.
///
/// Noum never chooses a variant locally. An assignment exists only after an
/// exact, externally configured token is active for an eligible account.
enum ReviewExperimentVariant: Int, Codable, Equatable {
    case genericReviewControl = 0
    case goalOutcomeAdaptivePrescription = 1
}

/// The narrow UI projection used by Summary. Unassigned accounts deliberately
/// stay on the shipping outcome loop so an unavailable or mistyped Remote
/// Config value cannot silently degrade the product.
enum ReviewExperimentPresentation: Equatable {
    case genericReview
    case outcomeLoop

    var showsGoalOutcome: Bool { self == .outcomeLoop }
    var recordsAdaptivePrescription: Bool { self == .outcomeLoop }
}

/// Content-free, account-local assignment recovered from `FlowEventLog`.
/// FlowEventLog remains the persistence, export, deletion, and account-scope
/// owner; this value is only its typed projection.
struct ReviewExperimentAssignment: Equatable {
    let correlationID: UUID
    let version: Int
    let variant: ReviewExperimentVariant
    let assignedAt: Date
}

/// Per-account attribution only. It distinguishes configuration, rendered
/// exposure, and a later durable rep. It is not a cohort result and contains
/// no transcript, prompt, recommendation copy, or user identifier.
struct ReviewExperimentAttribution: Equatable {
    let assignment: ReviewExperimentAssignment
    let exposedVariant: ReviewExperimentVariant?
    let exposureContext: ActivationExperimentExposureContext?
    let exposedAt: Date?
    let completedNextRepAt: Date?

    var wasExposed: Bool { exposedAt != nil }
    var completedNextRep: Bool { completedNextRepAt != nil }

    var timeToCompletedNextRepSeconds: TimeInterval? {
        guard let exposedAt, let completedNextRepAt else { return nil }
        return max(0, completedNextRepAt.timeIntervalSince(exposedAt))
    }
}

enum ReviewExperimentContract {
    /// Remote Config owns delivery. Only these exact, versioned values may
    /// enroll an eligible account; empty, unknown, or not-yet-active values
    /// fail closed to no assignment.
    static let remoteConfigKey = "review_outcome_loop_contract"
    static let currentVersion = 1
    static let genericReviewToken = "review-outcome-v1:generic-review"
    static let outcomeLoopToken = "review-outcome-v1:goal-outcome-adaptive-prescription"

    static func isEligibleForNewAssignment(
        hasHydratedAccountStores: Bool,
        isDeveloper: Bool,
        isUITesting: Bool,
        hasPriorReviewExposure: Bool
    ) -> Bool {
        hasHydratedAccountStores
            && !isDeveloper
            && !isUITesting
            && !hasPriorReviewExposure
    }

    /// A durable rep means the account has already reached the post-rep
    /// Summary even when an older build did not emit the explicit Review
    /// surface marker. The marker also covers a user who opened empty Review.
    static func hasPriorReviewExposure(
        events: [FlowEvent],
        sessions: [PracticeSession]
    ) -> Bool {
        sessions.contains { !$0.isEvaluationFixture }
            || events.contains {
                $0.stage == TransformationKPIEventStage.reviewSurfaceOpened
                    || $0.stage == "review.sessionOpened"
                    || $0.stage == TransformationKPIEventStage.reviewExperimentExposed
            }
    }

    static func resolveAssignment(
        configuredValue: String?,
        isEligible: Bool,
        correlationID: UUID = UUID(),
        now: Date = Date()
    ) -> ReviewExperimentAssignment? {
        guard isEligible,
              let value = configuredValue?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        let variant: ReviewExperimentVariant
        switch value {
        case genericReviewToken:
            variant = .genericReviewControl
        case outcomeLoopToken:
            variant = .goalOutcomeAdaptivePrescription
        default:
            return nil
        }

        return ReviewExperimentAssignment(
            correlationID: correlationID,
            version: currentVersion,
            variant: variant,
            assignedAt: now
        )
    }

    static func persistedAssignment(in events: [FlowEvent]) -> ReviewExperimentAssignment? {
        events
            .filter { $0.stage == TransformationKPIEventStage.reviewExperimentAssigned }
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap(decodeAssignment)
            .first
    }

    static func presentation(in events: [FlowEvent]) -> ReviewExperimentPresentation {
        guard let assignment = persistedAssignment(in: events) else {
            return .outcomeLoop
        }
        switch assignment.variant {
        case .genericReviewControl: return .genericReview
        case .goalOutcomeAdaptivePrescription: return .outcomeLoop
        }
    }

    static func attribution(
        in events: [FlowEvent],
        sessions: [PracticeSession]
    ) -> ReviewExperimentAttribution? {
        guard let assignment = persistedAssignment(in: events) else { return nil }
        let exposure = events
            .compactMap { event -> (
                event: FlowEvent,
                context: ActivationExperimentExposureContext
            )? in
                guard event.stage == TransformationKPIEventStage.reviewExperimentExposed
                    && event.correlationId == assignment.correlationID
                    && event.createdAt >= assignment.assignedAt
                    && event.numerics["experimentVersion"] == assignment.version
                    && event.numerics["variant"] == assignment.variant.rawValue,
                      let context = ActivationExperimentExposureContext(
                        numerics: event.numerics
                      ) else { return nil }
                return (event, context)
            }
            .min { $0.event.createdAt < $1.event.createdAt }

        let nextRep = exposure.flatMap { exposure in
            sessions
                .filter { !$0.isEvaluationFixture && $0.date > exposure.event.createdAt }
                .min { $0.date < $1.date }
        }

        return ReviewExperimentAttribution(
            assignment: assignment,
            exposedVariant: exposure == nil ? nil : assignment.variant,
            exposureContext: exposure?.context,
            exposedAt: exposure?.event.createdAt,
            completedNextRepAt: nextRep?.date
        )
    }

    private static func decodeAssignment(_ event: FlowEvent) -> ReviewExperimentAssignment? {
        guard event.numerics["experimentVersion"] == currentVersion,
              let rawVariant = event.numerics["variant"],
              let variant = ReviewExperimentVariant(rawValue: rawVariant) else {
            return nil
        }
        return ReviewExperimentAssignment(
            correlationID: event.correlationId,
            version: currentVersion,
            variant: variant,
            assignedAt: event.createdAt
        )
    }
}

// MARK: - Generic Summary control presentation

struct SummaryGenericReviewActionPresentation: Equatable {
    let mode: PracticeMode
    let title: String
    let supportingCopy: String

    static func make(for mode: PracticeMode) -> SummaryGenericReviewActionPresentation {
        let supportingCopy: String
        if mode == .imConversation {
            supportingCopy = "Start a fresh \(mode.displayLabel) rep with the same scenario and target tone."
        } else {
            supportingCopy = "Start a fresh \(mode.displayLabel) rep."
        }
        return SummaryGenericReviewActionPresentation(
            mode: mode,
            title: "Repeat this rep",
            supportingCopy: supportingCopy
        )
    }

    var accessibilityLabel: String { "\(title). \(supportingCopy)" }

    /// The control is intentionally replay-only. It cannot enter the adaptive
    /// recommendation learning ledger through this presentation.
    var recordsAdaptivePrescriptionAcceptance: Bool { false }
}

#if canImport(SwiftUI)
@available(iOS 17.0, *)
struct SummaryGenericReviewActionCard: View {
    let presentation: SummaryGenericReviewActionPresentation
    let onStart: () -> Void

    private var tint: Color { AppColor.tint(for: presentation.mode) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Next rep")
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(tint)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(presentation.title)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)

            Text(presentation.supportingCopy)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onStart) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: presentation.mode.iconName)
                        .font(Typography.subheadline.weight(.semibold))
                    Text(presentation.title)
                        .font(Typography.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .foregroundStyle(.white)
                .background(
                    tint,
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier(SummaryExitPanel.AccessibilityID.fullRetry)
            .accessibilityLabel(presentation.accessibilityLabel)
            .accessibilityHint("Starts a fresh replay without recording an adaptive prescription acceptance.")
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.08), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summary.reviewExperiment.genericAction")
    }
}
#endif
