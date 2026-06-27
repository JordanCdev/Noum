//
//  CoachBrainTests.swift
//  NoumTests
//
//  Coverage for the coach "brain": the curated coaching knowledge base, the
//  BM25 retriever + honesty gate, the expertise formatter, the context-builder
//  injection, and the softened observable-anchor gate.
//

import Foundation
import Testing
@testable import Noum

// MARK: - Corpus integrity
//
// The corpus is the whole product here — thin, malformed, or gate-fighting cards
// would make the coach MORE of a wrapper, not less. These tests pin the bar.

@Suite("CoachKnowledgeBaseIntegrityTests")
struct CoachKnowledgeBaseIntegrityTests {

    /// Mirrors the private `roboticPhrases` + `defensiveProductPhrases` in
    /// `AICoachChatService`. A card containing one of these could tempt the
    /// model to echo a phrase its OWN reply gate would then reject — the corpus
    /// must never fight the gate. Kept in sync via the manifest.
    static let bannedPhrases: [String] = [
        "based on your data", "the key insight is", "concrete next move",
        "this indicates", "recent reps show", "scores are down", "let's",
        "let us", "as an ai", "as your ai", "optimize your", "utilize",
        "i understand your frustration", "here are some tips",
        "here are a few tips", "it's important to", "it is important to",
        "in order to improve", "effective communication",
        "to communicate more clearly", "be clear and concise",
        "try to be more confident", "retrieval load", "chosen profile",
        "profile yet", "in my response", "your brain", "brain was searching", "searching for the next word",
        "close your mouth", "closing your mouth", "close your lips",
        "closing your lips", "go to the practice tab", "open the practice tab",
        "tap the practice tab", "use the practice screen",
        "go to the practice screen", "open the practice screen",
        "the app is designed", "the system is designed", "i am just", "i'm just"
    ]

    @Test func corpusIsSubstantial() {
        // A real body of expertise, not a token gesture.
        #expect(CoachKnowledgeBase.cards.count >= 50)
    }

    @Test func everyCardHasNonEmptyFields() {
        for card in CoachKnowledgeBase.cards {
            #expect(!card.id.isEmpty, "empty id")
            #expect(!card.title.isEmpty, "\(card.id) empty title")
            #expect(!card.technique.isEmpty, "\(card.id) empty technique")
            #expect(!card.why.isEmpty, "\(card.id) empty why")
            #expect(!card.howToApply.isEmpty, "\(card.id) empty howToApply")
            #expect(!card.successMarker.isEmpty, "\(card.id) empty successMarker")
            #expect(!card.whenToUse.isEmpty, "\(card.id) empty whenToUse")
            #expect(!card.leverTags.isEmpty, "\(card.id) has no lever tags")
        }
    }

    @Test func cardIDsAreUnique() {
        let ids = CoachKnowledgeBase.cards.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate card ids present")
    }

    @Test func everyDomainHasCoverage() {
        for domain in CoachingDomain.allCases {
            let count = CoachKnowledgeBase.cards.filter { $0.domain == domain }.count
            #expect(count >= 1, "domain \(domain.rawValue) has no cards")
        }
    }

    /// The load-bearing honesty test: no card's USER-FACING formatted line
    /// contains a phrase the reply gate bans, so retrieval can never inject a
    /// phrase the model's own gate would reject.
    @Test func noCardContainsAGateBannedPhrase() {
        for card in CoachKnowledgeBase.cards {
            let line = CoachExpertiseFormatter.line(for: card).lowercased()
            for banned in Self.bannedPhrases {
                #expect(!line.contains(banned),
                        "card \(card.id) contains gate-banned phrase '\(banned)'")
            }
        }
    }

    /// Evidence tiers must actually be used — if everything is `.empirical` the
    /// softening mechanism is decorative.
    @Test func evidenceTiersAreUsedHonestly() {
        let tiers = Set(CoachKnowledgeBase.cards.map(\.evidenceTier))
        #expect(tiers.contains(.practitioner))
        #expect(tiers.contains(.folk))
    }
}

// MARK: - Retriever

@Suite("KnowledgeRetrieverTests")
struct KnowledgeRetrieverTests {

    @Test func fillerQuerySurfacesFillerCard() {
        let result = KnowledgeRetriever.retrieve(query: "how do i stop saying um")
        #expect(!result.isEmpty)
        #expect(result.first?.domain == .fillerReduction)
        #expect(result.contains { $0.id == "filler-pause-beats-filler" })
    }

