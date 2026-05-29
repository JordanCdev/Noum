import Foundation
import AVFoundation
import Accelerate
import os

// MARK: - Pitch Analyzer (M10)
//
// On-device f0 (fundamental frequency) detector for the user's voice.
// Designed to be fed from the AVAudioEngine installTap callback — that
// callback runs on a real-time audio thread, so the append path must
// be lock-light and allocation-free.
//
// Architecture:
//   • Audio thread calls `appendBuffer(_:sampleRate:)` per buffer.
//     We grab the float channel data and append it to a thread-safe
//     ring of samples under an OSAllocatedUnfairLock. No DSP runs here.
//   • At session end (any thread), `analyze()` walks the captured
//     samples in 2048-sample windows, runs autocorrelation, and emits
//     a `PitchMetrics` aggregate.
//   • The whole thing is opt-in: callers create a fresh instance per
//     session. Discarding the instance after `analyze()` releases all
//     captured audio.
//
// Why autocorrelation: cheap, accurate enough for voice in the 70-400Hz
// band, no model dependencies. We could move to YIN later if we want
// higher accuracy on whisper-quiet voiced regions.

/// Pure pitch-tracker. Sendable so it can move between actors safely.
final class PitchAnalyzer: @unchecked Sendable {

    /// Sample-rate-aware analysis bounds (Hz). 70-400Hz covers both ends
    /// of typical adult vocal range with margin.
    static let minPitchHz: Double = 70.0
    static let maxPitchHz: Double = 400.0

    /// Analysis window in samples. 2048 ≈ 46ms at 44.1kHz, 128ms at 16kHz.
    static let windowSize = 2048

    /// Hop size between successive windows (50% overlap).
    static let hopSize = 1024

    /// Minimum normalized autocorrelation peak to consider a window
    /// confidently voiced. Below this we treat the window as unvoiced
    /// (silence, fricative, noise).
    static let voicingThreshold: Float = 0.30

    /// Cap on samples we'll keep — protects memory if recording runs
    /// far longer than expected. 44.1kHz × 600s = 26.46M floats ≈ 100MB.
    /// Capping at 10 minutes of audio at 44.1kHz keeps it under 110MB.
    static let maxSamples: Int = 44_100 * 10 * 60

    private let lock = OSAllocatedUnfairLock<State>(initialState: State())

    private struct State {
        var samples: [Float] = []
        var sampleRate: Double = 0
    }

    // MARK: - Append (audio-thread safe)

    /// Append samples from an AVAudioPCMBuffer. Safe to call from the
    /// installTap callback on the audio rendering thread.
    func appendBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        // Snapshot samples into a local Array first (allocates on the
        // audio thread — small but unavoidable without a pre-sized ring).
        // For session lengths under a few minutes this is fine.
        let new = Array(UnsafeBufferPointer(start: channelData, count: frameCount))

