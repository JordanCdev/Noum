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
        CardView {
            VStack(spacing: Spacing.sm) {
                // Tightened from size 96 + `.md` spacing to 72 + `.sm`.
                // The earlier card felt airy — too much chrome around the
                // character, not enough density on the coach line + CTA.
                NoumCharacter(
                    mood: characterMood,
                    tint: accentTint,
                    size: 72
                )
                .accessibilityHidden(true)
                .padding(.top, Spacing.xs)

                Text(coachLine)
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xs)
                    .accessibilityIdentifier("home.coachCard.line")

                Text(microLabelText)
                    .microLabel()
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("home.coachCard.microLabel")

                // Goal-alignment chip — surfaces "Toward your <voice> voice"
                // when the recommended mode trains a skill the user's chosen
                // voice goal aligns with. Silent on no-goal / non-aligned
                // recommendations (no fake personalization). Same component
                // the cloud routines wired into the suggestion link; lives
                // here too so the redesigned hero carries the same thread.
                VoiceAlignmentChip(
                    styleGoal: coachingProfileStore.profile?.speakingStyleGoal,
                    mode: recommendedMode,
                    tint: accentTint
                )

                PrimaryCTA("Begin", tint: accentTint) {
                    beginRecommendedRep()
                }
                .accessibilityIdentifier("home.coachCard.begin")

                // Utility strip (streak + word-of-day) lives as a sibling
                // `HomeUtilityStrip` below the Coach Card on the populated
                // home stack, not inside this card. Keeps the Coach Card
                // focused on hero + coach voice + single CTA.
            }
        }
        .onAppear { syncMoodForFreshRecommendation() }
        .onChange(of: recommendationKey) { _, _ in syncMoodForFreshRecommendation() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.coachCard")
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

    private var coachLine: String {
        guard hasSignal else {
            // True cold-start: no sessions yet.
            return "Welcome. Tap Begin and Noum will start hearing you out."
        }

        if sessionStore.sessions.count < 3 {
            // Early-signal: don't over-claim with weak evidence.
            return "Start with a clean baseline rep \u{2014} Noum needs three reps to find your weakest line."
        }

        let blueprint = recommendationBlueprint
        let focus = blueprint.focus.trimmingCharacters(in: .whitespacesAndNewlines)
        let why = blueprint.whyNow.trimmingCharacters(in: .whitespacesAndNewlines)

        // Tier-holding read — Gold/Platinum/Diamond users get a ladder
        // reference. Bronze/Silver get the plain coaching line so we
        // never write "You're holding Bronze" (no false flattery).
        let tier = LeagueTier.tier(for: ratingStore.rating.overall)
        let tierHolding = tier == .gold || tier == .platinum || tier == .diamond
        let reps = sessionStore.sessions.count
        if tierHolding && reps >= 8 {
            return "You're holding \(tier.title). One more clean rep keeps the ladder moving \u{2014} \(focus.lowercased())."
        }

        // Default coach line: focus + whyNow stitched into one sentence.
        if !focus.isEmpty && !why.isEmpty {
            return "\(focus). \(why)"
        }
        if !focus.isEmpty {
            return focus
        }
        return why.isEmpty ? "Run a clean rep to keep the read sharp." : why
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
