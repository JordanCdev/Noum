import Foundation

// MARK: - Pressure Follow-Up Service

enum PressureFollowUpContract {
    static func localeSupportsAI(_ locale: PracticeLocale) -> Bool {
        locale.aiSupported
    }

    static func normalized(_ followUp: String, transcript: String) -> String? {
        let candidate = followUp
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty,
              !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              passesToneContract(candidate) else {
            return nil
        }

        let words = candidate.split(whereSeparator: \.isWhitespace)
        guard words.count >= 4 else { return nil }
        let bounded = words.prefix(15).joined(separator: " ")
        guard engagesTranscript(bounded, transcript: transcript) else { return nil }
        return bounded
    }

    private static func passesToneContract(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        guard !value.contains("!"),
              !lowercased.contains("stupid"),
              !lowercased.contains("idiot"),
              !lowercased.contains("ridiculous"),
              !lowercased.contains("nonsense"),
              !lowercased.contains("bad answer"),
              !lowercased.contains("wrong again"),
              !lowercased.contains("as an ai") else {
            return false
        }
        return true
    }

    private static func engagesTranscript(_ followUp: String, transcript: String) -> Bool {
        let lowerTranscript = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let lowerFollowUp = followUp.lowercased()

        let transcriptWords = Set(contentWords(in: lowerTranscript))
        let followUpWords = contentWords(in: lowerFollowUp)
        if followUpWords.contains(where: { transcriptWords.contains($0) }) {
            return true
        }

        let window = 12
        let chars = Array(lowerTranscript)
        guard chars.count >= window else { return false }
        for start in 0...(chars.count - window) {
            let slice = String(chars[start..<(start + window)])
            if lowerFollowUp.contains(slice) {
                return true
            }
        }
        return false
    }

    private static func contentWords(in text: String) -> [String] {
        text
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 4 && !groundingStopWords.contains($0) }
    }

    private static let groundingStopWords: Set<String> = [
        "about", "actual", "after", "again", "apply", "because", "being",
        "break", "care", "challenge", "clarify", "could", "defend",
        "differently", "disagrees", "does", "down", "elaborate", "example",
        "explain", "follow", "give", "going", "happened", "important",
        "interesting", "just", "matter", "mean", "more", "most", "next",
        "part", "practice", "prompt", "reasoning", "said", "short", "should",
        "someone", "speaker", "specific", "takeaway", "that", "their",
        "there", "they", "think", "thinking", "through", "version", "walk",
        "what", "when", "where", "which", "with", "would", "your"
    ]
}

