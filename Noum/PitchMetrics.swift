import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

// MARK: - Pitch Metrics
//
// M10 — Pitch / intonation v1.
//
// Computes pitch (fundamental-frequency) statistics over the just-finished
// session. Pitch is the third leg of "how it sounds when you speak" alongside
// fillers and pace, and it is the most differentiating signal vs. competitors:
// listeners read flat delivery as low-confidence even when the words are right.
//
// Pipeline (all on-device, all in-process — no new privacy implications):
// 1. Capture path feeds raw mono Float32 PCM at the audio engine's sample rate
//    into a `PitchTracker`.
// 2. The tracker buffers samples into ~50ms windows (Hann-weighted) and runs
//    autocorrelation via `vDSP_conv` to estimate F0.
// 3. Voiced windows (those with enough periodicity strength) contribute to a
//    pitch track. Unvoiced ones (silence, breath, fricatives) are dropped.
// 4. At finalize, the track is reduced to a small `PitchMetrics` struct
//    (5 numbers) so it can persist on every `PracticeSession` without
//    blowing up UserDefaults.
//
// "Monotone vs varied" score:
//   The standard deviation of pitch in semitones across voiced frames maps to
//   a 0...1 variety score. ≤1 ST is robotically flat; ≥4 ST is rich and
//   expressive. We use a soft logistic so a single outlier note doesn't push
//   a flat speaker into "varied" territory.

struct PitchMetrics: Codable, Equatable {
    /// Mean fundamental in Hz across voiced frames. 0 when unvoiced.
    let meanHz: Double
    /// Total voiced duration in seconds — how much of the rep had readable pitch.
    let voicedSeconds: Double
    /// Standard deviation of pitch in semitones across voiced frames.
    /// This is the raw "varied vs monotone" signal: ≤1 = robotic, 2 = present,
    /// ≥4 = expressive.
    let semitoneStdDev: Double
    /// 0...1 variety score. 0 = monotone, 1 = highly varied. Derived from
    /// `semitoneStdDev` via a soft logistic so a single outlier note can't
    /// push a flat speaker into "varied" territory.
    let varietyScore: Double
    /// Pitch range covered, in semitones (max − min across voiced frames).
    /// Useful in the coach line; doesn't drive the score on its own.
    let rangeSemitones: Double

    static let empty = PitchMetrics(
        meanHz: 0,
        voicedSeconds: 0,
        semitoneStdDev: 0,
        varietyScore: 0,
        rangeSemitones: 0
    )

    /// Minimum voiced time before we trust the metrics. Below this we treat
    /// the rep as unmeasurable rather than reading false certainty into a
    /// few stray frames.
    static let minVoicedSecondsForReadout: Double = 4.0

    /// Whether there is enough voiced data to surface this card.
    var hasReadableSignal: Bool {
        voicedSeconds >= Self.minVoicedSecondsForReadout
    }
}

// MARK: - Reduction from raw frames

extension PitchMetrics {
    /// Build a `PitchMetrics` from a raw pitch track. `frameDuration` is the
    /// hop size in seconds the tracker emitted at — typically 0.025s
    /// (25ms hop on a 50ms window).
    static func reduce(
        frames: [PitchTracker.Frame],
        frameDuration: Double
    ) -> PitchMetrics {
        let voiced = frames.filter { $0.isVoiced && $0.frequencyHz > 0 }
        guard !voiced.isEmpty else { return .empty }

        let voicedSeconds = Double(voiced.count) * frameDuration
        let hzValues = voiced.map(\.frequencyHz)
        let meanHz = hzValues.reduce(0, +) / Double(hzValues.count)

        // Convert each Hz to semitones relative to the median, so a male and
        // female speaker normalise the same way. Median (not mean) keeps a
        // single octave-error from skewing the centre.
        let sortedHz = hzValues.sorted()
        let medianHz = sortedHz[sortedHz.count / 2]
        guard medianHz > 0 else { return .empty }

        let semitones = hzValues.map { 12.0 * log2(max($0, 1) / medianHz) }
        let mean = semitones.reduce(0, +) / Double(semitones.count)
        let variance = semitones.map { pow($0 - mean, 2) }.reduce(0, +) / Double(semitones.count)
        let stdDev = sqrt(variance)

        let lo = semitones.min() ?? 0
        let hi = semitones.max() ?? 0
        let range = hi - lo

        // Variety score: soft logistic centred at ~2.0 ST. <1 ST → near 0
        // (monotone); 2 ST → ~0.5 (present); ≥4 ST → near 1 (varied).
        let variety = 1.0 / (1.0 + exp(-1.5 * (stdDev - 2.0)))

        return PitchMetrics(
            meanHz: meanHz,
            voicedSeconds: voicedSeconds,
            semitoneStdDev: stdDev,
            varietyScore: max(0, min(1, variety)),
            rangeSemitones: range
        )
    }
}

// MARK: - Coaching read

