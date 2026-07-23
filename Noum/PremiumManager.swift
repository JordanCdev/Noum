import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
import StoreKit

#if canImport(SwiftUI)

// MARK: - StoreKit presentation contracts

enum PremiumPlanOption: String, CaseIterable, Identifiable, Sendable {
    case annual
    case monthly

    static let defaultSelection: PremiumPlanOption = .annual

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .annual: return PremiumManager.annualID
        case .monthly: return PremiumManager.monthlyID
        }
    }

    var title: String {
        switch self {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        }
    }

    var growthPlan: GrowthSubscriptionPlan {
        switch self {
        case .annual: return .annual
        case .monthly: return .monthly
        }
    }

    static func resolve(productID: String) -> PremiumPlanOption? {
        allCases.first { $0.productID == productID }
    }
}

enum PremiumPlanAvailability {
    static func visiblePlans(productIDs: Set<String>) -> [PremiumPlanOption] {
        PremiumPlanOption.allCases.filter { productIDs.contains($0.productID) }
    }

    static func resolvedSelection(
        current: PremiumPlanOption,
        productIDs: Set<String>
    ) -> PremiumPlanOption? {
        let visible = visiblePlans(productIDs: productIDs)
        if visible.contains(current) {
            return current
        }
        if visible.contains(.annual) {
            return .annual
        }
        return visible.first
    }
}

enum SubscriptionBillingUnit: String, Codable, Equatable, Sendable {
    case day
    case week
    case month
    case year
}

struct SubscriptionPeriodSnapshot: Codable, Equatable, Sendable {
    let value: Int
    let unit: SubscriptionBillingUnit

    init(value: Int, unit: SubscriptionBillingUnit) {
        self.value = max(1, value)
        self.unit = unit
    }

    init(_ period: Product.SubscriptionPeriod) {
        let unit: SubscriptionBillingUnit
        switch period.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: unit = .month
        }
        self.init(value: period.value, unit: unit)
    }

    var fullDescription: String {
        "\(value) \(unit.rawValue)\(value == 1 ? "" : "s")"
    }

    var compactAdjective: String {
        "\(value)-\(unit.rawValue)"
    }

    var billingCadence: String {
        value == 1 ? "per \(unit.rawValue)" : "every \(fullDescription)"
    }

    func multiplied(by count: Int) -> SubscriptionPeriodSnapshot {
        SubscriptionPeriodSnapshot(value: value * max(1, count), unit: unit)
    }

    func projectedEndDate(
        startingAt startDate: Date,
        periodCount: Int = 1,
        calendar: Calendar
    ) -> Date? {
        let amount = value * max(1, periodCount)
        switch unit {
        case .day: return calendar.date(byAdding: .day, value: amount, to: startDate)
        case .week: return calendar.date(byAdding: .weekOfYear, value: amount, to: startDate)
        case .month: return calendar.date(byAdding: .month, value: amount, to: startDate)
        case .year: return calendar.date(byAdding: .year, value: amount, to: startDate)
        }
    }
}

enum IntroductoryOfferPaymentMode: Equatable, Sendable {
    case freeTrial
    case payAsYouGo
    case payUpFront
}

struct IntroductoryOfferSnapshot: Equatable, Sendable {
    let isEligible: Bool
    let paymentMode: IntroductoryOfferPaymentMode
    let period: SubscriptionPeriodSnapshot
    let periodCount: Int
    let displayPrice: String

    var totalPeriod: SubscriptionPeriodSnapshot {
        period.multiplied(by: periodCount)
    }
}

struct PremiumProductPresentation: Equatable, Identifiable, Sendable {
    let id: String
    let displayPrice: String
    let billingPeriod: SubscriptionPeriodSnapshot?
    let introductoryOffer: IntroductoryOfferSnapshot?

    var billingLine: String {
        guard let billingPeriod else { return displayPrice }
        return "\(displayPrice) \(billingPeriod.billingCadence)"
    }

    func introductoryOfferLine(
        startingAt startDate: Date,
        calendar: Calendar
    ) -> String? {
        guard let offer = introductoryOffer, offer.isEligible else { return nil }
        let renewal = billingLine
        switch offer.paymentMode {
        case .freeTrial:
            guard let endDate = offer.period.projectedEndDate(
                startingAt: startDate,
                periodCount: offer.periodCount,
                calendar: calendar
            ) else {
                return "\(offer.totalPeriod.fullDescription) free, then \(renewal)"
            }
            return "\(offer.totalPeriod.fullDescription) free until \(Self.formatted(endDate)), then \(renewal)"
        case .payAsYouGo:
            return "\(offer.displayPrice) \(offer.period.billingCadence) for \(offer.totalPeriod.fullDescription), then \(renewal)"
        case .payUpFront:
            return "\(offer.displayPrice) for \(offer.totalPeriod.fullDescription), then \(renewal)"
        }
    }

    var purchaseButtonTitle: String {
        guard let offer = introductoryOffer,
              offer.isEligible,
              offer.paymentMode == .freeTrial else {
            return "Subscribe"
        }
        return "Start \(offer.totalPeriod.compactAdjective) free trial"
    }

