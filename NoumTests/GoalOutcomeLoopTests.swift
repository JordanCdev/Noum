import Foundation
import Testing
@testable import Noum

@Suite("M26 goal outcome loop")
struct GoalOutcomeLoopTests {
    @Test func everyVoiceHasAnExplicitNormalizedRubric() {
        let rubrics = SpeakingStyleGoal.allCases.map(GoalRubricStore.rubric(for:))
        #expect(Set(rubrics.map(\.goalID)).count == SpeakingStyleGoal.allCases.count)
        for rubric in rubrics {
            #expect(abs(rubric.defaultWeights.values.reduce(0, +) - 1) < 0.000_001)
            #expect(Set(rubric.defaultWeights.keys) == Set(rubric.dimensions.map(\.id)))
            #expect((rubric.establishedEvidenceFloor ?? 0) >= 0.65)
        }
    }

    @Test func warmAndStorytellingDoNotUseAuthorityWeights() {
        let authority = GoalRubricStore.rubric(for: .authoritative)
        let warm = GoalRubricStore.rubric(for: .warm)
        let story = GoalRubricStore.rubric(for: .storytelling)
        #expect(warm.defaultWeights["hedge_control"]! < authority.defaultWeights["hedge_control"]!)
        #expect(story.defaultWeights["salience"]! > authority.defaultWeights["salience"]!)
        #expect(story.defaultWeights["verdict_first"]! < authority.defaultWeights["verdict_first"]!)
    }

    @Test func outcomeReadIsDeterministicAndQualitative() {
        let assessment = makeAssessment(confidence: 0.76, evidence: ["The latest rep led with the decision.", "The close stopped cleanly."])
        let first = GoalOutcomeRead.make(style: .executive, assessment: assessment)
        let second = GoalOutcomeRead.make(style: .executive, assessment: assessment)
        #expect(first == second)
        #expect(first.evidenceLevel == .established)
        #expect(first.strongestDimension?.dimensionID == "clean_close")
        #expect(first.nextDimension?.dimensionID == "hedge_control")
    }

    @Test func outcomeReadHonoursEachGoalEvidenceFloor() {
        let assessment = makeAssessment(
            confidence: 0.70,
            evidence: ["The latest rep led with the decision.", "The close stopped cleanly."]
        )

        // Concise uses a calibrated 0.68 floor, while executive presence
        // requires 0.72 before the same evidence can be called established.
        #expect(GoalOutcomeRead.make(style: .concise, assessment: assessment).evidenceLevel == .established)
        #expect(GoalOutcomeRead.make(style: .executive, assessment: assessment).evidenceLevel == .forming)
    }

    @Test func goalOutcomeRequiresAnExplicitVoiceChoice() {
        let unchosen = makeProfile(style: .warm, chosenStyle: nil)
        let chosen = makeProfile(style: .warm, chosenStyle: .warm)
        #expect(GoalOutcomeEngine.selectedGoal(from: unchosen) == nil)
        #expect(GoalOutcomeEngine.selectedGoal(from: chosen) == .warm)
        #expect(AIRewriteService.selectedVoice(from: unchosen) == nil)
        #expect(AIRewriteService.selectedVoice(from: chosen) == .warm)
    }

    @Test func weakEvidenceNeverBecomesAnIdentityVerdict() {
        let read = GoalOutcomeRead.make(
            style: .persuasive,
            assessment: makeAssessment(confidence: 0.24, evidence: [])
        )
        #expect(read.evidenceLevel == .insufficient)
        #expect(read.movement == .emerging)
    }

