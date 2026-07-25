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
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var aiSettings = AISettingsManager.shared

    /// Step badges and their hanging indent scale with type so AX sizes
    /// don't overflow the fixed circles.
    @ScaledMetric(relativeTo: .subheadline) private var stepBadgeSize: CGFloat = 22
    @ScaledMetric(relativeTo: .subheadline) private var stepIndent: CGFloat = 30

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
                modeAvailability: modeAvailability
            )
            // One-shot entrance stagger: intro → plan → footer. The view
            // mounts fresh per navigation push, so the entrance replays only
            // on genuine re-entry, never on pop-back from a rep (the modifier
            // guards on its own hasAppeared state). CardEntranceModifier is
            // the blessed stagger — Reduce Motion appears instantly.
            introCard(plan: plan, moment: moment, days: days)
                .cardEntrance(0)
            stepsCard(plan: plan, moment: moment)
                .cardEntrance(1)
            footerNote(moment: moment)
                .cardEntrance(2)
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
                Text(introEyebrow(days: days))
                    .font(Typography.micro)
                    .foregroundStyle(AppColor.brandBlue)
                    .tracking(0.8)
            }
            Text(plan.proximityCopy)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            // The arc sentence carries the WHY at a quieter weight so the
            // proximity line leads. Same copy as before, just re-weighted.
            Text(plan.arcCopy)
                .font(.footnote)
                .foregroundStyle(.secondary)
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

    private func introEyebrow(days: Int) -> String {
        if days <= 0 { return "REHEARSAL TODAY" }
        return days == 1 ? "REHEARSAL IN 1 DAY" : "REHEARSAL IN \(days) DAYS"
    }

    /// One list = plan AND status. The three shapes run in order — a
    /// deliberate graduated-exposure arc (ease in → pressure → the real
    /// shape) — so later steps stay locked until every earlier step has
    /// been covered. Coverage is derived by the planner's ordered
    /// attribution, so completing a gated step's offered Timed fallback
    /// advances the sequence (honestly marked) instead of dead-ending it.
    /// Done reads green at a glance, the current step is the only
    /// actionable one, locked steps name the actual step that unlocks
    /// them. This replaces the separate "Where you stand" card, which
    /// repeated the same three items with a second, easily-misread status
    /// vocabulary.
    private func stepsCard(plan: PrepSessionPlan, moment: BigMoment) -> some View {
        let statuses = PrepSessionPlanner.stepStatuses(
            plan: plan,
            sessions: sessionStore.sessions,
            momentCreatedAt: moment.createdAt
        )
        return VStack(alignment: .leading, spacing: Spacing.md) {
            // Identifier lives on the header, not the card container — a
            // container-level identifier blankets descendants and would stomp
            // the per-step "prepSession.step.N.begin" button identifiers.
            HStack(alignment: .firstTextBaseline) {
                Text("REHEARSAL PLAN")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                    .accessibilityIdentifier("prepSession.plan")
                Spacer()
                // Fallback-inclusive count derived from the SAME statuses
                // the rows render, so the header can never disagree with
                // the list beneath it.
                Text("\(PrepSessionPlanner.coveredStepCount(in: statuses)) of \(plan.steps.count) covered")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                stepRow(
                    index: index + 1,
                    step: step,
                    status: statuses[index]
                )
                if index < plan.steps.count - 1 {
                    Divider()
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func stepRow(
        index: Int,
        step: PrepRepStep,
        status: PrepStepStatus
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // The text rows combine into one VoiceOver element; the action
            // button below stays its own element so activation is directly
            // focusable and its hint survives.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: 8) {
                    stepBadge(for: status.phase, index: index)
                        .accessibilityHidden(true)

                    Text(step.displayLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(status.phase == .locked ? .secondary : .primary)
                    Spacer()
                }
                .opacity(status.phase == .locked ? 0.6 : 1)

                switch status.phase {
                case .done:
                    if status.coveredViaFallback {
                        // Done and green — but never claiming the unavailable
                        // shape itself was rehearsed.
                        Text(step.coveredViaFallbackLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, stepIndent)
                    } else {
                        Text("Covered — run it again any time.")
                            .font(.footnote)
                            .foregroundStyle(AppColor.positive)
                            .padding(.leading, stepIndent)
                    }
                case .current:
                    Text(step.rationale)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, stepIndent)
                case .locked:
                    VStack(alignment: .leading, spacing: 2) {
                        if let unlockLine = status.unlockLine {
                            Text(unlockLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let marker = step.fallbackMarkerLine {
                            Text(marker)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, stepIndent)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(prepStepAccessibilityLabel(index: index, step: step, status: status)))

            if status.phase != .locked {
                Button {
                    launch(step: step)
                } label: {
                    HStack(spacing: 4) {
                        Text(status.phase == .done ? "Run again" : step.startLabel)
                            .font(.footnote.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(status.phase == .done ? AppColor.textSecondary : AppColor.brandBlue)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(
                        (status.phase == .done ? Color.secondary.opacity(0.10) : AppColor.brandBlue.opacity(0.10)),
                        in: Capsule()
                    )
                }
                .buttonStyle(.pressable)
                .padding(.leading, stepIndent)
                .accessibilityLabel(
                    status.phase == .done
                        ? "Run again — \(step.displayLabel)"
                        : step.startLabel
                )
                .accessibilityHint(step.rationale)
                .accessibilityIdentifier("prepSession.step.\(index).begin")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Static hierarchy cue, not motion: the current step carries a 3pt
        // accent bar in the card gutter so the one actionable row reads
        // first. Decorative only — hidden from VoiceOver so the combined
        // row label keeps its shape.
        .overlay(alignment: .leading) {
            if status.phase == .current {
                Capsule()
                    .fill(AppColor.brandBlue)
                    .frame(width: 3)
                    .offset(x: -Spacing.sm)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func stepBadge(for phase: PrepStepStatus.Phase, index: Int) -> some View {
        switch phase {
        case .done:
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: stepBadgeSize, height: stepBadgeSize)
                .background(AppColor.positive, in: Circle())
        case .current:
            Text("\(index)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: stepBadgeSize, height: stepBadgeSize)
                .background(AppColor.brandBlue, in: Circle())
        case .locked:
            Image(systemName: "lock.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: stepBadgeSize, height: stepBadgeSize)
                .background(Color.secondary.opacity(0.14), in: Circle())
        }
    }

    private func prepStepAccessibilityLabel(
        index: Int,
        step: PrepRepStep,
        status: PrepStepStatus
    ) -> String {
        switch status.phase {
        case .done:
            guard status.coveredViaFallback else {
                return "Step \(index), \(step.displayLabel), covered."
            }
            return "Step \(index), \(step.displayLabel), covered with the Timed fallback. The \(PrepSessionReadiness.shapeName(for: step.mode)) itself is still untested."
        case .current:
            return "Step \(index), \(step.displayLabel), up next. \(step.rationale)"
        case .locked:
            var sentences = ["Step \(index), \(step.displayLabel), locked."]
            if let unlockLine = status.unlockLine {
                sentences.append(unlockLine)
            }
            if let marker = step.fallbackMarkerLine {
                sentences.append(marker)
            }
            return sentences.joined(separator: " ")
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
        // Commitment register (A2 map) — same beat as the Home coach card
        // Begin and the Train floating Start. All three steps funnel through
        // here, and the pattern is settings-gated inside CoachHaptic.
        CoachHaptic.drillStart()
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
