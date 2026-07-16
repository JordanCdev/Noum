import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import test from "node:test";
import {
  assertTrustedCaller,
  assertSocialCallablesAvailable,
  buildVertexContents,
  type CoachGenerateContentResponse,
  coachCompletionLogMetadata,
  consumeCoachStream,
  isAcceptableFinishReason,
  maxOutputTokensForRequest,
  modelForQualityTier,
  nextRateState,
  normalizeQualityTier,
  validateCoachChatRequest,
} from "./index.js";
import {FinishReason} from "@google/genai";

const request = {
  schemaVersion: 1,
  requestID: "2cb446d8-4f39-43a6-a95c-2486e47155bc",
  surface: "text",
  qualityTier: "fast",
  coachingContext: "One completed rep. Evidence remains early.",
  messages: [{role: "user", content: "What should I fix first?"}],
};

interface HttpsErrorShape {
  code?: string;
  details?: {reason?: string};
}

/**
 * Returns the shared account-deletion executor from the source contract.
 * @param {string} source Function source.
 * @return {string} Shared deletion executor source.
 */
function deletionExecutorSource(source: string): string {
  const start = source.indexOf("async function executeAccountDeletion(");
  const end = source.indexOf("export const deleteAccount", start);
  assert.equal(start >= 0 && end > start, true);
  return source.slice(start, end);
}

test("validates the versioned coach request", () => {
  assert.deepEqual(validateCoachChatRequest(request), request);
});

test("normalizes legacy tiers and routes Fast and Ultra models", () => {
  assert.equal(normalizeQualityTier("geminiFast"), "fast");
  assert.equal(normalizeQualityTier("claudeReasoning"), "ultra");
  assert.equal(modelForQualityTier("fast", "flash", "pro"), "flash");
  assert.equal(modelForQualityTier("ultra", "flash", "pro"), "pro");
});

test("server budgets cover every Fast and Ultra client route", () => {
  assert.equal(maxOutputTokensForRequest("text", "fast"), 180);
  assert.equal(maxOutputTokensForRequest("text", "ultra"), 380);
  assert.equal(maxOutputTokensForRequest("live", "fast"), 220);
  assert.equal(maxOutputTokensForRequest("live", "ultra"), 220);
});

test(
  "legacy Ultra normalizes through routing and completion metadata",
  async () => {
    const input = validateCoachChatRequest({
      ...request,
      qualityTier: "claudeReasoning",
    });
    const model = modelForQualityTier(
      input.qualityTier,
      "gemini-2.5-flash",
      "gemini-2.5-pro"
    );
    const completion = await consumeCoachStream(
      input,
      model,
      {
        generate: async () => vertexStream(["Lead with the answer."]),
      }
    );

    assert.equal(input.qualityTier, "ultra");
    assert.equal(model, "gemini-2.5-pro");
    assert.equal(completion.qualityTier, "ultra");
    assert.equal(completion.model, "gemini-2.5-pro");
  }
);

test("rejects an oversized message list", () => {
  assert.throws(() => validateCoachChatRequest({
    ...request,
    messages: Array.from({length: 13}, () => request.messages[0]),
  }));
});

test("rejects every invalid public request discriminator", () => {
  for (const patch of [
    {schemaVersion: 2},
    {requestID: "not-a-uuid"},
    {requestID: "00000000-0000-0000-0000-000000000000"},
    {surface: "settings"},
    {qualityTier: "unknown"},
    {coachingContext: ""},
    {messages: []},
    {messages: [{role: "system", content: "Policy"}]},
    {messages: [{role: "user", content: ""}]},
  ]) {
    assert.throws(() => validateCoachChatRequest({...request, ...patch}));
  }
});

test("accepts exact field boundaries and rejects one character over", () => {
  const exact = {
    ...request,
    coachingContext: "c".repeat(12_000),
    messages: [
      {role: "assistant", content: "a".repeat(4_000)},
      {role: "user", content: "u".repeat(4_000)},
    ],
  };
  assert.equal(validateCoachChatRequest(exact).coachingContext.length, 12_000);
  assert.throws(() => validateCoachChatRequest({
    ...exact,
    coachingContext: "c".repeat(12_001),
  }));
  assert.throws(() => validateCoachChatRequest({
    ...request,
    messages: [{role: "user", content: "u".repeat(4_001)}],
  }));
});

