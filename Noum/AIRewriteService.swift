import Foundation

// MARK: - AI Rewrite Service (Pro)
//
// Takes the user's actual transcript + the specific weakness category +
// observable signals about their voice (sentence length, vocabulary
// shape, contraction usage), and returns a rewritten version of the
// **weak section only** — preserving the rest of the user's voice.
//
// The defining design constraint, per direct user feedback during M14
// real-device QA: "don't want them to learn how to speak like
// chatgpt/AI right, THIS IS VERY IMPORTANT."
//
// What that means in practice for the prompt:
//   • Re-use the user's vocabulary set wherever possible. If they said
//     "kind of" three times, the rewrite is allowed to say "kind of" too.
//     If they didn't say "leverage", the rewrite must not say "leverage".
//   • Match their sentence rhythm. Average sentence length stays close
//     to theirs; we don't turn a clipped speaker into a flowing one.
//   • Keep contractions if they used contractions ("I'm", "don't").
//   • Don't add corporate jargon the user didn't use ("strategic",
//     "leverage", "synergize", "value-add", "stakeholder", "ecosystem").
//   • Output is ONE replacement sentence/clause for the targeted weak
//     section — not a rewrite of the whole rep.
//
// Same provider plumbing as GoalParaphraseService / AIPromptGeneratorService:
// reads `AISettingsManager.activeProvider`, falls back silently when
// no provider is configured.
//
// Pro gating happens at the call site, not in this service — keeps the
// service reusable for future surfaces.

