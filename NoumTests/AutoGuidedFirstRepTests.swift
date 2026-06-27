//
//  AutoGuidedFirstRepTests.swift
//  NoumTests
//
//  Contracts behind the auto-guided first rep routing decision: the flag is
//  off by default (new users unaffected until felt-QA signs off), the path
//  fires only when enabled + onboarding-seen + not-yet-completed, the one-shot
//  never re-fires, and the framing prompt is seeded into the exact key the
//  Timed engine already consumes. Pure-logic tests — no UI, no rep engine —
//  mirroring the existing FirstRunOnboardingGate / PracticeModeQuickStart style.
//

import Foundation
import Testing
@testable import Noum

@MainActor
@Suite(.serialized)
struct AutoGuidedFirstRepTests {

    /// Pristine state for the current account before/after each assertion.
    private func cleanState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AutoGuidedFirstRep.enabledOverrideKey)
        defaults.removeObject(forKey: "timedPractice.suggestedPrompt")
        defaults.removeObject(forKey: AutoGuidedFirstRep.fastStartOnceKey)
        AutoGuidedFirstRep.resetForDebug() // clears the per-account one-shot + fast-start
    }

    @Test func defaultsToOffSoNewUsersKeepThePicker() {
        cleanState()
        // Compile-time default is off until an on-device feel pass signs off.
        #expect(AutoGuidedFirstRep.enabled == false)
        #expect(AutoGuidedFirstRep.shouldAutoGuide(hasSeenOnboarding: true) == false)
        cleanState()
    }

    @Test func firesOnlyWhenEnabledAndSeenAndNotCompleted() {
        cleanState()
        UserDefaults.standard.set(true, forKey: AutoGuidedFirstRep.enabledOverrideKey)
        #expect(AutoGuidedFirstRep.enabled == true)
        // All three conditions met → fires.
        #expect(AutoGuidedFirstRep.shouldAutoGuide(hasSeenOnboarding: true) == true)
        // Onboarding not finished → never hijack a non-onboarded launch.
        #expect(AutoGuidedFirstRep.shouldAutoGuide(hasSeenOnboarding: false) == false)
        cleanState()
    }

    @Test func enabledOverrideCanForceOff() {
        cleanState()
        UserDefaults.standard.set(false, forKey: AutoGuidedFirstRep.enabledOverrideKey)
        #expect(AutoGuidedFirstRep.enabled == false)
        #expect(AutoGuidedFirstRep.shouldAutoGuide(hasSeenOnboarding: true) == false)
        cleanState()
    }

    @Test func oneShotNeverRefires() {
        cleanState()
        UserDefaults.standard.set(true, forKey: AutoGuidedFirstRep.enabledOverrideKey)
        #expect(AutoGuidedFirstRep.shouldAutoGuide(hasSeenOnboarding: true) == true)

        // Marked at the fork (or on escape) → completion / app-kill / back-out
        // can never re-trigger the auto-guide.
        AutoGuidedFirstRep.markFirstRepCompleted()
        #expect(AutoGuidedFirstRep.firstRepCompleted == true)
        #expect(AutoGuidedFirstRep.shouldAutoGuide(hasSeenOnboarding: true) == false)

        // Debug reset re-arms it for felt-QA.
        AutoGuidedFirstRep.resetForDebug()
        #expect(AutoGuidedFirstRep.firstRepCompleted == false)
        #expect(AutoGuidedFirstRep.shouldAutoGuide(hasSeenOnboarding: true) == true)
        cleanState()
    }

    @Test func seedFramingPromptWritesTheExactEngineKey() {
        cleanState()
        AutoGuidedFirstRep.seedFramingPrompt()
        // Must be the exact key TimedPracticeView.consumeSeededPrompt reads,
        // so the guided rep starts on the supplied prompt (low time-to-word).
        #expect(
            UserDefaults.standard.string(forKey: "timedPractice.suggestedPrompt")
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
}
