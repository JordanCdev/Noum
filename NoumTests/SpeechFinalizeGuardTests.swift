//
//  SpeechFinalizeGuardTests.swift
//  NoumTests
//
//  Pins the delayed-finalize race guard in SpeechRecognizerViewModel.
//  `stopRecording()` finalizes (saves the session + records quality metrics) on
//  a 500ms delay so trailing transcripts can land. If a NEW session starts
//  inside that window (rapid push-to-talk re-tap in the live coach call, or
//  back-to-back Sudden Death rounds), the stale tail must NOT run — by then the
//  new session has bumped the generation and reset the transcript buffers, so
//  finalizing would save the wrong rep's data and blend quality metrics across
//  two reps. `shouldFinalize` is the pure predicate the guard defers to.
//

import Foundation
import Testing
@testable import Noum

@MainActor
@Suite struct SpeechFinalizeGuardTests {

    @Test func finalizesWhenNoNewerSessionStarted() {
        // Single rep, stop -> 500ms -> finalize: the generation captured at stop
        // still matches, so the rep is saved (the happy path is untouched).
        #expect(SpeechRecognizerViewModel.shouldFinalize(captured: 7, current: 7) == true)
    }

    @Test func skipsWhenANewerSessionStarted() {
        // A new session began during the teardown/finalize window (generation
        // advanced), so the stale tail bails instead of corrupting the new rep.
        #expect(SpeechRecognizerViewModel.shouldFinalize(captured: 7, current: 8) == false)
    }

    @Test func skipsAcrossMultipleRestarts() {
        // Several quick restarts in the window — still stale, still skipped.
        #expect(SpeechRecognizerViewModel.shouldFinalize(captured: 3, current: 10) == false)
    }

    @Test func zeroOriginFinalizes() {
        // First-ever rep (generation 0 throughout) finalizes normally.
        #expect(SpeechRecognizerViewModel.shouldFinalize(captured: 0, current: 0) == true)
    }
}
