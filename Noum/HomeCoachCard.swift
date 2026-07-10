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

    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var forwardPlanStore = ForwardPlanStore.shared
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

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                emanationRay
                NoumCharacter(
                    mood: displayedMood,
                    tint: .white,
                    size: 64
                )
                .accessibilityHidden(true)
            }

            // Title — punchy, 1-3 words usually. Drives the visual
            // hierarchy. The earlier "one long coach sentence" pattern
            // read as a paragraph; this reads as a coach speaking.
            Text(coachTitle)
                .font(Typography.figtree(size: 22, weight: .bold, relativeTo: .title2))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.xs)
                .accessibilityIdentifier("home.coachCard.title")

            // Subtitle — the why, in body weight, secondary. Conditional —
            // hides cleanly when the variant only carries a title.
            if let subtitle = coachSubtitle {
                Text(subtitle)
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.sm)
                    .accessibilityIdentifier("home.coachCard.subtitle")
            }

            VoiceAlignmentChip(
                styleGoal: coachingProfileStore.profile?.speakingStyleGoal,
                mode: recommendedMode,
                tint: .white
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
                Button("Start \(recommendedMode.displayLabel) instead") {
                    beginRecommendedRep()
                }
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.coachCard.begin")
            } else {
                PrimaryCTA(beginCTAText, tint: .white, labelTint: AppColor.coachHeroStart) {
                    beginRecommendedRep()
                }
                .accessibilityIdentifier("home.coachCard.begin")
            }

            if showsPlanArc {
                planArcRow
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(coachCardBackground)
        // Tinted elevation in the hero's own gradient family — the ONE
        // vibrant surface on Home (docs/UX_VISUAL_DIRECTION.md).
        .shadow(color: HeroGradient.coach.shadowTint.opacity(0.32), radius: 22, x: 0, y: 10)
        .onAppear { syncMoodForFreshRecommendation() }
        .onChange(of: recommendationKey) { _, _ in syncMoodForFreshRecommendation() }
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

    private var beginCTAText: String {
        // No-signal (empty-state, brand-new user): name the moment, not
        // the mode. This is the simplest door into the product.
        guard hasSignal else {
            return "Start your first rep"
        }
        return "Start \(recommendedMode.displayLabel)"
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

    private var coachTitle: String {
        guard hasSignal else {
            return "Welcome."
        }

        if sessionStore.sessions.count < 3 {
            return "Start clean."
        }

        if let moment = bigMomentStore.activeMoment,
           let days = bigMomentStore.daysUntil(moment),
           days >= 0 && days <= 14 {
            return HomeMomentCopy.title(momentTitle: moment.title, days: days)
        }

        if recommendationBlueprint.source == .caseIntervention {
            return "Keep building the case."
        }

        // Consecutive clean reps — trajectory signal. "Three in a row"
        // feels like a coach who notices patterns, not a dashboard.
        let cleanRun = consecutiveCleanReps
        if cleanRun >= 3, sessionStore.sessions.count >= 5 {
            return cleanRun == 3 ? "Three in a row." : "\(cleanRun) clean."
        }

        // Landmark within reach — wins over tier-holding because the path
        // node is a concrete next action the user can complete this rep,
        // while "Hold {tier}" is a steady-state nudge. When the user is
        // one rep / one score-point / one day from unlocking their next
        // node, surface that explicitly. See `landmarkWithinReach` for the
        // predicate. Never fires for boolean-trigger criteria the user
        // hasn't engaged with at all — restraint over coverage.
        if landmarkWithinReach {
            return "Landmark within reach."
        }

        let tier = LeagueTier.tier(for: ratingStore.rating.overall)
        let tierHolding = tier == .gold || tier == .platinum || tier == .diamond
        let reps = sessionStore.sessions.count
        if tierHolding && reps >= 8 {
            return "Hold \(tier.title)."
        }

        let focus = CoachDisplayCopy.normalized(recommendationBlueprint.focus)
        if !focus.isEmpty {
            // Ensure punctuation closure — title reads as a complete
            // imperative, not a fragment trailing into the subtitle.
            let trimmed = focus.trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
            return "\(trimmed)."
        }

        return "Build a clean rep."
    }

    private var coachSubtitle: String? {
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

        if sessionStore.sessions.count < 3 {
            return "Three reps and Noum starts finding your weakest line."
        }

        if recommendationBlueprint.source == .caseIntervention {
            return CoachDisplayCopy.normalized(recommendationBlueprint.whyNow)
        }

        // Landmark within reach — subtitle is the gating line itself so the
        // user reads the concrete bar ("One rep from unlocked.") right
        // under the headline. The gating phrase is sourced from
        // `PathProgressManager.currentNodeGatingPhrase`, which never
        // punish-shames a regression.
        if landmarkWithinReach, let phrase = pathProgress.currentNodeGatingPhrase {
            return phrase
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

        // Weekly rhythm milestone — fires at 3, 5, 7 reps per week.
        // Reinforces cadence between landmark and tier variants.
        let weekReps = weeklyRepCount
        if [3, 5, 7].contains(weekReps), sessionStore.sessions.count >= 5 {
            switch weekReps {
            case 3: return "Third rep this week — rhythm is building."
            case 5: return "Five this week — strong rhythm."
            case 7: return "Seven reps this week — serious commitment."
            default: break
            }
        }

        let blueprint = recommendationBlueprint
        let focus = CoachDisplayCopy.normalized(blueprint.focus)
        let why = CoachDisplayCopy.normalized(blueprint.whyNow)

        let tier = LeagueTier.tier(for: ratingStore.rating.overall)
        let tierHolding = tier == .gold || tier == .platinum || tier == .diamond
        let reps = sessionStore.sessions.count
        if tierHolding && reps >= 8 {
            return "One clean rep keeps the ladder moving \u{2014} \(focus.lowercased())."
        }

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
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Continue prep")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Three focused reps")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
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
        if let line = HomePlanArcLine.line(
            state: state,
            voice: coachingProfileStore.profile?.speakingStyleGoal
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
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityHidden(true)
                    Text(line)
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Your four-week plan. \(line). Opens the coach thread."))
            .accessibilityIdentifier("home.coachCard.planArc")
        }
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
        case .timed:          return "TIMED"
        case .suddenDeath:    return "PRESSURE DRILL"
        case .ahCounter:      return "AH-COUNTER"
        case .imConversation: return "CONVERSATION"
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

    private func beginRecommendedRep() {
        // Commitment haptic (A2 register map): the user just committed
        // to a rep — the single most consequential tap in the product.
        CoachHaptic.drillStart()
        let mode = recommendedMode
        recommendationLearningStore.markTapped(mode: mode)
        if mode == .timed {
            let theme = recommendationBlueprint.suggestedTheme
            if theme != .all {
                UserDefaults.standard.set(
                    theme.rawValue,
                    forKey: "timedPractice.selectedTheme"
                )
            }
        }
        navigationPath.append(destination())
    }

    private func destination() -> AppDestination {
        // Round 18: the `mode` parameter was removed because the router
        // already reads `recommendedMode` off `recommendationBlueprint`
        // — passing it in opened a silent-drift hole where a caller could
        // claim to route a different mode than the blueprint says. The
        // function is now a one-liner against the same router that
        // `ContentView.practiceAppDestination(for:)` and (once the
        // closure-pass UI lands) the post-rep `LookingAheadCard` call
        // into, so the IM-unavailable fallback stays in one tested place.
        SummaryLookingAheadRouter.destination(
            for: recommendationBlueprint,
            imAvailable: IMModeAvailability.isAvailable
        )
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
        let blueprint = recommendationBlueprint
        return "\(blueprint.recommendedMode.rawValue)|\(blueprint.focus)|\(blueprint.target)"
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
        !sessionStore.sessions.isEmpty
    }

    private var recommendedMode: PracticeMode {
        recommendationBlueprint.recommendedMode
    }

    private var accentTint: Color {
        AppColor.tint(for: recommendedMode)
    }

    private var sessionStreak: Int {
        streakFreeze.currentStreak
    }

    // MARK: - Recommendation blueprint

    private var recommendationBlueprint: RecommendationBiasBlueprint {
        RecommendationBiasContextBuilder.context(
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            sessionStreak: sessionStreak,
            daysSinceLastSession: daysSinceLastSession,
            coachMemory: coachMemoryStore.currentMemory,
            imAvailable: IMModeAvailability.isAvailable,
            recommendationOutcomes: recommendationLearningStore.outcomes,
            summaryStyle: .compact
        ).blueprint
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
        let sorted = sessionStore.sessions // already sorted newest-first
        var count = 0
        for session in sorted {
            let mins = max(session.duration / 60.0, 1.0 / 60.0)
            let rate = Double(session.fillerWordCount) / mins
            let threshold = max(baseRate * 0.5, 0.5)
            if rate <= threshold || session.fillerWordCount <= 1 {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    /// The most credible recurring-position read across the recent rep window,
    /// or nil when no positional habit has cleared `RepEventTrendEngine`'s
    /// honesty floors (>=3 reps carried the event AND one zone holds a >=60%
    /// super-majority). Pure — recomputed from the live session store, no new
    /// persistence. `compute` returns trends in a fixed kind order (rushed →
    /// pause → filler), so `.first` deterministically prefers the most
    /// actionable pace read when several patterns co-exist.
    private var positionalTrend: RepEventTrend? {
        RepEventTrendEngine.compute(sessions: sessionStore.sessions).first
    }

    /// Reps completed in the current ISO week.
    private var weeklyRepCount: Int {
        let cal = Calendar.current
        let now = Date()
        let currentWeek = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return sessionStore.sessions.filter { session in
            let w = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date)
            return w.yearForWeekOfYear == currentWeek.yearForWeekOfYear
                && w.weekOfYear == currentWeek.weekOfYear
        }.count
    }

    private var daysSinceLastSession: Int {
        guard let latest = sessionStore.sessions.first else { return 0 }
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
