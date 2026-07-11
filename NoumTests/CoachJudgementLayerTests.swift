//
//  CoachJudgementLayerTests.swift
//  NoumTests
//
//  Focused coverage for the low-latency coach judgement pass: turn depth,
//  rubric selection, deterministic assessment, semantic gate, provider routing,
//  live budgets, and provisional pending-row rendering.
//

import Foundation
import Testing
@testable import Noum

@Suite("BackendAuthHeadersTests")
struct BackendAuthHeadersTests {

    @Test func bearerTokenSuppressesSpoofableIdentityHeaders() {
        var request = URLRequest(url: URL(string: "https://example.com/v1/test")!)
        let headers = BackendAuthHeaders(
            accountID: " account-123 ",
            providerRawValue: " firebase ",
            apiKey: " backend-key ",
            firebaseIDToken: " firebase-token "
        )

        headers.apply(to: &request)

        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.authorizationHeader) == "Bearer firebase-token")
        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.apiKeyHeader) == "backend-key")
        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.accountIDHeader) == nil)
        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.authProviderHeader) == nil)
    }

    @Test func legacyTransitionHeadersOnlyApplyWithoutBearerToken() {
        var request = URLRequest(url: URL(string: "https://example.com/v1/test")!)
        let headers = BackendAuthHeaders(
            accountID: " account-123 ",
            providerRawValue: " guest ",
            apiKey: " backend-key ",
            firebaseIDToken: nil
        )

        headers.apply(to: &request)

        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.authorizationHeader) == nil)
        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.accountIDHeader) == "account-123")
        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.authProviderHeader) == "guest")
        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.apiKeyHeader) == "backend-key")
    }

    @Test func omitsBlankHeaderValues() {
        var request = URLRequest(url: URL(string: "https://example.com/v1/test")!)
        let headers = BackendAuthHeaders(
            accountID: " ",
            providerRawValue: "\n",
            apiKey: nil,
            firebaseIDToken: "\t"
        )

        headers.apply(to: &request)

        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.authorizationHeader) == nil)
        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.accountIDHeader) == nil)
        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.authProviderHeader) == nil)
        #expect(request.value(forHTTPHeaderField: BackendAuthHeaders.apiKeyHeader) == nil)
    }

    @Test func configuredAPIKeyPrefersEnvironmentOverConfig() {
        let key = BackendAuthHeaders.configuredAPIKey(
            env: ["BACKEND_API_KEY": " env-key "],
            configValue: { _ in "config-key" }
        )

        #expect(key == "env-key")
    }

    @Test func configuredAPIKeyFallsBackToTrimmedConfig() {
        let key = BackendAuthHeaders.configuredAPIKey(
            env: [:],
            configValue: { _ in " config-key " }
        )

        #expect(key == "config-key")
    }
}

@Suite("TurnDepthClassifierTests")
struct TurnDepthClassifierTests {

    @Test func distanceToGoalQuestionsAreDeepAssessment() {
        #expect(TurnDepthClassifier.classify(
            userText: "How far off am I from sounding authoritative?"
        ) == .deepAssessment)
        #expect(TurnDepthClassifier.classify(
            userText: "Be honest, am I close to my goal overall?"
        ) == .deepAssessment)
    }

    @Test func qualitativeJudgementQuestionsAreDeepAssessment() {
        #expect(TurnDepthClassifier.classify(
            userText: "Do I lack conviction?"
        ) == .deepAssessment)
        #expect(TurnDepthClassifier.classify(
            userText: "Could this sound polished but evasive?"
        ) == .deepAssessment)
        #expect(TurnDepthClassifier.classify(
            userText: "Does this sound credible enough for the board?"
        ) == .deepAssessment)
    }

    @Test func softerPerceptionQuestionsAreGroundedRead() {
        #expect(TurnDepthClassifier.classify(
            userText: "Do I sound timid?"
        ) == .groundedRead)
        #expect(TurnDepthClassifier.classify(
            userText: "How did I sound in that answer?"
        ) == .groundedRead)
    }

    @Test func howToSoundMoreConfidentIsQuickMove() {
        #expect(TurnDepthClassifier.classify(
            userText: "How do I sound more confident at the end?"
        ) == .quickMove)
    }

    @Test func goalChangeLanguageDoesNotBecomeDeepAssessment() {
        #expect(TurnDepthClassifier.classify(
            userText: "I think I want to sound more engaging."
        ) == .quickMove)
    }

    @Test func nextMoveQuestionsAreQuickMove() {
        #expect(TurnDepthClassifier.classify(
            userText: "What should I do next?"
        ) == .quickMove)
    }

    @Test func memoryHandoffQuestionsAreGroundedReads() {
        #expect(TurnDepthClassifier.classify(
            userText: "What should Noum remember?"
        ) == .groundedRead)
        #expect(TurnDepthClassifier.classify(
            userText: "So what should you remember next time?"
        ) == .groundedRead)
    }

    @Test func repReadQuestionsAreGroundedRead() {
        #expect(TurnDepthClassifier.classify(
            userText: "What happened in that rep?"
        ) == .groundedRead)
    }

    @Test func coachPushbackIsTrustRepair() {
        #expect(TurnDepthClassifier.classify(
            userText: "That's not informative at all. You missed the point."
        ) == .trustRepair)
        #expect(TurnDepthClassifier.classify(
            userText: "It's not easy."
        ) == .trustRepair)
        #expect(TurnDepthClassifier.classify(
            userText: "You're repeating yourself."
        ) == .trustRepair)
        #expect(TurnDepthClassifier.classify(
            userText: "Too much writing. Get to the point."
        ) == .trustRepair)
    }

    @Test func politeHoweverAfterCoachReplyIsTrustRepair() {
        let history = [
            CoachMessage(role: .coach, text: "Your next move is to run another timed rep.")
        ]

        #expect(TurnDepthClassifier.classify(
            userText: "Okay, that's cool. However, I don't feel like that answered what I meant.",
            recentTurns: history
        ) == .trustRepair)
    }

    @Test func explicitDidNotAnswerWhatIMeantIsTrustRepair() {
        // The unambiguous pushback form stays classified as trust repair.
        #expect(TurnDepthClassifier.classify(
            userText: "That didn't answer what I meant."
        ) == .trustRepair)
    }

    @Test func benignSelfClarificationIsNotTrustRepair() {
        // Regression: a bare "what I meant" self-clarification (and a bare
        // "real question") is NOT pushback. Routing it to trust repair would
        // emit a phantom "you're right to push me" attunement opener for a
        // user who was simply restating their ask.
        #expect(TurnDepthClassifier.classify(
            userText: "What I meant was, I want to focus on my pacing."
        ) != .trustRepair)
        #expect(TurnDepthClassifier.classify(
            userText: "My real question is whether my pacing improved."
        ) != .trustRepair)
    }
}

@Suite("CoachStreamingPartialGateTests")
struct CoachStreamingPartialGateTests {

    @Test func waitsForCompleteSentenceBeforeRendering() {
        var gate = CoachStreamingPartialGate()

        #expect(gate.consume(delta: "You are closer mechanically") == nil)
        #expect(gate.consume(delta: " than authoritatively overall") == nil)

        let visible = gate.consume(delta: ". Mechanics still need pressure proof.")
        #expect(visible == "You are closer mechanically than authoritatively overall.")
    }

    @Test func streamsAfterFirstGuardedSentenceReleases() {
        var gate = CoachStreamingPartialGate()

        _ = gate.consume(delta: "You are closer mechanically than authoritatively overall.")

        let next = gate.consume(delta: " Mechanics still need pressure proof")
        #expect(next == "You are closer mechanically than authoritatively overall. Mechanics still need pressure proof")
    }

    @Test func sanitizedScaffoldOnlyPrefixDoesNotRender() {
        var gate = CoachStreamingPartialGate()

        #expect(gate.consume(delta: "**Read:**\n- **Move:**") == nil)
        let visible = gate.consume(delta: " Start with the verdict, then stop.")

        #expect(visible == "Start with the verdict, then stop.")
        #expect(visible?.contains("**") == false)
        #expect(visible?.localizedCaseInsensitiveContains("Read:") == false)
        #expect(visible?.localizedCaseInsensitiveContains("Move:") == false)
    }

    @Test func veryShortInterjectionDoesNotBecomeFirstVisibleToken() {
        var gate = CoachStreamingPartialGate()

        #expect(gate.consume(delta: "Fair.") == nil)
        let visible = gate.consume(delta: " I missed the actual distance-to-goal question.")

        #expect(visible == "Fair. I missed the actual distance-to-goal question.")
    }
}

@Suite("GoalRubricStoreTests")
struct GoalRubricStoreTests {

    @Test func authoritativeRubricCarriesRequiredDimensions() {
        let rubric = GoalRubricStore.rubric(for: .authoritative)
        let ids = Set(rubric.dimensions.map(\.id))

        #expect(rubric.goalID == "authoritative")
        #expect(ids.contains("verdict_first"))
        #expect(ids.contains("hedge_control"))
        #expect(ids.contains("clean_close"))
        #expect(ids.contains("pressure_stability"))
        #expect(ids.contains("controlled_pacing"))
        #expect(ids.contains("salience"))
    }
}

@Suite("UserTrajectoryCacheTests", .serialized)
struct UserTrajectoryCacheTests {

    @Test func repeatedSnapshotWithSameInputsHitsCache() {
        let cache = UserTrajectoryCache.shared
        cache.invalidate()
        let session = Self.session(id: UUID(), date: Date(timeIntervalSince1970: 1_000))

        let first = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )
        let second = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )

        #expect(first.cacheHit == false)
        #expect(second.cacheHit == true)
        #expect(second.snapshot.latestRepEvidencePack?.fillerCount == 1)
        cache.invalidate()
    }

    @Test func invalidateForcesNextSnapshotToRebuild() {
        let cache = UserTrajectoryCache.shared
        cache.invalidate()
        let session = Self.session(id: UUID(), date: Date(timeIntervalSince1970: 2_000))

        _ = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )
        cache.invalidate()
        let rebuilt = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )

        #expect(rebuilt.cacheHit == false)
        cache.invalidate()
    }

    @Test func changedSessionEvidenceMissesCacheWithoutManualInvalidation() {
        let cache = UserTrajectoryCache.shared
        cache.invalidate()
        let first = Self.session(id: UUID(), date: Date(timeIntervalSince1970: 3_000), fillerWordCount: 1)
        let second = Self.session(id: UUID(), date: Date(timeIntervalSince1970: 4_000), fillerWordCount: 4)

        _ = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [first],
            coachMemory: nil
        )
        let rebuilt = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [second, first],
            coachMemory: nil
        )

        #expect(rebuilt.cacheHit == false)
        #expect(rebuilt.snapshot.latestRepEvidencePack?.fillerCount == 4)
        cache.invalidate()
    }

    @Test func changedEvidenceOnSameSessionIdentityMissesCacheWithoutManualInvalidation() {
        let cache = UserTrajectoryCache.shared
        cache.invalidate()
        let sessionID = UUID()
        let date = Date(timeIntervalSince1970: 3_500)
        let first = Self.session(
            id: sessionID,
            date: date,
            fillerWordCount: 1,
            transcript: "We should make the decision now because the team needs a clear recommendation.",
            duration: 60,
            score: 7,
            confidence: 0.90
        )
        let revised = Self.session(
            id: sessionID,
            date: date,
            fillerWordCount: 5,
            transcript: "Um maybe we could sort of wait because I am not sure what recommendation to make.",
            duration: 42,
            score: 4,
            confidence: 0.61
        )

        _ = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [first],
            coachMemory: nil
        )
        let rebuilt = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [revised],
            coachMemory: nil
        )

        #expect(rebuilt.cacheHit == false)
        #expect(rebuilt.snapshot.latestRepEvidencePack?.fillerCount == 5)
        #expect(rebuilt.snapshot.latestRepEvidencePack?.score == 4)
        #expect(rebuilt.snapshot.latestRepEvidencePack?.durationSeconds == 42)
        #expect(rebuilt.snapshot.latestRepEvidencePack?.transcriptExcerpt?.lowercased().contains("maybe") == true)
        cache.invalidate()
    }

    @Test func changedBaselineMetricsMissCacheWithoutManualInvalidation() {
        let cache = UserTrajectoryCache.shared
        cache.invalidate()
        let session = Self.session(id: UUID(), date: Date(timeIntervalSince1970: 4_250))
        let firstBaseline = Self.baseline(fillerRate: 1.2, pace: 128, hedgingRate: 0.2)
        let revisedBaseline = Self.baseline(fillerRate: 4.4, pace: 151, hedgingRate: 1.6)

        _ = cache.snapshot(
            profile: nil,
            baseline: firstBaseline,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )
        let rebuilt = cache.snapshot(
            profile: nil,
            baseline: revisedBaseline,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )

        #expect(rebuilt.cacheHit == false)
        #expect(rebuilt.snapshot.trendLines.contains("baseline filler rate: 4.4/min"))
        #expect(rebuilt.snapshot.trendLines.contains("baseline pace: 151 WPM"))
        #expect(rebuilt.snapshot.trendLines.contains("baseline hedging: 1.6/min"))
        cache.invalidate()
    }

    @Test @MainActor func baselineStoreRebuildInvalidatesTrajectoryCacheForSameInputs() {
        let cache = UserTrajectoryCache.shared
        let previousSessions = PracticeSessionStore.shared.sessions
        let session = Self.session(id: UUID(), date: Date(timeIntervalSince1970: 4_500))
        cache.invalidate()
        defer {
            BaselineStore.shared.rebuild(from: previousSessions)
            cache.invalidate()
        }

        _ = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )
        BaselineStore.shared.rebuild(from: [])
        let rebuilt = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )

        #expect(rebuilt.cacheHit == false)
    }

    @Test @MainActor func ratingStoreMutationInvalidatesTrajectoryCacheForSameInputs() {
        let cache = UserTrajectoryCache.shared
        let previousRating = RatingStore.shared.rating
        let session = Self.session(id: UUID(), date: Date(timeIntervalSince1970: 4_750))
        cache.invalidate()
        defer {
            RatingStore.shared.replaceForDebug(previousRating)
            cache.invalidate()
        }

        _ = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )
        RatingStore.shared.recordRatedSession(
            score: 8,
            sessionId: UUID(),
            pressureLevel: .elevated
        )
        let rebuilt = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )

        #expect(rebuilt.cacheHit == false)
    }

    @Test func changedProfileVoiceMissesCacheWithoutManualInvalidation() {
        let cache = UserTrajectoryCache.shared
        cache.invalidate()
        let session = Self.session(id: UUID(), date: Date(timeIntervalSince1970: 5_000))

        _ = cache.snapshot(
            profile: Self.profile(voice: .concise),
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )
        let rebuilt = cache.snapshot(
            profile: Self.profile(voice: .authoritative),
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )

        #expect(rebuilt.cacheHit == false)
        cache.invalidate()
    }

    @Test func usableSingleRepRaisesCoverageWithoutClaimingOverallReadiness() {
        let cache = UserTrajectoryCache.shared
        cache.invalidate()
        let session = Self.session(id: UUID(), date: Date(timeIntervalSince1970: 6_000))

        let result = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [session],
            coachMemory: nil
        )

        #expect(result.snapshot.evidenceCoverage > 0.05)
        #expect(result.snapshot.evidenceCoverage < 0.43)
        cache.invalidate()
    }

    @Test @MainActor func practiceFinalizerPrewarmsCurrentStoreSnapshot() {
        let cache = UserTrajectoryCache.shared
        let sessionStore = PracticeSessionStore.shared
        let previousSessions = sessionStore.sessions
        let previousRating = RatingStore.shared.rating
        let previousMemory = CoachMemoryStore.shared.currentMemory

        sessionStore.replaceAllForDebug([])
        BaselineStore.shared.rebuild(from: [])
        RatingStore.shared.replaceForDebug(.initial)
        CoachMemoryStore.shared.replaceForTesting(nil)
        cache.invalidate()

        defer {
            sessionStore.replaceAllForDebug(previousSessions)
            BaselineStore.shared.rebuild(from: previousSessions)
            RatingStore.shared.replaceForDebug(previousRating)
            CoachMemoryStore.shared.replaceForTesting(previousMemory)
            cache.invalidate()
        }

        let finalized = PracticeSessionFinalizer.finalize(
            store: sessionStore,
            draft: PracticeSessionDraft(
                transcript: "The decision is to keep one owner, name the risk, and close with the next checkpoint.",
                fillerWordCount: 0,
                duration: 54,
                date: Date(timeIntervalSince1970: 7_000),
                mode: .timed,
                transcriptConfidence: 0.92,
                transcriptionProvider: "unit-test",
                pressureLevel: .elevated,
                isRated: true
            ),
            annotation: PracticeSessionAnnotation(
                score: 8,
                xpEarned: 100,
                headline: "Clear recommendation",
                insights: ["Named the decision before the supporting detail."],
                coachSummary: "The close was specific and calm."
            )
        )

        let currentStoreSnapshot = cache.snapshot(
            profile: CoachingProfileStore.shared.profile,
            baseline: BaselineStore.shared.baseline,
            rating: RatingStore.shared.rating,
            sessions: sessionStore.sessions,
            coachMemory: CoachMemoryStore.shared.currentMemory
        )

        #expect(currentStoreSnapshot.cacheHit == true)
        #expect(currentStoreSnapshot.snapshot.sessionCount == 1)
        #expect(currentStoreSnapshot.snapshot.latestRepEvidencePack?.score == 8)
        #expect(currentStoreSnapshot.snapshot.latestRepEvidencePack?.transcriptWordCount ?? 0 > 10)
        #expect(sessionStore.sessions.first?.id == finalized.id)
    }

    private static func session(
        id: UUID,
        date: Date,
        fillerWordCount: Int = 1,
        transcript: String = "We should make the decision now because the team needs a clear recommendation.",
        duration: TimeInterval = 60,
        score: Int? = 7,
        confidence: Double? = nil
    ) -> PracticeSession {
        var session = PracticeSession(
            transcript: transcript,
            fillerWordCount: fillerWordCount,
            duration: duration,
            date: date,
            mode: .timed,
            score: score,
            transcriptConfidence: confidence
        )
        session.id = id
        return session
    }

    private static func baseline(
        fillerRate: Double,
        pace: Double,
        hedgingRate: Double
    ) -> CommunicationBaseline {
        var baseline = CommunicationBaseline.empty
        baseline.sessionCount = 5
        baseline.qualifyingSessionCount = 5
        baseline.fillerRate = Self.stat(fillerRate)
        baseline.pace = Self.stat(pace)
        baseline.hedgingRate = Self.stat(hedgingRate)
        return baseline
    }

    private static func stat(_ value: Double) -> BaselineStat {
        BaselineStat(
            value: value,
            sampleCount: 5,
            confidence: .moderate,
            trend: .stable,
            percentile25: value,
            percentile75: value
        )
    }

    private static func profile(voice: SpeakingStyleGoal) -> CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: .moreConcise,
            confidenceLevel: .rebuilding,
            biggestChallenge: .rambling,
            desiredOutcome: .persuasive,
            speakingStyleGoal: voice,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: "",
            chosenStyleGoal: voice
        )
    }
}

