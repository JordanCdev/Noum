import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

// MARK: - Pitch / Intonation
//
// On-device pitch tracker for M10 (Pitch / intonation v1). Runs alongside
// the existing transcription pipeline. The audio tap callback hands a
// copy of each buffer to a `PitchAnalyzer`, which slices it into 50 ms
// windows (25 ms hop) and runs an autocorrelation-based pitch estimator
// over each window using `Accelerate` (vDSP).
//
// Only voiced frames produce a pitch reading; unvoiced (silence,
// fricatives, noise) frames are dropped. The resulting `[PitchPoint]`
// track is condensed into `IntonationMetrics` at session finalize.
//
// Privacy posture: every line of analysis runs in-process. Audio samples
// never leave the device for pitch — the only network traffic is the
// existing transcription stream.

struct PitchPoint: Equatable {
    /// Seconds since session start.
    let time: TimeInterval
    /// Estimated f0 in Hz. `nil` when the frame is unvoiced.
    let hz: Double?
}

struct IntonationMetrics: Codable, Equatable {
    /// Number of voiced 50 ms windows analysed.
    let voicedFrameCount: Int
    /// Total voiced time in seconds (voicedFrameCount × hopSeconds).
    let voicedSeconds: Double
    /// Median pitch across voiced frames, Hz.
    let medianHz: Double
    /// Standard deviation of pitch across voiced frames in semitones.
    /// Lower → more monotone delivery. Higher → more varied.
    let stddevSemitones: Double
    /// Pitch range (10th–90th percentile) in semitones.
    /// Robust to single-frame jumps that would dominate min/max.
    let rangeSemitones: Double
    /// 0–100 monotone-vs-varied score. 0 = perfectly flat, 100 = highly
    /// varied. Maps `stddevSemitones` against a coaching reference range.
    let varietyScore: Int

    static let empty = IntonationMetrics(
        voicedFrameCount: 0,
        voicedSeconds: 0,
        medianHz: 0,
        stddevSemitones: 0,
        rangeSemitones: 0,
        varietyScore: 0
    )

    /// Minimum voiced frames needed to publish honest metrics. Below this
    /// we suppress the card rather than showing noise.
    static let minimumVoicedFrames: Int = 12

    /// Reference upper-bound for `stddevSemitones` in the variety score.
    /// Strong speakers tend to show ~2.0–2.5 semitones of pitch stddev
    /// across an answer; trained / dramatic delivery can reach 3+.
    /// Capping at 3.0 keeps the score interpretable: 50 = average,
    /// 100 = highly expressive.
    static let varietyReferenceSemitones: Double = 3.0

    /// Compute from an analyser's pitch track.
    /// Returns `nil` when there isn't enough voiced material to be honest
    /// about it (e.g. a 10-word reply, mostly silence).
    static func compute(from track: [PitchPoint], hopSeconds: Double = 0.025) -> IntonationMetrics? {
        let voiced = track.compactMap { $0.hz }.filter { $0 > 0 }
        guard voiced.count >= minimumVoicedFrames else { return nil }

        let median = Self.median(voiced)
        guard median > 0 else { return nil }

        let semis = voiced.map { 12.0 * log2($0 / median) }
        let mean = semis.reduce(0, +) / Double(semis.count)
        let variance = semis.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(semis.count)
        let stddev = variance.squareRoot()
        let p10 = Self.percentile(semis, 0.10)
        let p90 = Self.percentile(semis, 0.90)
        let range = max(0, p90 - p10)

        let normalized = min(1.0, stddev / varietyReferenceSemitones)
        let score = Int((normalized * 100).rounded())

        return IntonationMetrics(
            voicedFrameCount: voiced.count,
            voicedSeconds: Double(voiced.count) * hopSeconds,
            medianHz: median,
            stddevSemitones: stddev,
            rangeSemitones: range,
            varietyScore: score
        )
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            return sorted[mid]
        }
    }

    private static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let rank = max(0, min(Double(sorted.count - 1), p * Double(sorted.count - 1)))
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        if lower == upper { return sorted[lower] }
        let frac = rank - Double(lower)
        return sorted[lower] * (1 - frac) + sorted[upper] * frac
    }
}