    var growthTrialEligibility: GrowthTrialEligibility {
        guard let introductoryOffer else { return .unavailable }
        return introductoryOffer.isEligible ? .eligible : .ineligible
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static func storeKitProjection(for product: Product) async -> PremiumProductPresentation {
        guard let subscription = product.subscription else {
            return PremiumProductPresentation(
                id: product.id,
                displayPrice: PremiumPricing.displayPrice(product.displayPrice),
                billingPeriod: nil,
                introductoryOffer: nil
            )
        }

        let eligibility = await subscription.isEligibleForIntroOffer
        let introductoryOffer = subscription.introductoryOffer.map { offer in
            let paymentMode: IntroductoryOfferPaymentMode
            switch offer.paymentMode {
            case .freeTrial: paymentMode = .freeTrial
            case .payAsYouGo: paymentMode = .payAsYouGo
            case .payUpFront: paymentMode = .payUpFront
            default: paymentMode = .payUpFront
            }
            return IntroductoryOfferSnapshot(
                isEligible: eligibility,
                paymentMode: paymentMode,
                period: SubscriptionPeriodSnapshot(offer.period),
                periodCount: offer.periodCount,
                displayPrice: PremiumPricing.displayPrice(offer.displayPrice)
            )
        }

        return PremiumProductPresentation(
            id: product.id,
            displayPrice: PremiumPricing.displayPrice(product.displayPrice),
            billingPeriod: SubscriptionPeriodSnapshot(subscription.subscriptionPeriod),
            introductoryOffer: introductoryOffer
        )
    }
}

enum VerifiedSubscriptionRenewalState: Equatable, Sendable {
    /// A future StoreKit renewal state that this build cannot classify. It
    /// must never be rewritten as expiry: absence of understanding is not
    /// evidence that access ended.
    case unknown
    case subscribed
    case expired
    case inBillingRetryPeriod
    case inGracePeriod
    case revoked
}

struct VerifiedSubscriptionStatusSnapshot: Equatable, Sendable {
    let productID: String
    let renewalProductID: String
    let state: VerifiedSubscriptionRenewalState
    let willAutoRenew: Bool
    let expirationDate: Date?
    let renewalDate: Date?
    let renewalDisplayPrice: String?
    let renewalPeriod: SubscriptionPeriodSnapshot?
    let isIntroductoryOffer: Bool
    let wasRefunded: Bool
}

enum SubscriptionLifecycleState: String, Codable, Equatable, Sendable {
    case unknown
    case free
    case active
    case cancelledButActive
    case gracePeriod
    case billingRetry
    case expired
    case revoked
}

struct SubscriptionLifecycleSnapshot: Codable, Equatable, Sendable {
    let state: SubscriptionLifecycleState
    let productID: String?
    let renewalProductID: String?
    let willAutoRenew: Bool
    let expirationDate: Date?
    let renewalDate: Date?
    let renewalDisplayPrice: String?
    let renewalPeriod: SubscriptionPeriodSnapshot?
    let isIntroductoryOffer: Bool
    let wasRefunded: Bool

    static let unknown = SubscriptionLifecycleSnapshot(
        state: .unknown,
        productID: nil,
        renewalProductID: nil,
        willAutoRenew: false,
        expirationDate: nil,
        renewalDate: nil,
        renewalDisplayPrice: nil,
        renewalPeriod: nil,
        isIntroductoryOffer: false,
        wasRefunded: false
    )

    static let free = SubscriptionLifecycleSnapshot(
        state: .free,
        productID: nil,
        renewalProductID: nil,
        willAutoRenew: false,
        expirationDate: nil,
        renewalDate: nil,
        renewalDisplayPrice: nil,
        renewalPeriod: nil,
        isIntroductoryOffer: false,
        wasRefunded: false
    )

    var isEntitledState: Bool {
        switch state {
        case .active, .cancelledButActive, .gracePeriod: return true
        case .unknown, .free, .billingRetry, .expired, .revoked: return false
        }
    }

    static func resolve(
        verifiedStatuses: [VerifiedSubscriptionStatusSnapshot],
        now: Date = Date()
    ) -> SubscriptionLifecycleSnapshot {
        guard let status = verifiedStatuses.max(by: {
            priority(for: $0, now: now) < priority(for: $1, now: now)
        }) else {
            return .free
        }

        let state: SubscriptionLifecycleState
        switch status.state {
        case .unknown: state = .unknown
        case .subscribed:
            if let expirationDate = status.expirationDate, expirationDate <= now {
                state = .expired
            } else {
                state = status.willAutoRenew ? .active : .cancelledButActive
            }
        case .inGracePeriod: state = .gracePeriod
        case .inBillingRetryPeriod: state = .billingRetry
        case .expired: state = .expired
        case .revoked: state = .revoked
        }

        return SubscriptionLifecycleSnapshot(
            state: state,
            productID: status.productID,
            renewalProductID: status.renewalProductID,
            willAutoRenew: status.willAutoRenew,
            expirationDate: status.expirationDate,
            renewalDate: status.renewalDate,
            renewalDisplayPrice: status.renewalDisplayPrice,
            renewalPeriod: status.renewalPeriod,
            isIntroductoryOffer: status.isIntroductoryOffer,
            wasRefunded: status.wasRefunded
        )
    }

    /// Product-independent admission boundary for the global StoreKit status
    /// stream. Both the current transaction and its renewal target must be one
    /// of Noum's explicit product identifiers. This prevents another
    /// subscription group (or an unexpected cross-product renewal target) from
    /// influencing Noum's lifecycle telemetry while still allowing lifecycle
    /// state to resolve when no `Product` presentation metadata loaded.
    static func resolve(
        verifiedStatuses: [VerifiedSubscriptionStatusSnapshot],
        allowedProductIDs: Set<String>,
        now: Date = Date()
    ) -> SubscriptionLifecycleSnapshot {
        resolve(
            verifiedStatuses: admittedStatuses(
                verifiedStatuses,
                allowedProductIDs: allowedProductIDs
            ),
            now: now
        )
    }

    static func admittedStatuses(
        _ verifiedStatuses: [VerifiedSubscriptionStatusSnapshot],
        allowedProductIDs: Set<String>
    ) -> [VerifiedSubscriptionStatusSnapshot] {
        verifiedStatuses.filter {
            allowedProductIDs.contains($0.productID)
                && allowedProductIDs.contains($0.renewalProductID)
        }
    }

    private static func priority(
        for status: VerifiedSubscriptionStatusSnapshot,
        now: Date
    ) -> Int {
        switch status.state {
        case .unknown: return 0
        case .subscribed:
            guard status.expirationDate.map({ $0 > now }) ?? true else { return 2 }
            return status.willAutoRenew ? 7 : 6
        case .inGracePeriod: return 5
        case .inBillingRetryPeriod: return 4
        case .revoked: return 3
        case .expired: return 2
        }
    }
}

/// Separates the lifecycle shown now from the last verified observation used
/// to classify future transitions. Absence from StoreKit's global status
/// stream is not affirmative evidence that an already-entitled subscription
/// expired, so that case displays an unknown state without overwriting the
/// previous verified receipt.
struct SubscriptionLifecycleObservation: Equatable, Sendable {
    let visibleSnapshot: SubscriptionLifecycleSnapshot
    let snapshotToCommit: SubscriptionLifecycleSnapshot?