test("rejects total input over the 32000 character envelope", () => {
  assert.doesNotThrow(() => validateCoachChatRequest({
    ...request,
    coachingContext: "c".repeat(12_000),
    messages: Array.from({length: 5}, (_, index) => ({
      role: index === 4 ? "user" : "assistant",
      content: "m".repeat(4_000),
    })),
  }));
  assert.throws(() => validateCoachChatRequest({
    ...request,
    coachingContext: "c".repeat(12_000),
    messages: [
      ...Array.from({length: 5}, () => ({
        role: "assistant",
        content: "m".repeat(4_000),
      })),
      {role: "user", content: "x"},
    ],
  }));
});

test("rejects a request whose last turn is not the user", () => {
  assert.throws(() => validateCoachChatRequest({
    ...request,
    messages: [{role: "assistant", content: "A reply"}],
  }));
});

test("minute rate limit allows five and rejects the sixth", () => {
  const now = 1_800_000;
  let state = nextRateState(undefined, now);
  assert.equal(state.allowed, true);
  for (let count = 2; count <= 5; count += 1) {
    state = nextRateState(state.state, now);
    assert.equal(state.allowed, true);
  }
  state = nextRateState(state.state, now);
  assert.equal(state.allowed, false);
});

test("rate windows reset independently", () => {
  const first = nextRateState(undefined, 3_600_000);
  const nextMinute = nextRateState(first.state, 3_660_000);
  assert.equal(nextMinute.state.minuteCount, 1);
  assert.equal(nextMinute.state.hourCount, 2);
  const nextHour = nextRateState(nextMinute.state, 7_200_000);
  assert.equal(nextHour.state.minuteCount, 1);
  assert.equal(nextHour.state.hourCount, 1);
});

test("hour rate limit allows thirty and rejects the thirty-first", () => {
  const hourStart = 10 * 3_600_000;
  let state = nextRateState(undefined, hourStart);
  for (let count = 2; count <= 30; count += 1) {
    state = nextRateState(state.state, hourStart + (count - 1) * 60_000);
    assert.equal(state.allowed, true);
  }
  state = nextRateState(state.state, hourStart + 30 * 60_000);
  assert.equal(state.allowed, false);
});

test("requires both authenticated and App Check-verified callers", () => {
  assert.throws(() => assertTrustedCaller(undefined, {appId: "app"}));
  assert.throws(() => assertTrustedCaller({uid: "user"}, undefined));
  assert.doesNotThrow(() => assertTrustedCaller(
    {uid: "user"},
    {appId: "app"}
  ));
});

test("client rules deny every rate-limit collection operation", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  assert.match(
    rules,
    // This exact server-only rule should remain visually auditable.
    // eslint-disable-next-line max-len
    /match \/_serverRateLimits\/\{[^}]+\}[\s\S]*?allow read, write: if false;/
  );
});

test("recommendation state is callable-only", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  assert.match(
    rules,
    // eslint-disable-next-line max-len
    /match \/recommendations\/\{recommendationID\}[\s\S]*?allow read:[\s\S]*?allow create, update: if false;[\s\S]*?allow delete: if false;/
  );
  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  const start = source.indexOf("export const syncRecommendationState");
  const end = source.indexOf("function isAuthUserNotFound", start);
  assert.equal(start >= 0 && end > start, true);
  const callable = source.slice(start, end);
  assert.match(callable, /enforceAppCheck: true/);
  assert.match(callable, /assertTrustedCaller\(request\.auth, request\.app\)/);
  assert.match(callable, /runTransaction/);
  assert.match(callable, /_accountDeletionState/);
  assert.doesNotMatch(callable, /assertSocialCallablesAvailable/);
});

