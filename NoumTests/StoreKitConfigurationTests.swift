import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Noum

@Suite("StoreKit configuration", .serialized)
struct StoreKitConfigurationTests {
    private static let expectedProductIDs: Set<String> = [
        PremiumManager.monthlyID,
        PremiumManager.annualID,
    ]

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var configurationURL: URL {
        repositoryRoot
            .appendingPathComponent("Noum", isDirectory: true)
            .appendingPathComponent("Configuration", isDirectory: true)
            .appendingPathComponent("Noum.storekit", isDirectory: false)
    }

    private static var schemeURL: URL {
        repositoryRoot
            .appendingPathComponent("Noum.xcodeproj", isDirectory: true)
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)
            .appendingPathComponent("Noum-StoreKit.xcscheme", isDirectory: false)
    }

    private static var projectURL: URL {
        repositoryRoot
            .appendingPathComponent("Noum.xcodeproj", isDirectory: true)
            .appendingPathComponent("project.pbxproj", isDirectory: false)
    }

    @Test func checkedInConfigurationHasTheLaunchProductContract() throws {
        let data = try Data(contentsOf: Self.configurationURL)
        let configuration = try JSONDecoder().decode(StoreKitConfiguration.self, from: data)

        #expect(configuration.version.major == 3)
        #expect(configuration.subscriptionGroups.count == 1)

        let group = try #require(configuration.subscriptionGroups.first)
        #expect(group.name == "Noum Pro")
        #expect(group.subscriptions.count == 2)
        #expect(Set(group.subscriptions.map(\.productID)) == Self.expectedProductIDs)
        #expect(Set(group.subscriptions.map(\.subscriptionGroupID)) == [group.id])

        let monthly = try #require(
            group.subscriptions.first { $0.productID == PremiumManager.monthlyID }
        )
        #expect(monthly.displayPrice == "11.99")
        #expect(monthly.recurringSubscriptionPeriod == "P1M")
        #expect(monthly.introductoryOffer == nil)

        let annual = try #require(
            group.subscriptions.first { $0.productID == PremiumManager.annualID }
        )
        #expect(annual.displayPrice == "79.99")
        #expect(annual.recurringSubscriptionPeriod == "P1Y")
        #expect(annual.introductoryOffer?.paymentMode == "free")
        #expect(annual.introductoryOffer?.subscriptionPeriod == "P1W")
    }

    @Test func sharedSchemeUsesTheCheckedInConfigurationForTestsAndRuns() throws {
        let scheme = try String(contentsOf: Self.schemeURL, encoding: .utf8)
        // Xcode resolves scheme service references from the .xcodeproj bundle.
        let reference = "../Noum/Configuration/Noum.storekit"
        let resolvedReference = Self.repositoryRoot
            .appendingPathComponent("Noum.xcodeproj", isDirectory: true)
            .appendingPathComponent(reference, isDirectory: false)
            .standardizedFileURL

        #expect(scheme.components(separatedBy: reference).count - 1 == 2)
        #expect(scheme.contains("<TestAction"))
        #expect(scheme.contains("<LaunchAction"))
        #expect(resolvedReference == Self.configurationURL.standardizedFileURL)
    }

    @Test func sharedSchemesNeverCarryAppCheckDebugCredentials() throws {
        let schemesDirectory = Self.repositoryRoot
            .appendingPathComponent("Noum.xcodeproj/xcshareddata/xcschemes", isDirectory: true)
        let schemeURLs = try FileManager.default.contentsOfDirectory(
            at: schemesDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "xcscheme" }

        #expect(!schemeURLs.isEmpty)
        for url in schemeURLs {
            let source = try String(contentsOf: url, encoding: .utf8)
            #expect(!source.contains("FIRAAppCheckDebugToken"))
            #expect(!source.contains("AppCheckDebugToken"))
        }
    }

    @Test func developmentCatalogIsExcludedFromApplicationTargetMembership() throws {
        let project = try String(contentsOf: Self.projectURL, encoding: .utf8)
        let exceptionStart = try #require(
            project.range(of: "/* Exceptions for \"Noum\" folder in \"Noum\" target */ = {")
        )
        let exceptionEnd = try #require(
            project.range(
                of: "\n\t\t};",
                range: exceptionStart.upperBound..<project.endIndex
            )
        )
        let exceptionSet = project[exceptionStart.lowerBound..<exceptionEnd.upperBound]

        #expect(exceptionSet.contains("membershipExceptions = ("))
        #expect(exceptionSet.contains("\n\t\t\t\tConfiguration/Noum.storekit,\n"))
    }

    @Test func storeKitLoadsPricesPeriodsAndTheEligibleAnnualTrial() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let products = try await Product.products(for: Self.expectedProductIDs)
        guard !products.isEmpty else {
            // Xcode 26's xcodebuild path does not always synchronize the active
            // StoreKit catalog into storekitd. Keep the integration assertion
            // visible without making the deterministic file contract flaky.
            withKnownIssue(
                "Xcode 26 xcodebuild can return no local StoreKit products; verify Product metadata in Xcode and the App Store sandbox."
            ) {
                Issue.record("The active StoreKit configuration returned no products")
            }
            return
        }
        #expect(Set(products.map(\.id)) == Self.expectedProductIDs)

        let monthly = try #require(products.first { $0.id == PremiumManager.monthlyID })
        #expect(monthly.type == .autoRenewable)
        #expect(monthly.price == Decimal(string: "11.99", locale: Locale(identifier: "en_US_POSIX")))
        #expect(monthly.subscription?.subscriptionPeriod.value == 1)
        #expect(monthly.subscription?.subscriptionPeriod.unit == .month)
        #expect(monthly.subscription?.introductoryOffer == nil)

        let annual = try #require(products.first { $0.id == PremiumManager.annualID })
        #expect(annual.type == .autoRenewable)
        #expect(annual.price == Decimal(string: "79.99", locale: Locale(identifier: "en_US_POSIX")))
        #expect(annual.subscription?.subscriptionPeriod.value == 1)
        #expect(annual.subscription?.subscriptionPeriod.unit == .year)

        let offer = try #require(annual.subscription?.introductoryOffer)
        #expect(offer.type == .introductory)
        #expect(offer.paymentMode == .freeTrial)
        #expect(offer.price == 0)
        #expect(offer.periodCount == 1)
        #expect(offer.period.value == 1)
        #expect(offer.period.unit == .week)
    }

    @Test func localSessionCompatibilityPathCanPurchaseCancelRenewExpireAndRefundSubscriptions() throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        // The current async SKTestSession.buyProduct API returns .notEntitled
        // under Xcode 26.x for URL-backed configurations. Invoke StoreKitTest's
        // legacy external-transaction entry point only to exercise local state
        // transitions until Apple's current API is reliable again.
        do {
            try buyProductUsingExternalTransactionCompatibility(
                PremiumManager.annualID,
                in: session
            )
        } catch let error as NSError
            where error.domain == "SKInternalErrorDomain" && error.code == 3 {
            withKnownIssue(
                "Xcode 26 xcodebuild did not synchronize the local StoreKit catalog into storekitd; rerun this lifecycle test from Xcode or a physical sandbox."
            ) {
                Issue.record("StoreKitTest catalog synchronization failed with SKInternalErrorDomain Code=3")
            }
            return
        }

        let annualTestTransaction = try #require(
            session.allTransactions().first { $0.productIdentifier == PremiumManager.annualID }
        )
        #expect(annualTestTransaction.autoRenewingEnabled)
        try session.disableAutoRenewForTransaction(identifier: annualTestTransaction.identifier)

        let cancelled = try #require(
            session.allTransactions().first { $0.identifier == annualTestTransaction.identifier }
        )
        #expect(!cancelled.autoRenewingEnabled)
        try session.enableAutoRenewForTransaction(identifier: annualTestTransaction.identifier)
        try session.forceRenewalOfSubscription(productIdentifier: PremiumManager.annualID)
        #expect(session.allTransactions().filter { $0.productIdentifier == PremiumManager.annualID }.count >= 2)
        try session.expireSubscription(productIdentifier: PremiumManager.annualID)
        #expect(
            session.allTransactions()
                .filter { $0.productIdentifier == PremiumManager.annualID }
                .contains { $0.expirationDate != nil }
        )

        try buyProductUsingExternalTransactionCompatibility(
            PremiumManager.monthlyID,
            in: session
        )
        let monthlyTestTransaction = try #require(
            session.allTransactions().last { $0.productIdentifier == PremiumManager.monthlyID }
        )
        try session.refundTransaction(identifier: monthlyTestTransaction.identifier)

        let refunded = try #require(
            session.allTransactions().first { $0.identifier == monthlyTestTransaction.identifier }
        )
        #expect(refunded.cancelDate != nil)
    }

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(contentsOf: Self.configurationURL)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.storefront = "GBR"
        session.locale = Locale(identifier: "en_GB")
        return session
    }

    private func buyProductUsingExternalTransactionCompatibility(
        _ productID: String,
        in session: SKTestSession
    ) throws {
        try session.buyProduct(productIdentifier: productID)
    }
}

private struct StoreKitConfiguration: Decodable {
    struct Version: Decodable {
        let major: Int
    }

    struct SubscriptionGroup: Decodable {
        let id: String
        let name: String
        let subscriptions: [Subscription]
    }

    struct Subscription: Decodable {
        let displayPrice: String
        let introductoryOffer: IntroductoryOffer?
        let productID: String
        let recurringSubscriptionPeriod: String
        let subscriptionGroupID: String
    }

    struct IntroductoryOffer: Decodable {
        let paymentMode: String
        let subscriptionPeriod: String
    }

    let subscriptionGroups: [SubscriptionGroup]
    let version: Version
}
