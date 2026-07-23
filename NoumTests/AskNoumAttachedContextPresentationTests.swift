import Testing
@testable import Noum

@Suite("Ask Noum attached context presentation")
struct AskNoumAttachedContextPresentationTests {
    @Test("Names every bounded personal category and clamps verified quotes")
    func namesBoundedCategories() {
        let presentation = AskNoumAttachedContextPresentation.make(
            latestTimedPracticeLabel: "Timed Practice",
            hasLatestTimedTranscript: true,
            hasRecentPractice: true,
            verifiedQuoteCount: 99,
            currentFocus: "Open with the answer",
            hasSavedGoal: true,
            conversationMessageCount: 99
        )

        #expect(presentation.headline == "Timed Practice · focus: Open with the answer")
        #expect(presentation.categoryLine.contains("recent rep summaries"))
        #expect(presentation.categoryLine.contains("latest Timed Practice transcript"))
        #expect(presentation.categoryLine.contains("3 verified quotes"))
        #expect(presentation.categoryLine.contains("current coaching focus"))
        #expect(presentation.categoryLine.contains("saved speaking goal"))
        #expect(presentation.categoryLine.contains("this bounded conversation"))
        #expect(!presentation.categoryLine.contains("99"))
    }

    @Test("Never claims a transcript or proof quote that is unavailable")
    func withholdsUnavailableEvidence() {
        let presentation = AskNoumAttachedContextPresentation.make(
            latestTimedPracticeLabel: "Timed Practice",
            hasLatestTimedTranscript: false,
            hasRecentPractice: true,
            verifiedQuoteCount: 0,
            currentFocus: nil,
            hasSavedGoal: false,
            conversationMessageCount: 0
        )

        #expect(presentation.headline == "Timed Practice coaching context")
        #expect(presentation.categoryLine == "Attached: recent rep summaries.")
        #expect(!presentation.categoryLine.contains("transcript"))
        #expect(!presentation.categoryLine.contains("quote"))
    }

    @Test("Privacy copy explicitly excludes speech content from growth analytics")
    func statesAnalyticsBoundary() {
        let copy = AskNoumAttachedContextPresentation.privacyExplanation.lowercased()

        #expect(copy.contains("growth analytics"))
        #expect(copy.contains("never records"))
        #expect(copy.contains("words"))
        #expect(copy.contains("prompts"))
        #expect(copy.contains("transcripts"))
    }

    @Test("Whitespace-only labels do not become attached context claims")
    func normalizesEmptyLabels() {
        let presentation = AskNoumAttachedContextPresentation.make(
            latestTimedPracticeLabel: "  ",
            hasLatestTimedTranscript: true,
            hasRecentPractice: false,
            verifiedQuoteCount: -2,
            currentFocus: "\n",
            hasSavedGoal: false,
            conversationMessageCount: -1
        )

        #expect(presentation.headline == "Your coaching context")
        #expect(presentation.categoryLine == "No personal evidence is attached yet.")
    }
}
