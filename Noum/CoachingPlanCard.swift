#if canImport(SwiftUI)
import Foundation
import SwiftUI

// MARK: - Coaching Plan Card (M20 Forward Plan surface on Profile)
//
// One small card on `ProfileView` that surfaces the active 4-week
// forward plan: current week's focus + suggested mode + a progress
// row (completed vs target). Tap → opens Ask Noum where the plan is
// stored in the chat history as a coach turn. The card is the
// at-a-glance read; the chat thread is where the full plan lives.
//
// Visibility states (pure):
//   • `hidden` — fewer than 3 qualifying sessions OR no active profile.
//     The plan needs data to be honest, and a brand-new user without a
//     profile shouldn't see a coaching surface at all.
//   • `prompt` — ≥3 sessions, no plan yet. Render a "Ask Noum to plan
//     your next four weeks" pre-prompt so the user knows the feature
//     exists. Tap → Ask Noum.
//   • `live` — plan exists AND is still aligned with the active Big
//     Moment (or no Big Moment at either generation or now). Renders
//     current week + progress.
//   • `stale` — plan exists but the user's Big Moment has changed
//     since generation. Same as `live` but with a quiet "Big moment
//     changed — regenerate" line so the user knows to refresh.
//
// Why a state enum rather than view-level branching: the visibility
// rules are testable in `CoachingPlanCardVisibilityTests` without
// mounting a SwiftUI hierarchy. The view is dumb — it renders
// whichever state the resolver hands it.

@available(iOS 17.0, *)
enum CoachingPlanCardState: Equatable {
    case hidden
    case prompt                                       // No plan yet, but user has ≥3 sessions
    case live(plan: ForwardPlan, completed: Int)      // Active + aligned
    case stale(plan: ForwardPlan, completed: Int)     // Active but BigMoment changed
}

@available(iOS 17.0, *)
enum CoachingPlanCardVisibility {

    /// Pure resolver. Inputs in, state out — no singleton reads, so the
    /// test suite can exercise every branch with fixture data.
    static func resolve(
        plan: ForwardPlan?,
        profile: CoachingProfile?,
        sessions: [PracticeSession],
        activeBigMomentID: UUID?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachingPlanCardState {
        guard profile != nil else { return .hidden }
        let eligibleSessions = PracticeProgressEligibility.eligibleSessions(in: sessions)
        let qualifyingCount = eligibleSessions.count
        guard let plan else {
            // No plan; show the pre-prompt only after enough data.
            return qualifyingCount >= 3 ? .prompt : .hidden
        }
        // A voice-mismatched plan can contain rationale written for a fallback
        // or former choice. Treat it as absent rather than rendering that stale
        // copy; the prompt regenerates from the current explicit boundary.
        if plan.voiceAtGeneration != profile?.chosenStyleGoal {
            return qualifyingCount >= 3 ? .prompt : .hidden
        }
        let progress = ForwardPlanProgress.currentWeekProgress(
            plan: plan,
            sessions: eligibleSessions,
            now: now,
            calendar: calendar
        )
        let completed = progress?.completed ?? 0
        if plan.isInvalidated(by: activeBigMomentID) {
            return .stale(plan: plan, completed: completed)
        }
        return .live(plan: plan, completed: completed)
    }

    /// Voice-shaped CTA copy for the prompt + stale states. Mirrors the
    /// catalogues used by `askNoumProfileLabel(for:)` so every Ask Noum
    /// entry point sounds like the same voice.
    static func ctaLabel(state: CoachingPlanCardState, voice: SpeakingStyleGoal?) -> String {
        switch state {
        case .hidden, .live:
            return ""
        case .prompt:
            switch voice {
            case .authoritative: return "Ask Noum to plan four weeks"
            case .warm:          return "Ask Noum for a four-week plan"
            case .concise:       return "Plan four weeks. One ask."
            case .persuasive:    return "Ask for a structured four-week plan"
            case .executive:     return "Brief: plan my next four weeks"
            case .storytelling:  return "Ask Noum for the next four chapters"
            case .none:          return "Ask Noum to plan four weeks"
            }
        case .stale:
            switch voice {
            case .authoritative: return "Regenerate — your moment changed"
            case .warm:          return "Plan moved — ask Noum to redraft"
            case .concise:       return "Moment changed. Replan."
            case .persuasive:    return "Refresh the plan around the new moment"
            case .executive:     return "Recommend: regenerate the plan"
            case .storytelling:  return "New arc — ask Noum to rewrite the weeks"
            case .none:          return "Big moment changed — regenerate the plan"
            }
        }
    }

    /// Visible receipt for the transfer loop. Only returns copy when
    /// real-world check-ins for the active Big Moment's category existed before
    /// this plan was generated and cleared the same prep-transfer honesty floor
    /// the planner uses. This avoids claiming a plan was shaped by reports that
    /// arrived after generation.
    static func transferAdaptationReceipt(
        plan: ForwardPlan?,
        activeMoment: BigMoment?,
        reports: [BigMomentOutcomeReport]
    ) -> String? {
        guard let plan,
              let activeMoment,
              plan.bigMomentID == activeMoment.id,
              !plan.isInvalidated(by: activeMoment.id),
              BigMomentStore.dominantTransferRead(for: activeMoment.category, in: reports) == .didNotTransfer else {
            return nil
        }
        guard let trend = BigMomentStore.transferTrends(
            from: reports,
            minimumReports: 3,
            maxReportsPerCategory: 6,
            limit: BigMomentCategory.allCases.count
        ).first(where: { $0.category == activeMoment.category }),
              trend.latestRecordedAt <= plan.generatedAt else {
            return nil
        }
        return "Plan adjusted from your \(activeMoment.category.displayName) check-ins: you reported that rehearsal has not fully carried into the room yet, so Week 4 is the bridge. Self-report only."
    }
}

// MARK: - View

@available(iOS 17.0, *)
struct CoachingPlanCard: View {
    let state: CoachingPlanCardState
    let voice: SpeakingStyleGoal?
    let transferReceipt: String?
    /// Triggered when the user taps the card / CTA. The caller decides
    /// whether to deep-link to Ask Noum or open the regeneration sheet.
    var onTap: () -> Void

