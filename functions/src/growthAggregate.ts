import {HttpsError} from "firebase-functions/v2/https";

const DAY_MILLISECONDS = 86_400_000;
const MAXIMUM_BACKFILL_DAYS = 7;
const MAXIMUM_COUNT = 500;
const MAXIMUM_AI_COST_MICROS = 1_000_000_000_000;

const EVENT_NAMES = new Set([
  "growth.lifecycle.accountActivated",
  "growth.lifecycle.appActivated",
  "growth.activation.onboardingStarted",
  "growth.activation.onboardingCompleted",
  "growth.activation.firstValueDelivered",
  "growth.activation.firstWrittenValueDelivered",
  "growth.practice.firstSpokenStarted",
  "growth.practice.started",
  "growth.practice.completed",
  "growth.practice.secondCompleted",
  "growth.practice.thirdCompleted",
  "growth.practice.summaryViewed",
  "growth.engagement.coachOpened",
  "growth.engagement.weeklyReadViewed",
  "growth.subscription.paywallViewed",
  "growth.subscription.paywallEligibilityResolved",
  "growth.subscription.productSelected",
  "growth.subscription.trialStarted",
  "growth.subscription.purchaseStarted",
  "growth.subscription.purchaseSucceeded",
  "growth.subscription.purchaseFailed",
  "growth.subscription.purchaseCancelled",
  "growth.subscription.purchasePending",
  "growth.subscription.restoreStarted",
  "growth.subscription.restoreSucceeded",
  "growth.subscription.restoreNoEntitlement",
  "growth.subscription.restoreFailed",
  "growth.subscription.entitlementActivated",
  "growth.subscription.entitlementRenewed",
  "growth.subscription.cancellationRequested",
  "growth.subscription.billingFailed",
  "growth.subscription.purchaseRefunded",
  "growth.subscription.entitlementExpired",
  "growth.subscription.entitlementBecameInactive",
  "growth.notification.optInPrompted",
  "growth.notification.optInAccepted",
  "growth.notification.optInDeclined",
  "growth.notification.opened",
  "growth.ai.budgetReserved",
  "growth.ai.usageEstimated",
  "growth.ai.usageUnpriced",
]);

const REQUEST_KEYS = new Set([
  "schemaVersion",
  "batchID",
  "appVersion",
  "buildNumber",
  "generatedAtMilliseconds",
  "periodStartMilliseconds",
  "periodEndMilliseconds",
  "activationCohortDay",
  "eventCounts",
  "paywallSourceCounts",
  "planSelectionCounts",
  "trialEligibilityCounts",
  "inactiveReasonCounts",
  "notificationOpenCounts",
  "activeDayIndexCounts",
  "firstWrittenValueDurationBucketCounts",
  "secondPracticeWithin48HoursCount",
  "weeklyReadAmongDay1ReturnersCount",
  "estimatedAICostMicros",
  "estimatedAICostCurrency",
  "unpricedAIUsageCount",
  "aiBudgetReservationCount",
]);

const DURATION_BUCKETS = new Set([
  "under30s", "30to59s", "60to119s", "120sPlus",
]);

export interface GrowthAggregateInput {
  schemaVersion: 2;
  batchID: string;
  appVersion: string;
  buildNumber: string;
  generatedAtMilliseconds: number;
  periodStartMilliseconds: number;
  periodEndMilliseconds: number;
  activationCohortDay: string;
  eventCounts: Record<string, number>;
  paywallSourceCounts: Record<string, number>;
  planSelectionCounts: Record<string, number>;
  trialEligibilityCounts: Record<string, number>;
  inactiveReasonCounts: Record<string, number>;
  notificationOpenCounts: Record<string, number>;
  activeDayIndexCounts: Record<string, number>;
  firstWrittenValueDurationBucketCounts: Record<string, number>;
  secondPracticeWithin48HoursCount: number;
  weeklyReadAmongDay1ReturnersCount: number;
  estimatedAICostMicros: number;
  estimatedAICostCurrency: "USD";
  unpricedAIUsageCount: number;
  aiBudgetReservationCount: number;
}

/**
 * Rejects an aggregate without echoing any submitted value.
 * @param {string} reason Stable diagnostic reason.
 */
function invalid(reason: string): never {
  throw new HttpsError(
    "invalid-argument",
    "The aggregate batch is invalid.",
    {reason}
  );
}

/**
 * Checks for a plain JSON object.
 * @param {unknown} value Candidate value.
 * @return {boolean} Whether the value is a record.
 */
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Requires a bounded safe integer.
 * @param {unknown} value Candidate value.
 * @param {number} minimum Inclusive minimum.
 * @param {number} maximum Inclusive maximum.
 * @param {string} reason Stable rejection reason.
 * @return {number} Validated integer.
 */
function requireSafeInteger(
  value: unknown,
  minimum: number,
  maximum: number,
  reason: string
): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) ||
      value < minimum || value > maximum) {
    return invalid(reason);
  }
  return value;
}

