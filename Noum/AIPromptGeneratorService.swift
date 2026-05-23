import Foundation

// MARK: - AI Prompt Generator (M7)
//
// Generates a single, on-voice impromptu speaking prompt biased by the
// user's coaching goal and weakest baseline dimension. Same provider
// plumbing as `GoalParaphraseService` and `AIInsightsService` (Gemini /
// OpenAI / DeepSeek via `AISettingsManager.activeProvider`).
//
// One-shot, best-effort. Returns nil on:
//   - No provider configured
//   - Network failure / non-2xx
//   - Empty model response
//   - Content filter rejection (length, leading second-person directive,
//     no terminal "?", PII heuristic)
// Callers fall back to the curated 200-prompt pool. Never blocks.
//
// Not metered against the AI Coach budget — prompt generation is
// session-startup latency, not coaching feedback.

actor AIPromptGeneratorService {
    static let shared = AIPromptGeneratorService()

    private init() {}

    /// Generate one prompt, biased by the user's profile and weakest baseline
    /// dimension. Returns nil if no provider is configured, the call fails,
    /// or the model output fails the content filter.
    ///
    /// `weakestDimension` should be a short label like "filler control" or
    /// "structured opening" — the model uses it to make the prompt actually
    /// challenge the thing the user needs to practice.
    ///
    /// `recentPromptTexts` (newest first) is shown to the model with an
    /// instruction to avoid near-clones. Pool dedup already covers exact
    /// repeats; this only matters for the AI path so it doesn't generate
    /// a paraphrase of last week's prompt. Defaults to empty for callers
    /// that don't have prompt history available.
    func generate(
        profile: CoachingProfile,
        weakestDimension: String?,
        recentPromptTexts: [String] = []
    ) async -> String? {
        // M13: skip AI generation when the user is practising in a locale
        // we haven't localised AI prompts for. Falling back to the curated
        // pool is honest; an English prompt mid-Spanish session is not.
        guard await activeLocaleSupportsAI() else { return nil }
        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider) else {
            return nil
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12

        let prompt = userPrompt(
            profile: profile,
            weakestDimension: weakestDimension,
            recentPromptTexts: recentPromptTexts
        )

        do {
            switch provider {
            case .none:
                return nil
            case .openAI, .deepSeek:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                let body: [String: Any] = [
                    "model": provider.model,
                    "temperature": 0.9,  // higher than paraphrase — we want variety
                    "messages": [
                        ["role": "system", "content": Self.systemPrompt],
                        ["role": "user", "content": prompt]
                    ]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            case .gemini:
                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
                let body: [String: Any] = [
                    "systemInstruction": ["parts": [["text": Self.systemPrompt]]],
                    "contents": [["parts": [["text": prompt]]]],
                    "generationConfig": ["temperature": 0.9]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard let raw = decodeText(from: data, provider: provider) else { return nil }
            return PromptContentFilter.accept(raw)
        } catch {
            return nil
        }
    }

    // MARK: - Provider plumbing (mirrors GoalParaphraseService)

    @MainActor
    private func currentProvider() -> AIProvider? {
        AISettingsManager.shared.activeProvider
    }

    /// True when the active practice locale has AI surfaces enabled.
    /// Reads `LocaleSettingsManager.shared.current.aiSupported`.
    @MainActor
    private func activeLocaleSupportsAI() -> Bool {
        LocaleSettingsManager.shared.current.aiSupported
    }

    private func apiKey(for provider: AIProvider) -> String? {
        guard let keyName = provider.environmentKey else { return nil }
        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")
    }

    // MARK: - Prompts

    private static let systemPrompt = """
    You are writing a practice prompt for someone training a specific \
    speaking voice and working on a specific weakness — surfaced in the \
    user message as voice + weakest dimension. The user will speak for \
    30–60 seconds answering your prompt. Output ONLY the prompt — no \
    preface, no quotes, no JSON, no enumeration. Single sentence ending \
    with a question mark. 8–22 words. Concrete, answerable, \
    opinion-inviting. Avoid: corporate jargon, marketing tone, politics, \
    religion, identity targeting, anything requiring specialised \
    knowledge. No second-person directives ("Tell me about…", \
    "Describe…"). Frame as a question the user is asked, e.g. "What is \
    the most overrated skill in your industry?" or "When should a leader \
    admit they don't have an answer?". \
    Match the user's voice register. A user training authoritative gets \
    a verdict-shaped question; warm gets a felt-experience question; \
    concise gets a clipped question; persuasive gets a premise-evidence \
    question; executive gets a top-line question; storytelling gets a \
    scene-shaped question. Same shape, different register. \
    When recent prompts are listed, avoid near-clones — pick a different \
    angle, subject, or framing rather than paraphrasing.
    """

    private func userPrompt(
        profile: CoachingProfile,
        weakestDimension: String?,
        recentPromptTexts: [String]
    ) -> String {
        Self.buildUserPrompt(
            profile: profile,
            weakestDimension: weakestDimension,
            recentPromptTexts: recentPromptTexts
        )
    }

    /// Deterministic prompt-body builder. Pulled out as `static` so tests
    /// can exercise the shape without standing up a provider or a network
    /// stub — see `AIPromptGeneratorSeedTests` in NoumTests.
    static func buildUserPrompt(
        profile: CoachingProfile,
        weakestDimension: String?,
        recentPromptTexts: [String]
    ) -> String {
        var lines: [String] = []
        // Lead with the voice + weakness frame — the system prompt
        // references this directly ("training [voice], currently
        // weakest at [dimension]").
        let voice = profile.speakingStyleGoal.title.lowercased()
        let weakLabel = (weakestDimension?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        if let weak = weakLabel {
            lines.append("You are writing a practice prompt for someone training \(voice), currently weakest at \(weak.lowercased()).")
        } else {
            lines.append("You are writing a practice prompt for someone training \(voice).")
        }
        lines.append("")
        lines.append("Goal: \(profile.primaryGoal.title)")
        lines.append("Style aim: \(profile.speakingStyleGoal.title)")
        lines.append("Speaking context: \(profile.speakingContext.title)")
        lines.append("Biggest challenge: \(profile.biggestChallenge.title)")
        if let w = weakestDimension, !w.isEmpty {
            lines.append("Weakest dimension to challenge: \(w)")
        }
        let cleanedRecents = recentPromptTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !cleanedRecents.isEmpty {
            lines.append("")
            lines.append("Recent prompts the user has already seen — avoid near-clones:")
            for text in cleanedRecents {
                lines.append("- \(text)")
            }
        }
        return lines.joined(separator: "\n") + "\n\nReturn one prompt."
    }

    /// Exposed for tests so they can assert the system-prompt clause.
    static var systemPromptForTesting: String { systemPrompt }

    // MARK: - Response decoding (mirrors GoalParaphraseService)

    private func decodeText(from data: Data, provider: AIProvider) -> String? {
        switch provider {
        case .none: return nil
        case .openAI, .deepSeek:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = object["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return nil }
            return content
        case .gemini:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = object["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            else { return nil }
            return parts.compactMap { $0["text"] as? String }.joined(separator: " ")
        }
    }
}

// MARK: - Content Filter

/// Rejects model output that wouldn't make a good speaking prompt:
///   - too short or too long
///   - missing the terminal "?"
///   - leading directive ("Describe…", "Tell me about…")
///   - obvious PII shape (looks like an email or phone number)
///   - off-voice marketing tone (multiple exclamation marks)
///
/// Filter logic is deterministic and easily tested in isolation —
/// see `AIPromptContentFilterTests` in NoumTests.
enum PromptContentFilter {
    /// Accepted prompt range in characters (after trimming).
    static let minLength = 20
    static let maxLength = 220

    /// Returns the cleaned prompt if it passes, otherwise nil.
    static func accept(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip enclosing quotes if the model wrapped its output in them.
        if (text.hasPrefix("\"") && text.hasSuffix("\"")) ||
           (text.hasPrefix("\u{201C}") && text.hasSuffix("\u{201D}")) {
            if text.count >= 2 {
                text = String(text.dropFirst().dropLast())
            }
        }

        // Collapse internal whitespace.
        text = text.replacingOccurrences(of: "\n", with: " ")
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Length bounds — short prompts aren't speakable, long ones are bloat.
        guard (minLength...maxLength).contains(text.count) else { return nil }

        // Must end with a question mark to actually invite a spoken answer.
        guard text.hasSuffix("?") else { return nil }

        // Reject leading directives — we want questions, not commands.
        let lowered = text.lowercased()
        let directivePrefixes = [
            "tell me ", "describe ", "talk about ", "explain ",
            "discuss ", "elaborate on ", "share with me ", "share a "
        ]
        if directivePrefixes.contains(where: { lowered.hasPrefix($0) }) {
            return nil
        }

        // PII heuristics — bail on anything resembling an email or phone.
        if text.range(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, options: .regularExpression) != nil {
            return nil
        }
        if text.range(of: #"\+?\d[\d\s\-().]{7,}"#, options: .regularExpression) != nil {
            return nil
        }

        // Off-voice tone — chained exclamations don't fit the brand voice.
        if text.contains("!!") { return nil }

        return text
    }
}
