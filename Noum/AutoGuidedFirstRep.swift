import Foundation

// MARK: - Auto-Guided First Rep

/// Feature flag + one-shot state for the **auto-guided first rep** — the
/// first-run-only path that skips the practice picker and drops a brand-new
/// user straight into a single ~20–30s guided micro-rep, so they are *speaking*
/// within seconds of finishing onboarding instead of choosing a mode first.
/// Closing this "time-to-first-spoken-word" gap is the single biggest lever on
/// the acquisition axis (see `docs/SPEC_first_rep_auto_guided.md`).
///
/// This type holds only the routing decision and its one-shot persistence; the
/// rep itself fully **reuses** the existing Timed engine via the
/// `PracticeModeQuickStart` auto-begin handshake and `SummaryView`'s honest
/// read. Nothing here forks the rep pipeline.
///
/// Design principles (mirrors `PracticeModeQuickStart` / `FirstRunOnboardingManager`):
/// - **Default OFF.** `enabled` is false until an on-device felt-QA pass signs
///   off on the cold-start moment (the spec's gate). A debug build can flip the
///   `enabledOverrideKey` to exercise the path without recompiling.
/// - **One-shot, per-account.** `firstRepCompleted` is scoped by account id the
///   same way `FirstRunOnboardingManager.hasSeen` is, so a fresh account on the
///   same device still gets its first guided rep.
/// - **Marked at the fork, not at finalize.** The router sets the flag *before*
///   launching the rep, so an app-kill mid-rep can never re-trigger the
///   auto-guide (and never re-arm the mic on next launch).
/// - **No overclaim.** The rep runs non-pressure, so `isRated` stays false and
///   the first read carries no rating/peak/league/trend claim
///   (`hasRatedEvidence` honesty gate is respected by reuse, not bypassed).
@MainActor
@available(iOS 17.0, *)
enum AutoGuidedFirstRep {

    // MARK: Feature flag

    /// Compile-time default. Stays `false` until felt-QA signs off; flipping
    /// this is the device-owning session's one-line change after the feel pass.
    private static let defaultEnabled = false

    /// UserDefaults override so a felt-QA build can enable the path without a
    /// recompile. Absent → falls back to `defaultEnabled`.
    static let enabledOverrideKey = "noum.firstRep.autoGuided.enabledOverride"

    /// Whether the auto-guided first rep is live. Default-off; an override key
    /// (set in a debug / felt-QA build) can force it on.
    static var enabled: Bool {
        if UserDefaults.standard.object(forKey: enabledOverrideKey) != nil {
            return UserDefaults.standard.bool(forKey: enabledOverrideKey)
        }
        return defaultEnabled
    }

    // MARK: One-shot state (per-account)

    private static let completedKeyPrefix = "noum.firstRep.autoGuided.completed."

    /// Per-account scoping, identical fallback to `FirstRunOnboardingManager`
    /// so pre-auth (brand-new install, no account yet) still persists state.
    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private static var completedKey: String {
        completedKeyPrefix + currentAccountID()
    }

    /// True once the current account has done (or escaped) its first guided rep.
    static var firstRepCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    /// Mark the one-shot done. Idempotent. Called at the *fork* (before the rep
    /// launches) and on the "pick a different drill" escape, so neither
    /// completion, an app-kill mid-rep, nor a back-out can re-fire the path.
    static func markFirstRepCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    // MARK: Routing decision

    /// Whether the cold `noum://train` deep link should route to the guided
    /// first rep instead of the picker. True only when the flag is on, the user
    /// has finished onboarding, and the one-shot has not fired.
    static func shouldAutoGuide(hasSeenOnboarding: Bool) -> Bool {
        enabled && hasSeenOnboarding && !firstRepCompleted
    }

    // MARK: Prompt seeding

    /// The framing opener handed to the user so they never face a blank record
    /// screen wondering what to say (the friction that kills rep #1). Warm,
    /// answerable, ~20–30s.
    static let framingPrompt = "Tell me about something you did this week that you're proud of."

    /// Seed the opener into the exact key the Timed engine already consumes
    /// (`TimedPracticeView.consumeSeededPrompt`), so the guided rep starts on a
    /// supplied prompt instead of awaiting topic generation — keeping
    /// time-to-first-word low. Reuses the existing seeding contract; does not
    /// invent a new key.
    static func seedFramingPrompt() {
        UserDefaults.standard.set(framingPrompt, forKey: "timedPractice.suggestedPrompt")
    }

    // MARK: Debug

    #if DEBUG
    /// Re-arm the auto-guided path for felt-QA on a real build (clears the
    /// one-shot for the current account). Mirrors
    /// `FirstRunOnboardingManager.resetForDebug`.
    static func resetForDebug() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
    #endif
}