test(
  "exactly twelve competitive and social callables share the cutover gate",
  () => {
    const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
    const exportedCallables = [...source.matchAll(
    // eslint-disable-next-line max-len
      /export const (\w+) = onCall\([\s\S]*?(?=\nexport const \w+ = onCall|\n\/\*\*|$)/g
    )];
    const gated = exportedCallables
      .filter((match) =>
        match[0].includes("await assertSocialCallablesAvailable();")
      )
      .map((match) => match[1])
      .sort();
    assert.deepEqual(gated, [
      "acceptFriendInvite",
      "beginCompetitiveObservation",
      "completeCompetitiveObservation",
      "createChallenge",
      "createFriendInvite",
      "getPeerProfile",
      "listFriendLinks",
      "listLeagueMembers",
      "recordPeerSession",
      "removeFriendLink",
      "setChallengeReaction",
      "submitChallengeResult",
    ]);
    for (const callableName of gated) {
      const callable = exportedCallables.find(
        (match) => match[1] === callableName
      );
      assert.ok(callable);
      const gateIndex = callable[0].indexOf(
        "await assertSocialCallablesAvailable();"
      );
      const isObservation = callableName.includes("CompetitiveObservation");
      const firstProtectedWork = isObservation ?
        callable[0].indexOf("enforceCompetitiveObservationRateLimit") :
        callable[0].search(/(?:const input = )?validate[A-Z]/);
      assert.equal(gateIndex >= 0 && gateIndex < firstProtectedWork, true);
    }

    const recommendation = exportedCallables.find(
      (match) => match[1] === "syncRecommendationState"
    );
    assert.ok(recommendation);
    assert.doesNotMatch(recommendation[0], /assertSocialCallablesAvailable/);

    const deletion = exportedCallables.find(
      (match) => match[1] === "deleteAccount"
    );
    assert.ok(deletion);
    assert.match(deletion[0], /executeAccountDeletion\(request\)/);
    assert.doesNotMatch(deletion[0], /assertSocialCallablesAvailable/);
    assert.match(
      deletionExecutorSource(source),
      /assertSocialReferenceCutoverComplete/
    );
  }
);

test(
  "competitive observation callables preserve the ineligible boundary",
  () => {
    const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
    const beginStart = source.indexOf(
      "export const beginCompetitiveObservation"
    );
    const completeStart = source.indexOf(
      "export const completeCompetitiveObservation"
    );
    const completeEnd = source.indexOf(
      "function publicProfileDocument",
      completeStart
    );
    assert.equal(beginStart >= 0 && completeStart > beginStart, true);
    assert.equal(completeEnd > completeStart, true);
    const begin = source.slice(beginStart, completeStart);
    const complete = source.slice(completeStart, completeEnd);
    const rateStart = source.indexOf(
      "async function enforceCompetitiveObservationRateLimit"
    );
    const rateOwner = source.slice(rateStart, beginStart);
    for (const callable of [begin, complete]) {
      assert.match(callable, /enforceAppCheck: true/);
      assert.match(callable, /TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT/);
      assert.match(
        callable,
        /assertTrustedCaller\(request\.auth, request\.app\)/
      );
      assert.match(callable, /await assertSocialCallablesAvailable\(\)/);
      assert.match(callable, /_accountDeletionState/);
      assert.doesNotMatch(callable, /_verifiedSessionEvidence/);
    }
    assert.match(complete, /secrets: \[deepgramManagementKey\]/);
    assert.match(complete, /collection\("captureIntents"\)/);
    assert.match(complete, /_competitiveAudioReplayClaims/);
    assert.match(complete, /competitiveAudioReplayDigest/);
    assert.match(complete, /competitiveAudioReplayClaim/);
    assert.match(complete, /validateStoredCompetitiveAudioReplayClaim/);
    assert.doesNotMatch(complete, /collection\("audioDigests"\)/);
    const replayCreate = complete.match(
      /transaction\.create\(replayRef, \{([\s\S]*?)\}\);/
    );
    assert.ok(replayCreate);
    assert.match(replayCreate[1], /schemaVersion/);
    assert.match(replayCreate[1], /digest/);
    assert.match(replayCreate[1], /claimedAt/);
    assert.match(replayCreate[1], /expiresAt/);
    assert.doesNotMatch(
      replayCreate[1],
      /uid|sessionID|audioSHA256|competitiveEligible|transcript/
    );
    assert.match(complete, /collection\("observations"\)/);
    assert.match(complete, /competitiveEligible: false/);
    assert.match(rateOwner, /COMPETITIVE_OBSERVATION_MINUTE_LIMIT/);
    assert.match(rateOwner, /COMPETITIVE_OBSERVATION_HOUR_LIMIT/);
    assert.match(complete, /status: "processing"/);
    assert.match(complete, /processingStartedAt: Timestamp\.fromMillis/);
    assert.match(complete, /intent\.status !== "processing"/);
    assert.doesNotMatch(complete, /competitiveObservationRetryMatches/);
    assert.doesNotMatch(complete, /fillerWordCount|isRated|score:/);
    const workStart = complete.indexOf("completeCompetitiveObservationWork");
    const claimStart = complete.indexOf("claimAudio:", workStart);
    const providerStart = complete.indexOf("transcribe:", workStart);
    const commitStart = complete.indexOf("commitObservation:", workStart);
    assert.equal(
      workStart >= 0 && claimStart > workStart && providerStart > claimStart &&
      commitStart > providerStart,
      true
    );
  }
);

test("friendship callables preserve server-only reciprocal authority", () => {
  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  const names = [
    "createFriendInvite",
    "acceptFriendInvite",
    "listFriendLinks",
    "removeFriendLink",
  ];
  for (const [index, name] of names.entries()) {
    const start = source.indexOf(`export const ${name}`);
    const endName = names[index + 1] ?? "recordPeerSession";
    const end = source.indexOf(`export const ${endName}`, start + 1);
    const callable = source.slice(start, end);
    assert.match(callable, /enforceAppCheck: true/);
    assert.match(callable, /SOCIAL_RUNTIME_SERVICE_ACCOUNT/);
    assert.match(
      callable,
      /assertTrustedCaller\(request\.auth, request\.app\)/
    );
    assert.match(callable, /await assertSocialCallablesAvailable\(\)/);
    assert.match(callable, /_accountDeletionState/);
  }
  const create = source.slice(
    source.indexOf("export const createFriendInvite"),
    source.indexOf("export const acceptFriendInvite")
  );
  assert.match(create, /where\("status", "==", "active"\)/);
  assert.match(create, /MAX_ACTIVE_FRIEND_INVITES \+ 1/);
  assert.match(create, /friend-invite-capacity/);
  const accept = source.slice(
    source.indexOf("export const acceptFriendInvite"),
    source.indexOf("export const listFriendLinks")
  );
  assert.match(accept, /FRIEND_LINK_SCHEMA_VERSION/);
  assert.match(accept, /inviteDigest: tokenDigest/);
  assert.match(accept, /validateReciprocalFriendManifests/);
  assert.doesNotMatch(accept, /logger\.(info|warn|error)/);
  const remove = source.slice(
    source.indexOf("export const removeFriendLink"),
    source.indexOf("export const recordPeerSession")
  );
  assert.match(remove, /status: "revoked"/);
  assert.match(remove, /friend-link-generation-mismatch/);
  assert.match(remove, /pairID: input\.pairID/);
  assert.match(remove, /transaction\.delete\(ownLinkRef\)/);
  assert.match(remove, /transaction\.delete\(friendLinkRef\)/);
  assert.match(remove, /friendAccountID,/);
  const list = source.slice(
    source.indexOf("export const listFriendLinks"),
    source.indexOf("export const removeFriendLink")
  );
  assert.match(list, /\.friendAccountIDs\]\.sort\(\)/);
  assert.doesNotMatch(list, /\.slice\(/);
  const deletion = deletionExecutorSource(source);
  assert.match(deletion, /collectionGroup\("friends"\)/);
  assert.match(deletion, /FieldValue\.arrayRemove\(uid\)/);
  const callable = source.slice(
    source.indexOf("export const deleteAccount"),
    source.indexOf("export const reconcileAccountDeletionTombstones")
  );
  const validateIndex = callable.indexOf("validateDeleteAccountRequest(");
  const identityBindingIndex = callable.indexOf(
    "assertDeleteAccountRequestIdentity("
  );
  const firstDeletionWorkIndex = callable.indexOf(
    "executeAccountDeletion(request)"
  );
  assert.equal(
    validateIndex >= 0 &&
      identityBindingIndex > validateIndex &&
      identityBindingIndex < firstDeletionWorkIndex,
    true
  );
  const peer = source.slice(
    source.indexOf("export const getPeerProfile"),
    source.indexOf("export const listLeagueMembers")
  );
  assert.match(peer, /validateReciprocalFriendLinks/);
  assert.match(peer, /validateReciprocalFriendManifests/);
  const challenge = source.slice(
    source.indexOf("export const createChallenge"),
    source.indexOf("export const submitChallengeResult")
  );
  assert.match(challenge, /validateReciprocalFriendLinks/);
  assert.match(challenge, /validateReciprocalFriendManifests/);
});

test(
  "social callable gate rejects unavailable markers with a stable error",
  async () => {
    await assert.doesNotReject(
      () => assertSocialCallablesAvailable(async () => ({
        schemaVersion: 4,
        status: "complete",
        runID: "B713738E-D9ED-4337-986E-09205089D42E",
        projectID: "noum-d0b6f",
        sourceGitCommit: "a".repeat(40),
        sourceImplementationSHA256: "b".repeat(64),
        backupDigest: "c".repeat(64),
        inventoryDigest: "d".repeat(64),
        verifiedInventoryDigest: "d".repeat(64),
        completedAt: {toMillis: () => 1_800_000},
      }))
    );
    await assert.rejects(
      () => assertSocialCallablesAvailable(async () => undefined),
      (error: unknown) => {
        const httpsError = error as HttpsErrorShape;
        return httpsError.code === "failed-precondition" &&
          httpsError.details?.reason === "social-reference-cutover-incomplete";
      }
    );
    await assert.rejects(
      () => assertSocialCallablesAvailable(async () => ({
        schemaVersion: 2,
        status: "complete",
      })),
      (error: unknown) => (error as HttpsErrorShape)
        .details?.reason === "social-reference-cutover-incomplete"
    );
    await assert.rejects(
      () => assertSocialCallablesAvailable(async () => {
        throw new Error("backend unavailable");
      }),
      (error: unknown) => (error as {details?: {reason?: string}})
        .details?.reason === "social-reference-cutover-incomplete"
    );
  }
);

test("private profile optional fields remain type and size bounded", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  const start = rules.indexOf("function validPrivateProfile(data)");
  const end = rules.indexOf("function validPrivateProgress(data)");
  assert.equal(start >= 0 && end > start, true);
  const validator = rules.slice(start, end);

  const requiredFragments = [
    "!('customChallengeText' in data)",
    "data.customChallengeText == null",
    "validBoundedString(data.customChallengeText, 90)",
    "!('paraphrasedGoal' in data)",
    "data.paraphrasedGoal == null",
    "validBoundedString(data.paraphrasedGoal, 220)",
    "!('bigMomentID' in data)",
    "data.bigMomentID == null",
    "data.bigMomentID is string",
    "data.bigMomentID.matches(",
    "!('secondaryStyleGoal' in data)",
    "data.secondaryStyleGoal == null",
    "validSpeakingStyleGoal(data.secondaryStyleGoal)",
  ];
  for (const fragment of requiredFragments) {
    assert.equal(validator.includes(fragment), true, fragment);
  }
});

