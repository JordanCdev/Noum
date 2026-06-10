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
    func endAudio() async throws
    var transcriptUpdates: AsyncStream<TranscriptUpdate> { get }
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
