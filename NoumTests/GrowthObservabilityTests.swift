import Foundation
import Testing
@testable import Noum

@MainActor
@Suite(.serialized)
struct GrowthObservabilityTests {
    @Test("Generic notification attribution is bounded and routable")
    func genericNotificationAttributionContract() throws {
        let route = try #require(URL(string: "noum://train"))
        let attribution = try #require(GrowthNotificationAttribution(
            kind: .practiceReminder,
            route: route
        ))
        let decoded = try #require(GrowthNotificationAttribution.decode(
            attribution.userInfo
        ))

        #expect(decoded == attribution)
        #expect(Set(attribution.userInfo.keys.compactMap { $0 as? String }) == [
            GrowthNotificationAttribution.contractKey,
            GrowthNotificationAttribution.growthKindKey,
            GrowthNotificationAttribution.routeKey,
        ])
        #expect(GrowthNotificationAttribution(
            kind: .unknown,
            route: route
        ) == nil)
        #expect(GrowthNotificationAttribution(
            kind: .weeklyRead,
            route: try #require(URL(string: "https://noum.app"))
        ) == nil)
        #expect(GrowthNotificationAttribution.decode([:]) == nil)
    }

    @Test("Onboarding journey correlation survives draft creation and relaunch")
    func onboardingJourneyCorrelationIsStable() {
        let startedID = UUID()
        let draftID = UUID()
        let fallbackID = UUID()
        let start = GrowthEvent(
            createdAt: Date(timeIntervalSince1970: 10),
            correlationID: startedID,
            name: .onboardingStarted
        )

        #expect(GrowthJourneyCorrelation.onboarding(
            existingEvents: [start],
            draftCorrelationID: draftID,
            fallback: fallbackID
        ) == startedID)
        #expect(GrowthJourneyCorrelation.onboarding(
            existingEvents: [],
            draftCorrelationID: draftID,
            fallback: fallbackID
        ) == draftID)
        #expect(GrowthJourneyCorrelation.onboarding(
            existingEvents: [],
            draftCorrelationID: nil,
            fallback: fallbackID
        ) == fallbackID)
    }

    private let start = Date(timeIntervalSince1970: 1_735_732_800) // 2025-01-01 12:00 UTC

    @Test("Activation day index uses elapsed local calendar days, not open count")
    func activationDayIndexPreservesCalendarGaps() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let activatedAt = try #require(calendar.date(
            from: DateComponents(year: 2025, month: 3, day: 8, hour: 23, minute: 50)
        ))
        let sevenDaysLater = try #require(calendar.date(
            from: DateComponents(year: 2025, month: 3, day: 15, hour: 8)
        ))

        #expect(GrowthActivationDayIndex.elapsed(
            from: activatedAt,
            to: activatedAt,
            calendar: calendar
        ) == 0)
        // Crosses the spring DST boundary and six unopened days.
        #expect(GrowthActivationDayIndex.elapsed(
            from: activatedAt,
            to: sevenDaysLater,
            calendar: calendar
        ) == 7)
        #expect(GrowthActivationDayIndex.elapsed(
            from: activatedAt,
            to: activatedAt.addingTimeInterval(-86_400),
            calendar: calendar
        ) == 0)
    }

    @Test func lifecycleVocabularyFitsTheExistingFlowBounds() {
        for name in GrowthEventName.allCases {
            let event = GrowthEvent(createdAt: start, name: name)
            #expect(event.flowEvent.stage == name.rawValue)
            #expect(event.flowEvent.reason == name.canonicalReason)
            #expect(GrowthPrivacyGuard.sanitize(event.flowEvent) != nil)
        }
    }

    @Test("Written value and first spoken rep remain distinct funnel events")
    func firstValueModalitiesAreExplicit() {
        let journeyID = UUID()
        let repID = UUID()
        let written = GrowthEvent(
            createdAt: start,
            correlationID: journeyID,
            name: .firstWrittenValueDelivered,
            entryPoint: .onboarding,
            metrics: [.durationMs: 12_000]
        )
        let spoken = GrowthEvent(
            createdAt: start.addingTimeInterval(5),
            correlationID: repID,
            name: .firstSpokenPracticeStarted,
            entryPoint: .train
        )

        #expect(written.name != spoken.name)
        #expect(written.correlationID == journeyID)
        #expect(written.metrics[.durationMs] == 12_000)
        #expect(spoken.correlationID == repID)
        #expect(spoken.metrics.isEmpty)
        #expect(!GrowthPrivacyGuard.containsCommunicationContent(written))
        #expect(!GrowthPrivacyGuard.containsCommunicationContent(spoken))
    }

    @Test func typedEventsKeepOnlyAllowedBoundedNumerics() {
        let event = GrowthEvent(
            createdAt: start,
            name: .aiBudgetReserved,
            subscriptionState: .paid,
            aiSurface: .postRepCoachNote,
            metrics: [
                .dailyUsageCount: -4,
                .dailyUsageCap: 2_000_000,
                .inputTokens: 900,
            ]
        )

        #expect(event.metrics[.dailyUsageCount] == 0)
        #expect(event.metrics[.dailyUsageCap] == 1_000_000)
        #expect(event.metrics[.inputTokens] == nil)
        #expect(!GrowthPrivacyGuard.containsCommunicationContent(event))

        let fullUsageEvent = GrowthEvent(
            createdAt: start,
            name: .aiUsageEstimated,
            subscriptionState: .paid,
            entryPoint: .coach,
            aiSurface: .askNoum,
            aiProvider: .anthropic,
            metrics: [
                .inputTokens: 1,
                .outputTokens: 2,
                .cacheReadTokens: 3,
                .cacheWriteTokens: 4,
                .cachedInputTokens: 5,
                .estimatedCostMicros: 6,
                .pricingVersion: 7,
                .latencyMs: 8,
            ]
        )
        #expect(fullUsageEvent.subscriptionState == .unknown)
        #expect(fullUsageEvent.entryPoint == .unknown)
        #expect(fullUsageEvent.flowEvent.numerics.count == 12)
    }

    @Test func rawFlowImportRedactsReasonUnknownKeysAndOutOfRangeValues() throws {
        let privateText = "The user said a private sentence that must not survive."
        let raw = FlowEvent.make(
            createdAt: start,
            correlationId: UUID(),
            flow: .other,
            stage: GrowthEventName.practiceCompleted.rawValue,
            reason: privateText,
            numerics: [
                "durationMs": -200,
                "privateScore": 91,
                "growthSchema": GrowthEvent.schemaVersion,
                "growthOutcome": 99,
            ]
        )

        let validation = try #require(GrowthPrivacyGuard.sanitize(raw))
        #expect(validation.wasRedacted)
        #expect(validation.redactions.contains(.reason))
        #expect(validation.redactions.contains(.unknownNumeric))
        #expect(validation.redactions.contains(.outOfRangeNumeric))
        #expect(validation.redactions.contains(.invalidDimension))
        #expect(validation.event.metrics[.durationMs] == 0)
        #expect(validation.event.flowEvent.reason == GrowthEventName.practiceCompleted.canonicalReason)
        #expect(!validation.event.flowEvent.reason.contains(privateText))
        #expect(GrowthPrivacyGuard.sanitize(FlowEvent.make(
            correlationId: UUID(),
            flow: .other,
            stage: "private.arbitrary.event",
            reason: privateText
        )) == nil)
    }

    @Test func commercialDimensionsStayBoundedAndNeverPersistProductIdentifiers() throws {
        let selected = GrowthEvent(
            createdAt: start,
            name: .productSelected,
            subscriptionState: .free,
            subscriptionPlan: .annual,
            entryPoint: .postPractice,
            aiProvider: .openAI
        )
        let eligibility = GrowthEvent(
            createdAt: start,
            name: .paywallEligibilityResolved,
            subscriptionPlan: .annual,
            trialEligibility: .eligible
        )
        let inactive = GrowthEvent(
            createdAt: start,
            name: .entitlementBecameInactive,
            subscriptionState: .lapsed,
            subscriptionPlan: .monthly,
            inactiveReason: .billingRetry
        )

        #expect(selected.subscriptionPlan == .annual)
        #expect(selected.aiProvider == nil)
        #expect(eligibility.trialEligibility == .eligible)
        #expect(inactive.inactiveReason == .billingRetry)
        let roundTrip = try #require(GrowthPrivacyGuard.sanitize(inactive.flowEvent)?.event)
        #expect(roundTrip.subscriptionPlan == .monthly)
        #expect(roundTrip.inactiveReason == .billingRetry)

        let encoded = try #require(String(
            data: JSONEncoder().encode([selected, eligibility, inactive]),
            encoding: .utf8
        ))
        #expect(!encoded.contains(PremiumManager.monthlyID))
        #expect(!encoded.contains(PremiumManager.annualID))
    }

    @Test func flowBackedSinkUsesTheExistingLedgerAndRoundTripsTypedEvents() throws {
        let suiteName = "growth.observability.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let log = FlowEventLog(defaults: defaults, storageKey: "growth.events")
        let sink = FlowEventGrowthEventSink(flowEventLog: log)
        let journeyID = UUID()

        #expect(sink.record(GrowthEvent(
            createdAt: start,
            correlationID: journeyID,
            name: .paywallViewed,
            subscriptionState: .free,
            entryPoint: .postPractice
        )))

        let stored = try #require(log.growthEvents().first)
        #expect(stored.name == .paywallViewed)
        #expect(stored.correlationID == journeyID)
        #expect(stored.subscriptionState == .free)
        #expect(stored.entryPoint == .postPractice)
        #expect(log.events.count == 1)

        log.reset()
        #expect(log.events.isEmpty)
        #expect(FlowEventLog(
            defaults: defaults,
            storageKey: "growth.events"
        ).events.isEmpty)
    }

    @Test func foundationalGrowthAnchorsSurviveBoundedFlowTrimming() {
        let defaults = isolatedDefaults()
        let log = FlowEventLog(defaults: defaults, storageKey: "growth.trim", maxRecords: 9)
        let sink = FlowEventGrowthEventSink(flowEventLog: log)

        sink.record(GrowthEvent(createdAt: start, name: .accountActivated))
        sink.record(GrowthEvent(createdAt: start.addingTimeInterval(2), name: .firstValueDelivered))
        sink.record(GrowthEvent(createdAt: start.addingTimeInterval(3), name: .firstWrittenValueDelivered))
        sink.record(GrowthEvent(createdAt: start.addingTimeInterval(4), name: .firstSpokenPracticeStarted))
        sink.record(GrowthEvent(createdAt: start.addingTimeInterval(5), name: .practiceCompleted))
        sink.record(GrowthEvent(createdAt: start.addingTimeInterval(6), name: .summaryViewed))
        sink.record(GrowthEvent(createdAt: start.addingTimeInterval(7), name: .secondPracticeCompleted))
        sink.record(GrowthEvent(createdAt: start.addingTimeInterval(8), name: .thirdPracticeCompleted))
        sink.record(GrowthEvent(createdAt: start.addingTimeInterval(9), name: .entitlementActivated))
        for index in 10...30 {
            log.log(FlowEvent.make(
                createdAt: start.addingTimeInterval(Double(index)),
                correlationId: UUID(),
                flow: .other,
                stage: "noise.\(index)"
            ))
        }

        let names = Set(log.growthEvents().map(\.name))
        #expect(log.events.count == 9)
        #expect(names == [
            .accountActivated,
            .firstValueDelivered,
            .firstWrittenValueDelivered,
            .firstSpokenPracticeStarted,
            .practiceCompleted,
            .summaryViewed,
            .secondPracticeCompleted,
            .thirdPracticeCompleted,
            .entitlementActivated,
        ])
    }

    @Test func deterministicCostEstimatorPricesEveryTokenClass() throws {
        let pricing = AIUsagePricing(
            version: 7,
            inputMicrosPerMillionTokens: 3_000_000,
            outputMicrosPerMillionTokens: 15_000_000,
            cacheWriteMicrosPerMillionTokens: 3_750_000,
            cacheReadMicrosPerMillionTokens: 300_000
        )
        let record = try #require(AIUsageCostEstimator.estimate(
            createdAt: start,
            surface: .askNoum,
            provider: .anthropic,
            inputTokens: 1_000,
            outputTokens: 200,
            cacheWriteTokens: 400,
            cacheReadTokens: 500,
            pricing: pricing
        ))

        #expect(record.estimatedCostMicros == 7_650)
        #expect(record.pricingVersion == 7)
        #expect(record.growthEvent.metrics[.estimatedCostMicros] == 7_650)
        #expect(AIUsageCostEstimator.estimate(
            surface: .unknown,
            provider: .unknown,
            inputTokens: nil,
            outputTokens: nil,
            pricing: pricing
        ) == nil)
    }

    @Test func cachedContentIsNotDoublePricedWhenInputIncludesIt() throws {
        let pricing = AIUsagePricing(
            version: 1,
            inputMicrosPerMillionTokens: 1_000_000,
            outputMicrosPerMillionTokens: 0,
            cacheReadMicrosPerMillionTokens: 250_000,
            inputCountIncludesCachedContent: true
        )
        let record = try #require(AIUsageCostEstimator.estimate(
            surface: .sessionDebrief,
            provider: .google,
            inputTokens: 1_000,
            outputTokens: 0,
            cachedInputTokens: 400,
            pricing: pricing
        ))

        #expect(record.estimatedCostMicros == 700)
    }

    @Test func diagnosticProjectionDropsRawProviderModelAndSurfaceStrings() throws {
        let diagnostic = AICallDiagnosticRecord.make(
            createdAt: start,
            surface: "Ask Noum chat",
            provider: "Anthropic secure callable",
            model: "claude-private-routing-label",
            outcome: .success,
            reason: "input=800 output=120",
            inputTokens: 800,
            outputTokens: 120
        )
        let pricing = AIUsagePricing(
            version: 2,
            inputMicrosPerMillionTokens: 1_000_000,
            outputMicrosPerMillionTokens: 2_000_000
        )
        let record = try #require(AIUsageCostEstimator.estimate(
            diagnostic: diagnostic,
            pricing: pricing
        ))

        #expect(record.surface == .askNoum)
        #expect(record.provider == .anthropic)
        let encoded = try #require(String(data: JSONEncoder().encode(record), encoding: .utf8))
        #expect(!encoded.contains("claude-private-routing-label"))
        #expect(!encoded.contains("Anthropic secure callable"))
        #expect(!encoded.contains(diagnostic.reason))
    }

    @Test func productionPricingClassifiesProviderSurfaceAndEveryTokenClass() throws {
        let diagnostic = AICallDiagnosticRecord.make(
            createdAt: start,
            surface: "Ask Noum chat",
            provider: "Anthropic secure callable",
            model: "claude-sonnet-4-6",
            outcome: .success,
            reason: "private diagnostic detail",
            cacheCreationInputTokens: 200,
            cacheReadInputTokens: 300,
            inputTokens: 1_000,
            outputTokens: 100
        )
        let pricing = try #require(AIUsagePricingCatalog.pricing(for: diagnostic))
        let usage = try #require(AIUsageCostEstimator.estimate(
            diagnostic: diagnostic,
            pricing: pricing
        ))

        #expect(usage.provider == .anthropic)
        #expect(usage.surface == .askNoum)
        #expect(usage.estimatedCostMicros == 5_340)
        #expect(usage.pricingVersion == AIUsagePricingCatalog.currentVersion)
        #expect(AIUsagePricingCatalog.pricing(
            provider: .anthropic,
            model: "unknown-model-override"
        ) == nil)
    }

    @Test func deepgramTranscriptionUsesResolvedProviderSecondsAndUSDPrice() throws {
        let correlationID = UUID()
        let diagnostic = AICallDiagnostics.makeTranscriptionRecord(
            id: UUID(),
            correlationID: correlationID,
            requestedCloud: true,
            resolvedProviderIdentifier: TranscriptionProviderID.deepgram.rawValue,
            captureDurationSeconds: 30.2,
            now: start
        )
        let pricing = try #require(AIUsagePricingCatalog.pricing(for: diagnostic))
        let usage = try #require(AIUsageCostEstimator.estimate(
            diagnostic: diagnostic,
            pricing: pricing
        ))

        #expect(AIUsageSurface.classify(diagnostic.surface) == .transcription)
        #expect(AIUsageProviderFamily.classify(
            provider: diagnostic.provider,
            model: diagnostic.model
        ) == .deepgram)
        #expect(usage.correlationID == correlationID)
        #expect(usage.provider == .deepgram)
        #expect(usage.surface == .transcription)
        #expect(usage.outcome == .succeeded)
        #expect(usage.currency == .usd)
        #expect(usage.audioSeconds == 31)
        #expect(usage.estimatedCostMicros == 3_014)
        #expect(usage.pricingVersion == AIUsagePricingCatalog.currentVersion)
        #expect(usage.growthEvent.metrics[.audioSeconds] == 31)
        #expect(usage.growthEvent.metrics[.estimatedCostMicros] == 3_014)
        #expect(AIUsageCostEstimator.billableAudioSeconds(
            duration: 0.01,
            pricing: pricing
        ) == 1)
        #expect(AIUsageCostEstimator.billableAudioSeconds(
            duration: 14,
            pricing: pricing
        ) == 14)

        let encoded = try #require(String(
            data: JSONEncoder().encode(usage.growthEvent),
            encoding: .utf8
        ))
        #expect(!encoded.contains("The private words spoken during the rep"))
        #expect(!GrowthPrivacyGuard.containsCommunicationContent(usage.growthEvent))
    }

    @Test func onDeviceFallbackKeepsDiagnosticOutcomeWithoutPaidUsage() throws {
        let suiteName = "growth.transcription-local.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let diagnostics = AICallDiagnosticsStore(
            defaults: defaults,
            storageKey: "diagnostics"
        )
        let log = FlowEventLog(defaults: defaults, storageKey: "growth")
        let diagnostic = AICallDiagnostics.makeTranscriptionRecord(
            correlationID: UUID(),
            requestedCloud: true,
            resolvedProviderIdentifier: TranscriptionProviderID.local.rawValue,
            captureDurationSeconds: 12.4,
            now: start
        )

        #expect(diagnostic.outcome == .fallback)
        #expect(!AICallDiagnostics.commit(
            diagnostic,
            diagnosticsStore: diagnostics,
            growthEventSink: FlowEventGrowthEventSink(flowEventLog: log)
        ))
        #expect(diagnostics.records == [diagnostic])
        #expect(log.growthEvents().isEmpty)
    }

    @Test func unknownCloudTranscriptionMarksMarginEvidenceUnpriced() throws {
        let suiteName = "growth.transcription-unknown.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let diagnostics = AICallDiagnosticsStore(
            defaults: defaults,
            storageKey: "diagnostics"
        )
        let log = FlowEventLog(defaults: defaults, storageKey: "growth")
        let diagnostic = AICallDiagnostics.makeTranscriptionRecord(
            correlationID: UUID(),
            requestedCloud: true,
            resolvedProviderIdentifier: "future-cloud-provider",
            captureDurationSeconds: 8,
            now: start
        )

        #expect(AICallDiagnostics.commit(
            diagnostic,
            diagnosticsStore: diagnostics,
            growthEventSink: FlowEventGrowthEventSink(flowEventLog: log)
        ))
        let event = try #require(log.growthEvents().first)
        #expect(event.name == .aiUsageUnpriced)
        #expect(event.outcome == .succeeded)
        #expect(event.aiSurface == .transcription)
        #expect(event.aiProvider == .unknown)
        #expect(event.metrics[.audioSeconds] == 8)
        #expect(event.metrics[.estimatedCostMicros] == nil)
        #expect(GrowthKPIReport.derive(events: [event]).unpricedAIUsageCount == 1)
    }

    @Test func providerFallbackAttemptsEachEmitOneBoundedUsageEvent() throws {
        let suiteName = "growth.ai-usage.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let diagnostics = AICallDiagnosticsStore(
            defaults: defaults,
            storageKey: "diagnostics"
        )
        let log = FlowEventLog(defaults: defaults, storageKey: "growth")
        let sink = FlowEventGrowthEventSink(flowEventLog: log)
        let correlationID = UUID()
        let privateReason = "The user said something that must never enter growth events."
        let anthropicAttempt = AICallDiagnosticRecord.make(
            id: UUID(),
            createdAt: start,
            surface: "Ask Noum chat",
            provider: "Anthropic secure callable",
            model: "claude-sonnet-4-6",
            outcome: .fallback,
            reason: privateReason,
            correlationID: correlationID,
            inputTokens: 1_000,
            outputTokens: 100
        )
        let googleAttempt = AICallDiagnosticRecord.make(
            id: UUID(),
            createdAt: start.addingTimeInterval(1),
            surface: "Ask Noum chat",
            provider: "Google Agent Platform",
            model: "gemini-3.5-flash",
            outcome: .success,
            reason: privateReason,
            correlationID: correlationID,
            inputTokens: 1_000,
            outputTokens: 100
        )

        #expect(AICallDiagnostics.commit(
            anthropicAttempt,
            diagnosticsStore: diagnostics,
            growthEventSink: sink
        ))
        #expect(AICallDiagnostics.commit(
            googleAttempt,
            diagnosticsStore: diagnostics,
            growthEventSink: sink
        ))
        // Re-delivery of one diagnostic is idempotent by diagnostic UUID, but
        // a fallback and its successful provider attempt both remain billable.
        #expect(AICallDiagnostics.commit(
            anthropicAttempt,
            diagnosticsStore: diagnostics,
            growthEventSink: sink
        ))

        let events = log.growthEvents().filter { $0.name == .aiUsageEstimated }
        #expect(events.count == 2)
        #expect(Set(events.compactMap(\.aiProvider)) == [.anthropic, .google])
        #expect(events.allSatisfy { $0.aiSurface == .askNoum })
        #expect(events.first(where: { $0.aiProvider == .anthropic })?
            .metrics[.estimatedCostMicros] == 4_500)
        #expect(events.first(where: { $0.aiProvider == .anthropic })?.outcome == .fallback)
        #expect(events.first(where: { $0.aiProvider == .google })?
            .metrics[.estimatedCostMicros] == 2_400)
        #expect(diagnostics.records.count == 3)

        let encoded = try #require(String(
            data: JSONEncoder().encode(log.events),
            encoding: .utf8
        ))
        #expect(!encoded.contains(privateReason))
        #expect(!encoded.contains("claude-sonnet-4-6"))
        #expect(!encoded.contains("Google Agent Platform"))
    }

    @Test func tokenlessProviderFallbackMarksUnitEconomicsUnpriced() throws {
        let suiteName = "growth.ai-tokenless.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let diagnostics = AICallDiagnosticsStore(
            defaults: defaults,
            storageKey: "diagnostics"
        )
        let log = FlowEventLog(defaults: defaults, storageKey: "growth")
        let sink = FlowEventGrowthEventSink(flowEventLog: log)
        let diagnostic = AICallDiagnosticRecord.make(
            surface: "Ask Noum chat",
            provider: "Anthropic secure callable",
            model: "claude-sonnet-4-6",
            outcome: .fallback,
            reason: "transport failed before usage existed"
        )

        #expect(AICallDiagnostics.commit(
            diagnostic,
            diagnosticsStore: diagnostics,
            growthEventSink: sink
        ))
        #expect(diagnostics.records == [diagnostic])
        let event = try #require(log.growthEvents().first)
        #expect(event.name == .aiUsageUnpriced)
        #expect(event.outcome == .fallback)
        #expect(event.aiSurface == .askNoum)
        #expect(event.aiProvider == .anthropic)
        #expect(event.metrics[.pricingVersion] == AIUsagePricingCatalog.currentVersion)
        #expect(event.metrics[.estimatedCostMicros] == nil)
    }

    @Test func kpiReducerRequiresPairedOrderedFunnelEvents() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let onboardingID = UUID()
        let practiceID = UUID()
        let orphanPracticeID = UUID()
        let purchaseID = UUID()
        let outOfOrderPurchaseID = UUID()
        let cost = try #require(AIUsageCostEstimator.estimate(
            createdAt: start.addingTimeInterval(50),
            surface: .askNoum,
            provider: .anthropic,
            inputTokens: 1_000,
            outputTokens: 0,
            pricing: AIUsagePricing(
                version: 1,
                inputMicrosPerMillionTokens: 1_000_000,
                outputMicrosPerMillionTokens: 0
            )
        ))
        let events = [
            growth(.firstValueDelivered, at: -2),
            growth(.purchaseSucceeded, at: -1),
            growth(.accountActivated, at: 0),
            growth(.onboardingStarted, at: 1, correlationID: onboardingID),
            growth(.onboardingCompleted, at: 10, correlationID: onboardingID),
            growth(.firstValueDelivered, at: 20),
            growth(.firstWrittenValueDelivered, at: 20, metrics: [.durationMs: 20_000]),
            growth(.firstSpokenPracticeStarted, at: 24),
            growth(.practiceStarted, at: 25, correlationID: practiceID),
            growth(.practiceCompleted, at: 40, correlationID: practiceID),
            growth(.practiceCompleted, at: 35, correlationID: orphanPracticeID),
            growth(.secondPracticeCompleted, at: 41),
            growth(.thirdPracticeCompleted, at: 42),
            growth(.weeklyReadViewed, at: 43),
            growth(.summaryViewed, at: 45, correlationID: practiceID),
            growth(.paywallViewed, at: 46, correlationID: purchaseID),
            growth(.purchaseStarted, at: 47, correlationID: purchaseID),
            growth(
                .purchaseSucceeded,
                at: 48,
                correlationID: purchaseID,
                subscriptionState: .paid
            ),
            growth(.purchaseStarted, at: 49, correlationID: outOfOrderPurchaseID),
            growth(.paywallViewed, at: 51, correlationID: outOfOrderPurchaseID),
            growth(.purchaseSucceeded, at: 52, correlationID: outOfOrderPurchaseID),
            growth(.appActivated, at: 86_400),
            cost.growthEvent,
        ]

        let report = GrowthKPIReport.derive(
            events: events,
            now: start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(report.firstValueDelivered)
        #expect(report.timeToFirstValueSeconds == 20)
        #expect(report.firstWrittenValueDelivered)
        #expect(report.timeToFirstWrittenValueSeconds == 20)
        #expect(report.firstSpokenPracticeStarted)
        #expect(report.onboardingCompletionRate == 1)
        #expect(report.practiceCompletionRate == 1)
        #expect(report.summaryReachRate == 1)
        #expect(report.secondPracticeReached)
        #expect(report.secondPracticeWithin48Hours)
        #expect(report.thirdPracticeReached)
        #expect(report.weeklyReadViewed)
        #expect(report.paywallToPurchaseRate == 0.5)
        #expect(report.purchaseSuccessRate == 1)
        #expect(report.becamePaid)
        #expect(report.timeToPaidSeconds == 48)
        #expect(report.retainedDay1 == true)
        #expect(report.retainedDay7 == false)
        #expect(report.retainedDay28 == nil)
        #expect(report.estimatedAICostMicros == 1_000)
        #expect(report.unpricedAIUsageCount == 0)
    }

    @Test func cohortReducerAggregatesAccountsWithoutIdentifiers() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let accountA = [
            growth(.accountActivated, at: 0),
            growth(.firstValueDelivered, at: 20),
            growth(.secondPracticeCompleted, at: 21),
            growth(.thirdPracticeCompleted, at: 22),
            growth(.weeklyReadViewed, at: 23),
            growth(.entitlementActivated, at: 30, subscriptionState: .paid),
            growth(.appActivated, at: 86_400),
        ]
        let accountB = [
            growth(.accountActivated, at: 3_600),
        ]

        let cohorts = GrowthCohortReducer.reduce(
            accountEvents: [accountA, accountB],
            now: start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(cohorts.count == 1)
        #expect(cohorts[0].accountCount == 2)
        #expect(cohorts[0].firstValueRate == 0.5)
        #expect(cohorts[0].secondPracticeRate == 0.5)
        #expect(cohorts[0].thirdPracticeRate == 0.5)
        #expect(cohorts[0].weeklyReadRate == 0.5)
        #expect(cohorts[0].paidConversionRate == 0.5)
        #expect(cohorts[0].day1RetentionRate == 0.5)
        #expect(cohorts[0].day7RetentionRate == 0)
        #expect(cohorts[0].day28RetentionRate == nil)
    }

    @Test func secondRepWithin48HoursIsAnchoredToActivationNotFirstRep() {
        let firstRepID = UUID()
        let lateSecondRep = GrowthKPIReport.derive(
            events: [
                growth(.accountActivated, at: 0),
                growth(.practiceStarted, at: 47 * 60 * 60, correlationID: firstRepID),
                growth(.practiceCompleted, at: 47 * 60 * 60 + 30, correlationID: firstRepID),
                growth(.secondPracticeCompleted, at: 49 * 60 * 60),
            ],
            now: start.addingTimeInterval(50 * 60 * 60)
        )
        #expect(lateSecondRep.secondPracticeReached)
        #expect(!lateSecondRep.secondPracticeWithin48Hours)

        let onTimeSecondRep = GrowthKPIReport.derive(
            events: [
                growth(.accountActivated, at: 0),
                growth(.secondPracticeCompleted, at: 48 * 60 * 60),
            ],
            now: start.addingTimeInterval(49 * 60 * 60)
        )
        #expect(onTimeSecondRep.secondPracticeWithin48Hours)
    }

    @Test func trialCheckoutDoesNotCountAsPaidConversion() {
        let account = [
            growth(.accountActivated, at: 0),
            growth(.purchaseSucceeded, at: 20, subscriptionState: .trial),
            growth(.trialStarted, at: 21, subscriptionState: .trial),
        ]
        let trial = GrowthKPIReport.derive(
            events: account,
            now: start.addingTimeInterval(30)
        )
        #expect(!trial.becamePaid)
        #expect(trial.timeToPaidSeconds == nil)

        let converted = GrowthKPIReport.derive(
            events: account + [
                growth(.entitlementRenewed, at: 8 * 86_400, subscriptionState: .paid),
            ],
            now: start.addingTimeInterval(9 * 86_400)
        )
        #expect(converted.becamePaid)
        #expect(abs((converted.timeToPaidSeconds ?? 0) - (8 * 86_400)) < 0.001)
    }

    @Test func unitEconomicsProjectionSeparatesRevenueFeesAndVariableCost() throws {
        let pricing = AIUsagePricing(
            version: 1,
            inputMicrosPerMillionTokens: 100_000,
            outputMicrosPerMillionTokens: 0
        )
        let first = try #require(AIUsageCostEstimator.estimate(
            surface: .askNoum,
            provider: .anthropic,
            inputTokens: 1_000,
            outputTokens: 0,
            pricing: pricing
        ))
        let second = try #require(AIUsageCostEstimator.estimate(
            surface: .sessionDebrief,
            provider: .google,
            inputTokens: 2_000,
            outputTokens: 0,
            pricing: pricing
        ))

        let projection = GrowthUnitEconomicsProjection.derive(
            activeAccountCount: 10,
            paidAccountCount: 2,
            grossRevenueMicros: 10_000_000,
            storeCommissionBasisPoints: 1_500,
            otherVariableCostMicros: 200_000,
            usage: [first, second]
        )

        #expect(projection.storeCommissionMicros == 1_500_000)
        #expect(projection.netRevenueMicros == 8_500_000)
        #expect(projection.revenueCurrency == .usd)
        #expect(projection.aiCostCurrency == .usd)
        #expect(projection.aiCostConversionBasisPoints == 10_000)
        #expect(projection.estimatedAICostMicros == 300)
        #expect(projection.estimatedAICostInRevenueCurrencyMicros == 300)
        #expect(projection.contributionMicros == 8_299_700)
        #expect(projection.contributionMarginBasisPoints == 9_764)
        #expect(projection.estimatedAICostPerActiveAccountMicros == 30)
        #expect(projection.estimatedAICostPerPaidAccountMicros == 150)

        let extreme = GrowthUnitEconomicsProjection.derive(
            activeAccountCount: 0,
            paidAccountCount: Int.max,
            grossRevenueMicros: Int64.max,
            storeCommissionBasisPoints: Int.max,
            otherVariableCostMicros: Int64.max,
            usage: []
        )
        #expect(extreme.grossRevenueMicros == GrowthUnitEconomicsProjection.maximumFinancialMicros)
        #expect(extreme.paidAccountCount == 0)
        #expect(extreme.netRevenueMicros == 0)
        #expect(extreme.contributionMicros == -GrowthUnitEconomicsProjection.maximumFinancialMicros)
    }

    @Test func unitEconomicsRequiresExplicitCurrencyConversionBeforeClaimingMargin() throws {
        let pricing = AIUsagePricing(
            version: 1,
            inputMicrosPerMillionTokens: 1_000_000,
            outputMicrosPerMillionTokens: 0
        )
        let usage = try #require(AIUsageCostEstimator.estimate(
            surface: .askNoum,
            provider: .anthropic,
            inputTokens: 10_000,
            outputTokens: 0,
            pricing: pricing
        ))

        let unconverted = GrowthUnitEconomicsProjection.derive(
            activeAccountCount: 1,
            paidAccountCount: 1,
            grossRevenueMicros: 10_000_000,
            storeCommissionBasisPoints: 1_500,
            revenueCurrency: .gbp,
            usage: [usage]
        )
        #expect(unconverted.aiCostCurrency == .usd)
        #expect(unconverted.aiCostConversionBasisPoints == nil)
        #expect(unconverted.estimatedAICostInRevenueCurrencyMicros == nil)
        #expect(unconverted.contributionMicros == nil)
        #expect(unconverted.contributionMarginBasisPoints == nil)

        let converted = GrowthUnitEconomicsProjection.derive(
            activeAccountCount: 1,
            paidAccountCount: 1,
            grossRevenueMicros: 10_000_000,
            storeCommissionBasisPoints: 1_500,
            revenueCurrency: .gbp,
            aiCostToRevenueCurrencyBasisPoints: 8_000,
            usage: [usage]
        )
        #expect(converted.aiCostConversionBasisPoints == 8_000)
        #expect(converted.estimatedAICostMicros == 10_000)
        #expect(converted.estimatedAICostInRevenueCurrencyMicros == 8_000)
        #expect(converted.contributionMicros == 8_492_000)

        let incomplete = GrowthUnitEconomicsProjection.derive(
            activeAccountCount: 1,
            paidAccountCount: 1,
            grossRevenueMicros: 10_000_000,
            storeCommissionBasisPoints: 1_500,
            revenueCurrency: .gbp,
            aiCostToRevenueCurrencyBasisPoints: 8_000,
            unpricedAIUsageCount: 1,
            usage: [usage]
        )
        #expect(incomplete.unpricedAIUsageCount == 1)
        #expect(incomplete.contributionMicros == nil)
        #expect(incomplete.contributionMarginBasisPoints == nil)
    }

    @Test func aggregateUploaderRequiresConsentAndContainsNoEventIdentifiers() async throws {
        let transport = GrowthAggregateTransportSpy()
        let uploader = GrowthAggregateUploader(transport: transport)
        let eventID = UUID()
        let correlationID = UUID()
        let events = [
            GrowthEvent(
                createdAt: start.addingTimeInterval(-3 * 86_400),
                name: .accountActivated,
                metrics: [.activeDayIndex: 0]
            ),
            GrowthEvent(
                id: eventID,
                createdAt: start,
                correlationID: correlationID,
                name: .productSelected,
                subscriptionPlan: .annual
            ),
            GrowthEvent(
                createdAt: start.addingTimeInterval(1),
                name: .notificationOpened,
                notificationKind: .weeklyRead,
                entryPoint: .notification
            ),
            GrowthEvent(
                createdAt: start.addingTimeInterval(2),
                name: .paywallViewed,
                entryPoint: .postPractice
            ),
            GrowthEvent(
                createdAt: start.addingTimeInterval(3),
                name: .paywallEligibilityResolved,
                subscriptionPlan: .annual,
                trialEligibility: .eligible
            ),
            GrowthEvent(
                createdAt: start.addingTimeInterval(4),
                name: .entitlementBecameInactive,
                subscriptionPlan: .annual,
                inactiveReason: .billingRetry
            ),
            GrowthEvent(
                createdAt: start.addingTimeInterval(5),
                name: .aiUsageEstimated,
                aiSurface: .askNoum,
                aiProvider: .anthropic,
                metrics: [.estimatedCostMicros: 120, .pricingVersion: 1]
            ),
            GrowthEvent(
                createdAt: start.addingTimeInterval(6),
                name: .aiUsageUnpriced,
                aiSurface: .transcription,
                aiProvider: .unknown,
                metrics: [.audioSeconds: 8, .pricingVersion: 1]
            ),
        ]
        let period = DateInterval(start: start, duration: 86_400)

        let deniedUpload = try await uploader.uploadIfConsented(
            consent: .denied,
            events: events,
            period: period,
            generatedAt: start
        )
        #expect(!deniedUpload)
        let batchesBeforeConsent = await transport.recordedBatches()
        #expect(batchesBeforeConsent.isEmpty)
        let grantedUpload = try await uploader.uploadIfConsented(
            consent: .granted,
            events: events,
            period: period,
            generatedAt: start
        )
        #expect(grantedUpload)

        let recordedBatches = await transport.recordedBatches()
        let batch = try #require(recordedBatches.first)
        #expect(batch.batchID != eventID)
        #expect(batch.schemaVersion == 2)
        #expect(batch.activationCohortDay == "2024-12-29")
        #expect(batch.eventCounts[.productSelected] == 1)
        #expect(batch.eventCounts[.notificationOpened] == 1)
        #expect(batch.paywallSourceCounts[.postPractice] == 1)
        #expect(batch.planSelectionCounts[.annual] == 1)
        #expect(batch.trialEligibilityCounts[.eligible] == 1)
        #expect(batch.inactiveReasonCounts[.billingRetry] == 1)
        #expect(batch.notificationOpenCounts[.weeklyRead] == 1)
        #expect(batch.estimatedAICostMicros == 120)
        #expect(batch.unpricedAIUsageCount == 1)
        let request = GrowthAggregateCallableRequest(batch: batch)
        #expect(request.unpricedAIUsageCount == 1)
        let encoded = try #require(String(data: JSONEncoder().encode(batch), encoding: .utf8))
        #expect(!encoded.contains(eventID.uuidString))
        #expect(!encoded.contains(correlationID.uuidString))
        #expect(!encoded.contains("reason"))
        #expect(encoded.contains("\"activationCohortDay\":\"2024-12-29\""))
    }

    @Test func aggregateConsentCursorAndClosedDayCadencePersist() async throws {
        let defaults = isolatedDefaults()
        let log = FlowEventLog(defaults: defaults, storageKey: "growth.cadence")
        let transport = GrowthAggregateTransportSpy()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.startOfDay(for: start)
        FlowEventGrowthEventSink(flowEventLog: log).record(GrowthEvent(
            createdAt: day.addingTimeInterval(30),
            name: .accountActivated,
            metrics: [.activeDayIndex: 0]
        ))
        FlowEventGrowthEventSink(flowEventLog: log).record(GrowthEvent(
            createdAt: day.addingTimeInterval(60),
            name: .firstWrittenValueDelivered,
            metrics: [.durationMs: 18_000]
        ))

        #expect(log.aggregateConsent == .notDetermined)
        #expect(try await log.uploadClosedGrowthAggregatePeriods(
            transport: transport,
            now: day.addingTimeInterval(2 * 86_400 + 60),
            calendar: calendar
        ) == 0)

        log.setAggregateConsent(.granted)
        #expect(try await log.uploadClosedGrowthAggregatePeriods(
            transport: transport,
            now: day.addingTimeInterval(2 * 86_400 + 60),
            calendar: calendar,
            appVersion: "1.2.0",
            buildNumber: "314"
        ) == 1)
        #expect(log.lastAggregatePeriodEnd == day.addingTimeInterval(2 * 86_400))
        #expect(log.aggregateUploadStatus == .uploaded)
        let batch = try #require(await transport.recordedBatches().first)
        #expect(batch.appVersion == "1.2.0")
        #expect(batch.buildNumber == "314")
        #expect(batch.firstWrittenValueDurationBucketCounts["under30s"] == 1)

        let reloaded = FlowEventLog(defaults: defaults, storageKey: "growth.cadence")
        #expect(reloaded.aggregateConsent == .granted)
        #expect(reloaded.lastAggregatePeriodEnd == day.addingTimeInterval(2 * 86_400))
    }

    @Test("Aggregate upload fails closed without a cohort activation anchor")
    func aggregateRequiresActivationCohort() async throws {
        let transport = GrowthAggregateTransportSpy()
        let uploader = GrowthAggregateUploader(transport: transport)
        let didUpload = try await uploader.uploadIfConsented(
            consent: .granted,
            events: [GrowthEvent(
                createdAt: start,
                name: .weeklyReadViewed,
                entryPoint: .home
            )],
            period: DateInterval(start: start, duration: 86_400),
            generatedAt: start.addingTimeInterval(86_400)
        )

        #expect(!didUpload)
        #expect(await transport.recordedBatches().isEmpty)
    }

    @Test func failedAggregateUploadRetriesTheSameAnonymousBatch() async throws {
        let defaults = isolatedDefaults()
        let log = FlowEventLog(defaults: defaults, storageKey: "growth.retry")
        let transport = GrowthAggregateFailOnceTransport()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.startOfDay(for: start)
        FlowEventGrowthEventSink(flowEventLog: log).record(GrowthEvent(
            createdAt: day.addingTimeInterval(60),
            name: .appActivated,
            metrics: [.activeDayIndex: 1]
        ))
        log.setAggregateConsent(.granted)

        await #expect(throws: GrowthAggregateTestError.self) {
            try await log.uploadClosedGrowthAggregatePeriods(
                transport: transport,
                now: day.addingTimeInterval(86_400 + 60),
                calendar: calendar
            )
        }
        #expect(log.aggregateUploadStatus == .waitingToRetry)
        #expect(log.lastAggregatePeriodEnd == nil)

        #expect(try await log.uploadClosedGrowthAggregatePeriods(
            transport: transport,
            now: day.addingTimeInterval(86_400 + 60),
            calendar: calendar
        ) == 1)
        let attempts = await transport.attemptedBatchIDs()
        #expect(attempts.count == 2)
        #expect(attempts[0] == attempts[1])
    }

    @Test func rateLimiterPublishesOnlyAReservationIntoInjectedGrowthLedger() {
        let defaults = isolatedDefaults()
        let log = FlowEventLog(defaults: defaults, storageKey: "growth.rate")
        let sink = FlowEventGrowthEventSink(flowEventLog: log)
        let limiter = AIRateLimiter(
            defaults: defaults,
            accountIDProvider: { "growth-test" },
            now: { start },
            premiumProvider: { false },
            growthEventSink: sink
        )

        #expect(limiter.consumeIfAllowed(kind: .postRepCoachNote))
        #expect(!limiter.consumeIfAllowed(kind: .postRepCoachNote))
        let events = log.growthEvents()
        #expect(events.count == 1)
        #expect(events[0].name == .aiBudgetReserved)
        #expect(events[0].subscriptionState == .free)
        #expect(events[0].aiSurface == .postRepCoachNote)
        #expect(events[0].metrics[.dailyUsageCount] == 1)
        #expect(events[0].metrics[.dailyUsageCap] == AIRateLimiter.freeDailyCap)
        #expect(events[0].metrics[.estimatedCostMicros] == nil)
    }

    private func growth(
        _ name: GrowthEventName,
        at offset: TimeInterval,
        correlationID: UUID = UUID(),
        subscriptionState: GrowthSubscriptionState = .unknown,
        metrics: [GrowthMetric: Int] = [:]
    ) -> GrowthEvent {
        GrowthEvent(
            createdAt: start.addingTimeInterval(offset),
            correlationID: correlationID,
            name: name,
            subscriptionState: subscriptionState,
            metrics: metrics
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "growth.observability.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

}

private actor GrowthAggregateTransportSpy: GrowthAggregateTransport {
    private var batches: [GrowthAggregateBatch] = []

    func upload(_ batch: GrowthAggregateBatch) async throws {
        batches.append(batch)
    }

    func recordedBatches() -> [GrowthAggregateBatch] {
        batches
    }
}

private struct GrowthAggregateTestError: Error {}

private actor GrowthAggregateFailOnceTransport: GrowthAggregateTransport {
    private var attempts: [UUID] = []

    func upload(_ batch: GrowthAggregateBatch) async throws {
        attempts.append(batch.batchID)
        if attempts.count == 1 { throw GrowthAggregateTestError() }
    }

    func attemptedBatchIDs() -> [UUID] {
        attempts
    }
}
