#if canImport(SwiftUI)
import SwiftUI

// MARK: - Semantic motion owners (V4.6 polish layer)
//
// Views request MOMENTS, not durations. Every name below resolves onto the
// frozen token vocabulary in DesignSystem.swift — this file adds no new
// timings, it names the moments the product actually has so surface code
// reads as intent ("evidenceReveal") rather than plumbing (".spring(0.5)").
//
// Principle: earned, restrained, unmistakably rewarding. Motion binds to
// real state; reward binds to evidence.

enum NoumMotion {
    /// Press squish on any tappable control.
    static let interactionPress = Animation.tapFeedback
    /// Selection moved — rows, chips, tabs, dims.
    static let interactionSelection = Animation.listChange
    /// One screen flowing into the next (pre-push handoff beats,
    /// arrivals) — the navigation-continuity register.
    static let screenContinuation = Animation.settle
    /// Evidence appearing: verified quotes, reads, receipts.
    static let evidenceReveal = Animation.spring(response: 0.5, dampingFraction: 0.86)
    /// The phrase-transformation sequence's per-beat curve. The SEQUENCE
    /// is owned by `PhraseTransformationBeat`; this is each beat's spring.
    static let phraseTransformation = Animation.spring(response: 0.42, dampingFraction: 0.88)
    /// Earned progress landing (comparison payoff, earned hero flip).
    static let earnedProgress = Animation.payoffReveal
    /// Ambient presence loops — VoiceTrace breath (2.4s, signed-off) and
    /// NoumCharacter (4s) own their cycles; this exists so no NEW ambient
    /// timing is ever invented at a call site.
    static let ambientBreathingPeriod: TimeInterval = 2.4
    /// Live trace response to the mic envelope.
    static let audioResponse = Animation.easeOut(duration: 0.12)
    /// Recording settling into analysis.
    static let processingSettle = Animation.v46Dissolve

    /// Whether ambient (decorative, repeating) motion may run right now.
    /// Ambient loops stop when the scene isn't active, under Reduce
    /// Motion, and in Low Power Mode — state-bound motion (press, reveal)
    /// is unaffected by the power gate.
    static func ambientAllowed(
        reduceMotion: Bool,
        scenePhase: ScenePhase,
        lowPower: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    ) -> Bool {
        !reduceMotion && scenePhase == .active && !lowPower
    }
}

/// The Review phrase-transformation choreography — one owned sequence
/// (total ≈ 620ms) so the beats cannot drift apart per call site:
/// transcript is already visible → setup recedes → strengthened phrase
/// resolves → explanation surfaces after the visual change.
/// Reduce Motion: all phases apply instantly (single accessible swap).
enum PhraseTransformationBeat {
    /// Setup/scaffold recedes.
    static let recede: TimeInterval = 0
    /// Strengthened phrase resolves into place.
    static let resolve: TimeInterval = 0.18
    /// Explanation appears after the visual change has landed.
    static let explain: TimeInterval = 0.46
    /// Sequence considered settled (replay re-arms after this).
    static let settled: TimeInterval = 0.62
}

/// Microphone → trace envelope contract (Moment B). Attack is fast so
/// speech onset reads immediately; decay is ~3× slower so the trace
/// breathes out rather than flickering; the floor gates room noise so a
/// silent mic reads as intentional stillness, not jitter.
enum AudioEnvelope {
    /// Per-sample blend when the level is RISING (≈70ms to ~63% at 30Hz).
    static let attackCoefficient: Double = 0.45
    /// Per-sample blend when the level is FALLING (≈260ms).
    static let decayCoefficient: Double = 0.12
    /// RMS below this is treated as silence (noise floor).
    static let noiseFloor: Double = 0.06

    /// Pure envelope step — unit-tested; the audio tap calls this.
    static func step(current: Double, sample: Double) -> Double {
        let target = sample < noiseFloor ? 0 : sample
        let coefficient = target > current ? attackCoefficient : decayCoefficient
        let blended = current * (1 - coefficient) + target * coefficient
        return min(max(blended, 0), 1)
    }
}
#endif
