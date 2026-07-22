import Foundation

// MARK: - Ask Noum mode suggestion (A3)
//
// Detects, from the coach's latest reply, whether it is pointing the user at a
// concrete practice mode/exercise — so Ask Noum can surface ONE tappable card
// that launches straight there (reusing AppDestination routing, the same
// destinations Home/Summary use). Conservative by design:
//   • explicit mode/drill names win (use that exact mode),
//   • a small set of high-confidence delivery-skill phrases map to their
//     natural mode (Timed, where you'd work pitch/variety/pacing),
//   • anything ambiguous returns nil → NO card. Better none than a wrong
//     launch (a card that says "Pressure Drill" when the coach meant a calm
//     conversation rep erodes trust fast).
// Pure + fully unit-testable; no SwiftUI, no model call.
enum AskNoumModeSuggestion {

    /// One coherent practice launch for the established Ask Noum next-move
    /// card. The label, Quick Start handshake, and navigation destination are
    /// all derived from `mode`, so an unavailable recommendation can never
    /// advertise or arm a different exercise from the one it opens.
    struct LaunchProjection: Equatable {
        let mode: PracticeMode
        let label: String
        let quickStartMode: PracticeMode
        let destination: AppDestination

        /// Recheck only the mode that was actually rendered. Capability gains
        /// do not silently upgrade a visible Timed fallback into a different
        /// exercise at tap time; capability loss may only fail closed to Timed.
        func resolvingForTap(
            modeAvailability: NextActionModeAvailability,
            imAvailable: Bool
        ) -> LaunchProjection {
            AskNoumModeSuggestion.launchProjection(
                requestedMode: mode,
                modeAvailability: modeAvailability,
                imAvailable: imAvailable
            )
        }
    }

    /// The single launchable destination implied by a coach reply, or nil.
    static func detect(in reply: String) -> AppDestination? {
        let t = reply.lowercased()

        // Explicit mode / drill names — highest confidence.
        if t.contains("ah-counter") || t.contains("ah counter")
            || t.contains("filler drill") || t.contains("filler round")
            || t.contains("filler-word drill") || t.contains("filler word drill")
            || t.contains("filler-count drill") || t.contains("filler count drill") {
            return .ahCounterPractice
        }
        if t.contains("sudden death") || t.contains("pressure drill") {
            return .suddenDeathPractice
        }
        if t.contains("conversation practice") || t.contains("difficult conversation")
            || t.contains("im mode")
            || t.contains("conversation mode") || t.contains("audience simulation")
            || t.contains("role-play") || t.contains("roleplay") {
            return .imPractice(scenario: nil, tone: nil)
        }
        if t.contains("timed rep") || t.contains("timed round")
            || t.contains("timed mode") || t.contains("timed practice") {
            return .timedPractice(difficulty: nil)
        }

        // High-confidence delivery-skill phrases → Timed (free delivery
        // practice). Kept deliberately tight to avoid false positives on
        // common words like "pace" alone.
        if t.contains("vocal variety") || t.contains("vary your pitch")
            || t.contains("vary your tone") || t.contains("pitch range")
            || t.contains("vary your delivery") {
            return .timedPractice(difficulty: nil)
        }

        return nil
    }

    /// Detect and resolve the launch against the capability snapshot that owns
    /// the rendered card. Sudden Death fails closed without rated evidence; IM
    /// requires both the decision-time snapshot and the live availability
    /// guard. Timed and Filler Control remain available in every snapshot.
    static func launchProjection(
        in reply: String,
        modeAvailability: NextActionModeAvailability,
        imAvailable: Bool
    ) -> LaunchProjection? {
        guard let detected = detect(in: reply),
              let requestedMode = quickStartMode(for: detected) else {
            return nil
        }
        return launchProjection(
            requestedMode: requestedMode,
            modeAvailability: modeAvailability,
            imAvailable: imAvailable
        )
    }

    /// Short, action-shaped label for the launch card per destination.
    static func label(for destination: AppDestination) -> String {
        switch destination {
        case .timedPractice, .timedPracticePrompt:
            return "Start Timed Practice"
        case .suddenDeathPractice: return "Start Pressure Drill"
        case .ahCounterPractice:   return "Start Filler Control"
        case .imPractice:          return "Start Conversation Practice"
        default:                   return "Start this exercise"
        }
    }

    /// PracticeModeQuickStart counterpart for a detected destination.
    /// Ask Noum uses this before navigation so a coach-prescribed drill
    /// behaves like a human coach handing you the rep, not another setup stop.
    static func quickStartMode(for destination: AppDestination) -> PracticeMode? {
        switch destination {
        case .timedPractice, .timedPracticePrompt:
            return .timed
        case .suddenDeathPractice:
            return .suddenDeath
        case .ahCounterPractice:
            return .ahCounter
        case .imPractice:
            return .imConversation
        default:
            return nil
        }
    }

    private static func launchProjection(
        requestedMode: PracticeMode,
        modeAvailability: NextActionModeAvailability,
        imAvailable: Bool
    ) -> LaunchProjection {
        let sharedProjection = PracticeModeLaunchProjection.resolve(
            displayedMode: requestedMode,
            imAvailable: imAvailable,
            modeAvailability: modeAvailability
        )
        // The shared projection is the final defensive authority. Ask Noum
        // only adds its action-shaped copy and Quick Start handshake around
        // the route every recommendation surface resolves through.
        let resolvedMode = sharedProjection.launchedMode
        return LaunchProjection(
            mode: resolvedMode,
            label: label(for: sharedProjection.destination),
            quickStartMode: resolvedMode,
            destination: sharedProjection.destination
        )
    }
}
