import Foundation

// MARK: - Google Cloud Speech V2 Provider

/// Uses Google Cloud Speech-to-Text V2 REST API with chunked recognition.
/// For real-time streaming, audio is accumulated in short chunks and sent as
/// sequential recognize requests. This avoids gRPC dependencies.
///
/// **Security model:** Google API keys are restricted in Google Cloud Console
/// by iOS bundle ID (com.yourapp.noum). This means:
/// - The key only works from your app's bundle — extracting it from the .ipa
///   won't help unless the attacker also spoofs the bundle ID.
/// - Additionally, restrict the key to the Speech-to-Text API only in the Console.
/// - No backend proxy needed (unlike Deepgram which has no bundle-ID restriction).
///
/// To restrict: Google Cloud Console → APIs & Services → Credentials →
/// Edit your key → Application restrictions → iOS apps → Add bundle ID.
/// Also set API restrictions → Restrict key → Cloud Speech-to-Text API only.
final class GoogleSpeechProvider: TranscriptionProvider, @unchecked Sendable {
    let name = "Google Cloud Speech"
    let identifier = "google"

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        let credentials = try loadCredentials()
        return GoogleSpeechSession(
            apiKey: credentials.apiKey,
            projectId: credentials.projectId,
            config: config
        )
    }

    private func loadCredentials() throws -> (apiKey: String, projectId: String) {
        // Priority: 1) Environment variables, 2) TranscriptionProviders.plist
        let envKey = ProcessInfo.processInfo.environment["GOOGLE_SPEECH_API_KEY"] ?? ""
        let envProject = ProcessInfo.processInfo.environment["GOOGLE_SPEECH_PROJECT_ID"] ?? ""

        if !envKey.isEmpty && !envProject.isEmpty {
            return (envKey, envProject)
        }

        if let plistPath = Bundle.main.path(forResource: "TranscriptionProviders", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: plistPath),
           let key = dict["GOOGLE_SPEECH_API_KEY"] as? String, !key.isEmpty, key != "YOUR_GOOGLE_KEY",
           let project = dict["GOOGLE_SPEECH_PROJECT_ID"] as? String, !project.isEmpty, project != "YOUR_PROJECT_ID" {
            return (key, project)
        }

        throw GoogleSpeechError.missingCredentials
    }
}

enum GoogleSpeechError: LocalizedError {
    case missingCredentials
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Google Speech API key or project ID not found. Set GOOGLE_SPEECH_API_KEY and GOOGLE_SPEECH_PROJECT_ID in environment or TranscriptionProviders.plist."
        case .requestFailed(let reason): return "Google Speech request failed: \(reason)"
        case .invalidResponse: return "Google Speech returned an invalid response."
        }
    }
}

// MARK: - Google Speech Session

/// Accumulates audio and sends chunked recognize requests.
/// This is a simpler approach than full bidirectional streaming,
/// suitable for the filler detection use case where near-real-time
/// (every ~1-2 seconds) is sufficient.
final class GoogleSpeechSession: TranscriptionSession, @unchecked Sendable {
    private let apiKey: String
    private let projectId: String
    private let config: TranscriptionConfig
    private let updateContinuation: AsyncStream<TranscriptUpdate>.Continuation
    let transcriptUpdates: AsyncStream<TranscriptUpdate>

    private var audioBuffer = Data()
    private let bufferLock = NSLock()
    private var isRunning = true
    private var chunkTask: Task<Void, Never>?

    // Chunk interval in seconds — controls latency vs API call frequency
    private let chunkIntervalSeconds: TimeInterval = 1.5

    init(apiKey: String, projectId: String, config: TranscriptionConfig) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.config = config

        var continuation: AsyncStream<TranscriptUpdate>.Continuation!
        self.transcriptUpdates = AsyncStream { continuation = $0 }
        self.updateContinuation = continuation

        // Start a background task that periodically sends accumulated audio
        self.chunkTask = Task { [weak self] in
            while let self, self.isRunning {
                try? await Task.sleep(for: .milliseconds(Int(self.chunkIntervalSeconds * 1000)))
                await self.sendChunk()
            }
        }
    }

    func sendAudio(_ data: Data) async throws {
        bufferLock.lock()
        audioBuffer.append(data)
        bufferLock.unlock()
    }

    func endAudio() async throws {
        isRunning = false
        chunkTask?.cancel()
        // Send any remaining audio
        await sendChunk()
        updateContinuation.finish()
    }

    private func sendChunk() async {
        bufferLock.lock()
        guard !audioBuffer.isEmpty else {
            bufferLock.unlock()
            return
        }
        let chunk = audioBuffer
        audioBuffer = Data()
        bufferLock.unlock()

        // Build the request
        let base64Audio = chunk.base64EncodedString()
        let requestBody: [String: Any] = [
            "config": [
                "auto_decoding_config": [:] as [String: Any],
                "language_codes": [config.languageCode.replacingOccurrences(of: "_", with: "-")],
                "model": "long",
                "features": [
                    "enable_word_time_offsets": true,
                    "enable_word_confidence": true
                ] as [String: Any]
            ] as [String: Any],
            "content": base64Audio
        ]

        guard let url = URL(string: "https://speech.googleapis.com/v2/projects/\(projectId)/locations/global/recognizers/_:recognize?key=\(apiKey)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("[GoogleSpeech] Request failed with status \(statusCode)")
                return
            }

            let decoded = try JSONDecoder().decode(GoogleRecognizeResponse.self, from: data)
            for result in decoded.results ?? [] {
                guard let alternative = result.alternatives?.first,
                      !alternative.transcript.isEmpty else { continue }

                let wordTimings = alternative.words?.map { word in
                    TranscriptUpdate.WordTiming(
                        word: word.word,
                        startTime: parseGoogleDuration(word.startOffset),
                        endTime: parseGoogleDuration(word.endOffset),
                        confidence: word.confidence
                    )
                }

                let update = TranscriptUpdate(
                    text: alternative.transcript,
                    isFinal: result.isFinal ?? true,  // Chunk-based requests are always final
                    confidence: alternative.confidence,
                    words: wordTimings,
                    providerFillerWords: nil,  // Google has no native filler detection
                    latencyMs: nil
                )
                updateContinuation.yield(update)
            }
        } catch {
            print("[GoogleSpeech] Error: \(error)")
        }
    }

    private func parseGoogleDuration(_ value: String?) -> TimeInterval {
        // Google returns durations like "1.500s"
        guard let value, value.hasSuffix("s") else { return 0 }
        let numericPart = String(value.dropLast())
        return Double(numericPart) ?? 0
    }
}

// MARK: - Google Speech JSON Models

private struct GoogleRecognizeResponse: Decodable {
    let results: [GoogleSpeechResult]?
}

private struct GoogleSpeechResult: Decodable {
    let alternatives: [GoogleSpeechAlternative]?
    let isFinal: Bool?

    enum CodingKeys: String, CodingKey {
        case alternatives
        case isFinal
    }
}

private struct GoogleSpeechAlternative: Decodable {
    let transcript: String
    let confidence: Double?
    let words: [GoogleSpeechWord]?
}

private struct GoogleSpeechWord: Decodable {
    let word: String
    let startOffset: String?
    let endOffset: String?
    let confidence: Double?
}
