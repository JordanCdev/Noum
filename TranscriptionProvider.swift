import Foundation

// MARK: - Provider Protocol

/// Abstraction over speech-to-text services (AWS, Deepgram, Google).
/// Each provider creates a session that streams audio in and transcript updates out.
protocol TranscriptionProvider: Sendable {
    var name: String { get }
    var identifier: String { get }  // "aws", "deepgram", "google"
    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession
}

// MARK: - Session Protocol

/// A live transcription session. Send audio data and receive transcript updates.
protocol TranscriptionSession: AnyObject, Sendable {
    func sendAudio(_ data: Data) async throws
    /// Finishes the provider stream and waits for its terminal response. A
    /// successful return means the provider accepted the audio and completed
    /// its own finalization; it does not imply that speech was detected.
    func finish() async throws -> FinalizedTranscript
    var transcriptUpdates: AsyncThrowingStream<TranscriptUpdate, Error> { get }
}

// MARK: - Configuration

struct TranscriptionConfig: Sendable {
    let languageCode: String          // "en-US"
    let sampleRate: Int               // from AVAudioSession
    let encoding: AudioEncoding
    let enableFillerWordDetection: Bool  // provider-level filler detection (Deepgram)

    enum AudioEncoding: Sendable {
        case pcmSigned16Bit
    }
}

// MARK: - Transcript Events

struct TranscriptUpdate: Sendable {
    let text: String
    let isFinal: Bool
    let confidence: Double?           // 0.0-1.0, nil if provider doesn't report
    let words: [WordTiming]?          // word-level detail when available
    let providerFillerWords: [String]? // fillers detected by the provider itself (e.g. Deepgram)
    let latencyMs: Int?               // time from audio send to transcript receive

    struct WordTiming: Sendable {
        let word: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Double?
    }
}

/// Provider-level terminal receipt. Views must require both captured audio and
/// usable speech before treating a rep as complete; a clean provider close with
/// silence is intentionally represented as a successful but unusable result.
struct FinalizedTranscript: Sendable, Equatable {
    let text: String
    let receivedFinalResult: Bool
    let audioByteCount: Int

    var hasCapturedAudio: Bool { audioByteCount > 0 }