    static func resolve(
        verifiedStatuses: [VerifiedSubscriptionStatusSnapshot],
        allowedProductIDs: Set<String>,
        verifiedEntitlementProductIDs: Set<String>,
        lastObservedLifecycle: SubscriptionLifecycleSnapshot,
        now: Date = Date()
    ) -> SubscriptionLifecycleObservation {
        let admitted = SubscriptionLifecycleSnapshot.admittedStatuses(
            verifiedStatuses,
            allowedProductIDs: allowedProductIDs
        )
        let hasVerifiedEntitlement = !verifiedEntitlementProductIDs
            .intersection(allowedProductIDs)
            .isEmpty

        guard !admitted.isEmpty else {
            if hasVerifiedEntitlement || lastObservedLifecycle.isEntitledState {
                return SubscriptionLifecycleObservation(
                    visibleSnapshot: .unknown,
                    snapshotToCommit: nil
                )
            }
            return SubscriptionLifecycleObservation(
                visibleSnapshot: .free,
                snapshotToCommit: .free
            )
        }

        // StoreKit may add renewal states after this binary ships. Preserve
        // the last verified observation and expose uncertainty rather than
        // manufacturing an expiry/cancellation transition.
        let understood = admitted.filter { $0.state != .unknown }
        guard !understood.isEmpty else {
            return SubscriptionLifecycleObservation(
                visibleSnapshot: .unknown,
                snapshotToCommit: nil
            )
        }

        let snapshot = SubscriptionLifecycleSnapshot.resolve(
            verifiedStatuses: understood,
            now: now
        )
        return SubscriptionLifecycleObservation(
            visibleSnapshot: snapshot,
            snapshotToCommit: snapshot
        )
    }
}

enum PremiumPurchaseOutcome: Equatable, Hashable, Sendable {
    case purchased
    case cancelled
    case pending
    case failed

    var growthEventName: GrowthEventName {
        switch self {
        case .purchased: return .purchaseSucceeded
        case .cancelled: return .purchaseCancelled
        case .pending: return .purchasePending
        case .failed: return .purchaseFailed
        }
    }

    var growthOutcome: GrowthEventOutcome {
        switch self {
        case .purchased: return .succeeded
        case .cancelled: return .cancelled
        case .pending: return .deferred
        case .failed: return .failed
        }
    }
}

enum PremiumRestoreOutcome: Equatable, Sendable {
    case restored
    case noActiveSubscription
    case failed

    var userMessage: String {
        switch self {
        case .restored: return "Noum Pro was restored."
        case .noActiveSubscription: return "No active App Store subscription was found."
        case .failed: return "Restore could not connect to the App Store. Please try again."
        }
    }

    var growthEventName: GrowthEventName {
        switch self {
        case .restored: return .restoreSucceeded
        case .noActiveSubscription: return .restoreNoEntitlement
        case .failed: return .restoreFailed
        }
    }

    var growthOutcome: GrowthEventOutcome {
        switch self {
        case .restored: return .succeeded
        case .noActiveSubscription: return .recorded
        case .failed: return .failed
        }
    }
}

// MARK: - Premium Entitlement System (StoreKit 2)

@MainActor
final class PremiumManager: ObservableObject {
    static let shared = PremiumManager()

    @Published private(set) var isPremium: Bool
    @Published private(set) var products: [Product] = []
    @Published private(set) var productPresentations: [String: PremiumProductPresentation] = [:]
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var subscriptionLifecycle: SubscriptionLifecycleSnapshot = .unknown
    @Published private(set) var videoAnalysisCreditsRemaining: Int

    private let creditsKey = "NoumVideoAnalysisCredits"
    private let creditsResetKey = "NoumVideoAnalysisResetDate"
    /// StoreKit-derived lifecycle history is device/Apple-account scoped rather
    /// than attributable to a Noum account. Keep the key visible to the privacy
    /// registry so it remains exportable and deletable as legacy device data.
    nonisolated static let lifecycleSnapshotKey = "NoumVerifiedSubscriptionLifecycle.v1"
    private var lastObservedLifecycle: SubscriptionLifecycleSnapshot
    static let monthlyVideoAnalysisLimit = 5

    /// StoreKit product identifiers
    nonisolated static let monthlyID = "com.noum.pro.monthly"
    nonisolated static let annualID = "com.noum.pro.annual"
    private let productIDs: Set<String> = [monthlyID, annualID]

    private var transactionListener: Task<Void, Error>?
    #if DEBUG
    /// In-memory development/test override. This is intentionally separate
    /// from StoreKit state and is never persisted or compiled into release
    /// entitlement resolution.
    private var debugEntitlementOverride: Bool?
    #endif

    private init() {
        // StoreKit's current verified entitlements are the only production
        // authority. Start closed until that local StoreKit snapshot arrives
        // rather than briefly granting access from a stale persisted flag.
        isPremium = false
        lastObservedLifecycle = Self.loadLastObservedLifecycle()
        videoAnalysisCreditsRemaining = UserDefaults.standard.object(forKey: creditsKey) as? Int ?? Self.monthlyVideoAnalysisLimit
        resetCreditsIfNeeded()
        // Defer StoreKit work so it doesn't block the first frame.
        // The transaction listener and product loading involve XPC calls
        // that trigger heavy plist decoding on the main thread.
        Task { @MainActor [weak self] in
            // Yield once so the current run-loop cycle (view init) completes first
            await Task.yield()
            guard let self else { return }
            self.transactionListener = self.listenForTransactions()
            await self.loadProducts()
            await self.updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - StoreKit 2 Product Loading

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            let sortedProducts = storeProducts.sorted { $0.price < $1.price }
            var presentations: [String: PremiumProductPresentation] = [:]
            for product in sortedProducts {
                presentations[product.id] = await PremiumProductPresentation.storeKitProjection(for: product)
            }
            products = sortedProducts
            productPresentations = presentations
        } catch {
            // Products may not be available in sandbox — fall back gracefully
        }
    }

    // MARK: - Purchase