@Suite("CoachAssessmentCacheTests", .serialized)
struct CoachAssessmentCacheTests {

    @Test func repeatedInputsReuseTypedAssessment() {
        let cache = CoachAssessmentCache()
        var buildCount = 0
        let trajectory = Self.trajectory()
        let rubric = ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative)

        let first = cache.assessment(
            turnDepth: .deepAssessment,
            userQuestion: "How far off am I from sounding authoritative?",
            trajectory: trajectory,
            rubric: rubric,
            surface: .text,
            recentProofTests: [],
            previousCoachReply: nil,
            build: {
                buildCount += 1
                return CoachReasoningPass.assess(
                    turnDepth: .deepAssessment,
                    userQuestion: "How far off am I from sounding authoritative?",
                    trajectory: trajectory,
                    rubric: rubric,
                    surface: .text
                )
            }
        )
        let second = cache.assessment(
            turnDepth: .deepAssessment,
            userQuestion: "How far off am I from sounding authoritative?",
            trajectory: trajectory,
            rubric: rubric,
            surface: .text,
            recentProofTests: [],
            previousCoachReply: nil,
            build: {
                buildCount += 1
                return CoachReasoningPass.assess(
                    turnDepth: .deepAssessment,
                    userQuestion: "How far off am I from sounding authoritative?",
                    trajectory: trajectory,
                    rubric: rubric,
                    surface: .text
                )
            }
        )

        #expect(first.cacheHit == false)
        #expect(second.cacheHit == true)
        #expect(buildCount == 1)
        #expect(second.assessment == first.assessment)
    }

    @Test func recentProofTestsChangeAssessmentSignature() {
        let cache = CoachAssessmentCache()
        var buildCount = 0
        let trajectory = Self.trajectory()
        let rubric = ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative)

        let first = cache.assessment(
            turnDepth: .quickMove,
            userQuestion: "How do I slow down without sounding unsure?",
            trajectory: trajectory,
            rubric: rubric,
            surface: .text,
            recentProofTests: [],
            previousCoachReply: nil,
            build: {
                buildCount += 1
                return CoachReasoningPass.assess(
                    turnDepth: .quickMove,
                    userQuestion: "How do I slow down without sounding unsure?",
                    trajectory: trajectory,
                    rubric: rubric,
                    surface: .text
                )
            }
        )
        let second = cache.assessment(
            turnDepth: .quickMove,
            userQuestion: "How do I slow down without sounding unsure?",
            trajectory: trajectory,
            rubric: rubric,
            surface: .text,
            recentProofTests: [first.assessment.nextProofTest],
            previousCoachReply: nil,
            build: {
                buildCount += 1
                return CoachReasoningPass.assess(
                    turnDepth: .quickMove,
                    userQuestion: "How do I slow down without sounding unsure?",
                    trajectory: trajectory,
                    rubric: rubric,
                    surface: .text,
                    recentProofTests: [first.assessment.nextProofTest]
                )
            }
        )

        #expect(second.cacheHit == false)
        #expect(buildCount == 2)
        #expect(second.assessment.nextProofTest != first.assessment.nextProofTest)
    }

    private static func trajectory() -> UserTrajectorySnapshot {
        UserTrajectorySnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            sessionCount: 2,
            ratedSessionCount: 1,
            evidenceCoverage: 0.36,
            recentSessionLines: [
                "Timed Practice: 7/10, 1 fillers, 60s",
                "Timed Practice: 6/10, 2 fillers, 55s"
            ],
            trendLines: ["recent filler average: 1.5 per rep across last 2"],
            latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Timed Practice",
                score: 7,
                fillerCount: 1,
                durationSeconds: 60,
                wordsPerMinute: 118,
                transcriptWordCount: 70,
                transcriptExcerpt: "I would recommend one owner for the decision because the team needs a clear next step",
                evidenceLines: ["latest rep: Timed Practice, 7/10, 1 fillers, 60s"]
            ),
            coachCaseSummary: CoachCaseSummary(
                hypothesis: "The recommendation is clear but the close softens.",
                focus: "clean close",
                evidenceSummary: "Recent reps open better than they close.",
                nextCoachMove: "test a decision-first close"
            ),
            activeInterventionState: nil
        )
    }
}

@Suite("CoachReasoningPassTests")
struct CoachReasoningPassTests {

    @Test func singleSevenOutOfTenDoesNotBecomeOverallCloseness() {
        let assessment = CoachReasoningPass.assess(
            turnDepth: .deepAssessment,
            userQuestion: "How far off am I from sounding authoritative?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )

        let verdict = assessment.directVerdict.lowercased()
        #expect(!verdict.contains("close"))
        #expect(!verdict.contains("not far off"))
        #expect(assessment.missingEvidence.contains { $0.lowercased().contains("repeated evidence") })
        #expect(assessment.nextProofTest.lowercased().contains("verdict") || assessment.nextProofTest.lowercased().contains("pressure"))
    }

    @Test func deepAssessmentImmediateReadIncludesMissingEvidenceAndNextCheck() {
        let assessment = CoachReasoningPass.assess(
            turnDepth: .deepAssessment,
            userQuestion: "Where do I stand overall?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .live
        )

        let read = assessment.immediateCoachRead.lowercased()
        #expect(!read.contains("read:"))
        #expect(!read.contains("signal:"))
        #expect(!read.contains("try this next:"))
        #expect(read.contains("the useful signal"))
        #expect(read.contains("what is still missing"))
        #expect(read.contains("for the next check"))
        #expect(!read.contains("proof test"))
        #expect(read.contains("pressure"))
    }

    @Test func quickMoveImmediateReadNamesLeverSignalAndTest() {
        let assessment = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "How do I slow down without sounding unsure?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .live
        )

        let read = assessment.immediateCoachRead.lowercased()
        #expect(read != assessment.nextProofTest.lowercased())
        #expect(!read.contains("read:"))
        #expect(!read.contains("signal:"))
        #expect(!read.contains("test:"))
        #expect(read.contains("pacing"))
        #expect(read.contains("the useful signal"))
        #expect(read.contains("one recent timed rep gives a usable sample"))
        #expect(!read.contains("timed, 7/10"))
        #expect(!read.contains("try this next:"))
        #expect(read.contains("pause") || read.contains("beat"))
    }

    @Test func quickLatencyCueDoesNotOverrideCleanCloseEvidence() {
        var trajectory = Self.singleRepTrajectory
        trajectory.latestRepEvidencePack = LatestRepEvidencePack(
            mode: "Timed",
            score: 7,
            fillerCount: 1,
            durationSeconds: 60,
            wordsPerMinute: 145,
            transcriptWordCount: 72,
            transcriptExcerpt: "My recommendation is to prioritize the launch because the team needs one decision this week so",
            evidenceLines: [
                "latest rep: Timed, 7/10, 1 fillers, 60s",
                "pace estimate: 145 WPM"
            ]
        )

        let assessment = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "Quickly, what do I do next?",
            trajectory: trajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )

