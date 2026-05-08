//
//  ContentView.swift
//  Noum
//
//  Created by Jordan Coaten on 25/01/2025.
//

#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private struct HomeScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var profile = ProfileManager.shared
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var dailyGoal = DailyGoalManager.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var deferredCapture = DeferredProfileCaptureManager.shared
    @StateObject private var goalRefresh = GoalRefreshManager.shared
    @StateObject private var notificationPrePrompt = NotificationPrePromptManager.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared
    @StateObject private var league = LeagueManager.shared
    @State private var selectedPracticeMode: PracticeMode = .timed
    @State private var showDailyGoalCelebration = false
    @State private var showFreezeNudge = false
    @State private var aiRecommendation: AIHomeRecommendation?
    @State private var homeCelebrationVisible = false
    @State private var homeScrollOffset: CGFloat = 0
    @State private var navigationPath = NavigationPath()
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    private let isOnboardingUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING_ONBOARDING")
    private let aiHomeRecommendationService: AIHomeRecommendationServicing = AIHomeRecommendationService()

    private struct PracticeSuggestion {
        let title: String
        let detail: String
        let focus: String
        let target: String
        let mode: PracticeMode
        let recommendedTone: IMTargetTone?
        let recommendedScenario: IMConversationScenario?
        let benefit: String
        let tint: Color
        var suggestedTimedDifficulty: TimedPracticeDifficulty? = nil
        var suggestedTheme: PromptTheme = .all
    }

    private struct ModeSnapshot {
        let mode: PracticeMode
        let count: Int
        let averageFillers: Double
        let averageDuration: Double
        let averagePace: Double
        let averageScore: Double
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppColor.screenBackground
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: HomeScrollOffsetKey.self, value: proxy.frame(in: .named("homeScroll")).minY)
                    }
                    .frame(height: 0)

                    VStack(spacing: Spacing.cardGap) {
                        if sessionStore.sessions.isEmpty {
                            // Empty-state: a single, clear primary action.
                            // Lessons + Path are surfaced below the fold so
                            // the user sees the curriculum exists, but
                            // they're never asked to choose between four
                            // CTAs before they've done anything.
                            heroCard.cardEntrance(0)
                            firstSessionCard.cardEntrance(1)
                            DailyGoalCard(manager: dailyGoal).cardEntrance(2)
                            secondaryDiscoveryCard.cardEntrance(3)
                        } else {
                            // Populated home — editorial pass (M14).
                            //
                            // Reduced from 11 cards to 6. Each remaining
                            // card earns its place; nothing is duplicated:
                            //
                            //  1. heroCard — greeting + character + streak chip.
                            //  2. quickStartCard — primary CTA, promoted to
                            //     second slot.
                            //  3. DailyChallengeTile — daily-open mechanic
                            //     with an inline "N of M reps today" header
                            //     so we don't need a separate DailyGoalCard.
                            //  4. WordOfTheDayTile — small daily stretch.
                            //  5. AIWeeklyInsightCard — differentiator;
                            //     keeps the narrative-coaching feel.
                            //  6. journeyPreviewCard — long-game path CTA.
                            //
                            // Removed and where the surface still lives:
                            //  • DailyGoalCard — rep counter folded into
                            //    the DailyChallengeTile header.
                            //  • streakCard — already in the hero chip.
                            //  • nextLessonCard — reachable via Path /
                            //    Review.
                            //  • progressCard — rank/level is identity,
                            //    lives on Profile.
                            //  • suggestedPracticeCard — duplicated the
                            //    quickStartCard's primary intent.
                            heroCard.cardEntrance(0)
                            quickStartCard.cardEntrance(1)
                            DailyChallengeTile().cardEntrance(2)
                            WordOfTheDayTile(navigationPath: $navigationPath).cardEntrance(3)
                            AIWeeklyInsightCard(
                                sessionStore: sessionStore,
                                ratingStore: RatingStore.shared,
                                clutchWordStore: ClutchWordStore.shared,
                                coachingProfileStore: coachingProfileStore
                            )
                            .cardEntrance(4)
                            journeyPreviewCard.cardEntrance(5)
                        }
                    }
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, 12)
                    // Generous bottom inset so the last card never sits
                    // under the floating bottom-nav pill. The pill lives
                    // in `safeAreaInset(edge: .bottom)` further below; if
                    // we trim this any tighter the populated home's
                    // bottom card gets clipped on first paint.
                    .padding(.bottom, 96)
                }
            }
            .coordinateSpace(name: "homeScroll")
            .toolbar(.hidden, for: .navigationBar)
            .onPreferenceChange(HomeScrollOffsetKey.self) { value in
                homeScrollOffset = value
            }
            .safeAreaInset(edge: .bottom) {
                bottomNavigation
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .practiceSelection:
                    PracticeModeSelectionView(selectedMode: $selectedPracticeMode, navigationPath: $navigationPath)
                case .timedPractice:
                    TimedPracticeView(navigationPath: $navigationPath)
                case .suddenDeathPractice:
                    SuddenDeathPracticeView(navigationPath: $navigationPath)
                case .ahCounterPractice:
                    AhCounterView(navigationPath: $navigationPath)
                case .imPractice(let scenario, let tone):
                    if IMModeAvailability.isAvailable {
                        IMPracticeView(
                            navigationPath: $navigationPath,
                            preferredScenario: scenario,
                            preferredTone: tone
                        )
                    } else {
                        TimedPracticeView(navigationPath: $navigationPath)
                    }
                case .cutTheCrutchPractice:
                    CutTheCrutchView(navigationPath: $navigationPath)
                case .friendLeaderboard:
                    FriendLeaderboardView()
                case .league:
                    LeagueView()
                case .speechProjects:
                    SpeechProjectsView(navigationPath: $navigationPath)
                case .lessons:
                    LessonsHomeView(navigationPath: $navigationPath)
                case .lesson(let id):
                    if let lesson = LessonsCatalog.lesson(id: id) {
                        LessonView(lesson: lesson, navigationPath: $navigationPath)
                    } else {
                        LessonsHomeView(navigationPath: $navigationPath)
                    }
                case .summary(let payload):
                    SummaryView(payload: payload, navigationPath: $navigationPath)
                case .sessionHistory:
                    SessionHistoryView(navigationPath: $navigationPath)
                case .socialProfile:
                    ProfileView()
                case .settings:
                    SettingsView()
                case .speakingRank:
                    SpeakingRankView()
                case .pathJourney:
                    PathJourneyView(navigationPath: $navigationPath)
                }
            }
        }
        .accessibilityIdentifier("home.screen")
        .fullScreenCover(
            isPresented: .init(
                get: { isOnboardingUITesting },
                set: { _ in }
            )
        ) {
            CoachingOnboardingView()
        }
        // Tier promotion celebration. Surfaces over the home with a
        // tinted radial gradient + sparkle ribbon. Cleared when the
        // user taps Continue or the backdrop.
        .fullScreenCover(item: $league.pendingPromotion) { promotion in
            TierPromotionOverlay(promotion: promotion) {
                league.consumePendingPromotion()
            }
            .presentationBackground(.clear)
        }
        .overlay {
            if showDailyGoalCelebration {
                DailyGoalCelebration {
                    showDailyGoalCelebration = false
                    dailyGoal.consumeGoalCelebration()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .overlay {
            if let unlockedNode = pendingPathCelebration {
                PathNodeCelebration(
                    node: unlockedNode,
                    onDismiss: {
                        pathProgress.consumeCelebration()
                    }
                )
                .transition(.opacity)
                .zIndex(99)
            }
        }
        // Deferred profile capture — M14 UX rework.
        //
        // Previously fired as a full-screen sheet that hijacked the
        // post-session moment. Real-device feedback flagged this as too
        // much decision pressure right after a rep ("need a more user
        // friendly way of adding it"). Now the pending prompt surfaces
        // as an inline card on SummaryView (`DeferredCaptureInlineCard`)
        // that the user can answer or scroll past — no modal block.
        // Captured text lands on Profile via the "In your own words"
        // section so users see their reflections being held by the app.
        // Goal refresh — 2-week cadence "still your goal?" lightweight sheet.
        .sheet(isPresented: $goalRefresh.shouldPresent) {
            GoalRefreshSheet()
        }
        // Notification pre-prompt — soft sell before iOS's hard prompt.
        // Fires once on session 1 with a 30-day cool-down on decline.
        .sheet(isPresented: $notificationPrePrompt.pendingPrompt) {
            NotificationPrePromptSheet()
        }
        .onChange(of: deepLinkRouter.pending) { _, url in
            guard let url else { return }
            consumeDeepLink(url)
        }
        .onChange(of: dailyGoal.pendingGoalCelebration) { _, isPending in
            if isPending {
                showDailyGoalCelebration = true
            }
        }
        .onAppear {
            dailyGoal.recompute()
            DailyChallengesManager.shared.ensureForToday()
            DailyChallengesManager.shared.recomputeReady()
            WordOfTheDayManager.shared.ensureForToday()
        }
        .task {
            guard !isUITesting, !isOnboardingUITesting, !authManager.isSignedIn else { return }
            authManager.startAnonymousSession()
        }
        .task(id: recommendationCacheKey) {
            await refreshHomeRecommendation()
        }
        .task(id: shownRecommendationFingerprint) {
            recommendationLearningStore.recordShown(
                fingerprint: shownRecommendationFingerprint,
                title: effectiveSuggestion.title,
                focus: effectiveSuggestion.focus,
                target: effectiveSuggestion.target,
                mode: effectiveSuggestion.mode,
                isAIBacked: aiRecommendation != nil
            )
        }
    }

    private var displayName: String {
        authManager.currentAccountName ?? "Speaker"
    }

    private var heroTitle: String {
        displayName == "Guest Speaker" ? "Guest" : displayName
    }

    private var heroSubtitle: String {
        let sessions = sessionStore.sessions

        // 1. No sessions at all
        if sessions.isEmpty {
            return "One rep sets your baseline"
        }

        // 2. Seven-day streak or higher
        if sessionStreak >= 7 {
            return "\(sessionStreak)-day streak — that's a habit"
        }

        // 3. Three-day streak or higher
        if sessionStreak >= 3 {
            return "\(sessionStreak) days in a row — building a habit"
        }

        // 4. Filler trend (need at least 10 sessions for two groups of 5)
        if sessions.count >= 10 {
            let recentFillers = sessions.prefix(5).map { Double($0.fillerWordCount) }
            let previousFillers = sessions.dropFirst(5).prefix(5).map { Double($0.fillerWordCount) }
            let recentAvg = recentFillers.reduce(0, +) / Double(recentFillers.count)
            let previousAvg = previousFillers.reduce(0, +) / Double(previousFillers.count)
            if recentAvg < previousAvg {
                return "Your filler count is trending down"
            }
        }

        // 5. Score trend (need at least 6 scored sessions for two groups of 3)
        let scored = sessions.filter { $0.score != nil }
        if scored.count >= 6 {
            let recentScores = scored.prefix(3).compactMap(\.score).map(Double.init)
            let previousScores = scored.dropFirst(3).prefix(3).compactMap(\.score).map(Double.init)
            if !recentScores.isEmpty && !previousScores.isEmpty {
                let recentAvg = recentScores.reduce(0, +) / Double(recentScores.count)
                let previousAvg = previousScores.reduce(0, +) / Double(previousScores.count)
                if recentAvg > previousAvg {
                    return "Your scores are climbing"
                }
            }
        }

        // 6. Practiced today
        if sessionStreak == 1 {
            return "Already practiced today — stack a second rep"
        }

        // 7. Last session was yesterday
        if daysSinceLastSession == 1 {
            return "Welcome back — keep the momentum"
        }

        // 8. Been a few days
        if daysSinceLastSession >= 3 {
            return "Ready to pick up where you left off?"
        }

        // 9. Default
        return "Every rep makes you sharper"
    }

    /// Time-of-day-aware greeting that feels like the coach is reading
    /// the user's day, not just dropping a generic "Hello". Streak +
    /// recency shape the variant chosen.
    private var heroGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let streak = sessionStreak
        // Lapsed user: name the absence first, before the time of day.
        if daysSinceLastSession >= 3, !sessionStore.sessions.isEmpty {
            return "Welcome back"
        }
        // Late-night reps: read the discipline.
        if hour >= 22 || hour < 5 { return "Late rep" }
        // Streak-aware morning frame.
        if hour < 12 {
            return streak >= 3 ? "Morning, day \(streak)" : "Good morning"
        }
        if hour < 17 { return "Good afternoon" }
        return streak >= 3 ? "Evening, day \(streak)" : "Good evening"
    }

    /// Mood for the hero's coach character. Excited only on long
    /// streaks (≥7 days) so the moment lands; everything else stays
    /// calm to keep the home grounded.
    private var heroCharacterMood: NoumCharacter.Mood {
        sessionStreak >= 7 ? .excited : .calm
    }

    /// Tint for the hero's gradient. Alive streak pulls toward brand
    /// blue; lapsed users get a softer tint so the surface doesn't
    /// shame them on a return rep.
    private var heroGradientTint: Color {
        let streak = sessionStreak
        if daysSinceLastSession >= 3 { return AppColor.brandBlue.opacity(0.6) }
        if streak >= 7 { return AppColor.brandBlue }
        if streak >= 3 { return AppColor.brandBlue.opacity(0.85) }
        return AppColor.brandBlue.opacity(0.7)
    }

    private var heroCard: some View {
        let collapseFactor = max(0, 1 + (homeScrollOffset / 42))
        return ZStack(alignment: .topLeading) {
            // Soft tinted gradient. Subtler than a full card so the
            // hero feels like a header, not a banner ad.
            LinearGradient(
                colors: [
                    heroGradientTint.opacity(0.10),
                    heroGradientTint.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))

            // Coach character. Composes SF Symbols (waveform + halo +
            // glow) into a presence that breathes. Mood adapts to streak
            // state — excited when on a streak, calm otherwise. Per the
            // design rules: motion + color + shape, no illustration.
            NoumCharacter(
                mood: heroCharacterMood,
                tint: heroGradientTint,
                size: 76
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, Spacing.sm)
            .padding(.top, -10)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text("\(heroGreeting), \(heroTitle)")
                        .font(Typography.sectionHero)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if sessionStreak > 0 {
                        streakChip(streak: sessionStreak)
                    }
                }
                Text(heroSubtitle)
                    .font(Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: max(0, 104 + min(0, homeScrollOffset)))
        .opacity(collapseFactor)
        .clipped()
    }

    private func streakChip(streak: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.caption2.weight(.bold))
            Text("\(streak)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.standardSpring, value: streak)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.12), in: Capsule(style: .continuous))
        .accessibilityLabel("\(streak)-day streak")
    }

    // MARK: - First Session

    private var firstSessionWelcomeMessage: String {
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
        return "One short rep is all it takes to set your starting line."
    }

    private var firstSessionCard: some View {
        Button { navigationPath.append(AppDestination.timedPractice) } label: {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Find your starting point")
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)

                    Text(firstSessionWelcomeMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Text("Start your first rep")
                        .font(.headline.weight(.semibold))

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 44, height: 44)

                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, Spacing.md)
                .background(
                    LinearGradient(
                        colors: [AppColor.brandBlue, AppColor.brandBlue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule(style: .continuous)
                )

                Text("Your first rep sets your baseline \u{2014} no pressure")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColor.brandBlue.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("home.firstSession")
    }

    // MARK: - Secondary discovery (empty state)

    /// Compact two-row card used only in the empty state. Surfaces lessons
    /// + path as a *discovery* surface so the new user sees the curriculum
    /// exists, but neither row competes with the primary "Start your first
    /// rep" CTA. Intentionally lower visual weight than the firstSessionCard.
    private var secondaryDiscoveryCard: some View {
        VStack(spacing: 0) {
            discoveryRow(
                icon: "books.vertical.fill",
                title: "Bite-sized lessons",
                subtitle: "Three steps. Two minutes. Earn a crown.",
                tint: AppColor.brandBlue,
                destination: .lessons,
                accessibilityID: "home.discovery.lessons"
            )
            Divider().padding(.leading, 60)
            discoveryRow(
                icon: "signpost.right.fill",
                title: "Your path",
                subtitle: "Clear nodes by hitting concrete goals.",
                tint: AppColor.positive,
                destination: .pathJourney,
                accessibilityID: "home.discovery.path"
            )
        }
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    private func discoveryRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        destination: AppDestination,
        accessibilityID: String
    ) -> some View {
        Button {
            navigationPath.append(destination)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

    // MARK: - Next Lesson

    /// "Your next lesson" home card. Picks the lesson the user should
    /// work on next from `LessonStore.nextRecommendedLesson`. Shows the
    /// crown progress on the picked lesson + a one-tap CTA that opens
    /// the lesson directly. Hides itself when every lesson is mastered.
    @ViewBuilder
    private var nextLessonCard: some View {
        if let lesson = LessonStore.shared.nextRecommendedLesson {
            let crowns = LessonStore.shared.crownLevel(for: lesson.id)
            Button {
                navigationPath.append(AppDestination.lesson(id: lesson.id))
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(AppColor.brandBlue.opacity(0.14))
                            .frame(width: 46, height: 46)
                        Image(systemName: lesson.symbolName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColor.brandBlue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(crowns == 0 ? "Next lesson" : "Earn another crown")
                            .font(Typography.micro)
                            .foregroundStyle(AppColor.brandBlue)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        Text(lesson.title)
                            .font(Typography.cardTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(lesson.tagline)
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        crownPips(crowns: crowns)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColor.brandBlue)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 14)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(Color.white.opacity(0.75), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.nextLesson")
        }
    }

    private func crownPips(crowns: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<LessonStore.crownCap, id: \.self) { i in
                Image(systemName: i < crowns ? "crown.fill" : "crown")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(i < crowns ? AppColor.brandBlue : Color.secondary.opacity(0.30))
            }
        }
    }

    // MARK: - Quick Start

    private var quickStartCard: some View {
        let suggestion = effectiveSuggestion
        return Button { navigationPath.append(practiceAppDestination(for: suggestion)) } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(suggestion.tint.gradient)
                        .frame(width: 52, height: 52)
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Quick start")
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                    Text(suggestion.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(suggestion.tint)
            }
            .padding(Spacing.md)
            .background(
                LinearGradient(
                    colors: [suggestion.tint.opacity(0.10), suggestion.tint.opacity(0.04)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(suggestion.tint.opacity(0.18), lineWidth: 1)
            )
        }
        .simultaneousGesture(TapGesture().onEnded {
            selectedPracticeMode = suggestion.mode
            recommendationLearningStore.markTapped(mode: suggestion.mode)
        })
        .buttonStyle(.pressable)
        .accessibilityIdentifier("home.quickStart")
    }

    // MARK: - Streak Card

    /// Compact streak pill with optional freeze badge. Replaces the legacy
    /// `streakChallengeCard` — the "today's challenge" half is now covered by
    /// `DailyGoalCard`, which makes the source of truth singular.
    private var streakCard: some View {
        let streak = streakFreeze.currentStreak
        let isAlive = streak > 0
        let savedByFreeze = streakFreeze.freezeJustConsumedToday

        return Button {
            if savedByFreeze { streakFreeze.consumeFreezeNudge() }
            navigationPath.append(AppDestination.friendLeaderboard)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isAlive ? .orange : Color.secondary.opacity(0.4))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(streak)")
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(isAlive ? .orange : .secondary)
                        .contentTransition(.numericText())
                        .animation(.standardSpring, value: streak)
                    Text(savedByFreeze ? "Saved by a freeze" : "day streak")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(savedByFreeze ? AppColor.brandBlue : .secondary)
                }

                Spacer()

                if streakFreeze.freezesAvailable > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "snowflake")
                            .font(.caption.weight(.bold))
                        Text("Freeze")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
                    .accessibilityLabel("Streak freeze available")
                    .accessibilityHint("One free miss this week is automatically protected.")
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(streak) day streak")
        .accessibilityHint("Open the weekly leaderboard.")
    }

    private var progressCard: some View {
        Button { navigationPath.append(AppDestination.socialProfile) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: rankSymbol)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(rankTint)
                        .frame(width: 46, height: 46)
                        .background(rankTint.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speaking Rank")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(rankTitle)
                            .font(Typography.bigStat)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Open progress, unlocked achievements, and recent coaching insights")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(nextRankTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Text(levelProgressLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                    }

                    ShimmerProgressBar(progress: profile.progressTowardsNextLevel, tint: AppColor.brandBlue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(ProfileManager.xpNeededToNextLevel(forXP: profile.xp)) XP to level up")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Text(retentionSnapshot.activeChallenge.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(rankTint)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()

                        Text(retentionSnapshot.activeChallenge.progressLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                }
            }
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 164)
            .padding(Spacing.lg)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.rank")
    }

    private var suggestedPracticeCard: some View {
        let primary = effectiveSuggestion

        return VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Practice")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            
            suggestionLink(
                suggestion: primary,
                systemImage: primary.mode.iconName
            )

            coachingFocusCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .fill(AppColor.cardBackground)
                    .shadow(color: primary.tint.opacity(0.08), radius: 12, x: 0, y: 4)

                AppColor.cardBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.8), primary.tint.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
    }

    /// "Your next node" home surface. The header area pushes the full path
    /// on tap; the inline CTA capsule jumps straight to the action that
    /// progresses *this* node, so the user never has to stop at the path
    /// map. The two affordances live as sibling buttons (no nesting) so
    /// hit-testing is unambiguous.
    private var journeyPreviewCard: some View {
        let status = pathProgress.currentNode
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                navigationPath.append(AppDestination.pathJourney)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: status?.node.symbolName ?? "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColor.positive)
                        .frame(width: 46, height: 46)
                        .background(
                            AppColor.positive.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(status == nil ? "Path cleared" : "Your next node")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColor.positive)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Text(status?.node.title ?? "Defend your gains")
                            .font(Typography.cardTitle)
                            .foregroundStyle(.primary)
                        Text(status?.node.coachLine ?? "You've cleared every node. Hold the path with one rep a day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("home.path.nextMilestone")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.path")

            if let status, status.progress > 0 && !status.isComplete {
                ProgressView(value: status.progress)
                    .progressViewStyle(.linear)
                    .tint(AppColor.positive)
            }

            HStack(spacing: 8) {
                Spacer()
                if let status {
                    Button {
                        navigationPath.append(status.node.actionDestination)
                    } label: {
                        HStack(spacing: 4) {
                            Text(status.node.actionLabel)
                                .font(.caption.weight(.bold))
                            Image(systemName: "arrow.right")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColor.positive, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.path.action")
                } else {
                    Button {
                        navigationPath.append(AppDestination.pathJourney)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Open path")
                                .font(.caption.weight(.bold))
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(AppColor.positive)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        )
    }

    private var bottomNavigation: some View {
        HStack(spacing: 10) {
            Group {
                Button { navigationPath.append(AppDestination.practiceSelection) } label: {
                    navItem(title: "Train", systemImage: "dumbbell.fill", accent: .blue)
                }
                .accessibilityIdentifier("nav.practice")

                Button { navigationPath.append(AppDestination.sessionHistory) } label: {
                    navItem(title: "Review", systemImage: "book.fill", accent: .orange)
                }
                .accessibilityIdentifier("nav.history")

                Button { navigationPath.append(AppDestination.socialProfile) } label: {
                    navItem(title: "Profile", systemImage: "person.fill", accent: .purple)
                }
                .accessibilityIdentifier("nav.social")

                Button { navigationPath.append(AppDestination.settings) } label: {
                    navItem(title: "Settings", systemImage: "slider.horizontal.3", accent: .green)
                }
                .accessibilityIdentifier("nav.settings")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func suggestionLink(
        suggestion: PracticeSuggestion,
        systemImage: String
    ) -> some View {
        Button {
            selectedPracticeMode = suggestion.mode
            recommendationLearningStore.markTapped(mode: suggestion.mode)
            navigationPath.append(practiceAppDestination(for: suggestion))
        } label: {
            HStack(alignment: .center, spacing: 14) {
                PulseBadge(systemImage: systemImage, tint: suggestion.tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(suggestionSubtitle(for: suggestion))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text(primaryActionLabel)
                        .font(.caption.weight(.bold))
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(suggestion.tint, in: Capsule())
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [
                        suggestion.tint.opacity(0.10),
                        suggestion.tint.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(suggestion.tint.opacity(0.10), lineWidth: 1)
            )
        }
    }

    private var coachingFocusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lastAction = LastNextActionSnapshot.load() {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                    Text("Your next move")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                Text(lastAction.reasoning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(recommendedPracticeSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private func navItem(title: String, systemImage: String, accent: Color) -> some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
                    .symbolEffect(.pulse, options: .repeating.speed(0.6))
            }
            Text(title)
                .font(Typography.nav)
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(accent.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private var primarySuggestion: PracticeSuggestion {
        let sessions = sessionStore.sessions
        let plan = CoachingPlanner.plan(for: sessions, profile: coachingProfileStore.profile)

        guard let latest = sessions.first else {
            return PracticeSuggestion(
                title: "Start with a clean baseline rep",
                detail: "Timed rep to establish your baseline.",
                focus: "Baseline",
                target: "Clean rep",
                mode: .timed,
                recommendedTone: nil,
                recommendedScenario: nil,
                benefit: RecommendationBiasEngine.playbook.first(where: { $0.mode == .timed })?.benefit ?? "Best for establishing a clean baseline.",
                tint: .blue
            )
        }

        let recent = Array(sessions.prefix(5))
        let averageFillers = Double(recent.map(\.fillerWordCount).reduce(0, +)) / Double(recent.count)
        let averagePace = Double(recent.map(\.wordsPerMinute).reduce(0, +)) / Double(recent.count)
        let averageDuration = recent.map(\.duration).reduce(0, +) / Double(recent.count)
        let timedSnapshot = modeSnapshot(for: .timed, sessions: recent)
        let suddenDeathSnapshot = modeSnapshot(for: .suddenDeath, sessions: recent)
        let ahCounterSnapshot = modeSnapshot(for: .ahCounter, sessions: recent)
        let targetFillers = max(0, Int(floor(min(averageFillers, Double(latest.fillerWordCount)) - 1)))
        let strongControl = averageFillers <= 1.5 && latest.fillerWordCount <= 1 && averageDuration >= 30
        let rushedDelivery = averagePace >= 155 || latest.wordsPerMinute >= 165
        let shortAnswers = averageDuration < 25 || latest.duration < 25
        let fillerPressure = averageFillers >= 4 || latest.fillerWordCount >= 5

        if strongControl {
            let mode: PracticeMode = suddenDeathSnapshot.count > 0 ? .suddenDeath : .timed
            return PracticeSuggestion(
                title: mode == .suddenDeath ? "Step up into pressure" : "Push a sharper timed rep",
                detail: mode == .suddenDeath
                    ? "Your filler control is strong enough to push into a harder mode."
                    : "Your control is steady. Push for a cleaner, firmer timed answer.",
                focus: "Pressure",
                target: mode == .suddenDeath ? "Zero fillers" : "35s+",
                mode: mode,
                recommendedTone: nil,
                recommendedScenario: nil,
                benefit: RecommendationBiasEngine.playbook.first(where: { $0.mode == mode })?.benefit ?? "",
                tint: AppColor.tint(for: mode)
            )
        }

        if fillerPressure {
            return PracticeSuggestion(
                title: "Clean up the next opening",
                detail: "Too many fillers usually means the pressure is too high right now.",
                focus: "Cleaner opening",
                target: "\(targetFillers) fillers or less",
                mode: timedSnapshot.averageScore >= ahCounterSnapshot.averageScore ? .timed : .ahCounter,
                recommendedTone: nil,
                recommendedScenario: nil,
                benefit: RecommendationBiasEngine.playbook.first(where: { $0.mode == (timedSnapshot.averageScore >= ahCounterSnapshot.averageScore ? .timed : .ahCounter) })?.benefit ?? "",
                tint: timedSnapshot.averageScore >= ahCounterSnapshot.averageScore ? .blue : .green
            )
        }

        if rushedDelivery {
            return PracticeSuggestion(
                title: "Slow the pace without losing control",
                detail: "The message is getting rushed, so the next rep should train calmer spacing.",
                focus: "Pacing",
                target: "<150 WPM",
                mode: .ahCounter,
                recommendedTone: nil,
                recommendedScenario: nil,
                benefit: RecommendationBiasEngine.playbook.first(where: { $0.mode == .ahCounter })?.benefit ?? "",
                tint: .green
            )
        }

        if shortAnswers {
            return PracticeSuggestion(
                title: "Extend the next answer",
                detail: "Your answers are ending too early to build real speaking stamina.",
                focus: "Longer answer",
                target: "30s+",
                mode: .timed,
                recommendedTone: nil,
                recommendedScenario: nil,
                benefit: RecommendationBiasEngine.playbook.first(where: { $0.mode == .timed })?.benefit ?? "",
                tint: .blue
            )
        }

        if let plan, plan.strongestMode == .suddenDeath, suddenDeathSnapshot.averageFillers <= 2.0 {
            return PracticeSuggestion(
                title: "Lean into the pressure rep",
                detail: "Recent sudden-death runs suggest you can handle more pressure.",
                focus: "Pressure",
                target: "Zero fillers",
                mode: .suddenDeath,
                recommendedTone: nil,
                recommendedScenario: nil,
                benefit: RecommendationBiasEngine.playbook.first(where: { $0.mode == .suddenDeath })?.benefit ?? "",
                tint: .orange
            )
        }

        if timedSnapshot.count >= 3 && timedSnapshot.averageFillers <= 2.5 && timedSnapshot.averageDuration >= 30 {
            return PracticeSuggestion(
                title: "Graduate to a harder rep",
                detail: "Your timed sessions are stable enough to turn the pressure up.",
                focus: "Pressure",
                target: "Zero fillers",
                mode: .suddenDeath,
                recommendedTone: nil,
                recommendedScenario: nil,
                benefit: RecommendationBiasEngine.playbook.first(where: { $0.mode == .suddenDeath })?.benefit ?? "",
                tint: .orange
            )
        }

        let bias = recommendationBiasBlueprint
        return PracticeSuggestion(
            title: bias.recommendedMode == .imConversation ? "Train the live interaction" : (plan?.strongestMode == .ahCounter ? "Keep the delivery composed" : "Keep the streak deliberate"),
            detail: plan?.encouragement ?? bias.whyNow,
            focus: bias.focus,
            target: bias.target,
            mode: bias.recommendedMode,
            recommendedTone: bias.recommendedTone,
            recommendedScenario: bias.recommendedScenario,
            benefit: bias.modeBenefit,
            tint: AppColor.tint(for: bias.recommendedMode),
            suggestedTimedDifficulty: bias.suggestedTimedDifficulty,
            suggestedTheme: bias.suggestedTheme
        )
    }

    private var effectiveSuggestion: PracticeSuggestion {
        guard let aiRecommendation,
              let mode = PracticeMode(rawValue: aiRecommendation.recommendedMode) else {
            return normalizedSuggestion(primarySuggestion)
        }

        let bias = recommendationBiasBlueprint
        return normalizedSuggestion(PracticeSuggestion(
            title: aiRecommendation.title,
            detail: aiRecommendation.detail,
            focus: aiRecommendation.focus,
            target: aiRecommendation.target,
            mode: mode,
            recommendedTone: aiRecommendation.recommendedTone.flatMap(IMTargetTone.init(rawValue:)) ?? bias.recommendedTone,
            recommendedScenario: aiRecommendation.recommendedScenario.flatMap(IMConversationScenario.init(rawValue:)) ?? bias.recommendedScenario,
            benefit: aiRecommendation.modeBenefit.isEmpty ? bias.modeBenefit : aiRecommendation.modeBenefit,
            tint: AppColor.tint(for: mode)
        ))
    }

    private var sessionsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        return sessionStore.sessions.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }.count
    }

    private var averageFillersText: String {
        guard !sessionStore.sessions.isEmpty else { return "0.0" }
        let recent = Array(sessionStore.sessions.prefix(5))
        let average = Double(recent.map(\.fillerWordCount).reduce(0, +)) / Double(recent.count)
        return String(format: "%.1f", average)
    }

    private var averagePaceText: String {
        guard !sessionStore.sessions.isEmpty else { return "--" }
        let recent = Array(sessionStore.sessions.prefix(5))
        let average = Double(recent.map(\.wordsPerMinute).reduce(0, +)) / Double(recent.count)
        return "\(Int(average.rounded())) WPM"
    }

    private var recommendationBiasBlueprint: RecommendationBiasBlueprint {
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
            recentSessionSummary: recentSessionSummary(from: recent),
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

    private var primaryTargetText: String {
        effectiveSuggestion.target
    }

    private var primaryActionLabel: String {
        switch effectiveSuggestion.mode {
        case .timed:
            return "Start"
        case .suddenDeath:
            return "Begin"
        case .ahCounter:
            return "Start"
        case .imConversation:
            return "Begin"
        }
    }

    /// Routes a `noum://` URL to the right destination on the navigation
    /// path. Called when `DeepLinkRouter.pending` changes (set by
    /// `NoumApp.onOpenURL`). Clears the pending URL after consumption so
    /// it doesn't fire twice.
    private func consumeDeepLink(_ url: URL) {
        defer { deepLinkRouter.pending = nil }
        guard url.scheme == "noum" else { return }
        let host = url.host ?? ""
        let path = url.path
        switch host {
        case "lesson":
            // noum://lesson/<id>
            let lessonID = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !lessonID.isEmpty,
                  LessonsCatalog.lesson(id: lessonID) != nil else { return }
            navigationPath.append(AppDestination.lesson(id: lessonID))
        case "practice":
            navigationPath.append(AppDestination.practiceSelection)
        case "league":
            navigationPath.append(AppDestination.league)
        case "path":
            navigationPath.append(AppDestination.pathJourney)
        case "lessons":
            navigationPath.append(AppDestination.lessons)
        case "friend":
            // Add the inviter as a friend immediately, then surface the
            // profile so the user sees the new entry. `acceptInvite`
            // is idempotent — re-scanning the same URL is a no-op.
            FriendsManager.shared.acceptInvite(from: url)
            navigationPath.append(AppDestination.socialProfile)
        default:
            // Unrecognised — no-op rather than crash.
            break
        }
    }

    /// The node that was just newly-unlocked, if any. Drives the path
    /// celebration overlay. Cleared by `pathProgress.consumeCelebration()`.
    private var pendingPathCelebration: PathNode? {
        guard let id = pathProgress.pendingCelebrationNodeID else { return nil }
        return PathNodeRegistry.all.first(where: { $0.0.id == id })?.0
    }

    private var retentionSnapshot: RetentionLoopSnapshot {
        RetentionLoopEngine.snapshot(
            sessions: sessionStore.sessions,
            profile: coachingProfileStore.profile
        )
    }

    private var recommendedPracticeSummary: String {
        let recent = Array(sessionStore.sessions.prefix(5))
        guard let latest = recent.first else {
            return "This is the best next rep to establish a useful speaking baseline."
        }

        let averageFillers = Double(recent.map(\.fillerWordCount).reduce(0, +)) / Double(recent.count)
        let averageDuration = recent.map(\.duration).reduce(0, +) / Double(recent.count)
        let averagePace = Double(recent.map(\.wordsPerMinute).reduce(0, +)) / Double(recent.count)
        let timedSnapshot = modeSnapshot(for: .timed, sessions: recent)
        let suddenDeathSnapshot = modeSnapshot(for: .suddenDeath, sessions: recent)
        let ahCounterSnapshot = modeSnapshot(for: .ahCounter, sessions: recent)

        switch effectiveSuggestion.mode {
        case .timed:
            if averageDuration < 25 || latest.duration < 25 {
                return "Recent answers have been short, so timed reps should help you finish thoughts more completely."
            }
            if timedSnapshot.count > 0 && timedSnapshot.averageScore >= max(suddenDeathSnapshot.averageScore, ahCounterSnapshot.averageScore) {
                return "Your strongest recent sessions have come in timed mode, so this rep builds on what is already working."
            }
            return "Your recent history suggests you need more structure, and timed reps are the clearest place to build it."
        case .suddenDeath:
            if suddenDeathSnapshot.count > 0 && suddenDeathSnapshot.averageFillers <= 2 {
                return "Your recent pressure reps have held up well, so this is the right time to push the difficulty higher."
            }
            return "Your recent sessions look steadier, so a pressure rep is the next useful test of control."
        case .ahCounter:
            if averagePace >= 155 || latest.wordsPerMinute >= 165 {
                return "Recent sessions have been rushed, so this rep should help you slow down and create more space."
            }
            if averageFillers >= 4 || latest.fillerWordCount >= 5 {
                return "Recent sessions show filler pressure, so this rep should help you clean up the opening."
            }
            return "Your recent history points to pacing and filler control as the next thing to tighten."
        case .imConversation:
            return "Recent sessions suggest the next gain is applying your delivery in a more realistic live conversation."
        }
    }

    private var recommendationCacheKey: String {
        let recent = sessionStore.sessions.prefix(5).map { session in
            "\(session.id.uuidString)-\(session.mode.rawValue)-\(session.fillerWordCount)-\(Int(session.duration))-\(session.score ?? 0)"
        }.joined(separator: "|")
        let profileKey = coachingProfileStore.profile.map {
            "\($0.primaryGoal.rawValue)-\($0.biggestChallenge.rawValue)-\($0.desiredOutcome.rawValue)-\($0.speakingStyleGoal.rawValue)"
        } ?? "no-profile"
        return "homeRecommendation.\(profileKey).\(recent)"
    }

    private func refreshHomeRecommendation() async {
        if let cached = loadCachedRecommendation(for: recommendationCacheKey) {
            aiRecommendation = cached
            return
        }

        guard sessionStore.sessions.count >= AIHomeRecommendationService.minimumSessionCount,
              aiSettings.canRequestAnalysis else {
            aiRecommendation = nil
            return
        }

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
            recentSessionSummary: recentSessionSummary(from: recent),
            averageFillers: Double(recent.map(\.fillerWordCount).reduce(0, +)) / Double(recent.count),
            averageDuration: recent.map(\.duration).reduce(0, +) / Double(recent.count),
            averageWordsPerMinute: Double(recent.map(\.wordsPerMinute).reduce(0, +)) / Double(recent.count),
            fillerTrendDelta: trendDelta(
                current: recent.map { Double($0.fillerWordCount) },
                previous: previous.map { Double($0.fillerWordCount) }
            ),
            durationTrendDelta: trendDelta(
                current: recent.map(\.duration),
                previous: previous.map(\.duration)
            ),
            paceTrendDelta: trendDelta(
                current: recent.map { Double($0.wordsPerMinute) },
                previous: previous.map { Double($0.wordsPerMinute) }
            ),
            averageWordCount: Double(recent.map(\.wordCount).reduce(0, +)) / Double(recent.count),
            strongestMode: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)?.strongestMode,
            currentIdentity: identity.identity,
            currentIdentityEvidence: identity.evidence,
            styleAlignmentScore: styleTrend.currentAlignment,
            sessionStreak: sessionStreak,
            daysSinceLastSession: daysSinceLastSession,
            preferredModeBias: recommendationBiasBlueprint.recommendedMode.rawValue,
            preferredToneBias: recommendationBiasBlueprint.recommendedTone?.rawValue ?? "",
            preferredScenarioBias: recommendationBiasBlueprint.recommendedScenario?.rawValue ?? "",
            modeBenefitBias: recommendationBiasBlueprint.modeBenefit
        )

        do {
            let recommendation = try await aiHomeRecommendationService.generateHomeRecommendation(
                input: input,
                profile: coachingProfileStore.profile,
                plan: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)
            )
            aiRecommendation = recommendation
            cacheRecommendation(recommendation, for: recommendationCacheKey)
        } catch {
            aiRecommendation = nil
        }
    }

    private func recentSessionSummary(from sessions: [PracticeSession]) -> String {
        sessions.enumerated().map { index, session in
            let scoreText = session.score.map(String.init) ?? "n/a"
            let pace = PracticeEvaluator.paceSnapshot(forTranscript: session.transcript, duration: session.duration)
            let identity = PracticeEvaluator.speakingIdentity(for: session.transcript, profile: coachingProfileStore.profile)
            return "Session \(index + 1): mode=\(session.mode.rawValue), fillers=\(session.fillerWordCount), duration=\(Int(session.duration))s, words=\(session.wordCount), wpm=\(session.wordsPerMinute), paceLabel=\(pace.label), score=\(scoreText), headline=\(session.headline ?? "none"), identity=\(identity.identity)"
        }.joined(separator: "\n")
    }

    private func loadCachedRecommendation(for key: String) -> AIHomeRecommendation? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let recommendation = try? JSONDecoder().decode(AIHomeRecommendation.self, from: data) else {
            return nil
        }
        return recommendation
    }

    private func cacheRecommendation(_ recommendation: AIHomeRecommendation, for key: String) {
        guard let data = try? JSONEncoder().encode(recommendation) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private var shownRecommendationFingerprint: String {
        let suggestion = effectiveSuggestion
        return "\(recommendationCacheKey).\(suggestion.mode.rawValue).\(suggestion.title).\(suggestion.focus).\(suggestion.target)"
    }

    private func trendDelta(current: [Double], previous: [Double]) -> Double {
        guard !current.isEmpty else { return 0 }
        let currentAverage = current.reduce(0, +) / Double(current.count)
        guard !previous.isEmpty else { return 0 }
        let previousAverage = previous.reduce(0, +) / Double(previous.count)
        return currentAverage - previousAverage
    }

    /// Single source of truth for the user-visible streak count: the
    /// `StreakFreezeManager`, which applies freezes. This used to be
    /// computed twice (raw calculation + freeze-applied) and the home
    /// could show two different numbers. Now both reads pull from here.
    private var sessionStreak: Int {
        streakFreeze.currentStreak
    }

    private var daysSinceLastSession: Int {
        guard let latest = sessionStore.sessions.first else { return 999 }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: latest.date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
    }

    private func modeSnapshot(for mode: PracticeMode, sessions: [PracticeSession]) -> ModeSnapshot {
        let matching = sessions.filter { $0.mode == mode }
        guard !matching.isEmpty else {
            return ModeSnapshot(
                mode: mode,
                count: 0,
                averageFillers: .greatestFiniteMagnitude,
                averageDuration: 0,
                averagePace: 0,
                averageScore: 0
            )
        }

        let averageFillers = Double(matching.map(\.fillerWordCount).reduce(0, +)) / Double(matching.count)
        let averageDuration = matching.map(\.duration).reduce(0, +) / Double(matching.count)
        let averagePace = Double(matching.map(\.wordsPerMinute).reduce(0, +)) / Double(matching.count)
        let scored = matching.compactMap(\.score)
        let averageScore = scored.isEmpty ? 0 : Double(scored.reduce(0, +)) / Double(scored.count)

        return ModeSnapshot(
            mode: mode,
            count: matching.count,
            averageFillers: averageFillers,
            averageDuration: averageDuration,
            averagePace: averagePace,
            averageScore: averageScore
        )
    }

    private func practiceAppDestination(for suggestion: PracticeSuggestion) -> AppDestination {
        if suggestion.mode == .timed {
            // Seed the theme picker with the goal-biased suggestion so the first
            // topic the user sees is matched to their coaching goal. User can still
            // change it inside the practice view.
            if suggestion.suggestedTheme != .all {
                UserDefaults.standard.set(
                    suggestion.suggestedTheme.rawValue,
                    forKey: "timedPractice.selectedTheme"
                )
            }
        }
        switch suggestion.mode {
        case .timed:
            return .timedPractice
        case .suddenDeath:
            return .suddenDeathPractice
        case .ahCounter:
            return .ahCounterPractice
        case .imConversation:
            if IMModeAvailability.isAvailable {
                return .imPractice(scenario: suggestion.recommendedScenario, tone: suggestion.recommendedTone)
            } else {
                return .timedPractice
            }
        }
    }

    private func normalizedSuggestion(_ suggestion: PracticeSuggestion) -> PracticeSuggestion {
        guard suggestion.mode == .imConversation, !IMModeAvailability.isAvailable else {
            return suggestion
        }

        return PracticeSuggestion(
            title: "Keep the next rep deliberate",
            detail: "Conversation mode is offline right now, so train the same control in a live speaking drill.",
            focus: "Consistency",
            target: "Clean rep",
            mode: .timed,
            recommendedTone: nil,
            recommendedScenario: nil,
            benefit: RecommendationBiasEngine.playbook.first(where: { $0.mode == .timed })?.benefit ?? "",
            tint: .blue
        )
    }

    private func suggestionSubtitle(for suggestion: PracticeSuggestion) -> String {
        guard suggestion.mode == .imConversation,
              let scenario = suggestion.recommendedScenario,
              let tone = suggestion.recommendedTone else {
            return "Mode: \(suggestion.mode.displayLabel)"
        }
        return "Mode: \(suggestion.mode.displayLabel) • \(scenario.title) • \(tone.title)"
    }

    // Rank helpers forwarded from ProfileManager extension (PracticeSupport.swift)
    private var levelProgressLabel: String { profile.levelProgressLabel }
    private var rankSymbol: String { profile.rankSymbol }
    private var rankTint: Color { profile.rankTint }
    private var rankDescriptor: String { profile.rankDescriptor }
    private var rankTitle: String { profile.rankTitle }
    private var nextRankTitle: String { profile.nextRankTitle }

}
#endif

#if canImport(SwiftUI)
#Preview {
    ContentView()
}
#endif
