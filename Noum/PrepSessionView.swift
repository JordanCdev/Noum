#if canImport(SwiftUI)
import SwiftUI

// MARK: - Prep Session View
//
// Landing surface for the M23 situational preparation flow. When the
// user has an active BigMoment within 14 days, this view appears as
// the entry point from the home `prepSessionCTA`. It frames the next
// three reps as a rehearsal for the specific upcoming event.
//
// MVP behavior:
//   - Coach-voice intro card that names the event + days remaining
//   - 3-rep plan with rationale per step (Warm up → Pressure → Audience)
//   - Per-step CTA that pushes the corresponding practice view
//   - User navigates back to this landing surface after each rep
//
// Deferred (not in MVP):
//   - Auto-chaining the 3 modes (each mode owns its own session
//     lifecycle; chaining requires sheet-presented + completion
//     observation that's worth its own follow-up pass)
//   - Inter-rep "Rep N done — moving to next" coach copy
//   - End-of-prep ready-signal summary card with green/amber/red rows
//   - Session marking (`isPrepSession: true` on PracticeSession) so
//     summaries can render with prep-specific framing
//
// Anti-goal compliance:
//   - The view does NOT block on completing all 3 reps. The user can
//     do any subset; partial completion is a valid prep session.
//   - No hearts-and-lives, no streak shame, no fake confidence
//     numbers. The intro frames the day's work as preparation —
//     a snapshot of where you stand, not a pass/fail gate.

