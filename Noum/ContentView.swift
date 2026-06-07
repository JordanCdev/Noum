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

struct HomePeakGlowPresentation: Equatable {
    struct Stat: Equatable {
        let value: String
        let label: String
    }

    let headline: String
    let body: String
    let stats: [Stat]

    static func make(weekPeak: Int, current: Int, allTime: Int) -> HomePeakGlowPresentation {
        let peak = max(0, weekPeak)
        let currentRating = max(0, current)
        let allTimePeak = max(0, allTime)

        let body: String
        if currentRating < peak {
            body = "\(peak) is this week's best. Your current rating is \(currentRating)."
        } else if allTimePeak > peak {
            body = "\(peak) is this week's best. All-time is \(allTimePeak)."
        } else {
            body = "\(peak) is now your recorded high."
        }

        var stats = [
            Stat(value: "\(peak)", label: "This week's peak")
        ]
        if allTimePeak > peak {
            stats.append(Stat(value: "\(allTimePeak - peak)", label: "off all-time"))
        }

        return HomePeakGlowPresentation(
            headline: allTimePeak > peak
                ? "You raised this week's rating mark."
                : "You moved your rating mark.",
            body: body,
            stats: stats
        )
    }
}

// Home-only time-of-day ambient. The four buckets shift the canvas
// gradient softly through the day: warm-light mornings → cool airy
// middays → richer purple-pink evenings → deeper-saturated nights.
// Other screens keep `LightGradientBackground` from DesignSystem —
// this is home-only.
private enum HourBucket: Int {
    case morning, midday, evening, night

    static func current(date: Date = Date()) -> HourBucket {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:  return .morning
        case 11..<17: return .midday
        case 17..<22: return .evening
        default:      return .night
        }
    }

    var start: Color {
        switch self {
        case .morning: return Color(red: 0.961, green: 0.949, blue: 1.000)
        case .midday:  return Color(red: 0.969, green: 0.969, blue: 1.000)
        case .evening: return Color(red: 0.941, green: 0.929, blue: 0.980)
        case .night:   return Color(red: 0.914, green: 0.898, blue: 0.961)
        }
    }

    var end: Color {
        switch self {
        case .morning: return Color(red: 0.980, green: 0.980, blue: 0.988)
        case .midday:  return Color(red: 0.929, green: 0.949, blue: 1.000)
        case .evening: return Color(red: 0.980, green: 0.941, blue: 0.980)
        case .night:   return Color(red: 0.949, green: 0.929, blue: 0.980)
        }
    }
}

enum HomeAskNoumEvidenceCopy {
    static func line(sessionCount: Int) -> String {
        switch sessionCount {
        case ..<1:
            return "Give me one rep and I'll name the first lever worth training."
        case 1:
            return "I have one rep, so I'll keep the read light and concrete."
        case 2:
            return "I have two reps, so I'll compare carefully without overcalling a pattern."
        default:
            return "I read your recent reps first, then keep the answer focused."
        }
    }
}

struct HomeBottomShortcut: Identifiable, Equatable {
    enum Accent: String, Equatable {
        case practice
        case review
        case profile
        case settings
    }

    let id: String
    let title: String
    let systemImage: String
    let destination: AppDestination
    let accessibilityIdentifier: String
    let accent: Accent

    var accessibilityLabel: String {
        "Open \(title)"
    }

    static let all: [HomeBottomShortcut] = [
        HomeBottomShortcut(
            id: "train",
            title: "Train",
            systemImage: "dumbbell.fill",
            destination: .practiceSelection,
            accessibilityIdentifier: "nav.practice",
            accent: .practice
        ),
        HomeBottomShortcut(
            id: "review",
            title: "Review",
            systemImage: "book.fill",
            destination: .sessionHistory,
            accessibilityIdentifier: "nav.history",
            accent: .review
        ),
        HomeBottomShortcut(
            id: "profile",
            title: "Profile",
            systemImage: "person.fill",
            destination: .socialProfile,
            accessibilityIdentifier: "nav.social",
            accent: .profile
        ),
        HomeBottomShortcut(
            id: "settings",
            title: "Settings",
            systemImage: "slider.horizontal.3",
            destination: .settings,
            accessibilityIdentifier: "nav.settings",
            accent: .settings
        )
    ]
}

struct HomeAccessibilityModalGate: Equatable {
    var onboardingPresented = false
    var leaguePromotionPresented = false
    var dailyGoalCelebrationPresented = false
    var pathCelebrationPresented = false
    var goalRefreshPresented = false
    var notificationPromptPresented = false
    var bigMomentIntakePresented = false

