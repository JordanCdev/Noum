import Foundation

// MARK: - Filler Word Breakdown

/// Per-word filler breakdown from a single transcript analysis.
struct FillerWordBreakdown {
    /// Total filler count across all words.
    let totalCount: Int
    /// Per-word counts, e.g. ["um": 3, "like": 5, "uh": 1]. Lowercased keys.
    let wordCounts: [String: Int]
    /// All match ranges in the source text.
    let matchRanges: [NSRange]

    var isEmpty: Bool { totalCount == 0 }

    /// Top filler words sorted by frequency (descending).
    var topWords: [(word: String, count: Int)] {
        wordCounts.sorted { $0.value > $1.value }.map { (word: $0.key, count: $0.value) }
    }
}

// MARK: - Filler Word Detector

struct FillerWordDetector {
    static let baseFillerWords: Set<String> = [
        "uh", "um", "er", "erm", "ah", "eh", "huh",
        "like", "so", "you know"
    ]

    /// Deepgram-supported filler words (returned when filler_words=true).
    static let deepgramFillerWords: Set<String> = [
        "uh", "um", "mhmm", "mm-mm", "uh-uh", "uh-huh", "nuh-uh"
    ]

    /// All words to detect: base set + any user custom words.
    static func effectiveWordSet(customWords: Set<String> = []) -> Set<String> {
        baseFillerWords.union(customWords.map { $0.lowercased() })
    }

    static func buildRegexes(for words: Set<String>) -> [NSRegularExpression] {
        var regexes: [NSRegularExpression] = []
        // Dynamic vocal hesitation patterns
        if let dynamic = try? NSRegularExpression(
            pattern: #"(?i)(?<!\w)(?:u+h{2,}|u+m{2,}|hu+h+|er{2,}|er+m{2,}|ah+|eh+|h+m+|m{2,})(?=\b|[^\w]|$)"#
        ) {
            regexes.append(dynamic)
        }
        for word in words {
            let escaped = NSRegularExpression.escapedPattern(for: word)
            let pattern = #"(?i)(?<!\w)\#(escaped)(?=\b|[^\w]|$)"#
            if let r = try? NSRegularExpression(pattern: pattern) {
                regexes.append(r)
            }
        }
        return regexes
    }

    // Default regexes using base set only (for backward compat)
    static let fillerWordRegexes: [NSRegularExpression] = buildRegexes(for: baseFillerWords)

    static func matches(in text: String) -> [NSTextCheckingResult] {
        fillerWordRegexes.flatMap { regex in
            regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        }
    }

    static func count(in text: String) -> Int {
        matches(in: text).count
    }

    // MARK: - Context-Aware Detection (for Sudden Death / Pressure Drill)

    /// Words that are ONLY counted as fillers when used as discourse markers / disfluencies,
    /// not when used as regular vocabulary (e.g. "like" as a verb/preposition, "so" as an adverb).
    private static let ambiguousWords: Set<String> = ["like", "so", "you know"]

    /// Pure disfluency sounds that are always fillers regardless of context.
    private static let pureDisfluencies: Set<String> = ["uh", "um", "er", "erm", "ah", "eh", "huh"]

