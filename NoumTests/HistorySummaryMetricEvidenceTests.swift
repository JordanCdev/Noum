import Foundation
import Testing
@testable import Noum

@Suite("History summary metric evidence")
struct HistorySummaryMetricEvidenceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Filler history keeps factual reps but excludes every unqualified mechanic")
    func fillerSummaryUsesStrictMetricSubset() throws {
        let qualifiedID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let sessions = [
            session(id: qualifiedID, mode: .ahCounter, words: 30, duration: 30, fillers: 2),
            session(mode: .ahCounter, words: 3, duration: 30, fillers: 0),
            session(mode: .ahCounter, words: 30, duration: 14.999, fillers: 0),
            session(mode: .ahCounter, words: 30, duration: 30, fillers: 0, confidence: 0.49),
            session(
                mode: .ahCounter,
                words: 30,
                duration: 30,
                fillers: 0,
                comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
            ),
            session(mode: .ahCounter, words: 30, duration: 30, fillers: 0, isEvaluationFixture: true),
        ]

        let stats = try #require(AhCounterHistorySummary.summarize(sessions: sessions, now: now))

        #expect(stats.runCount == 6)
        #expect(stats.fillerMeasuredRepCount == 1)
        #expect(stats.averageFillersPerMinute == 4)
        #expect(stats.cleanRepCount == 0)
        #expect(stats.cleanest?.sessionID == qualifiedID)
        #expect(stats.cleanest?.fillersPerMinute == 4)
        #expect(AhCounterHistoryBreakdownCard.metricEvidenceCopy(for: stats) ==
            "Filler rate measured: 1 of 6 reps")
        #expect(AhCounterHistoryBreakdownCard.statRowAccessibilityLabel(for: stats)
            .contains("Filler rate measured: 1 of 6 reps"))
    }

    @Test("Filler trend and clean wins require qualified evidence in each window")
    func fillerTrendUsesQualifiedWindows() throws {
        let recentID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let recent = session(
            id: recentID,
            mode: .ahCounter,
            words: 30,
            duration: 30,
            fillers: 0,
            date: now.addingTimeInterval(-86_400)
        )
        let stalePrior = session(
            mode: .ahCounter,
            words: 30,
            duration: 30,
            fillers: 0,
            date: now.addingTimeInterval(-9 * 86_400),
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )
        let qualifiedPrior = session(
            mode: .ahCounter,
            words: 30,
            duration: 30,
            fillers: 2,
            date: now.addingTimeInterval(-10 * 86_400)
        )

        #expect(AhCounterHistorySummary.trendComparison(
            sessions: [recent, stalePrior],
            now: now,
            calendar: utcCalendar
        ) == nil)

        let stats = try #require(AhCounterHistorySummary.summarize(
            sessions: [recent, stalePrior, qualifiedPrior],
            now: now,
            calendar: utcCalendar
        ))
        let trend = try #require(stats.trend)

        #expect(stats.runCount == 3)
        #expect(stats.fillerMeasuredRepCount == 2)
        #expect(stats.cleanRepCount == 1)
        #expect(stats.cleanest?.sessionID == recentID)
        #expect(trend.recentSevenDayRate == 0)
        #expect(trend.priorSevenDayRate == 4)
        #expect(trend.direction == .improving)
    }

    @Test("Filler card names missing metric evidence without claiming zero clean reps")
    func fillerCardWithholdsEmptyMetricClaims() throws {
        let stats = try #require(AhCounterHistorySummary.summarize(sessions: [
            session(mode: .ahCounter, words: 3, duration: 30, fillers: 0),
        ], now: now))

        #expect(stats.runCount == 1)
        #expect(stats.fillerMeasuredRepCount == 0)
        #expect(stats.averageFillersPerMinute == nil)
        #expect(stats.cleanest == nil)
        #expect(stats.cleanRepCount == 0)
        #expect(stats.trend == nil)
        #expect(AhCounterHistoryBreakdownCard.metricEvidenceCopy(for: stats) ==
            "Filler rate measured: 0 of 1 rep")
        #expect(AhCounterHistoryBreakdownCard.statRowAccessibilityLabel(for: stats) ==
            "Filler rate measured: 0 of 1 rep. Filler progress metrics are not yet available.")
    }

    @Test("Timed history qualifies pace independently from factual reps and scores")
    func timedSummaryUsesStrictPaceSubset() throws {
        let qualifiedID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let bestScoreID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let sessions = [
            session(id: qualifiedID, mode: .timed, words: 60, duration: 30, fillers: 1, score: 6),
            session(id: bestScoreID, mode: .timed, words: 60, duration: 30, fillers: 1, score: 10, confidence: 0.49),
            session(mode: .timed, words: 3, duration: 15, fillers: 0, score: 9),
            session(mode: .timed, words: 30, duration: 14.999, fillers: 0),
            session(
                mode: .timed,
                words: 120,
                duration: 30,
                fillers: 1,
                score: 8,
                comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
            ),
            session(mode: .timed, words: 120, duration: 30, fillers: 1, score: 7, isEvaluationFixture: true),
        ]

        let stats = try #require(TimedHistorySummary.summarize(sessions: sessions, now: now))

        #expect(stats.runCount == 6)
        #expect(stats.averageScore == 8)
        #expect(stats.best?.sessionID == bestScoreID)
        #expect(stats.best?.score == 10)
        #expect(stats.best?.wordsPerMinute == nil)
        #expect(stats.paceMeasuredRepCount == 1)
        #expect(stats.averageWPM == 120)
        #expect(stats.inZoneRepCount == 1)
        #expect(TimedHistoryBreakdownCard.metricEvidenceCopy(for: stats) ==
            "Pace measured: 1 of 6 reps")
        #expect(TimedHistoryBreakdownCard.zoneBandSubtitle(for: stats) ==
            "1 of 1 measured rep in zone")
        #expect(TimedHistoryBreakdownCard.zoneBandRatio(for: stats) == 1)
        #expect(TimedHistoryBreakdownCard.statRowAccessibilityLabel(for: stats)
            .contains("Pace measured: 1 of 6 reps"))
    }

    @Test("Timed best row preserves a score while exposing pace only when qualified")
    func timedBestPaceIsOptional() throws {
        let qualifiedBest = session(
            mode: .timed,
            words: 60,
            duration: 30,
            fillers: 0,
            score: 10
        )
        let qualifiedOutOfZone = session(
            mode: .timed,
            words: 100,
            duration: 30,
            fillers: 0,
            score: 7
        )

        let stats = try #require(TimedHistorySummary.summarize(
            sessions: [qualifiedBest, qualifiedOutOfZone],
            now: now
        ))

        #expect(stats.best?.score == 10)
        #expect(stats.best?.wordsPerMinute == 120)
        #expect(stats.paceMeasuredRepCount == 2)
        #expect(stats.averageWPM == 160)
        #expect(stats.inZoneRepCount == 1)
        #expect(TimedHistoryBreakdownCard.zoneBandSubtitle(for: stats) ==
            "1 of 2 measured reps in zone")
        #expect(TimedHistoryBreakdownCard.zoneBandRatio(for: stats) == 0.5)
    }

    @Test("Timed score trend survives when pace evidence is unavailable")
    func timedScoreTrendRemainsIndependent() throws {
        let recent = session(
            mode: .timed,
            words: 30,
            duration: 30,
            fillers: 1,
            score: 9,
            date: now.addingTimeInterval(-86_400),
            confidence: 0.49
        )
        let prior = session(
            mode: .timed,
            words: 30,
            duration: 30,
            fillers: 1,
            score: 5,
            date: now.addingTimeInterval(-10 * 86_400),
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )

        let stats = try #require(TimedHistorySummary.summarize(
            sessions: [recent, prior],
            now: now,
            calendar: utcCalendar
        ))

        #expect(stats.paceMeasuredRepCount == 0)
        #expect(stats.averageWPM == nil)
        #expect(stats.inZoneRepCount == 0)
        #expect(stats.best?.score == 9)
        #expect(stats.best?.wordsPerMinute == nil)
        #expect(stats.trend?.deltaScore == 4)
        #expect(stats.trend?.direction == .improving)
        #expect(TimedHistoryBreakdownCard.metricEvidenceCopy(for: stats) ==
            "Pace measured: 0 of 2 reps")
        #expect(TimedHistoryBreakdownCard.zoneBandRatio(for: stats) == 0)
        #expect(TimedHistoryBreakdownCard.statRowAccessibilityLabel(for: stats) ==
            "Pace measured: 0 of 2 reps. Average score 7.0. Pace progress metrics are not yet available.")
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func session(
        id: UUID = UUID(),
        mode: PracticeMode,
        words: Int,
        duration: TimeInterval,
        fillers: Int,
        score: Int? = nil,
        date: Date? = nil,
        confidence: Double? = nil,
        comparisonMetricSchemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false
    ) -> PracticeSession {
        PracticeSession(
            id: id,
            transcript: Array(repeating: "word", count: words).joined(separator: " "),
            fillerWordCount: fillers,
            duration: duration,
            date: date ?? now,
            mode: mode,
            score: score,
            transcriptConfidence: confidence,
            comparisonMetricSchemaVersion: comparisonMetricSchemaVersion,
            isEvaluationFixture: isEvaluationFixture
        )
    }
}
