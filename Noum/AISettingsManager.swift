import Foundation

// Extracted from PracticeSupport.swift to relieve that file's size pressure
// (named long-term debt in docs/CURRENT_STATE.md). Pure mechanical move:
// behavior is identical, every public API surface is preserved.

@MainActor
final class AISettingsManager: ObservableObject {
    static let shared = AISettingsManager()

    @Published private(set) var analysisCountThisMonth: Int {
        didSet { UserDefaults.standard.set(analysisCountThisMonth, forKey: countKey) }
    }

    private let countKey = "aiMonthlyAnalysisCount"
    private let monthKey = "aiMonthlyAnalysisMonth"
    private let disclosureKeyPrefix = "hasAcknowledgedAIDisclosure."

    // MARK: - Usage Tiers
    // Premium: generous 100/month — most active users won't hit this.
    // Free: 20/month — enough to experience value, encourages upgrade.
    private static let premiumMonthlyLimit = 100
    private static let freeMonthlyLimit = 20

    /// The threshold (as fraction of limit) at which we surface a gentle heads-up.
    /// Set at 90% so users get a soft nudge, not a wall.
    static let usageAwarenessThreshold: Double = 0.90

    private init() {
        analysisCountThisMonth = UserDefaults.standard.integer(forKey: countKey)
        resetIfNeeded()
    }

    var activeProvider: AIProvider? {
        [.gemini, .openAI].first(where: hasAPIKey(for:))
    }

    /// Current monthly limit based on subscription tier.
    var monthlyLimit: Int {
        PremiumManager.shared.isPremium ? Self.premiumMonthlyLimit : Self.freeMonthlyLimit
    }

    var remainingAnalyses: Int {
        max(0, monthlyLimit - analysisCountThisMonth)
    }

    var canRequestAnalysis: Bool {
        activeProvider != nil && remainingAnalyses > 0
    }

    /// Whether the user is approaching their limit (≥90% used).
    /// Returns false if they still have plenty of headroom.
    var isApproachingLimit: Bool {
        let limit = monthlyLimit
        guard limit > 0 else { return true }
        return Double(analysisCountThisMonth) / Double(limit) >= Self.usageAwarenessThreshold
    }

    /// True when the monthly cap has been reached.
    var hasReachedLimit: Bool {
        analysisCountThisMonth >= monthlyLimit
    }

    /// Estimated date when the counter resets (first of next month).
    var resetDate: Date {
        let cal = Calendar.current
        let now = Date()
        if let nextMonth = cal.date(byAdding: .month, value: 1, to: cal.startOfDay(for: now)) {
            let comps = cal.dateComponents([.year, .month], from: nextMonth)
            return cal.date(from: comps) ?? nextMonth
        }
        return now
    }

    /// Human-readable reset date (e.g., "May 1").
    var resetDateFormatted: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d"
        return fmt.string(from: resetDate)
    }

    func recordAnalysis() {
        resetIfNeeded()
        analysisCountThisMonth += 1
    }

    func resetIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())
        let savedMonth = UserDefaults.standard.string(forKey: monthKey)
        if savedMonth != currentMonth {
            UserDefaults.standard.set(currentMonth, forKey: monthKey)
            analysisCountThisMonth = 0
        }
    }

    // MARK: - AI Transcript Disclosure

    /// Whether the current user has acknowledged that speech transcripts are sent to cloud AI.
    var hasAcknowledgedAIDisclosure: Bool {
        let accountID = KeychainHelper.load(key: "NoumAccountID") ?? "guest"
        return UserDefaults.standard.bool(forKey: disclosureKeyPrefix + accountID)
    }

    func acknowledgeAIDisclosure() {
        let accountID = KeychainHelper.load(key: "NoumAccountID") ?? "guest"
        UserDefaults.standard.set(true, forKey: disclosureKeyPrefix + accountID)
    }

    /// The user-facing name of the active AI provider (e.g., "Google Gemini", "OpenAI").
    var activeProviderDisplayName: String {
        switch activeProvider {
        case .gemini: return "Google Gemini"
        case .openAI: return "OpenAI"
        default: return "a cloud AI provider"
        }
    }

    private func hasAPIKey(for provider: AIProvider) -> Bool {
        guard let keyName = provider.environmentKey else { return false }

        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return true
        }

        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig") != nil
    }
}
