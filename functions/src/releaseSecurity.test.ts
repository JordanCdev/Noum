import assert from "node:assert/strict";
import test from "node:test";
import {
  ACCOUNT_DELETION_STEPS,
  AccountDeletionPartialError,
  type AccountDeletionStep,
  type AccountDeletionWork,
  accountDeletionLogMetadata,
  assertAppleRevocationSupported,
  assertRecentAuthentication,
  deletionAuthenticationTime,
  executeAccountDeletionPlan,
  grantDeepgramTranscriptionToken,
  nextWindowRateState,
  ProviderGrantError,
  TRANSCRIPTION_TOKEN_HOUR_LIMIT,
  TRANSCRIPTION_TOKEN_MINUTE_LIMIT,
  transcriptionTokenLogMetadata,
  validateDeepgramGrantResponse,
  validateDeleteAccountRequest,
  validateTranscriptionTokenRequest,
} from "./releaseSecurity.js";

const requestID = "2cb446d8-4f39-43a6-a95c-2486e47155bc";
const managementKey = "server-management-key-fixture-123";
const accessToken = ["a".repeat(32), "b".repeat(32), "c".repeat(32)]
  .join(".");

test("transcription token input rejects client authority fields", () => {
  assert.doesNotThrow(() => validateTranscriptionTokenRequest({
    schemaVersion: 1,
  }));
  for (const value of [
    undefined,
    {},
    {schemaVersion: 2},
    {schemaVersion: 1, accountID: "another-user"},
    {schemaVersion: 1, ttlSeconds: 3_600},
  ]) {
    assert.throws(() => validateTranscriptionTokenRequest(value));
  }
});

test("deletion input requires one UUID request ID and no account ID", () => {
  assert.equal(validateDeleteAccountRequest({
    schemaVersion: 1,
    requestID,
  }), requestID);
  for (const value of [
    {schemaVersion: 1},
    {schemaVersion: 1, requestID: "not-a-uuid"},
    {schemaVersion: 1, requestID, accountID: "another-user"},
  ]) {
    assert.throws(() => validateDeleteAccountRequest(value));
  }
});

test("transcription rate limit rejects minute and hour overflow", () => {
  const minuteStart = 6 * 3_600_000;
  let decision = nextWindowRateState(
    undefined,
    minuteStart,
    TRANSCRIPTION_TOKEN_MINUTE_LIMIT,
    TRANSCRIPTION_TOKEN_HOUR_LIMIT
  );
  for (let count = 2; count <= TRANSCRIPTION_TOKEN_MINUTE_LIMIT; count += 1) {
    decision = nextWindowRateState(
      decision.state,
      minuteStart,
      TRANSCRIPTION_TOKEN_MINUTE_LIMIT,
      TRANSCRIPTION_TOKEN_HOUR_LIMIT
    );
    assert.equal(decision.allowed, true);
  }
  decision = nextWindowRateState(
    decision.state,
    minuteStart,
    TRANSCRIPTION_TOKEN_MINUTE_LIMIT,
    TRANSCRIPTION_TOKEN_HOUR_LIMIT
  );
  assert.equal(decision.allowed, false);

  let hourly = nextWindowRateState(undefined, minuteStart, 60, 60);
  for (let count = 2; count <= 60; count += 1) {
    hourly = nextWindowRateState(
      hourly.state,
      minuteStart + (count - 1) * 30_000,
      60,
      60
    );
  }
  assert.equal(hourly.allowed, true);
  assert.equal(nextWindowRateState(
    hourly.state,
    minuteStart + 59 * 30_000,
    60,
    60
  ).allowed, false);
});

test("transcription rate windows reset independently", () => {
  const first = nextWindowRateState(undefined, 3_600_000, 6, 60);
  const nextMinute = nextWindowRateState(first.state, 3_660_000, 6, 60);
  assert.equal(nextMinute.state.minuteCount, 1);
  assert.equal(nextMinute.state.hourCount, 2);
  const nextHour = nextWindowRateState(
    nextMinute.state,
    7_200_000,
    6,
    60
  );
  assert.equal(nextHour.state.minuteCount, 1);
  assert.equal(nextHour.state.hourCount, 1);
});

