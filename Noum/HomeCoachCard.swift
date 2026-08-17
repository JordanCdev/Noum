#if canImport(SwiftUI)
import SwiftUI

enum HomeMomentCopy {
    static func title(momentTitle: String, days: Int) -> String {
        "\(momentTitle) · \(days) day\(days == 1 ? "" : "s")"
    }
}

/// Truthful, non-persisted progress for Today’s deliberately small mission.
/// A rep counts only after the existing daily-goal owner accepts it; this type
/// merely projects that reconciled same-day count against the user's persisted
/// 1–3 rep preference.
struct TodayRepMissionProgress: Equatable {
    let targetReps: Int
    let completedReps: Int

    init(completedReps: Int, targetReps: Int) {
        self.targetReps = min(max(targetReps, 1), 3)
        self.completedReps = min(max(completedReps, 0), self.targetReps)
    }

    var isComplete: Bool {
        completedReps == targetReps
    }

    var currentRep: Int {
        isComplete ? targetReps : completedReps + 1
    }

    var progress: Double {
        Double(completedReps) / Double(targetReps)
    }

    var compactLabel: String {
        isComplete
            ? "\(targetReps) of \(targetReps) complete"
            : "Rep \(currentRep) of \(targetReps)"
    }

    var accessibilityValue: String {
        if isComplete {
            return "All \(targetReps) rep\(targetReps == 1 ? "" : "s") complete today."
        }
        let remaining = targetReps - completedReps
        return "\(completedReps) of \(targetReps) reps complete. \(remaining) remaining."
    }

    /// The visible commitment stays about the user's small daily promise,
    /// while the accessibility label on the button continues to name the
    /// exact practice mode that will open.
    var actionTitle: String {
        if isComplete { return "Practice another rep" }
        if targetReps == 1 { return "Start today's rep" }
        return "Start rep \(currentRep) of \(targetReps)"
    }
}

enum TodayMissionRepState: Equatable {
    case complete
    case current
    case upcoming
}

/// Pure visual projection for the authored mission stack. It deliberately
/// derives from `TodayRepMissionProgress` instead of owning another counter.
struct TodayMissionRepPresentation: Identifiable, Equatable {
    let rep: Int
    let state: TodayMissionRepState

    var id: Int { rep }
    var title: String { "Rep \(rep)" }

    var supporting: String {
        switch state {
        case .complete: return "Complete"
        case .current: return "Ready now"
        case .upcoming: return "After rep \(rep - 1)"
        }
    }

    var status: String {
        switch state {
        case .complete: return "Done"
        case .current: return "Now"
        case .upcoming: return "Next"
        }
    }

    static func items(for progress: TodayRepMissionProgress) -> [Self] {
        (1...progress.targetReps).map { rep in
            let state: TodayMissionRepState
            if rep <= progress.completedReps {
                state = .complete
            } else if !progress.isComplete && rep == progress.currentRep {
                state = .current
            } else {
                state = .upcoming
            }
            return Self(rep: rep, state: state)
        }
    }
}

// MARK: - Home Coach Card (M14)
//
// One composed hero that replaces the populated home's split greeting
// (heroCard) + suggestion (quickStartCard). The product shift is from
// "dashboard of tiles" to "a coach speaking to you on open" — the shared
// waveform carries Noum's identity, the coach's recommendation is the primary
// copy, and a single Begin CTA carries the user into the right rep.
//
// All copy comes from the existing recommendation pipeline
// (`RecommendationBiasEngine` + `CoachingPlanner`); nothing here invents
// coaching logic.

@available(iOS 17.0, macOS 12.0, *)
struct HomeAskNoumShortcut: Equatable {
    static let title = "Ask Noum"
    static let actionTitle = "Ask Noum"
    // The Ask Noum door now renders as its own quiet white row on Home
    // (below the Path/Journey card), not nested inside the coach hero —
    // so the identifier is location-neutral. See `homeAskNoumRow` in
    // ContentView and docs/UX_VISUAL_DIRECTION.md ("Ask Noum = white row
    // + violet chat chip").
    static let accessibilityIdentifier = "home.askNoum.row"

    static func body(sessionCount: Int) -> String {
        HomeAskNoumEvidenceCopy.line(sessionCount: sessionCount)
    }
}

/// Exact recommendation projection rendered and actioned by Home's coach
/// hero. Keeping exposure identity beside the visible surface prevents the
/// learning ledger from recording copy that was never shown, and gives the
/// tap path the same mode value that `recordShown` received.
struct HomeCoachRecommendationExposure: Equatable {
    let fingerprint: String
    let title: String
    let focus: String
    let target: String
    let mode: PracticeMode
    let scenario: IMConversationScenario?
    let tone: IMTargetTone?
    let suggestedTheme: PromptTheme
    let prescribedDemand: PracticeSessionDemand?

    static func make(
        blueprint: RecommendationBiasBlueprint,
        title: String,
        profile: CoachingProfile?,
        recentSessions: [PracticeSession]
    ) -> HomeCoachRecommendationExposure {
        let rawFocus = blueprint.focus.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawTarget = blueprint.target.trimmingCharacters(in: .whitespacesAndNewlines)
        let focus = rawFocus.isEmpty ? "Build one clear rep." : String(rawFocus.prefix(180))
        let target = rawTarget.isEmpty
            ? "Answer first. Give one reason. Then stop."
            : String(rawTarget.prefix(180))
        let recent = PracticeProgressEligibility.eligibleSessions(in: recentSessions).prefix(5).map { session in
            "\(session.id.uuidString)-\(session.mode.rawValue)-\(session.fillerWordCount)-\(Int(session.duration))-\(session.score ?? 0)"
        }.joined(separator: "|")
        let profileKey = profile.map {
            "\($0.primaryGoal.rawValue)-\($0.biggestChallenge.rawValue)-\($0.desiredOutcome.rawValue)-\($0.chosenStyleGoal?.rawValue ?? "no-style")"
        } ?? "no-profile"
        // Home's duration micro-label is part of the prescription. Its Timed
        // fallback copy says 30 SEC, so persist Medium rather than silently
        // falling back to the user's unrelated saved setting at launch time.
        let prescribedDemand: PracticeSessionDemand? = blueprint.recommendedMode == .timed
            ? .timed(
                difficulty: blueprint.suggestedTimedDifficulty ?? .medium,
                speechProjectID: nil
            )
            : nil
        let fingerprint = [
            "home-coach",
            profileKey,
            blueprint.source.trackingLabel,
            blueprint.recommendedMode.rawValue,
            blueprint.recommendedScenario?.rawValue ?? "no-scenario",
            blueprint.recommendedTone?.rawValue ?? "no-tone",
            prescribedDemand?.recommendationFingerprintComponent ?? "mode-only",
            blueprint.suggestedTheme.rawValue,
            title,
            focus,
            target,
            recent
        ].joined(separator: "|")
        return HomeCoachRecommendationExposure(
            fingerprint: fingerprint,
            title: title,
            focus: focus,
            target: target,
            mode: blueprint.recommendedMode,
            scenario: blueprint.recommendedScenario,
            tone: blueprint.recommendedTone,
            suggestedTheme: blueprint.suggestedTheme,
            prescribedDemand: prescribedDemand
        )
    }

