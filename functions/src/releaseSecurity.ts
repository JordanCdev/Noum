import {HttpsError} from "firebase-functions/v2/https";

export const TRANSCRIPTION_TOKEN_MINUTE_LIMIT = 6;
export const TRANSCRIPTION_TOKEN_HOUR_LIMIT = 60;
export const RECENT_AUTH_MAX_AGE_MS = 5 * 60 * 1_000;
/** Maximum lifetime of a Firebase Auth ID token after issuance. */
export const FIREBASE_ID_TOKEN_MAX_LIFETIME_MS = 60 * 60 * 1_000;
/** Two full token windows keep deletion fenced through clock skew and retry. */
export const ACCOUNT_DELETION_TOMBSTONE_RETENTION_MS =
  2 * FIREBASE_ID_TOKEN_MAX_LIFETIME_MS;
export const ACCOUNT_DELETION_RECONCILIATION_MIN_AGE_MS = 30 * 60 * 1_000;
export const ACCOUNT_DELETION_RECONCILIATION_BATCH_SIZE = 100;

const DEEPGRAM_GRANT_URL = "https://api.deepgram.com/v1/auth/grant";
const MAX_CLOCK_SKEW_MS = 60_000;
const MAX_DEEPGRAM_TOKEN_CHARS = 8_192;
const MIN_DEEPGRAM_TOKEN_CHARS = 64;
const DEEPGRAM_GRANT_SECONDS = 30;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Persisted fixed-window counters for one protected operation. */
export interface WindowRateState {
  minuteBucket: number;
  minuteCount: number;
  hourBucket: number;
  hourCount: number;
  updatedAtMs: number;
}

/** Result produced inside a Firestore transaction. */
export interface WindowRateDecision {
  allowed: boolean;
  state: WindowRateState;
}

/** Public short-lived transcription credential contract. */
export interface TranscriptionTokenPayload {
  provider: "deepgram";
  accessToken: string;
  expiresAt: string;
}

/** Provider response before it crosses the trusted backend boundary. */
export interface DeepgramGrantPayload {
  access_token: string;
  expires_in: number;
}

/** Safe failure categories. Provider response bodies are never retained. */
export type ProviderGrantFailure =
  | "configuration"
  | "network"
  | "provider-http"
  | "provider-response";

/** Content-free provider failure used by the callable error mapper. */
export class ProviderGrantError extends Error {
  /** @param {ProviderGrantFailure} reason Safe provider failure category. */
  constructor(readonly reason: ProviderGrantFailure) {
    super("Temporary speech credential unavailable.");
    this.name = "ProviderGrantError";
  }
}

/** Fetch seam used by production and deterministic unit tests. */
export interface DeepgramGrantDependencies {
  fetchImpl?: typeof fetch;
  nowMs?: number;
  signal?: AbortSignal;
}

/**
 * Ordered deletion steps. The exact social worklist is a data finalizer: it
 * runs only after every dependent cleanup succeeds. Auth follows it, while
 * the deletion fence remains and is finalized as a retained completed marker.
 */
const ACCOUNT_DELETION_DEPENDENT_STEPS = [
  "userTree",
  "publicProfile",
  "leagueMemberships",
  "challenges",
  "friendInvites",
  "friendLinks",
  "competitiveObservations",
  "rateLimits",
] as const;

export const ACCOUNT_DELETION_STEPS = [
  ...ACCOUNT_DELETION_DEPENDENT_STEPS,
  "socialReferenceManifest",
  "authUser",
  "completedTombstone",
] as const;

export type AccountDeletionStep = typeof ACCOUNT_DELETION_STEPS[number];

/** Injected deletion work. It keeps orchestration independently testable. */
export type AccountDeletionWork = Record<
  AccountDeletionStep,
  () => Promise<void>
>;

/** Typed partial failure without underlying SDK errors or user content. */
export class AccountDeletionPartialError extends Error {
  /** @param {AccountDeletionStep[]} failedSteps Incomplete resource groups. */
  constructor(readonly failedSteps: AccountDeletionStep[]) {
    super("Account deletion did not complete.");
    this.name = "AccountDeletionPartialError";
  }
}

