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
    @State private var showSplash = true
    @StateObject private var onboardingHero = OnboardingHeroManager.shared
    @StateObject private var localeSettings = LocaleSettingsManager.shared
    @Environment(\.scenePhase) private var scenePhase
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")

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
        Group {
            if showSplash && !isUITesting {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation { showSplash = false }
                        }
                    }
            } else {
                ContentView()
                    .fullScreenCover(isPresented: heroPresented) {
                        // Manager persists the seen flag inside the view
                        // when "Begin" or "Skip" is tapped; the published
                        // change propagates back to `heroPresented` and
                        // the cover dismisses automatically.
                        OnboardingHeroView(onFinish: {})
                    }
            }
        }
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

    /// Drives the onboarding hero `fullScreenCover`. Presents only for
    /// brand-new users who have never seen the hero on the current
    /// account. UI testing bypasses the hero so the screenshot-tour
    /// suite isn't blocked by it.
    private var heroPresented: Binding<Bool> {
        Binding(
            get: { !isUITesting && !onboardingHero.hasSeen },
            set: { newValue in
                if newValue == false {
                    onboardingHero.markSeen()
                }
            }
        )
    }

    /// Routes an incoming `noum://` URL to the right surface.
    /// - `noum://friend/<accountID>` — friend invite (handled from the
    ///   profile/social route).
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
#endif
