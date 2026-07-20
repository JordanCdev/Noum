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

    /// Live scroll offset from the parent ScrollView, passed in from
    /// ContentView's `homeScrollOffset`. Drives a barely-there interior
    /// parallax on the radial-wash anchors — the card itself never
    /// moves. Default `0` keeps preview + non-scroll call sites
    /// compiling unchanged. Pinned to zero under reduce-motion.
    var scrollOffset: CGFloat = 0
    /// Gate flag from `HomeSignalGate` (>= 1 completed rep). The row
    /// additionally self-gates on an actual active plan via
    /// `HomePlanArcLine` — both must hold before anything renders.
    var showsPlanArc: Bool = false
    /// Home uses the coach gradient as the entire canvas. The legacy card
    /// presentation remains available for previews and any embedded caller.
    var presentation: HomeCoachPresentation = .card

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

    // Emanation ray — a brief tinted pulse that fires from behind the
    // character when a fresh recommendation arrives.
    //
    // `emanationProgress` runs 0.0 → 1.0 across the 700ms pulse:
    //   • 0.0 (just fired):  opacity 0.5, scale 1.0  → ring visible at the character's size
    //   • 1.0 (resting):     opacity 0.0, scale 1.6  → fully faded out, expanded
    // At rest the value sits at 1.0 so the ray is invisible. Each
    // trigger snaps it back to 0.0 (no animation) then animates to 1.0
    // with ease-out — the classic radial-pulse shape.
    @State private var emanationProgress: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isSelectedAppTab) private var isSelectedAppTab

    var body: some View {
        _ = aiSettings.cloudProcessingConsent
        let renderedAvailability = currentModeAvailability
        let sourceBlueprint = RecommendationTapCapabilityLossUITestFixture
            .blueprintForRendering(coherentRecommendationBlueprint)
        let renderedBlueprint = renderedAvailability.resolving(sourceBlueprint)
        let renderedExposure = recommendationExposure(for: renderedBlueprint)
        return VStack(spacing: presentation == .immersive ? Spacing.md : Spacing.xs) {
            ZStack {
                emanationRay
                NoumCharacter(
                    mood: displayedMood,
                    tint: .white,
                    size: presentation == .immersive ? 88 : 64
                )
                .accessibilityHidden(true)
            }

            // Title — punchy, 1-3 words usually. Drives the visual
            // hierarchy. The earlier "one long coach sentence" pattern
            // read as a paragraph; this reads as a coach speaking.
            Text(coachTitle(for: renderedBlueprint))
                .font(Typography.figtree(
                    size: presentation == .immersive ? 34 : 22,
                    weight: .bold,
                    relativeTo: presentation == .immersive ? .largeTitle : .title2
                ))
                .foregroundStyle(AppColor.coachHeroInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.xs)
                .accessibilityIdentifier("home.coachCard.title")

            // Subtitle — the why, in body weight, secondary. Conditional —
            // hides cleanly when the variant only carries a title.
            if let subtitle = coachSubtitle(for: renderedBlueprint) {
                Text(subtitle)
                    .font(presentation == .immersive
                        ? Typography.manrope(size: 19, weight: .medium, relativeTo: .title3)
                        : Typography.body)
                    .foregroundStyle(AppColor.coachHeroInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.sm)
                    .accessibilityIdentifier("home.coachCard.subtitle")
            }

            VoiceAlignmentChip(
                styleGoal: coachingProfileStore.profile?.chosenStyleGoal,
                mode: renderedExposure.mode,
                tint: AppColor.coachHeroInk
            )
            .padding(.top, Spacing.xs)

            // M23 — Prep Session entry. Surfaces when the user has an
            // active BigMoment within 14 days. Sits ABOVE the Begin
            // button so the prep CTA reads as the higher-priority next
            // action — "your moment is close, this is what the coach
            // would have you do." Standard mode rep stays as the
            // secondary action below.
            if let moment = bigMomentStore.activeMoment,
               let days = bigMomentStore.daysUntil(moment),
               days >= 0 && days <= 14 {
                prepSessionCTA(moment: moment, days: days)
                Button {
                    beginRecommendedRep(renderedExposure: renderedExposure)
                } label: {
                    Text("Start \(renderedExposure.mode.displayLabel) instead")
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(AppColor.coachHeroInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppColor.coachHeroQuietSurface, in: Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.coachCard.begin")
            } else {
                PrimaryCTA(beginCTAText(for: renderedExposure.mode), tint: .white, labelTint: AppColor.coachHeroInk) {
                    beginRecommendedRep(renderedExposure: renderedExposure)
                }
                .accessibilityIdentifier("home.coachCard.begin")
            }

            // The cohesive Home intentionally suppresses the generic plan arc,
            // but an explicitly saved line is a concrete current-week action,
            // not extra dashboard furniture. Let that one bounded handoff
            // surface without reopening the broader plan row.
            if showsPlanArc || currentPlannedPhrase != nil {
                planArcRow
            }
        }
        .padding(.horizontal, presentation == .immersive ? Spacing.lg + Spacing.xs : Spacing.md)
        .padding(.vertical, presentation == .immersive ? Spacing.lg + Spacing.xs : Spacing.md)
        .frame(maxWidth: .infinity)
        .background {
            if presentation == .card {
                coachCardBackground
            }
        }
        // Tinted elevation in the hero's own gradient family — the ONE
        // vibrant surface on Home (docs/UX_VISUAL_DIRECTION.md).
        .shadow(
            color: presentation == .card ? HeroGradient.coach.shadowTint.opacity(0.32) : .clear,
            radius: 22,
            x: 0,
            y: 10
        )
        .onAppear {
            lastRenderedRecommendationExposure = renderedExposure
            syncMoodForFreshRecommendation()
        }
        .onChange(of: renderedExposure.fingerprint) { _, _ in
            lastRenderedRecommendationExposure = renderedExposure
            syncMoodForFreshRecommendation()
        }
        .task(id: "\(renderedExposure.fingerprint)|\(isSelectedAppTab)") {
            // A cold deep link briefly mounts Home before AppShell selects the
            // destination tab. Require a small, cancellable visibility dwell
            // so that transient mount is not counted as a shown prescription.
            // The tap path still records synchronously (and idempotently), so
            // a legitimate fast tap cannot lose its exposure event.
            guard isSelectedAppTab else { return }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, isSelectedAppTab else { return }
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
    /// Maps live scroll offset (±120pt) to a ±5pt opposite-direction
    /// gradient shift. Capped + zeroed under reduce-motion. The card
    /// itself doesn't move — only the interior wash anchors do.
    private var parallaxAmount: CGFloat {
        guard !reduceMotion else { return 0 }
        let normalized = max(-1, min(1, scrollOffset / 120))
        return -normalized * 5
    }

    private func beginCTAText(for mode: PracticeMode) -> String {
        // No-signal (empty-state, brand-new user): name the moment, not
        // the mode. This is the simplest door into the product.
        guard hasSignal else {
            return "Start your first rep"
        }
        return "Start \(mode.displayLabel)"
    }

    /// Hero card chrome — replaces the standard `CardView` so the Coach
    /// Card carries visual depth + a brand-tinted presence. The card now
    /// reads as an "alive" iOS-26 hero rather than a tinted gradient:
    /// the radial Pro-purple wash drifts slowly across the top, and a
    /// `.regularMaterial` layer sits between the wash and the content so
    /// the tint reads through frosted glass (the Apple Music / Fitness /
    /// Sleep app pattern).
    ///
    /// Layers, bottom to top:
    ///   1. White card surface (the canvas).
    ///   2. Top-anchored radial purple wash with a slow drifting center
    ///      — `(0.35, 0.0)` ↔ `(0.65, 0.15)` on a ~7s ease-in-out loop.
    ///      Reduce-motion collapses this to a static center at `(0.5, 0.0)`
    ///      so nothing animates.
    ///   3. Trailing-anchored low-alpha mode-tint accent — keeps the
    ///      "this is your recommendation" register.
    ///   4. `.regularMaterial` frosted-glass overlay — desaturates the
    ///      washes underneath without erasing them, giving the card the
    ///      iOS-26 depth feel. Clipped to the card shape.
    ///   5. Faint purple hairline border on top of the glass so the
    ///      silhouette stays crisp.
    /// Outer `.shadow` (applied by `body`) adds elevation in Pro-purple.
    @ViewBuilder
    private var coachCardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        let dy = parallaxAmount
        ZStack {
            // The ONE vibrant surface on Home — the approved blue→cyan
            // coach gradient (docs/UX_VISUAL_DIRECTION.md).
            shape.fill(HeroGradient.coach.gradient)

            // Drifting white highlight wash — keeps the "card breathes"
            // quality on the gradient. Shifts by `dy` opposite the scroll
            // direction (barely-there interior parallax); clipped so the
            // offset gradient never escapes the silhouette.
            highlightWash(in: shape)
                .offset(y: dy)
                .clipShape(shape)

            // White hairline keeps the silhouette crisp on the canvas.
            shape.strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
    }

    /// White highlight wash with optional slow drift across the top of
    /// the gradient hero. The TimelineView path samples the system
    /// animation clock so the gradient redraws smoothly; reduce-motion
    /// renders a single static highlight.
    @ViewBuilder
    private func highlightWash<S: Shape>(in shape: S) -> some View {
        if reduceMotion {
            shape.fill(
                RadialGradient(
                    colors: [.white.opacity(0.20), .white.opacity(0.05), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 340
                )
            )
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                // 7s ease-in-out loop — "this card breathes," not
                // "this card animates."
                let phase = (sin(t * (2 * .pi / 7.0)) + 1) / 2
                let centerX = 0.35 + 0.30 * phase
                let centerY = 0.0 + 0.15 * phase
                shape.fill(
                    RadialGradient(
                        colors: [.white.opacity(0.20), .white.opacity(0.05), Color.clear],
                        center: UnitPoint(x: centerX, y: centerY),
                        startRadius: 0,
                        endRadius: 340
                    )
                )
            }
        }
    }

    /// Soft mode-tinted radial pulse that emanates from behind the
    /// character when a fresh recommendation arrives. The pulse
    /// progresses from `progress=0.0` (just fired: opacity 0.5,
    /// scale 1.0) to `progress=1.0` (resting: opacity 0.0, scale 1.6)
    /// over ~700ms via `withAnimation`. Reduce-motion users see no ray.
    @ViewBuilder
    private var emanationRay: some View {
        if reduceMotion {
            Color.clear
                .frame(width: 1, height: 1)
        } else {
            let scale = 1.0 + 0.6 * emanationProgress
            let opacity = 0.5 * (1.0 - emanationProgress)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentTint.opacity(0.45), accentTint.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(scale)
                .opacity(opacity)
                .allowsHitTesting(false)
        }
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
        guard hasSignal else {
            return "Welcome."
        }

        if sessionStore.progressEligibleSessionCount < 3 {
            return "Start clean."
        }

        if let moment = bigMomentStore.activeMoment,
           let days = bigMomentStore.daysUntil(moment),
           days >= 0 && days <= 14 {
            return HomeMomentCopy.title(momentTitle: moment.title, days: days)
        }

        let focus = CoachDisplayCopy.normalized(blueprint.focus)
        if !focus.isEmpty {
            // Ensure punctuation closure — title reads as a complete
            // imperative, not a fragment trailing into the subtitle.
            let trimmed = focus.trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
            return "\(trimmed)."
        }

        return "Build a clean rep."
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

    /// M23 — Prep Session CTA. Brand-purple secondary action surfaced
    /// in the coach card hero when an active BigMoment is within 14
    /// days. Tapping pushes `AppDestination.prepSession`, where the
    /// PrepSessionPlanner assembles a 3-rep rehearsal sequence
    /// tailored to the moment's category.
    @ViewBuilder
    private func prepSessionCTA(moment: BigMoment, days: Int) -> some View {
        Button {
            navigationPath.append(AppDestination.prepSession)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: moment.category.sfSymbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.coachHeroInk)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Continue prep")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.coachHeroInk)
                    Text("Three focused reps")
                        .font(.caption)
                        .foregroundStyle(AppColor.coachHeroInk)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.coachHeroInk)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.xs)
        .accessibilityIdentifier("home.coachCard.prepSession")
        .accessibilityLabel(Text("Prepare for your \(moment.category.displayName), \(days) day\(days == 1 ? "" : "s") away"))
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
                        .foregroundStyle(AppColor.coachHeroInk)
                        .accessibilityHidden(true)
                    Text("Week \(plannedPhrase.target.weekIndex) phrase \u{2014} practice your saved line")
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(AppColor.coachHeroInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColor.coachHeroInk)
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
                        .foregroundStyle(AppColor.coachHeroInk)
                        .accessibilityHidden(true)
                    Text(line)
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(AppColor.coachHeroInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColor.coachHeroInk)
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
        let launch = PracticeModeLaunchProjection.resolve(
            displayedMode: exposure.mode,
            scenario: exposure.scenario,
            tone: exposure.tone,
            prescribedDemand: exposure.prescribedDemand,
            imAvailable: liveIMAvailability,
            modeAvailability: liveAvailability
        )
        RecommendationTapAttribution.apply(
            launch: launch,
            recordShown: {
                // Cover a very fast tap before SwiftUI's onAppear callback settles.
                // `recordShown` is idempotent for this exact visible fingerprint.
                recordRecommendationShown(exposure)
            },
            recordAccepted: { mode in
                recommendationLearningStore.markTapped(mode: mode)
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
            // A fallback is not a one-tap acceptance. Clear any interrupted
            // handshake from an earlier Train launch before Timed mounts.
            PracticeModeQuickStart.clear()
        }
        navigationPath.append(launch.destination)
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
        // Fire the emanation ray in lockstep with the mood burst — the
        // pulse paints the character's halo as a soft mode-tinted ring
        // that fades outward over ~700ms.
        triggerEmanation()
    }

    /// Snap the emanation back to its "just fired" state (progress 0)
    /// without animation, then animate to resting (progress 1) over
    /// 700ms with ease-out. Reduce-motion is checked at the call site
    /// (the ray view itself also returns Color.clear under reduce-motion),
    /// but we early-return here too so we never schedule a no-op animation.
    private func triggerEmanation() {
        guard !reduceMotion else { return }
        // Reset instantly so a back-to-back trigger doesn't get
        // interpolated from a partial-state mid-pulse.
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            emanationProgress = 0.0
        }
        withAnimation(.easeOut(duration: 0.7)) {
            emanationProgress = 1.0
        }
    }

    // MARK: - Derived state

    private var hasSignal: Bool {
        sessionStore.progressEligibleSessionCount > 0
    }

    private var recommendedMode: PracticeMode {
        recommendationExposure.mode
    }

    private var accentTint: Color {
        AppColor.tint(for: recommendedMode)
    }

    private var sessionStreak: Int {
        streakFreeze.currentStreak
    }

    // MARK: - Recommendation blueprint

    private var recommendationBlueprint: RecommendationBiasBlueprint {
        currentModeAvailability.resolving(coherentRecommendationBlueprint)
    }

    private var coherentRecommendationBlueprint: RecommendationBiasBlueprint {
        let base = RecommendationBiasContextBuilder.context(
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            sessionStreak: sessionStreak,
            daysSinceLastSession: daysSinceLastSession,
            coachMemory: coachMemoryStore.currentMemory,
            imAvailable: IMModeAvailability.isAvailable,
            recommendationOutcomes: recommendationLearningStore.outcomes,
            summaryStyle: .compact
        ).blueprint
        let trends = TrendAnalyzer.analyze(snapshots: skillTrendStore.snapshots)
        let coherentBlueprint = CurrentCoachingFocusPresentation.make(
            trends: trends,
            sessionCount: sessionStore.progressEligibleSessionCount
        )?.applying(to: base) ?? base
        return coherentBlueprint
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
        HomeCoachRecommendationExposure.make(
            blueprint: blueprint,
            title: coachTitle(for: blueprint),
            profile: coachingProfileStore.profile,
            recentSessions: sessionStore.progressEligibleSessions
        )
    }

    private func recordRecommendationShown(
        _ exposure: HomeCoachRecommendationExposure
    ) {
        recommendationLearningStore.recordShown(
            fingerprint: exposure.fingerprint,
            title: exposure.title,
            focus: exposure.focus,
            target: exposure.target,
            mode: exposure.mode,
            isAIBacked: false,
            goal: coachingProfileStore.profile?.chosenStyleGoal,
            prescribedDemand: exposure.prescribedDemand
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
