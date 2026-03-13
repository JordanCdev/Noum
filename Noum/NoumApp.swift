//
//  NoumApp.swift
//  Noum
//
//  Created by Jordan Coaten on 25/01/2025.
//

#if canImport(SwiftUI)
import SwiftUI

struct NoumApp: App {
    @State private var showSplash = true
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")

    var body: some Scene {
        WindowGroup {
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
    }
}
#endif
