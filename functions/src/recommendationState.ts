/* eslint-disable valid-jsdoc, require-jsdoc, max-len */

import {HttpsError} from "firebase-functions/v2/https";

export const RECOMMENDATION_STATE_SCHEMA_VERSION = 1;
export const RECOMMENDATION_OUTCOME_LIMIT = 40;
export const RECOMMENDATION_STATE_MAX_BYTES = 256_000;
const MIN_TIMESTAMP_SECONDS = 946_684_800; // 2000-01-01 UTC
const MAX_TIMESTAMP_SECONDS = 4_102_444_800; // 2100-01-01 UTC

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PRACTICE_MODES = new Set([
  "timed",
  "suddenDeath",
  "ahCounter",
  "imConversation",
]);
const STYLE_GOALS = new Set([
  "authoritative",
  "warm",
  "concise",
  "persuasive",
  "executive",
  "storytelling",
]);
const FOLLOW_UP_RESULTS = new Set([
  "held",
  "earlyImprovement",
  "mixed",
  "needsMoreEvidence",
]);
const TIMED_DIFFICULTIES = new Set(["free", "easy", "medium", "hard"]);
const PRESSURE_DIFFICULTIES = new Set(["easy", "medium", "hard"]);
const PROJECT_ID_PATTERN = /^[A-Za-z0-9_-]+$/;
const RECOMMENDATION_ADHERENCE_SCHEMA_VERSION = 1;

type JsonMap = Record<string, unknown>;

export interface RecommendationStateBody {
  pendingExposure: JsonMap | null;
  outcomes: JsonMap[];
}

export interface RecommendationMutationInput extends RecommendationStateBody {
  schemaVersion: 1;
  mutationID: string;
  expectedRemoteRevision: number;
}

export interface RecommendationStateEnvelope extends RecommendationStateBody {
  schemaVersion: 1;
  remoteRevision: number;
  lastMutationID: string | null;
}

export type RecommendationMutationStatus =
  "committed" | "alreadyCommitted" | "conflict";

export interface RecommendationMutationDecision {
  status: RecommendationMutationStatus;
  state: RecommendationStateEnvelope;
}

