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
            }
        }
        .preferredColorScheme(.light)
        // M3 typography redesign: default body text uses Manrope. Views can
        // override with the Figtree-backed `Typography.headline` /
        // `Typography.cardTitle` etc. for headlines.
        .environment(\.font, Typography.body)
#if canImport(GoogleSignIn)
        .onOpenURL { url in
            GIDSignIn.sharedInstance.handle(url)
        }
#endif
    }
}
#endif