    func purchaseOutcome(
        _ product: Product,
        entryPoint: GrowthEntryPoint = .unknown,
        correlationID: UUID = UUID()
    ) async -> PremiumPurchaseOutcome {
        let plan = PremiumPlanOption.resolve(productID: product.id)?.growthPlan ?? .unknown
        recordGrowth(
            name: .purchaseStarted,
            outcome: .recorded,
            plan: plan,
            entryPoint: entryPoint,
            correlationID: correlationID
        )

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                recordGrowth(
                    name: .purchaseSucceeded,
                    outcome: .succeeded,
                    plan: plan,
                    entryPoint: entryPoint,
                    correlationID: correlationID
                )
                if Self.isFreeTrial(transaction) {
                    recordGrowth(
                        name: .trialStarted,
                        outcome: .succeeded,
                        plan: plan,
                        entryPoint: entryPoint,
                        correlationID: correlationID
                    )
                }
                return .purchased
            case .userCancelled:
                recordGrowth(
                    name: .purchaseCancelled,
                    outcome: .cancelled,
                    plan: plan,
                    entryPoint: entryPoint,
                    correlationID: correlationID
                )
                return .cancelled
            case .pending:
                recordGrowth(
                    name: .purchasePending,
                    outcome: .deferred,
                    plan: plan,
                    entryPoint: entryPoint,
                    correlationID: correlationID
                )
                return .pending
            @unknown default:
                recordGrowth(
                    name: .purchaseFailed,
                    outcome: .failed,
                    plan: plan,
                    entryPoint: entryPoint,
                    correlationID: correlationID
                )
                return .failed
            }
        } catch {
            recordGrowth(
                name: .purchaseFailed,
                outcome: .failed,
                plan: plan,
                entryPoint: entryPoint,
                correlationID: correlationID
            )
            return .failed
        }
    }

    /// Source-compatible Boolean facade retained for existing callers. New
    /// paywall code uses the typed outcome so pending approval is not presented
    /// as cancellation or failure.
    func purchase(_ product: Product) async throws -> Bool {
        await purchaseOutcome(product) == .purchased
    }

    /// Fallback purchase for when StoreKit products aren't loaded (simulated)
    func purchaseSimulated() {
        #if DEBUG
        upgradeToPremium()
        #endif
    }

    // MARK: - Restore

    @discardableResult
    func restorePurchases(
        entryPoint: GrowthEntryPoint = .unknown,
        correlationID: UUID = UUID()
    ) async -> PremiumRestoreOutcome {
        recordGrowth(
            name: .restoreStarted,
            outcome: .recorded,
            entryPoint: entryPoint,
            correlationID: correlationID
        )
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            let outcome: PremiumRestoreOutcome = isPremium
                ? .restored
                : .noActiveSubscription
            recordGrowth(
                name: outcome.growthEventName,
                outcome: outcome.growthOutcome,
                entryPoint: entryPoint,
                correlationID: correlationID
            )
            return outcome
        } catch {
            recordGrowth(
                name: .restoreFailed,
                outcome: .failed,
                entryPoint: entryPoint,
                correlationID: correlationID
            )
            return .failed
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    // Transaction verification failed
                }
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let item):
            return item
        }
    }

    private enum StoreError: Error {
        case failedVerification
    }

    nonisolated private static func isFreeTrial(_ transaction: StoreKit.Transaction) -> Bool {
        if #available(iOS 17.2, macOS 14.2, *) {
            return transaction.offer?.paymentMode == .freeTrial
        }
        return transaction.offerPaymentModeStringRepresentation
            == Product.SubscriptionOffer.PaymentMode.freeTrial.rawValue
    }

    // MARK: - Update Purchased Products

    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if productIDs.contains(transaction.productID) {
                    purchased.insert(transaction.productID)
                }
            } catch {
                // Skip unverified transactions
            }
        }

        purchasedProductIDs = purchased
        #if DEBUG
        let override = debugEntitlementOverride
        #else
        let override: Bool? = nil
        #endif
        let entitled = Self.resolvedEntitlement(
            verifiedPurchasedProductIDs: purchased,
            debugOverride: override
        )
        if entitled != isPremium {
            isPremium = entitled
        }
        await updateSubscriptionLifecycle()
    }

    /// Reconciles changes Apple may have delivered while Noum was not
    /// running. Authorization still comes only from verified StoreKit state;
    /// the persisted bounded snapshot is used solely to classify transitions.
    func refreshStoreKitState() async {
        if products.isEmpty {
            await loadProducts()
        }
        await updatePurchasedProducts()
    }

    /// Pure entitlement contract used by the StoreKit refresh and focused
    /// tests. There is deliberately no persisted-entitlement input: an empty
    /// verified set resolves to free unless a DEBUG-only override is active.
    nonisolated static func resolvedEntitlement(
        verifiedPurchasedProductIDs: Set<String>,
        debugOverride: Bool? = nil
    ) -> Bool {
        #if DEBUG
        if let debugOverride {
            return debugOverride
        }
        #else
        _ = debugOverride
        #endif
        return !verifiedPurchasedProductIDs.isEmpty
    }

    // MARK: - DEBUG Entitlement Override

    /// Retained for existing previews and test fixtures. Release builds never
    /// grant premium through this path.
    func upgradeToPremium() {
        #if DEBUG
        debugEntitlementOverride = true
        isPremium = true
        #endif
    }

    /// Retained for existing previews and test fixtures. Release builds keep
    /// StoreKit as the sole entitlement authority.
    func revokePremium() {
        #if DEBUG
        debugEntitlementOverride = false
        isPremium = false
        #endif
    }

    // MARK: - Video Analysis Credits

    var canUseVideoAnalysis: Bool { isPremium && videoAnalysisCreditsRemaining > 0 }

    func consumeVideoAnalysisCredit() -> Bool {
        guard canUseVideoAnalysis else { return false }
        videoAnalysisCreditsRemaining -= 1
        UserDefaults.standard.set(videoAnalysisCreditsRemaining, forKey: creditsKey)
        return true
    }

    private func resetCreditsIfNeeded() {
        let defaults = UserDefaults.standard
        if let resetDate = defaults.object(forKey: creditsResetKey) as? Date {
            if Date() >= resetDate {
                videoAnalysisCreditsRemaining = Self.monthlyVideoAnalysisLimit
                defaults.set(videoAnalysisCreditsRemaining, forKey: creditsKey)
                defaults.set(nextMonthlyReset(), forKey: creditsResetKey)
            }
        } else {
            // First launch — set initial reset date
            defaults.set(nextMonthlyReset(), forKey: creditsResetKey)
            defaults.set(Self.monthlyVideoAnalysisLimit, forKey: creditsKey)
            videoAnalysisCreditsRemaining = Self.monthlyVideoAnalysisLimit
        }
    }

    private func nextMonthlyReset() -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    // MARK: - Feature Gating

    // Core premium features
    var canUseCoachMode: Bool { isPremium }
    var canUseLiveTranscript: Bool { isPremium }
    var canViewCoachingInsights: Bool { isPremium }
    var canUseFillerTracking: Bool { isPremium }
    var canViewTrends: Bool { isPremium }
    var canRecordVideo: Bool { isPremium }
    var canUseAsyncChallenges: Bool { isPremium }

    // Free features available to everyone
    var canUseClassicMode: Bool { true }
    var canUseThinkingTime: Bool { true }
    var canUsePromptReadAloud: Bool { true }
    var canViewBasicScore: Bool { true }
    var canViewBasicHeadline: Bool { true }
    var canUseDailyChallenges: Bool { true }

    // Free users can create 1 async challenge at a time; premium unlimited
    var asyncChallengeLimit: Int { isPremium ? .max : 1 }

    // MARK: - Product Helpers

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyID }
    }

    var annualProduct: Product? {
        products.first { $0.id == Self.annualID }
    }

    func presentation(for plan: PremiumPlanOption) -> PremiumProductPresentation? {
        productPresentations[plan.productID]
    }

    // MARK: - Verified subscription lifecycle

    private func updateSubscriptionLifecycle() async {
        var statuses: [VerifiedSubscriptionStatusSnapshot] = []
        let productsByID = Dictionary(
            products.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // `Status.all` is independent of `Product.products(for:)`, so a
        // temporary catalog or storefront metadata failure cannot leave the
        // lifecycle snapshot stale. Every status still has to pass StoreKit's
        // verification boundary before it enters the bounded projection.
        for await group in Product.SubscriptionInfo.Status.all {
            for status in group.statuses {
                guard let transaction = try? checkVerified(status.transaction),
                      let renewalInfo = try? checkVerified(status.renewalInfo) else {
                    continue
                }

                // Loaded products enrich copy only. They are never required
                // for lifecycle state, entitlement authority, or admission.
                let renewalProduct = productsByID[renewalInfo.currentProductID]
                let renewalDisplayPrice: String?
                if let price = renewalInfo.renewalPrice, let renewalProduct {
                    renewalDisplayPrice = price.formatted(renewalProduct.priceFormatStyle)
                } else if let price = renewalInfo.renewalPrice,
                          let currency = renewalInfo.currency {
                    renewalDisplayPrice = price.formatted(.currency(code: currency.identifier))
                } else {
                    renewalDisplayPrice = nil
                }

                let isIntroductoryOffer: Bool
                if #available(iOS 17.2, macOS 14.2, *) {
                    isIntroductoryOffer = transaction.offer?.type == .introductory
                } else {
                    isIntroductoryOffer = transaction.offerType == .introductory
                }

                statuses.append(
                    VerifiedSubscriptionStatusSnapshot(
                        productID: transaction.productID,
                        renewalProductID: renewalInfo.currentProductID,
                        state: Self.lifecycleState(for: status.state),
                        willAutoRenew: renewalInfo.willAutoRenew,
                        expirationDate: transaction.expirationDate,
                        renewalDate: renewalInfo.renewalDate,
                        renewalDisplayPrice: renewalDisplayPrice,
                        renewalPeriod: renewalProduct?.subscription.map {
                            SubscriptionPeriodSnapshot($0.subscriptionPeriod)
                        },
                        isIntroductoryOffer: isIntroductoryOffer,
                        wasRefunded: transaction.revocationDate != nil
                            && transaction.ownershipType == .purchased
                    )
                )
            }
        }

        let previous = lastObservedLifecycle
        let observation = SubscriptionLifecycleObservation.resolve(
            verifiedStatuses: statuses,
            allowedProductIDs: productIDs,
            verifiedEntitlementProductIDs: purchasedProductIDs,
            lastObservedLifecycle: previous
        )
        subscriptionLifecycle = observation.visibleSnapshot
        guard let next = observation.snapshotToCommit else {
            return
        }
        recordLifecycleTransition(from: previous, to: next)
        lastObservedLifecycle = next
        Self.persistLastObservedLifecycle(next)
    }

    private static func lifecycleState(
        for state: Product.SubscriptionInfo.RenewalState
    ) -> VerifiedSubscriptionRenewalState {
        switch state {
        case .subscribed: return .subscribed
        case .expired: return .expired
        case .inBillingRetryPeriod: return .inBillingRetryPeriod
        case .inGracePeriod: return .inGracePeriod
        case .revoked: return .revoked
        default: return .unknown
        }
    }

    private func recordLifecycleTransition(
        from previous: SubscriptionLifecycleSnapshot,
        to next: SubscriptionLifecycleSnapshot
    ) {
        guard previous != next else { return }
        let eventName: GrowthEventName?
        let inactiveReason: GrowthEntitlementInactiveReason
        if !previous.isEntitledState, next.isEntitledState {
            eventName = .entitlementActivated
            inactiveReason = .unknown
        } else if previous.isEntitledState, !next.isEntitledState {
            switch next.state {
            case .billingRetry:
                eventName = .billingFailed
                inactiveReason = .billingRetry
            case .expired:
                eventName = .entitlementExpired
                inactiveReason = .expired
            case .revoked where next.wasRefunded:
                eventName = .purchaseRefunded
                inactiveReason = .refunded
            case .revoked:
                eventName = .entitlementBecameInactive
                inactiveReason = .revoked
            default:
                eventName = .entitlementBecameInactive
                inactiveReason = .unknown
            }
        } else if previous.isEntitledState,
                  next.isEntitledState,
                  previous.willAutoRenew,
                  !next.willAutoRenew {
            eventName = .subscriptionCancellationRequested
            inactiveReason = .unknown
        } else if previous.isEntitledState,
                  next.isEntitledState,
                  let previousExpiration = previous.expirationDate,
                  let nextExpiration = next.expirationDate,
                  nextExpiration > previousExpiration {
            eventName = .entitlementRenewed
            inactiveReason = .unknown
        } else {
            eventName = nil
            inactiveReason = .unknown
        }
        guard let eventName else { return }
        let plan = next.renewalProductID
            .flatMap(PremiumPlanOption.resolve(productID:))?
            .growthPlan ?? .unknown
        recordGrowth(
            name: eventName,
            outcome: .recorded,
            plan: plan,
            inactiveReason: inactiveReason
        )
    }


    private nonisolated static func loadLastObservedLifecycle() -> SubscriptionLifecycleSnapshot {
        guard let data = UserDefaults.standard.data(forKey: lifecycleSnapshotKey),
              let snapshot = try? JSONDecoder().decode(
                SubscriptionLifecycleSnapshot.self,
                from: data
              ) else {
            return .unknown
        }
        return snapshot
    }

    private nonisolated static func persistLastObservedLifecycle(
        _ snapshot: SubscriptionLifecycleSnapshot
    ) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: lifecycleSnapshotKey)
    }

    func recordPaywallImpression(
        entryPoint: GrowthEntryPoint,
        correlationID: UUID
    ) {
        recordGrowth(
            name: .paywallViewed,
            outcome: .recorded,
            plan: PremiumPlanOption.defaultSelection.growthPlan,
            entryPoint: entryPoint,
            correlationID: correlationID
        )
    }

    func recordPaywallEligibility(
        for plan: PremiumPlanOption,
        presentation: PremiumProductPresentation?,
        entryPoint: GrowthEntryPoint,
        correlationID: UUID
    ) {
        recordGrowth(
            name: .paywallEligibilityResolved,
            outcome: .recorded,
            plan: plan.growthPlan,
            trialEligibility: presentation?.growthTrialEligibility ?? .unavailable,
            entryPoint: entryPoint,
            correlationID: correlationID
        )
    }

    func recordProductSelection(
        _ plan: PremiumPlanOption,
        entryPoint: GrowthEntryPoint,
        correlationID: UUID
    ) {
        recordGrowth(
            name: .productSelected,
            outcome: .recorded,
            plan: plan.growthPlan,
            entryPoint: entryPoint,
            correlationID: correlationID
        )
    }

    private func recordGrowth(
        name: GrowthEventName,
        outcome: GrowthEventOutcome,
        plan: GrowthSubscriptionPlan = .unknown,
        trialEligibility: GrowthTrialEligibility = .unknown,
        inactiveReason: GrowthEntitlementInactiveReason = .unknown,
        entryPoint: GrowthEntryPoint = .unknown,
        correlationID: UUID = UUID()
    ) {
        let state: GrowthSubscriptionState
        if subscriptionLifecycle.isIntroductoryOffer && subscriptionLifecycle.isEntitledState {
            state = .trial
        } else if isPremium {
            state = .paid
        } else if subscriptionLifecycle.state == .expired || subscriptionLifecycle.state == .revoked {
            state = .lapsed
        } else {
            state = .free
        }
        FlowEventGrowthEventSink.shared.record(
            GrowthEvent(
                correlationID: correlationID,
                name: name,
                outcome: outcome,
                subscriptionState: state,
                subscriptionPlan: plan,
                trialEligibility: trialEligibility,
                inactiveReason: inactiveReason,
                entryPoint: entryPoint
            )
        )
    }
}

