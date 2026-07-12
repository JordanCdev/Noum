/* eslint-disable valid-jsdoc, max-len */

import assert from "node:assert/strict";
import test from "node:test";
import {
  CHALLENGE_DOCUMENT_SCHEMA_VERSION,
  CHALLENGE_REACTIONS,
  INITIAL_RATING,
  advanceSocialState,
  assertEvidenceBoundToChallenge,
  assertSocialReferenceCutoverComplete,
  calculateCurrentStreak,
  calculateRatingDelta,
  challengeEnvelope,
  challengeSubmissionDocument,
  combinedChallengeDocument,
  currentTrustedLeagueBucket,
  isoWeekKey,
  promptDigest,
  socialReferenceManifestIncludingChallenge,
  socialReferenceManifestUpdatingLeagueMembership,
  stableLegacyUUID,
  storedSocialState,
  validateCreateChallengeRequest,
  validateGetPeerProfileRequest,
  validateListLeagueMembersRequest,
  validateRecordPeerSessionRequest,
  validateReciprocalFriendLinks,
  validateSetChallengeReactionRequest,
  validateSocialReferenceManifest,
  validateStoredPublicProfile,
  validateSubmitChallengeResultRequest,
  validateVerifiedSessionEvidence,
} from "./socialAuthority.js";

const sessionID = "A713738E-D9ED-4337-986E-09205089D42E";
const challengeID = "2CB446D8-4F39-43A6-A95C-2486E47155BC";
const nowMs = Date.UTC(2026, 6, 11, 12);

/** Firestore Timestamp-compatible deterministic test value. */
function timestamp(milliseconds: number): {toMillis: () => number} {
  return {toMillis: () => milliseconds};
}

/** Builds one server evidence fixture with focused overrides. */
function evidence(
  overrides: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    schemaVersion: 1,
    evidenceSource: "noum-server-evaluator",
    evaluatorVersion: 1,
    competitiveEligible: true,
    sessionID,
    score: 8,
    duration: 42,
    completedAt: timestamp(nowMs),
    attestedAt: timestamp(nowMs + 1_000),
    isRated: true,
    summary: "Clear structure",
    challengeID: null,
    promptDigest: null,
    ...overrides,
  };
}

/** Builds v2 challenge metadata without competitive result fields. */
function challenge(
  overrides: Record<string, unknown> = {}
): Record<string, unknown> {
  const prompt = "Give a concise project update.";
  return {
    schemaVersion: CHALLENGE_DOCUMENT_SCHEMA_VERSION,
    id: challengeID,
    prompt,
    promptDigest: promptDigest(prompt),
    createdAt: timestamp(nowMs - 60_000),
    expiresAt: timestamp(nowMs + 86_400_000),
    creatorID: stableLegacyUUID("firebase-user"),
    creatorName: "Jordan",
    creatorAccountID: "firebase-user",
    opponentID: stableLegacyUUID("firebase-opponent"),
    opponentName: "Alex",
    opponentAccountID: "firebase-opponent",
    participantIDs: ["firebase-user", "firebase-opponent"],
    completedAt: null,
    ...overrides,
  };
}

test("validates and canonicalizes every exact social request", () => {
  assert.deepEqual(validateRecordPeerSessionRequest({
    schemaVersion: 1,
    sessionID: sessionID.toLowerCase(),
    displayName: "Jordan",
  }), {schemaVersion: 1, sessionID, displayName: "Jordan"});
  assert.deepEqual(validateCreateChallengeRequest({
    schemaVersion: 1,
    challengeID: challengeID.toLowerCase(),
    opponentAccountID: "firebase-opponent",
    prompt: "Give a concise project update.",
  }), {
    schemaVersion: 1,
    challengeID,
    opponentAccountID: "firebase-opponent",
    prompt: "Give a concise project update.",
  });
  assert.deepEqual(validateSubmitChallengeResultRequest({
    schemaVersion: 1,
    challengeID,
    sessionID,
  }), {schemaVersion: 1, challengeID, sessionID});
  assert.deepEqual(validateSetChallengeReactionRequest({
    schemaVersion: 1,
    challengeID,
    reaction: "👏",
  }), {schemaVersion: 1, challengeID, reaction: "👏"});
  assert.deepEqual(validateGetPeerProfileRequest({
    schemaVersion: 1,
    accountID: "firebase-opponent",
  }), {schemaVersion: 1, accountID: "firebase-opponent"});
  assert.deepEqual(validateListLeagueMembersRequest({
    schemaVersion: 1,
    limit: 20,
  }), {schemaVersion: 1, limit: 20});
});

