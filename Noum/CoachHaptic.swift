import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Centralized haptic patterns for the coaching experience.
/// Each pattern is designed to feel intentional and non-intrusive.
/// All patterns honor `HapticsSettings.shared.isEnabled` — if the user
/// disables haptics from Settings, nothing fires.
///
/// Register map (A2) — pick by what the moment IS, not by what's loudest:
///   • Input acknowledgment — `selectionTap` / `.sensoryFeedback(.selection)`
///     on small choices. Ordinary buttons get the visual squish only;
///     never add a global haptic to every tap.
///   • Commitment — `drillStart` (medium impact), reserved for Begin/Start
///     CTAs: the user is committing to a rep.
///   • Result lands — `scoreReveal` (light) on the verdict settle frame,
///     paired with `InteractionCue.verdictReveal`; `sessionComplete`
///     marks the rep boundary itself.
///   • Completion verdicts — `drillSuccess` (.success) vs `drillIncomplete`
///     (soft single tap — acknowledgment, never a fail-buzzer), paired
///     with the bright/dull `drillComplete*` brushes.
///   • Milestones — escalating patterns (`levelUp`, `personalBest`,
///     `streakAchievement`) stay reserved for RewardEngine
///     `.major`-gated celebrations. Never fire these for micro-wins.
enum CoachHaptic {

    /// Master gate — all patterns route through this so a single setting
    /// silences every haptic pathway in the app.
    private static var isEnabled: Bool { HapticsSettings.isEnabledSync }

    /// Single firm tap — marks the start of a drill.
    static func drillStart() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// Satisfying success notification — drill completed successfully.
    static func drillSuccess() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Soft single tap — drill completed but criteria not fully met.
    /// Not punishing — just a gentle acknowledgment.
    static func drillIncomplete() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Three ascending taps — skill leveled up.
    static func skillLevelUp() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred(intensity: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            generator.impactOccurred(intensity: 0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            generator.impactOccurred(intensity: 1.0)
        }
        #endif
    }

    /// Gentle pulse — trend breakthrough or positive shift.
    static func trendBreakthrough() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    /// Earned-evidence payoff — two soft rising transients (0.55 then
    /// 0.85, 100 ms apart). Reserved for ledger/outcome-bound earned
    /// moments (the Today earned announcement, a verified improved retry):
    /// a felt "that changed something", calmer than the milestone
    /// patterns, never fired for held/regressed/insufficient evidence.
    static func earnedEvidence() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.55)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            generator.impactOccurred(intensity: 0.85)
        }
        #endif
    }

    /// Light selection tap — UI interaction feedback.
    static func selectionTap() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// Medium impact — countdown moment or transition.
    static func countdownBeat() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        #endif
    }

    /// Double tap for streak achievement.
    static func streakAchievement() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred()
        }
        #endif
    }

    /// Light punctuation when score number lands after count-up animation.
    static func scoreReveal() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        #endif
    }

    /// Full level-up sequence — heavy escalating triple-tap plus success notification.
    static func levelUp() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred(intensity: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            heavy.impactOccurred(intensity: 0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            heavy.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }

    /// Personal best — success notification followed by delayed heavy impact.
    static func personalBest() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
        }
        #endif
    }

    /// Subtle XP accumulation — very light tap.
    static func xpEarned() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
        #endif
    }

    /// Session complete — a definitive "done" feel. Medium impact followed by a soft success.
    /// Used when any practice session ends (all modes).
    static func sessionComplete() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }

    /// Game over in Sudden Death — heavy, decisive impact.
    static func gameOver() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }

    /// Filler detected alert — light rigid tap paired with audio cue.
    static func fillerAlert() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5)
        #endif
    }

    /// Pace warning — double soft tap when leaving WPM zone (Beat the Brake).
    static func paceWarning() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            generator.impactOccurred(intensity: 0.6)
        }
        #endif
    }

    /// Checkpoint locked — medium impact (Land the Pause lock-in).
    static func checkpointLock() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
        #endif
    }

    /// Timer urgency — rapid double-tap when time is running critically low.
    static func timerUrgency() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            generator.impactOccurred(intensity: 0.9)
        }
        #endif
    }

    /// Round survived — quick success pulse between rounds.
    static func roundSurvived() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Unavailable / warning notice — soft double-tick. Warning register:
    /// fired when a live capability becomes unavailable (coach transport,
    /// dead mic), never for mere `.checking`, and never as a fail-buzzer
    /// on user performance. Always paired with a visible banner or notice.
    static func unavailableNotice() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            generator.impactOccurred(intensity: 0.4)
        }
        #endif
    }

    /// Pressure session complete — definitive ending with ascending taps.
    static func pressureSessionComplete() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred(intensity: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            heavy.impactOccurred(intensity: 0.9)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }
}
