import Foundation
import Testing
@testable import Noum

private func quantityFairnessSession(
    fillers: Int,
    duration: TimeInterval,
    words: Int,
    date: Date = Date(),
    confidence: Double? = 0.9,
    insights: [String] = [],
    comparisonMetricSchemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
    isEvaluationFixture: Bool = false
) -> PracticeSession {
    PracticeSession(
        transcript: Array(repeating: "word", count: max(0, words)).joined(separator: " "),
        fillerWordCount: fillers,
        duration: duration,
        date: date,
        mode: .timed,
        insights: insights,
        transcriptConfidence: confidence,
        comparisonMetricSchemaVersion: comparisonMetricSchemaVersion,
        isEvaluationFixture: isEvaluationFixture
    )
}

@Suite("Summary filler-rate fairness")
struct SummaryFillerPresentationTests {
    private let priorDate = Date(timeIntervalSince1970: 1_000)

    private var repeatedBaseline: [PracticeSession] {
        [
            quantityFairnessSession(fillers: 2, duration: 60, words: 100, date: priorDate),
            quantityFairnessSession(fillers: 4, duration: 120, words: 200, date: priorDate.addingTimeInterval(-60))
        ]
    }

    @Test func exactSharedQuantityFloorIsEligible() throws {
        let presentation = SummaryFillerPresentation.make(
            fillerCount: 1,
            duration: 15,
            wordCount: 20,
            previousSessions: repeatedBaseline
        )

        #expect(try #require(presentation.currentRatePerMinute) == 4)
        #expect(presentation.tone == .warning)
    }

    @Test func durationOrWordCountBelowFloorWithholdsJudgment() {
        for (duration, words) in [(14.9, 20), (15.0, 19)] {
            let presentation = SummaryFillerPresentation.make(
                fillerCount: 0,
                duration: duration,
                wordCount: words,
                previousSessions: repeatedBaseline
            )

            #expect(presentation.currentRatePerMinute == nil)
            #expect(presentation.comparison == nil)
            #expect(presentation.derivedInsight == nil)
            #expect(presentation.tone == .insufficient)
            #expect(presentation.accessibilityLabel.contains("Not enough speech"))
        }
    }

    @Test func equalRatesRemainSteadyDespiteUnequalRawCounts() throws {
        let presentation = SummaryFillerPresentation.make(
            fillerCount: 1,
            duration: 30,
            wordCount: 50,
            previousSessions: repeatedBaseline
        )

        #expect(try #require(presentation.comparison).direction == .steady)
        #expect(presentation.meaningfulDeltaRatePerMinute == nil)
        #expect(presentation.derivedInsight == nil)
    }

    @Test func HigherRawCountCanStillBeAnImprovingRate() throws {
        let presentation = SummaryFillerPresentation.make(
            fillerCount: 3,
            duration: 180,
            wordCount: 300,
            previousSessions: repeatedBaseline
        )

        #expect(try #require(presentation.comparison).direction == .improving)
        #expect(presentation.derivedInsight?.contains("improved") == true)
        #expect(presentation.accessibilityLabel.contains("lower"))
    }

    @Test func LowerRawCountCanStillBeAWorseningRate() throws {
        let presentation = SummaryFillerPresentation.make(
            fillerCount: 1,
            duration: 15,
            wordCount: 20,
            previousSessions: repeatedBaseline
        )

        #expect(try #require(presentation.comparison).direction == .worsening)
        #expect(presentation.derivedInsight?.contains("rose above") == true)
        #expect(presentation.accessibilityLabel.contains("higher"))
    }

    @Test func comparisonRequiresTwoQualifiedPriorSamples() {
        let thin = quantityFairnessSession(fillers: 10, duration: 10, words: 50)
        let lowConfidence = quantityFairnessSession(fillers: 10, duration: 60, words: 100, confidence: 0.4)
        let presentation = SummaryFillerPresentation.make(
            fillerCount: 1,
            duration: 30,
            wordCount: 50,
            previousSessions: [repeatedBaseline[0], thin, lowConfidence]
        )

        #expect(presentation.currentRatePerMinute == 2)
        #expect(presentation.comparison == nil)
        #expect(presentation.accessibilityLabel.contains("No recent qualified average"))
    }

    @Test func lowConfidenceCurrentRepWithholdsJudgment() {
        let presentation = SummaryFillerPresentation.make(
            fillerCount: 1,
            duration: 60,
            wordCount: 100,
            transcriptConfidence: 0.4,
            previousSessions: repeatedBaseline
        )

        #expect(presentation.currentRatePerMinute == nil)
        #expect(presentation.comparison == nil)
        #expect(presentation.tone == .insufficient)
    }