test("private sessions validate demand and metric provenance", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  const demandStart = rules.indexOf("function validPracticeDemand(data)");
  const sessionStart = rules.indexOf(
    "function validPrivateSession(data, sessionID)"
  );
  const sessionEnd = rules.indexOf(
    "function validPublicProfile(data, accountID)"
  );
  assert.equal(demandStart >= 0 && sessionStart > demandStart, true);
  assert.equal(sessionEnd > sessionStart, true);

  const demandValidator = rules.slice(demandStart, sessionStart);
  const sessionValidator = rules.slice(sessionStart, sessionEnd);
  const demandFragments = [
    "!('practiceDemand' in data)",
    "data.practiceDemand is map",
    "'schemaVersion', 'timedDifficulty'",
    "data.practiceDemand.schemaVersion == 1",
    "data.mode == 'timed'",
    "'free', 'easy', 'medium', 'hard'",
    "!('suddenDeathDifficulty' in data.practiceDemand)",
    "data.mode == 'suddenDeath'",
    "'easy', 'medium', 'hard'",
    "!('timedDifficulty' in data.practiceDemand)",
    "'ice_breaker', 'table_topic', 'vocal_variety'",
  ];
  for (const fragment of demandFragments) {
    assert.equal(demandValidator.includes(fragment), true, fragment);
  }

  const sessionFragments = [
    "'comparisonMetricSchemaVersion', 'practiceDemand'",
    "data.comparisonMetricSchemaVersion is int",
    "data.comparisonMetricSchemaVersion == 1",
    "validPracticeDemand(data)",
  ];
  for (const fragment of sessionFragments) {
    assert.equal(sessionValidator.includes(fragment), true, fragment);
  }
});

