import Foundation
import Testing
@testable import Noum

@Suite("Premium growth contracts")
struct PremiumGrowthContractTests {
    @Test func annualIsDefaultAndMonthlyIsEquallyDiscoverable() {
        #expect(PremiumPlanOption.defaultSelection == .annual)
        #expect(PremiumPlanOption.allCases == [.annual, .monthly])
        #expect(PremiumPlanOption.annual.productID == PremiumManager.annualID)
        #expect(PremiumPlanOption.monthly.productID == PremiumManager.monthlyID)
    }

    @Test func planAvailabilityNeverShowsOrSelectsAProductThatStoreKitDidNotReturn() {
        let none: Set<String> = []
        #expect(PremiumPlanAvailability.visiblePlans(productIDs: none).isEmpty)
        #expect(
            PremiumPlanAvailability.resolvedSelection(
                current: .annual,
                productIDs: none
            ) == nil
        )

        let monthlyOnly: Set<String> = [PremiumManager.monthlyID]
        #expect(PremiumPlanAvailability.visiblePlans(productIDs: monthlyOnly) == [.monthly])
        #expect(
            PremiumPlanAvailability.resolvedSelection(
                current: .annual,
                productIDs: monthlyOnly
            ) == .monthly
        )

        let annualOnly: Set<String> = [PremiumManager.annualID]
        #expect(PremiumPlanAvailability.visiblePlans(productIDs: annualOnly) == [.annual])
        #expect(
            PremiumPlanAvailability.resolvedSelection(
                current: .monthly,
                productIDs: annualOnly
            ) == .annual
        )
    }

    @Test func planAvailabilityPreservesAValidChoiceAndDefaultsToAnnualWhenBothLoad() {
        let both: Set<String> = [PremiumManager.annualID, PremiumManager.monthlyID]
        #expect(PremiumPlanAvailability.visiblePlans(productIDs: both) == [.annual, .monthly])
        #expect(
            PremiumPlanAvailability.resolvedSelection(
                current: .monthly,
                productIDs: both
            ) == .monthly
        )
        #expect(
            PremiumPlanAvailability.resolvedSelection(
                current: .annual,
                productIDs: both
            ) == .annual
        )
    }

    @Test func productLoadFailuresStayHonestAndActionable() {
        #expect(
            PremiumProductLoadIssue.emptyCatalog.userMessage
                .contains("monthly or annual plan")
        )
        #expect(
            PremiumProductLoadIssue.storefrontRequestFailed.userMessage
                .contains("couldn’t contact the App Store")
        )
        #expect(
            PremiumProductLoadIssue.emptyCatalog
                != .storefrontRequestFailed
        )
    }

    @Test func eligibleFreeTrialUsesStoreProjectedPeriodAndRenewalCopy() {
        let presentation = PremiumProductPresentation(
            id: PremiumManager.annualID,
            displayPrice: "£79.99",
            billingPeriod: SubscriptionPeriodSnapshot(value: 1, unit: .year),
            introductoryOffer: IntroductoryOfferSnapshot(
                isEligible: true,
                paymentMode: .freeTrial,
                period: SubscriptionPeriodSnapshot(value: 7, unit: .day),
                periodCount: 1,
                displayPrice: "£0.00"
            )
        )

        #expect(presentation.billingLine == "£79.99 per year")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_774_310_400) // 24 Mar 2026 UTC
        let end = presentation.introductoryOffer?.period.projectedEndDate(
            startingAt: start,
            periodCount: 1,
            calendar: calendar
        )
        #expect(end == Date(timeIntervalSince1970: 1_774_915_200)) // 31 Mar 2026 UTC
        let displayedEnd = end!.formatted(date: .abbreviated, time: .omitted)
        #expect(
            presentation.introductoryOfferLine(startingAt: start, calendar: calendar)?.contains(displayedEnd) == true
        )
        #expect(
            presentation.introductoryOfferLine(startingAt: start, calendar: calendar)?.contains("then £79.99 per year") == true
        )
        #expect(presentation.purchaseButtonTitle == "Start 7-day free trial")
        #expect(presentation.growthTrialEligibility == .eligible)
    }

    @Test func ineligibleIntroOfferNeverPresentsTrialCopy() {
        let presentation = PremiumProductPresentation(
            id: PremiumManager.annualID,
            displayPrice: "79,99 €",
            billingPeriod: SubscriptionPeriodSnapshot(value: 1, unit: .year),
            introductoryOffer: IntroductoryOfferSnapshot(
                isEligible: false,
                paymentMode: .freeTrial,
                period: SubscriptionPeriodSnapshot(value: 2, unit: .week),
                periodCount: 1,
                displayPrice: "0,00 €"
            )
        )

        #expect(
            presentation.introductoryOfferLine(startingAt: .now, calendar: .current) == nil
        )
        #expect(presentation.purchaseButtonTitle == "Subscribe")
        #expect(presentation.growthTrialEligibility == .ineligible)
    }

    @Test func paidIntroOfferPreservesStorePriceAndExactDuration() {
        let presentation = PremiumProductPresentation(
            id: PremiumManager.monthlyID,
            displayPrice: "$11.99",
            billingPeriod: SubscriptionPeriodSnapshot(value: 1, unit: .month),
            introductoryOffer: IntroductoryOfferSnapshot(
                isEligible: true,
                paymentMode: .payAsYouGo,
                period: SubscriptionPeriodSnapshot(value: 1, unit: .month),
                periodCount: 3,
                displayPrice: "$4.99"
            )
        )

        #expect(
            presentation.introductoryOfferLine(startingAt: .now, calendar: .current)
                == "$4.99 per month for 3 months, then $11.99 per month"
        )
        #expect(presentation.purchaseButtonTitle == "Subscribe")
    }

    @Test func cancelledSubscriptionKeepsAccessUntilVerifiedExpiry() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let expiry = now.addingTimeInterval(86_400 * 10)
        let snapshot = SubscriptionLifecycleSnapshot.resolve(
            verifiedStatuses: [
                VerifiedSubscriptionStatusSnapshot(
                    productID: PremiumManager.annualID,
                    renewalProductID: PremiumManager.annualID,
                    state: .subscribed,
                    willAutoRenew: false,
                    expirationDate: expiry,
                    renewalDate: nil,
                    renewalDisplayPrice: nil,
                    renewalPeriod: nil,
                    isIntroductoryOffer: false,
                    wasRefunded: false
                ),
            ],
            now: now
        )

        #expect(snapshot.state == .cancelledButActive)
        #expect(snapshot.isEntitledState)
        #expect(snapshot.expirationDate == expiry)
        #expect(!snapshot.willAutoRenew)
    }

    @Test func expiredCancellationDoesNotClaimAccess() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let snapshot = SubscriptionLifecycleSnapshot.resolve(
            verifiedStatuses: [
                VerifiedSubscriptionStatusSnapshot(
                    productID: PremiumManager.annualID,
                    renewalProductID: PremiumManager.annualID,
                    state: .subscribed,
                    willAutoRenew: false,
                    expirationDate: now.addingTimeInterval(-1),
                    renewalDate: nil,
                    renewalDisplayPrice: nil,
                    renewalPeriod: nil,
                    isIntroductoryOffer: false,
                    wasRefunded: false
                ),
            ],
            now: now
        )

        #expect(snapshot.state == .expired)
        #expect(!snapshot.isEntitledState)
    }

    @Test func lifecycleProjectionDoesNotRequireLoadedProductMetadata() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let expiry = now.addingTimeInterval(86_400)
        let snapshot = SubscriptionLifecycleSnapshot.resolve(
            verifiedStatuses: [
                VerifiedSubscriptionStatusSnapshot(
                    productID: PremiumManager.annualID,
                    renewalProductID: PremiumManager.annualID,
                    state: .subscribed,
                    willAutoRenew: true,
                    expirationDate: expiry,
                    renewalDate: expiry,
                    renewalDisplayPrice: nil,
                    renewalPeriod: nil,
                    isIntroductoryOffer: true,
                    wasRefunded: false
                ),
            ],
            allowedProductIDs: [PremiumManager.monthlyID, PremiumManager.annualID],
            now: now
        )

        #expect(snapshot.state == .active)
        #expect(snapshot.productID == PremiumManager.annualID)
        #expect(snapshot.renewalDisplayPrice == nil)
        #expect(snapshot.renewalPeriod == nil)
        #expect(snapshot.isIntroductoryOffer)
    }

    @Test func lifecycleProjectionStrictlyRejectsOtherProductsAndCrossProductRenewals() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let allowed: Set<String> = [PremiumManager.monthlyID, PremiumManager.annualID]
        let unrelatedID = "com.example.unrelated.subscription"
        let statuses = [
            VerifiedSubscriptionStatusSnapshot(
                productID: unrelatedID,
                renewalProductID: unrelatedID,
                state: .subscribed,
                willAutoRenew: true,
                expirationDate: now.addingTimeInterval(86_400 * 30),
                renewalDate: nil,
                renewalDisplayPrice: "$999.99",
                renewalPeriod: SubscriptionPeriodSnapshot(value: 1, unit: .month),
                isIntroductoryOffer: false,
                wasRefunded: false
            ),
            VerifiedSubscriptionStatusSnapshot(
                productID: PremiumManager.annualID,
                renewalProductID: unrelatedID,
                state: .subscribed,
                willAutoRenew: true,
                expirationDate: now.addingTimeInterval(86_400 * 30),
                renewalDate: nil,
                renewalDisplayPrice: "$999.99",
                renewalPeriod: SubscriptionPeriodSnapshot(value: 1, unit: .month),
                isIntroductoryOffer: false,
                wasRefunded: false
            ),
        ]

        let snapshot = SubscriptionLifecycleSnapshot.resolve(
            verifiedStatuses: statuses,
            allowedProductIDs: allowed,
            now: now
        )

        #expect(snapshot == .free)
    }

    @Test func emptyStatusStreamDoesNotInventExpiryForVerifiedEntitlement() {
        let previous = SubscriptionLifecycleSnapshot(
            state: .active,
            productID: PremiumManager.annualID,
            renewalProductID: PremiumManager.annualID,
            willAutoRenew: true,
            expirationDate: Date(timeIntervalSince1970: 2_000_000_000),
            renewalDate: nil,
            renewalDisplayPrice: "£79.99",
            renewalPeriod: SubscriptionPeriodSnapshot(value: 1, unit: .year),
            isIntroductoryOffer: false,
            wasRefunded: false
        )
        let observation = SubscriptionLifecycleObservation.resolve(
            verifiedStatuses: [],
            allowedProductIDs: [PremiumManager.monthlyID, PremiumManager.annualID],
            verifiedEntitlementProductIDs: [PremiumManager.annualID],
            lastObservedLifecycle: previous
        )

        #expect(observation.visibleSnapshot == .unknown)
        #expect(observation.snapshotToCommit == nil)
    }

    @Test func emptyStatusStreamCanResolveFreeWithoutEntitlementOrPriorAccess() {
        let observation = SubscriptionLifecycleObservation.resolve(
            verifiedStatuses: [],
            allowedProductIDs: [PremiumManager.monthlyID, PremiumManager.annualID],
            verifiedEntitlementProductIDs: [],
            lastObservedLifecycle: .unknown
        )

        #expect(observation.visibleSnapshot == .free)
        #expect(observation.snapshotToCommit == .free)
    }

    @Test func unknownFutureRenewalStateDoesNotInventOrPersistExpiry() {
        let previous = SubscriptionLifecycleSnapshot(
            state: .active,
            productID: PremiumManager.annualID,
            renewalProductID: PremiumManager.annualID,
            willAutoRenew: true,
            expirationDate: Date(timeIntervalSince1970: 2_000_000_000),
            renewalDate: nil,
            renewalDisplayPrice: "£79.99",
            renewalPeriod: SubscriptionPeriodSnapshot(value: 1, unit: .year),
            isIntroductoryOffer: false,
            wasRefunded: false
        )
        let unknownStatus = VerifiedSubscriptionStatusSnapshot(
            productID: PremiumManager.annualID,
            renewalProductID: PremiumManager.annualID,
            state: .unknown,
            willAutoRenew: false,
            expirationDate: nil,
            renewalDate: nil,
            renewalDisplayPrice: nil,
            renewalPeriod: nil,
            isIntroductoryOffer: false,
            wasRefunded: false
        )

        let observation = SubscriptionLifecycleObservation.resolve(
            verifiedStatuses: [unknownStatus],
            allowedProductIDs: [PremiumManager.monthlyID, PremiumManager.annualID],
            verifiedEntitlementProductIDs: [PremiumManager.annualID],
            lastObservedLifecycle: previous
        )

        #expect(observation.visibleSnapshot == .unknown)
        #expect(observation.snapshotToCommit == nil)
    }

    @Test func activeLifecycleCopyIncludesVerifiedRenewalDatePriceAndPeriod() {
        let renewalDate = Date(timeIntervalSince1970: 1_774_915_200)
        let snapshot = SubscriptionLifecycleSnapshot(
            state: .active,
            productID: PremiumManager.annualID,
            renewalProductID: PremiumManager.annualID,
            willAutoRenew: true,
            expirationDate: renewalDate,
            renewalDate: renewalDate,
            renewalDisplayPrice: "£79.99",
            renewalPeriod: SubscriptionPeriodSnapshot(value: 1, unit: .year),
            isIntroductoryOffer: false,
            wasRefunded: false
        )

        #expect(
            PremiumSubscriptionCopy.lifecycleMessage(snapshot, formatDate: { _ in "31 Mar 2026" })
                == "Renews on 31 Mar 2026 at £79.99 per year."
        )
    }

    @Test func boundedLifecycleSnapshotRoundTripsForRelaunchReconciliation() throws {
        let snapshot = SubscriptionLifecycleSnapshot(
            state: .billingRetry,
            productID: PremiumManager.monthlyID,
            renewalProductID: PremiumManager.monthlyID,
            willAutoRenew: true,
            expirationDate: Date(timeIntervalSince1970: 2_000_000_000),
            renewalDate: Date(timeIntervalSince1970: 2_000_086_400),
            renewalDisplayPrice: "£11.99",
            renewalPeriod: SubscriptionPeriodSnapshot(value: 1, unit: .month),
            isIntroductoryOffer: false,
            wasRefunded: false
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(
            SubscriptionLifecycleSnapshot.self,
            from: encoded
        )
        #expect(decoded == snapshot)
    }

    @Test func cancellationCopyNamesAppleManagementAndDeletionBoundary() {
        #expect(PremiumSubscriptionCopy.cancellationExplanation.contains("Apple Account"))
        #expect(PremiumSubscriptionCopy.cancellationExplanation.contains("access continues"))
        #expect(PremiumSubscriptionCopy.deletionExplanation.contains("does not cancel"))
    }

    @Test func restoreStatesAreDistinctAndActionable() {
        #expect(PremiumRestoreOutcome.restored.userMessage == "Noum Pro was restored.")
        #expect(PremiumRestoreOutcome.noActiveSubscription.userMessage.contains("No active"))
        #expect(PremiumRestoreOutcome.failed.userMessage.contains("try again"))
        #expect(PremiumRestoreOutcome.restored != .noActiveSubscription)
        #expect(PremiumRestoreOutcome.failed != .noActiveSubscription)
        #expect(PremiumRestoreOutcome.restored.growthEventName == .restoreSucceeded)
        #expect(PremiumRestoreOutcome.noActiveSubscription.growthEventName == .restoreNoEntitlement)
        #expect(PremiumRestoreOutcome.failed.growthEventName == .restoreFailed)
        #expect(PremiumRestoreOutcome.restored.growthOutcome == .succeeded)
        #expect(PremiumRestoreOutcome.noActiveSubscription.growthOutcome == .recorded)
        #expect(PremiumRestoreOutcome.failed.growthOutcome == .failed)
    }

    @Test func purchaseOutcomesKeepCancellationAndPendingSeparate() {
        let outcomes: Set<PremiumPurchaseOutcome> = [.purchased, .cancelled, .pending, .failed]
        #expect(outcomes.count == 4)
        #expect(PremiumPurchaseOutcome.cancelled != .pending)
        #expect(PremiumPurchaseOutcome.purchased != .pending)
        #expect(PremiumPurchaseOutcome.failed != .pending)
        #expect(PremiumPurchaseOutcome.purchased.growthEventName == .purchaseSucceeded)
        #expect(PremiumPurchaseOutcome.cancelled.growthEventName == .purchaseCancelled)
        #expect(PremiumPurchaseOutcome.pending.growthEventName == .purchasePending)
        #expect(PremiumPurchaseOutcome.failed.growthEventName == .purchaseFailed)
        #expect(PremiumPurchaseOutcome.cancelled.growthOutcome == .cancelled)
        #expect(PremiumPurchaseOutcome.pending.growthOutcome == .deferred)
    }
}

