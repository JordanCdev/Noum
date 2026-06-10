//
//  NoumApp.swift
//  Noum
//
//  Created by Jordan Coaten on 25/01/2025.
//

#if canImport(SwiftUI)
import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct NoumApp: App {
    @StateObject private var firstRunOnboarding = FirstRunOnboardingManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var localeSettings = LocaleSettingsManager.shared
    @State private var uiTestingFirstRunCoverDismissed = false
    @Environment(\.scenePhase) private var scenePhase
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    private let isRealFirstRunUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING_REAL_FIRST_RUN")

    init() {
        FirebaseBootstrap.configure()
        TypographyDebug.logRegisteredFamiliesOnce()
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        let hasSeed = args.contains("UI_TESTING_SEED")
        // `UI_TESTING_SEED_FORCE` always reseeds — used by ScreenshotTour
        // so the test starts from a deterministic populated state every
        // run. Plain `UI_TESTING_SEED` only seeds when the store is empty
        // (preserves hand-test data across launches).
        let forceSeed = args.contains("UI_TESTING_SEED_FORCE")
        if hasSeed || forceSeed {
            // Inject the "improving intermediate" dev profile before any view
            // binds to PracticeSessionStore so screenshot-tour UI tests open on
            // a populated state instead of the first-run empty card.
            if forceSeed || PracticeSessionStore.shared.sessions.isEmpty {
                // Capture tooling can pick which dev persona to seed via
                // `UI_TESTING_SEED_PROFILE <rawValue>` (the cold/empty
                // first-run state is driven by simply omitting the seed
                // args). Defaults to the improving-intermediate demo persona
                // that ScreenshotTour has always used.
                let seededProfile: SeedProfile = {
                    if let i = args.firstIndex(of: "UI_TESTING_SEED_PROFILE"),
                       i + 1 < args.count,
                       let picked = SeedProfile(rawValue: args[i + 1]) {
                        return picked
                    }
                    return .improvingIntermediate
                }()
                DevSeedData.injectProfile(seededProfile)
                // Suppress overlay celebrations that fire from the seed's
                // rating change (tier promotion) or persisted pending state
                // (daily goal, path node, lesson) — they otherwise cover
                // Home and intercept tap targets in the screenshot tour.
                LeagueManager.shared.suppressCelebrationsForTesting()
                DailyGoalManager.shared.consumeGoalCelebration()
                PathProgressManager.shared.consumeCelebration()
                LessonStore.shared.consumeCelebration()
            }
        }
        // `FORCE_GOAL_REFRESH` / `FORCE_NOTIFICATION_PROMPT` flip the
        // respective manager flags so ScreenshotTour can capture sheets
        // that normally fire on a cadence (2-week goal refresh) or
        // first-session-only (notification pre-prompt).
        if args.contains("FORCE_GOAL_REFRESH") {
            DispatchQueue.main.async {
                GoalRefreshManager.shared.shouldPresent = true
            }
        }
        if args.contains("FORCE_NOTIFICATION_PROMPT") {
            DispatchQueue.main.async {
                NotificationPrePromptManager.shared.pendingPrompt = true
            }
        }
        // Lets UI tests exercise the real app-level first-run cover while
        // preserving the normal `UI_TESTING` bypass used by seeded tours.
        if args.contains("UI_TESTING_REAL_FIRST_RUN") {
            PracticeSessionStore.shared.endSession()
            ProfileManager.shared.replaceFromRemote(0)
            CoachingProfileStore.shared.replaceForDebug(nil)
            FirstRunOnboardingManager.shared.resetForDebug()
        }
        // `-DeepLink noum://<host>` launch arg lets the noum-screenshots
        // skill drive tab nav via `simctl launch --terminate-running-process`
        // without triggering iOS's "Open in Noum?" confirmation that blocks
        // headless `simctl openurl` automation.
        if let idx = args.firstIndex(of: "-DeepLink"),
           idx + 1 < args.count,
           let url = URL(string: args[idx + 1]) {
            DispatchQueue.main.async {
                DeepLinkRouter.shared.pending = url
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        rootContent
        .preferredColorScheme(.light)
        // M3 typography redesign: default body text uses Manrope. Views can
        // override with the Figtree-backed `Typography.headline` /
        // `Typography.cardTitle` etc. for headlines.
        .environment(\.font, Typography.body)
        // M13: drive the in-app locale from LocaleSettingsManager so any
        // `Text("key")` call site reads from the matching translation in
        // `Localizable.xcstrings`. The .id(...) modifier forces a re-render
        // when the user picks a different locale in Settings — without it,
        // already-rendered Text views keep their original locale.
        .environment(\.locale, Locale(identifier: localeSettings.current.code))
        .id(localeSettings.current.code)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            // Re-arm scheduled notifications with the latest streak +
            // freezes + reps-today snapshot. Notification copy is
            // streak-aware via NotificationCopy, so the body that fires
            // tonight reflects what the user actually has on the line.
            NotificationManager.shared.refreshScheduledNotifications()
            // Push the freshest state to the App Group so the widget
            // doesn't render stale data after a backgrounded session.
            if #available(iOS 17.0, *) {
                SharedNoumStateMirror.refresh()
            }
            // M22 — Monthly Coach Letter auto-fire. Idempotent (guards
            // on day-of-month + prior-letter-exists + non-empty history).
            // Safe to call on every scene activation.
            if #available(iOS 17.0, *) {
                Task { @MainActor in
                    CoachLetterCoordinator.autoFireIfDue()
                }
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if let overlayHarness = OverlayScreenshotHarnessKind.requested() {
            OverlayScreenshotHarnessView(kind: overlayHarness)
        } else if isRealFirstRunUITesting && !uiTestingFirstRunCoverDismissed {
            // UI-test-only proof path. Rendering onboarding as the temporary
            // root avoids a presentation race where child Home sheets can win
            // before the app-level first-run cover appears on reused sims.
            CoachingOnboardingView {
                uiTestingFirstRunCoverDismissed = true
                markFirstRunCompletedIfProfileExists()
            }
            .interactiveDismissDisabled(true)
        } else {
            ContentView()
                .fullScreenCover(
                    isPresented: firstRunOnboardingPresented,
                    onDismiss: {
                        markFirstRunCompletedIfProfileExists()
                    }
                ) {
                    CoachingOnboardingView()
                        .interactiveDismissDisabled(true)
                }
        }
        #else
        if isRealFirstRunUITesting && !uiTestingFirstRunCoverDismissed {
            // UI-test-only proof path. Rendering onboarding as the temporary
            // root avoids a presentation race where child Home sheets can win
            // before the app-level first-run cover appears on reused sims.
            CoachingOnboardingView {
                uiTestingFirstRunCoverDismissed = true
                markFirstRunCompletedIfProfileExists()
            }
            .interactiveDismissDisabled(true)
        } else {
            ContentView()
                .fullScreenCover(
                    isPresented: firstRunOnboardingPresented,
                    onDismiss: {
                        markFirstRunCompletedIfProfileExists()
                    }
                ) {
                    CoachingOnboardingView()
                        .interactiveDismissDisabled(true)
                }
        }
        #endif
    }

    /// Drives the first-run coaching intake. UI testing bypasses it so the
    /// screenshot-tour suite is not blocked. `UI_TESTING_REAL_FIRST_RUN`
    /// opts back into the real app-level cover so the dismiss → Train route
    /// can be verified without the older pinned `UI_TESTING_ONBOARDING`
    /// harness.
    private var firstRunOnboardingPresented: Binding<Bool> {
        Binding(
            get: {
                if isRealFirstRunUITesting {
                    return !uiTestingFirstRunCoverDismissed
                }
                return FirstRunOnboardingGate.shouldPresent(
                    hasCompletedFirstRun: firstRunOnboarding.hasSeen,
                    hasCoachingProfile: coachingProfileStore.profile != nil,
                    isUITesting: isUITesting && !isRealFirstRunUITesting
                )
            },
            set: { newValue in
                if newValue == false {
                    uiTestingFirstRunCoverDismissed = true
                    markFirstRunCompletedIfProfileExists()
                }
            }
        )
    }

    private func markFirstRunCompletedIfProfileExists() {
        guard coachingProfileStore.profile != nil else { return }
        firstRunOnboarding.markSeen()
    }

    /// Routes an incoming `noum://` URL to the right surface.
    /// - `noum://lesson/<id>` — open a specific lesson.
    /// - `noum://practice` — open the practice picker.
    /// Falls through to the default screen if the URL is unrecognised.
    private func handleIncomingURL(_ url: URL) {
#if canImport(GoogleSignIn)
        // GoogleSignIn handles its own URL scheme — let it consume first.
        if GIDSignIn.sharedInstance.handle(url) { return }
#endif
        guard url.scheme == "noum" else { return }
        // The full deep-link router lives on the home screen, which holds
        // the navigationPath. Surface the URL via a global so ContentView
        // can pick it up on next refresh.
        DeepLinkRouter.shared.pending = url
    }
}

// MARK: - Deep link router

/// Buffer the latest pending URL so `ContentView` can route once it owns
/// the `NavigationPath`. Cleared on consumption.
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    @Published private(set) var hasReceivedRouteThisLaunch = false
    @Published var pending: URL? {
        didSet {
            if pending != nil {
                hasReceivedRouteThisLaunch = true
            }
        }
    }
    private init() {}
}