// MARK: - Paywall Release Contracts

enum PremiumPricing {
    static let unavailablePrice = "Price unavailable"

    /// StoreKit has already localized this value for the active storefront.
    /// If it is absent, showing no numeric claim is safer than inventing a
    /// currency-specific fallback.
    static func displayPrice(_ storeKitDisplayPrice: String?) -> String {
        guard let value = storeKitDisplayPrice?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return unavailablePrice
        }
        return value
    }

    /// Returns a conservative whole-number saving only when both StoreKit
    /// prices make the comparison valid. Rounding down avoids overclaiming.
    static func annualSavingsPercentage(
        monthlyPrice: Decimal?,
        annualPrice: Decimal?
    ) -> Int? {
        guard let monthlyPrice,
              let annualPrice,
              monthlyPrice > 0,
              annualPrice > 0 else {
            return nil
        }

        let twelveMonths = monthlyPrice * Decimal(12)
        guard annualPrice < twelveMonths else { return nil }

        var rawPercentage = ((twelveMonths - annualPrice) / twelveMonths) * Decimal(100)
        var roundedPercentage = Decimal()
        NSDecimalRound(&roundedPercentage, &rawPercentage, 0, .down)
        let percentage = NSDecimalNumber(decimal: roundedPercentage).intValue
        return percentage > 0 ? percentage : nil
    }
}

