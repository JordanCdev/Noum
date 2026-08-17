import Foundation

/// The exact recommendation the user accepted before a one-tap practice
/// launch. This is deliberately a bounded value, not another recommendation
/// store: Home's existing exposure ledger remains authoritative, while this
/// payload prevents the live view from re-deriving different copy or demand
/// after navigation.
struct PracticeQuickStartIntent: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let maximumAge: TimeInterval = 120
    static let maximumFingerprintCharacters = 2_048
    static let maximumCopyCharacters = 180

    let schemaVersion: Int
    let fingerprint: String
    let focus: String
    let target: String
    let mode: PracticeMode
    let prescribedDemand: PracticeSessionDemand?
    let acceptedAt: Date

    init?(
        fingerprint: String,
        focus: String,
        target: String,
        mode: PracticeMode,
        prescribedDemand: PracticeSessionDemand?,
        acceptedAt: Date = Date()
    ) {
        let fingerprint = fingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
        let focus = focus.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fingerprint.isEmpty,
              fingerprint.count <= Self.maximumFingerprintCharacters,
              !focus.isEmpty,
              focus.count <= Self.maximumCopyCharacters,
              !target.isEmpty,
              target.count <= Self.maximumCopyCharacters,
              acceptedAt.timeIntervalSince1970.isFinite,
              prescribedDemand.map({ $0.isValid(for: mode) }) ?? true else {
            return nil
        }
        self.schemaVersion = Self.currentSchemaVersion
        self.fingerprint = fingerprint
        self.focus = focus
        self.target = target
        self.mode = mode
        self.prescribedDemand = prescribedDemand
        self.acceptedAt = acceptedAt
    }

    func isValid(at now: Date) -> Bool {
        guard schemaVersion == Self.currentSchemaVersion,
              acceptedAt.timeIntervalSince1970.isFinite,
              now.timeIntervalSince1970.isFinite else { return false }
        let age = now.timeIntervalSince(acceptedAt)
        let boundedFingerprint = fingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundedFocus = focus.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        return age >= -5
            && age <= Self.maximumAge
            && !boundedFingerprint.isEmpty
            && boundedFingerprint.count <= Self.maximumFingerprintCharacters
            && !boundedFocus.isEmpty
            && boundedFocus.count <= Self.maximumCopyCharacters
            && !boundedTarget.isEmpty
            && boundedTarget.count <= Self.maximumCopyCharacters
            && (prescribedDemand.map({ $0.isValid(for: mode) }) ?? true)
    }
}

/// A successful one-shot consumption is either the legacy mode-only signal or
/// an exact recommendation contract. Keeping the legacy case lets manual
/// Quick Start callers retain their existing behavior without manufacturing a
/// coaching target they never displayed.
enum PracticeQuickStartLaunch: Equatable {
    case modeOnly
    case recommendation(PracticeQuickStartIntent)

    var recommendationIntent: PracticeQuickStartIntent? {
        guard case .recommendation(let intent) = self else { return nil }
        return intent
    }
}

/// Cross-view contract for the "Start now" affordance on the mode picker.
///
/// The picker arms a bounded UserDefaults handshake with the target mode; the
/// destination practice view consumes (and clears) the handshake inside its
/// `.task`, then triggers its existing `beginSession` / `beginCountdown` /
/// `beginConversation` entry point. Defaults for each mode are already
/// baked into the view's own state (Timed reads its `@AppStorage` config,
/// Sudden Death its difficulty, IM falls back to `.socialCatchUp` +
/// `.confident`, Cut the Crutch's init picks a top user crutch or
/// `"actually"`), so Quick Start is purely a "skip the setup tap" — never
/// a parallel config path.
enum PracticeModeQuickStart {
    /// Mode authority for both legacy mode-only and recommendation launches.
    /// `intentKey` is present only for the latter. Both are cleared together.
    static let armedModeKey = "practiceMode.quickStart.armedMode"
    static let intentKey = "practiceMode.quickStart.intent"

    /// Arm the flag for `mode` before pushing onto the navigation path.
    /// Caller is responsible for the navigation push itself; this only
    /// signals "auto-begin on land".
    static func arm(
        for mode: PracticeMode,
        defaults: UserDefaults = .standard
    ) {
        clear(defaults: defaults)
        defaults.set(mode.rawValue, forKey: armedModeKey)
    }

    /// Arm one exact accepted recommendation. Encoding failure clears the
    /// handshake rather than falling back to a mode-only auto-start, because
    /// doing so would show one target on Today and coach another in capture.
    @discardableResult
    static func arm(
        intent: PracticeQuickStartIntent,
        defaults: UserDefaults = .standard
    ) -> Bool {
        clear(defaults: defaults)
        guard intent.isValid(at: intent.acceptedAt),
              let data = try? JSONEncoder().encode(intent) else {
            return false
        }
        defaults.set(intent.mode.rawValue, forKey: armedModeKey)
        defaults.set(data, forKey: intentKey)
        return true
    }

    /// True when the picker armed Quick Start for `mode`. Always clears
    /// the flag on read so a single set produces a single consumption —
    /// re-renders, view tear-down/restore, or accidental double-fires
    /// can't re-trigger the begin call.
    static func consume(
        for mode: PracticeMode,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Bool {
        consumeLaunch(for: mode, defaults: defaults, now: now) != nil
    }

    /// Atomically consumes all quick-start authority on the first read. A mode
    /// mismatch, malformed payload, expired acceptance, or invalid demand
    /// clears both keys. That fail-closed behavior prevents a visit to another
    /// practice tab from leaving a stale recommendation armed for later.
    static func consumeLaunch(
        for mode: PracticeMode,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> PracticeQuickStartLaunch? {
        guard let raw = defaults.string(forKey: armedModeKey) else {
            // A payload without its mode authority is corrupt/stale too.
            defaults.removeObject(forKey: intentKey)
            return nil
        }
        let data = defaults.data(forKey: intentKey)
        clear(defaults: defaults)
        guard raw == mode.rawValue else { return nil }
        guard let data else { return .modeOnly }
        guard let intent = try? JSONDecoder().decode(
            PracticeQuickStartIntent.self,
            from: data
        ),
        intent.mode == mode,
        intent.isValid(at: now) else {
            return nil
        }
        return .recommendation(intent)
    }

    /// Clear without consumption. The picker calls this on appear so a
    /// stale flag (e.g. user armed → backed out before navigation
    /// landed) never lingers into the next session.
    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: armedModeKey)
        defaults.removeObject(forKey: intentKey)
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
