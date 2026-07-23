import Foundation

// MARK: - Growth and commercial observability
//
// This module defines a bounded event vocabulary and projects those events
// onto the existing account-local `FlowEventLog`; it is not another analytics
// store. Any first-party upload is a separate, explicit-consent aggregate of
// these sanitized events. Events contain enums, UUID correlation keys, dates, and bounded
// integers only. Transcript, prompt, response, goal, name, account identifier,
// product identifier, locale, and arbitrary metadata are not representable.

enum GrowthEventName: String, Codable, CaseIterable, Sendable {
    case accountActivated = "growth.lifecycle.accountActivated"
    case appActivated = "growth.lifecycle.appActivated"
    case onboardingStarted = "growth.activation.onboardingStarted"
    case onboardingCompleted = "growth.activation.onboardingCompleted"
    case firstValueDelivered = "growth.activation.firstValueDelivered"
    case firstWrittenValueDelivered = "growth.activation.firstWrittenValueDelivered"
    case firstSpokenPracticeStarted = "growth.practice.firstSpokenStarted"
    case practiceStarted = "growth.practice.started"
    case practiceCompleted = "growth.practice.completed"
    case secondPracticeCompleted = "growth.practice.secondCompleted"
    case thirdPracticeCompleted = "growth.practice.thirdCompleted"
    case summaryViewed = "growth.practice.summaryViewed"
    case coachOpened = "growth.engagement.coachOpened"
    case weeklyReadViewed = "growth.engagement.weeklyReadViewed"
    case paywallViewed = "growth.subscription.paywallViewed"
    case paywallEligibilityResolved = "growth.subscription.paywallEligibilityResolved"
    case productSelected = "growth.subscription.productSelected"
    case trialStarted = "growth.subscription.trialStarted"
    case purchaseStarted = "growth.subscription.purchaseStarted"
    case purchaseSucceeded = "growth.subscription.purchaseSucceeded"
    case purchaseFailed = "growth.subscription.purchaseFailed"
    case purchaseCancelled = "growth.subscription.purchaseCancelled"
    case purchasePending = "growth.subscription.purchasePending"
    case restoreStarted = "growth.subscription.restoreStarted"
    case restoreSucceeded = "growth.subscription.restoreSucceeded"
    case restoreNoEntitlement = "growth.subscription.restoreNoEntitlement"
    case restoreFailed = "growth.subscription.restoreFailed"
    case entitlementActivated = "growth.subscription.entitlementActivated"
    case entitlementRenewed = "growth.subscription.entitlementRenewed"
    case subscriptionCancellationRequested = "growth.subscription.cancellationRequested"
    case billingFailed = "growth.subscription.billingFailed"
    case purchaseRefunded = "growth.subscription.purchaseRefunded"
    case entitlementExpired = "growth.subscription.entitlementExpired"
    case entitlementBecameInactive = "growth.subscription.entitlementBecameInactive"
    case notificationOptInPrompted = "growth.notification.optInPrompted"
    case notificationOptInAccepted = "growth.notification.optInAccepted"
    case notificationOptInDeclined = "growth.notification.optInDeclined"
    case notificationOpened = "growth.notification.opened"
    case aiBudgetReserved = "growth.ai.budgetReserved"
    case aiUsageEstimated = "growth.ai.usageEstimated"
    case aiUsageUnpriced = "growth.ai.usageUnpriced"

    var canonicalReason: String {
        switch self {
        case .accountActivated: return "Account lifecycle began"
        case .appActivated: return "App became active"
        case .onboardingStarted: return "Onboarding began"
        case .onboardingCompleted: return "Onboarding completed"
        case .firstValueDelivered: return "First value delivered"
        case .firstWrittenValueDelivered: return "First written value delivered"
        case .firstSpokenPracticeStarted: return "First spoken practice began"
        case .practiceStarted: return "Practice began"
        case .practiceCompleted: return "Practice completed"
        case .secondPracticeCompleted: return "Second practice completed"
        case .thirdPracticeCompleted: return "Third practice completed"
        case .summaryViewed: return "Summary viewed"
        case .coachOpened: return "Coach opened"
        case .weeklyReadViewed: return "Weekly read viewed"
        case .paywallViewed: return "Subscription options viewed"
        case .paywallEligibilityResolved: return "Subscription eligibility resolved"
        case .productSelected: return "Subscription plan selected"
        case .trialStarted: return "Trial began"
        case .purchaseStarted: return "Purchase began"
        case .purchaseSucceeded: return "Purchase completed"
        case .purchaseFailed: return "Purchase did not complete"
        case .purchaseCancelled: return "Purchase cancelled"
        case .purchasePending: return "Purchase pending"
        case .restoreStarted: return "Restore began"
        case .restoreSucceeded: return "Restore completed"
        case .restoreNoEntitlement: return "Restore found no active entitlement"
        case .restoreFailed: return "Restore did not complete"
        case .entitlementActivated: return "Entitlement became active"
        case .entitlementRenewed: return "Entitlement renewed"
        case .subscriptionCancellationRequested: return "Subscription cancellation requested"
        case .billingFailed: return "Subscription billing failed"
        case .purchaseRefunded: return "Purchase refunded"
        case .entitlementExpired: return "Entitlement expired"
        case .entitlementBecameInactive: return "Entitlement became inactive"
        case .notificationOptInPrompted: return "Notification permission prompted"
        case .notificationOptInAccepted: return "Notification permission accepted"
        case .notificationOptInDeclined: return "Notification permission declined"
        case .notificationOpened: return "Notification opened"
        case .aiBudgetReserved: return "AI budget reserved"
        case .aiUsageEstimated: return "AI usage cost estimated"
        case .aiUsageUnpriced: return "AI usage cost needs provider units"
        }
    }

    fileprivate var allowedMetrics: Set<GrowthMetric> {
        switch self {
        case .accountActivated, .appActivated:
            return [.activeDayIndex]
        case .onboardingStarted:
            return []
        case .onboardingCompleted, .firstValueDelivered, .firstWrittenValueDelivered:
            return [.durationMs]
        case .practiceStarted, .practiceCompleted:
            return [.durationMs, .sessionCount]
        case .firstSpokenPracticeStarted,
             .secondPracticeCompleted, .thirdPracticeCompleted,
             .summaryViewed, .coachOpened, .weeklyReadViewed, .paywallViewed,
             .paywallEligibilityResolved, .productSelected, .purchaseStarted,
             .purchaseFailed, .purchaseCancelled, .purchasePending,
             .restoreStarted, .restoreSucceeded, .restoreNoEntitlement, .restoreFailed,
             .subscriptionCancellationRequested, .billingFailed,
             .purchaseRefunded, .entitlementExpired, .entitlementBecameInactive,
             .notificationOptInPrompted, .notificationOptInAccepted,
             .notificationOptInDeclined,
             .notificationOpened:
            return []
        case .trialStarted:
            return [.trialDays]
        case .purchaseSucceeded, .entitlementActivated, .entitlementRenewed:
            return [.trialDays, .periodDays]
        case .aiBudgetReserved:
            return [.dailyUsageCount, .dailyUsageCap]
        case .aiUsageEstimated:
            return [
                .inputTokens, .outputTokens, .cacheReadTokens,
                .cacheWriteTokens, .cachedInputTokens,
                .audioSeconds, .estimatedCostMicros, .pricingVersion, .latencyMs,
            ]
        case .aiUsageUnpriced:
            return [.audioSeconds, .pricingVersion, .latencyMs]
        }
    }

    fileprivate var allowsSubscriptionPlan: Bool {
        switch self {
        case .paywallViewed, .paywallEligibilityResolved, .productSelected,
             .trialStarted, .purchaseStarted, .purchaseSucceeded,
             .purchaseFailed, .purchaseCancelled, .purchasePending,
             .entitlementActivated, .entitlementRenewed,
             .subscriptionCancellationRequested, .billingFailed,
             .purchaseRefunded, .entitlementExpired,
             .entitlementBecameInactive:
            return true
        default:
            return false
        }
    }
}

/// Resolves stable, content-free journey keys without introducing a second
/// analytics store. A previously logged start is authoritative across app
/// relaunches; otherwise the onboarding draft's durable correlation ID wins.
enum GrowthJourneyCorrelation {
    static func onboarding(
        existingEvents: [GrowthEvent],
        draftCorrelationID: UUID?,
        fallback: UUID = UUID()
    ) -> UUID {
        existingEvents
            .filter { $0.name == .onboardingStarted }
            .min(by: { $0.createdAt < $1.createdAt })?
            .correlationID
            ?? draftCorrelationID
            ?? fallback
    }
}

