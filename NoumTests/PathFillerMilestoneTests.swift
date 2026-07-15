import Foundation
import Testing
@testable import Noum

struct PathFillerMilestoneTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func session(
        fillerCount: Int = 0,
        duration: TimeInterval = 60,
        wordCount: Int = 20,
        confidence: Double? = 0.9,
        comparisonSchemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false,
        score: Int? = 5,
        dayOffset: Int = 0
    ) -> PracticeSession {
        PracticeSession(
            transcript: Array(repeating: "word", count: wordCount).joined(separator: " "),
            fillerWordCount: fillerCount,
            duration: duration,
            date: Calendar.current.date(byAdding: .day, value: dayOffset, to: now) ?? now,
            mode: .timed,
            score: score,
            transcriptConfidence: confidence,
            comparisonMetricSchemaVersion: comparisonSchemaVersion,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    private func input(_ sessions: [PracticeSession]) -> PathProgressInput {
        PathProgressInput(
            sessions: sessions,
            currentStreak: 0,
            baseline: .empty,
            rating: .initial,
            modeMastery: [:],
            totalLessonPasses: 0,
            maxLessonPassCount: 0,
            now: now
        )
    }

    @Test func singleCleanRepAcceptsQualifiedEvidence() {
        let criterion = PathNodeCriterion.zeroFillerSession

        #expect(
            criterion.isComplete(
                for: input([session(duration: 15, wordCount: 20, confidence: 0.5)])
            )
        )
    }

    @Test func singleCleanRepRejectsShortDuration() {
        let criterion = PathNodeCriterion.zeroFillerSession

        #expect(!criterion.isComplete(for: input([session(duration: 14.99)])))
    }

    @Test func singleCleanRepRejectsNineteenWords() {
        let criterion = PathNodeCriterion.zeroFillerSession

        #expect(!criterion.isComplete(for: input([session(wordCount: 19)])))
    }

    @Test func singleCleanRepRejectsLowConfidence() {
        let criterion = PathNodeCriterion.zeroFillerSession

        #expect(!criterion.isComplete(for: input([session(confidence: 0.49)])))
    }

    @Test func singleCleanRepRejectsStaleMetricSchema() {
        let criterion = PathNodeCriterion.zeroFillerSession

        #expect(!criterion.isComplete(for: input([session(comparisonSchemaVersion: 0)])))
    }

    @Test func singleCleanRepRejectsMissingMetricSchema() {
        let criterion = PathNodeCriterion.zeroFillerSession

        #expect(!criterion.isComplete(for: input([session(comparisonSchemaVersion: nil)])))
    }

    @Test func singleCleanRepRejectsEvaluationFixture() {
        let criterion = PathNodeCriterion.zeroFillerSession

        #expect(!criterion.isComplete(for: input([session(isEvaluationFixture: true)])))
    }

    @Test func singleCleanRepRejectsDetectedFiller() {
        let criterion = PathNodeCriterion.zeroFillerSession

        #expect(!criterion.isComplete(for: input([session(fillerCount: 1)])))
    }

    @Test func fillerFreeWeekRequiresFiveQualifiedScoredReps() {
        let sessions = (0..<5).map { session(dayOffset: -$0) }
        let criterion = PathNodeCriterion.cleanRunsInWindow(5, minScore: 5)

        #expect(criterion.isComplete(for: input(sessions)))
    }

    @Test func disqualifiedRepDoesNotAdvanceFillerFreeWeek() {
        let qualified = (0..<4).map { session(dayOffset: -$0) }
        let thin = session(wordCount: 19, dayOffset: -4)
        let criterion = PathNodeCriterion.cleanRunsInWindow(5, minScore: 5)

        #expect(criterion.progress(for: input(qualified + [thin])) == 0.8)
        #expect(
            GatingPhrase.copy(for: criterion, input: input(qualified + [thin]))
                == "1 more full clean rep (20+ words, 15s+, 5/10+) in seven days from unlocked."
        )
    }

    @Test func lowScoreDoesNotAdvanceFillerFreeWeek() {
        let sessions = (0..<4).map { session(dayOffset: -$0) }
            + [session(score: 4, dayOffset: -4)]
        let criterion = PathNodeCriterion.cleanRunsInWindow(5, minScore: 5)

        #expect(criterion.progress(for: input(sessions)) == 0.8)
    }

    @Test func repOutsideSevenDayWindowDoesNotAdvanceFillerFreeWeek() {
        let sessions = (0..<4).map { session(dayOffset: -$0) }
            + [session(dayOffset: -8)]
        let criterion = PathNodeCriterion.cleanRunsInWindow(5, minScore: 5)

        #expect(criterion.progress(for: input(sessions)) == 0.8)
    }

    @Test func completedFillerFreeWeekUsesReadyGatingPhrase() {
        let sessions = (0..<5).map { session(dayOffset: -$0) }
        let criterion = PathNodeCriterion.cleanRunsInWindow(5, minScore: 5)

        #expect(GatingPhrase.copy(for: criterion, input: input(sessions)) == "Ready to mark complete.")
    }

    @Test func cleanRepGatingPhraseNamesSharedQuantityFloor() {
        let copy = GatingPhrase.copy(
            for: .zeroFillerSession,
            input: input([])
        )

        #expect(copy == "One zero-filler rep (20+ words, 15s+) from unlocked.")
        #expect(copy?.contains("14+") == false)
    }

    @Test func persistedFillerWeekUnlockSurvivesTightenedLiveCriterion() throws {
        let legacyPayload = try JSONEncoder().encode(["clean_rep", "filler_free_week"])
        let persistedIDs = PathUnlockCodec.decode(legacyPayload)

        #expect(
            PathUnlockPolicy.isComplete(
                nodeID: "filler_free_week",
                liveProgress: 0,
                unlockedNodeIDs: persistedIDs
            )
        )
        #expect(
            !PathUnlockPolicy.isComplete(
                nodeID: "filler_free_week",
                liveProgress: 0,
                unlockedNodeIDs: []
            )
        )
    }

    @Test func unlockCodecPreservesExistingJSONShape() throws {
        let encoded = try #require(
            PathUnlockCodec.encode(["filler_free_week", "clean_rep"])
        )
        let decodedArray = try JSONDecoder().decode([String].self, from: encoded)

        #expect(decodedArray == ["clean_rep", "filler_free_week"])
        #expect(PathUnlockCodec.decode(encoded) == ["clean_rep", "filler_free_week"])
    }

    @Test func registryCopyDisclosesEvidenceBarWithoutPressureTransferClaim() throws {
        let entry = try #require(
            PathNodeRegistry.all.first { $0.0.id == "filler_free_week" }
        )

        #expect(entry.0.detail.contains("20+ words"))
        #expect(entry.0.detail.contains("15+ seconds"))
        #expect(entry.0.detail.contains("5/10+"))
        #expect(!entry.0.coachLine.lowercased().contains("pressure"))
    }
}
