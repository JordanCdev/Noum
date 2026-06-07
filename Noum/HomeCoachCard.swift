#if canImport(SwiftUI)
import SwiftUI

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
struct HomeCoachAskNoumShortcut: Equatable {
    static let title = "Ask Noum"
    static let actionTitle = "Open the thread"
    static let accessibilityIdentifier = "home.coachCard.askNoum"

    static func body(sessionCount: Int) -> String {
        HomeAskNoumEvidenceCopy.line(sessionCount: sessionCount)
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
    var showsAskNoumShortcut: Bool = false

    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    // Path progress drives the "Mission within reach" coach variant — when
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
        VStack(spacing: Spacing.sm) {
            ZStack {
                emanationRay
                NoumCharacter(
                    mood: displayedMood,
                    tint: accentTint,
                    size: 90
                )
                .accessibilityHidden(true)
            }
            .padding(.top, Spacing.xs)

            // Title — punchy, 1-3 words usually. Drives the visual
            // hierarchy. The earlier "one long coach sentence" pattern
            // read as a paragraph; this reads as a coach speaking.
            Text(coachTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.xs)
                .accessibilityIdentifier("home.coachCard.title")

            // Subtitle — the why, in body weight, secondary. Conditional —
            // hides cleanly when the variant only carries a title.
            if let subtitle = coachSubtitle {
                Text(subtitle)
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.sm)
                    .accessibilityIdentifier("home.coachCard.subtitle")
            }

            VoiceAlignmentChip(
                styleGoal: coachingProfileStore.profile?.speakingStyleGoal,
                mode: recommendedMode,
                tint: accentTint
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
            }

            // Begin button carries the mode name so the micro-label
            // "SUDDEN DEATH · ONE BREATH · ONE COMPLETE REP" row can go
            // away — three text rows became one button label.
            PrimaryCTA(beginCTAText, tint: accentTint) {
                beginRecommendedRep()
            }
            .accessibilityIdentifier("home.coachCard.begin")

            if showsAskNoumShortcut {
                askNoumShortcutCTA
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(coachCardBackground)
        // Soft Pro-purple elevation — the hero now carries the brand
        // premium register as its ambient color, with mode tint reserved
        // for the action (Begin button) + character. Two registers, not
        // one, gives the hero presence without overloading the eye.
        .shadow(color: AppColor.pro.opacity(0.18), radius: 22, x: 0, y: 10)
        .onAppear { syncMoodForFreshRecommendation() }
        .onChange(of: recommendationKey) { _, _ in syncMoodForFreshRecommendation() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.coachCard")
    }

    /// Label for the Begin CTA — "Begin · Pressure Drill" pattern carries
    /// the mode info that used to live in the micro-label row. One row
    /// fewer on Home; user still knows exactly what they're starting.
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
        // the mode. "Begin · Timed" is a stranger's instruction; "Begin ·
        // First rep" is the door the user just walked up to.
        guard hasSignal else {
            return "Begin \u{00B7} First rep"
        }
        let modeName: String
        switch recommendedMode {
        case .timed:          modeName = "Timed"
        case .suddenDeath:    modeName = PracticeMode.suddenDeath.displayLabel
        case .ahCounter:      modeName = "Ah-Counter"
        case .imConversation: modeName = "IM"
        }
        return "Begin \u{00B7} \(modeName)"
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
            shape.fill(AppColor.cardBackground)

            // The drifting Pro-purple radial. When reduce-motion is on
            // we render a single static gradient; otherwise a
            // TimelineView samples a sine-driven UnitPoint so the
            // center sweeps smoothly without invalidating SwiftUI
            // state every frame.
            //
            // The whole wash shifts by `dy` opposite the scroll
            // direction — a barely-there interior parallax that
            // gives the card a sense of depth under scroll without
            // moving the card itself. Clipped to the shape so the
            // offset gradient never escapes the silhouette.
            purpleWash(in: shape)
                .offset(y: dy)
                .clipShape(shape)

            // Trailing mode-tint — kept under the material so the
            // glass also frosts this register. The mode tint stays
            // legible through the material because the radius is
            // wider and the color anchors to the trailing edge.
            // Drifts at 0.6x the purple wash so the two layers don't
            // slide as one sheet.
            shape.fill(
                RadialGradient(
                    colors: [accentTint.opacity(0.12), Color.clear],
                    center: UnitPoint(x: 1.0, y: 0.5),
                    startRadius: 0,
                    endRadius: 240
                )
            )
            .offset(y: dy * 0.6)
            .clipShape(shape)

            // Frosted-glass overlay — dropped from 0.55 to 0.30 alpha
            // so the underlying purple wash reads obviously at rest, not
            // just in motion. The previous opacity was too soft against
            // a richer wash and made the card read as a flat white card
            // in still screenshots.
            shape.fill(.regularMaterial)
                .opacity(0.30)

            // Hairline border bumped from 0.22 to 0.40 so the card's
            // silhouette has a defined edge against the home canvas.
            shape.strokeBorder(AppColor.pro.opacity(0.40), lineWidth: 1)
        }
    }