    @Test func presentationQuerySurfacesPresentationOrOpening() {
        let result = KnowledgeRetriever.retrieve(query: "how do i open a presentation")
        #expect(!result.isEmpty)
        #expect(result.contains { $0.domain == .transferPresentation || $0.leverTags.contains(.openingStrength) })
    }

    @Test func interviewQueryWithPluralStemMatches() {
        // "interviews" (plural) must match the singular "interview" corpus term.
        let result = KnowledgeRetriever.retrieve(query: "i keep freezing in interviews")
        #expect(!result.isEmpty)
        #expect(result.contains { $0.domain == .transferInterview })
    }

    @Test func conciseQuerySurfacesConcisenessTechnique() {
        let result = KnowledgeRetriever.retrieve(query: "how do i sound more concise")
        #expect(!result.isEmpty)
        #expect(result.contains { $0.leverTags.contains(.conciseSpeaking) || $0.id == "voice-concise" })
    }

    @Test func retrievalIsDeterministic() {
        let a = KnowledgeRetriever.retrieve(query: "how do i handle a hard question under pressure")
        let b = KnowledgeRetriever.retrieve(query: "how do i handle a hard question under pressure")
        #expect(a.map(\.id) == b.map(\.id))
    }

    @Test func respectsLimit() {
        let result = KnowledgeRetriever.retrieve(query: "how do i open close pace pause structure interview", limit: 2)
        #expect(result.count <= 2)
    }

    // MARK: Honesty gate

    @Test func coldStartNonTechniqueTurnReturnsNothing() {
        // No diagnosis, not asking for technique -> coach reads the person, not
        // a card. This is the weak-evidence -> softer-feedback contract.
        let result = KnowledgeRetriever.retrieve(query: "hey", lever: nil, hasDiagnosis: false)
        #expect(result.isEmpty)
    }

    @Test func techniqueQuestionRetrievesEvenWithoutDiagnosis() {
        let result = KnowledgeRetriever.retrieve(query: "how do i stop rambling", lever: nil, hasDiagnosis: false)
        #expect(!result.isEmpty)
    }

    @Test func diagnosedVagueTurnSeedsTheActiveLever() {
        // Vague turn but an established case -> surface ON-CASE technique even
        // with no lexical overlap. Every returned card serves the active lever.
        let result = KnowledgeRetriever.retrieve(query: "xyzzy", lever: .fillerReduction, hasDiagnosis: true)
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { $0.leverTags.contains(.fillerReduction) })
    }

    // MARK: Boosting

    @Test func voiceBoostRanksTheMatchingRegisterFirst() {
        // Seed path (no lexical match) so only the boosts differ: among the
        // concise-lever cards, one written FOR the concise voice ranks above the
        // concise-lever cards aligned to OTHER voices (authoritative/executive).
        let result = KnowledgeRetriever.retrieve(
            query: "xyzzy",
            lever: .conciseSpeaking,
            voice: .concise,
            hasDiagnosis: true
        )
        #expect(result.first?.voiceAlignment.contains(.concise) == true)
    }

    @Test func techniqueSignalDetection() {
        #expect(KnowledgeRetriever.isTechniqueSeekingTurn("how do i stop rambling"))
        #expect(KnowledgeRetriever.isTechniqueSeekingTurn("any tips for interviews"))
        #expect(KnowledgeRetriever.isTechniqueSeekingTurn("help me prepare for my pitch"))
        #expect(!KnowledgeRetriever.isTechniqueSeekingTurn("hey"))
        #expect(!KnowledgeRetriever.isTechniqueSeekingTurn("thanks"))
        #expect(!KnowledgeRetriever.isTechniqueSeekingTurn("that makes sense"))
    }

    @Test func pluralStemFoldsConsistently() {
        #expect(KnowledgeRetriever.stem("interviews") == "interview")
        #expect(KnowledgeRetriever.stem("fillers") == "filler")
        #expect(KnowledgeRetriever.stem("pauses") == "pause")
        // Conservative: leave "ss" endings + short words alone.
        #expect(KnowledgeRetriever.stem("stress") == "stress")
        #expect(KnowledgeRetriever.stem("is") == "is")
    }
}

// MARK: - Formatter

@Suite("CoachExpertiseFormatterTests")
struct CoachExpertiseFormatterTests {