/// Generates intelligent NPC follow-up messages for Sudden Death pressure mode
/// by calling the same Gemini API used by IM Mode.
///
/// Falls back to template-based follow-ups when AI is unavailable.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class PressureFollowUpService: PressureFollowUpProviding {
    static let shared = PressureFollowUpService()
    private init() {}

    private let settings = AISettingsManager.shared

    // MARK: - PressureFollowUpProviding

    func generateFollowUp(
        userTranscript: String,
        previousPrompt: String,
        round: Int,
        profile: CoachingProfile?
    ) async -> String {
        func record(
            _ outcome: AICallDiagnosticOutcome,
            _ reason: String,
            provider: AIProvider? = nil,
            startedAt: Date? = nil
        ) {
            AICallDiagnostics.record(
                surface: "Pressure follow-up",
                provider: provider,
                outcome: outcome,
                reason: reason,
                startedAt: startedAt
            )
        }

        guard PressureFollowUpContract.localeSupportsAI(LocaleSettingsManager.shared.current) else {
            print("[PressureFollowUp] Locale does not support AI follow-ups, using template")
            record(.skipped, "Locale not AI-supported")
            return PressureFollowUpTemplates.random()
        }

        // Guard: need an AI provider
        let configuredProvider = settings.activeProvider
        guard let provider = configuredProvider,
              let apiKey = resolveAPIKey(for: provider),
              let endpoint = provider.endpoint else {
            print("[PressureFollowUp] No AI provider available, using template")
            record(.skipped, configuredProvider == nil ? "No active provider" : "Missing key or endpoint", provider: configuredProvider)
            return PressureFollowUpTemplates.random()
        }

        let startedAt = Date()
        do {
            let followUp = try await callGemini(
                provider: provider,
                apiKey: apiKey,
                endpoint: endpoint,
                userTranscript: userTranscript,
                previousPrompt: previousPrompt,
                round: round,
                profile: profile
            )
            guard let normalized = PressureFollowUpContract.normalized(
                followUp,
                transcript: userTranscript
            ) else {
                print("[PressureFollowUp] AI follow-up was ungrounded, using template")
                record(.fallback, "Follow-up failed grounding gate", provider: provider, startedAt: startedAt)
                return PressureFollowUpTemplates.random()
            }
            record(.success, "Follow-up accepted", provider: provider, startedAt: startedAt)
            return normalized
        } catch {
            print("[PressureFollowUp] Gemini call failed: \(error.localizedDescription), using template")
            record(.failure, "Transport or decode error", provider: provider, startedAt: startedAt)
            return PressureFollowUpTemplates.random()
        }
    }

    // MARK: - Gemini Call

    private func callGemini(
        provider: AIProvider,
        apiKey: String,
        endpoint: URL,
        userTranscript: String,
        previousPrompt: String,
        round: Int,
        profile: CoachingProfile?
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8 // Fast timeout — this must not block the game feel

        let systemPrompt = buildSystemPrompt(round: round, profile: profile)
        let userPrompt = buildUserPrompt(
            userTranscript: userTranscript,
            previousPrompt: previousPrompt,
            round: round
        )

        switch provider {
        case .gemini:
            request.setGoogleAPIKey(apiKey)
            let body = GeminiRequest(
                systemInstruction: .init(parts: [.init(text: systemPrompt)]),
                contents: [.init(role: "user", parts: [.init(text: userPrompt)])],
                generationConfig: .init(temperature: 0.8, responseMimeType: "application/json")
            )
            request.httpBody = try JSONEncoder().encode(body)

        case .openAI:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let body: [String: Any] = [
                "model": provider.model,
                "temperature": 0.8,
                "max_tokens": 60,
                "response_format": ["type": "json_object"],
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userPrompt]
                ]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

        default:
            throw FollowUpError.unsupportedProvider
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw FollowUpError.httpError
        }

        return try extractMessage(from: data, provider: provider)
    }

    // MARK: - Prompt Construction

    private func buildSystemPrompt(round: Int, profile: CoachingProfile?) -> String {
        var prompt = """
        You are an NPC in a speaking pressure drill. Your job is to fire back a short, \
        pointed follow-up that forces the speaker to think fast and respond immediately.

        Rules:
        - Reply with JSON only: { "followUp": "your message" }
        - Your follow-up must be 5 to 15 words
        - Be direct, specific, and conversational — like a sharp interviewer or debater
        - Reference what the speaker actually said — don't ask generic questions
        - Challenge their reasoning, ask for specifics, or push them to go deeper
        - Never be mean, sarcastic, or insulting — be firm but fair
        - Never break character or mention being AI
        - One question or challenge per message
        """

        if round >= 5 {
            prompt += "\n- This is round \(round). Be more pointed. Shorter. Faster. Maximum pressure."
        }

        if let profile {
            let focus = profile.primaryGoal.title.lowercased()
            prompt += "\n- The speaker's training focus is: \(focus). Probe that area."
        }

        return prompt
    }

    private func buildUserPrompt(userTranscript: String, previousPrompt: String, round: Int) -> String {
        """
        The previous prompt was: "\(previousPrompt)"

        The speaker said: "\(userTranscript)"

        Generate a follow-up that pushes them to elaborate, defend, or clarify what they just said. \
        Be specific to their actual words. Round \(round) of an ongoing pressure drill.
        """
    }

    // MARK: - Response Parsing

    private func extractMessage(from data: Data, provider: AIProvider) throws -> String {
        let jsonData: Data

        switch provider {
        case .gemini:
            let completion = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let text = completion.candidates.first?.content.parts.compactMap(\.text).joined(),
                  !text.isEmpty else {
                throw FollowUpError.emptyResponse
            }
            guard let textData = normalizedJSONData(from: text) else {
                throw FollowUpError.invalidJSON
            }
            jsonData = textData

        case .openAI:
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = object["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String,
                  let contentData = content.data(using: .utf8) else {
                throw FollowUpError.invalidJSON
            }
            jsonData = contentData

        default:
            throw FollowUpError.unsupportedProvider
        }

        guard let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let followUp = parsed["followUp"] as? String,
              !followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FollowUpError.emptyResponse
        }

        return followUp
    }

    /// Handle markdown code fences and whitespace in JSON responses.
    private func normalizedJSONData(from text: String) -> Data? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip markdown code fences
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.data(using: .utf8)
    }

    // MARK: - API Key Resolution

    private func resolveAPIKey(for provider: AIProvider) -> String? {
        AIProviderCredential.apiKey(for: provider)
    }

    // MARK: - Gemini Request/Response Structs (mirrored from IM service)

    private struct GeminiRequest: Codable {
        struct Content: Codable {
            let role: String?
            let parts: [Part]

            init(role: String? = nil, parts: [Part]) {
                self.role = role
                self.parts = parts
            }
        }
        struct Part: Codable {
            let text: String
        }
        struct GenerationConfig: Codable {
            struct ThinkingConfig: Codable {
                let thinkingBudget: Int
            }

            let temperature: Double
            let responseMimeType: String
            let thinkingConfig: ThinkingConfig?

            init(
                temperature: Double,
                responseMimeType: String,
                thinkingConfig: ThinkingConfig? = .init(thinkingBudget: 0)
            ) {
                self.temperature = temperature
                self.responseMimeType = responseMimeType
                self.thinkingConfig = thinkingConfig
            }
        }

        let systemInstruction: Content
        let contents: [Content]
        let generationConfig: GenerationConfig

        enum CodingKeys: String, CodingKey {
            case systemInstruction = "system_instruction"
            case contents
            case generationConfig
        }
    }

    private struct GeminiResponse: Codable {
        struct Candidate: Codable {
            struct Content: Codable {
                struct Part: Codable {
                    let text: String?
                }
                let parts: [Part]
            }
            let content: Content
        }
        let candidates: [Candidate]
    }

    // MARK: - Errors

    private enum FollowUpError: Error {
        case unsupportedProvider
        case httpError
        case emptyResponse
        case invalidJSON
    }
}