/**
 * Requires a bounded map whose keys come from an explicit allowlist.
 * @param {unknown} value Candidate count map.
 * @param {ReadonlySet<string>} allowedKeys Allowed keys.
 * @param {string} reason Stable rejection reason.
 * @return {Record<string, number>} Validated count map.
 */
function requireCountMap(
  value: unknown,
  allowedKeys: ReadonlySet<string>,
  reason: string
): Record<string, number> {
  if (!isRecord(value) || Object.keys(value).length > allowedKeys.size) {
    return invalid(reason);
  }
  const result: Record<string, number> = {};
  for (const [key, rawCount] of Object.entries(value)) {
    if (!allowedKeys.has(key)) return invalid(reason);
    result[key] = requireSafeInteger(rawCount, 0, MAXIMUM_COUNT, reason);
  }
  return result;
}

/**
 * Creates the allowlist for an integer-backed enum.
 * @param {number} minimum Inclusive minimum.
 * @param {number} maximum Inclusive maximum.
 * @return {Set<string>} Decimal key strings.
 */
function numericKeySet(minimum: number, maximum: number): Set<string> {
  return new Set(Array.from(
    {length: maximum - minimum + 1},
    (_, index) => String(index + minimum)
  ));
}

/**
 * Sums a bounded count map.
 * @param {Record<string, number>} values Count map.
 * @return {number} Sum of counts.
 */
function sum(values: Record<string, number>): number {
  return Object.values(values).reduce((total, value) => total + value, 0);
}

/**
 * Requires a short numeric app or build version token.
 * @param {unknown} value Candidate token.
 * @param {string} reason Stable rejection reason.
 * @return {string} Validated token.
 */
function requireVersion(value: unknown, reason: string): string {
  if (typeof value !== "string" ||
      !/^(?:unknown|[0-9][0-9.-]{0,31})$/u.test(value)) {
    return invalid(reason);
  }
  return value;
}

/**
 * Validates the only accepted content-free aggregate schema.
 * @param {unknown} data Callable payload.
 * @param {number} nowMilliseconds Trusted server wall clock for tests/runtime.
 * @return {GrowthAggregateInput} Bounded normalized batch.
 */
