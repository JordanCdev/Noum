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

/// Pure presentation plan for the one action Home leads with. The view passes
/// existing store facts into this resolver; no state is persisted here.
struct HomePrimaryActionPresentation: Equatable {
    enum Kind: Equatable {
        case pendingOutcomeCheckIn
        case upcomingMomentPrep
        case recommendedRep
        case firstRep
    }

    let kind: Kind
    let showsAskNoum: Bool

    static func resolve(
        sessionCount: Int,
        hasPendingOutcomeCheckIn: Bool,
        hasUpcomingMomentPrep: Bool
    ) -> HomePrimaryActionPresentation {
        let kind: Kind
        if hasPendingOutcomeCheckIn {
            kind = .pendingOutcomeCheckIn
        } else if hasUpcomingMomentPrep {
            kind = .upcomingMomentPrep
        } else if sessionCount > 0 {
            kind = .recommendedRep
        } else {
            kind = .firstRep
        }
        return HomePrimaryActionPresentation(
            kind: kind,
            showsAskNoum: sessionCount > 0
        )
    }

    /// Home always has one primary surface, may add Ask Noum after rep one,
    /// and accepts at most one conditional review row.
    func visibleSurfaceCount(hasConditionalRow: Bool) -> Int {
        1 + (showsAskNoum ? 1 : 0) + (hasConditionalRow ? 1 : 0)
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
            // Cold start, lowest patience: lead with the benefit and make the
            // depth curve legible so a new user sees the coach sharpens with
            // evidence — without claiming history it doesn't have.
            return "Give me one rep and I'll name the first focus worth training. A few more, and I'll name your core move."
        case 1:
            return "I have one rep, so I'll keep the read light and concrete."
        case 2:
            return "I have two reps, so I'll compare without overcalling a pattern."
        default:
            return "I read your recent reps before answering."
        }
    }
}

/// Quiet streak status under the coach hero — owner decision (roadmap
/// §12.1): the streak survives as a gentle, no-countdown marker, never a
/// pressure anchor. Coach-voice fact only ("4 day streak"), no
/// exclamation, no "don't lose it", no zero-state furniture.
///
/// Returns nil below two days: a single rep is not a streak, and the
/// reset state renders nothing — drops update the home silently
/// (never punish-shame).
enum HomeStreakStatusCopy {
    static func line(days: Int) -> String? {
        guard days >= 2 else { return nil }
        return "\(days) day streak"
    }
}

/// Quiet status line — a coach-voice fact ("4 day streak") rendered in
/// the caption register with no countdown, no warning and no tap
/// target. Reads the freeze-aware `StreakFreezeManager` count — the
/// single displayed-streak owner — so this never disagrees with the
/// streak shown elsewhere. Drops update silently: the line disappears,
/// nothing shames.
///
/// First-sight beat: on the first render of a genuinely HIGHER day count
/// (persisted last-seen guard on `StreakFreezeManager`, seeded on first
/// launch so a fresh install never pops a day it didn't watch grow), the
/// flame does one scale pop and the number rolls in via `.numericText`,
/// with one quiet damped tock (`InteractionCue.streakFirstSight`) on the
/// pop beat. A calendar day of practice genuinely happened — one pop,
/// one tock, never repeated, no haptic. Freeze-spends show the same
/// number and stay silent; drops persist silently (never punish-shame).
private struct HomeStreakStatusLine: View {
    let days: Int
    /// Final display copy from `HomeStreakStatusCopy` — also the stable
    /// VoiceOver label, so assistive tech never hears the rolling value.
    let line: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedDays: Int
    @State private var flamePop = false

