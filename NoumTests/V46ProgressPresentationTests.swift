import Foundation
import Testing
@testable import Noum

/// Slice 3 contracts: the Progress evidence head and the Updated Today
/// earned state are driven only by comparable ledger evidence, speak in
/// bounded honest classes, and self-suppress without data.
@Suite("V4.6 Progress + Updated Today contracts")
struct V46ProgressPresentationTests {

    private func outcome(
        result: TranscriptRetryResult,
        daysAgo: Double,
        lever: TranscriptPracticeLever = .opening,
        difficulty: TimedPracticeDifficulty = .easy,
        now: Date = Date()
    ) -> RecommendationOutcome {
        RecommendationOutcome(
            id: UUID(),
            fingerprint: "v46-test",
            title: "Answer first",
            focus: "Answer first",
            target: "Answer first",
            mode: .timed,
            sessionID: UUID(),
            followed: true,
            executedDemand: .timed(difficulty: difficulty, speechProjectID: nil),
            completedAt: now.addingTimeInterval(-daysAgo * 24 * 3600),
            scoreDelta: 0,
            hasComparableScore: true,
            fillerDelta: 0,
            durationDelta: 0,
            transcriptRetryTarget: TranscriptRetryTarget(lever: lever),
            transcriptRetryComparison: TranscriptRetryComparison(
                schemaVersion: TranscriptRetryComparison.schemaVersion,
                lever: lever,
                sourceSessionID: UUID(),
                retrySessionID: UUID(),
                sourceSignal: 40,
                retrySignal: result == .regressed ? 20 : 70,
                meaningOverlapPercent: 80,
                result: result
            )
        )
    }

    @Test("No comparable evidence renders nothing — never an activity chart")
    func suppressesWithoutComparableEvidence() {
        let presentation = V46ProgressPresentation.make(
            outcomes: [],
            intervention: nil
        )
        #expect(presentation == nil)
    }

    @Test("Three holds in four reps reads as becoming reliable, with the honest tally")
    func reliableTallyClass() throws {
        let now = Date()
        let outcomes = [
            outcome(result: .improved, daysAgo: 3, now: now),
            outcome(result: .held, daysAgo: 2, now: now),
            outcome(result: .regressed, daysAgo: 1, difficulty: .hard, now: now),
            outcome(result: .improved, daysAgo: 0, difficulty: .medium, now: now)
        ]
        let presentation = try #require(V46ProgressPresentation.make(
            outcomes: outcomes,
            intervention: nil,
            now: now
        ))
        #expect(presentation.headline == "Becoming reliable.")
        #expect(presentation.subtitle.contains("Held in 3 of 4 comparable reps"))
        #expect(presentation.subtitle.contains("under pressure"))
        #expect(presentation.rows.count <= 3)
        #expect(presentation.trajectory.count <= 4)
    }

    @Test("A regressed day is an amber lapse row with a text cue, never colour alone")
    func lapseDayCarriesTextCue() throws {
        let now = Date()
        let outcomes = [
            outcome(result: .improved, daysAgo: 2, now: now),
            outcome(result: .regressed, daysAgo: 1, now: now),
            outcome(result: .improved, daysAgo: 0, now: now)
        ]
        let presentation = try #require(V46ProgressPresentation.make(
            outcomes: outcomes,
            intervention: nil,
            now: now
        ))
        let lapse = try #require(presentation.rows.first { $0.tone == .lapse })
        #expect(lapse.copy.contains("Didn't hold"))
        let lapseDay = try #require(presentation.trajectory.first { $0.isLapse })
        #expect(lapseDay.intensity < 0.8)
    }

    @Test("Below three comparable reps the head stays an early read")
    func earlyReadFloor() throws {
        let now = Date()
        let presentation = try #require(V46ProgressPresentation.make(
            outcomes: [outcome(result: .improved, daysAgo: 0, now: now)],
            intervention: nil,
            now: now
        ))
        #expect(presentation.headline == "Early read.")
        #expect(presentation.subtitle.contains("more for a reliable read"))
    }

    @Test("Earned Today fires once per un-acknowledged evidence event")
    func earnedTodayOncePerEvent() throws {
        let now = Date()
        let earned = outcome(result: .improved, daysAgo: 0.1, difficulty: .easy, now: now)
        let first = try #require(V46EarnedTodayPresentation.make(
            outcomes: [earned],
            suggestedNextDifficulty: .medium,
            acknowledgedOutcomeIDs: [],
            now: now
        ))
        #expect(first.outcomeID == earned.id)
        // The clock tightened (60s → 30s), so the hero re-speaks around it.
        #expect(first.headlineOverride == "Same target \u{2014} shorter clock.")
        #expect(first.ctaOverride == "Start the shorter clock")

        let second = V46EarnedTodayPresentation.make(
            outcomes: [earned],
            suggestedNextDifficulty: .medium,
            acknowledgedOutcomeIDs: [earned.id],
            now: now
        )
        #expect(second == nil)
    }

    @Test("Earned Today without a tightened clock keeps ordinary copy — chip only")
    func earnedTodayWithoutClockChange() throws {
        let now = Date()
        let earned = outcome(result: .held, daysAgo: 0.1, difficulty: .medium, now: now)
        let presentation = try #require(V46EarnedTodayPresentation.make(
            outcomes: [earned],
            suggestedNextDifficulty: .medium,
            acknowledgedOutcomeIDs: [],
            now: now
        ))
        #expect(presentation.headlineOverride == nil)
        #expect(presentation.ctaOverride == nil)
        #expect(presentation.chipText.contains("New evidence"))
    }

    @Test("A stale evidence event never re-announces")
    func earnedTodayWindowExpires() {
        let now = Date()
        let stale = outcome(result: .improved, daysAgo: 2, now: now)
        let presentation = V46EarnedTodayPresentation.make(
            outcomes: [stale],
            suggestedNextDifficulty: .medium,
            acknowledgedOutcomeIDs: [],
            now: now
        )
        #expect(presentation == nil)
    }
}