/** True for a plain JSON object. */
function isRecord(value: unknown): value is JsonMap {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasOnlyKeys(value: JsonMap, allowed: readonly string[]): boolean {
  const allowedSet = new Set(allowed);
  return Object.keys(value).every((key) => allowedSet.has(key));
}

function requiredString(
  value: unknown,
  field: string,
  maximum: number
): string {
  if (typeof value !== "string" || value.length === 0 || value.length > maximum) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return value;
}

function optionalString(
  value: unknown,
  field: string,
  maximum: number
): void {
  if (value === undefined || value === null) return;
  requiredString(value, field, maximum);
}

function finiteNumber(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return value;
}

function boundedNumber(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number
): number {
  const candidate = finiteNumber(value, field);
  if (candidate < minimum || candidate > maximum) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return candidate;
}

function optionalBoundedNumber(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number
): void {
  if (value === undefined || value === null) return;
  boundedNumber(value, field, minimum, maximum);
}

function optionalUUID(value: unknown, field: string): void {
  if (value === undefined || value === null) return;
  const uuid = requiredString(value, field, 64);
  if (!UUID_PATTERN.test(uuid)) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
}

function validateOptionalAdherenceVersion(value: unknown, field: string): void {
  if (value === undefined || value === null) return;
  if (value !== RECOMMENDATION_ADHERENCE_SCHEMA_VERSION) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
}

function validateDemand(
  value: unknown,
  field: string,
  mode: string
): JsonMap | null {
  if (value === undefined || value === null) return null;
  if (!isRecord(value) || !hasOnlyKeys(value, [
    "schemaVersion", "timedDifficulty", "suddenDeathDifficulty",
    "speechProjectID",
  ]) || value.schemaVersion !== 1) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  const timedDifficulty = value.timedDifficulty;
  const pressureDifficulty = value.suddenDeathDifficulty;
  const projectID = value.speechProjectID;
  if (mode === "timed") {
    if (typeof timedDifficulty !== "string" ||
        !TIMED_DIFFICULTIES.has(timedDifficulty) ||
        (pressureDifficulty !== undefined && pressureDifficulty !== null)) {
      throw new HttpsError("invalid-argument", `${field} is invalid.`);
    }
    if (projectID !== undefined && projectID !== null &&
        (typeof projectID !== "string" || projectID.length === 0 ||
         projectID.length > 80 || !PROJECT_ID_PATTERN.test(projectID))) {
      throw new HttpsError("invalid-argument", `${field} is invalid.`);
    }
    return value;
  }
  if (mode === "suddenDeath" &&
      typeof pressureDifficulty === "string" &&
      PRESSURE_DIFFICULTIES.has(pressureDifficulty) &&
      (timedDifficulty === undefined || timedDifficulty === null) &&
      (projectID === undefined || projectID === null)) {
    return value;
  }
  throw new HttpsError("invalid-argument", `${field} is invalid.`);
}

function validateExposure(value: unknown): JsonMap | null {
  if (value === null) return null;
  if (!isRecord(value) || !hasOnlyKeys(value, [
    "fingerprint", "title", "focus", "target", "mode", "isAIBacked",
    "shownAt", "tappedAt", "goal", "targetDimensionID", "sourceSessionID",
    "observabilityID", "adherenceSchemaVersion", "prescribedDemand",
  ])) {
    throw new HttpsError("invalid-argument", "pendingExposure is invalid.");
  }
  requiredString(value.fingerprint, "pendingExposure.fingerprint", 512);
  requiredString(value.title, "pendingExposure.title", 240);
  requiredString(value.focus, "pendingExposure.focus", 240);
  requiredString(value.target, "pendingExposure.target", 240);
  const mode = requiredString(
    value.mode,
    "pendingExposure.mode",
    32
  );
  if (!PRACTICE_MODES.has(mode)) {
    throw new HttpsError("invalid-argument", "pendingExposure.mode is invalid.");
  }
  if (typeof value.isAIBacked !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      "pendingExposure.isAIBacked is invalid."
    );
  }
  const shownAt = boundedNumber(
    value.shownAt,
    "pendingExposure.shownAt",
    MIN_TIMESTAMP_SECONDS,
    MAX_TIMESTAMP_SECONDS
  );
  optionalBoundedNumber(
    value.tappedAt,
    "pendingExposure.tappedAt",
    shownAt,
    MAX_TIMESTAMP_SECONDS
  );
  if (value.goal !== undefined && value.goal !== null &&
      !STYLE_GOALS.has(requiredString(value.goal, "pendingExposure.goal", 32))) {
    throw new HttpsError("invalid-argument", "pendingExposure.goal is invalid.");
  }
  optionalString(value.targetDimensionID, "pendingExposure.targetDimensionID", 120);
  optionalUUID(value.sourceSessionID, "pendingExposure.sourceSessionID");
  optionalUUID(value.observabilityID, "pendingExposure.observabilityID");
  validateOptionalAdherenceVersion(
    value.adherenceSchemaVersion,
    "pendingExposure.adherenceSchemaVersion"
  );
  const prescribedDemand = validateDemand(
    value.prescribedDemand,
    "pendingExposure.prescribedDemand",
    mode
  );
  if (prescribedDemand !== null &&
      value.adherenceSchemaVersion !== RECOMMENDATION_ADHERENCE_SCHEMA_VERSION) {
    throw new HttpsError(
      "invalid-argument",
      "pendingExposure.adherenceSchemaVersion is invalid."
    );
  }
  return value;
}

