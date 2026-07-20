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
        case .review:        return "Performance review"
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
        case .transferred:    return "Rehearsal carried over"
        case .partly:         return "Partly"
        case .didNotTransfer: return "Didn't carry"
        }
    }

    var coachClause: String {
        switch self {
        case .transferred:    return "their rehearsal carried into the moment"
        case .partly:         return "their rehearsal partly carried into the moment"
        case .didNotTransfer: return "their rehearsal didn't carry into the moment"
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
            line += " They felt \(drillTransfer.coachClause)."
        }
        if let note {
            line += " Their note: \"\(note)\"."
        }
        return line
    }
}

// MARK: - Coach acknowledgment (the receipt for a saved check-in)

/// Deterministic post-transfer coach debrief for a just-saved outcome report —
/// the human beat after the user tells their coach how the real moment
/// went. Rendered in the Home card's slot the moment they save, and
/// injected once into the Ask Noum thread so the coach has visibly
/// received the report on the next visit.
///
/// Contracts:
///   • Association language ONLY. The prep "carried" because the USER
///     reported it carried — their read, never proof the training caused
///     the result, and the copy says so.
///   • Never punish-shame. A moment that fell short gets a steady,
///     forward-looking line — never a verdict on the user, never
///     repetition of "fell short" back at them.
///   • No quotes. The user's free-text note is never echoed, so no quote
///     verification is needed and nothing sensitive is repeated.
///   • Debrief-shaped, not a bare receipt. The line has three beats:
///     acknowledgement, the user's transfer read, and the next review move.
///   • Honest. "Noted" is literal: the report persists here and reaches
///     `CoachMemoryStore.noteTransferOutcome` at the save site.
enum BigMomentOutcomeAck {
    static func line(for report: BigMomentOutcomeReport) -> String {
        let event = report.category.displayName

        return [
            opening(for: report, event: event),
            transferRead(for: report),
            nextReviewMove(for: report, event: event)
        ].joined(separator: " ")
    }

    private static func opening(for report: BigMomentOutcomeReport, event: String) -> String {
        switch report.outcome {
        case .wentWell:
            return "Good to hear the \(event) went well."
        case .mixed:
            return "Thanks for the honest read on the \(event) — mixed moments are useful evidence."
        case .fellShort:
            return "Thanks for logging the \(event) honestly; one hard room doesn't change the work — it sharpens it."
        }
    }

    private static func transferRead(for report: BigMomentOutcomeReport) -> String {
        switch report.drillTransfer {
        case .transferred:
            return "You felt the rehearsal carry into the room — your read, not proof either way."
        case .partly:
            return "You felt part of the rehearsal carry — a useful pointer to what stayed behind."
        case .didNotTransfer:
            return "You felt the rehearsal didn't carry this time — useful self-reported evidence, not a verdict on you."
        case nil:
            return "I've noted your read of the room alongside your training."
        }
    }

    private static func nextReviewMove(for report: BigMomentOutcomeReport, event: String) -> String {
        switch report.outcome {
        case .wentWell:
            return "Next review: name what held, then repeat one similar \(event) rep before the next similar moment."
        case .mixed:
            return "Next review: compare what held with what broke, then rehearse one narrower \(event) rep before the next similar moment."
        case .fellShort:
            return "Next review: isolate the first point that broke, then run one narrower \(event) rep before the next similar moment."
        }
    }
}

/// A bounded cross-event read over the user's own real-world outcome reports.
/// This is not persisted and never claims objective transfer; it only gives the
/// coach enough shape to ask a better follow-up after repeated similar moments.
struct BigMomentTransferTrend: Equatable {
    let category: BigMomentCategory
    let reportCount: Int
    let outcomeCounts: [ReportedMomentOutcome: Int]
    let audienceCounts: [ReportedAudienceResponse: Int]
    let drillTransferCounts: [ReportedDrillTransfer: Int]
    let latestRecordedAt: Date

    var contextLine: String {
        var line = "Across the user's last \(reportCount) \(category.displayName) outcome reports, they reported \(Self.outcomeClause(outcomeCounts)); room read: \(Self.audienceClause(audienceCounts))."
        if !drillTransferCounts.isEmpty {
            line += " Prep transfer read: \(Self.drillTransferClause(drillTransferCounts))."
        }
        line += " Tentative self-report pattern only; not objective evidence or proof that training caused the result."
        return line
    }

    var profileTitle: String {
        let noun = reportCount == 1 ? "check-in" : "check-ins"
        return "\(reportCount) \(category.displayName) \(noun)"
    }

    var profileDetailLine: String {
        var line = "You reported \(Self.outcomeClause(outcomeCounts)); room read: \(Self.audienceClause(audienceCounts))."
        if !drillTransferCounts.isEmpty {
            line += " Prep read: \(Self.drillTransferClause(drillTransferCounts))."
        }
        line += " Self-report only, not measured proof."
        return line
    }

    private static func outcomeClause(_ counts: [ReportedMomentOutcome: Int]) -> String {
        clause(
            ordered: ReportedMomentOutcome.allCases,
            counts: counts,
            label: { $0.chipLabel.lowercased() }
        )
    }

    private static func audienceClause(_ counts: [ReportedAudienceResponse: Int]) -> String {
        clause(
            ordered: ReportedAudienceResponse.allCases,
            counts: counts,
            label: { response in
                switch response {
                case .engaged: return "engaged"
                case .unclear: return "hard to read"
                case .resistant: return "resistant"
                }
            }
        )
    }

    private static func drillTransferClause(_ counts: [ReportedDrillTransfer: Int]) -> String {
        clause(
            ordered: ReportedDrillTransfer.allCases,
            counts: counts,
            label: { transfer in
                switch transfer {
                case .transferred: return "prep carried"
                case .partly: return "partly carried"
                case .didNotTransfer: return "did not carry"
                }
            }
        )
    }