    @Test func legacyMetricHistoryDoesNotBecomeAComparisonBaseline() {
        let legacy = repeatedBaseline.map { session in
            quantityFairnessSession(
                fillers: session.fillerWordCount,
                duration: session.duration,
                words: session.wordCount,
                date: session.date
            )
        }.map { session -> PracticeSession in
            PracticeSession(
                transcript: session.transcript,
                fillerWordCount: session.fillerWordCount,
                duration: session.duration,
                date: session.date,
                mode: session.mode,
                transcriptConfidence: session.transcriptConfidence,
                comparisonMetricSchemaVersion: nil
            )
        }
        let presentation = SummaryFillerPresentation.make(
            fillerCount: 1,
            duration: 30,
            wordCount: 50,
            previousSessions: legacy
        )

        #expect(presentation.currentRatePerMinute == 2)
        #expect(presentation.comparison == nil)
    }

    @Test func subThresholdJitterDoesNotBecomeProgress() throws {
        let previous = [
            quantityFairnessSession(fillers: 2, duration: 60, words: 100),
            quantityFairnessSession(fillers: 2, duration: 60, words: 100)
        ]
        let presentation = SummaryFillerPresentation.make(
            fillerCount: 6,
            duration: 180,
            wordCount: 300,
            previousSessions: previous
        )

        #expect(try #require(presentation.comparison).direction == .steady)
        #expect(presentation.meaningfulDeltaRatePerMinute == nil)
    }

    @Test func invalidCountsAndDurationsFailClosed() {
        let negative = SummaryFillerPresentation.make(
            fillerCount: -1,
            duration: 60,
            wordCount: 100,
            previousSessions: repeatedBaseline
        )
        let infinite = SummaryFillerPresentation.make(
            fillerCount: 1,
            duration: .infinity,
            wordCount: 100,
            previousSessions: repeatedBaseline
        )

        #expect(negative.currentRatePerMinute == nil)
        #expect(infinite.currentRatePerMinute == nil)
    }
}

@Suite("Coaching planner filler-rate fairness")
struct CoachingPlannerQuantityFairnessTests {
    private let baseDate = Date(timeIntervalSince1970: 10_000)

    @Test func equivalentRatesProduceSteadyEncouragement() throws {
        let sessions = [
            quantityFairnessSession(fillers: 1, duration: 30, words: 50, date: baseDate),
            quantityFairnessSession(fillers: 2, duration: 60, words: 100, date: baseDate.addingTimeInterval(-60)),
            quantityFairnessSession(fillers: 4, duration: 120, words: 200, date: baseDate.addingTimeInterval(-120))
        ]

        let plan = try #require(CoachingPlanner.plan(for: sessions, profile: nil))
        #expect(plan.encouragement.contains("holding steady"))
        #expect(plan.hiddenBaseline.averageFillersPerMinute == 2)
    }

    @Test func longLowRateHistoryDoesNotTriggerFillerPrescription() throws {
        let sessions = (0..<3).map { offset in
            quantityFairnessSession(
                fillers: 4,
                duration: 240,
                words: 400,
                date: baseDate.addingTimeInterval(Double(-offset * 60))
            )
        }

        let plan = try #require(CoachingPlanner.plan(for: sessions, profile: nil))
        #expect(!plan.currentFocus.localizedCaseInsensitiveContains("reducing filler"))
        #expect(!plan.suggestedDrill.localizedCaseInsensitiveContains("pause before each new point"))
    }

    @Test func urgentQualifiedRateTriggersFillerPrescriptionWithoutProfile() throws {
        let sessions = (0..<3).map { offset in
            quantityFairnessSession(
                fillers: 6,
                duration: 60,
                words: 100,
                date: baseDate.addingTimeInterval(Double(-offset * 60))
            )
        }

        let plan = try #require(CoachingPlanner.plan(for: sessions, profile: nil))
        #expect(plan.currentFocus.localizedCaseInsensitiveContains("reducing filler"))
        #expect(plan.suggestedDrill.localizedCaseInsensitiveContains("pause before each new point"))
    }