@Suite("App review prompt policy")
struct AppReviewPromptPolicyTests {
    private let version = "1.1"

    @Test func thirdQualifyingRepIsFirstVolumeEligibilityPoint() {
        #expect(decision(moment: .qualifyingRepCompleted, reps: 2) == .insufficientValue)
        #expect(decision(moment: .qualifyingRepCompleted, reps: 3) == .eligible)
        #expect(decision(moment: .qualifyingRepCompleted, reps: 8) == .eligible)
    }

    @Test func firstVerifiedImprovementIsEligibleWithoutThreeReps() {
        #expect(decision(moment: .firstVerifiedImprovement, reps: 1) == .eligible)
    }

    @Test func launchAndErrorMomentsAreNeverEligible() {
        #expect(decision(moment: .appLaunch, reps: 20) == .inappropriateMoment)
        #expect(decision(moment: .errorOrRecovery, reps: 20) == .inappropriateMoment)
    }

    @Test func onlyOneRequestIsAllowedPerVersion() {
        let context = AppReviewPromptContext(
            moment: .firstVerifiedImprovement,
            qualifyingRepCount: 10,
            currentVersion: version,
            lastRequestedVersion: version
        )
        #expect(AppReviewPromptPolicy.decision(for: context) == .alreadyRequestedThisVersion)
    }

