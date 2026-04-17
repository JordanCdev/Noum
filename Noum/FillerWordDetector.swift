import Foundation

// MARK: - Filler Detection Result

/// A single filler detection with confidence scoring and context classification.
struct FillerDetection {
    let word: String           // The matched filler word (lowercased)
    let range: NSRange         // Location in the source text
    let confidence: Double     // 0–1, how sure this is a filler
    let context: FillerContext // Where in speech this filler appeared

    /// Only detections at or above this threshold should end a Sudden Death run.
    static let suddenDeathThreshold: Double = 0.8
}

/// Classifies where a filler appears in the speech flow.
enum FillerContext: String {
    case transitionGap    // Between ideas — high confidence filler
    case sentenceStart    // Beginning of sentence — medium confidence
    case midPhrase        // Mid-phrase — depends on word
    case promptEcho       // Appears in the prompt — low confidence, likely not a filler
}

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
                    // Allow natural uses without penalty — only flag if excessive.
                    let occurrencesInTranscript = textWords.filter { $0 == matchedWord }.count
                    let occurrencesInPrompt = prompt.lowercased().split { !$0.isLetter }.filter { String($0) == matchedWord }.count
                    // Allow up to prompt count + 2 natural uses before flagging
                    if occurrencesInTranscript <= occurrencesInPrompt + 2 {
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

    // MARK: - Confidence-Scored Detections

    /// Analyze a transcript and return per-detection confidence scores and context.
    /// This is the enhanced detection path used for fair evaluation and baseline tracking.
    ///
    /// - Parameters:
    ///   - text: The transcript to analyze.
    ///   - prompt: The session prompt (for echo exclusion). Pass empty string if none.
    /// - Returns: Array of `FillerDetection` with confidence and context classification.
    static func detections(in text: String, prompt: String = "") -> [FillerDetection] {
        guard !text.isEmpty else { return [] }

        let fullRange = NSRange(text.startIndex..., in: text)
        var results: [FillerDetection] = []
        let lowText = text.lowercased()
        let textWords = lowText.split { !$0.isLetter }.map(String.init)

        // Normalize prompt words for echo detection
        let promptWords = Set(prompt.lowercased().split { !$0.isLetter }.map(String.init))
        let promptWordCounts: [String: Int] = {
            var counts: [String: Int] = [:]
            for w in prompt.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init) {
                counts[w, default: 0] += 1
            }
            return counts
        }()

        // --- Pure disfluencies (always high confidence) ---

        // Dynamic vocal hesitation patterns (elongated ums, uhs, etc.)
        if let disfluencyRegex = try? NSRegularExpression(
            pattern: #"(?i)(?<!\w)(?:u+h{2,}|u+m{2,}|hu+h+|er{2,}|er+m{2,}|ah+|eh+|h+m+|m{2,})(?=\b|[^\w]|$)"#
        ) {
            let matches = disfluencyRegex.matches(in: text, range: fullRange)
            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }
                let word = String(text[range]).lowercased()
                let ctx = classifyContext(range: match.range, in: text, textWords: textWords)
                results.append(FillerDetection(
                    word: word, range: match.range,
                    confidence: 0.95, context: ctx
                ))
            }
        }

        // Exact single-word pure disfluencies
        for disfluency in pureDisfluencies {
            let pattern = #"(?i)(?<!\w)\#(NSRegularExpression.escapedPattern(for: disfluency))(?=\b|[^\w]|$)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: fullRange)
            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }
                let word = String(text[range]).lowercased()
                let ctx = classifyContext(range: match.range, in: text, textWords: textWords)
                results.append(FillerDetection(
                    word: word, range: match.range,
                    confidence: 0.95, context: ctx
                ))
            }
        }

        // --- Ambiguous words with context-dependent confidence ---

        for ambiguous in ambiguousWords {
            let pattern = #"(?i)(?<!\w)\#(NSRegularExpression.escapedPattern(for: ambiguous))(?=\b|[^\w]|$)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: fullRange)

            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }
                let matchedWord = String(text[range]).lowercased()

                // Prompt echo check — when a word appears in the prompt, the user is
                // naturally primed to use it. Be generous: allow prompt count + 2 natural uses
                // before treating excess as potential fillers.
                if promptWords.contains(matchedWord) {
                    let transcriptCount = textWords.filter { $0 == matchedWord }.count
                    let promptCount = promptWordCounts[matchedWord] ?? 0
                    if transcriptCount <= promptCount + 2 {
                        // Likely echoing the prompt
                        results.append(FillerDetection(
                            word: matchedWord, range: match.range,
                            confidence: 0.15, context: .promptEcho
                        ))
                        continue
                    }
                }

                let startIdx = text.distance(from: text.startIndex, to: range.lowerBound)
                let wordIndex = text[text.startIndex..<range.lowerBound].split { !$0.isLetter }.count
                let beforeWords = textWords.prefix(max(0, wordIndex))
                let afterStart = min(wordIndex + 1, textWords.count)
                let afterWords = afterStart < textWords.count ? Array(textWords[afterStart...]) : []
                let precedingWord = beforeWords.last ?? ""
                let followingWord = afterWords.first ?? ""

                if matchedWord == "like" {
                    let detection = classifyLike(
                        precedingWord: precedingWord,
                        followingWord: followingWord,
                        startIdx: startIdx,
                        matchRange: match.range,
                        in: text,
                        textWords: textWords
                    )
                    if let d = detection { results.append(d) }

                } else if matchedWord == "so" {
                    let detection = classifySo(
                        precedingWord: precedingWord,
                        followingWord: followingWord,
                        startIdx: startIdx,
                        matchRange: match.range,
                        in: text,
                        textWords: textWords
                    )
                    if let d = detection { results.append(d) }

                } else if matchedWord == "you know" {
                    let detection = classifyYouKnow(
                        range: range,
                        matchRange: match.range,
                        in: text,
                        textWords: textWords
                    )
                    if let d = detection { results.append(d) }
                }
            }
        }

        // --- Deduplicate by range ---
        var seenRanges = Set<String>()
        var unique: [FillerDetection] = []
        for detection in results {
            let key = "\(detection.range.location)-\(detection.range.length)"
            if seenRanges.insert(key).inserted {
                unique.append(detection)
            }
        }

        return unique.sorted { $0.range.location < $1.range.location }
    }

    /// High-confidence detection count (only detections above the sudden death threshold).
    static func highConfidenceCount(in text: String, prompt: String = "") -> Int {
        detections(in: text, prompt: prompt)
            .filter { $0.confidence >= FillerDetection.suddenDeathThreshold }
            .count
    }

    // MARK: - Context Classification Helpers

    /// Determine the speech context of a match based on its position in the text.
    private static func classifyContext(range: NSRange, in text: String, textWords: [String]) -> FillerContext {
        // Near start of text → sentence start
        if range.location < 5 {
            return .sentenceStart
        }

        // Check for sentence boundary before the match
        guard let swiftRange = Range(range, in: text) else { return .midPhrase }
        let before = String(text[text.startIndex..<swiftRange.lowerBound])
        let trimmedBefore = before.trimmingCharacters(in: .whitespaces)

        // After punctuation → transition gap (between sentences/clauses)
        if let lastChar = trimmedBefore.last,
           ".!?,;:—–-".contains(lastChar) {
            return .transitionGap
        }

        // After conjunctions that start new clauses → transition
        let lastWord = trimmedBefore.split { !$0.isLetter }.last.map(String.init)?.lowercased() ?? ""
        let clauseStarters: Set<String> = ["and", "but", "or", "so", "then", "because", "although", "however"]
        if clauseStarters.contains(lastWord) {
            return .transitionGap
        }

        return .midPhrase
    }

    /// Classify "like" with enhanced context rules.
    private static func classifyLike(
        precedingWord: String,
        followingWord: String,
        startIdx: Int,
        matchRange: NSRange,
        in text: String,
        textWords: [String]
    ) -> FillerDetection? {
        // Non-filler: after simile/preference verbs
        let simileVerbs: Set<String> = [
            "feel", "feels", "felt", "look", "looks", "looked",
            "sound", "sounds", "sounded", "seem", "seems",
            "taste", "tastes", "would", "dont", "didnt"
        ]
        if simileVerbs.contains(precedingWord) { return nil }

        // Non-filler: before articles/demonstratives (comparison usage)
        let comparisonFollowers: Set<String> = ["a", "an", "the", "that", "this", "what", "how"]
        if comparisonFollowers.contains(followingWord) { return nil }

        // Non-filler: "like" used as a verb/preposition with a content word following
        // Patterns: "I like about", "I like to", "what I like", "you like"
        let verbFollowers: Set<String> = ["to", "it", "about", "when", "because", "doing", "having", "being"]
        if precedingWord == "i" && verbFollowers.contains(followingWord) { return nil }

        // High confidence: after filler-preceding words that create a clear filler pattern
        // "was like", "she like went", "it like brings" — but NOT "I like" alone (ambiguous verb)
        let fillerPreceders: Set<String> = ["he", "she", "they", "we", "it", "its", "was", "is", "and", "but"]
        if fillerPreceders.contains(precedingWord) {
            let ctx = classifyContext(range: matchRange, in: text, textWords: textWords)
            return FillerDetection(
                word: "like", range: matchRange,
                confidence: 0.85,
                context: ctx
            )
        }

        // Sentence-initial "like" is a filler but lower confidence
        if startIdx < 3 {
            return FillerDetection(
                word: "like", range: matchRange,
                confidence: 0.75,
                context: .sentenceStart
            )
        }

        // "I like" without a verb-follower is ambiguous — could be quotative ("I was like")
        // or genuine preference ("I like this"). Give lower confidence.
        if precedingWord == "i" {
            return FillerDetection(
                word: "like", range: matchRange,
                confidence: 0.5,
                context: .midPhrase
            )
        }

        // Ambiguous — give benefit of the doubt with low confidence
        return FillerDetection(
            word: "like", range: matchRange,
            confidence: 0.4,
            context: .midPhrase
        )
    }

    /// Classify "so" with context rules.
    private static func classifySo(
        precedingWord: String,
        followingWord: String,
        startIdx: Int,
        matchRange: NSRange,
        in text: String,
        textWords: [String]
    ) -> FillerDetection? {
        // Non-filler: "so that", "so much", etc. (adverbial use)
        let nonFillerFollowers: Set<String> = ["that", "much", "many", "far", "long", "often", "good", "bad"]
        if nonFillerFollowers.contains(followingWord) { return nil }

        // Non-filler: "not so", "just so", "is so" (degree adverb)
        let nonFillerPreceders: Set<String> = ["not", "just", "is", "was", "be"]
        if nonFillerPreceders.contains(precedingWord) { return nil }

        // At sentence start or after pause, likely filler
        if startIdx < 3 || precedingWord.isEmpty {
            return FillerDetection(
                word: "so", range: matchRange,
                confidence: 0.7,
                context: startIdx < 3 ? .sentenceStart : .transitionGap
            )
        }

        // After conjunctions ("and so", "but so", "or so I think"), "so" is a transitional filler
        let conjunctions: Set<String> = ["and", "but", "or", "then", "like", "yeah"]
        if conjunctions.contains(precedingWord) {
            return FillerDetection(
                word: "so", range: matchRange,
                confidence: 0.65,
                context: .midPhrase
            )
        }

        return nil
    }

    /// Classify "you know" with context rules.
    private static func classifyYouKnow(
        range: Range<String.Index>,
        matchRange: NSRange,
        in text: String,
        textWords: [String]
    ) -> FillerDetection? {
        // Check what follows
        let afterIdx = range.upperBound
        let trailing = String(text[afterIdx...]).trimmingCharacters(in: .whitespaces).lowercased()

        // Non-filler: "you know what/that/how/who/where" (genuine question)
        let questionFollowers = ["what", "that", "how", "who", "where", "when", "why", "if"]
        for follower in questionFollowers {
            if trailing.hasPrefix(follower) { return nil }
        }

        // Non-filler: "do/did you know" (genuine question)
        let beforeStr = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces).lowercased()
        if beforeStr.hasSuffix("do") || beforeStr.hasSuffix("did") || beforeStr.hasSuffix("don't") || beforeStr.hasSuffix("didn't") {
            return nil
        }

        // "you know" as standalone discourse marker — high confidence filler
        let ctx = classifyContext(range: matchRange, in: text, textWords: textWords)
        return FillerDetection(
            word: "you know", range: matchRange,
            confidence: 0.9,
            context: ctx
        )
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