enum PremiumLegalLinks {
    /// Reuse the same hosted policy used by Settings and App Store Connect.
    static let privacyPolicy = NoumWebURLs.privacy

    /// Noum has no custom terms URL yet, so subscriptions use Apple's
    /// standard licensed application end-user licence agreement.
    static let termsOfUse = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!
}

enum PremiumSubscriptionCopy {
    static let cancellationExplanation =
        "Plans renew automatically. You can cancel or change plans in your Apple Account; access continues through the paid period after cancellation."
    static let deletionExplanation =
        "Deleting Noum does not cancel an App Store subscription."

    static func lifecycleMessage(
        _ snapshot: SubscriptionLifecycleSnapshot,
        formatDate: (Date) -> String
    ) -> String {
        let renewalDate = snapshot.renewalDate.map(formatDate)
        let expirationDate = snapshot.expirationDate.map(formatDate)
        let renewalCharge = snapshot.renewalDisplayPrice.map { price in
            guard let period = snapshot.renewalPeriod else { return price }
            return "\(price) \(period.billingCadence)"
        }
        switch snapshot.state {
        case .active:
            if let renewalDate, let renewalCharge {
                return "Renews on \(renewalDate) at \(renewalCharge)."
            }
            if let renewalDate { return "Renews on \(renewalDate)." }
            if let renewalCharge { return "Your next renewal is \(renewalCharge)." }
            return "Your subscription is active. Apple manages renewal and billing."
        case .cancelledButActive:
            if let expirationDate {
                return "Renewal is off. Pro remains available until \(expirationDate)."
            }
            return "Renewal is off. Apple shows the exact access end date in subscription management."
        case .gracePeriod:
            if let expirationDate {
                return "Apple is resolving a billing issue. Pro remains available through \(expirationDate)."
            }
            return "Apple is resolving a billing issue. Review your payment method in subscription management."
        case .billingRetry:
            return "Apple could not renew this subscription. Update your payment method to restore Pro."
        case .expired:
            return "This subscription has expired. Choose a plan to restart Pro."
        case .revoked:
            return "Apple has revoked this subscription. Open subscription management for details."
        case .unknown, .free:
            return "No active subscription is available."
        }
    }
}

// MARK: - Paywall View

