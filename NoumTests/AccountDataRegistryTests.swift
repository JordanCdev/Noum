import Foundation
import XCTest
@testable import Noum

@MainActor
final class AccountDataRegistryTests: XCTestCase {
    private final class Recorder {
        var events: [String] = []
    }

    private enum FixtureError: Error { case failed }

    func testLifecycleOrderAndCoverageParityAreDeterministic() throws {
        let recorder = Recorder()
        let first = participant(id: "first", recorder: recorder)
        let second = participant(id: "second", recorder: recorder)
        let registry = try AccountDataRegistry(participants: [first, second])

        registry.reloadForCurrentAccount()
        registry.endSession()

        XCTAssertEqual(recorder.events, [
            "reload:first", "reload:second", "end:second", "end:first",
        ])
        XCTAssertTrue(registry.coverage.hasParity)
        XCTAssertEqual(
            registry.coverage.exportParticipantIDs,
            Set(["first", "second", AccountDataRegistry.residualParticipantID])
        )
    }

    func testDuplicateParticipantIDIsRejected() {
        let recorder = Recorder()
        XCTAssertThrowsError(try AccountDataRegistry(participants: [
            participant(id: "duplicate", recorder: recorder),
            participant(id: "duplicate", recorder: recorder),
        ])) { error in
            XCTAssertEqual(
                error as? AccountDataRegistryError,
                .duplicateParticipantID("duplicate")
            )
        }
    }

    func testAccountBucketRuleDoesNotClaimAnotherAccountsCache() {
        let rule = AccountDataStorageRule.accountBucket(prefix: "homeRecommendation.")
        XCTAssertTrue(rule.matches(
            "homeRecommendation.account-a.fingerprint",
            accountID: "account-a"
        ))
        XCTAssertFalse(rule.matches(
            "homeRecommendation.account-b.fingerprint",
            accountID: "account-a"
        ))
        XCTAssertFalse(rule.matches(
            "homeRecommendation.unattributed-profile",
            accountID: "account-a"
        ))
    }

    func testExportAndDeletionStayAccountIsolatedIncludingResidualKeys() throws {
        let suite = "AccountDataRegistryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("A", forKey: "profile.account-a")
        defaults.set("B", forKey: "profile.account-b")
        defaults.set("A residual", forKey: "future.account-a.bucket")
        defaults.set("B residual", forKey: "future.account-b.bucket")

        let item = AccountDataParticipant.defaultsBacked(
            id: "profile",
            rules: [.accountKey(prefix: "profile.")],
            defaults: defaults,
            reload: {},
            endSession: {}
        )
        let registry = try AccountDataRegistry(
            participants: [item],
            defaults: defaults
        )
        let entries = try registry.exportEntries(for: "account-a")
        let payload = try JSONSerialization.jsonObject(
            with: try data(in: entries, path: "data/profile.json")
        ) as? [String: Any]
        let records = payload?["records"] as? [String: Any]
        XCTAssertEqual(records?["profile.account-a"] as? String, "A")
        XCTAssertNil(records?["profile.account-b"])

        let residual = try JSONSerialization.jsonObject(
            with: try data(
                in: entries,
                path: "data/\(AccountDataRegistry.residualParticipantID).json"
            )
        ) as? [String: Any]
        let residualRecords = residual?["records"] as? [String: Any]
        XCTAssertEqual(
            residualRecords?["future.account-a.bucket"] as? String,
            "A residual"
        )
        XCTAssertNil(residualRecords?["future.account-b.bucket"])

        try registry.deleteAllData(for: "account-a")
        XCTAssertNil(defaults.object(forKey: "profile.account-a"))
        XCTAssertNil(defaults.object(forKey: "future.account-a.bucket"))
        XCTAssertEqual(defaults.string(forKey: "profile.account-b"), "B")
        XCTAssertEqual(
            defaults.string(forKey: "future.account-b.bucket"),
            "B residual"
        )
    }

    func testDeletionAttemptsEveryParticipantBeforeReportingFailure() throws {
        let recorder = Recorder()
        let failing = participant(
            id: "failing",
            recorder: recorder,
            deleteError: FixtureError.failed
        )
        let healthy = participant(id: "healthy", recorder: recorder)
        let registry = try AccountDataRegistry(participants: [failing, healthy])

        XCTAssertThrowsError(try registry.deleteAllData(for: "account-a")) { error in
            XCTAssertEqual(
                error as? AccountDataRegistryError,
                .deletionFailed(["failing"])
            )
        }
        XCTAssertEqual(recorder.events, ["delete:failing", "delete:healthy"])
    }

    func testCodableSnapshotExportUsesVersionedAccountEnvelope() throws {
        struct Snapshot: Codable, Equatable {
            let value: String
        }

        var deletedAccountID: String?
        let item = AccountDataParticipant.codableSnapshot(
            id: "social",
            rules: [.accountKey(prefix: "social.")],
            reload: {},
            endSession: {},
            snapshot: { Snapshot(value: "snapshot-for-\($0)") },
            delete: { deletedAccountID = $0 }
        )
        let registry = try AccountDataRegistry(participants: [item])

        let entries = try registry.exportEntries(for: "account-a")
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(
            with: try data(in: entries, path: "data/social.json")
        ) as? [String: Any])
        XCTAssertEqual(payload["schemaVersion"] as? Int, 1)
        XCTAssertEqual(payload["participantID"] as? String, "social")
        XCTAssertEqual(payload["scope"] as? String, "account")
        XCTAssertEqual(
            (payload["snapshot"] as? [String: Any])?["value"] as? String,
            "snapshot-for-account-a"
        )