    /// Rehydrates the exact bounded fields already owned by the recommendation
    /// ledger. This is the bridge used when Summary exposed a prescription but
    /// CoachMemory has not yet projected it as a continuing intervention.
    /// Scenario/tone/theme were never part of adherence provenance; restoring
    /// them by inference would be less honest than keeping their neutral values.
    static func restoring(
        _ persisted: RecommendationExposure
    ) -> HomeCoachRecommendationExposure? {
        let focus = persisted.focus.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = persisted.target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard persisted.adherenceSchemaVersion
                == RecommendationAdherenceContract.schemaVersion,
              !persisted.fingerprint.isEmpty,
              !focus.isEmpty,
              !target.isEmpty,
              persisted.prescribedDemand.map({ $0.isValid(for: persisted.mode) })
                ?? true else {
            return nil
        }
        return HomeCoachRecommendationExposure(
            fingerprint: persisted.fingerprint,
            title: persisted.title,
            focus: focus,
            target: target,
            mode: persisted.mode,
            scenario: nil,
            tone: nil,
            suggestedTheme: .all,
            prescribedDemand: persisted.prescribedDemand
        )
    }

    /// One immutable handoff derived from this exact visible projection. The
    /// caller supplies time for deterministic tests; no target or demand is
    /// re-resolved at the navigation boundary.
    func quickStartIntent(acceptedAt: Date = Date()) -> PracticeQuickStartIntent? {
        PracticeQuickStartIntent(
            fingerprint: fingerprint,
            focus: focus,
            target: target,
            mode: mode,
            prescribedDemand: prescribedDemand,
            acceptedAt: acceptedAt
        )
    }
}

/// Shared projection and acceptance boundary for Home-owned recommendations.
/// The coach hero and first-week action screen both use this path so the copy
/// the user sees, the persisted exposure, and the launched practice demand
/// remain one coherent prescription.
enum HomeCoachRecommendationPipeline {
    static func coherentBlueprint(
        profile: CoachingProfile?,
        sessions: [PracticeSession],
        sessionStreak: Int,
        daysSinceLastSession: Int,
        coachMemory: CoachMemory?,
        imAvailable: Bool,
        recommendationOutcomes: [RecommendationOutcome],
        skillTrends: [SkillSnapshot]
    ) -> RecommendationBiasBlueprint {
        let eligibleSessions = PracticeProgressEligibility.eligibleSessions(in: sessions)
        let base = RecommendationBiasContextBuilder.context(
            profile: profile,
            sessions: eligibleSessions,
            sessionStreak: sessionStreak,
            daysSinceLastSession: daysSinceLastSession,
            coachMemory: coachMemory,
            imAvailable: imAvailable,
            recommendationOutcomes: recommendationOutcomes,
            summaryStyle: .compact
        ).blueprint
        return CurrentCoachingFocusPresentation.make(
            trends: TrendAnalyzer.analyze(snapshots: skillTrends),
            sessionCount: eligibleSessions.count
        )?.applying(to: base) ?? base
    }

    static func title(
        for blueprint: RecommendationBiasBlueprint,
        sessionCount: Int,
        activeMomentTitle: String?,
        daysUntilActiveMoment: Int?
    ) -> String {
        guard sessionCount > 0 else { return "Welcome." }
        if sessionCount < 3 { return "Start clean." }
        if let activeMomentTitle,
           let daysUntilActiveMoment,
           daysUntilActiveMoment >= 0,
           daysUntilActiveMoment <= 14 {
            return HomeMomentCopy.title(
                momentTitle: activeMomentTitle,
                days: daysUntilActiveMoment
            )
        }
        let focus = CoachDisplayCopy.normalized(blueprint.focus)
        guard !focus.isEmpty else { return "Build a clean rep." }
        let trimmed = focus.trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        return "\(trimmed)."
    }

    static func exposure(
        for blueprint: RecommendationBiasBlueprint,
        title: String,
        profile: CoachingProfile?,
        recentSessions: [PracticeSession]
    ) -> HomeCoachRecommendationExposure {
        HomeCoachRecommendationExposure.make(
            blueprint: blueprint,
            title: title,
            profile: profile,
            recentSessions: recentSessions
        )
    }

    @MainActor
    static func recordShown(
        _ exposure: HomeCoachRecommendationExposure,
        goal: SpeakingStyleGoal?,
        store: RecommendationLearningStore
    ) {
        store.recordShown(
            fingerprint: exposure.fingerprint,
            title: exposure.title,
            focus: exposure.focus,
            target: exposure.target,
            mode: exposure.mode,
            isAIBacked: false,
            goal: goal,
            prescribedDemand: exposure.prescribedDemand
        )
    }

    /// Records the exact rendered exposure, marks it accepted only when the
    /// live route still honors its mode/demand, and returns the route that
    /// should actually launch. Operational fallbacks are deliberately not
    /// counted as followed prescriptions.
    @MainActor
    static func accept(
        _ exposure: HomeCoachRecommendationExposure,
        modeAvailability: NextActionModeAvailability,
        imAvailable: Bool,
        goal: SpeakingStyleGoal?,
        store: RecommendationLearningStore
    ) -> PracticeModeLaunchProjection {
        let launch = PracticeModeLaunchProjection.resolve(
            displayedMode: exposure.mode,
            scenario: exposure.scenario,
            tone: exposure.tone,
            prescribedDemand: exposure.prescribedDemand,
            imAvailable: imAvailable,
            modeAvailability: modeAvailability
        )
        RecommendationTapAttribution.apply(
            launch: launch,
            recordShown: {
                recordShown(exposure, goal: goal, store: store)
            },
            recordAccepted: { mode in
                store.markTapped(mode: mode)
            }
        )
        // The prescribed theme intentionally never writes into the user's
        // persisted manual Timed setup (`PromptTheme.selectedDefaultsKey`).
        // That slot belongs to an explicit setup choice; overwriting it made
        // one accepted prescription leak into every later manual or fallback
        // launch. Prompt bias still applies: with the default "All Themes"
        // selection, `PracticeTopics.next` resolves prompts through
        // `themeBias(for: profile)` — the same mapping that produced
        // `exposure.suggestedTheme` in the first place.
        if !launch.acceptsDisplayedPrescription {
            PracticeModeQuickStart.clear()
        }
        return launch
    }
}

