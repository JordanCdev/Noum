#if canImport(SwiftUI)
import Foundation
import Combine
import CryptoKit
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
    /// Bump only when the trust contract for generated proof copy changes.
    /// A missing value identifies a legacy record whose voice provenance is
    /// unknowable, so replay surfaces fail closed instead of guessing.
    static let currentStyleTrustVersion = 1

    var id: UUID { sessionID }
    let sessionID: UUID
    let proof: ProofMoment
    let addedAt: Date
    let voiceAtGeneration: SpeakingStyleGoal?
    let styleTrustVersion: Int?

    init(
        sessionID: UUID,
        proof: ProofMoment,
        addedAt: Date = Date(),
        voiceAtGeneration: SpeakingStyleGoal? = nil,
        styleTrustVersion: Int? = Self.currentStyleTrustVersion
    ) {
        self.sessionID = sessionID
        self.proof = proof
        self.addedAt = addedAt
        self.voiceAtGeneration = voiceAtGeneration
        self.styleTrustVersion = styleTrustVersion
    }

    /// Only proof generated under the current trust contract and the exact
    /// current explicit voice choice may be replayed. Exact optional equality
    /// deliberately allows a newly generated neutral proof for an unchosen
    /// profile, while withholding legacy records whose version is absent.
    func isCompatible(with chosenStyleGoal: SpeakingStyleGoal?) -> Bool {
        styleTrustVersion == Self.currentStyleTrustVersion
            && voiceAtGeneration == chosenStyleGoal
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID
        case proof
        case addedAt
        case voiceAtGeneration
        case styleTrustVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        proof = try container.decode(ProofMoment.self, forKey: .proof)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        voiceAtGeneration = try container.decodeIfPresent(
            SpeakingStyleGoal.self,
            forKey: .voiceAtGeneration
        )
        styleTrustVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .styleTrustVersion
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(proof, forKey: .proof)
        try container.encode(addedAt, forKey: .addedAt)
        // Encode nil explicitly. The version is the authoritative legacy
        // discriminator, but keeping the key makes new neutral provenance
        // inspectable rather than relying on an omitted optional.
        try container.encode(voiceAtGeneration, forKey: .voiceAtGeneration)
        try container.encode(styleTrustVersion, forKey: .styleTrustVersion)
    }
}

/// Account-, lifecycle-, and session-store-scoped lease for one exact saved
/// session used by an asynchronous Proof Moment request. The source snapshot
/// reuses the same inspectable value contract as generated Coach Read
/// persistence: a provider result can commit only while the identity epoch,
/// loaded session-store epoch, and every source field still match.
struct ProofMomentSaveToken: Equatable {
    let accountScope: String
    let accountLifecycleGeneration: UInt64
    let sessionStoreEpoch: PracticeSessionStoreEpoch
    let source: CoachReadSourceSnapshot
    let generationIdentity: String

