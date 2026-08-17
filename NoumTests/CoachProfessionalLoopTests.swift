import Foundation
import Testing
@testable import Noum

@Suite("Professional coach loop")
struct CoachProfessionalLoopTests {

    @Test("Intervention catalogue carries a complete professional contract")
    func interventionCatalogueIsComplete() {
        #expect(CoachReasoningPass.interventionCatalogue.count >= 6)
        #expect(CoachReasoningPass.interventionCatalogue.count <= 14)
        #expect(Set(CoachReasoningPass.interventionCatalogue.map(\.id)).count ==
            CoachReasoningPass.interventionCatalogue.count)
        for intervention in CoachReasoningPass.interventionCatalogue {
            #expect(!intervention.whenToUse.isEmpty)
            #expect(!intervention.whenNotToUse.isEmpty)
            #expect(!intervention.modelLine.isEmpty)
            #expect(!intervention.drill.isEmpty)
            #expect(!intervention.passCondition.isEmpty)
            #expect(!intervention.transferPrompt.isEmpty)
        }
    }

    @Test("Decision plan is structured before prose and chooses a demonstration")
    func decisionPlanHasEightRequiredFields() {
        let plan = CoachReasoningPass.decisionPlan(for: Self.answerFirstAssessment)

        #expect(plan.situation == "How do I make the answer land sooner?")
        #expect(!plan.stakes.isEmpty)
        #expect(!plan.emotion.isEmpty)
        #expect(!plan.observedBehavior.isEmpty)
        #expect(!plan.exactEvidence.isEmpty)
        #expect(plan.skillStage == .establish)
        #expect(plan.chosenIntervention.contains("Answer first"))
        #expect(!plan.successTest.isEmpty)
        #expect(plan.modelLine?.contains("recommendation") == true)
        #expect(plan.replyPosture == .coachedAttempt)
    }

    @Test("Last-three novelty advances the move instead of repeating the drill")
    func interventionNoveltyAdvancesStage() {
        let firstMove = CoachReasoningPass.interventionCatalogue
            .first { $0.id == "answer-first" }!
            .drill
        let choice = CoachReasoningPass.selectIntervention(
            userQuestion: "How do I make the answer land sooner?",
            preferredDimensionID: "verdict_first",
            trajectory: Self.trajectory,
            turnDepth: .quickMove,
            replyPosture: .coachedAttempt,
            recentMoves: [firstMove]
        )

        #expect(choice?.intervention.id == "answer-first")
        #expect(choice?.stage == .stretch)
        #expect(choice?.move != firstMove)
        #expect(choice?.move.contains("passes when") == true)
    }

    @Test("Low-capacity emotional turn may stop at presence")
    func lowCapacityUsesPresenceOnly() {
        let posture = CoachReplyPosture.resolve(
            userText: "I'm exhausted and I can't do another rep."
        )
        let choice = CoachReasoningPass.selectIntervention(
            userQuestion: "I'm exhausted and I can't do another rep.",
            preferredDimensionID: "verdict_first",
            trajectory: Self.trajectory,
            turnDepth: .trustRepair,
            replyPosture: posture,
            recentMoves: []
        )

        #expect(posture == .presenceOnly)
        #expect(choice?.intervention.id == "presence-before-practice")
        #expect(choice?.stage == .recover)
    }

    @Test("Low-capacity disclosure blocks a well-meaning new drill")
    func lowCapacityDrillFailsClosed() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "That sounds exhausting. Run one shorter rep and keep only the first sentence.",
            previousCoachReply: nil,
            latestUserTurn: "I'm tired. I don't have it in me today.",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: 0.6
        )

        #expect(verdict.issues.contains(.vulnerablePushbackQuestionBurden))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText?.contains("Do not force another rep") == true)
        #expect(verdict.fallbackText?.contains("Run one") == false)
    }

    @Test("Presence without another demand remains a complete answer")
    func lowCapacityPresencePasses() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "That sounds exhausting. Do not force another rep today; come back when you have room.",
            previousCoachReply: nil,
            latestUserTurn: "I'm tired. I don't have it in me today.",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: 0.6
        )

        #expect(!verdict.issues.contains(.vulnerablePushbackQuestionBurden))
        #expect(!verdict.blocked)
    }

    @Test("General craft question gets a plan without fake personal evidence")
    func generalQuestionGetsNonPersonalPlan() {
        let plan = CoachReasoningPass.generalDecisionPlan(
            userQuestion: "How do I add depth without rambling?"
        )

        #expect(plan.observedBehavior.contains("No personal delivery claim"))
        #expect(plan.exactEvidence.contains("No personal rep evidence"))
        #expect(plan.chosenIntervention.contains("One proof point"))
        #expect(plan.modelLine != nil)
        #expect(plan.replyPosture == .coachedAttempt)
    }

    @Test("Craft knowledge gets a direct answer-only posture")
    func craftKnowledgeDoesNotForcePractice() {
        let plan = CoachReasoningPass.generalDecisionPlan(
            userQuestion: "What is active listening?"
        )

        #expect(plan.replyPosture == .informationOnly)
        #expect(plan.chosenIntervention.contains("Answer-only craft explanation"))
        #expect(plan.modelLine == nil)
        #expect(plan.invitation == nil)

        let applied = CoachReasoningPass.generalDecisionPlan(
            userQuestion: "How do I listen better in a tense meeting?"
        )
        #expect(applied.replyPosture == .coachedAttempt)
        #expect(applied.chosenIntervention.contains("Close the listening loop"))
        #expect(applied.modelLine != nil)
    }

    @Test("Tell-me knowledge requests cover cadence and clarity without claiming personal evidence")
    func expandedInformationOnlyRoutingIsBounded() {
        #expect(CoachCraftKnowledgeRequest.isAnswerOnly("Tell me about cadence."))
        #expect(CoachCraftKnowledgeRequest.isAnswerOnly("Tell me about communication clarity."))
        #expect(!CoachCraftKnowledgeRequest.isAnswerOnly("Tell me about my delivery."))
        #expect(!CoachCraftKnowledgeRequest.isAnswerOnly("What is my communication style?"))

        let cadence = CoachReliabilityGate.craftKnowledgeFallback(
            for: "Tell me about cadence."
        )
        #expect(cadence.contains("pace, rhythm, sentence length, and pauses"))
        #expect(!cadence.contains("drill"))

        let clarity = CoachReliabilityGate.craftKnowledgeFallback(
            for: "Tell me about communication clarity."
        )
        #expect(clarity.contains("main point"))
        #expect(clarity.contains("response or decision"))
        #expect(!clarity.contains("exercise"))
    }

    @Test("Generic benchmarks are explicit, bounded, and not personal metrics")
    func genericBenchmarkRoutingIsRequestBound() {
        let questions: [(String, CoachBenchmarkKind, String)] = [
            ("What is a good pace for a keynote?", .keynotePace, "120–150"),
            ("How long should an elevator pitch be?", .elevatorPitchLength, "30–60"),
            ("What is the ideal pause duration?", .pauseDuration, "0.5–1.5")
        ]

        for (question, kind, expectedRange) in questions {
            let authorization = CoachBenchmarkAuthorization.explicitRequest(
                in: question
            )
            #expect(authorization?.kind == kind)
            #expect(authorization?.range.contains(expectedRange) == true)
            #expect(CoachReplyPosture.resolve(userText: question) == .informationOnly)
            #expect(TurnDepthClassifier.requestedPersonalMetrics(question).isEmpty)
        }

        let personalQuestion = "What was my pace in the keynote?"
        #expect(CoachBenchmarkAuthorization.explicitRequest(in: personalQuestion) == nil)
        #expect(TurnDepthClassifier.requestedPersonalMetrics(personalQuestion) == [.paceWordsPerMinute])
        #expect(CoachReplyPosture.resolve(
            userText: personalQuestion,
            requestedMetrics: TurnDepthClassifier.requestedPersonalMetrics(personalQuestion)
        ) == .requestedMetrics)
    }

    @Test("Generic benchmark prompt authorizes one range with a caveat")
    func genericBenchmarkPromptIsBounded() {
        let context = CoachPromptBundle.generalContextBlock(
            userQuestion: "What pace should I use for my keynote?",
            turnDepth: .quickMove,
            surface: .text
        )

        #expect(context.contains("Generic benchmark authorization: generic keynote pace only"))
        #expect(context.contains("120–150 words per minute"))
        #expect(context.contains("Benchmark caveat required"))
        #expect(context.contains("Personal metric authorization: NONE"))
        #expect(context.contains("No personal diagnosis, demonstration, drill, invitation"))
    }

    @Test("A bounded requested benchmark passes; false precision fails closed")
    func benchmarkReliabilityCap() {
        let good = CoachReliabilityGate.evaluate(
            replyText: "For most keynotes, about 120–150 words per minute is a useful starting range, not a universal target; adjust for audience familiarity, idea density, and the room.",
            previousCoachReply: nil,
            latestUserTurn: "What is a good pace for a keynote?",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: nil
        )
        #expect(!good.issues.contains(.rawReportVoice))
        #expect(!good.blocked)

        let exact = CoachReliabilityGate.evaluate(
            replyText: "Exactly 140 WPM.",
            previousCoachReply: nil,
            latestUserTurn: "What is a good pace for a keynote?",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: nil
        )
        #expect(exact.issues.contains(.rawReportVoice))
        #expect(exact.blocked)
        #expect(exact.fallbackText?.contains("120–150") == true)
        #expect(exact.fallbackText?.contains("not a universal target") == true)
    }

    @Test("Information-only answer rejects an appended drill or closing question")
    func informationOnlyReliabilityCap() {
        let direct = CoachReliabilityGate.evaluate(
            replyText: "Active listening means attending to the speaker’s meaning, reflecting it accurately, and checking your understanding before adding your own view.",
            previousCoachReply: nil,
            latestUserTurn: "What is active listening?",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: nil
        )
        #expect(!direct.issues.contains(.wrongQuestion))
        #expect(!direct.blocked)

        let forced = CoachReliabilityGate.evaluate(
            replyText: "Active listening means attending to the speaker’s meaning, reflecting it accurately, and checking your understanding. Now try one rep. What changed?",
            previousCoachReply: nil,
            latestUserTurn: "What is active listening?",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: nil
        )
        #expect(forced.issues.contains(.wrongQuestion))
        #expect(forced.blocked)
        #expect(forced.fallbackText?.contains("Active listening means") == true)
        #expect(forced.fallbackText?.contains("try one rep") == false)
        #expect(forced.fallbackText?.hasSuffix("?") == false)
    }

    @Test("Requested benchmark rejects appended work but keeps the authorized answer")
    func benchmarkReliabilityCapRemovesForcedFollowUp() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "For most keynotes, about 120–150 words per minute is a useful starting range, not a universal target; adjust for audience familiarity, idea density, and the room. Now practise it once. What changed?",
            previousCoachReply: nil,
            latestUserTurn: "What is a good pace for a keynote?",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: nil
        )

        #expect(verdict.issues.contains(.wrongQuestion))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText?.contains("120–150 words per minute") == true)
        #expect(verdict.fallbackText?.contains("not a universal target") == true)
        #expect(verdict.fallbackText?.contains("practise") == false)
        #expect(verdict.fallbackText?.hasSuffix("?") == false)
    }

    @Test("Benchmark authorization does not permit another metric")
    func benchmarkAuthorizationRejectsCrossMetricAndUnaskedRange() {
        let crossMetric = CoachReliabilityGate.evaluate(
            replyText: "About 120–150 WPM is a useful starting range; adjust for the audience. Aim for a score of 8/10 too.",
            previousCoachReply: nil,
            latestUserTurn: "What is a good pace for a keynote?",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: nil
        )
        #expect(crossMetric.issues.contains(.rawReportVoice))

        let unasked = CoachReliabilityGate.evaluate(
            replyText: "Use 120–150 WPM as your starting range.",
            previousCoachReply: nil,
            latestUserTurn: "What is active listening?",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: nil
        )
        #expect(unasked.issues.contains(.rawReportVoice))
    }

    @Test("Catalogue covers story, listening, prosody, and audience adaptation")
    func expandedInterventionSelection() {
        let cases: [(String, String)] = [
            ("How do I tell a story without losing the point?", "story-beat"),
            ("How do I listen without preparing my reply?", "listening-loop"),
            ("How do I make my vocal delivery less flat?", "vocal-contrast"),
            ("How do I tailor this for an executive audience?", "audience-lens")
        ]

        for (question, expectedID) in cases {
            let plan = CoachReasoningPass.generalDecisionPlan(
                userQuestion: question
            )
            #expect(plan.chosenIntervention.lowercased().contains(
                CoachReasoningPass.interventionCatalogue
                    .first { $0.id == expectedID }!.title.lowercased()
            ))
        }
    }

    @Test("A new domain intervention advances stage across the last-three window")
    func expandedInterventionNoveltyAdvances() {
        let listening = CoachReasoningPass.interventionCatalogue
            .first { $0.id == "listening-loop" }!
        let choice = CoachReasoningPass.selectIntervention(
            userQuestion: "How do I listen without interrupting?",
            preferredDimensionID: nil,
            trajectory: Self.trajectory,
            turnDepth: .quickMove,
            replyPosture: .coachedAttempt,
            recentMoves: [listening.drill]
        )

        #expect(choice?.intervention.id == "listening-loop")
        #expect(choice?.stage == .stretch)
        #expect(choice?.move != listening.drill)
    }

    @Test("Unmatched questions never default blindly to answer-first")
    func unmatchedQuestionHasNoAnswerFirstDefault() {
        let knowledge = CoachReasoningPass.generalDecisionPlan(
            userQuestion: "What is conversational turn-taking?"
        )
        #expect(knowledge.replyPosture == .informationOnly)
        #expect(!knowledge.chosenIntervention.lowercased().contains("answer first"))

        let action = CoachReasoningPass.generalDecisionPlan(
            userQuestion: "How do I handle an awkward communication moment?"
        )
        #expect(action.replyPosture == .coachedAttempt)
        #expect(!action.chosenIntervention.lowercased().contains("answer first"))
        #expect(action.modelLine == nil)
    }

    @Test("Prompt hides score rows and requires acknowledge read model invite")
    func promptUsesProfessionalResponseContract() {
        let context = CoachPromptBundle.contextBlock(
            assessment: Self.answerFirstAssessment,
            rubric: Self.rubric,
            surface: .text
        )

        #expect(context.contains("COACH DECISION PLAN (PRIVATE"))
        #expect(context.contains("- Situation:"))
        #expect(context.contains("- Stakes:"))
        #expect(context.contains("- Emotion:"))
        #expect(context.contains("- Observed behavior:"))
        #expect(context.contains("- Exact evidence:"))
        #expect(context.contains("- Skill stage:"))
        #expect(context.contains("- Chosen intervention:"))
        #expect(context.contains("- Success test:"))
        #expect(context.contains("acknowledge briefly; give the specific read; model better wording or delivery; invite one attempt"))
        #expect(context.contains("Metric authorization: NONE"))
        #expect(!context.contains("Verdict first: 0."))
        #expect(!context.contains("confidence 0."))
    }

    @Test("Metric authorization is explicit and bounded")
    func requestedMetricPromptOnlyAuthorizesRequestedKind() {
        var assessment = Self.answerFirstAssessment
        assessment.requestedMetrics = [.score]
        let context = CoachPromptBundle.contextBlock(
            assessment: assessment,
            rubric: Self.rubric,
            surface: .text
        )

        #expect(context.contains("Metric authorization: score."))
        #expect(context.contains("Report only these requested metric kinds"))
        #expect(!context.contains("Metric authorization: NONE"))
    }

    @Test("Unrequested scorecard voice fails closed")
    func rawReportVoiceBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Score: 7/10. Pace: 148 WPM. Filler rate: 2.1 per minute.",
            previousCoachReply: nil,
            latestUserTurn: "What should I work on next?",
            turnDepth: .quickMove,
            assessment: Self.answerFirstAssessment,
            evidenceCoverage: 0.6
        )

        #expect(verdict.issues.contains(.rawReportVoice))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText?.contains("7/10") == false)
        #expect(verdict.fallbackText?.contains("WPM") == false)
    }

    @Test("An explicitly requested score remains allowed")
    func requestedMetricPassesReportCap() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Your score was 7/10.",
            previousCoachReply: nil,
            latestUserTurn: "What was my score?",
            turnDepth: .groundedRead,
            assessment: nil,
            evidenceCoverage: 0.6
        )

        #expect(!verdict.issues.contains(.rawReportVoice))
    }

    @Test("A why question cannot be replaced by another drill")
    func wrongQuestionBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Run another 60-second answer with the recommendation first.",
            previousCoachReply: nil,
            latestUserTurn: "Why did that answer land badly?",
            turnDepth: .groundedRead,
            assessment: Self.answerFirstAssessment,
            evidenceCoverage: 0.6
        )

        #expect(verdict.issues.contains(.wrongQuestion))
        #expect(verdict.blocked)
    }

    @Test("A direct causal read answers the why question")
    func whyQuestionWithSpecificReadPasses() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "The recommendation arrived after two setup sentences, so the listener had to wait for the answer. A cleaner version is “I recommend option A because the delivery risk is lower.” Try that once.",
            previousCoachReply: nil,
            latestUserTurn: "Why did that answer land badly?",
            turnDepth: .groundedRead,
            assessment: Self.answerFirstAssessment,
            evidenceCoverage: 0.6
        )

        #expect(!verdict.issues.contains(.wrongQuestion))
        #expect(!verdict.issues.contains(.missingDemonstration))
        #expect(!verdict.blocked)
    }

    @Test("Polite generic encouragement is still a non-answer")
    func politeNonAnswerBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Great question. Keep practicing—you've got this.",
            previousCoachReply: nil,
            latestUserTurn: "How do I make my recommendation clearer?",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: nil
        )

        #expect(verdict.issues.contains(.nonAnswer))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText?.contains("model the craft") == true)
    }

    @Test("Asked-for wording requires a demonstrated line")
    func missingDemonstrationBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Lead with the recommendation and give one reason.",
            previousCoachReply: nil,
            latestUserTurn: "What should I say to my manager?",
            turnDepth: .quickMove,
            assessment: Self.answerFirstAssessment,
            evidenceCoverage: 0.6
        )

        #expect(verdict.issues.contains(.missingDemonstration))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText?.contains("“") == true)
    }

    @Test("Third unchanged intervention in the active window fails closed")
    func repeatedInterventionBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "The pattern is late setup. Give one answer with the recommendation in sentence one, then one reason.",
            previousCoachReply: "The signal is the opener. Put the answer first in sentence one, add one reason, then stop.",
            recentCoachReplies: [
                "The signal is the opener. Put the answer first in sentence one, add one reason, then stop.",
                "The pattern is delayed setup. Run one answer with the recommendation first in sentence one, then one reason."
            ],
            latestUserTurn: "What should I work on?",
            turnDepth: .quickMove,
            assessment: Self.answerFirstAssessment,
            evidenceCoverage: 0.6
        )

        #expect(verdict.issues.contains(.repeatedIntervention))
        #expect(verdict.blocked)
    }

    @Test("Private decision-plan labels are scaffold leakage")
    func decisionPlanScaffoldBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Skill stage: stretch. Chosen intervention: answer-first.",
            previousCoachReply: nil,
            latestUserTurn: "What should I work on?",
            turnDepth: .quickMove,
            assessment: Self.answerFirstAssessment,
            evidenceCoverage: 0.6
        )

        #expect(verdict.issues.contains(.scaffoldLeak))
        #expect(verdict.blocked)
    }

    private static let answerFirstAssessment = CoachAssessment(
        turnDepth: .quickMove,
        surface: .text,
        questionRestatement: "How do I make the answer land sooner?",
        directVerdict: "The recommendation arrives after too much setup.",
        confidence: 0.62,
        evidenceUsed: [
            "latest transcript: the answer begins with two context sentences before the recommendation"
        ],
        rubricScores: [
            RubricScore(
                dimensionID: "verdict_first",
                label: "Verdict first",
                score: 0.42,
                confidence: 0.62,
                evidence: ["the recommendation arrived after setup"],
                missingEvidence: "Need a clean sentence-one recommendation."
            )
        ],
        nextProofDimensionID: "verdict_first",
        missingEvidence: [],
        nextProofTest: "Give one 30-second answer: recommendation in sentence one, one reason in sentence two, then stop.",
        responseMode: .immediateOnly
    )

    private static let rubric = ActiveGoalRubric(
        rubric: GoalRubric(
            goalID: "professional-loop-test",
            displayName: "Executive clarity",
            dimensions: [
                RubricDimension(
                    id: "verdict_first",
                    label: "Verdict first",
                    description: "The answer arrives before setup.",
                    proofSignals: ["recommendation in sentence one"],
                    proofTest: "Give the recommendation first.",
                    missingIfAbsent: "Need a clean sentence-one recommendation."
                )
            ],
            defaultWeights: ["verdict_first": 1]
        ),
        voice: nil
    )

    private static let trajectory = UserTrajectorySnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_000),
        sessionCount: 2,
        ratedSessionCount: 2,
        evidenceCoverage: 0.62,
        recentSessionLines: [],
        trendLines: [],
        latestRepEvidencePack: nil,
        coachCaseSummary: nil,
        activeInterventionState: ActiveInterventionState(
            title: "Answer first",
            target: "Recommendation in sentence one",
            followedRepCount: 1,
            reviewStatus: "forming"
        )
    )
}
