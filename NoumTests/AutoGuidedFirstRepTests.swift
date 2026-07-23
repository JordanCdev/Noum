//
//  AutoGuidedFirstRepTests.swift
//  NoumTests
//
//  Contracts behind the optional auto-guided first-rep launch preparation.
//  Routing remains elsewhere; this suite pins the default-off felt-QA gate and
//  the exact one-shot handshakes consumed by the existing Timed engine.
//

import Foundation
import Testing
@testable import Noum

@MainActor
@Suite(.serialized)
struct AutoGuidedFirstRepTests {
    private let accountID = "auto-guided-tests"

    /// Pristine state for the current account before/after each assertion.
    private func cleanState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AutoGuidedFirstRep.enabledOverrideKey)
        defaults.removeObject(forKey: TimedPracticePromptHandoff.legacyDefaultsKey)
        defaults.removeObject(forKey: AutoGuidedFirstRep.fastStartOnceKey)
        defaults.removeObject(
            forKey: AutoGuidedFirstRep.completedKeyPrefix + accountID
        )
        TimedPracticePromptHandoff.shared.clear()
        PracticeModeQuickStart.clear()
        AutoGuidedFirstRep.resetForDebug(accountID: accountID)
    }

    @Test func defaultsOffUntilSignedDeviceActivationGatePasses() {
        cleanState()
        #expect(AutoGuidedFirstRep.enabled == false)
        #expect(!AutoGuidedFirstRep.prepareLaunchIfNeeded(
            hasCompletedOnboarding: true,
            accountID: accountID
        ))
        cleanState()
    }

    @Test func preparesOnlyWhenEnabledAndProfileCompleted() {
        cleanState()
        UserDefaults.standard.set(true, forKey: AutoGuidedFirstRep.enabledOverrideKey)
        #expect(AutoGuidedFirstRep.enabled == true)
        #expect(!AutoGuidedFirstRep.prepareLaunchIfNeeded(
            hasCompletedOnboarding: false,
            accountID: accountID
        ))
        let preparation = AutoGuidedFirstRep.prepareLaunch(
            hasCompletedOnboarding: true,
            accountID: accountID
        )
        #expect(preparation != nil)
        #expect(preparation?.promptToken != nil)
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .prepared)
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) != .completed)
        #expect(PracticeModeQuickStart.consume(for: .timed))
        #expect(AutoGuidedFirstRep.consumeFastStartOnce())
        #expect(
            TimedPracticePromptHandoff.shared.pendingPrompt(accountID: accountID)
                == AutoGuidedFirstRep.framingPrompt
        )
        cleanState()
    }

    @Test func enabledOverrideCanForceOff() {
        cleanState()
        UserDefaults.standard.set(false, forKey: AutoGuidedFirstRep.enabledOverrideKey)
        #expect(AutoGuidedFirstRep.enabled == false)
        #expect(!AutoGuidedFirstRep.prepareLaunchIfNeeded(hasCompletedOnboarding: true))
        cleanState()
    }

    @Test func automaticOfferNeverRefiresButDoesNotInventCompletion() {
        cleanState()
        UserDefaults.standard.set(true, forKey: AutoGuidedFirstRep.enabledOverrideKey)
        #expect(AutoGuidedFirstRep.prepareLaunchIfNeeded(
            hasCompletedOnboarding: true,
            accountID: accountID
        ))
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .prepared)
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) != .completed)

        // Consuming or abandoning the process-local prompt leaves a durable
        // offered marker. Relaunch must not automatically open/arm it again.
        TimedPracticePromptHandoff.shared.clear()
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .offered)
        #expect(!AutoGuidedFirstRep.prepareLaunchIfNeeded(
            hasCompletedOnboarding: true,
            accountID: accountID
        ))

        // Debug reset re-arms it for felt-QA.
        AutoGuidedFirstRep.resetForDebug(accountID: accountID)
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .available)
        #expect(AutoGuidedFirstRep.prepareLaunchIfNeeded(
            hasCompletedOnboarding: true,
            accountID: accountID
        ))
        cleanState()
    }

    @Test func explicitTapCanPrepareAgainAfterBackOrRelaunch() {
        cleanState()

        let first = AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(
            accountID: accountID
        )
        #expect(first?.automaticallyStartsCapture == false)
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .prepared)
        #expect(!AutoGuidedFirstRep.consumeFastStartOnce())
        #expect(!PracticeModeQuickStart.consume(for: .timed))

        // Back / process death drops the process-local prompt but cannot turn
        // the route offer into evidence.
        TimedPracticePromptHandoff.shared.clear()
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .offered)
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) != .completed)

        let retry = AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(
            accountID: accountID
        )
        #expect(retry?.promptToken != nil)
        #expect(retry?.promptToken != first?.promptToken)
        #expect(retry?.automaticallyStartsCapture == false)
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .prepared)
        #expect(!AutoGuidedFirstRep.consumeFastStartOnce())
        #expect(!PracticeModeQuickStart.consume(for: .timed))
        cleanState()
    }

    @Test func explicitTapReplacesAStillPreparedRouteWithoutQuickStart() throws {
        cleanState()

        let first = try #require(
            AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(
                accountID: accountID
            )
        )
        let replacement = try #require(
            AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(
                accountID: accountID
            )
        )
        let firstToken = try #require(first.promptToken)
        let replacementToken = try #require(replacement.promptToken)

        #expect(replacementToken != firstToken)
        #expect(replacement.automaticallyStartsCapture == false)
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .prepared)
        #expect(!AutoGuidedFirstRep.consumeFastStartOnce())
        #expect(!PracticeModeQuickStart.consume(for: .timed))

        // The abandoned route cannot consume the replacement, while the new
        // explicit tap still owns one usable exact prompt.
        #expect(
            TimedPracticePromptHandoff.shared.consume(
                token: firstToken,
                accountID: accountID
            ) == nil
        )
        #expect(
            TimedPracticePromptHandoff.shared.consume(
                token: replacementToken,
                accountID: accountID
            ) == AutoGuidedFirstRep.framingPrompt
        )
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .offered)
        cleanState()
    }

    @Test func onlyAQualifyingPersistedRepPermanentlyCompletesHandoff() {
        cleanState()
        _ = AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(accountID: accountID)

        let tooThin = PracticeSession(
            transcript: "Not enough",
            fillerWordCount: 0,
            duration: 2.9,
            date: Date(),
            mode: .timed
        )
        #expect(!AutoGuidedFirstRep.reconcileQualifiedCompletion(
            in: [tooThin],
            accountID: accountID
        ))
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .prepared)

        let qualified = PracticeSession(
            transcript: "One complete answer",
            fillerWordCount: 0,
            duration: 3,
            date: Date(),
            mode: .timed
        )
        #expect(AutoGuidedFirstRep.reconcileQualifiedCompletion(
            in: [tooThin, qualified],
            accountID: accountID
        ))
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .completed)
        #expect(AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(
            accountID: accountID
        ) == nil)

        // Completion is its own durable marker, not a projection of the
        // current Review list. Removing the session cannot reopen Day 0.
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .completed)
        cleanState()
    }

    @Test func scopedCompletionUsesThePersistedRowsAccountLease() {
        let leasedAccount = "auto-guided-lease-a-\(UUID().uuidString)"
        let unrelatedAccount = "auto-guided-lease-b-\(UUID().uuidString)"
        let leasedKey = AutoGuidedFirstRep.completedKeyPrefix + leasedAccount
        let unrelatedKey = AutoGuidedFirstRep.completedKeyPrefix + unrelatedAccount
        defer {
            UserDefaults.standard.removeObject(forKey: leasedKey)
            UserDefaults.standard.removeObject(forKey: unrelatedKey)
        }
        UserDefaults.standard.removeObject(forKey: leasedKey)
        UserDefaults.standard.removeObject(forKey: unrelatedKey)

        let qualified = PracticeSession(
            transcript: "This row belongs to the leased account",
            fillerWordCount: 0,
            duration: 3,
            date: Date(),
            mode: .timed
        )
        let scopedSession = AccountScopedPracticeSession(
            epoch: PracticeSessionStoreEpoch(
                accountScope: leasedAccount,
                generation: 42
            ),
            session: qualified
        )

        #expect(AutoGuidedFirstRep.reconcileQualifiedCompletion(
            scopedSession: scopedSession
        ))
        #expect(AutoGuidedFirstRep.handoffState(accountID: leasedAccount) == .completed)
        #expect(AutoGuidedFirstRep.handoffState(accountID: unrelatedAccount) == .available)
    }

    @Test func explicitFirstRepKeepsRecoverableSummaryUntilExactPresentation() throws {
        cleanState()
        defer { cleanState() }
        _ = AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(accountID: accountID)

        let qualified = PracticeSession(
            transcript: "This durable answer should still have a useful summary after relaunch",
            fillerWordCount: 1,
            duration: 24,
            date: Date(),
            mode: .timed,
            score: 7,
            practiceDemand: .timed(difficulty: .medium)
        )
        let scoped = AccountScopedPracticeSession(
            epoch: PracticeSessionStoreEpoch(accountScope: accountID, generation: 7),
            session: qualified
        )

        #expect(AutoGuidedFirstRep.reconcileQualifiedCompletion(scopedSession: scoped))
        #expect(
            AutoGuidedFirstRep.pendingSummarySession(
                in: [qualified],
                accountID: accountID
            )?.id == qualified.id
        )

        let otherID = UUID()
        AutoGuidedFirstRep.markSummaryPresented(
            sessionID: otherID,
            accountID: accountID
        )
        #expect(
            AutoGuidedFirstRep.pendingSummarySession(
                in: [qualified],
                accountID: accountID
            )?.id == qualified.id
        )

        AutoGuidedFirstRep.markSummaryPresented(
            sessionID: qualified.id,
            accountID: accountID
        )
        #expect(
            AutoGuidedFirstRep.pendingSummarySession(
                in: [qualified],
                accountID: accountID
            ) == nil
        )
    }

    @Test func hydrationRepairRestoresOfferedRepButNotHistoricalAvailableAccount() {
        cleanState()
        defer { cleanState() }
        let qualified = PracticeSession(
            transcript: "A complete persisted answer for relaunch recovery",
            fillerWordCount: 0,
            duration: 20,
            date: Date(),
            mode: .timed
        )

        _ = AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(accountID: accountID)
        TimedPracticePromptHandoff.shared.clear()
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .offered)
        #expect(AutoGuidedFirstRep.reconcileQualifiedCompletion(
            in: [qualified],
            accountID: accountID
        ))
        #expect(
            AutoGuidedFirstRep.pendingSummarySession(
                in: [qualified],
                accountID: accountID
            )?.id == qualified.id
        )

        cleanState()
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .available)
        #expect(AutoGuidedFirstRep.reconcileQualifiedCompletion(
            in: [qualified],
            accountID: accountID
        ))
        #expect(
            AutoGuidedFirstRep.pendingSummarySession(
                in: [qualified],
                accountID: accountID
            ) == nil
        )
    }

    @Test func pendingSummaryRecoveryRouteCarriesOnlyExactSessionIdentity() throws {
        let sessionID = UUID()
        let route = try #require(
            AutoGuidedFirstRep.pendingSummaryRoute(sessionID: sessionID)
        )
        #expect(AutoGuidedFirstRep.pendingSummarySessionID(from: route) == sessionID)
        #expect(route.absoluteString.contains("transcript") == false)
        #expect(route.absoluteString.contains("prompt") == false)
        #expect(
            AutoGuidedFirstRep.pendingSummarySessionID(
                from: URL(string: "noum://summary/recover?session=not-a-uuid")!
            ) == nil
        )
    }

    @Test func legacyForkBooleanMigratesToOfferedUntilStoreReconciliation() {
        cleanState()
        UserDefaults.standard.set(
            true,
            forKey: AutoGuidedFirstRep.completedKeyPrefix + accountID
        )
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .offered)

        let qualified = PracticeSession(
            transcript: "This is durable evidence",
            fillerWordCount: 0,
            duration: 3,
            date: Date(),
            mode: .timed
        )
        #expect(AutoGuidedFirstRep.reconcileQualifiedCompletion(
            in: [qualified],
            accountID: accountID
        ))
        #expect(AutoGuidedFirstRep.handoffState(accountID: accountID) == .completed)
        cleanState()
    }

    @Test func seedFramingPromptUsesTheTimedEngineHandoff() {
        cleanState()
        AutoGuidedFirstRep.seedFramingPrompt(accountID: accountID)
        // Must use the exact one-shot handoff Timed Practice consumes, so the
        // guided rep starts on the supplied prompt (low time-to-word).
        #expect(
            TimedPracticePromptHandoff.shared.pendingPrompt(accountID: accountID)
                == AutoGuidedFirstRep.framingPrompt
        )
        #expect(AutoGuidedFirstRep.framingPrompt.isEmpty == false)
        cleanState()
    }

    @Test func fastStartIsNotArmedByDefault() {
        cleanState()
        // A returning-user / non-auto-guided rep never armed it → consume is a
        // no-op false, so the rep keeps the user's saved prep-countdown behaviour.
        #expect(AutoGuidedFirstRep.consumeFastStartOnce() == false)
        cleanState()
    }

    @Test func fastStartIsConsumedExactlyOnce() {
        cleanState()
        AutoGuidedFirstRep.armFastStartOnce()
        // First read (the auto-guided rep's QuickStart handshake) sees it on...
        #expect(AutoGuidedFirstRep.consumeFastStartOnce() == true)
        // ...and it is removed, so a later rep / app-kill mid-rep can never
        // re-apply instant-start to a rep the user didn't opt into.
        #expect(AutoGuidedFirstRep.consumeFastStartOnce() == false)
        cleanState()
    }

    @Test func fastStartDoesNotMutatePersistentPrefs() {
        cleanState()
        let defaults = UserDefaults.standard
        // User's saved practice prefs (defaults: prep-countdown ON, prompt hidden).
        defaults.removeObject(forKey: "timedPractice.enableThinkingTime")
        defaults.removeObject(forKey: "timedPractice.keepPromptVisible")

        AutoGuidedFirstRep.armFastStartOnce()
        _ = AutoGuidedFirstRep.consumeFastStartOnce()

        // Arming + consuming the one-shot must NOT write the persistent keys —
        // the instant-start lives only as a per-rep @State override in the view.
        #expect(defaults.object(forKey: "timedPractice.enableThinkingTime") == nil)
        #expect(defaults.object(forKey: "timedPractice.keepPromptVisible") == nil)
        cleanState()
    }

    @Test func debugResetClearsFastStart() {
        cleanState()
        AutoGuidedFirstRep.armFastStartOnce()
        // An aborted felt-QA (rep never consumed the one-shot) must not leak the
        // flag into the next run; resetForDebug clears it alongside the one-shot.
        AutoGuidedFirstRep.resetForDebug()
        #expect(AutoGuidedFirstRep.consumeFastStartOnce() == false)
        cleanState()
    }

    @Test func accountTransitionClearsEveryPendingLaunchHandshake() {
        cleanState()
        AutoGuidedFirstRep.seedFramingPrompt(accountID: accountID)
        AutoGuidedFirstRep.armFastStartOnce()
        PracticeModeQuickStart.arm(for: .timed)

        AutoGuidedFirstRep.cancelPendingLaunch()

        #expect(TimedPracticePromptHandoff.shared.pendingPrompt(accountID: accountID) == nil)
        #expect(!AutoGuidedFirstRep.consumeFastStartOnce())
        #expect(!PracticeModeQuickStart.consume(for: .timed))
        cleanState()
    }
}