    @Test func repeatedPromisingOutcomesProduceEarlyImprovement() {
        let outcomes = (0..<2).map { index in
            RecommendationOutcome(
                id: UUID(), fingerprint: "goal", title: "Tighten the close",
                focus: "Clean close", target: "End with the ask", mode: .timed,
                sessionID: UUID(), followed: true,
                completedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                scoreDelta: 1, hasComparableScore: true, fillerDelta: -1,
                durationDelta: 0, goal: .concise, targetDimensionID: "clean_close",
                goalFollowUpResult: .earlyImprovement
            )
        }
        let read = GoalOutcomeRead.make(
            style: .concise,
            assessment: makeAssessment(confidence: 0.8, evidence: ["The close landed.", "The ask was explicit."]),
            outcomes: outcomes
        )
        #expect(read.movement == .improving)
        #expect(read.latestFollowUpResult == .earlyImprovement)
    }

    @Test func showcaseSeedUsesComparableEvidenceBeforeOfferingAMilestone() {
        let fixture = DevSeedData.coachIntelligenceFixture(for: .improvingIntermediate)
        let comparable = fixture.recommendationOutcomes.filter {
            $0.goal == .warm && $0.targetDimensionID == "salience"
        }
        #expect(comparable.count >= 2)
        #expect(comparable.filter { $0.goalFollowUpResult == .earlyImprovement }.count >= 2)

        let read = GoalOutcomeEngine.read(
            profile: fixture.profile,
            baseline: fixture.baseline,
            rating: fixture.rating,
            sessions: fixture.sessions,
            coachMemory: fixture.memory,
            outcomes: fixture.recommendationOutcomes
        )
        #expect(read?.evidenceLevel == .established)
        #expect(read?.movement == .improving)
        #expect(read.map { GoalMilestoneShare.isAvailable(for: $0) } == true)
    }

    @Test func milestoneShareIsEvidenceBoundedAndTranscriptFree() {
        let established = GoalOutcomeRead.make(
            style: .concise,
            assessment: makeAssessment(
                confidence: 0.82,
                evidence: ["The latest rep led with the decision.", "The close stopped cleanly."]
            ),
            outcomes: [
                RecommendationOutcome(
                    id: UUID(), fingerprint: "goal", title: "Tighten the close",
                    focus: "Clean close", target: "End with the ask", mode: .timed,
                    sessionID: UUID(), followed: true, completedAt: Date(),
                    scoreDelta: 1, hasComparableScore: true, fillerDelta: -1,
                    durationDelta: 0, goal: .concise, targetDimensionID: "clean_close",
                    goalFollowUpResult: .earlyImprovement
                ),
                RecommendationOutcome(
                    id: UUID(), fingerprint: "goal-two", title: "Tighten the close",
                    focus: "Clean close", target: "End with the ask", mode: .timed,
                    sessionID: UUID(), followed: true, completedAt: Date(timeIntervalSince1970: 1),
                    scoreDelta: 1, hasComparableScore: true, fillerDelta: -1,
                    durationDelta: 0, goal: .concise, targetDimensionID: "clean_close",
                    goalFollowUpResult: .earlyImprovement
                ),
            ]
        )
        #expect(GoalMilestoneShare.isAvailable(for: established))
        let message = GoalMilestoneShare.message(for: established)
        #expect(message.contains("concise"))
        #expect(!message.contains("The latest rep led with the decision."))
        #expect(!message.contains("0.82"))

        let thin = GoalOutcomeRead.make(
            style: .concise,
            assessment: makeAssessment(confidence: 0.28, evidence: [])
        )
        #expect(!GoalMilestoneShare.isAvailable(for: thin))

        let mixed = GoalOutcomeRead.make(
            style: .concise,
            assessment: makeAssessment(
                confidence: 0.82,
                evidence: ["The latest rep led with the decision.", "The close stopped cleanly."]
            ),
            outcomes: [
                RecommendationOutcome(
                    id: UUID(), fingerprint: "mixed", title: "Tighten the close",
                    focus: "Clean close", target: "End with the ask", mode: .timed,
                    sessionID: UUID(), followed: true, completedAt: Date(),
                    scoreDelta: 1, hasComparableScore: true, fillerDelta: 1,
                    durationDelta: 0, goal: .concise, targetDimensionID: "clean_close",
                    goalFollowUpResult: .mixed
                ),
            ]
        )
        #expect(!GoalMilestoneShare.isAvailable(for: mixed))
    }

