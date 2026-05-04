import Foundation

// MARK: - Eloquence Engine
//
// Detects classical rhetorical devices on a transcript and surfaces them as
// positive coaching feedback. Inspired by Mark Forsyth's *The Elements of
// Eloquence* — speaking well isn't just about clean delivery, it's about
// shape: lists of three, parallel structure, repetition with intent.
//
// The engine is **pure** — no IO, no @MainActor, no Foundation singletons
// beyond the regex stdlib. Easy to unit-test, easy to reuse from session
// finalisation or a future review tool.
//
// Detection strategy: lightweight pattern matching on a normalised token
// stream. We deliberately err toward **false negatives** — a low-confidence
// finding flagged as rhetoric would be worse than not flagging real rhetoric
// at all (the user's trust is fragile here). Devices that genuinely require
// semantic understanding (antithesis, real metaphor) are tagged as such and
// kept conservative.

// MARK: - Public types

/// One rhetorical device detection. A short snippet of the transcript that
/// triggered it + a coach-voice line explaining what made it work.
struct EloquenceFinding: Codable, Equatable, Identifiable {
    let id: UUID
    let device: EloquenceDevice
    let snippet: String
    let coachLine: String

    init(id: UUID = UUID(), device: EloquenceDevice, snippet: String, coachLine: String) {
        self.id = id
        self.device = device
        self.snippet = snippet
        self.coachLine = coachLine
    }
}

/// Classical figure of speech. Names match Forsyth + Toastmasters
/// vocabulary so coach-facing copy is consistent.
enum EloquenceDevice: String, Codable, CaseIterable {
    case tricolon
    case anaphora
    case epistrophe
    case alliteration
    case isocolon
    case antithesis
    case polysyndeton
    case asyndeton
    case diacope
    case epizeuxis
    case rhetoricalQuestion
    case ruleOfThree

    var title: String {
        switch self {
        case .tricolon, .ruleOfThree: return "Rule of three"
        case .anaphora: return "Anaphora"
        case .epistrophe: return "Epistrophe"
        case .alliteration: return "Alliteration"
        case .isocolon: return "Parallel structure"
        case .antithesis: return "Antithesis"
        case .polysyndeton: return "Polysyndeton"
        case .asyndeton: return "Asyndeton"
        case .diacope: return "Diacope"
        case .epizeuxis: return "Emphatic repetition"
        case .rhetoricalQuestion: return "Rhetorical question"
        }
    }

    /// Default coach-line if a finding doesn't ship its own. Expressed as a
    /// fact about *why* the device worked, not flattery — keeps the Noum
    /// voice ("a coach who heard your last five reps") intact.
    var defaultCoachLine: String {
        switch self {
        case .tricolon, .ruleOfThree:
            return "Lists of three feel complete. The third item is what makes it land."
        case .anaphora:
            return "Repeating the opening of a clause builds rhythm and presses the point."
        case .epistrophe:
            return "Ending consecutive clauses on the same word makes the closing word the verdict."
        case .alliteration:
            return "Same-sound openings make a phrase memorable without sounding clever."
        case .isocolon:
            return "Parallel grammar makes ideas sound equally weighted."
        case .antithesis:
            return "Setting an idea against its opposite makes both sharper."
        case .polysyndeton:
            return "Stacking conjunctions slows the listener down and adds gravity."
        case .asyndeton:
            return "Dropping the conjunction speeds delivery and presses urgency."
        case .diacope:
            return "Repeating a word with something between it makes the second hit land harder."
        case .epizeuxis:
            return "Repeating the same word back-to-back is the rawest emphasis."
        case .rhetoricalQuestion:
            return "Asking instead of asserting pulls the listener into the answer with you."
        }
    }
}

// MARK: - Engine

enum EloquenceEngine {

