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
    @Environment(\.scenePhase) private var scenePhase
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")

    init() {
        FirebaseBootstrap.configure()
        TypographyDebug.logRegisteredFamiliesOnce()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UI_TESTING_SEED") {
            // Inject the "improving intermediate" dev profile before any view
            // binds to PracticeSessionStore so screenshot-tour UI tests open on
            // a populated state instead of the first-run empty card.
            if PracticeSessionStore.shared.sessions.isEmpty {
                DevSeedData.injectProfile(.improvingIntermediate)
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
    /// - `noum://friend/<accountID>` — friend invite (handled inside
    ///   SocialProfileView's QR scanner; we surface the app to that tab).
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
    @Published var pending: URL?
    private init() {}
}
#endif
