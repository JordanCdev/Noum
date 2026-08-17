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

/// One compact Home row for the existing first-week coaching contract.
/// Copy, routing, and evidence strength stay owned by the contract; this type
/// only turns its current snapshot into a calm, testable presentation.
struct FirstWeekHomeEntryPresentation: Equatable {
    enum Style: Equatable {
        case nextStep
        case durableRead
    }

    let title: String
    let body: String
    let systemImage: String
    let style: Style
    let route: URL
    let accessibilityIdentifier: String
    let accessibilityHint: String

    static func make(
        snapshot: FirstWeekCoachingContract.Snapshot
    ) -> FirstWeekHomeEntryPresentation? {
        let route = FirstWeekNotificationAttribution(snapshot: snapshot).route

        switch snapshot.nextAction {
        case .recordSpokenBaseline:
            return nextStep(
                snapshot: snapshot,
                route: route,
                systemImage: "waveform.and.mic",
                accessibilityHint: "Starts the spoken baseline rep"
            )
        case .repeatRep(let mode):
            return nextStep(
                snapshot: snapshot,
                route: route,
                systemImage: mode?.iconName ?? "arrow.clockwise",
                accessibilityHint: "Starts the next rep in your first-week plan"
            )
        case .compareAndAdapt(_, let mode):
            return nextStep(
                snapshot: snapshot,
                route: route,
                systemImage: mode?.iconName ?? "arrow.triangle.2.circlepath",
                accessibilityHint: "Starts the comparison rep in your first-week plan"
            )
        case .realWorldCheckIn:
            return nextStep(
                snapshot: snapshot,
                route: route,
                systemImage: "bubble.left.and.text.bubble.right",
                accessibilityHint: "Opens a short real-world coaching check-in"
            )
        case .reviewFirstWeekRead:
            guard let read = snapshot.firstWeekRead else { return nil }
            return FirstWeekHomeEntryPresentation(
                title: "Your first-week read",
                body: firstWeekReadBody(read),
                systemImage: "text.book.closed.fill",
                style: .durableRead,
                route: route,
                accessibilityIdentifier: "home.firstWeekRead.open",
                accessibilityHint: "Opens your durable first-week coaching read"
            )
        }
    }

    private static func nextStep(
        snapshot: FirstWeekCoachingContract.Snapshot,
        route: URL,
        systemImage: String,
        accessibilityHint: String
    ) -> FirstWeekHomeEntryPresentation {
        let line = NotificationCopy.firstWeek(intent: snapshot.notificationIntent)
        return FirstWeekHomeEntryPresentation(
            title: line.title,
            body: line.body,
            systemImage: systemImage,
            style: .nextStep,
            route: route,
            accessibilityIdentifier: snapshot.nextAction.accessibilityIdentifier,
            accessibilityHint: accessibilityHint
        )
    }

    private static func firstWeekReadBody(
        _ read: FirstWeekCoachingContract.FirstWeekReadProjection
    ) -> String {
        switch read.whatChanged {
        case .verifiedComparison:
            return "A qualified comparison and your next-week plan are ready."
        case .notYetProven:
            return "See what Noum can support and what still needs evidence."
        }
    }
}