    /// Run all detectors over a transcript and return findings sorted by
    /// rhetorical impact. Caps at `maxFindings` so the summary surface stays
    /// uncluttered.
    static func analyse(transcript: String, maxFindings: Int = 4) -> [EloquenceFinding] {
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 30 else { return [] } // not enough to draw on

        let sentences = splitIntoSentences(cleaned)
        let words = tokenise(cleaned)
        // Short threshold: anything under 5 tokens is unlikely to carry a
        // detectable device. Per-detector guards refuse anything tighter.
        guard words.count >= 5 else { return [] }

        var findings: [EloquenceFinding] = []
        findings.append(contentsOf: detectTricolon(sentences: sentences))
        findings.append(contentsOf: detectAnaphora(sentences: sentences))
        findings.append(contentsOf: detectEpistrophe(sentences: sentences))
        findings.append(contentsOf: detectAlliteration(words: words))
        findings.append(contentsOf: detectIsocolon(sentences: sentences))
        findings.append(contentsOf: detectAntithesis(sentences: sentences))
        findings.append(contentsOf: detectPolysyndeton(sentences: sentences))
        findings.append(contentsOf: detectAsyndeton(sentences: sentences))
        findings.append(contentsOf: detectDiacope(sentences: sentences))
        findings.append(contentsOf: detectEpizeuxis(words: words))
        findings.append(contentsOf: detectRhetoricalQuestion(sentences: sentences))

        return Array(prioritised(findings).prefix(maxFindings))
    }

    /// Lighter "did the user use ANY rhetorical move?" check — used by the
    /// scoring pipeline to award an "eloquence bonus" without surfacing a
    /// full finding list.
    static func hasAnyDevice(transcript: String) -> Bool {
        !analyse(transcript: transcript, maxFindings: 1).isEmpty
    }

    // MARK: - Detection
    //
    // Each detector is a pure function over the tokenised transcript. They
    // produce zero or more findings. Every finding ships a short snippet so
    // the summary card can highlight exactly what the user said.