        let verdict = assessment.directVerdict.lowercased()
        let proof = assessment.nextProofTest.lowercased()
        #expect(verdict.contains("ending"))
        #expect(!verdict.contains("pacing"))
        #expect(proof.contains("final sentence") || proof.contains("ask"))
    }

    @Test func deepAssessmentCarriesCaseSummaryAndInterventionEvidence() {
        var trajectory = Self.singleRepTrajectory
        trajectory.evidenceCoverage = 0.64
        trajectory.coachCaseSummary = CoachCaseSummary(
            hypothesis: "The recommendation is clear but the close softens.",
            focus: "clean close",
            evidenceSummary: "Recent reps open better than they close.",
            nextCoachMove: "review whether the close held under pressure"
        )
        trajectory.activeInterventionState = ActiveInterventionState(
            title: "Clean close reps",
            target: "End on the ask without an extra caveat.",
            followedRepCount: 2,
            reviewStatus: "review due"
        )

        let assessment = CoachReasoningPass.assess(
            turnDepth: .deepAssessment,
            userQuestion: "Where do I stand overall?",
            trajectory: trajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )
        let evidence = assessment.evidenceUsed.joined(separator: "\n").lowercased()
        let prompt = CoachPromptBundle.contextBlock(
            assessment: assessment,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        ).lowercased()

        #expect(evidence.contains("case summary:"))
        #expect(evidence.contains("recommendation is clear"))
        #expect(evidence.contains("review whether the close held under pressure"))
        #expect(evidence.contains("active intervention:"))
        #expect(evidence.contains("clean close reps"))
        #expect(evidence.contains("followed reps: 2"))
        #expect(prompt.contains("case summary:"))
        #expect(prompt.contains("active intervention:"))
    }

    @Test func proofTestFollowsUserNamedPacingLever() {
        let assessment = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "How do I slow down without sounding unsure?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )

        let proof = assessment.nextProofTest.lowercased()
        #expect(proof.contains("silent beat"))
        #expect(!proof.contains("pressure mode"))
    }

    @Test func proofTestFollowsUserNamedClosingLever() {
        let assessment = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "How do I make the ending stronger?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )

        let proof = assessment.nextProofTest.lowercased()
        #expect(proof.contains("exact decision") || proof.contains("ask"))
        #expect(proof.contains("stop"))
    }

    @Test func proofTestRoutesArenaIntentQuestionsBeyondOneDefaultDimension() {
        let questions = [
            "I have a difficult conversation tonight. What should I practice?",
            "The room seemed engaged. Did the drill cause that?",
            "Do I lack conviction?",
            "My presentation sounds polished but flat. What is missing?",
            "I ramble when introducing myself at networking events.",
            "You counted 'like' but I meant it as a comparison."
        ]

        let proofs = questions.map { question in
            CoachReasoningPass.assess(
                turnDepth: .quickMove,
                userQuestion: question,
                trajectory: Self.singleRepTrajectory,
                rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
                surface: .text
            ).nextProofTest
        }
        let proofKeys = Set(proofs.map { CoachReplyPipeline.proofTestHash(for: $0) })

        #expect(proofKeys.count >= 5)
        #expect(proofs[0].lowercased().contains("verdict") || proofs[0].lowercased().contains("sentence one"))
        #expect(proofs[1].lowercased().contains("pressure") || proofs[1].lowercased().contains("timer"))
        #expect(proofs[2].lowercased().contains("maybe") || proofs[2].lowercased().contains("hedge"))
        #expect(proofs[3].lowercased().contains("beat") || proofs[3].lowercased().contains("speed"))
        #expect(proofs[4].lowercased().contains("memorable") || proofs[4].lowercased().contains("example"))
        #expect(proofs[5].lowercased().contains("maybe") || proofs[5].lowercased().contains("hedge"))
    }

    @Test func proofTestsStayCaseSpecificAcrossRepresentativeArenaTurns() {
        let turns: [(CoachTurnDepth, String)] = [
            (.deepAssessment, "How far off am I from sounding authoritative overall?"),
            (.trustRepair, "That was too much writing and it missed the point."),
            (.groundedRead, "Can you give me examples from my sessions?"),
            (.quickMove, "I have an interview tomorrow. What should I practice?"),
            (.quickMove, "My leadership update is tomorrow."),
            (.quickMove, "I have a difficult conversation tonight and need to disagree."),
            (.quickMove, "I ramble when introducing myself at networking events."),
            (.quickMove, "My sales pitch loses the customer."),
            (.quickMove, "I panic and blank when I get interrupted."),
            (.groundedRead, "You counted 'like' but I meant it as a comparison."),
            (.quickMove, "My filler words spike under pressure."),
            (.quickMove, "I overexplain before I get to the ask."),
            (.groundedRead, "The room seemed engaged. Did the drill cause that?")
        ]
        var recentProofTests: [String] = []
        var proofs: [String] = []

        for (depth, question) in turns {
            let assessment = CoachReasoningPass.assess(
                turnDepth: depth,
                userQuestion: question,
                trajectory: Self.singleRepTrajectory,
                rubric: ActiveGoalRubric(
                    rubric: GoalRubricStore.rubric(for: .authoritative),
                    voice: .authoritative
                ),
                surface: .text,
                recentProofTests: recentProofTests
            )
            proofs.append(assessment.nextProofTest)
            recentProofTests = Array(([assessment.nextProofTest] + recentProofTests).prefix(6))
        }

        let proofKeys = proofs.map { CoachReplyPipeline.proofTestHash(for: $0) }
        let counts = Dictionary(grouping: proofKeys, by: { $0 }).mapValues(\.count)
        let lowerProofs = proofs.map { $0.lowercased() }

        #expect(Set(proofKeys).count >= 11)
        #expect((counts.values.max() ?? 0) <= 2)
        #expect(lowerProofs.contains { $0.contains("stakes-style pressure proof") })
        #expect(lowerProofs.contains { $0.contains("verified session example") })
        #expect(lowerProofs.contains { $0.contains("field note") })
        #expect(lowerProofs.contains { $0.contains("memorable detail") })
        #expect(lowerProofs.contains { $0.contains("keep the word only if it adds meaning") })
    }

    @Test func quickMoveVerdictVariesWithUserNamedLever() {
        let pacing = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "How do I slow down without sounding unsure?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )
        let ending = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "How do I make the ending stronger?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )

        #expect(pacing.directVerdict != ending.directVerdict)
        #expect(pacing.directVerdict.lowercased().contains("pacing"))
        #expect(ending.directVerdict.lowercased().contains("ending"))
        #expect(!pacing.directVerdict.lowercased().contains("overall"))
        #expect(!ending.directVerdict.lowercased().contains("overall"))
    }

    @Test func genericQuickMoveVerdictUsesActiveInterventionBeforeTemplate() {
        var trajectory = Self.singleRepTrajectory
        trajectory.activeInterventionState = ActiveInterventionState(
            title: "Clean close reps",
            target: "End on the ask without an extra caveat.",
            followedRepCount: 2,
            reviewStatus: "review due"
        )

        let assessment = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "What should I do next?",
            trajectory: trajectory,
            rubric: Self.openEndedRubric,
            surface: .text
        )

        let verdict = assessment.directVerdict.lowercased()
        #expect(verdict.contains("active intervention"))
        #expect(verdict.contains("end on the ask without an extra caveat"))
        #expect(!verdict.contains("test one observable change"))
    }

    @Test func genericQuickMoveVerdictUsesCaseNextMoveWhenInterventionIsAbsent() {
        var trajectory = Self.singleRepTrajectory
        trajectory.coachCaseSummary = CoachCaseSummary(
            hypothesis: "The recommendation is clear but the close softens.",
            focus: "clean close",
            evidenceSummary: "Recent reps open better than they close.",
            nextCoachMove: "review whether the close held under pressure"
        )

        let assessment = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "What should I do next?",
            trajectory: trajectory,
            rubric: Self.openEndedRubric,
            surface: .text
        )

        let verdict = assessment.directVerdict.lowercased()
        #expect(verdict.contains("case file"))
        #expect(verdict.contains("review whether the close held under pressure"))
        #expect(!verdict.contains("test one observable change"))
    }

    @Test func repeatedProofTestVariesWithinUserNamedLever() {
        let first = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "How do I slow down without sounding unsure?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )
        let second = CoachReasoningPass.assess(
            turnDepth: .quickMove,
            userQuestion: "How do I slow down without sounding unsure?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text,
            recentProofTests: [first.nextProofTest]
        )

        #expect(second.nextProofTest != first.nextProofTest)
        #expect(second.nextProofTest.lowercased().contains("pause") || second.nextProofTest.lowercased().contains("beat"))
    }

    @Test func trustRepairAssessmentNamesColdFrictionBeforePrescribing() {
        let assessment = CoachReasoningPass.assess(
            turnDepth: .trustRepair,
            userQuestion: "This still feels robotic and cold, like generic AI tips.",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text,
            previousCoachReply: "Keep practicing and try to communicate clearly."
        )

        #expect(assessment.toneMode == .repair)
        #expect(assessment.repairFocus == "I sounded cold instead of giving a human coach read")
        #expect(assessment.evidenceUsed.first == "trust repair signal: I sounded cold instead of giving a human coach read")
        #expect(assessment.immediateCoachRead.lowercased().hasPrefix("fair push. i sounded cold"))
        #expect(!assessment.immediateCoachRead.lowercased().contains("the useful repair is"))
    }

    @Test func trustRepairProofTestsFollowProductVoiceFailureMode() {
        let format = CoachReasoningPass.assess(
            turnDepth: .trustRepair,
            userQuestion: "The ** don't format and TTS reads them out. The responses feel robotic and cold.",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text,
            previousCoachReply: "**Read:** Your metrics suggest improvement. **Move:** Practice."
        )
        let generic = CoachReasoningPass.assess(
            turnDepth: .trustRepair,
            userQuestion: "This feels like a generic AI wrapper.",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text,
            previousCoachReply: "Here are some tips: be confident, speak clearly, and practice."
        )
        let cold = CoachReasoningPass.assess(
            turnDepth: .trustRepair,
            userQuestion: "This sounds cold and robotic.",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text,
            previousCoachReply: "Be clear, confident, and concise."
        )
        let proofHashes = Set([format, generic, cold].map { CoachReplyPipeline.proofTestHash(for: $0.nextProofTest) })

        #expect(proofHashes.count == 3)
        #expect(format.nextProofTest.lowercased().contains("plain speech"))
        #expect(generic.nextProofTest.lowercased().contains("user-specific signal"))
        #expect(cold.nextProofTest.lowercased().contains("human acknowledgement"))
    }

    @Test func trustRepairAssessmentNamesTerseFrictionBeforePrescribing() {
        let repeated = CoachReasoningPass.assess(
            turnDepth: .trustRepair,
            userQuestion: "You're repeating yourself.",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text,
            previousCoachReply: "Run the same 60-second proof test."
        )
        let hard = CoachReasoningPass.assess(
            turnDepth: .trustRepair,
            userQuestion: "It's not easy.",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text,
            previousCoachReply: "Just pause before the close."
        )
        let notInformative = CoachReasoningPass.assess(
            turnDepth: .trustRepair,
            userQuestion: "That's not informative at all.",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text,
            previousCoachReply: "Try to communicate more clearly."
        )

        #expect(repeated.repairFocus == "I repeated the same coaching move instead of advancing the read")
        #expect(repeated.evidenceUsed.first == "trust repair signal: I repeated the same coaching move instead of advancing the read")
        #expect(repeated.nextProofTest.contains("Advance the read"))
        #expect(!repeated.nextProofTest.contains("Repair this turn first"))
        #expect(!repeated.immediateCoachRead.contains("Proof test:"))
        #expect(hard.repairFocus == "I made the move sound easier than it feels under pressure")
        #expect(hard.evidenceUsed.first == "trust repair signal: I made the move sound easier than it feels under pressure")
        #expect(notInformative.repairFocus == "I missed the actual question before prescribing")
        #expect(notInformative.nextProofTest.contains("Answer the actual question in sentence one"))
        #expect(!notInformative.nextProofTest.contains("Repair this turn first"))
        #expect(!notInformative.immediateCoachRead.contains("Proof test:"))
    }

    @Test func promptBundleCarriesRepairFocusAsProviderConstraint() {
        let assessment = CoachReasoningPass.assess(
            turnDepth: .trustRepair,
            userQuestion: "Okay, that's cool. However, that still feels generic.",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text,
            previousCoachReply: "Keep practicing and try to communicate clearly."
        )

        let context = CoachPromptBundle.contextBlock(
            assessment: assessment,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )

        #expect(context.contains("- Tone mode: repair."))
        #expect(context.contains("- Repair focus:"))
        #expect(context.contains("Acknowledge this before prescribing again."))
        #expect(context.contains("Do not give another drill until the repair focus has been named."))
        #expect(context.contains("Evidence to use (translate into spoken behavior"))
        #expect(context.contains("Final action to express as a normal sentence"))
        #expect(context.contains("Do not use colon-led coaching labels"))
    }

    @Test func assessmentConfidenceMovesWithEvidenceCoverage() {
        var lowCoverage = Self.singleRepTrajectory
        lowCoverage.evidenceCoverage = 0.05
        var higherCoverage = Self.singleRepTrajectory
        higherCoverage.sessionCount = 8
        higherCoverage.ratedSessionCount = 5
        higherCoverage.evidenceCoverage = 0.76

        let low = CoachReasoningPass.assess(
            turnDepth: .deepAssessment,
            userQuestion: "How far off am I from sounding authoritative?",
            trajectory: lowCoverage,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )
        let higher = CoachReasoningPass.assess(
            turnDepth: .deepAssessment,
            userQuestion: "How far off am I from sounding authoritative?",
            trajectory: higherCoverage,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .text
        )

        #expect(low.confidence == 0.20)
        #expect(higher.confidence > low.confidence + 0.30)
        #expect(higher.confidence <= 0.82)
    }

    @Test func memoryHandoffAssessmentStaysConsentBoundToConversationHypothesis() {
        let assessment = CoachReasoningPass.assess(
            turnDepth: .groundedRead,
            userQuestion: "What should Noum remember?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .executive),
            surface: .text,
            previousCoachReply: "Then reject that hypothesis and keep the observable read: the disagreement arrived after too much setup. Run the same answer disagreement-first and compare whether the listener gets the point sooner."
        )

        #expect(assessment.directVerdict.contains("testable hypothesis only"))
        #expect(assessment.directVerdict.contains("disagreement may be getting softened by setup"))
        #expect(assessment.nextProofTest == "Keep it if two pressure reps show the point arrives late; drop it if verdict-first solves it.")
        #expect(assessment.evidenceUsed.first == "conversation hypothesis: disagreement may be getting softened by setup")
        #expect(assessment.immediateCoachRead.lowercased().contains("testable hypothesis only"))
        #expect(assessment.immediateCoachRead.lowercased().contains("drop it if verdict-first solves it"))
        #expect(!assessment.immediateCoachRead.lowercased().contains("no maybe"))
    }

    private static let openEndedRubric = ActiveGoalRubric(
        rubric: GoalRubric(
            goalID: "presence",
            displayName: "Presence",
            dimensions: [
                RubricDimension(
                    id: "presence_continuity",
                    label: "Presence continuity",
                    description: "Keeps the current coaching thread coherent before adding a new tactic.",
                    proofSignals: ["same target repeated", "case next move used"],
                    proofTest: "Run one answer using the same target and compare the close.",
                    missingIfAbsent: "Need one targeted rep against the active coaching thread."
                )
            ],
            defaultWeights: ["presence_continuity": 1.0]
        ),
        voice: .authoritative
    )

    private static let singleRepTrajectory = UserTrajectorySnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_000),
        sessionCount: 1,
        ratedSessionCount: 1,
        evidenceCoverage: 0.24,
        recentSessionLines: [
            "Timed: 7/10, 1 fillers, 60s"
        ],
        trendLines: [],
        latestRepEvidencePack: LatestRepEvidencePack(
            mode: "Timed",
            score: 7,
            fillerCount: 1,
            durationSeconds: 60,
            wordsPerMinute: 145,
            transcriptWordCount: 64,
            transcriptExcerpt: "My recommendation is to prioritize the launch because the team needs one decision this week",
            evidenceLines: [
                "latest rep: Timed, 7/10, 1 fillers, 60s",
                "pace estimate: 145 WPM"
            ]
        ),
        coachCaseSummary: nil,
        activeInterventionState: nil
    )
}

@Suite("CoachSemanticQualityGateTests")
struct CoachSemanticQualityGateTests {

    @Test func deepAssessmentRejectsScoreOnlyTip() {
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You scored 7/10, so use fewer fillers next time. Record one more rep.",
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment
        )

        #expect(issue != nil)
    }

    @Test func deepAssessmentAcceptsCalibratedVerdict() {
        let reply = """
        You are closer mechanically than you are to sounding authoritative overall. Mechanics: your latest rep was 7/10 with 1 filler, and the pace estimate was 145 WPM; goal readiness still needs pressure evidence. Missing: repeated reps under stakes. Proof test: record a 75-second answer with the verdict in sentence one, one reason, and a clean stop.
        """

        let issue = AICoachChatService.semanticQualityIssue(
            in: reply,
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment
        )

        #expect(issue == nil)
    }

    @Test func unsupportedOverallClosenessFailsWhenCoverageIsThin() {
        var assessment = Self.deepAssessment
        assessment.confidence = 0.42
        assessment.evidenceUsed = []

        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are close overall. Mechanics and goal readiness look aligned from the score. Missing evidence: pressure reps. Proof test: record a 75-second verdict-first answer.",
            turnDepth: .deepAssessment,
            assessment: assessment
        )

        #expect(issue == .unsupportedClosenessClaim)
    }

    @Test func exampleRequestFailsWhenReplySkipsExample() {
        let issue = AICoachChatService.semanticQualityIssue(
            in: "The move is verdict-first: answer first, give one reason, then stop.",
            latestUserTurn: "Can you give me an example of me doing this in sessions?",
            turnDepth: .quickMove,
            assessment: Self.quickAssessment
        )

        #expect(issue == .missingIntentFit)
    }

    @Test func exampleRequestPassesWhenReplyGivesConcreteSessionExample() {
        let issue = AICoachChatService.semanticQualityIssue(
            in: "In your vendor rep, you said implementation risk was lower and the team already knew the workflow. That is the pattern: reasons before the picture, so add one concrete example after the first reason.",
            latestUserTurn: "Can you give me an example of me doing this in sessions?",
            turnDepth: .quickMove,
            assessment: Self.quickAssessment
        )

        #expect(issue == nil)
    }

    @Test func sessionExampleRequestWithVerifiedProofRejectsNonQuotingReply() {
        let turn = "Can you give me an example of me doing this in sessions?"
        let quoteGuard = CoachChatQuoteGuardContext(
            verifiedProofQuotes: ["we focused on three priorities"],
            latestUserTurn: turn
        )

        let issue = AICoachChatService.replyQualityIssue(
            in: "A safe example is the latest rep: the reasons were clear, but there was no concrete scene for the listener to picture. Next rep, add one example after the first reason.",
            latestUserTurn: turn,
            quoteGuard: quoteGuard,
            turnDepth: .quickMove
        )

        #expect(issue == .missingVerifiedExampleQuote)
    }

    @Test func sessionExampleRequestWithVerifiedProofAcceptsQuotedExample() {
        let turn = "Can you give me an example of me doing this in sessions?"
        let quoteGuard = CoachChatQuoteGuardContext(
            verifiedProofQuotes: ["we focused on three priorities"],
            latestUserTurn: turn
        )

        let issue = AICoachChatService.replyQualityIssue(
            in: "One example is the rep where you said 'we focused on three priorities.' The reasons were clear, but the listener had no scene to picture, so add one concrete example after the first reason next time.",
            latestUserTurn: turn,
            quoteGuard: quoteGuard,
            turnDepth: .quickMove
        )

        #expect(issue == nil)
    }

    @Test func transferCausalityFailsEvenWithoutTypedAssessment() {
        let context = """
        REAL-WORLD TRANSFER
        - For presentation "Leadership update", the user reported it went well; the audience or counterpart seemed engaged. On their rehearsal, they felt their rehearsal carried into the moment.
        - These are the user's reported outcome and read of the room, not objective evidence or proof that training caused the result.
        """

        let issue = AICoachChatService.semanticQualityIssue(
            in: "That proves the 75-second close drill caused the room to engage. The audience response is objective proof that training transferred.",
            latestUserTurn: "What should I capture now?",
            systemContext: context,
            turnDepth: .quickMove,
            assessment: nil
        )

        #expect(issue == .unsupportedTransferCausalityClaim)
    }

    @Test func transferSelfReportLanguagePassesSemanticGate() {
        let context = """
        REAL-WORLD TRANSFER
        - For presentation "Leadership update", the user reported it went well; the audience or counterpart seemed engaged. On their rehearsal, they felt their rehearsal carried into the moment.
        - These are the user's reported outcome and read of the room, not objective evidence or proof that training caused the result.
        """

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Capture it as your room read, not proof: people asked about timeline, so next prep should add one date before the final ask.",
            latestUserTurn: "What should I capture now?",
            systemContext: context,
            turnDepth: .quickMove,
            assessment: nil
        )

        #expect(issue == nil)
    }

    @Test func briefTacticalMoveCanClearRetrievedExpertiseGate() {
        let context = """
        COACHING EXPERTISE
        - Progress can wobble when the close softens after the ask.
        - Conflict coaching should name the point early, then stop.
        """

        let issue = AICoachChatService.replyQualityIssue(
            in: "The close is the lever, so make the final sentence the ask, then stop.",
            latestUserTurn: "Quickly, what do I do next?",
            systemContext: context,
            turnDepth: .quickMove
        )

        #expect(issue == nil)
    }

    @Test func briefRecordingMoveCanClearRetrievedExpertiseGate() {
        let context = """
        COACHING EXPERTISE
        - Answer depth improves when the same recommendation keeps one claim, one reason, and one example.
        - The drill should isolate answer depth rather than adding a second thread.
        """

        let issue = AICoachChatService.replyQualityIssue(
            in: "Record the same executive recommendation in 60 seconds because it isolates answer depth. Sentence one is the claim, sentence two is one reason, sentence three is one example, then stop.",
            latestUserTurn: "What should I record?",
            systemContext: context,
            turnDepth: .quickMove
        )

        #expect(issue == nil)
    }

    @Test func briefFollowupMoveCanClearRetrievedExpertiseGate() {
        let context = """
        COACHING EXPERTISE
        - Order is the useful read when warmth arrives before the recommendation.
        - The next rep should isolate order without removing reassurance.
        """

        let issue = AICoachChatService.replyQualityIssue(
            in: "Run one 45-second client concern answer because it isolates order. Sentence one is the recommendation; sentence two is one reassurance; then stop.",
            latestUserTurn: "What should I do with that?",
            systemContext: context,
            turnDepth: .quickMove
        )

        #expect(issue == nil)
    }

    @Test func briefTacticalMoveExceptionRequiresConcreteAnchor() {
        let context = """
        COACHING EXPERTISE
        - Order is the useful read when warmth arrives before the recommendation.
        """

        let issue = AICoachChatService.replyQualityIssue(
            in: "Practice once because it will help. Then stop.",
            latestUserTurn: "What should I do with that?",
            systemContext: context,
            turnDepth: .quickMove
        )

        #expect(issue != nil)
    }

    @Test func unconfirmedPersonalPatternLabelFailsProfessionalGate() {
        let issue = AICoachChatService.replyQualityIssue(
            in: "You are defensive because you fear disagreement. Run a 60-second rep with the disagreement first, then one reason.",
            latestUserTurn: "Do I sound defensive when I disagree?",
            turnDepth: .groundedRead
        )

        #expect(issue == .overclaimsEvidence)
    }

    @Test func confirmablePersonalPatternHypothesisClearsProfessionalGate() {
        let reply = "From the transcript, I would treat defensiveness as a hypothesis, not a label: you softened the disagreement and added context before the point. Check whether that fits; next rep, say the disagreement in sentence one, give one reason, then stop."

        let issue = AICoachChatService.replyQualityIssue(
            in: reply,
            latestUserTurn: "Do I sound defensive when I disagree?",
            systemContext: "RECENT (most-recent first)\n- Transcript: I softened the disagreement and added context before the point.",
            turnDepth: .groundedRead
        )

        #expect(issue == nil)
    }

    @Test func memoryHandoffHypothesisClearsProfessionalAndSemanticGates() {
        let reply = "Use this memory as a testable hypothesis only: disagreement may be getting softened by setup. Keep it if two pressure reps show the point arrives late; drop it if verdict-first solves it."
        let previousCoachReply = "Then reject that hypothesis and keep the observable read: the disagreement arrived after too much setup. Run the same answer disagreement-first and compare whether the listener gets the point sooner."
        let assessment = CoachReasoningPass.assess(
            turnDepth: .groundedRead,
            userQuestion: "What should Noum remember?",
            trajectory: Self.memoryHandoffTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .executive),
            surface: .text,
            previousCoachReply: previousCoachReply
        )

        let qualityIssue = AICoachChatService.replyQualityIssue(
            in: reply,
            latestUserTurn: "What should Noum remember?",
            systemContext: "RECENT (most-recent first)\n- Transcript: I disagree with the direction, but I understand the concern, and maybe we can keep exploring options before I say no.",
            recentCoachReplies: [previousCoachReply],
            turnDepth: .groundedRead
        )
        let semanticIssue = AICoachChatService.semanticQualityIssue(
            in: reply,
            latestUserTurn: "What should Noum remember?",
            turnDepth: .groundedRead,
            assessment: assessment
        )

        #expect(qualityIssue == nil)
        #expect(semanticIssue == nil)
    }

    @Test func observableStructureReadDoesNotTripPersonalPatternGate() {
        let issue = AICoachChatService.replyQualityIssue(
            in: "From the transcript, the disagreement arrived after too much setup, so run the same answer once with the disagreement in sentence one.",
            latestUserTurn: "Do I sound defensive when I disagree?",
            systemContext: "RECENT (most-recent first)\n- Transcript: I softened the disagreement and added context before the point.",
            turnDepth: .groundedRead
        )

        #expect(issue == nil)
    }

    private static let memoryHandoffTrajectory = UserTrajectorySnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_000),
        sessionCount: 1,
        ratedSessionCount: 1,
        evidenceCoverage: 0.24,
        recentSessionLines: [
            "Timed: 6/10, 1 fillers, 63s"
        ],
        trendLines: [],
        latestRepEvidencePack: LatestRepEvidencePack(
            mode: "Timed",
            score: 6,
            fillerCount: 1,
            durationSeconds: 63,
            wordsPerMinute: 132,
            transcriptWordCount: 16,
            transcriptExcerpt: "I disagree with the direction, but I understand the concern before I say no",
            evidenceLines: [
                "latest rep: Timed, 6/10, 1 fillers, 63s"
            ]
        ),
        coachCaseSummary: nil,
        activeInterventionState: nil
    )

    private static let quickAssessment = CoachAssessment(
        turnDepth: .quickMove,
        surface: .text,
        questionRestatement: "Can you give me an example of me doing this in sessions?",
        directVerdict: "Use one concrete example from the latest session before prescribing the next rep.",
        confidence: 0.68,
        evidenceUsed: [
            "vendor rep: reasons appeared before the concrete example"
        ],
        rubricScores: [],
        missingEvidence: [],
        nextProofTest: "Record a 45-second answer with one recommendation, one reason, and one concrete example.",
        responseMode: .immediateOnly
    )

    private static let deepAssessment = CoachAssessment(
        turnDepth: .deepAssessment,
        surface: .text,
        questionRestatement: "How far off am I from sounding authoritative?",
        directVerdict: "You are closer mechanically than you are to fully sounding authoritative.",
        confidence: 0.62,
        evidenceUsed: [
            "latest rep: Timed, 7/10, 1 fillers, 60s",
            "pace estimate: 145 WPM"
        ],
        rubricScores: [],
        missingEvidence: [
            "Need repeated evidence across more than one clean rep before calling the user close overall.",
            "Need pressure-mode evidence before treating the goal as ready for real stakes."
        ],
        nextProofTest: "Record a 75-second answer where sentence one gives the verdict, sentence two gives one reason, and the final sentence names the ask.",
        responseMode: .expandable
    )
}