    private static func clause<T: CaseIterable & Hashable>(
        ordered: T.AllCases,
        counts: [T: Int],
        label: (T) -> String
    ) -> String where T.AllCases: Sequence {
        let parts = ordered.compactMap { item -> String? in
            guard let count = counts[item], count > 0 else { return nil }
            return "\(count) \(label(item))"
        }
        return parts.isEmpty ? "no clear pattern yet" : parts.joined(separator: ", ")
    }
}

// MARK: - BigMomentStore

@MainActor
final class BigMomentStore: ObservableObject {
    static let shared = BigMomentStore()

    @Published private(set) var activeMoment: BigMoment?
    @Published private(set) var archive: [BigMoment] = []
    @Published private(set) var outcomeReports: [BigMomentOutcomeReport] = []

    /// Transient, in-memory only: the outcome report the user just saved
    /// this session, so Home can replace the check-in card with one quiet
    /// coach acknowledgment instead of a silent vanish. Never persisted —
    /// relaunch and account changes clear it; `consumeOutcomeAck()` clears
    /// it once the acknowledgment beat has been shown. Mirrors the
    /// `RatingStore.pendingPeakGlow` transient-celebration contract.
    @Published private(set) var pendingOutcomeAck: BigMomentOutcomeReport?

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
        pendingOutcomeAck = nil
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
        pendingOutcomeAck = nil
    }

    /// One-shot consumer for the transient post-save acknowledgment.
    /// Home calls this once the acknowledgment beat has been shown.
    func consumeOutcomeAck() {
        pendingOutcomeAck = nil
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

    func transferTrends(
        minimumReports: Int = 3,
        maxReportsPerCategory: Int = 6,
        limit: Int = 2
    ) -> [BigMomentTransferTrend] {
        Self.transferTrends(
            from: outcomeReports,
            minimumReports: minimumReports,
            maxReportsPerCategory: maxReportsPerCategory,
            limit: limit
        )
    }

    nonisolated static func transferTrends(
        from reports: [BigMomentOutcomeReport],
        minimumReports: Int = 3,
        maxReportsPerCategory: Int = 6,
        limit: Int = 2
    ) -> [BigMomentTransferTrend] {
        guard minimumReports > 0, maxReportsPerCategory > 0, limit > 0 else { return [] }
        let grouped = Dictionary(grouping: reports, by: \.category)

        let trends = grouped.compactMap { category, group -> BigMomentTransferTrend? in
            let bounded = Array(group.sorted { $0.recordedAt > $1.recordedAt }.prefix(maxReportsPerCategory))
            guard bounded.count >= minimumReports,
                  let latest = bounded.first?.recordedAt else { return nil }

            return BigMomentTransferTrend(
                category: category,
                reportCount: bounded.count,
                outcomeCounts: Dictionary(grouping: bounded, by: \.outcome).mapValues(\.count),
                audienceCounts: Dictionary(grouping: bounded, by: \.audienceResponse).mapValues(\.count),
                drillTransferCounts: Dictionary(grouping: bounded.compactMap(\.drillTransfer), by: { $0 }).mapValues(\.count),
                latestRecordedAt: latest
            )
        }

        return Array(trends.sorted { $0.latestRecordedAt > $1.latestRecordedAt }.prefix(limit))
    }

    /// Qualifying prep-transfer read for `category`, when enough reports exist
    /// to clear the same honesty floor as `transferTrends`. Returns a read only
    /// when the prep-transfer answers themselves clear the floor and one answer
    /// is the strict plurality. A tie, missing transfer answers, or thin data
    /// returns nil so downstream coaching surfaces stay quiet.
    nonisolated static func dominantTransferRead(
        for category: BigMomentCategory,
        in reports: [BigMomentOutcomeReport],
        minimumReports: Int = 3,
        maxReportsPerCategory: Int = 6
    ) -> ReportedDrillTransfer? {
        guard let trend = transferTrends(
            from: reports,
            minimumReports: minimumReports,
            maxReportsPerCategory: maxReportsPerCategory,
            limit: BigMomentCategory.allCases.count
        ).first(where: { $0.category == category }) else { return nil }

        let counts = trend.drillTransferCounts
        let transferReadCount = counts.values.reduce(0, +)
        guard transferReadCount >= minimumReports else { return nil }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        let tiedAtTop = counts.values.filter { $0 == top.value }.count
        guard tiedAtTop == 1 else { return nil }
        return top.key
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
        // Surface the one-shot coach acknowledgment in the card's slot —
        // a save must never be a silent vanish.
        pendingOutcomeAck = report
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
            pendingOutcomeAck = nil
        }
    }
}

#if DEBUG
extension BigMomentStore {
    /// Replace active moment and transfer reports for deterministic DEBUG seed
    /// personas. Keeps the same in-memory owners the live app reads.
    func replaceForDebug(
        activeMoment: BigMoment?,
        outcomeReports seededReports: [BigMomentOutcomeReport]
    ) {
        let accountID = currentAccountID ?? "guest"
        self.activeMoment = activeMoment
        archive = []
        outcomeReports = Array(seededReports.prefix(Self.outcomeReportCap))
        pendingOutcomeAck = nil

        if let activeMoment, let data = try? JSONEncoder().encode(activeMoment) {
            defaults.set(data, forKey: activeMomentKey(for: accountID))
        } else {
            defaults.removeObject(forKey: activeMomentKey(for: accountID))
        }
        if let data = try? JSONEncoder().encode(outcomeReports) {
            defaults.set(data, forKey: outcomesKey(for: accountID))
        }
        defaults.removeObject(forKey: archiveKey(for: accountID))
    }
}
#endif
