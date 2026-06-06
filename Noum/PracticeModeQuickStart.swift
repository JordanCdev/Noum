import Foundation

/// Cross-view contract for the "Start now" affordance on the mode picker.
///
/// The picker arms a single UserDefaults flag with the target mode; the
/// destination practice view consumes (and clears) the flag inside its
/// `.task`, then triggers its existing `beginSession` / `beginCountdown` /
/// `beginConversation` entry point. Defaults for each mode are already
/// baked into the view's own state (Timed reads its `@AppStorage` config,
/// Sudden Death its difficulty, IM falls back to `.socialCatchUp` +
/// `.confident`, Cut the Crutch's init picks a top user crutch or
/// `"actually"`), so Quick Start is purely a "skip the setup tap" — never
/// a parallel config path.
enum PracticeModeQuickStart {
    /// Single-flag handshake. Stores the raw value of the armed mode, or
    /// is absent when no Quick Start is pending. Cleared the moment a
    /// consumer reads its mode — re-arming for the same mode requires a
    /// fresh tap.
    static let armedModeKey = "practiceMode.quickStart.armedMode"

    /// Arm the flag for `mode` before pushing onto the navigation path.
    /// Caller is responsible for the navigation push itself; this only
    /// signals "auto-begin on land".
    static func arm(for mode: PracticeMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: armedModeKey)
    }

    /// True when the picker armed Quick Start for `mode`. Always clears
    /// the flag on read so a single set produces a single consumption —
    /// re-renders, view tear-down/restore, or accidental double-fires
    /// can't re-trigger the begin call.
    static func consume(for mode: PracticeMode) -> Bool {
        guard let raw = UserDefaults.standard.string(forKey: armedModeKey),
              raw == mode.rawValue else { return false }
        UserDefaults.standard.removeObject(forKey: armedModeKey)
        return true
    }

    /// Clear without consumption. The picker calls this on appear so a
    /// stale flag (e.g. user armed → backed out before navigation
    /// landed) never lingers into the next session.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: armedModeKey)
    }

    /// Cut the Crutch isn't a `PracticeMode` (it's a sibling drill), so
    /// it gets its own armed flag. Same semantics as the four pressure
    /// modes — Boolean here because there's only one drill to address.
    static let crutchArmedKey = "practiceMode.quickStart.crutchArmed"

    static func armCrutch() {
        UserDefaults.standard.set(true, forKey: crutchArmedKey)
    }

    static func consumeCrutch() -> Bool {
        guard UserDefaults.standard.bool(forKey: crutchArmedKey) else { return false }
        UserDefaults.standard.removeObject(forKey: crutchArmedKey)
        return true
    }

    static func clearCrutch() {
        UserDefaults.standard.removeObject(forKey: crutchArmedKey)
    }
}