@Suite("CoachSemanticQualityGateAdversarialTests")
struct CoachSemanticQualityGateAdversarialTests {

    // MARK: Deep-assessment gate ordering
    //
    // semanticQualityIssue runs six ordered checks for .deepAssessment:
    //   1 missingDirectVerdict        (reply must open with the verdict)
    //   2 missingMechanicsGoalDistinction
    //   3 insufficientEvidenceReferences (only when evidenceReferenceCount >= 2)
    //   4 missingEvidenceDisclosure   (only when confidence < 0.78)
    //   5 unsupportedClosenessClaim   (only when confidence < 0.70)
    //   6 missingProofTest
    // Each fixture below makes every EARLIER check pass so the targeted check is
    // the one that fires, guarding against silent reordering or threshold drift.

    @Test func verdictBuriedAfterPreambleFailsAsMissingVerdict() {
        // Opens with a preamble, not the verdict -> check 1.
        let issue = AICoachChatService.semanticQualityIssue(
            in: "Let me walk through the evidence first. Your latest rep was 7/10 at a 145 WPM pace. You are closer mechanically than authoritative overall. Missing: pressure reps. Proof test: record one verdict-first rep.",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        )
        #expect(issue == .missingDirectVerdict)
    }

    @Test func abbreviatedContractedVerdictFirstIsAccepted() {
        // "You're not there..." is a valid verdict opener; full reply passes.
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You're not there on authority yet, though your mechanics are landing. Your latest rep was 7/10 at a 145 WPM pace; goal readiness under pressure is unproven. Still need repeated reps. Proof test: record one verdict-first rep.",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        )
        #expect(issue == nil)
    }

    @Test func boundedYesNoJudgementOpenersAreAccepted() {
        let issue = AICoachChatService.semanticQualityIssue(
            in: "Yes, it could, but keep it as a structure read, not a claim about you. The latest rep and pace estimate support answer-after-setup: mechanics are usable, but the goal is not proven under pressure. Missing: repeated pressure proof and a listener read. Proof test: put the direct answer in sentence one, then use one polished reason after it.",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        )

        #expect(issue == nil)
    }

    @Test func evidenceBoundaryJudgementOpenersAreAccepted() {
        let issue = AICoachChatService.semanticQualityIssue(
            in: "I cannot prove timid from text alone. The latest rep and pace estimate only support a mechanics signal: indirectness before the recommendation, so the authority goal still needs audio evidence. Missing: tone and prosody. Proof test: try one direct recommendation first; audio would be needed for a tone verdict.",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        )

        #expect(issue == nil)
    }

    @Test func mechanicsWithoutGoalLanguageFailsDistinction() {
        // Verdict-first and mechanics-laden but no goal-readiness language -> check 2.
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are closer on mechanics than before. Your latest rep was 7/10 with a 145 WPM pace and one filler. Record one more rep.",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        )
        #expect(issue == .missingMechanicsGoalDistinction)
    }

    @Test func noEvidenceTouchesFailsAsInsufficientReferences() {
        // Passes verdict + distinction but cites none of the assessment's evidence
        // while evidenceReferenceCount >= 2 -> check 3.
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are closer mechanically than to full authority overall, but goal readiness is unproven. The score alone does not settle it. Missing: pressure reps. Proof test: try one more rep.",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        )
        #expect(issue == .insufficientEvidenceReferences)
    }

    @Test func deepAssessmentWithCaseEvidenceFailsWhenReplyIgnoresCaseAnchor() {
        // Passes verdict + mechanics/goal + ordinary evidence-count checks, but
        // drops the current case hypothesis and active intervention.
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are closer mechanically than authoritatively overall. Your latest rep was 7/10 and the pace estimate was 145 WPM; goal readiness under pressure is unproven. Still need repeated reps. Proof test: record one verdict-first rep.",
            turnDepth: .deepAssessment,
            assessment: Self.caseAnchoredDeep
        )

        #expect(issue == .missingCaseAnchor)
    }

    @Test func deepAssessmentCaseAnchorIsNotSatisfiedByGenericCleanCloseLanguage() {
        // The case evidence names a clean-close intervention, but a reply that
        // only repeats generic proof-test words has not used the actual case.
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are closer mechanically than authoritatively overall. Your latest rep was 7/10 and the pace estimate was 145 WPM; goal readiness under pressure is unproven. Still need repeated reps. Proof test: record one clean-close answer with the final sentence as the ask.",
            turnDepth: .deepAssessment,
            assessment: Self.caseAnchoredDeep
        )

        #expect(issue == .missingCaseAnchor)
    }

    @Test func deepAssessmentWithCaseEvidencePassesWhenReplyUsesCaseAnchor() {
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are closer mechanically than authoritatively overall, but the current case read is still the clean close: the close softens after the recommendation. Your latest rep was 7/10 and the pace estimate was 145 WPM; goal readiness under pressure is unproven. Still need repeated reps. Proof test: record one verdict-first rep.",
            turnDepth: .deepAssessment,
            assessment: Self.caseAnchoredDeep
        )

        #expect(issue == nil)
    }

    @Test func unnamedMissingEvidenceFailsDisclosureWhenConfidenceThin() {
        // Verdict + distinction + 2 evidence touches but never names missing
        // evidence, at confidence 0.62 (< 0.78) -> check 4.
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are closer mechanically than authoritatively overall. Your latest rep was 7/10 at a 145 WPM pace, so the mechanics are landing while goal readiness is unproven. Proof test: record one verdict-first rep.",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        )
        #expect(issue == .missingEvidenceDisclosure)
    }

    @Test func unqualifiedClosenessFailsWhenConfidenceBelowSeventy() {
        // Confidence 0.62 (< 0.70) + unqualified "close overall" -> check 5.
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You're close overall and basically there. Your latest rep was 7/10 at a 145 WPM pace; mechanics and goal readiness look aligned. Still need pressure reps. Proof test: record one rep.",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        )
        #expect(issue == .unsupportedClosenessClaim)
    }

    @Test func closenessQualifiedToMechanicsIsNotRejected() {
        // The over-rejection guard: "close on mechanics only, not overall yet" is
        // a fair, bounded claim and must pass even below 0.70 confidence.
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are close on mechanics only, but not overall yet. Your latest rep was 7/10 at a 145 WPM pace; goal readiness under pressure is unproven. Missing: repeated reps. Proof test: record one verdict-first rep.",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        )
        #expect(issue == nil)
    }

    @Test func missingProofTestFailsLastWhenEverythingElsePasses() {
        // Passes checks 1-5 but offers no proof test -> check 6.
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are closer mechanically than authoritatively overall. Your latest rep was 7/10 at a 145 WPM pace; goal readiness under pressure is unproven. Missing: repeated reps under stakes.",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        )
        #expect(issue == .missingProofTest)
    }

    // MARK: Confidence-threshold guards against over-rejection

    @Test func highConfidenceNeedNotDiscloseMissingEvidence() {
        // At confidence 0.80 (>= 0.78) the disclosure gate (check 4) eases.
        var assessment = Self.baseDeep
        assessment.confidence = 0.80
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are authoritative overall now, and the mechanics back it. Your latest rep was 7/10 at a 145 WPM pace. Proof test: record one verdict-first rep.",
            turnDepth: .deepAssessment,
            assessment: assessment
        )
        #expect(issue == nil)
    }

    @Test func midConfidenceAllowsUnqualifiedClosenessClaim() {
        // At confidence 0.72 (>= 0.70) the closeness gate (check 5) does not fire,
        // as long as the thinner disclosure gate (check 4) is satisfied.
        var assessment = Self.baseDeep
        assessment.confidence = 0.72
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You are close overall. Your latest rep was 7/10 at a 145 WPM pace; mechanics look right. Still need pressure reps. Proof test: record one rep.",
            turnDepth: .deepAssessment,
            assessment: assessment
        )
        #expect(issue == nil)
    }

    // MARK: Trust-repair gate

    @Test func trustRepairWithoutAcknowledgementFailsAsMissingVerdict() {
        let issue = AICoachChatService.semanticQualityIssue(
            in: "Your latest rep was solid and the pace was good. Keep recording reps.",
            turnDepth: .trustRepair,
            assessment: Self.baseDeep
        )
        #expect(issue == .missingDirectVerdict)
    }

    @Test func trustRepairAcknowledgingTheMissIsAccepted() {
        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — that read was too generic. I'll cut the filler framing. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: Self.baseDeep
        )
        #expect(issue == nil)
    }

    @Test func trustRepairMustNameAssessmentRepairFocus() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — that was not good enough. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == .missingDirectVerdict)
    }

    @Test func trustRepairWithAssessmentRepairFocusIsAccepted() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — that sounded cold, not like a human coach read. The useful read is the last rep buried the recommendation behind setup. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == nil)
    }

    @Test func trustRepairPolitePushbackDoesNotPassBySayingBut() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "there is friction underneath the polite pushback"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — but the move is a verdict-first rep. The actual read is your recommendation needs to land before the setup. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == .missingDirectVerdict)
    }

    @Test func trustRepairPolitePushbackNamesFrictionAndPasses() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "there is friction underneath the polite pushback"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — there is friction underneath the polite pushback. The actual read is your recommendation needs to land before the setup. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == nil)
    }

    @Test func trustRepairRoboticAcknowledgementNamesColdRepairFocus() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push: that read was robotic and too much like a report. The useful read is the last rep buried the recommendation behind setup. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == nil)
    }

    @Test func trustRepairFocusWithoutConcreteReadFails() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — that sounded cold, not like a human coach read. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == .missingRepairInsight)
    }

    @Test func trustRepairBecauseApologyWithoutEvidenceReadFails() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — that sounded cold, not like a human coach read, because I missed the tone. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == .missingRepairInsight)
    }

    @Test func trustRepairTargetBehaviorWithoutEvidenceReadFails() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — that sounded cold, not like a human coach read. The target behavior is cleaner. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == .missingRepairInsight)
    }

    @Test func trustRepairExplicitActualReadIsAccepted() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — that sounded cold, not like a human coach read. The actual read is your recommendation needs to land before the setup. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == nil)
    }

    @Test func vulnerableRepairMechanismAndSmallerExperimentIsAccepted() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "this is not easy under pressure"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push: no, it is not easy. The hard part is that sentence one carries the social risk, so test a smaller version: say only the disagreement and one calm reason, then stop.",
            latestUserTurn: "It's not easy.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == nil)
    }

    @Test func trustRepairWithCaseEvidenceFailsWhenRepairIgnoresCaseAnchor() {
        var assessment = Self.caseAnchoredDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — that sounded cold, not like a human coach read. The actual read is your latest rep was 7/10 with a 145 WPM pace. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == .missingCaseAnchor)
    }

    @Test func trustRepairCaseAnchorIsNotSatisfiedByGenericInterventionNameOnly() {
        var assessment = Self.caseAnchoredDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — that sounded cold, not like a human coach read. The actual read is the clean-close intervention needs one more answer ending on the ask. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == .missingCaseAnchor)
    }

    @Test func trustRepairWithCaseEvidencePassesWhenRepairUsesCaseAnchor() {
        var assessment = Self.caseAnchoredDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push — that sounded cold, not like a human coach read. The actual read is the clean-close intervention is still live: your close softens after the recommendation. Proof test: record one verdict-first rep.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == nil)
    }

    @Test func vulnerableRepairWithPressureCloseCaseAnchorIsAccepted() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I made the move sound easier than it feels under pressure"
        assessment.evidenceUsed.append(contentsOf: [
            "case summary: focus: pressure close; evidence: fillers cluster before the close; next move: use silence before the final sentence",
            "active intervention: Silent beat close reps; target: one silent beat before the final sentence.; followed reps: 1; review: review due"
        ])

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push: no, it is not easy. The hard part is holding the silent beat at the pressure point before the final sentence. Keep the next rep smaller: say only the close — one silent beat, the final sentence, then stop.",
            latestUserTurn: "It's not easy.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == nil)
    }

    @Test func trustRepairWithOrderingCaseAnchorIsAccepted() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .trustRepair
        assessment.repairFocus = "I sounded cold instead of giving a human coach read"
        assessment.evidenceUsed.append(contentsOf: [
            "case summary: focus: ordering signal; evidence: warmth arrives before the recommendation; next move: recommendation first then reassurance",
            "active intervention: Recommendation first reps; target: recommendation first, reassurance after.; followed reps: 1; review: review due"
        ])

        let issue = AICoachChatService.semanticQualityIssue(
            in: "Fair push: that was advice, not coaching. The ordering signal is warmth before the recommendation. Test this once: put the recommendation first, add one reassurance after it, then stop.",
            latestUserTurn: "This still sounds cold and overexplained, like generic AI tips.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        #expect(issue == nil)
    }

    // MARK: Quick-move gate

    @Test func quickMoveBlocksThinConfidenceClosenessClaim() {
        var assessment = Self.baseDeep
        assessment.turnDepth = .quickMove
        assessment.confidence = 0.40
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You're close overall, just go for it.",
            turnDepth: .quickMove,
            assessment: assessment
        )
        #expect(issue == .unsupportedClosenessClaim)
    }

    @Test func quickMoveAllowsClosenessClaimAboveConfidenceFloor() {
        // At confidence 0.62 (>= 0.55) the quick-move closeness gate is inactive.
        var assessment = Self.baseDeep
        assessment.turnDepth = .quickMove
        assessment.confidence = 0.62
        let issue = AICoachChatService.semanticQualityIssue(
            in: "You're close overall — go for it.",
            turnDepth: .quickMove,
            assessment: assessment
        )
        #expect(issue == nil)
    }

    @Test func nilAssessmentSkipsGate() {
        #expect(AICoachChatService.semanticQualityIssue(
            in: "Anything at all.",
            turnDepth: .deepAssessment,
            assessment: nil
        ) == nil)
    }

    @Test func emptyReplySkipsGate() {
        #expect(AICoachChatService.semanticQualityIssue(
            in: "   \n  ",
            turnDepth: .deepAssessment,
            assessment: Self.baseDeep
        ) == nil)
    }

    private static let baseDeep = CoachAssessment(
        turnDepth: .deepAssessment,
        surface: .text,
        questionRestatement: "How far off am I from sounding authoritative?",
        directVerdict: "You are closer mechanically than you are to fully sounding authoritative.",
        confidence: 0.62,
        evidenceUsed: [
            "latest rep: Timed, 7/10, 1 fillers, 60s",
            "pace estimate: 145 WPM"
        ],
        rubricScores: [],
        missingEvidence: [
            "Need repeated evidence across more than one clean rep before calling the user close overall.",
            "Need pressure-mode evidence before treating the goal as ready for real stakes."
        ],
        nextProofTest: "Record a 75-second answer where sentence one gives the verdict, sentence two gives one reason, and the final sentence names the ask.",
        responseMode: .expandable
    )

    private static let caseAnchoredDeep = CoachAssessment(
        turnDepth: .deepAssessment,
        surface: .text,
        questionRestatement: "Where do I stand overall?",
        directVerdict: "You are closer mechanically than you are to fully sounding authoritative.",
        confidence: 0.62,
        evidenceUsed: [
            "latest rep: Timed, 7/10, 1 fillers, 60s",
            "pace estimate: 145 WPM",
            "case summary: hypothesis: The recommendation is clear but the close softens; focus: clean close; evidence: Recent reps open better than they close; next move: review whether the close held under pressure",
            "active intervention: Clean close reps; target: End on the ask without an extra caveat.; followed reps: 2; review: review due"
        ],
        rubricScores: [],
        missingEvidence: [
            "Need repeated evidence across more than one clean rep before calling the user close overall.",
            "Need pressure-mode evidence before treating the goal as ready for real stakes."
        ],
        nextProofTest: "Record a 75-second answer where sentence one gives the verdict, sentence two gives one reason, and the final sentence names the ask.",
        responseMode: .expandable
    )
}

