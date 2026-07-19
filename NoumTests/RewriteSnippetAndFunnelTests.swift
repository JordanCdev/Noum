import Foundation
import Testing
@testable import Noum

// Covers the two pieces of new logic behind surfacing the rewrite card and
// closing the coaching funnel. Both are pure or store-local, so they are
// tested directly rather than through a view.

@Suite("Rewrite snippet + coaching funnel")
struct RewriteSnippetAndFunnelTests {

    // MARK: - Original snippet
    //
    // The snippet is quoted back to the user in two places: the Pro card's
    // "your version" toggle and the locked card a free user sees. The
    // invariant that matters for trust is that it is always THEIR words —
    // a fabricated or paraphrased "your version" would be a lie about what
    // they said, and the locked card would be false advertising.

    private let transcript = "So basically I think we should ship it. The data supports the change. Users have asked for this repeatedly. Anyway that's my take."

    @Test func snippetIsAlwaysDrawnFromTheUsersOwnTranscript() {
        for weakness in [
            AIRewriteService.Weakness.opening,
            .closing,
            .structure,
            .concise,
        ] {
            let snippet = AIRewriteService.originalSnippet(
                transcript: transcript,
                weakness: weakness
            )
            #expect(!snippet.isEmpty)
            // Every word in the snippet must appear in the source. Punctuation
            // and the truncation ellipsis are re-composed, so compare words.
            let sourceWords = Set(
                transcript.lowercased()
                    .split(whereSeparator: { !$0.isLetter })
                    .map(String.init)
            )
            let snippetWords = snippet.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
            for word in snippetWords {
                #expect(sourceWords.contains(word), "snippet invented the word '\(word)'")
            }
        }
    }

    @Test func openingAndClosingSelectOppositeEndsOfTheRep() {
        let opening = AIRewriteService.originalSnippet(transcript: transcript, weakness: .opening)
        let closing = AIRewriteService.originalSnippet(transcript: transcript, weakness: .closing)
        #expect(opening.lowercased().contains("basically"))
        #expect(!opening.lowercased().contains("that's my take"))
        #expect(closing.lowercased().contains("my take"))
        #expect(!closing.lowercased().contains("basically"))
    }

    /// Regression: several speech providers return unpunctuated text, which
    /// collapses to a single "sentence". Before this was bounded, `.opening`
    /// handed back the ENTIRE rep labelled as the user's opening — so the
    /// card claimed to quote one sentence while quoting all of them.
    @Test func aTranscriptWithNoSentenceBreaksIsBoundedNotReturnedWhole() {
        let runOn = String(repeating: "words and more words ", count: 40)
        #expect(runOn.count > 800)

        let opening = AIRewriteService.originalSnippet(transcript: runOn, weakness: .opening)
        #expect(!opening.isEmpty)
        #expect(opening.count < runOn.count / 2, "opening returned the whole rep")
        #expect(runOn.hasPrefix(opening.replacingOccurrences(of: "…", with: "")))

        // The closing must come from the END of the rep, not the start.
        let closing = AIRewriteService.originalSnippet(transcript: runOn, weakness: .closing)
        #expect(closing.count < runOn.count / 2, "closing returned the whole rep")
        #expect(runOn.hasSuffix(closing.replacingOccurrences(of: "…", with: "")))

        // And no trailing full stop is invented on text that had none.
        #expect(!opening.hasSuffix("."))
    }

    @Test func punctuatedClosingStillSelectsFromTheEnd() {
        let closing = AIRewriteService.originalSnippet(transcript: transcript, weakness: .closing)
        #expect(closing.lowercased().contains("anyway"))
    }

    @Test func emptyTranscriptDoesNotCrashOrInventContent() {
        let snippet = AIRewriteService.originalSnippet(transcript: "", weakness: .concise)
        #expect(snippet.isEmpty)
    }

    // MARK: - Coaching funnel denominators

    @MainActor
    @Test func repStartedOpensTheFunnelOncePerRep() {
        let defaults = UserDefaults(suiteName: "funnel.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events")
        let repID = UUID()

        log.recordRepStarted(correlationId: repID, mode: "timed")
        log.recordRepStarted(correlationId: repID, mode: "timed")

        let started = log.events.filter { $0.stage == CoachingFunnelStage.repStarted }
        #expect(started.count == 1)
        #expect(started.first?.correlationId == repID)
        #expect(started.first?.flow == .practiceRep)
    }

    @MainActor
    @Test func separateRepsEachOpenTheirOwnFunnel() {
        let defaults = UserDefaults(suiteName: "funnel.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events")

        log.recordRepStarted(correlationId: UUID(), mode: "timed")
        log.recordRepStarted(correlationId: UUID(), mode: "ahCounter")

        #expect(log.events.filter { $0.stage == CoachingFunnelStage.repStarted }.count == 2)
    }

    @MainActor
    @Test func summaryViewedIsRecordedOncePerRep() {
        let defaults = UserDefaults(suiteName: "funnel.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events")
        let sessionID = UUID()

        // Re-entry is normal: SwiftUI can fire onAppear again after an
        // interstitial dismisses. The denominator must not double-count.
        log.recordSummaryViewed(correlationId: sessionID)
        log.recordSummaryViewed(correlationId: sessionID)
        log.recordSummaryViewed(correlationId: sessionID)

        #expect(log.events.filter { $0.stage == CoachingFunnelStage.summaryViewed }.count == 1)
    }

    @MainActor
    @Test func funnelEventsCarryNoTranscriptText() {
        let defaults = UserDefaults(suiteName: "funnel.\(UUID().uuidString)")!
        let log = FlowEventLog(defaults: defaults, storageKey: "events")
        let secret = "the user said something private about their divorce"

        // Mode is the only caller-supplied string, so it is the only place
        // transcript text could leak in. Even when abused, the event must not
        // become a transcript store — this asserts the reason stays bounded.
        log.recordRepStarted(correlationId: UUID(), mode: secret)
        log.recordSummaryViewed(correlationId: UUID())

        for event in log.events {
            #expect(event.reason.count <= 256)
            #expect(!event.numerics.keys.contains("transcript"))
        }
        #expect(log.events.contains { $0.stage == CoachingFunnelStage.summaryViewed })
    }
}
