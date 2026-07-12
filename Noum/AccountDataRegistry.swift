import Foundation

enum AccountDataScope: String, Codable, Equatable, Sendable {
    case account
    case legacyDeviceUnattributed
}

enum AccountDataExportSource: Sendable {
    case data(Data)
    case file(URL)
}

struct AccountDataExportEntry: Sendable {
    let relativePath: String
    let participantID: String
    let scope: AccountDataScope
    let source: AccountDataExportSource
}

enum AccountDataStorageRule: Equatable {
    case accountKey(prefix: String)
    case accountBucket(prefix: String)
    case literal(String)

    func matches(_ key: String, accountID: String) -> Bool {
        switch self {
        case .accountKey(let prefix):
            return key == prefix + accountID
        case .accountBucket(let prefix):
            return key.hasPrefix(prefix + accountID + ".")
        case .literal(let literal):
            return key == literal
        }
    }
}

enum AccountDataRegistryError: LocalizedError, Equatable {
    case invalidAccountID
    case duplicateParticipantID(String)
    case duplicateExportPath(String)
    case deletionFailed([String])

    var errorDescription: String? {
        switch self {
        case .invalidAccountID:
            return "Noum couldn't identify the active account."
        case .duplicateParticipantID(let id):
            return "Account-data participant '\(id)' is registered more than once."
        case .duplicateExportPath(let path):
            return "Account-data export path '\(path)' is registered more than once."
        case .deletionFailed:
            return "Noum couldn't finish clearing local account data. You can retry."
        }
    }
}

@MainActor
struct AccountDataParticipant {
    let id: String
    let scope: AccountDataScope
    let storageRules: [AccountDataStorageRule]
    private let reloadAction: () -> Void
    private let endSessionAction: () -> Void
    private let exportAction: (String) throws -> [AccountDataExportEntry]
    private let deleteAction: (String) throws -> Void

    init(
        id: String,
        scope: AccountDataScope = .account,
        storageRules: [AccountDataStorageRule] = [],
        reload: @escaping () -> Void,
        endSession: @escaping () -> Void,
        export: @escaping (String) throws -> [AccountDataExportEntry],
        delete: @escaping (String) throws -> Void
    ) {
        self.id = id
        self.scope = scope
        self.storageRules = storageRules
        self.reloadAction = reload
        self.endSessionAction = endSession
        self.exportAction = export
        self.deleteAction = delete
    }

    func reload() { reloadAction() }
    func endSession() { endSessionAction() }
    func export(accountID: String) throws -> [AccountDataExportEntry] {
        try exportAction(accountID)
    }
    func delete(accountID: String) throws { try deleteAction(accountID) }

    func claimedKeys(in availableKeys: Set<String>, accountID: String) -> Set<String> {
        Set(availableKeys.filter { key in
            storageRules.contains { $0.matches(key, accountID: accountID) }
        })
    }

    static func defaultsBacked(
        id: String,
        scope: AccountDataScope = .account,
        rules: [AccountDataStorageRule],
        defaults: UserDefaults = .standard,
        reload: @escaping () -> Void,
        endSession: @escaping () -> Void
    ) -> AccountDataParticipant {
        AccountDataParticipant(
            id: id,
            scope: scope,
            storageRules: rules,
            reload: reload,
            endSession: endSession,
            export: { accountID in
                let values = defaults.dictionaryRepresentation()
                let keys = values.keys.filter { key in
                    rules.contains { $0.matches(key, accountID: accountID) }
                }
                let data = try AccountDataRegistry.jsonData(
                    participantID: id,
                    scope: scope,
                    keys: keys,
                    values: values
                )
                return [AccountDataExportEntry(
                    relativePath: "data/\(id).json",
                    participantID: id,
                    scope: scope,
                    source: .data(data)
                )]
            },
            delete: { accountID in
                let keys = defaults.dictionaryRepresentation().keys.filter { key in
                    rules.contains { $0.matches(key, accountID: accountID) }
                }
                keys.forEach(defaults.removeObject(forKey:))
            }
        )
    }