// MARK: - Coaching read

extension IntonationMetrics {
    /// Short, on-voice headline for the summary card. Avoids fake
    /// certainty when sample size is small.
    var headline: String {
        if voicedFrameCount < Self.minimumVoicedFrames { return "Not enough voiced audio to read" }
        switch varietyScore {
        case ..<20: return "Delivery ran flat"
        case 20..<40: return "Mostly even, room to lift"
        case 40..<65: return "Steady with some variety"
        case 65..<85: return "Engaged, varied delivery"
        default: return "Wide-range expressive read"
        }
    }

    /// One-sentence body explaining what the numbers mean for coaching.
    var coachLine: String {
        if voicedFrameCount < Self.minimumVoicedFrames {
            return "Speak for a longer, more sustained answer next rep so we can read your pitch shape."
        }
        switch varietyScore {
        case ..<20:
            return "Pitch held within roughly \(formatSemis(rangeSemitones)) — listeners read flat delivery as low conviction. Try landing one key word with extra emphasis next rep."
        case 20..<40:
            return "There is some movement, around \(formatSemis(stddevSemitones)) of variation. Lifting on the most important phrase will make the point land harder."
        case 40..<65:
            return "Variation is honest and conversational. Hold this and pick one moment per answer for a clearly higher or lower line."
        case 65..<85:
            return "Your pitch is doing real work — the answer reads engaged. Keep the variation tied to meaning, not nerves."
        default:
            return "Wide expressive range. Watch you don't oversell — varied is good when the variation tracks what actually matters."
        }
    }

    private func formatSemis(_ value: Double) -> String {
        if value < 1 { return String(format: "%.1f semitones", value) }
        return String(format: "%.0f semitones", value)
    }
}

// MARK: - Analyser
//
// Stateful, thread-safe pitch tracker. The audio tap copies samples and
// hands them off via `process(samples:)`; processing happens on whatever
// queue the caller routes us to (we recommend a dedicated serial queue,
// not the audio thread). Internally we keep a running buffer and slide
// 50 ms windows with 25 ms hop.

final class PitchAnalyzer {
    private let sampleRate: Double
    private let frameSize: Int
    private let hopSize: Int
    /// `hopSeconds` is the per-pitch-point time advance. Exposed so
    /// `IntonationMetrics.compute` can convert frame counts to seconds.
    let hopSeconds: Double
    private let minLag: Int
    private let maxLag: Int
    /// Voicing gate — minimum RMS for a window to be considered.
    /// ~ -46 dBFS, well above mic noise floor on iPhone.
    private let rmsGate: Float = 0.005
    /// Normalised peak-to-zero-lag ratio above which a frame is voiced.
    /// 0.5 is conservative; speech usually shows 0.6+ on voiced frames.
    private let nccGate: Float = 0.5

    private var pendingSamples: [Float] = []
    private var samplesAdvanced: Int = 0
    private var trackStorage: [PitchPoint] = []
    private let lock = NSLock()

    init(sampleRate: Double) {
        // Clamp sample rate to a sane range. iOS hardware emits 16 kHz
        // (some Bluetooth) up to 48 kHz; we don't want to blow up on
        // weird inputs.
        let safeRate = max(8000, min(96000, sampleRate))
        self.sampleRate = safeRate
        self.frameSize = Int(safeRate * 0.05)
        self.hopSize = Int(safeRate * 0.025)
        self.hopSeconds = Double(self.hopSize) / safeRate
        // Human pitch range: ~75 Hz (low male) to ~400 Hz (high female).
        self.minLag = max(1, Int(safeRate / 400.0))
        self.maxLag = max(self.minLag + 1, Int(safeRate / 75.0))
        self.pendingSamples.reserveCapacity(self.frameSize * 4)
    }

