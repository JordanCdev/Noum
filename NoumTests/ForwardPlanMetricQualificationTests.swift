import Foundation
import Testing
@testable import Noum

@Suite("Forward Plan metric qualification")
struct ForwardPlanMetricQualificationTests {
    private func input(
        baseline: CommunicationBaseline = .empty,
        sessions: [PracticeSession]
    ) -> ForwardPlanInput {
        ForwardPlanInput(
            profile: nil,
            baseline: baseline,
            sessions: sessions,
            weeklyDelta: 0,
            weeklyReps: sessions.count,
            currentStreak: 0,
            bigMoment: nil,
            bigMomentDaysUntil: nil,
            trends: [],
            recentDrills: [],
            recommendationOutcomes: [],
            transferOutcomes: []
        )
    }

    private func stat(
        _ value: Double,
        confidence: BaselineConfidence = .moderate
    ) -> BaselineStat {
        BaselineStat(
            value: value,
            sampleCount: 8,
            confidence: confidence,
            trend: .stable,
            percentile25: value,
            percentile75: value
        )
    }

    private func baseline(
        comparisonSchema: Int?,
        metricConfidence: BaselineConfidence = .moderate
    ) -> CommunicationBaseline {
        var baseline = CommunicationBaseline.empty
        baseline.comparisonMetricSchemaVersion = comparisonSchema
        baseline.fillerRate = stat(3.2, confidence: metricConfidence)
        baseline.pace = stat(142, confidence: metricConfidence)
        baseline.averageScore = stat(8.1)
        return baseline
    }

    private func session(
        wordCount: Int = SessionQualifier.minimumWordCount,
        fillerCount: Int,
        duration: TimeInterval = 60,
        confidence: Double? = 0.9,
        comparisonSchema: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false
    ) -> PracticeSession {
        PracticeSession(
            transcript: Array(repeating: "word", count: wordCount).joined(separator: " "),
            fillerWordCount: fillerCount,
            duration: duration,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            mode: .timed,
            score: 7,
            transcriptConfidence: confidence,
            comparisonMetricSchemaVersion: comparisonSchema,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    @Test func qualifiedSessionExposesRateInsteadOfRawCount() {
        let prompt = ForwardPlanService.userPrompt(input: input(sessions: [
            session(fillerCount: 2, duration: 30)
        ]))

        #expect(prompt.contains("filler rate 4.0 per minute"))
        #expect(!prompt.contains("| fillers"))
        #expect(!prompt.contains("fillers 2"))
    }

    @Test func qualifiedZeroRemainsMeasuredEvidence() {
        let prompt = ForwardPlanService.userPrompt(input: input(sessions: [
            session(fillerCount: 0, duration: 60)
        ]))

        #expect(prompt.contains("filler rate 0.0 per minute"))
        #expect(!prompt.contains("filler rate not measured"))
    }

    @Test func everyHistoricalQualificationGateFailsClosed() {
        let unqualified: [PracticeSession] = [
            session(wordCount: SessionQualifier.minimumWordCount - 1, fillerCount: 17),
            session(fillerCount: 17, duration: SessionQualifier.minimumDuration - 0.1),
            session(fillerCount: 17, confidence: SessionQualifier.minimumConfidence - 0.01),
            session(
                fillerCount: 17,
                comparisonSchema: PracticeSession.currentComparisonMetricSchemaVersion - 1
            ),
            session(fillerCount: 17, isEvaluationFixture: true),
        ]

        for candidate in unqualified {
            let prompt = ForwardPlanService.userPrompt(input: input(sessions: [candidate]))
            #expect(prompt.contains("filler rate not measured"))
            #expect(!prompt.contains("17"))
        }
    }

    @Test func equivalentRatesDoNotExposeDifferentCounts() {
        let prompt = ForwardPlanService.userPrompt(input: input(sessions: [
            session(fillerCount: 1, duration: 60),
            session(fillerCount: 10, duration: 600),
        ]))

        #expect(prompt.components(separatedBy: "filler rate 1.0 per minute").count - 1 == 2)
        #expect(!prompt.contains("fillers 1"))
        #expect(!prompt.contains("fillers 10"))
    }

    @Test func currentReliableBaselineIncludesComparisonMetrics() {
        let prompt = ForwardPlanService.userPrompt(input: input(
            baseline: baseline(
                comparisonSchema: PracticeSession.currentComparisonMetricSchemaVersion
            ),
            sessions: []
        ))

        #expect(prompt.contains("Average score baseline: 8.1/10"))
        #expect(prompt.contains("Filler rate baseline: 3.2 per minute"))
        #expect(prompt.contains("Pace baseline: 142 WPM"))
    }

    @Test func staleBaselineWithholdsComparisonMetricsButKeepsIndependentScore() {
        let prompt = ForwardPlanService.userPrompt(input: input(
            baseline: baseline(
                comparisonSchema: PracticeSession.currentComparisonMetricSchemaVersion - 1
            ),
            sessions: []
        ))

        #expect(prompt.contains("Average score baseline: 8.1/10"))
        #expect(!prompt.contains("Filler rate baseline:"))
        #expect(!prompt.contains("Pace baseline:"))
    }

    @Test func insufficientBaselineWithholdsComparisonMetricsButKeepsIndependentScore() {
        let prompt = ForwardPlanService.userPrompt(input: input(
            baseline: baseline(
                comparisonSchema: PracticeSession.currentComparisonMetricSchemaVersion,
                metricConfidence: .tentative
            ),
            sessions: []
        ))

        #expect(prompt.contains("Average score baseline: 8.1/10"))
        #expect(!prompt.contains("Filler rate baseline:"))
        #expect(!prompt.contains("Pace baseline:"))
    }
}
