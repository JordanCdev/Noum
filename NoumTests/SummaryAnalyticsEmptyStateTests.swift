//
//  SummaryAnalyticsEmptyStateTests.swift
//  NoumTests
//
//  Locks the pure visibility gate behind the "More from this rep" honest
//  empty-state. Tests assert STRUCTURAL + honesty invariants only:
//    1. an early rep with no readable analytics → the honest note shows;
//    2. the note self-hides the moment ANY speech-quality card has signal;
//    3. a mature user's quiet rep (>= patternFloor) → SILENCE, never a nag
//       and never the small-sample lie "we're still analysing" to someone
//       who has plenty of reps;
//    4. never speaks on the IM-conversation summary (wrong surface);
//    5. the copy is a hedged, non-overclaiming read (names "recur", makes no
//       promise, no "replaces a coach" claim).

import Testing
@testable import Noum

private func signals(
    eloquence: Bool = false,
    pause: Bool = false,
    pitch: Bool = false,
    positional: Bool = false,
    trend: Bool = false,
    wordChoice: Bool = false
) -> SummaryAnalyticsEmptyState.Signals {
    .init(
        hasEloquence: eloquence,
        hasPause: pause,
        hasPitch: pitch,
        hasPositional: positional,
        hasTrend: trend,
        hasWordChoice: wordChoice
    )
}

@Suite("SummaryAnalyticsEmptyStateTests")
struct SummaryAnalyticsEmptyStateTests {

    @Test("Early rep with no analytics shows the honest note")
    func earlyRepNoAnalyticsShowsNote() {
        let msg = SummaryAnalyticsEmptyState.message(
            isIMSummary: false, repCount: 1, signals: signals()
        )
        #expect(msg != nil)
        // Hedged + names the recurrence discipline, makes no promise.
        #expect(msg?.contains("recur") == true)
    }

    @Test("Second rep is still early → note shows")
    func secondRepStillEarly() {
        #expect(SummaryAnalyticsEmptyState.message(
            isIMSummary: false, repCount: 2, signals: signals()
        ) != nil)
    }

    @Test("Any present analytic self-hides the note")
    func anyAnalyticHidesNote() {
        #expect(SummaryAnalyticsEmptyState.message(isIMSummary: false, repCount: 1, signals: signals(eloquence: true)) == nil)
        #expect(SummaryAnalyticsEmptyState.message(isIMSummary: false, repCount: 1, signals: signals(pause: true)) == nil)
        #expect(SummaryAnalyticsEmptyState.message(isIMSummary: false, repCount: 1, signals: signals(pitch: true)) == nil)
        #expect(SummaryAnalyticsEmptyState.message(isIMSummary: false, repCount: 1, signals: signals(positional: true)) == nil)
        #expect(SummaryAnalyticsEmptyState.message(isIMSummary: false, repCount: 1, signals: signals(trend: true)) == nil)
        #expect(SummaryAnalyticsEmptyState.message(isIMSummary: false, repCount: 1, signals: signals(wordChoice: true)) == nil)
    }

    @Test("Mature user's quiet rep stays silent — never nags, never the small-sample lie")
    func matureQuietRepStaysSilent() {
        // At the floor and well past it, a genuinely quiet rep must NOT be told
        // patterns are "still building" — that user has plenty of reps.
        #expect(SummaryAnalyticsEmptyState.message(isIMSummary: false, repCount: 3, signals: signals()) == nil)
        #expect(SummaryAnalyticsEmptyState.message(isIMSummary: false, repCount: 50, signals: signals()) == nil)
    }

    @Test("Never speaks on the IM-conversation summary")
    func neverOnIMSummary() {
        #expect(SummaryAnalyticsEmptyState.message(isIMSummary: true, repCount: 1, signals: signals()) == nil)
    }

    @Test("Copy makes no coach-replacement or certainty overclaim")
    func copyDoesNotOverclaim() {
        let msg = SummaryAnalyticsEmptyState.message(isIMSummary: false, repCount: 1, signals: signals()) ?? ""
        let lowered = msg.lowercased()
        #expect(!lowered.contains("replace"))
        #expect(!lowered.contains("guarantee"))
        #expect(!lowered.contains("always"))
    }
}
