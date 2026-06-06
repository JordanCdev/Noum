import Foundation
import AVFoundation

// MARK: - Vocal Energy Metrics
//
// Per-session aggregate of the RMS amplitude envelope captured on the
// audio thread during a rep. The live envelope (`SpeechRecognizerViewModel
// .audioLevel`) already drives the orb visualizers; until now, it
// evaporated when the session ended. `VocalEnergyMetrics` is the
// session-level summary that survives — mean, peak, dynamic range, and
// a derived steadiness score so the coach can comment on how the user
// SOUNDED, not just what they said.
//
// Per VISION § Coach-parity standard #5 (Perception) + § Strategic
// roadmap #2 (Delivery intelligence):
//   - "Pause quality, prosody/intonation, pitch range, breathing,
//      emphasis, vocal energy, authority/tension, structure..."
//   - "Coach for the difference between clarity and over-polish,
//      avoidance, timidity, or emotional distance."
// Vocal energy is one of the explicitly listed signals. Today it
// exists per-buffer for the orb but is never aggregated to the
// session.
//
// Design rules (mirror PauseMetrics + PitchMetrics):
//   - Pure-data model — all derivation lives in
//     `VocalEnergyAccumulator`. The struct stays test-friendly.
//   - Codable round-tripping with `decodeIfPresent` everywhere it's
//     consumed so old persisted sessions decode cleanly with nil.
//   - Honest about thin data — sample count below the floor returns
//     nil from the accumulator instead of fabricating a number.

/// Per-session aggregate vocal-energy summary.
///
/// All values are in the same 0-1 normalised range as the live
/// `audioLevel` envelope (RMS dB-scaled, -50dB → 0, -10dB → 1).
/// Steadiness derives from the coefficient of variation: low CV = the
/// user held a consistent vocal energy through the rep; high CV = the
/// energy spiked and dipped, which can read as nervousness or
/// thinning conviction.
struct VocalEnergyMetrics: Codable, Equatable {
    /// Mean RMS envelope across the rep. 0 = silence, 1 = loud.
    /// Typical conversational speech lands in 0.30-0.55.
    let meanLevel: Double
    /// Peak RMS envelope across the rep. Indicates loudest moment.
    let peakLevel: Double
    /// Standard deviation of the envelope. Raw dispersion signal.
    let stdDeviation: Double
    /// Coefficient of variation: stdDev / mean. Scale-invariant.
    /// Used to derive steadiness without being dominated by overall
    /// volume.
    let coefficientOfVariation: Double
    /// Bucketed steadiness label derived from CV. 0-1 normalised:
    /// 1.0 = held a steady energy throughout (calm authority); 0.0 =
    /// energy varied wildly (often reads as nervous or losing thread).
    let steadiness: Double
    /// Number of raw samples that fed the aggregate. Sample count
    /// drives the "thin data" gate on the accumulator side — a rep
    /// shorter than the floor returns nil instead of producing a
    /// meaningless aggregate.
    let sampleCount: Int

    /// Coach-voice qualitative label derived from `steadiness` +
    /// `meanLevel`. Used by `CoachContextBuilder` to surface a
    /// short, hedged read to the AI coach — NOT a clinical claim.
    /// Per VISION dev rule: weak evidence → tentative language.
    var qualitativeReadout: String {
        let energyLabel: String
        switch meanLevel {
        case ..<0.20:   energyLabel = "low"
        case 0.20..<0.40: energyLabel = "moderate"
        case 0.40..<0.65: energyLabel = "engaged"
        default:        energyLabel = "high"
        }
        let steadinessLabel: String
        switch steadiness {
        case 0.75...:   steadinessLabel = "steady"
        case 0.50..<0.75: steadinessLabel = "mostly steady"
        case 0.25..<0.50: steadinessLabel = "variable"
        default:        steadinessLabel = "very variable"
        }
        return "\(energyLabel) energy, \(steadinessLabel)"
    }
}

/// Lock-light accumulator that runs on the audio thread.
/// `append(level:)` is called from the audio tap; `finalize()` is
/// called from the recording lifecycle teardown to produce the
/// session-level aggregate.
///
/// Holds raw samples in a bounded ring (capped at 12000 ≈ 5 min at
/// ~40Hz envelope updates) so a long rep doesn't blow up memory.
final class VocalEnergyAccumulator {

    /// Minimum sample count to produce a non-nil aggregate. Below
    /// this, the rep is too short to characterise reliably — return
    /// nil so the consumer surfaces nothing rather than a fabricated
    /// number from 2 samples.
    static let minimumSampleFloor: Int = 30 // ≈ 0.75s at 40Hz

    /// Ring buffer cap. ~5 min of envelope at 40Hz update rate.
    private static let maxSamples: Int = 12000

    private let lock = NSLock()
    private var samples: [Double] = []

    /// Append a normalised RMS sample (0-1) from the audio thread.
    /// Lock-light: a brief `NSLock` window keeps the writer safe
    /// without bouncing onto the main actor.
    func append(level: Double) {
        let clamped = max(0, min(1, level))
        lock.lock()
        defer { lock.unlock() }
        samples.append(clamped)
        if samples.count > Self.maxSamples {
            // Drop the oldest sample; over a 5+ min rep we'd rather
            // lose the beginning than corrupt the trailing window.
            samples.removeFirst()
        }
    }

    /// Snapshot + clear. Called at session teardown. Returns nil when
    /// the rep is too thin for a credible read. Honest about thin
    /// data per VISION dev rule.
    func finalize() -> VocalEnergyMetrics? {
        lock.lock()
        let snapshot = samples
        samples.removeAll(keepingCapacity: true)
        lock.unlock()

        guard snapshot.count >= Self.minimumSampleFloor else { return nil }
        return Self.compute(samples: snapshot)
    }

    /// Reset without producing an aggregate. Called when a rep is
    /// abandoned before it counts as a real session.
    func reset() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    /// Snapshot without clearing. Useful for live debug surfaces.
    func currentSampleCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return samples.count
    }

    // MARK: - Pure aggregator (testable in isolation)

    /// Pure-function compute over a sample array. Public so unit
    /// tests can exercise the math without spinning up an audio tap.
    static func compute(samples: [Double]) -> VocalEnergyMetrics {
        let count = samples.count
        guard count > 0 else {
            return VocalEnergyMetrics(
                meanLevel: 0,
                peakLevel: 0,
                stdDeviation: 0,
                coefficientOfVariation: 0,
                steadiness: 0,
                sampleCount: 0
            )
        }
        let mean = samples.reduce(0.0, +) / Double(count)
        let peak = samples.max() ?? 0
        let variance = samples.reduce(0.0) { acc, x in
            let d = x - mean
            return acc + d * d
        } / Double(count)
        let stdDev = sqrt(variance)
        // Coefficient of variation. Guard against divide-by-zero on
        // a silent rep (mean ≈ 0); steadiness is undefined there.
        let cv: Double = mean > 1e-6 ? stdDev / mean : 0
        // Map CV to steadiness: CV 0 → steadiness 1.0; CV ≥ 1.0 →
        // steadiness 0.0. The 1.0 ceiling is empirically a "spiky"
        // rep — anything past that is noise.
        let steadiness = max(0, min(1, 1.0 - cv))
        return VocalEnergyMetrics(
            meanLevel: mean,
            peakLevel: peak,
            stdDeviation: stdDev,
            coefficientOfVariation: cv,
            steadiness: steadiness,
            sampleCount: count
        )
    }
}