        lock.withLock { state in
            // Hard cap protects memory if a session somehow runs forever.
            guard state.samples.count + new.count <= Self.maxSamples else { return }
            state.samples.append(contentsOf: new)
            if state.sampleRate == 0 { state.sampleRate = sampleRate }
        }
    }

    /// Number of samples currently captured. Useful for tests + diagnostics.
    var capturedSampleCount: Int {
        lock.withLock { $0.samples.count }
    }

    // MARK: - Analyze (off-thread)

    /// Run autocorrelation across the captured buffer and emit aggregate
    /// metrics. Safe to call once per session at the end. Never call from
    /// the audio thread — this is O(N × W) on the captured audio.
    func analyze() -> PitchMetrics {
        let (samples, sampleRate) = lock.withLock { state -> ([Float], Double) in
            (state.samples, state.sampleRate)
        }
        guard sampleRate > 0, samples.count >= Self.windowSize else {
            return .empty
        }

        let minLag = Int((sampleRate / Self.maxPitchHz).rounded())
        let maxLag = Int((sampleRate / Self.minPitchHz).rounded())
        guard maxLag < Self.windowSize else { return .empty }

        var voicedFrequencies: [Double] = []
        var totalWindows = 0

        var start = 0
        while start + Self.windowSize <= samples.count {
            let window = Array(samples[start..<(start + Self.windowSize)])
            totalWindows += 1
            if let f0 = Self.detectF0(
                in: window,
                sampleRate: sampleRate,
                minLag: minLag,
                maxLag: maxLag
            ) {
                voicedFrequencies.append(f0)
            }
            start += Self.hopSize
        }

        guard !voicedFrequencies.isEmpty, totalWindows > 0 else {
            return PitchMetrics(meanHz: nil, stdHz: nil, voicedRatio: 0, windowCount: totalWindows)
        }

        let mean = voicedFrequencies.reduce(0, +) / Double(voicedFrequencies.count)
        let variance = voicedFrequencies
            .map { ($0 - mean) * ($0 - mean) }
            .reduce(0, +) / Double(voicedFrequencies.count)
        let std = variance.squareRoot()
        let voiced = Double(voicedFrequencies.count) / Double(totalWindows)

        return PitchMetrics(
            meanHz: mean,
            stdHz: std,
            voicedRatio: voiced,
            windowCount: totalWindows
        )
    }

    /// Drop captured samples. Useful between back-to-back sessions on
    /// the same view-model instance.
    func reset() {
        lock.withLock { state in
            state.samples.removeAll(keepingCapacity: false)
            state.sampleRate = 0
        }
    }

    // MARK: - Detection (pure function, testable)

    /// Run normalized autocorrelation on a single window and return the
    /// detected f0 if the peak is above the voicing threshold.
    ///
    /// Peak-picking: walks normalized autocorrelation across the lag range
    /// and picks the FIRST local maximum that clears the voicing threshold.
    /// This avoids the classic octave-doubling failure mode where argmax
    /// picks a harmonic of the fundamental — for a pure 220Hz sine, lag 146
    /// (110Hz) and lag 73 (220Hz) both peak; we want the smallest lag,
    /// which corresponds to the fundamental.
    static func detectF0(
        in window: [Float],
        sampleRate: Double,
        minLag: Int,
        maxLag: Int
    ) -> Double? {
        guard window.count >= maxLag + 1 else { return nil }

        // Energy of the un-shifted window — denominator for normalization.
        var energy: Float = 0
        vDSP_dotpr(window, 1, window, 1, &energy, vDSP_Length(window.count))
        guard energy > 0 else { return nil }

        // Compute normalized autocorrelation for every lag in the range,
        // then walk the resulting curve to find the first local maximum
        // that clears the voicing threshold.
        var normalized = [Float](repeating: 0, count: maxLag + 1)
        for lag in minLag...maxLag {
            var corr: Float = 0
            var leftEnergy: Float = 0
            var rightEnergy: Float = 0
            window.withUnsafeBufferPointer { ptr in
                let n = vDSP_Length(window.count - lag)
                vDSP_dotpr(ptr.baseAddress!, 1, ptr.baseAddress! + lag, 1, &corr, n)
                vDSP_dotpr(ptr.baseAddress!, 1, ptr.baseAddress!, 1, &leftEnergy, n)
                vDSP_dotpr(ptr.baseAddress! + lag, 1, ptr.baseAddress! + lag, 1, &rightEnergy, n)
            }
            let denom = (leftEnergy * rightEnergy).squareRoot()
            normalized[lag] = denom > 0 ? corr / denom : 0
        }

        // First-local-max scan. A local max at lag `i` requires
        //   normalized[i] > normalized[i-1] AND normalized[i] >= normalized[i+1]
        // and the value must clear the voicing threshold. The smallest such
        // lag is taken as the fundamental period.
        var bestLag = -1
        for lag in (minLag + 1)..<maxLag {
            let prev = normalized[lag - 1]
            let curr = normalized[lag]
            let next = normalized[lag + 1]
            if curr > prev, curr >= next, curr >= voicingThreshold {
                bestLag = lag
                break
            }
        }

        // Fallback: if no local max cleared the threshold via the strict
        // walk, take the absolute peak across the range. Some noisy reps
        // produce monotonic curves where the fundamental still dominates.
        if bestLag < 0 {
            var maxVal: Float = 0
            var maxLagFallback = -1
            for lag in minLag...maxLag {
                if normalized[lag] > maxVal {
                    maxVal = normalized[lag]
                    maxLagFallback = lag
                }
            }
            guard maxVal >= voicingThreshold, maxLagFallback > 0 else { return nil }
            bestLag = maxLagFallback
        }

        return sampleRate / Double(bestLag)
    }
}
