import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - BigMoment Model

enum BigMomentCategory: String, Codable, CaseIterable {
    case presentation
    case interview
    case review
    case conversation
    case publicSpeaking
    case other

    var title: String {
        switch self {
        case .presentation:  return "Presentation"
        case .interview:     return "Interview"
        case .review:        return "Review"
        case .conversation:  return "Conversation"
        case .publicSpeaking: return "Public speaking"
        case .other:         return "Other"
        }
    }

    var sfSymbol: String {
        switch self {
        case .presentation:  return "briefcase"
        case .interview:     return "person.crop.rectangle"
        case .review:        return "calendar.badge.clock"
        case .conversation:  return "text.bubble"
        case .publicSpeaking: return "mic.fill"
        case .other:         return "square.grid.2x2"
        }
    }

    /// Lowercase, sentence-embeddable form for coach copy and
    /// lock-screen notification bodies — "7 days to your presentation."
    /// reads better than "...your Presentation." with a mid-sentence
    /// capital. Use `title` for standalone labels (settings rows, sheet
    /// headers); use `displayName` inside running sentences.
    var displayName: String {
        switch self {
        case .presentation:  return "presentation"
        case .interview:     return "interview"
        case .review:        return "performance review"
        case .conversation:  return "difficult conversation"
        case .publicSpeaking: return "public speaking event"
        case .other:         return "big moment"
        }
    }
}

struct BigMoment: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var date: Date?
    var category: BigMomentCategory
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        date: Date? = nil,
        category: BigMomentCategory,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.category = category
        self.createdAt = createdAt
    }
}

// MARK: - Real-World Outcome Report

/// User-owned account of how a completed real-world moment went. This is
/// deliberately not derived from practice metrics: Noum can prepare for an
/// interview or presentation, but only the user can report what happened.
enum ReportedMomentOutcome: String, Codable, CaseIterable, Identifiable {
    case wentWell
    case mixed
    case fellShort

    var id: String { rawValue }

    var chipLabel: String {
        switch self {
        case .wentWell:  return "Went well"
        case .mixed:     return "Mixed"
        case .fellShort: return "Fell short"
        }
    }

    var coachClause: String {
        switch self {
        case .wentWell:  return "it went well"
        case .mixed:     return "it was mixed"
        case .fellShort: return "it fell short of what they wanted"
        }
    }
}

/// The user's perception of the room or counterpart during the completed
/// moment. Kept separate from outcome so the coach can learn whether a
/// polished performance actually appeared to connect.
enum ReportedAudienceResponse: String, Codable, CaseIterable, Identifiable {
    case engaged
    case unclear
    case resistant

    var id: String { rawValue }

    var chipLabel: String {
        switch self {
        case .engaged:   return "They engaged"
        case .unclear:   return "Hard to tell"
        case .resistant: return "Met resistance"
        }
    }

    var coachClause: String {
        switch self {
        case .engaged:   return "the audience or counterpart seemed engaged"
        case .unclear:   return "their response was hard to read"
        case .resistant: return "they perceived resistance"
        }
    }
}

/// F4b — the user's read on whether their PREP / prescribed drill carried into
/// the real moment. Deliberately framed as what they FELT, never as proof the
/// drill caused the outcome (the no-causation contract). Kept separate from
/// `outcome` so the coach can learn whether training is transferring even when
/// the moment itself went mixed or poorly.
enum ReportedDrillTransfer: String, Codable, CaseIterable, Identifiable {
    case transferred
    case partly
    case didNotTransfer

    var id: String { rawValue }

    var chipLabel: String {
        switch self {
        case .transferred:    return "Prep carried over"
        case .partly:         return "Partly"
        case .didNotTransfer: return "Didn't carry"
        }
    }

    var coachClause: String {
        switch self {
        case .transferred:    return "they felt their prep carried into the moment"
        case .partly:         return "they felt their prep partly carried into the moment"
        case .didNotTransfer: return "they felt their prep didn't carry into the moment"
        }
    }
}

struct BigMomentOutcomeReport: Codable, Identifiable, Equatable {
    static let noteCharacterLimit = 180

