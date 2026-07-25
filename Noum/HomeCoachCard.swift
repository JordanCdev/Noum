#if canImport(SwiftUI)
import SwiftUI

enum HomeMomentCopy {
    static func title(momentTitle: String, days: Int) -> String {
        "\(momentTitle) · \(days) day\(days == 1 ? "" : "s")"
    }
}

// MARK: - Home Coach Card (M14)
//
// One composed hero that replaces the populated home's split greeting
// (heroCard) + suggestion (quickStartCard). The product shift is from
// "dashboard of tiles" to "a coach speaking to you on open" — the
// character is present, the coach's recommendation is the primary copy,
// and a single Begin CTA carries the user into the right rep.
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
            blueprint.focus,
            blueprint.target,
            recent
        ].joined(separator: "|")
        return HomeCoachRecommendationExposure(
            fingerprint: fingerprint,
            title: title,
            focus: blueprint.focus,
            target: blueprint.target,
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
        if exposure.mode == .timed, launch.launchedMode == .timed {
            let theme = exposure.suggestedTheme
            if theme != .all {
                UserDefaults.standard.set(
                    theme.rawValue,
                    forKey: "timedPractice.selectedTheme"
                )
            }
        }
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

    /// Gate flag from `HomeSignalGate` (>= 1 completed rep). The row
    /// additionally self-gates on an actual active plan via
    /// `HomePlanArcLine` — both must hold before anything renders.
    var showsPlanArc: Bool = false
    /// Retained for source compatibility. Both presentations now use the same
    /// compact card language; Home no longer turns the coach surface into an
    /// immersive canvas.
    var presentation: HomeCoachPresentation = .card
    /// False while Home is only the retained routing root behind another
    /// recommendation surface. The delayed dwell task is cancelled before it
    /// can replace that surface's current exact ledger exposure.
    var recordsRecommendationExposure: Bool = true
    /// Top safe-area inset measured by the host — the V4.6 hero bleeds
    /// behind the status bar, so its content pads down by this amount.
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

    /// True while a fresh-recommendation burst is showing the `.excited`
    /// mood. The displayed mood otherwise reads from `restingMood` so the
    /// computed `hasSignal` value drives the empty/populated mood
    /// directly — no first-paint flash where a stale `@State` default
    /// disagrees with the actual state for a frame.
    @State private var isBursting: Bool = false
    @State private var lastSeenRecommendationKey: String = ""
    @State private var lastRenderedRecommendationExposure: HomeCoachRecommendationExposure?
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
        // V4.6 Today hero (Figma 258:934) — the app's single marquee
        // gradient. Structure: eyebrow → one target headline → one reason →
        // practice meta → idle voice trace → one dominant Start. All copy
        // still flows from the existing recommendation pipeline; only the
        // presentation changed.
        return VStack(alignment: .leading, spacing: 0) {
            Text("Today")
                .font(Typography.figtree(size: 15, weight: .heavy, relativeTo: .subheadline))
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityAddTraits(.isHeader)

            // V4.6 Updated Today (258:1078) — the earned chip announces one
            // un-acknowledged retry-comparison win; the hero's structure
            // tightens to chip → headline → meta → earned trace → CTA.
            if let earned = activeEarned {
                earnedChip(earned.chipText)
                    .padding(.top, Spacing.sm)
            }

            Text(activeEarned?.headlineOverride ?? coachTitle(for: renderedBlueprint))
                .font(Typography.figtree(size: 31, weight: .heavy, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, activeEarned == nil ? Spacing.lg : Spacing.sm)
                .accessibilityIdentifier("home.coachCard.title")

            if activeEarned == nil, let subtitle = coachSubtitle(for: renderedBlueprint) {
                Text(subtitle)
                    .font(Typography.manrope(size: 15.5, weight: .regular, relativeTo: .subheadline))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.md)
                    .accessibilityIdentifier("home.coachCard.subtitle")
            }

            Text(activeEarned?.metaOverride ?? heroMetaText(for: renderedBlueprint))
                .font(Typography.monoDigit(Typography.manrope(size: 13.5, weight: .semibold, relativeTo: .footnote)))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.lg)

            VoiceTrace(variant: activeEarned == nil ? .idleHero : .earnedHero)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.lg)

            heroActions(renderedExposure: renderedExposure)
                .padding(.top, Spacing.lg)

            // The cohesive Home intentionally suppresses the generic plan arc,
            // but an explicitly saved line is a concrete current-week action,
            // not extra dashboard furniture. Let that one bounded handoff
            // surface without reopening the broader plan row.
            if showsPlanArc || currentPlannedPhrase != nil {
                planArcRow
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, heroTopInset + Spacing.sm)
        .padding(.bottom, Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    bottomLeading: CornerRadius.hero,
                    bottomTrailing: CornerRadius.hero
                ),
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [AppColor.heroGradientStart, AppColor.heroGradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // Bleed generously above the content top so no canvas sliver can
            // show between the hero and the physical top edge — even on a
            // hard rubber-band pull. Background only, clipped by the
            // ScrollView at rest, so layout is unaffected.
            .padding(.top, -240)
            .shadow(color: AppColor.coachAccent.opacity(0.28), radius: 22, y: 14)
        }
        .onAppear {
            lastRenderedRecommendationExposure = renderedExposure
            syncMoodForFreshRecommendation()
            resolveEarnedState(for: renderedBlueprint)
        }
        .onChange(of: renderedExposure.fingerprint) { _, _ in
            lastRenderedRecommendationExposure = renderedExposure
            syncMoodForFreshRecommendation()
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

    /// Label for the primary CTA. Keep it verb-led and natural rather than
    /// joining implementation labels with punctuation.
    private func beginCTAText(for mode: PracticeMode) -> String {
        // No-signal (empty-state, brand-new user): name the moment, not
        // the mode. This is the simplest door into the product.
        guard hasSignal else {
            return "Start your first rep"
        }
        return "Start \(mode.displayLabel)"
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
            return "Three focused reps before the real conversation."
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
            return "Three reps and Noum starts finding your weakest line."
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
        renderedExposure: HomeCoachRecommendationExposure
    ) -> some View {
        if let moment = bigMomentStore.activeMoment,
           let days = bigMomentStore.daysUntil(moment),
           days >= 0 && days <= 14 {
            VStack(spacing: Spacing.xs) {
                ImmersiveCTA(title: "Continue prep") {
                    navigationPath.append(AppDestination.prepSession)
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
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("home.coachCard.begin")
            }
        } else {
            ImmersiveCTA(
                title: activeEarned?.ctaOverride ?? beginCTAText(for: renderedExposure.mode)
            ) {
                beginRecommendedRep(renderedExposure: renderedExposure)
            }
            .accessibilityIdentifier("home.coachCard.begin")
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
                .font(Typography.figtree(size: 10.5, weight: .heavy, relativeTo: .caption2))
                .tracking(0.6)
                .foregroundStyle(.white)
        }
        .padding(.leading, 10)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.16), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("New evidence, from your retry"))
        .accessibilityIdentifier("home.coachCard.earnedChip")
    }

    /// Resolve the once-per-event earned announcement. Acknowledging on
    /// first render is what enforces "shown once, then collapsed" — the
    /// @State copy keeps this visit stable while the ledger moves on.
    private func resolveEarnedState(for blueprint: RecommendationBiasBlueprint) {
        guard activeEarned == nil else { return }
        let accountID = AuthManager.shared.currentAccountID
        guard let earned = V46EarnedTodayPresentation.make(
            outcomes: recommendationLearningStore.outcomes,
            suggestedNextDifficulty: blueprint.suggestedTimedDifficulty,
            acknowledgedOutcomeIDs: V46EarnedEvidenceLedger.acknowledgedIDs(accountID: accountID)
        ) else { return }
        activeEarned = earned
        V46EarnedEvidenceLedger.acknowledge(earned.outcomeID, accountID: accountID)
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
                        .foregroundStyle(Color.white.opacity(0.9))
                        .accessibilityHidden(true)
                    Text("Week \(plannedPhrase.target.weekIndex) phrase \u{2014} practice your saved line")
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                        .foregroundStyle(Color.white.opacity(0.9))
                        .accessibilityHidden(true)
                    Text(line)
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
            navigationPath.append(
                AppDestination.timedPracticePrompt(
                    token: token,
                    difficulty: .medium
                )
            )
        } else {
            // V4.6 — the hero IS the briefing (target, reason, clock), so
            // Start lands directly in the rep flow. Same one-shot arming
            // contract as the picker/Ask Noum tap launches.
            PracticeModeQuickStart.arm(for: launch.launchedMode)
            navigationPath.append(launch.destination)
        }
    }

    // MARK: - Mood lifecycle
    //
    // The character defaults to `restingMood` — `.coaching` (slight tilt,
    // "the coach has something to say") for the populated state, or
    // `.listening` (symmetric arc-pulses, "the coach is hearing you for
    // the first time") for the empty state. When the active recommendation
    // changes (e.g. after a finalize that produces a new suggested mode),
    // brief `.excited` for ~1s then settle back to the resting mood.
    // Reduce-motion users skip the burst entirely.

    private var recommendationKey: String {
        recommendationExposure.fingerprint
    }

    /// Base mood the card rests in when no fresh-recommendation burst is
    /// firing. Empty-state (no signal) reads `.listening` — symmetric arc-
    /// pulses around the character, framing "the coach is hearing you for
    /// the first time". Once the user has reps, the mood settles into
    /// `.coaching` — the slight tilt that frames "the coach has something
    /// to say." Two registers, honest to the moment.
    private var restingMood: NoumCharacter.Mood {
        hasSignal ? .coaching : .listening
    }

    /// Mood actually rendered on the character. Derives live from
    /// `restingMood` unless an `.excited` burst is active — so a cold-
    /// start empty-state user sees `.listening` from frame zero, no
    /// `@State` default ever flashing through.
    private var displayedMood: NoumCharacter.Mood {
        isBursting ? .excited : restingMood
    }

    private func syncMoodForFreshRecommendation() {
        let key = recommendationKey
        defer { lastSeenRecommendationKey = key }
        guard !reduceMotion else { return }
        // Only burst on a real change, not on first appear (first appear
        // already has the character's onAppear entrance animation).
        guard !lastSeenRecommendationKey.isEmpty, lastSeenRecommendationKey != key else {
            return
        }
        isBursting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isBursting = false
        }
    }

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

#if DEBUG
@available(iOS 17.0, macOS 12.0, *)
#Preview("Coach Card — Populated") {
    ScrollView {
        VStack(spacing: Spacing.cardGap) {
            HomeCoachCard(navigationPath: .constant(NavigationPath()))
        }
        .padding(.horizontal, Spacing.screenH)
    }
    .background(AppColor.screenBackground.ignoresSafeArea())
}
#endif

#endif