/**
 * True only for an unboxed JSON object.
 * @param {unknown} value Candidate JSON value.
 * @return {boolean} Whether the value is a record.
 */
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * True only when a stored server record has exactly the allowed fields.
 * @param {Record<string, unknown>} value Stored server record.
 * @param {string[]} expected Allowed field names.
 * @return {boolean} Whether the record has exactly the allowed fields.
 */
function hasExactKeys(
  value: Record<string, unknown>,
  expected: readonly string[]
): boolean {
  const actual = Object.keys(value).sort();
  return actual.length === expected.length &&
    actual.every((key, index) => key === expected[index]);
}

/**
 * Validates a no-argument, versioned callable request.
 * Extra fields are rejected so a client-supplied account ID can never become
 * an accidental source of authority.
 * @param {unknown} data Raw callable payload.
 * @return {void}
 */
export function validateTranscriptionTokenRequest(data: unknown): void {
  if (!isRecord(data) || data.schemaVersion !== 1) {
    throw new HttpsError("invalid-argument", "Unsupported schema version.");
  }
  const keys = Object.keys(data);
  if (keys.length !== 1 || keys[0] !== "schemaVersion") {
    throw new HttpsError("invalid-argument", "Request contains extra fields.");
  }
}

/** Versioned destructive request bound to one expected authenticated UID. */
export interface DeleteAccountRequest {
  schemaVersion: 2 | 3;
  requestID: string;
  expectedAccountID: string;
  appleAuthorizationRevoked: boolean;
}

/** Minimal server-owned marker retained beyond any stale Firebase ID token. */
export interface CompletedAccountDeletionTombstone {
  schemaVersion: 2;
  status: "complete";
  accountID: string;
  requestID: string;
  completedAt: Date;
  expiresAt: Date;
}

/** Admission decision for one server-owned deletion-fence snapshot. */
export type AccountDeletionStateAdmission =
  | "createPending"
  | "resumePending"
  | "alreadyCompleted"
  | "invalid";

/** Exact stale pending row eligible for scheduled full-worklist resumption. */
export interface PendingAccountDeletionReconciliationCandidate {
  accountID: string;
  requestID: string;
  appleRevocationRequiredAtAdmission: boolean;
  appleAuthorizationRevoked: boolean;
}

/** Timestamp projection shared by Firestore and deterministic tests. */
export type AccountDeletionTimestampMilliseconds =
  (value: unknown) => number | null;

/**
 * Builds the content-free terminal deletion fence stored for TTL cleanup.
 * Firestore rules intentionally gate on existence, not expiresAt, so deletion
 * stays denied until TTL or an authorized operator actually removes the row.
 * @param {string} accountID Deleted Firebase Auth UID.
 * @param {string} requestID Client correlation identifier.
 * @param {number} completedAtMs Trusted server completion time.
 * @return {CompletedAccountDeletionTombstone} Minimal retained marker.
 */
export function completedAccountDeletionTombstone(
  accountID: string,
  requestID: string,
  completedAtMs: number
): CompletedAccountDeletionTombstone {
  if (!Number.isFinite(completedAtMs) || completedAtMs < 0) {
    throw new Error("Invalid account deletion completion time.");
  }
  return {
    schemaVersion: 2,
    status: "complete",
    accountID,
    requestID,
    completedAt: new Date(completedAtMs),
    expiresAt: new Date(
      completedAtMs + ACCOUNT_DELETION_TOMBSTONE_RETENTION_MS
    ),
  };
}

/**
 * Validates the exact persisted fence for one authenticated deletion request.
 * A coherent completed marker is terminal; any different request, account,
 * schema, status, timestamp interval, or extra field fails closed.
 * @param {unknown} data Stored Firestore document, or undefined when absent.
 * @param {string} accountID Verified Firebase Auth UID and document ID.
 * @param {string} requestID Validated durable request UUID.
 * @param {AccountDeletionTimestampMilliseconds} dateMilliseconds
 * Firestore timestamp projection seam.
 * @return {AccountDeletionStateAdmission} Safe request disposition.
 */