    let id: UUID
    let momentID: UUID
    let momentTitle: String
    let category: BigMomentCategory
    let outcome: ReportedMomentOutcome
    let audienceResponse: ReportedAudienceResponse
    let note: String?
    /// F4b — the user's read on whether their prep transferred. User-reported,
    /// never proof the drill caused the outcome. Optional → reports persisted
    /// before F4b decode with nil (synthesized Decodable, optional key).
    let drillTransfer: ReportedDrillTransfer?
    let recordedAt: Date

    init(
        id: UUID = UUID(),
        moment: BigMoment,
        outcome: ReportedMomentOutcome,
        audienceResponse: ReportedAudienceResponse,
        note: String? = nil,
        drillTransfer: ReportedDrillTransfer? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.momentID = moment.id
        self.momentTitle = moment.title
        self.category = moment.category
        self.outcome = outcome
        self.audienceResponse = audienceResponse
        let normalizedNote = note?
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        if let normalizedNote, !normalizedNote.isEmpty {
            self.note = String(normalizedNote.prefix(Self.noteCharacterLimit))
        } else {
            self.note = nil
        }
        self.drillTransfer = drillTransfer
        self.recordedAt = recordedAt
    }

    /// Bounded, explicitly user-reported language for the AI coach context.
    var coachContextLine: String {
        var line = "For \(category.displayName) \"\(momentTitle)\", the user reported \(outcome.coachClause); \(audienceResponse.coachClause)."
        if let drillTransfer {
            line += " On their prep, \(drillTransfer.coachClause)."
        }
        if let note {
            line += " Their note: \"\(note)\"."
        }
        return line
    }
}

// MARK: - BigMomentStore

@MainActor
final class BigMomentStore: ObservableObject {
    static let shared = BigMomentStore()