test("private profile enum fields match Codable raw values", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  ).replace(/\s+/g, " ")
    .replace(/\[\s+/g, "[")
    .replace(/\s+\]/g, "]");
  const requiredFragments = [
    "function validSpeakingContext(value) { return value in " +
      "['work', 'interviews', 'presentations', 'social']; }",
    "function validCoachingPriority(value) { return value in " +
      "['reduceFillers', 'moreConcise', 'thinkFaster', " +
      "'calmerDelivery']; }",
    "function validConfidenceLevel(value) { return value in " +
      "['beginner', 'rebuilding', 'inconsistent', 'confident']; }",
    "function validSpeakingChallenge(value) { return value in " +
      "['fillerWords', 'rambling', 'freezing', 'rushing']; }",
    "function validSpeakingOutcome(value) { return value in " +
      "['concise', 'composed', 'persuasive', 'spontaneous']; }",
    "function validSpeakingStyleGoal(value) { return value in " +
      "['authoritative', 'warm', 'concise', 'persuasive', " +
      "'executive', 'storytelling']; }",
    "validSpeakingContext(data.speakingContext)",
    "validCoachingPriority(data.primaryGoal)",
    "validConfidenceLevel(data.confidenceLevel)",
    "validSpeakingChallenge(data.biggestChallenge)",
    "validSpeakingOutcome(data.desiredOutcome)",
    "validSpeakingStyleGoal(data.speakingStyleGoal)",
    "validSpeakingStyleGoal(data.chosenStyleGoal)",
  ];
  for (const fragment of requiredFragments) {
    assert.equal(rules.includes(fragment), true, fragment);
  }
});

