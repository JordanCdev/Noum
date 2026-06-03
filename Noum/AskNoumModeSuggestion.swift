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
//     launch (a card that says "Sudden Death" when the coach meant a calm
//     conversation rep erodes trust fast).
// Pure + fully unit-testable; no SwiftUI, no model call.
enum AskNoumModeSuggestion {

    /// The single launchable destination implied by a coach reply, or nil.
    static func detect(in reply: String) -> AppDestination? {
        let t = reply.lowercased()

        // Explicit mode / drill names — highest confidence.
        if t.contains("ah-counter") || t.contains("ah counter") || t.contains("filler") {
            return .ahCounterPractice
        }
        if t.contains("sudden death") {
            return .suddenDeathPractice
        }
        if t.contains("difficult conversation") || t.contains("im mode")
            || t.contains("conversation mode") || t.contains("audience simulation")
            || t.contains("role-play") || t.contains("roleplay") {
            return .imPractice(scenario: nil, tone: nil)
        }
        if t.contains("timed rep") || t.contains("timed round")
            || t.contains("timed mode") || t.contains("timed practice") {
            return .timedPractice
        }

        // High-confidence delivery-skill phrases → Timed (free delivery
        // practice). Kept deliberately tight to avoid false positives on
        // common words like "pace" alone.
        if t.contains("vocal variety") || t.contains("vary your pitch")
            || t.contains("vary your tone") || t.contains("pitch range")
            || t.contains("vary your delivery") {
            return .timedPractice
        }

        return nil
    }

    /// Short, action-shaped label for the launch card per destination.
    static func label(for destination: AppDestination) -> String {
        switch destination {
        case .timedPractice:       return "Start a Timed rep"
        case .suddenDeathPractice: return "Try a Sudden Death round"
        case .ahCounterPractice:   return "Start an Ah-Counter round"
        case .imPractice:          return "Open a conversation rep"
        default:                   return "Start this exercise"
        }
    }
}