function validateOutcome(value: unknown, index: number): JsonMap {
  const field = `outcomes[${index}]`;
  if (!isRecord(value) || !hasOnlyKeys(value, [
    "id", "fingerprint", "title", "focus", "target", "mode", "sessionID",
    "followed", "completedAt", "scoreDelta", "hasComparableScore",
    "adherenceSchemaVersion", "prescribedDemand", "executedDemand",
    "fillerRateDelta", "fillerDelta", "durationDelta",
    "comparisonSessionCount", "comparisonSchemaVersion", "wordsPerMinute",
    "paceDelta", "goal", "targetDimensionID", "sourceSessionID",
    "goalFollowUpResult",
  ])) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  optionalUUID(value.id, `${field}.id`);
  if (value.id === undefined || value.id === null) {
    throw new HttpsError("invalid-argument", `${field}.id is invalid.`);
  }
  requiredString(value.fingerprint, `${field}.fingerprint`, 512);
  requiredString(value.title, `${field}.title`, 240);
  optionalString(value.focus, `${field}.focus`, 240);
  optionalString(value.target, `${field}.target`, 240);
  const mode = requiredString(value.mode, `${field}.mode`, 32);
  if (!PRACTICE_MODES.has(mode)) {
    throw new HttpsError("invalid-argument", `${field}.mode is invalid.`);
  }
  optionalUUID(value.sessionID, `${field}.sessionID`);
  if (value.sessionID === undefined || value.sessionID === null ||
      typeof value.followed !== "boolean") {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  validateOptionalAdherenceVersion(
    value.adherenceSchemaVersion,
    `${field}.adherenceSchemaVersion`
  );
  const prescribedDemand = validateDemand(
    value.prescribedDemand,
    `${field}.prescribedDemand`,
    mode
  );
  const executedDemand = validateDemand(
    value.executedDemand,
    `${field}.executedDemand`,
    mode
  );
  if ((prescribedDemand !== null || executedDemand !== null) &&
      value.adherenceSchemaVersion !== RECOMMENDATION_ADHERENCE_SCHEMA_VERSION) {
    throw new HttpsError(
      "invalid-argument",
      `${field}.adherenceSchemaVersion is invalid.`
    );
  }
  if (value.followed === true && prescribedDemand !== null &&
      canonicalJSON(prescribedDemand) !== canonicalJSON(executedDemand)) {
    throw new HttpsError("invalid-argument", `${field}.followed is invalid.`);
  }
  boundedNumber(
    value.completedAt,
    `${field}.completedAt`,
    MIN_TIMESTAMP_SECONDS,
    MAX_TIMESTAMP_SECONDS
  );
  boundedNumber(value.scoreDelta, `${field}.scoreDelta`, -100, 100);
  if (value.hasComparableScore !== undefined &&
      value.hasComparableScore !== null &&
      typeof value.hasComparableScore !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      `${field}.hasComparableScore is invalid.`
    );
  }
  optionalBoundedNumber(
    value.fillerRateDelta,
    `${field}.fillerRateDelta`,
    -1_000,
    1_000
  );
  boundedNumber(value.fillerDelta, `${field}.fillerDelta`, -100_000, 100_000);
  boundedNumber(value.durationDelta, `${field}.durationDelta`, -86_400, 86_400);
  const comparisonSessionCount = value.comparisonSessionCount;
  if (comparisonSessionCount !== undefined && comparisonSessionCount !== null &&
      (!Number.isSafeInteger(comparisonSessionCount) ||
       (comparisonSessionCount as number) < 0 ||
       (comparisonSessionCount as number) > 5)) {
    throw new HttpsError(
      "invalid-argument",
      `${field}.comparisonSessionCount is invalid.`
    );
  }
  const comparisonSchemaVersion = value.comparisonSchemaVersion;
  if (comparisonSchemaVersion !== undefined &&
      comparisonSchemaVersion !== null && comparisonSchemaVersion !== 1 &&
      comparisonSchemaVersion !== 2) {
    throw new HttpsError(
      "invalid-argument",
      `${field}.comparisonSchemaVersion is invalid.`
    );
  }
  optionalBoundedNumber(value.wordsPerMinute, `${field}.wordsPerMinute`, 0, 1_000);
  optionalBoundedNumber(value.paceDelta, `${field}.paceDelta`, -1_000, 1_000);
  if (value.goal !== undefined && value.goal !== null &&
      !STYLE_GOALS.has(requiredString(value.goal, `${field}.goal`, 32))) {
    throw new HttpsError("invalid-argument", `${field}.goal is invalid.`);
  }
  optionalString(value.targetDimensionID, `${field}.targetDimensionID`, 120);
  optionalUUID(value.sourceSessionID, `${field}.sourceSessionID`);
  if (value.goalFollowUpResult !== undefined &&
      value.goalFollowUpResult !== null &&
      !FOLLOW_UP_RESULTS.has(requiredString(
        value.goalFollowUpResult,
        `${field}.goalFollowUpResult`,
        32
      ))) {
    throw new HttpsError(
      "invalid-argument",
      `${field}.goalFollowUpResult is invalid.`
    );
  }
  return value;
}

function validatedBody(pending: unknown, outcomes: unknown): RecommendationStateBody {
  if (!Array.isArray(outcomes) || outcomes.length > RECOMMENDATION_OUTCOME_LIMIT) {
    throw new HttpsError("invalid-argument", "outcomes is invalid.");
  }
  const validatedOutcomes = outcomes.map(validateOutcome);
  const outcomeIDs = new Set<string>();
  const sessionIDs = new Set<string>();
  for (const outcome of validatedOutcomes) {
    const outcomeID = outcome.id as string;
    const sessionID = outcome.sessionID as string;
    if (outcomeIDs.has(outcomeID) || sessionIDs.has(sessionID)) {
      throw new HttpsError("invalid-argument", "outcomes must be unique.");
    }
    outcomeIDs.add(outcomeID);
    sessionIDs.add(sessionID);
  }
  const body = {
    pendingExposure: validateExposure(pending),
    outcomes: validatedOutcomes,
  };
  if (Buffer.byteLength(JSON.stringify(body), "utf8") >
      RECOMMENDATION_STATE_MAX_BYTES) {
    throw new HttpsError("invalid-argument", "Recommendation state is too large.");
  }
  return body;
}

function validatedStoredBody(
  pending: unknown,
  outcomes: unknown
): RecommendationStateBody {
  try {
    return validatedBody(pending, outcomes);
  } catch {
    throw new HttpsError(
      "failed-precondition",
      "Recommendation state is malformed."
    );
  }
}

