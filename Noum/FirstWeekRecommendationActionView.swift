#if canImport(SwiftUI)
import SwiftUI

/// Pure gate for the Day 1–4 continuation surface. A notification is only an
/// invitation to re-resolve state: it never carries coaching copy or enough
/// information to recreate an old prescription. The action becomes launchable
/// only when the live first-week contract and the current case intervention
/// still agree on one available mode and one exact rendered exposure.
struct FirstWeekRecommendationActionProjection: Equatable {
    enum Step: Equatable {
        case repeatRep
        case compareAndAdapt

        var kicker: String {
            switch self {
            case .repeatRep: return "FIRST-WEEK REPEAT"
            case .compareAndAdapt: return "COMPARISON REP"
            }
        }

        var title: String {
            switch self {
            case .repeatRep: return "Repeat the same lever"
            case .compareAndAdapt: return "Check whether it holds"
            }
        }

        var explanation: String {
            switch self {
            case .repeatRep:
                return "Keep the target fixed for one more rep so Noum can tell a repeatable signal from a one-off."
            case .compareAndAdapt:
                return "Use the same target once more. Noum will compare the result before reinforcing or changing course."
            }
        }
    }

    enum UnavailableReason: Equatable {
        case planMovedOn
        case noCurrentPrescription
        case modeUnavailable

        var title: String { "Your plan changed" }

        var message: String {
            switch self {
            case .planMovedOn:
                return "This reminder no longer matches your current first-week step. Choose a fresh exercise and Noum will build from what you do next."
            case .noCurrentPrescription:
                return "The exact recommendation behind this step is no longer available. Noum will not count a generic rep as following it."
            case .modeUnavailable:
                return "That prescribed exercise is not available right now. Choose another exercise without treating it as a verified follow-through."
            }
        }
    }

    struct Ready: Equatable {
        let step: Step
        let exposure: HomeCoachRecommendationExposure
    }

    struct Candidate: Equatable {
        enum Source: Equatable {
            case persistedExposure
            case continuingCase
        }

        let source: Source
        let exposure: HomeCoachRecommendationExposure

        static func persisted(
            _ persisted: RecommendationExposure,
            snapshot: FirstWeekCoachingContract.Snapshot,
            latestEligibleSession: PracticeSession,
            now: Date
        ) -> Candidate? {
            guard PracticeProgressEligibility.qualifies(latestEligibleSession),
                  snapshot.activation.completedAt <= persisted.shownAt,
                  snapshot.activation.completedAt <= latestEligibleSession.date,
                  latestEligibleSession.date <= persisted.shownAt,
                  persisted.shownAt <= now,
                  persisted.fingerprint.hasPrefix(
                    "summary-next-action|\(latestEligibleSession.id.uuidString)|"
                  ),
                  persisted.sourceSessionID == latestEligibleSession.id,
                  persisted.prescribedDemand == nil,
                  persisted.transcriptRetryTarget == nil,
                  !persisted.isAIBacked,
                  let exposure = HomeCoachRecommendationExposure.restoring(
                    persisted
                  ) else {
                return nil
            }
            return Candidate(
                source: .persistedExposure,
                exposure: exposure
            )
        }

        static func continuingCase(
            _ exposure: HomeCoachRecommendationExposure
        ) -> Candidate {
            Candidate(source: .continuingCase, exposure: exposure)
        }
    }

