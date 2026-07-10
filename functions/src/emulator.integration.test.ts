import assert from "node:assert/strict";
import test from "node:test";

const projectID = process.env.GCLOUD_PROJECT ?? "noum-d0b6f";
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";
const region = "europe-west2";
const preflightURL =
  `http://${functionsHost}/${projectID}/${region}/coachChatAvailability`;
const coachURL = `http://${functionsHost}/${projectID}/${region}/coachChat`;

interface EmulatorIdentity {
  idToken: string;
  localId: string;
}

interface CallableStreamFrame {
  message?: {type?: string; requestID?: string; text?: string};
  result?: {
    requestID?: string;
    qualityTier?: string;
    model?: string;
    finishReason?: string;
  };
}

/** Creates an anonymous account in the isolated Auth emulator. */
async function anonymousIdentity(): Promise<EmulatorIdentity> {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/` +
      "accounts:signUp?key=fake-api-key",
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({returnSecureToken: true}),
    }
  );
  assert.equal(response.ok, true);
  const value = await response.json() as Partial<EmulatorIdentity>;
  assert.equal(typeof value.idToken, "string");
  assert.equal(typeof value.localId, "string");
  return value as EmulatorIdentity;
}

/**
 * Builds an unsigned local-only token decoded by the Functions emulator.
 * @return {string} Local App Check fixture token.
 */
function localAppCheckToken(): string {
  const appID = "1:381934683469:ios:b0b44845c0e98cde356304";
  const encode = (value: object): string => Buffer
    .from(JSON.stringify(value))
    .toString("base64url");
  return `${encode({alg: "none", typ: "JWT"})}.` +
    `${encode({sub: appID, app_id: appID})}.`;
}

/**
 * Calls a JSON callable endpoint without exposing local emulator tokens.
 * @param {string} url Callable emulator endpoint.
 * @param {unknown} data Callable data payload.
 * @param {EmulatorIdentity|undefined} identity Optional emulator identity.
 * @param {boolean} includeAppCheck Whether to include local App Check.
 * @param {boolean} acceptStreaming Whether to request streamed callable data.
 * @return {Promise<Response>} Callable HTTP response.
 */
async function callable(
  url: string,
  data: unknown,
  identity?: EmulatorIdentity,
  includeAppCheck = false,
  acceptStreaming = false
): Promise<Response> {
  const headers: Record<string, string> = {
    "content-type": "application/json",
  };
  if (identity) headers.authorization = `Bearer ${identity.idToken}`;
  if (includeAppCheck) headers["x-firebase-appcheck"] = localAppCheckToken();
  if (acceptStreaming) headers.accept = "text/event-stream";
  return fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify({data}),
  });
}

/**
 * Decodes the callable streaming wire format emitted by the Functions SDK.
 * The local emulator does not attach an event-stream content-type header, so
 * the `data:` frames themselves are the stable integration contract.
 * @param {string} body Raw callable response body.
 * @return {CallableStreamFrame[]} Decoded delta and completion frames.
 */
function callableStreamFrames(body: string): CallableStreamFrame[] {
  return body
    .split("\n\n")
    .map((frame) => frame.trim())
    .filter((frame) => frame.startsWith("data: "))
    .map((frame) => JSON.parse(frame.slice(6)) as CallableStreamFrame);
}

/**
 * Performs a client-scoped Firestore REST request against the emulator.
 * @param {string} url Emulator document or collection URL.
 * @param {"GET"|"PATCH"} method Firestore operation.
 * @param {EmulatorIdentity|undefined} identity Optional authenticated caller.
 * @return {Promise<Response>} Raw Firestore emulator response.
 */
function firestoreClientRequest(
  url: string,
  method: "GET" | "PATCH",
  identity?: EmulatorIdentity
): Promise<Response> {
  const headers: Record<string, string> = {
    "content-type": "application/json",
  };
  if (identity) headers.authorization = `Bearer ${identity.idToken}`;
  return fetch(url, {
    method,
    headers,
    body: method === "PATCH" ? JSON.stringify({
      fields: {minuteCount: {integerValue: "999"}},
    }) : undefined,
  });
}

const validPreflight = {
  schemaVersion: 1,
  requestID: "2cb446d8-4f39-43a6-a95c-2486e47155bc",
};

const validCoachRequest = {
  ...validPreflight,
  surface: "text",
  qualityTier: "fast",
  coachingContext: "One recent rep. Evidence remains early.",
  messages: [{role: "user", content: "What should I fix first?"}],
};

test("callable emulator rejects missing Auth", async () => {
  const response = await callable(preflightURL, validPreflight);
  assert.equal(response.status, 401);
});

test("emulator rejects missing App Check after valid Auth", async () => {
  const identity = await anonymousIdentity();
  const response = await callable(preflightURL, validPreflight, identity);
  assert.equal(response.status, 401);
});

test("callable emulator accepts verified Auth and App Check", async () => {
  const identity = await anonymousIdentity();
  const response = await callable(
    preflightURL,
    validPreflight,
    identity,
    true
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {result: {available: true}});
});

test("coach emulator rejects oversized input early", async () => {
  const identity = await anonymousIdentity();
  const response = await callable(
    coachURL,
    {
      ...validPreflight,
      surface: "text",
      qualityTier: "fast",
      coachingContext: "c".repeat(12_001),
      messages: [{role: "user", content: "What should I fix first?"}],
    },
    identity,
    true
  );
  assert.equal(response.status, 400);
  const body = JSON.stringify(await response.json());
  assert.equal(body.includes("INVALID_ARGUMENT"), true);
});

test("callable streams Fast deltas and typed completion metadata", async () => {
  const identity = await anonymousIdentity();
  const response = await callable(
    coachURL,
    validCoachRequest,
    identity,
    true,
    true
  );
  assert.equal(response.status, 200);
  const frames = callableStreamFrames(await response.text());
  assert.deepEqual(frames[0]?.message, {
    type: "delta",
    requestID: validCoachRequest.requestID,
    text: "Fast coaching route verified.",
  });
  assert.equal(frames[1]?.result?.qualityTier, "fast");
  assert.equal(frames[1]?.result?.model, "gemini-2.5-flash");
  assert.equal(frames[1]?.result?.finishReason, "STOP");
});

test("callable streams Ultra through its reasoning model", async () => {
  const identity = await anonymousIdentity();
  const response = await callable(
    coachURL,
    {...validCoachRequest, qualityTier: "ultra"},
    identity,
    true,
    true
  );
  assert.equal(response.status, 200);
  const frames = callableStreamFrames(await response.text());
  assert.deepEqual(frames[0]?.message, {
    type: "delta",
    requestID: validCoachRequest.requestID,
    text: "Ultra coaching route verified.",
  });
  assert.equal(frames[1]?.result?.qualityTier, "ultra");
  assert.equal(frames[1]?.result?.model, "gemini-2.5-pro");
  assert.equal(frames[1]?.result?.finishReason, "STOP");
});

test("rate-limit rules deny every client", async () => {
  const identity = await anonymousIdentity();
  const adminWrite = await callable(
    coachURL,
    validCoachRequest,
    identity,
    true
  );
  assert.equal(adminWrite.status, 200);

  const collectionURL = `http://${firestoreHost}/v1/projects/${projectID}/` +
    "databases/(default)/documents/_serverRateLimits";
  const documentURL = `${collectionURL}/` +
    encodeURIComponent(identity.localId);
  for (const caller of [undefined, identity]) {
    const documentRead = await firestoreClientRequest(
      documentURL,
      "GET",
      caller
    );
    assert.equal(documentRead.status, 403);
    const collectionRead = await firestoreClientRequest(
      `${collectionURL}?pageSize=10`,
      "GET",
      caller
    );
    assert.equal(collectionRead.status, 403);
    const write = await firestoreClientRequest(documentURL, "PATCH", caller);
    assert.equal(write.status, 403);
  }
});

test("callable enforces the per-minute UID rate limit", async () => {
  const identity = await anonymousIdentity();
  for (let count = 0; count < 5; count += 1) {
    const response = await callable(
      coachURL,
      validCoachRequest,
      identity,
      true
    );
    assert.equal(response.status, 200);
  }
  const rejected = await callable(
    coachURL,
    validCoachRequest,
    identity,
    true
  );
  assert.equal(rejected.status, 429);
  const body = JSON.stringify(await rejected.json());
  assert.equal(body.includes("RESOURCE_EXHAUSTED"), true);
});
