import Foundation

// MARK: - Auto-Guided First Rep

/// Feature flag + one-shot launch preparation for the **auto-guided first
/// rep**. Routing remains owned by NoumApp → DeepLinkRouter → AppShell; this
/// type only seeds and arms the existing Timed engine when release QA enables it.
/// Closing this "time-to-first-spoken-word" gap is the single biggest lever on
/// the acquisition axis (see `docs/SPEC_first_rep_auto_guided.md`).
///
/// This type holds only the routing decision and its one-shot persistence; the
/// rep itself fully **reuses** the existing Timed engine via the
/// `PracticeModeQuickStart` auto-begin handshake and `SummaryView`'s honest
/// read. Nothing here forks the rep pipeline.
///
/// Design principles (mirrors `PracticeModeQuickStart` and the app-level
/// profile-as-truth gate):
/// - **Default OFF until the M26 signed-device release gate passes.** The path
///   remains debug-overridable through the existing key for the required QA.
/// - **One-shot, per-account.** `firstRepCompleted` is scoped by account id, so
///   a fresh account on the same device still gets its first guided rep.
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

    /// Release default remains off until the signed-device permission,
    /// interruption, relaunch, and consent matrix is complete.
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

    static let completedKeyPrefix = "noum.firstRep.autoGuided.completed."

    /// Account bootstrap completes before onboarding, but keep a defensive
    /// guest fallback for debug/test helpers that invoke this type directly.
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
    private static func markFirstRepCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    // MARK: Launch preparation

    struct LaunchPreparation: Equatable {
        /// Opaque, process-local route identity. It carries no prompt or
        /// account content and is nil only when defensive account lookup made
        /// the prompt unavailable.
        let promptToken: UUID?
    }

    /// Production form used by the onboarding router so the exact Timed
    /// destination carries the prompt token it prepared.
    static func prepareLaunch(
        hasCompletedOnboarding: Bool,
        accountID: String? = nil
    ) -> LaunchPreparation? {
        guard enabled, hasCompletedOnboarding, !firstRepCompleted else {
            return nil
        }
        markFirstRepCompleted()
        let promptToken = seedFramingPrompt(accountID: accountID)
        armFastStartOnce()
        PracticeModeQuickStart.arm(for: .timed)
        return LaunchPreparation(promptToken: promptToken)
    }

    /// Arms the existing Timed quick-start path once, after profile persistence
    /// succeeds. The caller still queues the canonical
    /// `noum://practice/timed` route whether this returns true or false. Tests
    /// and compatibility callers can use this Boolean form; production routing
    /// uses `prepareLaunch` so it can carry the opaque token.
    @discardableResult
    static func prepareLaunchIfNeeded(
        hasCompletedOnboarding: Bool,
        accountID: String? = nil
    ) -> Bool {
        prepareLaunch(
            hasCompletedOnboarding: hasCompletedOnboarding,
            accountID: accountID
        ) != nil
    }

    // MARK: Prompt seeding

    /// The framing opener handed to the user so they never face a blank record
    /// screen wondering what to say (the friction that kills rep #1). Warm,
    /// answerable, ~20–30s.
    static let framingPrompt = "Tell me about something you did this week that you're proud of."

    /// Seed the opener into the process-local, account-bound handoff consumed by
    /// `TimedPracticeView`, so the guided rep starts on a supplied prompt
    /// without persisting user-visible content under a device-global key.
    @discardableResult
    static func seedFramingPrompt(accountID: String? = nil) -> UUID? {
        if let accountID {
            return TimedPracticePromptHandoff.shared.offerToken(
                framingPrompt,
                accountID: accountID
            )
        }
        return TimedPracticePromptHandoff.shared.offerToken(framingPrompt)
    }

    // MARK: Fast start (per-rep one-shot)

    /// One-shot key that tells the *next* Timed rep to start instantly — no 15s
    /// prep countdown, prompt kept visible — WITHOUT mutating the user's
    /// persistent `enableThinkingTime` / `keepPromptVisible` preferences. The
    /// 15s countdown turns "speak in seconds" into "wait 15s, then speak," which
    /// defeats the acquisition lever; this closes that gap for rep #1 only.
    /// Mirrors the seeded-prompt contract: written at the fork, read-and-removed
    /// once by the rep, so an app-kill mid-rep can never re-apply it to a later
    /// rep. See `docs/SPEC_first_rep_fast_start.md`.
    static let fastStartOnceKey = "timedPractice.fastStartOnce"

    /// Arm the instant-start for the auto-guided first rep only. Called at the
    /// fork alongside `seedFramingPrompt()`.
    static func armFastStartOnce() {
        UserDefaults.standard.set(true, forKey: fastStartOnceKey)
    }

    /// Read-and-remove the one-shot. Returns true exactly once per arming;
    /// false (and a no-op) for every returning-user / non-auto-guided rep.
    @discardableResult
    static func consumeFastStartOnce() -> Bool {
        let defaults = UserDefaults.standard
        defer { defaults.removeObject(forKey: fastStartOnceKey) }
        return defaults.bool(forKey: fastStartOnceKey)
    }

    /// Clears an armed-but-not-yet-consumed launch during sign-out/account
    /// deletion so a different account can never inherit the prompt or mic
    /// auto-begin handshake.
    static func cancelPendingLaunch() {
        TimedPracticePromptHandoff.shared.clear()
        UserDefaults.standard.removeObject(forKey: fastStartOnceKey)
        PracticeModeQuickStart.clear()
    }

    // MARK: Debug

    #if DEBUG
    /// Re-arm the auto-guided path for felt-QA on a real build (clears the
    /// one-shot for the current account). Mirrors
    /// the other first-run one-shots.
    static func resetForDebug() {
        UserDefaults.standard.removeObject(forKey: completedKey)
        cancelPendingLaunch()
    }
    #endif
}
