import Foundation

// MARK: - Knowledge Retriever (the "R" in the coach brain's RAG)
//
// Maps a user's chat turn + their active coaching case to the handful of
// `CoachKnowledgeBase` cards most worth grounding the next reply in. This is the
// piece that turns a static corpus into retrieval-augmented coaching.
//
// Mechanism: pure-Swift BM25 over an in-memory inverted index, with two boosts
// (the user's active lever, the user's chosen voice) and an honesty gate. The
// research call for an ~64-card bounded corpus was deliberate: BM25 is
// deterministic, dependency-free, sub-millisecond, works offline and in the
// Simulator, and is fully unit-testable without a device, a model download, or
// any API key. An optional on-device embedding rerank (NLContextualEmbedding) is
// the documented enhancement seam — see the manifest — but it must never become
// a hard dependency (it cannot load in the Simulator), so BM25 is the shipping
// primary, not a fallback.
//
// Tool-shaped on purpose: `retrieve(...)` is a clean, callable function with a
// typed result. Today `CoachReplyPipeline` calls it for the model (fast,
// deterministic grounding). The same function is the drop-in tool a future
// model-driven tool-calling loop would invoke — the agentic upgrade is a wiring
// change, not a rebuild.
//
// Pure, `nonisolated`, no state ownership, no I/O. The honesty gate keeps the
// corpus from violating the weak-evidence -> softer-feedback contract: on a
// cold-start user with no established case, expertise is surfaced ONLY when the
// turn is explicitly asking for technique. Otherwise it stays out of the way and
// the coach reads the person, not a card.

enum KnowledgeRetriever {

    // MARK: Tuning constants (named so tests can assert against them)

    /// Standard BM25 term-frequency saturation.
    static let bm25K1: Double = 1.2
    /// Standard BM25 length-normalization.
    static let bm25B: Double = 0.75
    /// Multiplicative lift when a card serves the user's ACTIVE lever.
    static let leverBoost: Double = 0.6
    /// Multiplicative lift when a card is written for the user's chosen voice.
    static let voiceBoost: Double = 0.25
    /// Seed score so a lever-matched card is still retrievable on a vague but
    /// diagnosed turn (e.g. "what next?" when the active lever is fillers),
    /// where BM25 alone would score it zero.
    static let leverSeedScore: Double = 0.5
    /// Default number of cards surfaced. Keeps the COACHING EXPERTISE block
    /// tight (the formatter caps the token budget). Matches the system
    /// prompt's own instruction to pull in "at most one or two techniques,
    /// never a list" — narrowing here means the model sees fewer, higher-
    /// confidence candidates instead of relying on it to self-select from a
    /// wider, noisier set (a weak model is disproportionately hurt by
    /// distracting context it didn't ask to filter).
    static let defaultLimit: Int = 2
    /// Wider BM25 candidate pool handed to the optional semantic reranker, so it
    /// can promote a semantically-strong card BM25 ranked just outside the top-K.
    static let rerankCandidatePool: Int = 10

    // MARK: Public API (the tool)

    /// Retrieve the cards most worth grounding this turn in.
    ///
    /// - Parameters:
    ///   - query: the user's latest turn (or any technique query).
    ///   - lever: the user's active coaching lever (`CoachMemory.currentLever`),
    ///     used to boost on-case cards. `nil` when there's no diagnosis yet.
    ///   - voice: the user's chosen voice, used to boost register-matched cards.
    ///   - hasDiagnosis: whether Noum has an established case for this user
    ///     (proxy: a current lever exists). Gates proactive expertise so a
    ///     cold-start user isn't prescribed technique on thin evidence.
    ///   - limit: max cards to return.
    /// - Returns: up to `limit` cards, highest relevance first. Empty when the
    ///   honesty gate says expertise shouldn't be surfaced this turn.
    nonisolated static func retrieve(
        query: String,
        lever: SkillArea? = nil,
        voice: SpeakingStyleGoal? = nil,
        hasDiagnosis: Bool = false,
        limit: Int = defaultLimit
    ) -> [CoachKnowledgeCard] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isCoachRepairTurn(trimmed) else { return [] }

