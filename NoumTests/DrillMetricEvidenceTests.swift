import Foundation
import Testing
@testable import Noum

@Suite("Drill metric evidence qualification", .serialized)
struct DrillMetricEvidenceTests {
    @Test("Thin speech cannot prescribe filler or pace from raw rates")
    func thinSpeechFailsClosed() {
        let recommendation = recommend(
            fillerCount: 12,
            duration: 15,
            wordCount: 19
        )

        #expect(recommendation.skillArea != .fillerReduction)
        #expect(recommendation.skillArea != .paceControl)
    }

    @Test("Low-confidence speech cannot prescribe filler or pace from raw rates")
    func lowConfidenceSpeechFailsClosed() {
        let recommendation = recommend(
            fillerCount: 12,
            duration: 15,
            wordCount: 60,
            transcriptConfidence: 0.49
        )

        #expect(recommendation.skillArea != .fillerReduction)
        #expect(recommendation.skillArea != .paceControl)
    }

    @Test("Stale metric schema cannot prescribe filler or pace")
    func staleSchemaFailsClosed() {
        let recommendation = recommend(
            fillerCount: 12,
            duration: 15,
            wordCount: 60,
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )

        #expect(recommendation.skillArea != .fillerReduction)
        #expect(recommendation.skillArea != .paceControl)
    }

    @Test("Evaluation fixtures cannot prescribe filler or pace")
    func evaluationFixtureFailsClosed() {
        let recommendation = recommend(
            fillerCount: 12,
            duration: 15,
            wordCount: 60,
            isEvaluationFixture: true
        )

        #expect(recommendation.skillArea != .fillerReduction)
        #expect(recommendation.skillArea != .paceControl)
    }

    @Test("Qualified evidence can still prescribe the measured weakness")
    func qualifiedEvidenceControlsFocus() {
        let fillerRecommendation = recommend(
            fillerCount: 12,
            duration: 15,
            wordCount: 60,
            transcriptConfidence: 0.5
        )
        let paceRecommendation = recommend(
            fillerCount: 0,
            duration: 15,
            wordCount: 60,
            transcriptConfidence: 0.5
        )

        #expect(fillerRecommendation.skillArea == .fillerReduction)
        #expect(fillerRecommendation.reason.contains("12 filler"))
        #expect(paceRecommendation.skillArea == .paceControl)
        #expect(paceRecommendation.reason.contains("240 WPM"))
    }

    @Test("Only qualified severe evidence can override the trend focus")
    func severeOverrideUsesQualifiedEvidence() {
        let structureTrend = SkillTrend(
            skillArea: .structure,
            direction: .stable,
            confidence: .high,
            windowSize: 8,
            currentLevel: .weak
        )
        let unqualified = recommend(
            fillerCount: 12,
            duration: 15,
            wordCount: 60,
            transcriptConfidence: 0.49,
            trends: [structureTrend]
        )
        let qualified = recommend(
            fillerCount: 12,
            duration: 15,
            wordCount: 60,
            transcriptConfidence: 0.5,
            trends: [structureTrend]
        )

        #expect(unqualified.skillArea == .structure)
        #expect(qualified.skillArea == .fillerReduction)
    }

    @Test("Explicit targets do not turn unqualified raw metrics into claims")
    func rationaleFailsClosed() {
        let fillerRecommendation = recommend(
            fillerCount: 12,
            duration: 15,
            wordCount: 60,
            transcriptConfidence: 0.49,
            targetArea: .fillerReduction
        )
        let paceRecommendation = recommend(
            fillerCount: 0,
            duration: 15,
            wordCount: 60,
            comparisonMetricSchemaVersion: nil,
            targetArea: .paceControl
        )
        let openingRecommendation = recommend(
            fillerCount: 12,
            duration: 15,
            wordCount: 60,
            isEvaluationFixture: true,
            targetArea: .openingStrength
        )

        #expect(!fillerRecommendation.reason.contains("12 filler"))
        #expect(!paceRecommendation.reason.contains("240 WPM"))
        #expect(!openingRecommendation.reason.contains("12 filler"))
    }

    private func recommend(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        transcriptConfidence: Double? = nil,
        comparisonMetricSchemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false,
        targetArea: SkillArea? = nil,
        trends: [SkillTrend] = []
    ) -> DrillRecommendationV2 {
        let defaults = UserDefaults(
            suiteName: "DrillMetricEvidenceTests.\(UUID().uuidString)"
        )!
        let history = DrillHistoryStore(
            defaults: defaults,
            accountIDProvider: { "metric-evidence" }
        )

        return DrillEngineV2.recommend(
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            score: 4,
            feedbackCategories: [],
            targetArea: targetArea,
            trendOverride: trends,
            drillHistory: history,
            transcriptConfidence: transcriptConfidence,
            comparisonMetricSchemaVersion: comparisonMetricSchemaVersion,
            isEvaluationFixture: isEvaluationFixture
        )
    }
}