extension PitchMetrics {
    /// Short, on-voice headline for the summary card. Mirrors the pause
    /// card's pattern — never claims certainty when the signal is thin.
    var headline: String {
        guard hasReadableSignal else { return "Pitch read: not enough voiced audio" }
        if varietyScore < 0.25 { return "Flat delivery — room to vary the line" }
        if varietyScore < 0.55 { return "Pitch is moving, but mostly mid-range" }
        if varietyScore < 0.80 { return "Varied, expressive delivery" }
        return "Rich melodic range across the rep"
    }

    /// One-sentence body explaining what the numbers mean for coaching.
    var coachLine: String {
        guard hasReadableSignal else {
            return "Most of the rep was breath, silence, or whisper. Speak a little louder on the next one so pitch can be read."
        }
        if varietyScore < 0.25 {
            return "Pitch held within \(formatST(semitoneStdDev)) of centre. Try lifting one key word per sentence — listeners read flat delivery as uncertain."
        }
        if varietyScore < 0.55 {
            return "You moved across \(formatST(rangeSemitones)). One extra emphasis per point would push this from 'present' to 'compelling'."
        }
        if varietyScore < 0.80 {
            return "Pitch ranged \(formatST(rangeSemitones)) across the rep — that's the sound of a confident speaker."
        }
        return "Range of \(formatST(rangeSemitones)) — strong vocal variety. The line is doing real work for you."
    }

    /// Compact 0–100 percentile for UI tags ("Pitch 64").
    var displayScore: Int {
        Int((varietyScore * 100).rounded())
    }

    private func formatST(_ value: Double) -> String {
        if value >= 10 { return String(format: "%.0f ST", value) }
        return String(format: "%.1f ST", value)
    }
}

// MARK: - On-device pitch tracker

/// Real-time pitch tracker. Buffers mono Float32 PCM, runs autocorrelation
/// on overlapping ~50ms windows, and emits voiced/unvoiced `Frame`s.
///
/// Designed to be fed from the same `inputNode.installTap` callback the
/// transcription provider already uses — we don't open a second audio
/// session, we just multiplex the existing one. Heavy math runs on a
/// dedicated serial queue so the audio thread stays unblocked.
final class PitchTracker {

    struct Frame: Equatable {
        let isVoiced: Bool
        let frequencyHz: Double
    }

    /// Voicing threshold: ratio of best-lag autocorrelation to lag-0
    /// energy. Below this, the window is treated as unvoiced.
    private let voicingThreshold: Double = 0.3
    /// Minimum F0 we'll detect (deeper male speakers ~80 Hz).
    private let minHz: Double = 70
    /// Maximum F0 we'll detect (high female speakers ~400 Hz; clamp to 500
    /// to keep autocorrelation lag bounds tight).
    private let maxHz: Double = 500

    /// Window length in seconds. 50ms gives stable autocorrelation while
    /// remaining responsive enough to track natural speech contour.
    private let windowSeconds: Double = 0.050
    /// Hop in seconds. 50% overlap (25ms) gives a smooth pitch track.
    private let hopSeconds: Double = 0.025

    /// The sample rate this tracker was configured for. Read by the
    /// audio capture path so it can detect a format change between
    /// sessions and rebuild the tracker rather than feeding mismatched
    /// samples into the autocorrelator.
    let sampleRate: Double
    private let windowSize: Int
    private let hopSize: Int
    private let minLag: Int
    private let maxLag: Int

    /// Pre-computed Hann window for the current window size.
    private let hannWindow: [Float]

    /// Rolling buffer of incoming samples, drained as windows are completed.
    /// Access guarded by `bufferQueue`.
    private var buffer: [Float] = []
    private let bufferQueue = DispatchQueue(label: "com.jordancoaten.noum.pitch", qos: .userInitiated)

