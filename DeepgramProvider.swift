import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

// MARK: - Deepgram Nova-2 Provider

/// Production sessions receive a short-lived Deepgram JWT from the trusted
/// Firebase callable. Long-lived provider credentials are never read from the
/// production process environment or app bundle.
final class DeepgramProvider: TranscriptionProvider, @unchecked Sendable {
    static let region = "europe-west2"
    static let tokenFunctionName = "transcriptionToken"

    let name = "Deepgram Nova-2"
    let identifier = "deepgram"

    private let cacheLock = NSLock()
    private var cachedToken: DeepgramAccessToken?

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        try await CloudTranscriptionConsentGate.requireAllowed()
        let token = try await resolveAccessToken()
        let session = DeepgramSession(credential: token, config: config)
        do {
            try await session.waitUntilReady()
            return session
        } catch {
            session.abort(error)
            throw error
        }
    }

    private func resolveAccessToken() async throws -> DeepgramAccessToken {
        if let cached: DeepgramAccessToken = cacheLock.withLock({ cachedToken }),
           Date().addingTimeInterval(5) < cached.expiresAt {
            return cached
        }

        #if DEBUG
        // Developer scripts explicitly inject this value into the simulator.
        // No plist fallback is intentional: a copied local file must never
        // become a release-build credential source by target-membership drift.
        if let local = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !local.isEmpty {
            return DeepgramAccessToken(
                value: local,
                expiresAt: Date().addingTimeInterval(30 * 60),
                authorizationScheme: .apiKey
            )
        }
        #endif

        let token = try await fetchCallableToken()
        cacheLock.withLock { cachedToken = token }
        return token
    }

    private func fetchCallableToken() async throws -> DeepgramAccessToken {
        // Firebase Auth is SDK-global, unlike Noum's isolated UI-automation
        // Keychain service. Never let a rendered test borrow the simulator's
        // normal user when Functions attaches ambient authentication.
        guard AuthManager.firebaseSDKSessionAccessAllowed(
            arguments: ProcessInfo.processInfo.arguments
        ) else {
            throw DeepgramError.authenticationRequired
        }
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFunctions)
        guard FirebaseApp.app() != nil, Auth.auth().currentUser != nil else {
            throw DeepgramError.authenticationRequired
        }

        let functions = Functions.functions(region: Self.region)
        let callable: Callable<TranscriptionTokenRequest, TranscriptionTokenResponse> = functions
            .httpsCallable(Self.tokenFunctionName)
        let response: TranscriptionTokenResponse
        do {
            response = try await callable.call(TranscriptionTokenRequest())
        } catch {
            throw DeepgramError.tokenServiceUnavailable
        }

        return try response.validatedToken(now: Date())
        #else
        throw DeepgramError.tokenServiceUnavailable
        #endif
    }
}

private struct TranscriptionTokenRequest: Encodable, Sendable {
    let schemaVersion = 1
}

/// Exact callable response contract. Keep this shape deliberately narrow so a
/// backend cannot accidentally expose management-key metadata to the client.
struct TranscriptionTokenResponse: Decodable, Sendable, Equatable {
    let provider: String
    let accessToken: String
    let expiresAt: String

    func validatedToken(now: Date) throws -> DeepgramAccessToken {
        guard provider == "deepgram" else { throw DeepgramError.invalidTokenResponse }
        let cleanToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else { throw DeepgramError.invalidTokenResponse }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let expiry = fractional.date(from: expiresAt)
                ?? ISO8601DateFormatter().date(from: expiresAt),
              expiry > now else {
            throw DeepgramError.expiredToken
        }
        return DeepgramAccessToken(
            value: cleanToken,
            expiresAt: expiry,
            authorizationScheme: .temporaryJWT
        )
    }
}

struct DeepgramAccessToken: Sendable, Equatable {
    enum AuthorizationScheme: String, Sendable, Equatable {
        case apiKey = "Token"
        case temporaryJWT = "Bearer"
    }

    let value: String
    let expiresAt: Date
    let authorizationScheme: AuthorizationScheme
}

enum DeepgramError: LocalizedError, Sendable, Equatable {
    case authenticationRequired
    case tokenServiceUnavailable
    case invalidTokenResponse
    case expiredToken
    case connectionFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "A secure Noum session is required before live transcription can start."
        case .tokenServiceUnavailable:
            return "Live transcription could not establish a secure connection."
        case .invalidTokenResponse:
            return "Live transcription received an invalid access token."
        case .expiredToken:
            return "Live transcription received an expired access token."
        case .connectionFailed(let reason):
            return "Deepgram connection failed: \(reason)"
        case .invalidResponse:
            return "Deepgram returned an unreadable response."
        }
    }
}

// MARK: - Deepgram Session (WebSocket)

final class DeepgramSession: NSObject, TranscriptionSession, URLSessionWebSocketDelegate, @unchecked Sendable {
    static let streamingEndpoint = "wss://api.deepgram.com/v1/listen"

    private struct ConnectionState {
        var didOpen = false
        var finishRequested = false
        var didComplete = false
    }

