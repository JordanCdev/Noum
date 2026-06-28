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

    /// A clean quick-move assessment whose `immediateCoachRead` is the proof
    /// test — usable as a clean fallback source.
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

    @Test func trustRepairWithoutAcknowledgementRecordsSoftIssue() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Run a 60-second rep and put the verdict first, then stop.",
            previousCoachReply: "Earlier read.",
            turnDepth: .trustRepair,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5
        )
        #expect(verdict.issues.contains(.noAttunementOnPushback))
        #expect(!verdict.blocked) // soft: a non-acknowledging-but-otherwise-fine reply still ships
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

    @Test func repeatedProofTestIsRecordedNotBlocked() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Lead with the verdict and prove it once.",
            previousCoachReply: nil,
            turnDepth: .quickMove,
            assessment: Self.quickMoveAssessment(),
            evidenceCoverage: 0.5,
            proofTestRecentlyRepeated: true
        )
        #expect(verdict.issues.contains(.repeatedProofTest))
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
        // immediateCoachRead for a quickMove == the proof test, which is clean.
        #expect(verdict.fallbackText == assessment.immediateCoachRead)
    }

    @Test func fallbackUsesHonestStaticLineWhenImmediateReadIsDirty() {
        // A proof test that itself leaks a placeholder marker → immediateCoachRead
        // is not a clean candidate → static honest line is used instead.
        let assessment = Self.quickMoveAssessment(proofTest: "placeholder next step")
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
        // The provider duplicated the previous reply AND the immediate read equals
        // it too — the fallback must not re-emit the duplicate.
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
            good: "Fair — you're right that a drill isn't what you asked for. The real answer: your close trails off, so the ask never lands.",
            bad: "Lead with the decision, then one reason. Try a 60-second rep.",
            previousCoachReply: "Lead with the decision, then one reason. Try a 60-second rep."
        ),
        Golden(
            id: "how-far-off-am-i",
            depth: .deepAssessment,
            good: "Honest read: you're closer mechanically than under pressure. I don't have a stakes rep yet, so I won't claim you're ready.",
            bad: "placeholder",
            previousCoachReply: nil
        ),
        Golden(
            id: "robotic-cold-complaint",
            depth: .trustRepair,
            good: "You're right — that came out clinical. Let me drop the scaffolding: the one thing holding you back is the soft ending.",
            bad: "turnDepth=trustRepair toneMode=repair",
            previousCoachReply: nil
        ),
        Golden(
            id: "tts-formatting-complaint",
            depth: .trustRepair,
            good: "Fair, the formatting got in the way. Plainly: slow the open by one beat and put the verdict first.",
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