        try registry.deleteAllData(for: "account-a")
        XCTAssertEqual(deletedAccountID, "account-a")
    }

    func testProductionParticipantInventoryIsStable() {
        let suite = "AccountDataRegistryInventory.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let registry = AccountDataRegistry.production(
            defaults: defaults,
            documentsDirectory: root
        )

        XCTAssertEqual(registry.participantIDs, [
            "ai-consent", "coaching-profile", "practice-sessions",
            "skill-trends", "baseline", "rating", "profile-progress",
            "im-relationships", "recommendation-learning", "flow-observability", "big-moments",
            "forward-plan", "session-intent", "session-reflections",
            "coach-check-ins", "coach-letters", "post-rep-notes",
            "coach-memory", "proof-moments", "phrase-bank", "ask-noum", "pressure-history",
            "daily-goal", "streak-freeze", "path-progress", "lessons",
            "skill-progression", "daily-challenges", "word-of-day",
            "practice-locale", "roleplay", "primary-focus", "prompt-history",
            "account-prompts", "home-recommendations", "ai-rate-limits",
            "friends", "challenges", "clubs", "feedback-requests", "league",
            "legacy-device-coaching", "app-managed-recordings",
        ])
        XCTAssertTrue(registry.coverage.hasParity)
    }

    func testRecommendationSyncMetadataExportsAndDeletesWithItsAccount() throws {
        let suite = "AccountDataRegistryRecommendationReset.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let accountID = "account-a"
        let key = "recommendation.resetPending.\(accountID)"
        let syncKey = "recommendation.syncPending.\(accountID)"
        let revisionKey = "recommendation.remoteRevision.\(accountID)"
        let mutationKey = "recommendation.pendingMutationID.\(accountID)"
        defaults.set(1_720_000_000.0, forKey: key)
        defaults.set(1_720_000_001.0, forKey: syncKey)
        defaults.set(7, forKey: revisionKey)
        defaults.set(UUID().uuidString, forKey: mutationKey)
        let registry = AccountDataRegistry.production(defaults: defaults)

        let entries = try registry.exportEntries(for: accountID)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(
            with: try data(in: entries, path: "data/recommendation-learning.json")
        ) as? [String: Any])
        let records = try XCTUnwrap(payload["records"] as? [String: Any])
        XCTAssertEqual(records[key] as? Double, 1_720_000_000.0)
        XCTAssertEqual(records[syncKey] as? Double, 1_720_000_001.0)
        XCTAssertEqual(records[revisionKey] as? Int, 7)
        XCTAssertNotNil(records[mutationKey] as? String)

        try registry.deleteAllData(for: accountID)
        XCTAssertNil(defaults.object(forKey: key))
        XCTAssertNil(defaults.object(forKey: syncKey))
        XCTAssertNil(defaults.object(forKey: revisionKey))
        XCTAssertNil(defaults.object(forKey: mutationKey))
    }

    func testPracticeDemandExportsAndDeletesWithItsAccountSessionBlob() throws {
        let suite = "AccountDataRegistryDemand.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let accountA = "account-a"
        let accountB = "account-b"
        let keyA = "practiceSessions.\(accountA)"
        let keyB = "practiceSessions.\(accountB)"
        let session = PracticeSession(
            transcript: "The recommendation is clear and the next step is specific.",
            fillerWordCount: 0,
            duration: 40,
            date: Date(timeIntervalSince1970: 1_720_000_000),
            mode: .timed,
            practiceDemand: .timed(
                difficulty: .hard,
                speechProjectID: "ice_breaker"
            )
        )
        defaults.set(try JSONEncoder().encode([session]), forKey: keyA)
        defaults.set(try JSONEncoder().encode([session]), forKey: keyB)
        let registry = AccountDataRegistry.production(defaults: defaults)

        let entries = try registry.exportEntries(for: accountA)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(
            with: try data(in: entries, path: "data/practice-sessions.json")
        ) as? [String: Any])
        let records = try XCTUnwrap(payload["records"] as? [String: Any])
        let sessions = try XCTUnwrap(records[keyA] as? [[String: Any]])
        let demand = try XCTUnwrap(sessions.first?["practiceDemand"] as? [String: Any])
        XCTAssertEqual(demand["schemaVersion"] as? Int, 1)
        XCTAssertEqual(demand["timedDifficulty"] as? String, "hard")
        XCTAssertEqual(demand["speechProjectID"] as? String, "ice_breaker")
        XCTAssertNil(records[keyB])

        try registry.deleteAllData(for: accountA)
        XCTAssertNil(defaults.data(forKey: keyA))
        XCTAssertNotNil(defaults.data(forKey: keyB))
    }

    func testAppManagedRecordingsExportAndDeleteWithUnattributedScope() throws {
        let suite = "AccountDataRegistryMedia.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let recordings = root.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(
            at: recordings,
            withIntermediateDirectories: true
        )
        let movie = recordings.appendingPathComponent("session.mov")
        try Data("video-fixture".utf8).write(to: movie)

        let registry = AccountDataRegistry.production(
            defaults: defaults,
            documentsDirectory: root
        )
        let entries = try registry.exportEntries(for: "account-a")
        let media = try XCTUnwrap(entries.first {
            $0.relativePath == "recordings/app-managed-unattributed/session.mov"
        })
        XCTAssertEqual(media.scope, .legacyDeviceUnattributed)
        try registry.deleteAllData(for: "account-a")
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordings.path))
    }

    private func participant(
        id: String,
        recorder: Recorder,
        deleteError: Error? = nil
    ) -> AccountDataParticipant {
        AccountDataParticipant(
            id: id,
            reload: { recorder.events.append("reload:\(id)") },
            endSession: { recorder.events.append("end:\(id)") },
            export: { _ in
                recorder.events.append("export:\(id)")
                return [AccountDataExportEntry(
                    relativePath: "data/\(id).json",
                    participantID: id,
                    scope: .account,
                    source: .data(Data("{}".utf8))
                )]
            },
            delete: { _ in
                recorder.events.append("delete:\(id)")
                if let deleteError { throw deleteError }
            }
        )
    }

    private func data(
        in entries: [AccountDataExportEntry],
        path: String
    ) throws -> Data {
        let entry = try XCTUnwrap(entries.first { $0.relativePath == path })
        guard case .data(let data) = entry.source else {
            throw FixtureError.failed
        }
        return data
    }
}