    private static func detectTricolon(sentences: [String]) -> [EloquenceFinding] {
        var found: [EloquenceFinding] = []
        for sentence in sentences {
            // Look for: "A, B, and C" or "A, B, C" with the items being
            // mostly nouns/verbs and not too long.
            let lowered = sentence.lowercased()
            guard let match = tricolonRegex.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) else {
                continue
            }
            let matchedRange = Range(match.range, in: lowered)
            guard let r = matchedRange else { continue }
            let snippet = String(lowered[r])
            // Reject obvious lists (e.g. shopping lists) — require at least
            // one item to be 2+ words OR at least 5 syllables across items.
            let items = snippet.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard items.count >= 3 else { continue }
            let avgLen = items.map(\.count).reduce(0, +) / max(1, items.count)
            guard avgLen >= 4 else { continue } // skip "a, b, c"-style placeholders
            found.append(
                EloquenceFinding(
                    device: .tricolon,
                    snippet: snippet,
                    coachLine: EloquenceDevice.tricolon.defaultCoachLine
                )
            )
            if found.count >= 1 { break } // one tricolon per session is enough
        }
        return found
    }

    private static func detectAnaphora(sentences: [String]) -> [EloquenceFinding] {
        guard sentences.count >= 2 else { return [] }
        var found: [EloquenceFinding] = []
        var i = 0
        while i < sentences.count - 1 {
            let aWords = tokenise(sentences[i])
            let bWords = tokenise(sentences[i + 1])
            guard let aFirst = aWords.first?.lowercased(),
                  let bFirst = bWords.first?.lowercased(),
                  aFirst == bFirst,
                  aFirst.count >= 2,
                  !stopwords.contains(aFirst)
            else {
                i += 1
                continue
            }
            // Snip the two openings.
            let snippet = "\(sentences[i]) \(sentences[i + 1])"
            found.append(
                EloquenceFinding(
                    device: .anaphora,
                    snippet: snippet,
                    coachLine: EloquenceDevice.anaphora.defaultCoachLine
                )
            )
            i += 2 // skip the matched pair to avoid double-counting
        }
        return found
    }

    private static func detectEpistrophe(sentences: [String]) -> [EloquenceFinding] {
        guard sentences.count >= 2 else { return [] }
        var found: [EloquenceFinding] = []
        var i = 0
        while i < sentences.count - 1 {
            let a = tokenise(sentences[i])
            let b = tokenise(sentences[i + 1])
            guard let aLast = a.last?.lowercased(),
                  let bLast = b.last?.lowercased(),
                  aLast == bLast,
                  aLast.count >= 3,
                  !stopwords.contains(aLast)
            else {
                i += 1
                continue
            }
            let snippet = "\(sentences[i]) \(sentences[i + 1])"
            found.append(
                EloquenceFinding(
                    device: .epistrophe,
                    snippet: snippet,
                    coachLine: EloquenceDevice.epistrophe.defaultCoachLine
                )
            )
            i += 2
        }
        return found
    }

    private static func detectAlliteration(words: [String]) -> [EloquenceFinding] {
        // Look for runs of 3+ adjacent content words sharing a starting
        // sound (initial letter, ignoring case). Skip stopwords and very
        // short words to avoid trivial matches.
        var found: [EloquenceFinding] = []
        var run: [String] = []
        for word in words {
            let lower = word.lowercased()
            let trimmed = lower.trimmingCharacters(in: .punctuationCharacters)
            guard trimmed.count >= 3, !stopwords.contains(trimmed) else {
                if run.count >= 3 {
                    found.append(makeAlliterationFinding(run: run))
                }
                run = []
                continue
            }
            if let prev = run.last,
               firstLetter(prev) == firstLetter(trimmed) {
                run.append(trimmed)
            } else {
                if run.count >= 3 {
                    found.append(makeAlliterationFinding(run: run))
                }
                run = [trimmed]
            }
        }
        if run.count >= 3 {
            found.append(makeAlliterationFinding(run: run))
        }
        return found
    }

    private static func makeAlliterationFinding(run: [String]) -> EloquenceFinding {
        EloquenceFinding(
            device: .alliteration,
            snippet: run.joined(separator: " "),
            coachLine: EloquenceDevice.alliteration.defaultCoachLine
        )
    }

    private static func detectIsocolon(sentences: [String]) -> [EloquenceFinding] {
        guard sentences.count >= 2 else { return [] }
        var found: [EloquenceFinding] = []
        for i in 0..<(sentences.count - 1) {
            let a = sentences[i]
            let b = sentences[i + 1]
            let aLen = tokenise(a).count
            let bLen = tokenise(b).count
            guard aLen >= 3, bLen >= 3 else { continue }
            // Length parity within ±1 token AND first-token POS-ish similarity
            // (we're loose — match on opening-word letter category).
            guard abs(aLen - bLen) <= 1 else { continue }
            let aFirst = (tokenise(a).first ?? "").lowercased()
            let bFirst = (tokenise(b).first ?? "").lowercased()
            guard aFirst != bFirst, // pure anaphora is detected separately
                  pseudoCategory(of: aFirst) == pseudoCategory(of: bFirst),
                  pseudoCategory(of: aFirst) != .other
            else { continue }
            let snippet = "\(a) \(b)"
            found.append(
                EloquenceFinding(
                    device: .isocolon,
                    snippet: snippet,
                    coachLine: EloquenceDevice.isocolon.defaultCoachLine
                )
            )
            if found.count >= 1 { break }
        }
        return found
    }

    private static func detectAntithesis(sentences: [String]) -> [EloquenceFinding] {
        // Conservative — flag a sentence containing a known opposing-word
        // pair within 8 tokens. False positives here are expensive ("you
        // pretended to use antithesis"), so we keep the seed set small.
        var found: [EloquenceFinding] = []
        for sentence in sentences {
            let tokens = tokenise(sentence).map { $0.lowercased() }
            guard tokens.count >= 4 else { continue }
            for pair in oppositionPairs {
                guard let a = tokens.firstIndex(of: pair.0),
                      let b = tokens.firstIndex(of: pair.1) else { continue }
                if abs(a - b) <= 8 {
                    found.append(
                        EloquenceFinding(
                            device: .antithesis,
                            snippet: sentence,
                            coachLine: EloquenceDevice.antithesis.defaultCoachLine
                        )
                    )
                    break
                }
            }
            if found.count >= 1 { break }
        }
        return found
    }

    private static func detectPolysyndeton(sentences: [String]) -> [EloquenceFinding] {
        // Three or more "and"s within a single sentence is the threshold.
        for sentence in sentences {
            let tokens = tokenise(sentence).map { $0.lowercased() }
            let andCount = tokens.filter { $0 == "and" || $0 == "or" }.count
            if andCount >= 3 {
                return [
                    EloquenceFinding(
                        device: .polysyndeton,
                        snippet: sentence,
                        coachLine: EloquenceDevice.polysyndeton.defaultCoachLine
                    )
                ]
            }
        }
        return []
    }

    private static func detectAsyndeton(sentences: [String]) -> [EloquenceFinding] {
        // 3+ comma-separated items WITHOUT a final "and". Tight heuristic.
        for sentence in sentences {
            let parts = sentence.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 3 else { continue }
            // Last item shouldn't begin with "and" / "or".
            let last = parts.last!.lowercased()
            if !last.hasPrefix("and ") && !last.hasPrefix("or "),
               !sentence.lowercased().contains(" and ") {
                return [
                    EloquenceFinding(
                        device: .asyndeton,
                        snippet: sentence,
                        coachLine: EloquenceDevice.asyndeton.defaultCoachLine
                    )
                ]
            }
        }
        return []
    }

    private static func detectDiacope(sentences: [String]) -> [EloquenceFinding] {
        // word X word — same word repeated with 1–4 tokens between.
        // Operates per sentence so "Bond" → "Bond" doesn't match across a
        // full stop. Minimum 3 tokens per sentence (a, X, a).
        for sentence in sentences {
            let tokens = tokenise(sentence)
            guard tokens.count >= 3 else { continue }
            for i in 0..<(tokens.count - 2) {
                let maxGap = min(4, tokens.count - i - 2)
                guard maxGap >= 1 else { continue }
                for gap in 1...maxGap {
                    let aIdx = i
                    let bIdx = i + 1 + gap
                    if bIdx >= tokens.count { continue }
                    let a = tokens[aIdx].lowercased()
                    let b = tokens[bIdx].lowercased()
                    guard a == b, a.count >= 3, !stopwords.contains(a) else { continue }
                    let snippet = tokens[aIdx...bIdx].joined(separator: " ")
                    return [
                        EloquenceFinding(
                            device: .diacope,
                            snippet: snippet,
                            coachLine: EloquenceDevice.diacope.defaultCoachLine
                        )
                    ]
                }
            }
        }
        return []
    }

    private static func detectEpizeuxis(words: [String]) -> [EloquenceFinding] {
        // word, word — same word back-to-back. "Never, never, never give in."
        for i in 0..<(words.count - 1) {
            let a = words[i].lowercased().trimmingCharacters(in: .punctuationCharacters)
            let b = words[i + 1].lowercased().trimmingCharacters(in: .punctuationCharacters)
            guard a == b, a.count >= 3, !stopwords.contains(a) else { continue }
            return [
                EloquenceFinding(
                    device: .epizeuxis,
                    snippet: "\(words[i]) \(words[i + 1])",
                    coachLine: EloquenceDevice.epizeuxis.defaultCoachLine
                )
            ]
        }
        return []
    }

    private static func detectRhetoricalQuestion(sentences: [String]) -> [EloquenceFinding] {
        for sentence in sentences {
            guard sentence.hasSuffix("?") else { continue }
            // Skip true Q&A questions to interlocutors — heuristic: "you" within
            // first 3 tokens probably means "asking you". We're after the
            // self-answering kind ("How did we get here?", "What does that mean?").
            let tokens = tokenise(sentence).prefix(3).map { $0.lowercased() }
            if tokens.contains("you") { continue }
            return [
                EloquenceFinding(
                    device: .rhetoricalQuestion,
                    snippet: sentence,
                    coachLine: EloquenceDevice.rhetoricalQuestion.defaultCoachLine
                )
            ]
        }
        return []
    }

    // MARK: - Helpers

    /// Sort findings by impact: stronger devices first, then alliteration,
    /// then everything else. De-duplicates by device so the summary doesn't
    /// list the same device twice.
    private static func prioritised(_ findings: [EloquenceFinding]) -> [EloquenceFinding] {
        var seen: Set<EloquenceDevice> = []
        var out: [EloquenceFinding] = []
        let order: [EloquenceDevice] = [
            .tricolon, .anaphora, .epistrophe, .antithesis, .isocolon,
            .diacope, .epizeuxis, .rhetoricalQuestion,
            .polysyndeton, .asyndeton, .alliteration
        ]
        for device in order {
            if let f = findings.first(where: { $0.device == device }), !seen.contains(device) {
                out.append(f)
                seen.insert(device)
            }
        }
        return out
    }

    // MARK: - Tokenisation

    private static func tokenise(_ text: String) -> [String] {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    private static func splitIntoSentences(_ text: String) -> [String] {
        // Light sentence splitter: split on .?! followed by whitespace.
        // Filler-laden transcripts may not have punctuation; we fall back to
        // newlines + comma-pair grouping for those.
        var sentences: [String] = []
        let scalars = Array(text)
        var current = ""
        var i = 0
        while i < scalars.count {
            let ch = scalars[i]
            current.append(ch)
            if ".!?".contains(ch) {
                let next = i + 1 < scalars.count ? scalars[i + 1] : " "
                if next.isWhitespace || i + 1 == scalars.count {
                    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        sentences.append(trimmed)
                    }
                    current = ""
                }
            }
            i += 1
        }
        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            sentences.append(trailing)
        }
        return sentences
    }

    private static func firstLetter(_ word: String) -> Character? {
        word.first(where: { $0.isLetter })
    }

    /// Stopwords — common function words that we exclude from openings/endings
    /// when looking for rhetorical patterns.
    private static let stopwords: Set<String> = [
        "the", "a", "an", "and", "but", "or", "so", "of", "in", "on", "at",
        "to", "for", "is", "are", "was", "were", "i", "we", "you", "he", "she",
        "they", "it", "this", "that", "these", "those", "with", "as", "by",
        "from", "be", "been", "have", "has", "had", "do", "does", "did", "if",
        "then", "than", "no", "not", "yes", "ok", "um", "uh", "er", "erm", "like"
    ]

    /// Tiny seed of opposition pairs for antithesis. Conservative on purpose.
    private static let oppositionPairs: [(String, String)] = [
        ("good", "bad"), ("right", "wrong"), ("yes", "no"), ("start", "finish"),
        ("start", "end"), ("up", "down"), ("first", "last"), ("more", "less"),
        ("big", "small"), ("strong", "weak"), ("win", "lose"), ("won", "lost"),
        ("known", "unknown"), ("simple", "complex"), ("light", "dark"),
        ("speak", "silent"), ("loud", "quiet"), ("question", "answer"),
        ("ask", "tell"), ("listen", "speak"), ("yes", "but"), ("not", "but"),
        ("ours", "theirs"), ("us", "them"), ("near", "far"), ("with", "without")
    ]

    /// Coarse "category" of a word from its opening — used to detect
    /// pseudo-parallel structure without a real POS tagger.
    private enum PseudoCategory: Equatable { case article, modal, pronoun, verb, other }
    private static func pseudoCategory(of word: String) -> PseudoCategory {
        switch word {
        case "the", "a", "an": return .article
        case "can", "will", "would", "could", "should", "must", "may", "might": return .modal
        case "i", "we", "you", "they", "he", "she", "it": return .pronoun
        case "do", "is", "are", "was", "were", "have", "has", "had", "be": return .verb
        default: return .other
        }
    }

    // MARK: - Regex (cached at module load)

    /// Detects "A, B, and C" or "A, B, C" patterns. Captures the whole list.
    /// Items are 2–24 chars to avoid runaway matches on very long clauses.
    private static let tricolonRegex: NSRegularExpression = {
        let pattern = #"\b[\w'\- ]{2,24},\s+[\w'\- ]{2,24},\s+(?:and\s+)?[\w'\- ]{2,24}\b"#
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()
}