@Suite("CoachSemanticGateDryRunTests")
struct CoachSemanticGateDryRunTests {

    @Test func dryRunFlagDefaultsOffButCanBeEnabledFromEnvironment() {
        #expect(CoachBrainFlags.boolFlag(
            key: CoachBrainFlags.semanticGateDryRunEnabledKey,
            defaultValue: false,
            env: [:],
            configValue: { _ in nil }
        ) == false)

        #expect(CoachBrainFlags.boolFlag(
            key: CoachBrainFlags.semanticGateDryRunEnabledKey,
            defaultValue: false,
            env: [CoachBrainFlags.semanticGateDryRunEnabledKey: "1"],
            configValue: { _ in nil }
        ) == true)
    }

    @Test func dryRunAcceptsProviderReplyWhileSemanticGateWouldRejectIt() async throws {
        let semanticallyThinReply = """
        You are closer mechanically than authoritatively overall. Mechanics and goal readiness are different, so the score alone does not settle it. Missing: pressure reps. Proof test: record one verdict-first rep.
        """
        #expect(AICoachChatService.semanticQualityIssue(
            in: semanticallyThinReply,
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment
        ) == .insufficientEvidenceReferences)

        let payload: [String: Any] = [
            "content": [
                [
                    "type": "text",
                    "text": semanticallyThinReply
                ]
            ],
            "stop_reason": "end_turn"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let service = AICoachChatService(
            keyedProviders: { [.anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in .success(data) },
            semanticGateDryRun: { true }
        )

        let outcome = await service.reply(
            history: [
                CoachMessage(
                    role: .user,
                    text: "How far off am I from sounding authoritative?"
                )
            ],
            systemPrompt: "You are Noum.",
            userContext: "COACH JUDGEMENT PASS",
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            #expect(text.contains("closer mechanically"))
        case .failure(let failure):
            #expect(Bool(false), "dry-run should accept the provider reply, got \(failure)")
        }
    }

    private static let deepAssessment = CoachAssessment(
        turnDepth: .deepAssessment,
        surface: .text,
        questionRestatement: "How far off am I from sounding authoritative?",
        directVerdict: "You are closer mechanically than you are to fully sounding authoritative.",
        confidence: 0.62,
        evidenceUsed: [
            "latest rep: Timed, 7/10, 1 fillers, 60s",
            "pace estimate: 145 WPM"
        ],
        rubricScores: [],
        missingEvidence: [
            "Need repeated evidence across more than one clean rep before calling the user close overall.",
            "Need pressure-mode evidence before treating the goal as ready for real stakes."
        ],
        nextProofTest: "Record a 75-second answer where sentence one gives the verdict, sentence two gives one reason, and the final sentence names the ask.",
        responseMode: .expandable
    )
}

@Suite("CoachTypedFallbackTests", .serialized)
struct CoachTypedFallbackTests {

    @Test func trustRepairRubricUsesDepthAwareBudget() {
        let reply = """
        Fair push. The symbols and the report-style layout are on me.
        Your last rep gives one real signal to work: the recommendation arrived late, and the close was the softest part. So the one move is this: lead with your verdict in the first sentence, then give one reason or implication, and stop there.
        Test it in the next rep under a 60-second timer. That's the pressure condition that will tell us something real.
        """

        let rubric = AICoachChatService.professionalCoachRubric(
            reply: reply,
            latestUserTurn: "The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach."
        )

        #expect(!rubric.misses.contains(.overlong))
        #expect(rubric.passesSeniorCoachFloor)
    }

