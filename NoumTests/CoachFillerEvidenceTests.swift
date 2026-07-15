import Foundation
import Testing
@testable import Noum

struct CoachFillerEvidenceTests {
    private let qualifiedTranscript = "I recommend we hold the launch until migration is stable because customers need a reliable handoff and the team needs one clear decision."

    @Test func qualifiedEvidenceCarriesCountDurationAndRate() throws {
        let evidence = QuantityQualifiedFillerEvidence.current(
            fillerCount: 6,
            duration: 64,
            wordCount: 21,
            transcriptConfidence: 0.9
        )

        #expect(evidence.status == .qualified)
        #expect(evidence.summary == "6 fillers in 64 seconds (5.6 per minute)")
        #expect(QuantityQualifiedFillerEvidence.parseLatest(in: evidence.contextLine) == evidence)
    }

    @Test(arguments: [
        (duration: 14.9, words: 21, confidence: Optional(0.9)),
        (duration: 64.0, words: 19, confidence: Optional(0.9)),
        (duration: 64.0, words: 21, confidence: Optional(0.49))
    ])
    func thinOrUncertainEvidenceWithholdsComparison(
        duration: Double,
        words: Int,
        confidence: Double?
    ) {
        let evidence = QuantityQualifiedFillerEvidence.current(
            fillerCount: 6,
            duration: duration,
            wordCount: words,
            transcriptConfidence: confidence
        )

        #expect(evidence.status == .insufficient)
        #expect(evidence.summary == nil)
        #expect(evidence.contextLine.contains("comparison withheld"))
        #expect(!evidence.contextLine.contains("6 fillers"))
    }

    @Test func qualifiedZeroIsEvidenceButThinZeroIsNot() {
        let qualified = QuantityQualifiedFillerEvidence.current(
            fillerCount: 0,
            duration: 60,
            wordCount: 21,
            transcriptConfidence: 0.9
        )
        let thin = QuantityQualifiedFillerEvidence.current(
            fillerCount: 0,
            duration: 10,
            wordCount: 4,
            transcriptConfidence: 0.9
        )

        #expect(qualified.summary == "0 fillers in 60 seconds (0.0 per minute)")
        #expect(thin.status == .insufficient)
    }

    @Test func parserDoesNotScrapeUnrelatedHistoricalCounts() {
        let context = "RECENT: an older rep had 17 fillers. The baseline mentioned 9 fillers."
        #expect(QuantityQualifiedFillerEvidence.parseLatest(in: context) == nil)
    }

    @Test func repairUsesQualifiedSummaryAndRateComparison() throws {
        let evidence = QuantityQualifiedFillerEvidence.current(
            fillerCount: 6,
            duration: 64,
            wordCount: 21,
            transcriptConfidence: 0.9
        )
        let system = "\(evidence.contextLine)\nSafe filler fact: one filler appeared after the decision line."
        let reply = try #require(AICoachChatService.directFollowThroughRepairReferenceShape(
            for: "What should I do with that filler count?",
            system: system
        ))

        #expect(reply.contains("6 fillers in 64 seconds (5.6 per minute)"))
        #expect(reply.contains("compare fillers per minute"))
        #expect(!reply.contains("pressure leak"))
        #expect(!reply.contains("mostly before"))
    }

    @Test func repairWithheldEvidenceCannotLeakOlderCount() throws {
        let system = """
        An older rep had 17 fillers.
        Latest filler evidence: comparison withheld because the sample did not meet the shared quantity and confidence floor.
        Placement-only filler observation: one filler appeared after the decision line.
        """
        let reply = try #require(AICoachChatService.directFollowThroughRepairReferenceShape(
            for: "What should I do with that filler count?",
            system: system
        ))

        #expect(reply.contains("too small or uncertain"))
        #expect(reply.contains("60-second equivalent rep"))
        #expect(!reply.contains("17 fillers"))
    }

    @Test func deterministicCoachReadDoesNotClaimThinZeroIsClean() {
        let input = AICoachSessionInput(
            transcript: "Short answer only",
            mode: .timed,
            score: 7,
            duration: 8,
            speakingIdentity: "Developing speaker"
        )
        let prompt = AICoachService.userPrompt(
            input: input,
            profile: nil,
            plan: nil,
            baselineContext: ""
        )
        let feedback = AICoachService.deterministicFeedback(input: input)

        #expect(!prompt.lowercased().contains("filler"))
        #expect(!prompt.lowercased().contains("pace"))
        #expect(!feedback.strengths.joined(separator: " ").contains("no filler"))
        #expect(!feedback.strengths.joined(separator: " ").contains("Not a single filler"))
    }
}