    var hasUsableSpeech: Bool {
        hasCapturedAudio
            && receivedFinalResult
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Single gate shared by persistence, scoring, pressure outcomes, and XP.
/// Keeping it pure makes every mode's trust boundary independently testable.
enum RecordingCompletionGate {
    static func allowsScoringAndProgress(_ result: FinalizedTranscript?) -> Bool {
        result?.hasUsableSpeech == true
    }
}

/// Shared precondition for countdown/timer engines. A view can request a
/// phase change at any time, but an engine may only start consuming the
/// user's response window after provider and microphone readiness is true.
enum RecordingStartGate {
    static func allowsTimerStart(captureReady: Bool) -> Bool { captureReady }
}

/// Defense-in-depth service gate. Callers check early for better UX, and each
/// cloud provider checks again immediately before opening a network session so
/// a future call site cannot bypass the account's consent decision.
@MainActor
enum CloudTranscriptionConsentGate {
    static func requireAllowed() throws {
        guard AISettingsManager.shared.isCloudProcessingAllowed else {
            throw TranscriptionSessionError.cloudProcessingConsentRequired
        }
    }
}

enum TranscriptionSessionError: LocalizedError, Sendable, Equatable {
    case notReady
    case alreadyFinished
    case cloudProcessingConsentRequired
    case transport(String)
    case invalidResponse
    case finalizationTimedOut

    var errorDescription: String? {
        switch self {
        case .notReady:
            return "The transcription connection is not ready."
        case .alreadyFinished:
            return "The transcription session has already finished."
        case .cloudProcessingConsentRequired:
            return "Cloud processing is off. Turn it on in Settings to use live transcription."
        case .transport(let reason):
            return reason
        case .invalidResponse:
            return "The transcription service returned an unreadable response."
        case .finalizationTimedOut:
            return "The transcription service did not finish in time."
        }
    }
}

/// Thread-safe terminal aggregation shared by provider implementations. It
/// keeps stream callbacks, `finish()`, and timeout races on one exactly-once
/// result without introducing a second app-level state owner.
final class TranscriptionTerminalState: @unchecked Sendable {
    private struct State {
        var audioByteCount = 0
        var finalSegments: [String] = []
        var receivedFinalResult = false
        var result: Result<FinalizedTranscript, Error>?
        var waiters: [CheckedContinuation<FinalizedTranscript, Error>] = []
    }

    private let lock = NSLock()
    private var state = State()

    func noteAudio(bytes: Int) {
        guard bytes > 0 else { return }
        lock.withLock { state.audioByteCount += bytes }
    }

    func note(_ update: TranscriptUpdate) {
        guard update.isFinal else { return }
        let text = update.text.trimmingCharacters(in: .whitespacesAndNewlines)
        lock.withLock {
            state.receivedFinalResult = true
            if !text.isEmpty { state.finalSegments.append(text) }
        }
    }

    func succeed() {
        let result: FinalizedTranscript = lock.withLock {
            FinalizedTranscript(
                text: state.finalSegments.joined(separator: " "),
                receivedFinalResult: state.receivedFinalResult,
                audioByteCount: state.audioByteCount
            )
        }
        complete(.success(result))
    }

    func fail(_ error: Error) {
        complete(.failure(error))
    }

    func wait(timeout: Duration) async throws -> FinalizedTranscript {
        try await withCheckedThrowingContinuation { continuation in
            let immediate: Result<FinalizedTranscript, Error>? = lock.withLock {
                if let result = state.result { return result }
                state.waiters.append(continuation)
                return nil
            }
            if let immediate { continuation.resume(with: immediate) }

            Task.detached { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.fail(TranscriptionSessionError.finalizationTimedOut)
            }
        }
    }

    private func complete(_ result: Result<FinalizedTranscript, Error>) {
        let waiters: [CheckedContinuation<FinalizedTranscript, Error>] = lock.withLock {
            guard state.result == nil else { return [] }
            state.result = result
            let pending = state.waiters
            state.waiters.removeAll()
            return pending
        }
        waiters.forEach { $0.resume(with: result) }
    }
}

/// Exactly-once readiness gate for providers whose constructors begin an
/// asynchronous handshake (Deepgram WebSocket and AWS streaming).
final class TranscriptionReadinessGate: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Void, Error>?
    private var waiters: [CheckedContinuation<Void, Error>] = []

    func succeed() { complete(.success(())) }
    func fail(_ error: Error) { complete(.failure(error)) }

    func wait(timeout: Duration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let immediate: Result<Void, Error>? = lock.withLock {
                if let result { return result }
                waiters.append(continuation)
                return nil
            }
            if let immediate { continuation.resume(with: immediate) }

            Task.detached { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.fail(TranscriptionSessionError.transport("The transcription connection timed out."))
            }
        }
    }

    private func complete(_ result: Result<Void, Error>) {
        let pending: [CheckedContinuation<Void, Error>] = lock.withLock {
            guard self.result == nil else { return [] }
            self.result = result
            let pending = waiters
            waiters.removeAll()
            return pending
        }
        pending.forEach { $0.resume(with: result) }
    }
}

/// Lossless, ordered bridge from a realtime audio callback to an async
/// provider session. Audio taps cannot await, and spawning one unstructured
/// task per buffer can reorder chunks or race CloseStream. This pump accepts
/// buffers synchronously, sends them from one consumer, and can be drained
/// before `finish()` is invoked.
final class TranscriptionAudioPump: @unchecked Sendable {
    private let continuation: AsyncStream<Data>.Continuation
    private var consumerTask: Task<Void, Error>?

