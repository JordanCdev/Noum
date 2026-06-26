//
//  CoachBrainRerankTests.swift
//  NoumTests
//
//  Pure-math coverage for the optional semantic-rerank layer. The
//  NLContextualEmbedding wrapper itself is device-only (the asset never loads in
//  the Simulator), so the testable contract is the vector arithmetic + fusion.
//

import Foundation
import Testing
@testable import Noum

@Suite("KnowledgeVectorMathTests")
struct KnowledgeVectorMathTests {

    private func approxEqual(_ a: [Float], _ b: [Float], tol: Float = 1e-5) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).allSatisfy { abs($0 - $1) <= tol }
    }

    @Test func meanPoolAveragesElementwise() {
        #expect(approxEqual(KnowledgeVectorMath.meanPool([[1, 2, 3], [3, 2, 1]]), [2, 2, 2]))
    }

    @Test func meanPoolEmptyOrRaggedIsEmpty() {
        #expect(KnowledgeVectorMath.meanPool([]).isEmpty)
        #expect(KnowledgeVectorMath.meanPool([[1, 2], [1]]).isEmpty)
    }

    @Test func l2NormalizeMakesUnitLength() {
        #expect(approxEqual(KnowledgeVectorMath.l2Normalize([3, 4]), [0.6, 0.8]))
    }

    @Test func l2NormalizeZeroVectorIsUnchanged() {
        #expect(approxEqual(KnowledgeVectorMath.l2Normalize([0, 0]), [0, 0]))
    }

    @Test func cosineIdenticalIsOne() {
        let v = KnowledgeVectorMath.l2Normalize([1, 2, 3])
        #expect(abs(KnowledgeVectorMath.cosine(v, v) - 1) <= 1e-5)
    }

    @Test func cosineOrthogonalIsZero() {
        #expect(abs(KnowledgeVectorMath.cosine([1, 0], [0, 1])) <= 1e-6)
    }

    @Test func cosineMismatchedLengthIsZero() {
        #expect(KnowledgeVectorMath.cosine([1, 2, 3], [1, 2]) == 0)
    }

    @Test func rrfFusesAndBreaksTiesById() {
        // a: rank0+rank1, b: rank1+rank0 -> equal score, tie broken a<b. c last.
        let fused = KnowledgeVectorMath.reciprocalRankFusion(rankings: [
            ["a", "b", "c"],
            ["b", "a", "c"],
        ])
        #expect(fused == ["a", "b", "c"])
    }

    @Test func rrfSingleListPreservesOrder() {
        #expect(KnowledgeVectorMath.reciprocalRankFusion(rankings: [["x", "y", "z"]]) == ["x", "y", "z"])
    }

    @Test func rrfIsDeterministic() {
        let r: [[String]] = [["p", "q", "r"], ["r", "q", "p"]]
        #expect(KnowledgeVectorMath.reciprocalRankFusion(rankings: r)
                == KnowledgeVectorMath.reciprocalRankFusion(rankings: r))
    }
}

// MARK: - Reranked retrieval graceful fallback

@Suite("KnowledgeRerankFallbackTests")
struct KnowledgeRerankFallbackTests {

    @Test func rerankedFallsBackToBM25WhenModelUnavailable() async {
        // The NLContextualEmbedding model never loads in the Simulator, so the
        // async reranked path must return the BM25 result unchanged.
        let reranked = await KnowledgeRetriever.retrieveReranked(query: "how do i stop saying um")
        let bm25 = KnowledgeRetriever.retrieve(query: "how do i stop saying um")
        #expect(!reranked.isEmpty)
        #expect(reranked.map(\.id) == bm25.map(\.id))
    }

    @Test func rerankedRespectsTheColdStartGate() async {
        // Gate still applies through the reranked path: no diagnosis + not a
        // technique turn -> nothing.
        let reranked = await KnowledgeRetriever.retrieveReranked(
            query: "hey", lever: nil, hasDiagnosis: false
        )
        #expect(reranked.isEmpty)
    }
}

// MARK: - Agentic tool loop (deterministic parts; the live loop needs device QA)

@Suite("AgenticToolLoopTests")
struct AgenticToolLoopTests {

    @Test func toolDeclarationHasQueryParameter() {
        let decl = AICoachChatService.expertiseToolDeclaration()
        #expect(decl["name"] as? String == "retrieve_expertise")
        let params = decl["parameters"] as? [String: Any]
        let props = params?["properties"] as? [String: Any]
        #expect(props?["query"] != nil)
        #expect((params?["required"] as? [String])?.contains("query") == true)
    }

    @Test func toolExecutesAndReturnsTechniques() {
        let resp = AICoachChatService.executeExpertiseTool(
            query: "how do i stop saying um",
            context: CoachToolContext()
        )
        let techniques = resp["techniques"] as? [[String: Any]]
        #expect(techniques?.isEmpty == false)
        #expect(techniques?.first?["technique"] is String)
        #expect(techniques?.first?["successMarker"] is String)
    }

    @Test func toolReturnsNoteWhenNothingMatches() {
        let resp = AICoachChatService.executeExpertiseTool(
            query: "zzzqqq nonsensical gibberish xyzzy",
            context: CoachToolContext()
        )
        #expect((resp["techniques"] as? [[String: Any]])?.isEmpty == true)
        #expect(resp["note"] is String)
    }

    @Test func geminiContentsMapsRolesAndSkipsEmptyOrSystem() {
        let msgs = [
            CoachMessage(role: .user, text: "hi"),
            CoachMessage(role: .coach, text: "Good to have you back."),
            CoachMessage(role: .systemNotice, text: "ui only"),
            CoachMessage(role: .coach, text: "   ", isPending: true), // empty pending -> skipped
        ]
        let contents = AICoachChatService.geminiContents(from: msgs)
        #expect(contents.count == 2)
        #expect(contents[0]["role"] as? String == "user")
        #expect(contents[1]["role"] as? String == "model")
    }

    @Test func parseDetectsFunctionCall() {
        let obj: [String: Any] = ["candidates": [[
            "content": ["role": "model", "parts": [[
                "functionCall": ["name": "retrieve_expertise", "args": ["query": "stop fillers"]],
            ]]],
            "finishReason": "STOP",
        ]]]
        switch AICoachChatService.parseGeminiStep(from: obj) {
        case .call(let name, let args, _):
            #expect(name == "retrieve_expertise")
            #expect(args["query"] as? String == "stop fillers")
        default:
            Issue.record("expected .call")
        }
    }

    @Test func parseDetectsFinalText() {
        let obj: [String: Any] = ["candidates": [[
            "content": ["role": "model", "parts": [["text": "Hold a beat before your next answer."]]],
            "finishReason": "STOP",
        ]]]
        switch AICoachChatService.parseGeminiStep(from: obj) {
        case .text(let text):
            #expect(text.contains("Hold a beat"))
        default:
            Issue.record("expected .text")
        }
    }

    @Test func parseTreatsTruncatedTextAsUnusable() {
        let obj: [String: Any] = ["candidates": [[
            "content": ["role": "model", "parts": [["text": "This got cut off mid"]]],
            "finishReason": "MAX_TOKENS",
        ]]]
        switch AICoachChatService.parseGeminiStep(from: obj) {
        case .unusable: #expect(Bool(true))
        default: Issue.record("expected .unusable for MAX_TOKENS")
        }
    }

    @Test func parseTreatsMalformedAsUnusable() {
        switch AICoachChatService.parseGeminiStep(from: ["candidates": [[String: Any]]()]) {
        case .unusable: #expect(Bool(true))
        default: Issue.record("expected .unusable for empty candidates")
        }
    }
}
