import Foundation
import NaturalLanguage

// MARK: - Knowledge Semantic Reranker (optional, device-only enhancement)
//
// An OPTIONAL semantic rerank of the coach brain's BM25 results, using Apple's
// on-device `NLContextualEmbedding` (iOS 17). BM25 stays the primary, always-on
// retriever; this only REORDERS the BM25 top-K when a user's phrasing is
// semantically close to a card that shares few literal words ("I freeze up when
// the boss puts me on the spot" -> the tactical-pause card). It fuses the two
// rankings with Reciprocal Rank Fusion so neither signal dominates.
//
// Hard safety rules (the embedding model is a trap if mishandled):
//   • It does NOT load in the iOS Simulator (Apple FB22699606) and its assets
//     download over the network on first run. So warmup is FIRE-AND-FORGET, off
//     the reply path, with a timeout; any failure sets `.unavailable` and the
//     reply silently uses BM25.
//   • The reply path NEVER awaits asset load. `rerank` contributes only when the
//     model is already `.ready`; otherwise it returns the BM25 order untouched.
//   • Behind `KnowledgeBrainFlags.semanticRerankEnabled`. Because it degrades to
//     BM25 everywhere it can't run, it's safe to leave on — on the Simulator it
//     simply no-ops; on a device it activates after the one-time asset download.
//
// Per-token vectors are `[Double]` (Apple's type); we mean-pool + L2-normalize
// (via `KnowledgeVectorMath`, converting to `[Float]` for a lighter cache).

enum KnowledgeBrainFlags {
    /// Master switch for the semantic rerank. Safe to leave on: it degrades to
    /// BM25 wherever `NLContextualEmbedding` can't load (Simulator, offline,
    /// pre-download). On a real device it triggers a one-time model-asset
    /// download (~tens of MB) the first time chat assembles a reply. Flip to
    /// `false` to ship pure-BM25 with zero download.
    nonisolated(unsafe) static var semanticRerankEnabled = true

    /// Master switch for the model-driven agentic tool-calling loop (the coach
    /// can call `retrieve_expertise` on demand instead of only the pre-retrieved
    /// block). TEXT chat only — the live voice call stays single-shot for
    /// latency. Fully fallback-guarded: any failure drops to the existing
    /// single-shot grounded reply, so worst case is today's behavior. Needs live
    /// device/network QA (can't be exercised in the Simulator's offline tests).
    nonisolated(unsafe) static var agenticToolCallingEnabled = true
}

@available(iOS 17.0, *)
actor KnowledgeSemanticReranker {

    static let shared = KnowledgeSemanticReranker()

    enum Readiness: Equatable { case cold, warming, ready, unavailable }
    private(set) var readiness: Readiness = .cold

    private var model: NLContextualEmbedding?
    /// cardID -> mean-pooled, L2-normalized embedding. Built once at warmup.
    private var cardVectors: [String: [Float]] = [:]

    private init() {}

    // MARK: Warmup (fire-and-forget, OFF the reply path)

    /// Load the model + embed the corpus once. Safe to call repeatedly; only the
    /// first cold call does work. On ANY failure (Simulator, offline, timeout)
    /// readiness becomes `.unavailable` and the brain stays on BM25. Never throws.
    func warmUpIfNeeded() async {
        guard KnowledgeBrainFlags.semanticRerankEnabled else { return }
        guard readiness == .cold else { return }
        readiness = .warming

        guard let embedding = NLContextualEmbedding(language: .english) else {
            readiness = .unavailable
            return
        }

        do {
            if !embedding.hasAvailableAssets {
                // Off the reply path (fire-and-forget). If this ever hangs on a
                // device, readiness simply stays `.warming` and retrieval keeps
                // using BM25 — the reply is never blocked or failed by it.
                let result = try await embedding.requestAssets()
                guard result == .available else {
                    readiness = .unavailable
                    return
                }
            }
            try embedding.load()

            let dimension = embedding.dimension
            guard dimension > 0 else {
                readiness = .unavailable
                return
            }

            var vectors: [String: [Float]] = [:]
            for card in CoachKnowledgeBase.cards {
                if let vector = Self.embed(card.searchableText, with: embedding, dimension: dimension) {
                    vectors[card.id] = vector
                }
            }
            guard !vectors.isEmpty else {
                readiness = .unavailable
                return
            }

            model = embedding
            cardVectors = vectors
            readiness = .ready
        } catch {
            // Simulator permission error, offline, asset failure — degrade calmly.
            readiness = .unavailable
        }
    }

    // MARK: Rerank (reply path — never blocks on assets)

    /// Reorder BM25 candidates by fusing BM25 rank with semantic-cosine rank.
    /// Returns the BM25 top-`limit` UNCHANGED when the model isn't ready, so the
    /// reply never waits on (or fails because of) the embedding model.
    func rerank(
        query: String,
        candidates: [CoachKnowledgeCard],
        bm25Order: [String],
        limit: Int
    ) -> [CoachKnowledgeCard] {
        guard readiness == .ready, let model,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let queryVector = Self.embed(query, with: model, dimension: model.dimension)
        else {
            return Array(candidates.prefix(max(0, limit)))
        }

        let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })

        // Semantic ranking of the SAME candidate set.
        let semanticOrder = candidates
            .compactMap { card -> (String, Float)? in
                guard let vector = cardVectors[card.id] else { return nil }
                return (card.id, KnowledgeVectorMath.cosine(queryVector, vector))
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0 < rhs.0
            }
            .map(\.0)

        let fusedIDs = KnowledgeVectorMath.reciprocalRankFusion(rankings: [bm25Order, semanticOrder])
        let reordered = fusedIDs.compactMap { byID[$0] }
        return Array(reordered.prefix(max(0, limit)))
    }

    // MARK: Embedding helper

    /// Mean-pool the per-token `[Double]` vectors into one L2-normalized `[Float]`
    /// vector. Returns nil on any embedding failure.
    private static func embed(
        _ text: String,
        with model: NLContextualEmbedding,
        dimension: Int
    ) -> [Float]? {
        guard dimension > 0,
              let result = try? model.embeddingResult(for: text, language: .english)
        else { return nil }

        var pooled = [Double](repeating: 0, count: dimension)
        var tokenCount = 0
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { tokenVector, _ in
            if tokenVector.count == dimension {
                for i in 0..<dimension { pooled[i] += tokenVector[i] }
                tokenCount += 1
            }
            return true
        }
        guard tokenCount > 0 else { return nil }

        let divisor = Double(tokenCount)
        let floatVector = pooled.map { Float($0 / divisor) }
        return KnowledgeVectorMath.l2Normalize(floatVector)
    }
}