        let techniqueTurn = isTechniqueSeekingTurn(trimmed)

        // Honesty gate: don't surface prescriptive expertise on a cold-start
        // user (no diagnosis) UNLESS they explicitly asked for technique. This
        // is the weak-evidence -> softer-feedback contract at the retrieval layer.
        guard techniqueTurn || hasDiagnosis else { return [] }

        let queryTokens = tokenize(trimmed)
        let queryTokenSet = Set(queryTokens)

        // Score every card; keep the ones with real signal.
        var scored: [(card: CoachKnowledgeCard, score: Double)] = []
        for card in CoachKnowledgeBase.cards {
            var base = index.bm25(queryTokens: queryTokens, cardID: card.id)

            let leverMatch = lever.map { card.leverTags.contains($0) } ?? false
            // Seed lever-matched cards so a diagnosed-but-vague turn can still
            // surface the on-case technique even with no lexical overlap.
            if base == 0, leverMatch, hasDiagnosis {
                base = leverSeedScore
            }
            guard base > 0 else { continue }

            // Precision gate: admit a lexically-scored card only when the
            // user's own words hit one of the card's curated `keywords` — the
            // terms authors picked as "what a user would actually type" — or
            // the lever-seed path already vouches for it. Plain BM25 over the
            // full prose (why/howToApply/domain name) is too permissive on
            // short conversational queries: common words shared with an
            // unrelated card (e.g. a conflict-de-escalation card matching on
            // "however", "feel", "thought") can outscore the genuinely
            // relevant card, injecting a distracting, off-topic technique
            // into a weak model's context (the "distraction effect" a noisy
            // retrieval layer causes). Requiring the keyword anchor keeps
            // retrieval high-precision: silence over a wrong card.
            let keywordTokens = Set(card.keywords.flatMap(KnowledgeRetriever.tokenize))
            let keywordMatch = !keywordTokens.isDisjoint(with: queryTokenSet)
            guard keywordMatch || (leverMatch && hasDiagnosis) else { continue }

            // Only boost on an EXPLICIT voice match (a card that names this
            // voice). An "any voice" card (empty alignment) stays neutral.
            let voiceMatch = voice.map { v in
                !card.voiceAlignment.isEmpty && card.voiceAlignment.contains(v)
            } ?? false

            let multiplier = 1.0
                + (leverMatch ? leverBoost : 0)
                + (voiceMatch ? voiceBoost : 0)
            scored.append((card, base * multiplier))
        }