    var suppressesUnderlyingHome: Bool {
        onboardingPresented
        || leaguePromotionPresented
        || dailyGoalCelebrationPresented
        || pathCelebrationPresented
        || goalRefreshPresented
        || notificationPromptPresented
        || bigMomentIntakePresented
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
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var bigMomentStore = BigMomentStore.shared
    @StateObject private var dailyGoal = DailyGoalManager.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var deferredCapture = DeferredProfileCaptureManager.shared
    @StateObject private var goalRefresh = GoalRefreshManager.shared
    @StateObject private var notificationPrePrompt = NotificationPrePromptManager.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared
    @StateObject private var league = LeagueManager.shared
    @StateObject private var ratingStore = RatingStore.shared
    // M15 Phase 4 — Home discipline. Off by default; users who want every
    // card from rep 1 can flip it in Settings → Practice.
    @AppStorage("practice.showAllHomeCards") private var showAllHomeCards: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPracticeMode: PracticeMode = .timed
    @State private var showDailyGoalCelebration = false
    @State private var showFreezeNudge = false
    @State private var aiRecommendation: AIHomeRecommendation?
    @State private var homeCelebrationVisible = false
    @State private var homeScrollOffset: CGFloat = 0
    @State private var navigationPath = NavigationPath()
    @State private var hourBucket: HourBucket = HourBucket.current()
    /// Proof moment loaded for the active path celebration. Stays nil
    /// until the async extraction resolves, at which point the
    /// celebration's `proofLine` row fades in. Cleared when the
    /// celebration is dismissed.
    @State private var pathCelebrationProof: ProofMoment? = nil
    @State private var showBigMomentIntake: Bool = false
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    private let isOnboardingUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING_ONBOARDING")
    private let launchedWithDeepLink = ProcessInfo.processInfo.arguments.contains("-DeepLink")
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

    private var homeAccessibilityIsSuppressed: Bool {
        HomeAccessibilityModalGate(
            onboardingPresented: isOnboardingUITesting,
            leaguePromotionPresented: league.pendingPromotion != nil,
            dailyGoalCelebrationPresented: showDailyGoalCelebration,
            pathCelebrationPresented: pendingPathCelebration != nil,
            goalRefreshPresented: goalRefresh.shouldPresent,
            notificationPromptPresented: notificationPrePrompt.pendingPrompt,
            bigMomentIntakePresented: showBigMomentIntake
        ).suppressesUnderlyingHome
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Time-of-day ambient — morning lavender / midday airy /
                // evening soft purple-pink / night deeper saturation.
                // Home-only; other screens keep LightGradientBackground.
                homeBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: HomeScrollOffsetKey.self, value: proxy.frame(in: .named("homeScroll")).minY)
                    }
                    .frame(height: 0)

