import Foundation
import Testing
@testable import Noum

@Suite(.serialized)
@MainActor
struct FeedbackRequestManagerTests {
    private final class AccountContext {
        var id: String?

        init(_ id: String?) {
            self.id = id
        }
    }

    @Test func accountSwitchKeepsTranscriptRequestsIsolated() throws {
        let fixture = makeFixture(accountID: "alpha")
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

        _ = fixture.store.createRequest(
            recipientName: "Alpha reviewer",
            transcript: "Alpha private transcript",
            score: 72,
            headline: "Alpha headline",
            prompt: nil,
            mode: .timed,
            requestNote: "Alpha note"
        )

        fixture.account.id = "beta"
        fixture.store.reloadForCurrentAccount()
        #expect(fixture.store.requests.isEmpty)

        _ = fixture.store.createRequest(
            recipientName: "Beta reviewer",
            transcript: "Beta private transcript",
            score: 81,
            headline: "Beta headline",
            prompt: "Beta prompt",
            mode: .ahCounter,
            requestNote: "Beta note"
        )

        #expect(fixture.store.exportSnapshot(for: "alpha").requests.map(\.transcript) == [
            "Alpha private transcript",
        ])
        #expect(fixture.store.exportSnapshot(for: "beta").requests.map(\.transcript) == [
            "Beta private transcript",
        ])

        fixture.account.id = "alpha"
        fixture.store.reloadForCurrentAccount()
        #expect(fixture.store.requests.map(\.transcript) == ["Alpha private transcript"])
    }

    @Test func legacyArchiveMigratesOnlyToFirstEstablishedAccount() throws {
        let suiteName = "FeedbackRequestManagerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacyRequest = StoredFeedbackRequest(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 100),
            sessionId: UUID(),
            recipientName: "Legacy reviewer",
            transcript: "Legacy private transcript",
            score: 70,
            headline: "Legacy headline",
            prompt: "Legacy prompt",
            mode: .timed,
            requestNote: "Legacy note",
            status: .pending,
            responses: []
        )
        defaults.set(
            try JSONEncoder().encode([legacyRequest]),
            forKey: "noum_feedback_requests"
        )
        let account = AccountContext("alpha")

        let store = FeedbackRequestManager(
            defaults: defaults,
            accountIDProvider: { account.id }
        )

        #expect(store.requests.map(\.transcript) == ["Legacy private transcript"])
        #expect(defaults.data(forKey: "noum_feedback_requests") == nil)
        #expect(defaults.data(forKey: "noum_feedback_requests.alpha") != nil)

        account.id = "beta"
        store.reloadForCurrentAccount()
        #expect(store.requests.isEmpty)
        #expect(store.exportSnapshot(for: "alpha").requests.count == 1)
        #expect(store.exportSnapshot(for: "beta").requests.isEmpty)
    }

    @Test func endSessionPreservesDiskAndDeletionTargetsOnlyRequestedAccount() throws {
        let fixture = makeFixture(accountID: "alpha")
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

        _ = fixture.store.createRequest(
            recipientName: "Alpha reviewer",
            transcript: "Alpha private transcript",
            score: 72,
            headline: "Alpha headline",
            prompt: nil,
            mode: .timed,
            requestNote: "Alpha note"
        )
        fixture.account.id = "beta"
        fixture.store.reloadForCurrentAccount()
        _ = fixture.store.createRequest(
            recipientName: "Beta reviewer",
            transcript: "Beta private transcript",
            score: 82,
            headline: "Beta headline",
            prompt: nil,
            mode: .suddenDeath,
            requestNote: "Beta note"
        )

        fixture.store.deleteAllData(for: "alpha")
        #expect(fixture.store.exportSnapshot(for: "alpha").requests.isEmpty)
        #expect(fixture.store.requests.map(\.transcript) == ["Beta private transcript"])

        fixture.store.endSession()
        #expect(fixture.store.requests.isEmpty)
        fixture.store.reloadForCurrentAccount()
        #expect(fixture.store.requests.map(\.transcript) == ["Beta private transcript"])

        fixture.store.deleteAllData(for: "beta")
        #expect(fixture.store.requests.isEmpty)
        #expect(fixture.store.exportSnapshot(for: "beta").requests.isEmpty)
    }

    private func makeFixture(
        accountID: String
    ) -> (
        store: FeedbackRequestManager,
        account: AccountContext,
        defaults: UserDefaults,
        suiteName: String
    ) {
        let suiteName = "FeedbackRequestManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let account = AccountContext(accountID)
        let store = FeedbackRequestManager(
            defaults: defaults,
            accountIDProvider: { account.id }
        )
        return (store, account, defaults, suiteName)
    }
}