    var sourceRevision: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+infinity",
            negativeInfinity: "-infinity",
            nan: "nan"
        )
        let data = (try? encoder.encode(source))
            ?? Data(source.sessionID.uuidString.utf8)
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Process-local cache namespace. Session ID stays first so invalidating a
    /// session removes every account/epoch/voice variant without parsing user
    /// text. Account and lifecycle scope prevent a cache hit after hydration,
    /// sign-out, or a rapid return to the same account ID.
    var cacheIdentity: String {
        [
            source.sessionID.uuidString,
            accountScope,
            String(accountLifecycleGeneration),
            String(sessionStoreEpoch.generation),
            sourceRevision,
            generationIdentity,
        ].joined(separator: "|")
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
    private let accountLifecycleGenerationProvider: () -> UInt64
    private let accountIsReadyProvider: () -> Bool
    private let sourceProvider: (UUID) -> AccountScopedPracticeSession?

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil,
        accountLifecycleGenerationProvider: (() -> UInt64)? = nil,
        accountIsReadyProvider: (() -> Bool)? = nil,
        sourceProvider: ((UUID) -> AccountScopedPracticeSession?)? = nil
    ) {
        self.defaults = defaults
        if let provider = accountIDProvider {
            self.accountIDProvider = provider
        } else {
            self.accountIDProvider = { Self.defaultAccountIDProvider() }
        }
        if let provider = accountLifecycleGenerationProvider {
            self.accountLifecycleGenerationProvider = provider
        } else {
            self.accountLifecycleGenerationProvider = {
                AuthManager.shared.accountLifecycleGeneration
            }
        }
        if let provider = accountIsReadyProvider {
            self.accountIsReadyProvider = provider
        } else {
            self.accountIsReadyProvider = {
                AuthManager.shared.isSignedIn
                    && AuthManager.shared.initialAccountHydrationState == .ready
            }
        }
        if let provider = sourceProvider {
            self.sourceProvider = provider
        } else {
            self.sourceProvider = { sessionID in
                PracticeSessionStore.shared.accountScopedSession(id: sessionID)
            }
        }
        loadFromDisk()
    }

    /// Captures the input and its lease synchronously on the main actor before
    /// provider work can suspend. A detached input, signed-out transition, or
    /// row still loaded from another account cannot be relabelled later.
    func generationRequest(
        for input: ProofMomentInput
    ) -> ProofMomentGenerationRequest? {
        guard accountIsReadyProvider(),
              let accountScope = accountIDProvider(),
              !accountScope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let ownedSource = sourceProvider(input.session.id),
              ownedSource.epoch.accountScope == accountScope,
              ownedSource.session.coachReadSourceSnapshot
                == input.session.coachReadSourceSnapshot else {
            return nil
        }
        let token = ProofMomentSaveToken(
            accountScope: accountScope,
            accountLifecycleGeneration: accountLifecycleGenerationProvider(),
            sessionStoreEpoch: ownedSource.epoch,
            source: ownedSource.session.coachReadSourceSnapshot,
            generationIdentity: ProofMomentService.generationIdentity(for: input)
        )
        return ProofMomentGenerationRequest(
            input: input,
            saveToken: token
        )
    }

    /// Revalidates the account epoch and exact source synchronously on the main
    /// actor. Callers use this both at the archive boundary and immediately
    /// before assigning an async result to a rendered surface.
    func tokenIsCurrent(_ token: ProofMomentSaveToken) -> Bool {
        guard accountIsReadyProvider(),
              token.accountScope == accountIDProvider(),
              token.accountLifecycleGeneration == accountLifecycleGenerationProvider(),
              let ownedSource = sourceProvider(token.source.sessionID),
              ownedSource.epoch == token.sessionStoreEpoch else {
            return false
        }
        return token.source == ownedSource.session.coachReadSourceSnapshot
    }

    /// Persist a proof for the given session. Idempotent on `sessionID`
    /// — re-saving replaces the existing record rather than appending,
    /// so a refresh from a now-configured AI provider correctly
    /// upgrades the cached deterministic proof.
    func record(
        _ proof: ProofMoment,
        for sessionID: UUID,
        voiceAtGeneration: SpeakingStyleGoal? = nil,
        at date: Date = Date()
    ) {
        let entry = ProofMomentRecord(
            sessionID: sessionID,
            proof: proof,
            addedAt: date,
            voiceAtGeneration: voiceAtGeneration
        )
        upsert(entry)
    }

    /// Compare-and-save boundary for asynchronous generation. Account or
    /// source drift returns nil without touching in-memory state or disk. The
    /// quote/date checks keep the archive tied to the exact token source even
    /// if a future service caller skips its own response validation.
    @discardableResult
    func record(
        _ proof: ProofMoment,
        expected token: ProofMomentSaveToken,
        voiceAtGeneration: SpeakingStyleGoal? = nil,
        at date: Date = Date()
    ) -> ProofMomentRecord? {
        guard tokenIsCurrent(token),
              proof.sessionDate == token.source.date,
              ProofMomentService.transcriptContains(
                proof.quote,
                in: token.source.transcript
              ) else {
            return nil
        }
        let entry = ProofMomentRecord(
            sessionID: token.source.sessionID,
            proof: proof,
            addedAt: date,
            voiceAtGeneration: voiceAtGeneration
        )
        upsert(entry)
        return entry
    }

    private func upsert(_ entry: ProofMomentRecord) {
        let sessionID = entry.sessionID
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

    /// Current replay projection. The raw archive remains available for
    /// account export/deletion and migration, but coaching surfaces must use
    /// this projection so stale goal-shaped claims cannot leak forward.
    func compatibleRecords(with chosenStyleGoal: SpeakingStyleGoal?) -> [ProofMomentRecord] {
        records.filter { $0.isCompatible(with: chosenStyleGoal) }
    }

    func recent(
        limit: Int = 5,
        compatibleWith chosenStyleGoal: SpeakingStyleGoal?
    ) -> [ProofMomentRecord] {
        Array(compatibleRecords(with: chosenStyleGoal)
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

    func weeklyGroups(
        compatibleWith chosenStyleGoal: SpeakingStyleGoal?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [(weekStart: Date, label: String, records: [ProofMomentRecord])] {
        ProofMomentStore.weeklyGroups(
            from: compatibleRecords(with: chosenStyleGoal),
            now: now,
            calendar: calendar
        )
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

    func reloadForCurrentAccount() {
        loadFromDisk()
    }

    func endSession() {
        records = []
    }

    func deleteAllData(for accountID: String) {
        defaults.removeObject(forKey: key(for: accountID))
        if accountIDProvider() == accountID {
            records = []
        }
    }

    // MARK: - Persistence

    private var currentKey: String {
        let id = accountIDProvider() ?? "guest"
        return key(for: id)
    }

    private func key(for accountID: String) -> String {
        "\(Self.storagePrefix).\(accountID)"
    }

    private func loadFromDisk() {
        guard let data = defaults.data(forKey: currentKey),
              let decoded = try? JSONDecoder().decode([ProofMomentRecord].self, from: data) else {
            records = []
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

#if DEBUG
@available(iOS 17.0, macOS 12.0, *)
extension ProofMomentStore {
    /// Replace proof archive entries for deterministic DEBUG seed personas.
    /// Production writes still flow through `ProofMomentService`.
    func replaceForDebug(_ seededRecords: [ProofMomentRecord]) {
        records = Array(seededRecords.prefix(Self.maxStoredRecords))
        persist()
    }
}
#endif

#endif
