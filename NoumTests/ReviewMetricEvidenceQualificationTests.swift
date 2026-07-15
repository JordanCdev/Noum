import Foundation
import Testing
@testable import Noum

#if canImport(SwiftUI)
import SwiftUI

@MainActor
@Suite("Review metric evidence qualification")
struct ReviewMetricEvidenceQualificationTests {
    private typealias ChartPoint = ProgressionChartsCard.ChartPoint
    private typealias ChartSeries = ProgressionChartsCard.ChartSeries

    private let now = Date(timeIntervalSince1970: 2_100_000_000)

    @Test("Charts keep filler and pace optional without manufacturing zeroes")
    func chartMetricsUseHistoricalQualification() throws {
        let qualified = session(words: 30, duration: 20, fillers: 2, confidence: 0.9)
        let thin = session(words: 10, duration: 20, fillers: 8)
        let lowConfidence = session(words: 30, duration: 20, fillers: 8, confidence: 0.49)
        let stale = session(
            words: 30,
            duration: 20,
            fillers: 8,
            schema: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )
        let legacy = session(words: 30, duration: 20, fillers: 8, schema: nil)
        let fixture = session(words: 30, duration: 20, fillers: 8, isEvaluationFixture: true)

        let qualifiedPoint = try #require(ChartPoint(session: qualified))
        let thinPoint = try #require(ChartPoint(session: thin))
        let lowConfidencePoint = try #require(ChartPoint(session: lowConfidence))
        let stalePoint = try #require(ChartPoint(session: stale))
        let legacyPoint = try #require(ChartPoint(session: legacy))

        #expect(qualifiedPoint.fillerRate == 6)
        #expect(qualifiedPoint.pace == 90)
        #expect(thinPoint.fillerRate == nil)
        #expect(thinPoint.pace == nil)
        #expect(lowConfidencePoint.fillerRate == nil)
        #expect(lowConfidencePoint.pace == nil)
        #expect(stalePoint.fillerRate == nil)
        #expect(stalePoint.pace == nil)
        #expect(legacyPoint.fillerRate == nil)
        #expect(legacyPoint.pace == nil)
        #expect(ChartPoint(session: fixture).map { _ in false } ?? true)

        let points = [qualifiedPoint, thinPoint, lowConfidencePoint, stalePoint, legacyPoint]
        #expect(points.compactMap { ChartSeries.fillerRate.value(from: $0) } == [6])
        #expect(points.compactMap { ChartSeries.pace.value(from: $0) } == [90])
        #expect(ChartSeries.score.value(from: thinPoint) == 8)
    }

    @Test("Session detail withholds unqualified WPM while raw filler count remains inspectable")
    func detailPaceUsesHistoricalQualification() {
        let qualified = session(words: 30, duration: 20, fillers: 2, confidence: 0.9)
        let thin = session(words: 10, duration: 20, fillers: 8)
        let lowConfidence = session(words: 30, duration: 20, fillers: 8, confidence: 0.49)
        let stale = session(
            words: 30,
            duration: 20,
            fillers: 8,
            schema: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )
        let legacy = session(words: 30, duration: 20, fillers: 8, schema: nil)
        let fixture = session(words: 30, duration: 20, fillers: 8, isEvaluationFixture: true)

        #expect(SessionHistoryDetailPresentation.paceLabel(for: qualified) == "90")
        #expect(SessionHistoryDetailPresentation.paceLabel(for: thin) == "Not measured")
        #expect(SessionHistoryDetailPresentation.paceLabel(for: lowConfidence) == "Not measured")
        #expect(SessionHistoryDetailPresentation.paceLabel(for: stale) == "Not measured")
        #expect(SessionHistoryDetailPresentation.paceLabel(for: legacy) == "Not measured")
        #expect(SessionHistoryDetailPresentation.paceLabel(for: fixture) == "Not measured")
        #expect(lowConfidence.fillerWordCount == 8)
    }

