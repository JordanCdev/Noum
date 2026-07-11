import Foundation

// MARK: - First-run onboarding policy

/// Pure root-routing policy for the first coaching intake.
///
/// `CoachingProfileStore.profile` is the only completion truth. The policy
/// waits until AuthManager has established a durable identity and hydrated the
/// account's local stores, then presents onboarding only when that account has
/// no saved coaching profile. No second "has seen onboarding" flag is owned
/// here.
enum FirstRunOnboardingGate {
    /// Legacy key retained only so account deletion can remove data written by
    /// builds that predate profile-as-truth onboarding.
    static let legacyCompletedKeyPrefix = "noum.onboarding.firstRun.completed."

    static func shouldPresent(
        hasDurableIdentity: Bool,
        hasHydratedAccountStores: Bool,
        hasCoachingProfile: Bool,
        isUITesting: Bool
    ) -> Bool {
        hasDurableIdentity
            && hasHydratedAccountStores
            && !isUITesting
            && !hasCoachingProfile
    }
}
