import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Weekly Coach Check-In (F1 — Formulation, coach-parity stage 2)
//
// A human coach asks questions; Noum generated insights but never ran a
// bidirectional check-in. This is the weekly back-channel: a few short
// questions whose ANSWERS become durable coaching context.
//
// Why a NEW bounded store (and not an existing owner):
//   • SessionReflectionStore is PER-REP (how one rep FELT). This is broader —
//     a weekly read across all of life, not one session.
//   • CoachMemoryStore is the durable CASE (hypothesis/intervention); it
//     CONSUMES check-ins via context, it doesn't own the raw log.
//   • BigMomentStore owns upcoming events + their outcomes, not weekly
//     reflection. ("What real moment is coming next" is intentionally NOT
//     duplicated here — BigMomentStore stays the single owner of upcoming
//     moments and already feeds the BIG MOMENT context section.)
// So CoachCheckInStore owns exactly one thing: a bounded, account-scoped log
// of weekly check-ins, on a no-nag weekly cadence.

/// The user's read on whether the prescribed drill is working — the observe-
/// side signal a coach asks for directly. User-reported, never inferred, and
/// never treated as proof the drill caused anything.
enum CoachDrillVerdict: String, Codable, CaseIterable, Identifiable {
    case helped
    case stalled
    case missed

    var id: String { rawValue }

    var chipLabel: String {
        switch self {
        case .helped:  return "It helped"
        case .stalled: return "Stalled"
        case .missed:  return "Missed the mark"
        }
    }

    var coachClause: String {
        switch self {
        case .helped:  return "the current drill felt like it helped"
        case .stalled: return "the current drill felt stalled"
        case .missed:  return "the current drill missed what they needed"
        }
    }
}

/// The user's own read on confidence across the week. This is deliberately
/// self-report, not inferred from score or delivery metrics.
enum CoachConfidenceShift: String, Codable, CaseIterable, Identifiable {
    case moreSteady
    case aboutSame
    case lessSteady

    var id: String { rawValue }

    var chipLabel: String {
        switch self {
        case .moreSteady: return "More steady"
        case .aboutSame:  return "About the same"
        case .lessSteady: return "Less steady"
        }
    }

    var coachClause: String {
        switch self {
        case .moreSteady: return "more steady"
        case .aboutSame:  return "about the same"
        case .lessSteady: return "less steady"
        }
    }
}

struct CoachCheckIn: Codable, Identifiable, Equatable {
    static let fieldCharacterLimit = 200

    let id: UUID
    let recordedAt: Date
    /// What felt hardest this week (free text, bounded). nil when skipped.
    let hardest: String?
    /// Where communication showed up OUTSIDE the app this week — the everyday
    /// transfer signal. nil when skipped.
    let outsideApp: String?
    /// The user's read on the current drill. nil when skipped.
    let drillVerdict: CoachDrillVerdict?
    /// The user's read on confidence this week. nil when skipped.
    let confidenceShift: CoachConfidenceShift?
    /// What the user avoided saying, if anything. nil when skipped.
    let avoidedSaying: String?

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        hardest: String? = nil,
        outsideApp: String? = nil,
        drillVerdict: CoachDrillVerdict? = nil,
        confidenceShift: CoachConfidenceShift? = nil,
        avoidedSaying: String? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.hardest = Self.normalize(hardest)
        self.outsideApp = Self.normalize(outsideApp)
        self.drillVerdict = drillVerdict
        self.confidenceShift = confidenceShift
        self.avoidedSaying = Self.normalize(avoidedSaying)
    }

    /// True when the user actually said something — an all-empty check-in is
    /// never recorded (no hollow "checked in" with no content).
    var hasContent: Bool {
        hardest != nil || outsideApp != nil || drillVerdict != nil || confidenceShift != nil || avoidedSaying != nil
    }

    private static func normalize(_ text: String?) -> String? {
        guard let collapsed = text?
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " "),
              !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(fieldCharacterLimit))
    }

    /// Bounded, explicitly user-reported lines for the AI coach context.
    var coachContextLines: [String] {
        var out: [String] = []
        if let hardest { out.append("- Hardest this week (user's words): \"\(hardest)\".") }
        if let outsideApp { out.append("- Where it showed up outside the app: \"\(outsideApp)\".") }
        if let drillVerdict { out.append("- On the current drill, the user reported \(drillVerdict.coachClause).") }
        if let confidenceShift { out.append("- Confidence this week (user-reported): \(confidenceShift.coachClause).") }
        if let avoidedSaying { out.append("- What they avoided saying (user's words): \"\(avoidedSaying)\".") }
        return out
    }
}

