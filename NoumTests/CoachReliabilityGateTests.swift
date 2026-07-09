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

    private static func vulnerableTrustRepairAssessment(
        proofTest: String = "Test a smaller version in the next rep: say only the disagreement and one calm reason, then stop before defending it.",
        evidence: [String] = ["This week you held composure through an interruption before the close."]
    ) -> CoachAssessment {
        CoachAssessment(
            turnDepth: .trustRepair,
            surface: .text,
            questionRestatement: "It's not easy.",
            directVerdict: "The hard part is sentence one carrying the social risk.",
            confidence: 0.55,
            evidenceUsed: evidence,
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: proofTest,
            responseMode: .immediateOnly,
            toneMode: .repair,
            repairFocus: "no, it is not easy"
        )
    }

    private static func recurringCloseRushAssessment() -> CoachAssessment {
        CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "What should I work on next?",
            directVerdict: "The close is the next edge.",
            confidence: 0.72,
            evidenceUsed: [
                "POSITIONAL TREND: You've rushed the close in 4 of your last 5 reps that had a fast stretch — the fastest stretch keeps landing there. It showed up in 5 of your last 6 reps overall. A recurring position, not a fixed trait."
            ],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Plant one silent beat before the final line.",
            responseMode: .immediateOnly
        )
    }

    private static func metadataSelfKnowledgeAssessment() -> CoachAssessment {
        CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "What do you know about me?",
            directVerdict: "The known pattern is racing to fill silence in hard conversations.",
            confidence: 0.68,
            evidenceUsed: [
                "Goal: sounding like yourself in hard conversations.",
                "Pattern: when a moment turns tense, you speed up to outrun the silence.",
                "Baseline: pace around 170 WPM; streak: 12 days."
            ],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Do not prescribe here; answer what the coach knows.",
            responseMode: .immediateOnly
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

    @Test func trustRepairGenericWrapperComplaintWithSafeSignalPasses() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair push. That sounded like a generic AI wrapper, not a coach read. One safe signal is that your recommendation arrived late, so put the recommendation in sentence one on the next rep, give one reason, then stop.",
            previousCoachReply: "Here are some tips: be confident, speak clearly, and practice.",
            latestUserTurn: "This feels like a generic AI wrapper.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.noAttunementOnPushback))
        #expect(!verdict.issues.contains(.thinTrustRepair))
        #expect(!verdict.blocked)
    }

    @Test func trustRepairGenericWrapperRepairPasses() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair push. That sounded like a generic AI wrapper, not a coach read. The safe signal I can use is that your recommendation arrived late, so the next rep is sentence-one recommendation, one reason, stop.",
            previousCoachReply: "Here are some tips: be confident, speak clearly, and practice.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(!verdict.issues.contains(.noAttunementOnPushback))
        #expect(!verdict.issues.contains(.thinTrustRepair))
        #expect(!verdict.blocked)
    }

    @Test func trustRepairCouldGoToAnyoneSpecificRepairPasses() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair. That read like it could go to anyone, and you deserve better this close to the investor call. The specific pattern is that you hedged the ask twice — \"we're hoping to maybe raise around\" instead of stating the number. State the raise as one flat sentence, then stop.",
            previousCoachReply: "Earlier generic pitch advice.",
            latestUserTurn: "This is so generic, it could be for anyone.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.7
        )

        #expect(!verdict.issues.contains(.noAttunementOnPushback))
        #expect(!verdict.issues.contains(.thinTrustRepair))
        #expect(!verdict.blocked)
    }

    @Test func tooGenericScaffoldedRepairBlocksWithSpecificFallback() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair. That read like it could go to anyone. The specific thing: on that pitch rep you hedged the ask twice instead of the number, more than your 7 fillers do. Next rep: state the raise as one flat sentence, then stop.",
            previousCoachReply: "Earlier generic pitch advice.",
            latestUserTurn: "This is so generic, it could be for anyone.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.7
        )

        #expect(verdict.issues.contains(.genericRepairScaffolded))
        #expect(verdict.blockingIssues.contains(.genericRepairScaffolded))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("That was too generic"))
        #expect(fallback.contains("The specific pattern is the ask itself"))
        #expect(fallback.contains("State the raise as one flat sentence"))
        #expect(!lowered.contains("specific thing:"))
        #expect(!lowered.contains("next rep:"))
        #expect(!lowered.contains("fillers"))
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

    @Test func notInformativeRepairScaffoldBlocksWithSpecificFallback() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair. That was fluff, not coaching. Real read: score 74, but your point did not arrive until sentence four. Next rep: say the point in sentence one, then back it. Cut the throat-clearing.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "That's not informative.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )

        #expect(verdict.issues.contains(.notInformativeRepairScaffold))
        #expect(verdict.blockingIssues.contains(.notInformativeRepairScaffold))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("The useful read is that your point arrived in sentence four"))
        #expect(fallback.contains("Make sentence one the point"))
        #expect(!lowered.contains("real read:"))
        #expect(!lowered.contains("score"))
        #expect(!lowered.contains("cut the"))
    }

    @Test func cleanNotInformativeRepairDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair. I was too vague. The useful read is that your point arrived in sentence four after three warm-up sentences. Make sentence one the point; let one reason do the supporting.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "That's not informative.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )

        #expect(!verdict.issues.contains(.notInformativeRepairScaffold))
        #expect(!verdict.issues.contains(.thinTrustRepair))
        #expect(!verdict.blocked)
    }

    @Test func straightAnswerWithoutExplicitSplitBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair. That was waffle. Straight answer: yes. Fillers dropped from 5.5 to 3.2 a minute over two weeks, and your last rep hit 3 in 60 seconds — your best on record. What's still moving is pace under pressure. Next rep, hold one silent beat before you answer a hard question.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "Why can't you just give me a straight answer?",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.7
        )

        #expect(verdict.issues.contains(.straightAnswerSplitMissing))
        #expect(verdict.blockingIssues.contains(.straightAnswerSplitMissing))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("Straight answer: yes on fillers; no on pace under pressure"))
        #expect(fallback.contains("one silent beat"))
        #expect(!lowered.contains("hit 3"))
        #expect(!lowered.contains("scored"))
    }

    @Test func cleanStraightAnswerSplitDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair. Straight answer: yes on fillers; no on pace under pressure. Your filler trend is moving the right way, but the rush still shows up when the pressure rises. Next rep, hold one silent beat before the hard answer.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "Why can't you just give me a straight answer?",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.7
        )

        #expect(!verdict.issues.contains(.straightAnswerSplitMissing))
        #expect(!verdict.issues.contains(.thinTrustRepair))
        #expect(!verdict.blocked)
    }

    @Test func paceSelfFrustrationReportVoiceBlocksWithPauseGapFallback() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "It's not the speed. Yesterday's rep was clean and scored 71, but pace sat near 215 with almost no gap between sentences. So the fix isn't slowing down, it's the pause.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "I talk way too fast, people can't keep up.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(evidence: [
                "latest rep: Timed, score 71, clean content",
                "pace estimate: 215 WPM",
                "pause rate: 0.09"
            ]),
            evidenceCoverage: 0.7
        )

        #expect(verdict.issues.contains(.paceSelfFrustrationReportVoice))
        #expect(verdict.blockingIssues.contains(.paceSelfFrustrationReportVoice))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("215 WPM"))
        #expect(fallback.contains("0.09 pause rate"))
        #expect(fallback.contains("Fix the pause, not the speed"))
        #expect(fallback.contains("one silent beat"))
        #expect(!lowered.contains("scored"))
        #expect(!lowered.contains("score 71"))
    }

    @Test func cleanPaceSelfFrustrationReadDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "You're not imagining it: 215 words a minute with a 0.09 pause rate means the gap between sentences is disappearing. Fix the pause, not the speed. Next rep, hold one silent beat after every full stop and see if people track you without forcing a slower voice.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "I talk way too fast, people can't keep up.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(evidence: [
                "pace estimate: 215 WPM",
                "pause rate: 0.09"
            ]),
            evidenceCoverage: 0.7
        )

        #expect(!verdict.issues.contains(.paceSelfFrustrationReportVoice))
        #expect(!verdict.blocked)
    }

    @Test func rambleScaffoldedReplyBlocksWithStopRuleFallback() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "You don't lose the thread — you keep adding to it. Yesterday you opened with the actual point, then stacked three side stories before circling back to a weaker version of it. So the fix isn't focus, it's a stop signal. Next rep: say your point, one line of support, then cut before the first side story. One point, then silence.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "I ramble — I start a point and three minutes later I'm somewhere else.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.7
        )

        #expect(verdict.issues.contains(.rambleStoppingRuleMiss))
        #expect(verdict.blockingIssues.contains(.rambleStoppingRuleMiss))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("You do not lose the thread"))
        #expect(fallback.contains("weaker repeat"))
        #expect(fallback.contains("Use a hard stop"))
        #expect(!lowered.contains("next rep:"))
        #expect(CoachReliabilityGate.wordCount(CoachReliabilityGate.normalize(fallback)) <= 45)
    }

    @Test func cleanRambleStopRuleReadDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "You do not lose the thread; you keep reopening it. The tell is the weaker repeat at the end after the side stories. Use a hard stop: state the point, give one support line, then silence.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "I ramble — I start a point and three minutes later I'm somewhere else.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.7
        )

        #expect(!verdict.issues.contains(.rambleStoppingRuleMiss))
        #expect(!verdict.blocked)
    }

    @Test func leadershipStatusReportWithRawScoreAndNoTonightRehearsalBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "The room zones out because nine updates all land at the same weight — your last rep was clean at 77, but with no through-line, nothing gets to matter more than anything else. For tomorrow: pick the one update that actually changes what they do this week, open on it, and say the so what in a sentence before any detail.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "I have to give the weekly leadership update to the whole department tomorrow. It always feels like I'm just reading a status report and people zone out. Help.",
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment(),
            evidenceCoverage: 0.75
        )

        #expect(verdict.issues.contains(.leadershipStatusReportMiss))
        #expect(verdict.blockingIssues.contains(.leadershipStatusReportMiss))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("real risk for tomorrow"))
        #expect(fallback.contains("The fix is hierarchy"))
        #expect(fallback.contains("Tonight, write the opener"))
        #expect(fallback.contains("Say it aloud"))
        #expect(!lowered.contains("77"))
        #expect(!lowered.contains("score"))
    }

    @Test func cleanLeadershipStatusReportRehearsalDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "That is a real risk for tomorrow: if every update lands at the same weight, the room hears a status report. The fix is hierarchy, not delivery polish. Tonight, write the opener as: \"The one thing that matters this week is X because Y.\" Say it aloud three times, then let the other items become quick support.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "I have to give the weekly leadership update to the whole department tomorrow. It always feels like I'm just reading a status report and people zone out. Help.",
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment(),
            evidenceCoverage: 0.75
        )

        #expect(!verdict.issues.contains(.leadershipStatusReportMiss))
        #expect(!verdict.blocked)
    }

    @Test func recurringCloseRushTrendWithoutOverallPrevalenceBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "The open landed — that read came through in today's rep too. The one thing to fix is the close. Your last 20 seconds sped up and the final line ran together, and that pattern has shown up in 4 of your last 5 reps. Hit your second-to-last sentence, hold a silent beat, then say the final line at half the pace you think you need.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "What should I work on next? The last one felt solid to me.",
            turnDepth: .groundedRead,
            assessment: Self.recurringCloseRushAssessment(),
            evidenceCoverage: 0.8
        )

        #expect(verdict.issues.contains(.recurringCloseTrendDiluted))
        #expect(verdict.blockingIssues.contains(.recurringCloseTrendDiluted))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        #expect(fallback.contains("solid feeling is real"))
        #expect(fallback.contains("4 of the last 5"))
        #expect(fallback.contains("5 of the last 6 overall"))
        #expect(fallback.contains("recurring spot, not a trait"))
        #expect(fallback.contains("Plant one silent beat before the final line"))
        #expect(!fallback.contains("second-to-last"))
        #expect(!fallback.contains("half the pace"))
    }

    @Test func cleanRecurringCloseRushTrendDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "That solid feeling is real, and the next edge is specific: the fastest stretch keeps landing at the close. It has shown up in 4 of the last 5 reps with a fast stretch, and 5 of the last 6 overall — a recurring spot, not a trait. Plant one silent beat before the final line.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "What should I work on next? The last one felt solid to me.",
            turnDepth: .groundedRead,
            assessment: Self.recurringCloseRushAssessment(),
            evidenceCoverage: 0.8
        )

        #expect(!verdict.issues.contains(.recurringCloseTrendDiluted))
        #expect(!verdict.blocked)
    }

    @Test func metadataSelfKnowledgeAnswerWithNextRepPrescriptionBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Here's the shape of it: you came in five weeks ago wanting to sound like yourself in the hard conversations, and you've shown up twelve days running to get there. The thread I'm working is that when a moment turns tense you speed up to outrun the silence — your 170 pace reads more like nerves than a habit. So the thing to test: next rep, hold one silent beat before you answer a hard question.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "What does your system actually know about me?",
            turnDepth: .groundedRead,
            assessment: Self.metadataSelfKnowledgeAssessment(),
            evidenceCoverage: 0.78
        )

        #expect(verdict.issues.contains(.metadataSelfKnowledgeMiss))
        #expect(verdict.blockingIssues.contains(.metadataSelfKnowledgeMiss))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        #expect(fallback.contains("Real read, not a script"))
        #expect(fallback.contains("sound like yourself in hard conversations"))
        #expect(fallback.contains("race to fill silence"))
        #expect(fallback.contains("170 WPM"))
        #expect(fallback.contains("12-day streak"))
        #expect(fallback.contains("wait on a next drill"))
        #expect(!fallback.lowercased().contains("next rep"))
        #expect(!fallback.lowercased().contains("system prompt"))
    }

    @Test func cleanMetadataSelfKnowledgeAnswerDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Real read, not a script: you came in wanting to sound like yourself in hard conversations. The pattern I know is that tense moments make you race to fill silence; the numbers I can safely name are a pace baseline around 170 WPM and a 12-day streak. That is what I know. I will wait on a next drill until you ask for one.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "What does your system actually know about me?",
            turnDepth: .groundedRead,
            assessment: Self.metadataSelfKnowledgeAssessment(),
            evidenceCoverage: 0.78
        )

        #expect(!verdict.issues.contains(.metadataSelfKnowledgeMiss))
        #expect(!verdict.blocked)
    }

    @Test func repetitionCalloutWithScorecardResidueBlocksToCourseCorrection() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair. I did. That rep with a clean close — no reason to run it again.\n\nNew target: pace. Record 60 seconds and deliberately slow your three most important words, holding a silent beat before each.",
            previousCoachReply: "Good. Now record another 60-second answer and put the point up front, then stop clean.",
            latestUserTurn: "You're repeating yourself.",
            turnDepth: .trustRepair,
            assessment: Self.vulnerableTrustRepairAssessment(),
            evidenceCoverage: 0.7
        )

        #expect(verdict.issues.contains(.repetitionCourseCorrectionMiss))
        #expect(verdict.blockingIssues.contains(.repetitionCourseCorrectionMiss))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("repeat the same target"))
        #expect(fallback.contains("You led cleanly"))
        #expect(fallback.contains("New target: pace"))
        #expect(fallback.contains("hold one silent beat"))
        #expect(!lowered.contains("hit 82"))
        #expect(!lowered.contains("lead with the point"))
        #expect(!lowered.contains("point up front"))
    }

    @Test func cleanRepetitionCourseCorrectionDoesNotBlock() {
        let reply = "Fair. I did repeat the same target. You led cleanly and the close held, so there is no reason to run that drill again. New target: pace. Slow the three words that carry the point, then hold one silent beat before the next sentence."
        let verdict = CoachReliabilityGate.evaluate(
            replyText: reply,
            previousCoachReply: "Good. Now record another 60-second answer and put the point up front, then stop clean.",
            latestUserTurn: "You're repeating yourself.",
            turnDepth: .trustRepair,
            assessment: Self.vulnerableTrustRepairAssessment(),
            evidenceCoverage: 0.7
        )

        #expect(!verdict.issues.contains(.repetitionCourseCorrectionMiss))
        #expect(!verdict.issues.contains(.thinTrustRepair))
        #expect(!verdict.blocked)
    }

    @Test func vulnerablePushbackEndingOnBareDiagnosticQuestionBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "No, it isn't — and a freeze in the room is a different animal than the reps you keep landing clean. When it hits, what goes first: the thought itself, or the words that were meant to carry it?",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "It's not easy.",
            turnDepth: .trustRepair,
            assessment: Self.vulnerableTrustRepairAssessment(),
            evidenceCoverage: 0.65
        )

        #expect(verdict.issues.contains(.vulnerablePushbackQuestionBurden))
        #expect(verdict.blockingIssues.contains(.vulnerablePushbackQuestionBurden))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        #expect(fallback.contains("No, it is not easy"))
        #expect(fallback.contains("held composure through an interruption"))
        #expect(fallback.contains("Test a smaller version"))
        #expect(!fallback.lowercased().contains("what goes first"))
    }

    @Test func vulnerablePushbackWithSmallStepInvitationDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "No, it is not easy. This week you held composure through an interruption, so keep the next step small: test a smaller version in the next rep, then stop before defending it. Want to try?",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "It's not easy.",
            turnDepth: .trustRepair,
            assessment: Self.vulnerableTrustRepairAssessment(),
            evidenceCoverage: 0.65
        )

        #expect(!verdict.issues.contains(.vulnerablePushbackQuestionBurden))
        #expect(!verdict.blocked)
    }

    @Test func voiceGoalStateDirectiveBlocksWithCoachRecommendationFallback() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Start with Authoritative. Tap to confirm and I'll lock it in.",
            previousCoachReply: nil,
            latestUserTurn: "Just set me to authoritative.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.4
        )

        #expect(verdict.issues.contains(.goalStateDirectiveLeak))
        #expect(verdict.blockingIssues.contains(.goalStateDirectiveLeak))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("Authoritative is a sensible recommendation"))
        #expect(!lowered.contains("tap"))
        #expect(!lowered.contains("lock it"))
        #expect(!lowered.contains("i'll set"))
    }

    @Test func voiceChoiceUncertaintyFallbackAsksTheRoomQuestion() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "For meetings I'd start with Authoritative. Tap to confirm and I'll lock it in.",
            previousCoachReply: nil,
            latestUserTurn: "What voice should I even pick? There are six and I don't know.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.4
        )

        #expect(verdict.issues.contains(.goalStateDirectiveLeak))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("Start with Authoritative"))
        #expect(fallback.contains("short verdicts that hold the floor"))
        #expect(fallback.contains("Executive presence as the close second"))
        #expect(fallback.contains("one voice to test"))
        #expect(!lowered.contains("do not choose"))
        #expect(!lowered.contains("tap"))
        #expect(!lowered.contains("lock it"))
    }

    @Test func engagingGoalChangeFallbackCarriesProgressWithoutRawMetrics() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Before you pivot, know your authoritative work is landing: 80 this week, 3 fillers in 68 seconds, three weeks in. That answer picks the voice, then tap to confirm and I'll lock it in.",
            previousCoachReply: nil,
            latestUserTurn: "I think I want to sound more engaging.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.7
        )

        #expect(verdict.issues.contains(.goalStateDirectiveLeak))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("authoritative work is already landing"))
        #expect(fallback.contains("Storytelling"))
        #expect(fallback.contains("Warm"))
        #expect(fallback.contains("What changed"))
        #expect(!lowered.contains("80 this week"))
        #expect(!lowered.contains("3 fillers"))
        #expect(!lowered.contains("tap"))
        #expect(!lowered.contains("lock it"))
    }

    @Test func voiceGoalRawMetricsWithoutDirectiveStillBlocks() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Before you pivot, know your authoritative work is landing: 80 this week, 3 fillers in 68 seconds, three weeks in. Engaging maps closest to Storytelling, with Warm as the softer backup. What changed?",
            previousCoachReply: nil,
            latestUserTurn: "I think I want to sound more engaging.",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.7
        )

        #expect(verdict.issues.contains(.goalStateReportVoiceLeak))
        #expect(!verdict.issues.contains(.goalStateDirectiveLeak))
        #expect(verdict.blockingIssues.contains(.goalStateReportVoiceLeak))
        #expect(verdict.blocked)
        let fallback = verdict.fallbackText ?? ""
        let lowered = fallback.lowercased()
        #expect(fallback.contains("authoritative work is already landing"))
        #expect(fallback.contains("Storytelling"))
        #expect(fallback.contains("Warm"))
        #expect(fallback.contains("What changed"))
        #expect(!lowered.contains("80 this week"))
        #expect(!lowered.contains("3 fillers"))
        #expect(!lowered.contains("68 seconds"))
    }

    @Test func voiceGoalCleanRecommendationDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Authoritative is the right lane for getting talked over: point first, one reason, clean stop. Executive presence is the close second if the room is senior rather than interruptive.",
            previousCoachReply: nil,
            latestUserTurn: "What voice should I even pick?",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.4
        )

        #expect(!verdict.issues.contains(.goalStateDirectiveLeak))
        #expect(!verdict.blocked)
    }

    @Test func genericReplyAfterTrustRepairBlocksCarryoverBreak() {
        let previousRepair = "Fair push: that was advice, not coaching. The specific read is order: warmth is arriving before the recommendation, so the point lands late. Put the recommendation first, add one reassurance after it, then stop."
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
        let previousRepair = "Fair push: that was advice, not coaching. The specific read is order: warmth is arriving before the recommendation, so the point lands late. Put the recommendation first, add one reassurance after it, then stop."
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
                "The confidence leak is after the ask: maybe or just reopens the decision, so the fix is a clean stop. Make the ask, stop, and listen for whether the final sentence still sounds clean without the qualifier."
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
                "The confidence leak is after the ask: maybe or just reopens the decision, so the fix is a clean stop. Make the ask, stop, and listen for whether the final sentence still sounds clean without the qualifier."
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

    @Test func coachThisPlaceholderFallbackUsesHonestEvidenceGapNotice() throws {
        let assessment = Self.quickMoveAssessment(
            proofTest: "Run one clean 60-second rep: verdict first, one reason, then stop."
        )
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "TODO: generate coach response here.",
            previousCoachReply: nil,
            latestUserTurn: "Can you coach this?",
            turnDepth: .quickMove,
            assessment: assessment,
            evidenceCoverage: 0.1
        )
        let fallback = try #require(verdict.fallbackText)
        #expect(verdict.blocked)
        #expect(verdict.issues.contains(.placeholder))
        #expect(fallback == CoachReliabilityGate.coachThisEvidenceGapFallback(surface: .text))
        #expect(fallback != assessment.immediateCoachRead)
        #expect(fallback != CoachReliabilityGate.staticFallback(turnDepth: .quickMove, surface: .text))
        #expect(!fallback.lowercased().contains("verdict first"))
        #expect(!fallback.lowercased().contains("decision up front"))
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

    // MARK: - Fallback-path audit (grades what ships when NO live model answers)

    /// The RALPH benchmark turns + greetings, swept through the REAL deterministic
    /// path (TurnDepthClassifier -> truthfulFallback). This is the path the Arena's
    /// prompt+model runs never exercise — exactly where the "Hi -> Pressure Drill"
    /// bug lived unseen while reports read ~70/100. Every fallback the pipeline can
    /// ship must be: non-empty, clean (no placeholder/scaffold), a warm hello on a
    /// greeting (never a drill), attuned on trust repair, and never a verbatim
    /// repeat of the fallback the user just saw.
    private static let fallbackAuditTurns: [String] = [
        "Hi", "hey noum", "what's up",
        "How far off am I from sounding authoritative?",
        "That's not informative.",
        "Okay that's cool, however I lose my train of thought.",
        "It's not that easy.",
        "You're repeating yourself.",
        "Why did that answer land badly?",
        "I'm exhausted.",
        "I've got my final round interview tomorrow.",
        "I have to give the leadership update tomorrow.",
        "What do you know about me?"
    ]

    /// A depth-faithful assessment like the reasoning pass would build: trust
    /// repair carries a repairFocus so its immediateCoachRead opens by
    /// acknowledging, other depths carry the drill-shaped read.
    private static func fallbackAuditAssessment(for depth: CoachTurnDepth) -> CoachAssessment {
        CoachAssessment(
            turnDepth: depth,
            surface: .text,
            questionRestatement: "audit",
            directVerdict: depth == .trustRepair
                ? "The repair is to name the miss first, then answer with one useful move."
                : "The opening is the next lever: put the verdict in sentence one.",
            confidence: 0.45,
            evidenceUsed: ["latest rep: Timed, 7/10, 1 filler, 58s"],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Run one 60-second rep with the verdict first, then one reason, then stop.",
            responseMode: .immediateOnly,
            toneMode: depth == .trustRepair ? .repair : .prescribe,
            repairFocus: depth == .trustRepair ? "I missed the actual question before prescribing" : nil
        )
    }

    @Test func fallbackPathAuditEveryBenchmarkTurnShipsACleanCoachReply() {
        for turn in Self.fallbackAuditTurns {
            let depth = TurnDepthClassifier.classify(userText: turn)
            let assessment = Self.fallbackAuditAssessment(for: depth)
            let fallback = CoachReliabilityGate.truthfulFallback(
                turnDepth: depth,
                assessment: assessment,
                surface: .text,
                previousCoachReply: nil,
                recentCoachReplies: [],
                latestUserTurn: turn
            )
            #expect(!fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(turn): empty fallback")
            #expect(
                CoachReliabilityGate.isCleanCandidate(fallback, previousCoachReply: nil),
                "\(turn): fallback leaks placeholder/scaffold"
            )
            let lowered = CoachReliabilityGate.normalize(fallback)
            if TurnDepthClassifier.isGreetingOrSmallTalk(turn) {
                #expect(
                    !CoachReliabilityGate.replyDrillsInsteadOfGreeting(lowered),
                    "\(turn): greeting got a drill fallback: \(fallback)"
                )
            } else if depth == .trustRepair {
                #expect(
                    CoachReliabilityGate.openingAcknowledges(fallback),
                    "\(turn): trust-repair fallback does not acknowledge: \(fallback)"
                )
            }
        }
    }

    @Test func fallbackPathAuditConsecutiveFallbacksNeverRepeatVerbatim() {
        for turn in Self.fallbackAuditTurns where !TurnDepthClassifier.isGreetingOrSmallTalk(turn) {
            let depth = TurnDepthClassifier.classify(userText: turn)
            let assessment = Self.fallbackAuditAssessment(for: depth)
            let first = CoachReliabilityGate.truthfulFallback(
                turnDepth: depth,
                assessment: assessment,
                surface: .text,
                previousCoachReply: nil,
                recentCoachReplies: [],
                latestUserTurn: turn
            )
            // Same turn again with the first fallback as the previous coach reply —
            // the "it keeps sending the same canned line" loop must not reproduce.
            let second = CoachReliabilityGate.truthfulFallback(
                turnDepth: depth,
                assessment: assessment,
                surface: .text,
                previousCoachReply: first,
                recentCoachReplies: [first],
                latestUserTurn: turn
            )
            #expect(
                CoachReliabilityGate.normalize(first) != CoachReliabilityGate.normalize(second),
                "\(turn): back-to-back fallbacks are verbatim-identical"
            )
        }
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
        // The substitute may keep the active thread, but must be a warm greeting,
        // NOT the drill / assessment read.
        #expect(verdict.fallbackText == "Hey — good to see you back. Pick up with the opener: lead with the recommendation, give one reason, then stop.")
        let fb = (verdict.fallbackText ?? "").lowercased()
        #expect(!CoachReliabilityGate.replyDrillsInsteadOfGreeting(fb), "greeting fallback must not itself be a drill")
    }

    @Test func greetingFallbackUsesCloseThreadWhenAssessmentHasOne() {
        let assessment = Self.quickMoveAssessment(
            proofTest: "Land the final sentence flat, then stop.",
            evidence: ["The close held once but softened once."]
        )
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Good to have you back. Yesterday the close held once but softened once, so the target stands: land the final sentence flat and stop. Run one rep and make the whole point closing clean.",
            previousCoachReply: "Earlier read.",
            latestUserTurn: "Hi",
            turnDepth: .quickMove,
            assessment: assessment,
            evidenceCoverage: 0.65
        )

        #expect(verdict.issues.contains(.greetingWithDrill))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText == "Hey — good to see you back. Pick up with the close: land the final sentence flat, then stop.")
        let fb = (verdict.fallbackText ?? "").lowercased()
        #expect(!CoachReliabilityGate.replyDrillsInsteadOfGreeting(fb), "threaded greeting fallback must not itself be a drill")
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

    // MARK: - Off-topic tests never get metric drills

    /// The replay failure shape for `off-topic-egg`: the user sends a one-word
    /// test and the reply dumps recent stats plus a drill. This must be replaced
    /// with a composed redirect, not sanitized into a brusque coaching command.
    private static let offTopicMetricDrillReply =
        "Egg won't sharpen you. This will: today's rep hit 80, 3 fillers, tight and clean. Run one more Timed rep and hold a silent beat where those fillers landed — aim to beat 3."

    @Test func offTopicTestAnsweredWithMetricDrillBlocksAndRedirects() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: Self.offTopicMetricDrillReply,
            previousCoachReply: nil,
            latestUserTurn: "egg",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.4
        )

        #expect(verdict.issues.contains(.offTopicTestWithDrill))
        #expect(verdict.blockingIssues.contains(.offTopicTestWithDrill))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText == CoachReliabilityGate.offTopicTestFallback(surface: .text))
        let fb = (verdict.fallbackText ?? "").lowercased()
        #expect(!CoachReliabilityGate.replyDrillsInsteadOfGreeting(fb), "off-topic fallback must not itself be a drill")
        #expect(fb.contains("tiny test"))
        #expect(fb.contains("all good"))
        #expect(!fb.contains("not a coaching ask"))
        #expect(!fb.contains("pretending"))
        #expect(!fb.contains("score"))
        #expect(!fb.contains("filler"))
        #expect(!fb.contains("timed"))
    }

    @Test func offTopicTestAnsweredAsRedirectDoesNotBlock() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: CoachReliabilityGate.offTopicTestFallback(surface: .text),
            previousCoachReply: nil,
            latestUserTurn: "asdf",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.4
        )

        #expect(!verdict.issues.contains(.offTopicTestWithDrill))
        #expect(!verdict.blocked)
    }

    @Test func realCoachingTurnWithOddWordIsNeverTreatedAsOffTopic() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: Self.screenshotDrillReply,
            previousCoachReply: nil,
            latestUserTurn: "why do I keep saying egg when I freeze?",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.4
        )

        #expect(!verdict.issues.contains(.offTopicTestWithDrill))
    }

    @Test func lowSignalOffTopicClassifierStaysNarrow() {
        for sample in ["egg", "asdf", "test", "lol", "huh", "banana"] {
            #expect(TurnDepthClassifier.isLowSignalOffTopicTest(sample), "\(sample) should be treated as a tiny test")
        }
        for sample in [
            "what should I practice?",
            "how do I stop rambling?",
            "egg in my throat when I speak",
            "help me prep",
            "score",
            "why"
        ] {
            #expect(!TurnDepthClassifier.isLowSignalOffTopicTest(sample), "\(sample) should remain a normal coaching turn")
        }
    }

    @Test func isGreetingOrSmallTalkDiscriminates() {
        for g in ["Hi", "hey", "Hello", "hey Noum", "yo", "how's it going?", "what's up", "thanks!", "good morning", "I'm back"] {
            #expect(TurnDepthClassifier.isGreetingOrSmallTalk(g), "\(g) should be a greeting")
        }
        for c in ["what should I do next?", "how do I stop rambling", "help me prep for my interview", "read my last rep", "thanks, what should I do next?", "how far off am I from authoritative?"] {
            #expect(!TurnDepthClassifier.isGreetingOrSmallTalk(c), "\(c) should NOT be a greeting")
        }
    }

    // MARK: - Cold-start jargon guard (no baseline -> no product jargon / fake metrics)

    /// The exact leak the Arena `cold-start-no-data` fixture flags at 22/100:
    /// a no-baseline reply that names an internal mode AND invents a filler
    /// target. On a cold start (coverage pinned to 0.05) this must block and be
    /// replaced with a clean plain-language first-rep invitation.
    private static let coldStartJargonReply =
        "No baseline yet, so start there. Do one Ah-Counter round: 60 seconds on a topic you know cold, aiming to stay under 4 fillers. That gives you a first number and me your starting point."

    @Test func coldStartJargonBlocksAndRecoversClean() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: Self.coldStartJargonReply,
            previousCoachReply: nil,
            latestUserTurn: "What should I work on?",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.05
        )
        #expect(verdict.issues.contains(.coldStartJargon))
        #expect(verdict.blockingIssues.contains(.coldStartJargon))
        #expect(verdict.blocked)
        #expect(verdict.fallbackText == CoachReliabilityGate.coldStartFallback(surface: .text))
        // The recovery must itself be clean of every cold-start marker.
        let fb = CoachReliabilityGate.normalize(verdict.fallbackText ?? "")
        #expect(!CoachReliabilityGate.leaksColdStartJargon(fb), "cold-start fallback must not itself leak jargon")
        #expect(!fb.contains("baseline"), "cold-start fallback should not lead with internal baseline framing")
        #expect(fb.contains("start with one real sample"))
        #expect(!fb.contains("let's"), "cold-start fallback must obey the no-let's coach register")
    }

    @Test func coldStartModeNameAloneBlocks() {
        for reply in [
            "Give a Sudden Death round a shot to see where you stand.",
            "Start with an IM Conversation and I'll read it from there.",
            "Run one rep and try to keep it under 3 fillers this time.",
            "Do a quick rep — the goal is your first number so I can calibrate."
        ] {
            let verdict = CoachReliabilityGate.evaluate(
                replyText: reply,
                previousCoachReply: nil,
                latestUserTurn: "what do I do first?",
                turnDepth: .groundedRead,
                assessment: Self.quickMoveAssessment(),
                evidenceCoverage: 0.05
            )
            #expect(verdict.issues.contains(.coldStartJargon), "expected cold-start block for: \(reply)")
            #expect(verdict.blocked)
        }
    }

    @Test func coldStartCleanFirstRepReplyPasses() {
        // The excellent-shape reply: honest, plain 60-second rep, no jargon, no
        // invented metric. Must pass clean even at cold-start coverage.
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Good to have you here. No baseline yet, so start there — run a 60-second rep on something you know cold, like how you'd explain your job to a stranger. That gives me your real pace and where the point lands.",
            previousCoachReply: nil,
            latestUserTurn: "hey, what do I do first?",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.05
        )
        #expect(!verdict.issues.contains(.coldStartJargon))
        #expect(!verdict.blocked)
    }

    @Test func establishedUserCitingFillerCountIsNeverColdStartBlocked() {
        // A real user with a baseline may legitimately hear their own numbers.
        // The guard must NOT fire above the cold-start coverage ceiling, even
        // with "under 4 fillers" and a mode name present.
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Your last Ah-Counter round held under 4 fillers — that's real progress. Next rep, protect the close.",
            previousCoachReply: nil,
            latestUserTurn: "how did I do?",
            turnDepth: .groundedRead,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.55
        )
        #expect(!verdict.issues.contains(.coldStartJargon))
    }

    @Test func coldStartTrustRepairIsNotHijackedByJargonGuard() {
        // Trust-repair owns its own surface; the cold-start guard must defer to
        // it even at cold-start coverage so repair routing is unchanged.
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Fair. I don't have a read yet — do one Ah-Counter round and I'll name the gap.",
            previousCoachReply: nil,
            latestUserTurn: "that's not helpful",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.05
        )
        #expect(!verdict.issues.contains(.coldStartJargon))
    }

    // MARK: - Evidence overclaim on a no-baseline turn

    /// The exact `placeholder-leak-049` overclaim: a live-style draft that
    /// invents a rep to coach ("I can coach the latest rep: the close is the
    /// usable signal…") on a turn with no baseline. Today this only trips a soft
    /// floor-confidence smell and ships; it must now BLOCK and recover honestly.
    private static let noBaselineOverclaimReply =
        "I can coach the latest rep: the close is the usable signal, so make the final sentence the ask, then stop."

    @Test func evidenceOverclaimOnNoBaselineBlocksAndRecoversHonestly() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: Self.noBaselineOverclaimReply,
            previousCoachReply: nil,
            latestUserTurn: "Can you coach this?",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.05
        )
        #expect(verdict.issues.contains(.evidenceOverclaimNoBaseline))
        #expect(verdict.blockingIssues.contains(.evidenceOverclaimNoBaseline))
        // Distinguishable fallback trace: a blocking issue means the pipeline
        // stamps reliabilityFallbackApplied and swaps the reply.
        #expect(verdict.blocked)
        #expect(verdict.fallbackText == CoachReliabilityGate.noBaselineReadFallback(surface: .text))
        // The recovery must not itself repeat the invented-rep overclaim.
        let fb = CoachReliabilityGate.normalize(verdict.fallbackText ?? "")
        #expect(!CoachReliabilityGate.overclaimsRepEvidence(fb), "recovery must not itself overclaim a rep")
    }

    @Test func honestThinEvidenceReadIsNeverOverclaimBlocked() {
        // lack-conviction-style: legitimately cites "the latest rep … only
        // support a signal" but openly hedges ("not enough evidence", "Missing:").
        // The acknowledgement guard must keep this safe even at cold-start
        // coverage, so an honest read is never mistaken for an overclaim.
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "There is not enough evidence to call this lack of conviction overall. The latest rep and pace estimate only support a mechanics signal: hedge control before the recommendation. Missing: repeated pressure proof.",
            previousCoachReply: nil,
            latestUserTurn: "Do I lack conviction?",
            turnDepth: .deepAssessment,
            assessment: Self.deepAssessment(confidence: 0.20, evidence: ["hedges before recommendation"]),
            evidenceCoverage: 0.05
        )
        #expect(!verdict.issues.contains(.evidenceOverclaimNoBaseline))
    }

    @Test func establishedUserRepReadIsNeverOverclaimBlocked() {
        // With a real baseline (coverage above the cold-start ceiling), citing
        // "the latest rep" and "the close is the signal" is legitimate coaching,
        // never an overclaim.
        let verdict = CoachReliabilityGate.evaluate(
            replyText: Self.noBaselineOverclaimReply,
            previousCoachReply: nil,
            latestUserTurn: "Can you coach this?",
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.55
        )
        #expect(!verdict.issues.contains(.evidenceOverclaimNoBaseline))
        #expect(!verdict.blocked)
    }

    @Test func overclaimGuardDefersToTrustRepairSurface() {
        // Trust-repair owns its own surface; the overclaim guard must defer even
        // at cold-start coverage so repair routing is unchanged.
        let verdict = CoachReliabilityGate.evaluate(
            replyText: Self.noBaselineOverclaimReply,
            previousCoachReply: "Earlier read.",
            latestUserTurn: "that's not helpful",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.05
        )
        #expect(!verdict.issues.contains(.evidenceOverclaimNoBaseline))
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
                for banned in ["amazing", "nailed", "crushed", "you're ready", "guaranteed", "let's"] {
                    #expect(!lowered.contains(banned), "text variant \(i) for \(depth) contains \(banned)")
                }
            }
            for (i, v) in liveVariants.enumerated() {
                #expect(!v.lowercased().contains("let's"), "live variant \(i) for \(depth) contains let's")
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

    @Test func selectStaticFallbackUsesRecoveryLineWhenVariantsAreExhausted() {
        let variants = CoachReliabilityGate.staticFallbackVariants(turnDepth: .quickMove, surface: .text)
        let picked = CoachReliabilityGate.selectStaticFallback(
            turnDepth: .quickMove,
            surface: .text,
            previousCoachReply: variants.last,
            recentCoachReplies: variants
        )
        #expect(picked != variants.last)
        #expect(!variants.contains(picked))
        #expect(
            CoachReliabilityGate.isCleanCandidate(
                picked,
                previousCoachReply: variants.last,
                recentCoachReplies: variants
            )
        )
    }

    @Test func selectStaticFallbackAvoidsImmediateRepeatWhenRecoveryWasAlsoRecent() {
        let variants = CoachReliabilityGate.staticFallbackVariants(turnDepth: .quickMove, surface: .text)
        let recovery = CoachReliabilityGate.exhaustedStaticFallback(turnDepth: .quickMove, surface: .text)
        let picked = CoachReliabilityGate.selectStaticFallback(
            turnDepth: .quickMove,
            surface: .text,
            previousCoachReply: recovery,
            recentCoachReplies: variants + [recovery]
        )
        #expect(picked != recovery)
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