    @Test func missingVersionFailsClosed() {
        let context = AppReviewPromptContext(
            moment: .firstVerifiedImprovement,
            qualifyingRepCount: 10,
            currentVersion: "  ",
            lastRequestedVersion: nil
        )
        #expect(AppReviewPromptPolicy.decision(for: context) == .versionUnavailable)
    }

    private func decision(
        moment: AppReviewPromptMoment,
        reps: Int
    ) -> AppReviewPromptDecision {
        AppReviewPromptPolicy.decision(
            for: AppReviewPromptContext(
                moment: moment,
                qualifyingRepCount: reps,
                currentVersion: version,
                lastRequestedVersion: nil
            )
        )
    }
}

@Suite("Summary review prompt exit gate")
struct SummaryReviewPromptExitGateTests {
    @Test func armingDoesNotPresentAndExplicitExitConsumesExactlyOnce() {
        var gate = SummaryReviewPromptExitGate()

        #expect(gate.pendingMoment == nil)
        gate.arm(.firstVerifiedImprovement)
        #expect(gate.pendingMoment == .firstVerifiedImprovement)
        #expect(gate.consumeForExplicitExit() == .firstVerifiedImprovement)
        #expect(gate.consumeForExplicitExit() == nil)
        #expect(gate.pendingMoment == nil)
    }