@available(iOS 17.0, *)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var premium = PremiumManager.shared
    @State private var selectedPlan: PremiumPlanOption = .defaultSelection
    @State private var isPurchasing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var restoreMessage: String?
    @State private var showFeatureDetails = false
    @State private var didRecordImpression = false
    @State private var correlationID = UUID()
    @State private var recordedEligibilityPlans: Set<PremiumPlanOption> = []
    @State private var recordedSelectionPlans: Set<PremiumPlanOption> = []

    let entryPoint: GrowthEntryPoint
    let onProductSelection: ((PremiumPlanOption) -> Void)?

    init(
        entryPoint: GrowthEntryPoint = .unknown,
        onProductSelection: ((PremiumPlanOption) -> Void)? = nil
    ) {
        self.entryPoint = entryPoint
        self.onProductSelection = onProductSelection
    }

    private let proColor = AppColor.pro

    private func presentation(for plan: PremiumPlanOption) -> PremiumProductPresentation? {
        premium.presentation(for: plan)
    }

    private func priceText(for plan: PremiumPlanOption) -> String {
        presentation(for: plan)?.displayPrice
            ?? PremiumPricing.displayPrice(product(for: plan)?.displayPrice)
    }

    private func savingsText(for plan: PremiumPlanOption) -> String? {
        guard plan == .annual,
              let percentage = PremiumPricing.annualSavingsPercentage(
                monthlyPrice: premium.monthlyProduct?.price,
                annualPrice: premium.annualProduct?.price
              ) else {
            return nil
        }
        return "Save \(percentage)%"
    }

    private var selectedProduct: Product? {
        product(for: selectedPlan)
    }

    private var selectedPresentation: PremiumProductPresentation? {
        presentation(for: selectedPlan)
    }

    private func product(for plan: PremiumPlanOption) -> Product? {
        switch plan {
        case .annual: return premium.annualProduct
        case .monthly: return premium.monthlyProduct
        }
    }

    private var availableProductIDs: Set<String> {
        Set([premium.annualProduct?.id, premium.monthlyProduct?.id].compactMap { $0 })
    }

    private var availablePlans: [PremiumPlanOption] {
        PremiumPlanAvailability.visiblePlans(productIDs: availableProductIDs)
    }

    private var plansAvailable: Bool {
        !availablePlans.isEmpty
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppColor.textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(AppColor.cardBackground, in: Circle())
                            }
                            .buttonStyle(.pressable)
                            .accessibilityLabel("Close")
                        }
                        .padding(.top, Spacing.xs)

                        VStack(spacing: Spacing.sm) {
                            ZStack {
                                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                    .fill(proColor.opacity(0.10))
                                    .frame(width: 56, height: 56)

                                Image(systemName: "crown.fill")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(proColor)
                            }

                            Text("Go deeper with Noum")
                                .font(Typography.figtree(size: 32, weight: .bold, relativeTo: .title))
                                .foregroundStyle(AppColor.textPrimary)

                            Text("Core practice stays free. Pro adds a coach that remembers your reps and helps you review them.")
                                .font(Typography.body)
                                .foregroundStyle(AppColor.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        CardView(cornerRadius: CornerRadius.xl, padding: Spacing.lg) {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Text("Choose a plan")
                                    .font(Typography.headline.weight(.semibold))
                                    .foregroundStyle(AppColor.textPrimary)

                                if availablePlans.isEmpty {
                                    HStack(spacing: Spacing.sm) {
                                        ProgressView()
                                        Text("Loading App Store plans…")
                                            .font(.subheadline)
                                            .foregroundStyle(AppColor.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 88)
                                } else {
                                    ViewThatFits(in: .horizontal) {
                                        HStack(spacing: Spacing.sm) {
                                            ForEach(availablePlans) { plan in
                                                planCard(plan)
                                            }
                                        }

                                        VStack(spacing: Spacing.sm) {
                                            ForEach(availablePlans) { plan in
                                                planCard(plan)
                                            }
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(PremiumSubscriptionCopy.cancellationExplanation)
                                    Text(PremiumSubscriptionCopy.deletionExplanation)
                                }
                                .font(.caption)
                                .foregroundStyle(AppColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                                .stroke(proColor.opacity(0.12), lineWidth: 1)
                        )

                        if premium.subscriptionLifecycle.state != .unknown,
                           premium.subscriptionLifecycle.state != .free {
                            subscriptionStatusCard
                        }

                        CardView(cornerRadius: CornerRadius.large, padding: Spacing.lg) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("What Pro adds")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppColor.textPrimary)

                                featureRow(icon: "text.magnifyingglass", title: "Ask Noum", description: "A coaching thread grounded in your recent reps")
                                featureRow(icon: "chart.line.uptrend.xyaxis", title: "Deeper review", description: "See meaningful change and the next move")
                                featureRow(icon: "video.fill", title: "Video analysis", description: "Review delivery from saved practice recordings")

                                Divider()
                                    .padding(.vertical, Spacing.xs)

                                DisclosureGroup(isExpanded: $showFeatureDetails) {
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        Text("Core practice stays free")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppColor.textPrimary)
                                        freeFeatureRow(icon: "mic.fill", text: "Timed Practice")
                                        freeFeatureRow(icon: "brain.head.profile", text: "Session scoring")
                                        freeFeatureRow(icon: "clock.arrow.circlepath", text: "Session history")
                                        freeFeatureRow(icon: "person.fill.checkmark", text: "Coaching profile")
                                    }
                                    .padding(.top, Spacing.sm)
                                } label: {
                                    Text("See details")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColor.textPrimary)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                }
                                .tint(AppColor.textSecondary)
                            }
                        }

                        Spacer(minLength: Spacing.md)
                    }
                    .padding(.horizontal, Spacing.screenH)
                }

                VStack(spacing: Spacing.sm) {
                    Button {
                        if selectedProduct == nil {
                            reloadPlans()
                        } else {
                            purchasePremium()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: selectedProduct == nil ? "arrow.clockwise" : "crown.fill")
                                    .font(.headline)
                            }
                            Text(
                                isPurchasing
                                    ? "Loading\u{2026}"
                                    : selectedProduct == nil
                                        ? "Reload plans"
                                        : selectedPresentation?.purchaseButtonTitle ?? "Subscribe"
                            )
                                .font(.headline.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            LinearGradient(
                                colors: [proColor, proColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                        .shadow(color: proColor.opacity(0.18), radius: 12, y: 6)
                    }
                    .buttonStyle(.pressable)
                    .disabled(isPurchasing)
                    .accessibilityLabel(isPurchasing ? "Loading plans" : selectedProduct == nil ? "Reload subscription plans" : "Subscribe to Noum Pro")

                    if !plansAvailable, errorMessage == nil {
                        Text("Plans are temporarily unavailable. Reload to try again.")
                            .font(.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(AppColor.warning)
                    }

                    VStack(spacing: 8) {
                        Button("Restore") {
                            Task {
                                restoreMessage = nil
                                let outcome = await premium.restorePurchases(
                                    entryPoint: entryPoint,
                                    correlationID: correlationID
                                )
                                restoreMessage = outcome.userMessage
                                if outcome == .restored {
                                    showSuccess = true
                                }
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(minHeight: 44)

                        if let restoreMessage {
                            Text(restoreMessage)
                                .font(.caption)
                                .foregroundStyle(AppColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        Text("Payment is charged to your Apple Account at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the current period ends.")
                            .font(.caption2)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) {
                                subscriptionLinks
                            }

                            VStack(spacing: 0) {
                                subscriptionLinks
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
                .background(.regularMaterial)
                .overlay(alignment: .top) { Divider() }
            }

            if showSuccess {
                successOverlay
            }
        }
        .onChange(of: premium.isPremium) { _, newValue in
            if newValue {
                showSuccess = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    await MainActor.run { dismiss() }
                }
            }
        }
        .onAppear {
            if !didRecordImpression {
                didRecordImpression = true
                premium.recordPaywallImpression(
                    entryPoint: entryPoint,
                    correlationID: correlationID
                )
            }
            resolveSelectedPlanIfNeeded()
            recordSelectionIfNeeded(selectedPlan)
            recordAvailableEligibility()
        }
        .onChange(of: availableProductIDs) { _, _ in
            resolveSelectedPlanIfNeeded()
            recordSelectionIfNeeded(selectedPlan)
            recordAvailableEligibility()
        }
        .accessibilityIdentifier("paywall.root")
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(proColor)
                .frame(width: 36, height: 36)
                .background(proColor.opacity(0.15), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(proColor)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, Spacing.md)
    }

    private func freeFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppColor.positive)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private func planCard(_ plan: PremiumPlanOption) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            guard selectedPlan != plan else { return }
            withAnimation(reduceMotion ? nil : .snappySpring) {
                selectedPlan = plan
            }
            recordSelectionIfNeeded(plan)
        } label: {
            VStack(spacing: 8) {
                if let savings = savingsText(for: plan) {
                    Text(savings)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(proColor, in: Capsule())
                } else {
                    Spacer()
                        .frame(height: 20)
                }

                Text(plan.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)

                Text(priceText(for: plan))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? proColor : AppColor.textPrimary)

                Text(presentation(for: plan)?.billingPeriod?.billingCadence ?? "Billing period unavailable")
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)

                if let offer = presentation(for: plan)?.introductoryOfferLine(
                    startingAt: .now,
                    calendar: .current
                ) {
                    Text(offer)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(proColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ? proColor.opacity(0.08) : AppColor.innerSurface,
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? proColor : AppColor.subtleBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func purchasePremium() {
        isPurchasing = true
        errorMessage = nil

        Task {
            // Try real StoreKit purchase first
            let product: Product? = selectedPlan == .annual ? premium.annualProduct : premium.monthlyProduct

            if let product {
                let outcome = await premium.purchaseOutcome(
                    product,
                    entryPoint: entryPoint,
                    correlationID: correlationID
                )
                await MainActor.run {
                    isPurchasing = false
                    switch outcome {
                    case .purchased, .cancelled:
                        errorMessage = nil
                    case .pending:
                        errorMessage = "Purchase is awaiting App Store approval. Pro activates after Apple confirms it."
                    case .failed:
                        errorMessage = "Purchase failed. Please try again."
                    }
                }
            } else {
                // Products not available
                #if DEBUG
                // Simulate purchase in development
                try? await Task.sleep(for: .seconds(1.0))
                await MainActor.run {
                    premium.purchaseSimulated()
                    isPurchasing = false
                }
                #else
                await MainActor.run {
                    errorMessage = "Unable to connect to the App Store. Please check your connection and try again."
                    isPurchasing = false
                }
                #endif
            }
        }
    }

    private func reloadPlans() {
        isPurchasing = true
        errorMessage = nil

        Task {
            await premium.loadProducts()
            await MainActor.run {
                resolveSelectedPlanIfNeeded()
                isPurchasing = false
                if selectedProduct == nil {
                    errorMessage = "Plans are still unavailable. Please try again later."
                }
            }
        }
    }

    private func resolveSelectedPlanIfNeeded() {
        guard let resolved = PremiumPlanAvailability.resolvedSelection(
            current: selectedPlan,
            productIDs: availableProductIDs
        ) else {
            return
        }
        selectedPlan = resolved
    }

    private func recordAvailableEligibility() {
        for plan in PremiumPlanOption.allCases where !recordedEligibilityPlans.contains(plan) {
            guard product(for: plan) != nil,
                  let presentation = presentation(for: plan) else {
                continue
            }
            recordedEligibilityPlans.insert(plan)
            premium.recordPaywallEligibility(
                for: plan,
                presentation: presentation,
                entryPoint: entryPoint,
                correlationID: correlationID
            )
        }
    }

    private func recordSelectionIfNeeded(_ plan: PremiumPlanOption) {
        guard availablePlans.contains(plan) else { return }
        guard recordedSelectionPlans.insert(plan).inserted else { return }
        premium.recordProductSelection(
            plan,
            entryPoint: entryPoint,
            correlationID: correlationID
        )
        onProductSelection?(plan)
    }

    private var successOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColor.positive)
            Text("Pro is active")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Text("Your premium coaching tools are ready.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.screenBackground.opacity(0.98))
        .transition(.opacity)
    }

    @ViewBuilder
    private var subscriptionLinks: some View {
        Link("Manage subscription", destination: NoumWebURLs.manageSubscriptions)
            .accessibilityHint("Opens Apple subscription management.")
            .frame(minHeight: 44)

        Link("Privacy Policy", destination: PremiumLegalLinks.privacyPolicy)
            .accessibilityHint("Opens Noum's privacy policy.")
            .frame(minHeight: 44)

        Link("Terms of Use", destination: PremiumLegalLinks.termsOfUse)
            .accessibilityHint("Opens the subscription terms of use.")
            .frame(minHeight: 44)
    }

    private var subscriptionStatusCard: some View {
        let snapshot = premium.subscriptionLifecycle
        return CardView(cornerRadius: CornerRadius.large, padding: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Your subscription", systemImage: "checkmark.seal.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)

                Text(
                    PremiumSubscriptionCopy.lifecycleMessage(
                        snapshot,
                        formatDate: Self.formattedDate
                    )
                )
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Link("Manage or cancel with Apple", destination: NoumWebURLs.manageSubscriptions)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(minHeight: 44)
                    .accessibilityHint("Opens Apple subscription management.")
            }
        }
    }

    private static func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Premium Gate Overlay (reusable component)

@available(iOS 17.0, *)
struct PremiumGateOverlay: View {
    var feature: String = "This feature"
    @State private var showPaywall = false

    private let proColor = AppColor.pro

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(proColor)

            Text("\(feature) requires Pro")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text("Upgrade to unlock deeper coaching, transcripts, and analytics.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                    Text("Upgrade to Pro")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(proColor, in: Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [proColor.opacity(0.06), proColor.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(proColor.opacity(0.12), lineWidth: 1)
        )
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

#endif