    @Test func transferReviewCaptureCountsAsPrescribedAction() {
        let userTurn = "My interview answer landed better than practice. What do we learn?"
        let reply = "Treat it as useful self-report, not proof. The reusable move is verdict first plus one example, so keep that for interviews and capture what question made it land."

        let rubric = AICoachChatService.professionalCoachRubric(
            reply: reply,
            latestUserTurn: userTurn,
            turnDepth: .groundedRead
        )

        #expect(!rubric.misses.contains(.missingPrescribedAction))
        #expect(AICoachChatService.replyQualityIssue(
            in: reply,
            latestUserTurn: userTurn,
            systemContext: "REAL-WORLD TRANSFER: user reports an interview answer landed better.",
            turnDepth: .groundedRead
        ) == nil)
    }

    @Test func providerQualityFailureFallsBackToTypedDeepAssessment() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "You scored 7/10, so just sound more confident next time."
        )

        let outcome = await service.reply(
            history: [
                CoachMessage(
                    role: .user,
                    text: "How far off am I from sounding authoritative?"
                )
            ],
            systemPrompt: "You are Noum.",
            userContext: "COACH JUDGEMENT PASS",
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            #expect(text.contains("closer mechanically"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: "How far off am I from sounding authoritative?",
                turnDepth: .deepAssessment
            ) == nil)
            #expect(AICoachChatService.semanticQualityIssue(
                in: text,
                turnDepth: .deepAssessment,
                assessment: Self.deepAssessment
            ) == nil)
        case .failure(let failure):
            #expect(Bool(false), "typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackForLowConfidenceDistanceVerdict() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "You're a 7/10, so you're close. Try sounding more confident."
        )
        let userTurn = "How far off am I from sounding authoritative?"

        let outcome = await service.reply(
            history: [
                CoachMessage(
                    role: .user,
                    text: userTurn
                )
            ],
            systemPrompt: "You are Noum.",
            userContext: "RECENT (most-recent first): latest rep Timed, 7/10, 1 fillers, 58s.",
            turnDepth: .deepAssessment,
            assessment: Self.lowConfidenceDistanceAssessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("not proven authoritative overall"))
            #expect(!lower.contains("you're close"))
            #expect(!lower.contains("you are close"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: "RECENT (most-recent first): latest rep Timed, 7/10, 1 fillers, 58s.",
                turnDepth: .deepAssessment
            ) == nil)
            #expect(AICoachChatService.semanticQualityIssue(
                in: text,
                turnDepth: .deepAssessment,
                assessment: Self.lowConfidenceDistanceAssessment
            ) == nil)
        case .failure(let failure):
            #expect(Bool(false), "low-confidence typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackWithReadableQuickMoveConnector() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "Based on your data, here are a few tips to communicate more clearly."
        )
        let userTurn = "How do I add depth without rambling?"

        let outcome = await service.reply(
            history: [
                CoachMessage(
                    role: .user,
                    text: userTurn
                )
            ],
            systemPrompt: "You are Noum.",
            userContext: "RECENT (most-recent first): latest rep Timed, 8/10, 0 fillers, 63s.",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            #expect(text.contains("so use"))
            #expect(!text.contains("so Run"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: "RECENT (most-recent first): latest rep Timed, 8/10, 0 fillers, 63s.",
                turnDepth: .quickMove
            ) == nil)
        case .failure(let failure):
            #expect(Bool(false), "quick-move typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackWithIntentSpecificArenaReads() async throws {
        struct Spec {
            let userTurn: String
            let depth: CoachTurnDepth
            let expectedFragments: [String]
            let rejectedFragments: [String]
        }

        let specs: [Spec] = [
            Spec(
                userTurn: "Can you give me an example of me doing this in sessions?",
                depth: .groundedRead,
                expectedFragments: ["safe example", "latest rep", "concrete scene", "add one example"],
                rejectedFragments: ["fabricated quote"]
            ),
            Spec(
                userTurn: "The room seemed engaged. Did the drill cause that?",
                depth: .groundedRead,
                expectedFragments: ["not call that causation", "useful association", "room stayed engaged", "capture"],
                rejectedFragments: ["drill caused"]
            ),
            Spec(
                userTurn: "I have a difficult conversation tonight. What should I practice?",
                depth: .quickMove,
                expectedFragments: ["over-proving", "boundary sentence", "one calm reason", "then stop"],
                rejectedFragments: ["75-second answer"]
            ),
            Spec(
                userTurn: "I ramble when introducing myself at networking events.",
                depth: .quickMove,
                expectedFragments: ["20-second test", "who you help", "one question", "ramble starts"],
                rejectedFragments: ["memorable phrase"]
            ),
            Spec(
                userTurn: "My presentation sounds polished but flat. What is missing?",
                depth: .groundedRead,
                expectedFragments: ["cannot prove vocal energy", "hypothesis", "mark the consequence", "deliberate emphasis"],
                rejectedFragments: ["silent beat"]
            ),
            Spec(
                userTurn: "My sales pitch loses people after the first minute.",
                depth: .quickMove,
                expectedFragments: ["likely gap is salience", "customer example", "first claim", "return to the ask"],
                rejectedFragments: ["memorable phrase"]
            ),
            Spec(
                userTurn: "Am I afraid to disagree?",
                depth: .groundedRead,
                expectedFragments: ["not diagnose fear", "hypothesis only", "observable pattern", "sentence one"],
                rejectedFragments: ["you are afraid"]
            ),
            Spec(
                userTurn: "Do I lack conviction?",
                depth: .deepAssessment,
                expectedFragments: ["not enough evidence", "recent reps", "hedge before the recommendation", "not a verdict about your identity", "repeated answers under pressure"],
                rejectedFragments: ["you lack conviction", "proof test", "goal readiness"]
            ),
            Spec(
                userTurn: "Could this sound polished but evasive?",
                depth: .deepAssessment,
                expectedFragments: ["structure read", "not a claim about you", "too much setup", "not seen it hold under pressure", "listener's read"],
                rejectedFragments: ["you are evasive", "personality", "proof test", "goal readiness"]
            ),
            Spec(
                userTurn: "Do I sound timid?",
                depth: .groundedRead,
                expectedFragments: ["cannot prove timid", "audio evidence", "direct recommendation", "tone verdict"],
                rejectedFragments: ["you are timid"]
            ),
            Spec(
                userTurn: "It sounds correct but not like me. What do I change?",
                depth: .groundedRead,
                expectedFragments: ["trust that signal", "keep the structure", "actually say", "check how it feels"],
                rejectedFragments: ["be authentic"]
            ),
            Spec(
                userTurn: "You counted 'like' but I meant it as a comparison.",
                depth: .groundedRead,
                expectedFragments: ["good correction", "semantic comparison", "should not count", "punish valid speech"],
                rejectedFragments: ["stop saying like"]
            ),
            Spec(
                userTurn: "The prompt made me repeat the phrase. Is that my filler?",
                depth: .groundedRead,
                expectedFragments: ["fair boundary", "prompt echo", "not the same as filler", "would not count"],
                rejectedFragments: ["your filler"]
            ),
            Spec(
                userTurn: "Did I actually say that?",
                depth: .groundedRead,
                expectedFragments: ["correction", "retract the quote", "supported read", "unverified wording"],
                rejectedFragments: ["yes, you said"]
            ),
            Spec(
                userTurn: "Quickly, what do I do next?",
                depth: .quickMove,
                expectedFragments: ["close is the lever", "final sentence", "then stop"],
                rejectedFragments: ["several things"]
            ),
            Spec(
                userTurn: "This week felt harder even though my score improved.",
                depth: .groundedRead,
                expectedFragments: ["both can be true", "score says mechanics improved", "felt harder", "one fewer condition"],
                rejectedFragments: ["score improved, so"]
            ),
            Spec(
                userTurn: "My interview answer landed better than practice. What do we learn?",
                depth: .groundedRead,
                expectedFragments: ["useful self-report", "not proof", "verdict first plus one example", "capture what question"],
                rejectedFragments: ["drill caused"]
            ),
            Spec(
                userTurn: "What voice should I even pick? There are six and I don't know.",
                depth: .groundedRead,
                expectedFragments: ["start with authoritative", "meetings where you get talked over", "executive presence"],
                rejectedFragments: ["tap to confirm", "lock it in"]
            ),
            Spec(
                userTurn: "I think I want to sound more engaging.",
                depth: .groundedRead,
                expectedFragments: ["engaging maps closest to storytelling", "warm", "what changed"],
                rejectedFragments: ["tap to confirm", "lock it in", "3 fillers"]
            ),
            Spec(
                userTurn: "Why can't you just give me a straight answer?",
                depth: .trustRepair,
                expectedFragments: ["straight answer", "yes on fillers", "no on pace under pressure", "one silent beat"],
                rejectedFragments: ["hit 3 in 60 seconds", "score"]
            ),
            Spec(
                userTurn: "What is the one move?",
                depth: .quickMove,
                expectedFragments: ["close is the move", "final sentence", "then stop"],
                rejectedFragments: ["read:"]
            ),
            Spec(
                userTurn: "Can you coach this?",
                depth: .quickMove,
                expectedFragments: ["one rep", "coach this honestly", "opener and close", "record 60 seconds"],
                rejectedFragments: ["placeholder", "latest rep"]
            )
        ]
        let context = "RECENT (most-recent first): latest rep Timed, 7/10, 1 fillers, 50s.\nREAL-WORLD TRANSFER: user reports the room seemed engaged and an interview answer landed better."

        for spec in specs {
            let service = try Self.serviceThatAlwaysReturnsBadReply(
                "Based on your data, here are a few tips to communicate more clearly."
            )
            let assessment = Self.intentFallbackAssessment(
                depth: spec.depth,
                userTurn: spec.userTurn
            )

            let outcome = await service.reply(
                history: [CoachMessage(role: .user, text: spec.userTurn)],
                systemPrompt: "You are Noum.",
                userContext: context,
                turnDepth: spec.depth,
                assessment: assessment,
                surface: .text,
                preferredTier: .claudeReasoning
            )

            switch outcome {
            case .reply(let text):
                let lower = text.lowercased()
                for fragment in spec.expectedFragments {
                    #expect(lower.contains(fragment), "\(spec.userTurn) missing \(fragment) in \(text)")
                }
                for fragment in spec.rejectedFragments {
                    #expect(!lower.contains(fragment), "\(spec.userTurn) should not contain \(fragment) in \(text)")
                }
                #expect(AICoachChatService.replyQualityIssue(
                    in: text,
                    latestUserTurn: spec.userTurn,
                    systemContext: context,
                    turnDepth: spec.depth,
                    surface: .text
                ) == nil, "\(spec.userTurn) should pass reply quality: \(text)")
                #expect(AICoachChatService.semanticQualityIssue(
                    in: text,
                    latestUserTurn: spec.userTurn,
                    systemContext: context,
                    turnDepth: spec.depth,
                    assessment: assessment
                ) == nil, "\(spec.userTurn) should pass semantic quality: \(text)")
            case .failure(let failure):
                #expect(Bool(false), "\(spec.userTurn) typed fallback should prevent content rejection, got \(failure)")
            }
        }
    }

    @Test func providerQualityFailureFallsBackToColdStartFirstSample() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "Based on your data, do an Ah-Counter round and keep it under 4 fillers."
        )
        let userTurn = "What should I work on?"
        let context = """
        PERSONALIZATION FLOOR: no rated sessions yet.
        Not enough data for a stable baseline yet.
        No voice set yet.
        """
        let assessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: "There is not enough evidence for a stable coaching read yet.",
            confidence: 0.20,
            evidenceUsed: [],
            rubricScores: [],
            missingEvidence: [
                "Need one real recorded sample before assigning a stable focus."
            ],
            nextProofTest: "Record one 60-second sample on something familiar.",
            responseMode: .immediateOnly
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .groundedRead,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("start with one real sample"))
            #expect(lower.contains("record 60 seconds"))
            #expect(lower.contains("real pace"))
            #expect(!lower.contains("ah-counter"))
            #expect(!lower.contains("under 4 fillers"))
            #expect(!lower.contains("stable baseline"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .groundedRead,
                surface: .text
            ) == nil, "cold-start fallback should pass reply quality: \(text)")
            #expect(AICoachChatService.semanticQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .groundedRead,
                assessment: assessment
            ) == nil, "cold-start fallback should pass semantic quality: \(text)")
        case .failure(let failure):
            #expect(Bool(false), "cold-start typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackToOffTopicRedirect() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "You hit 80 today with 3 fillers. Run one Timed rep and chase a cleaner score."
        )
        let userTurn = "egg"
        let context = "RECENT (most-recent first): latest rep Timed, 8/10, 1 filler, 58s."
        let assessment = Self.intentFallbackAssessment(
            depth: .quickMove,
            userTurn: userTurn
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .quickMove,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("tiny test"))
            #expect(lower.contains("send the moment"))
            #expect(lower.contains("one clean read"))
            #expect(!lower.contains("hit 80"))
            #expect(!lower.contains("timed rep"))
            #expect(!lower.contains("fillers"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .quickMove,
                surface: .text
            ) == nil, "off-topic fallback should pass reply quality: \(text)")
            #expect(AICoachChatService.semanticQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .quickMove,
                assessment: assessment
            ) == nil, "off-topic fallback should pass semantic quality: \(text)")
        case .failure(let failure):
            #expect(Bool(false), "off-topic typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackToGreetingThreadCue() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "Run one Timed rep and hit 3 fillers again."
        )
        let userTurn = "Hi"
        let assessment = CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: "The close is still the thread to pick up.",
            confidence: 0.55,
            evidenceUsed: [
                "latest rep: close held once but softened once"
            ],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Land the final sentence flat, then stop.",
            responseMode: .immediateOnly
        )
        let context = "RECENT: latest rep close held once but softened once."

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .quickMove,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("hey"))
            #expect(lower.contains("pick up with the close"))
            #expect(lower.contains("land the final sentence flat"))
            #expect(!lower.contains("timed rep"))
            #expect(!lower.contains("hit 3 fillers"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .quickMove,
                surface: .text
            ) == nil, "greeting fallback should pass reply quality: \(text)")
        case .failure(let failure):
            #expect(Bool(false), "greeting typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackToVulnerablePushbackPresence() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "It is easy: just be confident and keep practicing."
        )
        let userTurn = "It's not easy."
        let assessment = CoachAssessment(
            turnDepth: .trustRepair,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: "The repair should meet the pressure before prescribing again.",
            confidence: 0.42,
            evidenceUsed: [
                "this week you held composure through an interruption"
            ],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Say only the first hard sentence, then stop.",
            responseMode: .immediateOnly,
            toneMode: .repair,
            repairFocus: "I made the move sound easier than it feels under pressure"
        )
        let context = "RECENT: user held composure through an interruption this week."

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .trustRepair,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("no, it is not easy"))
            #expect(lower.contains("held composure through an interruption"))
            #expect(lower.contains("first hard sentence"))
            #expect(!lower.contains("just be confident"))
            #expect(!lower.contains("sentence one carries the social risk"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .trustRepair,
                surface: .text
            ) == nil, "vulnerable fallback should pass reply quality: \(text)")
            #expect(AICoachChatService.semanticQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .trustRepair,
                assessment: assessment
            ) == nil, "vulnerable fallback should pass semantic quality: \(text)")
        case .failure(let failure):
            #expect(Bool(false), "vulnerable typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func referenceRepairForNotInformativeUsesSpecificReadWithoutScaffold() throws {
        let shape = try #require(AICoachChatService.repairReferenceShape(
            issue: .missedTrustRepair,
            latestUserTurn: "That's not informative.",
            system: "RECENT: the point arrived in sentence four after three warm-up sentences."
        ))
        let lower = shape.lowercased()

        #expect(lower.contains("fair. i was too vague"))
        #expect(lower.contains("point arrived in sentence four"))
        #expect(lower.contains("say the point first"))
        #expect(!lower.contains("real read:"))
        #expect(!lower.contains("score"))
        #expect(!lower.contains("cut the"))
    }

    @Test func providerQualityFailureFallsBackToPaceSelfFrustrationRead() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "You scored 71. Just slow down and be more confident."
        )
        let userTurn = "I talk way too fast, people can't keep up."
        let context = "RECENT: latest rep scored 71, pace 215 WPM, pause rate 0.09."
        let assessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: "The issue is the missing gap between sentences, not confidence.",
            confidence: 0.64,
            evidenceUsed: [
                "latest rep: pace 215 WPM, pause rate 0.09"
            ],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Hold one silent beat after every full stop.",
            responseMode: .immediateOnly
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .groundedRead,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("you're not imagining it"))
            #expect(lower.contains("215 wpm"))
            #expect(lower.contains("0.09 pause rate"))
            #expect(lower.contains("fix the pause"))
            #expect(!lower.contains("scored 71"))
            #expect(!lower.contains("just slow down"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .groundedRead,
                surface: .text
            ) == nil, "pace fallback should pass reply quality: \(text)")
        case .failure(let failure):
            #expect(Bool(false), "pace typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackToRambleStoppingRule() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "Next rep: be more concise and structure your thoughts."
        )
        let userTurn = "I ramble — I start a point and three minutes later I'm somewhere else."
        let context = "RECENT: opened with the point, then stacked side stories before a weaker repeat."
        let assessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: "The mechanism is reopening the point after side stories.",
            confidence: 0.60,
            evidenceUsed: [
                "latest rep: side stories clustered before a weaker repeat at the end"
            ],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "State the point, give one support line, then silence.",
            responseMode: .immediateOnly
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .groundedRead,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("kept the thread"))
            #expect(lower.contains("weaker repeat"))
            #expect(lower.contains("hard stop"))
            #expect(!lower.contains("next rep:"))
            #expect(!lower.contains("be more concise"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .groundedRead,
                surface: .text
            ) == nil, "ramble fallback should pass reply quality: \(text)")
        case .failure(let failure):
            #expect(Bool(false), "ramble typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackToLeadershipRehearsal() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "Your last rep was clean at 77. Add structure and people will listen."
        )
        let userTurn = "I have to give the weekly leadership update to the whole department tomorrow. It always feels like I'm just reading a status report and people zone out. Help."
        let context = "RECENT: nine equal-weight updates, no through-line, last rep clean at 77."
        let assessment = CoachAssessment(
            turnDepth: .deepAssessment,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: "The status-report risk is hierarchy: every update lands at the same weight.",
            confidence: 0.66,
            evidenceUsed: [
                "latest rep: nine equal-weight updates with no through-line"
            ],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Tonight, write the opener as the one thing that matters this week and why.",
            responseMode: .expandable
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .deepAssessment,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("status-report risk is hierarchy"))
            #expect(lower.contains("leadership goal"))
            #expect(lower.contains("hierarchy"))
            #expect(lower.contains("tonight"))
            #expect(lower.contains("the one thing that matters this week"))
            #expect(!lower.contains("clean at 77"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .deepAssessment,
                surface: .text
            ) == nil, "leadership fallback should pass reply quality: \(text)")
        case .failure(let failure):
            #expect(Bool(false), "leadership typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackToRecurringCloseTrend() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "Next rep: hit your second-to-last sentence, hold a beat, then say the final line slowly."
        )
        let userTurn = "What should I work on next? The last one felt solid to me."
        let context = "POSITIONAL TREND: fastest stretch keeps landing at the close: 4 of the last 5 reps with a fast stretch, 5 of the last 6 overall."
        let assessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: "The solid feeling is real, and the recurring edge is the close.",
            confidence: 0.70,
            evidenceUsed: [
                "close rush: 4 of the last 5 reps with a fast stretch and 5 of the last 6 overall"
            ],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Plant one silent beat before the final line.",
            responseMode: .immediateOnly
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .groundedRead,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("solid feeling is real"))
            #expect(lower.contains("4 of the last 5"))
            #expect(lower.contains("5 of the last 6"))
            #expect(lower.contains("plant one silent beat"))
            #expect(!lower.contains("next rep:"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .groundedRead,
                surface: .text
            ) == nil, "recurring-close fallback should pass reply quality: \(text)")
        case .failure(let failure):
            #expect(Bool(false), "recurring-close typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackToMetadataSelfKnowledgeRead() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "So the thing to test: next rep, hold one silent beat before you answer."
        )
        let userTurn = "What does your system actually know about me?"
        let context = "GOAL: sound like yourself in hard conversations. PATTERN: tense moments make you race to fill silence. BASELINE: 170 WPM pace. STREAK: 12-day streak."
        let assessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: "The bounded read is goal, pressure pattern, pace baseline, and streak.",
            confidence: 0.68,
            evidenceUsed: [
                "goal: sound like yourself in hard conversations",
                "pattern: race to fill silence under pressure",
                "numbers: 170 WPM pace baseline and 12-day streak"
            ],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Wait on a next drill until the user asks for one.",
            responseMode: .immediateOnly
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .groundedRead,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("real read, not a script"))
            #expect(lower.contains("sound like yourself"))
            #expect(lower.contains("pace baseline around 170 wpm"))
            #expect(lower.contains("12-day streak"))
            #expect(lower.contains("wait on a next drill"))
            #expect(!lower.contains("so the thing to test"))
            #expect(!lower.contains("next rep"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .groundedRead,
                surface: .text
            ) == nil, "metadata fallback should pass reply quality: \(text)")
        case .failure(let failure):
            #expect(Bool(false), "metadata typed fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func lackConvictionTypedFallbackPassesCaseAnchorGate() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "You lack conviction, so try to sound more confident."
        )
        let userTurn = "Do I lack conviction?"
        let assessment = CoachAssessment(
            turnDepth: .deepAssessment,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: "There is not enough evidence to call this lack of conviction overall.",
            confidence: 0.62,
            evidenceUsed: [
                "latest rep: Timed, 7/10, 1 fillers, 50s",
                "pace estimate: 145 WPM",
                "case summary: hypothesis: Filler Words appears to be the highest-leverage focus because it keeps showing up in recent reps; keep checking against future reps."
            ],
            rubricScores: [],
            missingEvidence: [
                "Need repeated pressure proof before making an identity-level call."
            ],
            nextProofTest: "Repeat the answer and replace the first hedge with a direct verb.",
            responseMode: .expandable
        )
        let context = "RECENT (most-recent first): latest rep Timed, 7/10, 1 fillers, 50s."

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .deepAssessment,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("recent reps"))
            #expect(lower.contains("point to one narrow read"))
            #expect(lower.contains("hedge before the recommendation"))
            #expect(!lower.contains("proof test"))
            #expect(!lower.contains("goal readiness"))
            #expect(!lower.contains("you lack conviction"))
            #expect(AICoachChatService.semanticQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                systemContext: context,
                turnDepth: .deepAssessment,
                assessment: assessment
            ) == nil, "case-anchored lack-conviction fallback should pass semantic quality: \(text)")
        case .failure(let failure):
            #expect(Bool(false), "case-anchored lack-conviction fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackToTypedTrustRepair() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "Let us optimize your communication style with better responses."
        )
        let userTurn = "This is robotic and too much writing."

        let outcome = await service.reply(
            history: [
                CoachMessage(
                    role: .user,
                    text: userTurn
                )
            ],
            systemPrompt: "You are Noum.",
            userContext: "RECENT: latest rep had 4 fillers.",
            turnDepth: .trustRepair,
            assessment: Self.trustRepairAssessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            #expect(text.contains("Fair push"))
            #expect(text.lowercased().contains("report"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                turnDepth: .trustRepair
            ) == nil)
            #expect(AICoachChatService.semanticQualityIssue(
                in: text,
                turnDepth: .trustRepair,
                assessment: Self.trustRepairAssessment
            ) == nil)
        case .failure(let failure):
            #expect(Bool(false), "typed trust fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackToTypedMarkdownTTSRepair() async throws {
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "I'll cut the markers and the report voice from here."
        )
        let userTurn = "The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach."

        let outcome = await service.reply(
            history: [
                CoachMessage(
                    role: .user,
                    text: userTurn
                )
            ],
            systemPrompt: "You are Noum.",
            userContext: "RECENT: latest rep had 4 fillers.",
            turnDepth: .trustRepair,
            assessment: Self.trustRepairAssessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("tts"))
            #expect(lower.contains("formatting"))
            #expect(lower.contains("robotic") || lower.contains("cold"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: userTurn,
                turnDepth: .trustRepair
            ) == nil)
            #expect(AICoachChatService.semanticQualityIssue(
                in: text,
                turnDepth: .trustRepair,
                assessment: Self.trustRepairAssessment
            ) == nil)
        case .failure(let failure):
            #expect(Bool(false), "typed markdown/TTS trust fallback should prevent content rejection, got \(failure)")
        }
    }

    @Test func providerQualityFailureFallsBackToTypedMarkdownTTSRepairInLiveFixtureContext() async throws {
        let fixture = try #require(CoachChatEvaluationCorpus.fixtures.first {
            $0.id == "markdown-tts-trust-repair"
        })
        let service = try Self.serviceThatAlwaysReturnsBadReply(
            "I'll cut the markers and the report voice from here."
        )
        let history = Self.history(for: fixture)
        let turnDepth = TurnDepthClassifier.classify(
            userText: fixture.latestUserTurn,
            recentTurns: history,
            liveMode: false
        )
        let trajectory = UserTrajectoryCache.shared.snapshot(
            profile: fixture.profile,
            baseline: .empty,
            rating: .initial,
            sessions: fixture.sessions,
            coachMemory: nil
        )
        let rubric = GoalRubricStore.activeRubric(for: fixture.profile)
        let assessment = CoachReasoningPass.assess(
            turnDepth: turnDepth,
            userQuestion: fixture.latestUserTurn,
            trajectory: trajectory.snapshot,
            rubric: rubric,
            surface: .text
        )
        let systemPrompt = CoachContextBuilder.systemPrompt(for: fixture.profile)
        var context = await Self.liveStyleContext(for: fixture)
        context += "\n" + CoachPromptBundle.contextBlock(
            assessment: assessment,
            rubric: rubric,
            surface: .text
        )
        let grounding = Self.grounding(for: fixture)
        let quoteGuard = CoachChatQuoteGuardContext(
            transcripts: [grounding.recentTimedTranscript],
            latestUserTurn: fixture.latestUserTurn,
            recentUserTurns: history.filter { $0.role == .user }.map(\.text)
        )

        let outcome = await service.reply(
            history: history,
            systemPrompt: systemPrompt,
            userContext: context,
            grounding: grounding,
            turnDepth: turnDepth,
            assessment: assessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        switch outcome {
        case .reply(let text):
            let lower = text.lowercased()
            #expect(lower.contains("tts"))
            #expect(lower.contains("formatting") || lower.contains("symbols"))
            #expect(lower.contains("robotic") || lower.contains("cold"))
            #expect(lower.contains("run one"))
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: fixture.latestUserTurn,
                quoteGuard: quoteGuard,
                systemContext: context,
                turnDepth: turnDepth,
                surface: .text
            ) == nil)
            #expect(AICoachChatService.replyQualityIssue(
                in: text,
                latestUserTurn: fixture.latestUserTurn,
                quoteGuard: quoteGuard,
                systemContext: systemPrompt + "\n\n" + context,
                turnDepth: turnDepth,
                surface: .text
            ) == nil)
            #expect(AICoachChatService.semanticQualityIssue(
                in: text,
                turnDepth: turnDepth,
                assessment: assessment
            ) == nil)
        case .failure(let failure):
            #expect(Bool(false), "typed markdown/TTS fixture fallback should prevent content rejection, got \(failure)")
        }
    }

    private static func liveStyleContext(
        for fixture: CoachChatEvaluationFixture
    ) async -> String {
        let expertise = await KnowledgeRetriever.retrieveReranked(
            query: fixture.latestUserTurn,
            lever: fixture.trends.first?.skillArea,
            voice: fixture.profile?.speakingStyleGoal,
            hasDiagnosis: !fixture.sessions.isEmpty
        )
        return CoachContextBuilder.userContext(
            profile: fixture.profile,
            baseline: .empty,
            rating: .initial,
            sessions: fixture.sessions,
            currentStreak: fixture.sessions.isEmpty ? 0 : 2,
            pathStatus: nil,
            pathGatingPhrase: nil,
            trends: fixture.trends,
            latestUserTurn: fixture.latestUserTurn,
            previousCoachReply: fixture.previousCoachReply,
            recentUserTurns: [fixture.latestUserTurn],
            coachingExpertise: expertise
        )
    }

    private static func history(
        for fixture: CoachChatEvaluationFixture
    ) -> [CoachMessage] {
        var messages: [CoachMessage] = []
        if let previous = fixture.previousCoachReply,
           !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(CoachMessage(role: .coach, text: previous))
        }
        messages.append(CoachMessage(role: .user, text: fixture.latestUserTurn))
        return messages
    }

    private static func grounding(
        for fixture: CoachChatEvaluationFixture
    ) -> ChatGroundingContext {
        let recentTimed = fixture.sessions
            .filter { $0.mode == .timed }
            .max(by: { $0.date < $1.date })
        return ChatGroundingContext(
            recentTimedTranscript: recentTimed?.transcript,
            verifiedProofQuotes: []
        )
    }

    private static func serviceThatAlwaysReturnsBadReply(
        _ text: String
    ) throws -> AICoachChatService {
        let payload: [String: Any] = [
            "content": [
                [
                    "type": "text",
                    "text": text
                ]
            ],
            "stop_reason": "end_turn"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return AICoachChatService(
            keyedProviders: { [.anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in .success(data) }
        )
    }

    private static let deepAssessment = CoachAssessment(
        turnDepth: .deepAssessment,
        surface: .text,
        questionRestatement: "How far off am I from sounding authoritative?",
        directVerdict: "You are closer mechanically than you are to fully sounding authoritative.",
        confidence: 0.62,
        evidenceUsed: [
            "latest rep: Timed, 7/10, 1 fillers, 60s",
            "pace estimate: 145 WPM"
        ],
        rubricScores: [],
        missingEvidence: [
            "Need repeated evidence across more than one clean rep before calling the user close overall.",
            "Need pressure-mode evidence before treating the goal as ready for real stakes."
        ],
        nextProofTest: "Record a 75-second answer where sentence one gives the verdict, sentence two gives one reason, and the final sentence names the ask.",
        responseMode: .expandable
    )

    private static let lowConfidenceDistanceAssessment = CoachAssessment(
        turnDepth: .deepAssessment,
        surface: .text,
        questionRestatement: "How far off am I from sounding authoritative?",
        directVerdict: "I do not have enough evidence for an overall authoritative communication verdict yet.",
        confidence: 0.20,
        evidenceUsed: [
            "latest rep: Timed, 7/10, 1 fillers, 58s"
        ],
        rubricScores: [],
        missingEvidence: [
            "Need repeated evidence across more than one clean rep before calling the user close overall.",
            "Need a pressure rep; a clean normal rep does not prove authority under stakes.",
            "Need a rep showing pauses replacing fillers, not just a lower score."
        ],
        nextProofTest: "Run the same answer under a 60-90 second timer or pressure mode and keep the verdict first.",
        responseMode: .expandable
    )

    private static let quickMoveAssessment = CoachAssessment(
        turnDepth: .quickMove,
        surface: .text,
        questionRestatement: "How do I add depth without rambling?",
        directVerdict: "The next useful move is narrow: test one observable change, not a new plan.",
        confidence: 0.20,
        evidenceUsed: [
            "latest rep: Timed, 8/10, 0 fillers, 63s"
        ],
        rubricScores: [],
        missingEvidence: [],
        nextProofTest: "Run the same answer under a 60-90 second timer or pressure mode and keep the verdict first.",
        responseMode: .immediateOnly
    )

    private static func intentFallbackAssessment(
        depth: CoachTurnDepth,
        userTurn: String
    ) -> CoachAssessment {
        CoachAssessment(
            turnDepth: depth,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: depth == .deepAssessment
                ? "You do not have enough evidence for a stable overall verdict yet."
                : "The next useful move is to answer the real question before adding another drill.",
            confidence: depth == .deepAssessment ? 0.62 : 0.69,
            evidenceUsed: [
                "latest rep: Timed, 7/10, 1 fillers, 50s",
                "pace estimate: 145 WPM"
            ],
            rubricScores: [],
            missingEvidence: depth == .deepAssessment
                ? ["Need repeated pressure proof before making an identity-level call."]
                : [],
            nextProofTest: depth == .deepAssessment
                ? "Run one answer with no maybe or probably before the recommendation and check whether the verdict sounds cleaner."
                : "Make the final sentence the ask, then stop.",
            responseMode: depth == .deepAssessment ? .expandable : .immediateOnly
        )
    }

    private static let trustRepairAssessment = CoachAssessment(
        turnDepth: .trustRepair,
        surface: .text,
        questionRestatement: "This is robotic and too much writing.",
        directVerdict: "The prior answer needs repair: it should answer the real question before offering advice.",
        confidence: 0.40,
        evidenceUsed: [
            "latest rep: Timed, 7/10, 4 fillers, 60s"
        ],
        rubricScores: [],
        missingEvidence: [
            "Need repeated evidence across more than one clean rep before calling the user close overall."
        ],
        nextProofTest: "Run one cleaner rep with the main point first, then stop.",
        responseMode: .expandable
    )
}

@Suite("CoachProviderRoutingByDepthTests")
struct CoachProviderRoutingByDepthTests {

    @Test func deepAssessmentPrefersClaudeInTextMode() {
        let chain = AICoachChatService.orderedChain(
            keyed: [.gemini, .anthropic, .openAI],
            cooldowns: [:],
            now: Date(timeIntervalSince1970: 1_000),
            preferredTier: CoachPromptBundle.preferredProviderTier(for: .deepAssessment, surface: .text)
        )

        #expect(chain.first == .anthropic)
    }

    @Test func liveDeepAssessmentKeepsFastTier() {
        #expect(CoachPromptBundle.preferredProviderTier(for: .deepAssessment, surface: .live) == .geminiFast)
        #expect(CoachPromptBundle.maxOutputTokens(for: .deepAssessment, surface: .live)
            < CoachPromptBundle.maxOutputTokens(for: .deepAssessment, surface: .text))
    }

    @Test func quickMovePrefersGeminiFamily() {
        let chain = AICoachChatService.orderedChain(
            keyed: [.anthropic, .openAI, .gemini],
            cooldowns: [:],
            now: Date(timeIntervalSince1970: 1_000),
            preferredTier: CoachPromptBundle.preferredProviderTier(for: .quickMove, surface: .text)
        )

        #expect(chain.first == .gemini)
    }

    @MainActor
    @Test func acceptedReplyReportsActualProviderChoice() async throws {
        let payload = try Self.anthropicPayload(
            "Your last rep was 7/10 with 1 filler, so lead with the recommendation in sentence one and stop after one proof point. Run one 60-second rep with that shape."
        )
        let service = AICoachChatService(
            keyedProviders: { [.anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in .success(payload) }
        )
        var providerChoice: CoachTurnProviderChoice?

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "What should I do next?")],
            systemPrompt: "You are Noum.",
            userContext: "RECENT: latest rep 7/10, 1 filler.",
            turnDepth: .quickMove,
            surface: .text,
            preferredTier: .claudeReasoning,
            onProviderChosen: { choice in
                providerChoice = choice
            }
        )

        if case .failure(let failure) = outcome {
            #expect(Bool(false), "expected accepted provider reply, got \(failure)")
        }
        #expect(providerChoice?.providerName == CoachChatProvider.anthropic.displayName)
        #expect(providerChoice?.model == CoachChatProvider.anthropic.model)
    }

    @MainActor
    @Test func typedFallbackReportsProviderChoiceAfterQualityFailure() async throws {
        let payload = try Self.anthropicPayload(
            "You scored 7/10, so you are close. Try sounding more confident."
        )
        let service = AICoachChatService(
            keyedProviders: { [.anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in .success(payload) }
        )
        var providerChoice: CoachTurnProviderChoice?

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "How far off am I from sounding authoritative?")],
            systemPrompt: "You are Noum.",
            userContext: "RECENT: latest rep 7/10, 1 filler.",
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment,
            surface: .text,
            preferredTier: .claudeReasoning,
            onProviderChosen: { choice in
                providerChoice = choice
            }
        )

        switch outcome {
        case .reply(let text):
            #expect(text.lowercased().contains("not proven") || text.lowercased().contains("closer mechanically"))
        case .failure(let failure):
            #expect(Bool(false), "typed fallback should be accepted, got \(failure)")
        }
        #expect(providerChoice?.providerName == "Typed judgement fallback")
        #expect(providerChoice?.model == "CoachAssessment")
    }

    @MainActor
    @Test func typedFallbackUsesPressureFillerCloseShapeAfterQualityFailure() async throws {
        let payload = try Self.anthropicPayload(
            "You scored 10/10. Semantic words are fillers, so just stop saying um."
        )
        let service = AICoachChatService(
            keyedProviders: { [.anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in .success(payload) }
        )
        var providerChoice: CoachTurnProviderChoice?

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "How do I stop saying um under pressure?")],
            systemPrompt: "You are Noum.",
            userContext: "RECENT\n- Latest pressure rep: 6 fillers, mostly before the close.",
            turnDepth: .quickMove,
            assessment: Self.pressureFillerAssessment,
            surface: .text,
            preferredTier: .claudeReasoning,
            onProviderChosen: { choice in
                providerChoice = choice
            }
        )

        guard case .reply(let text) = outcome else {
            Issue.record("typed fallback should be accepted, got \(outcome)")
            return
        }
        #expect(text.contains("Your last pressure rep had 6 fillers"))
        #expect(text.contains("one silent beat before the final sentence"))
        #expect(text.contains("finish the ask"))
        #expect(!text.lowercased().contains("semantic words"))
        #expect(providerChoice?.providerName == "Typed judgement fallback")
        #expect(providerChoice?.model == "CoachAssessment")
    }

    @MainActor
    @Test func typedFallbackPressureFillerIntentHandlesEquivalentWording() async throws {
        let payload = try Self.anthropicPayload(
            "You scored 10/10. Just stop using fillers under pressure."
        )
        let service = AICoachChatService(
            keyedProviders: { [.anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in .success(payload) }
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "How do I stop fillers under pressure?")],
            systemPrompt: "You are Noum.",
            userContext: "RECENT\n- Latest pressure rep: 6 fillers, mostly before the close.",
            turnDepth: .quickMove,
            assessment: Self.pressureFillerAssessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        guard case .reply(let text) = outcome else {
            Issue.record("typed fallback should be accepted, got \(outcome)")
            return
        }
        #expect(text.contains("Your last pressure rep had 6 fillers"))
        #expect(text.contains("one silent beat before the final sentence"))
        #expect(!text.lowercased().contains("just stop"))
        #expect(!text.lowercased().contains("semantic words"))
    }

    @MainActor
    @Test func typedFallbackPressureFillerIntentDoesNotNeedExactCount() async throws {
        let payload = try Self.anthropicPayload(
            "Separate semantic words from filler words before cutting anything."
        )
        let service = AICoachChatService(
            keyedProviders: { [.anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in .success(payload) }
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "How do I stop saying um under pressure?")],
            systemPrompt: "You are Noum.",
            userContext: "RECENT\n- Latest pressure rep: fillers clustered before the close.",
            turnDepth: .quickMove,
            assessment: Self.pressureFillerAssessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        guard case .reply(let text) = outcome else {
            Issue.record("typed fallback should be accepted, got \(outcome)")
            return
        }
        #expect(text.contains("Under pressure, do not fight the urge directly"))
        #expect(text.contains("one silent beat before the final sentence"))
        #expect(text.contains("finish the ask"))
        #expect(!text.lowercased().contains("semantic words"))
        #expect(!text.contains("Your last pressure rep had 6 fillers"))
    }

    @MainActor
    @Test func typedFallbackPressureFillerIntentDoesNotSwallowSemanticCorrection() async throws {
        let payload = try Self.anthropicPayload(
            "Cut every like under pressure. It is all filler."
        )
        let service = AICoachChatService(
            keyedProviders: { [.anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in .success(payload) }
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "I meant like as a comparison under pressure. Should I cut it?")],
            systemPrompt: "You are Noum.",
            userContext: "RECENT\n- Latest pressure rep: 6 fillers, mostly before the close.",
            turnDepth: .quickMove,
            assessment: Self.pressureFillerAssessment,
            surface: .text,
            preferredTier: .claudeReasoning
        )

        guard case .reply(let text) = outcome else {
            Issue.record("typed fallback should be accepted, got \(outcome)")
            return
        }
        #expect(text.contains("semantic comparison"))
        #expect(text.contains("I should not count it as filler"))
        #expect(!text.contains("Your last pressure rep had 6 fillers"))
        #expect(!text.contains("final sentence"))
    }

    @MainActor
    @Test func typedFallbackUsesAttunedNotEasyRepairAfterQualityFailure() async throws {
        let payload = try Self.anthropicPayload(
            "You scored 10/10. It is easy: just be confident and keep practicing."
        )
        let service = AICoachChatService(
            keyedProviders: { [.anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in .success(payload) }
        )
        var providerChoice: CoachTurnProviderChoice?

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "It's not easy.")],
            systemPrompt: "You are Noum.",
            userContext: "RECENT\n- Latest pressure rep: 1 filler, disagreement arrived after setup.",
            turnDepth: .trustRepair,
            assessment: Self.pressureDifficultyTrustRepairAssessment,
            surface: .text,
            preferredTier: .claudeReasoning,
            onProviderChosen: { choice in
                providerChoice = choice
            }
        )

        guard case .reply(let text) = outcome else {
            Issue.record("typed fallback should be accepted, got \(outcome)")
            return
        }
        #expect(text.contains("Fair push: no, it is not easy"))
        #expect(text.contains("sentence one carries the social risk"))
        #expect(text.contains("say only the disagreement and one calm reason"))
        #expect(text.contains("stop before defending it"))
        #expect(!text.contains("I made the move sound easier"))
        #expect(!text.contains("Your last rep gives one safe signal"))
        #expect(providerChoice?.providerName == "Typed judgement fallback")
        #expect(providerChoice?.model == "CoachAssessment")
    }

    private static func anthropicPayload(_ text: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "content": [
                [
                    "type": "text",
                    "text": text
                ]
            ],
            "stop_reason": "end_turn"
        ])
    }

    private static let deepAssessment = CoachAssessment(
        turnDepth: .deepAssessment,
        surface: .text,
        questionRestatement: "How far off am I from sounding authoritative?",
        directVerdict: "You are closer mechanically than you are to fully sounding authoritative.",
        confidence: 0.62,
        evidenceUsed: [
            "latest rep: Timed, 7/10, 1 fillers, 60s",
            "pace estimate: 145 WPM"
        ],
        rubricScores: [],
        missingEvidence: [
            "Need repeated evidence across more than one clean rep before calling the user close overall.",
            "Need pressure-mode evidence before treating the goal as ready for real stakes."
        ],
        nextProofTest: "Record a 75-second answer where sentence one gives the verdict, sentence two gives one reason, and the final sentence names the ask.",
        responseMode: .expandable
    )

    private static let pressureFillerAssessment = CoachAssessment(
        turnDepth: .quickMove,
        surface: .text,
        questionRestatement: "How do I stop saying um under pressure?",
        directVerdict: "Pressure is the next lever: repeat the same answer under a timer and protect the sentence where it leaks.",
        confidence: 0.44,
        evidenceUsed: [
            "latest rep: Pressure, 7/10, 6 fillers, 60s"
        ],
        rubricScores: [],
        missingEvidence: [],
        nextProofTest: "Repeat the latest pressure rep with 6 fillers: replace the filler urge with one silent beat before the final sentence, then finish the ask.",
        responseMode: .immediateOnly
    )

    private static let pressureDifficultyTrustRepairAssessment = CoachAssessment(
        turnDepth: .trustRepair,
        surface: .text,
        questionRestatement: "It's not easy.",
        directVerdict: "The repair is to name the miss first, then answer with one useful move.",
        confidence: 0.40,
        evidenceUsed: [
            "trust repair signal: I made the move sound easier than it feels under pressure"
        ],
        rubricScores: [],
        missingEvidence: [],
        nextProofTest: "Test a smaller version in the next rep: say only the disagreement and one calm reason, then stop before defending it.",
        responseMode: .immediateOnly,
        toneMode: .repair,
        repairFocus: "I made the move sound easier than it feels under pressure"
    )
}