    static func codableSnapshot<Snapshot: Encodable>(
        id: String,
        rules: [AccountDataStorageRule],
        reload: @escaping () -> Void,
        endSession: @escaping () -> Void,
        snapshot: @escaping (String) throws -> Snapshot,
        delete: @escaping (String) throws -> Void
    ) -> AccountDataParticipant {
        AccountDataParticipant(
            id: id,
            storageRules: rules,
            reload: reload,
            endSession: endSession,
            export: { accountID in
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                let data = try encoder.encode(AccountDataSnapshotEnvelope(
                    schemaVersion: 1,
                    participantID: id,
                    scope: .account,
                    snapshot: try snapshot(accountID)
                ))
                return [AccountDataExportEntry(
                    relativePath: "data/\(id).json",
                    participantID: id,
                    scope: .account,
                    source: .data(data)
                )]
            },
            delete: delete
        )
    }

    /// Registration point for legacy owners whose storage remains device-wide.
    /// The scope prevents exports from implying account ownership.
    static func legacyDeviceDefaults(
        id: String,
        keys: [String],
        defaults: UserDefaults = .standard,
        reload: @escaping () -> Void = {},
        endSession: @escaping () -> Void = {}
    ) -> AccountDataParticipant {
        defaultsBacked(
            id: id,
            scope: .legacyDeviceUnattributed,
            rules: keys.map(AccountDataStorageRule.literal),
            defaults: defaults,
            reload: reload,
            endSession: endSession
        )
    }
}

private struct AccountDataSnapshotEnvelope<Snapshot: Encodable>: Encodable {
    let schemaVersion: Int
    let participantID: String
    let scope: AccountDataScope
    let snapshot: Snapshot
}

struct AccountDataCoverage: Equatable {
    let lifecycleParticipantIDs: Set<String>
    let exportParticipantIDs: Set<String>
    let deletionParticipantIDs: Set<String>

    var hasParity: Bool {
        lifecycleParticipantIDs == exportParticipantIDs
            && exportParticipantIDs == deletionParticipantIDs
    }
}

@MainActor
final class AccountDataRegistry {
    static let residualParticipantID = "unregistered-account-storage"

    let participants: [AccountDataParticipant]
    private let defaults: UserDefaults

    init(
        participants: [AccountDataParticipant],
        defaults: UserDefaults = .standard
    ) throws {
        var seen: Set<String> = []
        for participant in participants {
            guard seen.insert(participant.id).inserted else {
                throw AccountDataRegistryError.duplicateParticipantID(participant.id)
            }
        }
        self.participants = participants
        self.defaults = defaults
    }

    var participantIDs: [String] { participants.map(\.id) }

    var coverage: AccountDataCoverage {
        let ids = Set(participantIDs + [Self.residualParticipantID])
        return AccountDataCoverage(
            lifecycleParticipantIDs: ids,
            exportParticipantIDs: ids,
            deletionParticipantIDs: ids
        )
    }

    func reloadForCurrentAccount() {
        participants.forEach { $0.reload() }
    }

    func endSession() {
        participants.reversed().forEach { $0.endSession() }
    }

    func exportEntries(for accountID: String) throws -> [AccountDataExportEntry] {
        let accountID = try Self.validatedAccountID(accountID)
        var entries = try participants.flatMap { try $0.export(accountID: accountID) }
        let available = Set(defaults.dictionaryRepresentation().keys)
        let claimed = participants.reduce(into: Set<String>()) { result, participant in
            result.formUnion(participant.claimedKeys(in: available, accountID: accountID))
        }
        let residual = available.filter {
            Self.isAccountScopedDefaultsKey($0, accountID: accountID)
                && !claimed.contains($0)
        }
        let residualData = try Self.jsonData(
            participantID: Self.residualParticipantID,
            scope: .account,
            keys: residual,
            values: defaults.dictionaryRepresentation()
        )
        entries.append(AccountDataExportEntry(
            relativePath: "data/\(Self.residualParticipantID).json",
            participantID: Self.residualParticipantID,
            scope: .account,
            source: .data(residualData)
        ))

        var paths: Set<String> = []
        for entry in entries {
            guard paths.insert(entry.relativePath).inserted else {
                throw AccountDataRegistryError.duplicateExportPath(entry.relativePath)
            }
        }
        return entries
    }