function canonicalJSON(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJSON).join(",")}]`;
  }
  if (isRecord(value)) {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonicalJSON(value[key])}`
    ).join(",")}}`;
  }
  return JSON.stringify(value) ?? "undefined";
}

function recommendationBodiesMatch(
  current: RecommendationStateBody,
  input: RecommendationStateBody
): boolean {
  return canonicalJSON({
    pendingExposure: current.pendingExposure,
    outcomes: current.outcomes,
  }) === canonicalJSON({
    pendingExposure: input.pendingExposure,
    outcomes: input.outcomes,
  });
}

/** Validates the exact public mutation envelope. */
export function validateRecommendationMutation(
  value: unknown
): RecommendationMutationInput {
  if (!isRecord(value) || !hasOnlyKeys(value, [
    "schemaVersion", "mutationID", "expectedRemoteRevision",
    "pendingExposure", "outcomes",
  ]) || value.schemaVersion !== RECOMMENDATION_STATE_SCHEMA_VERSION) {
    throw new HttpsError("invalid-argument", "Unsupported recommendation schema.");
  }
  const mutationID = requiredString(value.mutationID, "mutationID", 64);
  if (!UUID_PATTERN.test(mutationID)) {
    throw new HttpsError("invalid-argument", "mutationID must be a UUID.");
  }
  if (!Number.isSafeInteger(value.expectedRemoteRevision) ||
      (value.expectedRemoteRevision as number) < 0 ||
      (value.expectedRemoteRevision as number) >= Number.MAX_SAFE_INTEGER) {
    throw new HttpsError("invalid-argument", "Remote revision is invalid.");
  }
  return {
    schemaVersion: 1,
    mutationID,
    expectedRemoteRevision: value.expectedRemoteRevision as number,
    ...validatedBody(value.pendingExposure, value.outcomes),
  };
}

/** Reads an absent, exact legacy, or current versioned document. */
export function normalizeStoredRecommendationState(
  value: unknown
): RecommendationStateEnvelope {
  if (value === undefined || value === null) {
    return {
      schemaVersion: 1,
      remoteRevision: 0,
      lastMutationID: null,
      pendingExposure: null,
      outcomes: [],
    };
  }
  if (!isRecord(value)) {
    throw new HttpsError("failed-precondition", "Recommendation state is malformed.");
  }
  const isLegacy = Object.keys(value).every((key) =>
    key === "pendingExposure" || key === "outcomes"
  ) && Object.prototype.hasOwnProperty.call(value, "pendingExposure") &&
    Object.prototype.hasOwnProperty.call(value, "outcomes");
  if (isLegacy) {
    return {
      schemaVersion: 1,
      remoteRevision: 0,
      lastMutationID: null,
      ...validatedStoredBody(value.pendingExposure, value.outcomes),
    };
  }
  if (!hasOnlyKeys(value, [
    "schemaVersion", "remoteRevision", "lastMutationID", "pendingExposure",
    "outcomes", "updatedAt",
  ]) || value.schemaVersion !== RECOMMENDATION_STATE_SCHEMA_VERSION ||
      !Number.isSafeInteger(value.remoteRevision) ||
      (value.remoteRevision as number) < 1) {
    throw new HttpsError(
      "failed-precondition",
      "Recommendation state version is unsupported."
    );
  }
  let lastMutationID: string;
  try {
    lastMutationID = requiredString(
      value.lastMutationID,
      "lastMutationID",
      64
    );
  } catch {
    throw new HttpsError(
      "failed-precondition",
      "Recommendation state is malformed."
    );
  }
  if (!UUID_PATTERN.test(lastMutationID)) {
    throw new HttpsError("failed-precondition", "Recommendation state is malformed.");
  }
  return {
    schemaVersion: 1,
    remoteRevision: value.remoteRevision as number,
    lastMutationID,
    ...validatedStoredBody(value.pendingExposure, value.outcomes),
  };
}

/** Applies idempotency and compare-and-swap without touching Firestore. */
export function decideRecommendationMutation(
  current: RecommendationStateEnvelope,
  input: RecommendationMutationInput
): RecommendationMutationDecision {
  if (current.lastMutationID === input.mutationID) {
    if (!recommendationBodiesMatch(current, input)) {
      throw new HttpsError(
        "invalid-argument",
        "mutationID was already used for different recommendation state."
      );
    }
    return {status: "alreadyCommitted", state: current};
  }
  if (current.remoteRevision !== input.expectedRemoteRevision) {
    return {status: "conflict", state: current};
  }
  return {
    status: "committed",
    state: {
      schemaVersion: 1,
      remoteRevision: current.remoteRevision + 1,
      lastMutationID: input.mutationID,
      pendingExposure: input.pendingExposure,
      outcomes: input.outcomes,
    },
  };
}