test("rejects identity, authority, and oversized request fields", () => {
  assert.throws(() => validateRecordPeerSessionRequest({
    schemaVersion: 1, sessionID, displayName: "Jordan", rating: 1_000,
  }));
  assert.throws(() => validateCreateChallengeRequest({
    schemaVersion: 1,
    challengeID,
    opponentAccountID: "opponent",
    prompt: "p".repeat(501),
  }));
  assert.throws(() => validateCreateChallengeRequest({
    schemaVersion: 1,
    challengeID,
    opponentAccountID: "opponent/forged",
    prompt: "A bounded prompt",
  }));
  assert.throws(() => validateSubmitChallengeResultRequest({
    schemaVersion: 1, challengeID, sessionID, score: 10,
  }));
  assert.throws(() => validateSetChallengeReactionRequest({
    schemaVersion: 1, challengeID, reaction: "🚀",
  }));
  assert.throws(() => validateGetPeerProfileRequest({
    schemaVersion: 1, accountID: "peer", rating: 1_000,
  }));
  assert.throws(() => validateListLeagueMembersRequest({
    schemaVersion: 1, limit: 51,
  }));
});

test("reaction validation covers the complete closed enum", () => {
  for (const reaction of CHALLENGE_REACTIONS) {
    assert.equal(validateSetChallengeReactionRequest({
      schemaVersion: 1, challengeID, reaction,
    }).reaction, reaction);
  }
});

test("accepts only attested server evidence and rejects client session shapes", () => {
  const validated = validateVerifiedSessionEvidence(
    evidence(),
    sessionID,
    nowMs + 2_000
  );
  assert.equal(validated.score, 8);
  assert.equal(validated.isRated, true);
  assert.equal(validated.summary, "Clear structure");
  for (const invalid of [
    {id: sessionID, score: 10, date: nowMs / 1_000, isRated: true},
    evidence({score: 8.5}),
    evidence({completedAt: nowMs / 1_000}),
    evidence({evidenceSource: "client-sync"}),
    evidence({competitiveEligible: false}),
    evidence({attestedAt: timestamp(nowMs - 1)}),
  ]) {
    assert.throws(() => validateVerifiedSessionEvidence(
      invalid,
      sessionID,
      nowMs + 2_000
    ));
  }
});

test("ports RatingEngine delta exactly", () => {
  assert.equal(calculateRatingDelta(400, 8), 13);
  assert.equal(calculateRatingDelta(400, 0), -13);
  assert.equal(calculateRatingDelta(600, 10), 10);
  assert.equal(calculateRatingDelta(800, 10), 3);
  assert.equal(calculateRatingDelta(1_000, 10), 0);
});

test("ISO week and strict consecutive-day streak stay deterministic", () => {
  assert.equal(isoWeekKey(Date.UTC(2025, 11, 29)), "2026-W01");
  assert.equal(isoWeekKey(Date.UTC(2026, 0, 5)), "2026-W02");
  assert.equal(calculateCurrentStreak([
    "2026-07-11", "2026-07-09", "2026-07-08",
  ], nowMs), 1);
  assert.equal(calculateCurrentStreak([
    "2026-07-11", "2026-07-08",
  ], nowMs), 1);
});

test("advances public rating only from verified evidence", () => {
  const initial = storedSocialState(null, "Jordan", nowMs);
  assert.equal(initial.schemaVersion, 2);
  assert.equal(initial.rating, INITIAL_RATING);
  const verified = validateVerifiedSessionEvidence(
    evidence(),
    sessionID,
    nowMs + 2_000
  );
  const result = advanceSocialState(
    initial,
    verified,
    "firebase-user",
    "Jordan",
    nowMs
  );
  assert.equal(result.ratingDelta, 13);
  assert.equal(result.profile.rating, 413);
  assert.equal(result.profile.weeklyReps, 1);
  assert.equal(result.profile.leagueTier, "silver");
  assert.equal(result.state.currentBucket, "silver_2026-W28");
});

test("competitive rating rejects evidence processed out of recording order", () => {
  const initial = storedSocialState(null, "Jordan", nowMs);
  const first = advanceSocialState(
    initial,
    validateVerifiedSessionEvidence(evidence(), sessionID, nowMs + 2_000),
    "firebase-user",
    "Jordan",
    nowMs
  ).state;
  const olderID = "9713738E-D9ED-4337-986E-09205089D42E";
  const older = validateVerifiedSessionEvidence(evidence({
    sessionID: olderID,
    completedAt: timestamp(nowMs - 1),
    attestedAt: timestamp(nowMs + 1),
  }), olderID, nowMs + 2_000);
  assert.throws(
    () => advanceSocialState(first, older, "firebase-user", "Jordan", nowMs),
    (error: unknown) => (error as {details?: {reason?: string}})
      .details?.reason === "out-of-order-evidence"
  );
  const sameTimeLowerID = "0713738E-D9ED-4337-986E-09205089D42E";
  const tied = validateVerifiedSessionEvidence(evidence({
    sessionID: sameTimeLowerID,
  }), sameTimeLowerID, nowMs + 2_000);
  assert.throws(
    () => advanceSocialState(first, tied, "firebase-user", "Jordan", nowMs),
    (error: unknown) => (error as {details?: {reason?: string}})
      .details?.reason === "out-of-order-evidence"
  );
});