    @Test func thinLatestRepDoesNotClaimImprovementOrRegression() throws {
        let sessions = [
            quantityFairnessSession(fillers: 0, duration: 5, words: 5, date: baseDate),
            quantityFairnessSession(fillers: 2, duration: 60, words: 100, date: baseDate.addingTimeInterval(-60)),
            quantityFairnessSession(fillers: 2, duration: 60, words: 100, date: baseDate.addingTimeInterval(-120))
        ]

        let plan = try #require(CoachingPlanner.plan(for: sessions, profile: nil))
        #expect(plan.encouragement.contains("still forming"))
        #expect(!plan.encouragement.contains("cleaner"))
        #expect(!plan.encouragement.contains("less steady"))
    }

    @Test func historicalReviewIgnoresFutureSessions() {
        let reviewed = quantityFairnessSession(fillers: 2, duration: 60, words: 100, date: baseDate)
        let earlierA = quantityFairnessSession(fillers: 4, duration: 60, words: 100, date: baseDate.addingTimeInterval(-60))
        let earlierB = quantityFairnessSession(fillers: 4, duration: 60, words: 100, date: baseDate.addingTimeInterval(-120))
        let future = quantityFairnessSession(fillers: 0, duration: 600, words: 1_000, date: baseDate.addingTimeInterval(60))

        let insights = CoachingPlanner.sessionInsights(
            for: reviewed,
            comparedTo: [future, reviewed, earlierA, earlierB],
            profile: nil
        )

        #expect(insights.contains { $0.contains("below your earlier qualified average") })
    }

    @Test func unqualifiedHistoricalReviewWithholdsFillerAndPaceClaims() {
        let earlierA = quantityFairnessSession(fillers: 4, duration: 60, words: 100, date: baseDate.addingTimeInterval(-60))
        let earlierB = quantityFairnessSession(fillers: 4, duration: 60, words: 100, date: baseDate.addingTimeInterval(-120))
        let unqualified = [
            quantityFairnessSession(fillers: 0, duration: 5, words: 5, date: baseDate),
            quantityFairnessSession(fillers: 0, duration: 60, words: 100, date: baseDate, confidence: 0.49),
            quantityFairnessSession(
                fillers: 0,
                duration: 60,
                words: 100,
                date: baseDate,
                comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
            ),
            quantityFairnessSession(
                fillers: 0,
                duration: 60,
                words: 100,
                date: baseDate,
                isEvaluationFixture: true
            )
        ]

        for reviewed in unqualified {
            let insights = CoachingPlanner.sessionInsights(
                for: reviewed,
                comparedTo: [reviewed, earlierA, earlierB],
                profile: nil
            )

            #expect(!insights.contains { $0.localizedCaseInsensitiveContains("filler rate") })
            #expect(!insights.contains { $0.localizedCaseInsensitiveContains("pace check") })
        }
    }
}

@Suite("Practice evaluator filler-rate history")
struct PracticeEvaluatorQuantityTrendTests {
    private let current = quantityFairnessSession(fillers: 1, duration: 30, words: 50)
    private let priors = [
        quantityFairnessSession(fillers: 2, duration: 60, words: 100),
        quantityFairnessSession(fillers: 4, duration: 120, words: 200)
    ]

    @Test func equivalentRatesDoNotCreateAboveOrBelowInsight() {
        let insights = PracticeEvaluator.timedModeInsightsForTesting(
            fillerCount: 1,
            duration: 30,
            wordCount: 50,
            wordsPerMinute: 100,
            recentSessions: [current] + priors,
            transcript: current.transcript,
            prompt: nil
        )

        #expect(!insights.contains { $0.contains("filler rate was above") || $0.contains("filler rate was below") })
    }

    @Test func currentRepBelowWordFloorWithholdsTrend() {
        let insights = PracticeEvaluator.timedModeInsightsForTesting(
            fillerCount: 0,
            duration: 30,
            wordCount: 19,
            wordsPerMinute: 38,
            recentSessions: [current] + priors,
            transcript: Array(repeating: "word", count: 19).joined(separator: " "),
            prompt: nil
        )

        #expect(!insights.contains { $0.localizedCaseInsensitiveContains("filler rate") })
    }

    @Test func higherRawCountWithLowerRateProducesBelowAverageInsight() {
        let insights = PracticeEvaluator.timedModeInsightsForTesting(
            fillerCount: 3,
            duration: 180,
            wordCount: 300,
            wordsPerMinute: 100,
            recentSessions: [current] + priors,
            transcript: Array(repeating: "word", count: 300).joined(separator: " "),
            prompt: nil
        )

        #expect(insights.contains { $0.contains("filler rate was below") })
    }
}
