#if canImport(SwiftUI)
import Foundation
import Combine
#if canImport(Security)
import Security
#endif

// MARK: - Proof Moment Archive
//
// Persistent, per-account log of transcript-anchored "proof moments" the
// user has generated across sessions. The Ask Noum coach reads from this
// archive so its replies can quote the user's actual past words back
// ("Three weeks ago you said 'we focused on three priorities' — that's
// the move you've been refining"). Without the archive, every proof was
// born and died inside a single in-memory cache; the chat surface had
// numbers but never the user's voice.
//
// Design rules (mirror AskNoumStore):
//   • Per-account persistence via UserDefaults keyed `<prefix>.<accountID>`.
//   • Bounded — last 12 records on disk. Older records drop off the
//     front. Twelve is enough to feed two or three voice-shaped chat
//     replies without inflating the system prompt; we don't need every
//     proof the user has ever earned, just the recent ones.
//   • De-duplicated by session ID. Re-saving the same session's proof
//     (e.g. a re-fetch with a fresh AI provider) replaces the existing
//     record rather than producing two rows from one rep.
//   • Sorted most-recent-first when read. The model gets the newest
//     evidence first; that's also what the future Profile library card
//     will want.
//   • Failure-soft. A corrupt blob on disk is dropped silently — the
//     archive falls back to empty rather than crashing the chat surface
//     on a malformed write from an earlier build.

/// One persisted proof entry. Wraps `ProofMoment` with the source
/// session ID + an `addedAt` stamp so the archive can de-dupe and
/// order without round-tripping through any other store.
struct ProofMomentRecord: Codable, Identifiable, Equatable {
    var id: UUID { sessionID }
    let sessionID: UUID
    let proof: ProofMoment
    let addedAt: Date

    init(sessionID: UUID, proof: ProofMoment, addedAt: Date = Date()) {
        self.sessionID = sessionID
        self.proof = proof
        self.addedAt = addedAt
    }
}

/// Per-account observable archive of proof moments. Reads / writes are
/// `@MainActor` so the published `records` array stays SwiftUI-safe;
/// writers from `ProofMomentService` (an actor) hop here via the usual
/// `await MainActor.run { ... }` shape.
@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class ProofMomentStore: ObservableObject {

    static let shared = ProofMomentStore()

    /// Cap on persisted records. Twelve covers ~2 weeks of daily reps;
    /// older proofs drop off the front. The chat surface only reads
    /// the most-recent few, so we don't need a deeper archive.
    static let maxStoredRecords = 12

    /// Storage key prefix. Joined with the account ID the same way
    /// every other per-account value is keyed.
    private static let storagePrefix = "proofMoment.archive"

    @Published private(set) var records: [ProofMomentRecord] = []

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil
    ) {
        self.defaults = defaults
        if let provider = accountIDProvider {
            self.accountIDProvider = provider
        } else {
            self.accountIDProvider = { Self.defaultAccountIDProvider() }
        }
        loadFromDisk()
    }

    /// Persist a proof for the given session. Idempotent on `sessionID`
    /// — re-saving replaces the existing record rather than appending,
    /// so a refresh from a now-configured AI provider correctly
    /// upgrades the cached deterministic proof.
    func record(_ proof: ProofMoment, for sessionID: UUID, at date: Date = Date()) {
        let entry = ProofMomentRecord(sessionID: sessionID, proof: proof, addedAt: date)
        if let existing = records.firstIndex(where: { $0.sessionID == sessionID }) {
            records[existing] = entry
        } else {
            records.append(entry)
        }
        trimAndPersist()
    }

    /// Read most-recent-first up to `limit`. Used by the chat surface
    /// to feed `CoachContextBuilder.userContext` and (later) the
    /// Profile library card.
    func recent(limit: Int = 5) -> [ProofMomentRecord] {
        Array(records
            .sorted { $0.proof.sessionDate > $1.proof.sessionDate }
            .prefix(max(0, limit)))
    }

    /// Group all records into week-buckets for the Growth Library surface.
    /// Bucket key is the start-of-week date in the supplied calendar; the
    /// returned tuples are ordered newest-week-first, and within each week
    /// the records are most-recent-first by `proof.sessionDate`. Empty
    /// archive returns an empty array — caller renders no list.
    func weeklyGroups(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [(weekStart: Date, label: String, records: [ProofMomentRecord])] {
        ProofMomentStore.weeklyGroups(from: records, now: now, calendar: calendar)
    }

    /// Pure-function variant — tests drive it directly without touching
    /// the shared instance. Same shape as the instance method.
    nonisolated static func weeklyGroups(
        from records: [ProofMomentRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [(weekStart: Date, label: String, records: [ProofMomentRecord])] {
        guard !records.isEmpty else { return [] }
        let buckets = Dictionary(grouping: records) { record -> Date in
            calendar.dateInterval(of: .weekOfYear, for: record.proof.sessionDate)?.start
                ?? calendar.startOfDay(for: record.proof.sessionDate)
        }
        let sortedKeys = buckets.keys.sorted(by: >)
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
        return sortedKeys.map { key in
            let label = weekLabel(for: key, now: now, thisWeekStart: thisWeekStart, calendar: calendar)
            let sorted = (buckets[key] ?? []).sorted { $0.proof.sessionDate > $1.proof.sessionDate }
            return (weekStart: key, label: label, records: sorted)
        }
    }

    nonisolated private static func weekLabel(
        for weekStart: Date,
        now: Date,
        thisWeekStart: Date?,
        calendar: Calendar
    ) -> String {
        if let thisWeekStart, calendar.isDate(weekStart, inSameDayAs: thisWeekStart) {
            return "This week"
        }
        if let thisWeekStart,
           let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart),
           calendar.isDate(weekStart, inSameDayAs: lastWeekStart) {
            return "Last week"
        }
        let now = now
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        if calendar.component(.year, from: weekStart) == calendar.component(.year, from: now) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return "Week of \(formatter.string(from: weekStart))"
    }

    /// Drop a specific proof — used by callers that want to invalidate
    /// after a transcript edit (rare; sessions are immutable in
    /// practice) or by a future "forget this moment" surface.
    func remove(sessionID: UUID) {
        records.removeAll { $0.sessionID == sessionID }
        persist()
    }

    /// Wipe the archive — sign-out path + Settings reset hook.
    func clear() {
        records.removeAll()
        persist()
    }

    // MARK: - Persistence

    private var currentKey: String {
        let id = accountIDProvider() ?? "guest"
        return "\(Self.storagePrefix).\(id)"
    }

    private func loadFromDisk() {
        guard let data = defaults.data(forKey: currentKey),
              let decoded = try? JSONDecoder().decode([ProofMomentRecord].self, from: data) else {
            return
        }
        records = decoded
    }

    private func trimAndPersist() {
        if records.count > Self.maxStoredRecords {
            // Drop the oldest by `addedAt` so refresh-replaces don't
            // accidentally evict a record we just upgraded.
            records.sort { $0.addedAt < $1.addedAt }
            records.removeFirst(records.count - Self.maxStoredRecords)
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: currentKey)
    }

    // MARK: - Account ID

    private static func defaultAccountIDProvider() -> String? {
        #if canImport(Security)
        return KeychainHelper.load(key: "NoumAccountID")
        #else
        return nil
        #endif
    }
}

#endif