export function accountDeletionStateAdmission(
  data: unknown,
  accountID: string,
  requestID: string,
  dateMilliseconds: AccountDeletionTimestampMilliseconds
): AccountDeletionStateAdmission {
  if (data === undefined) return "createPending";
  if (!isRecord(data) ||
      data.accountID !== accountID || data.requestID !== requestID) {
    return "invalid";
  }
  if (data.status === "pending") {
    const legacyKeys = [
      "accountID", "requestID", "schemaVersion", "startedAt", "status",
      "updatedAt",
    ];
    const currentKeys = [
      "accountID", "appleAuthorizationRevoked",
      "appleRevocationRequiredAtAdmission", "requestID", "schemaVersion",
      "startedAt", "status", "updatedAt",
    ];
    const legacy = data.schemaVersion === 2 && hasExactKeys(data, legacyKeys);
    const current = data.schemaVersion === 3 &&
      hasExactKeys(data, currentKeys) &&
      typeof data.appleRevocationRequiredAtAdmission === "boolean" &&
      typeof data.appleAuthorizationRevoked === "boolean" &&
      (!data.appleRevocationRequiredAtAdmission ||
        data.appleAuthorizationRevoked) &&
      (data.appleRevocationRequiredAtAdmission ||
        !data.appleAuthorizationRevoked);
    if (!legacy && !current) return "invalid";
    const startedAtMs = dateMilliseconds(data.startedAt);
    const updatedAtMs = dateMilliseconds(data.updatedAt);
    return startedAtMs !== null && updatedAtMs !== null &&
      startedAtMs <= updatedAtMs ? "resumePending" : "invalid";
  }
  if (data.status === "complete" && data.schemaVersion === 2) {
    if (!hasExactKeys(data, [
      "accountID", "completedAt", "expiresAt", "requestID", "schemaVersion",
      "status",
    ])) return "invalid";
    const completedAtMs = dateMilliseconds(data.completedAt);
    const expiresAtMs = dateMilliseconds(data.expiresAt);
    return completedAtMs !== null && expiresAtMs !== null &&
      expiresAtMs - completedAtMs ===
        ACCOUNT_DELETION_TOMBSTONE_RETENTION_MS ?
      "alreadyCompleted" : "invalid";
  }
  return "invalid";
}

/**
 * Selects a stale exact pending row for scheduled full-worklist resumption.
 * Age only limits overlap with an active callable; the accepted server marker,
 * not age or current Auth existence, carries the durable deletion authority.
 * @param {unknown} data Stored pending marker.
 * @param {string} documentID Firestore document ID.
 * @param {number} nowMs Trusted server time.
 * @param {AccountDeletionTimestampMilliseconds} dateMilliseconds
 * Firestore timestamp projection seam.
 * @return {PendingAccountDeletionReconciliationCandidate|null} Safe candidate.
 */
export function pendingAccountDeletionReconciliationCandidate(
  data: unknown,
  documentID: string,
  nowMs: number,
  dateMilliseconds: AccountDeletionTimestampMilliseconds
): PendingAccountDeletionReconciliationCandidate | null {
  if (!Number.isFinite(nowMs) || !isRecord(data) ||
      data.schemaVersion !== 3 ||
      typeof data.accountID !== "string" ||
      typeof data.requestID !== "string" ||
      typeof data.appleRevocationRequiredAtAdmission !== "boolean" ||
      typeof data.appleAuthorizationRevoked !== "boolean" ||
      data.accountID !== documentID || !UUID_PATTERN.test(data.requestID) ||
      accountDeletionStateAdmission(
        data,
        documentID,
        data.requestID,
        dateMilliseconds
      ) !== "resumePending") return null;
  const updatedAtMs = dateMilliseconds(data.updatedAt);
  if (updatedAtMs === null ||
      nowMs - updatedAtMs < ACCOUNT_DELETION_RECONCILIATION_MIN_AGE_MS) {
    return null;
  }
  return {
    accountID: documentID,
    requestID: data.requestID,
    appleRevocationRequiredAtAdmission:
      data.appleRevocationRequiredAtAdmission,
    appleAuthorizationRevoked: data.appleAuthorizationRevoked,
  };
}