    @Test func anUnarmedExitCannotInventAnEligibleMoment() {
        var gate = SummaryReviewPromptExitGate()
        #expect(gate.consumeForExplicitExit() == nil)
    }

    @Test func summaryHasNoElapsedTimeReviewTrigger() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Noum")
                .appendingPathComponent("SummaryView.swift"),
            encoding: .utf8
        )

        #expect(!source.contains(".task(id: pendingReviewPromptMoment)"))
        #expect(!source.contains("Task.sleep(for: .seconds(1.4))"))
        #expect(
            source.components(separatedBy: "SummaryExitPanel(onDone: completeSummaryReview)").count - 1 == 2
        )
        #expect(source.contains(".accessibilityAction(named: Text(\"Done\"))"))
        #expect(source.contains("completeSummaryReview()"))
    }
}

@Suite("App review prompt persistence")
@MainActor
struct AppReviewPromptCoordinatorTests {
    @Test func eligibleRequestMarksVersionBeforeASecondAttempt() {
        let suiteName = "PremiumGrowthContractTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let coordinator = AppReviewPromptCoordinator(
            defaults: defaults,
            versionProvider: { "2.0" }
        )
        var requestCount = 0

        let first = coordinator.requestIfEligible(
            moment: .qualifyingRepCompleted,
            qualifyingRepCount: 3,
            request: { requestCount += 1 }
        )
        let second = coordinator.requestIfEligible(
            moment: .firstVerifiedImprovement,
            qualifyingRepCount: 4,
            request: { requestCount += 1 }
        )

        #expect(first == .eligible)
        #expect(second == .alreadyRequestedThisVersion)
        #expect(requestCount == 1)
    }
}