    /// Detect fillers with prompt-awareness and contextual heuristics.
    /// Returns only high-confidence filler matches suitable for ending a Pressure Drill run.
    ///
    /// Layers:
    /// 1. Prompt echo exclusion — if the user repeats words from the prompt, don't penalize.
    /// 2. Pure disfluency pass — "uh", "um", "er" etc. are always fillers.
    /// 3. Ambiguous word analysis — "like", "so", "you know" require context checks.
    /// 4. Confidence threshold — only flag if high-confidence.
    static func pressureDrillMatches(in text: String, prompt: String) -> [NSTextCheckingResult] {
        guard !text.isEmpty else { return [] }

        let fullRange = NSRange(text.startIndex..., in: text)
        var confirmedMatches: [NSTextCheckingResult] = []

        // Normalize prompt into words for echo detection
        let promptWords = Set(prompt.lowercased().split { !$0.isLetter }.map(String.init))

        // --- Layer 1: Pure disfluency regex (always fillers) ---
        if let disfluencyRegex = try? NSRegularExpression(
            pattern: #"(?i)(?<!\w)(?:u+h{2,}|u+m{2,}|hu+h+|er{2,}|er+m{2,}|ah+|eh+|h+m+|m{2,})(?=\b|[^\w]|$)"#
        ) {
            confirmedMatches.append(contentsOf: disfluencyRegex.matches(in: text, range: fullRange))
        }

        // Exact single-word disfluencies
        for word in pureDisfluencies {
            let pattern = #"(?i)(?<!\w)\#(NSRegularExpression.escapedPattern(for: word))(?=\b|[^\w]|$)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            confirmedMatches.append(contentsOf: regex.matches(in: text, range: fullRange))
        }

        // --- Layer 2: Ambiguous words with context checks ---
        let lowText = text.lowercased()
        let textWords = lowText.split { !$0.isLetter }.map(String.init)

        for ambiguous in ambiguousWords {
            let pattern = #"(?i)(?<!\w)\#(NSRegularExpression.escapedPattern(for: ambiguous))(?=\b|[^\w]|$)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: fullRange)

            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }
                let matchedWord = String(text[range]).lowercased()

                // Skip if this word appears in the prompt (prompt echo)
                if promptWords.contains(matchedWord) {
                    // Check if this is genuinely repeated from prompt context.
                    // Allow the first occurrence without penalty — only flag if excessive.
                    let occurrencesInTranscript = textWords.filter { $0 == matchedWord }.count
                    let occurrencesInPrompt = prompt.lowercased().split { !$0.isLetter }.filter { String($0) == matchedWord }.count
                    // Allow up to prompt count + 1 natural uses before flagging
                    if occurrencesInTranscript <= occurrencesInPrompt + 1 {
                        continue
                    }
                }

                // Context check: look at surrounding words
                let startIdx = text.distance(from: text.startIndex, to: range.lowerBound)
                let wordIndex = text[text.startIndex..<range.lowerBound].split { !$0.isLetter }.count

                if matchedWord == "like" {
                    // "like" is a filler when:
                    // - Sentence-initial or after a pause marker
                    // - Preceded by subject pronoun (I, he, she, they, we, it)
                    // - Between two content words as a hedge
                    // "like" is NOT a filler when:
                    // - After "feel", "look", "sound", "seem", "taste" (simile)
                    // - After "would" (preference: "I would like")
                    // - Part of "like a", "like the", "like that" (comparison)
                    let beforeWords = textWords.prefix(max(0, wordIndex))
                    let afterStart = min(wordIndex + 1, textWords.count)
                    let afterWords = afterStart < textWords.count ? Array(textWords[afterStart...]) : []

                    let precedingWord = beforeWords.last ?? ""
                    let followingWord = afterWords.first ?? ""

                    // Non-filler patterns
                    let simileVerbs: Set<String> = ["feel", "feels", "felt", "look", "looks", "looked",
                                                     "sound", "sounds", "sounded", "seem", "seems",
                                                     "taste", "tastes", "would", "dont", "didnt"]
                    if simileVerbs.contains(precedingWord) { continue }
                    let comparisonFollowers: Set<String> = ["a", "an", "the", "that", "this", "what", "how"]
                    if comparisonFollowers.contains(followingWord) { continue }

                    // If the word appears at the very start, it's likely filler
                    // If preceded by a pronoun, it's likely filler ("I like went...")
                    let fillerPreceders: Set<String> = ["i", "he", "she", "they", "we", "it", "its", "was", "is", "and", "but"]
                    if startIdx < 3 || fillerPreceders.contains(precedingWord) {
                        confirmedMatches.append(match)
                    }
                    // Otherwise skip — ambiguous, give benefit of the doubt

                } else if matchedWord == "so" {
                    // "so" is a filler at sentence start or after conjunctions
                    // "so" is NOT a filler in "so that", "so much", "not so", adverbial use
                    let afterStart2 = min(wordIndex + 1, textWords.count)
                    let followingWord2 = afterStart2 < textWords.count ? textWords[afterStart2] : ""
                    let beforeWords2 = textWords.prefix(max(0, wordIndex))
                    let precedingWord2 = beforeWords2.last ?? ""

                    let nonFillerFollowers: Set<String> = ["that", "much", "many", "far", "long", "often", "good", "bad"]
                    if nonFillerFollowers.contains(followingWord2) { continue }
                    let nonFillerPreceders: Set<String> = ["not", "just", "is", "was", "be"]
                    if nonFillerPreceders.contains(precedingWord2) { continue }

                    // At sentence start or after pause, likely filler
                    if startIdx < 3 || precedingWord2.isEmpty {
                        confirmedMatches.append(match)
                    }

                } else if matchedWord == "you know" {
                    // "you know" as standalone discourse marker is almost always filler
                    // Exception: "you know what", "you know that", "do you know"
                    let afterRange = text.index(range.upperBound, offsetBy: 0, limitedBy: text.endIndex) ?? text.endIndex
                    let trailing = String(text[afterRange...]).trimmingCharacters(in: .whitespaces).lowercased()
                    if trailing.hasPrefix("what") || trailing.hasPrefix("that") || trailing.hasPrefix("how") || trailing.hasPrefix("who") || trailing.hasPrefix("where") {
                        continue
                    }
                    let beforeStr = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces).lowercased()
                    if beforeStr.hasSuffix("do") || beforeStr.hasSuffix("did") || beforeStr.hasSuffix("don't") || beforeStr.hasSuffix("didn't") {
                        continue
                    }
                    confirmedMatches.append(match)
                }
            }
        }

        // --- Deduplicate by range ---
        var seenRanges = Set<String>()
        var unique: [NSTextCheckingResult] = []
        for match in confirmedMatches {
            let key = "\(match.range.location)-\(match.range.length)"
            if seenRanges.insert(key).inserted {
                unique.append(match)
            }
        }

        return unique
    }

    /// Convenience: count-only version of pressureDrillMatches.
    static func pressureDrillCount(in text: String, prompt: String) -> Int {
        pressureDrillMatches(in: text, prompt: prompt).count
    }

    // MARK: - Per-Word Breakdown

    /// Analyze a transcript and return a detailed breakdown of filler words found.
    static func breakdown(in text: String, customWords: Set<String> = []) -> FillerWordBreakdown {
        let words = effectiveWordSet(customWords: customWords)
        let regexes = buildRegexes(for: words)
        let fullRange = NSRange(text.startIndex..., in: text)

        var allMatches: [NSTextCheckingResult] = []
        var wordCounts: [String: Int] = [:]

        for regex in regexes {
            let found = regex.matches(in: text, range: fullRange)
            for match in found {
                allMatches.append(match)
                if let range = Range(match.range, in: text) {
                    let matched = String(text[range]).lowercased()
                    wordCounts[matched, default: 0] += 1
                }
            }
        }

        // Deduplicate overlapping matches (keep unique ranges)
        var seenRanges = Set<String>()
        var uniqueMatches: [NSTextCheckingResult] = []
        var uniqueWordCounts: [String: Int] = [:]

        for match in allMatches {
            let key = "\(match.range.location)-\(match.range.length)"
            if seenRanges.insert(key).inserted {
                uniqueMatches.append(match)
                if let range = Range(match.range, in: text) {
                    let matched = String(text[range]).lowercased()
                    uniqueWordCounts[matched, default: 0] += 1
                }
            }
        }

        return FillerWordBreakdown(
            totalCount: uniqueMatches.count,
            wordCounts: uniqueWordCounts,
            matchRanges: uniqueMatches.map(\.range)
        )
    }
}