    /// Selects one candidate without allowing the global recommendation
    /// ledger to redefine this first-week step. A current case exposure keeps
    /// its complete live setup only when the persisted row is that exact
    /// rendered exposure. The sole restoration bridge is Summary's bounded,
    /// mode-only next action, tied to the latest eligible source session.
    static func selectCandidate(
        snapshot: FirstWeekCoachingContract.Snapshot,
        pending: RecommendationExposure?,
        latestEligibleSession: PracticeSession?,
        liveCaseExposure: HomeCoachRecommendationExposure?,
        now: Date
    ) -> Candidate? {
        guard let pending else {
            return liveCaseExposure.map(Candidate.continuingCase)
        }

        let collidesWithLiveCase = liveCaseExposure.map {
            $0.fingerprint == pending.fingerprint
        } ?? false
        guard let latestEligibleSession else {
            // `recordShown` is fingerprint-idempotent. If a malformed row
            // collides with the live case, showing that case would leave the
            // malformed row authoritative at tap time, so fail closed.
            return collidesWithLiveCase
                ? nil
                : liveCaseExposure.map(Candidate.continuingCase)
        }

        let isFresh = PracticeProgressEligibility.qualifies(latestEligibleSession)
            && snapshot.activation.completedAt <= latestEligibleSession.date
            && latestEligibleSession.date <= pending.shownAt
            && pending.shownAt <= now

        if let liveCaseExposure, collidesWithLiveCase {
            guard isFresh,
                  pending.adherenceSchemaVersion
                    == RecommendationAdherenceContract.schemaVersion,
                  !pending.isAIBacked,
                  pending.title == liveCaseExposure.title,
                  pending.focus == liveCaseExposure.focus,
                  pending.target == liveCaseExposure.target,
                  pending.mode == liveCaseExposure.mode,
                  pending.sourceSessionID == nil,
                  pending.prescribedDemand == liveCaseExposure.prescribedDemand,
                  pending.transcriptRetryTarget == nil,
                  pending.prescribedDemand.map({ $0.isValid(for: pending.mode) })
                    ?? true else {
                return nil
            }
            // Return the live exposure, not a lossy reconstruction: IM
            // scenario/tone and Timed theme remain exactly as prescribed.
            return .continuingCase(liveCaseExposure)
        }

        if isFresh,
           let restored = Candidate.persisted(
            pending,
            snapshot: snapshot,
            latestEligibleSession: latestEligibleSession,
            now: now
           ) {
            return restored
        }

        // An unrelated or stale global pending row cannot hijack the first-
        // week action. A distinct live case can safely replace it when shown.
        return liveCaseExposure.map(Candidate.continuingCase)
    }

    enum State: Equatable {
        case ready(Ready)
        case unavailable(UnavailableReason)
    }

    let state: State

    static func resolve(
        snapshot: FirstWeekCoachingContract.Snapshot?,
        candidate: Candidate?,
        availability: NextActionModeAvailability
    ) -> FirstWeekRecommendationActionProjection {
        let expected: (step: Step, mode: PracticeMode?)
        switch snapshot?.nextAction {
        case .repeatRep(let mode):
            expected = (.repeatRep, mode)
        case .compareAndAdapt(_, let mode):
            expected = (.compareAndAdapt, mode)
        case .recordSpokenBaseline, .realWorldCheckIn, .reviewFirstWeekRead, nil:
            return FirstWeekRecommendationActionProjection(
                state: .unavailable(.planMovedOn)
            )
        }

        guard let candidate else {
            return FirstWeekRecommendationActionProjection(
                state: .unavailable(.noCurrentPrescription)
            )
        }
        let exposure = candidate.exposure
        guard expected.mode.map({ $0 == exposure.mode }) ?? true,
              !exposure.fingerprint.isEmpty else {
            return FirstWeekRecommendationActionProjection(
                state: .unavailable(.planMovedOn)
            )
        }
        guard availability.isAvailable(exposure.mode) else {
            return FirstWeekRecommendationActionProjection(
                state: .unavailable(.modeUnavailable)
            )
        }
        return FirstWeekRecommendationActionProjection(
            state: .ready(Ready(step: expected.step, exposure: exposure))
        )
    }
}