@MainActor
final class CoachCheckInStore: ObservableObject {
    static let shared = CoachCheckInStore()

    @Published private(set) var checkIns: [CoachCheckIn] = []

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?
    private let keyPrefix = "coachCheckIns."
    static let cap = 8
    /// No-nag cadence: a check-in is due only when the last one is at least
    /// this many days old (or there is none yet).
    static let cadenceDays = 7

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: @escaping () -> String? = { KeychainHelper.load(key: "NoumAccountID") }
    ) {
        self.defaults = defaults
        self.accountIDProvider = accountIDProvider
    }

    // MARK: - Lifecycle

    func reloadForCurrentAccount() {
        guard let accountID = currentAccountID else { checkIns = []; return }
        checkIns = Self.load(forKey: key(for: accountID), defaults: defaults)
    }

    func endSession() { checkIns = [] }

    // MARK: - API

    var latest: CoachCheckIn? { checkIns.first }

    /// True when the weekly cadence has elapsed (or there's no check-in yet).
    func isCheckInDue(now: Date = Date()) -> Bool {
        Self.isCheckInDue(latest: latest, now: now)
    }

    /// Pure cadence predicate — testable without a store. No-nag: never true
    /// twice within `cadenceDays`.
    static func isCheckInDue(latest: CoachCheckIn?, now: Date) -> Bool {
        guard let latest else { return true }
        let days = Calendar.current.dateComponents([.day], from: latest.recordedAt, to: now).day ?? 0
        return days >= cadenceDays
    }

    /// Days until the next check-in is due (0 when due now). For not-yet-due
    /// echo copy.
    func daysUntilDue(now: Date = Date()) -> Int {
        guard let latest else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: latest.recordedAt, to: now).day ?? 0
        return max(0, Self.cadenceDays - days)
    }

    func recentForContext(limit: Int = 2) -> [CoachCheckIn] {
        guard limit > 0 else { return [] }
        return Array(checkIns.prefix(limit))
    }

    @discardableResult
    func record(
        hardest: String? = nil,
        outsideApp: String? = nil,
        drillVerdict: CoachDrillVerdict? = nil,
        confidenceShift: CoachConfidenceShift? = nil,
        avoidedSaying: String? = nil,
        at now: Date = Date()
    ) -> CoachCheckIn? {
        guard let accountID = currentAccountID else { return nil }
        let checkIn = CoachCheckIn(
            recordedAt: now,
            hardest: hardest,
            outsideApp: outsideApp,
            drillVerdict: drillVerdict,
            confidenceShift: confidenceShift,
            avoidedSaying: avoidedSaying
        )
        // An all-empty check-in is a no-op — never record a hollow "checked in".
        guard checkIn.hasContent else { return nil }
        var updated = checkIns
        updated.insert(checkIn, at: 0)
        checkIns = Array(updated.prefix(Self.cap))
        persist(accountID: accountID)
        return checkIn
    }

    // MARK: - Auth Wipe

    func deleteAllData(for accountID: String) {
        defaults.removeObject(forKey: key(for: accountID))
        if currentAccountID == accountID { checkIns = [] }
    }

    // MARK: - Private

    private var currentAccountID: String? { accountIDProvider() }
    private func key(for accountID: String) -> String { "\(keyPrefix)\(accountID)" }

    private func persist(accountID: String) {
        if let data = try? JSONEncoder().encode(checkIns) {
            defaults.set(data, forKey: key(for: accountID))
        }
    }

    private static func load(forKey key: String, defaults: UserDefaults) -> [CoachCheckIn] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CoachCheckIn].self, from: data) else { return [] }
        return decoded
    }
}

#if DEBUG
extension CoachCheckInStore {
    /// Replace weekly check-ins for deterministic DEBUG seed personas.
    /// Production capture still goes through `record(...)`; this is only for
    /// local seeded inspection and UI-test launches.
    func replaceForDebug(_ seeded: [CoachCheckIn]) {
        checkIns = Array(seeded.prefix(Self.cap))
        let accountID = currentAccountID ?? "guest"
        persist(accountID: accountID)
    }
}
#endif