/**
 * Validates the correlation identifier and expected-user binding on a
 * destructive account request. The expected ID is not authority; callers must
 * compare it exactly with the verified callable auth UID before any work.
 * @param {unknown} data Raw callable payload.
 * @return {DeleteAccountRequest} Validated request binding.
 */
export function validateDeleteAccountRequest(
  data: unknown
): DeleteAccountRequest {
  if (!isRecord(data) ||
      (data.schemaVersion !== 2 && data.schemaVersion !== 3) ||
      typeof data.requestID !== "string" ||
      typeof data.expectedAccountID !== "string") {
    throw new HttpsError("invalid-argument", "Invalid deletion request.");
  }
  const schemaVersion = data.schemaVersion;
  const isCurrent = schemaVersion === 3;
  if (isCurrent && typeof data.appleAuthorizationRevoked !== "boolean") {
    throw new HttpsError("invalid-argument", "Invalid deletion request.");
  }
  const requestID = data.requestID.trim();
  const expectedAccountID = data.expectedAccountID;
  const keys = Object.keys(data).sort();
  const expectedKeys = isCurrent ? [
    "appleAuthorizationRevoked",
    "expectedAccountID",
    "requestID",
    "schemaVersion",
  ] : ["expectedAccountID", "requestID", "schemaVersion"];
  if (keys.length !== expectedKeys.length ||
      !keys.every((key, index) => key === expectedKeys[index]) ||
      !UUID_PATTERN.test(requestID) || expectedAccountID.length < 1 ||
      expectedAccountID.length > 128 ||
      expectedAccountID !== expectedAccountID.trim()) {
    throw new HttpsError("invalid-argument", "Invalid deletion request.");
  }
  return {
    schemaVersion,
    requestID,
    expectedAccountID,
    appleAuthorizationRevoked:
      isCurrent && data.appleAuthorizationRevoked === true,
  };
}

/**
 * Requires the current client capability after that client has completed
 * Firebase's authorization-code revocation flow. This is not a cryptographic
 * revocation receipt; it binds the versioned flow and prevents every legacy
 * production client from bypassing the new Apple deletion gate.
 * @param {string[]} providerIDs Server-read Firebase provider IDs.
 * @param {DeleteAccountRequest} request Validated versioned request.
 * @return {void}
 */
export function assertAppleRevocationAttested(
  providerIDs: readonly string[],
  request: DeleteAccountRequest
): void {
  if (providerIDs.includes("apple.com") &&
      (request.schemaVersion !== 3 ||
       request.appleAuthorizationRevoked !== true)) {
    throw new HttpsError(
      "failed-precondition",
      "Sign in with Apple access must be revoked before account deletion.",
      {reason: "apple-revocation-unavailable"}
    );
  }
}

/**
 * Requires the client binding to name the verified callable identity exactly.
 * @param {string} expectedAccountID Validated request binding.
 * @param {string} authenticatedUID Verified callable auth UID.
 * @return {void}
 */
export function assertDeleteAccountRequestIdentity(
  expectedAccountID: string,
  authenticatedUID: string
): void {
  if (expectedAccountID !== authenticatedUID) {
    throw new HttpsError(
      "permission-denied",
      "Account deletion identity did not match the secure session."
    );
  }
}

/**
 * Computes fixed minute/hour counters for one protected operation.
 * @param {Partial<WindowRateState>|undefined} current Stored counters.
 * @param {number} nowMs Current Unix time in milliseconds.
 * @param {number} minuteLimit Maximum requests in one minute bucket.
 * @param {number} hourLimit Maximum requests in one hour bucket.
 * @return {WindowRateDecision} Updated counters and allow decision.
 */
