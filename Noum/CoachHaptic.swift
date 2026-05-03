import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Centralized haptic patterns for the coaching experience.
/// Each pattern is designed to feel intentional and non-intrusive.
enum CoachHaptic {

    /// Single firm tap — marks the start of a drill.
    static func drillStart() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// Satisfying success notification — drill completed successfully.
    static func drillSuccess() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Soft single tap — drill completed but criteria not fully met.
    /// Not punishing — just a gentle acknowledgment.
    static func drillIncomplete() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Three ascending taps — skill leveled up.
    static func skillLevelUp() {
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
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    /// Light selection tap — UI interaction feedback.
    static func selectionTap() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// Medium impact — countdown moment or transition.
    static func countdownBeat() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        #endif
    }

    /// Double tap for streak achievement.
    static func streakAchievement() {
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
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        #endif
    }

    /// Full level-up sequence — heavy escalating triple-tap plus success notification.
    static func levelUp() {
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
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
        }
        #endif
    }

    /// Subtle XP accumulation — very light tap.
    static func xpEarned() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
        #endif
    }

    /// Session complete — a definitive "done" feel. Medium impact followed by a soft success.
    /// Used when any practice session ends (all modes).
    static func sessionComplete() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }

    /// Game over in Sudden Death — heavy, decisive impact.
    static func gameOver() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }

    /// Filler detected alert — light rigid tap paired with audio cue.
    static func fillerAlert() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5)
        #endif
    }

    /// Pace warning — double soft tap when leaving WPM zone (Beat the Brake).
    static func paceWarning() {
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
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
        #endif
    }

    /// Timer urgency — rapid double-tap when time is running critically low.
    static func timerUrgency() {
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
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Pressure session complete — definitive ending with ascending taps.
    static func pressureSessionComplete() {
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
