import Foundation
import Testing
@testable import Noum

@Suite("Release identity and privacy contracts")
struct ReleaseIdentityPrivacyTests {
    @Test("Firebase anonymous upgrades link in place")
    func anonymousUpgradeLinksInPlace() {
        #expect(AuthManager.firebaseCredentialStrategy(
            persistedAccountID: "guest-uid",
            persistedProviderRawValue: AuthProvider.guest.rawValue,
            firebaseUID: "guest-uid",
            firebaseUserIsAnonymous: true
        ) == .linkAnonymousUser)
    }

    @Test("Keychain-only guest upgrades preserve the guest")
    func localGuestUpgradeIsBlocked() {
        #expect(AuthManager.firebaseCredentialStrategy(
            persistedAccountID: "local-guest-123",
            persistedProviderRawValue: AuthProvider.guest.rawValue,
            firebaseUID: nil,
            firebaseUserIsAnonymous: false
        ) == .preserveLocalGuest)
    }

    @Test("Existing authenticated accounts use normal sign in")
    func existingAccountUsesSignIn() {
        #expect(AuthManager.firebaseCredentialStrategy(
            persistedAccountID: "apple-user",
            persistedProviderRawValue: AuthProvider.apple.rawValue,
            firebaseUID: "apple-user",
            firebaseUserIsAnonymous: false
        ) == .signIn)
    }

    @Test("Current allow decision opens the cloud boundary")
    func currentConsentIsAllowed() {
        let consent = CloudProcessingConsent(
            decision: .allowed,
            decidedAt: Date(timeIntervalSince1970: 1_700_000_000),
            disclosureVersion: AISettingsManager.disclosureVersion,
            processorManifestVersion: AISettingsManager.processorManifestVersion
        )
        #expect(consent.isCurrent(
            disclosureVersion: AISettingsManager.disclosureVersion,
            processorManifestVersion: AISettingsManager.processorManifestVersion
        ))
    }

    @Test("Decline and stale disclosure versions keep cloud processing closed")
    func declinedOrStaleConsentIsClosed() {
        let declined = CloudProcessingConsent(
            decision: .declined,
            decidedAt: .now,
            disclosureVersion: AISettingsManager.disclosureVersion,
            processorManifestVersion: AISettingsManager.processorManifestVersion
        )
        let stale = CloudProcessingConsent(
            decision: .allowed,
            decidedAt: .now,
            disclosureVersion: AISettingsManager.disclosureVersion - 1,
            processorManifestVersion: AISettingsManager.processorManifestVersion
        )
        #expect(!declined.isCurrent(
            disclosureVersion: AISettingsManager.disclosureVersion,
            processorManifestVersion: AISettingsManager.processorManifestVersion
        ))
        #expect(!stale.isCurrent(
            disclosureVersion: AISettingsManager.disclosureVersion,
            processorManifestVersion: AISettingsManager.processorManifestVersion
        ))
    }

    @Test("Legacy acknowledgement migration requires a current decision")
    func legacyAcknowledgementMigrates() {
        let date = Date(timeIntervalSince1970: 1_650_000_000)
        let migrated = CloudProcessingConsent.migratedLegacyAcknowledgement(
            acknowledged: true,
            decidedAt: date,
            disclosureVersion: 3,
            processorManifestVersion: 4
        )
        #expect(migrated == CloudProcessingConsent(
            decision: .allowed,
            decidedAt: date,
            disclosureVersion: 2,
            processorManifestVersion: 3
        ))
        #expect(migrated?.isCurrent(disclosureVersion: 3, processorManifestVersion: 4) == false)
        #expect(CloudProcessingConsent.migratedLegacyAcknowledgement(
            acknowledged: false,
            decidedAt: date,
            disclosureVersion: 3,
            processorManifestVersion: 4
        ) == nil)
    }

    @Test("Account key matching includes bucketed values but excludes other users")
    func accountKeyMatching() {
        #expect(AuthManager.isAccountScopedDefaultsKey(
            "coachMemory.user-a",
            accountID: "user-a"
        ))
        #expect(AuthManager.isAccountScopedDefaultsKey(
            "aiRateLimit.user-a.coachRead.2026-07-11",
            accountID: "user-a"
        ))
        #expect(!AuthManager.isAccountScopedDefaultsKey(
            "coachMemory.user-b",
            accountID: "user-a"
        ))
        #expect(!AuthManager.isAccountScopedDefaultsKey("globalSetting", accountID: "user-a"))
    }

    @Test("Local export snapshot is account isolated and JSON safe")
    func accountSnapshotIsIsolated() throws {
        let suiteName = "ReleaseIdentityPrivacyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(7, forKey: "profileXP.user-a")
        defaults.set(11, forKey: "profileXP.user-b")
        defaults.set(try JSONSerialization.data(withJSONObject: ["goal": "clearer openings"]),
                     forKey: "coachingProfile.user-a")
        defaults.set(Data([0x00, 0xFF]), forKey: "opaque.user-a")

        let snapshot = AuthManager.accountScopedDefaultsSnapshot(
            for: "user-a",
            defaults: defaults
        )
        #expect(snapshot["profileXP.user-a"] as? Int == 7)
        #expect(snapshot["profileXP.user-b"] == nil)
        #expect((snapshot["coachingProfile.user-a"] as? [String: Any])?["goal"] as? String == "clearer openings")
        #expect((snapshot["opaque.user-a"] as? [String: Any])?["encoding"] as? String == "base64")
        #expect(JSONSerialization.isValidJSONObject(snapshot))
    }

    @Test("Deletion failures remain actionable")
    func deletionFailureCopy() {
        #expect(AccountDeletionError.requiresRecentAuthentication.requiresReauthentication)
        #expect(!AccountDeletionError.serviceUnavailable.requiresReauthentication)
        #expect(AccountDeletionError.appleRevocationUnavailable.localizedDescription.contains("unchanged"))
        #expect(AccountDeletionError.serviceUnavailable.localizedDescription.contains("unchanged"))
    }

    @Test("Deletion callable contract uses the production region and name")
    func deletionCallableRouting() {
        #expect(BackendSyncManager.functionsRegion == "europe-west2")
        #expect(BackendSyncManager.deleteAccountFunctionName == "deleteAccount")
    }
}