@Suite("CoachProvisionalReadEligibilityTests")
struct CoachProvisionalReadEligibilityTests {

    @Test func quickTextTurnDoesNotShowLocalProvisionalRead() {
        #expect(CoachReplyPipeline.shouldShowProvisionalCoachRead(
            turnDepth: .quickMove,
            surface: .text,
            responseMode: .immediateOnly,
            realtimeCoachModeEnabled: true
        ) == false)
    }

    @Test func deepTextTurnCanShowLocalProvisionalRead() {
        #expect(CoachReplyPipeline.shouldShowProvisionalCoachRead(
            turnDepth: .deepAssessment,
            surface: .text,
            responseMode: .expandable,
            realtimeCoachModeEnabled: true
        ))
    }

    @Test func liveTurnCanShowLocalProvisionalReadEvenWhenImmediateOnly() {
        #expect(CoachReplyPipeline.shouldShowProvisionalCoachRead(
            turnDepth: .groundedRead,
            surface: .live,
            responseMode: .immediateOnly,
            realtimeCoachModeEnabled: true
        ))
    }

    @Test func realtimeFlagDisablesLocalProvisionalRead() {
        #expect(CoachReplyPipeline.shouldShowProvisionalCoachRead(
            turnDepth: .deepAssessment,
            surface: .text,
            responseMode: .expandable,
            realtimeCoachModeEnabled: false
        ) == false)
    }

    @Test func proofTestHashIsStableAndNormalized() {
        let first = CoachReplyPipeline.proofTestHash(
            for: " Record one verdict-first rep. "
        )
        let second = CoachReplyPipeline.proofTestHash(
            for: "record one verdict-first rep."
        )
        let different = CoachReplyPipeline.proofTestHash(
            for: "Use one silent beat after the verdict."
        )

        #expect(first == second)
        #expect(first != different)
    }

    @Test func contentRejectedFallbackUsesCleanAssessmentReadOnlyForQualityGateFailure() {
        let assessment = CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: "What should I practice?",
            directVerdict: "Practice the boundary sentence only.",
            confidence: 0.70,
            evidenceUsed: ["latest rep: disagreement arrived after setup"],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Say the disagreement in sentence one, give one calm reason, then stop.",
            responseMode: .immediateOnly,
            toneMode: .prescribe
        )

        let fallback = CoachReplyPipeline.contentRejectedFallbackText(
            for: .failure(.contentRejected),
            assessment: assessment,
            turnDepth: .quickMove,
            surface: .text,
            previousCoachReply: nil
        )
        let noProviderFallback = CoachReplyPipeline.contentRejectedFallbackText(
            for: .failure(.noProvider),
            assessment: assessment,
            turnDepth: .quickMove,
            surface: .text,
            previousCoachReply: nil
        )
        let missingAssessmentFallback = CoachReplyPipeline.contentRejectedFallbackText(
            for: .failure(.contentRejected),
            assessment: nil,
            turnDepth: .quickMove,
            surface: .text,
            previousCoachReply: nil
        )

        #expect(fallback?.contains("Practice the boundary sentence only") == true)
        #expect(fallback?.contains("Say the disagreement") == true)
        #expect(fallback?.contains("Try this next:") == false)
        #expect(noProviderFallback == nil)
        #expect(missingAssessmentFallback == nil)
    }

    @Test func pipelineFinalizedOutcomeStripsFallbackMetricResidue() {
        let outcome = CoachReplyPipeline.finalizedOutcome(
            .reply("The opening is the next lever. The signal I can use is Pressure Drill, 1/10, 0 fillers, 0s. Try this next: end the next rep on the exact ask."),
            latestUserTurn: "Give me one direct move for my next update.",
            turnDepth: .quickMove
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected finalized reply")
            return
        }
        #expect(text.contains("1/10") == false)
        #expect(text.contains("0 fillers") == false)
        #expect(text.contains("The signal I can use is Pressure Drill.") == false)
        #expect(text.contains("Try this next"))
    }
}

