import Foundation
import Testing
@testable import Noum

@Suite("Path unlock celebration integrity")
struct PathUnlockCelebrationIntegrityTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func session(
        id: UUID = UUID(),
        words: Int = 20,
        duration: TimeInterval = 20,
        mode: PracticeMode = .timed,
        score: Int? = 5,
        dayOffset: Int = 0,
        isEvaluationFixture: Bool = false
    ) -> PracticeSession {
        PracticeSession(
            id: id,
            transcript: Array(repeating: "word", count: words).joined(separator: " "),
            fillerWordCount: 0,
            duration: duration,
            date: Calendar.current.date(byAdding: .day, value: dayOffset, to: now) ?? now,
            mode: mode,
            score: score,
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

    @Test("Only finalized, non-fixture reps advance general Path criteria")
    func progressEligibilityMatrix() {
        let eligible = session()
        let tooShort = session(duration: 2.99)
        let tooFewWords = session(words: 2)
        let fixture = session(isEvaluationFixture: true)
        let progress = input([eligible, tooShort, tooFewWords, fixture])

        #expect(progress.sessionCount == 1)
        #expect(PathNodeCriterion.sessionCountAtLeast(2).progress(for: progress) == 0.5)
        #expect(PathNodeCriterion.modeSessionAtLeast(.timed, 2).progress(for: progress) == 0.5)
        #expect(PathNodeCriterion.scoreAtLeast(6).progress(for: progress) == Double(5) / 6)
        #expect(progress.distinctPracticeDayCount == 1)
    }

    @Test("The progress floor rejects invalid duration without hiding valid short reps")
    func sharedProgressFloor() {
        #expect(PracticeProgressEligibility.qualifies(wordCount: 3, duration: 3))
        #expect(!PracticeProgressEligibility.qualifies(wordCount: 2, duration: 3))
        #expect(!PracticeProgressEligibility.qualifies(wordCount: 3, duration: 2.99))
        #expect(!PracticeProgressEligibility.qualifies(wordCount: 20, duration: .infinity))
        #expect(!PracticeProgressEligibility.qualifies(wordCount: 20, duration: 20, isEvaluationFixture: true))
    }

    @Test("Unlock resolution keeps registry order and exact session provenance")
    func unlockEventOrderingAndProvenance() throws {
        let sessionID = UUID()
        let event = try #require(
            PathUnlockCelebrationResolver.resolve(
                snapshot: PathUnlockSnapshot(unlockedNodeIDs: ["first_rep"]),
                currentUnlockedNodeIDs: ["first_rep", "clean_rep", "three_reps"],
                triggeringSessionID: sessionID,
                orderedNodeIDs: ["first_rep", "three_reps", "clean_rep"]
            )
        )

        #expect(event.nodeID == "three_reps")
        #expect(event.triggeringSessionID == sessionID)
    }

    @Test("No newly unlocked node produces no celebration")
    func noFalseCelebration() {
        let ids: Set<String> = ["first_rep", "three_reps"]
        #expect(
            PathUnlockCelebrationResolver.resolve(
                snapshot: PathUnlockSnapshot(unlockedNodeIDs: ids),
                currentUnlockedNodeIDs: ids,
                triggeringSessionID: UUID(),
                orderedNodeIDs: Array(ids)
            ) == nil
        )
    }

    @Test("Common finalization snapshots before append and emits the exact event once")
    func finalizationSourceContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let practiceSupport = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/PracticeSupport.swift"),
            encoding: .utf8
        )
        let sessionFinalizer = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SessionFinalizer.swift"),
            encoding: .utf8
        )

        let snapshot = try #require(practiceSupport.range(of: "captureUnlockSnapshot()"))
        let append = try #require(practiceSupport.range(of: "store.append(intentAwareDraft)"))
        let evaluate = try #require(practiceSupport.range(of: "evaluateAfterSession(\n            triggeringSessionID: finalized.id"))
        #expect(snapshot.lowerBound < append.lowerBound)
        #expect(append.lowerBound < evaluate.lowerBound)
        #expect(!sessionFinalizer.contains("PathProgressManager.shared.evaluateAfterSession"))
    }

    @Test("Celebration copy and proof resolve the triggering session, never array position")
    func renderedProvenanceSourceContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let celebration = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/PathNodeCelebration.swift"),
            encoding: .utf8
        )
        let content = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/ContentView.swift"),
            encoding: .utf8
        )

        #expect(celebration.contains("first(where: { $0.id == triggeringSessionID })"))
        #expect(!celebration.contains("sessionStore.sessions.last"))
        #expect(content.contains("first(where: { $0.id == sessionID })"))
        #expect(content.contains("pendingCelebrationSessionID == sessionID"))
    }
}
