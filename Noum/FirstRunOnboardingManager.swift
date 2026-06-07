import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - First Run Onboarding Manager

enum FirstRunOnboardingGate {
    static func shouldPresent(
        hasCompletedFirstRun: Bool,
        hasCoachingProfile: Bool,
        isUITesting: Bool
    ) -> Bool {
        !isUITesting && !hasCompletedFirstRun && !hasCoachingProfile
    }
}

/// Tracks whether the brand-new user has completed the first-run coaching
/// intake. The intake is the product proof path: ask three questions, then
/// send the user to their first real rep.
///
/// Design principles:
/// - **Show once.** After the user completes the intake, we never replay it.
/// - **Per-account scoped.** A device that signs in with a fresh account
///   should see onboarding — this is a per-account property, not a per-device
///   one. Mirrors `StreakFreezeManager`'s scoping pattern.
/// - **Pre-auth safe.** A brand-new install has no `currentAccountID` yet.
///   We fall back to `"guest"` — the same fallback `StreakFreezeManager`
///   uses — so first-run state still persists before sign-in completes.
@MainActor
@available(iOS 17.0, *)
final class FirstRunOnboardingManager: ObservableObject {
    static let shared = FirstRunOnboardingManager()

    // MARK: Published

    /// Whether the current account has already completed first-run
    /// onboarding. False on brand-new installs / fresh accounts.
    @Published private(set) var hasSeen: Bool = false

    // MARK: Storage

    private let seenKeyPrefix = "noum.onboarding.firstRun.completed."

    private init() {
        load()
    }

    // MARK: - Account scoping

    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private var seenKey: String { seenKeyPrefix + Self.currentAccountID() }

    // MARK: - Public API

    /// Re-reads persisted state for the now-current account after auth
    /// changes.
    func reloadForCurrentAccount() {
        load()
    }

    /// Marks first-run onboarding as completed for the current account.
    /// Idempotent.
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
