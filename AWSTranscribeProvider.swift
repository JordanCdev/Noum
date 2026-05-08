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
        _ = try await authManager.currentCredentials()
        let clientConfig = try await TranscribeStreamingClient.TranscribeStreamingClientConfiguration(
            awsCredentialIdentityResolver: authManager.credentialResolver(),
            region: authManager.region
        )
        let client = TranscribeStreamingClient(config: clientConfig)
        return AWSTranscribeSession(client: client, config: config)
    }
}

// MARK: - AWS Transcribe Session

final class AWSTranscribeSession: TranscriptionSession, @unchecked Sendable {
    private let client: TranscribeStreamingClient
    private let config: TranscriptionConfig
    private var requestStreamContinuation: AsyncThrowingStream<TranscribeStreamingClientTypes.AudioStream, Error>.Continuation?
    private var streamConnection: StartStreamTranscriptionOutput?
    private let updateContinuation: AsyncStream<TranscriptUpdate>.Continuation
    let transcriptUpdates: AsyncStream<TranscriptUpdate>

    init(client: TranscribeStreamingClient, config: TranscriptionConfig) {
        self.client = client
        self.config = config

        var continuation: AsyncStream<TranscriptUpdate>.Continuation!
        self.transcriptUpdates = AsyncStream { continuation = $0 }
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
            if let events = output.transcriptResultStream {
                for try await event in events {
                    handleEvent(event)
                }
            }
        } catch {
            print("[AWSTranscribeSession] Streaming error: \(error)")
        }
        updateContinuation.finish()
    }

    func sendAudio(_ data: Data) async throws {
        requestStreamContinuation?.yield(
            .audioevent(TranscribeStreamingClientTypes.AudioEvent(audioChunk: data))
        )
    }

    func endAudio() async throws {
        requestStreamContinuation?.finish()
        requestStreamContinuation = nil
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
                updateContinuation.yield(update)
            }
        default: break
        }
    }
}
