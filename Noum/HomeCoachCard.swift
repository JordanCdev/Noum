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
struct HomeCoachCard: View {

    @Binding var navigationPath: NavigationPath

    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared

    @State private var characterMood: NoumCharacter.Mood = .coaching
    @State private var lastSeenRecommendationKey: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.sm) {
            NoumCharacter(
                mood: characterMood,
                tint: accentTint,
                size: 90
            )
            .accessibilityHidden(true)
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

            // Begin button carries the mode name so the micro-label
            // "SUDDEN DEATH · ONE BREATH · ONE COMPLETE REP" row can go
            // away — three text rows became one button label.
            PrimaryCTA(beginCTAText, tint: accentTint) {
                beginRecommendedRep()
            }
            .accessibilityIdentifier("home.coachCard.begin")
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

    /// Label for the Begin CTA — "Begin · Sudden Death" pattern carries
    /// the mode info that used to live in the micro-label row. One row
    /// fewer on Home; user still knows exactly what they're starting.
    private var beginCTAText: String {
        let modeName: String
        switch recommendedMode {
        case .timed:          modeName = "Timed"
        case .suddenDeath:    modeName = "Sudden Death"
        case .ahCounter:      modeName = "Ah-Counter"
        case .imConversation: modeName = "IM"
        }
        return "Begin \u{00B7} \(modeName)"
    }

    /// Hero card chrome — replaces the standard `CardView` so the Coach
    /// Card carries visual depth + a brand-tinted presence. A flat white
    /// rectangle was the right starting point for the redesign but read
    /// as generic against the dream brief ("fancy designs, awesome cards").
    ///
    /// Layers, bottom to top:
    ///   1. White card surface (the canvas).
    ///   2. Mode-tinted radial gradient washing from the character anchor
    ///      down — same hue as the recommended mode, very low alpha, so
    ///      the card visibly belongs to the recommendation that drives it.
    ///   3. A faint tinted hairline border (1pt) that reinforces the wash
    ///      without competing.
    /// Outer `.shadow` (applied by `body`) adds elevation in the same hue.
    /// Hero card chrome — Pro-purple as the ambient brand register, with
    /// a very faint mode-tint accent at the trailing edge so the card
    /// still subtly belongs to the recommendation. Two colors, two
    /// registers: purple = "this is your coach", mode tint = "this is
    /// what to do."
    ///
    /// Layers, bottom to top:
    ///   1. White card base.
    ///   2. Top-anchored radial purple wash (the dream's "fancy purple").
    ///   3. Trailing-anchored low-alpha mode tint (very subtle).
    ///   4. Faint purple hairline border.
    private var coachCardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)

            shape.fill(
                RadialGradient(
                    colors: [AppColor.pro.opacity(0.22), AppColor.pro.opacity(0.04), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 320
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [accentTint.opacity(0.10), Color.clear],
                    center: UnitPoint(x: 1.0, y: 0.5),
                    startRadius: 0,
                    endRadius: 220
                )
            )

            shape.strokeBorder(AppColor.pro.opacity(0.20), lineWidth: 1)
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
        guard hasSignal else {
            return "Tap Begin and Noum will start hearing you out."
        }

        if sessionStore.sessions.count < 3 {
            return "Three reps and Noum starts finding your weakest line."
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
        navigationPath.append(destination(for: mode))
    }

    private func destination(for mode: PracticeMode) -> AppDestination {
        switch mode {
        case .timed:
            return .timedPractice
        case .suddenDeath:
            return .suddenDeathPractice
        case .ahCounter:
            return .ahCounterPractice
        case .imConversation:
            if IMModeAvailability.isAvailable {
                return .imPractice(
                    scenario: recommendationBlueprint.recommendedScenario,
                    tone: recommendationBlueprint.recommendedTone
                )
            } else {
                return .timedPractice
            }
        }
    }

    // MARK: - Mood lifecycle
    //
    // The character defaults to .coaching (the brief's spec). When the
    // active recommendation changes (e.g. after a finalize that produces
    // a new suggested mode), brief .excited for ~1s then settle back.
    // Reduce-motion users stay on .coaching the entire time so nothing
    // animates.

    private var recommendationKey: String {
        let blueprint = recommendationBlueprint
        return "\(blueprint.recommendedMode.rawValue)|\(blueprint.focus)|\(blueprint.target)"
    }

    private func syncMoodForFreshRecommendation() {
        let key = recommendationKey
        defer { lastSeenRecommendationKey = key }
        guard !reduceMotion else {
            characterMood = .coaching
            return
        }
        // Only burst on a real change, not on first appear (first appear
        // already has the character's onAppear entrance animation).
        guard !lastSeenRecommendationKey.isEmpty, lastSeenRecommendationKey != key else {
            characterMood = .coaching
            return
        }
        characterMood = .excited
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            characterMood = .coaching
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
            plan: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)
        )
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
