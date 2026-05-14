import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Onboarding Hero Manager

/// Tracks whether the brand-new user has seen the 3-screen value-prop hero.
///
/// Design principles:
/// - **Show once.** The hero is a first-impression surface. After the user
///   has seen it (whether they tapped "Begin" or "Skip"), we never replay it.
/// - **Per-account scoped.** A device that signs in with a fresh account
///   should re-see the hero — onboarding is a per-account property, not a
///   per-device one. Mirrors `StreakFreezeManager`'s scoping pattern.
/// - **Pre-auth safe.** A brand-new install has no `currentAccountID` yet
///   (the splash hands off before sign-in completes). We fall back to
///   `"guest"` — the same fallback `StreakFreezeManager` uses — so the
///   "seen" state still persists across the splash → ContentView transition.
@MainActor
@available(iOS 17.0, *)
final class OnboardingHeroManager: ObservableObject {
    static let shared = OnboardingHeroManager()

    // MARK: Published

    /// Whether the current account has already seen the hero. False on
    /// brand-new installs / fresh accounts — that's the single trigger
    /// for `NoumApp` to present the cover.
    @Published private(set) var hasSeen: Bool = false

    // MARK: Storage

    private let seenKeyPrefix = "noum.onboarding.hero.seen."

    private init() {
        load()
    }

    // MARK: - Account scoping

    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private var seenKey: String { seenKeyPrefix + Self.currentAccountID() }

    // MARK: - Public API

    /// Re-reads persisted state for the now-current account. Call after
    /// auth events if the hero needs to re-evaluate (e.g. user signs out
    /// and a different account signs in).
    func reloadForCurrentAccount() {
        load()
    }

    /// Marks the hero as seen for the current account. Called when the
    /// user taps "Begin" or "Skip". Idempotent.
    func markSeen() {
        guard !hasSeen else { return }
        hasSeen = true
        UserDefaults.standard.set(true, forKey: seenKey)
    }

    // MARK: - Internals

    private func load() {
        hasSeen = UserDefaults.standard.bool(forKey: seenKey)
    }
}
