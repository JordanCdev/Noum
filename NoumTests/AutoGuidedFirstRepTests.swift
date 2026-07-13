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
        TimedPracticePromptHandoff.shared.clear()
        PracticeModeQuickStart.clear()
        AutoGuidedFirstRep.resetForDebug() // clears the per-account one-shot + fast-start
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

    @Test func oneShotNeverRefires() {
        cleanState()
        UserDefaults.standard.set(true, forKey: AutoGuidedFirstRep.enabledOverrideKey)
        #expect(AutoGuidedFirstRep.prepareLaunchIfNeeded(
            hasCompletedOnboarding: true,
            accountID: accountID
        ))
        #expect(AutoGuidedFirstRep.firstRepCompleted == true)
        #expect(!AutoGuidedFirstRep.prepareLaunchIfNeeded(
            hasCompletedOnboarding: true,
            accountID: accountID
        ))

        // Debug reset re-arms it for felt-QA.
        AutoGuidedFirstRep.resetForDebug()
        #expect(AutoGuidedFirstRep.firstRepCompleted == false)
        #expect(AutoGuidedFirstRep.prepareLaunchIfNeeded(
            hasCompletedOnboarding: true,
            accountID: accountID
        ))
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
