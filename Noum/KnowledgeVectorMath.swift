import Foundation

// MARK: - Knowledge Vector Math (pure)
//
// The deterministic vector arithmetic behind the OPTIONAL semantic rerank of the
// coach brain's BM25 results. Split out from `KnowledgeSemanticReranker` (which
// wraps the device-only `NLContextualEmbedding` model) so this math is unit-
// testable on any host — no framework, no model download, no Simulator caveat.
//
// All Foundation-only, all `nonisolated`, all total.

enum KnowledgeVectorMath {

    /// Mean-pool a set of per-token vectors into one document vector.
    /// `NLContextualEmbedding` yields a vector PER TOKEN; a single document
    /// vector is the element-wise mean. Returns `[]` for no tokens, or for a
    /// ragged input (defensive — all token vectors must share a dimension).
    nonisolated static func meanPool(_ tokenVectors: [[Float]]) -> [Float] {
        guard let first = tokenVectors.first, !first.isEmpty else { return [] }
        let dim = first.count
        guard tokenVectors.allSatisfy({ $0.count == dim }) else { return [] }

        var sum = [Float](repeating: 0, count: dim)
        for vector in tokenVectors {
            for i in 0..<dim { sum[i] += vector[i] }
        }
        let count = Float(tokenVectors.count)
        for i in 0..<dim { sum[i] /= count }
        return sum
    }

    /// L2-normalize so cosine reduces to a dot product. Returns the input
    /// unchanged when its magnitude is zero (defensive — never divides by 0).
    nonisolated static func l2Normalize(_ vector: [Float]) -> [Float] {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }

    /// Cosine similarity in [-1, 1]. Returns 0 for empty or mismatched-length
    /// inputs (defensive) so a malformed vector can't poison a ranking.
    nonisolated static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var dot: Float = 0, magA: Float = 0, magB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            magA += a[i] * a[i]
            magB += b[i] * b[i]
        }
        let denom = sqrt(magA) * sqrt(magB)
        guard denom > 0 else { return 0 }
        return dot / denom
    }

    /// Reciprocal Rank Fusion over any number of ranked id-lists. RRF is the
    /// standard, score-scale-free way to fuse a lexical (BM25) ranking with a
    /// semantic (cosine) ranking: a card's fused score is the sum across lists
    /// of `1 / (k + rank)`, rank being 0-based position. k=60 is the robust
    /// default. Returns ids sorted by fused score desc, ties broken by id asc
    /// for determinism.
    nonisolated static func reciprocalRankFusion(
        rankings: [[String]],
        k: Double = 60
    ) -> [String] {
        var fused: [String: Double] = [:]
        for ranking in rankings {
            for (rank, id) in ranking.enumerated() {
                fused[id, default: 0] += 1.0 / (k + Double(rank))
            }
        }
        return fused
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .map(\.key)
    }
}