    @Test func followUpClassificationStaysSoftOnThinOrConflictingEvidence() {
        #expect(RecommendationLearningStore.goalFollowUpResult(
            followed: true, comparableScoreDelta: nil, fillerDelta: 0, comparablePaceDelta: nil
        ) == .needsMoreEvidence)
        #expect(RecommendationLearningStore.goalFollowUpResult(
            followed: true, comparableScoreDelta: 1, fillerDelta: 1, comparablePaceDelta: nil
        ) == .mixed)
        #expect(RecommendationLearningStore.goalFollowUpResult(
            followed: false, comparableScoreDelta: 1, fillerDelta: -2, comparablePaceDelta: nil
        ) == nil)
    }

    @Test func recommendationOutcomeRequiresExplicitAcceptanceAndMatchingMode() {
        let untapped = recommendationExposure(mode: .timed, tappedAt: nil)
        let tapped = recommendationExposure(mode: .timed, tappedAt: Date())

        #expect(!RecommendationLearningStore.followedPrescription(
            untapped,
            completedMode: .timed
        ))
        #expect(RecommendationLearningStore.followedPrescription(
            tapped,
            completedMode: .timed
        ))
        #expect(!RecommendationLearningStore.followedPrescription(
            tapped,
            completedMode: .ahCounter
        ))
    }

    @Test func legacyUntappedExposureFailsClosedForOutcomeAttribution() throws {
        let json = """
        {"fingerprint":"legacy","title":"Timed rep","focus":"Structure","target":"Land one clear point","mode":"timed","isAIBacked":false,"shownAt":0}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let exposure = try decoder.decode(RecommendationExposure.self, from: json)

        #expect(exposure.tappedAt == nil)
        #expect(!RecommendationLearningStore.followedPrescription(
            exposure,
            completedMode: .timed
        ))
    }

    @Test func preM26OutcomeStillDecodes() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","fingerprint":"old","title":"Old","mode":"timed","sessionID":"00000000-0000-0000-0000-000000000002","followed":true,"completedAt":0,"scoreDelta":0,"fillerDelta":0,"durationDelta":0}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(RecommendationOutcome.self, from: json)
        #expect(decoded.goal == nil)
        #expect(decoded.targetDimensionID == nil)
        #expect(decoded.goalFollowUpResult == nil)
    }

    @Test func rewriteEligibilitySuppressesWeakOrSensitiveEvidence() {
        #expect(AIRewriteService.eligibility(
            transcript: "I think the proposal should start next week because the customer evidence is clear and the team is ready.",
            confidence: 0.9
        ) == .eligible)
        #expect(AIRewriteService.eligibility(
            transcript: "A short fragment.",
            confidence: 0.9
        ) == .tooShort)
        #expect(AIRewriteService.eligibility(
            transcript: "This transcript is long enough to inspect but its recognition confidence is too weak to rewrite honestly.",
            confidence: 0.3
        ) == .lowConfidence)
        #expect(AIRewriteService.eligibility(
            transcript: "Contact me at jordan@example.com because this sentence otherwise contains enough words for the rewrite gate.",
            confidence: 0.9
        ) == .containsSensitiveIdentifier)
        #expect(AIRewriteService.eligibility(
            transcript: "word word word word word word word word word word word word word word word word",
            confidence: 0.9
        ) == .semanticallyAmbiguous)
    }

    @Test func onDeviceRewriteIsDeterministicTransparentAndVocabularyBounded() throws {
        let transcript = "Um, so I think the release should start next week because the support team has time to prepare. The customer message needs one clear decision."
        let light = try #require(AIRewriteService.onDeviceRewrite(
            transcript: transcript,
            weakness: .opening,
            voice: .authoritative,
            intensity: .light,
            confidence: 0.9
        ))
        let medium = try #require(AIRewriteService.onDeviceRewrite(
            transcript: transcript,
            weakness: .opening,
            voice: .authoritative,
            intensity: .medium,
            confidence: 0.9
        ))
        let strong = try #require(AIRewriteService.onDeviceRewrite(
            transcript: transcript,
            weakness: .opening,
            voice: .authoritative,
            intensity: .strong,
            confidence: 0.9
        ))

        #expect(light.source == .onDevice)
        #expect(medium.source == .onDevice)
        #expect(strong.source == .onDevice)
        #expect(light.text.lowercased().contains("um") == false)
        #expect(medium.text.lowercased().hasPrefix("i think"))
        #expect(strong.text.lowercased().hasPrefix("the release"))
        #expect(Set([light.text, medium.text, strong.text]).count == 3)

        let sourceWords = Set(transcript.lowercased().split(whereSeparator: { !$0.isLetter }))
        let rewrittenWords = Set(strong.text.lowercased().split(whereSeparator: { !$0.isLetter }))
        #expect(rewrittenWords.isSubset(of: sourceWords))
    }

    @Test func onDeviceRewriteWithholdsCosmeticOrUnsafeEdits() {
        #expect(AIRewriteService.onDeviceRewrite(
            transcript: "The decision is ready for review. The team can respond today.",
            weakness: .opening,
            voice: .warm,
            intensity: .strong,
            confidence: 0.9
        ) == nil)
    }

    @Test func coachContextUsesObservationalGoalFollowUpLanguage() {
        let outcome = RecommendationOutcome(
            id: UUID(), fingerprint: "goal", title: "Tighten the close",
            focus: "Clean close", target: "End with the ask", mode: .timed,
            sessionID: UUID(), followed: true, completedAt: Date(),
            scoreDelta: 1, hasComparableScore: true, fillerDelta: -1,
            durationDelta: 0, goal: .executive, targetDimensionID: "clean_close",
            goalFollowUpResult: .earlyImprovement
        )
        let lines = RecommendationResponseAnalyzer.promptLines(from: [outcome])
        #expect(lines.first?.contains("this rep showed early signs of improvement") == true)
        #expect(lines.first?.contains("not proof that the drill caused") == true)
    }

    private func makeAssessment(confidence: Double, evidence: [String]) -> CoachAssessment {
        CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "Goal read",
            directVerdict: "A bounded read.",
            confidence: confidence,
            evidenceUsed: evidence,
            rubricScores: [
                RubricScore(dimensionID: "clean_close", label: "Clean close", score: 0.82, confidence: confidence, evidence: ["The close landed."], missingEvidence: nil),
                RubricScore(dimensionID: "hedge_control", label: "Hedge control", score: 0.42, confidence: confidence, evidence: ["Two hedges remained."], missingEvidence: "Need a cleaner claim.")
            ],
            missingEvidence: [],
            nextProofTest: "Repeat the answer and finish with the ask.",
            responseMode: .expandable
        )
    }

    private func recommendationExposure(
        mode: PracticeMode,
        tappedAt: Date?
    ) -> RecommendationExposure {
        RecommendationExposure(
            fingerprint: "goal-outcome-attribution",
            title: "One focused rep",
            focus: "Structure",
            target: "Land one clear point",
            mode: mode,
            isAIBacked: false,
            shownAt: Date(timeIntervalSince1970: 0),
            tappedAt: tappedAt
        )
    }

    private func makeProfile(
        style: SpeakingStyleGoal,
        chosenStyle: SpeakingStyleGoal?
    ) -> CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: .moreConcise,
            confidenceLevel: .rebuilding,
            biggestChallenge: .rambling,
            desiredOutcome: .concise,
            speakingStyleGoal: style,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: "",
            chosenStyleGoal: chosenStyle
        )
    }
}