    private let connectionLock = NSLock()
    private var connectionState = ConnectionState()
    private let readiness = TranscriptionReadinessGate()
    private let terminal = TranscriptionTerminalState()
    private let updateContinuation: AsyncThrowingStream<TranscriptUpdate, Error>.Continuation
    let transcriptUpdates: AsyncThrowingStream<TranscriptUpdate, Error>

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    init(credential: DeepgramAccessToken, config: TranscriptionConfig) {
        var continuation: AsyncThrowingStream<TranscriptUpdate, Error>.Continuation!
        self.transcriptUpdates = AsyncThrowingStream { continuation = $0 }
        self.updateContinuation = continuation
        super.init()

        let url = Self.streamingURL(config: config)
        var request = URLRequest(url: url)
        request.setValue(
            "\(credential.authorizationScheme.rawValue) \(credential.value)",
            forHTTPHeaderField: "Authorization"
        )

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        urlSession = session
        let task = session.webSocketTask(with: request)
        webSocket = task
        task.resume()
        startReceiveLoop()
    }

    static func streamingURL(config: TranscriptionConfig) -> URL {
        var components = URLComponents(string: streamingEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "model", value: "nova-2"),
            URLQueryItem(
                name: "language",
                value: config.languageCode.replacingOccurrences(of: "_", with: "-")
            ),
            URLQueryItem(
                name: "filler_words",
                value: config.enableFillerWordDetection ? "true" : "false"
            ),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: String(config.sampleRate)),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            // Stable product-level attribution only. Never include account,
            // session, transcript, or other personal identifiers in tags.
            URLQueryItem(name: "tag", value: "noum-production"),
            // Deepgram's request-level model-improvement opt-out. Consent to
            // processing is not consent to provider model training.
            URLQueryItem(name: "mip_opt_out", value: "true"),
        ]
        return components.url!
    }

    func waitUntilReady() async throws {
        try await readiness.wait(timeout: .seconds(8))
    }

    func abort(_ error: Error) {
        fail(error)
    }

    func sendAudio(_ data: Data) async throws {
        guard !data.isEmpty else { return }
        let canSend = connectionLock.withLock {
            connectionState.didOpen && !connectionState.finishRequested && !connectionState.didComplete
        }
        guard canSend, let webSocket else { throw TranscriptionSessionError.notReady }
        do {
            try await webSocket.send(.data(data))
            terminal.noteAudio(bytes: data.count)
        } catch {
            fail(error)
            throw error
        }
    }

    func finish() async throws -> FinalizedTranscript {
        let mayFinish = connectionLock.withLock { () -> Bool in
            guard connectionState.didOpen,
                  !connectionState.finishRequested,
                  !connectionState.didComplete else { return false }
            connectionState.finishRequested = true
            return true
        }
        guard mayFinish, let webSocket else { throw TranscriptionSessionError.alreadyFinished }

        do {
            try await webSocket.send(.string("{\"type\":\"CloseStream\"}"))
            return try await terminal.wait(timeout: .seconds(5))
        } catch {
            fail(error)
            webSocket.cancel(with: .goingAway, reason: nil)
            throw error
        }
    }

    private func startReceiveLoop() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                let completed = self.connectionLock.withLock { self.connectionState.didComplete }
                if !completed { self.startReceiveLoop() }
            case .failure(let error):
                self.fail(error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else {
            fail(DeepgramError.invalidResponse)
            return
        }

        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            if response.type == "Metadata" {
                completeSuccessfully()
                return
            }
            guard response.type == "Results" else { return }
            guard let channel = response.channel,
                  let alternative = channel.alternatives.first else {
                throw DeepgramError.invalidResponse
            }

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
            terminal.note(update)
            updateContinuation.yield(update)
        } catch {
            fail(error)
        }
    }

    private func completeSuccessfully() {
        let shouldComplete = connectionLock.withLock { () -> Bool in
            guard !connectionState.didComplete else { return false }
            connectionState.didComplete = true
            return true
        }
        guard shouldComplete else { return }
        updateContinuation.finish()
        terminal.succeed()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        urlSession?.finishTasksAndInvalidate()
    }

    private func fail(_ error: Error) {
        let shouldFail = connectionLock.withLock { () -> Bool in
            guard !connectionState.didComplete else { return false }
            connectionState.didComplete = true
            return true
        }
        guard shouldFail else { return }
        readiness.fail(error)
        terminal.fail(error)
        updateContinuation.finish(throwing: error)
        webSocket?.cancel(with: .goingAway, reason: nil)
        urlSession?.invalidateAndCancel()
    }

    // MARK: URLSessionWebSocketDelegate

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        connectionLock.withLock { connectionState.didOpen = true }
        readiness.succeed()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let finishRequested = connectionLock.withLock { connectionState.finishRequested }
        if finishRequested && closeCode == .normalClosure {
            completeSuccessfully()
        } else {
            fail(DeepgramError.connectionFailed("socket closed with code \(closeCode.rawValue)"))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error { fail(error) }
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
    let type: String?
}