    func deleteAllData(for accountID: String) throws {
        let accountID = try Self.validatedAccountID(accountID)
        let available = Set(defaults.dictionaryRepresentation().keys)
        let claimed = participants.reduce(into: Set<String>()) { result, participant in
            result.formUnion(participant.claimedKeys(in: available, accountID: accountID))
        }
        let residual = available.filter {
            Self.isAccountScopedDefaultsKey($0, accountID: accountID)
                && !claimed.contains($0)
        }
        var failures: [String] = []
        for participant in participants {
            do {
                try participant.delete(accountID: accountID)
            } catch {
                failures.append(participant.id)
            }
        }
        residual.forEach(defaults.removeObject(forKey:))
        guard failures.isEmpty else {
            throw AccountDataRegistryError.deletionFailed(failures.sorted())
        }
    }

    nonisolated static func isAccountScopedDefaultsKey(
        _ key: String,
        accountID: String
    ) -> Bool {
        let trimmed = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let token = ".\(trimmed)"
        return key.hasSuffix(token) || key.contains(token + ".")
    }

    nonisolated private static func validatedAccountID(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AccountDataRegistryError.invalidAccountID }
        return trimmed
    }

    nonisolated static func jsonSafeValue(_ value: Any) -> Any {
        if let data = value as? Data {
            if let decoded = try? JSONSerialization.jsonObject(with: data),
               JSONSerialization.isValidJSONObject(decoded) {
                return decoded
            }
            return ["encoding": "base64", "value": data.base64EncodedString()]
        }
        if let date = value as? Date {
            return ISO8601DateFormatter().string(from: date)
        }
        if JSONSerialization.isValidJSONObject(["value": value]) { return value }
        return String(describing: value)
    }

    nonisolated static func jsonData(
        participantID: String,
        scope: AccountDataScope,
        keys: some Sequence<String>,
        values: [String: Any]
    ) throws -> Data {
        var records: [String: Any] = [:]
        for key in keys.sorted() {
            if let value = values[key] { records[key] = jsonSafeValue(value) }
        }
        return try JSONSerialization.data(
            withJSONObject: [
                "schemaVersion": 1,
                "participantID": participantID,
                "scope": scope.rawValue,
                "records": records,
            ],
            options: [.prettyPrinted, .sortedKeys]
        )
    }
}