test("Deepgram grant response is strict and returns an ISO expiry", () => {
  const nowMs = Date.UTC(2026, 6, 11, 12, 0, 0);
  assert.deepEqual(validateDeepgramGrantResponse({
    access_token: accessToken,
    expires_in: 30,
  }, nowMs), {
    provider: "deepgram",
    accessToken,
    expiresAt: "2026-07-11T12:00:30.000Z",
  });
  for (const value of [
    {access_token: "long-lived-key", expires_in: 30},
    {access_token: accessToken, expires_in: 0},
    {access_token: accessToken, expires_in: 60},
    {access_token: accessToken, expires_in: 3_600},
    {access_token: accessToken, expires_in: "30"},
    {token: accessToken, expires_in: 30},
  ]) {
    assert.throws(
      () => validateDeepgramGrantResponse(value, nowMs),
      ProviderGrantError
    );
  }
});

test(
  "Deepgram exchange sends the secret once and returns no long-lived key",
  async () => {
    let seenURL = "";
    let seenInit: RequestInit | undefined;
    const result = await grantDeepgramTranscriptionToken(managementKey, {
      nowMs: Date.UTC(2026, 6, 11, 12, 0, 0),
      fetchImpl: async (input, init) => {
        seenURL = input.toString();
        seenInit = init;
        return new Response(JSON.stringify({
          access_token: accessToken,
          expires_in: 30,
        }), {status: 200, headers: {"content-type": "application/json"}});
      },
    });
    assert.equal(seenURL, "https://api.deepgram.com/v1/auth/grant");
    assert.equal(seenInit?.method, "POST");
    assert.equal(seenInit?.body, "{}");
    assert.equal(
      new Headers(seenInit?.headers).get("authorization"),
      `Token ${managementKey}`
    );
    assert.equal(JSON.stringify(result).includes(managementKey), false);
    assert.deepEqual(Object.keys(result).sort(), [
      "accessToken", "expiresAt", "provider",
    ]);
  }
);

test("Deepgram HTTP and malformed JSON failures are content-free", async () => {
  const providerBody = "provider-secret-response";
  await assert.rejects(
    () => grantDeepgramTranscriptionToken(managementKey, {
      fetchImpl: async () => new Response(providerBody, {status: 403}),
    }),
    (error: unknown) => error instanceof ProviderGrantError &&
      error.reason === "provider-http" &&
      !error.message.includes(providerBody) &&
      !error.message.includes(managementKey)
  );
  await assert.rejects(
    () => grantDeepgramTranscriptionToken(managementKey, {
      fetchImpl: async () => new Response("not-json", {status: 200}),
    }),
    (error: unknown) => error instanceof ProviderGrantError &&
      error.reason === "provider-response"
  );
});

test("security logs contain no provider credential material", () => {
  const tokenLog = transcriptionTokenLogMetadata("ok", 120, 30);
  const deletionLog = accountDeletionLogMetadata(
    requestID,
    "partial-failure",
    250,
    ["challenges"]
  );
  const serialized = JSON.stringify({tokenLog, deletionLog});
  assert.equal(serialized.includes(managementKey), false);
  assert.equal(serialized.includes(accessToken), false);
  assert.deepEqual(Object.keys(tokenLog).sort(), [
    "expiresIn", "latencyMs", "operation", "provider", "status",
  ]);
});

test("recent authentication rejects missing, stale, and future claims", () => {
  const nowMs = Date.UTC(2026, 6, 11, 12, 0, 0);
  assert.doesNotThrow(() => assertRecentAuthentication(
    nowMs / 1_000 - 299,
    nowMs
  ));
  for (const authTime of [
    undefined,
    nowMs / 1_000 - 301,
    nowMs / 1_000 + 61,
  ]) {
    assert.throws(() => assertRecentAuthentication(authTime, nowMs));
  }
});

