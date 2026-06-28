import Foundation

// MARK: - Deepgram Nova-2 Provider

/// Production: fetches a short-lived scoped key from your backend (Option A).
/// Dev: falls back to environment variable or local TranscriptionProviders.plist.
///
/// Backend endpoint: GET /v1/transcribe/deepgram-key
/// Expected response: { "apiKey": "dg_...", "expiresAt": "ISO8601" }
/// The backend creates a scoped key via Deepgram's API: POST https://api.deepgram.com/v1/keys/{projectId}
/// with `time_to_live_in_seconds` and limited scopes (e.g. ["usage:write"]).
final class DeepgramProvider: TranscriptionProvider, @unchecked Sendable {
    let name = "Deepgram Nova-2"
    let identifier = "deepgram"

    private var cachedKey: (key: String, expiresAt: Date)?

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        let apiKey = try await resolveAPIKey()
        return DeepgramSession(apiKey: apiKey, config: config)
    }

    private func resolveAPIKey() async throws -> String {
        // 1. Use cached backend key if still valid (refresh 30s before expiry)
        if let cached = cachedKey,
           Date().addingTimeInterval(30) < cached.expiresAt {
            return cached.key
        }

        // 2. Try backend-vended scoped key (production path)
        if let backendKey = try? await fetchBackendScopedKey() {
            cachedKey = backendKey
            return backendKey.key
        }

        // 3. Fall back to local dev credentials
        return try loadLocalAPIKey()
    }

    /// Fetches a short-lived Deepgram scoped key from your backend.
    /// Backend should call Deepgram's key management API to create a temporary key
    /// with limited scopes and TTL (e.g. 30 minutes).
    private func fetchBackendScopedKey() async throws -> (key: String, expiresAt: Date)? {
        let authManager = await AuthManager.shared
        guard let accountID = await authManager.currentAccountID,
              let providerRaw = await authManager.currentAuthProviderRawValue else {
            return nil
        }

        let baseURLString = ProcessInfo.processInfo.environment["BACKEND_BASE_URL"]
            ?? LocalConfigLoader.value(forKey: "BACKEND_BASE_URL", plistNamed: "BackendConfig")

        guard let baseURLString, !baseURLString.isEmpty,
              let baseURL = URL(string: baseURLString) else {
            return nil
        }

        let endpoint = baseURL.appending(path: "/v1/transcribe/deepgram-key")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        await BackendAuthHeaders.applyCurrent(
            to: &request,
            accountID: accountID,
            providerRawValue: providerRaw
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(DeepgramKeyResponse.self, from: data)
        return (key: decoded.apiKey, expiresAt: decoded.expiresAt)
    }

    private func loadLocalAPIKey() throws -> String {
        // Priority: 1) Environment variable, 2) TranscriptionProviders.plist
        if let envKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        if let plistPath = Bundle.main.path(forResource: "TranscriptionProviders", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: plistPath),
           let key = dict["DEEPGRAM_API_KEY"] as? String, !key.isEmpty, key != "YOUR_DEEPGRAM_KEY" {
            return key
        }

        throw DeepgramError.missingAPIKey
    }
}

private struct DeepgramKeyResponse: Decodable {
    let apiKey: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case apiKey
        case expiresAt, expiration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiKey = try container.decode(String.self, forKey: .apiKey)
        let dateString = try (container.decodeIfPresent(String.self, forKey: .expiresAt)
            ?? container.decode(String.self, forKey: .expiration))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString)
                ?? ISO8601DateFormatter().date(from: dateString) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [CodingKeys.expiresAt], debugDescription: "Invalid ISO8601 date")
            )
        }
        expiresAt = date
    }
}

enum DeepgramError: LocalizedError {
    case missingAPIKey
    case connectionFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Deepgram API key not found. Set DEEPGRAM_API_KEY in environment or TranscriptionProviders.plist."
        case .connectionFailed(let reason): return "Deepgram connection failed: \(reason)"
        case .invalidResponse: return "Deepgram returned an invalid response."
        }
    }
}

// MARK: - Deepgram Session (WebSocket)

final class DeepgramSession: NSObject, TranscriptionSession, URLSessionWebSocketDelegate, @unchecked Sendable {
    private var webSocket: URLSessionWebSocketTask?
    private let updateContinuation: AsyncStream<TranscriptUpdate>.Continuation
    let transcriptUpdates: AsyncStream<TranscriptUpdate>
    private var urlSession: URLSession?

    init(apiKey: String, config: TranscriptionConfig) {
        var continuation: AsyncStream<TranscriptUpdate>.Continuation!
        self.transcriptUpdates = AsyncStream { continuation = $0 }
        self.updateContinuation = continuation
        super.init()

        let params = [
            "model=nova-2",
            "language=\(config.languageCode.replacingOccurrences(of: "_", with: "-"))",
            "filler_words=true",
            "interim_results=true",
            "encoding=linear16",
            "sample_rate=\(config.sampleRate)",
            "channels=1",
            "punctuate=true",
            "smart_format=true"
        ].joined(separator: "&")

        let url = URL(string: "wss://api.deepgram.com/v1/listen?\(params)")!
        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.urlSession = session
        let task = session.webSocketTask(with: request)
        self.webSocket = task
        task.resume()
        startReceiveLoop()
    }

    func sendAudio(_ data: Data) async throws {
        try await webSocket?.send(.data(data))
    }

    func endAudio() async throws {
        // Send empty byte to signal end-of-stream per Deepgram protocol
        try await webSocket?.send(.data(Data()))
        webSocket?.cancel(with: .normalClosure, reason: nil)
    }

    private func startReceiveLoop() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.startReceiveLoop()
            case .failure(let error):
                print("[DeepgramSession] Receive error: \(error)")
                self.updateContinuation.finish()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else { return }

        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            guard response.type == "Results",
                  let channel = response.channel,
                  let alternative = channel.alternatives.first else { return }

            let providerFillers = alternative.words?
                .filter { $0.type == "filler" }
                .map(\.word)

            let wordTimings = alternative.words?.map { word in
                TranscriptUpdate.WordTiming(
                    word: word.word,
                    startTime: word.start,
                    endTime: word.end,
                    confidence: word.confidence
                )
            }

            let update = TranscriptUpdate(
                text: alternative.transcript,
                isFinal: response.isFinal ?? false,
                confidence: alternative.confidence,
                words: wordTimings,
                providerFillerWords: providerFillers,
                latencyMs: nil
            )
            updateContinuation.yield(update)
        } catch {
            print("[DeepgramSession] Parse error: \(error)")
        }
    }

    // URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        updateContinuation.finish()
    }
}

// MARK: - Deepgram JSON Models

private struct DeepgramResponse: Decodable {
    let type: String?
    let channel: DeepgramChannel?
    let isFinal: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case channel
        case isFinal = "is_final"
    }
}

private struct DeepgramChannel: Decodable {
    let alternatives: [DeepgramAlternative]
}

private struct DeepgramAlternative: Decodable {
    let transcript: String
    let confidence: Double?
    let words: [DeepgramWord]?
}

private struct DeepgramWord: Decodable {
    let word: String
    let start: TimeInterval
    let end: TimeInterval
    let confidence: Double?
    let type: String?  // "filler" for filler words when filler_words=true
}