    /// Pro-purple radial wash with optional slow drift across the top
    /// of the card. The TimelineView path samples the system animation
    /// clock so the gradient itself redraws smoothly rather than relying
    /// on `withAnimation` interpolating a state-bound `UnitPoint` (which
    /// SwiftUI doesn't animate continuously across `RadialGradient`
    /// re-creations).
    @ViewBuilder
    private func purpleWash<S: Shape>(in shape: S) -> some View {
        if reduceMotion {
            shape.fill(
                RadialGradient(
                    colors: [AppColor.pro.opacity(0.55), AppColor.proLight.opacity(0.25), AppColor.pro.opacity(0.04), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 340
                )
            )
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                // 7s ease-in-out loop. Mapping a sine to [0, 1] gives
                // a symmetric drift that lingers softly at each end —
                // the user reads "this card breathes," not "this card
                // animates."
                let phase = (sin(t * (2 * .pi / 7.0)) + 1) / 2
                let centerX = 0.35 + 0.30 * phase
                let centerY = 0.0 + 0.15 * phase
                shape.fill(
                    RadialGradient(
                        colors: [AppColor.pro.opacity(0.55), AppColor.proLight.opacity(0.25), AppColor.pro.opacity(0.04), Color.clear],
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

        if recommendationBlueprint.source == .caseIntervention {
            return "Stay with the case."
        }

        // Consecutive clean reps — trajectory signal. "Three in a row"
        // feels like a coach who notices patterns, not a dashboard.
        let cleanRun = consecutiveCleanReps
        if cleanRun >= 3, sessionStore.sessions.count >= 5 {
            return cleanRun == 3 ? "Three in a row." : "\(cleanRun) clean."
        }

        // Mission within reach — wins over tier-holding because the path
        // node is a concrete next action the user can complete this rep,
        // while "Hold {tier}" is a steady-state nudge. When the user is
        // one rep / one score-point / one day from unlocking their next
        // node, surface that explicitly. See `missionWithinReach` for the
        // predicate. Never fires for boolean-trigger criteria the user
        // hasn't engaged with at all — restraint over coverage.
        if missionWithinReach {
            return "Mission within reach."
        }

        let tier = LeagueTier.tier(for: ratingStore.rating.overall)
        let tierHolding = tier == .gold || tier == .platinum || tier == .diamond
        let reps = sessionStore.sessions.count
        if tierHolding && reps >= 8 {
            return "Hold \(tier.title)."
        }

        let focus = recommendationBlueprint.focus.trimmingCharacters(in: .whitespacesAndNewlines)
        if !focus.isEmpty {
            // Ensure punctuation closure — title reads as a complete
            // imperative, not a fragment trailing into the subtitle.
            let trimmed = focus.trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
            return "\(trimmed)."
        }

        return "Run a clean rep."
    }

    private var coachSubtitle: String? {
        // Big Moment countdown — highest-priority variant when a moment is
        // set and within 30 days. Suppressed when daysUntil < 0 (moment
        // passed) or > 30 (too far out to feel urgent). Falls back to the
        // goal-voice subtitle when the moment is cleared or past.
        if let moment = bigMomentStore.activeMoment,
           let days = bigMomentStore.daysUntil(moment),
           days >= 0 && days <= 30 {
            let label = bigMomentCountdownCopy(moment: moment, days: days)
            return label
        }

        guard hasSignal else {
            // Empty-state — adapt to the user's stated challenge if the
            // CoachingProfile already exists (they finished onboarding
            // but haven't done a rep yet). Mirrors the copy the legacy
            // `firstSessionWelcomeMessage` carried so the first-impression
            // line names the user's own goal, not a generic banner.
            if let profile = coachingProfileStore.profile {
                let challenge: String
                switch profile.biggestChallenge {
                case .fillerWords:
                    challenge = "cleaning up filler words"
                case .rambling:
                    challenge = "tightening your structure"
                case .freezing:
                    challenge = "thinking faster on the spot"
                case .rushing:
                    challenge = "slowing down under pressure"
                }
                return "You want to work on \(challenge). One short rep sets your starting line."
            }
            return "One short rep sets your starting line."
        }

        if sessionStore.sessions.count < 3 {
            return "Three reps and Noum starts finding your weakest line."
        }

        if recommendationBlueprint.source == .caseIntervention {
            return recommendationBlueprint.whyNow
        }

        // Mission within reach — subtitle is the gating line itself so the
        // user reads the concrete bar ("One rep from unlocked.") right
        // under the headline. The gating phrase is sourced from
        // `PathProgressManager.currentNodeGatingPhrase`, which never
        // punish-shames a regression.
        if missionWithinReach, let phrase = pathProgress.currentNodeGatingPhrase {
            return phrase
        }

        // Weekly rhythm milestone — fires at 3, 5, 7 reps per week.
        // Reinforces cadence between mission and tier variants.
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
        let focus = blueprint.focus.trimmingCharacters(in: .whitespacesAndNewlines)
        let why = blueprint.whyNow.trimmingCharacters(in: .whitespacesAndNewlines)

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
                    .foregroundStyle(AppColor.pro)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Prepare for your \(moment.category.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(days) day\(days == 1 ? "" : "s") out · three-rep rehearsal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.pro)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppColor.pro.opacity(0.14), AppColor.pro.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(AppColor.pro.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.xs)
        .accessibilityIdentifier("home.coachCard.prepSession")
        .accessibilityLabel(Text("Prepare for your \(moment.category.displayName), \(days) day\(days == 1 ? "" : "s") away"))
    }

    /// Secondary Ask Noum entry folded into the coach hero. This replaces
    /// the standalone Home promo card so the home feed has one coach
    /// surface, one primary rep action, and one quieter way to ask a
    /// follow-up after there is evidence to discuss.
    @ViewBuilder
    private var askNoumShortcutCTA: some View {
        let body = HomeCoachAskNoumShortcut.body(sessionCount: sessionStore.sessions.count)
        Button {
            navigationPath.append(AppDestination.askNoum)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColor.pro.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: "message.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.pro)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(HomeCoachAskNoumShortcut.title)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(body)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Text(HomeCoachAskNoumShortcut.actionTitle)
                    .font(Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(AppColor.pro)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.pro)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColor.pro.opacity(0.07),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(AppColor.pro.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(HomeCoachAskNoumShortcut.title). \(body). \(HomeCoachAskNoumShortcut.actionTitle)."))
        .accessibilityIdentifier(HomeCoachAskNoumShortcut.accessibilityIdentifier)
    }

    /// Countdown copy for the Big Moment subtitle.
    /// Uses the title when it fits within ~40 chars, otherwise falls back
    /// to the category displayName to keep the line compact on home.
    private func bigMomentCountdownCopy(moment: BigMoment, days: Int) -> String {
        let titleLabel: String
        if moment.title.count <= 40 {
            titleLabel = moment.title
        } else {
            titleLabel = moment.category.displayName
        }
        return "\(days) day\(days == 1 ? "" : "s") to your \(titleLabel)."
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
    private var missionWithinReach: Bool {
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
        case .suddenDeath:    return "SUDDEN DEATH"
        case .ahCounter:      return "AH-COUNTER"
        case .imConversation: return "IM"
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
    //
    // Mirrors the same construction `ContentView.recommendationBiasBlueprint`
    // uses today, so the coach card and any other recommendation surface
    // read the same playbook. When ContentView's helper is hoisted to a
    // shared computed source, this can collapse to a single call.

    private var recommendationBlueprint: RecommendationBiasBlueprint {
        let recent = Array(sessionStore.sessions.prefix(5))
        let previous = Array(sessionStore.sessions.dropFirst(5).prefix(5))
        let identity = PracticeEvaluator.speakingIdentity(
            for: recent.first?.transcript ?? "",
            profile: coachingProfileStore.profile
        )
        let styleTrend = PracticeEvaluator.styleTrendSnapshot(
            transcript: recent.first?.transcript ?? "",
            recentSessions: recent,
            profile: coachingProfileStore.profile
        )
        let input = AIHomeRecommendationInput(
            recentSessionSummary: "",
            averageFillers: recent.isEmpty ? 0 : Double(recent.map(\.fillerWordCount).reduce(0, +)) / Double(recent.count),
            averageDuration: recent.isEmpty ? 0 : recent.map(\.duration).reduce(0, +) / Double(recent.count),
            averageWordsPerMinute: recent.isEmpty ? 0 : Double(recent.map(\.wordsPerMinute).reduce(0, +)) / Double(recent.count),
            fillerTrendDelta: trendDelta(current: recent.map { Double($0.fillerWordCount) }, previous: previous.map { Double($0.fillerWordCount) }),
            durationTrendDelta: trendDelta(current: recent.map(\.duration), previous: previous.map(\.duration)),
            paceTrendDelta: trendDelta(current: recent.map { Double($0.wordsPerMinute) }, previous: previous.map { Double($0.wordsPerMinute) }),
            averageWordCount: recent.isEmpty ? 0 : Double(recent.map(\.wordCount).reduce(0, +)) / Double(recent.count),
            strongestMode: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)?.strongestMode,
            currentIdentity: identity.identity,
            currentIdentityEvidence: identity.evidence,
            styleAlignmentScore: styleTrend.currentAlignment,
            sessionStreak: sessionStreak,
            daysSinceLastSession: daysSinceLastSession,
            preferredModeBias: "",
            preferredToneBias: "",
            preferredScenarioBias: "",
            modeBenefitBias: ""
        )
        return RecommendationBiasEngine.blueprint(
            profile: coachingProfileStore.profile,
            input: input,
            plan: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile),
            imToneSignal: IMModeAvailability.isAvailable
                ? IMHistorySummary.toneDrillSignal(from: sessionStore.sessions)
                : nil,
            coachMemory: coachMemoryStore.currentMemory
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

    private func trendDelta(current: [Double], previous: [Double]) -> Double {
        guard !current.isEmpty, !previous.isEmpty else { return 0 }
        let currentAvg = current.reduce(0, +) / Double(current.count)
        let previousAvg = previous.reduce(0, +) / Double(previous.count)
        return currentAvg - previousAvg
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
