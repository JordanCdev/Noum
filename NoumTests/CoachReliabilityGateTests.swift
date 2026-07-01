//
//  CoachReliabilityGateTests.swift
//  NoumTests
//
//  Coverage for the last-mile reliability gate: the truthful backstop that runs
//  on the final coach reply before it reaches the UI. Two layers:
//
//    1. Unit coverage for each issue (hard blocks vs soft smells), the fallback
//       selection (prefer the deterministic on-device read, else an honest
//       depth-shaped line), and the normalisation that drives duplicate/marker
//       detection.
//    2. Golden-scenario coverage derived from the deep-research report's ten
//       benchmark cases — each asserts a representative good reply passes clean
//       AND that the degenerate variant (empty / placeholder / duplicate /
//       scaffold) is blocked and replaced with a non-empty truthful fallback.
//
//  The gate is pure, so every assertion here is deterministic with no I/O.
//

import Foundation
import Testing
@testable import Noum

@Suite("CoachReliabilityGateTests")
struct CoachReliabilityGateTests {

    // MARK: Fixtures

    /// A clean quick-move assessment whose `immediateCoachRead` wraps the proof
    /// test in a local read — usable as a clean fallback source.
    private static func quickMoveAssessment(
        proofTest: String = "Run one 60-second rep with the verdict first, then one reason, then stop.",
        confidence: Double = 0.55,
        evidence: [String] = ["latest rep: Timed, 7/10, 1 filler, 58s"]
    ) -> CoachAssessment {
        CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: "What should I do next?",
            directVerdict: "The opening is the next lever: put the verdict in sentence one.",
            confidence: confidence,
            evidenceUsed: evidence,
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: proofTest,
            responseMode: .immediateOnly
        )
    }

    private static func deepAssessment(
        confidence: Double = 0.30,
        evidence: [String] = ["latest rep: Timed, 7/10, 1 filler, 58s"]
    ) -> CoachAssessment {
        CoachAssessment(
            turnDepth: .deepAssessment,
            surface: .text,
            questionRestatement: "How far off am I from sounding authoritative?",
            directVerdict: "You have useful pieces, but the full standard is not proven yet.",
            confidence: confidence,
            evidenceUsed: evidence,
            rubricScores: [],
            missingEvidence: ["Need pressure-mode evidence before treating the goal as ready."],
            nextProofTest: "Run the same answer under a 60-second timer and keep the verdict first.",
            responseMode: .expandable
        )
    }

    // MARK: - Clean path

    @Test func cleanReplyProducesNoIssuesAndNoFallback() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Lead with your recommendation in the first sentence, then give one reason. Want to try a 60-second rep?",
            previousCoachReply: "Earlier we worked on your close.",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(verdict.issues.isEmpty)
        #expect(verdict.fallbackText == nil)
        #expect(verdict.blocked == false)
    }

    // MARK: - Hard blocks

    @Test func emptyReplyBlocksWithFallback() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "   \n  ",
            previousCoachReply: nil,
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(verdict.issues.contains(.empty))
        #expect(verdict.blocked)
        #expect(!(verdict.fallbackText ?? "").isEmpty)
    }

    @Test func placeholderTextBlocks() {
        for stub in ["Full answer coming…", "placeholder reply", "Coach read coming shortly", "Your response here"] {
            let verdict = CoachReliabilityGate.evaluate(
                replyText: stub,
                previousCoachReply: nil,
                turnDepth: .quickMove,
                assessment: Self.quickMoveAssessment(),
                evidenceCoverage: 0.6
            )
            #expect(verdict.issues.contains(.placeholder), "expected placeholder for: \(stub)")
            #expect(verdict.blocked)
        }
    }

    @Test func legitimatePlaceholderAskDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "For the 75-second update, use a placeholder ask: I need alignment on the next step, because it trains the close before the business content is final.",
            previousCoachReply: nil,
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(!verdict.issues.contains(.placeholder))
        #expect(!verdict.blocked)
    }

    @Test func verbatimDuplicateOfPreviousCoachReplyBlocks() {
        let prior = "Lead with the decision, then one reason. Try a 60-second rep and keep sentence one as the answer."
        let verdict = CoachReliabilityGate.evaluate(
            // Same content, different whitespace/casing — normalisation must still match.
            replyText: "Lead with the decision, then one reason.  Try a 60-second rep and keep sentence one as the answer.",
            previousCoachReply: prior,
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(verdict.issues.contains(.duplicateReply))
        #expect(verdict.blocked)
    }

    @Test func nearButNotIdenticalReplyIsNotADuplicate() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Lead with the decision, then give two reasons this time.",
            previousCoachReply: "Lead with the decision, then one reason.",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(!verdict.issues.contains(.duplicateReply))
    }

    @Test func nearDuplicateReplyIsRecordedSoftNotBlocked() {
        let prior = "your close trails off so the ask never lands with conviction in the room"
        let verdict = CoachReliabilityGate.evaluate(
            // A rephrase: one word added, nothing dropped → high token overlap, not verbatim.
            replyText: "your close trails off so the ask never lands with conviction in the busy room",
            previousCoachReply: prior,
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(verdict.issues.contains(.nearDuplicateReply))
        #expect(!verdict.issues.contains(.duplicateReply))
        #expect(!verdict.blocked) // soft: recorded, not replaced
    }

    @Test func exactDuplicatePrefersHardDuplicateOverNearDuplicate() {
        let text = "your close trails off so the ask never lands with conviction in the room"
        let verdict = CoachReliabilityGate.evaluate(
            replyText: text,
            previousCoachReply: text,
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(verdict.issues.contains(.duplicateReply))
        #expect(!verdict.issues.contains(.nearDuplicateReply))
        #expect(verdict.blocked)
    }

    @Test func genuinelyDifferentReplyIsNotNearDuplicate() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Lead with the verdict in sentence one, then prove it with a single concrete example.",
            previousCoachReply: "your close trails off so the ask never lands with conviction in the room",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(!verdict.issues.contains(.nearDuplicateReply))
        #expect(!verdict.issues.contains(.duplicateReply))
    }

    @Test func shortSimilarRepliesDoNotTripNearDuplicate() {
        // Below the token floor → unstable overlap is not flagged.
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Run a 60-second drill",
            previousCoachReply: "Run a 60-second rep",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(!verdict.issues.contains(.nearDuplicateReply))
    }

    @Test func isNearDuplicateHelperIsSymmetricAndThresholded() {
        let a = CoachReliabilityGate.normalize("your close trails off so the ask never lands with conviction in the room")
        let b = CoachReliabilityGate.normalize("your close trails off so the ask never lands with conviction in the busy room")
        #expect(CoachReliabilityGate.isNearDuplicate(a, b))
        #expect(CoachReliabilityGate.isNearDuplicate(b, a)) // symmetric
        let c = CoachReliabilityGate.normalize("lead with the verdict then prove it once with a concrete vivid detail")
        #expect(!CoachReliabilityGate.isNearDuplicate(a, c))
    }

    @Test func leakedScaffoldBlocks() {
        for leak in [
            "turnDepth=deepAssessment confidence 0.20",
            "Here is the directVerdict and the rubricScore breakdown",
            "{\"surfaceText\": \"hi\", \"verdict\": \"x\"}",
            "Apply point-reason-example-point and stop."
        ] {
            let verdict = CoachReliabilityGate.evaluate(
                replyText: leak,
                previousCoachReply: nil,
                turnDepth: .deepAssessment,
                assessment: Self.deepAssessment(),
                evidenceCoverage: 0.5
            )
            #expect(verdict.issues.contains(.scaffoldLeak), "expected scaffold leak for: \(leak)")
            #expect(verdict.blocked)
        }
    }

    @Test func normalConversationalPhrasesDoNotFalseTripScaffold() {
        // "trust repair" / "quick move" as English phrases (with spaces) must be
        // safe — only the concatenated code forms leak.
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Let's do a quick move to repair trust here: name the miss, then give one fix.",
            previousCoachReply: nil,
            turnDepth: .trustRepair,
            assessment: Self.deepAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.scaffoldLeak))
    }

    // MARK: - Soft smells (recorded, never blanket-replace)

    @Test func floorConfidenceWithEvidenceIsRecordedButDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Here is a perfectly fine, human coaching reply with a clear next step.",
            previousCoachReply: nil,
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment(confidence: 0.20, evidence: ["latest rep: Timed, 7/10"]),
            evidenceCoverage: 0.4
        )
        #expect(verdict.issues.contains(.floorConfidenceWithEvidence))
        #expect(!verdict.blocked)
        #expect(verdict.fallbackText == nil)
    }

    @Test func floorConfidenceWithoutEvidenceDoesNotFire() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Here is a fine reply.",
            previousCoachReply: nil,
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment(confidence: 0.20, evidence: []),
            evidenceCoverage: 0.05
        )
        #expect(!verdict.issues.contains(.floorConfidenceWithEvidence))
    }

    @Test func trustRepairWithoutAcknowledgementBlocksWithFallback() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Run a 60-second rep and put the verdict first, then stop.",
            previousCoachReply: "Earlier read.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(verdict.issues.contains(.noAttunementOnPushback))
        #expect(verdict.blockingIssues.contains(.noAttunementOnPushback))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText?.isEmpty == false)
    }

    @Test func trustRepairWithAcknowledgementDoesNotRecordSoftIssue() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "You're right to push me — I leaned on advice before answering. Here's the real read: lead with the verdict.",
            previousCoachReply: "Earlier read.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.noAttunementOnPushback))
    }

    @Test func trustRepairLetMePrescribeDoesNotCountAsAcknowledgement() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Let me give you the drill: run a 60-second rep and put the verdict first.",
            previousCoachReply: "Earlier read.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(verdict.issues.contains(.noAttunementOnPushback))
        #expect(verdict.blockingIssues.contains(.noAttunementOnPushback))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText?.isEmpty == false)
    }

    @Test func trustRepairLetMeRepairDoesCountAsAcknowledgement() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Let me repair that: I gave you advice before answering the friction. The real read is the opener.",
            previousCoachReply: "Earlier read.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.noAttunementOnPushback))
    }

    @Test func thinTrustRepairAcknowledgesButSkipsRepairBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair push. Run a 45-second rep with the opener first because it gives the point somewhere to land.",
            previousCoachReply: "Earlier read.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.noAttunementOnPushback))
        #expect(verdict.issues.contains(.thinTrustRepair))
        #expect(verdict.blockingIssues.contains(.thinTrustRepair))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText?.isEmpty == false)
    }

    @Test func trustRepairThatNamesMissBeforePrescriptionPasses() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair push. I gave you advice before answering the friction. The real read is the opener, then one proof point.",
            previousCoachReply: "Earlier read.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.noAttunementOnPushback))
        #expect(!verdict.issues.contains(.thinTrustRepair))
        #expect(!verdict.blocked)
    }

    @Test func trustRepairStraightAnswerCountsAsSubstantiveRepair() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair. Straight answer: the close is not decisive yet; proof it with one timer rep.",
            previousCoachReply: "Earlier read.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.noAttunementOnPushback))
        #expect(!verdict.issues.contains(.thinTrustRepair))
        #expect(!verdict.blocked)
    }

    @Test func genericReplyAfterTrustRepairBlocksCarryoverBreak() {
        let previousRepair = "Fair push: that was advice, not coaching. The real read is warmth came before the recommendation, so next rep say the recommendation first."
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "A good next step is to practice more and communicate clearly over time. Track your progress and keep going.",
            previousCoachReply: previousRepair,
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(verdict.issues.contains(.repairCarryoverBreak))
        #expect(verdict.blockingIssues.contains(.repairCarryoverBreak))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText?.isEmpty == false)
    }

    @Test func specificReplyAfterTrustRepairCarriesForward() {
        let previousRepair = "Fair push: that was advice, not coaching. The real read is warmth came before the recommendation, so next rep say the recommendation first."
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Carry the repaired read forward: the target is still order, not less warmth. Recommendation first, then one reassurance so the point lands without sounding abrupt.",
            previousCoachReply: previousRepair,
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.repairCarryoverBreak))
        #expect(!verdict.blocked)
    }

    @Test func rejectingGenericPhraseAfterRepairDoesNotBlockCarryover() {
        let previousRepair = "Fair push: that sounded cold and too generic. The actual question was whether warmth can follow the recommendation without weakening it."
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Do not practice more in general. Keep the repaired read: sentence one is the recommendation, sentence two is one reassurance, then stop.",
            previousCoachReply: previousRepair,
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.repairCarryoverBreak))
        #expect(!verdict.blocked)
    }

    @Test func genericReplyWithoutPreviousTrustRepairDoesNotTripCarryoverBreak() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "A good next step is to practice more and communicate clearly over time.",
            previousCoachReply: "Earlier we worked on the close.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.repairCarryoverBreak))
    }

    @Test func explicitSilentPlanSwitchBlocksWithFallback() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Actually, change target. New plan instead: ignore the earlier read and work on vocal warmth with a 60-second confidence rep.",
            previousCoachReply: "The pressure rep target is verdict first: protect sentence one under the timer, then check the clean stop.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(verdict.issues.contains(.silentPlanSwitch))
        #expect(verdict.blockingIssues.contains(.silentPlanSwitch))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText?.isEmpty == false)
    }

    @Test func negatedPriorTargetWithoutRationaleBlocksPlanSwitch() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Not the opener now. Work on vocal warmth with a 60-second confidence rep.",
            previousCoachReply: "The opener is the target: put the recommendation in sentence one, then prove it once.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(verdict.issues.contains(.silentPlanSwitch))
        #expect(verdict.blocked)
    }

    @Test func explainedTargetRevisionDoesNotBlockPlanSwitch() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "That tells us order improved faster than tone. Keep the recommendation first, then add one reassurance so clarity does not sound abrupt.",
            previousCoachReply: "The opener is the target: put the recommendation in sentence one, then prove it once.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.6
        )
        #expect(!verdict.issues.contains(.silentPlanSwitch))
        #expect(!verdict.blocked)
    }

    @Test func repetitivePrescriptionOnlyDiscourseMoveBlocksWithFallback() {
        let assessment = Self.quickMoveAssessment(
            proofTest: "Run a different proof: make the close the ask, then stop."
        )
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Run one focused rep on the timeline detail. Check whether the date answers sequence.",
            previousCoachReply: "Run one focused rep on the proof line. Check whether one proof line is concrete.",
            recentCoachReplies: [
                "Run one focused rep on the proof line. Check whether one proof line is concrete.",
                "Run one focused rep on the opener. Check whether sentence one lands before setup."
            ],
            turnDepth: .quickMove,
            assessment: assessment,
            evidenceCoverage: 0.5
        )
        #expect(verdict.issues.contains(.repetitiveDiscourseMove))
        #expect(verdict.blockingIssues.contains(.repetitiveDiscourseMove))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText == assessment.immediateCoachRead)
    }

    @Test func narrowedRepeatFollowUpDoesNotTripDiscourseLoopWhenReplyNamesExactLine() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Repeat the final sentence only: ask, period, because that isolates the confidence leak. If you add a qualifier after it, rewrite that same line until it ends cleanly.",
            previousCoachReply: "Use the close in your next rep: directness is fine if the reason already came before the ask, so keep the reason before it and stop.",
            recentCoachReplies: [
                "Use the close in your next rep: directness is fine if the reason already came before the ask, so keep the reason before it and stop.",
                "Cut the softener after the ask. The close keeps adding maybe or just after the decision, so make the ask and stop before the confidence leaks."
            ],
            latestUserTurn: "What do I repeat?",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.repetitiveDiscourseMove))
        #expect(!verdict.blocked)
    }

    @Test func narrowedRepeatFollowUpStillBlocksGenericTimerPrescription() {
        let assessment = Self.quickMoveAssessment()
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Repeat the same answer under a timer and protect sentence one.",
            previousCoachReply: "Use the close in your next rep: directness is fine if the reason already came before the ask, so keep the reason before it and stop.",
            recentCoachReplies: [
                "Use the close in your next rep: directness is fine if the reason already came before the ask, so keep the reason before it and stop.",
                "Cut the softener after the ask. The close keeps adding maybe or just after the decision, so make the ask and stop before the confidence leaks."
            ],
            latestUserTurn: "What do I repeat?",
            turnDepth: .quickMove,
            assessment: assessment,
            evidenceCoverage: 0.5
        )
        #expect(verdict.issues.contains(.repetitiveDiscourseMove))
        #expect(verdict.blockingIssues.contains(.repetitiveDiscourseMove))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText == assessment.immediateCoachRead)
    }

    @Test func twoPrescriptionOnlyTurnsDoNotTripDiscourseLoop() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Run one focused rep on the proof line. Check whether one proof line is concrete.",
            previousCoachReply: "Run one focused rep on the opener. Check whether sentence one lands before setup.",
            recentCoachReplies: [
                "Run one focused rep on the opener. Check whether sentence one lands before setup."
            ],
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.repetitiveDiscourseMove))
        #expect(!verdict.blocked)
    }

    @Test func answerOrDiagnosisBreaksPrescriptionOnlyDiscourseLoop() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "No. The target is still the opener, because sentence one is where the listener gets the point. Run one clean rep.",
            previousCoachReply: "Run one focused rep on the proof line. Check whether one proof line is concrete.",
            recentCoachReplies: [
                "Run one focused rep on the proof line. Check whether one proof line is concrete.",
                "Run one focused rep on the opener. Check whether sentence one lands before setup."
            ],
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.repetitiveDiscourseMove))
        #expect(!verdict.blocked)
    }

    @Test func rationaleBecauseDoesNotCountAsUsePrescriptionInDiscourseLoop() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Then the decision line is cleaner, but the proof handoff is leaking, so review the transcript from the first proof sentence and rewrite only that transition: decision, because, proof.",
            previousCoachReply: "Use a 45-second recommendation prompt because it tests the decision line without inviting a full essay. Sentence one is the decision, sentence two is one reason, then stop cleanly.",
            recentCoachReplies: [
                "Use a 45-second recommendation prompt because it tests the decision line without inviting a full essay. Sentence one is the decision, sentence two is one reason, then stop cleanly.",
                "Because the filler interrupts the moment where authority should sound settled. The pause after the decision gives your reason somewhere to go without weakening the recommendation."
            ],
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.repetitiveDiscourseMove))
        #expect(!verdict.blocked)
    }

    @Test func repeatedProofTestBlocksWithAssessmentFallback() {
        let assessment = Self.quickMoveAssessment(
            proofTest: "Run a different proof: make the final sentence the ask, then stop."
        )
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Lead with the verdict and prove it once.",
            previousCoachReply: nil,
            turnDepth: .quickMove,
            assessment: assessment,
            evidenceCoverage: 0.5,
            proofTestRecentlyRepeated: true
        )
        #expect(verdict.issues.contains(.repeatedProofTest))
        #expect(verdict.blockingIssues.contains(.repeatedProofTest))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText == assessment.immediateCoachRead)
        #expect(verdict.fallbackText?.contains("Run a different proof") == true)
    }

    @Test func freshProofTestDoesNotTripRepeatedProofGate() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Lead with the verdict and prove it once.",
            previousCoachReply: nil,
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5,
            proofTestRecentlyRepeated: false
        )
        #expect(!verdict.issues.contains(.repeatedProofTest))
        #expect(!verdict.blocked)
    }

    // MARK: - Fallback selection

    @Test func fallbackPrefersCleanImmediateCoachRead() {
        let assessment = Self.quickMoveAssessment(
            proofTest: "Run one clean 60-second rep: verdict first, one reason, then stop."
        )
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "", // forces a block
            previousCoachReply: nil,
            turnDepth: .quickMove,
            assessment: assessment,
            evidenceCoverage: 0.5
        )
        #expect(verdict.blocked)
        #expect(assessment.immediateCoachRead.lowercased().contains("the signal i can use"))
        #expect(assessment.immediateCoachRead.lowercased().contains("try this next"))
        #expect(verdict.fallbackText == assessment.immediateCoachRead)
    }

    @Test func fallbackUsesHonestStaticLineWhenImmediateReadIsDirty() {
        // A proof test that itself leaks a placeholder marker → immediateCoachRead
        // is not a clean candidate → static honest line is used instead.
        let assessment = Self.quickMoveAssessment(proofTest: "placeholder reply")
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "",
            previousCoachReply: nil,
            turnDepth: .quickMove,
            assessment: assessment,
            evidenceCoverage: 0.5
        )
        #expect(verdict.blocked)
        #expect(verdict.fallbackText != assessment.immediateCoachRead)
        #expect(verdict.fallbackText == CoachReliabilityGate.staticFallback(turnDepth: .quickMove, surface: .text))
    }

    @Test func fallbackNeverReintroducesTheDuplicateItIsEscaping() {
        // The provider duplicated the previous reply. Even if the local read wraps
        // that same proof test in extra context, the fallback must not re-emit it.
        let dupe = "Run one 60-second rep with the verdict first, then one reason, then stop."
        let assessment = Self.quickMoveAssessment(proofTest: dupe)
        let verdict = CoachReliabilityGate.evaluate(
            replyText: dupe,
            previousCoachReply: dupe,
            turnDepth: .quickMove,
            assessment: assessment,
            evidenceCoverage: 0.5
        )
        #expect(verdict.blocked)
        #expect(CoachReliabilityGate.normalize(verdict.fallbackText ?? "") != CoachReliabilityGate.normalize(dupe))
        #expect(!(verdict.fallbackText ?? "").lowercased().contains(dupe.lowercased()))
    }

    @Test func staticFallbackVariesByDepthAndIsHonest() {
        for depth in CoachTurnDepth.allCases {
            let text = CoachReliabilityGate.staticFallback(turnDepth: depth, surface: .text)
            #expect(!text.isEmpty)
            // Honest fallbacks never fake certainty or fanfare.
            let lowered = text.lowercased()
            for banned in ["amazing", "nailed", "crushed", "you're ready", "guaranteed"] {
                #expect(!lowered.contains(banned), "fallback for \(depth) should not contain \(banned)")
            }
        }
    }

    @Test func liveSurfaceFallbackIsShorterThanTextSurface() {
        let live = CoachReliabilityGate.staticFallback(turnDepth: .trustRepair, surface: .live)
        let text = CoachReliabilityGate.staticFallback(turnDepth: .trustRepair, surface: .text)
        #expect(live.count <= text.count)
    }

    // MARK: - Greeting never gets a drill (the "Hi -> Pressure Drill" bug)

    /// The exact reply from the reported screenshot: a "Hi" answered with the
    /// deterministic `immediateCoachRead` drill because no live model replied.
    private static let screenshotDrillReply =
        "The opening is the next lever: put the verdict in sentence one, then prove it once. The signal I can use is Pressure Drill, 2/10, 1 fillers, 52s. Try this next: Open the next rep with the decision before any context."

    @Test func greetingAnsweredWithADrillBlocksAndGreetsBack() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: Self.screenshotDrillReply,
            previousCoachReply: "Run one 45-second answer: verdict in sentence one, one reason, then end on the exact ask and stop.",
            latestUserTurn: "Hi",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.4
        )
        #expect(verdict.issues.contains(.greetingWithDrill))
        #expect(verdict.blockingIssues.contains(.greetingWithDrill))
        #expect(verdict.blocked)
        // The substitute must be the warm greeting, NOT the drill / assessment read.
        #expect(verdict.fallbackText == CoachReliabilityGate.greetingFallback(surface: .text))
        let fb = (verdict.fallbackText ?? "").lowercased()
        #expect(!CoachReliabilityGate.replyDrillsInsteadOfGreeting(fb), "greeting fallback must not itself be a drill")
    }

    @Test func greetingAnsweredWarmlyDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Hey — good to see you. Want to jump back into the opener work, or is something else on your mind?",
            previousCoachReply: nil,
            latestUserTurn: "hey noum",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.4
        )
        #expect(!verdict.issues.contains(.greetingWithDrill))
        #expect(!verdict.blocked)
    }

    @Test func realCoachingTurnIsNeverTreatedAsAGreeting() {
        // A genuine coaching ask must still get its normal read, never the
        // greeting fallback — the drill markers here are legitimate.
        let verdict = CoachReliabilityGate.evaluate(
            replyText: Self.screenshotDrillReply,
            previousCoachReply: nil,
            latestUserTurn: "what should I work on next?",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.4
        )
        #expect(!verdict.issues.contains(.greetingWithDrill))
    }

    @Test func isGreetingOrSmallTalkDiscriminates() {
        for g in ["Hi", "hey", "Hello", "hey Noum", "yo", "how's it going?", "what's up", "thanks!", "good morning", "I'm back"] {
            #expect(TurnDepthClassifier.isGreetingOrSmallTalk(g), "\(g) should be a greeting")
        }
        for c in ["what should I do next?", "how do I stop rambling", "help me prep for my interview", "read my last rep", "thanks, what should I do next?", "how far off am I from authoritative?"] {
            #expect(!TurnDepthClassifier.isGreetingOrSmallTalk(c), "\(c) should NOT be a greeting")
        }
    }

    // MARK: - Canned fallback never repeats across turns

    @Test func staticFallbackVariantsAreDistinctHonestAndLiveShorter() {
        for depth in CoachTurnDepth.allCases {
            let textVariants = CoachReliabilityGate.staticFallbackVariants(turnDepth: depth, surface: .text)
            let liveVariants = CoachReliabilityGate.staticFallbackVariants(turnDepth: depth, surface: .live)
            #expect(textVariants.count >= 2, "need >=2 text variants to rotate for \(depth)")
            #expect(liveVariants.count >= 2, "need >=2 live variants to rotate for \(depth)")
            // Distinct within a surface so rotation actually changes the wording.
            #expect(Set(textVariants.map(CoachReliabilityGate.normalize)).count == textVariants.count)
            for (i, v) in textVariants.enumerated() {
                #expect(!v.isEmpty)
                let lowered = v.lowercased()
                for banned in ["amazing", "nailed", "crushed", "you're ready", "guaranteed"] {
                    #expect(!lowered.contains(banned), "text variant \(i) for \(depth) contains \(banned)")
                }
            }
            // The canonical (first) live line stays no longer than the text one.
            #expect(liveVariants[0].count <= textVariants[0].count)
        }
    }

    @Test func staticFallbackTwoArgIsTheFirstVariant() {
        // Back-compat: the zero-context helper is variant 0, so existing callers
        // and prior tests keep their exact contract.
        for depth in CoachTurnDepth.allCases {
            for surface in [CoachReplySurface.text, .live] {
                #expect(
                    CoachReliabilityGate.staticFallback(turnDepth: depth, surface: surface) ==
                    CoachReliabilityGate.staticFallbackVariants(turnDepth: depth, surface: surface)[0]
                )
            }
        }
    }

    @Test func selectStaticFallbackAvoidsRecentlyShownVariant() {
        let variants = CoachReliabilityGate.staticFallbackVariants(turnDepth: .quickMove, surface: .text)
        // The user just saw variant 0 — the gate must not hand it straight back.
        let picked = CoachReliabilityGate.selectStaticFallback(
            turnDepth: .quickMove,
            surface: .text,
            previousCoachReply: variants[0],
            recentCoachReplies: [variants[0]]
        )
        #expect(picked != variants[0])
        #expect(variants.contains(picked))
    }

    @Test func selectStaticFallbackWithNoHistoryReturnsCanonicalVariant() {
        let picked = CoachReliabilityGate.selectStaticFallback(
            turnDepth: .deepAssessment,
            surface: .text,
            previousCoachReply: nil,
            recentCoachReplies: []
        )
        #expect(picked == CoachReliabilityGate.staticFallback(turnDepth: .deepAssessment, surface: .text))
    }

    @Test func isCleanCandidateRejectsNearDuplicateOfRecentReply() {
        let recent = "your close trails off so the ask never lands with conviction in the room"
        let nearDupe = "your close trails off so the ask never lands with conviction in the busy room"
        #expect(!CoachReliabilityGate.isCleanCandidate(nearDupe, previousCoachReply: nil, recentCoachReplies: [recent]))
        // A genuinely different candidate stays clean against the same recent set.
        #expect(CoachReliabilityGate.isCleanCandidate(
            "Lead with the verdict in sentence one, then prove it with a single concrete example.",
            previousCoachReply: nil,
            recentCoachReplies: [recent]
        ))
    }

    @Test func gateFallbackDoesNotRepeatCannedLineShownRecently() {
        // The reply is empty (forces a block) and the assessment read is dirty
        // (its proof test leaks a placeholder → static path). The exact canned
        // line was already shown a turn ago, so the substituted fallback must be
        // a different honest variant — never the same canned line twice.
        let cannedText = CoachReliabilityGate.staticFallback(turnDepth: .quickMove, surface: .text)
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "",
            previousCoachReply: cannedText,
            recentCoachReplies: [cannedText],
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(proofTest: "placeholder reply"),
            evidenceCoverage: 0.5
        )
        #expect(verdict.blocked)
        #expect(!(verdict.fallbackText ?? "").isEmpty)
        #expect(verdict.fallbackText != cannedText)
        #expect(
            CoachReliabilityGate.normalize(verdict.fallbackText ?? "") !=
            CoachReliabilityGate.normalize(cannedText)
        )
    }

    @Test func gateFallbackSkipsAssessmentReadThatEchoesARecentTurn() {
        // The assessment's on-device read is otherwise clean, but it near-matches
        // a coach turn from two turns ago → the gate must fall through to a static
        // variant instead of re-serving the same read.
        let read = Self.quickMoveAssessment().immediateCoachRead
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "",
            previousCoachReply: "Some unrelated earlier coaching line about your opener.",
            recentCoachReplies: [read],
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(verdict.blocked)
        #expect(!(verdict.fallbackText ?? "").isEmpty)
        #expect(
            CoachReliabilityGate.normalize(verdict.fallbackText ?? "") !=
            CoachReliabilityGate.normalize(read)
        )
    }

    @Test func gateDisabledFlagIsRespectedByCaller() {
        // The gate itself is always pure; the disable switch lives on the flag.
        // This pins the default so a regression that flips it off is visible.
        #expect(CoachBrainFlags.reliabilityGateEnabled == true)
    }

    // MARK: - Golden scenarios (derived from the deep-research report)

    /// Each golden case pairs a representative *good* reply (must pass clean of
    /// blocking issues) with a degenerate variant (must block + yield a non-empty
    /// truthful fallback). The degenerate variant rotates through the four hard
    /// failure modes so every block path is exercised across the ten cases.
    private struct Golden {
        let id: String
        let depth: CoachTurnDepth
        let good: String
        let bad: String
        let previousCoachReply: String?
    }

    private static let goldens: [Golden] = [
        Golden(
            id: "examples-in-sessions",
            depth: .groundedRead,
            good: "In your last rep you opened with context for nine seconds before the point — that's the lag. Next time, name the decision first.",
            bad: "",
            previousCoachReply: nil
        ),
        Golden(
            id: "pushback-after-partial-agreement",
            depth: .trustRepair,
            good: "Fair — you're right that a drill isn't what you asked for. Straight answer: your close trails off, so the ask never lands.",
            bad: "Lead with the decision, then one reason. Try a 60-second rep.",
            previousCoachReply: "Lead with the decision, then one reason. Try a 60-second rep."
        ),
        Golden(
            id: "how-far-off-am-i",
            depth: .deepAssessment,
            good: "Honest read: you're closer mechanically than under pressure. I don't have a stakes rep yet, so I won't claim you're ready.",
            bad: "placeholder reply",
            previousCoachReply: nil
        ),
        Golden(
            id: "robotic-cold-complaint",
            depth: .trustRepair,
            good: "You're right — I sounded cold and clinical. Straight answer: the one thing holding you back is the soft ending.",
            bad: "turnDepth=trustRepair toneMode=repair",
            previousCoachReply: nil
        ),
        Golden(
            id: "tts-formatting-complaint",
            depth: .trustRepair,
            good: "Fair, the formatting should never reach the voice. Plain answer: slow the open by one beat and put the verdict first.",
            bad: "",
            previousCoachReply: nil
        ),
        Golden(
            id: "what-next-after-decent-rep",
            depth: .quickMove,
            // good differs from the prior turn; bad is the verbatim repeat that
            // must be caught as a duplicate.
            good: "Solid rep — open and pace held. The only edge left is the close: land the ask, then stop.",
            bad: "Good rep. The one remaining edge is your close — make the final sentence the ask, then stop.",
            previousCoachReply: "Good rep. The one remaining edge is your close — make the final sentence the ask, then stop."
        ),
        Golden(
            id: "ending-stronger",
            depth: .quickMove,
            good: "Your endings trail into 'yeah, so'. End on the ask itself and leave the silence there.",
            bad: "coach read coming",
            previousCoachReply: nil
        ),
        Golden(
            id: "opening-stronger",
            depth: .quickMove,
            good: "Your point arrives late. Put the verdict in sentence one, then prove it once.",
            bad: "{\"surfaceText\":\"...\"}",
            previousCoachReply: nil
        ),
        Golden(
            id: "add-depth-without-rambling",
            depth: .quickMove,
            good: "Add one concrete example after the verdict — not three. One detail makes it memorable; more makes it ramble.",
            bad: "",
            previousCoachReply: nil
        ),
        Golden(
            id: "freeze-before-answering",
            depth: .groundedRead,
            good: "The freeze is a search for the perfect open. Buy the beat out loud: 'The short answer is…', then commit.",
            bad: "Your response here",
            previousCoachReply: nil
        )
    ]

    @Test func goldenGoodRepliesPassCleanOfBlockingIssues() {
        for golden in Self.goldens {
            let verdict = CoachReliabilityGate.evaluate(
                replyText: golden.good,
                previousCoachReply: golden.previousCoachReply,
                turnDepth: golden.depth,
                assessment: Self.quickMoveAssessment(),
                evidenceCoverage: 0.6
            )
            #expect(verdict.blockingIssues.isEmpty, "golden \(golden.id) good reply should not block: \(verdict.issues)")
            #expect(!verdict.blocked, "golden \(golden.id) good reply should ship")
        }
    }

    @Test func goldenDegenerateRepliesBlockWithTruthfulFallback() {
        for golden in Self.goldens {
            let verdict = CoachReliabilityGate.evaluate(
                replyText: golden.bad,
                previousCoachReply: golden.previousCoachReply,
                turnDepth: golden.depth,
                assessment: Self.quickMoveAssessment(),
                evidenceCoverage: 0.6
            )
            #expect(verdict.blocked, "golden \(golden.id) degenerate reply should block")
            #expect(!(verdict.fallbackText ?? "").isEmpty, "golden \(golden.id) must yield a non-empty fallback")
            // The fallback itself must be clean — never a second defect.
            #expect(
                CoachReliabilityGate.isCleanCandidate(verdict.fallbackText ?? "", previousCoachReply: golden.previousCoachReply),
                "golden \(golden.id) fallback must itself be clean"
            )
        }
    }
}