@MainActor
final class AccountDataExportServiceTests: XCTestCase {
    func testZIPContainsManifestJSONAndFileSourcesWithValidCRC() async throws {
        let suite = "AccountDataExportService.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("coach", forKey: "coach.account-a")
        let participant = AccountDataParticipant.defaultsBacked(
            id: "coach",
            rules: [.accountKey(prefix: "coach.")],
            defaults: defaults,
            reload: {},
            endSession: {}
        )
        let registry = try AccountDataRegistry(
            participants: [participant],
            defaults: defaults
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixedDate = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-07-11T12:00:00Z")
        )
        let service = AccountDataExportService(
            registry: registry,
            exportRoot: root,
            now: { fixedDate }
        )

        let url = try await service.createExport(for: "account-a")
        XCTAssertEqual(url.lastPathComponent, "Noum-export-2026-07-11.zip")
        let contents = try readStoredZIP(url)
        XCTAssertNotNil(contents["manifest.json"])
        XCTAssertNotNil(contents["data/coach.json"])
        XCTAssertNotNil(contents["data/unregistered-account-storage.json"])
        let manifest = try JSONDecoder.iso8601.decode(
            AccountDataExportManifest.self,
            from: try XCTUnwrap(contents["manifest.json"])
        )
        XCTAssertFalse(manifest.keychainIncluded)
        XCTAssertFalse(manifest.photosLibraryIncluded)
        XCTAssertTrue(manifest.limitations.contains { $0.contains("Keychain") })
        XCTAssertTrue(manifest.limitations.contains { $0.contains("Photos") })

        service.cleanupExport(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testUnsafeZIPPathFailsWithoutLeavingPartialFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("unsafe.zip")
        let entry = AccountDataExportEntry(
            relativePath: "../secret",
            participantID: "fixture",
            scope: .account,
            source: .data(Data("secret".utf8))
        )
        XCTAssertThrowsError(try StoredZIPWriter.write(
            entries: [entry],
            to: destination,
            date: Date(timeIntervalSince1970: 0)
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: destination.appendingPathExtension("partial").path
        ))
    }

    private func readStoredZIP(_ url: URL) throws -> [String: Data] {
        let archive = try Data(contentsOf: url)
        var offset = 0
        var entries: [String: Data] = [:]
        while offset + 4 <= archive.count {
            let signature = readUInt32(archive, at: offset)
            guard signature == 0x04034b50 else { break }
            let method = readUInt16(archive, at: offset + 8)
            let expectedCRC = readUInt32(archive, at: offset + 14)
            let size = Int(readUInt32(archive, at: offset + 18))
            let nameLength = Int(readUInt16(archive, at: offset + 26))
            let extraLength = Int(readUInt16(archive, at: offset + 28))
            XCTAssertEqual(method, 0)
            let nameStart = offset + 30
            let dataStart = nameStart + nameLength + extraLength
            let payload = archive.subdata(in: dataStart..<(dataStart + size))
            let nameData = archive.subdata(in: nameStart..<(nameStart + nameLength))
            let name = try XCTUnwrap(String(data: nameData, encoding: .utf8))
            XCTAssertEqual(CRC32.checksum(payload), expectedCRC)
            entries[name] = payload
            offset = dataStart + size
        }
        return entries
    }

    private func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
