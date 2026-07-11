import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
import StoreKit

#if canImport(SwiftUI)

// MARK: - Premium Entitlement System (StoreKit 2)

@MainActor
final class PremiumManager: ObservableObject {
    static let shared = PremiumManager()

    @Published private(set) var isPremium: Bool
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var videoAnalysisCreditsRemaining: Int

    private let creditsKey = "NoumVideoAnalysisCredits"
    private let creditsResetKey = "NoumVideoAnalysisResetDate"
    static let monthlyVideoAnalysisLimit = 5

    /// StoreKit product identifiers
    static let monthlyID = "com.noum.pro.monthly"
    static let annualID = "com.noum.pro.annual"
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
            await MainActor.run {
                products = storeProducts.sorted { $0.price < $1.price }
            }
        } catch {
            // Products may not be available in sandbox — fall back gracefully
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Fallback purchase for when StoreKit products aren't loaded (simulated)
    func purchaseSimulated() {
        #if DEBUG
        upgradeToPremium()
        #endif
    }

    // MARK: - Restore

    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
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

// MARK: - Paywall View

@available(iOS 17.0, *)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var premium = PremiumManager.shared
    @State private var selectedPlan: PlanOption = .annual
    @State private var isPurchasing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var showFeatureDetails = false

    private enum PlanOption: String, CaseIterable, Identifiable {
        case monthly
        case annual

        var id: String { rawValue }

        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .annual: return "Annual"
            }
        }

        var renewalText: String {
            switch self {
            case .monthly: return "Renews monthly"
            case .annual: return "Renews annually"
            }
        }
    }

    private let proColor = AppColor.pro

    private func priceText(for plan: PlanOption) -> String {
        switch plan {
        case .monthly:
            return PremiumPricing.displayPrice(premium.monthlyProduct?.displayPrice)
        case .annual:
            return PremiumPricing.displayPrice(premium.annualProduct?.displayPrice)
        }
    }

    private func savingsText(for plan: PlanOption) -> String? {
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
        selectedPlan == .annual ? premium.annualProduct : premium.monthlyProduct
    }

    private var plansAvailable: Bool {
        premium.monthlyProduct != nil && premium.annualProduct != nil
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

                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: Spacing.sm) {
                                        ForEach(PlanOption.allCases) { plan in
                                            planCard(plan)
                                        }
                                    }

                                    VStack(spacing: Spacing.sm) {
                                        ForEach(PlanOption.allCases) { plan in
                                            planCard(plan)
                                        }
                                    }
                                }

                                Text("Cancel anytime in your Apple Account settings.")
                                    .font(.caption)
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                                .stroke(proColor.opacity(0.12), lineWidth: 1)
                        )

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
                            Text(isPurchasing ? "Loading\u{2026}" : selectedProduct == nil ? "Reload plans" : "Subscribe")
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
                                await premium.restorePurchases()
                                if premium.isPremium {
                                    showSuccess = true
                                }
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(minHeight: 44)

                        Text("Payment is charged to your Apple Account at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the current period ends.")
                            .font(.caption2)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 16) {
                            Link("Privacy Policy", destination: PremiumLegalLinks.privacyPolicy)
                                .accessibilityHint("Opens Noum's privacy policy.")
                                .frame(minHeight: 44)

                            Link("Terms of Use", destination: PremiumLegalLinks.termsOfUse)
                                .accessibilityHint("Opens the subscription terms of use.")
                                .frame(minHeight: 44)
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

    private func planCard(_ plan: PlanOption) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            withAnimation(reduceMotion ? nil : .snappySpring) {
                selectedPlan = plan
            }
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

                Text(plan.renewalText)
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
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
    }

    private func purchasePremium() {
        isPurchasing = true
        errorMessage = nil

        Task {
            // Try real StoreKit purchase first
            let product: Product? = selectedPlan == .annual ? premium.annualProduct : premium.monthlyProduct

            if let product {
                do {
                    let success = try await premium.purchase(product)
                    await MainActor.run {
                        isPurchasing = false
                        if !success {
                            errorMessage = nil // User cancelled — no error
                        }
                    }
                } catch {
                    await MainActor.run {
                        isPurchasing = false
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
                isPurchasing = false
                if selectedProduct == nil {
                    errorMessage = "Plans are still unavailable. Please try again later."
                }
            }
        }
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