@MainActor
@Suite("CoachReplyPipelineProvisionalReadTests", .serialized)
struct CoachReplyPipelineProvisionalReadTests {

    @Test func liveGenerateSurfacesImmediateCoachReadBeforeProviderCompletion() async {
        let suiteName = "CoachReplyPipelineProvisionalReadTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        CoachAssessmentCache.shared.invalidate()
        defer {
            CoachAssessmentCache.shared.invalidate()
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AskNoumStore(defaults: defaults, accountIDProvider: { "pipeline-provisional" })
        let ids = store.appendUserTurn("How far off am I from sounding authoritative in a live call?")
        let noProviderService = AICoachChatService(
            keyedProviders: { [] },
            keyLookup: { _ in nil },
            localeSupportsAI: { true },
            diagnosticRecorder: { _, _, _, _, _, _, _, _ in }
        )

        var callbackText: String?
        var callbackSawPendingCoachRow = false
        var callbackMetadata: CoachTurnMetadata?
        let outcome = await CoachReplyPipeline.generate(
            coachID: ids.coachID,
            surface: .live,
            store: store,
            coachService: noProviderService,
            judgementPassEnabled: true,
            realtimeCoachModeEnabled: true,
            onProvisionalCoachReadVisible: { text in
                callbackText = text
                let pending = store.messages.first { $0.id == ids.coachID }
                callbackSawPendingCoachRow = pending?.role == .coach && pending?.isPending == true
                callbackMetadata = pending?.metadata
            }
        )

        switch outcome {
        case .failure(.noProvider):
            break
        default:
            #expect(Bool(false), "Expected injected no-provider service to finish with noProvider, got \(outcome)")
        }

        #expect(callbackText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        #expect(callbackSawPendingCoachRow)
        #expect(callbackMetadata?.immediateCoachReadShown == true)
        #expect(callbackMetadata?.timeToFirstVisibleTokenMs != nil)
        #expect(callbackMetadata?.timeToFirstVisibleTokenSource == .localImmediateRead)
        #expect(callbackMetadata?.surface == .live)

        #expect(store.messages.first { $0.id == ids.coachID } == nil)
        #expect(store.messages.filter { $0.role == .user }.count == 1)
        #expect(store.messages.allSatisfy { $0.role != .systemNotice })
        #expect(store.lastFailure == .noProvider)
        #expect(!store.isAwaitingReply)
    }

    @Test func successfulTextTurnsUsePriorAssessmentToVaryNextProofTest() async {
        let suiteName = "CoachReplyPipelineHistoryProgressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        CoachAssessmentCache.shared.invalidate()
        UserTrajectoryCache.shared.invalidate()
        defer {
            CoachAssessmentCache.shared.invalidate()
            UserTrajectoryCache.shared.invalidate()
            defaults.removePersistentDomain(forName: suiteName)
        }

        let scriptedHTTP = CoachReplyPipelineScriptedHTTP(replies: [
            """
            Your latest rep points at pacing: the structure is there, but it needs one planned pause. Next rep, put the verdict first, hold one silent beat, then give one reason and stop. That tests whether control comes from silence instead of extra wording.
            """,
            """
            Your latest rep still makes pacing the useful lever, but the proof should change now. Next rep, place one beat after the verdict, then finish the reason in one sentence. That tests whether the pause holds without adding more setup.
            """
        ])
        let service = AICoachChatService(
            keyedProviders: { [.openAI] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { provider, endpoint, key, body in
                await scriptedHTTP.next(provider: provider, endpoint: endpoint, key: key, body: body)
            },
            diagnosticRecorder: { _, _, _, _, _, _, _, _ in }
        )
        let store = AskNoumStore(defaults: defaults, accountIDProvider: { "pipeline-history" })

        let firstIDs = store.appendUserTurn("How do I slow down without sounding unsure?")
        let firstOutcome = await CoachReplyPipeline.generate(
            coachID: firstIDs.coachID,
            surface: .text,
            store: store,
            coachService: service,
            judgementPassEnabled: true,
            realtimeCoachModeEnabled: true
        )
        guard case .reply = firstOutcome else {
            Issue.record("Expected first scripted provider reply, got \(firstOutcome)")
            return
        }

        let firstCoach = store.messages.first { $0.id == firstIDs.coachID }
        let firstProof = firstCoach?.metadata?.assessment?.nextProofTest
        #expect(firstCoach?.role == .coach)
        #expect(firstCoach?.metadata?.turnDepth == .quickMove)
        #expect(firstCoach?.metadata?.assessmentCacheHit == false)
        #expect(firstCoach?.metadata?.timeToFirstVisibleTokenSource == .finalReplyCommit)
        #expect(firstCoach?.metadata?.qualityGateEvents?.isEmpty == false)
        #expect(firstProof?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)

        let secondIDs = store.appendUserTurn("How do I slow down without sounding unsure?")
        let secondOutcome = await CoachReplyPipeline.generate(
            coachID: secondIDs.coachID,
            surface: .text,
            store: store,
            coachService: service,
            judgementPassEnabled: true,
            realtimeCoachModeEnabled: true
        )
        guard case .reply = secondOutcome else {
            Issue.record("Expected second scripted provider reply, got \(secondOutcome)")
            return
        }

        let secondCoach = store.messages.first { $0.id == secondIDs.coachID }
        let secondProof = secondCoach?.metadata?.assessment?.nextProofTest
        #expect(secondCoach?.role == .coach)
        #expect(secondCoach?.metadata?.turnDepth == .quickMove)
        #expect(secondCoach?.metadata?.assessmentCacheHit == false)
        #expect(secondCoach?.metadata?.timeToFirstVisibleTokenSource == .finalReplyCommit)
        #expect(secondCoach?.metadata?.proofTestRecentlyRepeated == false)
        #expect(secondCoach?.metadata?.qualityGateEvents?.isEmpty == false)
        #expect(secondProof?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        #expect(secondProof != firstProof)
        #expect(await scriptedHTTP.callCount == 2)
    }

    private actor CoachReplyPipelineScriptedHTTP {
        private var replies: [String]
        private(set) var callCount = 0

        init(replies: [String]) {
            self.replies = replies
        }

        func next(
            provider: CoachChatProvider,
            endpoint: URL,
            key: String,
            body: [String: Any]
        ) -> AICoachChatService.ProviderHTTPResult {
            callCount += 1
            guard !replies.isEmpty else {
                return .refused(status: 500, retryAfter: nil)
            }
            return .success(Self.openAIData(replies.removeFirst()))
        }

        private static func openAIData(_ content: String) -> Data {
            let payload: [String: Any] = [
                "choices": [
                    [
                        "message": ["content": content],
                        "finish_reason": "stop"
                    ]
                ]
            ]
            return try! JSONSerialization.data(withJSONObject: payload)
        }
    }
}

@Suite("CoachKnowledgeRetrievalPolicyTests")
struct CoachKnowledgeRetrievalPolicyTests {

    @Test func liveSurfaceDisablesSemanticRerankEvenWhenEnabled() {
        #expect(CoachReplyPipeline.shouldUseSemanticKnowledgeRerank(
            surface: .live,
            semanticRerankEnabled: true
        ) == false)
    }

    @Test func textSurfaceAllowsSemanticRerankWhenEnabled() {
        #expect(CoachReplyPipeline.shouldUseSemanticKnowledgeRerank(
            surface: .text,
            semanticRerankEnabled: true
        ))
    }

    @Test func flagDisablesSemanticRerankOnEverySurface() {
        #expect(CoachReplyPipeline.shouldUseSemanticKnowledgeRerank(
            surface: .text,
            semanticRerankEnabled: false
        ) == false)
        #expect(CoachReplyPipeline.shouldUseSemanticKnowledgeRerank(
            surface: .live,
            semanticRerankEnabled: false
        ) == false)
    }
}

@MainActor
@Suite("AskNoumProvisionalReadTests")
struct AskNoumProvisionalReadTests {

    @Test func provisionalReadStaysPendingAndOutOfReplay() {
        let defaults = UserDefaults(suiteName: "AskNoumProvisionalReadTests.\(UUID().uuidString)")!
        defaults.removePersistentDomain(forName: defaultsSuiteName(defaults))
        let store = AskNoumStore(defaults: defaults, accountIDProvider: { "tester" })
        let ids = store.appendUserTurn("How far off am I?")

        store.setProvisionalCoachRead(
            id: ids.coachID,
            text: "You are closer mechanically than authoritatively. Proof test: record one verdict-first rep."
        )

        let pending = store.messages.first { $0.id == ids.coachID }
        #expect(pending?.isPending == true)
        #expect(pending?.text.contains("closer mechanically") == true)
        #expect(!store.replayForModel.contains { $0.id == ids.coachID })
    }

    @Test func provisionalReadStaysVisibleWhenRevealIsPrearmed() {
        let id = UUID()
        let message = CoachMessage(
            id: id,
            role: .coach,
            text: "You are closer mechanically than authoritatively. Proof test: record one verdict-first rep.",
            isPending: true
        )

        #expect(AskNoumCoachVisibleText.text(
            for: message,
            revealingMessageID: id,
            revealedText: ""
        ).contains("closer mechanically"))
    }

    @Test func landedReplyUsesRevealPrefixWhenPrearmed() {
        let id = UUID()
        let message = CoachMessage(
            id: id,
            role: .coach,
            text: "Full final answer",
            isPending: false
        )

        #expect(AskNoumCoachVisibleText.text(
            for: message,
            revealingMessageID: id,
            revealedText: "Full"
        ) == "Full")
    }

    private func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        // Test-only helper. UserDefaults does not expose suiteName; this is only
        // used immediately after construction, where removePersistentDomain on
        // a random name is a defensive no-op if the suite is already empty.
        "AskNoumProvisionalReadTests"
    }
}