// MARK: - UI-test overlay screenshot harness

@available(iOS 17.0, macOS 12.0, *)
enum OverlayScreenshotHarnessKind: String, CaseIterable {
    case progression
    case personalBest
    case levelUp
    case achievementUnlock

    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Self? {
        guard let index = arguments.firstIndex(of: "UI_TESTING_OVERLAY"),
              index + 1 < arguments.count else {
            return nil
        }
        return Self(rawValue: arguments[index + 1])
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct OverlayScreenshotHarnessView: View {
    let kind: OverlayScreenshotHarnessKind

    var body: some View {
        ZStack {
            switch kind {
            case .progression:
                PostSessionProgressionView(
                    xpEarned: 86,
                    previousXP: 1_280,
                    newXP: 1_366,
                    previousLevel: "Novice Speaker II",
                    newLevel: "Novice Speaker II",
                    achievementProgress: sampleProgressDeltas,
                    newUnlocks: [],
                    onContinue: {}
                )
            case .personalBest:
                PersonalBestCelebrationScreen(
                    scoreValue: 8,
                    scoreAccent: AppColor.brandBlue,
                    modeName: PracticeMode.timed.displayLabel,
                    previousBest: "Previous best: 7/10",
                    onContinue: {},
                    proof: sampleProofMoment
                )
            case .levelUp:
                LevelUpCelebrationScreen(
                    newLevel: PracticeVolumeNarration.title(forXP: 6_320),
                    previousLevel: PracticeVolumeNarration.title(forXP: 5_980),
                    xp: 6_320,
                    xpProgress: 0.32,
                    onContinue: {}
                )
            case .achievementUnlock:
                AchievementUnlockCelebration(
                    tier: sampleAchievementTier,
                    onContinue: {}
                )
            }
        }
        .accessibilityIdentifier("overlayHarness.\(kind.rawValue)")
    }

    private var sampleAchievementTier: AchievementTier {
        AchievementStore.tier(for: "clarity_1") ?? AchievementStore.allTiers[0]
    }

    private var sampleProgressDeltas: [AchievementProgressDelta] {
        [
            AchievementProgressDelta(
                id: "clarity_1",
                title: "Clean Run",
                previousProgress: 0.0,
                newProgress: 1.0,
                progressLabel: "1/1"
            ),
            AchievementProgressDelta(
                id: "volume_10",
                title: "Double Digits",
                previousProgress: 0.8,
                newProgress: 0.9,
                progressLabel: "9/10"
            )
        ]
    }

    private var sampleProofMoment: ProofMoment {
        ProofMoment(
            quote: "We should decide the owner, the deadline, and the first customer impact.",
            technique: "Clear structure",
            claim: "That is the concise structure you have been building.",
            sessionDate: Date(),
            isAIBacked: false,
            generatedAt: Date()
        )
    }
}
#endif
