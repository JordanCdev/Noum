import Foundation

// MARK: - Multi-channel moments (V6.1 / V8 motion contract)
//
// The motion spec is binding on one point that code could not previously
// express:
//
//   "Sound + haptic are one event. Never fire a cue without its haptic
//    partner, and never schedule either off the animation clock."
//    — docs/V6_1_MOTION_SPEC.md, carried into docs/V8_STICKER_BOLD.md
//
// Before this file a call site fired `InteractionSoundEngine.cue(_:)` and
// `CoachHaptic.x()` as two independent statements, so an unpaired cue was a
// silent omission rather than a decision. `NoumMoment` names the moment and
// owns both channels, and `MomentHaptic` has no "nothing" case — a moment
// whose haptic is genuinely delivered somewhere else has to say so by name.
//
// This adds NO new timings, NO new state and NO new patterns. Sound stays
// owned by `InteractionSoundEngine`, haptics by `CoachHaptic`, and both keep
// their own user gates (`InteractionSoundSettings`, `HapticsSettings`).
//
// Reduce Motion note: sound and haptics are NOT motion. A Reduce Motion path
// skips the animation and lands the moment immediately — it never goes quiet.

/// The haptic half of a moment. Every register here is an existing
/// `CoachHaptic` semantic owner; milestone patterns (`levelUp`,
/// `personalBest`, `streakAchievement`) are deliberately absent so a
/// micro-moment can never reach for a celebration brush — those stay
/// `RewardEngine` `.major`-gated.
enum MomentHaptic: String, CaseIterable, Sendable {
    /// Light punctuation as a computed verdict settles.
    case scoreReveal
    /// Two soft rising transients — an outcome-bound earned payoff.
    case earnedEvidence
    /// Very light tap — earned progress accumulating.
    case xpEarned
    /// Declared, not missing: the drill verdict haptic already fired
    /// upstream in `MiniDrillView.finishDrill`, on the frame the verdict was
    /// computed. The result surface's brush lands later, when the result view
    /// makes its entrance. The two channels are therefore genuinely split —
    /// named here so the split is a reviewable decision rather than an
    /// accidental omission. Re-firing here would double-tap the same verdict.
    case deliveredAtDrillVerdict

    /// Whether this register fires from the moment's own call site.
    var firesAtMoment: Bool { self != .deliveredAtDrillVerdict }

    /// Fire the register. No-op for a partner delivered elsewhere.
    func fire() {
        switch self {
        case .scoreReveal:            CoachHaptic.scoreReveal()
        case .earnedEvidence:         CoachHaptic.earnedEvidence()
        case .xpEarned:               CoachHaptic.xpEarned()
        case .deliveredAtDrillVerdict: break
        }
    }
}

/// A moment the product speaks in more than one channel. Call sites request
/// the MOMENT and `land()` it from the same state change that drives the
/// visual beat — a `withAnimation` completion, or directly on the Reduce
/// Motion path. Never from a wall-clock timer running alongside the
/// animation: that is what lets the channels drift apart on a slow frame.
enum NoumMoment: String, CaseIterable, Sendable {
    /// A computed score settled into its ring.
    case verdictLanded
    /// Verified evidence landed — the outcome-bound earned payoff.
    case earnedEvidenceLanded
    /// An earned progress bar finished filling after a genuine increase.
    case earnedProgressSettled
    /// A drill resolved with its criteria met.
    case drillResolvedSuccess
    /// A drill resolved short of its criteria. The duller brush is an
    /// acknowledgment, never a fail-buzzer — distinction is timbral.
    case drillResolvedIncomplete

    var sound: InteractionCue {
        switch self {
        case .verdictLanded:          return .verdictReveal
        case .earnedEvidenceLanded:   return .verdictReveal
        case .earnedProgressSettled:  return .countSettle
        case .drillResolvedSuccess:   return .drillCompleteSuccess
        case .drillResolvedIncomplete: return .drillCompleteIncomplete
        }
    }

    var haptic: MomentHaptic {
        switch self {
        case .verdictLanded:          return .scoreReveal
        case .earnedEvidenceLanded:   return .earnedEvidence
        case .earnedProgressSettled:  return .xpEarned
        case .drillResolvedSuccess:   return .deliveredAtDrillVerdict
        case .drillResolvedIncomplete: return .deliveredAtDrillVerdict
        }
    }

    /// Land every channel of this moment as one event.
    func land() {
        InteractionSoundEngine.cue(sound)
        haptic.fire()
    }

    /// The drill result surface picks its brush from the honest verdict.
    static func drillResolved(succeeded: Bool) -> NoumMoment {
        succeeded ? .drillResolvedSuccess : .drillResolvedIncomplete
    }
}
