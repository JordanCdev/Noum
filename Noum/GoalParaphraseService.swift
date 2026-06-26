import Foundation

/// Single-shot paraphrase of a user's onboarding goal text into one short,
/// on-voice sentence safe to surface in UI and lock-screen notifications.
///
/// Called once at goal capture from `CoachingProfileStore.save(_:)`. Result
/// stored as `CoachingProfile.paraphrasedGoal`. Best-effort: silent on every
/// failure path — `displayableGoal` falls back to a deterministic template.
///
/// This is not part of the IM or coaching-feedback budget. It runs once per
/// profile capture and is not metered.
actor GoalParaphraseService {
    static let shared = GoalParaphraseService()

    private init() {}

    func paraphrase(profile: CoachingProfile) async -> String? {
        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider)
        else {
            return nil
        }

        let prompt = userPrompt(from: profile)

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
                    "temperature": 0.4,
                    "messages": [
                        ["role": "system", "content": Self.systemPrompt],
                        ["role": "user", "content": prompt]
                    ]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            case .gemini, .agentPlatform:                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
                let body: [String: Any] = [
                    "systemInstruction": ["parts": [["text": Self.systemPrompt]]],
                    "contents": [["parts": [["text": prompt]]]],
                    "generationConfig": ["temperature": 0.4]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return decodeText(from: data, provider: provider)
                .map(sanitize)
                .flatMap { $0.isEmpty ? nil : $0 }
        } catch {
            return nil
        }
    }

    // MARK: - Provider plumbing

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

    // MARK: - Prompt

    private static let systemPrompt = """
    You rewrite a user's speaking-coach onboarding answers into one short, \
    second-person sentence that paraphrases their goal. Output the sentence \
    only — no quotes, no preface, no JSON. Voice: trusted speaking coach. \
    No emoji, no exclamation marks, no marketing language. Maximum 18 words. \
    Start with "You want to" or "You're working toward". Drop personally \
    identifying details. Soften hyperbole.
    """

    private func userPrompt(from profile: CoachingProfile) -> String {
        let parts: [String] = [
            "Primary goal: \(profile.primaryGoal.title)",
            "Speaking context: \(profile.speakingContext.title)",
            "Style aim: \(profile.speakingStyleGoal.title)",
            "Desired outcome: \(profile.desiredOutcome.title)",
            "Biggest challenge: \(profile.biggestChallenge.title)",
            profile.styleReference.isEmpty ? "" : "Style reference: \(profile.styleReference)",
            profile.coachingBrief.isEmpty ? "" : "User wrote: \(profile.coachingBrief)",
            profile.motivationWhyNow.isEmpty ? "" : "Why now: \(profile.motivationWhyNow)",
            profile.successVision.isEmpty ? "" : "Success looks like: \(profile.successVision)"
        ]
        let body = parts.filter { !$0.isEmpty }.joined(separator: "\n")
        return "Inputs:\n\(body)\n\nReturn one paraphrased sentence."
    }

    // MARK: - Response decoding

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
        case .gemini, .agentPlatform:            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = object["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            else { return nil }
            return parts.compactMap { $0["text"] as? String }.joined(separator: " ")
        }
    }

    private func sanitize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\"") && text.hasSuffix("\"") && text.count >= 2 {
            text = String(text.dropFirst().dropLast())
        }
        text = text.replacingOccurrences(of: "\n", with: " ")
        text = text.replacingOccurrences(of: "  ", with: " ")
        if text.count > 220 {
            text = String(text.prefix(217)) + "..."
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
