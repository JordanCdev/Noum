import Foundation
import Testing
@testable import Noum

@Suite("Retired Daily Challenge lifecycle")
struct RetiredDailyChallengeLifecycleTests {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    @Test("Only the dormant tile references the compatibility manager")
    func productionHasNoDailyChallengeLifecycleOwner() throws {
        let sourceDirectory = repositoryRoot.appendingPathComponent("Noum", isDirectory: true)
        let swiftSources = try FileManager.default
            .subpathsOfDirectory(atPath: sourceDirectory.path)
            .filter { $0.hasSuffix(".swift") }

        var sharedManagerReferences: [String] = []
        var tileConstructionOutsideDormantSource: [String] = []
        for relativePath in swiftSources {
            let contents = try String(
                contentsOf: sourceDirectory.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            if contents.contains("DailyChallengesManager.shared") {
                sharedManagerReferences.append(relativePath)
            }
            if relativePath != "DailyChallengeTile.swift",
               contents.contains("DailyChallengeTile()") {
                tileConstructionOutsideDormantSource.append(relativePath)
            }
        }

        #expect(sharedManagerReferences.sorted() == ["DailyChallengeTile.swift"])
        #expect(tileConstructionOutsideDormantSource.isEmpty)

        let manager = try source("Noum/DailyChallengesManager.swift")
        #expect(manager.contains("private init() {}"))
        #expect(!manager.contains("observeSessionStore"))
        #expect(!manager.contains("PracticeSessionStore.shared.$sessions"))
    }

    @Test("Legacy notification is removed but can never be re-armed")
    func notificationMigrationIsOneWay() throws {
        #expect(
            NotificationManager.retiredDailyChallengeNotificationIdentifiers == [
                "noum.daily.challengeExpiry"
            ]
        )

        let manager = try source("Noum/NotificationManager.swift")
        #expect(manager.contains("removePendingNotificationRequests(withIdentifiers: identifiers)"))
        #expect(manager.contains("removeDeliveredNotifications(withIdentifiers: identifiers)"))
        #expect(!manager.contains("scheduleDailyChallengeExpiryWarning"))
        #expect(!manager.contains("NotificationCopy.dailyChallengeExpiry"))

        let copy = try source("Noum/NotificationCopy.swift")
        #expect(!copy.contains("dailyChallengeExpiry"))
        #expect(!copy.contains("dailyChallengeClaimed"))
    }

    @Test("Legacy account data stays governed without activating its manager")
    func accountDataRuleRemainsMigrationOnly() throws {
        let registry = try source("Noum/AccountDataRegistry.swift")
        #expect(registry.contains("participant(\"daily-challenges\", [.accountKey(prefix: \"noum.dailyChallenges.\")], reload: {}, end: {})"))
        #expect(!registry.contains("DailyChallengesManager.shared.reloadForCurrentAccount()"))
    }
}
