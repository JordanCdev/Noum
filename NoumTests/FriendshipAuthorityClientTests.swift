import Foundation
import Testing
@testable import Noum

@Suite("Friendship authority client")
struct FriendshipAuthorityClientTests {
    @Test("Friendship callables and requests use the exact v1 surface")
    func callableAndRequestShape() throws {
        #expect(BackendSyncManager.functionsRegion == "europe-west2")
        #expect(BackendSyncManager.createFriendInviteFunctionName == "createFriendInvite")
        #expect(BackendSyncManager.acceptFriendInviteFunctionName == "acceptFriendInvite")
        #expect(BackendSyncManager.listFriendLinksFunctionName == "listFriendLinks")
        #expect(BackendSyncManager.removeFriendLinkFunctionName == "removeFriendLink")

        let create = try jsonObject(CreateFriendInviteRequest(displayName: " Speaker "))
        let accept = try jsonObject(AcceptFriendInviteRequest(
            inviteToken: " \(validInviteToken) ",
            displayName: " Speaker "
        ))
        let list = try jsonObject(ListFriendLinksRequest(limit: 50))
        let remove = try jsonObject(RemoveFriendLinkRequest(
            pairID: pairB,
            friendAccountID: "friend-b"
        ))

        #expect(Set(create.keys) == ["schemaVersion", "displayName"])
        #expect(create["displayName"] as? String == "Speaker")
        #expect(Set(accept.keys) == ["schemaVersion", "inviteToken", "displayName"])
        #expect(accept["inviteToken"] as? String == validInviteToken)
        #expect(Set(list.keys) == ["schemaVersion", "limit"])
        #expect(Set(remove.keys) == ["schemaVersion", "pairID", "friendAccountID"])
        #expect(remove["pairID"] as? String == pairB.uuidString)
    }

    @Test("Invite responses require a canonical token and bounded future Unix expiry")
    func inviteResponseValidation() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let valid = CreateFriendInviteResponse(
            schemaVersion: 1,
            inviteToken: validInviteToken,
            expiresAt: now.timeIntervalSince1970 + 300
        )
        let result = try valid.result(now: now)
        #expect(result.inviteToken == validInviteToken)
        #expect(result.expiresAt == now.addingTimeInterval(300))

        let skewTolerant = CreateFriendInviteResponse(
            schemaVersion: 1,
            inviteToken: validInviteToken,
            expiresAt: now.timeIntervalSince1970 + 86_700
        )
        #expect(try skewTolerant.result(now: now).expiresAt == now.addingTimeInterval(86_700))

