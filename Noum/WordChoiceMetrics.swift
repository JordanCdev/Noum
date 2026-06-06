import Foundation

// MARK: - Word Choice Metrics
//
// Computes a "variety score" + repetition signal from a session's
// transcript. The two signals coach different things:
//
// - `uniqueRatio` — distinct-word count / total-word count. Higher = more
//   varied vocabulary. Sensitive to length: longer answers naturally
//   trend lower.
// - `repeatedContentWords` — top 3 content words (excluding stop-words and
//   filler tokens) used most. Surfaces verbal habits the user has but
//   hasn't named, complementing `ClutchWordStore` (which is user-curated).
//
// Both are computed deterministically — no AI, no network. Lives next to
// `PauseMetrics` as the second leg of "speech quality v2".
//
// Stays a struct on the session so we can persist + chart over time
// without re-tokenizing the transcript on every read.

struct WordChoiceMetrics: Codable, Equatable {
    /// Distinct words / total words after filtering. 0 when the session is
    /// too short to read (< 20 content words).
    let uniqueRatio: Double
    /// Top content words by raw count. Lowercased, stop-words and fillers
    /// excluded. Capped at 3.
    let repeatedContentWords: [Repeated]
    /// Total content-words counted (post-filter). Used for confidence.
    let contentWordCount: Int

    struct Repeated: Codable, Equatable, Identifiable {
        let word: String
        let count: Int
        var id: String { word }
    }

    /// Minimum content-word count needed before we report metrics. Shorter
    /// answers don't have enough material for the ratio to be meaningful.
    static let minContentWords: Int = 20

    static let empty = WordChoiceMetrics(
        uniqueRatio: 0,
        repeatedContentWords: [],
        contentWordCount: 0
    )

    static func compute(transcript: String) -> WordChoiceMetrics {
        let tokens = transcript
            .lowercased()
            .split { !$0.isLetter }
            .map(String.init)
        let content = tokens.filter { token in
            !Self.stopWords.contains(token)
                && !Self.fillerTokens.contains(token)
                && token.count >= 3
        }
        guard content.count >= minContentWords else { return .empty }

        let unique = Set(content).count
        let ratio = Double(unique) / Double(content.count)

        // Count occurrences and pick the top 3 content words. Tie-break by
        // alphabetical order so the result is stable across runs.
        let counts = Dictionary(grouping: content, by: { $0 }).mapValues(\.count)
        let sorted = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }
        let top = sorted
            .prefix(3)
            .filter { $0.value >= 3 }   // need at least 3 reps to be a habit
            .map { Repeated(word: $0.key, count: $0.value) }

        return WordChoiceMetrics(
            uniqueRatio: ratio,
            repeatedContentWords: Array(top),
            contentWordCount: content.count
        )
    }

    // MARK: - Lexicons

    /// Common English stop words. Removing these is what makes the
    /// "repeated content words" signal interesting — without filtering,
    /// the top 3 would always be "the / a / I".
    private static let stopWords: Set<String> = [
        "the", "and", "but", "for", "with", "you", "your", "yours",
        "are", "was", "were", "have", "has", "had", "this", "that",
        "these", "those", "they", "them", "their", "theirs", "from",
        "into", "onto", "what", "when", "where", "which", "while", "who",
        "whom", "why", "how", "about", "above", "below", "after", "again",
        "all", "any", "because", "been", "being", "between", "both", "can",
        "could", "did", "does", "doing", "down", "each", "few", "further",
        "here", "more", "most", "other", "over", "same", "should",
        "some", "such", "than", "then", "there", "through", "under", "until",
        "very", "will", "would", "shall", "may", "might", "must",
        "ours", "yourself", "yourselves", "themselves",
        "him", "her", "his", "hers", "she", "its",
        "ourselves", "myself", "itself", "himself", "herself"
    ]

    /// Filler tokens. Excluded so they don't show up as "repeated content"
    /// (they're already coached on their own track via FillerWordDetector).
    private static let fillerTokens: Set<String> = [
        "um", "uh", "ah", "er", "erm", "hmm", "mhm", "uhm",
        "like", "literally", "basically", "actually", "honestly",
        "sort", "kind"
    ]
}

// MARK: - Coaching read

extension WordChoiceMetrics {
    /// Short, on-voice headline for the summary card. Avoids fake certainty
    /// when sample size is tiny.
    var headline: String {
        guard contentWordCount > 0 else { return "Not enough material to read" }
        if let top = repeatedContentWords.first {
            return "\"\(top.word)\" carried the rep"
        }
        if uniqueRatio >= 0.7 { return "Crisp, varied word choice" }
        if uniqueRatio >= 0.55 { return "Solid range, some repetition" }
        return "Varied vocabulary"
    }

    var coachLine: String {
        guard contentWordCount >= Self.minContentWords else {
            return "Longer answers give the coach more vocabulary to read."
        }
        if let top = repeatedContentWords.first, top.count >= 5 {
            return "\"\(top.word)\" landed \(top.count) times. Swap one for a stronger noun next rep."
        }
        if uniqueRatio < 0.45 {
            return "Vocabulary stayed tight. The next rep is a chance to stretch one word further."
        }
        return "Word choice is working — vary further by leaning on stronger verbs over filler nouns."
    }
}
