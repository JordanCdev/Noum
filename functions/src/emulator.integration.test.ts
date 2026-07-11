/* eslint-disable valid-jsdoc, max-len */

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
const transcriptionURL =
  `http://${functionsHost}/${projectID}/${region}/transcriptionToken`;
const deletionURL =
  `http://${functionsHost}/${projectID}/${region}/deleteAccount`;
const recordPeerSessionURL =
  `http://${functionsHost}/${projectID}/${region}/recordPeerSession`;
const createChallengeURL =
  `http://${functionsHost}/${projectID}/${region}/createChallenge`;
const submitChallengeResultURL =
  `http://${functionsHost}/${projectID}/${region}/submitChallengeResult`;
const setChallengeReactionURL =
  `http://${functionsHost}/${projectID}/${region}/setChallengeReaction`;

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

type FirestoreValue = Record<string, unknown>;

/** Returns the emulator REST URL for one document path. */
function firestoreDocumentURL(path: string): string {
  return `http://${firestoreHost}/v1/projects/${projectID}/databases/` +
    `(default)/documents/${path}`;
}

/** Performs an authenticated full-document Firestore REST write. */
function writeFirestoreDocument(
  path: string,
  fields: Record<string, FirestoreValue>,
  identity: EmulatorIdentity
): Promise<Response> {
  return fetch(firestoreDocumentURL(path), {
    method: "PATCH",
    headers: {
      "content-type": "application/json",
      "authorization": `Bearer ${identity.idToken}`,
    },
    body: JSON.stringify({fields}),
  });
}

/** Performs an optionally authenticated Firestore REST document read. */
function readFirestoreDocument(
  path: string,
  identity?: EmulatorIdentity
): Promise<Response> {
  const headers: Record<string, string> = {};
  if (identity) headers.authorization = `Bearer ${identity.idToken}`;
  return fetch(firestoreDocumentURL(path), {headers});
}

/** Builds the persisted fields for one complete non-fixture session. */
function socialSessionFields(
  id: string,
  dateSeconds: number,
  score = 8,
  isRated = true
): Record<string, FirestoreValue> {
  return {
    id: {stringValue: id},
    transcript: {stringValue: "A complete real rep with clear structure."},
    fillerWordCount: {integerValue: "0"},
    duration: {doubleValue: 42},
    date: {doubleValue: dateSeconds},
    mode: {stringValue: "timed"},
    score: {integerValue: String(score)},
    isRated: {booleanValue: isRated},
    isEvaluationFixture: {booleanValue: false},
    headline: {stringValue: "Clear structure"},
  };
}

/** Writes one complete social session through the same owner rules as iOS. */
async function seedSocialSession(
  identity: EmulatorIdentity,
  sessionID: string,
  dateSeconds = Date.now() / 1_000,
  score = 8,
  isRated = true
): Promise<void> {
  const response = await writeFirestoreDocument(
    `users/${identity.localId}/sessions/${sessionID}`,
    socialSessionFields(sessionID, dateSeconds, score, isRated),
    identity
  );
  assert.equal(response.status, 200);
}

