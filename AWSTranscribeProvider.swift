import Foundation
@preconcurrency import AWSSDKIdentity
@preconcurrency import AWSTranscribeStreaming
@preconcurrency import AWSClientRuntime

// MARK: - AWS Transcribe Provider

final class AWSTranscribeProvider: TranscriptionProvider, @unchecked Sendable {
    let name = "AWS Transcribe"
    let identifier = "aws"
    private let authManager: AuthManager

    @MainActor
    init(authManager: AuthManager? = nil) {
        // `AuthManager.shared` is main-actor-isolated, so this init
        // must be too. Callers (SpeechRecognizerViewModel etc.) are
        // already on @MainActor when constructing the provider.
        if let provided = authManager {
            self.authManager = provided
        } else {
            self.authManager = AuthManager.shared
        }
    }

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        try await CloudTranscriptionConsentGate.requireAllowed()
        _ = try await authManager.currentCredentials()
        let clientConfig = try await TranscribeStreamingClient.TranscribeStreamingClientConfiguration(
            awsCredentialIdentityResolver: authManager.credentialResolver(),
            region: authManager.region
        )
        let client = TranscribeStreamingClient(config: clientConfig)
        let session = AWSTranscribeSession(client: client, config: config)
        do {
            try await session.waitUntilReady()
            return session
        } catch {
            session.abort(error)
            throw error
        }
    }
}

// MARK: - AWS Transcribe Session

final class AWSTranscribeSession: TranscriptionSession, @unchecked Sendable {
    private let client: TranscribeStreamingClient
    private let config: TranscriptionConfig
    private var requestStreamContinuation: AsyncThrowingStream<TranscribeStreamingClientTypes.AudioStream, Error>.Continuation?
    private var streamConnection: StartStreamTranscriptionOutput?
    private let readiness = TranscriptionReadinessGate()
    private let terminal = TranscriptionTerminalState()
    private let updateContinuation: AsyncThrowingStream<TranscriptUpdate, Error>.Continuation
    let transcriptUpdates: AsyncThrowingStream<TranscriptUpdate, Error>

    init(client: TranscribeStreamingClient, config: TranscriptionConfig) {
        self.client = client
        self.config = config

        var continuation: AsyncThrowingStream<TranscriptUpdate, Error>.Continuation!
        self.transcriptUpdates = AsyncThrowingStream { continuation = $0 }
        self.updateContinuation = continuation

        Task { await self.startStreaming() }
    }

    private func startStreaming() async {
        let audioStream = AsyncThrowingStream<TranscribeStreamingClientTypes.AudioStream, Error> { continuation in
            self.requestStreamContinuation = continuation
        }

        // Map the BCP-47 code from the practice locale to AWS Transcribe's
        // enum. Falls back to en-US for any unknown code so a future locale
        // addition won't crash users on older builds.
        let awsLanguage: TranscribeStreamingClientTypes.LanguageCode = {
            switch config.languageCode {
            case "en-US": return .enUs
            case "es-ES": return .esEs
            case "fr-FR": return .frFr
            default:      return .enUs
            }
        }()

        let request = StartStreamTranscriptionInput(
            audioStream: audioStream,
            languageCode: awsLanguage,
            mediaEncoding: .pcm,
            mediaSampleRateHertz: config.sampleRate
        )

        do {
            let output = try await client.startStreamTranscription(input: request)
            self.streamConnection = output
            readiness.succeed()
            if let events = output.transcriptResultStream {
                for try await event in events {
                    handleEvent(event)
                }
            }
            terminal.succeed()
            updateContinuation.finish()
        } catch {
            readiness.fail(error)
            terminal.fail(error)
            updateContinuation.finish(throwing: error)
        }
    }

    func waitUntilReady() async throws {
        try await readiness.wait(timeout: .seconds(8))
    }

    func abort(_ error: Error) {
        requestStreamContinuation?.finish(throwing: error)
        requestStreamContinuation = nil
        readiness.fail(error)
        terminal.fail(error)
        updateContinuation.finish(throwing: error)
    }

    func sendAudio(_ data: Data) async throws {
        guard !data.isEmpty else { return }
        guard let requestStreamContinuation else {
            throw TranscriptionSessionError.notReady
        }
        let result = requestStreamContinuation.yield(
            .audioevent(TranscribeStreamingClientTypes.AudioEvent(audioChunk: data))
        )
        switch result {
        case .enqueued:
            terminal.noteAudio(bytes: data.count)
        case .dropped:
            let error = TranscriptionSessionError.transport("AWS Transcribe dropped an audio chunk.")
            abort(error)
            throw error
        case .terminated:
            let error = TranscriptionSessionError.transport("The AWS transcription stream closed early.")
            abort(error)
            throw error
        @unknown default:
            let error = TranscriptionSessionError.transport("The AWS transcription stream became unavailable.")
            abort(error)
            throw error
        }
    }

    func finish() async throws -> FinalizedTranscript {
        guard requestStreamContinuation != nil else {
            throw TranscriptionSessionError.alreadyFinished
        }
        self.requestStreamContinuation?.finish()
        self.requestStreamContinuation = nil
        return try await terminal.wait(timeout: .seconds(8))
    }

    private func handleEvent(_ event: TranscribeStreamingClientTypes.TranscriptResultStream) {
        switch event {
        case .transcriptevent(let transcriptEvent):
            for result in transcriptEvent.transcript?.results ?? [] {
                guard let alternative = result.alternatives?.first,
                      let snippet = alternative.transcript?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !snippet.isEmpty else { continue }

                let update = TranscriptUpdate(
                    text: snippet,
                    isFinal: result.isPartial == false,
                    confidence: nil,  // AWS doesn't expose confidence per-utterance easily
                    words: nil,
                    providerFillerWords: nil,  // AWS has no native filler detection
                    latencyMs: nil
                )
                terminal.note(update)
                updateContinuation.yield(update)
            }
        default: break
        }
    }
}