    @Test("Replay filler targeting uses normalized qualified burden")
    func replayFillerSignalUsesQualifiedRate() {
        let concentrated = session(words: 47, duration: 20, fillers: 3)
        let diluted = session(words: 1_300, duration: 600, fillers: 6)
        let lowConfidence = session(words: 47, duration: 20, fillers: 3, confidence: 0.49)
        let thin = session(words: 10, duration: 20, fillers: 3)
        let stale = session(
            words: 47,
            duration: 20,
            fillers: 3,
            schema: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )
        let legacy = session(words: 47, duration: 20, fillers: 3, schema: nil)
        let fixture = session(words: 47, duration: 20, fillers: 3, isEvaluationFixture: true)

        #expect(MistakeReplayCard.hasFillerReplaySignal(concentrated))
        #expect(!MistakeReplayCard.hasFillerReplaySignal(diluted))
        #expect(!MistakeReplayCard.hasFillerReplaySignal(lowConfidence))
        #expect(!MistakeReplayCard.hasFillerReplaySignal(thin))
        #expect(!MistakeReplayCard.hasFillerReplaySignal(stale))
        #expect(!MistakeReplayCard.hasFillerReplaySignal(legacy))
        #expect(!MistakeReplayCard.hasFillerReplaySignal(fixture))
        #expect(diluted.fillerWordCount == 6)
    }

    @Test("Low-score replay remains independent when filler evidence is unavailable")
    func lowScoreReplayKeepsGeneralProgressEligibility() {
        let staleLowScore = session(
            words: 30,
            duration: 20,
            fillers: 0,
            score: 5,
            schema: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )

        #expect(!MistakeReplayCard.hasFillerReplaySignal(staleLowScore))
        #expect(MistakeReplayCard.hasReviewRows(in: [staleLowScore], now: now))
    }

    @Test("Goal-example ranking requires qualified filler and pace projections")
    func goalExampleUsesQualifiedMetrics() throws {
        let profile = chosenVoiceProfile(.authoritative)
        let qualified = session(words: 60, duration: 40, fillers: 0, confidence: 0.9)
        let lowConfidence = session(words: 60, duration: 40, fillers: 0, confidence: 0.49)
        let stale = session(
            words: 60,
            duration: 40,
            fillers: 0,
            schema: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )
        let legacy = session(words: 60, duration: 40, fillers: 0, schema: nil)
        let thin = session(words: 10, duration: 40, fillers: 0)
        let fixture = session(words: 60, duration: 40, fillers: 0, isEvaluationFixture: true)

        #expect(ReviewHighlightsEngine.goalExample(in: [lowConfidence], profile: profile) == nil)
        #expect(ReviewHighlightsEngine.goalExample(in: [stale], profile: profile) == nil)
        #expect(ReviewHighlightsEngine.goalExample(in: [legacy], profile: profile) == nil)
        #expect(ReviewHighlightsEngine.goalExample(in: [thin], profile: profile) == nil)
        #expect(ReviewHighlightsEngine.goalExample(in: [fixture], profile: profile) == nil)

        let highlight = try #require(
            ReviewHighlightsEngine.goalExample(in: [qualified, lowConfidence, stale], profile: profile)
        )
        #expect(highlight.sessionID == qualified.id)
        #expect(highlight.line.contains("0 fillers"))
        #expect(highlight.line.contains("90 WPM"))
    }

    @Test("Score-only highlights remain available without filler or pace evidence")
    func recentBestKeepsIndependentScoreEvidence() throws {
        let stale = session(
            words: 30,
            duration: 20,
            fillers: 8,
            score: 9,
            schema: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )

        let highlight = try #require(ReviewHighlightsEngine.recentBest(in: [stale], now: now))
        #expect(highlight.sessionID == stale.id)
        #expect(highlight.kind == .recentBest)
    }

    private func session(
        words: Int,
        duration: TimeInterval,
        fillers: Int,
        score: Int = 8,
        confidence: Double? = nil,
        schema: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false
    ) -> PracticeSession {
        PracticeSession(
            transcript: Array(repeating: "word", count: words).joined(separator: " "),
            fillerWordCount: fillers,
            duration: duration,
            date: now,
            mode: .timed,
            score: score,
            transcriptConfidence: confidence,
            comparisonMetricSchemaVersion: schema,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    private func chosenVoiceProfile(_ goal: SpeakingStyleGoal) -> CoachingProfile {
        var profile = CoachingProfile(
            speakingContext: .interviews,
            primaryGoal: .reduceFillers,
            confidenceLevel: .rebuilding,
            biggestChallenge: .fillerWords,
            desiredOutcome: .persuasive,
            speakingStyleGoal: goal,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: ""
        )
        profile.chosenStyleGoal = goal
        return profile
    }
}
#endif
