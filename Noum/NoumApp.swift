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
#if canImport(GoogleSignIn)
        .onOpenURL { url in
            GIDSignIn.sharedInstance.handle(url)
        }
#endif
    }
}
#endif

