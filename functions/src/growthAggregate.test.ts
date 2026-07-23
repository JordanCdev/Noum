import assert from "node:assert/strict";
import test from "node:test";
import {
  growthAggregatePeriodKey,
  validateGrowthAggregate,
} from "./growthAggregate.js";

const now = Date.UTC(2026, 6, 21, 12, 0, 0);
const periodStart = Date.UTC(2026, 6, 20, 0, 0, 0);

/**
 * Returns one valid content-free daily aggregate fixture.
 * @return {Record<string, unknown>} Valid test request.
 */
function validBatch(): Record<string, unknown> {
  return {
    schemaVersion: 2,
    batchID: "d9428888-122b-4a4b-9e76-9f0b4295f74e",
    appVersion: "1.2.0",
    buildNumber: "314",
    generatedAtMilliseconds: now,
    periodStartMilliseconds: periodStart,
    periodEndMilliseconds: periodStart + 86_400_000,
    activationCohortDay: "2026-07-20",
    eventCounts: {
      "growth.lifecycle.appActivated": 1,
      "growth.activation.firstWrittenValueDelivered": 1,
      "growth.practice.firstSpokenStarted": 1,
      "growth.practice.secondCompleted": 1,
      "growth.engagement.weeklyReadViewed": 1,
      "growth.subscription.paywallViewed": 1,
      "growth.subscription.paywallEligibilityResolved": 1,
      "growth.subscription.productSelected": 1,
      "growth.notification.opened": 1,
      "growth.ai.budgetReserved": 1,
      "growth.ai.usageEstimated": 1,
      "growth.ai.usageUnpriced": 1,
    },
    paywallSourceCounts: {"8": 1},
    planSelectionCounts: {"2": 1},
    trialEligibilityCounts: {"1": 1},
    inactiveReasonCounts: {},
    notificationOpenCounts: {"2": 1},
    activeDayIndexCounts: {"1": 1},
    firstWrittenValueDurationBucketCounts: {"under30s": 1},
    secondPracticeWithin48HoursCount: 1,
    weeklyReadAmongDay1ReturnersCount: 1,
    estimatedAICostMicros: 2300,
    estimatedAICostCurrency: "USD",
    unpricedAIUsageCount: 1,
    aiBudgetReservationCount: 1,
  };
}

test("growth aggregate accepts the exact bounded content-free schema", () => {
  const input = validateGrowthAggregate(validBatch(), now);
  assert.equal(input.appVersion, "1.2.0");
  assert.equal(input.eventCounts["growth.practice.firstSpokenStarted"], 1);
  assert.equal(input.firstWrittenValueDurationBucketCounts.under30s, 1);
  assert.equal(input.estimatedAICostCurrency, "USD");
  assert.equal(input.unpricedAIUsageCount, 1);
  assert.equal(input.activationCohortDay, "2026-07-20");
  assert.equal(growthAggregatePeriodKey(input), "2026-07-20");
  assert.equal(JSON.stringify(input).includes("transcript"), false);
});

test(
  "growth aggregate requires a real non-future UTC activation cohort day",
  () => {
    for (const invalid of ["2026-7-20", "2026-02-30", "private-user-key"]) {
      const batch = validBatch();
      batch.activationCohortDay = invalid;
      assert.throws(() => validateGrowthAggregate(batch, now));
    }

    const future = validBatch();
    future.activationCohortDay = "2026-07-21";
    assert.throws(() => validateGrowthAggregate(future, now));

    const missing = validBatch();
    delete missing.activationCohortDay;
    assert.throws(() => validateGrowthAggregate(missing, now));
  }
);

test("growth aggregate rejects an unlabeled or mixed AI cost currency", () => {
  const missing = validBatch();
  delete missing.estimatedAICostCurrency;
  assert.throws(() => validateGrowthAggregate(missing, now));

  const mixed = validBatch();
  mixed.estimatedAICostCurrency = "GBP";
  assert.throws(() => validateGrowthAggregate(mixed, now));
});

test("growth aggregate rejects arbitrary content and event vocabulary", () => {
  assert.throws(() => validateGrowthAggregate({
    ...validBatch(),
    transcript: "private words",
  }, now));
  const unknown = validBatch();
  unknown.eventCounts = {"growth.private.userSentence": 1};
  assert.throws(() => validateGrowthAggregate(unknown, now));
});

test("growth aggregate rejects category counts without matching events", () => {
  const batch = validBatch();
  batch.planSelectionCounts = {"2": 2};
  assert.throws(() => validateGrowthAggregate(batch, now));
});

test("growth aggregate requires exact bounded unpriced AI usage", () => {
  const understated = validBatch();
  understated.unpricedAIUsageCount = 0;
  assert.throws(() => validateGrowthAggregate(understated, now));

  const overstated = validBatch();
  overstated.unpricedAIUsageCount = 2;
  assert.throws(() => validateGrowthAggregate(overstated, now));

  const unbounded = validBatch();
  unbounded.eventCounts = {"growth.ai.usageUnpriced": 500};
  unbounded.unpricedAIUsageCount = 501;
  assert.throws(() => validateGrowthAggregate(unbounded, now));
});

test("growth aggregate rejects partial and stale calendar periods", () => {
  const partial = validBatch();
  partial.periodEndMilliseconds = periodStart + 60_000;
  assert.throws(() => validateGrowthAggregate(partial, now));

  const stale = validBatch();
  stale.periodStartMilliseconds = periodStart - 9 * 86_400_000;
  stale.periodEndMilliseconds = periodStart - 8 * 86_400_000;
  assert.throws(() => validateGrowthAggregate(stale, now));
});

test("growth aggregate caps one account-local ledger at 500 events", () => {
  const batch = validBatch();
  batch.eventCounts = {"growth.lifecycle.appActivated": 501};
  batch.activeDayIndexCounts = {"1": 501};
  assert.throws(() => validateGrowthAggregate(batch, now));
});