        // Deterministic ordering: score desc, then card id asc for stable ties.
        scored.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.card.id < rhs.card.id
        }

        return scored.prefix(max(0, limit)).map(\.card)
    }

    /// Async retrieval with the OPTIONAL semantic rerank applied when enabled +
    /// the embedding model is ready. Falls back to pure BM25 — byte-identical to
    /// `retrieve` — when the flag is off, the corpus is thin, or the model isn't
    /// ready (Simulator / pre-download / offline). Used by `CoachReplyPipeline`.
    @available(iOS 17.0, *)
    static func retrieveReranked(
        query: String,
        lever: SkillArea? = nil,
        voice: SpeakingStyleGoal? = nil,
        hasDiagnosis: Bool = false,
        limit: Int = defaultLimit
    ) async -> [CoachKnowledgeCard] {
        // Pull a WIDER BM25 candidate set so the reranker has room to promote a
        // semantically-strong card BM25 ranked just outside the final top-K.
        let candidates = retrieve(
            query: query, lever: lever, voice: voice,
            hasDiagnosis: hasDiagnosis, limit: max(limit, rerankCandidatePool)
        )
        guard KnowledgeBrainFlags.semanticRerankEnabled, candidates.count > 1 else {
            return Array(candidates.prefix(max(0, limit)))
        }
        return await KnowledgeSemanticReranker.shared.rerank(
            query: query,
            candidates: candidates,
            bm25Order: candidates.map(\.id),
            limit: limit
        )
    }

    // MARK: Technique-question detection (pure, testable)

    /// Whether a turn is explicitly seeking technique / help — the case where
    /// surfacing expertise is appropriate even with thin user evidence.
    nonisolated static func isTechniqueSeekingTurn(_ query: String) -> Bool {
        let lower = query.lowercased()
        guard !lower.isEmpty else { return false }
        guard !isCoachRepairTurn(lower) else { return false }
        return techniqueSignals.contains { lower.contains($0) }
    }

    /// User turns criticising the coach's answer are trust-repair moments, not
    /// requests for a random technique card just because they mention "tips".
    nonisolated static func isCoachRepairTurn(_ query: String) -> Bool {
        let lower = query.lowercased()
        guard !lower.isEmpty else { return false }

        if coachFormattingRepairSignals.contains(where: { lower.contains($0) }) {
            return true
        }

        guard coachRepairSubjectSignals.contains(where: { lower.contains($0) }) else {
            return false
        }
        return coachRepairQualitySignals.contains { lower.contains($0) }
    }

    private static let techniqueSignals: [String] = [
        "how do i", "how do you", "how can i", "how to", "how should i",
        "what's the best way", "what is the best way", "best way to",
        "what should i", "what do i do", "help me", "any advice", "advice on",
        "tip", "tips", "technique", "get better at", "improve my", "improve at",
        "work on my", "stop saying", "deal with", "how do i handle", "handle a",
        "prepare for", "preparing for", "i keep", "i always", "i tend to",
        "i struggle", "struggle with", "i can't stop", "fix my", "what can i do"
    ]

    private static let coachRepairSubjectSignals: [String] = [
        "this ", "that ", "it ", "your answer", "your reply",
        "your response", "the answer", "the reply", "the response",
        "responses feel", "reply feels", "answer feels", "noum", "coach"
    ]

    private static let coachRepairQualitySignals: [String] = [
        "robotic", "generic ai", "generic tips", "cold", "overexplained",
        "over-explained", "not human", "low eq", "not high eq",
        "too much writing", "too long", "less text", "less writing",
        "doesn't feel", "does not feel", "nowhere near", "no where near"
    ]

    private static let coachFormattingRepairSignals: [String] = [
        "**", "markdown", "tts", "read them out", "read aloud",
        "don't format", "do not format", "symbols"
    ]

    // MARK: BM25 index

    /// Built once over the static corpus. The value is immutable after its
    /// first initialization and only ever read thereafter.
    static let index = BM25Index(cards: CoachKnowledgeBase.cards)

    /// A minimal, deterministic BM25 index over the cards' `searchableText`.
    struct BM25Index {
        /// term -> (cardID -> term frequency in that card)
        private let postings: [String: [String: Int]]
        /// cardID -> token count (document length)
        private let docLengths: [String: Int]
        /// term -> number of cards containing it (document frequency)
        private let docFrequency: [String: Int]
        private let averageDocLength: Double
        private let documentCount: Int

        init(cards: [CoachKnowledgeCard]) {
            var postings: [String: [String: Int]] = [:]
            var docLengths: [String: Int] = [:]
            var docFrequency: [String: Int] = [:]
            var totalLength = 0

            for card in cards {
                let tokens = KnowledgeRetriever.tokenize(card.searchableText)
                docLengths[card.id] = tokens.count
                totalLength += tokens.count

                var termCounts: [String: Int] = [:]
                for token in tokens { termCounts[token, default: 0] += 1 }
                for (term, count) in termCounts {
                    postings[term, default: [:]][card.id] = count
                    docFrequency[term, default: 0] += 1
                }
            }

            self.postings = postings
            self.docLengths = docLengths
            self.docFrequency = docFrequency
            self.documentCount = cards.count
            self.averageDocLength = cards.isEmpty
                ? 0
                : Double(totalLength) / Double(cards.count)
        }

        /// BM25 score of a tokenized query against one card.
        func bm25(queryTokens: [String], cardID: String) -> Double {
            guard documentCount > 0, averageDocLength > 0,
                  let docLength = docLengths[cardID] else { return 0 }
            let dl = Double(docLength)
            let n = Double(documentCount)
            let k1 = KnowledgeRetriever.bm25K1
            let b = KnowledgeRetriever.bm25B

            var score = 0.0
            // Unique query terms only — repeating a query word shouldn't
            // multiply its weight.
            for term in Set(queryTokens) {
                guard let df = docFrequency[term], df > 0,
                      let tf = postings[term]?[cardID], tf > 0 else { continue }
                // BM25 idf with the standard +0.5 smoothing, floored at 0 so a
                // term in nearly every card can't push a score negative.
                let idf = max(0, log((n - Double(df) + 0.5) / (Double(df) + 0.5) + 1))
                let numerator = Double(tf) * (k1 + 1)
                let denominator = Double(tf) + k1 * (1 - b + b * dl / averageDocLength)
                score += idf * (numerator / denominator)
            }
            return score
        }
    }

    // MARK: Tokenizer (pure, dependency-free, deterministic)

    private static let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "if", "then", "of", "to", "in",
        "on", "for", "with", "as", "at", "by", "is", "are", "was", "were", "be",
        "been", "it", "its", "this", "that", "these", "those", "i", "you", "your",
        "my", "me", "we", "us", "they", "them", "he", "she", "do", "does", "did",
        "can", "could", "should", "would", "will", "im", "ive", "id", "so", "up",
        "out", "not", "no", "yes", "ok", "okay", "get", "got", "have", "has"
    ]

    /// Lowercase, split on non-alphanumerics, drop stopwords and single chars,
    /// then light-stem plurals. Deterministic and Foundation-only so the index +
    /// scoring are testable without any framework or device.
    nonisolated static func tokenize(_ text: String) -> [String] {
        let lowered = text.lowercased()
        let raw = lowered.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return raw
            .filter { $0.count > 1 && !stopwords.contains($0) }
            .map(stem)
    }

    /// Conservative plural fold so a user's "interviews" / "fillers" / "pauses"
    /// match the singular forms in the corpus. Strips a trailing "s" only on
    /// words of length >= 4 that don't end in "ss" (leaves "stress", "address"
    /// intact). Applied identically to corpus AND query so the two sides always
    /// agree — exact linguistic correctness matters less than both sides folding
    /// the same way.
    nonisolated static func stem(_ token: String) -> String {
        guard token.count >= 4, token.hasSuffix("s"), !token.hasSuffix("ss") else {
            return token
        }
        return String(token.dropLast())
    }
}