actor AIRewriteService {
    static let shared = AIRewriteService()

    private init() {}

    enum Weakness: String, Sendable {
        case opening
        case closing
        case structure
        case concise

        var humanLabel: String {
            switch self {
            case .opening:   return "opening"
            case .closing:   return "closing"
            case .structure: return "structure"
            case .concise:   return "tightening"
            }
        }

        /// Specific instruction the model gets about what to fix.
        var fixInstruction: String {
            switch self {
            case .opening:
                return "Rewrite ONLY the user's opening (first 1-2 sentences). The rest of the rep stays untouched. Make the opening declarative — replace tentative starts ('I think maybe', 'so basically') with a confident first sentence that uses the user's own words and arrives at the point in 8-12 words."
            case .closing:
                return "Rewrite ONLY the user's closing (last 1-2 sentences). The rest stays untouched. Make the close land — replace trail-off endings ('and yeah', 'so that's it') with a deliberate final sentence in 8-12 words. The close should restate the point, not introduce new ideas."
            case .structure:
                return "Rewrite the rep with light structural anchors — add one transition phrase the user didn't use originally (e.g., 'the second thing', 'here's why'), without otherwise changing their words. Preserve their exact sentences; insert at most one short connective."
            case .concise:
                return "Cut the rep down by 30-40% by removing redundant phrasing the user repeated, hedging language ('kind of', 'sort of', 'just'), and filler words. Keep every original idea. Use only words the user actually said."
            }
        }
    }

    // MARK: - Public API

    /// Generate a rewritten version of the targeted weak section.
    /// Returns nil if no provider is configured, the call fails, the
    /// content filter rejects the output, or the rewrite drifts too
    /// far from the user's original voice.
    func rewrite(
        transcript: String,
        weakness: Weakness
    ) async -> Rewrite? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 40 else { return nil }
        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider) else {
            return nil
        }

        let signals = VoiceSignals.compute(transcript: trimmed)
        let userPrompt = buildUserPrompt(transcript: trimmed, weakness: weakness, signals: signals)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12

        do {
            switch provider {
            case .none:
                return nil
            case .openAI, .deepSeek:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                let body: [String: Any] = [
                    "model": provider.model,
                    "temperature": 0.5,  // lower than prompt-gen — we want fidelity, not creativity
                    "messages": [
                        ["role": "system", "content": Self.systemPrompt(for: weakness)],
                        ["role": "user", "content": userPrompt]
                    ]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            case .gemini:
                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
                let body: [String: Any] = [
                    "systemInstruction": ["parts": [["text": Self.systemPrompt(for: weakness)]]],
                    "contents": [["parts": [["text": userPrompt]]]],
                    "generationConfig": ["temperature": 0.5]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard let raw = decodeText(from: data, provider: provider) else { return nil }
            guard let cleaned = RewriteContentFilter.accept(raw, signals: signals) else { return nil }
            return Rewrite(text: cleaned, weakness: weakness)
        } catch {
            return nil
        }
    }

    // MARK: - Prompts

    private static func systemPrompt(for weakness: Weakness) -> String {
        """
        You are a speaking coach who rewrites a small slice of a user's transcript to fix a specific weakness — without making them sound like a different person. The user's existing voice is the asset; you protect it.

        Hard rules:
        1. Use the user's own words. Pull from the vocabulary the user actually used in their transcript. Do not introduce jargon, buzzwords, or corporate phrasing the user did not use ("leverage", "ecosystem", "stakeholder", "value-add", "strategic", "synergy", "actionable", "disrupt", "robust", "scalable").
        2. Match their cadence. Stay within ±25% of the user's average sentence length. If they speak in short sentences, you write short sentences.
        3. Match their formality. If they use contractions, you use contractions. If they use casual fillers like "kind of", you can keep them where they actually help.
        4. Fix only the targeted slice. Do not rewrite the whole rep. Do not generalise the topic. Stay on the exact subject the user was talking about.
        5. \(weakness.fixInstruction)
        6. Output ONLY the rewritten slice. No preface, no explanation, no quotes. Plain text. 8-26 words maximum.
        """
    }

    private func buildUserPrompt(transcript: String, weakness: Weakness, signals: VoiceSignals) -> String {
        var lines: [String] = []
        lines.append("Original transcript:")
        lines.append("---")
        lines.append(transcript)
        lines.append("---")
        lines.append("")
        lines.append("Voice signals (preserve these):")
        lines.append("- Avg sentence length: \(signals.avgSentenceLength) words")
        lines.append("- Uses contractions: \(signals.usesContractions ? "yes" : "no")")
        lines.append("- Uses hedging ('kind of', 'sort of'): \(signals.usesHedging ? "yes" : "no")")
        lines.append("- First-person heavy: \(signals.firstPersonHeavy ? "yes" : "no")")
        if !signals.distinctiveWords.isEmpty {
            lines.append("- Words they actually used to convey the point: \(signals.distinctiveWords.joined(separator: ", "))")
        }
        lines.append("")
        lines.append("Now rewrite the \(weakness.humanLabel) only. Plain text. No preface.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Provider plumbing (same pattern as GoalParaphraseService)

    @MainActor
    private func currentProvider() -> AIProvider? {
        AISettingsManager.shared.activeProvider
    }

    private func apiKey(for provider: AIProvider) -> String? {
        guard let keyName = provider.environmentKey else { return nil }
        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")
    }

    private func decodeText(from data: Data, provider: AIProvider) -> String? {
        switch provider {
        case .none: return nil
        case .openAI, .deepSeek:
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = object["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else { return nil }
            return content
        case .gemini:
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = object["candidates"] as? [[String: Any]],
                  let first = candidates.first,
                  let content = first["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else { return nil }
            return parts.compactMap { $0["text"] as? String }.joined(separator: " ")
        }
    }
}

// MARK: - Output type

struct Rewrite: Sendable, Equatable {
    let text: String
    let weakness: AIRewriteService.Weakness
}

// MARK: - Voice signals

/// Observable signals about how the user actually speaks, derived from
/// their transcript. Fed to the rewrite prompt so the model anchors on
/// the user's voice instead of regressing to an LLM "default voice."
struct VoiceSignals: Sendable {
    let avgSentenceLength: Int
    let usesContractions: Bool
    let usesHedging: Bool
    let firstPersonHeavy: Bool
    let distinctiveWords: [String]

    static let empty = VoiceSignals(
        avgSentenceLength: 0,
        usesContractions: false,
        usesHedging: false,
        firstPersonHeavy: false,
        distinctiveWords: []
    )

    static func compute(transcript: String) -> VoiceSignals {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        // Sentences split on terminal punctuation.
        let sentences = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Words split on whitespace + punctuation that isn't an apostrophe.
        let words = trimmed
            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .map { String($0).lowercased() }

        let avgLen: Int = {
            guard !sentences.isEmpty else { return words.count }
            let lengths = sentences.map { $0.split(whereSeparator: { !$0.isLetter && $0 != "'" }).count }
            return max(1, lengths.reduce(0, +) / lengths.count)
        }()

        let contractionMarkers: Set<String> = ["i'm", "don't", "can't", "won't", "it's", "you're", "they're", "we're", "i've", "i'll", "that's", "there's", "what's", "didn't", "isn't", "wasn't", "haven't"]
        let usesContractions = words.contains(where: { contractionMarkers.contains($0) })

        let hedgingPhrases = ["kind", "sort", "maybe", "probably", "i guess", "i think"]
        let usesHedging = hedgingPhrases.contains(where: { trimmed.lowercased().contains($0) })

        let firstPersonCount = words.filter { $0 == "i" || $0 == "me" || $0 == "my" || $0 == "i'm" || $0 == "i've" || $0 == "i'll" }.count
        let firstPersonHeavy = words.count >= 20 && (Double(firstPersonCount) / Double(words.count)) >= 0.06

        // Pull out content words (≥6 chars, non-stop) that the user
        // actually used. The model uses these as a vocabulary anchor.
        let stopWords: Set<String> = ["because", "really", "actually", "everything", "something", "nothing", "anything", "people", "though", "before", "always", "around", "between", "without", "another"]
        let distinctiveSorted: [String] = Array(Set(words.filter { $0.count >= 6 && !stopWords.contains($0) })).sorted()
        let distinctive: [String] = Array(distinctiveSorted.prefix(8))

        return VoiceSignals(
            avgSentenceLength: avgLen,
            usesContractions: usesContractions,
            usesHedging: usesHedging,
            firstPersonHeavy: firstPersonHeavy,
            distinctiveWords: distinctive
        )
    }
}

// MARK: - Content Filter

/// Rejects model output that drifts from the user's voice or produces
/// off-brand text. Fully deterministic — testable without hitting the
/// network.
enum RewriteContentFilter {
    /// List of corporate / AI-default words that signal the model
    /// regressed to its house style. If the rewrite contains any of
    /// these AND the user didn't, we reject the output. The user's
    /// quote: "don't want them to learn how to speak like chatgpt/AI".
    static let aiTellWords: Set<String> = [
        "leverage", "leveraging", "ecosystem", "stakeholder", "stakeholders",
        "value-add", "value add", "strategic", "synergy", "synergize",
        "actionable", "actionables", "disrupt", "disruptive", "robust",
        "scalable", "innovate", "innovative", "paradigm", "holistic",
        "synergistic", "deliverables", "bandwidth", "circle back",
        "deep dive", "double click", "north star", "best-in-class",
        "world-class", "moving forward", "going forward", "at the end of the day"
    ]

    /// Min/max characters for an acceptable rewrite slice.
    static let minLength = 18
    static let maxLength = 220

    /// Returns the cleaned rewrite if it passes all filters. nil otherwise.
    static func accept(_ raw: String, signals: VoiceSignals) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip enclosing quotes / smart quotes.
        if (text.hasPrefix("\"") && text.hasSuffix("\"")) ||
           (text.hasPrefix("\u{201C}") && text.hasSuffix("\u{201D}")) {
            if text.count >= 2 { text = String(text.dropFirst().dropLast()) }
        }

        // Collapse whitespace.
        text = text.replacingOccurrences(of: "\n", with: " ")
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard (minLength...maxLength).contains(text.count) else { return nil }

        // AI-tell check: if the rewrite contains corporate jargon AND the
        // user didn't, reject.
        let lowered = text.lowercased()
        for tell in aiTellWords where lowered.contains(tell) {
            // OK to keep if the user actually said it themselves.
            if !signals.distinctiveWords.contains(tell) {
                return nil
            }
        }

        // If the user uses contractions and the model dropped them, the
        // rewrite reads more formal than them. Reject.
        if signals.usesContractions {
            let hasAnyContraction = lowered.contains("'")
            if !hasAnyContraction { return nil }
        }

        return text
    }
}