test("account deletion uses exact server-owned social references", () => {
  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  assert.equal(source.includes("collectionGroup(\"friends\")"), true);
  assert.match(source, /collection\("_socialReferences"\)/);
  assert.match(source, /validateSocialReferenceManifest\(/);
  assert.match(source, /references\.leagueMembershipPaths/);
  assert.match(source, /references\.challengeIDs/);
  assert.match(source, /rawFriendIDs/);
  assert.match(source, /friendInvites: async/);
  assert.match(source, /_socialFriendInvites/);
  const observationStart = source.indexOf("competitiveObservations: async");
  const rateStart = source.indexOf("rateLimits: async");
  const finalizerStart = source.indexOf("socialReferenceManifest: async");
  assert.equal(
    observationStart >= 0 && rateStart > observationStart &&
      finalizerStart > rateStart,
    true
  );
  const observationCleanup = source.slice(observationStart, rateStart);
  assert.match(observationCleanup, /_competitiveCaptureIntents/);
  assert.match(observationCleanup, /_competitiveObservations/);
  assert.match(observationCleanup, /recursiveDelete/);
  assert.equal(
    source.slice(rateStart, finalizerStart).includes("_socialReferences"),
    false
  );
});

test("competitive observation storage is callable-only", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  for (const collection of [
    "_competitiveCaptureIntents",
    "_competitiveObservations",
    "_competitiveAudioReplayClaims",
  ]) {
    const start = rules.indexOf(`match /${collection}/{document=**}`);
    assert.notEqual(start, -1, collection);
    assert.match(
      rules.slice(start, start + 130),
      /allow read, write: if false;/
    );
  }
});

