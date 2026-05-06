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

    private let storageKey = "NoumPremiumEntitlement"
    private let creditsKey = "NoumVideoAnalysisCredits"
    private let creditsResetKey = "NoumVideoAnalysisResetDate"
    static let monthlyVideoAnalysisLimit = 5

    /// StoreKit product identifiers
    static let monthlyID = "com.noum.pro.monthly"
    static let annualID = "com.noum.pro.annual"
    private let productIDs: Set<String> = [monthlyID, annualID]

    private var transactionListener: Task<Void, Error>?

    private init() {
        isPremium = UserDefaults.standard.bool(forKey: storageKey)
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

        await MainActor.run {
            purchasedProductIDs = purchased
            let entitled = !purchased.isEmpty || UserDefaults.standard.bool(forKey: storageKey)
            if entitled != isPremium {
                isPremium = entitled
                UserDefaults.standard.set(entitled, forKey: storageKey)
            }
        }
    }

    // MARK: - Manual Entitlement (for testing / promo codes)

    func upgradeToPremium() {
        isPremium = true
        UserDefaults.standard.set(true, forKey: storageKey)
    }

    func revokePremium() {
        isPremium = false
        UserDefaults.standard.set(false, forKey: storageKey)
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
    var canSaveTranscripts: Bool { isPremium }
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

    // Transcript limits for free users
    var savedTranscriptLimit: Int { isPremium ? .max : 3 }

    // MARK: - Product Helpers

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyID }
    }

    var annualProduct: Product? {
        products.first { $0.id == Self.annualID }
    }
}

// MARK: - Paywall View

@available(iOS 17.0, *)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var premium = PremiumManager.shared
    @State private var selectedPlan: PlanOption = .annual
    @State private var isPurchasing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

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

        var fallbackPrice: String {
            switch self {
            case .monthly: return "$4.99/mo"
            case .annual: return "$29.99/yr"
            }
        }

        var savings: String? {
            switch self {
            case .monthly: return nil
            case .annual: return "Save 50%"
            }
        }

        var fallbackPerMonth: String {
            switch self {
            case .monthly: return "$4.99/mo"
            case .annual: return "$2.50/mo"
            }
        }
    }

    private let proColor = AppColor.pro

    private func priceText(for plan: PlanOption) -> String {
        switch plan {
        case .monthly:
            return premium.monthlyProduct?.displayPrice ?? plan.fallbackPrice
        case .annual:
            return premium.annualProduct?.displayPrice ?? plan.fallbackPrice
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.02, blue: 0.10),
                    Color(red: 0.10, green: 0.04, blue: 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Close button
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.1), in: Circle())
                        }
                    }
                    .padding(.top, 8)

                    // Hero
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [proColor, AppColor.proLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: proColor.opacity(0.4), radius: 20, y: 8)

                        Text("Upgrade to Pro")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Unlock the full coaching experience")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    // Already included — free
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Already included — free")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))

                        VStack(alignment: .leading, spacing: 8) {
                            freeFeatureRow(icon: "mic.fill", text: "Classic practice mode")
                            freeFeatureRow(icon: "brain.head.profile", text: "AI-powered scoring")
                            freeFeatureRow(icon: "waveform.badge.magnifyingglass", text: "Filler word detection")
                            freeFeatureRow(icon: "clock.arrow.circlepath", text: "Session history")
                            freeFeatureRow(icon: "flame.fill", text: "Streaks & daily challenges")
                            freeFeatureRow(icon: "person.fill.checkmark", text: "Coaching onboarding")
                        }
                    }
                    .padding(Spacing.lg)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                    // Features
                    VStack(spacing: 0) {
                        featureRow(icon: "text.magnifyingglass", title: "Coach Mode", description: "Full transcript-led practice with deeper feedback")
                        featureRow(icon: "text.quote", title: "Live Transcript", description: "See your words in real time as you speak")
                        featureRow(icon: "video.fill", title: "Video Recording", description: "Record yourself and review your delivery")
                        featureRow(icon: "waveform.badge.magnifyingglass", title: "Filler Tracking", description: "Detect and reduce verbal crutches")
                        featureRow(icon: "chart.line.uptrend.xyaxis", title: "Trend Analytics", description: "Track improvement across sessions")
                        featureRow(icon: "person.2.wave.2.fill", title: "Unlimited Async Challenges", description: "Challenge friends to the same prompt")
                        featureRow(icon: "sparkles.rectangle.stack.fill", title: "AI Video Analysis", description: "Nonverbal coaching — 5 analyses/month")
                        featureRow(icon: "brain.fill", title: "100 AI Coaching Reads", description: "5× more monthly AI analyses than free tier")
                        featureRow(icon: "tray.full.fill", title: "Saved Transcripts", description: "Review and compare past sessions")
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                    // Plan selector
                    HStack(spacing: 12) {
                        ForEach(PlanOption.allCases) { plan in
                            planCard(plan)
                        }
                    }

                    // CTA
                    VStack(spacing: 12) {
                        Button {
                            purchasePremium()
                        } label: {
                            HStack(spacing: 8) {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "crown.fill")
                                        .font(.headline)
                                }
                                Text(isPurchasing ? "Processing..." : "Subscribe Now")
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
                            .shadow(color: proColor.opacity(0.4), radius: 16, y: 6)
                        }
                        .buttonStyle(.pressable)
                        .disabled(isPurchasing)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }

                        Button("Restore Purchase") {
                            Task {
                                await premium.restorePurchases()
                                if premium.isPremium {
                                    showSuccess = true
                                }
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))

                        Text("Cancel anytime. No commitment.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
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
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(proColor)
                .frame(width: 36, height: 36)
                .background(proColor.opacity(0.15), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(proColor)
        }
        .padding(.horizontal, 16)
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
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func planCard(_ plan: PlanOption) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPlan = plan
            }
        } label: {
            VStack(spacing: 8) {
                if let savings = plan.savings {
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
                    .foregroundStyle(.white)

                Text(priceText(for: plan))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? proColor : .white.opacity(0.7))

                Text(plan.fallbackPerMonth)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? proColor : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
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

    private var successOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Welcome to Pro")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("All premium features are now unlocked.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
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
