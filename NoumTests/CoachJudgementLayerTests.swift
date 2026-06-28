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

    @Test func nextMoveQuestionsAreQuickMove() {
        #expect(TurnDepthClassifier.classify(
            userText: "What should I do next?"
        ) == .quickMove)
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

    @Test func deepAssessmentImmediateReadIncludesMissingEvidenceAndProofTest() {
        let assessment = CoachReasoningPass.assess(
            turnDepth: .deepAssessment,
            userQuestion: "Where do I stand overall?",
            trajectory: Self.singleRepTrajectory,
            rubric: ActiveGoalRubric(rubric: GoalRubricStore.rubric(for: .authoritative), voice: .authoritative),
            surface: .live
        )

        let read = assessment.immediateCoachRead.lowercased()
        #expect(read.contains("missing"))
        #expect(read.contains("proof test"))
    }

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

    private func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        // Test-only helper. UserDefaults does not expose suiteName; this is only
        // used immediately after construction, where removePersistentDomain on
        // a random name is a defensive no-op if the suite is already empty.
        "AskNoumProvisionalReadTests"
    }
}