test("completed deletion tombstones remain server-only write fences", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  assert.match(rules, /function deletionFenceExists\(accountID\)/);
  assert.match(
    rules,
    /return isOwner\(accountID\) && !deletionFenceExists\(accountID\);/
  );
  const storageStart = rules.indexOf(
    "match /_accountDeletionState/{document=**}"
  );
  assert.notEqual(storageStart, -1);
  assert.match(
    rules.slice(storageStart, storageStart + 140),
    /allow read, write: if false;/
  );

  const source = readFileSync(resolve(process.cwd(), "src/index.ts"), "utf8");
  const deletion = deletionExecutorSource(source);
  assert.match(deletion, /schemaVersion: 2,[\s\S]*?status: "pending"/);
  assert.match(
    deletion,
    // eslint-disable-next-line max-len
    /completedTombstone:[\s\S]*?transaction\.set\(deletionStateRef, completedAccountDeletionTombstone\(/
  );
  assert.doesNotMatch(deletion, /deletionStateRef\.delete\(\)/);
  assert.match(deletion, /admission === "alreadyCompleted"/);

  const scheduler = source.slice(
    source.indexOf("export const reconcileAccountDeletionTombstones")
  );
  assert.match(scheduler, /onSchedule\(/);
  assert.match(scheduler, /schedule: "every 15 minutes"/);
  assert.match(scheduler, /serviceAccount: ACCOUNT_RUNTIME_SERVICE_ACCOUNT/);
  assert.match(scheduler, /where\("status", "==", "pending"\)/);
  assert.match(scheduler, /where\("updatedAt", "<=", cutoff\)/);
  assert.match(
    scheduler,
    /pendingAccountDeletionReconciliationCandidate\(/
  );
  assert.match(scheduler, /executeAccountDeletion\(null, candidate\)/);
  assert.match(scheduler, /pageQuery\.startAfter\(cursor\)/);
  assert.match(
    scheduler,
    /admission === "resumePending"[\s\S]*?updatedAt: Timestamp\.now\(\)/
  );
  assert.doesNotMatch(scheduler, /completedAccountDeletionTombstone\(/);
  assert.doesNotMatch(scheduler, /deletionStateRef\.delete\(\)/);
  assert.match(deletion, /executeAccountDeletionPlan\(work\)/);
});

test("ephemeral server records have source-declared TTL", () => {
  const config = JSON.parse(readFileSync(
    resolve(process.cwd(), "../firestore.indexes.json"),
    "utf8"
  )) as {
    indexes?: Array<Record<string, unknown>>;
    fieldOverrides?: Array<Record<string, unknown>>;
  };
  const ttlGroups = new Set((config.fieldOverrides ?? [])
    .filter((entry) => entry.fieldPath === "expiresAt" && entry.ttl === true &&
      Array.isArray(entry.indexes) && entry.indexes.length === 0)
    .map((entry) => entry.collectionGroup));
  for (const collectionGroup of [
    "_accountDeletionState",
    "captureIntents",
    "observations",
    "_competitiveAudioReplayClaims",
  ]) {
    assert.equal(ttlGroups.has(collectionGroup), true, collectionGroup);
  }
  assert.deepEqual(
    (config.indexes ?? []).find(
      (entry) => entry.collectionGroup === "_accountDeletionState"
    ),
    {
      collectionGroup: "_accountDeletionState",
      queryScope: "COLLECTION",
      fields: [
        {fieldPath: "status", order: "ASCENDING"},
        {fieldPath: "updatedAt", order: "ASCENDING"},
      ],
    }
  );
});

test("friendship authority storage is callable-only", () => {
  const rules = readFileSync(
    resolve(process.cwd(), "../firestore.rules"),
    "utf8"
  );
  for (const collection of [
    "_socialFriendLinks",
    "_socialFriendInvites",
    "_socialReferences",
  ]) {
    const start = rules.indexOf(`match /${collection}/{document=**}`);
    assert.notEqual(start, -1, collection);
    assert.match(
      rules.slice(start, start + 130),
      /allow read, write: if false;/
    );
  }
});

test("only complete STOP generations are accepted", () => {
  assert.equal(isAcceptableFinishReason("STOP"), true);
  const rejected = [
    "MAX_TOKENS", "SAFETY", "RECITATION", "UNKNOWN", null,
  ];
  for (const reason of rejected) {
    assert.equal(isAcceptableFinishReason(reason), false);
  }
});

test("operational log metadata cannot contain coaching content", () => {
  const metadata = coachCompletionLogMetadata(
    validateCoachChatRequest(request),
    "gemini-2.5-flash",
    "STOP",
    200,
    40,
    900,
    "ok"
  );
  const serialized = JSON.stringify(metadata);
  assert.equal(serialized.includes(request.coachingContext), false);
  assert.equal(serialized.includes(request.messages[0].content), false);
  assert.deepEqual(Object.keys(metadata).sort(), [
    "finishReason", "inputTokens", "latencyMs", "model", "outputTokens",
    "qualityTier", "requestID", "status", "surface",
  ]);
});

test("Vertex contents attach context once and coalesce adjacent roles", () => {
  const input = validateCoachChatRequest({
    ...request,
    messages: [
      {role: "assistant", content: "Earlier reply"},
      {role: "user", content: "First unanswered turn"},
      {role: "user", content: "Current turn"},
    ],
  });
  const contents = buildVertexContents(input);
  assert.equal(contents[0].role, "user");
  assert.equal(contents[1].role, "model");
  assert.equal(contents[2].role, "user");
  assert.equal(
    contents[2].parts[0].text.includes("First unanswered turn"),
    true
  );
  assert.equal(contents[2].parts[0].text.includes("Current turn"), true);
  const serialized = JSON.stringify(contents);
  assert.equal(serialized.match(/COACHING CONTEXT/g)?.length, 1);
  for (let index = 1; index < contents.length; index += 1) {
    assert.notEqual(contents[index - 1].role, contents[index].role);
  }
});

/**
 * Builds the smallest valid Vertex response fixture.
 * @param {string} text Candidate text.
 * @param {FinishReason|undefined} finishReason Candidate finish reason.
 * @param {boolean} includeUsage Whether to attach final token metadata.
 * @return {CoachGenerateContentResponse} Vertex response fixture.
 */
function vertexResponse(
  text: string,
  finishReason: FinishReason | undefined,
  includeUsage = false
): CoachGenerateContentResponse {
  const response: CoachGenerateContentResponse = {
    candidates: [{content: {parts: [{text}]}, finishReason}],
  };
  if (includeUsage) {
    response.usageMetadata = {
      promptTokenCount: 120,
      candidatesTokenCount: 24,
    };
  }
  return response;
}

/**
 * Builds a deterministic Vertex stream fixture.
 * @param {string[]} chunks Streamed text chunks.
 * @param {FinishReason} finishReason Final candidate reason.
 * @return {AsyncIterable<CoachGenerateContentResponse>} Vertex stream fixture.
 */
function vertexStream(
  chunks: string[],
  finishReason: FinishReason = FinishReason.STOP
): AsyncIterable<CoachGenerateContentResponse> {
  return (async function* () {
    if (chunks.length === 0) {
      yield vertexResponse("", finishReason, true);
      return;
    }
    for (const [index, chunk] of chunks.entries()) {
      const isFinal = index === chunks.length - 1;
      yield vertexResponse(
        chunk,
        isFinal ? finishReason : undefined,
        isFinal
      );
    }
  })();
}

test("streams typed deltas and returns typed completion metadata", async () => {
  const deltas: unknown[] = [];
  const completion = await consumeCoachStream(
    validateCoachChatRequest(request),
    "gemini-2.5-flash",
    {
      generate: async () => vertexStream(["Lead first. ", "Add proof."]),
      sendDelta: async (delta) => {
        deltas.push(delta);
      },
    }
  );
  assert.deepEqual(deltas, [
    {type: "delta", requestID: request.requestID, text: "Lead first. "},
    {type: "delta", requestID: request.requestID, text: "Add proof."},
  ]);
  assert.deepEqual(completion, {
    requestID: request.requestID,
    text: "Lead first. Add proof.",
    model: "gemini-2.5-flash",
    qualityTier: "fast",
    finishReason: "STOP",
    inputTokens: 120,
    outputTokens: 24,
  });
});

test("accepts a final metadata-only Gen AI stream chunk", async () => {
  const completion = await consumeCoachStream(
    validateCoachChatRequest(request),
    "gemini-2.5-flash",
    {
      generate: async () => (async function* () {
        yield vertexResponse("Lead first.", undefined);
        yield vertexResponse("", FinishReason.STOP, true);
      })(),
    }
  );

  assert.equal(completion.text, "Lead first.");
  assert.equal(completion.finishReason, "STOP");
  assert.equal(completion.inputTokens, 120);
  assert.equal(completion.outputTokens, 24);
});

test("rejects truncated and empty Vertex completions", async () => {
  for (const result of [
    vertexStream(["Partial"], FinishReason.MAX_TOKENS),
    vertexStream([], FinishReason.STOP),
  ]) {
    await assert.rejects(() => consumeCoachStream(
      validateCoachChatRequest(request),
      "gemini-2.5-flash",
      {generate: async () => result}
    ));
  }
});

test("propagates Vertex failures for callable error mapping", async () => {
  const providerError = new Error("vertex unavailable");
  await assert.rejects(
    () => consumeCoachStream(
      validateCoachChatRequest(request),
      "gemini-2.5-flash",
      {generate: async () => {
        throw providerError;
      }}
    ),
    providerError
  );
});

test(
  "cancels an in-flight stream when the callable client disconnects",
  async () => {
    const controller = new AbortController();
    const blockedStream: AsyncIterable<CoachGenerateContentResponse> =
      (async function* () {
        await new Promise<void>(() => undefined);
        yield vertexResponse("never sent", FinishReason.STOP, true);
      })();
    const pending = consumeCoachStream(
      validateCoachChatRequest(request),
      "gemini-2.5-flash",
      {generate: async () => blockedStream, signal: controller.signal}
    );
    controller.abort();
    await assert.rejects(pending, (error: unknown) => {
      return typeof error === "object" && error !== null &&
      "code" in error && error.code === "cancelled";
    });
  }
);
