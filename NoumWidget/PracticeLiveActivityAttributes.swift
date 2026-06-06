import Foundation
#if canImport(ActivityKit)
import ActivityKit

// MARK: - Practice Live Activity Attributes
//
// Shared between the main Noum app target (which *starts* the activity)
// and the NoumWidget extension target (which *renders* it). Both targets
// must see the exact same struct definition so ActivityKit can match
// them across IPC.
//
// To keep them identical, this file is added to **both** targets. The
// widget folder receives a copy (registered via the xcodeproj script
// that wires the widget target).

@available(iOS 16.1, *)
struct PracticeLiveActivityAttributes: ActivityAttributes {
    public typealias ContentState = State

    public struct State: Codable, Hashable {
        var roundNumber: Int
        var totalRounds: Int
        /// Seconds remaining in the current round.
        var secondsRemaining: Int
        /// Filler count so far this session.
        var fillerCount: Int
        /// Phase label — "Get ready", "Speak", "Survived", "Done".
        var phase: String
    }

    /// Session start time — used to render absolute progress for the
    /// activity even if the system can't push frequent updates.
    let sessionStartedAt: Date
    /// Mode label for the activity title.
    let modeLabel: String
}

#endif