    /// Append a copy of audio samples produced by the input tap. Caller
    /// is responsible for copying out of the `AVAudioPCMBuffer` — buffer
    /// memory is reused by AVFoundation across callbacks.
    func process(samples: [Float]) {
        lock.lock(); defer { lock.unlock() }
        pendingSamples.append(contentsOf: samples)
        while pendingSamples.count >= frameSize {
            let frame = Array(pendingSamples.prefix(frameSize))
            let estimate = Self.estimatePitch(
                frame: frame,
                sampleRate: sampleRate,
                minLag: minLag,
                maxLag: maxLag,
                rmsGate: rmsGate,
                nccGate: nccGate
            )
            let elapsed = Double(samplesAdvanced) / sampleRate
            trackStorage.append(PitchPoint(time: elapsed, hz: estimate))
            pendingSamples.removeFirst(hopSize)
            samplesAdvanced += hopSize
        }
    }

    /// Snapshot of the pitch track so far. Cheap copy.
    func snapshot() -> [PitchPoint] {
        lock.lock(); defer { lock.unlock() }
        return trackStorage
    }

    /// Reset accumulated state. Call before reusing the analyser.
    func reset() {
        lock.lock(); defer { lock.unlock() }
        pendingSamples.removeAll(keepingCapacity: true)
        trackStorage.removeAll(keepingCapacity: true)
        samplesAdvanced = 0
    }

    // MARK: - Estimator

    /// Estimate pitch for a single frame using autocorrelation. Returns
    /// `nil` for unvoiced frames (silence, fricatives, low correlation).
    static func estimatePitch(
        frame: [Float],
        sampleRate: Double,
        minLag: Int,
        maxLag: Int,
        rmsGate: Float = 0.005,
        nccGate: Float = 0.5
    ) -> Double? {
        guard frame.count > maxLag + 1 else { return nil }
        #if canImport(Accelerate)
        var rms: Float = 0
        vDSP_rmsqv(frame, 1, &rms, vDSP_Length(frame.count))
        guard rms > rmsGate else { return nil }

        // Hanning window dampens edge artefacts in autocorrelation.
        var window = [Float](repeating: 0, count: frame.count)
        vDSP_hann_window(&window, vDSP_Length(frame.count), Int32(vDSP_HANN_NORM))
        var windowed = [Float](repeating: 0, count: frame.count)
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(frame.count))

        var zeroLag: Float = 0
        vDSP_svesq(windowed, 1, &zeroLag, vDSP_Length(windowed.count))
        guard zeroLag > 1e-8 else { return nil }

        var bestLag = minLag
        var bestValue: Float = -.infinity
        windowed.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for lag in minLag...maxLag {
                var dot: Float = 0
                vDSP_dotpr(base, 1, base.advanced(by: lag), 1, &dot, vDSP_Length(windowed.count - lag))
                if dot > bestValue {
                    bestValue = dot
                    bestLag = lag
                }
            }
        }

        let ncc = bestValue / zeroLag
        guard ncc > nccGate else { return nil }

        // Parabolic interpolation around the peak for sub-sample lag,
        // which sharpens pitch resolution especially at higher f0.
        let refinedLag = parabolicRefine(
            samples: windowed,
            centerLag: bestLag,
            minLag: minLag,
            maxLag: maxLag
        )
        guard refinedLag > 0 else { return nil }
        return sampleRate / refinedLag
        #else
        return nil
        #endif
    }

    private static func parabolicRefine(
        samples: [Float],
        centerLag: Int,
        minLag: Int,
        maxLag: Int
    ) -> Double {
        guard centerLag > minLag, centerLag < maxLag else { return Double(centerLag) }
        let n = samples.count
        func dot(_ lag: Int) -> Float {
            var v: Float = 0
            samples.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                #if canImport(Accelerate)
                vDSP_dotpr(base, 1, base.advanced(by: lag), 1, &v, vDSP_Length(n - lag))
                #endif
            }
            return v
        }
        let yMinus = dot(centerLag - 1)
        let yCenter = dot(centerLag)
        let yPlus = dot(centerLag + 1)
        let denom = (yMinus - 2 * yCenter + yPlus)
        guard denom != 0 else { return Double(centerLag) }
        let offset = 0.5 * Double((yMinus - yPlus) / denom)
        // Clamp offset to ±1 — anything larger means the peak isn't
        // really at `centerLag` and refinement would do more harm
        // than good.
        let clamped = max(-1.0, min(1.0, offset))
        return Double(centerLag) + clamped
    }
}
