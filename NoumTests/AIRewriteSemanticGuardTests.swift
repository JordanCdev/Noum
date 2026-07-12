import Foundation
import Testing
@testable import Noum

@Suite("AI rewrite semantic preservation")
struct AIRewriteSemanticGuardTests {
    private let source = "I don't think Acme should cut the $1.25 million launch budget, because Q3 retention is 92%. The customer signal is clear."

    @Test func acceptsStyleMovementAtEveryIntensityWhenMeaningAnchorsRemain() {
        let candidates = [
            "I don't think Acme should cut the $1.25 million launch budget; Q3 retention is 92%.",
            "I don't support cutting Acme's $1.25m launch budget; Q3 retention remains 92%.",
            "Do not cut Acme's $1.25 million launch budget: Q3 retention is 92%."
        ]

        for candidate in candidates {
            #expect(RewriteSemanticGuard.preservesMeaning(
                originalTranscript: source,
                candidate: candidate,
                weakness: .opening
            ))
        }
    }

    @Test func acceptsEquivalentNumberFormatting() {
        #expect(RewriteSemanticGuard.preservesMeaning(
            originalTranscript: "The Acme renewal is worth $ 1,250, and adoption is 92 percent.",
            candidate: "Keep the Acme renewal at $1,250 with adoption at 92%.",
            weakness: .opening
        ))
    }

    @Test func rejectsRemovedNegation() {
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: source,
            candidate: "Acme should cut the $1.25 million launch budget because Q3 retention is 92%.",
            weakness: .opening
        ))
    }

    @Test func rejectsIntroducedNegation() {
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: "I think Acme should keep the $1.25 million launch budget because Q3 retention is 92%.",
            candidate: "I don't think Acme should keep the $1.25 million launch budget; Q3 retention is 92%.",
            weakness: .opening
        ))
    }

    @Test func treatsContractionsAndExpandedNotAsEquivalent() {
        #expect(RewriteSemanticGuard.preservesMeaning(
            originalTranscript: source,
            candidate: "I do not think Acme should cut the $1.25 million launch budget; Q3 retention is 92%.",
            weakness: .opening
        ))
    }

    @Test func preservesNegationAtSentenceBoundary() {
        #expect(RewriteSemanticGuard.preservesMeaning(
            originalTranscript: "The Acme contract should not. The customer evidence supports waiting.",
            candidate: "The Acme contract should not; customer evidence supports waiting.",
            weakness: .opening
        ))
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: "The Acme contract should not. The customer evidence supports waiting.",
            candidate: "The Acme contract should proceed; customer evidence supports waiting.",
            weakness: .opening
        ))
    }

    @Test func rejectsChangedPercentage() {
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: source,
            candidate: "Do not cut Acme's $1.25 million launch budget: Q3 retention is 90%.",
            weakness: .opening
        ))
    }

    @Test func rejectsChangedCurrencyAmountOrDroppedCurrency() {
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: source,
            candidate: "Do not cut Acme's $1.5 million launch budget: Q3 retention is 92%.",
            weakness: .opening
        ))
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: source,
            candidate: "Do not cut Acme's 1.25 million launch budget: Q3 retention is 92%.",
            weakness: .opening
        ))
    }

    @Test func rejectsNewNumericClaim() {
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: "I think Acme should keep the launch budget because the customer signal is clear.",
            candidate: "Acme should keep 80% of the launch budget because the customer signal is clear.",
            weakness: .opening
        ))
    }

    @Test func rejectsChangedNamedEntityAndQuarterLabel() {
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: source,
            candidate: "Do not cut Nimbus's $1.25 million launch budget: Q3 retention is 92%.",
            weakness: .opening
        ))
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: source,
            candidate: "Do not cut Acme's $1.25 million launch budget: Q4 retention is 92%.",
            weakness: .opening
        ))
    }

    @Test func rejectsNewEntityLikeToken() {
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: "The launch budget should stay because customer retention is strong and the team is ready.",
            candidate: "The launch budget should stay at Nimbus because customer retention is strong.",
            weakness: .opening
        ))
    }

    @Test func preservesEntityAcrossPossessiveAndTerminalPunctuation() {
        #expect(RewriteSemanticGuard.preservesMeaning(
            originalTranscript: "The customer selected Acme. The launch evidence is ready for review.",
            candidate: "The customer selected Acme's launch; the evidence is ready for review.",
            weakness: .opening
        ))
    }

    @Test func openingGuardDoesNotRequireFactsFromUntargetedClose() {
        #expect(RewriteSemanticGuard.preservesMeaning(
            originalTranscript: "We should keep Acme's launch plan at 92%. The customer evidence is clear. Close Nimbus at £2 million.",
            candidate: "Keep Acme's launch plan at 92%; the customer evidence is clear.",
            weakness: .opening
        ))
    }

    @Test func structureAndConciseGuardsPreserveWholeRepFacts() {
        let transcript = "Acme retention is 92%. We should not cut the £2 million Nimbus plan."
        let safe = "Keep Acme retention at 92%; do not cut Nimbus's £2 million plan."
        let omission = "Keep Acme retention at 92%; do not cut the Nimbus plan."

        #expect(RewriteSemanticGuard.preservesMeaning(
            originalTranscript: transcript,
            candidate: safe,
            weakness: .structure
        ))
        #expect(RewriteSemanticGuard.preservesMeaning(
            originalTranscript: transcript,
            candidate: safe,
            weakness: .concise
        ))
        #expect(!RewriteSemanticGuard.preservesMeaning(
            originalTranscript: transcript,
            candidate: omission,
            weakness: .concise
        ))
    }
}