    @Environment(\.openURL) private var openURL

    @ViewBuilder
    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .prompt:
            promptCard
        case .live(let plan, let completed):
            liveCard(plan: plan, completed: completed, isStale: false)
        case .stale(let plan, let completed):
            liveCard(plan: plan, completed: completed, isStale: true)
        }
    }

    // MARK: - Pre-prompt state (≥3 sessions, no plan yet)

    private var promptCard: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                eyebrow("YOUR PROGRAM")
                Text("A four-week coach plan, written for you.")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(CoachingPlanCardVisibility.ctaLabel(state: state, voice: voice))
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.pro)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColor.pro.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.coachingPlanCard.prompt")
    }

    // MARK: - Live state (plan exists)

    @ViewBuilder
    private func liveCard(plan: ForwardPlan, completed: Int, isStale: Bool) -> some View {
        if let week = plan.currentWeek() {
            let target = week.sessionTarget
            let fraction = target > 0 ? min(1.0, Double(completed) / Double(target)) : 0
            Button {
                onTap()
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        eyebrow("WEEK \(week.weekIndex) OF 4")
                    }
                    Text(week.focusSkillArea.displayName)
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(week.rationale)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    progressRow(completed: completed, target: target, fraction: fraction)

                    if let transferReceipt, !isStale {
                        transferReceiptRow(transferReceipt)
                    }

                    if isStale {
                        Text(CoachingPlanCardVisibility.ctaLabel(state: state, voice: voice))
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.pro)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(AppColor.pro.opacity(isStale ? 0.35 : 0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(isStale ? "profile.coachingPlanCard.stale" : "profile.coachingPlanCard.live")
        }
    }

    // MARK: - Components

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(Typography.micro.weight(.semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(Typography.micro.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    private func progressRow(completed: Int, target: Int, fraction: Double) -> some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 6)
                GeometryReader { proxy in
                    Capsule()
                        .fill(AppColor.pro)
                        .frame(width: proxy.size.width * CGFloat(fraction), height: 6)
                }
                .frame(height: 6)
            }
            Text("\(completed) / \(target)")
                .font(Typography.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func transferReceiptRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(AppColor.pro)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(text)
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.pro.opacity(0.06),
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(AppColor.pro.opacity(0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(text))
        .accessibilityIdentifier("profile.coachingPlanCard.transferReceipt")
    }
}

#endif