test("public profiles and legacy cutover proof validate strictly", () => {
  const profile = {
    accountID: "firebase-user",
    displayName: "Jordan",
    rating: 413,
    peakRating: 413,
    currentStreak: 1,
    weeklyReps: 1,
    weeklyDelta: 13,
    leagueTier: "silver",
    updatedAt: timestamp(nowMs),
  };
  assert.equal(
    validateStoredPublicProfile(profile, "firebase-user").updatedAt,
    nowMs / 1_000
  );
  assert.throws(() => validateStoredPublicProfile(
    {...profile, accountID: "forged"},
    "firebase-user"
  ));
  assert.doesNotThrow(() => assertSocialReferenceCutoverComplete({
    schemaVersion: 1,
    status: "complete",
    completedAt: timestamp(nowMs),
  }));
  assert.throws(
    () => assertSocialReferenceCutoverComplete(undefined),
    (error: unknown) => (error as {details?: {reason?: string}})
      .details?.reason === "social-reference-cutover-incomplete"
  );
});

test("league reads reject a trusted bucket from a previous ISO week", () => {
  const currentWeek = isoWeekKey(nowMs);
  const currentState = {
    ...storedSocialState(undefined, "Jordan", nowMs),
    currentBucket: `silver_${currentWeek}`,
  };
  assert.equal(
    currentTrustedLeagueBucket(currentState, nowMs),
    `silver_${currentWeek}`
  );
  assert.throws(
    () => currentTrustedLeagueBucket(currentState, nowMs + 8 * 86_400_000),
    (error: unknown) => (error as {details?: {reason?: string}})
      .details?.reason === "trusted-social-state-unavailable"
  );
});

test("prompt binding rejects mismatched and expired evidence", () => {
  const metadata = challenge();
  const bound = validateVerifiedSessionEvidence(evidence({
    challengeID,
    promptDigest: metadata.promptDigest,
  }), sessionID, nowMs + 2_000);
  assert.doesNotThrow(() => assertEvidenceBoundToChallenge(
    bound,
    metadata,
    nowMs
  ));
  assert.throws(() => assertEvidenceBoundToChallenge(
    {...bound, promptDigest: "0".repeat(64)},
    metadata,
    nowMs
  ));
  assert.throws(() => assertEvidenceBoundToChallenge(
    bound,
    challenge({expiresAt: timestamp(nowMs - 1)}),
    nowMs
  ));
});

test("challenge envelope hides the opponent until combined materializes", () => {
  const metadata = challenge();
  const creatorEvidence = validateVerifiedSessionEvidence(evidence({
    challengeID,
    promptDigest: metadata.promptDigest,
  }), sessionID, nowMs + 2_000);
  const opponentSessionID = "B713738E-D9ED-4337-986E-09205089D42E";
  const opponentEvidence = validateVerifiedSessionEvidence(evidence({
    sessionID: opponentSessionID,
    score: 6,
    challengeID,
    promptDigest: metadata.promptDigest,
  }), opponentSessionID, nowMs + 2_000);
  const creator = challengeSubmissionDocument(
    challengeID,
    "firebase-user",
    "creator",
    creatorEvidence,
    timestamp(nowMs)
  );
  const opponent = challengeSubmissionDocument(
    challengeID,
    "firebase-opponent",
    "opponent",
    opponentEvidence,
    timestamp(nowMs)
  );
  const creatorOnly = challengeEnvelope(
    metadata,
    "firebase-user",
    creator
  );
  assert.equal(creatorOnly.creatorScore, 8);
  assert.equal(creatorOnly.opponentScore, null);
  const opponentOnly = challengeEnvelope(
    metadata,
    "firebase-opponent",
    opponent
  );
  assert.equal(opponentOnly.creatorScore, null);
  assert.equal(opponentOnly.opponentScore, 6);
  const combined = combinedChallengeDocument(
    challengeID,
    creator,
    opponent,
    timestamp(nowMs)
  );
  const revealed = challengeEnvelope(
    metadata,
    "firebase-user",
    creator,
    combined
  );
  assert.equal(revealed.creatorScore, 8);
  assert.equal(revealed.opponentScore, 6);
});

