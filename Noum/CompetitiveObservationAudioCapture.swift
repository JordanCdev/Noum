import Foundation
#if canImport(AVFoundation)
import AVFoundation

/// Fixed wire format for the server-observed competitive-rep path.
///
/// This is deliberately separate from the live transcription provider's
/// device-rate stream. The existing microphone tap feeds both consumers; no
/// second recorder or persisted audio file is created.
struct CompetitiveObservationAudioPayload: Equatable, Sendable {
    static let sampleRate = 16_000
    static let channelCount = 1
    static let bytesPerSample = MemoryLayout<Int16>.size
    static let minimumByteCount = 8_000
    static let maximumDuration: TimeInterval = 150
    static let maximumByteCount = sampleRate
        * channelCount
        * bytesPerSample
        * Int(maximumDuration)

    let pcm16Mono: Data
    let sampleRate: Int
    let channelCount: Int

    var isCanonical: Bool {
        sampleRate == Self.sampleRate
            && channelCount == Self.channelCount
            && pcm16Mono.count >= Self.minimumByteCount
            && pcm16Mono.count <= Self.maximumByteCount
            && pcm16Mono.count.isMultiple(of: Self.bytesPerSample)
    }

    var duration: TimeInterval {
        Double(pcm16Mono.count)
            / Double(sampleRate * channelCount * Self.bytesPerSample)
    }
}

enum CompetitiveObservationAudioAppendResult: Equatable, Sendable {
    case accepted
    /// Once the bound is crossed, the whole competitive observation is
    /// invalidated. A truncated clip must never be submitted as a complete
    /// competitive rep; the ordinary private-practice path can still finish.
    case invalidatedByLimit
    case invalidFormat
    case discarded
}

/// Bounded, memory-only downsampler fed from `SpeechRecognizerViewModel`'s
/// existing input tap. It performs a conservative box-filter downsample to
/// mono 16 kHz signed PCM and never touches disk or another audio session.
///
/// `NSLock` protects the callback-owned buffer from teardown/finalization.
/// The critical section has no suspension points and the production bound is
/// fixed at 4.8 MB (150 seconds).
final class CompetitiveObservationAudioCapture: @unchecked Sendable {
    private struct State {
        var pcm16Mono = Data()
        var phase = 0.0
        var pendingSampleSum: Double = 0
        var pendingSampleCount = 0
        var invalidated = false
        var discarded = false
    }

    private let lock = NSLock()
    private let sourceSampleRate: Double
    private let sourceChannelCount: Int
    private let maximumByteCount: Int
    private var state = State()

    init?(
        inputFormat: AVAudioFormat,
        maximumByteCount: Int = CompetitiveObservationAudioPayload.maximumByteCount
    ) {
        guard inputFormat.sampleRate.isFinite,
              inputFormat.sampleRate > 0,
              inputFormat.channelCount > 0,
              maximumByteCount >= CompetitiveObservationAudioPayload.bytesPerSample else {
            return nil
        }
        sourceSampleRate = inputFormat.sampleRate
        sourceChannelCount = Int(inputFormat.channelCount)
        self.maximumByteCount = maximumByteCount
    }

    @discardableResult
    func append(_ buffer: AVAudioPCMBuffer) -> CompetitiveObservationAudioAppendResult {
        lock.withLock {
            guard !state.discarded else { return .discarded }
            guard !state.invalidated else { return .invalidatedByLimit }
            guard buffer.format.sampleRate == sourceSampleRate,
                  Int(buffer.format.channelCount) == sourceChannelCount,
                  let channels = buffer.floatChannelData else {
                state.invalidated = true
                state.pcm16Mono.removeAll(keepingCapacity: false)
                return .invalidFormat
            }

            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return .accepted }
            var converted: [Int16] = []
            converted.reserveCapacity(
                Int(ceil(Double(frameCount) * Double(CompetitiveObservationAudioPayload.sampleRate) / sourceSampleRate)) + 1
            )

            for frame in 0..<frameCount {
                var mono = 0.0
                for channel in 0..<sourceChannelCount {
                    let sample = buffer.format.isInterleaved
                        ? channels[0][(frame * sourceChannelCount) + channel]
                        : channels[channel][frame]
                    mono += Double(sample)
                }
                mono /= Double(sourceChannelCount)
                mono = min(max(mono, -1), 1)

                state.pendingSampleSum += mono
                state.pendingSampleCount += 1
                state.phase += Double(CompetitiveObservationAudioPayload.sampleRate)

                while state.phase >= sourceSampleRate {
                    let averaged = state.pendingSampleCount > 0
                        ? state.pendingSampleSum / Double(state.pendingSampleCount)
                        : mono
                    let scaled = averaged >= 0
                        ? averaged * Double(Int16.max)
                        : averaged * 32_768.0
                    converted.append(Int16(clamping: Int(scaled.rounded())).littleEndian)
                    state.phase -= sourceSampleRate
                    state.pendingSampleSum = 0
                    state.pendingSampleCount = 0
                }
            }

            let addedByteCount = converted.count * CompetitiveObservationAudioPayload.bytesPerSample
            guard state.pcm16Mono.count <= maximumByteCount - addedByteCount else {
                state.invalidated = true
                state.pcm16Mono.removeAll(keepingCapacity: false)
                return .invalidatedByLimit
            }
            converted.withUnsafeBytes { state.pcm16Mono.append(contentsOf: $0) }
            return .accepted
        }
    }

    /// Consume the only in-memory copy. Calling this twice, crossing the size
    /// bound, receiving an incompatible format, or discarding returns nil.
    func consume() -> CompetitiveObservationAudioPayload? {
        lock.withLock {
            guard !state.discarded,
                  !state.invalidated,
                  !state.pcm16Mono.isEmpty,
                  state.pcm16Mono.count.isMultiple(of: CompetitiveObservationAudioPayload.bytesPerSample) else {
                state.discarded = true
                state.pcm16Mono.removeAll(keepingCapacity: false)
                return nil
            }
            let data = state.pcm16Mono
            state.discarded = true
            state.pcm16Mono.removeAll(keepingCapacity: false)
            return CompetitiveObservationAudioPayload(
                pcm16Mono: data,
                sampleRate: CompetitiveObservationAudioPayload.sampleRate,
                channelCount: CompetitiveObservationAudioPayload.channelCount
            )
        }
    }

    func discard() {
        lock.withLock {
            state.discarded = true
            state.pcm16Mono.removeAll(keepingCapacity: false)
            state.pendingSampleSum = 0
            state.pendingSampleCount = 0
        }
    }
}
#endif