test(
  "anonymous deletion uses refreshed iat while durable auth uses auth_time",
  () => {
    assert.equal(deletionAuthenticationTime({
      auth_time: 100,
      iat: 200,
      firebase: {sign_in_provider: "anonymous"},
    }), 200);
    assert.equal(deletionAuthenticationTime({
      auth_time: 100,
      iat: 200,
      firebase: {sign_in_provider: "google.com"},
    }), 100);
    assert.equal(deletionAuthenticationTime({
      iat: 200,
      firebase: {sign_in_provider: "google.com"},
    }), undefined);
  }
);

test("Apple-linked deletion is blocked before a plan can run", () => {
  assert.doesNotThrow(() => assertAppleRevocationSupported([
    "password",
    "google.com",
  ]));
  assert.throws(() => assertAppleRevocationSupported([
    "google.com",
    "apple.com",
  ]));
});

/**
 * Creates deterministic work functions and captures execution order.
 * @param {AccountDeletionStep[]} calls Mutable execution record.
 * @param {AccountDeletionStep[]} failingSteps Injected failures.
 * @return {AccountDeletionWork} Deterministic deletion operations.
 */
function deletionWork(
  calls: AccountDeletionStep[],
  failingSteps: readonly AccountDeletionStep[] = []
): AccountDeletionWork {
  return Object.fromEntries(ACCOUNT_DELETION_STEPS.map((step) => [
    step,
    async () => {
      calls.push(step);
      if (failingSteps.includes(step)) throw new Error("fixture failure");
    },
  ])) as AccountDeletionWork;
}

test("deletion plan finalizes references, Auth, then tombstone", async () => {
  const calls: AccountDeletionStep[] = [];
  await executeAccountDeletionPlan(deletionWork(calls));
  assert.deepEqual(calls, ACCOUNT_DELETION_STEPS);
  assert.deepEqual(calls.slice(-3), [
    "socialReferenceManifest",
    "authUser",
    "deletionTombstone",
  ]);
});

test(
  "deletion plan finishes data cleanup but preserves Auth on failure",
  async () => {
    const calls: AccountDeletionStep[] = [];
    await assert.rejects(
      () => executeAccountDeletionPlan(deletionWork(
        calls,
        ["publicProfile", "challenges"]
      )),
      (error: unknown) => error instanceof AccountDeletionPartialError &&
        JSON.stringify(error.failedSteps) ===
          JSON.stringify(["publicProfile", "challenges"])
    );
    assert.deepEqual(calls, ACCOUNT_DELETION_STEPS.slice(0, -3));
    assert.equal(calls.includes("socialReferenceManifest"), false);
    assert.equal(calls.includes("authUser"), false);
    assert.equal(calls.includes("deletionTombstone"), false);
  }
);

test("manifest finalization failure keeps Auth and tombstone", async () => {
  const calls: AccountDeletionStep[] = [];
  await assert.rejects(
    () => executeAccountDeletionPlan(deletionWork(
      calls,
      ["socialReferenceManifest"]
    )),
    (error: unknown) => error instanceof AccountDeletionPartialError &&
      error.failedSteps[0] === "socialReferenceManifest"
  );
  assert.equal(calls.includes("authUser"), false);
  assert.equal(calls.includes("deletionTombstone"), false);
});

test(
  "deletion plan reports an Auth failure after all data succeeds",
  async () => {
    const calls: AccountDeletionStep[] = [];
    await assert.rejects(
      () => executeAccountDeletionPlan(deletionWork(calls, ["authUser"])),
      (error: unknown) => error instanceof AccountDeletionPartialError &&
        error.failedSteps.length === 1 &&
        error.failedSteps[0] === "authUser"
    );
    assert.deepEqual(calls, ACCOUNT_DELETION_STEPS.slice(0, -1));
    assert.equal(calls.includes("deletionTombstone"), false);
  }
);
