import Foundation
import os

// MARK: - Google Cloud Speech V2 Provider

/// Uses Google Cloud Speech-to-Text V2 REST API with chunked recognition.
/// For real-time streaming, audio is accumulated in short chunks and sent as
/// sequential recognize requests. This avoids gRPC dependencies.
///
/// This provider is retained for DEBUG benchmarking only. Release builds do
/// not read API keys from the process or bundle; Deepgram's authenticated
/// temporary-token path is the sole production cloud transcription route.
/// Also set API restrictions → Restrict key → Cloud Speech-to-Text API only.
final class GoogleSpeechProvider: TranscriptionProvider, @unchecked Sendable {
    let name = "Google Cloud Speech"
    let identifier = "google"

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        try await CloudTranscriptionConsentGate.requireAllowed()
        let credentials = try loadCredentials()
        return GoogleSpeechSession(
            apiKey: credentials.apiKey,
            projectId: credentials.projectId,
            config: config
        )
    }

    private func loadCredentials() throws -> (apiKey: String, projectId: String) {
        #if DEBUG
        // Developer-only: environment first, then an ignored local plist.
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
        #endif

        throw GoogleSpeechError.missingCredentials
    }
}

enum GoogleSpeechError: LocalizedError {
    case missingCredentials
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Google Speech is unavailable in this build."
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
    private let terminal = TranscriptionTerminalState()
    private let updateContinuation: AsyncThrowingStream<TranscriptUpdate, Error>.Continuation
    let transcriptUpdates: AsyncThrowingStream<TranscriptUpdate, Error>

    // `audioBuffer` is owned by `bufferLock`. Switching from `NSLock`
    // to `OSAllocatedUnfairLock` because `NSLock.lock`/`unlock` are
    // unsafe to call from async functions under Swift 6 — the unfair
    // lock variant is async-context-safe and never holds across
    // suspension points (the closure body has no awaits).
    private struct BufferState {
        var data = Data()
        var isRunning = true
        var didFinish = false
    }
    private let bufferLock = OSAllocatedUnfairLock<BufferState>(initialState: BufferState())
    private var chunkTask: Task<Void, Never>?

    // Chunk interval in seconds — controls latency vs API call frequency
    private let chunkIntervalSeconds: TimeInterval = 1.5

    init(apiKey: String, projectId: String, config: TranscriptionConfig) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.config = config

        var continuation: AsyncThrowingStream<TranscriptUpdate, Error>.Continuation!
        self.transcriptUpdates = AsyncThrowingStream { continuation = $0 }
        self.updateContinuation = continuation

        // Start a background task that periodically sends accumulated audio
        self.chunkTask = Task { [weak self] in
            while let self, self.isRunning {
                do {
                    try await Task.sleep(for: .milliseconds(Int(self.chunkIntervalSeconds * 1000)))
                    try Task.checkCancellation()
                    try await self.sendChunk()
                } catch is CancellationError {
                    return
                } catch {
                    self.fail(error)
                    return
                }
            }
        }
    }

    private var isRunning: Bool {
        bufferLock.withLock { $0.isRunning }
    }

    func sendAudio(_ data: Data) async throws {
        guard !data.isEmpty else { return }
        let accepted = bufferLock.withLock { state -> Bool in
            guard state.isRunning, !state.didFinish else { return false }
            state.data.append(data)
            return true
        }
        guard accepted else { throw TranscriptionSessionError.alreadyFinished }
        terminal.noteAudio(bytes: data.count)
    }

    func finish() async throws -> FinalizedTranscript {
        let shouldFinish = bufferLock.withLock { state -> Bool in
            guard state.isRunning, !state.didFinish else { return false }
            state.isRunning = false
            state.didFinish = true
            return true
        }
        guard shouldFinish else { throw TranscriptionSessionError.alreadyFinished }
        chunkTask?.cancel()
        await chunkTask?.value

        do {
            try await sendChunk()
            updateContinuation.finish()
            terminal.succeed()
            return try await terminal.wait(timeout: .seconds(1))
        } catch {
            fail(error)
            throw error
        }
    }

    private func sendChunk() async throws {
        // Drain the buffer atomically — copy the bytes out under the
        // lock and reset, then do the network work without holding the
        // lock (no suspension points inside `withLock`).
        let chunk: Data = bufferLock.withLock { state in
            let snapshot = state.data
            state.data = Data()
            return snapshot
        }
        guard !chunk.isEmpty else { return }

        do {
            try await recognize(chunk)
        } catch {
            // Cancellation during `finish()` can interrupt an in-flight REST
            // request after its bytes were drained. Put those bytes back at
            // the front so the terminal request includes every trailing word.
            bufferLock.withLock { state in
                var restored = chunk
                restored.append(state.data)
                state.data = restored
            }
            throw error
        }
    }

    private func recognize(_ chunk: Data) async throws {

        // Build the request
        let base64Audio = chunk.base64EncodedString()
        let requestBody: [String: Any] = [
            "config": [
                "explicitDecodingConfig": [
                    "encoding": "LINEAR16",
                    "sampleRateHertz": config.sampleRate,
                    "audioChannelCount": 1,
                ] as [String: Any],
                "languageCodes": [config.languageCode.replacingOccurrences(of: "_", with: "-")],
                "model": "long",
                "features": [
                    "enableWordTimeOffsets": true,
                    "enableWordConfidence": true
                ] as [String: Any]
            ] as [String: Any],
            "content": base64Audio
        ]

        guard let url = URL(string: "https://speech.googleapis.com/v2/projects/\(projectId)/locations/global/recognizers/_:recognize?key=\(apiKey)") else {
            throw GoogleSpeechError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GoogleSpeechError.requestFailed("HTTP \(statusCode)")
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
                isFinal: result.isFinal ?? true,
                confidence: alternative.confidence,
                words: wordTimings,
                providerFillerWords: nil,
                latencyMs: nil
            )
            terminal.note(update)
            updateContinuation.yield(update)
        }
    }

    private func fail(_ error: Error) {
        bufferLock.withLock { state in
            state.isRunning = false
            state.didFinish = true
        }
        chunkTask?.cancel()
        terminal.fail(error)
        updateContinuation.finish(throwing: error)
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