#if canImport(SwiftUI)
extension AccountDataRegistry {
    static func production(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        documentsDirectory: URL? = nil
    ) -> AccountDataRegistry {
        func participant(
            _ id: String,
            _ rules: [AccountDataStorageRule],
            reload: @escaping () -> Void,
            end: @escaping () -> Void
        ) -> AccountDataParticipant {
            .defaultsBacked(
                id: id,
                rules: rules,
                defaults: defaults,
                reload: reload,
                endSession: end
            )
        }

        var items: [AccountDataParticipant] = [
            participant("ai-consent", [.accountKey(prefix: "cloudProcessingConsent."), .accountKey(prefix: "hasAcknowledgedAIDisclosure.")], reload: { AISettingsManager.shared.reloadForCurrentAccount() }, end: { AISettingsManager.shared.endSession() }),
            participant("coaching-profile", [.accountKey(prefix: "coachingProfile.")], reload: { CoachingProfileStore.shared.reloadForCurrentAccount() }, end: { CoachingProfileStore.shared.endSession() }),
            participant("practice-sessions", [.accountKey(prefix: "practiceSessions.")], reload: { PracticeSessionStore.shared.reloadForCurrentAccount() }, end: { PracticeSessionStore.shared.endSession() }),
            participant("skill-trends", [.accountKey(prefix: "skillTrendSnapshots.")], reload: { SkillTrendStore.shared.reloadForCurrentAccount() }, end: { SkillTrendStore.shared.endSession() }),
            participant("baseline", [.accountKey(prefix: "communicationBaseline."), .accountKey(prefix: "pressureProfile.")], reload: { BaselineStore.shared.reloadForCurrentAccount() }, end: { BaselineStore.shared.endSession() }),
            participant("rating", [.accountKey(prefix: "speakingRating."), .accountKey(prefix: "speakingRating.lastShownWeekPeak.")], reload: { RatingStore.shared.reloadForCurrentAccount() }, end: { RatingStore.shared.endSession() }),
            participant("profile-progress", [.accountKey(prefix: "profileXP."), .accountKey(prefix: "noumCharacter.peakStage.")], reload: { ProfileManager.shared.reloadForCurrentAccount() }, end: { ProfileManager.shared.endSession() }),
            participant("im-relationships", [.accountKey(prefix: "imRelationshipProfiles.")], reload: { IMRelationshipStore.shared.reloadForCurrentAccount() }, end: { IMRelationshipStore.shared.endSession() }),
            participant("recommendation-learning", [.accountKey(prefix: "recommendation.pending."), .accountKey(prefix: "recommendation.outcomes.")], reload: { RecommendationLearningStore.shared.reloadForCurrentAccount() }, end: { RecommendationLearningStore.shared.reloadForCurrentAccount() }),
            participant("big-moments", [.accountKey(prefix: "bigMoment."), .accountKey(prefix: "bigMomentArchive."), .accountKey(prefix: "bigMomentOutcomes.")], reload: { BigMomentStore.shared.reloadForCurrentAccount() }, end: { BigMomentStore.shared.endSession() }),
            participant("forward-plan", [.accountKey(prefix: "forwardPlan.")], reload: { ForwardPlanStore.shared.reloadForCurrentAccount() }, end: { ForwardPlanStore.shared.endSession() }),
            participant("session-intent", [.accountKey(prefix: "sessionIntent.history.")], reload: { SessionIntentStore.shared.reloadForCurrentAccount() }, end: { SessionIntentStore.shared.endSession() }),
            participant("session-reflections", [.accountKey(prefix: "sessionReflection.history.")], reload: { SessionReflectionStore.shared.reloadForCurrentAccount() }, end: { SessionReflectionStore.shared.endSession() }),
            participant("coach-check-ins", [.accountKey(prefix: "coachCheckIns.")], reload: { CoachCheckInStore.shared.reloadForCurrentAccount() }, end: { CoachCheckInStore.shared.endSession() }),
            participant("coach-letters", [.accountKey(prefix: "coachLetter.archive.")], reload: { CoachLetterStore.shared.reloadForCurrentAccount() }, end: { CoachLetterStore.shared.endSession() }),
            participant("post-rep-notes", [.accountKey(prefix: "postRepCoachNote.")], reload: { PostRepCoachNoteStore.shared.reloadForCurrentAccount() }, end: { PostRepCoachNoteStore.shared.endSession() }),
            participant("coach-memory", [.accountKey(prefix: "coachMemory.")], reload: { CoachMemoryStore.shared.reloadForCurrentAccount() }, end: { CoachMemoryStore.shared.endSession() }),
            participant("proof-moments", [.accountKey(prefix: "proofMoment.archive.")], reload: { ProofMomentStore.shared.reloadForCurrentAccount() }, end: { ProofMomentStore.shared.endSession() }),
            participant("ask-noum", [.accountKey(prefix: "askNoum.thread.")], reload: { AskNoumStore.shared.reloadForCurrentAccount() }, end: { AskNoumStore.shared.endSession() }),
            participant("pressure-history", [.accountKey(prefix: "suddenDeath.runHistory.")], reload: { SuddenDeathRunHistoryStore.shared.reloadForCurrentAccount() }, end: { SuddenDeathRunHistoryStore.shared.endSession() }),
            participant("daily-goal", [.accountKey(prefix: "noum.dailyGoal.reps."), .accountKey(prefix: "noum.dailyGoal.drillCompletions."), .accountKey(prefix: "noum.dailyGoal.lastCelebrationDay.")], reload: { DailyGoalManager.shared.reloadForCurrentAccount() }, end: { DailyGoalManager.shared.reloadForCurrentAccount() }),
            participant("streak-freeze", [.accountKey(prefix: "noum.streakFreeze.available."), .accountKey(prefix: "noum.streakFreeze.lastEarnedWeek."), .accountKey(prefix: "noum.streakFreeze.consumedDates."), .accountKey(prefix: "noum.streakFreeze.lastSeenStreakDay.")], reload: { StreakFreezeManager.shared.reloadForCurrentAccount() }, end: { StreakFreezeManager.shared.reloadForCurrentAccount() }),
            participant("path-progress", [.accountKey(prefix: "noum.pathProgress.unlocked."), .accountKey(prefix: "noum.pathProgress.initialized."), .accountKey(prefix: "noum.journey.lastSeenPracticedDays.")], reload: { PathProgressManager.shared.reloadForCurrentAccount() }, end: { PathProgressManager.shared.reloadForCurrentAccount() }),
            participant("lessons", [.accountKey(prefix: "noum.lessons.progress.")], reload: { LessonStore.shared.reloadForCurrentAccount() }, end: { LessonStore.shared.reloadForCurrentAccount() }),
            participant("skill-progression", [.accountKey(prefix: "noum.skillProgression.")], reload: { SkillProgressionStore.shared.reloadForCurrentAccount() }, end: { SkillProgressionStore.shared.reloadForCurrentAccount() }),
            participant("daily-challenges", [.accountKey(prefix: "noum.dailyChallenges.")], reload: { DailyChallengesManager.shared.reloadForCurrentAccount() }, end: { DailyChallengesManager.shared.reloadForCurrentAccount() }),
            participant("word-of-day", [.accountKey(prefix: "noum.wordOfTheDay.usedDays.")], reload: { WordOfTheDayManager.shared.reloadForCurrentAccount() }, end: { WordOfTheDayManager.shared.reloadForCurrentAccount() }),
            participant("practice-locale", [.accountKey(prefix: "noum.practiceLocale.")], reload: { LocaleSettingsManager.shared.reloadForCurrentAccount() }, end: { LocaleSettingsManager.shared.reloadForCurrentAccount() }),
            participant("roleplay", [.accountKey(prefix: "roleplayTurns.")], reload: { RoleplayStore.shared.reloadForCurrentAccount() }, end: { RoleplayStore.shared.endSession() }),
            participant("primary-focus", [.accountKey(prefix: "lastPrimaryFocus.")], reload: {}, end: {}),
            participant("prompt-history", [.accountKey(prefix: "noum.promptHistory."), .accountKey(prefix: "noum.promptHistory.texts.")], reload: {}, end: {}),
            participant("account-prompts", [.accountKey(prefix: "noum.notification.prePrompt.seen."), .accountKey(prefix: "noum.notification.prePrompt.declinedAt."), .accountKey(prefix: "noum.deferredCapture.seen.goal."), .accountKey(prefix: "noum.deferredCapture.seen.whyNow."), .accountKey(prefix: "noum.deferredCapture.seen.successVision."), .accountKey(prefix: "noum.goalRefresh.lastDate."), .accountKey(prefix: FirstRunOnboardingGate.legacyCompletedKeyPrefix), .accountKey(prefix: AutoGuidedFirstRep.completedKeyPrefix)], reload: {}, end: {}),
            participant("home-recommendations", [.accountBucket(prefix: "homeRecommendation.")], reload: {}, end: {}),
            participant("ai-rate-limits", [.accountBucket(prefix: "aiRateLimiter.")], reload: {}, end: { AIRateLimiter.shared.endSession() }),
        ]

        items.append(.codableSnapshot(
            id: "friends",
            rules: [.accountKey(prefix: "NoumFriendsList.")],
            reload: { FriendsManager.shared.reloadForCurrentAccount() },
            endSession: { FriendsManager.shared.endSession() },
            snapshot: { FriendsManager.shared.exportSnapshot(for: $0) },
            delete: { FriendsManager.shared.deleteAllData(for: $0) }
        ))
        items.append(.codableSnapshot(
            id: "challenges",
            rules: [
                .accountKey(prefix: "NoumChallenges."),
                .accountKey(prefix: "NoumCompletedChallenges."),
                .accountKey(prefix: "NoumAsyncChallenges."),
                .accountKey(prefix: "NoumAsyncChallengeArmedRep."),
            ],
            reload: { ChallengesManager.shared.reloadForCurrentAccount() },
            endSession: { ChallengesManager.shared.endSession() },
            snapshot: { ChallengesManager.shared.exportSnapshot(for: $0) },
            delete: { ChallengesManager.shared.deleteAllData(for: $0) }
        ))
        items.append(.codableSnapshot(
            id: "clubs",
            rules: [.accountKey(prefix: "NoumSavedClubs.")],
            reload: { ClubsManager.shared.reloadForCurrentAccount() },
            endSession: { ClubsManager.shared.endSession() },
            snapshot: { ClubsManager.shared.exportSnapshot(for: $0) },
            delete: { ClubsManager.shared.deleteAllData(for: $0) }
        ))
        items.append(.codableSnapshot(
            id: "feedback-requests",
            rules: [.accountKey(prefix: "noum_feedback_requests.")],
            reload: { FeedbackRequestManager.shared.reloadForCurrentAccount() },
            endSession: { FeedbackRequestManager.shared.endSession() },
            snapshot: { FeedbackRequestManager.shared.exportSnapshot(for: $0) },
            delete: { FeedbackRequestManager.shared.deleteAllData(for: $0) }
        ))
        items.append(.codableSnapshot(
            id: "league",
            rules: LeagueManager.accountDataKeyBases.map {
                .accountKey(prefix: "\($0).")
            },
            reload: { LeagueManager.shared.reloadForCurrentAccount() },
            endSession: { LeagueManager.shared.endSession() },
            snapshot: { LeagueManager.shared.exportSnapshot(for: $0) },
            delete: { LeagueManager.shared.deleteAllData(for: $0) }
        ))
        items.append(.legacyDeviceDefaults(
            id: "legacy-device-coaching",
            keys: ["noum_custom_filler_words", "noum_clutch_word_profile", "noum_dismissed_clutch_words", "noum_achievement_unlocks", "drillHistory", "lastNextActionSnapshot", "skillTrendSnapshots", "aiMonthlyAnalysisCount", "aiMonthlyAnalysisMonth"],
            defaults: defaults
        ))
        items.append(.appManagedRecordings(
            fileManager: fileManager,
            documentsDirectory: documentsDirectory
        ))
        return try! AccountDataRegistry(participants: items, defaults: defaults)
    }
}