    /// All voiced/unvoiced frames produced so far for this session.
    private var frames: [Frame] = []

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.windowSize = max(64, Int((windowSeconds * sampleRate).rounded()))
        self.hopSize = max(32, Int((hopSeconds * sampleRate).rounded()))
        self.minLag = max(1, Int((sampleRate / maxHz).rounded()))
        self.maxLag = min(windowSize - 1, Int((sampleRate / minHz).rounded()))
        self.hannWindow = Self.makeHannWindow(size: windowSize)
        self.buffer.reserveCapacity(windowSize * 4)
    }

    /// The hop size in seconds — what each emitted frame represents.
    /// `PitchMetrics.reduce` needs this to compute voiced seconds.
    var frameDuration: Double { hopSeconds }

    /// Append a new chunk of audio. Safe to call from the audio thread.
    func ingest(_ samples: UnsafePointer<Float>, count: Int) {
        let chunk = Array(UnsafeBufferPointer(start: samples, count: count))
        bufferQueue.async { [weak self] in
            self?.buffer.append(contentsOf: chunk)
            self?.drainCompletedWindows()
        }
    }

    /// Convenience for callers that already have an `[Float]` slice.
    func ingest(samples: [Float]) {
        bufferQueue.async { [weak self] in
            self?.buffer.append(contentsOf: samples)
            self?.drainCompletedWindows()
        }
    }

    /// Snapshot of the frames produced so far. Blocks briefly on the
    /// internal queue to ensure all in-flight ingests are visible — call
    /// this at session finalize, not on the audio thread.
    func snapshotFrames() -> [Frame] {
        bufferQueue.sync { frames }
    }

    /// Reset state for a new session. Cheap; call at startRecording.
    func reset() {
        bufferQueue.sync {
            self.buffer.removeAll(keepingCapacity: true)
            self.frames.removeAll(keepingCapacity: true)
        }
    }

    // MARK: - Internals

    private func drainCompletedWindows() {
        // Process every full window that has accumulated, advance by hopSize.
        while buffer.count >= windowSize {
            let window = Array(buffer.prefix(windowSize))
            let frame = analyseWindow(window)
            frames.append(frame)
            buffer.removeFirst(hopSize)
        }
    }

    private func analyseWindow(_ window: [Float]) -> Frame {
        // Apply Hann window in-place into a workspace.
        var workspace = [Float](repeating: 0, count: windowSize)
        #if canImport(Accelerate)
        vDSP_vmul(window, 1, hannWindow, 1, &workspace, 1, vDSP_Length(windowSize))
        #else
        for i in 0..<windowSize { workspace[i] = window[i] * hannWindow[i] }
        #endif

        // Energy gate: silent / near-silent windows are unvoiced by definition.
        var energy: Float = 0
        #if canImport(Accelerate)
        vDSP_measqv(workspace, 1, &energy, vDSP_Length(windowSize))
        #else
        energy = workspace.map { $0 * $0 }.reduce(0, +) / Float(windowSize)
        #endif
        if energy < 1.0e-5 {
            return Frame(isVoiced: false, frequencyHz: 0)
        }

        // Autocorrelation via vDSP_conv. We compute lags 0...maxLag, then
        // pick the maximum in [minLag...maxLag].
        let lagCount = maxLag + 1
        var autocorr = [Float](repeating: 0, count: lagCount)

        #if canImport(Accelerate)
        // Using vDSP_conv: signal length = windowSize, filter is the same
        // signal, output length = lagCount. Stride of 1 throughout.
        // Note: vDSP_conv with negative strides yields cross-correlation;
        // here we build the lagged-sum manually since we only need a
        // small lag range and scalar fallback is acceptable.
        workspace.withUnsafeBufferPointer { src in
            for lag in 0..<lagCount {
                let n = windowSize - lag
                guard n > 0 else { continue }
                var sum: Float = 0
                vDSP_dotpr(src.baseAddress!, 1, src.baseAddress! + lag, 1, &sum, vDSP_Length(n))
                autocorr[lag] = sum
            }
        }
        #else
        for lag in 0..<lagCount {
            let n = windowSize - lag
            var sum: Float = 0
            for i in 0..<n { sum += workspace[i] * workspace[i + lag] }
            autocorr[lag] = sum
        }
        #endif

        let r0 = autocorr[0]
        guard r0 > 0 else { return Frame(isVoiced: false, frequencyHz: 0) }

        // Find the best peak in the valid lag range. We require the lag
        // to actually be a local maximum so we don't lock onto a slowly-
        // decaying autocorrelation tail.
        var bestLag = 0
        var bestValue: Float = 0
        if maxLag > minLag + 1 {
            for lag in (minLag + 1)..<maxLag {
                let value = autocorr[lag]
                if value > bestValue
                    && value >= autocorr[lag - 1]
                    && value >= autocorr[lag + 1] {
                    bestValue = value
                    bestLag = lag
                }
            }
        }

        guard bestLag > 0 else {
            return Frame(isVoiced: false, frequencyHz: 0)
        }

        let strength = Double(bestValue / r0)
        guard strength >= voicingThreshold else {
            return Frame(isVoiced: false, frequencyHz: 0)
        }

        // Parabolic interpolation around the peak for sub-sample accuracy.
        let refinedLag: Double
        if bestLag > 0 && bestLag < lagCount - 1 {
            let yMinus = Double(autocorr[bestLag - 1])
            let yZero = Double(autocorr[bestLag])
            let yPlus = Double(autocorr[bestLag + 1])
            let denom = (yMinus - 2.0 * yZero + yPlus)
            if abs(denom) > .ulpOfOne {
                let offset = 0.5 * (yMinus - yPlus) / denom
                refinedLag = Double(bestLag) + offset
            } else {
                refinedLag = Double(bestLag)
            }
        } else {
            refinedLag = Double(bestLag)
        }

        let hz = sampleRate / max(refinedLag, 1)
        if hz < minHz || hz > maxHz {
            return Frame(isVoiced: false, frequencyHz: 0)
        }
        return Frame(isVoiced: true, frequencyHz: hz)
    }

    private static func makeHannWindow(size: Int) -> [Float] {
        guard size > 1 else { return [Float](repeating: 1, count: max(size, 1)) }
        var window = [Float](repeating: 0, count: size)
        for i in 0..<size {
            let phase = 2.0 * .pi * Double(i) / Double(size - 1)
            window[i] = Float(0.5 * (1.0 - cos(phase)))
        }
        return window
    }
}
