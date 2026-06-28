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