// MARK: - Plan-arc line (coach-parity eval move 4)
//
// The 4-week forward plan already exists (`ForwardPlanService` /
// `ForwardPlanStore`) but lived only on Profile + in the chat thread —
// built but buried. This folds it into the coach hero as ONE compact
// tappable line ("Week 2 of 4 — pauses") so today's prescription reads
// as a step inside a visible arc, not an isolated tip. Pure copy
// resolver, view-free, so the line contract is unit-testable.
@available(iOS 17.0, macOS 12.0, *)
enum HomePlanArcLine {

    /// Line for the hero's plan-arc row, or nil when Home should stay
    /// quiet. Reuses the existing `CoachingPlanCardState` contract:
    ///   • `.hidden` / `.prompt` → nil. The "ask for a plan" pre-prompt
    ///     stays a Profile surface — Home never advertises a plan that
    ///     doesn't exist yet.
    ///   • `.live` → "Week N of 4 — {focus}", the at-a-glance arc.
    ///   • `.stale` → the same voice-shaped regenerate copy the Profile
    ///     card uses (`CoachingPlanCardVisibility.ctaLabel`), so both
    ///     surfaces speak with one voice when the Big Moment changed.
    static func line(
        state: CoachingPlanCardState,
        voice: SpeakingStyleGoal?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        switch state {
        case .hidden, .prompt:
            return nil
        case .live(let plan, _):
            guard let week = plan.currentWeek(now: now, calendar: calendar) else { return nil }
            return "Week \(week.weekIndex) of 4 \u{2014} \(week.focusSkillArea.displayName.lowercased())"
        case .stale:
            let label = CoachingPlanCardVisibility.ctaLabel(state: state, voice: voice)
            return label.isEmpty ? nil : label
        }
    }
}

@available(iOS 17.0, macOS 12.0, *)
enum HomeCoachPresentation {
    case card
    case immersive
}

@available(iOS 17.0, macOS 12.0, *)
struct HomeCoachCard: View {

    @Binding var navigationPath: NavigationPath
    /// Read from `DailyGoalManager`, which already reconciles qualified speech
    /// sessions and explicitly recorded drills. This view never owns or writes
    /// a second progress counter.
    let completedRepsToday: Int
    /// The persisted user preference owned by `DailyGoalManager`. Defaulted for
    /// previews/legacy call sites; production Home always passes the live value.
    var targetRepsToday: Int = 1

    /// Host-supplied gate (>= 1 completed rep). The row additionally
    /// self-gates on an actual active plan via `HomePlanArcLine` — both
    /// must hold before anything renders.
    var showsPlanArc: Bool = false
    /// Retained for source compatibility. Both presentations now use the same
    /// compact card language; Home no longer turns the coach surface into an
    /// immersive canvas.
    var presentation: HomeCoachPresentation = .card
    /// False while Home is only the retained routing root behind another
    /// recommendation surface. The delayed dwell task is cancelled before it
    /// can replace that surface's current exact ledger exposure.
    var recordsRecommendationExposure: Bool = true
    /// Top safe-area inset measured by the host because the enclosing Today
    /// scroll view extends under the status bar.
    var heroTopInset: CGFloat = 0

    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var skillTrendStore = SkillTrendStore.shared
    @StateObject private var forwardPlanStore = ForwardPlanStore.shared
    @StateObject private var phraseBankStore = PhraseBankStore.shared
    // Path progress drives the "Landmark within reach" coach variant — when
    // the current path node is one rep / one score-point / one day from
    // unlocking, the coach voice points at it directly. Read-only.
    @StateObject private var pathProgress = PathProgressManager.shared
    private var bigMomentStore: BigMomentStore { .shared }