export function nextWindowRateState(
  current: Partial<WindowRateState> | undefined,
  nowMs: number,
  minuteLimit: number,
  hourLimit: number
): WindowRateDecision {
  if (!Number.isFinite(nowMs) || nowMs < 0 ||
      !Number.isInteger(minuteLimit) || minuteLimit < 1 ||
      !Number.isInteger(hourLimit) || hourLimit < minuteLimit) {
    throw new Error("Invalid rate-limit configuration.");
  }
  const minuteBucket = Math.floor(nowMs / 60_000);
  const hourBucket = Math.floor(nowMs / 3_600_000);
  const minuteCount = current?.minuteBucket === minuteBucket ?
    Math.max(0, current.minuteCount ?? 0) + 1 : 1;
  const hourCount = current?.hourBucket === hourBucket ?
    Math.max(0, current.hourCount ?? 0) + 1 : 1;
  return {
    allowed: minuteCount <= minuteLimit && hourCount <= hourLimit,
    state: {
      minuteBucket,
      minuteCount,
      hourBucket,
      hourCount,
      updatedAtMs: nowMs,
    },
  };
}

/**
 * Requires a recent Firebase sign-in before destructive account work starts.
 * @param {unknown} authTimeSeconds Verified token authentication time.
 * @param {number} nowMs Current Unix time in milliseconds.
 * @param {number} maxAgeMs Maximum accepted authentication age.
 * @return {void}
 */
export function assertRecentAuthentication(
  authTimeSeconds: unknown,
  nowMs: number,
  maxAgeMs = RECENT_AUTH_MAX_AGE_MS
): void {
  if (typeof authTimeSeconds !== "number" ||
      !Number.isFinite(authTimeSeconds) || authTimeSeconds <= 0 ||
      !Number.isFinite(nowMs) || nowMs < 0) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in again before deleting your account."
    );
  }
  const ageMs = nowMs - authTimeSeconds * 1_000;
  if (ageMs > maxAgeMs || ageMs < -MAX_CLOCK_SKEW_MS) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in again before deleting your account."
    );
  }
}

/**
 * Selects the recent-auth claim for account deletion. Durable providers must
 * reauthenticate and update auth_time. Anonymous users have no reusable
 * credential, so a force-refreshed, verified token's iat is the strongest
 * available freshness proof.
 * @param {unknown} token Verified Firebase decoded ID token.
 * @return {unknown} Timestamp claim to validate.
 */
export function deletionAuthenticationTime(token: unknown): unknown {
  if (!isRecord(token)) return undefined;
  const firebase = token.firebase;
  if (isRecord(firebase) && firebase.sign_in_provider === "anonymous") {
    return token.iat;
  }
  return token.auth_time;
}

/**
 * Strictly validates the temporary JWT returned by Deepgram.
 * @param {unknown} value Provider JSON response.
 * @param {number} nowMs Request timestamp used to derive expiry.
 * @return {TranscriptionTokenPayload} Validated client response.
 */
export function validateDeepgramGrantResponse(
  value: unknown,
  nowMs: number
): TranscriptionTokenPayload {
  if (!isRecord(value) || typeof value.access_token !== "string" ||
      typeof value.expires_in !== "number") {
    throw new ProviderGrantError("provider-response");
  }
  const accessToken = value.access_token.trim();
  const jwtParts = accessToken.split(".");
  const isJWT = jwtParts.length === 3 && jwtParts.every((part) =>
    part.length > 0 && /^[A-Za-z0-9_-]+$/.test(part)
  );
  if (!isJWT || accessToken.length < MIN_DEEPGRAM_TOKEN_CHARS ||
      accessToken.length > MAX_DEEPGRAM_TOKEN_CHARS ||
      !Number.isFinite(value.expires_in) ||
      value.expires_in !== DEEPGRAM_GRANT_SECONDS ||
      !Number.isFinite(nowMs) || nowMs < 0) {
    throw new ProviderGrantError("provider-response");
  }
  return {
    provider: "deepgram",
    accessToken,
    expiresAt: new Date(nowMs + Math.ceil(value.expires_in * 1_000))
      .toISOString(),
  };
}

