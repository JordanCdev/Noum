import Foundation
import Testing
@testable import Noum

@Suite("Generated Coach Read validation hardening")
struct GeneratedCoachReadValidationHardeningTests {
    private let transcript = "I'm recommending we can't delay the launch because the board needs one clear decision today."

    @Test("Current and historical filler aliases cannot bypass the metric quarantine")
    func fillerAliasesAreRejected() {
        let claims = [
            "You used fewer filled pauses than in the last rep.",
            "Your verbal crutches increased near the close.",
            "Hesitation markers were lower than usual.",
            "This rep had more filled pauses compared with recent reps.",
        ]

        for claim in claims {
            #expect(AICoachService.usesUnsupportedMetricClaim(
                feedback(improvement: claim),
                transcript: transcript
            ))
        }
    }

    @Test("Current and historical pace aliases cannot bypass the metric quarantine")
    func paceAliasesAreRejected() {
        let claims = [
            "Your delivery was faster than the last rep.",
            "The close sounded slower than usual.",
            "You were quicker through the recommendation.",
            "The opening felt brisk compared with recent reps.",
            "The close dragged after the decision.",
            "You were faster than usual.",
            "You were slower than the last rep.",
            "You sounded quicker compared with recent reps.",
            "Aim for a faster close than your usual.",
            "Try a slower opening than your last rep.",
            "Practice a quicker close relative to the previous rep.",
        ]

        for claim in claims {
            #expect(AICoachService.usesUnsupportedMetricClaim(
                feedback(improvement: claim),
                transcript: transcript
            ))
        }
    }

    @Test("Semantic non-filler language and generic prescriptions remain available")
    func semanticAndPrescriptiveAliasesRemainSafe() {
        let safe = [
            feedback(improvement: "That context was not filler; it made the decision concrete."),
            feedback(improvement: "The word like was semantic, not a verbal crutch."),
            feedback(drill: "Use a pause instead of a filled pause on the next rep."),
            feedback(drill: "Replace a verbal crutch with silence in the drill."),
            feedback(drill: "Try a slower pace next time, then listen back for clarity."),
            feedback(drill: "Aim for a brisk opening on the next rep."),
            feedback(drill: "Practice a quicker opener as an exercise."),
            feedback(improvement: "Revenue growth was faster than usual, which strengthened the recommendation."),
            feedback(improvement: "The slow rollout was the real constraint behind the decision."),
            feedback(drill: "Try a faster second pass next time."),
        ]

        for candidate in safe {
            #expect(!AICoachService.usesUnsupportedMetricClaim(
                candidate,
                transcript: transcript
            ))
        }
    }

    @Test("Masking a verified quote cannot erase the same unsupported prose outside it")
    func verifiedQuoteMaskingIsDelimiterLocal() {
        let source = "I said pace was fast because the launch decision needed a clear recommendation."
        let candidate = feedback(
            improvement: "You said “pace was fast”; your pace was fast."
        )

        #expect(AICoachService.usesUnsupportedMetricClaim(
            candidate,
            transcript: source
        ))
    }

    @Test("Required quote presence is separate from all-field attribution verification")
    func fabricatedAttributedQuotesAreRejectedInEveryField() {
        let verifiedStrength = "You opened with “I'm recommending we can't delay the launch” — that set the frame."
        let fabricated = "You said “Profit should lead the launch” in the rep."
        let candidates = [
            AICoachFeedback(
                strengths: [verifiedStrength, fabricated],
                keyImprovement: "Make the board decision explicit.",
                suggestedDrill: "Repeat the decision in one sentence.",
                revisedOpening: "The board should hold the launch."
            ),
            feedback(strength: verifiedStrength, improvement: fabricated),
            feedback(strength: verifiedStrength, drill: "Repeat what you said: “Profit should lead the launch”."),
            feedback(strength: verifiedStrength, opening: "You said “Profit should lead the launch”; open on the board decision instead."),
            feedback(strength: verifiedStrength, drill: "Repeat the line from your answer: “Profit should lead the launch”."),
            feedback(strength: verifiedStrength, opening: "Replace the words from your rep — “Profit should lead the launch”."),
        ]

        for candidate in candidates {
            #expect(AICoachService.hasVerifiedTranscriptQuote(
                candidate,
                transcript: transcript
            ))
            #expect(AICoachService.containsUnverifiedAttributedQuote(
                candidate,
                transcript: transcript
            ))
            #expect(!AICoachService.hasQuoteIntegrity(
                candidate,
                transcript: transcript
            ))
        }

        let unattributedFabricatedStrength = AICoachFeedback(
            strengths: [
                verifiedStrength,
                "The phrase “Profit should lead the launch” gave the answer a clear spine.",
            ],
            keyImprovement: "Make the board decision explicit.",
            suggestedDrill: "Repeat the decision in one sentence.",
            revisedOpening: "The board should hold the launch."
        )
        #expect(AICoachService.hasVerifiedTranscriptQuote(
            unattributedFabricatedStrength,
            transcript: transcript
        ))
        #expect(!AICoachService.containsUnverifiedAttributedQuote(
            unattributedFabricatedStrength,
            transcript: transcript
        ))
        #expect(!AICoachService.hasQuoteIntegrity(
            unattributedFabricatedStrength,
            transcript: transcript
        ))

        let proposedOpening = feedback(
            strength: verifiedStrength,
            opening: "Open with “The board should hold the launch today”."
        )
        #expect(AICoachService.hasVerifiedTranscriptQuote(
            proposedOpening,
            transcript: transcript
        ))
        #expect(!AICoachService.containsUnverifiedAttributedQuote(
            proposedOpening,
            transcript: transcript
        ))
        #expect(AICoachService.hasQuoteIntegrity(
            proposedOpening,
            transcript: transcript
        ))
    }

    @Test("Legacy replay keeps safe nonquoted coaching but hides attributed fabrication")
    func legacyReplayDoesNotRequireQuotePresenceButRejectsFabrication() {
        let safe = session(aiFeedback: feedback(
            strength: "The board decision gave the answer a clear spine.",
            improvement: "Move the board decision into the first sentence."
        ))
        let fabricatedDrill = session(aiFeedback: feedback(
            drill: "Repeat what you said: “Profit should lead the launch”."
        ))
        let fabricatedOpening = session(aiFeedback: feedback(
            opening: "You said “Profit should lead the launch”; replace it with a direct recommendation."
        ))

        #expect(safe.evidenceSafeAICoachFeedback != nil)
        #expect(fabricatedDrill.evidenceSafeAICoachFeedback == nil)
        #expect(fabricatedOpening.evidenceSafeAICoachFeedback == nil)
    }

    @Test("Deterministic fallback quotes contractions with parseable curly delimiters")
    func contractionFallbackPassesTheQuoteBoundary() {
        let feedback = AICoachService.deterministicFeedback(
            input: AICoachSessionInput(
                transcript: transcript,
                mode: .timed,
                score: 7,
                duration: 35,
                speakingIdentity: "Developing speaker",
                voice: .warm
            )
        )
        let fragments = (feedback.strengths + [feedback.revisedOpening])
            .flatMap { AICoachChatService.quotedFragments(in: $0) }
        let quoteGuard = CoachChatQuoteGuardContext(transcripts: [transcript])

        #expect(fragments.contains { $0.contains("I'm") && $0.contains("can't") })
        #expect(fragments.allSatisfy(quoteGuard.verifies))
        #expect(AICoachService.hasVerifiedTranscriptQuote(
            feedback,
            transcript: transcript
        ))
        #expect(!AICoachService.containsUnverifiedAttributedQuote(
            feedback,
            transcript: transcript
        ))
        #expect(AICoachService.hasQuoteIntegrity(
            feedback,
            transcript: transcript
        ))
    }

    @Test("Short first sentence falls through to an eligible full-transcript quote")
    func shortFirstSentenceUsesLeadingWindowWithoutPromotingShortCaptures() {
        let eligibleTranscript = "Yes. I'm recommending we can't delay the launch because the board needs clarity."
        let eligible = AICoachService.deterministicFeedback(
            input: AICoachSessionInput(
                transcript: eligibleTranscript,
                mode: .timed,
                score: 7,
                duration: 35,
                speakingIdentity: "Developing speaker",
                voice: .warm
            )
        )
        let short = AICoachService.deterministicFeedback(
            input: AICoachSessionInput(
                transcript: "Yes.",
                mode: .timed,
                score: 7,
                duration: 2,
                speakingIdentity: "Developing speaker",
                voice: .warm
            )
        )

        #expect(AICoachService.hasVerifiedTranscriptQuote(
            eligible,
            transcript: eligibleTranscript
        ))
        #expect(AICoachService.hasQuoteIntegrity(
            eligible,
            transcript: eligibleTranscript
        ))
        #expect(short.revisedOpening.isEmpty)
        #expect(!AICoachService.hasVerifiedTranscriptQuote(
            short,
            transcript: "Yes."
        ))
    }

    private func feedback(
        strength: String = "The board decision was specific.",
        improvement: String = "Make the board decision explicit.",
        drill: String = "Repeat the board decision in one sentence.",
        opening: String = "The board should hold the launch."
    ) -> AICoachFeedback {
        AICoachFeedback(
            strengths: [strength, "The recommendation gave the answer a clear spine."],
            keyImprovement: improvement,
            suggestedDrill: drill,
            revisedOpening: opening
        )
    }

    private func session(aiFeedback: AICoachFeedback) -> PracticeSession {
        PracticeSession(
            transcript: transcript,
            fillerWordCount: 0,
            duration: 35,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            mode: .timed,
            score: 7,
            aiCoachFeedback: aiFeedback,
            transcriptConfidence: 0.9
        )
    }
}