/// Converts account activation into a calendar-day index for retention.
///
/// This is deliberately elapsed-day based, not an ordinal count of opens: an
/// account activated on Day 0 that next returns on Day 7 must emit `7` even if
/// it did not open Noum on Days 1–6. The caller supplies the account's local
/// calendar so daylight-saving transitions do not turn a calendar return into
/// an hours-since-activation calculation.
enum GrowthActivationDayIndex {
    static func elapsed(
        from activatedAt: Date,
        to now: Date,
        calendar: Calendar = .current
    ) -> Int {
        let activationDay = calendar.startOfDay(for: activatedAt)
        let currentDay = calendar.startOfDay(for: now)
        let elapsed = calendar.dateComponents(
            [.day],
            from: activationDay,
            to: currentDay
        ).day ?? 0
        return min(GrowthMetric.activeDayIndex.maximum, max(0, elapsed))
    }
}

enum GrowthEventOutcome: Int, Codable, CaseIterable, Sendable {
    case recorded = 0
    case succeeded = 1
    case failed = 2
    case cancelled = 3
    case deferred = 4
    /// A provider attempt incurred usage before a later route took over.
    /// This stays distinct from `deferred` without retaining provider errors.
    case fallback = 5

    fileprivate var flowOutcome: AICallDiagnosticOutcome {
        switch self {
        case .recorded, .succeeded: return .success
        case .failed: return .failure
        case .cancelled, .deferred: return .skipped
        case .fallback: return .fallback
        }
    }
}

extension AICallDiagnosticOutcome {
    var growthUsageOutcome: GrowthEventOutcome {
        switch self {
        case .success: return .succeeded
        case .fallback: return .fallback
        case .failure: return .failed
        case .skipped: return .deferred
        }
    }
}

enum GrowthSubscriptionState: Int, Codable, CaseIterable, Sendable {
    case unknown = 0
    case free = 1
    case trial = 2
    case paid = 3
    case lapsed = 4
}

/// Deliberately coarser than a StoreKit product identifier. It is stable across
/// storefronts and cannot reveal offer codes or commercially sensitive IDs.
enum GrowthSubscriptionPlan: Int, Codable, CaseIterable, Sendable {
    case unknown = 0
    case monthly = 1
    case annual = 2
}

enum GrowthTrialEligibility: Int, Codable, CaseIterable, Sendable {
    case unknown = 0
    case eligible = 1
    case ineligible = 2
    case unavailable = 3
}

enum GrowthEntitlementInactiveReason: Int, Codable, CaseIterable, Sendable {
    case unknown = 0
    case userCancelled = 1
    case billingRetry = 2
    case billingFailure = 3
    case refunded = 4
    case expired = 5
    case revoked = 6
}

enum GrowthNotificationKind: Int, Codable, CaseIterable, Sendable {
    case unknown = 0
    case practiceReminder = 1
    case weeklyRead = 2
    case bigMoment = 3
    case reengagement = 4
}

/// Bounded origin of a lifecycle action. These are product surfaces, not
/// campaign identifiers; acquisition attribution remains outside the app.
enum GrowthEntryPoint: Int, Codable, CaseIterable, Sendable {
    case unknown = 0
    case onboarding = 1
    case home = 2
    case train = 3
    case review = 4
    case profile = 5
    case settings = 6
    case coach = 7
    case postPractice = 8
    case notification = 9
}

enum GrowthMetric: String, Codable, CaseIterable, Sendable {
    case activeDayIndex
    case durationMs
    case sessionCount
    case trialDays
    case periodDays
    case dailyUsageCount
    case dailyUsageCap
    case inputTokens
    case outputTokens
    case cacheReadTokens
    case cacheWriteTokens
    case cachedInputTokens
    case audioSeconds
    case estimatedCostMicros
    case pricingVersion
    case latencyMs

    fileprivate var maximum: Int {
        switch self {
        case .durationMs, .latencyMs: return 86_400_000
        case .audioSeconds: return 86_400
        case .inputTokens, .outputTokens, .cacheReadTokens,
             .cacheWriteTokens, .cachedInputTokens:
            return 100_000_000
        case .estimatedCostMicros: return 1_000_000_000
        case .pricingVersion: return 1_000_000
        case .activeDayIndex, .sessionCount, .trialDays, .periodDays,
             .dailyUsageCount, .dailyUsageCap:
            return 1_000_000
        }
    }

    fileprivate func bounded(_ value: Int) -> Int {
        min(max(0, value), maximum)
    }
}

enum AIUsageSurface: Int, Codable, CaseIterable, Sendable {
    case unknown = 0
    case askNoum = 1
    case coachJudgement = 2
    case postRepCoachNote = 3
    case sessionDebrief = 4
    case forwardPlan = 5
    case proofMoment = 6
    case goalParaphrase = 7
    case rewrite = 8
    case promptGeneration = 9
    case transcription = 10

    static func classify(_ diagnosticSurface: String) -> AIUsageSurface {
        let value = diagnosticSurface.lowercased()
        if value.contains("ask noum") || value.contains("coach chat") { return .askNoum }
        if value.contains("judgement") || value.contains("reasoning pass") { return .coachJudgement }
        if value.contains("post-rep") || value.contains("coach note") { return .postRepCoachNote }
        if value.contains("debrief") || value.contains("insight") { return .sessionDebrief }
        if value.contains("forward plan") { return .forwardPlan }
        if value.contains("proof moment") { return .proofMoment }
        if value.contains("goal") && value.contains("paraphrase") { return .goalParaphrase }
        if value.contains("rewrite") || value.contains("grammar") { return .rewrite }
        if value.contains("prompt") { return .promptGeneration }
        if value.contains("transcription") || value.contains("speech to text") { return .transcription }
        return .unknown
    }
}

enum AIUsageProviderFamily: Int, Codable, CaseIterable, Sendable {
    case unknown = 0
    case anthropic = 1
    case openAI = 2
    case google = 3
    case deepSeek = 4
    case onDevice = 5
    case deepgram = 6

    static func classify(provider: String, model: String? = nil) -> AIUsageProviderFamily {
        let value = "\(provider) \(model ?? "")".lowercased()
        if value.contains("anthropic") || value.contains("claude") { return .anthropic }
        if value.contains("openai") || value.contains("gpt") { return .openAI }
        if value.contains("google") || value.contains("gemini") || value.contains("vertex") { return .google }
        if value.contains("deepseek") { return .deepSeek }
        if value.contains("deepgram") || value.contains("nova-2") { return .deepgram }
        if value.contains("on-device") || value.contains("on device") || value.contains("local") { return .onDevice }
        return .unknown
    }
}

struct GrowthEvent: Codable, Equatable, Identifiable, Sendable {
    static let schemaVersion = 1

