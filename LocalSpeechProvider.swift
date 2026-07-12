import Foundation
#if canImport(Speech) && canImport(AVFAudio)
import Speech
import AVFAudio

/// Apple's on-device recognizer behind Noum's existing streaming abstraction.
/// Audio never leaves the device: `requiresOnDeviceRecognition` is always true
/// and unsupported locale/device combinations fail instead of silently using
/// Apple's server recognizer.
final class LocalSpeechProvider: TranscriptionProvider, @unchecked Sendable {
    let name = "Apple On-Device Speech"
    let identifier = "local"

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        let authorized = await Self.ensureAuthorization()
        guard authorized else { throw LocalSpeechError.authorizationDenied }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: config.languageCode)),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            throw LocalSpeechError.onDeviceRecognitionUnavailable(config.languageCode)
        }
        return try LocalSpeechSession(recognizer: recognizer, config: config)
    }

    private static func ensureAuthorization() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .denied, .restricted: return false
        @unknown default: return false
        }
    }
}

enum LocalSpeechError: LocalizedError, Sendable, Equatable {
    case authorizationDenied
    case onDeviceRecognitionUnavailable(String)
    case invalidAudioFormat

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Speech recognition access is off. Allow Speech Recognition in Settings to practice offline."
        case .onDeviceRecognitionUnavailable(let locale):
            return "On-device transcription isn't available for \(locale) on this device."
        case .invalidAudioFormat:
            return "Noum couldn't prepare this audio for on-device transcription."
        }
    }
}

private final class LocalSpeechSession: TranscriptionSession, @unchecked Sendable {
    let resolvedProviderIdentifier: String? = "local"
    let transcriptUpdates: AsyncThrowingStream<TranscriptUpdate, Error>

    private let continuation: AsyncThrowingStream<TranscriptUpdate, Error>.Continuation
    private let request: SFSpeechAudioBufferRecognitionRequest
    private let task: SFSpeechRecognitionTask
    private let format: AVAudioFormat
    private let terminal = TranscriptionTerminalState()
    private let lock = NSLock()
    private var finished = false

    init(recognizer: SFSpeechRecognizer, config: TranscriptionConfig) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(config.sampleRate),
            channels: 1,
            interleaved: true
        ) else { throw LocalSpeechError.invalidAudioFormat }
        self.format = format

        var captured: AsyncThrowingStream<TranscriptUpdate, Error>.Continuation!
        transcriptUpdates = AsyncThrowingStream { captured = $0 }
        continuation = captured

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.request = request

        task = recognizer.recognitionTask(with: request) { [continuation, terminal] result, error in
            if let result {
                let transcription = result.bestTranscription
                let words = transcription.segments.map { segment in
                    TranscriptUpdate.WordTiming(
                        word: segment.substring,
                        startTime: segment.timestamp,
                        endTime: segment.timestamp + segment.duration,
                        confidence: Double(segment.confidence)
                    )
                }
                let confidenceValues = transcription.segments.map { Double($0.confidence) }
                let confidence = confidenceValues.isEmpty
                    ? nil
                    : confidenceValues.reduce(0, +) / Double(confidenceValues.count)
                let update = TranscriptUpdate(
                    text: transcription.formattedString,
                    isFinal: result.isFinal,
                    confidence: confidence,
                    words: words,
                    providerFillerWords: nil,
                    latencyMs: nil
                )
                terminal.note(update)
                continuation.yield(update)
                if result.isFinal {
                    terminal.succeed()
                    continuation.finish()
                }
            }
            if let error {
                terminal.fail(error)
                continuation.finish(throwing: error)
            }
        }
    }

    func sendAudio(_ data: Data) async throws {
        guard !data.isEmpty else { return }
        guard !lock.withLock({ finished }) else { throw TranscriptionSessionError.alreadyFinished }
        let bytesPerFrame = MemoryLayout<Int16>.size
        let frameCount = data.count / bytesPerFrame
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let samples = buffer.int16ChannelData?[0] else {
            throw LocalSpeechError.invalidAudioFormat
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        data.withUnsafeBytes { source in
            guard let base = source.baseAddress else { return }
            memcpy(samples, base, frameCount * bytesPerFrame)
        }
        terminal.noteAudio(bytes: data.count)
        request.append(buffer)
    }

    func finish() async throws -> FinalizedTranscript {
        let shouldFinish = lock.withLock { () -> Bool in
            guard !finished else { return false }
            finished = true
            return true
        }
        guard shouldFinish else { throw TranscriptionSessionError.alreadyFinished }
        request.endAudio()
        return try await terminal.wait(timeout: .seconds(8))
    }

    deinit {
        task.cancel()
        continuation.finish()
    }
}
#else
final class LocalSpeechProvider: TranscriptionProvider, @unchecked Sendable {
    let name = "Apple On-Device Speech"
    let identifier = "local"
    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        throw TranscriptionSessionError.transport("On-device transcription is unavailable on this platform.")
    }
}
#endif

/// Starts with the authenticated production provider and falls back locally
/// only when cloud setup cannot begin. Once a provider session starts its
/// audio stream remains on that provider; Noum never duplicates live audio.
final class ResilientTranscriptionProvider: TranscriptionProvider, @unchecked Sendable {
    let name = "Automatic (Cloud + On-Device)"
    let identifier = "automatic"
    private let primary: any TranscriptionProvider
    private let fallback: any TranscriptionProvider

    init(primary: any TranscriptionProvider, fallback: any TranscriptionProvider) {
        self.primary = primary
        self.fallback = fallback
    }

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        do {
            let session = try await primary.startSession(config: config)
            return ProviderTaggedTranscriptionSession(base: session, identifier: primary.identifier)
        } catch {
            let session = try await fallback.startSession(config: config)
            return ProviderTaggedTranscriptionSession(base: session, identifier: fallback.identifier)
        }
    }
}

private final class ProviderTaggedTranscriptionSession: TranscriptionSession, @unchecked Sendable {
    let resolvedProviderIdentifier: String?
    private let base: any TranscriptionSession
    var transcriptUpdates: AsyncThrowingStream<TranscriptUpdate, Error> { base.transcriptUpdates }

    init(base: any TranscriptionSession, identifier: String) {
        self.base = base
        resolvedProviderIdentifier = identifier
    }

    func sendAudio(_ data: Data) async throws { try await base.sendAudio(data) }
    func finish() async throws -> FinalizedTranscript { try await base.finish() }
}