test("reciprocal server friend links fail closed on local-only claims", () => {
  const pairID = "C713738E-D9ED-4337-986E-09205089D42E";
  const creatorLink = {
    status: "active",
    accountID: "firebase-user",
    friendAccountID: "firebase-opponent",
    pairID,
    linkedAt: timestamp(nowMs),
  };
  const opponentLink = {
    status: "active",
    accountID: "firebase-opponent",
    friendAccountID: "firebase-user",
    pairID,
    linkedAt: timestamp(nowMs),
  };
  assert.doesNotThrow(() => validateReciprocalFriendLinks(
    creatorLink,
    opponentLink,
    "firebase-user",
    "firebase-opponent"
  ));
  assert.throws(() => validateReciprocalFriendLinks(
    {displayName: "Alex", accountID: "firebase-opponent"},
    opponentLink,
    "firebase-user",
    "firebase-opponent"
  ));
});

test("exact deletion manifests reject injected or unbounded paths", () => {
  assert.deepEqual(validateSocialReferenceManifest({
    leagueMembershipPaths: [
      "leagues/silver_2026-W28/members/firebase-user",
    ],
    challengeIDs: [challengeID],
    friendAccountIDs: ["firebase-opponent"],
  }, "firebase-user"), {
    leagueMembershipPaths: [
      "leagues/silver_2026-W28/members/firebase-user",
    ],
    challengeIDs: [challengeID],
    friendAccountIDs: ["firebase-opponent"],
  });
  assert.throws(() => validateSocialReferenceManifest({
    leagueMembershipPaths: ["profiles_public/victim"],
    challengeIDs: [],
    friendAccountIDs: [],
  }, "firebase-user"));
  assert.throws(() => validateSocialReferenceManifest({
    leagueMembershipPaths: [],
    challengeIDs: Array.from({length: 101}, () => challengeID),
    friendAccountIDs: [],
  }, "firebase-user"));
  const legacyMemberships = Array.from({length: 5}, (_, index) =>
    `leagues/silver_2026-W${String(index + 1).padStart(2, "0")}/` +
      "members/firebase-user"
  );
  assert.equal(validateSocialReferenceManifest({
    leagueMembershipPaths: legacyMemberships,
    challengeIDs: [],
    friendAccountIDs: [],
  }, "firebase-user").leagueMembershipPaths.length, 5);
  assert.throws(() => validateSocialReferenceManifest({
    leagueMembershipPaths: Array.from({length: 17}, (_, index) =>
      `leagues/silver_2025-W${String(index + 1).padStart(2, "0")}/` +
        "members/firebase-user"
    ),
    challengeIDs: [],
    friendAccountIDs: [],
  }, "firebase-user"));
});

test("challenge references preserve a complete bounded deletion manifest", () => {
  assert.deepEqual(socialReferenceManifestIncludingChallenge(
    undefined,
    "firebase-user",
    challengeID.toLowerCase()
  ), {
    leagueMembershipPaths: [],
    challengeIDs: [challengeID],
    friendAccountIDs: [],
  });
  const challengeIDs = Array.from({length: 100}, (_, index) =>
    `00000000-0000-4000-8000-${index.toString(16).padStart(12, "0")}`
      .toUpperCase()
  );
  assert.throws(() => socialReferenceManifestIncludingChallenge({
    leagueMembershipPaths: [],
    challengeIDs,
    friendAccountIDs: [],
  }, "firebase-user", challengeID));
});

test("trusted reps preserve backfilled legacy league references", () => {
  const legacyPaths = Array.from({length: 5}, (_, index) =>
    `leagues/silver_2026-W${String(index + 1).padStart(2, "0")}/` +
      "members/firebase-user"
  );
  const updated = socialReferenceManifestUpdatingLeagueMembership({
    leagueMembershipPaths: legacyPaths,
    challengeIDs: [challengeID],
    friendAccountIDs: ["firebase-opponent"],
  }, "firebase-user", null, "silver_2026-W28");
  assert.deepEqual(updated.leagueMembershipPaths, [
    ...legacyPaths,
    "leagues/silver_2026-W28/members/firebase-user",
  ]);
  assert.deepEqual(updated.challengeIDs, [challengeID]);
  assert.deepEqual(updated.friendAccountIDs, ["firebase-opponent"]);
});

test("legacy challenge UUIDs remain deterministic presentation values", () => {
  const first = stableLegacyUUID("firebase-user");
  assert.equal(first, stableLegacyUUID("firebase-user"));
  assert.notEqual(first, stableLegacyUUID("firebase-opponent"));
  assert.match(first, /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab]/);
});
