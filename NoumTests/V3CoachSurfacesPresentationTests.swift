import Foundation
import Testing
@testable import Noum

@Suite("V3 coaching surfaces")
struct V3CoachSurfacesPresentationTests {
    @Test("A landed coaching assessment projects exactly one authored practice move")
    func practiceMoveUsesExistingReasoningSelection() throws {
        let assessment = CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: "Help me lead with the answer.",
            directVerdict: "The recommendation arrives after the setup.",
            confidence: 0.82,
            evidenceUsed: ["latest rep: the recommendation arrived late"],
            rubricScores: [],
            nextProofDimensionID: "verdict_first",
            missingEvidence: [],
            nextProofTest: "Put the recommendation in sentence one.",
            responseMode: .immediateOnly,
            toneMode: .prescribe
        )

        let move = try #require(AskNoumPracticeMovePresentation.make(
            metadata: CoachTurnMetadata(assessment: assessment)
        ))

        #expect(move.title == "Answer first")
        #expect(move.modelLine.contains("recommendation"))
        #expect(move.drill == "Put the recommendation in sentence one.")
        #expect(move.passCondition.contains("sentence one"))
    }

    @Test("Metric-only and presence turns do not manufacture a drill card")
    func nonPracticePosturesStayConversational() {
        let metricAssessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "What was my pace?",
            directVerdict: "The latest qualified pace is available.",
            confidence: 0.90,
            evidenceUsed: [],
            rubricScores: [],
            requestedMetrics: [.paceWordsPerMinute],
            missingEvidence: [],
            nextProofTest: "Answer only the requested pace.",
            responseMode: .immediateOnly,
            toneMode: .explain
        )
        let presenceAssessment = CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: "I'm exhausted. Can we stop?",
            directVerdict: "No further rep is needed.",
            confidence: 0.80,
            evidenceUsed: [],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Leave the door open without assigning work.",
            responseMode: .immediateOnly,
            toneMode: .validate
        )

        #expect(AskNoumPracticeMovePresentation.make(
            metadata: CoachTurnMetadata(assessment: metricAssessment)
        ) == nil)
        #expect(AskNoumPracticeMovePresentation.make(
            metadata: CoachTurnMetadata(assessment: presenceAssessment)
        ) == nil)
    }

    @Test("Coaching graphics explain state without mascot or ambient motion")
    func coachChromeHasNoMascotOrAmbientLoop() throws {
        let askNoum = try repositorySource("Noum/AskNoumView.swift")
        #expect(askNoum.contains("role: .coachRead"))
        #expect(askNoum.contains("NoumWaveformMark("))

        let coachRead = try repositorySource("Noum/CoachReadCard.swift")
        #expect(coachRead.contains("role: .coachRead"))
        #expect(coachRead.contains("private var insightLoadingState"))
        #expect(coachRead.contains("role: .progressTrajectory"))
        #expect(!coachRead.contains("NoumWaveformMark("))

        let coachingPlan = try repositorySource("Noum/CoachingPlanCard.swift")
        #expect(coachingPlan.contains("role: .practicePlan"))
        #expect(!coachingPlan.contains("NoumWaveformMark("))

        for relativePath in [
            "Noum/AskNoumView.swift",
            "Noum/CoachReadCard.swift",
            "Noum/CoachingPlanCard.swift",
        ] {
            let source = try repositorySource(relativePath)
            #expect(!source.contains("NoumCharacter"))
            #expect(!source.contains("repeatForever"))
            #expect(!source.contains("options: .repeating"))
            #expect(!source.contains("preferredColorScheme(.light)"))
        }

        let session = try repositorySource("Noum/CoachSessionView.swift")
        #expect(session.contains("NoumMotion.animation(for: .calm"))
        #expect(!session.contains("NoumCharacter"))
        #expect(!session.contains("repeatForever"))

        let liveCall = try repositorySource("Noum/LiveCoachCallView.swift")
        #expect(liveCall.contains("NoumWaveformMark("))
        #expect(!liveCall.contains("NoumCharacter"))
        #expect(!liveCall.contains("TimelineView"))
        #expect(!liveCall.contains("repeatForever"))
    }

    @Test("Ask Noum keeps transport truth while disclosing move and evidence progressively")
    func askNoumPreservesBehaviorContracts() throws {
        let source = try repositorySource("Noum/AskNoumView.swift")

        #expect(source.contains("MODEL LINE"))
        #expect(source.contains("DRILL"))
        #expect(source.contains("PASS TEST"))
        #expect(source.contains("askNoum.coachMove.disclosure"))
        #expect(source.contains("askNoum.responseEvidence"))
        #expect(source.contains(".navigationTitle(\"Ask Noum\")"))
        #expect(source.contains("coachReplyIdentity(accent:"))
        #expect(source.contains("message.id == latestLandedCoachID"))
        #expect(source.contains("askNoum.nextMove.primary"))
        #expect(source.contains("store.prepareRetry"))
        #expect(source.contains("store.isAwaitingReply"))
        #expect(source.contains("navigationPath = NavigationPath()"))
        #expect(source.contains("AskNoumStore.shared"))
    }

    @Test("Source copy distinguishes AI wording from rule-based fallback")
    func sourceCopyIsHonest() {
        #expect(CoachReadCard.noteSourceDescription(isAIBacked: true).contains("AI-polished"))
        #expect(CoachReadCard.noteSourceDescription(isAIBacked: false).contains("Rule-based"))
        #expect(CoachingPlanCard.planSourceDescription(isAIBacked: true).contains("AI-written"))
        #expect(CoachingPlanCard.planSourceDescription(isAIBacked: false).contains("Rule-based"))
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let root = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