// MARK: - Coach Expertise Formatter
//
// Turns retrieved cards into the COACHING EXPERTISE context block. Kept separate
// from the retriever (and pure) so the wording is testable on its own and the
// honesty contract — naming the technique, the success marker, and a softening
// qualifier for weaker evidence tiers — is enforced in one place.

enum CoachExpertiseFormatter {

    /// Section header. Names the contract the system prompt rule relies on:
    /// this is craft reference to ground the move, NOT a reading of the user.
    static let header =
        "COACHING EXPERTISE (curated technique to ground THIS turn's move — apply it to the user's own data above; it is craft reference, never a reading of the user)"

    /// Build the context lines for the retrieved cards. Returns an empty array
    /// for no cards (so `userContext` emits no empty header).
    static func contextLines(for cards: [CoachKnowledgeCard]) -> [String] {
        guard !cards.isEmpty else { return [] }
        var lines = [header]
        for card in cards {
            lines.append(line(for: card))
        }
        return lines
    }

    /// One card as a single grounded line: title (citable technique), why,
    /// the move, the observable success marker, and an evidence-tier qualifier
    /// for anything below `.empirical` so the coach offers it honestly.
    static func line(for card: CoachKnowledgeCard) -> String {
        let qualifier = card.evidenceTier.softeningQualifier
        let suffix = qualifier.isEmpty ? "" : " [\(qualifier)]"
        return "- \(card.title) (\(card.technique)): \(card.why). Apply it: \(card.howToApply). Working when: \(card.successMarker).\(suffix)"
    }
}
