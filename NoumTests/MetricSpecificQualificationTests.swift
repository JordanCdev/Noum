import Foundation
import Testing
@testable import Noum

@Suite("Metric-specific quantity qualification")
struct MetricSpecificQualificationTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Pace uses the shared quantity and confidence floor")
    func pacePrimitiveBoundary() {
        #expect(SessionQualifier.quantityQualifiedWordsPerMinute(
            duration: 15,
            wordCount: 20,
            transcriptConfidence: 0.5
        ) == 80)
        #expect(SessionQualifier.quantityQualifiedWordsPerMinute(duration: 15, wordCount: 19) == nil)
        #expect(SessionQualifier.quantityQualifiedWordsPerMinute(duration: 14.999, wordCount: 20) == nil)
        #expect(SessionQualifier.quantityQualifiedWordsPerMinute(
            duration: 15,
            wordCount: 20,
            transcriptConfidence: 0.49
        ) == nil)
        #expect(SessionQualifier.quantityQualifiedWordsPerMinute(duration: .infinity, wordCount: 20) == nil)
    }

    @Test("Historical pace rejects stale schemas and evaluation rows")
    func historicalPaceProvenance() {
        let valid = session(words: 30, duration: 20, fillers: 1)
        let stale = session(
            words: 30,
            duration: 20,
            fillers: 1,
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )
        let fixture = session(words: 30, duration: 20, fillers: 1, isEvaluationFixture: true)

        #expect(SessionQualifier.quantityQualifiedWordsPerMinute(valid) == 90)
        #expect(SessionQualifier.quantityQualifiedWordsPerMinute(stale) == nil)
        #expect(SessionQualifier.quantityQualifiedWordsPerMinute(fixture) == nil)
        #expect(FillerBurden.quantityQualified(stale) == nil)
        #expect(FillerBurden.quantityQualified(fixture) == nil)
    }

    @Test("Trend confidence counts metric samples, not general progress reps")
    func trendPopulationIsMetricSpecific() throws {
        let thin = (0..<8).map { offset in
            snapshot(
                date: now.addingTimeInterval(Double(-offset)),
                fillerCount: 8,
                duration: 15,
                wordCount: 3,
                wpm: 260,
                qualified: false
            )
        }
        let qualified = (0..<3).map { offset in
            snapshot(
                date: now.addingTimeInterval(Double(-100 - offset)),
                fillerCount: 0,
                duration: 30,
                wordCount: 65,
                wpm: 130,
                qualified: true
            )
        }

        let trends = TrendAnalyzer.analyze(snapshots: thin + qualified)
        let filler = try #require(trends.first { $0.skillArea == .fillerReduction })
        let pace = try #require(trends.first { $0.skillArea == .paceControl })

        #expect(filler.windowSize == 3)
        #expect(filler.confidence == .medium)
        #expect(filler.currentLevel == .strong)
        #expect(pace.windowSize == 3)
        #expect(pace.confidence == .medium)
        #expect(pace.currentLevel == .strong)
    }

    @Test("Legacy and stale snapshot metrics fail closed without losing other evidence")
    func snapshotDecodingAndSchemaBoundary() throws {
        let legacy = snapshot(
            date: now,
            fillerCount: 8,
            duration: 30,
            wordCount: 60,
            wpm: 200,
            qualified: false
        )
        let roundTrip = try JSONDecoder().decode(
            SkillSnapshot.self,
            from: JSONEncoder().encode(legacy)
        )
        #expect(roundTrip.currentQualifiedFillerRatePerMinute == nil)
        #expect(roundTrip.currentQualifiedPaceWPM == nil)
        #expect(roundTrip.score == legacy.score)

        let stale = SkillSnapshot(
            sessionId: UUID(),
            fillerCount: 8,
            duration: 30,
            wordCount: 60,
            wpm: 120,
            qualifiedFillerRatePerMinute: 16,
            qualifiedPaceWPM: 120,
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1,
            score: 7
        )
        #expect(stale.currentQualifiedFillerRatePerMinute == nil)
        #expect(stale.currentQualifiedPaceWPM == nil)
    }

    @Test("Current focus ignores raw filler and pace values when metric evidence is absent")
    func currentFocusFailsClosed() {
        let thin = snapshot(
            date: now,
            fillerCount: 8,
            duration: 15,
            wordCount: 3,
            wpm: 260,
            qualified: false
        )
        let qualified = snapshot(
            date: now,
            fillerCount: 4,
            duration: 20,
            wordCount: 45,
            wpm: 135,
            qualified: true
        )

        #expect(TrendAnalyzer.primaryFocus(
            trends: [],
            currentSessionSnapshot: thin,
            recentDrills: []
        ) == .structure)
        #expect(TrendAnalyzer.primaryFocus(
            trends: [],
            currentSessionSnapshot: qualified,
            recentDrills: []
        ) == .fillerReduction)

        let noEvidenceTrends = TrendAnalyzer.analyze(snapshots: [thin])
        let fillerTrend = noEvidenceTrends.first { $0.skillArea == .fillerReduction }
        let paceTrend = noEvidenceTrends.first { $0.skillArea == .paceControl }
        #expect(fillerTrend?.windowSize == 0)
        #expect(fillerTrend?.currentLevel == .developing)
        #expect(paceTrend?.windowSize == 0)
        #expect(paceTrend?.currentLevel == .developing)
    }

    @Test("Baseline comparison withholds thin filler and pace interpretations")
    func baselineComparisonRequiresQualifiedCurrentSession() {
        let baselineSessions = (0..<5).map { offset in
            session(
                words: 50,
                duration: 25,
                fillers: 1,
                date: now.addingTimeInterval(Double(-100 - offset))
            )
        }
        let baseline = BaselineEngine.compute(from: baselineSessions)
        let thin = session(words: 3, duration: 15, fillers: 8, score: 9)
        let valid = session(words: 50, duration: 25, fillers: 8, score: 9)

        let thinComparison = BaselineEngine.sessionComparison(session: thin, baseline: baseline)
        let validComparison = BaselineEngine.sessionComparison(session: valid, baseline: baseline)

        #expect(thinComparison["Fillers"] == nil)
        #expect(thinComparison["Pace"] == nil)
        #expect(validComparison["Fillers"] != nil)
        #expect(validComparison["Pace"] != nil)
    }

    @Test("Recommendation aggregates and prompt projection ignore thin mechanics")
    func recommendationProjectionUsesQualifiedMetrics() {
        let thin = session(words: 3, duration: 15, fillers: 9, date: now)
        let valid = session(
            words: 60,
            duration: 30,
            fillers: 1,
            date: now.addingTimeInterval(-60)
        )
        let input = RecommendationBiasContextBuilder.input(
            profile: nil,
            sessions: [thin, valid],
            plan: nil,
            sessionStreak: 1,
            daysSinceLastSession: 0
        )

        #expect(input.averageFillersPerMinute == 2)
        #expect(input.averageWordsPerMinute == 120)
        #expect(input.recentSessionSummary.contains("wpm=not_measured"))
        #expect(input.recentSessionSummary.contains("wpm=120"))
    }

    @Test("Thin newest rep cannot advance clean streak or filler trend")
    func momentumRequiresQualifiedNewestRep() {
        let thin = session(words: 3, duration: 15, fillers: 0, date: now)
        let qualified = (0..<6).map { offset in
            session(
                words: 60,
                duration: 30,
                fillers: offset < 3 ? 0 : 3,
                date: now.addingTimeInterval(Double(-100 - offset))
            )
        }
        let sorted = [thin] + qualified

        #expect(MomentumComputer.consecutiveCleanReps(
            sorted: sorted,
            baselineFillerRate: 4
        ) == 0)
        #expect(MomentumComputer.fillerTrend(sorted: sorted) == nil)
    }

    @Test("Severe filler routing requires the metric word floor")
    func severeFillerRoutingRequiresMetricQuantity() {
        let input = NextActionInput(
            fillerCount: 3,
            duration: 15,
            wordCount: 3,
            wpm: 12,
            score: 5,
            categoryRatings: ["Structure": "Could improve"],
            mode: .timed,
            pressureLevel: .standard,
            baseline: .empty,
            pressureProfile: .empty,
            trends: [],
            drillHistory: [],
            sessionCount: 1,
            streakDays: 1,
            styleGoal: nil
        )

        let result = NextActionEngine.recommend(input: input)
        #expect(!result.reasoning.contains("clear constraint"))
        if case .practiceMode(let mode, _) = result.primary {
            #expect(mode != .ahCounter)
        }
    }

    private func session(
        words: Int,
        duration: TimeInterval,
        fillers: Int,
        date: Date? = nil,
        score: Int? = 7,
        confidence: Double? = nil,
        comparisonMetricSchemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false
    ) -> PracticeSession {
        PracticeSession(
            transcript: Array(repeating: "word", count: words).joined(separator: " "),
            fillerWordCount: fillers,
            duration: duration,
            date: date ?? now,
            mode: .timed,
            score: score,
            transcriptConfidence: confidence,
            comparisonMetricSchemaVersion: comparisonMetricSchemaVersion,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    private func snapshot(
        date: Date,
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        wpm: Double,
        qualified: Bool
    ) -> SkillSnapshot {
        let fillerRate = qualified ? Double(fillerCount) / (duration / 60) : nil
        return SkillSnapshot(
            sessionId: UUID(),
            date: date,
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            wpm: wpm,
            qualifiedFillerRatePerMinute: fillerRate,
            qualifiedPaceWPM: qualified ? wpm : nil,
            comparisonMetricSchemaVersion: qualified
                ? PracticeSession.currentComparisonMetricSchemaVersion
                : nil,
            score: 7
        )
    }
}