    let id: UUID
    let createdAt: Date
    let correlationID: UUID
    let name: GrowthEventName
    let outcome: GrowthEventOutcome
    let subscriptionState: GrowthSubscriptionState
    let subscriptionPlan: GrowthSubscriptionPlan
    let trialEligibility: GrowthTrialEligibility
    let inactiveReason: GrowthEntitlementInactiveReason
    let notificationKind: GrowthNotificationKind
    let entryPoint: GrowthEntryPoint
    let aiSurface: AIUsageSurface?
    let aiProvider: AIUsageProviderFamily?
    let metrics: [GrowthMetric: Int]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        correlationID: UUID = UUID(),
        name: GrowthEventName,
        outcome: GrowthEventOutcome = .recorded,
        subscriptionState: GrowthSubscriptionState = .unknown,
        subscriptionPlan: GrowthSubscriptionPlan = .unknown,
        trialEligibility: GrowthTrialEligibility = .unknown,
        inactiveReason: GrowthEntitlementInactiveReason = .unknown,
        notificationKind: GrowthNotificationKind = .unknown,
        entryPoint: GrowthEntryPoint = .unknown,
        aiSurface: AIUsageSurface? = nil,
        aiProvider: AIUsageProviderFamily? = nil,
        metrics: [GrowthMetric: Int] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.correlationID = correlationID
        self.name = name
        self.outcome = outcome
        switch name {
        case .aiUsageEstimated, .aiUsageUnpriced:
            // The full eight-field token/cost record plus schema, outcome, AI
            // surface, and provider exactly fills FlowEvent's numeric budget.
            // Subscription and UI origin belong on the paired lifecycle event.
            self.subscriptionState = .unknown
            self.subscriptionPlan = .unknown
            self.trialEligibility = .unknown
            self.inactiveReason = .unknown
            self.notificationKind = .unknown
            self.entryPoint = .unknown
            self.aiSurface = aiSurface
            self.aiProvider = aiProvider
        case .aiBudgetReserved:
            self.subscriptionState = subscriptionState
            self.subscriptionPlan = .unknown
            self.trialEligibility = .unknown
            self.inactiveReason = .unknown
            self.notificationKind = .unknown
            self.entryPoint = entryPoint
            self.aiSurface = aiSurface
            self.aiProvider = nil
        default:
            self.subscriptionState = subscriptionState
            self.subscriptionPlan = name.allowsSubscriptionPlan ? subscriptionPlan : .unknown
            self.trialEligibility = name == .paywallEligibilityResolved
                ? trialEligibility
                : .unknown
            self.inactiveReason = [
                GrowthEventName.entitlementBecameInactive,
                .billingFailed,
                .purchaseRefunded,
                .entitlementExpired,
            ].contains(name) ? inactiveReason : .unknown
            self.notificationKind = name == .notificationOpened
                ? notificationKind
                : .unknown
            self.entryPoint = entryPoint
            self.aiSurface = nil
            self.aiProvider = nil
        }
        self.metrics = Dictionary(
            metrics
                .filter { name.allowedMetrics.contains($0.key) }
                .sorted { $0.key.rawValue < $1.key.rawValue }
                .prefix(12)
                .map { ($0.key, $0.key.bounded($0.value)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var flowEvent: FlowEvent {
        var numerics = Dictionary(
            metrics.map { ($0.key.rawValue, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        numerics[GrowthPrivacyGuard.schemaKey] = Self.schemaVersion
        numerics[GrowthPrivacyGuard.outcomeKey] = outcome.rawValue
        if subscriptionState != .unknown {
            numerics[GrowthPrivacyGuard.subscriptionKey] = subscriptionState.rawValue
        }
        if subscriptionPlan != .unknown {
            numerics[GrowthPrivacyGuard.subscriptionPlanKey] = subscriptionPlan.rawValue
        }
        if trialEligibility != .unknown {
            numerics[GrowthPrivacyGuard.trialEligibilityKey] = trialEligibility.rawValue
        }
        if inactiveReason != .unknown {
            numerics[GrowthPrivacyGuard.inactiveReasonKey] = inactiveReason.rawValue
        }
        if notificationKind != .unknown {
            numerics[GrowthPrivacyGuard.notificationKindKey] = notificationKind.rawValue
        }
        if entryPoint != .unknown {
            numerics[GrowthPrivacyGuard.entryPointKey] = entryPoint.rawValue
        }
        if let aiSurface { numerics[GrowthPrivacyGuard.aiSurfaceKey] = aiSurface.rawValue }
        if let aiProvider { numerics[GrowthPrivacyGuard.aiProviderKey] = aiProvider.rawValue }
        return FlowEvent.make(
            id: id,
            createdAt: createdAt,
            correlationId: correlationID,
            flow: .other,
            stage: name.rawValue,
            outcome: outcome.flowOutcome,
            reason: name.canonicalReason,
            numerics: numerics
        )
    }
}

enum GrowthPrivacyRedaction: String, Codable, CaseIterable, Sendable {
    case reason
    case unknownNumeric
    case outOfRangeNumeric
    case invalidDimension
    case excessNumerics
}

struct GrowthPrivacyValidation: Equatable, Sendable {
    let event: GrowthEvent
    let redactions: Set<GrowthPrivacyRedaction>

    var wasRedacted: Bool { !redactions.isEmpty }
}

enum GrowthPrivacyGuard {
    fileprivate static let schemaKey = "growthSchema"
    fileprivate static let outcomeKey = "growthOutcome"
    fileprivate static let subscriptionKey = "subscriptionState"
    fileprivate static let subscriptionPlanKey = "subscriptionPlan"
    fileprivate static let trialEligibilityKey = "trialEligibility"
    fileprivate static let inactiveReasonKey = "inactiveReason"
    fileprivate static let notificationKindKey = "notificationKind"
    fileprivate static let entryPointKey = "entryPoint"
    fileprivate static let aiSurfaceKey = "aiSurface"
    fileprivate static let aiProviderKey = "aiProvider"

    private static let dimensionKeys: Set<String> = [
        schemaKey, outcomeKey, subscriptionKey, subscriptionPlanKey,
        trialEligibilityKey, inactiveReasonKey, notificationKindKey,
        entryPointKey, aiSurfaceKey, aiProviderKey,
    ]

    /// Converts an existing flow record into the typed growth vocabulary.
    /// Unknown stages fail closed. Arbitrary reasons and numeric keys are never
    /// retained; recognized numeric values are clamped to their safe range.
    static func sanitize(_ flowEvent: FlowEvent) -> GrowthPrivacyValidation? {
        guard let name = GrowthEventName(rawValue: flowEvent.stage) else { return nil }

        var redactions: Set<GrowthPrivacyRedaction> = []
        if flowEvent.reason != name.canonicalReason { redactions.insert(.reason) }
        if flowEvent.numerics.count > 12 { redactions.insert(.excessNumerics) }
        if let schema = flowEvent.numerics[schemaKey], schema != GrowthEvent.schemaVersion {
            redactions.insert(.invalidDimension)
        }

        var metrics: [GrowthMetric: Int] = [:]
        for (key, value) in flowEvent.numerics {
            if dimensionKeys.contains(key) { continue }
            guard let metric = GrowthMetric(rawValue: key),
                  name.allowedMetrics.contains(metric) else {
                redactions.insert(.unknownNumeric)
                continue
            }
            let bounded = metric.bounded(value)
            if bounded != value { redactions.insert(.outOfRangeNumeric) }
            metrics[metric] = bounded
        }

        func dimension<Value>(
            _ key: String,
            decode: (Int) -> Value?
        ) -> Value? {
            guard let rawValue = flowEvent.numerics[key] else { return nil }
            guard let value = decode(rawValue) else {
                redactions.insert(.invalidDimension)
                return nil
            }
            return value
        }

        let encodedOutcome = dimension(outcomeKey, decode: GrowthEventOutcome.init(rawValue:))
        let fallbackOutcome: GrowthEventOutcome = switch flowEvent.outcome {
        case .success: .recorded
        case .failure: .failed
        case .fallback: .fallback
        case .skipped: .deferred
        }
        let outcome = encodedOutcome ?? fallbackOutcome
        if encodedOutcome != nil, outcome.flowOutcome != flowEvent.outcome {
            redactions.insert(.invalidDimension)
        }
        let subscription = dimension(
            subscriptionKey,
            decode: GrowthSubscriptionState.init(rawValue:)
        ) ?? .unknown
        let subscriptionPlan = dimension(
            subscriptionPlanKey,
            decode: GrowthSubscriptionPlan.init(rawValue:)
        ) ?? .unknown
        let trialEligibility = dimension(
            trialEligibilityKey,
            decode: GrowthTrialEligibility.init(rawValue:)
        ) ?? .unknown
        let inactiveReason = dimension(
            inactiveReasonKey,
            decode: GrowthEntitlementInactiveReason.init(rawValue:)
        ) ?? .unknown
        let notificationKind = dimension(
            notificationKindKey,
            decode: GrowthNotificationKind.init(rawValue:)
        ) ?? .unknown
        let entryPoint = dimension(entryPointKey, decode: GrowthEntryPoint.init(rawValue:)) ?? .unknown
        let aiSurface = dimension(aiSurfaceKey, decode: AIUsageSurface.init(rawValue:))
        let aiProvider = dimension(aiProviderKey, decode: AIUsageProviderFamily.init(rawValue:))

        let sanitizedEvent = GrowthEvent(
            id: flowEvent.id,
            createdAt: flowEvent.createdAt,
            correlationID: flowEvent.correlationId,
            name: name,
            outcome: outcome,
            subscriptionState: subscription,
            subscriptionPlan: subscriptionPlan,
            trialEligibility: trialEligibility,
            inactiveReason: inactiveReason,
            notificationKind: notificationKind,
            entryPoint: entryPoint,
            aiSurface: aiSurface,
            aiProvider: aiProvider,
            metrics: metrics
        )
        if sanitizedEvent.subscriptionState != subscription
            || sanitizedEvent.subscriptionPlan != subscriptionPlan
            || sanitizedEvent.trialEligibility != trialEligibility
            || sanitizedEvent.inactiveReason != inactiveReason
            || sanitizedEvent.notificationKind != notificationKind
            || sanitizedEvent.entryPoint != entryPoint
            || sanitizedEvent.aiSurface != aiSurface
            || sanitizedEvent.aiProvider != aiProvider {
            redactions.insert(.invalidDimension)
        }

        return GrowthPrivacyValidation(
            event: sanitizedEvent,
            redactions: redactions
        )
    }

    static func containsCommunicationContent(_ event: GrowthEvent) -> Bool {
        // Typed events have no field capable of carrying communication content.
        // Keep this explicit predicate for export/privacy contract tests.
        false
    }
}

@MainActor
protocol GrowthEventSink: AnyObject {
    @discardableResult
    func record(_ event: GrowthEvent) -> Bool
}

/// Adapter only. `FlowEventLog` remains the single persistence, account scope,
/// export, and deletion owner for growth events.
@MainActor
final class FlowEventGrowthEventSink: GrowthEventSink {
    static let shared = FlowEventGrowthEventSink(flowEventLog: .shared)

    private let flowEventLog: FlowEventLog

    init(flowEventLog: FlowEventLog) {
        self.flowEventLog = flowEventLog
    }

    @discardableResult
    func record(_ event: GrowthEvent) -> Bool {
        guard !GrowthPrivacyGuard.containsCommunicationContent(event) else { return false }
        // Re-run construction so even a record produced by `Codable` decoding
        // cannot bypass metric bounds or event-specific dimension rules.
        let normalized = GrowthEvent(
            id: event.id,
            createdAt: event.createdAt,
            correlationID: event.correlationID,
            name: event.name,
            outcome: event.outcome,
            subscriptionState: event.subscriptionState,
            subscriptionPlan: event.subscriptionPlan,
            trialEligibility: event.trialEligibility,
            inactiveReason: event.inactiveReason,
            notificationKind: event.notificationKind,
            entryPoint: event.entryPoint,
            aiSurface: event.aiSurface,
            aiProvider: event.aiProvider,
            metrics: event.metrics
        )
        let flowEvent = normalized.flowEvent
        // Diagnostic producers can retry delivery to the main actor. Preserve
        // every provider attempt, but make replay of the exact same typed event
        // idempotent so unit-economics totals cannot double count it.
        guard !flowEventLog.events.contains(where: { $0.id == flowEvent.id }) else {
            return true
        }
        flowEventLog.log(flowEvent)
        return true
    }
}

// MARK: - AI usage cost

enum GrowthCurrency: String, Codable, Equatable, Sendable {
    case usd = "USD"
    case gbp = "GBP"
}

struct AIUsagePricing: Codable, Equatable, Sendable {
    static let maximumRateMicrosPerMillionTokens: Int64 = 100_000_000
    static let maximumRateMicrosPerAudioHour: Int64 = 100_000_000

    let version: Int
    let currency: GrowthCurrency
    let inputMicrosPerMillionTokens: Int64
    let outputMicrosPerMillionTokens: Int64
    let cacheWriteMicrosPerMillionTokens: Int64
    let cacheReadMicrosPerMillionTokens: Int64
    let inputCountIncludesCachedContent: Bool
    let audioMicrosPerHour: Int64
    let minimumBillableAudioSeconds: Int
    let audioBillingIncrementSeconds: Int

    init(
        version: Int,
        currency: GrowthCurrency = .usd,
        inputMicrosPerMillionTokens: Int64,
        outputMicrosPerMillionTokens: Int64,
        cacheWriteMicrosPerMillionTokens: Int64 = 0,
        cacheReadMicrosPerMillionTokens: Int64 = 0,
        inputCountIncludesCachedContent: Bool = false,
        audioMicrosPerHour: Int64 = 0,
        minimumBillableAudioSeconds: Int = 0,
        audioBillingIncrementSeconds: Int = 1
    ) {
        self.version = min(max(0, version), 1_000_000)
        self.currency = currency
        self.inputMicrosPerMillionTokens = Self.boundedRate(inputMicrosPerMillionTokens)
        self.outputMicrosPerMillionTokens = Self.boundedRate(outputMicrosPerMillionTokens)
        self.cacheWriteMicrosPerMillionTokens = Self.boundedRate(cacheWriteMicrosPerMillionTokens)
        self.cacheReadMicrosPerMillionTokens = Self.boundedRate(cacheReadMicrosPerMillionTokens)
        self.inputCountIncludesCachedContent = inputCountIncludesCachedContent
        self.audioMicrosPerHour = min(
            max(0, audioMicrosPerHour),
            Self.maximumRateMicrosPerAudioHour
        )
        self.minimumBillableAudioSeconds = min(max(0, minimumBillableAudioSeconds), 86_400)
        self.audioBillingIncrementSeconds = min(max(1, audioBillingIncrementSeconds), 86_400)
    }

    private static func boundedRate(_ value: Int64) -> Int64 {
        min(max(0, value), maximumRateMicrosPerMillionTokens)
    }
}

/// Versioned pricing snapshots for the text and speech models that Noum calls.
/// Unknown explicit models fail closed so a model override cannot silently be
/// assigned another model's rate. A missing model uses that provider's Noum
/// default because older diagnostics did not always persist a model label.
enum AIUsagePricingCatalog {
    static let currentVersion = 202607

    static func pricing(for diagnostic: AICallDiagnosticRecord) -> AIUsagePricing? {
        pricing(
            provider: AIUsageProviderFamily.classify(
                provider: diagnostic.provider,
                model: diagnostic.model
            ),
            model: diagnostic.model,
            inputTokens: diagnostic.inputTokens
        )
    }

    static func pricing(
        provider: AIUsageProviderFamily,
        model: String?,
        inputTokens: Int? = nil
    ) -> AIUsagePricing? {
        let normalizedModel = model?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        switch provider {
        case .anthropic:
            guard normalizedModel.isEmpty
                    || normalizedModel.contains("claude-sonnet-4-6") else { return nil }
            return AIUsagePricing(
                version: currentVersion,
                inputMicrosPerMillionTokens: 3_000_000,
                outputMicrosPerMillionTokens: 15_000_000,
                cacheWriteMicrosPerMillionTokens: 3_750_000,
                cacheReadMicrosPerMillionTokens: 300_000
            )
        case .openAI:
            guard normalizedModel.isEmpty
                    || normalizedModel.contains("gpt-4o-mini") else { return nil }
            return AIUsagePricing(
                version: currentVersion,
                inputMicrosPerMillionTokens: 150_000,
                outputMicrosPerMillionTokens: 600_000,
                cacheReadMicrosPerMillionTokens: 75_000,
                inputCountIncludesCachedContent: true
            )
        case .google:
            if normalizedModel.isEmpty || normalizedModel.contains("gemini-2.5-flash") {
                return AIUsagePricing(
                    version: currentVersion,
                    inputMicrosPerMillionTokens: 300_000,
                    outputMicrosPerMillionTokens: 2_500_000,
                    cacheReadMicrosPerMillionTokens: 30_000,
                    inputCountIncludesCachedContent: true
                )
            }
            if normalizedModel.contains("gemini-2.5-pro") {
                let exceedsBaseContextTier = max(0, inputTokens ?? 0) > 200_000
                return AIUsagePricing(
                    version: currentVersion,
                    inputMicrosPerMillionTokens: exceedsBaseContextTier
                        ? 2_500_000
                        : 1_250_000,
                    outputMicrosPerMillionTokens: exceedsBaseContextTier
                        ? 15_000_000
                        : 10_000_000,
                    cacheReadMicrosPerMillionTokens: exceedsBaseContextTier
                        ? 250_000
                        : 125_000,
                    inputCountIncludesCachedContent: true
                )
            }
            if normalizedModel.contains("gemini-3.5-flash") {
                return AIUsagePricing(
                    version: currentVersion,
                    inputMicrosPerMillionTokens: 1_500_000,
                    outputMicrosPerMillionTokens: 9_000_000,
                    cacheReadMicrosPerMillionTokens: 150_000,
                    inputCountIncludesCachedContent: true
                )
            }
            return nil
        case .deepSeek:
            guard normalizedModel.isEmpty
                    || normalizedModel.contains("deepseek-chat") else { return nil }
            return AIUsagePricing(
                version: currentVersion,
                inputMicrosPerMillionTokens: 270_000,
                outputMicrosPerMillionTokens: 1_100_000,
                cacheReadMicrosPerMillionTokens: 70_000,
                inputCountIncludesCachedContent: true
            )
        case .deepgram:
            guard normalizedModel.isEmpty || normalizedModel.contains("nova-2") else {
                return nil
            }
            // Deepgram's public pricing snapshot on 2026-07-21 lists legacy
            // Nova-2 streaming at USD $0.35/audio hour and documents true
            // per-second billing with no 15-second or full-minute minimum.
            // https://deepgram.com/pricing
            // A positive fractional local capture is conservatively rounded to
            // the next one-second billing unit before applying this rate.
            return AIUsagePricing(
                version: currentVersion,
                inputMicrosPerMillionTokens: 0,
                outputMicrosPerMillionTokens: 0,
                audioMicrosPerHour: 350_000,
                minimumBillableAudioSeconds: 1,
                audioBillingIncrementSeconds: 1
            )
        case .unknown, .onDevice:
            return nil
        }
    }
}

struct AIUsageCostRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let correlationID: UUID?
    let surface: AIUsageSurface
    let provider: AIUsageProviderFamily
    let outcome: GrowthEventOutcome
    let currency: GrowthCurrency
    let inputTokens: Int
    let outputTokens: Int
    let cacheWriteTokens: Int
    let cacheReadTokens: Int
    let cachedInputTokens: Int
    let audioSeconds: Int
    let estimatedCostMicros: Int64
    let pricingVersion: Int

    var growthEvent: GrowthEvent {
        var usageMetrics: [GrowthMetric: Int] = [
            .estimatedCostMicros: Int(min(estimatedCostMicros, Int64(Int.max))),
            .pricingVersion: pricingVersion,
        ]
        if inputTokens + outputTokens + cacheWriteTokens + cacheReadTokens + cachedInputTokens > 0 {
            usageMetrics[.inputTokens] = inputTokens
            usageMetrics[.outputTokens] = outputTokens
            usageMetrics[.cacheWriteTokens] = cacheWriteTokens
            usageMetrics[.cacheReadTokens] = cacheReadTokens
            usageMetrics[.cachedInputTokens] = cachedInputTokens
        }
        if audioSeconds > 0 {
            usageMetrics[.audioSeconds] = audioSeconds
        }
        return GrowthEvent(
            id: id,
            createdAt: createdAt,
            correlationID: correlationID ?? id,
            name: .aiUsageEstimated,
            outcome: outcome,
            aiSurface: surface,
            aiProvider: provider,
            metrics: usageMetrics
        )
    }
}

enum AIUsageCostEstimator {
    static let maximumTokensPerField = 100_000_000
    static let maximumAudioSeconds = 86_400

    static func estimate(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        correlationID: UUID? = nil,
        surface: AIUsageSurface,
        provider: AIUsageProviderFamily,
        inputTokens: Int?,
        outputTokens: Int?,
        cacheWriteTokens: Int? = nil,
        cacheReadTokens: Int? = nil,
        cachedInputTokens: Int? = nil,
        audioDurationSeconds: TimeInterval? = nil,
        outcome: GrowthEventOutcome = .recorded,
        pricing: AIUsagePricing
    ) -> AIUsageCostRecord? {
        let input = boundedTokens(inputTokens)
        let output = boundedTokens(outputTokens)
        let cacheWrite = boundedTokens(cacheWriteTokens)
        let cacheRead = boundedTokens(cacheReadTokens)
        let cachedInput = boundedTokens(cachedInputTokens)
        let audioSeconds = billableAudioSeconds(
            duration: audioDurationSeconds,
            pricing: pricing
        )
        guard input + output + cacheWrite + cacheRead + cachedInput > 0
                || audioSeconds > 0 else { return nil }

        let billableInput = pricing.inputCountIncludesCachedContent
            ? max(0, input - cachedInput)
            : input
        let cost = component(tokens: billableInput, rate: pricing.inputMicrosPerMillionTokens)
            + component(tokens: output, rate: pricing.outputMicrosPerMillionTokens)
            + component(tokens: cacheWrite, rate: pricing.cacheWriteMicrosPerMillionTokens)
            + component(tokens: cacheRead + cachedInput, rate: pricing.cacheReadMicrosPerMillionTokens)
            + audioComponent(seconds: audioSeconds, rate: pricing.audioMicrosPerHour)

        return AIUsageCostRecord(
            id: id,
            createdAt: createdAt,
            correlationID: correlationID,
            surface: surface,
            provider: provider,
            outcome: outcome,
            currency: pricing.currency,
            inputTokens: input,
            outputTokens: output,
            cacheWriteTokens: cacheWrite,
            cacheReadTokens: cacheRead,
            cachedInputTokens: cachedInput,
            audioSeconds: audioSeconds,
            estimatedCostMicros: cost,
            pricingVersion: pricing.version
        )
    }

    static func estimate(
        diagnostic: AICallDiagnosticRecord,
        pricing: AIUsagePricing
    ) -> AIUsageCostRecord? {
        estimate(
            id: diagnostic.id,
            createdAt: diagnostic.createdAt,
            correlationID: diagnostic.correlationID,
            surface: AIUsageSurface.classify(diagnostic.surface),
            provider: AIUsageProviderFamily.classify(
                provider: diagnostic.provider,
                model: diagnostic.model
            ),
            inputTokens: diagnostic.inputTokens,
            outputTokens: diagnostic.outputTokens,
            cacheWriteTokens: diagnostic.cacheCreationInputTokens,
            cacheReadTokens: diagnostic.cacheReadInputTokens,
            cachedInputTokens: diagnostic.cachedContentTokenCount,
            audioDurationSeconds: diagnostic.audioDurationSeconds.map(TimeInterval.init),
            outcome: diagnostic.outcome.growthUsageOutcome,
            pricing: pricing
        )
    }

    private static func boundedTokens(_ value: Int?) -> Int {
        min(max(0, value ?? 0), maximumTokensPerField)
    }

    static func billableAudioSeconds(
        duration: TimeInterval?,
        pricing: AIUsagePricing
    ) -> Int {
        guard pricing.audioMicrosPerHour > 0,
              let duration,
              duration.isFinite,
              duration > 0 else { return 0 }
        let wholeSeconds = min(maximumAudioSeconds, max(1, Int(ceil(duration))))
        let increment = max(1, pricing.audioBillingIncrementSeconds)
        let rounded = ((wholeSeconds + increment - 1) / increment) * increment
        return min(
            maximumAudioSeconds,
            max(pricing.minimumBillableAudioSeconds, rounded)
        )
    }

    /// Integer arithmetic keeps estimates stable across devices. Each component
    /// rounds up to one micro-unit so a non-zero priced call cannot disappear.
    private static func component(tokens: Int, rate: Int64) -> Int64 {
        guard tokens > 0, rate > 0 else { return 0 }
        return (Int64(tokens) * rate + 999_999) / 1_000_000
    }

    private static func audioComponent(seconds: Int, rate: Int64) -> Int64 {
        guard seconds > 0, rate > 0 else { return 0 }
        return (Int64(seconds) * rate + 3_599) / 3_600
    }
}

// MARK: - Account-local KPI and cohort reducers

struct GrowthKPIReport: Equatable, Sendable {
    let accountActivatedAt: Date?
    let firstValueDelivered: Bool
    let timeToFirstValueSeconds: TimeInterval?
    let firstWrittenValueDelivered: Bool
    let timeToFirstWrittenValueSeconds: TimeInterval?
    let firstSpokenPracticeStarted: Bool
    let onboardingCompletionRate: Double?
    let practiceCompletionRate: Double?
    let summaryReachRate: Double?
    let secondPracticeReached: Bool
    let secondPracticeWithin48Hours: Bool
    let thirdPracticeReached: Bool
    let weeklyReadViewed: Bool
    let paywallToPurchaseRate: Double?
    let purchaseSuccessRate: Double?
    let becamePaid: Bool
    let timeToPaidSeconds: TimeInterval?
    let activeDayCount: Int
    let retainedDay1: Bool?
    let retainedDay7: Bool?
    let retainedDay28: Bool?
    let aiBudgetReservationCount: Int
    let estimatedAICostMicros: Int64
    let unpricedAIUsageCount: Int

    static func derive(
        events: [GrowthEvent],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> GrowthKPIReport {
        let ordered = events.sorted { $0.createdAt < $1.createdAt }
        let activatedAt = ordered.first(where: { $0.name == .accountActivated })?.createdAt
            ?? ordered.first(where: { $0.name == .appActivated })?.createdAt
        let firstValueAt = activatedAt.flatMap { activatedAt in
            ordered.first(where: {
                $0.name == .firstValueDelivered && $0.createdAt >= activatedAt
            })?.createdAt
        }
        let firstWrittenValueAt = activatedAt.flatMap { activatedAt in
            ordered.first(where: {
                $0.name == .firstWrittenValueDelivered && $0.createdAt >= activatedAt
            })?.createdAt
        }
        let firstSpokenPracticeAt = activatedAt.flatMap { activatedAt in
            ordered.first(where: {
                $0.name == .firstSpokenPracticeStarted && $0.createdAt >= activatedAt
            })?.createdAt
        }
        let paidAt = activatedAt.flatMap { activatedAt in
            ordered.first(where: {
                ($0.name == .entitlementActivated
                    || $0.name == .entitlementRenewed
                    || $0.name == .purchaseSucceeded)
                    && $0.subscriptionState == .paid
                    && $0.createdAt >= activatedAt
            })?.createdAt
        }

        let onboardingStarts = ordered.filter { $0.name == .onboardingStarted }
        let onboardingStartIDs = Set(onboardingStarts.map(\.correlationID))
        let onboardingCompleted = matchedTerminalCount(
            starts: onboardingStarts,
            terminals: ordered.filter { $0.name == .onboardingCompleted }
        )
        let practiceStarts = ordered.filter { $0.name == .practiceStarted }
        let practiceCompletions = ordered.filter { $0.name == .practiceCompleted }
        let completedPracticeIDs = matchedTerminalIDs(
            starts: practiceStarts,
            terminals: practiceCompletions
        )
        let viewedSummaryIDs = Set(ordered.lazy
            .filter { $0.name == .summaryViewed }
            .map(\.correlationID))
            .intersection(completedPracticeIDs)
        let secondPracticeCompletedAt = ordered
            .first(where: { $0.name == .secondPracticeCompleted })?
            .createdAt
        // The launch gate is explicitly cohort-based: an activated account
        // must complete its second rep within 48 hours of activation. Anchoring
        // this to rep one would make a late first rep reset the clock and
        // overstate early retention.
        let secondWithin48Hours = activatedAt.flatMap { activation in
            secondPracticeCompletedAt.map {
                $0 >= activation
                    && $0.timeIntervalSince(activation) <= 48 * 60 * 60
            }
        } ?? false

        let paywalls = ordered.filter { $0.name == .paywallViewed }
        let purchaseStarts = ordered.filter { $0.name == .purchaseStarted }
        let purchaseSuccesses = ordered.filter { $0.name == .purchaseSucceeded }
        let matchedPurchaseIDs = matchedTerminalIDs(
            starts: purchaseStarts,
            terminals: purchaseSuccesses
        )
        let firstPaywallByID = earliestDateByCorrelationID(paywalls)
        let firstPurchaseStartByID = earliestDateByCorrelationID(purchaseStarts)
        let paywallIDs = Set(firstPaywallByID.keys)
        let purchasesAfterPaywall = Set(matchedPurchaseIDs.filter { correlationID in
            guard let paywallAt = firstPaywallByID[correlationID],
                  let purchaseStartedAt = firstPurchaseStartByID[correlationID] else {
                return false
            }
            return purchaseStartedAt >= paywallAt
        })

        let activeDays = Set(ordered.lazy
            .filter { $0.name == .appActivated || $0.name == .accountActivated }
            .map { calendar.startOfDay(for: $0.createdAt) })

        func retention(day: Int) -> Bool? {
            guard let activatedAt,
                  let target = calendar.date(
                    byAdding: .day,
                    value: day,
                    to: calendar.startOfDay(for: activatedAt)
                  ),
                  now >= target else { return nil }
            return activeDays.contains(target)
        }

        let aiCost = ordered.lazy
            .filter { $0.name == .aiUsageEstimated }
            .reduce(Int64(0)) { partial, event in
                let next = Int64(max(0, event.metrics[.estimatedCostMicros] ?? 0))
                return partial > Int64.max - next ? Int64.max : partial + next
            }

        return GrowthKPIReport(
            accountActivatedAt: activatedAt,
            firstValueDelivered: firstValueAt != nil,
            timeToFirstValueSeconds: activatedAt.flatMap { start in
                firstValueAt.map { max(0, $0.timeIntervalSince(start)) }
            },
            firstWrittenValueDelivered: firstWrittenValueAt != nil,
            timeToFirstWrittenValueSeconds: activatedAt.flatMap { start in
                firstWrittenValueAt.map { max(0, $0.timeIntervalSince(start)) }
            },
            firstSpokenPracticeStarted: firstSpokenPracticeAt != nil,
            onboardingCompletionRate: rate(onboardingCompleted, over: onboardingStartIDs.count),
            practiceCompletionRate: rate(completedPracticeIDs.count, over: Set(practiceStarts.map(\.correlationID)).count),
            summaryReachRate: rate(viewedSummaryIDs.count, over: completedPracticeIDs.count),
            secondPracticeReached: ordered.contains { $0.name == .secondPracticeCompleted },
            secondPracticeWithin48Hours: secondWithin48Hours,
            thirdPracticeReached: ordered.contains { $0.name == .thirdPracticeCompleted },
            weeklyReadViewed: ordered.contains { $0.name == .weeklyReadViewed },
            paywallToPurchaseRate: rate(purchasesAfterPaywall.count, over: paywallIDs.count),
            purchaseSuccessRate: rate(matchedPurchaseIDs.count, over: Set(purchaseStarts.map(\.correlationID)).count),
            becamePaid: paidAt != nil,
            timeToPaidSeconds: activatedAt.flatMap { start in
                paidAt.map { max(0, $0.timeIntervalSince(start)) }
            },
            activeDayCount: activeDays.count,
            retainedDay1: retention(day: 1),
            retainedDay7: retention(day: 7),
            retainedDay28: retention(day: 28),
            aiBudgetReservationCount: ordered.filter { $0.name == .aiBudgetReserved }.count,
            estimatedAICostMicros: aiCost,
            unpricedAIUsageCount: ordered.filter { $0.name == .aiUsageUnpriced }.count
        )
    }

    private static func matchedTerminalCount(
        starts: [GrowthEvent],
        terminals: [GrowthEvent]
    ) -> Int {
        matchedTerminalIDs(starts: starts, terminals: terminals).count
    }

    private static func matchedTerminalIDs(
        starts: [GrowthEvent],
        terminals: [GrowthEvent]
    ) -> Set<UUID> {
        let firstStartByID = earliestDateByCorrelationID(starts)
        return Set(terminals.compactMap { terminal in
            guard let startedAt = firstStartByID[terminal.correlationID],
                  terminal.createdAt >= startedAt else { return nil }
            return terminal.correlationID
        })
    }

    private static func earliestDateByCorrelationID(
        _ events: [GrowthEvent]
    ) -> [UUID: Date] {
        Dictionary(grouping: events, by: \.correlationID)
            .compactMapValues { $0.map(\.createdAt).min() }
    }

    private static func rate(_ numerator: Int, over denominator: Int) -> Double? {
        guard denominator > 0 else { return nil }
        return min(1, Double(numerator) / Double(denominator))
    }
}

struct GrowthCohortKPI: Equatable, Sendable {
    let cohortStart: Date
    let accountCount: Int
    let firstValueRate: Double
    let firstWrittenValueRate: Double
    let firstSpokenPracticeStartRate: Double
    let medianTimeToFirstWrittenValueSeconds: TimeInterval?
    let secondPracticeRate: Double
    let secondPracticeWithin48HoursRate: Double
    let thirdPracticeRate: Double
    let weeklyReadRate: Double
    let weeklyReadAmongDay1ReturnersRate: Double?
    let paidConversionRate: Double
    let day1RetentionRate: Double?
    let day7RetentionRate: Double?
    let day28RetentionRate: Double?
    let averageEstimatedAICostMicros: Int64
    let totalUnpricedAIUsageCount: Int
}

enum GrowthCohortReducer {
    /// Each inner event array is one already-isolated account ledger. Account
    /// identifiers are neither required nor returned.
    static func reduce(
        accountEvents: [[GrowthEvent]],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [GrowthCohortKPI] {
        let reports = accountEvents.compactMap { events -> (Date, GrowthKPIReport)? in
            let report = GrowthKPIReport.derive(events: events, now: now, calendar: calendar)
            guard let activatedAt = report.accountActivatedAt,
                  let cohortStart = calendar.dateInterval(of: .weekOfYear, for: activatedAt)?.start else {
                return nil
            }
            return (cohortStart, report)
        }

        return Dictionary(grouping: reports, by: { $0.0 })
            .map { cohortStart, members in
                let memberReports = members.map(\.1)
                let costs = memberReports.reduce(Int64(0)) {
                    let next = $1.estimatedAICostMicros
                    return $0 > Int64.max - next ? Int64.max : $0 + next
                }
                let writtenValueDurations = memberReports
                    .compactMap(\.timeToFirstWrittenValueSeconds)
                    .sorted()
                let day1Returners = memberReports.filter { $0.retainedDay1 == true }
                return GrowthCohortKPI(
                    cohortStart: cohortStart,
                    accountCount: memberReports.count,
                    firstValueRate: fraction(memberReports.filter(\.firstValueDelivered).count, memberReports.count),
                    firstWrittenValueRate: fraction(memberReports.filter(\.firstWrittenValueDelivered).count, memberReports.count),
                    firstSpokenPracticeStartRate: fraction(memberReports.filter(\.firstSpokenPracticeStarted).count, memberReports.count),
                    medianTimeToFirstWrittenValueSeconds: median(writtenValueDurations),
                    secondPracticeRate: fraction(memberReports.filter(\.secondPracticeReached).count, memberReports.count),
                    secondPracticeWithin48HoursRate: fraction(memberReports.filter(\.secondPracticeWithin48Hours).count, memberReports.count),
                    thirdPracticeRate: fraction(memberReports.filter(\.thirdPracticeReached).count, memberReports.count),
                    weeklyReadRate: fraction(memberReports.filter(\.weeklyReadViewed).count, memberReports.count),
                    weeklyReadAmongDay1ReturnersRate: day1Returners.isEmpty
                        ? nil
                        : fraction(day1Returners.filter(\.weeklyReadViewed).count, day1Returners.count),
                    paidConversionRate: fraction(memberReports.filter(\.becamePaid).count, memberReports.count),
                    day1RetentionRate: optionalFraction(memberReports.compactMap(\.retainedDay1)),
                    day7RetentionRate: optionalFraction(memberReports.compactMap(\.retainedDay7)),
                    day28RetentionRate: optionalFraction(memberReports.compactMap(\.retainedDay28)),
                    averageEstimatedAICostMicros: memberReports.isEmpty ? 0 : costs / Int64(memberReports.count),
                    totalUnpricedAIUsageCount: memberReports.reduce(0) {
                        $0 + $1.unpricedAIUsageCount
                    }
                )
            }
            .sorted { $0.cohortStart > $1.cohortStart }
    }

    private static func fraction(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }

    private static func optionalFraction(_ values: [Bool]) -> Double? {
        guard !values.isEmpty else { return nil }
        return fraction(values.filter { $0 }.count, values.count)
    }

    private static func median(_ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        if values.count.isMultiple(of: 2) {
            return (values[middle - 1] + values[middle]) / 2
        }
        return values[middle]
    }
}

// MARK: - Consent-gated first-party aggregate transport

enum GrowthAggregateConsent: Int, Codable, CaseIterable, Sendable {
    case notDetermined = 0
    case denied = 1
    case granted = 2
}

enum GrowthAggregateUploadStatus: Equatable, Sendable {
    case idle
    case uploading
    case uploaded
    case waitingToRetry
}

/// Durable anonymous retry state for one closed aggregate period. Persisting
/// this before transport means an app termination after server acceptance can
/// retry the same batch ID instead of incrementing the period twice.
struct GrowthAggregateUploadCheckpoint: Codable, Equatable, Sendable {
    let periodStart: Date
    let periodEnd: Date
    let batchID: UUID
    let generatedAt: Date

    var period: DateInterval {
        DateInterval(start: periodStart, end: periodEnd)
    }
}

/// Uploadable material is aggregate-only: no event UUIDs, correlation UUIDs,
/// account/device identifiers, exact event timestamps, reasons, or user text.
struct GrowthAggregateBatch: Encodable, Equatable, Sendable {
    static let schemaVersion = 2
    static let maximumEventCount = FlowEventLog.defaultMaxRecords

    /// Anonymous retry key for this aggregate period. This is not an event,
    /// account, installation, or device identifier. It exists only so the
    /// server can make a retried aggregate increment idempotent.
    let batchID: UUID
    let schemaVersion: Int
    let appVersion: String
    let buildNumber: String
    let generatedAt: Date
    let periodStart: Date
    let periodEnd: Date
    /// UTC calendar day of the first account activation. This is a coarse
    /// cohort label, not an account/install/device identifier. It lets the
    /// server combine later event-day aggregates with the correct activation
    /// denominator without transmitting a stable per-user key.
    let activationCohortDay: String
    let eventCounts: [GrowthEventName: Int]
    let paywallSourceCounts: [GrowthEntryPoint: Int]
    let planSelectionCounts: [GrowthSubscriptionPlan: Int]
    let trialEligibilityCounts: [GrowthTrialEligibility: Int]
    let inactiveReasonCounts: [GrowthEntitlementInactiveReason: Int]
    let notificationOpenCounts: [GrowthNotificationKind: Int]
    let activeDayIndexCounts: [Int: Int]
    let firstWrittenValueDurationBucketCounts: [String: Int]
    let secondPracticeWithin48HoursCount: Int
    let weeklyReadAmongDay1ReturnersCount: Int
    let estimatedAICostMicros: Int64
    let estimatedAICostCurrency: GrowthCurrency
    let unpricedAIUsageCount: Int
    let aiBudgetReservationCount: Int

    private init(
        batchID: UUID,
        schemaVersion: Int,
        appVersion: String,
        buildNumber: String,
        generatedAt: Date,
        periodStart: Date,
        periodEnd: Date,
        activationCohortDay: String,
        eventCounts: [GrowthEventName: Int],
        paywallSourceCounts: [GrowthEntryPoint: Int],
        planSelectionCounts: [GrowthSubscriptionPlan: Int],
        trialEligibilityCounts: [GrowthTrialEligibility: Int],
        inactiveReasonCounts: [GrowthEntitlementInactiveReason: Int],
        notificationOpenCounts: [GrowthNotificationKind: Int],
        activeDayIndexCounts: [Int: Int],
        firstWrittenValueDurationBucketCounts: [String: Int],
        secondPracticeWithin48HoursCount: Int,
        weeklyReadAmongDay1ReturnersCount: Int,
        estimatedAICostMicros: Int64,
        estimatedAICostCurrency: GrowthCurrency,
        unpricedAIUsageCount: Int,
        aiBudgetReservationCount: Int
    ) {
        self.batchID = batchID
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.generatedAt = generatedAt
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.activationCohortDay = activationCohortDay
        self.eventCounts = eventCounts
        self.paywallSourceCounts = paywallSourceCounts
        self.planSelectionCounts = planSelectionCounts
        self.trialEligibilityCounts = trialEligibilityCounts
        self.inactiveReasonCounts = inactiveReasonCounts
        self.notificationOpenCounts = notificationOpenCounts
        self.activeDayIndexCounts = activeDayIndexCounts
        self.firstWrittenValueDurationBucketCounts = firstWrittenValueDurationBucketCounts
        self.secondPracticeWithin48HoursCount = secondPracticeWithin48HoursCount
        self.weeklyReadAmongDay1ReturnersCount = weeklyReadAmongDay1ReturnersCount
        self.estimatedAICostMicros = estimatedAICostMicros
        self.estimatedAICostCurrency = estimatedAICostCurrency
        self.unpricedAIUsageCount = unpricedAIUsageCount
        self.aiBudgetReservationCount = aiBudgetReservationCount
    }

    static func make(
        consent: GrowthAggregateConsent,
        events: [GrowthEvent],
        period: DateInterval,
        batchID: UUID = UUID(),
        appVersion: String = "unknown",
        buildNumber: String = "unknown",
        generatedAt: Date = Date()
    ) -> GrowthAggregateBatch? {
        guard consent == .granted, period.duration > 0 else { return nil }
        let included = events.filter {
            $0.createdAt >= period.start && $0.createdAt < period.end
        }
        guard !included.isEmpty else { return nil }

        // Derive from the full bounded account-local ledger, not just the
        // event-day period. Later Day-1/Day-7 and weekly-read batches therefore
        // retain the same coarse cohort label as the activation-day batch.
        let accountActivatedAt = events.lazy
            .filter { $0.name == .accountActivated }
            .map(\.createdAt)
            .min()
        let legacyActivatedAt = events.lazy
            .filter { $0.name == .appActivated }
            .map(\.createdAt)
            .min()
        guard let activatedAt = accountActivatedAt ?? legacyActivatedAt else {
            // An unattributed numerator cannot support the promised cohort
            // rates. Fail closed instead of uploading a misleading event-day
            // bucket; the app records account activation before upload.
            return nil
        }
        let activationCohortDay = cohortDay(activatedAt)

        let counts = Dictionary(grouping: included, by: \.name)
            .mapValues { min(maximumEventCount, $0.count) }
        let paywallSources = boundedCounts(included.lazy
            .filter { $0.name == .paywallViewed && $0.entryPoint != .unknown }
            .map(\.entryPoint))
        let planSelections = boundedCounts(included.lazy
            .filter { $0.name == .productSelected && $0.subscriptionPlan != .unknown }
            .map(\.subscriptionPlan))
        let trialEligibility = boundedCounts(included.lazy
            .filter {
                $0.name == .paywallEligibilityResolved && $0.trialEligibility != .unknown
            }
            .map(\.trialEligibility))
        let inactiveReasons = boundedCounts(included.lazy
            .filter { $0.inactiveReason != .unknown }
            .map(\.inactiveReason))
        let notificationOpens = boundedCounts(included.lazy
            .filter { $0.name == .notificationOpened && $0.notificationKind != .unknown }
            .map(\.notificationKind))
        let activeDayIndexes = boundedIntegerCounts(included.lazy
            .filter { $0.name == .appActivated || $0.name == .accountActivated }
            .compactMap { $0.metrics[.activeDayIndex] })
        let writtenDurationBuckets = boundedStringCounts(included.lazy
            .filter { $0.name == .firstWrittenValueDelivered }
            .compactMap { $0.metrics[.durationMs] }
            .map(durationBucket))
        let accountReport = GrowthKPIReport.derive(
            events: events,
            now: generatedAt,
            calendar: utcCalendar
        )
        let secondWithin48Hours = included.contains { $0.name == .secondPracticeCompleted }
            && accountReport.secondPracticeWithin48Hours ? 1 : 0
        let weeklyReadAmongDay1Returners = included.contains { $0.name == .weeklyReadViewed }
            && accountReport.retainedDay1 == true ? 1 : 0
        let aiCost = included.lazy
            .filter { $0.name == .aiUsageEstimated }
            .reduce(Int64(0)) { partial, event in
                let maximum = Int64(GrowthMetric.estimatedCostMicros.maximum)
                let next = min(
                    maximum,
                    Int64(max(0, event.metrics[.estimatedCostMicros] ?? 0))
                )
                return min(maximum, partial + next)
            }
        let reservations = min(
            maximumEventCount,
            included.filter { $0.name == .aiBudgetReserved }.count
        )
        let unpricedUsage = counts[.aiUsageUnpriced] ?? 0

        return GrowthAggregateBatch(
            batchID: batchID,
            schemaVersion: schemaVersion,
            appVersion: boundedVersion(appVersion),
            buildNumber: boundedVersion(buildNumber),
            generatedAt: generatedAt,
            periodStart: period.start,
            periodEnd: period.end,
            activationCohortDay: activationCohortDay,
            eventCounts: counts,
            paywallSourceCounts: paywallSources,
            planSelectionCounts: planSelections,
            trialEligibilityCounts: trialEligibility,
            inactiveReasonCounts: inactiveReasons,
            notificationOpenCounts: notificationOpens,
            activeDayIndexCounts: activeDayIndexes,
            firstWrittenValueDurationBucketCounts: writtenDurationBuckets,
            secondPracticeWithin48HoursCount: secondWithin48Hours,
            weeklyReadAmongDay1ReturnersCount: weeklyReadAmongDay1Returners,
            estimatedAICostMicros: aiCost,
            estimatedAICostCurrency: .usd,
            unpricedAIUsageCount: unpricedUsage,
            aiBudgetReservationCount: reservations
        )
    }

    private static func boundedCounts<Key: Hashable, Values: Sequence>(
        _ values: Values
    ) -> [Key: Int] where Values.Element == Key {
        Dictionary(grouping: values, by: { $0 })
            .mapValues { min(maximumEventCount, $0.count) }
    }

    private static func boundedIntegerCounts<Values: Sequence>(
        _ values: Values
    ) -> [Int: Int] where Values.Element == Int {
        Dictionary(grouping: values, by: { min(max(0, $0), 28) })
            .mapValues { min(maximumEventCount, $0.count) }
    }

    private static func boundedStringCounts<Values: Sequence>(
        _ values: Values
    ) -> [String: Int] where Values.Element == String {
        Dictionary(grouping: values, by: { $0 })
            .mapValues { min(maximumEventCount, $0.count) }
    }

    private static func durationBucket(_ milliseconds: Int) -> String {
        switch max(0, milliseconds) {
        case ..<30_000: return "under30s"
        case ..<60_000: return "30to59s"
        case ..<120_000: return "60to119s"
        default: return "120sPlus"
        }
    }

    private static func cohortDay(_ date: Date) -> String {
        let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else { return "unknown" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func boundedVersion(_ value: String) -> String {
        let allowed = value.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return allowed.isEmpty ? "unknown" : String(allowed.prefix(32))
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

/// Implemented by first-party infrastructure outside this foundation. There is
/// intentionally no endpoint, SDK, retry queue, device ID, or background task
/// here; the caller owns those release/privacy decisions.
protocol GrowthAggregateTransport: Sendable {
    func upload(_ batch: GrowthAggregateBatch) async throws
}

struct GrowthAggregateUploader: Sendable {
    private let transport: any GrowthAggregateTransport

    init(transport: any GrowthAggregateTransport) {
        self.transport = transport
    }

    /// Returns false without touching transport unless current consent is
    /// explicitly granted and a non-empty aggregate can be formed.
    @discardableResult
    func uploadIfConsented(
        consent: GrowthAggregateConsent,
        events: [GrowthEvent],
        period: DateInterval,
        batchID: UUID = UUID(),
        appVersion: String = "unknown",
        buildNumber: String = "unknown",
        generatedAt: Date = Date()
    ) async throws -> Bool {
        guard let batch = GrowthAggregateBatch.make(
            consent: consent,
            events: events,
            period: period,
            batchID: batchID,
            appVersion: appVersion,
            buildNumber: buildNumber,
            generatedAt: generatedAt
        ) else { return false }
        try await transport.upload(batch)
        return true
    }
}

struct GrowthUnitEconomicsProjection: Equatable, Sendable {
    /// Keeps every basis-point multiplication inside signed 64-bit arithmetic,
    /// while still covering revenue far beyond Noum's practical planning range.
    static let maximumFinancialMicros = Int64.max / 20_000

    let activeAccountCount: Int
    let paidAccountCount: Int
    let revenueCurrency: GrowthCurrency
    let aiCostCurrency: GrowthCurrency
    let aiCostConversionBasisPoints: Int?
    let unpricedAIUsageCount: Int
    let grossRevenueMicros: Int64
    let storeCommissionMicros: Int64
    let netRevenueMicros: Int64
    let estimatedAICostMicros: Int64
    let estimatedAICostInRevenueCurrencyMicros: Int64?
    let otherVariableCostMicros: Int64
    let contributionMicros: Int64?
    let contributionMarginBasisPoints: Int?
    let estimatedAICostPerActiveAccountMicros: Int64?
    let estimatedAICostPerPaidAccountMicros: Int64?

    static func derive(
        activeAccountCount: Int,
        paidAccountCount: Int,
        grossRevenueMicros: Int64,
        storeCommissionBasisPoints: Int,
        revenueCurrency: GrowthCurrency = .usd,
        aiCostToRevenueCurrencyBasisPoints: Int? = nil,
        unpricedAIUsageCount: Int = 0,
        otherVariableCostMicros: Int64 = 0,
        usage: [AIUsageCostRecord]
    ) -> GrowthUnitEconomicsProjection {
        let active = max(0, activeAccountCount)
        let paid = min(max(0, paidAccountCount), active)
        let gross = min(max(0, grossRevenueMicros), maximumFinancialMicros)
        let commissionBps = Int64(min(max(0, storeCommissionBasisPoints), 10_000))
        let commission = (gross * commissionBps) / 10_000
        let net = max(0, gross - commission)
        let aiCost = usage.reduce(Int64(0)) { partial, record in
            let cost = min(max(0, record.estimatedCostMicros), maximumFinancialMicros)
            return min(maximumFinancialMicros, partial + cost)
        }
        let aiCostCurrency = usage.first?.currency ?? .usd
        let containsMixedAICurrencies = usage.contains { $0.currency != aiCostCurrency }
        let suppliedConversion = aiCostToRevenueCurrencyBasisPoints.flatMap { value in
            (1...20_000).contains(value) ? value : nil
        }
        let conversionBasisPoints: Int? = containsMixedAICurrencies
            ? nil
            : revenueCurrency == aiCostCurrency ? 10_000 : suppliedConversion
        let convertedAICost = conversionBasisPoints.map {
            convertedMicros(aiCost, basisPoints: Int64($0))
        }
        let unpriced = max(0, unpricedAIUsageCount)
        let other = min(max(0, otherVariableCostMicros), maximumFinancialMicros)
        let contribution = unpriced == 0 ? convertedAICost.map { convertedCost in
            let totalVariable = min(maximumFinancialMicros, convertedCost + other)
            return net >= totalVariable
                ? net - totalVariable
                : -(totalVariable - net)
        } : nil
        let margin = contribution.flatMap { contribution in
            net > 0
                ? Int(max(-10_000, min(10_000, (contribution * 10_000) / net)))
                : nil
        }

        return GrowthUnitEconomicsProjection(
            activeAccountCount: active,
            paidAccountCount: paid,
            revenueCurrency: revenueCurrency,
            aiCostCurrency: aiCostCurrency,
            aiCostConversionBasisPoints: conversionBasisPoints,
            unpricedAIUsageCount: unpriced,
            grossRevenueMicros: gross,
            storeCommissionMicros: commission,
            netRevenueMicros: net,
            estimatedAICostMicros: aiCost,
            estimatedAICostInRevenueCurrencyMicros: convertedAICost,
            otherVariableCostMicros: other,
            contributionMicros: contribution,
            contributionMarginBasisPoints: margin,
            estimatedAICostPerActiveAccountMicros: active > 0 ? aiCost / Int64(active) : nil,
            estimatedAICostPerPaidAccountMicros: paid > 0 ? aiCost / Int64(paid) : nil
        )
    }

    private static func convertedMicros(
        _ micros: Int64,
        basisPoints: Int64
    ) -> Int64 {
        let whole = (micros / 10_000) * basisPoints
        let remainder = micros % 10_000
        let roundedRemainder = (remainder * basisPoints + 9_999) / 10_000
        return min(maximumFinancialMicros, whole + roundedRemainder)
    }
}