@available(iOS 17.0, *)
struct PrepSessionView: View {
    @Binding var navigationPath: NavigationPath
    @StateObject private var bigMomentStore = BigMomentStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var aiSettings = AISettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                content
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(AppColor.screenBackground.ignoresSafeArea())
        .navigationTitle("Rehearsal")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("prepSession.screen")
    }

    @ViewBuilder
    private var content: some View {
        if let moment = bigMomentStore.activeMoment,
           let days = bigMomentStore.daysUntil(moment),
           days >= 0 {
            let modeAvailability = currentModeAvailability
            let plan = PrepSessionPlanner.plan(
                bigMoment: moment,
                daysRemaining: days,
                voice: coachingProfileStore.profile?.chosenStyleGoal,
                modeAvailability: modeAvailability
            )
            introCard(plan: plan, moment: moment, days: days)
            stepsCard(plan: plan, moment: moment)
            footerNote(moment: moment)
        } else {
            emptyState
        }
    }

    // MARK: - Sections

    private func introCard(plan: PrepSessionPlan, moment: BigMoment, days: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: moment.category.sfSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                Text(days == 1 ? "REHEARSAL IN 1 DAY" : "REHEARSAL IN \(days) DAYS")
                    .font(Typography.micro)
                    .foregroundStyle(AppColor.brandBlue)
                    .tracking(0.8)
            }
            Text(plan.introductionCopy)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.brandBlue.opacity(0.10), AppColor.brandBlue.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.brandBlue.opacity(0.18), lineWidth: 1)
        )
        .accessibilityIdentifier("prepSession.intro")
    }

    /// One list = plan AND status. The three shapes run in order — a
    /// deliberate graduated-exposure arc (ease in → pressure → the real
    /// shape) — so later steps stay locked until the previous shape has
    /// been covered. Done reads green at a glance, the current step is the
    /// only actionable one, locked steps say what unlocks them. This
    /// replaces the separate "Where you stand" card, which repeated the
    /// same three items with a second, easily-misread status vocabulary.
    private func stepsCard(plan: PrepSessionPlan, moment: BigMoment) -> some View {
        let readiness = PrepSessionPlanner.readiness(
            plan: plan,
            sessions: sessionStore.sessions,
            momentCreatedAt: moment.createdAt
        )
        let firstOpenIndex = plan.steps.firstIndex {
            !readiness.coveredModes.contains($0.mode)
        }
        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("REHEARSAL PLAN")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .tracking(0.8)
            ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                let done = readiness.coveredModes.contains(step.mode)
                let isCurrent = index == firstOpenIndex
                stepRow(
                    index: index + 1,
                    step: step,
                    state: done ? .done : (isCurrent ? .current : .locked),
                    unlocksAfter: index > 0 ? plan.steps[index - 1].readinessLabel : nil
                )
                if index < plan.steps.count - 1 {
                    Divider()
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .accessibilityIdentifier("prepSession.plan")
    }

    private enum PrepStepState {
        case done
        case current
        case locked
    }

    private func stepRow(
        index: Int,
        step: PrepRepStep,
        state: PrepStepState,
        unlocksAfter: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 8) {
                Group {
                    switch state {
                    case .done:
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(AppColor.positive, in: Circle())
                    case .current:
                        Text("\(index)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(AppColor.brandBlue, in: Circle())
                    case .locked:
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color.secondary.opacity(0.14), in: Circle())
                    }
                }
                .accessibilityHidden(true)

                Text(step.displayLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(state == .locked ? .secondary : .primary)
                Spacer()
            }
            .opacity(state == .locked ? 0.75 : 1)

            switch state {
            case .done:
                Text("Covered — run it again any time.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.positive)
                    .padding(.leading, 30)
            case .current:
                Text(step.rationale)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 30)
            case .locked:
                if let unlocksAfter {
                    Text("Unlocks after \(unlocksAfter.lowercased()).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 30)
                }
            }

            if state != .locked {
                Button {
                    launch(step: step)
                } label: {
                    HStack(spacing: 4) {
                        Text(state == .done ? "Run again" : step.startLabel)
                            .font(.footnote.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(state == .done ? AppColor.textSecondary : AppColor.brandBlue)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(
                        (state == .done ? Color.secondary.opacity(0.10) : AppColor.brandBlue.opacity(0.10)),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .padding(.leading, 30)
                .accessibilityHint(step.rationale)
                .accessibilityIdentifier("prepSession.step.\(index).begin")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(prepStepAccessibilityLabel(index: index, step: step, state: state)))
    }

    private func prepStepAccessibilityLabel(
        index: Int,
        step: PrepRepStep,
        state: PrepStepState
    ) -> String {
        switch state {
        case .done: return "Step \(index), \(step.displayLabel), covered."
        case .current: return "Step \(index), \(step.displayLabel), up next. \(step.rationale)"
        case .locked: return "Step \(index), \(step.displayLabel), locked until the previous step is covered."
        }
    }

    private func footerNote(moment: BigMoment) -> some View {
        Text("Steps unlock in order. You can return between reps — partial prep still counts.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Spacing.xs)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("No upcoming moment set.")
                .font(Typography.body.weight(.semibold))
            Text("Set an upcoming moment in Settings. Rehearsal appears when the date is within 14 days.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Launchers

    /// Resolve the rendered action again at tap time, then push the existing
    /// practice surface through an explicit preparation route. When a planned
    /// pressure/audience shape must fall back to Timed, carry one
    /// category-bounded prompt so the destination fulfills the card's
    /// rehearsal promise. The route stamps only presentation provenance onto
    /// the resulting Summary; BigMomentStore remains the state owner, and Done
    /// returns to this plan only while the same moment is still active.
    private func launch(step: PrepRepStep) {
        let imAvailable = IMModeAvailability.isAvailable
        let tapAvailability = NextActionModeAvailability(
            rating: ratingStore.rating,
            imConversationAvailable: imAvailable
        )
        let launch = step.resolvingLaunchForTap(
            modeAvailability: tapAvailability,
            imAvailable: imAvailable
        )
        guard let moment = bigMomentStore.activeMoment else { return }

        let destination: AppDestination
        if case .timedPractice = launch.destination,
           let prompt = PrepSessionPlanner.timedFallbackPrompt(
               for: step.mode,
               category: moment.category
           ),
           let token = TimedPracticePromptHandoff.shared.offerToken(prompt) {
            destination = .timedPracticePrompt(token: token)
        } else {
            destination = launch.destination
        }

        guard let route = PreparationPracticeRoute(
            momentID: moment.id,
            destination: destination
        ) else {
            assertionFailure("Preparation planner produced an unsupported destination")
            navigationPath.append(destination)
            return
        }
        navigationPath.append(AppDestination.preparationPractice(route))
    }

    /// The stores remain the state owners. Reading the published consent here
    /// makes provider/consent changes invalidate this view's rendered plan.
    private var currentModeAvailability: NextActionModeAvailability {
        _ = aiSettings.cloudProcessingConsent
        return NextActionModeAvailability(
            rating: ratingStore.rating,
            imConversationAvailable: IMModeAvailability.isAvailable
        )
    }
}

#endif