    init(
        session: any TranscriptionSession,
        onFailure: @escaping @Sendable (Error) -> Void
    ) {
        var capturedContinuation: AsyncStream<Data>.Continuation!
        let stream = AsyncStream<Data>(bufferingPolicy: .bufferingNewest(256)) {
            capturedContinuation = $0
        }
        continuation = capturedContinuation
        consumerTask = Task.detached {
            do {
                for await data in stream {
                    try Task.checkCancellation()
                    try await session.sendAudio(data)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                onFailure(error)
                throw error
            }
        }
    }

    deinit {
        continuation.finish()
        consumerTask?.cancel()
    }

    @discardableResult
    func enqueue(_ data: Data) -> Bool {
        guard !data.isEmpty else { return true }
        switch continuation.yield(data) {
        case .enqueued: return true
        case .dropped, .terminated: return false
        @unknown default: return false
        }
    }

    func finish() async throws {
        continuation.finish()
        try await consumerTask?.value
        consumerTask = nil
    }

    func cancel() {
        continuation.finish()
        consumerTask?.cancel()
        consumerTask = nil
    }
}

// MARK: - Provider Registry

enum TranscriptionProviderID: String, CaseIterable, Identifiable, Codable {
    case aws = "aws"
    case deepgram = "deepgram"
    case google = "google"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aws: return "AWS Transcribe"
        case .deepgram: return "Deepgram Nova-2"
        case .google: return "Google Cloud Speech"
        }
    }

    /// Canonical mapping from the persisted `"transcriptionProvider"`
    /// UserDefaults string to a provider ID. Single source of truth shared
    /// by practice reps (`SpeechRecognizerViewModel`) and the live coach
    /// call (`AskNoumVoiceInput`) so the two surfaces can never resolve a
    /// different provider from the same stored value. Mirrors the historic
    /// behavior exactly: unset → Deepgram (the default), unknown → AWS.
    static func resolved(fromStoredValue raw: String?) -> TranscriptionProviderID {
        switch raw {
        case nil, TranscriptionProviderID.deepgram.rawValue:
            return .deepgram
        case TranscriptionProviderID.google.rawValue:
            return .google
        default:
            return .aws
        }
    }
}

// MARK: - Quality Metrics (for benchmarking)

struct TranscriptionQualityMetrics: Codable {
    let provider: String
    let sessionId: UUID
    let date: Date
    let totalLatencyMs: Int           // avg latency per update
    let finalTranscriptLength: Int    // word count
    let fillerWordsDetected: Int      // by FillerWordDetector (consistent across providers)
    let providerFillersDetected: Int  // by provider's native detection
    let averageConfidence: Double?
    let sessionDuration: TimeInterval
}

// MARK: - Quality Metrics Store

@MainActor
final class TranscriptionQualityStore {
    static let shared = TranscriptionQualityStore()
    private init() {}

    private(set) var metrics: [TranscriptionQualityMetrics] = []

    func record(_ metric: TranscriptionQualityMetrics) {
        metrics.append(metric)
        // Keep last 50 entries
        if metrics.count > 50 {
            metrics.removeFirst(metrics.count - 50)
        }
        save()
    }

    func averageLatency(for provider: String) -> Int? {
        let matching = metrics.filter { $0.provider == provider }
        guard !matching.isEmpty else { return nil }
        return matching.map(\.totalLatencyMs).reduce(0, +) / matching.count
    }

    func averageConfidence(for provider: String) -> Double? {
        let matching = metrics.filter { $0.provider == provider }.compactMap(\.averageConfidence)
        guard !matching.isEmpty else { return nil }
        return matching.reduce(0, +) / Double(matching.count)
    }

    // MARK: - Persistence

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("transcription_quality_metrics.json")
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TranscriptionQualityMetrics].self, from: data) else { return }
        metrics = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(metrics) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