/// Rehydrates the exact content-free Day-0 prescription from durable coach
/// memory when Summary did not emit a recommendation exposure (for example an
/// experiment control or a process termination). This is intentionally narrower
/// than Home's general case projection: it admits only the source-bound seed and
/// revalidates its exact qualified session before rendering or recording it.
struct FirstWeekSeedPrescriptionExposure {
    static func resolve(
        memory: CoachMemory?,
        snapshot: FirstWeekCoachingContract.Snapshot?,
        sessions: [PracticeSession],
        now: Date
    ) -> HomeCoachRecommendationExposure? {
        guard let snapshot,
              let intervention = memory?.activeIntervention,
              BoundedFirstRepCoachingSeed.validates(
                intervention: intervention,
                activationAt: snapshot.activation.completedAt,
                sessions: sessions,
                now: now
              ),
              let sourceSessionID = intervention.sourceSessionID,
              let source = sessions.first(where: { $0.id == sourceSessionID }),
              let focus = normalized(intervention.focus),
              let target = normalized(intervention.target) else {
            return nil
        }

        let demand: PracticeSessionDemand? = if intervention.mode == .timed {
            source.practiceDemand.flatMap { value in
                value.isValid(for: .timed) ? value : nil
            } ?? .timed(difficulty: .medium, speechProjectID: nil)
        } else {
            nil
        }
        let fingerprint = [
            "first-week-seed",
            sourceSessionID.uuidString,
            intervention.mode.rawValue,
            demand?.recommendationFingerprintComponent ?? "mode-only",
            focus,
            target,
        ].joined(separator: "|")

        return HomeCoachRecommendationExposure(
            fingerprint: fingerprint,
            title: normalized(intervention.title) ?? "Repeat the first-rep lever",
            focus: focus,
            target: target,
            mode: intervention.mode,
            scenario: nil,
            tone: nil,
            suggestedTheme: .all,
            prescribedDemand: demand
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(120))
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct FirstWeekRecommendationActionView: View {
    @Binding var navigationPath: NavigationPath

    @StateObject private var authManager = AuthManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var coachCheckInStore = CoachCheckInStore.shared
    @StateObject private var skillTrendStore = SkillTrendStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var bigMomentStore = BigMomentStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                switch projection.state {
                case .ready(let ready):
                    readyContent(ready)
                case .unavailable(let reason):
                    unavailableContent(reason)
                }
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(AppColor.screenBackground.ignoresSafeArea())
        .navigationTitle("First-week plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityIdentifier("firstWeek.recommendationAction.screen")
        .task(id: readyExposure?.fingerprint) {
            guard let exposure = readyExposure else { return }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled,
                  readyExposure?.fingerprint == exposure.fingerprint else {
                return
            }
            HomeCoachRecommendationPipeline.recordShown(
                exposure,
                goal: coachingProfileStore.profile?.chosenStyleGoal,
                store: recommendationLearningStore
            )
        }
    }

    private var liveSnapshot: FirstWeekCoachingContract.Snapshot? {
        // Observe every existing owner read by the live resolver. No state is
        // copied into this view; these reads only make store changes refresh it.
        _ = authManager.initialAccountHydrationState
        _ = sessionStore.sessions
        _ = coachingProfileStore.profile
        _ = coachingProfileStore.onboardingDraft
        _ = ratingStore.rating
        _ = baselineStore.baseline
        _ = coachMemoryStore.currentMemory
        _ = coachCheckInStore.checkIns
        // This route may be an old notification. Resolve live state without
        // capturing a Day-7 read that this continuation screen will not show.
        return FirstWeekCoachingSnapshotResolver.projection(at: Date())
    }

    private var availability: NextActionModeAvailability {
        NextActionModeAvailability(
            rating: ratingStore.rating,
            imConversationAvailable: IMModeAvailability.isAvailable
        )
    }

    private var sourceBlueprint: RecommendationBiasBlueprint {
        HomeCoachRecommendationPipeline.coherentBlueprint(
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            sessionStreak: streakFreeze.currentStreak,
            daysSinceLastSession: daysSinceLastSession,
            coachMemory: coachMemoryStore.currentMemory,
            imAvailable: IMModeAvailability.isAvailable,
            recommendationOutcomes: recommendationLearningStore.outcomes,
            skillTrends: skillTrendStore.snapshots
        )
    }

    private var currentExposure: HomeCoachRecommendationExposure? {
        if let seeded = FirstWeekSeedPrescriptionExposure.resolve(
            memory: coachMemoryStore.currentMemory,
            snapshot: liveSnapshot,
            sessions: sessionStore.progressEligibleSessions,
            now: Date()
        ) {
            return seeded
        }
        let blueprint = sourceBlueprint
        guard blueprint.source == .caseIntervention else { return nil }
        let moment = bigMomentStore.activeMoment
        let title = HomeCoachRecommendationPipeline.title(
            for: blueprint,
            sessionCount: sessionStore.progressEligibleSessionCount,
            activeMomentTitle: moment?.title,
            daysUntilActiveMoment: moment.flatMap { bigMomentStore.daysUntil($0) }
        )
        return HomeCoachRecommendationPipeline.exposure(
            for: blueprint,
            title: title,
            profile: coachingProfileStore.profile,
            recentSessions: sessionStore.progressEligibleSessions
        )
    }

    private var currentCandidate: FirstWeekRecommendationActionProjection.Candidate? {
        guard let snapshot = liveSnapshot else { return nil }
        let now = Date()
        let latestEligibleSession = sessionStore.progressEligibleSessions
            .filter { snapshot.activation.completedAt <= $0.date && $0.date <= now }
            .max(by: { $0.date < $1.date })
        return FirstWeekRecommendationActionProjection.selectCandidate(
            snapshot: snapshot,
            pending: recommendationLearningStore.pendingExposure,
            latestEligibleSession: latestEligibleSession,
            liveCaseExposure: currentExposure,
            now: now
        )
    }

    private var projection: FirstWeekRecommendationActionProjection {
        FirstWeekRecommendationActionProjection.resolve(
            snapshot: liveSnapshot,
            candidate: currentCandidate,
            availability: availability
        )
    }

    private var readyExposure: HomeCoachRecommendationExposure? {
        guard case .ready(let ready) = projection.state else { return nil }
        return ready.exposure
    }

    private var daysSinceLastSession: Int {
        guard let latest = sessionStore.progressEligibleSessions.first else {
            return 0
        }
        return Calendar.current.dateComponents(
            [.day],
            from: latest.date,
            to: Date()
        ).day ?? 0
    }

    @ViewBuilder
    private func readyContent(
        _ ready: FirstWeekRecommendationActionProjection.Ready
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(ready.step.kicker)
                .font(Typography.micro)
                .foregroundStyle(AppColor.brandBlue)
                .tracking(0.8)
            Text(ready.step.title)
                .font(Typography.sectionHero)
                .foregroundStyle(AppColor.textPrimary)
            Text(ready.step.explanation)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        prescriptionCard(ready.exposure)

        VStack(spacing: Spacing.sm) {
            PrimaryCTA(
                "Start \(ready.exposure.mode.displayLabel)",
                icon: "arrow.right",
                tint: AppColor.brandBlue
            ) {
                start(ready.exposure)
            }
            .accessibilityIdentifier("firstWeek.recommendationAction.start")

            manualSetupButton(title: "Choose a different exercise")
        }
    }

    private func prescriptionCard(
        _ exposure: HomeCoachRecommendationExposure
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: exposure.mode.iconName)
                    .font(.headline)
                    .foregroundStyle(AppColor.tint(for: exposure.mode))
                    .frame(width: 42, height: 42)
                    .background(
                        AppColor.tint(for: exposure.mode).opacity(0.10),
                        in: Circle()
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT PRESCRIPTION")
                        .font(Typography.micro)
                        .foregroundStyle(AppColor.textTertiary)
                        .tracking(0.7)
                    Text(exposure.mode.displayLabel)
                        .font(Typography.cardLabel)
                        .foregroundStyle(AppColor.textPrimary)
                }
                Spacer(minLength: 0)
                if let demand = demandLabel(exposure.prescribedDemand) {
                    Text(demand)
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(AppColor.brandBlue.opacity(0.08), in: Capsule())
                }
            }

            Divider()

            prescriptionLine(label: "Focus", value: exposure.focus)
            prescriptionLine(label: "Target", value: exposure.target)

            Label(
                "Noum only counts this as followed when this exact setup is completed.",
                systemImage: "checkmark.shield"
            )
            .font(Typography.caption)
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(
                cornerRadius: CornerRadius.large,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: CornerRadius.large,
                style: .continuous
            )
            .stroke(AppColor.brandBlue.opacity(0.16), lineWidth: 1)
        )
        .accessibilityIdentifier("firstWeek.recommendationAction.prescription")
    }

    private func prescriptionLine(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label.uppercased())
                .font(Typography.micro)
                .foregroundStyle(AppColor.textTertiary)
                .tracking(0.7)
            Text(value)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func unavailableContent(
        _ reason: FirstWeekRecommendationActionProjection.UnavailableReason
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(width: 52, height: 52)
                .background(AppColor.brandBlue.opacity(0.10), in: Circle())
                .accessibilityHidden(true)
            Text(reason.title)
                .font(Typography.sectionHero)
                .foregroundStyle(AppColor.textPrimary)
            Text(reason.message)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(
                cornerRadius: CornerRadius.large,
                style: .continuous
            )
        )
        .accessibilityIdentifier("firstWeek.recommendationAction.unavailable")

        manualSetupButton(title: "Choose an exercise")
    }

    private func manualSetupButton(title: String) -> some View {
        Button {
            // Deliberately no recommendation store write here. The picker is
            // a manual recovery path, not proof that the stale prescription
            // was accepted or followed.
            navigationPath.append(AppDestination.practiceSelection)
        } label: {
            Text(title)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("firstWeek.recommendationAction.manualSetup")
    }

    private func start(_ renderedExposure: HomeCoachRecommendationExposure) {
        // Re-resolve at the tap boundary. A notification or visible screen can
        // age while open; stale copy must never create an accepted exposure.
        guard case .ready(let live) = projection.state,
              live.exposure.fingerprint == renderedExposure.fingerprint else {
            return
        }
        CoachHaptic.drillStart()
        let launch = HomeCoachRecommendationPipeline.accept(
            live.exposure,
            modeAvailability: availability,
            imAvailable: IMModeAvailability.isAvailable,
            goal: coachingProfileStore.profile?.chosenStyleGoal,
            store: recommendationLearningStore
        )
        navigationPath.append(launch.destination)
    }

    private func demandLabel(_ demand: PracticeSessionDemand?) -> String? {
        guard let difficulty = demand?.timedDifficulty else { return nil }
        return difficulty.compactDemandLabel
    }
}
#endif
