import Testing
import SwiftUI
@testable import Noum

// V4.6 polish layer — deterministic contracts for the semantic motion
// owners. Animation QUALITY is proven by recordings, not unit tests;
// these pin the state logic that motion binds to.
struct MotionSemanticsTests {

    // MARK: Audio envelope (Moment B)

    @Test func attackIsFasterThanDecay() {
        let rise = AudioEnvelope.step(current: 0.2, sample: 0.8)
        let fall = AudioEnvelope.step(current: 0.8, sample: 0.2)
        let riseDelta = rise - 0.2
        let fallDelta = 0.8 - fall
        #expect(riseDelta > fallDelta)
        #expect(AudioEnvelope.attackCoefficient > AudioEnvelope.decayCoefficient)
    }

    @Test func noiseFloorGatesToSilence() {
        // A sample under the floor decays toward zero, never sustains.
        var level = 0.5
        for _ in 0..<60 {
            level = AudioEnvelope.step(current: level, sample: AudioEnvelope.noiseFloor - 0.01)
        }
        #expect(level < 0.01)
    }

    @Test func speechOnsetReadsWithinBudget() {
        // From silence, a strong sample must cross half amplitude within
        // ~4 frames at 30Hz (≈130ms) — the responsiveness contract.
        var level = 0.0
        var frames = 0
        while level < 0.4 && frames < 10 {
            level = AudioEnvelope.step(current: level, sample: 0.8)
            frames += 1
        }
        #expect(frames <= 4)
    }

    @Test func envelopeStaysClamped() {
        #expect(AudioEnvelope.step(current: 1.0, sample: 2.0) <= 1.0)
        #expect(AudioEnvelope.step(current: 0.0, sample: -1.0) >= 0.0)
    }

    // MARK: Ambient gate

    @Test func ambientStopsOffActiveScene() {
        #expect(!NoumMotion.ambientAllowed(reduceMotion: false, scenePhase: .background, lowPower: false))
        #expect(!NoumMotion.ambientAllowed(reduceMotion: false, scenePhase: .inactive, lowPower: false))
        #expect(NoumMotion.ambientAllowed(reduceMotion: false, scenePhase: .active, lowPower: false))
    }

    @Test func ambientRespectsReduceMotionAndLowPower() {
        #expect(!NoumMotion.ambientAllowed(reduceMotion: true, scenePhase: .active, lowPower: false))
        #expect(!NoumMotion.ambientAllowed(reduceMotion: false, scenePhase: .active, lowPower: true))
    }

    // MARK: Phrase transformation sequence

    @Test func phraseBeatsAreOrderedAndInsideBudget() {
        #expect(PhraseTransformationBeat.recede < PhraseTransformationBeat.resolve)
        #expect(PhraseTransformationBeat.resolve < PhraseTransformationBeat.explain)
        #expect(PhraseTransformationBeat.explain < PhraseTransformationBeat.settled)
        // Brief: total sequence ≈ 550–750ms.
        #expect(PhraseTransformationBeat.settled >= 0.55 && PhraseTransformationBeat.settled <= 0.75)
    }

    // MARK: Earned retry reward (page-19 V3 E3)

    @Test func retryRewardBeatsStayInsideOneFastReveal() {
        let summedToAction = RetryRewardBeat.voiceformCompress
            + RetryRewardBeat.voiceformLift
            + RetryRewardBeat.burstToReward
            + RetryRewardBeat.rewardToEvidence
            + RetryRewardBeat.evidenceToNextStep
            + RetryRewardBeat.nextStepToAction

        #expect(RetryRewardBeat.actionReadyOffset == summedToAction)
        #expect(
            RetryRewardBeat.actionReady
                == RetryRewardBeat.startDelay + RetryRewardBeat.actionReadyOffset
        )
        #expect(RetryRewardBeat.animationComplete <= 1.80)
    }

    @Test func retryRewardRequiresContinueAndHasReducedMotionFallback() {
        #expect(RetryRewardBeat.requiresExplicitContinue)
        #expect(RetryRewardBeat.reducedMotionReveal <= 0.20)
        #expect(RetryRewardBeat.celebrationParticles == 6)
    }
}