    @State private var lastRenderedRecommendationExposure: HomeCoachRecommendationExposure?
    /// V4.6.1 hero entrance choreography — one-shot per mount (the
    /// CardEntrance precedent: replays on a cold remount, never on a
    /// pop-return to the retained Home). Content is never invisible:
    /// blocks start at 0.97 scale / 0.85 opacity and settle to identity.
    /// Reduce Motion sets both flags without animation (instant appear).
    @State private var heroTextSettled = false
    @State private var heroCTASettled = false
    /// Choreography beats: the headline settles first and the CTA follows
    /// at +120 ms — total well inside ScreenshotTour's 1.5 s post-
    /// `home.screen` wait. Offsets only; curves come from the shared
    /// motion tokens (`.settle`).
    private enum HeroEntranceBeat {
        static let ctaDelay: TimeInterval = 0.12
        /// Commit handoff: the waveform lifts toward the recording surface's
        /// presence for one beat before the push, so Today flows into the
        /// rep instead of cutting away. All business state (acceptance,
        /// arming, ledger) runs BEFORE the delay — only navigation waits.
        static let handoff: TimeInterval = 0.18
    }
    /// True during the commit handoff beat — the waveform lifts while
    /// the push is in flight. Reset when Home reappears on pop-back.
    @State private var heroHandoff = false
    @State private var plannedPhraseError: String?
    /// The earned evidence event this visit is announcing (258:1078).
    /// Resolved once on appear, acknowledged immediately so the next Home
    /// visit collapses it into the compact receipt instead.
    @State private var activeEarned: V46EarnedTodayPresentation?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isSelectedAppTab) private var isSelectedAppTab

    var body: some View {
        _ = aiSettings.cloudProcessingConsent
        let renderedAvailability = currentModeAvailability
        let sourceBlueprint = RecommendationTapCapabilityLossUITestFixture
            .blueprintForRendering(coherentRecommendationBlueprint)
        let renderedBlueprint = renderedAvailability.resolving(sourceBlueprint)
        let renderedExposure = recommendationExposure(for: renderedBlueprint)
        // Today is an editorial journey, not one giant gradient card. The
        // warm canvas establishes calm; the violet coach stage supplies one
        // moment of identity; truthful rep rows make the commitment tangible.
        return VStack(alignment: .leading, spacing: Spacing.lg) {
            missionHeader(todayMissionProgress)

            missionHeadline(for: renderedBlueprint)
                .heroEntrance(settled: heroTextSettled)

            coachFocusStage(
                exposure: renderedExposure,
                blueprint: renderedBlueprint
            )
            .heroEntrance(settled: heroTextSettled)

            missionRepTrack(todayMissionProgress)
                .heroEntrance(settled: heroTextSettled)

            heroActions(
                progress: todayMissionProgress,
                renderedExposure: renderedExposure
            )
            .heroEntrance(settled: heroCTASettled)

            // A saved current-week phrase is concrete practice, not an
            // additional recommendation. The broader plan stays hidden.
            if showsPlanArc || currentPlannedPhrase != nil {
                planArcRow
                    .heroEntrance(settled: heroCTASettled)
            }
        }
        .padding(.horizontal, Spacing.screenH)
        .padding(.top, heroTopInset + Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .onAppear {
            lastRenderedRecommendationExposure = renderedExposure
            // Pop-back from a rep: the handoff lift settles home again.
            heroHandoff = false
            playEntranceChoreography()
            resolveEarnedState(for: renderedBlueprint)
        }
        .onChange(of: renderedExposure.fingerprint) { _, _ in
            lastRenderedRecommendationExposure = renderedExposure
        }
        .task(
            id: "\(renderedExposure.fingerprint)|\(isSelectedAppTab)|\(recordsRecommendationExposure)"
        ) {
            // A cold deep link briefly mounts Home before AppShell selects the
            // destination tab. Require a small, cancellable visibility dwell
            // so that transient mount is not counted as a shown prescription.
            // The tap path still records synchronously (and idempotently), so
            // a legitimate fast tap cannot lose its exposure event.
            guard isSelectedAppTab, recordsRecommendationExposure else { return }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled,
                  isSelectedAppTab,
                  recordsRecommendationExposure else { return }
            recordRecommendationShown(renderedExposure)
        }
        .alert(
            "Phrase unavailable",
            isPresented: Binding(
                get: { plannedPhraseError != nil },
                set: { if !$0 { plannedPhraseError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { plannedPhraseError = nil }
        } message: {
            Text(plannedPhraseError ?? "Choose the phrase again from your Phrase bank.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.coachCard")
    }

    private var todayMissionProgress: TodayRepMissionProgress {
        TodayRepMissionProgress(
            completedReps: completedRepsToday,
            targetReps: targetRepsToday
        )
    }

    private func missionHeader(_ progress: TodayRepMissionProgress) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                missionEyebrow
                Spacer(minLength: Spacing.xs)
                missionProgressPill(progress)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                missionEyebrow
                missionProgressPill(progress)
            }
        }
    }

    private var missionEyebrow: some View {
        Text("Today's mission")
            .font(Typography.caption)
            .foregroundStyle(AppColor.coachingInkOnQuiet)
            .textCase(.uppercase)
            .tracking(0.5)
            .accessibilityAddTraits(.isHeader)
    }

    private func missionProgressPill(
        _ progress: TodayRepMissionProgress
    ) -> some View {
        Text(progress.compactLabel)
            .font(Typography.monoDigit(Typography.captionSmall))
            .foregroundStyle(AppColor.coachingInkOnQuiet)
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: 32)
            .background(AppColor.proQuietSurface, in: Capsule())
            .accessibilityHidden(true)
    }

    private func missionHeadline(
        for blueprint: RecommendationBiasBlueprint
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(activeEarned?.headlineOverride ?? coachTitle(for: blueprint))
                .font(Typography.figtree(size: 31, weight: .heavy, relativeTo: .largeTitle))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityIdentifier("home.coachCard.title")

            if activeEarned == nil, let subtitle = coachSubtitle(for: blueprint) {
                Text(subtitle)
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                    .accessibilityIdentifier("home.coachCard.subtitle")
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var missionWaveform: some View {
        NoumWaveformMark(
            state: activeEarned != nil
                ? .earned
                : (heroHandoff ? .listening : .idle),
            level: heroHandoff ? 1 : 0,
            tint: .white,
            size: 72
        )
        .scaleEffect(heroHandoff ? 1.08 : 1)
        .animation(
            reduceMotion ? nil : NoumMotion.screenContinuation,
            value: heroHandoff
        )
        .accessibilityHidden(true)
    }

    /// The violet stage is reserved for the coach's exact prescription. It
    /// carries the same immutable target that the launch handoff accepts.
    private func coachFocusStage(
        exposure: HomeCoachRecommendationExposure,
        blueprint: RecommendationBiasBlueprint
    ) -> some View {
        NoumSurface(.mission) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let earned = activeEarned {
                    earnedChip(earned.chipText)
                        .transition(.opacity)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: Spacing.lg) {
                        missionWaveform
                        coachFocusCopy(exposure)
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        missionWaveform
                        coachFocusCopy(exposure)
                    }
                }

                Text(activeEarned?.metaOverride ?? heroMetaText(for: blueprint))
                    .font(Typography.monoDigit(Typography.captionSmall))
                    .foregroundStyle(AppColor.homeHeroMetaText)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 30)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func coachFocusCopy(
        _ exposure: HomeCoachRecommendationExposure
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Your coach")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.homeHeroMetaText)

            Text(exposure.focus)
                .font(Typography.headline)
                .foregroundStyle(AppColor.homeHeroTitleText)
                .fixedSize(horizontal: false, vertical: true)

            Text(exposure.target)
                .font(Typography.body)
                .foregroundStyle(AppColor.homeHeroSubtitleText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's practice target. \(exposure.target)")
        .accessibilityIdentifier("home.coachCard.target")
    }

    private func missionRepTrack(
        _ progress: TodayRepMissionProgress
    ) -> some View {
        VStack(spacing: Spacing.xs) {
            ForEach(TodayMissionRepPresentation.items(for: progress)) { item in
                missionRepNode(item)
            }
        }
        .background(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(AppColor.subtleBorder)
                .frame(width: 3)
                .padding(.vertical, 32)
                // The rep rows inset their 44pt nodes by `Spacing.md`; keep
                // the connector through the node centres, not the card edge.
                .offset(x: Spacing.md + 20.5)
                .accessibilityHidden(true)
        }
        .animation(
            NoumMotion.animation(for: .earned, reduceMotion: reduceMotion),
            value: progress.completedReps
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Today's \(progress.targetReps)-rep mission"
        )
        .accessibilityValue(progress.accessibilityValue)
        .accessibilityIdentifier("home.mission.progress")
    }

    private func missionRepNode(
        _ item: TodayMissionRepPresentation
    ) -> some View {
        let isComplete = item.state == .complete
        let isCurrent = item.state == .current
        let tint: Color = isComplete
            ? AppColor.positive
            : isCurrent ? AppColor.coachingInk : AppColor.textTertiary

        return HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(isCurrent ? AppColor.coachingInk : tint.opacity(isComplete ? 1 : 0.12))

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                } else {
                    Text("\(item.rep)")
                        .font(Typography.monoDigit(Typography.caption.weight(.bold)))
                        .foregroundStyle(isCurrent ? Color.white : tint)
                }
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.title)
                    .font(Typography.headline)
                    .foregroundStyle(isCurrent ? AppColor.textPrimary : tint)
                Text(item.supporting)
                    .font(Typography.caption)
                    .foregroundStyle(isCurrent ? AppColor.textSecondary : tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.status)
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(
            isCurrent ? AppColor.proQuietSurface : Color.clear,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColor.coachAccent.opacity(0.18), lineWidth: 1)
            }
        }
        .shadow(
            color: isCurrent ? AppColor.coachingInk.opacity(0.08) : .clear,
            radius: isCurrent ? Spacing.sm : 0,
            y: isCurrent ? Spacing.xs : 0
        )
        .scaleEffect(!reduceMotion && isCurrent ? 1.01 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title). \(item.supporting). \(item.status).")
    }

    // MARK: - Coach copy
    //
    // Source of truth precedence:
    //   1. Coach memory has both signal and goal → use blueprint focus +
    //      tier reference where it lands naturally.
    //   2. Signal but no goal → blueprint focus only.
    //   3. No signal → cold-start line.
    //
    // We never quote a user-typed goal verbatim (lock-screen-safety rule),
    // we never use "Let's" / "Great job!" / exclamations, and we keep the
    // line short enough to read on open.

    /// Coach copy is now split into title + subtitle for visual
    /// hierarchy. Title is the headline (the user reads this first);
    /// subtitle is the why (read only if the title earned attention).

    private func coachTitle(for blueprint: RecommendationBiasBlueprint) -> String {
        let moment = bigMomentStore.activeMoment
        return HomeCoachRecommendationPipeline.title(
            for: blueprint,
            sessionCount: sessionStore.progressEligibleSessionCount,
            activeMomentTitle: moment?.title,
            daysUntilActiveMoment: moment.flatMap { bigMomentStore.daysUntil($0) }
        )
    }

    private func coachSubtitle(for blueprint: RecommendationBiasBlueprint) -> String? {
        // Big Moment countdown — highest-priority variant when a moment is
        // set and within 30 days. Suppressed when daysUntil < 0 (moment
        // passed) or > 30 (too far out to feel urgent). Falls back to the
        // goal-voice subtitle when the moment is cleared or past.
        if let moment = bigMomentStore.activeMoment,
           let days = bigMomentStore.daysUntil(moment),
           days >= 0 && days <= 14 {
            return "Today's focused mission builds toward the real conversation."
        }

        guard hasSignal else {
            // Empty-state — adapt to the user's stated challenge if the
            // CoachingProfile already exists (they finished onboarding
            // but haven't done a rep yet). Mirrors the copy the legacy
            // `firstSessionWelcomeMessage` carried so the first-impression
            // line names the user's own goal, not a generic banner.
            if let profile = coachingProfileStore.profile {
                // Canonical fragment shared with the Ask Noum day-0
                // greeting (`SpeakingChallenge.trainingFocusFragment`)
                // so both pre-evidence surfaces acknowledge the stated
                // challenge with one phrasing.
                let challenge = profile.biggestChallenge.trainingFocusFragment
                return "You want to work on \(challenge). One short rep sets your starting line."
            }
            return "One short rep sets your starting line."
        }

        if sessionStore.progressEligibleSessionCount < 3 {
            return "Complete three qualifying reps and Noum can start finding your weakest line."
        }

        if blueprint.source == .caseIntervention {
            return CoachDisplayCopy.normalized(blueprint.whyNow)
        }

        // Recurring positional read — the longitudinal "the coach remembers"
        // line. Until now this longitudinal signal reached only the coach prompt
        // (`CoachContextBuilder`'s POSITIONAL TREND block) and the dedicated
        // `RepEventTrendCard`; threading one line onto the hero makes the
        // cross-rep memory visible on the highest-traffic surface — the layer
        // whole-take-average rivals never reach. Sits ABOVE the weekly-rhythm /
        // tier-holding / generic-blueprint fallbacks (a named recurring position
        // is more specific and more differentiating than a cadence nudge) and
        // BELOW BigMoment / cold-start / case-intervention / landmark (those are
        // more time-critical or more concrete). Honest by construction: the
        // engine's >=3-reps-with-signal + super-majority floors self-suppress
        // below enough history for the claim to be truthful, so a thin-data user
        // never sees it. When a case intervention is active it returns above, so
        // the coach never double-points at one marker in a single line.
        if let trend = positionalTrend {
            return RepEventTrendCopy.homeSubtitle(for: trend)
        }

        let why = CoachDisplayCopy.normalized(blueprint.whyNow)

        if !why.isEmpty {
            return why
        }
        return nil
    }

    /// The hero's one dominant action. M23 precedence preserved: when a real
    /// moment is within 14 days, preparation is the primary action and the
    /// ordinary rep stays as a quiet alternative — the V4.6 "contextual
    /// upcoming moment" slot. Otherwise one Start pill, nothing else.
    @ViewBuilder
    private func heroActions(
        progress: TodayRepMissionProgress,
        renderedExposure: HomeCoachRecommendationExposure
    ) -> some View {
        if let moment = bigMomentStore.activeMoment,
           let days = bigMomentStore.daysUntil(moment),
            days >= 0 && days <= 14 {
            VStack(spacing: Spacing.xs) {
                PrimaryCTA("Continue prep", tint: AppColor.coachingInk) {
                    commitWithHandoff {
                        navigationPath.append(AppDestination.prepSession)
                    }
                }
                .accessibilityIdentifier("home.coachCard.prepSession")
                .accessibilityLabel(
                    Text("Prepare for your \(moment.category.displayName), \(days) day\(days == 1 ? "" : "s") away")
                )

                Button {
                    beginRecommendedRep(renderedExposure: renderedExposure)
                } label: {
                    Text("Start \(renderedExposure.mode.displayLabel) instead")
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(AppColor.coachingInkOnQuiet)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("home.coachCard.begin")
            }
        } else {
            PrimaryCTA(
                activeEarned?.ctaOverride ?? progress.actionTitle,
                tint: AppColor.coachingInk
            ) {
                beginRecommendedRep(renderedExposure: renderedExposure)
            }
            .accessibilityIdentifier("home.coachCard.begin")
            // Preserve the route-readable label used by VoiceOver and the
            // recommendation correlation UI suite. The visible copy names the
            // small mission commitment; this label names the exact mode.
            .accessibilityLabel("Start \(renderedExposure.mode.displayLabel)")
        }
    }

    /// White translucent capsule with the four-bar mini trace — the earned
    /// signal chip. Announced as one element per the accessibility sheet.
    private func earnedChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array([4.0, 7.0, 11.0, 6.0].enumerated()), id: \.offset) { _, height in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 2.5, height: height)
                }
            }
            .accessibilityHidden(true)

            Text(text)
                .font(Typography.figtree(size: 11, weight: .heavy, relativeTo: .caption2))
                .tracking(0.6)
                .foregroundStyle(.white)
        }
        .padding(.leading, 10)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("New evidence, from your retry"))
        .accessibilityIdentifier("home.coachCard.earnedChip")
    }

    /// Resolve the once-per-event earned announcement. Acknowledging on
    /// first render is what enforces "shown once, then collapsed" — the
    /// @State copy keeps this visit stable while the ledger moves on.
    ///
    /// Announcement beat: the chip, headline/meta overrides and waveform's
    /// earned state all land on one payoff reveal
    /// (Reduce Motion: 200 ms cross-fade), with the milestone-register
    /// haptic fired once — the nil-guard plus the immediate ledger
    /// acknowledge are the once-per-event contract, so neither the
    /// animation nor the haptic can replay.
    private func resolveEarnedState(for blueprint: RecommendationBiasBlueprint) {
        guard activeEarned == nil else { return }
        let accountID = AuthManager.shared.currentAccountID
        guard let earned = V46EarnedTodayPresentation.make(
            outcomes: recommendationLearningStore.outcomes,
            suggestedNextDifficulty: blueprint.suggestedTimedDifficulty,
            acknowledgedOutcomeIDs: V46EarnedEvidenceLedger.acknowledgedIDs(accountID: accountID)
        ) else { return }
        withAnimation(reduceMotion ? .v46ReduceMotionFade : .payoffReveal) {
            activeEarned = earned
        }
        V46EarnedEvidenceLedger.acknowledge(earned.outcomeID, accountID: accountID)
        CoachHaptic.earnedEvidence()
    }

    /// One-shot entrance: the headline block settles immediately and the CTA
    /// follows one beat later. Guarded on the settled flag so pop-returns to the
    /// retained Home never replay it; a cold remount starts fresh @State
    /// and plays again. Reduce Motion: instant appear, no animation.
    private func playEntranceChoreography() {
        guard !heroTextSettled else { return }
        guard !reduceMotion else {
            heroTextSettled = true
            heroCTASettled = true
            return
        }
        withAnimation(.settle) { heroTextSettled = true }
        withAnimation(.settle.delay(HeroEntranceBeat.ctaDelay)) { heroCTASettled = true }
    }

    // MARK: - Hero meta line
    //
    // "Timed practice · 30s answer clock · Week 2 of 4" — every clause is
    // real, sentence case, and self-suppresses when its datum is absent
    // (the V4.6 clause rule: never render placeholder metadata).

    private func heroMetaText(for blueprint: RecommendationBiasBlueprint) -> String {
        var clauses = [heroModeClause(for: blueprint.recommendedMode)]
        if let clock = heroClockClause(for: blueprint) {
            clauses.append(clock)
        }
        if let week = heroPlanWeekClause {
            clauses.append(week)
        }
        return clauses.joined(separator: " \u{00B7} ")
    }

    private func heroModeClause(for mode: PracticeMode) -> String {
        switch mode {
        case .timed:          return "Timed practice"
        case .suddenDeath:    return "Pressure drill"
        case .ahCounter:      return "Filler control"
        case .imConversation: return "Conversation practice"
        }
    }

    private func heroClockClause(for blueprint: RecommendationBiasBlueprint) -> String? {
        switch blueprint.recommendedMode {
        case .timed:
            let difficulty = blueprint.suggestedTimedDifficulty ?? .medium
            guard let seconds = difficulty.duration else { return "free clock" }
            return "\(seconds)s answer clock"
        case .suddenDeath:    return "one breath"
        case .ahCounter:      return "90s rep"
        case .imConversation: return nil
        }
    }

    /// "Week N of 4" only while the active plan is live and aligned — a
    /// stale or absent plan renders nothing rather than a wrong claim.
    private var heroPlanWeekClause: String? {
        let state = CoachingPlanCardVisibility.resolve(
            plan: forwardPlanStore.activePlan,
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            activeBigMomentID: bigMomentStore.activeMoment?.id
        )
        guard case .live(let plan, _) = state,
              let week = plan.currentWeek(now: Date(), calendar: .current) else {
            return nil
        }
        return "Week \(week.weekIndex) of 4"
    }

    /// Compact 4-week plan-arc line under the Begin CTA — today's rep
    /// read as a step inside the visible program ("Week 2 of 4 — pauses").
    /// Reuses the exact tap contract of Profile's `CoachingPlanCard`:
    /// live → open the coach thread (the full plan lives there as a
    /// coach turn); stale → regenerate around the changed moment, then
    /// open the thread. Quiet register on purpose: one line, no box —
    /// the hero keeps one primary action.
    @ViewBuilder
    private var planArcRow: some View {
        let state = CoachingPlanCardVisibility.resolve(
            plan: forwardPlanStore.activePlan,
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            activeBigMomentID: bigMomentStore.activeMoment?.id
        )
        if let plannedPhrase = currentPlannedPhrase {
            Button {
                startPlannedPhrase(plannedPhrase)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColor.coachingInkOnQuiet)
                        .accessibilityHidden(true)
                    Text("Week \(plannedPhrase.target.weekIndex) phrase \u{2014} practice your saved line")
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColor.textTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    AppColor.innerSurface,
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(
                Text("Week \(plannedPhrase.target.weekIndex) of your plan. Practice your saved phrase in Timed Practice.")
            )
            .accessibilityIdentifier("home.coachCard.planPhrase")
        } else if let line = HomePlanArcLine.line(
            state: state,
            voice: coachingProfileStore.profile?.chosenStyleGoal
        ) {
            Button {
                if case .stale = state {
                    // Same contract as Profile's stale card: redraft
                    // around the new moment, then land in the thread
                    // where the fresh plan arrives as a coach turn.
                    Task { await ForwardPlanCoordinator.generateAndAnnounce() }
                }
                navigationPath.append(AppDestination.askNoum)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColor.coachingInkOnQuiet)
                        .accessibilityHidden(true)
                    Text(line)
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColor.textTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    AppColor.innerSurface,
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text("Your four-week plan. \(line). Opens the coach thread."))
            .accessibilityIdentifier("home.coachCard.planArc")
        }
    }

    private var currentPlannedPhrase: ForwardPlanPhraseProjection? {
        let currentPlan = forwardPlanStore.currentPlan(
            activeBigMomentID: bigMomentStore.activeMoment?.id,
            chosenStyleGoal: coachingProfileStore.profile?.chosenStyleGoal
        )
        return ForwardPlanPhraseProjection.resolve(
            plan: currentPlan,
            entries: phraseBankStore.entries
        )
    }

    private func startPlannedPhrase(_ projection: ForwardPlanPhraseProjection) {
        let livePlan = forwardPlanStore.currentPlan(
            activeBigMomentID: bigMomentStore.activeMoment?.id,
            chosenStyleGoal: coachingProfileStore.profile?.chosenStyleGoal
        )
        guard let liveProjection = ForwardPlanPhraseProjection.resolve(
            plan: livePlan,
            entries: phraseBankStore.entries
        ),
        liveProjection.target == projection.target,
        liveProjection.entry.id == projection.entry.id,
        let token = TimedPracticePromptHandoff.shared.offerToken(
            liveProjection.practiceIntent.suggestedPrompt
        ) else {
            plannedPhraseError = "Your plan or saved phrase changed. Choose it again from your Phrase bank."
            return
        }
        CoachHaptic.drillStart()
        navigationPath.append(AppDestination.timedPracticePrompt(token: token))
    }

    /// True when the current path node is honestly one step from unlocked.
    ///
    /// Two-arm predicate — uses public state only:
    ///   1. Gating phrase begins with "One " (covers "One rep / day / crown /
    ///      ... from unlocked.") AND progress > 0 — the AND clause filters
    ///      out boolean-trigger criteria like `.zeroFillerSession` whose
    ///      copy *always* starts with "One" but where the user hasn't yet
    ///      attempted the action.
    ///   2. Live progress ≥ 0.80 — covers numeric thresholds whose "1 away"
    ///      math doesn't render as "One " (e.g. score 7→8, rating +20).
    ///
    /// Silent in the cleared-path state. The variant is never invented when
    /// the user is genuinely far from the next bar — restraint over
    /// coverage. Re-reads on every recompute via the @StateObject binding.
    private var landmarkWithinReach: Bool {
        guard let status = pathProgress.currentNode, !status.isComplete else {
            return false
        }
        if status.progress >= 0.80 {
            return true
        }
        if status.progress > 0,
           let phrase = pathProgress.currentNodeGatingPhrase,
           phrase.hasPrefix("One ") {
            return true
        }
        return false
    }

    private var microLabelText: String {
        let modeText = modeMicroLabel(for: recommendedMode)
        let timeText = sessionTimeMicroLabel(for: recommendedMode)
        let targetText = (recommendationBlueprint.target.isEmpty ? "Clean rep" : recommendationBlueprint.target).uppercased()
        return [modeText, timeText, targetText]
            .filter { !$0.isEmpty }
            .joined(separator: " \u{00B7} ")
    }

    private func modeMicroLabel(for mode: PracticeMode) -> String {
        switch mode {
        case .timed:          return "TIMED PRACTICE"
        case .suddenDeath:    return "PRESSURE DRILL"
        case .ahCounter:      return "FILLER CONTROL"
        case .imConversation: return "CONVERSATION PRACTICE"
        }
    }

    /// Rough per-mode time hint shown in the micro-label. These are
    /// surface labels only — the practice view owns the actual timer.
    private func sessionTimeMicroLabel(for mode: PracticeMode) -> String {
        switch mode {
        case .timed:
            if let difficulty = recommendationBlueprint.suggestedTimedDifficulty {
                switch difficulty {
                case .free:   return "FREE"
                case .easy:   return "60 SEC"
                case .medium: return "30 SEC"
                case .hard:   return "15 SEC"
                }
            }
            return "30 SEC"
        case .suddenDeath:    return "ONE BREATH"
        case .ahCounter:      return "90 SEC"
        case .imConversation: return "LIVE CHAT"
        }
    }

    // MARK: - Action

    private func beginRecommendedRep(
        renderedExposure: HomeCoachRecommendationExposure
    ) {
        // Commitment haptic (A2 register map): the user just committed
        // to a rep — the single most consequential tap in the product.
        CoachHaptic.drillStart()
        let exposure = lastRenderedRecommendationExposure?.fingerprint
            == renderedExposure.fingerprint
            ? lastRenderedRecommendationExposure ?? renderedExposure
            : renderedExposure
        let liveAvailability = RecommendationTapCapabilityLossUITestFixture
            .availabilityAtTap(currentModeAvailability)
        let liveIMAvailability = RecommendationTapCapabilityLossUITestFixture
            .imAvailableAtTap(IMModeAvailability.isAvailable)
        let launch = HomeCoachRecommendationPipeline.accept(
            exposure,
            modeAvailability: liveAvailability,
            imAvailable: liveIMAvailability,
            goal: coachingProfileStore.profile?.chosenStyleGoal,
            store: recommendationLearningStore
        )
        // A user who backed out of Day-0's prepared proof still has no usable
        // signal. Their generic Home baseline CTA is an explicit new tap, so
        // it may reseed the same framing prompt; it never arms Quick Start or
        // opens the microphone. Once a qualifying persisted rep closes the
        // handoff, ordinary recommendation routing resumes permanently.
        if !hasSignal,
           launch.launchedMode == .timed,
           let preparation = AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(),
           let token = preparation.promptToken {
            commitWithHandoff {
                navigationPath.append(
                    AppDestination.timedPracticePrompt(
                        token: token,
                        difficulty: .medium
                    )
                )
            }
        } else {
            // V4.6 — the hero IS the briefing (target, reason, clock), so
            // Start lands directly in the rep flow. Same one-shot arming
            // contract as the picker/Ask Noum tap launches. A capability
            // fallback must NOT re-arm: `accept` just cleared the handshake
            // because the mode that opens is not the mode the user saw, and
            // an unseen mode auto-starting the microphone is exactly the
            // interrupted-one-tap leak the other surfaces fail closed on.
            let exactIntentArmed: Bool
            if launch.acceptsDisplayedPrescription,
               launch.launchedMode == exposure.mode,
               let intent = exposure.quickStartIntent() {
                // Timed capture consumes the exact target and demand; the other
                // mode views consume the same gate without retaining it for a
                // later tab.
                exactIntentArmed = PracticeModeQuickStart.arm(intent: intent)
            } else {
                exactIntentArmed = false
            }
            if !exactIntentArmed {
                PracticeModeQuickStart.clear()
            }
            commitWithHandoff {
                navigationPath.append(launch.destination)
            }
        }
    }

    /// Moment A commit continuity: every business mutation has already run
    /// by the time this is called — only the navigation push rides the
    /// 180ms handoff beat while the waveform lifts. Reduce Motion pushes
    /// immediately with no beat.
    private func commitWithHandoff(_ push: @escaping () -> Void) {
        guard !reduceMotion else {
            push()
            return
        }
        withAnimation(NoumMotion.screenContinuation) { heroHandoff = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(HeroEntranceBeat.handoff * 1_000_000_000))
            push()
        }
    }

    // NOTE: the former mood lifecycle (`isBursting`/`restingMood`/
    // `displayedMood`) was deleted, not rewired. It drove an illustration
    // this hero no longer renders, and its burst fired on fingerprint
    // changes that happen almost exclusively while Home is off-screen
    // (post-rep, retained tab root) — a beat that would never be seen.
    // Dead state either way; deletion is the honest, smaller change.

    // MARK: - Derived state

    private var hasSignal: Bool {
        sessionStore.progressEligibleSessionCount > 0
    }

    private var recommendedMode: PracticeMode {
        recommendationExposure.mode
    }

    private var sessionStreak: Int {
        streakFreeze.currentStreak
    }

    // MARK: - Recommendation blueprint

    private var recommendationBlueprint: RecommendationBiasBlueprint {
        currentModeAvailability.resolving(coherentRecommendationBlueprint)
    }

    private var coherentRecommendationBlueprint: RecommendationBiasBlueprint {
        HomeCoachRecommendationPipeline.coherentBlueprint(
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            sessionStreak: sessionStreak,
            daysSinceLastSession: daysSinceLastSession,
            coachMemory: coachMemoryStore.currentMemory,
            imAvailable: IMModeAvailability.isAvailable,
            recommendationOutcomes: recommendationLearningStore.outcomes,
            skillTrends: skillTrendStore.snapshots
        )
    }

    private var currentModeAvailability: NextActionModeAvailability {
        NextActionModeAvailability(
            rating: ratingStore.rating,
            imConversationAvailable: IMModeAvailability.isAvailable
        )
    }

    private var recommendationExposure: HomeCoachRecommendationExposure {
        let blueprint = recommendationBlueprint
        return recommendationExposure(for: blueprint)
    }

    private func recommendationExposure(
        for blueprint: RecommendationBiasBlueprint
    ) -> HomeCoachRecommendationExposure {
        HomeCoachRecommendationPipeline.exposure(
            for: blueprint,
            title: coachTitle(for: blueprint),
            profile: coachingProfileStore.profile,
            recentSessions: sessionStore.progressEligibleSessions
        )
    }

    private func recordRecommendationShown(
        _ exposure: HomeCoachRecommendationExposure
    ) {
        HomeCoachRecommendationPipeline.recordShown(
            exposure,
            goal: coachingProfileStore.profile?.chosenStyleGoal,
            store: recommendationLearningStore
        )
    }

    // MARK: - Momentum helpers (inline, pure)

    /// Consecutive recent reps with fillers at or below half the baseline.
    /// Mirrors `MomentumComputer.consecutiveCleanReps` but computed
    /// inline from the live stores so HomeCoachCard doesn't need a
    /// separate momentum snapshot.
    private var consecutiveCleanReps: Int {
        let baseline = BaselineStore.shared.baseline
        guard baseline.fillerRate.confidence != .insufficient,
              let baseRate = Optional(baseline.fillerRate.value),
              baseRate > 0 else { return 0 }
        return MomentumComputer.consecutiveCleanReps(
            sorted: sessionStore.progressEligibleSessions,
            baselineFillerRate: baseRate
        )
    }

    /// The most credible recurring-position read across the recent rep window,
    /// or nil when no positional habit has cleared `RepEventTrendEngine`'s
    /// honesty floors (>=3 reps carried the event AND one zone holds a >=60%
    /// super-majority). Pure — recomputed from the live session store, no new
    /// persistence. `compute` returns trends in a fixed kind order (rushed →
    /// pause → filler), so `.first` deterministically prefers the most
    /// actionable pace read when several patterns co-exist.
    private var positionalTrend: RepEventTrend? {
        RepEventTrendEngine.compute(sessions: sessionStore.progressEligibleSessions).first
    }

    /// Reps completed in the current ISO week.
    private var weeklyRepCount: Int {
        let cal = Calendar.current
        let now = Date()
        let currentWeek = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return sessionStore.progressEligibleSessions.filter { session in
            let w = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date)
            return w.yearForWeekOfYear == currentWeek.yearForWeekOfYear
                && w.weekOfYear == currentWeek.weekOfYear
        }.count
    }

    private var daysSinceLastSession: Int {
        guard let latest = sessionStore.progressEligibleSessions.first else { return 0 }
        return Calendar.current.dateComponents([.day], from: latest.date, to: Date()).day ?? 0
    }

}

/// Entrance settle for the hero's blocks (V4.6.1): starts at 0.97 scale /
/// 0.85 opacity — visible from the first frame, never invisible — and
/// settles to identity. The driving state change carries the motion token
/// (`.settle`); Reduce Motion sets the flags without animation, so the
/// blocks simply appear settled.
private extension View {
    func heroEntrance(settled: Bool) -> some View {
        scaleEffect(settled ? 1 : 0.97)
            .opacity(settled ? 1 : 0.85)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 12.0, *)
#Preview("Coach Card — Populated") {
    ScrollView {
        VStack(spacing: Spacing.cardGap) {
            HomeCoachCard(
                navigationPath: .constant(NavigationPath()),
                completedRepsToday: 1,
                targetRepsToday: 3
            )
        }
    }
    .background(AppColor.screenBackground.ignoresSafeArea())
}

#Preview("Coach Card — Dark Accessibility") {
    ScrollView {
        HomeCoachCard(
            navigationPath: .constant(NavigationPath()),
            completedRepsToday: 2,
            targetRepsToday: 3
        )
    }
    .background(AppColor.screenBackground.ignoresSafeArea())
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
#endif

#endif
