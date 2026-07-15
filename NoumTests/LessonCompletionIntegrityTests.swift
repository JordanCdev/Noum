import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Lesson completion integrity", .serialized)
struct LessonCompletionIntegrityTests {
    private let lesson = LessonsCatalog.checkUnderstanding
    private let eligibleTranscript =
        "I will send the revised proposal Thursday at three p m after Finance confirms the final number. Is that correct?"

    @Test("Terminal disposition rejects unusable and short capture evidence")
    func completionDispositionMatrix() throws {
        #expect(resolve(completion: nil, duration: 8) == .unusableRecording)
        #expect(resolve(completion: receipt("send Thursday correct", bytes: 0), duration: 8) == .unusableRecording)
        #expect(resolve(completion: receipt("send Thursday correct", final: false), duration: 8) == .unusableRecording)
        #expect(resolve(completion: receipt("   "), duration: 8) == .unusableRecording)

        #expect(resolve(completion: receipt(eligibleTranscript), duration: 2.99) == .insufficientDuration(required: 3))
        #expect(resolve(completion: receipt(eligibleTranscript), duration: .nan) == .insufficientDuration(required: 3))
        #expect(resolve(completion: receipt(eligibleTranscript), duration: .infinity) == .insufficientDuration(required: 3))

        guard case .evaluated(_, let thinEvaluation, let thinEvidence) = resolve(
            completion: receipt("send Thursday correct"),
            duration: 3
        ) else {
            Issue.record("Expected transport-valid keyword speech to reach the transparent rubric")
            return
        }
        #expect(!thinEvaluation.passed)
        #expect(thinEvaluation.firstMiss?.criterionID == "complete-answer")
        #expect(thinEvidence == nil)

        guard case .evaluated(let transcript, let evaluation, let evidence) = resolve(
            completion: receipt(eligibleTranscript),
            duration: 3
        ) else {
            Issue.record("Expected the exact terminal boundary to be evaluated")
            return
        }
        #expect(transcript == eligibleTranscript)
        #expect(evaluation.passed)
        #expect(evidence?.isVerified(for: lesson) == true)
    }

    @Test("Lesson outcomes require exact step shape and verified Apply evidence")
    func outcomeFailsClosed() throws {
        let evidence = try #require(LessonApplyCompletionEvidence.verified(
            transcript: eligibleTranscript,
            recorderDuration: 8,
            lesson: lesson
        ))
        let validSteps: [LessonOutcome.StepResult] = [
            .concept,
            .spotIt(passed: true),
            .apply(passed: true, didUseDevice: true),
        ]

        let valid = LessonOutcome(
            lessonID: lesson.id,
            stepResults: validSteps,
            xpEarned: 50,
            applyEvidence: evidence
        )
        #expect(valid.passed)
        #expect(valid.isPerfect)
        #expect(LessonXP.xp(for: valid) == 50)

        let missingEvidence = LessonOutcome(
            lessonID: lesson.id,
            stepResults: validSteps,
            xpEarned: 50
        )
        #expect(!missingEvidence.passed)
        #expect(LessonXP.xp(for: missingEvidence) == 0)

        let incomplete = LessonOutcome(
            lessonID: lesson.id,
            stepResults: [.concept, .spotIt(passed: true)],
            xpEarned: 50,
            applyEvidence: evidence
        )
        #expect(!incomplete.passed)

        let duplicate = LessonOutcome(
            lessonID: lesson.id,
            stepResults: validSteps + [.apply(passed: true, didUseDevice: true)],
            xpEarned: 50,
            applyEvidence: evidence
        )
        #expect(!duplicate.passed)
    }

    @Test("Account reload and teardown cannot leak lesson progress or celebrations")
    func accountLifecycleIsIsolated() throws {
        try withDefaults { defaults in
            var accountID = "account-a"
            let store = LessonStore(
                defaults: defaults,
                accountIDProvider: { accountID }
            )
            let outcome = try validOutcome()
            let now = Date(timeIntervalSince1970: 2_000_000_000)

            let update = store.apply(outcome: outcome, now: now)
            #expect(update.didAdvanceRetention)
            #expect(store.practicePassCount(for: lesson.id) == 1)
            #expect(store.pendingCelebration != nil)

            accountID = "account-b"
            store.reloadForCurrentAccount()
            #expect(store.progress.isEmpty)
            #expect(store.pendingCelebration == nil)

            accountID = "account-a"
            store.reloadForCurrentAccount()
            #expect(store.practicePassCount(for: lesson.id) == 1)
            #expect(store.pendingCelebration == nil)

            store.endSession()
            #expect(store.progress.isEmpty)
            #expect(store.pendingCelebration == nil)

            store.reloadForCurrentAccount()
            #expect(store.practicePassCount(for: lesson.id) == 1)
        }
    }

    @Test("Malformed outcomes cannot earn lesson progress or XP")
    func storeRejectsMissingEvidence() throws {
        try withDefaults { defaults in
            let store = LessonStore(
                defaults: defaults,
                accountIDProvider: { "account-a" }
            )
            let malformed = LessonOutcome(
                lessonID: lesson.id,
                stepResults: [
                    .concept,
                    .spotIt(passed: true),
                    .apply(passed: true, didUseDevice: true),
                ],
                xpEarned: 50
            )

            #expect(LessonXP.xp(for: malformed) == 0)
            let update = store.apply(outcome: malformed)
            #expect(!update.outcomePassed)
            #expect(!update.earnsXP)
            #expect(store.practicePassCount(for: lesson.id) == 0)
            #expect(store.progress(for: lesson.id).totalAttempts == 0)
            #expect(store.progress(for: lesson.id).lastCompletedAt == nil)
            #expect(store.pendingCelebration == nil)
        }
    }

    @Test("Account registry tears LessonStore down instead of reloading it")
    func registryUsesLessonEndSession() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/AccountDataRegistry.swift"),
            encoding: .utf8
        )

        #expect(source.contains(
            "participant(\"lessons\", [.accountKey(prefix: \"noum.lessons.progress.\")], reload: { LessonStore.shared.reloadForCurrentAccount() }, end: { LessonStore.shared.endSession() })"
        ))
    }

    private func resolve(
        completion: FinalizedTranscript?,
        duration: TimeInterval
    ) -> LessonApplyCompletionDisposition {
        LessonApplyCompletionDisposition.resolve(
            completion: completion,
            recorderDuration: duration,
            findings: [],
            lesson: lesson
        )
    }

    private func receipt(
        _ text: String,
        final: Bool = true,
        bytes: Int = 4_096
    ) -> FinalizedTranscript {
        FinalizedTranscript(
            text: text,
            receivedFinalResult: final,
            audioByteCount: bytes
        )
    }

    private func validOutcome() throws -> LessonOutcome {
        let evidence = try #require(LessonApplyCompletionEvidence.verified(
            transcript: eligibleTranscript,
            recorderDuration: 8,
            lesson: lesson
        ))
        return LessonOutcome(
            lessonID: lesson.id,
            stepResults: [
                .concept,
                .spotIt(passed: true),
                .apply(passed: true, didUseDevice: true),
            ],
            xpEarned: 50,
            applyEvidence: evidence
        )
    }

    private func withDefaults(
        _ body: (UserDefaults) throws -> Void
    ) throws {
        let suite = "LessonCompletionIntegrityTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}
