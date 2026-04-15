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
    @State private var selectedPracticeMode: PracticeMode = .timed
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
                            heroCard
                            firstSessionCard
                        } else {
                            heroCard
                            quickStartCard
                            streakChallengeCard
                            progressCard
                            journeyPreviewCard
                            suggestedPracticeCard
                        }
                    }
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
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
                case .summary(let payload):
                    SummaryView(payload: payload, navigationPath: $navigationPath)
                case .sessionHistory:
                    SessionHistoryView()
                case .socialProfile:
                    ProfileView()
                case .settings:
                    SettingsView()
                case .speakingRank:
                    SpeakingRankView()
                case .pathJourney:
                    PathJourneyView()
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
            return "Let's find your baseline"
        }

        // 2. Seven-day streak or higher
        if sessionStreak >= 7 {
            return "\u{1F525} \(sessionStreak)-day streak — unstoppable"
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
            return "Already practiced today — nice"
        }

        // 7. Last session was yesterday
        if daysSinceLastSession == 1 {
            return "Welcome back — let's keep the momentum"
        }

        // 8. Been a few days
        if daysSinceLastSession >= 3 {
            return "Ready to pick up where you left off?"
        }

        // 9. Default
        return "Every rep makes you sharper"
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hello, \(heroTitle)")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text(heroSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: max(0, 64 + min(0, homeScrollOffset)))
        .opacity(max(0, 1 + (homeScrollOffset / 42)))
        .clipped()
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
            return "You said you want to work on \(challenge). Let's see where you stand."
        }
        return "One short rep is all it takes to set your starting line."
    }

    private var firstSessionCard: some View {
        Button { navigationPath.append(AppDestination.timedPractice) } label: {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Let's find your starting point")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
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
                        colors: [.blue, Color.blue.opacity(0.8)],
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
                    .stroke(Color.blue.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("home.firstSession")
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
                    Text("Quick Start")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
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

    // MARK: - Streak & Challenge Card

    private var streakChallengeCard: some View {
        let streak = sessionStreak
        let challenge = retentionSnapshot.activeChallenge

        return HStack(spacing: 12) {
            // Streak pill
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(streak > 0 ? .orange : .gray)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(streak)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(streak > 0 ? .orange : .secondary)
                    Text("day streak")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                (streak > 0 ? Color.orange : Color.gray).opacity(0.08),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )

            // Today's challenge pill
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                ShimmerProgressBar(
                    progress: challenge.progress,
                    tint: .blue,
                    animated: challenge.progress > 0 && challenge.progress < 1
                )
                HStack {
                    Text(challenge.progressLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                    Spacer()
                    Text(challenge.rewardLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.sm)
            .background(
                Color.blue.opacity(0.06),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
        }
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
                            .font(.system(size: 28, weight: .bold, design: .rounded))
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

                    ShimmerProgressBar(progress: profile.progressTowardsNextLevel, tint: .blue)
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
                .font(.system(size: 10, weight: .bold, design: .rounded))
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

    private var journeyPreviewCard: some View {
        Button { navigationPath.append(AppDestination.pathJourney) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColor.positive)
                        .frame(width: 46, height: 46)
                        .background(
                            AppColor.positive.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your Path")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(journeySnapshot.progressLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.positive)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 78)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 12)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.path")
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
                        .font(.system(size: 18, weight: .bold, design: .rounded))
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
        VStack(alignment: .leading, spacing: 0) {
            Text(recommendedPracticeSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                .font(.system(size: 10, weight: .semibold, design: .rounded))
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
            tint: AppColor.tint(for: bias.recommendedMode)
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

    private var journeySnapshot: PracticeJourneySnapshot {
        PracticeJourneySnapshot.make(from: sessionStore.sessions)
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

    private var sessionStreak: Int {
        PracticeSession.calculateStreak(from: sessionStore.sessions)
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