/**
 * Exchanges the server-held management key for Deepgram's default 30-second
 * usage token. The long-lived key never appears in a return value or error.
 * @param {string} managementKey Server-held provider management key.
 * @param {DeepgramGrantDependencies} dependencies Deterministic I/O seams.
 * @return {Promise<TranscriptionTokenPayload>} Short-lived client token.
 */
export async function grantDeepgramTranscriptionToken(
  managementKey: string,
  dependencies: DeepgramGrantDependencies = {}
): Promise<TranscriptionTokenPayload> {
  const key = managementKey.trim();
  if (key.length < 16 || key.length > 4_096 || /\s/.test(key)) {
    throw new ProviderGrantError("configuration");
  }
  const fetchImpl = dependencies.fetchImpl ?? fetch;
  let response: Response;
  try {
    response = await fetchImpl(DEEPGRAM_GRANT_URL, {
      method: "POST",
      headers: {
        "authorization": `Token ${key}`,
        "content-type": "application/json",
      },
      body: "{}",
      signal: dependencies.signal,
    });
  } catch {
    throw new ProviderGrantError("network");
  }
  if (!response.ok) {
    throw new ProviderGrantError("provider-http");
  }
  let body: unknown;
  try {
    body = await response.json();
  } catch {
    throw new ProviderGrantError("provider-response");
  }
  return validateDeepgramGrantResponse(body, dependencies.nowMs ?? Date.now());
}

/**
 * Builds the only metadata permitted in transcription-token logs.
 * @param {string} status Safe operation status.
 * @param {number} latencyMs End-to-end latency.
 * @param {number|undefined} expiresIn Token lifetime when successful.
 * @return {Record<string, unknown>} Content-free log fields.
 */
export function transcriptionTokenLogMetadata(
  status: string,
  latencyMs: number,
  expiresIn?: number
): Record<string, unknown> {
  return {
    operation: "transcriptionToken",
    provider: "deepgram",
    status,
    latencyMs,
    ...(expiresIn === undefined ? {} : {expiresIn}),
  };
}

/**
 * Builds content-free deletion metadata. No UID or SDK error is included.
 * @param {string} requestID Client correlation identifier.
 * @param {string} status Safe operation status.
 * @param {number} latencyMs End-to-end latency.
 * @param {AccountDeletionStep[]} failedSteps Incomplete groups.
 * @return {Record<string, unknown>} Content-free log fields.
 */
export function accountDeletionLogMetadata(
  requestID: string,
  status: string,
  latencyMs: number,
  failedSteps: readonly AccountDeletionStep[] = []
): Record<string, unknown> {
  return {
    operation: "deleteAccount",
    requestID,
    status,
    latencyMs,
    failedSteps: [...failedSteps],
  };
}

/**
 * Runs all dependent cleanup steps even when one fails. The exact worklist
 * and Auth user finalize strictly in that order after every dependent cleanup
 * succeeds. Completed-marker finalization remains a required reported step;
 * when it fails, the pending fence stays durable for scheduled reconciliation.
 * @param {AccountDeletionWork} work Injected deletion operations.
 * @return {Promise<void>} Resolves only after complete deletion.
 */
export async function executeAccountDeletionPlan(
  work: AccountDeletionWork
): Promise<void> {
  const failures: AccountDeletionStep[] = [];
  for (const step of ACCOUNT_DELETION_DEPENDENT_STEPS) {
    try {
      await work[step]();
    } catch {
      failures.push(step);
    }
  }
  if (failures.length > 0) {
    throw new AccountDeletionPartialError(failures);
  }
  for (const step of ["socialReferenceManifest", "authUser"] as const) {
    try {
      await work[step]();
    } catch {
      throw new AccountDeletionPartialError([step]);
    }
  }
  try {
    await work.completedTombstone();
  } catch {
    throw new AccountDeletionPartialError(["completedTombstone"]);
  }
}
