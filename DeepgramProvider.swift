import Foundation

// MARK: - Deepgram Nova-2 Provider

final class DeepgramProvider: TranscriptionProvider, @unchecked Sendable {
    let name = "Deepgram Nova-2"
    let identifier = "deepgram"

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        let apiKey = try loadAPIKey()
        return DeepgramSession(apiKey: apiKey, config: config)
    }

    private func loadAPIKey() throws -> String {
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
