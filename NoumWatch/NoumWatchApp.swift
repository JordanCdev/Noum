import SwiftUI

// MARK: - Noum Watch App
//
// A single-screen watchOS glance. No tabs, no navigation stack — the
// watch surface is intentionally one cohesive view that mirrors the
// daily-rhythm state from the iOS app via the shared App Group.
//
// Tap behaviour: the CTA at the bottom routes back to the iPhone via
// `WKExtension.openSystemURL` and the `noum://practice` deep link the
// iOS app already handles.

@main
struct NoumWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
    }
}
