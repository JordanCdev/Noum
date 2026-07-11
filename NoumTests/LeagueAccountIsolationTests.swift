import Foundation
import Testing
@testable import Noum

@Suite("League account persistence isolation")
struct LeagueAccountIsolationTests {
    @Test("Every durable league value has a distinct account key")
    func accountKeysAreScoped() {
        #expect(LeagueManager.accountDataKeyBases.count == 5)
        for base in LeagueManager.accountDataKeyBases {
            let first = LeagueManager.accountKey(base: base, accountID: "account-a")
            let second = LeagueManager.accountKey(base: base, accountID: "account-b")
            #expect(first == "\(base).account-a")
            #expect(first != second)
            #expect(first != base)
        }
    }

    @Test("Legacy league values migrate once without overwriting scoped state")
    func legacyMigrationIsOneTimeAndNonDestructive() throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let promotion = TierPromotion(
            previousTier: .silver,
            newTier: .gold,
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )
        defaults.set(LeagueTier.silver.rawValue, forKey: LeagueManager.lastSeenTierKey)
        defaults.set(true, forKey: LeagueManager.lastSeenTierInitializedKey)
        defaults.set(try JSONEncoder().encode(promotion), forKey: LeagueManager.pendingPromotionKey)
        defaults.set("2026-W28", forKey: LeagueManager.dailyChallengeWeekKey)
        defaults.set(4, forKey: LeagueManager.dailyChallengeCountKey)

        // A previously written scoped value must win over a stale global one.
        defaults.set(
            LeagueTier.platinum.rawValue,
            forKey: LeagueManager.accountKey(
                base: LeagueManager.lastSeenTierKey,
                accountID: "account-a"
            )
        )

        let removed = LeagueManager.migrateLegacyDataIfNeeded(
            accountID: "account-a",
            defaults: defaults
        )
        #expect(removed == Set(LeagueManager.accountDataKeyBases))
        for base in LeagueManager.accountDataKeyBases {
            #expect(defaults.object(forKey: base) == nil)
        }

        let first = LeagueManager.persistedSnapshot(
            for: "account-a",
            defaults: defaults
        )
        #expect(first.lastSeenTier == .platinum)
        #expect(first.lastSeenTierInitialized)
        #expect(first.pendingPromotion == promotion)
        #expect(first.dailyChallengeISOWeek == "2026-W28")
        #expect(first.dailyChallengeCompletions == 4)

        // With global keys consumed, a later account receives nothing.
        #expect(LeagueManager.migrateLegacyDataIfNeeded(
            accountID: "account-b",
            defaults: defaults
        ).isEmpty)
        let second = LeagueManager.persistedSnapshot(
            for: "account-b",
            defaults: defaults
        )
        #expect(second.lastSeenTier == nil)
        #expect(!second.lastSeenTierInitialized)
        #expect(second.pendingPromotion == nil)
        #expect(second.dailyChallengeISOWeek == nil)
        #expect(second.dailyChallengeCompletions == 0)
    }

    @Test("Unbootstrapped guest state never claims legacy account data")
    func guestDoesNotClaimLegacyState() throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(7, forKey: LeagueManager.dailyChallengeCountKey)
        let migrated = LeagueManager.migrateLegacyDataIfNeeded(
            accountID: "guest",
            defaults: defaults
        )

        #expect(migrated.isEmpty)
        #expect(defaults.integer(forKey: LeagueManager.dailyChallengeCountKey) == 7)
        #expect(defaults.object(forKey: LeagueManager.accountKey(
            base: LeagueManager.dailyChallengeCountKey,
            accountID: "guest"
        )) == nil)
    }

    @Test("Snapshot, Codable export, and deletion remain account isolated")
    func snapshotAndDeletionAreAccountIsolated() throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        setSnapshotValues(
            accountID: "account-a",
            tier: .gold,
            week: "2026-W27",
            count: 2,
            defaults: defaults
        )
        setSnapshotValues(
            accountID: "account-b",
            tier: .diamond,
            week: "2026-W28",
            count: 6,
            defaults: defaults
        )

        let first = LeagueManager.persistedSnapshot(for: "account-a", defaults: defaults)
        let encoded = try JSONEncoder().encode(first)
        #expect(try JSONDecoder().decode(LeagueAccountDataSnapshot.self, from: encoded) == first)

        LeagueManager.deletePersistedData(for: "account-a", defaults: defaults)
        let deleted = LeagueManager.persistedSnapshot(for: "account-a", defaults: defaults)
        let preserved = LeagueManager.persistedSnapshot(for: "account-b", defaults: defaults)

        #expect(deleted.lastSeenTier == nil)
        #expect(!deleted.lastSeenTierInitialized)
        #expect(deleted.dailyChallengeISOWeek == nil)
        #expect(deleted.dailyChallengeCompletions == 0)
        #expect(preserved.lastSeenTier == .diamond)
        #expect(preserved.lastSeenTierInitialized)
        #expect(preserved.dailyChallengeISOWeek == "2026-W28")
        #expect(preserved.dailyChallengeCompletions == 6)
    }

    private func isolatedDefaults() throws -> (String, UserDefaults) {
        let suiteName = "LeagueAccountIsolationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (suiteName, defaults)
    }

    private func setSnapshotValues(
        accountID: String,
        tier: LeagueTier,
        week: String,
        count: Int,
        defaults: UserDefaults
    ) {
        defaults.set(tier.rawValue, forKey: LeagueManager.accountKey(
            base: LeagueManager.lastSeenTierKey,
            accountID: accountID
        ))
        defaults.set(true, forKey: LeagueManager.accountKey(
            base: LeagueManager.lastSeenTierInitializedKey,
            accountID: accountID
        ))
        defaults.set(week, forKey: LeagueManager.accountKey(
            base: LeagueManager.dailyChallengeWeekKey,
            accountID: accountID
        ))
        defaults.set(count, forKey: LeagueManager.accountKey(
            base: LeagueManager.dailyChallengeCountKey,
            accountID: accountID
        ))
    }
}