        for response in [
            CreateFriendInviteResponse(schemaVersion: 2, inviteToken: validInviteToken, expiresAt: now.timeIntervalSince1970 + 300),
            CreateFriendInviteResponse(schemaVersion: 1, inviteToken: String(validInviteToken.dropLast()), expiresAt: now.timeIntervalSince1970 + 300),
            CreateFriendInviteResponse(schemaVersion: 1, inviteToken: "bad token", expiresAt: now.timeIntervalSince1970 + 300),
            CreateFriendInviteResponse(schemaVersion: 1, inviteToken: String(validInviteToken.dropLast()) + ".", expiresAt: now.timeIntervalSince1970 + 300),
            CreateFriendInviteResponse(schemaVersion: 1, inviteToken: validInviteToken, expiresAt: now.timeIntervalSince1970),
            CreateFriendInviteResponse(schemaVersion: 1, inviteToken: validInviteToken, expiresAt: now.timeIntervalSince1970 + 86_701),
            CreateFriendInviteResponse(schemaVersion: 1, inviteToken: validInviteToken, expiresAt: .infinity)
        ] {
            #expect(throws: SocialAuthorityError.invalidResponse) {
                try response.result(now: now)
            }
        }
    }

    @Test("Accept requests reject non-canonical bearer tokens")
    func acceptTokenValidation() {
        #expect(AcceptFriendInviteRequest(
            inviteToken: validInviteToken,
            displayName: "Speaker"
        ).isValid)
        #expect(!AcceptFriendInviteRequest(
            inviteToken: String(validInviteToken.dropLast()),
            displayName: "Speaker"
        ).isValid)
        #expect(!AcceptFriendInviteRequest(
            inviteToken: String(validInviteToken.dropLast()) + ".",
            displayName: "Speaker"
        ).isValid)
        #expect(!AcceptFriendInviteRequest(
            inviteToken: String(validInviteToken.dropLast(2)) + " A",
            displayName: "Speaker"
        ).isValid)
        #expect(!AcceptFriendInviteRequest(
            inviteToken: nonCanonicalInviteToken,
            displayName: "Speaker"
        ).isValid)
    }

    @Test("Friend envelopes decode the backend friendAccountID key")
    func friendEnvelopeWireKey() throws {
        let data = try #require("""
        {
          "pairID": "\(pairB.uuidString)",
          "friendAccountID": "friend-b",
          "displayName": "Partner",
          "linkedAt": 1800000000
        }
        """.data(using: .utf8))
        let envelope = try JSONDecoder().decode(FriendAuthorityEnvelope.self, from: data)
        #expect(envelope.accountID == "friend-b")

        let encoded = try jsonObject(envelope)
        #expect(encoded["friendAccountID"] as? String == "friend-b")
        #expect(encoded["accountID"] == nil)
    }

    @Test("Accept rejects self links and malformed server-owned fields")
    func acceptedLinkValidation() throws {
        let valid = AcceptFriendInviteResponse(
            schemaVersion: 1,
            friend: envelope(accountID: "friend-b")
        )
        let link = try valid.result(currentAccountID: "account-a")
        #expect(link.accountID == "friend-b")
        #expect(link.displayName == "Partner")

        let selfLink = AcceptFriendInviteResponse(
            schemaVersion: 1,
            friend: envelope(accountID: "account-a")
        )
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try selfLink.result(currentAccountID: "account-a")
        }

        let badTime = AcceptFriendInviteResponse(
            schemaVersion: 1,
            friend: FriendAuthorityEnvelope(
                pairID: pairB.uuidString,
                accountID: "friend-b",
                displayName: "Partner",
                linkedAt: .nan
            )
        )
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try badTime.result(currentAccountID: "account-a")
        }
    }

    @Test("List requires the complete 50-link snapshot contract")
    func listValidation() throws {
        #expect(ListFriendLinksRequest(limit: 50).isValid)
        #expect(!ListFriendLinksRequest(limit: 49).isValid)
        let valid = ListFriendLinksResponse(
            schemaVersion: 1,
            friends: [envelope(accountID: "friend-b"), envelope(accountID: "friend-c")]
        )
        let links = try valid.result(requestedLimit: 50, currentAccountID: "account-a")
        #expect(links.map(\.accountID) == ["friend-b", "friend-c"])

        let duplicate = ListFriendLinksResponse(
            schemaVersion: 1,
            friends: [envelope(accountID: "friend-b"), envelope(accountID: "friend-b")]
        )
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try duplicate.result(requestedLimit: 50, currentAccountID: "account-a")
        }
        let duplicatePair = ListFriendLinksResponse(
            schemaVersion: 1,
            friends: [
                envelope(accountID: "friend-b"),
                FriendAuthorityEnvelope(
                    pairID: pairB.uuidString,
                    accountID: "friend-c",
                    displayName: "Partner",
                    linkedAt: 1_800_000_000
                )
            ]
        )
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try duplicatePair.result(requestedLimit: 50, currentAccountID: "account-a")
        }
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try valid.result(requestedLimit: 49, currentAccountID: "account-a")
        }
        let overCapacity = ListFriendLinksResponse(
            schemaVersion: 1,
            friends: (0..<51).map { index in
                FriendAuthorityEnvelope(
                    pairID: String(format: "00000000-0000-4000-8000-%012d", index),
                    accountID: "friend-\(index)",
                    displayName: "Partner \(index)",
                    linkedAt: 1_800_000_000
                )
            }
        )
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try overCapacity.result(requestedLimit: 50, currentAccountID: "account-a")
        }
        let selfIncluded = ListFriendLinksResponse(
            schemaVersion: 1,
            friends: [envelope(accountID: "account-a")]
        )
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try selfIncluded.result(requestedLimit: 50, currentAccountID: "account-a")
        }
    }

    @Test("Confirmed removal cannot delete a replacement pair")
    @MainActor
    func removalIsPairBound() {
        let sharedID = UUID()
        let expected = NoumFriend(
            id: sharedID,
            displayName: "Expected",
            addedAt: Date(),
            addedVia: .invite,
            accountID: "friend-b",
            pairID: pairB.uuidString,
            connectionSchemaVersion: 1
        )
        let replacement = NoumFriend(
            id: sharedID,
            displayName: "Replacement",
            addedAt: Date(),
            addedVia: .invite,
            accountID: "friend-b",
            pairID: pairC.uuidString,
            connectionSchemaVersion: 1
        )

        let remaining = FriendsManager.removingConfirmedServerLink(
            id: sharedID,
            accountID: "friend-b",
            pairID: pairB,
            from: [expected, replacement]
        )

        #expect(remaining.count == 1)
        #expect(remaining.first?.pairID == pairC.uuidString)
    }

    @Test("Remove requires the exact expected pair and account echo")
    func removeEchoValidation() throws {
        let response = RemoveFriendLinkResponse(
            schemaVersion: 1,
            pairID: pairB.uuidString,
            friendAccountID: "friend-b",
            removed: false
        )
        let replay = try response.result(
            expectedPairID: pairB.uuidString,
            expectedFriendAccountID: "friend-b"
        )
        #expect(replay.pairID == pairB)
        #expect(replay.friendAccountID == "friend-b")
        #expect(!replay.removedNow)
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try response.result(
                expectedPairID: pairB.uuidString,
                expectedFriendAccountID: "friend-c"
            )
        }
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try response.result(
                expectedPairID: pairC.uuidString,
                expectedFriendAccountID: "friend-b"
            )
        }
    }

    @Test("Authoritative reconciliation preserves local contacts and cached stats")
    @MainActor
    func listMergePreservesOnlyIntendedState() throws {
        let retainedID = UUID()
        let localID = UUID()
        let staleID = UUID()
        let cached = [
            NoumFriend(
                id: retainedID,
                displayName: "Old name",
                addedAt: Date(timeIntervalSince1970: 100),
                addedVia: .invite,
                accountID: "friend-b",
                pairID: pairB.uuidString,
                connectionSchemaVersion: 1,
                lastKnownRating: 620,
                lastKnownPeakRating: 640,
                lastKnownStreak: 3,
                lastKnownRepsThisWeek: 2,
                lastSyncedAt: Date(timeIntervalSince1970: 150)
            ),
            NoumFriend(
                id: staleID,
                displayName: "Stale link",
                addedAt: Date(timeIntervalSince1970: 100),
                addedVia: .invite,
                accountID: "friend-stale",
                pairID: UUID().uuidString,
                connectionSchemaVersion: 1
            ),
            NoumFriend(
                id: localID,
                displayName: "Practice contact",
                addedAt: Date(timeIntervalSince1970: 100),
                addedVia: .manual
            )
        ]
        let remote = [
            FriendAuthorityLink(
                pairID: pairB,
                accountID: "friend-b",
                displayName: "Updated name",
                linkedAt: Date(timeIntervalSince1970: 200)
            ),
            FriendAuthorityLink(
                pairID: pairC,
                accountID: "friend-c",
                displayName: "New partner",
                linkedAt: Date(timeIntervalSince1970: 210)
            )
        ]

        let merged = FriendsManager.reconcilingServerLinks(cached: cached, remote: remote)

        #expect(merged.count == 3)
        #expect(merged.contains { $0.id == localID && !$0.isServerLinked })
        #expect(!merged.contains { $0.id == staleID })
        let retained = try #require(merged.first { $0.accountID == "friend-b" })
        #expect(retained.id == retainedID)
        #expect(retained.displayName == "Updated name")
        #expect(retained.lastKnownRating == 620)
        #expect(retained.lastKnownPeakRating == 640)
        #expect(merged.contains { $0.accountID == "friend-c" && $0.isServerLinked })
    }

    @Test("Legacy or manual rows cannot manufacture a connected account")
    func onlyServerSchemaMarksLinks() {
        let manualWithID = NoumFriend(
            id: UUID(),
            displayName: "Manual",
            addedAt: Date(),
            addedVia: .manual,
            accountID: "friend-b",
            connectionSchemaVersion: 1
        )
        let legacyInvite = NoumFriend(
            id: UUID(),
            displayName: "Legacy",
            addedAt: Date(),
            addedVia: .invite,
            accountID: "friend-c"
        )
        let serverInvite = NoumFriend(
            id: UUID(),
            displayName: "Connected",
            addedAt: Date(),
            addedVia: .invite,
            accountID: "friend-d",
            pairID: pairB.uuidString,
            connectionSchemaVersion: 1
        )

        #expect(!manualWithID.isServerLinked)
        #expect(!legacyInvite.isServerLinked)
        #expect(serverInvite.isServerLinked)
    }

    @Test("Friendship release capability remains independently disabled")
    func capabilityRemainsFalse() {
        #expect(!SocialReleaseCapabilities.friendConnections.isAvailable)
        #expect(!SocialReleaseCapabilities.friendProfiles.isAvailable)
        #expect(!SocialReleaseCapabilities.speakOffs.isAvailable)
        #expect(!SocialReleaseCapabilities.peerProgress.isAvailable)
        #expect(!SocialReleaseCapabilities.competitiveObservation.isAvailable)
        #expect(!SocialReleaseCapabilities.friendConnections.message.isEmpty)
    }

    @Test("Disabled friendship methods fail before Firebase configuration")
    func disabledBackendMethodsStopBeforeNetwork() async {
        do {
            _ = try await BackendSyncManager.shared.createFriendInvite(
                displayName: "Speaker",
                accountID: "account-a"
            )
            Issue.record("Disabled invite creation must not reach Firebase")
        } catch {
            #expect(error as? SocialAuthorityError == .friendAuthorizationUnavailable)
        }
        do {
            _ = try await BackendSyncManager.shared.listFriendLinks(
                accountID: "account-a"
            )
            Issue.record("Disabled friend listing must not reach Firebase")
        } catch {
            #expect(error as? SocialAuthorityError == .friendAuthorizationUnavailable)
        }
    }

    private func envelope(accountID: String) -> FriendAuthorityEnvelope {
        FriendAuthorityEnvelope(
            pairID: accountID == "friend-c" ? pairC.uuidString : pairB.uuidString,
            accountID: accountID,
            displayName: "Partner",
            linkedAt: 1_800_000_000
        )
    }

    private var pairB: UUID {
        UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    }

    private var pairC: UUID {
        UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    }

    private var validInviteToken: String {
        "0123456789abcdefghijklmnopqrstuvABCDEFGH_I8"
    }

    private var nonCanonicalInviteToken: String {
        "0123456789abcdefghijklmnopqrstuvABCDEFGH_I-"
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
