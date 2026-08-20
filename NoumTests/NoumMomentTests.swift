//
//  NoumMomentTests.swift
//  NoumTests
//
//  Pins the V6.1 / V8 multi-channel contract: "Sound + haptic are one event.
//  Never fire a cue without its haptic partner." These are pure table tests —
//  no audio graph, no haptic hardware. Whether a moment FEELS right is proven
//  on device; this proves it can never silently lose a channel.
//

import Foundation
import Testing
@testable import Noum

@Suite("NoumMoment multi-channel contract")
struct NoumMomentTests {

    /// The binding rule. There is no `.none` haptic case, so the type already
    /// forbids an unpaired cue; this asserts the one deferred register stays
    /// the single documented exception rather than growing into a habit.
    @Test func everyMomentDeclaresAHapticPartner() {
        let deferred = NoumMoment.allCases.filter { !$0.haptic.firesAtMoment }
        #expect(Set(deferred) == [.drillResolvedSuccess, .drillResolvedIncomplete])
        #expect(deferred.allSatisfy { $0.haptic == .deliveredAtDrillVerdict })
    }

    /// Milestone brushes (`levelUp`, `personalBest`, `streakAchievement`) must
    /// stay RewardEngine `.major`-gated. Keeping them out of `MomentHaptic`
    /// makes "a micro-moment reaches for a celebration" unrepresentable.
    @Test func momentHapticsExcludeCelebrationRegisters() {
        #expect(Set(MomentHaptic.allCases) == [
            .scoreReveal, .earnedEvidence, .xpEarned, .deliveredAtDrillVerdict
        ])
    }

    /// The pairing table itself. A rewire here is a product decision, so it
    /// should fail a test rather than pass silently.
    @Test func pairingTableIsLocked() {
        #expect(NoumMoment.verdictLanded.sound == .verdictReveal)
        #expect(NoumMoment.verdictLanded.haptic == .scoreReveal)

        #expect(NoumMoment.earnedEvidenceLanded.sound == .verdictReveal)
        #expect(NoumMoment.earnedEvidenceLanded.haptic == .earnedEvidence)

        #expect(NoumMoment.earnedProgressSettled.sound == .countSettle)
        #expect(NoumMoment.earnedProgressSettled.haptic == .xpEarned)

        #expect(NoumMoment.drillResolvedSuccess.sound == .drillCompleteSuccess)
        #expect(NoumMoment.drillResolvedIncomplete.sound == .drillCompleteIncomplete)
    }

    /// The drill verdict routes by the honest outcome, and the two variants
    /// differ only in brush brightness — the non-punishing contract already
    /// pinned in `InteractionSoundTests` is reachable from the moment layer.
    @Test func drillVerdictRoutesByOutcomeAndDiffersOnlyInTimbre() {
        #expect(NoumMoment.drillResolved(succeeded: true) == .drillResolvedSuccess)
        #expect(NoumMoment.drillResolved(succeeded: false) == .drillResolvedIncomplete)

        let bright = NoumMoment.drillResolvedSuccess.sound.drillBrushStartCutoffHz
        let dull = NoumMoment.drillResolvedIncomplete.sound.drillBrushStartCutoffHz
        #expect(bright != nil && dull != nil)
        #expect(bright! > dull!)
        #expect(NoumMoment.drillResolvedSuccess.sound.duration
                == NoumMoment.drillResolvedIncomplete.sound.duration)
    }

    /// Every moment's cue must survive the engine's own suppression policy
    /// under normal conditions, and none may bypass the mic gate — a moment
    /// is not a privileged channel.
    @Test func momentsObeyTheInteractionSoundPolicy() {
        for moment in NoumMoment.allCases {
            #expect(InteractionSoundPolicy.shouldPlay(
                moment.sound, enabled: true, isRecording: false
            ))
            #expect(!InteractionSoundPolicy.shouldPlay(
                moment.sound, enabled: true, isRecording: true
            ))
            #expect(!InteractionSoundPolicy.shouldPlay(
                moment.sound, enabled: false, isRecording: false
            ))
        }
    }

    /// A moment's cue must fit inside the pre-mic budget class it belongs to:
    /// nothing in this layer may outlast the `repStartBreath` ceiling, which
    /// is the longest cue the sound plan permits.
    @Test func momentCuesStayInsideTheCueDurationBudget() {
        for moment in NoumMoment.allCases {
            #expect(moment.sound.duration > 0)
            #expect(moment.sound.duration <= InteractionCue.repStartBreath.duration)
        }
    }
}
