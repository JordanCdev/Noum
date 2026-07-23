import Foundation

// MARK: - Auto-Guided First Rep

/// One-shot launch preparation for the first spoken proof. Routing remains
/// owned by NoumApp → DeepLinkRouter → AppShell; this type only seeds the
/// existing Timed engine and, for the legacy QA-only lane, can arm quick start.
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
/// - **Automatic capture stays OFF.** The legacy quick-start lane remains
///   debug-overridable for signed-device QA only. Production uses
///   `prepareUserInitiatedSpokenProof`, which requires a tap and never arms
///   `PracticeModeQuickStart` or the microphone-start handshake.
/// - **Two-stage, per-account.** Offering the route is not completion. A route
///   may be offered once automatically, while an explicit user tap may prepare
///   it again until a qualifying persisted rep exists.
/// - **Completion follows durable evidence.** A back-out or app kill before a
///   qualifying rep stays retryable. Once the account's session store contains
///   a qualifying rep, the handoff remains complete even if that session is
///   later removed from Review.
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
    /// Account-scoped receipt for the narrow interval after the spoken row is
    /// durable but before its Summary has mounted. The value is only an opaque
    /// local session UUID; speech and coaching content remain in the existing
    /// `PracticeSessionStore` owner.
    static let pendingSummaryKeyPrefix = "noum.firstRep.pendingSummary."

    /// Account bootstrap completes before onboarding, but keep a defensive
    /// guest fallback for debug/test helpers that invoke this type directly.
    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private static func completedKey(accountID: String? = nil) -> String {
        completedKeyPrefix + normalizedAccountID(accountID)
    }

    private static func pendingSummaryKey(accountID: String? = nil) -> String {
        pendingSummaryKeyPrefix + normalizedAccountID(accountID)
    }

    /// The historical key is retained so account deletion keeps clearing this
    /// state through the existing account-data registry. Its value is now a
    /// small state marker rather than a Boolean: old `true` values represented
    /// only a route fork, so they migrate conservatively to `.offered`.
    private static let offeredMarker = "offered"
    private static let completedMarker = "completed"

    enum HandoffState: Equatable {
        /// No automatic or explicit handoff has been offered for this account.
        case available
        /// A handoff was offered previously, but no route-bound prompt is live.
        case offered
        /// A route-bound framing prompt is currently prepared in memory.
        case prepared
        /// A qualifying persisted rep has permanently completed the handoff.
        case completed
    }

    /// True only after durable qualifying speech evidence exists. Merely
    /// opening or abandoning the Timed route never flips this value.
    static var firstRepCompleted: Bool {
        handoffState() == .completed
    }

    static func handoffState(accountID: String? = nil) -> HandoffState {
        let resolvedAccountID = normalizedAccountID(accountID)
        let stored = UserDefaults.standard.object(
            forKey: completedKey(accountID: resolvedAccountID)
        )
        if let marker = stored as? String, marker == completedMarker {
            return .completed
        }
        if TimedPracticePromptHandoff.shared.pendingPrompt(
            accountID: resolvedAccountID
        ) == framingPrompt {
            return .prepared
        }
        if stored != nil {
            // `true` is the only legacy value. It was written at the route
            // fork, so treating it as qualified completion would preserve the
            // exact tap -> kill/back bug this state machine closes.
            return .offered
        }
        return .available
    }

    private static func markFirstRepOffered(accountID: String? = nil) {
        UserDefaults.standard.set(
            offeredMarker,
            forKey: completedKey(accountID: accountID)
        )
    }

    /// Permanently closes the handoff only after its caller has supplied the
    /// current account's durable session-store contents. This also repairs the
    /// narrow crash window between session persistence and the Timed view's
    /// post-save callback when the app next hydrates that store.
    @discardableResult
    static func reconcileQualifiedCompletion(
        in persistedSessions: [PracticeSession],
        accountID: String? = nil
    ) -> Bool {
        guard let qualified = persistedSessions
            .filter(PracticeProgressEligibility.qualifies)
            .max(by: { $0.date < $1.date }) else {
            return false
        }
        registerPendingSummaryIfNeeded(
            sessionID: qualified.id,
            accountID: accountID
        )
        markFirstRepCompleted(accountID: accountID)
        return true
    }

    /// Completes the handoff from one exact row leased from the account-scoped
    /// session store. Timed uses this overload so an asynchronous provider tail
    /// cannot resolve completion against whichever Auth account happens to be
    /// current after the row was persisted.
    @discardableResult
    static func reconcileQualifiedCompletion(
        scopedSession: AccountScopedPracticeSession
    ) -> Bool {
        guard PracticeProgressEligibility.qualifies(scopedSession.session) else {
            return false
        }
        registerPendingSummaryIfNeeded(
            sessionID: scopedSession.session.id,
            accountID: scopedSession.epoch.accountScope
        )
        markFirstRepCompleted(accountID: scopedSession.epoch.accountScope)
        return true
    }

    /// Returns the exact durable row whose Summary was interrupted. A receipt
    /// can only be created from an explicitly offered first-rep handoff; this
    /// prevents an app update from resurrecting a historical Summary for an
    /// established user whose old installation predates this state machine.
    static func pendingSummarySession(
        in persistedSessions: [PracticeSession],
        accountID: String? = nil
    ) -> PracticeSession? {
        let resolvedAccountID = normalizedAccountID(accountID)
        guard let rawID = UserDefaults.standard.string(
            forKey: pendingSummaryKey(accountID: resolvedAccountID)
        ),
        let sessionID = UUID(uuidString: rawID),
        let session = persistedSessions.first(where: { $0.id == sessionID }),
        PracticeProgressEligibility.qualifies(session) else {
            UserDefaults.standard.removeObject(
                forKey: pendingSummaryKey(accountID: resolvedAccountID)
            )
            return nil
        }
        return session
    }

    /// Summary calls this at its visible evidence boundary. Matching the exact
    /// row means a stale presentation can never clear a newer recovery receipt.
    static func markSummaryPresented(
        sessionID: UUID,
        accountID: String? = nil
    ) {
        let key = pendingSummaryKey(accountID: accountID)
        guard UserDefaults.standard.string(forKey: key) == sessionID.uuidString else {
            return
        }
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Content-free local route used only after account hydration revalidated
    /// the receipt against the current account's session store.
    static func pendingSummaryRoute(sessionID: UUID) -> URL? {
        var components = URLComponents(string: "noum://summary/recover")
        components?.queryItems = [
            URLQueryItem(name: "session", value: sessionID.uuidString),
        ]
        return components?.url
    }

    static func pendingSummarySessionID(from url: URL) -> UUID? {
        guard url.scheme == "noum",
              url.host?.lowercased() == "summary",
              url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .lowercased() == "recover",
              let rawID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "session" })?
                .value else {
            return nil
        }
        return UUID(uuidString: rawID)
    }

    private static func registerPendingSummaryIfNeeded(
        sessionID: UUID,
        accountID: String?
    ) {
        let state = handoffState(accountID: accountID)
        guard state == .offered || state == .prepared else { return }
        UserDefaults.standard.set(
            sessionID.uuidString,
            forKey: pendingSummaryKey(accountID: accountID)
        )
    }

    private static func markFirstRepCompleted(accountID: String? = nil) {
        UserDefaults.standard.set(
            completedMarker,
            forKey: completedKey(accountID: accountID)
        )
    }

    // MARK: Launch preparation

    struct LaunchPreparation: Equatable {
        /// Opaque, process-local route identity. It carries no prompt or
        /// account content and is nil only when defensive account lookup made
        /// the prompt unavailable.
        let promptToken: UUID?
        /// True only for the debug-gated legacy lane. The production Day-0
        /// handoff always returns false and waits on the Timed screen for the
        /// user's explicit Begin/record action.
        let automaticallyStartsCapture: Bool
    }

    /// Production Day-0 handoff. It is available only because the user tapped
    /// the spoken-proof CTA; it seeds the existing Timed prompt route but does
    /// not arm quick start, skip preparation, request permissions, or open the
    /// microphone. No feature flag or premium gate sits between the written
    /// result and this user-initiated proof.
    static func prepareUserInitiatedSpokenProof(
        accountID: String? = nil
    ) -> LaunchPreparation? {
        let resolvedAccountID = normalizedAccountID(accountID)
        let state = handoffState(accountID: resolvedAccountID)
        guard state != .completed else {
            return nil
        }

        // Fail closed against a stale QA/quick-start handshake. The prompt is
        // offered after cleanup so it remains the only pending launch state.
        // An explicit second tap intentionally replaces a still-prepared token:
        // the old route may have been dropped before Timed consumed it, and a
        // process-local token must never strand an otherwise incomplete proof.
        UserDefaults.standard.removeObject(forKey: fastStartOnceKey)
        PracticeModeQuickStart.clear()
        guard let promptToken = seedFramingPrompt(accountID: resolvedAccountID) else {
            return nil
        }
        markFirstRepOffered(accountID: resolvedAccountID)
        return LaunchPreparation(
            promptToken: promptToken,
            automaticallyStartsCapture: false
        )
    }

    /// Canonical deep link for a prepared spoken proof. Carries only the
    /// process-local handoff token; prompt text and account identity stay in
    /// `TimedPracticePromptHandoff`.
    static func routeURL(for preparation: LaunchPreparation) -> URL? {
        guard let promptToken = preparation.promptToken else { return nil }
        var components = URLComponents(string: "noum://practice/timed")
        components?.queryItems = [
            URLQueryItem(
                name: AppTab.timedPromptTokenQueryName,
                value: promptToken.uuidString
            ),
            // The onboarding promise is an exact 30-second proof. Carry the
            // per-rep demand through the route instead of inheriting a saved
            // Free/Easy/Hard preference from another practice session.
            URLQueryItem(
                name: AppTab.timedDifficultyQueryName,
                value: TimedPracticeDifficulty.medium.rawValue
            ),
        ]
        return components?.url
    }

    /// Production form used by the onboarding router so the exact Timed
    /// destination carries the prompt token it prepared.
    static func prepareLaunch(
        hasCompletedOnboarding: Bool,
        accountID: String? = nil
    ) -> LaunchPreparation? {
        let resolvedAccountID = normalizedAccountID(accountID)
        guard enabled,
              hasCompletedOnboarding,
              handoffState(accountID: resolvedAccountID) == .available else {
            return nil
        }
        guard let promptToken = seedFramingPrompt(
            accountID: resolvedAccountID
        ) else { return nil }
        markFirstRepOffered(accountID: resolvedAccountID)
        armFastStartOnce()
        PracticeModeQuickStart.arm(for: .timed)
        return LaunchPreparation(
            promptToken: promptToken,
            automaticallyStartsCapture: true
        )
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

    private static func normalizedAccountID(_ accountID: String?) -> String {
        let value = accountID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? currentAccountID() : value
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
    static func resetForDebug(accountID: String? = nil) {
        UserDefaults.standard.removeObject(
            forKey: completedKey(accountID: accountID)
        )
        UserDefaults.standard.removeObject(
            forKey: pendingSummaryKey(accountID: accountID)
        )
        cancelPendingLaunch()
    }
    #endif
}
