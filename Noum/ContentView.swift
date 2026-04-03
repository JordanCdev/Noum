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
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.95),
                        Color(red: 0.99, green: 0.99, blue: 0.98),
                        Color.white,
                        Color(red: 0.97, green: 0.98, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Hero section - fixed at top with no gap
                    heroCard
                        .padding(.horizontal, 20)
                    
                    // Scrollable content starts immediately after hero
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            suggestedPracticeCard
                            journeyPreviewCard
                            progressCard
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 90)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                bottomNavigation
            }
        }
        .fullScreenCover(
            isPresented: .init(
                get: { !authManager.isSignedIn && !isUITesting && !isOnboardingUITesting },
                set: { _ in }
            )
        ) {
            LoginView()
        }
        .fullScreenCover(
            isPresented: .init(
                get: { authManager.isSignedIn && coachingProfileStore.shouldPresentInitialOnboarding && !isUITesting },
                set: { _ in }
            )
        ) {
            CoachingOnboardingView()
        }
        .fullScreenCover(
            isPresented: .init(
                get: { isOnboardingUITesting },
                set: { _ in }
            )
        ) {
            CoachingOnboardingView()
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

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hello, \(heroTitle)")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text("Ready to level up your speaking?")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .padding(.bottom, 0)
    }

    private var progressCard: some View {
        NavigationLink(destination: SpeakingRankView()) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: rankSymbol)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(rankTint)
                        .frame(width: 46, height: 46)
                        .background(rankTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

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
                }

                HStack(alignment: .center, spacing: 10) {
                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(profile.xp) XP")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.10), in: Capsule())

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
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
                    Text(retentionSnapshot.activeChallenge.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(rankTint)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(rankDescriptor)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(rankTint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 164)
            .padding(20)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.94),
                        rankTint.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var suggestedPracticeCard: some View {
        let primary = effectiveSuggestion

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Recommended Practice")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                
                Text("Your best next rep")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            challengePreviewPill
            
            suggestionLink(
                suggestion: primary,
                systemImage: iconName(for: primary.mode)
            )

            coachingFocusCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: primary.tint.opacity(0.08), radius: 12, x: 0, y: 4)
                
                LinearGradient(
                    colors: [
                        Color.white,
                        primary.tint.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
        NavigationLink(destination: PathJourneyView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(red: 0.34, green: 0.56, blue: 0.25))
                        .frame(width: 46, height: 46)
                        .background(
                            Color(red: 0.34, green: 0.56, blue: 0.25).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your Path")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(journeySnapshot.progressLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.30, green: 0.54, blue: 0.24))
                        Text(journeySnapshot.homeGoalShortLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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
            .frame(minHeight: 88)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.94),
                        Color(red: 0.94, green: 0.98, blue: 0.93).opacity(0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var bottomNavigation: some View {
        HStack(spacing: 10) {
            Group {
                NavigationLink(destination: PracticeModeSelectionView(selectedMode: $selectedPracticeMode)) {
                    navItem(title: "Train", systemImage: "dumbbell.fill", accent: .blue)
                }
                .accessibilityIdentifier("nav.practice")

                NavigationLink(destination: SessionHistoryView()) {
                    navItem(title: "History", systemImage: "book.fill", accent: .orange)
                }
                .accessibilityIdentifier("nav.history")

                NavigationLink(destination: SettingsView()) {
                    navItem(title: "Settings", systemImage: "slider.horizontal.3", accent: .green)
                }
                .accessibilityIdentifier("nav.settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private func suggestionLink(
        suggestion: PracticeSuggestion,
        systemImage: String
    ) -> some View {
        NavigationLink(destination: practiceDestination(for: suggestion)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    PulseBadge(systemImage: systemImage, tint: suggestion.tint)
                    VStack(alignment: .leading, spacing: 3) {
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
                }

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(primaryCardLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(suggestion.tint)
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(suggestion.tint.opacity(0.9))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [suggestion.tint.opacity(0.08), Color.black.opacity(0.015)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
        }
        .simultaneousGesture(TapGesture().onEnded {
            selectedPracticeMode = suggestion.mode
            recommendationLearningStore.markTapped(mode: suggestion.mode)
        })
    }

    private var coachingFocusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Coaching Focus")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(primaryFocusText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(effectiveSuggestion.benefit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(coachingFocusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                tint: tint(for: mode)
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
            tint: tint(for: bias.recommendedMode)
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
            tint: tint(for: mode)
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

    private var primaryCardLabel: String {
        switch effectiveSuggestion.mode {
        case .timed:
            return "Recommended"
        case .suddenDeath:
            return "Pressure rep"
        case .ahCounter:
            return "Pace reset"
        case .imConversation:
            return "Conversation rep"
        }
    }

    private var primaryFocusText: String {
        effectiveSuggestion.focus
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

    private var challengePreviewPill: some View {
        HStack(spacing: 10) {
            Text(retentionSnapshot.activeChallenge.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(effectiveSuggestion.tint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(retentionSnapshot.activeChallenge.progressLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.58), in: Capsule())
    }

    private var coachingFocusDetail: String {
        let biasSuffix: String
        if effectiveSuggestion.mode == .imConversation,
           let scenario = effectiveSuggestion.recommendedScenario,
           let tone = effectiveSuggestion.recommendedTone {
            biasSuffix = " Start with \(scenario.title) in a \(tone.title.lowercased()) tone."
        } else {
            biasSuffix = ""
        }
        if let aiRecommendation {
            return "\(aiRecommendation.whyMode) \(aiRecommendation.whyNow)\(biasSuffix)"
        }

        let target = effectiveSuggestion.target
        if target == "30s+" {
            return "Time target: 30 seconds or longer.\(biasSuffix)"
        }
        if target == "<150 WPM" {
            return "Coaching tip: slow the pace and leave more space between points.\(biasSuffix)"
        }
        if target.localizedCaseInsensitiveContains("filler") {
            return "Coaching tip: settle the opening and replace fillers with pauses.\(biasSuffix)"
        }
        return "Coaching tip: establish a clean baseline rep.\(biasSuffix)"
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
        let calendar = Calendar.current
        let uniqueDays = Set(sessionStore.sessions.map { calendar.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        while uniqueDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
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

    @ViewBuilder
    private func practiceDestination(for suggestion: PracticeSuggestion) -> some View {
        switch suggestion.mode {
        case .timed:
            TimedPracticeView()
        case .suddenDeath:
            SuddenDeathPracticeView()
        case .ahCounter:
            AhCounterView()
        case .imConversation:
            if IMModeAvailability.isAvailable {
                IMPracticeView(
                    preferredScenario: suggestion.recommendedScenario,
                    preferredTone: suggestion.recommendedTone
                )
            } else {
                TimedPracticeView()
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
            return "Mode: \(modeLabel(for: suggestion.mode))"
        }
        return "Mode: \(modeLabel(for: suggestion.mode)) • \(scenario.title) • \(tone.title)"
    }

    private var levelProgressLabel: String {
        "\(Int((profile.progressTowardsNextLevel * 100).rounded()))%"
    }

    private var rankSymbol: String {
        let title = profile.levelTitle
        if title.contains("Beginner") { return "sparkles" }
        if title.contains("Novice") { return "figure.stand" }
        if title.contains("Average") { return "waveform.path.ecg" }
        if title.contains("Professional") { return "shield.lefthalf.filled" }
        return "crown.fill"
    }

    private var rankTint: Color {
        let title = profile.levelTitle
        if title.contains("Beginner") { return .blue }
        if title.contains("Novice") { return .teal }
        if title.contains("Average") { return .indigo }
        if title.contains("Professional") { return .orange }
        return .yellow
    }

    private var rankDescriptor: String {
        let title = profile.levelTitle
        if title.contains("Beginner") { return "Foundational tier" }
        if title.contains("Novice") { return "Developing tier" }
        if title.contains("Average") { return "Steady tier" }
        if title.contains("Professional") { return "Advanced tier" }
        return "Elite tier"
    }

    private var rankTitle: String {
        "Speaker \(max(1, (profile.xp / 1000) + 1))"
    }

    private var nextRankTitle: String {
        "Next: Speaker \(max(2, (profile.xp / 1000) + 2))"
    }

    private func modeLabel(for mode: PracticeMode) -> String {
        switch mode {
        case .timed:
            return "Timed"
        case .suddenDeath:
            return "Sudden Death"
        case .ahCounter:
            return "Ah-Counter"
        case .imConversation:
            return "IM Mode"
        }
    }

    private func iconName(for mode: PracticeMode) -> String {
        switch mode {
        case .timed:
            return "clock.fill"
        case .suddenDeath:
            return "bolt.fill"
        case .ahCounter:
            return "waveform.and.mic"
        case .imConversation:
            return "message.badge.waveform.fill"
        }
    }

    private func tint(for mode: PracticeMode) -> Color {
        switch mode {
        case .timed:
            return .blue
        case .suddenDeath:
            return .orange
        case .ahCounter:
            return .green
        case .imConversation:
            return .purple
        }
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    ContentView()
}
#endif