    @Published private(set) var activeMoment: BigMoment?
    @Published private(set) var archive: [BigMoment] = []
    @Published private(set) var outcomeReports: [BigMomentOutcomeReport] = []

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?
    private let activeMomentKeyPrefix = "bigMoment."
    private let archiveKeyPrefix = "bigMomentArchive."
    private let outcomesKeyPrefix = "bigMomentOutcomes."
    private static let archiveCap = 5
    static let outcomeReportCap = 12

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: @escaping () -> String? = { KeychainHelper.load(key: "NoumAccountID") }
    ) {
        self.defaults = defaults
        self.accountIDProvider = accountIDProvider
    }

    // MARK: - Lifecycle

    func reloadForCurrentAccount() {
        guard let accountID = currentAccountID else {
            activeMoment = nil
            archive = []
            outcomeReports = []
            return
        }
        activeMoment = loadMoment(forKey: activeMomentKey(for: accountID))
        archive = Self.loadArchive(forKey: archiveKey(for: accountID), defaults: defaults)
        outcomeReports = Self.loadOutcomes(forKey: outcomesKey(for: accountID), defaults: defaults)
        archiveExpiredIfNeeded(accountID: accountID)
    }

    func endSession() {
        activeMoment = nil
        archive = []
        outcomeReports = []
    }

    // MARK: - API

    func setMoment(_ moment: BigMoment) {
        guard let accountID = currentAccountID else { return }
        activeMoment = moment
        persist(accountID: accountID)
    }

    func clearMoment() {
        guard let accountID = currentAccountID else { return }
        activeMoment = nil
        defaults.removeObject(forKey: activeMomentKey(for: accountID))
    }

    /// Re-evaluate an active dated moment when Home appears or remains open
    /// across its due date. Sign-in also calls this as part of reload.
    func archiveExpiredIfNeeded() {
        guard let accountID = currentAccountID else { return }
        archiveExpiredIfNeeded(accountID: accountID)
    }

    func daysUntil() -> Int? {
        guard let moment = activeMoment else { return nil }
        return Self.daysUntil(moment)
    }

    /// Days from today until `moment.date`, or nil if no date is set.
    /// Negative values mean the moment has passed. `nonisolated` because
    /// this is pure calendar math — no `activeMoment` read needed — so
    /// non-MainActor callers (e.g. `CoachContextBuilder.userContext`)
    /// can use it directly.
    nonisolated static func daysUntil(_ moment: BigMoment) -> Int? {
        guard let date = moment.date else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: today, to: target)
        return components.day
    }

    nonisolated func daysUntil(_ moment: BigMoment) -> Int? {
        Self.daysUntil(moment)
    }

    /// Most recent archived moment the user has not yet reflected on.
    var pendingOutcomeCheckInMoment: BigMoment? {
        archive.first { moment in
            !outcomeReports.contains { $0.momentID == moment.id }
        }
    }

    func recentOutcomeReports(limit: Int = 2) -> [BigMomentOutcomeReport] {
        guard limit > 0 else { return [] }
        return Array(outcomeReports.prefix(limit))
    }

    @discardableResult
    func recordOutcome(
        for moment: BigMoment,
        outcome: ReportedMomentOutcome,
        audienceResponse: ReportedAudienceResponse,
        note: String? = nil,
        drillTransfer: ReportedDrillTransfer? = nil
    ) -> BigMomentOutcomeReport? {
        guard let accountID = currentAccountID else { return nil }
        let report = BigMomentOutcomeReport(
            moment: moment,
            outcome: outcome,
            audienceResponse: audienceResponse,
            note: note,
            drillTransfer: drillTransfer
        )
        var updated = outcomeReports.filter { $0.momentID != moment.id }
        updated.insert(report, at: 0)
        outcomeReports = Array(updated.prefix(Self.outcomeReportCap))
        persistOutcomeReports(accountID: accountID)
        return report
    }

    // MARK: - Private

    private func archiveExpiredIfNeeded(accountID: String) {
        guard let moment = activeMoment,
              let date = moment.date,
              date < Calendar.current.startOfDay(for: Date()) else { return }
        var updatedArchive = archive
        updatedArchive.insert(moment, at: 0)
        if updatedArchive.count > Self.archiveCap {
            updatedArchive = Array(updatedArchive.prefix(Self.archiveCap))
        }
        archive = updatedArchive
        activeMoment = nil
        defaults.removeObject(forKey: activeMomentKey(for: accountID))
        if let data = try? JSONEncoder().encode(updatedArchive) {
            defaults.set(data, forKey: archiveKey(for: accountID))
        }
    }

    private func persist(accountID: String) {
        if let moment = activeMoment, let data = try? JSONEncoder().encode(moment) {
            defaults.set(data, forKey: activeMomentKey(for: accountID))
        }
    }

    private func persistOutcomeReports(accountID: String) {
        if let data = try? JSONEncoder().encode(outcomeReports) {
            defaults.set(data, forKey: outcomesKey(for: accountID))
        }
    }

    private func activeMomentKey(for accountID: String) -> String {
        "\(activeMomentKeyPrefix)\(accountID)"
    }

    private func archiveKey(for accountID: String) -> String {
        "\(archiveKeyPrefix)\(accountID)"
    }

    private func outcomesKey(for accountID: String) -> String {
        "\(outcomesKeyPrefix)\(accountID)"
    }

    private var currentAccountID: String? {
        accountIDProvider()
    }

    private func loadMoment(forKey key: String) -> BigMoment? {
        guard let data = defaults.data(forKey: key),
              let moment = try? JSONDecoder().decode(BigMoment.self, from: data) else { return nil }
        return moment
    }

    private static func loadArchive(forKey key: String, defaults: UserDefaults) -> [BigMoment] {
        guard let data = defaults.data(forKey: key),
              let moments = try? JSONDecoder().decode([BigMoment].self, from: data) else { return [] }
        return moments
    }

    private static func loadOutcomes(forKey key: String, defaults: UserDefaults) -> [BigMomentOutcomeReport] {
        guard let data = defaults.data(forKey: key),
              let reports = try? JSONDecoder().decode([BigMomentOutcomeReport].self, from: data) else { return [] }
        return reports
    }

    // MARK: - Auth Wipe

    func deleteAllData(for accountID: String) {
        defaults.removeObject(forKey: activeMomentKey(for: accountID))
        defaults.removeObject(forKey: archiveKey(for: accountID))
        defaults.removeObject(forKey: outcomesKey(for: accountID))
        if currentAccountID == accountID {
            activeMoment = nil
            archive = []
            outcomeReports = []
        }
    }
}