export function validateGrowthAggregate(
  data: unknown,
  nowMilliseconds: number = Date.now()
): GrowthAggregateInput {
  if (!isRecord(data) ||
      Object.keys(data).length !== REQUEST_KEYS.size ||
      Object.keys(data).some((key) => !REQUEST_KEYS.has(key))) {
    return invalid("growth-aggregate-shape");
  }
  if (data.schemaVersion !== 2) {
    return invalid("growth-aggregate-schema");
  }
  const batchIDPattern = new RegExp(
    "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-" +
      "[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    "iu"
  );
  if (typeof data.batchID !== "string" ||
      !batchIDPattern.test(data.batchID)) {
    return invalid("growth-aggregate-batch-id");
  }

  const generatedAtMilliseconds = requireSafeInteger(
    data.generatedAtMilliseconds, 0, nowMilliseconds + 300_000,
    "growth-aggregate-generated-at"
  );
  const periodStartMilliseconds = requireSafeInteger(
    data.periodStartMilliseconds, 0, nowMilliseconds,
    "growth-aggregate-period-start"
  );
  const periodEndMilliseconds = requireSafeInteger(
    data.periodEndMilliseconds, 0, nowMilliseconds,
    "growth-aggregate-period-end"
  );
  if (periodStartMilliseconds % DAY_MILLISECONDS !== 0 ||
      periodEndMilliseconds - periodStartMilliseconds !== DAY_MILLISECONDS ||
      generatedAtMilliseconds < periodEndMilliseconds ||
      periodEndMilliseconds < nowMilliseconds -
        (MAXIMUM_BACKFILL_DAYS + 1) * DAY_MILLISECONDS) {
    return invalid("growth-aggregate-period");
  }
  if (typeof data.activationCohortDay !== "string" ||
      !/^\d{4}-\d{2}-\d{2}$/u.test(data.activationCohortDay)) {
    return invalid("growth-aggregate-activation-cohort");
  }
  const activationCohortMilliseconds = Date.parse(
    `${data.activationCohortDay}T00:00:00.000Z`
  );
  if (!Number.isFinite(activationCohortMilliseconds) ||
      new Date(activationCohortMilliseconds).toISOString().slice(0, 10) !==
        data.activationCohortDay ||
      activationCohortMilliseconds > periodStartMilliseconds) {
    return invalid("growth-aggregate-activation-cohort");
  }

  const eventCounts = requireCountMap(
    data.eventCounts, EVENT_NAMES, "growth-aggregate-event-counts"
  );
  if (sum(eventCounts) < 1) {
    return invalid("growth-aggregate-empty");
  }
  const paywallSourceCounts = requireCountMap(
    data.paywallSourceCounts, numericKeySet(1, 9),
    "growth-aggregate-paywall-sources"
  );
  const planSelectionCounts = requireCountMap(
    data.planSelectionCounts, numericKeySet(1, 2),
    "growth-aggregate-plan-selections"
  );
  const trialEligibilityCounts = requireCountMap(
    data.trialEligibilityCounts, numericKeySet(1, 3),
    "growth-aggregate-trial-eligibility"
  );
  const inactiveReasonCounts = requireCountMap(
    data.inactiveReasonCounts, numericKeySet(1, 6),
    "growth-aggregate-inactive-reasons"
  );
  const notificationOpenCounts = requireCountMap(
    data.notificationOpenCounts, numericKeySet(1, 4),
    "growth-aggregate-notification-opens"
  );
  const activeDayIndexCounts = requireCountMap(
    data.activeDayIndexCounts, numericKeySet(0, 28),
    "growth-aggregate-active-days"
  );
  const firstWrittenValueDurationBucketCounts = requireCountMap(
    data.firstWrittenValueDurationBucketCounts, DURATION_BUCKETS,
    "growth-aggregate-written-duration"
  );
  const secondPracticeWithin48HoursCount = requireSafeInteger(
    data.secondPracticeWithin48HoursCount, 0, 1,
    "growth-aggregate-second-rep"
  );
  const weeklyReadAmongDay1ReturnersCount = requireSafeInteger(
    data.weeklyReadAmongDay1ReturnersCount, 0, 1,
    "growth-aggregate-weekly-read"
  );
  const estimatedAICostMicros = requireSafeInteger(
    data.estimatedAICostMicros, 0, MAXIMUM_AI_COST_MICROS,
    "growth-aggregate-ai-cost"
  );
  if (data.estimatedAICostCurrency !== "USD") {
    return invalid("growth-aggregate-ai-cost-currency");
  }
  const unpricedAIUsageCount = requireSafeInteger(
    data.unpricedAIUsageCount, 0, MAXIMUM_COUNT,
    "growth-aggregate-unpriced-ai-usage"
  );
  const aiBudgetReservationCount = requireSafeInteger(
    data.aiBudgetReservationCount, 0, MAXIMUM_COUNT,
    "growth-aggregate-ai-reservations"
  );

  if (sum(paywallSourceCounts) >
        (eventCounts["growth.subscription.paywallViewed"] ?? 0) ||
      sum(planSelectionCounts) >
        (eventCounts["growth.subscription.productSelected"] ?? 0) ||
      sum(trialEligibilityCounts) >
        (eventCounts["growth.subscription.paywallEligibilityResolved"] ?? 0) ||
      sum(notificationOpenCounts) >
        (eventCounts["growth.notification.opened"] ?? 0) ||
      sum(activeDayIndexCounts) >
        ((eventCounts["growth.lifecycle.appActivated"] ?? 0) +
         (eventCounts["growth.lifecycle.accountActivated"] ?? 0)) ||
      sum(firstWrittenValueDurationBucketCounts) >
        (eventCounts["growth.activation.firstWrittenValueDelivered"] ?? 0) ||
      secondPracticeWithin48HoursCount >
        (eventCounts["growth.practice.secondCompleted"] ?? 0) ||
      weeklyReadAmongDay1ReturnersCount >
        (eventCounts["growth.engagement.weeklyReadViewed"] ?? 0) ||
      unpricedAIUsageCount !==
        (eventCounts["growth.ai.usageUnpriced"] ?? 0) ||
      aiBudgetReservationCount >
        (eventCounts["growth.ai.budgetReserved"] ?? 0)) {
    return invalid("growth-aggregate-cross-field-count");
  }

  return {
    schemaVersion: 2,
    batchID: data.batchID.toLowerCase(),
    appVersion: requireVersion(data.appVersion, "growth-aggregate-app-version"),
    buildNumber: requireVersion(data.buildNumber, "growth-aggregate-build"),
    generatedAtMilliseconds,
    periodStartMilliseconds,
    periodEndMilliseconds,
    activationCohortDay: data.activationCohortDay,
    eventCounts,
    paywallSourceCounts,
    planSelectionCounts,
    trialEligibilityCounts,
    inactiveReasonCounts,
    notificationOpenCounts,
    activeDayIndexCounts,
    firstWrittenValueDurationBucketCounts,
    secondPracticeWithin48HoursCount,
    weeklyReadAmongDay1ReturnersCount,
    estimatedAICostMicros,
    estimatedAICostCurrency: "USD",
    unpricedAIUsageCount,
    aiBudgetReservationCount,
  };
}

/**
 * Stable UTC key for the closed period document.
 * @param {GrowthAggregateInput} input Validated aggregate.
 * @return {string} YYYY-MM-DD period key.
 */
export function growthAggregatePeriodKey(
  input: GrowthAggregateInput
): string {
  return new Date(input.periodStartMilliseconds).toISOString().slice(0, 10);
}