/** Creates a server-authored public profile from one stored session. */
async function recordSocialSession(
  identity: EmulatorIdentity,
  sessionID: string,
  displayName: string
): Promise<Record<string, unknown>> {
  const response = await callable(
    recordPeerSessionURL,
    {schemaVersion: 1, sessionID, displayName},
    identity,
    true
  );
  assert.equal(response.status, 200);
  return await response.json() as Record<string, unknown>;
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

test(
  "release callables enforce Auth, App Check, and strict input",
  async () => {
    const identity = await anonymousIdentity();
    const requests = [
      {
        url: transcriptionURL,
        validShape: {schemaVersion: 1},
        invalidShape: {schemaVersion: 1, accountID: identity.localId},
      },
      {
        url: deletionURL,
        validShape: {
          schemaVersion: 1,
          requestID: "783ab966-e91b-4ca4-8f7a-7e50113fa2c6",
        },
        invalidShape: {
          schemaVersion: 1,
          requestID: "783ab966-e91b-4ca4-8f7a-7e50113fa2c6",
          accountID: identity.localId,
        },
      },
      {
        url: recordPeerSessionURL,
        validShape: {
          schemaVersion: 1,
          sessionID: "A713738E-D9ED-4337-986E-09205089D42E",
          displayName: "Jordan",
        },
        invalidShape: {
          schemaVersion: 1,
          sessionID: "A713738E-D9ED-4337-986E-09205089D42E",
          displayName: "Jordan",
          rating: 1_000,
        },
      },
      {
        url: createChallengeURL,
        validShape: {
          schemaVersion: 1,
          challengeID: "2CB446D8-4F39-43A6-A95C-2486E47155BC",
          opponentAccountID: "opponent",
          prompt: "Give a concise update.",
        },
        invalidShape: {
          schemaVersion: 1,
          challengeID: "2CB446D8-4F39-43A6-A95C-2486E47155BC",
          opponentAccountID: "opponent",
          prompt: "Give a concise update.",
          creatorUID: identity.localId,
        },
      },
      {
        url: submitChallengeResultURL,
        validShape: {
          schemaVersion: 1,
          challengeID: "2CB446D8-4F39-43A6-A95C-2486E47155BC",
          sessionID: "A713738E-D9ED-4337-986E-09205089D42E",
        },
        invalidShape: {
          schemaVersion: 1,
          challengeID: "2CB446D8-4F39-43A6-A95C-2486E47155BC",
          sessionID: "A713738E-D9ED-4337-986E-09205089D42E",
          score: 10,
        },
      },
      {
        url: setChallengeReactionURL,
        validShape: {
          schemaVersion: 1,
          challengeID: "2CB446D8-4F39-43A6-A95C-2486E47155BC",
          reaction: "👏",
        },
        invalidShape: {
          schemaVersion: 1,
          challengeID: "2CB446D8-4F39-43A6-A95C-2486E47155BC",
          reaction: "👏",
          participantIDs: [identity.localId],
        },
      },
    ];
    for (const request of requests) {
      assert.equal(
        (await callable(request.url, request.validShape)).status,
        401
      );
      assert.equal((await callable(
        request.url,
        request.validShape,
        identity
      )).status, 401);
      const malformed = await callable(
        request.url,
        request.invalidShape,
        identity,
        true
      );
      assert.equal(malformed.status, 400);
      assert.equal(
        JSON.stringify(await malformed.json()).includes("INVALID_ARGUMENT"),
        true
      );
    }
  }
);

test("peer profile derives once from a stored session and rejects forgery", async () => {
  const identity = await anonymousIdentity();
  const other = await anonymousIdentity();
  const peerSessionID = "A713738E-D9ED-4337-986E-09205089D42E";
  await seedSocialSession(identity, peerSessionID);

  const first = await recordSocialSession(identity, peerSessionID, "Jordan") as {
    result?: {processed?: boolean; profile?: Record<string, unknown>};
  };
  assert.equal(first.result?.processed, true);
  assert.equal(first.result?.profile?.rating, 413);
  assert.equal(first.result?.profile?.weeklyReps, 1);
  const replay = await recordSocialSession(identity, peerSessionID, "Jordan") as {
    result?: {processed?: boolean; profile?: Record<string, unknown>};
  };
  assert.equal(replay.result?.processed, false);
  assert.equal(replay.result?.profile?.rating, 413);

  const profilePath = `profiles_public/${identity.localId}`;
  const profileResponse = await readFirestoreDocument(profilePath, identity);
  assert.equal(profileResponse.status, 200);
  const profile = await profileResponse.json() as {
    fields?: Record<string, FirestoreValue>;
  };
  assert.ok(profile.fields);
  const forgedFields = {...profile.fields};
  forgedFields.rating = {integerValue: "1000"};
  assert.equal((await writeFirestoreDocument(
    profilePath,
    forgedFields,
    identity
  )).status, 403);

  const renamedFields = {...profile.fields};
  renamedFields.displayName = {stringValue: "Jordan C"};
  assert.equal((await writeFirestoreDocument(
    profilePath,
    renamedFields,
    identity
  )).status, 200);

  const crossUser = await writeFirestoreDocument(
    `users/${other.localId}/sessions/${peerSessionID}`,
    socialSessionFields(peerSessionID, Date.now() / 1_000),
    identity
  );
  assert.equal(crossUser.status, 403);
  assert.equal((await readFirestoreDocument(
    `_socialState/${identity.localId}`,
    identity
  )).status, 403);
  const missing = await callable(
    recordPeerSessionURL,
    {
      schemaVersion: 1,
      sessionID: "783AB966-E91B-4CA4-8F7A-7E50113FA2C6",
      displayName: "Jordan",
    },
    identity,
    true
  );
  assert.equal(missing.status, 404);
});

test("challenge writes are server-derived, immutable, and replay-safe", async () => {
  const creator = await anonymousIdentity();
  const opponent = await anonymousIdentity();
  const outsider = await anonymousIdentity();
  const creatorProfileSession = "11111111-1111-4111-8111-111111111111";
  const opponentProfileSession = "22222222-2222-4222-8222-222222222222";
  await seedSocialSession(creator, creatorProfileSession, Date.now() / 1_000, 7);
  await seedSocialSession(opponent, opponentProfileSession, Date.now() / 1_000, 7);
  await recordSocialSession(creator, creatorProfileSession, "Creator");
  await recordSocialSession(opponent, opponentProfileSession, "Opponent");

  const firstChallengeID = "33333333-3333-4333-8333-333333333333";
  const prompt = "Give a concise project update.";
  const createResponse = await callable(
    createChallengeURL,
    {
      schemaVersion: 1,
      challengeID: firstChallengeID,
      opponentAccountID: opponent.localId,
      prompt,
    },
    creator,
    true
  );
  assert.equal(createResponse.status, 200);
  const created = await createResponse.json() as {
    result?: {
      created?: boolean;
      challenge?: {createdAt?: number; creatorAccountID?: string};
    };
  };
  assert.equal(created.result?.created, true);
  assert.equal(created.result?.challenge?.creatorAccountID, creator.localId);
  assert.equal((await callable(
    createChallengeURL,
    {
      schemaVersion: 1,
      challengeID: firstChallengeID,
      opponentAccountID: opponent.localId,
      prompt,
    },
    creator,
    true
  )).status, 200);

  const oversized = await callable(
    createChallengeURL,
    {
      schemaVersion: 1,
      challengeID: "44444444-4444-4444-8444-444444444444",
      opponentAccountID: opponent.localId,
      prompt: "p".repeat(501),
    },
    creator,
    true
  );
  assert.equal(oversized.status, 400);

  const challengePath = `challenges/${firstChallengeID}`;
  const directChallengeWrite = await writeFirestoreDocument(
    challengePath,
    {creatorScore: {integerValue: "10"}},
    creator
  );
  assert.equal(directChallengeWrite.status, 403);
  assert.equal((await readFirestoreDocument(challengePath, creator)).status, 200);
  assert.equal((await readFirestoreDocument(challengePath, opponent)).status, 200);
  assert.equal((await readFirestoreDocument(challengePath, outsider)).status, 403);

  const challengeStart = created.result?.challenge?.createdAt ??
    Date.now() / 1_000;
  const creatorResultSession = "55555555-5555-4555-8555-555555555555";
  const opponentResultSession = "66666666-6666-4666-8666-666666666666";
  await seedSocialSession(creator, creatorResultSession, challengeStart + 1, 9);
  await seedSocialSession(opponent, opponentResultSession, challengeStart + 1, 6);

  const creatorSubmit = await callable(
    submitChallengeResultURL,
    {
      schemaVersion: 1,
      challengeID: firstChallengeID,
      sessionID: creatorResultSession,
    },
    creator,
    true
  );
  assert.equal(creatorSubmit.status, 200);
  const creatorResult = await creatorSubmit.json() as {
    result?: {submitted?: boolean; challenge?: {creatorScore?: number}};
  };
  assert.equal(creatorResult.result?.submitted, true);
  assert.equal(creatorResult.result?.challenge?.creatorScore, 9);
  const replay = await callable(
    submitChallengeResultURL,
    {
      schemaVersion: 1,
      challengeID: firstChallengeID,
      sessionID: creatorResultSession,
    },
    creator,
    true
  );
  assert.equal(replay.status, 200);
  assert.equal((await replay.json() as {
    result?: {submitted?: boolean};
  }).result?.submitted, false);

  assert.equal((await callable(
    submitChallengeResultURL,
    {
      schemaVersion: 1,
      challengeID: firstChallengeID,
      sessionID: opponentResultSession,
    },
    opponent,
    true
  )).status, 200);
  const reacted = await callable(
    setChallengeReactionURL,
    {schemaVersion: 1, challengeID: firstChallengeID, reaction: "👏"},
    creator,
    true
  );
  assert.equal(reacted.status, 200);
  assert.equal((await reacted.json() as {
    result?: {updated?: boolean};
  }).result?.updated, true);
  const reactionReplay = await callable(
    setChallengeReactionURL,
    {schemaVersion: 1, challengeID: firstChallengeID, reaction: "👏"},
    creator,
    true
  );
  assert.equal((await reactionReplay.json() as {
    result?: {updated?: boolean};
  }).result?.updated, false);

  const secondChallengeID = "77777777-7777-4777-8777-777777777777";
  assert.equal((await callable(
    createChallengeURL,
    {
      schemaVersion: 1,
      challengeID: secondChallengeID,
      opponentAccountID: opponent.localId,
      prompt: "State the decision and one reason.",
    },
    creator,
    true
  )).status, 200);
  const reused = await callable(
    submitChallengeResultURL,
    {
      schemaVersion: 1,
      challengeID: secondChallengeID,
      sessionID: creatorResultSession,
    },
    creator,
    true
  );
  assert.equal(reused.status, 409);
  assert.equal(
    JSON.stringify(await reused.json()).includes("ALREADY_EXISTS"),
    true
  );

  const malformedChallenge = await writeFirestoreDocument(
    "challenges/88888888-8888-4888-8888-888888888888",
    {
      id: {stringValue: "88888888-8888-4888-8888-888888888888"},
      prompt: {stringValue: "p".repeat(600)},
      creatorAccountID: {stringValue: creator.localId},
    },
    creator
  );
  assert.equal(malformedChallenge.status, 403);
});

test("anonymous deletion is complete and retry-safe", async () => {
  const identity = await anonymousIdentity();
  const request = {
    schemaVersion: 1,
    requestID: "a713738e-d9ed-4337-986e-09205089d42e",
  };
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const response = await callable(
      deletionURL,
      request,
      identity,
      true
    );
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      result: {deleted: true, requestID: request.requestID},
    });
  }
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