    init(days: Int, line: String) {
        self.days = days
        self.line = line
        _displayedDays = State(initialValue: days)
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColor.caution)
                .scaleEffect(flamePop ? 1.25 : 1.0)
                .accessibilityHidden(true)
            Text(HomeStreakStatusCopy.line(days: displayedDays) ?? line)
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(displayedDays)))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(line)."))
        .accessibilityIdentifier("home.streakStatus")
        .onAppear(perform: animateFirstSightIfEarned)
        // Streak recomputed while the line is on screen (foreground day
        // rollover): evaluate the same first-sight beat live so the
        // number can never sit stale behind `days`.
        .onChange(of: days) { _, _ in animateFirstSightIfEarned() }
    }

    private func animateFirstSightIfEarned() {
        // Always consume — drops and freeze-days must be marked seen even
        // under Reduce Motion so a later increment compares honestly.
        let isFirstSightIncrement = StreakFreezeManager.shared.takeStreakFirstSightIncrement()
        // One quiet tock per genuine increment. Sound is not motion, so
        // it fires under Reduce Motion too (immediately — there is no
        // pop beat to sync with there); drops and freeze-spends never
        // reach this branch.
        if isFirstSightIncrement {
            if reduceMotion {
                InteractionSoundEngine.cue(.streakFirstSight)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    InteractionSoundEngine.cue(.streakFirstSight)
                }
            }
        }
        guard isFirstSightIncrement, !reduceMotion else {
            // Static fallback stays truthful: sync the displayed count on
            // every non-animating evaluation (Reduce Motion, drops, etc.).
            displayedDays = days
            return
        }

        // Roll from yesterday's count when that count renders as a line
        // (3 → 4); an increment onto the 2-day floor pops the flame only.
        // The un-animated write paints first so the roll has a real start
        // frame — a same-pass animated write would coalesce into a no-op.
        if HomeStreakStatusCopy.line(days: days - 1) != nil {
            displayedDays = days - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + Animation.streakPopDelay + 0.15) {
                withAnimation(.standardSpring) { displayedDays = days }
            }
        }
        // Pop starts as the card-entrance settle finishes; one beat, then
        // the flame returns to rest. All three beats key off
        // `streakPopDelay` so the channels can't drift apart.
        withAnimation(.bouncySpring.delay(Animation.streakPopDelay)) { flamePop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + Animation.streakPopDelay + 0.7) {
            withAnimation(.standardSpring) { flamePop = false }
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
        title
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

enum HomeShortcutDockLayout {
    static let scrollBottomPadding: CGFloat = 152
    static let backdropTopPadding: CGFloat = 18
    static let contentClearance: CGFloat = 16
    static let backdropTopOpacity: Double = 0.92
}

struct HomeAccessibilityModalGate: Equatable {
    var onboardingPresented = false
    var notificationPromptPresented = false
    var bigMomentIntakePresented = false

    var suppressesUnderlyingHome: Bool {
        onboardingPresented
        || notificationPromptPresented
        || bigMomentIntakePresented
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
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
    // M15 Phase 4 — Home discipline. Off by default; developer accounts
    // can flip it in Settings for inspection while normal users follow the
    // signal gate.
    @AppStorage("practice.showAllHomeCards") private var showAllHomeCards: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPracticeMode: PracticeMode = .timed
    @State private var showFreezeNudge = false
    @State private var homeCelebrationVisible = false
    @State private var homeScrollOffset: CGFloat = 0
    @Binding private var navigationPath: NavigationPath
    @State private var hourBucket: HourBucket = HourBucket.current()
    @State private var showBigMomentIntake: Bool = false
    @State private var showGoalReview: Bool = false
    @State private var showDeferredCoachingSetup = false
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    private let isOnboardingUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING_ONBOARDING")
    private let launchedWithDeepLink = ProcessInfo.processInfo.arguments.contains("-DeepLink")
    @Binding private var externalRoute: URL?
    private let isEmbeddedInTabShell: Bool

    init() {
        _navigationPath = .constant(NavigationPath())
        _externalRoute = .constant(nil)
        isEmbeddedInTabShell = false
    }

    init(navigationPath: Binding<NavigationPath>, externalRoute: Binding<URL?>) {
        _navigationPath = navigationPath
        _externalRoute = externalRoute
        isEmbeddedInTabShell = true
    }

    static func navigationStackAccessibilityIdentifier(pathIsEmpty: Bool) -> String {
        pathIsEmpty ? "home.screen" : "app.navigationStack"
    }

    private var homeAccessibilityIsSuppressed: Bool {
        HomeAccessibilityModalGate(
            onboardingPresented: isOnboardingUITesting,
            notificationPromptPresented: notificationPrePrompt.pendingPrompt,
            bigMomentIntakePresented: showBigMomentIntake
        ).suppressesUnderlyingHome
    }

    var body: some View {
        homePresentationContent
        .onChange(of: coachingProfileStore.profile) { old, new in
            let autoFireKey = "bigMomentIntake.hasAutoFired"
            if old == nil, new != nil,
               !UserDefaults.standard.bool(forKey: autoFireKey),
               !launchedWithDeepLink,
               !deepLinkRouter.hasReceivedRouteThisLaunch,
               navigationPath.isEmpty,
               deepLinkRouter.pending == nil,
               BigMomentStore.shared.activeMoment == nil,
               !showBigMomentIntake {
                UserDefaults.standard.set(true, forKey: autoFireKey)
                showBigMomentIntake = true
            }
        }
        .onChange(of: deepLinkRouter.pending) { _, url in
            guard !isEmbeddedInTabShell, let url else { return }
            consumeDeepLink(url)
        }
        .onChange(of: externalRoute) { _, url in
            guard let url else { return }
            consumeDeepLink(url)
            externalRoute = nil
        }
        .onAppear {
            bigMomentStore.archiveExpiredIfNeeded()
            dailyGoal.recompute()
            WordOfTheDayManager.shared.ensureForToday()
            refreshHourBucket()
            if !isEmbeddedInTabShell, let url = deepLinkRouter.pending {
                consumeDeepLink(url)
            }
        }
        .onReceive(Timer.publish(every: 300, on: .main, in: .common).autoconnect()) { _ in
            refreshHourBucket()
            bigMomentStore.archiveExpiredIfNeeded()
        }
    }

    private var homePresentationContent: some View {
        homeNavigationContent
        .accessibilityIdentifier(Self.navigationStackAccessibilityIdentifier(pathIsEmpty: navigationPath.isEmpty))
        .accessibilityHidden(homeAccessibilityIsSuppressed)
        .fullScreenCover(
            isPresented: .init(
                get: { isOnboardingUITesting },
                set: { _ in }
            )
        ) {
            CoachingOnboardingView()
        }
        .fullScreenCover(isPresented: $showDeferredCoachingSetup) {
            CoachingOnboardingView(
                prefill: coachingProfileStore.onboardingDraft,
                onComplete: { showDeferredCoachingSetup = false },
                onDefer: { showDeferredCoachingSetup = false }
            )
        }
        .sheet(isPresented: $notificationPrePrompt.pendingPrompt) {
            NotificationPrePromptSheet()
        }
        .sheet(isPresented: $showBigMomentIntake) {
            BigMomentIntakeView()
        }
    }

    private var homeNavigationContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Time-of-day ambient — morning lavender / midday airy /
                // evening soft purple-pink / night deeper saturation.
                // Home-only; other screens keep LightGradientBackground.
                homeBackground
                    .ignoresSafeArea()

                GeometryReader { container in
                    ScrollView(showsIndicators: false) {
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: HomeScrollOffsetKey.self, value: proxy.frame(in: .named("homeScroll")).minY)
                        }
                        .frame(height: 0)

                        VStack(spacing: 0) {
                            cohesiveHomeCards(availableHeight: container.size.height)
                        }
                        .frame(minHeight: container.size.height, alignment: .top)
                        .padding(.bottom, isEmbeddedInTabShell ? Spacing.lg : HomeShortcutDockLayout.scrollBottomPadding)
                    }
                }
            }
            .coordinateSpace(name: "homeScroll")
            .toolbar(.hidden, for: .navigationBar)
            .onPreferenceChange(HomeScrollOffsetKey.self) { value in
                homeScrollOffset = value
            }
            .safeAreaInset(edge: .bottom, spacing: HomeShortcutDockLayout.contentClearance) {
                if !isEmbeddedInTabShell {
                    bottomShortcutDock
                }
            }
            .navigationDestination(for: AppDestination.self) { destination in
                AppDestinationView(destination: destination, navigationPath: $navigationPath)
            }
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
        ZStack {
            HeroGradient.coach.gradient

            RadialGradient(
                colors: [.white.opacity(0.30), .white.opacity(0.06), .clear],
                center: UnitPoint(x: 0.52, y: 0.04),
                startRadius: 0,
                endRadius: 390
            )

            LinearGradient(
                colors: [hourBucket.start.opacity(0.20), hourBucket.end.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 1)
                .frame(width: 330, height: 330)
                .offset(x: -185, y: 300)

            LinearGradient(
                colors: [.white.opacity(0.34), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 170)
            .frame(maxHeight: .infinity, alignment: .top)
        }
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
    /// `showAllHomeCards` reveals active optional cards for developer
    /// inspection only; retired Home surfaces stay off.
    private var homeCardGate: HomeCardGate {
        HomeSignalGate.evaluate(
            sessionCount: sessionStore.progressEligibleSessionCount,
            sessionsThisWeekCount: HomeSignalGate.sessionsInCurrentISOWeek(
                sessionDates: sessionStore.progressEligibleSessions.map(\.date)
            ),
            hasUnlockedPathNode: !pathProgress.completedNodes.isEmpty,
            hasCoachingProfile: coachingProfileStore.profile != nil,
            showAllOverride: showAllHomeCards,
            overrideEligible: authManager.isDeveloper,
            streakDays: streakFreeze.currentStreak
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
                subtitle: "Reach landmarks by meeting concrete practice goals.",
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

    /// Path Journey preview — compact supporting status/action row. The
    /// Coach Card is the only Home hero; this keeps the progression route
    /// visible without turning Home back into a dashboard.
    /// Tier-adaptive tint for the journey card. Falls back to brand blue
    /// when the path is cleared (no current node).
    private var journeyTint: Color {
        pathProgress.currentNode?.node.tier.tint ?? AppColor.brandBlue
    }

    private var journeyPreviewCard: some View {
        let status = pathProgress.currentNode
        let cleared = status == nil
        let landmarkLine = journeyLandmarkLine(for: status)
        let titleLine = status?.node.title ?? "Path cleared"
        let gatingLine = journeyGatingLine(for: status)
        return Button {
            navigationPath.append(AppDestination.pathJourney)
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                Image(systemName: cleared ? "checkmark.seal.fill" : "map.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(journeyTint)
                    .frame(width: 32, height: 32)
                    .background(journeyTint.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text("Path")
                            .microLabel(journeyTint)
                        Text(landmarkLine)
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("home.path.landmarkCounter")
                    }

                    Text(titleLine)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("home.path.landmarkTitle")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(journeyTint)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.pressable)
        .background(AppColor.cardBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(journeyTint.opacity(0.10), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.path")
        .accessibilityLabel(Text("\(titleLine). \(landmarkLine). \(gatingLine)"))
    }

    /// "Landmark X of N" framing line. For the cleared state we celebrate
    /// the achievement without inventing a fake counter.
    private func journeyLandmarkLine(for status: PathNodeStatus?) -> String {
        let total = PathNodeRegistry.all.count
        guard let status else {
            return "All \(total) landmarks reached"
        }
        let position = status.node.order + 1
        return "Landmark \(position) of \(total)"
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
            return "You've reached every landmark. Keep the path strong with regular practice."
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

    // MARK: - Ask Noum row (H1 — Home-gap fill)
    //
    // The Ask Noum coach door used to live as a white-on-gradient chip
    // nested inside the coach hero. It now renders as its own quiet white
    // row below the Path/Journey card — filling the dead space that opened
    // when AIWeeklyInsightCard (3-rep gated) is absent, and matching the
    // approved direction (docs/UX_VISUAL_DIRECTION.md: "Ask Noum = white
    // row + violet chat chip").
    //
    // Card language mirrors `journeyPreviewCard` (white card, leading
    // tinted chip, evidence-scaled coach line, chevron) so Home reads as
    // one coherent stack, not a competing second hero. Copy stays the
    // shared, evidence-gated `HomeAskNoumShortcut` contract — no new copy
    // logic. Gated by `HomeSignalGate.askNoumShortcut`, so it never renders
    // empty furniture: hidden on a cold start with no profile, present once
    // onboarding produced a CoachingProfile (day-0 seeded thread) or after
    // the first rep.

    // Extracted from the Home `body` — the combined empty/populated card
    // stack in one `ViewBuilder` closure was too complex for the compiler
    // to type-check ("unable to type-check this expression in reasonable
    // time"). Splitting each branch into its own `@ViewBuilder` computed
    // property is a pure refactor: identical card set, identical
    // conditions, identical `cardEntrance` ordering.
    private enum HomeConditionalSurface {
        case goalReview
        case outcomeAcknowledgement
        case ratingReview
    }

    private var homePrimaryAction: HomePrimaryActionPresentation {
        let hasUpcomingPrep: Bool
        if let moment = bigMomentStore.activeMoment,
           let days = bigMomentStore.daysUntil(moment) {
            hasUpcomingPrep = days >= 0 && days <= 14
        } else {
            hasUpcomingPrep = false
        }

        return HomePrimaryActionPresentation.resolve(
            sessionCount: sessionStore.progressEligibleSessionCount,
            hasPendingOutcomeCheckIn: bigMomentStore.pendingOutcomeCheckInMoment != nil,
            hasUpcomingMomentPrep: hasUpcomingPrep
        )
    }

    /// Only one quiet row may follow the primary action and Ask Noum.
    /// Direction review wins because it is explicitly due, followed by a
    /// just-saved real-world acknowledgement, then a transient rating review.
    private var homeConditionalSurface: HomeConditionalSurface? {
        if goalRefresh.shouldPresent { return .goalReview }
        if bigMomentStore.pendingOutcomeAck != nil { return .outcomeAcknowledgement }
        if ratingStore.pendingPeakGlow && ratingStore.rating.hasRatedEvidence {
            return .ratingReview
        }
        return nil
    }

    @ViewBuilder
    private func cohesiveHomeCards(availableHeight: CGFloat) -> some View {
        let presentation = homePrimaryAction

        if presentation.kind == .pendingOutcomeCheckIn,
           let moment = bigMomentStore.pendingOutcomeCheckInMoment {
            BigMomentOutcomeInlineCard(moment: moment)
                .cardEntrance(0)
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.lg)
        } else {
            HomeCoachCard(
                navigationPath: $navigationPath,
                scrollOffset: homeScrollOffset,
                showsPlanArc: false,
                presentation: .immersive
            )
            .frame(minHeight: max(500, availableHeight - 148))
            .cardEntrance(0)
        }

        homeProgressReceipt
            .padding(.horizontal, Spacing.screenH)

        if coachingProfileStore.profile == nil,
           coachingProfileStore.onboardingDraft?.hasCompletedFirstValue == true {
            deferredCoachingSetupCard
                .padding(.horizontal, Spacing.screenH)
                .cardEntrance(1)
        }

        if presentation.showsAskNoum {
            homeAskNoumRow
                .padding(.horizontal, Spacing.screenH)
                .cardEntrance(1)
        }

        switch homeConditionalSurface {
        case .goalReview:
            if showGoalReview {
                GoalRefreshInlineCard()
                    .padding(.horizontal, Spacing.screenH)
                    .cardEntrance(2)
            } else {
                homeGoalReviewRow
                    .padding(.horizontal, Spacing.screenH)
                    .cardEntrance(2)
            }
        case .outcomeAcknowledgement:
            if let report = bigMomentStore.pendingOutcomeAck {
                BigMomentOutcomeAckCard(report: report) {
                    bigMomentStore.consumeOutcomeAck()
                }
                .padding(.horizontal, Spacing.screenH)
                .cardEntrance(2)
                .transition(.opacity)
            }
        case .ratingReview:
            homeRatingReviewRow
                .padding(.horizontal, Spacing.screenH)
                .cardEntrance(2)
        case nil:
            EmptyView()
        }
    }

    /// One calm receipt replaces the former tier, daily-goal and path
    /// celebration overlays. Persistence remains owned by the existing
    /// managers; Home only acknowledges one pending event at a time.
    @ViewBuilder
    private var homeProgressReceipt: some View {
        if let promotion = league.pendingPromotion {
            progressReceipt(
                title: "Peer group reached",
                body: "You're now in the \(promotion.newTier.title) peer group.",
                tint: promotion.newTier.tint,
                onDismiss: league.consumePendingPromotion
            )
        } else if let node = pendingPathNode {
            progressReceipt(
                title: "Landmark reached",
                body: node.title,
                tint: node.tier.tint,
                onDismiss: pathProgress.consumeCelebration
            )
        } else if dailyGoal.pendingGoalCelebration {
            progressReceipt(
                title: "Today's practice complete",
                body: "You completed your \(dailyGoal.goalReps)-rep target.",
                tint: AppColor.positive,
                onDismiss: dailyGoal.consumeGoalCelebration
            )
        }
    }

    private func progressReceipt(
        title: String,
        body: String,
        tint: Color,
        onDismiss: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.cardLabel)
                    .foregroundStyle(AppColor.textPrimary)
                Text(body)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.xs)

            Button("Done", action: onDismiss)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(Spacing.md)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.progressReceipt")
    }

    private var homeGoalReviewRow: some View {
        quietHomeRow(
            icon: "scope",
            title: "Review your direction",
            body: "Confirm that Noum is still training for the right conversation.",
            tint: AppColor.brandBlue,
            accessibilityID: "home.goalReview.row"
        ) {
            if reduceMotion {
                showGoalReview = true
            } else {
                withAnimation(.standardSpring) { showGoalReview = true }
            }
        }
    }

    private var homeRatingReviewRow: some View {
        let rating = ratingStore.rating
        let presentation = HomePeakGlowPresentation.make(
            weekPeak: rating.weekPeakRating,
            current: rating.overall,
            allTime: rating.peakRating
        )
        return quietHomeRow(
            icon: "chart.line.uptrend.xyaxis",
            title: "Review this week's movement",
            body: presentation.body,
            tint: AppColor.positive,
            accessibilityID: "home.ratingReview.row"
        ) {
            ratingStore.markPeakGlowConsumed()
            navigationPath.append(AppDestination.socialProfile)
        }
        .task {
            let seconds: UInt64 = reduceMotion ? 5 : 7
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            ratingStore.markPeakGlowConsumed()
        }
    }

    private func quietHomeRow(
        icon: String,
        title: String,
        body: String,
        tint: Color,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.coachHeroInk)
                    .frame(width: 32, height: 32)
                    .background(AppColor.coachHeroInk.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(Typography.cardLabel)
                        .foregroundStyle(AppColor.coachHeroInk)
                    Text(body)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.coachHeroInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.coachHeroInk)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .overlay(alignment: .top) {
            Rectangle().fill(AppColor.coachHeroInk.opacity(0.18)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(body)")
        .accessibilityIdentifier(accessibilityID)
    }

    @ViewBuilder
    private var emptyStateHomeCards: some View {
        // Empty-state — use the same coach-first floor as
        // the signal-gated populated home. First screen:
        // coach presence + Begin. Status and progression
        // surfaces unlock after signal instead of reading
        // like a habit dashboard before the user has
        // completed a rep. The Ask Noum shortcut alone
        // opens on day 0 once onboarding produced a
        // profile — the thread is seeded/read-only until
        // rep 1 (HomeSignalGate / AskNoumDayZeroGreeting).
        let gate = homeCardGate
        if goalRefresh.shouldPresent {
            GoalRefreshInlineCard()
                .cardEntrance(0)
        }
        if gate.coachCard {
            HomeCoachCard(
                navigationPath: $navigationPath,
                scrollOffset: homeScrollOffset,
                showsPlanArc: gate.planArc
            ).cardEntrance(goalRefresh.shouldPresent ? 1 : 0)
        }
        if let moment = bigMomentStore.pendingOutcomeCheckInMoment {
            BigMomentOutcomeInlineCard(moment: moment).cardEntrance(1)
        } else if let ackReport = bigMomentStore.pendingOutcomeAck {
            // The coach's receipt for a just-saved
            // check-in — fills the card's slot for a
            // beat instead of a silent vanish, then
            // self-consumes (transient, in-memory).
            BigMomentOutcomeAckCard(report: ackReport) {
                bigMomentStore.consumeOutcomeAck()
            }
            .cardEntrance(1)
            .transition(.opacity)
        }
        // Ask Noum coach door — a quiet white row, not a
        // nested chip on the hero. On day 0 (empty home)
        // this is the one calm progression cue under the
        // Begin CTA once onboarding produced a profile.
        if gate.askNoumShortcut {
            homeAskNoumRow.cardEntrance(2)
        }
        roleplayEntryRow.cardEntrance(3)
        if showAllHomeCards && authManager.isDeveloper {
            secondaryDiscoveryCard.cardEntrance(4)
        }
    }

    /// Quiet continuation for people who chose to explore after the
    /// permissionless first-value exercise. The receipt unlocks navigation,
    /// not profile-gated coaching claims; completing this card is still the
    /// only way to publish a full CoachingProfile.
    private var deferredCoachingSetupCard: some View {
        Button {
            showDeferredCoachingSetup = true
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(width: 44, height: 44)
                    .background(AppColor.brandBlue.opacity(0.08), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Complete coaching setup")
                        .font(Typography.cardLabel)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Add how you want to sound so Noum can tailor spoken practice.")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColor.subtleBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.coachingSetup.resume")
        .accessibilityHint("Opens the remaining coaching profile setup. Your earlier choices are prefilled.")
    }

    @ViewBuilder
    private var populatedHomeCards: some View {
        // Populated home — coach-led revamp.
        //
        // Default stack:
        //  1. HomeCoachCard — coach voice, primary CTA.
        //  2. journeyPreviewCard — next path move.
        //  3. AIWeeklyInsightCard — only after three
        //     current-week reps.
        //
        // Retired Home dashboard surfaces stay out of
        // the tree. Attendance, rank/level, lessons,
        // raw diagnostics and alternate practice entry
        // points now live in their owned routes instead
        // of competing with the coach-led Home.
        //
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
        // Reversible for developer inspection via
        // `practice.showAllHomeCards`.
        let gate = homeCardGate
        // M14 redesign: HomeCoachCard is the single
        // composed hero with NoumCharacter present, the
        // coach's recommendation as primary copy, and a single
        // Begin CTA. The recommendation pipeline
        // (RecommendationBiasEngine + CoachingPlanner)
        // feeds it directly — no new coaching logic.
        if goalRefresh.shouldPresent {
            GoalRefreshInlineCard()
                .cardEntrance(0)
        }
        if gate.coachCard {
            HomeCoachCard(
                navigationPath: $navigationPath,
                scrollOffset: homeScrollOffset,
                showsPlanArc: gate.planArc
            ).cardEntrance(goalRefresh.shouldPresent ? 1 : 0)
        }
        // Quiet streak status — the ONE status line the
        // populated home keeps (roadmap Iter 4). Gated on
        // a real >=2-day freeze-aware streak; the copy
        // helper returns nil below that floor so even the
        // developer show-all override can't render "0 day
        // streak" furniture. No countdown, no tap target,
        // no loss-aversion — a reset simply removes the
        // line silently.
        if gate.streakStatus,
           let streakLine = HomeStreakStatusCopy.line(days: streakFreeze.currentStreak) {
            HomeStreakStatusLine(
                days: streakFreeze.currentStreak,
                line: streakLine
            ).cardEntrance(1)
        }
        if let moment = bigMomentStore.pendingOutcomeCheckInMoment {
            BigMomentOutcomeInlineCard(moment: moment).cardEntrance(1)
        } else if let ackReport = bigMomentStore.pendingOutcomeAck {
            // The coach's receipt for a just-saved
            // check-in — fills the card's slot for a
            // beat instead of a silent vanish, then
            // self-consumes (transient, in-memory).
            BigMomentOutcomeAckCard(report: ackReport) {
                bigMomentStore.consumeOutcomeAck()
            }
            .cardEntrance(1)
            .transition(.opacity)
        }
        // Path Journey — a quiet supporting row. The
        // Coach Card owns Home's hero register; Path
        // stays nearby as the next progression cue
        // without becoming a competing second hero.
        if gate.journey {
            journeyPreviewCard.cardEntrance(2)
        }
        // H1 — Home-gap fill. The AI Weekly Insight card
        // below is gated on 3 current-week reps and is
        // usually absent, which left dead space under the
        // Path row. The Ask Noum coach door (relocated out
        // of the hero) now fills that slot as a quiet
        // white row + violet chat chip — a real,
        // signal-gated surface, never empty furniture.
        if gate.askNoumShortcut {
            homeAskNoumRow.cardEntrance(3)
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
        roleplayEntryRow.cardEntrance(7)
    }

    private var homeAskNoumRow: some View {
        let tint = AppColor.pro // brand violet — the chat/ask hue
        let body = HomeAskNoumShortcut.body(sessionCount: sessionStore.progressEligibleSessionCount)
        return Button {
            navigationPath.append(AppDestination.askNoum)
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                Image(systemName: "message.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.55), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(HomeAskNoumShortcut.title)
                        .font(Typography.captionSmall.weight(.bold))
                        .foregroundStyle(AppColor.coachHeroInk)

                    Text(body)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.coachHeroInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.coachHeroInk)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .overlay(alignment: .top) {
            Rectangle().fill(AppColor.coachHeroInk.opacity(0.20)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(HomeAskNoumShortcut.title). \(body)."))
        .accessibilityIdentifier(HomeAskNoumShortcut.accessibilityIdentifier)
    }

    // Quiet entry point for the pressure-ladder roleplay feature — same
    // visual weight as `homeAskNoumRow` (a white row, not a competing
    // hero), matching the existing note that alternate practice entry
    // points live in their own routes rather than piling onto the
    // coach-led hero.
    private var roleplayEntryRow: some View {
        let tint = AppColor.modeIM
        return Button {
            navigationPath.append(AppDestination.roleplaySetup)
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                Image(systemName: "person.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Practise a real conversation")
                        .microLabel(tint)
                    Text("Interview, leadership update, stakeholder pushback — under rising pressure.")
                        .font(Typography.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.pressable)
        .background(AppColor.cardBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(tint.opacity(0.10), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Practise a real conversation. Interview, leadership update, stakeholder pushback, under rising pressure."))
        .accessibilityIdentifier("home.roleplay.row")
    }

    // Shortcut dock — deliberately NOT a tab bar (roadmap Iter 4 "resolve
    // the fake tab bar"). Every control is a push into the one
    // NavigationStack, so there is no tab/selection state to represent.
    // Resolution taken: stop styling the row as a single tab-bar slab.
    // The four shortcuts render as discrete capsule buttons floating over
    // the canvas — they read as buttons (and VoiceOver announces them as
    // buttons, "Open Train"), not as tabs promising a persistent section
    // indicator. The dock only exists on the home root; pushed screens
    // cover it, which is honest for push navigation.
    private var bottomShortcutDock: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.xs) {
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
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.sm)
        }
        .padding(.top, HomeShortcutDockLayout.backdropTopPadding)
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [
                    AppColor.lightGradientEnd.opacity(HomeShortcutDockLayout.backdropTopOpacity),
                    AppColor.lightGradientEnd.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
    }

    private func shortcutItem(_ shortcut: HomeBottomShortcut) -> some View {
        let accent = shortcutAccent(shortcut.accent)
        return HStack(spacing: Spacing.xxs) {
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
        // 44pt min height — HIG tap target (the old 40pt was sub-HIG).
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, Spacing.xs)
        // Each chip carries its own frosted backing so scrolled content
        // never bleeds through the button itself; the gaps between chips
        // stay transparent, which is what visually breaks the "one solid
        // tab bar" read.
        .background(
            ZStack {
                Capsule(style: .continuous).fill(.regularMaterial)
                Capsule(style: .continuous).fill(accent.opacity(0.08))
            }
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.10), radius: 10, x: 0, y: 5)
    }

    /// Accent tokens for the dock — design-system colors only, matched to
    /// the hues the dock has always carried (blue/orange/purple/green).
    /// `caution` here is used purely as the warm amber accent token, not
    /// as a semantic warning.
    private func shortcutAccent(_ accent: HomeBottomShortcut.Accent) -> Color {
        switch accent {
        case .practice: return AppColor.brandBlue
        case .review: return AppColor.caution
        case .profile: return AppColor.pro
        case .settings: return AppColor.positive
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
            // AppShell owns production tab/deep-link routing. This fallback is
            // retained for the standalone ContentView preview/harness only and
            // deliberately has no first-run fork.
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
                    finalizedSessionID: session.id,
                    committedFinalization: nil,
                    suddenDeathGamePoints: nil,
                    suddenDeathMultiplierLabels: [],
                    suddenDeathTotalWords: nil,
                    showDuration: true,
                    practiceTitle: PracticeMode.timed.displayLabel,
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

    /// The persisted path manager remains the event owner; Home only resolves
    /// its compact display title.
    private var pendingPathNode: PathNode? {
        guard let nodeID = pathProgress.pendingCelebrationNodeID else { return nil }
        return PathNodeRegistry.all.first(where: { $0.0.id == nodeID })?.0
    }

    /// Single source of truth for the user-visible streak count: the
    /// `StreakFreezeManager`, which applies freezes. This used to be
    /// computed twice (raw calculation + freeze-applied) and the home
    /// could show two different numbers. Now both reads pull from here.
    private var sessionStreak: Int {
        streakFreeze.currentStreak
    }

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