/// Presentation-only acknowledgement for Home's one support slot. The durable
/// read remains in CoachMemory and its route remains valid; Home stops
/// promoting it only after the existing account-scoped growth ledger proves
/// that this exact first-week read was opened.
enum FirstWeekHomeEntryAvailability {
    static func shouldPresent(
        snapshot: FirstWeekCoachingContract.Snapshot,
        growthEvents: [GrowthEvent]
    ) -> Bool {
        guard snapshot.nextAction == .reviewFirstWeekRead else { return true }
        guard let correlationID = snapshot.activation.correlationID
                ?? snapshot.activation.sessionID else {
            // Without a stable content-free key, fail open: hiding the read
            // would invent an acknowledgement that no owner can prove.
            return true
        }
        return !growthEvents.contains {
            $0.name == .weeklyReadViewed
                && $0.correlationID == correlationID
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

/// Streak copy contract — owner decision (roadmap §12.1): the streak is a
/// gentle, no-countdown marker, never a pressure anchor. Coach-voice fact
/// only ("4 day streak"), no exclamation, no "don't lose it", no
/// zero-state furniture. The V4.6 one-screen Home no longer renders a
/// streak line; the contract (and its tests) remains the single source of
/// display copy for any surface that does.
///
/// Returns nil below two days: a single rep is not a streak, and the
/// reset state renders nothing — drops update silently
/// (never punish-shame).
enum HomeStreakStatusCopy {
    static func line(days: Int) -> String? {
        guard days >= 2 else { return nil }
        return "\(days) day streak"
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

/// Resolves the single supporting row allowed beneath Today’s mission.
/// The row never competes with the primary CTA, and every input remains owned
/// by its existing store. Dismissal or completion naturally reveals the next
/// eligible item without persisting a parallel queue.
enum HomeSupportSurface: Equatable {
    case outcomeAcknowledgement
    case goalReview
    case progressReceipt
    case firstWeek
    case deferredSetup
    case ratingReview

    static func resolve(
        hasOutcomeAcknowledgement: Bool,
        hasGoalReview: Bool,
        hasProgressReceipt: Bool,
        hasFirstWeekEntry: Bool,
        hasDeferredSetup: Bool,
        hasRatingReview: Bool
    ) -> HomeSupportSurface? {
        if hasOutcomeAcknowledgement { return .outcomeAcknowledgement }
        if hasGoalReview { return .goalReview }
        // A due coaching step changes what the user should do next. A passive
        // earned receipt can wait in the same existing ledger until that step
        // is completed or acknowledged; no second row is introduced.
        if hasFirstWeekEntry { return .firstWeek }
        if hasProgressReceipt { return .progressReceipt }
        if hasDeferredSetup { return .deferredSetup }
        if hasRatingReview { return .ratingReview }
        return nil
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
    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var deferredCapture = DeferredProfileCaptureManager.shared
    @StateObject private var goalRefresh = GoalRefreshManager.shared
    @StateObject private var notificationPrePrompt = NotificationPrePromptManager.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared
    @StateObject private var league = LeagueManager.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var coachCheckInStore = CoachCheckInStore.shared
    @StateObject private var flowEventLog = FlowEventLog.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPracticeMode: PracticeMode = .timed
    @State private var showFreezeNudge = false
    @State private var homeCelebrationVisible = false
    @Binding private var navigationPath: NavigationPath
    @State private var showGoalReview: Bool = false
    @State private var showDeferredCoachingSetup = false
    @State private var showFirstWeekRecommendationAction = false
    @State private var showAdjustPractice = false
    @State private var earnedReceiptRefresh = UUID()
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    private let isOnboardingUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING_ONBOARDING")
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
            notificationPromptPresented: notificationPrePrompt.pendingPrompt
        ).suppressesUnderlyingHome
    }

    private var firstWeekSnapshot: FirstWeekCoachingContract.Snapshot? {
        // Observe the existing evidence owners so saving a check-in or adapting
        // a prescription updates the compact entry without a second state owner.
        _ = coachMemoryStore.currentMemory
        _ = coachCheckInStore.checkIns
        return FirstWeekCoachingSnapshotResolver.current()
    }

    private var firstWeekEntryPresentation: FirstWeekHomeEntryPresentation? {
        guard let snapshot = firstWeekSnapshot,
              FirstWeekHomeEntryAvailability.shouldPresent(
                snapshot: snapshot,
                growthEvents: flowEventLog.growthEvents()
              ) else {
            return nil
        }
        return FirstWeekHomeEntryPresentation.make(snapshot: snapshot)
    }

    var body: some View {
        homePresentationContent
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
            if !isEmbeddedInTabShell, let url = deepLinkRouter.pending {
                consumeDeepLink(url)
            }
        }
        .onReceive(Timer.publish(every: 300, on: .main, in: .common).autoconnect()) { _ in
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
    }

    private var homeNavigationContent: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { screenProxy in
            ZStack {
                // Today keeps the warm editorial canvas and a restrained
                // violet wash. The scroll view may extend under the status
                // bar, while the bounded mission supplies the real top inset.
                AppColor.warmCanvas
                    .ignoresSafeArea()

                // The reward screen's depth comes from light, not furniture.
                // Today borrows that authored atmosphere without borrowing its
                // celebration: two quiet, static halos frame the mission.
                ZStack {
                    RadialGradient(
                        colors: [AppColor.coachAccent.opacity(0.09), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 260
                    )
                    RadialGradient(
                        colors: [AppColor.brandBlueLight.opacity(0.06), .clear],
                        center: .bottomLeading,
                        startRadius: 0,
                        endRadius: 300
                    )
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        cohesiveHomeCards(topInset: screenProxy.safeAreaInsets.top)
                    }
                    .padding(.bottom, isEmbeddedInTabShell ? Spacing.tabRootNavigationClearance : HomeShortcutDockLayout.scrollBottomPadding)
                }
                // When the one-screen Today state fits the viewport, don't
                // rubber-band on drag; deeper content states still scroll.
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .ignoresSafeArea(edges: .top)
            }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: HomeShortcutDockLayout.contentClearance) {
                if !isEmbeddedInTabShell {
                    bottomShortcutDock
                }
            }
            .navigationDestination(for: AppDestination.self) { destination in
                AppDestinationView(destination: destination, navigationPath: $navigationPath)
            }
            .navigationDestination(
                isPresented: $showFirstWeekRecommendationAction
            ) {
                FirstWeekRecommendationActionView(
                    navigationPath: $navigationPath
                )
            }
        }
    }

    // MARK: - Ask Noum row (H1 — Home-gap fill)
    //
    // The Ask Noum coach door used to live as a white-on-gradient chip
    // nested inside the coach hero. It now renders as its own quiet white
    // row in the cohesive stack, matching the approved direction
    // (docs/UX_VISUAL_DIRECTION.md: "Ask Noum = white row + violet chat
    // chip").
    //
    // Card language stays the quiet-row register (white card, leading
    // tinted chip, evidence-scaled coach line, chevron) so Home reads as
    // one coherent stack, not a competing second hero. Copy stays the
    // shared, evidence-gated `HomeAskNoumShortcut` contract — no new copy
    // logic. Visibility follows `HomePrimaryActionPresentation.showsAskNoum`
    // (first completed rep), so the row is never empty furniture on a cold
    // start.

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

    /// Today has one primary mission, optional Ask Noum, and at most one
    /// supporting row. Due coaching actions outrank passive earned receipts;
    /// after the action is completed (or a Day-7 read is acknowledged), the
    /// same slot naturally reveals the still-pending receipt.
    private var homeSupportSurface: HomeSupportSurface? {
        HomeSupportSurface.resolve(
            hasOutcomeAcknowledgement: bigMomentStore.pendingOutcomeAck != nil,
            hasGoalReview: goalRefresh.shouldPresent,
            hasProgressReceipt: progressReceiptIdentity != nil,
            hasFirstWeekEntry: firstWeekEntryPresentation != nil,
            hasDeferredSetup: coachingProfileStore.profile == nil
                && coachingProfileStore.onboardingDraft?.hasCompletedFirstValue == true,
            hasRatingReview: ratingStore.pendingPeakGlow
                && ratingStore.rating.hasRatedEvidence
        )
    }

    @ViewBuilder
    private func cohesiveHomeCards(topInset: CGFloat) -> some View {
        let presentation = homePrimaryAction

        if presentation.kind == .pendingOutcomeCheckIn,
           let moment = bigMomentStore.pendingOutcomeCheckInMoment {
            BigMomentOutcomeInlineCard(moment: moment)
                .cardEntrance(0)
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, topInset + Spacing.lg)
        } else {
            // V3 mission — one rounded, bounded commitment surface with the
            // quiet Adjust row beneath it (one tertiary row per screen).
            // No cardEntrance here: the hero owns its entrance
            // choreography internally (blocks settle from 0.97/0.85 —
            // content is never invisible, unlike the 0-opacity card fade).
            HomeCoachCard(
                navigationPath: $navigationPath,
                completedRepsToday: dailyGoal.repsToday,
                targetRepsToday: dailyGoal.goalReps,
                showsPlanArc: false,
                recordsRecommendationExposure: !showFirstWeekRecommendationAction,
                heroTopInset: topInset
            )

            adjustPracticeRow
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xs)
        }

        switch homeSupportSurface {
        case .outcomeAcknowledgement:
            if let report = bigMomentStore.pendingOutcomeAck {
                BigMomentOutcomeAckCard(report: report) {
                    bigMomentStore.consumeOutcomeAck()
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.cardGap)
                .cardEntrance(1)
                .transition(.opacity)
            }
        case .goalReview:
            if showGoalReview {
                GoalRefreshInlineCard()
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, Spacing.cardGap)
                    .cardEntrance(1)
            } else {
                homeGoalReviewRow
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, Spacing.cardGap)
                    .cardEntrance(1)
            }
        case .progressReceipt:
            homeProgressReceipt
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.cardGap)
                .animation(
                    reduceMotion ? .v46ReduceMotionFade : .settle,
                    value: progressReceiptIdentity
                )
        case .firstWeek:
            if let firstWeekEntryPresentation {
                firstWeekEntryCard(firstWeekEntryPresentation)
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, Spacing.cardGap)
                    .cardEntrance(1)
            }
        case .deferredSetup:
            deferredCoachingSetupCard
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.cardGap)
                .cardEntrance(1)
        case .ratingReview:
            homeRatingReviewRow
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.cardGap)
                .cardEntrance(1)
        case nil:
            EmptyView()
        }

        if presentation.showsAskNoum {
            homeAskNoumRow
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.cardGap)
                .cardEntrance(2)
        }
    }

    /// V4.6 quiet adjustment (258:945) — the screen's one tertiary row.
    /// Every option launches exactly what it names: a per-rep answer clock
    /// (never rewriting saved settings — `AppDestination.timedPractice`'s
    /// documented semantics) or the manual practice catalogue.
    private var adjustPracticeRow: some View {
        Button {
            showAdjustPractice = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
                Text("Change this rep")
                    .font(Typography.caption.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                AppColor.innerSurface,
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text("Adjust practice"))
        .accessibilityHint(Text("Choose a different answer clock for this rep, or pick practice manually."))
        .accessibilityIdentifier("home.adjustPractice")
        .confirmationDialog(
            "Adjust practice",
            isPresented: $showAdjustPractice,
            titleVisibility: .visible
        ) {
            ForEach([TimedPracticeDifficulty.easy, .medium, .hard]) { difficulty in
                if let seconds = difficulty.duration {
                    Button("\(seconds)s answer clock") {
                        CoachHaptic.drillStart()
                        PracticeModeQuickStart.arm(for: .timed)
                        navigationPath.append(
                            AppDestination.timedPractice(difficulty: difficulty)
                        )
                    }
                }
            }
            Button("Free — no countdown") {
                CoachHaptic.drillStart()
                PracticeModeQuickStart.arm(for: .timed)
                navigationPath.append(AppDestination.timedPractice(difficulty: .free))
            }
            Button("Choose practice manually") {
                navigationPath.append(AppDestination.practiceSelection)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This shapes today's rep only — your plan and saved settings don't change.")
        }
    }

    /// One calm receipt replaces the former tier, daily-goal and path
    /// celebration overlays. Persistence remains owned by the existing
    /// managers; Home only acknowledges one pending event at a time.
    @ViewBuilder
    private var homeProgressReceipt: some View {
        if let earned = earnedEvidenceReceipt {
            progressReceipt(
                title: "New evidence banked",
                body: earned.body,
                tint: AppColor.positive,
                onDismiss: {
                    V46EarnedEvidenceLedger.dismissReceipt(
                        earned.id,
                        accountID: authManager.currentAccountID
                    )
                    earnedReceiptRefresh = UUID()
                }
            )
        } else if let promotion = league.pendingPromotion {
            progressReceipt(
                title: "Peer group reached",
                body: "You're now in the \(promotion.newTier.title) peer group.",
                tint: promotion.newTier.tint,
                onDismiss: league.consumePendingPromotion
            )
        } else if let node = pendingPathNode {
            progressReceipt(
                title: "Spoken progress saved",
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

    /// V4.6 collapsed earned signal (258:1078 follow-up): after the hero's
    /// one-time announcement, later Home visits show one dismissible line.
    /// Backed by the same ledger the hero acknowledges into; the 10-minute
    /// floor keeps the announcement and the receipt from co-presenting.
    private var earnedEvidenceReceipt: (id: UUID, body: String)? {
        _ = earnedReceiptRefresh
        let accountID = authManager.currentAccountID
        let ackDates = V46EarnedEvidenceLedger.ackDates(accountID: accountID)
        let dismissed = V46EarnedEvidenceLedger.receiptDismissedIDs(accountID: accountID)
        let now = Date()
        guard let latest = recommendationLearningStore.outcomes
            .filter({ outcome in
                guard let result = outcome.transcriptRetryComparison?.result,
                      result == .improved || result == .held,
                      let ackedAt = ackDates[outcome.id] else { return false }
                return !dismissed.contains(outcome.id)
                    && now.timeIntervalSince(ackedAt) > 600
                    && now.timeIntervalSince(outcome.completedAt) < 36 * 3600
            })
            .max(by: { $0.completedAt < $1.completedAt }) else { return nil }

        let pressure = latest.executedDemand?.timedDifficulty.map { $0 == .medium || $0 == .hard } ?? false
        let lever = latest.transcriptRetryTarget?.lever.focusLabel ?? "your target"
        return (
            latest.id,
            "Held\(pressure ? " under pressure" : "") \u{2014} \(lever), on the retry."
        )
    }

    /// Identity of the receipt currently rendered by `homeProgressReceipt`
    /// — mirrors its precedence exactly (V4.6.1) so insertion, replacement
    /// and dismissal all animate as one settled list change. Nil when no
    /// receipt is pending.
    private var progressReceiptIdentity: String? {
        if let earned = earnedEvidenceReceipt { return "earned-\(earned.id.uuidString)" }
        if let promotion = league.pendingPromotion { return "league-\(promotion.newTier)" }
        if let node = pendingPathNode { return "path-\(node.id)" }
        if dailyGoal.pendingGoalCelebration { return "dailyGoal" }
        return nil
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
        // Settle in, fade out; Reduce Motion collapses both to a fade.
        // The driving animation is value-scoped at the call site.
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.97)),
                    removal: .opacity
                )
        )
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
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.10), in: Circle())
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
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(body)")
        .accessibilityIdentifier(accessibilityID)
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

    private func firstWeekEntryCard(
        _ presentation: FirstWeekHomeEntryPresentation
    ) -> some View {
        let tint = presentation.style == .durableRead
            ? AppColor.pro
            : AppColor.brandBlue

        return Button {
            openFirstWeekEntry(presentation)
        } label: {
            // Keep this a quiet row, but let localized and accessibility copy
            // wrap instead of silently discarding the end of the title.
            HStack(alignment: .center, spacing: Spacing.sm) {
                Image(systemName: presentation.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                Text(presentation.title)
                    .font(Typography.cardLabel)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.title). \(presentation.body)")
        .accessibilityIdentifier(presentation.accessibilityIdentifier)
        .accessibilityHint(presentation.accessibilityHint)
    }

    private func openFirstWeekEntry(
        _ presentation: FirstWeekHomeEntryPresentation
    ) {
        // Preserve the existing Day-7 push on Home. Earlier steps route
        // through AppShell so practice and check-in owners retain their tabs.
        if presentation.style == .durableRead {
            navigationPath.append(AppDestination.firstWeekRead)
        } else if AppTab.isFirstWeekSpokenProofRoute(presentation.route) {
            startFirstWeekSpokenProof()
        } else if presentation.route == FirstWeekNotificationAttribution.recommendationActionRoute {
            showFirstWeekRecommendationAction = true
        } else if isEmbeddedInTabShell {
            deepLinkRouter.pending = presentation.route
        } else if let destination = AppTab.rootDestination(for: presentation.route) {
            replaceNavigationPath(with: destination)
        } else {
            consumeDeepLink(presentation.route)
        }
    }

    /// Day 0 uses Home as a content-free rendezvous. Re-resolve the live
    /// contract only after the user's tap, then create one process-local
    /// prompt token and push the existing Timed engine. This path never arms
    /// Quick Start, asks for microphone permission, or opens capture itself.
    private func startFirstWeekSpokenProof() {
        guard let snapshot = FirstWeekCoachingSnapshotResolver.projection(at: Date()),
              snapshot.nextAction == .recordSpokenBaseline,
              let preparation = AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(
                accountID: snapshot.accountID
              ),
              let promptToken = preparation.promptToken,
              !preparation.automaticallyStartsCapture else {
            return
        }
        showFirstWeekRecommendationAction = false
        replaceNavigationPath(
            with: .timedPracticePrompt(token: promptToken, difficulty: .medium)
        )
    }

    private var homeAskNoumRow: some View {
        let tint = AppColor.pro // brand violet — the chat/ask hue
        let body = HomeAskNoumShortcut.body(sessionCount: sessionStore.progressEligibleSessionCount)
        return Button {
            navigationPath.append(AppDestination.askNoum)
        } label: {
            // V4.6 density: one-line quiet row; the evidence line stays in
            // the VoiceOver label and inside the thread itself.
            HStack(alignment: .center, spacing: Spacing.sm) {
                Image(systemName: "message.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.proText)
                    .frame(width: 32, height: 32)
                    .background(AppColor.proQuietSurface, in: Circle())
                    .accessibilityHidden(true)

                Text(HomeAskNoumShortcut.title)
                    .font(Typography.cardLabel)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(HomeAskNoumShortcut.title). \(body)."))
        .accessibilityIdentifier(HomeAskNoumShortcut.accessibilityIdentifier)
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
            AppColor.screenBackground
                .opacity(HomeShortcutDockLayout.backdropTopOpacity)
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
            if AppTab.isFirstWeekSpokenProofRoute(url) {
                replaceNavigationPath()
                startFirstWeekSpokenProof()
            } else if AppTab.isFirstWeekRecommendationActionRoute(url) {
                replaceNavigationPath()
                showFirstWeekRecommendationAction = true
            } else {
                replaceNavigationPath()
            }
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
            replaceNavigationPath(with: .bigMomentIntake)
        case "summary":
            if let sessionID = AutoGuidedFirstRep.pendingSummarySessionID(from: url),
               let accountID = authManager.currentAccountID,
               let session = AutoGuidedFirstRep.pendingSummarySession(
                   in: sessionStore.sessions,
                   accountID: accountID
               ),
               session.id == sessionID,
               let payload = SummaryDataStore.shared.storeRecoveredTimedSummary(
                   session: session,
                   recentSessions: sessionStore.sessions,
                   profile: coachingProfileStore.profile
               ) {
                replaceNavigationPath(with: .summary(payload))
                return
            }
#if DEBUG
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
                    sessionPrompt: session.prompt,
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
        guard let celebration = pathProgress.pendingCelebration,
              let source = sessionStore.sessions.first(where: {
                  $0.id == celebration.triggeringSessionID
              }),
              PracticeProgressEligibility.qualifies(source) else {
            return nil
        }
        return PathNodeRegistry.all.first(where: {
            $0.0.id == celebration.nodeID
        })?.0
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