    private func card(_ id: String) -> CoachKnowledgeCard {
        CoachKnowledgeBase.cards.first { $0.id == id }!
    }

    @Test func emptyCardsProduceNoLines() {
        #expect(CoachExpertiseFormatter.contextLines(for: []).isEmpty)
    }

    @Test func headerLeadsTheBlock() {
        let lines = CoachExpertiseFormatter.contextLines(for: [card("filler-pause-beats-filler")])
        #expect(lines.first == CoachExpertiseFormatter.header)
        #expect(lines.first?.contains("COACHING EXPERTISE") == true)
        // One header + one line per card.
        #expect(lines.count == 2)
    }

    @Test func lineNamesTechniqueAndSuccessMarker() {
        let c = card("filler-pause-beats-filler")
        let line = CoachExpertiseFormatter.line(for: c)
        #expect(line.contains(c.technique))
        #expect(line.contains("Working when"))
        #expect(line.contains("Apply it"))
    }

    @Test func empiricalCardCarriesNoSofteningQualifier() {
        let line = CoachExpertiseFormatter.line(for: card("filler-pause-beats-filler")) // empirical
        #expect(!line.contains("[rule of thumb"))
        #expect(!line.contains("[established"))
    }

    @Test func folkCardCarriesRuleOfThumbQualifier() {
        let line = CoachExpertiseFormatter.line(for: card("structure-one-idea-per-sentence")) // folk
        #expect(line.contains("[rule of thumb"))
    }

    @Test func practitionerCardCarriesPracticeQualifier() {
        let line = CoachExpertiseFormatter.line(for: card("filler-anchor-word")) // practitioner
        #expect(line.contains("[established coaching practice]"))
    }
}

// MARK: - Context-builder injection

@Suite("CoachContextExpertiseInjectionTests")
struct CoachContextExpertiseInjectionTests {

    private func userContext(expertise: [CoachKnowledgeCard]) -> String {
        CoachContextBuilder.userContext(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [],
            currentStreak: 0,
            pathStatus: nil,
            pathGatingPhrase: nil,
            coachingExpertise: expertise
        )
    }

    @Test func expertiseSectionAppearsWhenCardsPresent() {
        let card = CoachKnowledgeBase.cards.first { $0.id == "filler-pause-beats-filler" }!
        let ctx = userContext(expertise: [card])
        #expect(ctx.contains("COACHING EXPERTISE"))
        #expect(ctx.contains(card.technique))
        // Still terminated correctly.
        #expect(ctx.contains("=== END CONTEXT ==="))
    }

    @Test func noExpertiseSectionWhenEmpty() {
        let ctx = userContext(expertise: [])
        #expect(!ctx.contains("COACHING EXPERTISE"))
        #expect(ctx.contains("=== END CONTEXT ==="))
    }
}

// MARK: - Pipeline diagnostics

@Suite("CoachReplyPipelineBrainDiagnosticTests")
struct CoachReplyPipelineBrainDiagnosticTests {

    private func card(_ id: String) -> CoachKnowledgeCard {
        CoachKnowledgeBase.cards.first { $0.id == id }!
    }

    @Test func diagnosticNamesRetrievedCardsWithoutUserText() {
        let reason = CoachReplyPipeline.brainDiagnosticReason(
            cards: [
                card("filler-pause-beats-filler"),
                card("filler-anchor-word"),
                card("pacing-target-band"),
                card("structure-answer-first")
            ],
            latestUserTurn: "how do i stop saying um in interviews",
            hasDiagnosis: false
        )

        #expect(reason.contains("Retrieved 4 cards"))
        #expect(reason.contains("filler-pause-beats-filler"))
        #expect(reason.contains("+1"))
        #expect(!reason.contains("how do i stop"))
    }

    @Test func diagnosticExplainsColdNonTechniqueGate() {
        let reason = CoachReplyPipeline.brainDiagnosticReason(
            cards: [],
            latestUserTurn: "hey",
            hasDiagnosis: false
        )

        #expect(reason == "No cards: cold non-technique turn")
    }

    @Test func diagnosticExplainsEmptyTurn() {
        let reason = CoachReplyPipeline.brainDiagnosticReason(
            cards: [],
            latestUserTurn: "   ",
            hasDiagnosis: true
        )

        #expect(reason == "No cards: empty user turn")
    }
}