                    VStack(spacing: Spacing.cardGap) {
                        if sessionStore.sessions.isEmpty {
                            // Empty-state — use the same coach-first floor as
                            // the signal-gated populated home. First screen:
                            // coach presence + Begin. Status, Ask Noum and
                            // progression surfaces unlock after signal instead
                            // of reading like a habit dashboard before the
                            // user has completed a rep.
                            let gate = homeCardGate
                            if gate.coachCard {
                                HomeCoachCard(
                                    navigationPath: $navigationPath,
                                    scrollOffset: homeScrollOffset,
                                    showsAskNoumShortcut: gate.askNoumShortcut
                                ).cardEntrance(0)
                            }
                            if let moment = bigMomentStore.pendingOutcomeCheckInMoment {
                                BigMomentOutcomeInlineCard(moment: moment).cardEntrance(1)
                            }
                            if showAllHomeCards {
                                secondaryDiscoveryCard.cardEntrance(3)
                            }
                        } else {
                            // Populated home — coach-led revamp.
                            //
                            // Default stack:
                            //  1. HomeCoachCard — coach voice, primary CTA.
                            //  2. journeyPreviewCard — next path move.
                            //  3. AIWeeklyInsightCard — only after three
                            //     current-week reps.
                            //
                            // Removed and where the surface still lives:
                            //  • DailyGoalCard / DailyChallengeTile —
                            //    attendance work stays in League and
                            //    notifications, not Home.
                            //  • streakCard — already in the hero chip.
                            //  • nextLessonCard — reachable via Path /
                            //    Review.
                            //  • progressCard — rank/level is identity,
                            //    lives on Profile.
                            //  • suggestedPracticeCard — duplicated the
                            //    quickStartCard's primary intent.
                            //  • VoiceMetricsCard — raw diagnostics live on
                            //    Profile/History, not the coach-led Home.
                            // Premium personal-best anchor — M14 demotion:
                            // this is no longer the always-on top card
                            // whenever there happens to be a current-week
                            // peak. It's a post-session glow that fades in
                            // for ~7s after the user finishes a rep that
                            // raised their week peak, then self-dismisses
                            // and stays gone until they earn a NEW peak.
                            //
                            // Why: rendering this whenever `isWeekPeakCurrent`
                            // was true meant the home opened with a victory
                            // lap before today's rep. That stole attention
                            // from the coach. Glow keeps the celebration
                            // honest — it only shows when something just
                            // happened. The full peak list still lives on
                            // Profile via `PeakRatingWallCard`.
                            if ratingStore.pendingPeakGlow && ratingStore.rating.hasRatedEvidence {
                                personalBestHeroCard
                                    .cardEntrance(0)
                                    .transition(.opacity)
                                    .task {
                                        // Reduced-motion users get a slightly
                                        // shorter window — the fade itself is
                                        // suppressed, so the card just
                                        // appears, sits, then disappears.
                                        let seconds: UInt64 = reduceMotion ? 5 : 7
                                        try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                                        if reduceMotion {
                                            ratingStore.markPeakGlowConsumed()
                                        } else {
                                            withAnimation(.easeInOut(duration: 0.45)) {
                                                ratingStore.markPeakGlowConsumed()
                                            }
                                        }
                                    }
                            }
                            // M15 Phase 4 — signal-gated composition. The
                            // Coach Card is the cold-start floor; the in-card
                            // coach-chat entry unlocks after one completed
                            // rep.
                            // Reversible from Settings via
                            // `practice.showAllHomeCards`.
                            let gate = homeCardGate
                            // M14 redesign: HomeCoachCard replaces the old
                            // heroCard + quickStartCard pair. One composed
                            // hero with NoumCharacter present, the coach's
                            // recommendation as primary copy, and a single
                            // Begin CTA. The recommendation pipeline
                            // (RecommendationBiasEngine + CoachingPlanner)
                            // feeds it directly — no new coaching logic.
                            if gate.coachCard {
                                HomeCoachCard(
                                    navigationPath: $navigationPath,
                                    scrollOffset: homeScrollOffset,
                                    showsAskNoumShortcut: gate.askNoumShortcut
                                ).cardEntrance(0)
                            }
                            if let moment = bigMomentStore.pendingOutcomeCheckInMoment {
                                BigMomentOutcomeInlineCard(moment: moment).cardEntrance(1)
                            }
                            // Path Journey — promoted to slot 3 as a second
                            // hero. The Path is the gameplay loop; "next
                            // move" framing belongs near the Coach Card, not
                            // at the bottom of the stack under the weekly
                            // digest. Rewritten with mission framing
                            // (Chapter <tier> · Mission X of N · node title).
                            if gate.journey {
                                journeyPreviewCard.cardEntrance(2)
                            }
                            if gate.aiWeeklyInsight {
                                AIWeeklyInsightCard(
                                    sessionStore: sessionStore,
                                    ratingStore: ratingStore,
                                    clutchWordStore: ClutchWordStore.shared,
                                    coachingProfileStore: coachingProfileStore
                                )
                                .cardEntrance(6)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenH)
                    // Generous top padding so when the user scrolls up, the
                    // first card doesn't render UNDER the
                    // dynamic island. The home hides its nav bar, so iOS
                    // doesn't apply a scroll-edge blur — content sits flat
                    // against the status bar by default. The extra padding
                    // ensures scrolled content stays below the island.
                    .padding(.top, Spacing.lg + Spacing.xs)
                    // Generous bottom inset so the last card never sits
                    // under the floating shortcut dock. The dock lives
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
                bottomShortcutDock
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
                case .paceTrainingPractice:
                    PaceTrainingView(navigationPath: $navigationPath)
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
                    ProfileView()
                case .pathJourney:
                    PathJourneyView()
                case .askNoum:
                    CoachSessionView(
                        sessionStore: sessionStore,
                        ratingStore: ratingStore,
                        coachingProfileStore: coachingProfileStore,
                        navigationPath: $navigationPath,
                        initialMode: .live
                    )
                case .askNoumTyped:
                    CoachSessionView(
                        sessionStore: sessionStore,
                        ratingStore: ratingStore,
                        coachingProfileStore: coachingProfileStore,
                        navigationPath: $navigationPath,
                        initialMode: .type
                    )
                case .growthLibrary:
                    GrowthLibraryView()
                case .sessionDetail(let sessionID):
                    // Resolve the session against the live store. The
                    // sessionDetail destination is deep-linked from the
                    // Growth Library (and any future surface that wants to
                    // open "the session behind this artifact"); if the
                    // session has been deleted since the artifact was
                    // recorded, fall back to the History list rather than
                    // crashing or rendering an empty card.
                    if let session = sessionStore.sessions.first(where: { $0.id == sessionID }) {
                        SessionHistoryDetailView(
                            session: session,
                            insights: CoachingPlanner.sessionInsights(
                                for: session,
                                comparedTo: sessionStore.sessions,
                                profile: coachingProfileStore.profile
                            )
                        )
                    } else {
                        SessionHistoryView(navigationPath: $navigationPath)
                    }
                case .bigMomentIntake:
                    BigMomentIntakeView()
                case .prepSession:
                    PrepSessionView(navigationPath: $navigationPath)
                case .suddenDeathDifficultyDetail(let difficulty):
                    SuddenDeathDifficultyRunsView(difficulty: difficulty)
                case .imScenarioDetail(let scenario):
                    IMScenarioDetailView(scenario: scenario, navigationPath: $navigationPath)
                }
            }
        }
        .accessibilityIdentifier("home.screen")
        .accessibilityHidden(homeAccessibilityIsSuppressed)
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
            // Guard: only show the path celebration when the user is on
            // the home root — not inside SummaryView's progression chain.
            // `pendingCelebrationNodeID` persists until consumed, so the
            // overlay fires once the user navigates back from the summary.
            if navigationPath.isEmpty, let unlockedNode = pendingPathCelebration {
                PathNodeCelebration(
                    node: unlockedNode,
                    onDismiss: {
                        pathProgress.consumeCelebration()
                    },
                    // Secondary CTA pushes the path view so the user can
                    // see the just-unlocked node in context.
                    onOpenPath: {
                        pathProgress.consumeCelebration()
                        navigationPath.append(AppDestination.pathJourney)
                    },
                    // Proof moment — the rep that triggered the unlock
                    // is the most recent session. Pulls a transcript-
                    // anchored quote + technique label tied to the
                    // user's voice goal. Loaded on appear and hydrates
                    // mid-celebration; if it doesn't resolve in time,
                    // the proof line stays hidden (celebration renders
                    // without it). See `pathCelebrationProof`.
                    proof: pathCelebrationProof
                )
                .transition(.opacity)
                .zIndex(99)
                .onAppear {
                    Task { await loadPathCelebrationProof() }
                }
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
        // Big Moment intake — fires once after onboarding completes (new
        // accounts) or on noum://bigmoment deep link. Never blocks: Skip
        // clears the state without saving.
        .sheet(isPresented: $showBigMomentIntake) {
            BigMomentIntakeView()
        }
        .onChange(of: coachingProfileStore.profile) { old, new in
            // Fire BigMoment intake once after a brand-new profile is saved
            // (old == nil, new != nil). Skip if a moment is already set or
            // if the intake is already showing. Do not steal focus from a
            // direct route like Ask Noum; the intake is a home-root prompt.
            if old == nil, new != nil,
               !launchedWithDeepLink,
               !deepLinkRouter.hasReceivedRouteThisLaunch,
               navigationPath.isEmpty,
               deepLinkRouter.pending == nil,
               BigMomentStore.shared.activeMoment == nil,
               !showBigMomentIntake {
                showBigMomentIntake = true
            }
        }
        .onChange(of: deepLinkRouter.pending) { _, url in
            guard let url else { return }
            consumeDeepLink(url)
        }
        .onChange(of: dailyGoal.pendingGoalCelebration) { _, isPending in
            // Defer the daily goal celebration when the user is inside a
            // pushed destination (e.g. SummaryView's progression screen).
            // Showing it immediately stacks the overlay on top of the XP /
            // level-up / personal-best chain — visual collision. The
            // celebration fires once the user returns to the home root.
            if isPending && navigationPath.isEmpty {
                showDailyGoalCelebration = true
            }
        }
        .onChange(of: navigationPath) { _, newPath in
            // Deferred daily goal celebration: if the user was inside a
            // pushed view when the goal triggered, show it now that
            // they've returned to the home root.
            if newPath.isEmpty && dailyGoal.pendingGoalCelebration && !showDailyGoalCelebration {
                showDailyGoalCelebration = true
            }
        }
        .onAppear {
            bigMomentStore.archiveExpiredIfNeeded()
            dailyGoal.recompute()
            DailyChallengesManager.shared.ensureForToday()
            DailyChallengesManager.shared.recomputeReady()
            WordOfTheDayManager.shared.ensureForToday()
            refreshHourBucket()
            // Consume any deep link that was set before this view mounted
            // (e.g. `-DeepLink` launch arg handled in `NoumApp.init`).
            // `.onChange` only fires on subsequent mutations, so cold-start
            // URLs would otherwise be missed.
            if let url = deepLinkRouter.pending {
                consumeDeepLink(url)
            }
        }
        // Cheap 5-min poll so a long-lived session crosses a bucket
        // boundary smoothly. The fade between bucket gradients is the
        // .animation(_, value: hourBucket) on `homeBackground`.
        .onReceive(
            Timer.publish(every: 300, on: .main, in: .common).autoconnect()
        ) { _ in
            refreshHourBucket()
            bigMomentStore.archiveExpiredIfNeeded()
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

    /// Home-only ambient background. Other screens keep using
    /// `LightGradientBackground` from DesignSystem — this is a thin
    /// time-of-day-aware sibling that gives the home canvas its own
    /// quiet personality without pulling the rest of the app along.
    /// 1.2s ease-in-out fade between bucket boundaries keeps the
    /// transition soft. Reduce-motion: no fade, the new gradient
    /// snaps in but is still subtle enough to be invisible at-a-glance.
    private var homeBackground: some View {
        LinearGradient(
            colors: [hourBucket.start, hourBucket.end],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: hourBucket)
    }

    /// Re-evaluates the bucket from the wall clock. Setting the same
    /// value is a no-op (SwiftUI dedupes Equatable @State writes), so
    /// it's cheap to call from the 5-minute timer + onAppear.
    private func refreshHourBucket() {
        let next = HourBucket.current()
        if hourBucket != next {
            hourBucket = next
        }
    }

    // MARK: - M15 Phase 4 — Home card gate

    /// Read the live store state once per body invocation and produce the
    /// signal gate for Home. The Coach Card stays on at the floor; the rest
    /// unlock as signal accrues.
    /// `showAllHomeCards` (Settings) reveals active optional cards; retired
    /// Home surfaces stay off.
    private var homeCardGate: HomeCardGate {
        HomeSignalGate.evaluate(
            sessionCount: sessionStore.sessions.count,
            sessionsThisWeekCount: HomeSignalGate.sessionsInCurrentISOWeek(
                sessionDates: sessionStore.sessions.map(\.date)
            ),
            hasUnlockedPathNode: !pathProgress.completedNodes.isEmpty,
            hasCoachingProfile: coachingProfileStore.profile != nil,
            showAllOverride: showAllHomeCards
        )
    }

    // MARK: - Personal-best anchor (Figma "Premium Hero")
    //
    // M14: gated on `ratingStore.pendingPeakGlow`, which the store sets
    // briefly after a session finalize that raised the user's week peak.
    // The home wrap site auto-dismisses the card after ~7s via
    // `markPeakGlowConsumed()`, then the gate stays false until the user
    // earns a new peak. The copy and stats are still derived live from the
    // rating store so the card reflects what actually happened — never
    // invented. The full peak list (week + all-time + best-in-friends)
    // remains on Profile via `PeakRatingWallCard`.

    private var personalBestHeroCard: some View {
        let rating = ratingStore.rating
        let presentation = HomePeakGlowPresentation.make(
            weekPeak: rating.weekPeakRating,
            current: rating.overall,
            allTime: rating.peakRating
        )

        return PersonalBestHeroCard(
            kicker: "Personal best · this week",
            headline: presentation.headline,
            body: presentation.body,
            stats: presentation.stats.map { .init(value: $0.value, label: $0.label) },
            ctaTitle: "See your peaks",
            ctaAction: {
                navigationPath.append(AppDestination.socialProfile)
            }
        )
    }

    // MARK: - Secondary discovery (empty state)

    /// Compact two-row card used only in the empty state. Surfaces lessons
    /// + path as a *discovery* surface so the new user sees the curriculum
    /// exists, but neither row competes with the primary "Begin · First
    /// rep" CTA on the Coach Card above. Lower visual weight by design.
    private var secondaryDiscoveryCard: some View {
        VStack(spacing: 0) {
            discoveryRow(
                icon: "books.vertical.fill",
                title: "Bite-sized lessons",
                subtitle: "Three steps. Two minutes. Practice one move.",
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
    /// practice-pass progress on the picked lesson + a one-tap CTA that opens
    /// the lesson directly. Hides itself when every lesson is mastered.
    @ViewBuilder
    private var nextLessonCard: some View {
        if let lesson = LessonStore.shared.nextRecommendedLesson {
            let passCount = LessonStore.shared.practicePassCount(for: lesson.id)
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
                        Text(passCount == 0 ? "Next lesson" : "Strengthen lesson")
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
                        practicePassPips(completedPasses: passCount)
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

    private func practicePassPips(completedPasses: Int) -> some View {
        let progress = LessonProgressPresentation(completedPasses: completedPasses)
        return HStack(spacing: 3) {
            ForEach(0..<LessonStore.masteryPassCap, id: \.self) { i in
                Image(systemName: i < progress.completedPasses ? "checkmark.seal.fill" : "circle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(i < progress.completedPasses ? AppColor.brandBlue : Color.secondary.opacity(0.30))
            }
        }
        .accessibilityLabel(progress.accessibilityLabel)
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

    /// Path Journey card — M14 promotion. The Path is the gameplay loop;
    /// the previous small tile at the bottom of Home buried it. This is the
    /// second hero on populated home, sized between Coach Card and the
    /// utility cards, framed as a mission with explicit chapter + position.
    ///
    /// Layout:
    ///   • Header row — "YOUR JOURNEY" micro-label + Chapter <tier>.
    ///   • Mission counter — "Mission X of N" in body weight.
    ///   • Node title — 24pt rounded bold, the headline the user reads.
    ///   • Gating line — 1-2 lines of coach copy, the *concrete* distance
    ///     ("One rep from unlocked", "+88 rating to Platinum") sourced from
    ///     `PathProgressManager.currentNodeGatingPhrase`. Never shames a
    ///     regression — only renders forward distance.
    ///   • Progress bar (if 0 < progress < 1) — brand-blue tinted.
    ///   • CTA — "Open the Path →" capsule in brand-blue gradient.
    ///
    /// The whole card is a single button to the path destination; there's
    /// no node-level deep link because the destination *is* the next move
    /// surface. Brand-blue ambient wash + soft elevation give the card the
    /// "second hero" register, distinct from the Coach Card's Pro-purple
    /// without competing with it (blue = journey, purple = coach voice).
    /// Tier-adaptive tint for the journey card. Falls back to brand blue
    /// when the path is cleared (no current node).
    private var journeyTint: Color {
        pathProgress.currentNode?.node.tier.tint ?? AppColor.brandBlue
    }

    private var journeyPreviewCard: some View {
        let status = pathProgress.currentNode
        let cleared = status == nil
        let chapterTitle = status?.node.tier.title ?? "Mastery"
        let missionLine = journeyMissionLine(for: status)
        let titleLine = status?.node.title ?? "Path cleared"
        let gatingLine = journeyGatingLine(for: status)
        return Button {
            navigationPath.append(AppDestination.pathJourney)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header — micro-label on the left, chapter on the right.
                HStack(alignment: .firstTextBaseline) {
                    Text("Your journey")
                        .microLabel(journeyTint)
                    Spacer(minLength: Spacing.xs)
                    Text("Chapter \u{00B7} \(chapterTitle)")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Mission position — small, body-weight, never headline.
                Text(missionLine)
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("home.path.missionCounter")

                // Big rounded title — the node, but framed as a mission.
                Text(titleLine)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.path.missionTitle")

                // Gating line — concrete distance, coach voice.
                Text(gatingLine)
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.path.nextMilestone")

                if let status, status.progress > 0 && !status.isComplete {
                    ProgressView(value: status.progress)
                        .progressViewStyle(.linear)
                        .tint(journeyTint)
                        .padding(.top, Spacing.xxs)
                }

                // CTA row — single coach-voice action. The whole card
                // routes to the same destination, but the explicit capsule
                // anchors the user's eye and reads as a button.
                HStack(spacing: 6) {
                    Spacer()
                    Text(cleared ? "Hold the path" : "Open the Path")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    journeyTint.gradient,
                    in: Capsule(style: .continuous)
                )
                .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        }
        .buttonStyle(.pressable)
        .background(journeyHeroBackground)
        // Soft brand-blue elevation — mirrors the Coach Card's Pro-purple
        // shadow at the same intensity so the two heroes carry consistent
        // depth on the home canvas.
        .shadow(color: journeyTint.opacity(0.16), radius: 20, x: 0, y: 9)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.path")
        .accessibilityLabel(Text("\(titleLine). \(missionLine). \(gatingLine)"))
    }

    /// "Mission X of N" framing line. For the cleared state we celebrate
    /// the achievement without inventing a fake counter.
    private func journeyMissionLine(for status: PathNodeStatus?) -> String {
        let total = PathNodeRegistry.all.count
        guard let status else {
            return "All \(total) missions cleared"
        }
        let position = status.node.order + 1
        return "Mission \(position) of \(total)"
    }

    /// Hero card background — brand-blue ambient wash + frosted glass +
    /// hairline border. Mirrors the layered pattern used by HomeCoachCard
    /// (radial wash → material → border) in the blue register so the two
    /// heroes read as a matched pair rather than two different chrome
    /// languages. Reduce-motion users see a static wash; the motion-on
    /// path drifts the radial center across a slow 8s sine for the same
    /// "alive" feel the Coach Card carries, slightly slower so the two
    /// don't pulse in lockstep on the same screen.
    @ViewBuilder
    private var journeyHeroBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        let tint = journeyTint
        ZStack {
            shape.fill(AppColor.cardBackground)

            if reduceMotion {
                shape.fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(0.45),
                            tint.opacity(0.28),
                            tint.opacity(0.04),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.2, y: 0.0),
                        startRadius: 0,
                        endRadius: 320
                    )
                )
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    // 8s drift — slightly slower than the Coach Card's 7s
                    // so the two heroes breathe on different cadences.
                    let phase = (sin(t * (2 * .pi / 8.0)) + 1) / 2
                    let centerX = 0.15 + 0.30 * phase
                    let centerY = 0.0 + 0.12 * phase
                    shape.fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(0.45),
                                tint.opacity(0.28),
                                tint.opacity(0.04),
                                Color.clear
                            ],
                            center: UnitPoint(x: centerX, y: centerY),
                            startRadius: 0,
                            endRadius: 320
                        )
                    )
                }
            }

            // Frosted-glass overlay — same alpha as the Coach Card so the
            // wash reads through but the surface still reads as a card.
            shape.fill(.regularMaterial)
                .opacity(0.30)

            // Hairline border in tier tint so the silhouette stays crisp
            // against the home canvas.
            shape.strokeBorder(tint.opacity(0.38), lineWidth: 1)
        }
    }

    /// Coach-voice secondary line for the journey preview card.
    ///
    /// Resolution order:
    /// 1. Path cleared → quiet "hold the path" line.
    /// 2. Tier-aware variant when the user is within 100 rating of a
    ///    league promotion AND the next node references rating —
    ///    surface both the node and the league line so they reinforce.
    /// 3. Otherwise, the criterion-derived gating phrase.
    ///
    /// Never punish-shame: regressions don't change the copy shape; the
    /// gating helper only renders forward distance, and a recent rating
    /// drop just updates the snapshot silently.
    private func journeyGatingLine(for status: PathNodeStatus?) -> String {
        guard let status else {
            return "You've cleared every node. Hold the path with one rep a day."
        }

        // Tier-aware reinforcement — only when the next node IS the rating
        // gate and the user is within striking distance (<=100 points). If
        // the user is mid-tier on rating AND chasing a node-rating goal,
        // we name the league promotion so both surfaces point the same way.
        if let nextTierLine = tierPromotionReinforcement(for: status.node) {
            return nextTierLine
        }

        return pathProgress.currentNodeGatingPhrase
            ?? status.node.detail
    }

    /// Tier promotion reinforcement line — only fires when the current
    /// node's gating criterion is itself a rating bar (so the league
    /// line and the path line agree). Returns nil otherwise; we never
    /// mention Platinum on a node about pauses.
    private func tierPromotionReinforcement(for node: PathNode) -> String? {
        // Only consider rating-gated nodes — looking the node up by id
        // keeps this honest. Other criteria don't get a league overlay
        // because the two surfaces would point at different work.
        let ratingGated: Set<String> = ["rating_500", "rating_700"]
        guard ratingGated.contains(node.id) else { return nil }
        guard ratingStore.rating.hasRatedEvidence else { return nil }

        let tier = league.tier
        guard let nextTier = tier.nextTier else { return nil }
        let toGo = max(0, nextTier.ratingFloor - ratingStore.rating.overall)
        // Stay quiet unless the user is within range — over 100 points
        // off and "to Platinum" would feel like a far-future ask.
        guard toGo > 0, toGo <= 100 else { return nil }

        return "You're holding \(tier.title). +\(toGo) rating to \(nextTier.title)."
    }

    private var bottomShortcutDock: some View {
        HStack(spacing: 8) {
            ForEach(HomeBottomShortcut.all) { shortcut in
                Button {
                    navigationPath.append(shortcut.destination)
                } label: {
                    shortcutItem(shortcut)
                }
                .buttonStyle(ShortcutDockButtonStyle(reduceMotion: reduceMotion))
                .accessibilityIdentifier(shortcut.accessibilityIdentifier)
                .accessibilityLabel(shortcut.accessibilityLabel)
            }
        }
        .padding(8)
        // Each control pushes into the existing navigation stack and carries no
        // active-section state.
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        AppColor.pro.opacity(0.16),
                        AppColor.proLight.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Rectangle().fill(.regularMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.70), AppColor.pro.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppColor.pro.opacity(0.12), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .accessibilityIdentifier("home.shortcutDock")
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
                    VoiceAlignmentChip(
                        styleGoal: coachingProfileStore.profile?.speakingStyleGoal,
                        mode: suggestion.mode,
                        tint: suggestion.tint
                    )
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

    private func shortcutItem(_ shortcut: HomeBottomShortcut) -> some View {
        let accent = shortcutAccent(shortcut.accent)
        return HStack(spacing: 6) {
            Image(systemName: shortcut.systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 20, height: 20)

            Text(shortcut.title)
                .font(Typography.captionSmall)
                .foregroundStyle(.primary.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 7)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private func shortcutAccent(_ accent: HomeBottomShortcut.Accent) -> Color {
        switch accent {
        case .practice: return .blue
        case .review: return .orange
        case .profile: return .purple
        case .settings: return .green
        }
    }

    private var primarySuggestion: PracticeSuggestion {
        let sessions = sessionStore.sessions
        let plan = CoachingPlanner.plan(for: sessions, profile: coachingProfileStore.profile)
        let bias = recommendationBiasBlueprint

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

        if bias.source == .caseIntervention {
            return suggestion(
                from: bias,
                title: "Continue the current intervention",
                detail: bias.whyNow
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
        let bias = recommendationBiasBlueprint
        if bias.source == .caseIntervention {
            return normalizedSuggestion(
                suggestion(
                    from: bias,
                    title: "Continue the current intervention",
                    detail: bias.whyNow
                )
            )
        }

        guard let aiRecommendation,
              let mode = PracticeMode(rawValue: aiRecommendation.recommendedMode) else {
            return normalizedSuggestion(primarySuggestion)
        }

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
            plan: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile),
            imToneSignal: IMModeAvailability.isAvailable
                ? IMHistorySummary.toneDrillSignal(from: sessionStore.sessions)
                : nil,
            coachMemory: coachMemoryStore.currentMemory
        )
    }

    private func suggestion(
        from bias: RecommendationBiasBlueprint,
        title: String? = nil,
        detail: String? = nil
    ) -> PracticeSuggestion {
        PracticeSuggestion(
            title: title ?? (bias.recommendedMode == .imConversation ? "Train the live interaction" : "Keep the streak deliberate"),
            detail: detail ?? bias.whyNow,
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
        case "practice", "train":
            replaceNavigationPath(with: .practiceSelection)
        case "review", "history":
            replaceNavigationPath(with: .sessionHistory)
        case "profile", "social":
            replaceNavigationPath(with: .socialProfile)
        case "settings":
            replaceNavigationPath(with: .settings)
        case "home":
            replaceNavigationPath()
        case "league":
            navigationPath.append(AppDestination.league)
        case "path":
            navigationPath.append(AppDestination.pathJourney)
        case "ask", "asknoum":
            let pathMode = path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            let queryMode = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name.lowercased() == "mode" })?
                .value?
                .lowercased()
            if pathMode == "type" || pathMode == "chat" || queryMode == "type" || queryMode == "chat" {
                replaceNavigationPath(with: .askNoumTyped)
            } else {
                replaceNavigationPath(with: .askNoum)
            }
        case "asktype", "askchat":
            replaceNavigationPath(with: .askNoumTyped)
        case "growth", "library":
            navigationPath.append(AppDestination.growthLibrary)
        case "lessons":
            navigationPath.append(AppDestination.lessons)
        case "bigmoment":
            showBigMomentIntake = true
#if DEBUG
        case "summary":
            // Test-only: render the post-rep Summary for the most-recent
            // seeded session so the redesigned summary can be screenshotted
            // without completing a live (audio) rep. Minimal Entry — the coach
            // read, proof moment, and celebration are computed by SummaryView.
            guard let session = PracticeSessionStore.shared.sessions
                .sorted(by: { $0.date > $1.date }).first else { return }
            let summaryID = UUID()
            SummaryDataStore.shared.store(
                SummaryDataStore.Entry(
                    transcript: AttributedString(session.transcript),
                    fillerCount: session.fillerWordCount,
                    duration: session.duration,
                    score: session.score,
                    progressSegments: 0,
                    xpEarned: 0,
                    committedFinalization: nil,
                    suddenDeathGamePoints: nil,
                    suddenDeathMultiplierLabels: [],
                    suddenDeathTotalWords: nil,
                    showDuration: true,
                    practiceTitle: "Impromptu Practice",
                    feedbackOverride: nil,
                    headlineOverride: nil,
                    scoreBreakdown: [],
                    insights: [],
                    recentSessions: PracticeSessionStore.shared.sessions,
                    imConversationDetails: nil,
                    explicitMode: .timed,
                    recordingURL: nil,
                    sessionPrompt: nil,
                    sessionTheme: nil,
                    feedbackCategories: [],
                    strongMoments: [],
                    weakMoments: [],
                    durationAssessment: .onTarget,
                    targetRange: (min: 45, target: 60, max: 90),
                    onStartDrill: nil
                ),
                for: summaryID
            )
            navigationPath.append(AppDestination.summary(SummaryPayload(id: summaryID, mode: .timed)))
#endif
        default:
            // Unrecognised — no-op rather than crash.
            break
        }
    }

    /// Replace the stack in a single state write. Several deep-link routes used
    /// to clear the path and then append in the same frame, which can trigger
    /// SwiftUI's `NavigationRequestObserver tried to update multiple times per
    /// frame` warning.
    private func replaceNavigationPath(with destinations: AppDestination...) {
        var path = NavigationPath()
        for destination in destinations {
            path.append(destination)
        }
        navigationPath = path
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
        let caseKey: String
        if let intervention = coachMemoryStore.currentMemory?.activeIntervention {
            caseKey = [
                "case",
                intervention.mode.rawValue,
                intervention.reviewStatus.rawValue,
                "\(intervention.followedRepCount)",
                intervention.focus ?? "",
                intervention.target ?? ""
            ].joined(separator: "-")
        } else {
            caseKey = "no-case"
        }
        return "homeRecommendation.\(profileKey).\(caseKey).\(recent)"
    }

    /// Load the proof moment for the active path celebration. Picks
    /// the most recent session (the one that triggered the unlock)
    /// and asks `ProofMomentService` for a transcript-anchored quote
    /// + technique label tied to the user's voice. Hydrates
    /// `pathCelebrationProof` on success; leaves it nil on miss so
    /// the celebration renders without a proof line.
    private func loadPathCelebrationProof() async {
        let recent = sessionStore.sessions
            .sorted { $0.date > $1.date }
            .first
        guard let session = recent,
              !session.transcript.isEmpty,
              session.duration > 8 else {
            pathCelebrationProof = nil
            return
        }
        let baseline = BaselineStore.shared.baseline
        let input = ProofMomentInput(
            session: session,
            voice: coachingProfileStore.profile?.speakingStyleGoal,
            goalParaphrase: coachingProfileStore.profile?.displayableGoal,
            baselineFillerRate: baseline.fillerRate.confidence != .insufficient
                ? baseline.fillerRate.value : nil,
            baselinePace: baseline.pace.confidence != .insufficient
                ? baseline.pace.value : nil
        )
        let proof = await ProofMomentService.shared.proof(for: input)
        await MainActor.run {
            withAnimation(.standardSpring) {
                pathCelebrationProof = proof
            }
        }
    }

    private func refreshHomeRecommendation() async {
        if recommendationBiasBlueprint.source == .caseIntervention {
            aiRecommendation = nil
            return
        }

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
        // Round 17: destination mapping collapsed into
        // `SummaryLookingAheadRouter` so this surface, `HomeCoachCard`,
        // and the post-rep "Looking ahead" launch share one tested
        // mode-to-destination switch (incl. the IM-unavailable fallback
        // to Timed). Theme caching above stays here — it's the
        // suggestion-specific side effect, not part of the destination
        // contract.
        return SummaryLookingAheadRouter.destination(
            for: suggestion.mode,
            scenario: suggestion.recommendedScenario,
            tone: suggestion.recommendedTone,
            imAvailable: IMModeAvailability.isAvailable
        )
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

/// Press-feedback style for Home's shortcut dock. Reduced-motion users keep
/// the opacity change but skip animated scale.
private struct ShortcutDockButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(reduceMotion ? nil : .snappySpring, value: configuration.isPressed)
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    ContentView()
}
#endif