private extension AccountDataParticipant {
    static func appManagedRecordings(
        fileManager: FileManager,
        documentsDirectory: URL?
    ) -> AccountDataParticipant {
        let documents = documentsDirectory
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let root = documents.appendingPathComponent("Recordings", isDirectory: true)
        return AccountDataParticipant(
            id: "app-managed-recordings",
            scope: .legacyDeviceUnattributed,
            reload: {},
            endSession: {},
            export: { _ in
                let files = try appManagedRecordingFiles(root: root, fileManager: fileManager)
                let metadata = try JSONSerialization.data(
                    withJSONObject: [
                        "schemaVersion": 1,
                        "participantID": "app-managed-recordings",
                        "scope": AccountDataScope.legacyDeviceUnattributed.rawValue,
                        "ownershipNote": "Legacy fallback recordings are app-managed but were not stamped with an account ID.",
                        "files": files.map(\.lastPathComponent).sorted(),
                    ],
                    options: [.prettyPrinted, .sortedKeys]
                )
                var entries = [AccountDataExportEntry(
                    relativePath: "data/app-managed-recordings.json",
                    participantID: "app-managed-recordings",
                    scope: .legacyDeviceUnattributed,
                    source: .data(metadata)
                )]
                entries += files.map { file in
                    AccountDataExportEntry(
                        relativePath: "recordings/app-managed-unattributed/\(file.lastPathComponent)",
                        participantID: "app-managed-recordings",
                        scope: .legacyDeviceUnattributed,
                        source: .file(file)
                    )
                }
                return entries
            },
            delete: { _ in
                if fileManager.fileExists(atPath: root.path) {
                    try fileManager.removeItem(at: root)
                }
            }
        )
    }

    static func appManagedRecordingFiles(
        root: URL,
        fileManager: FileManager
    ) throws -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        let urls = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )
        return try urls.filter { url in
            let values = try url.resourceValues(forKeys: Set(keys))
            return values.isRegularFile == true && values.isSymbolicLink != true
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
#endif
