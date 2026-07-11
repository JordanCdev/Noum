import assert from "node:assert/strict";
import test from "node:test";
import {
  CHALLENGE_REACTIONS,
  INITIAL_RATING,
  advanceSocialState,
  calculateCurrentStreak,
  calculateRatingDelta,
  challengeEnvelope,
  isoWeekKey,
  stableLegacyUUID,
  storedSocialState,
  validateCreateChallengeRequest,
  validateRecordPeerSessionRequest,
  validateSetChallengeReactionRequest,
  validateStoredSocialSession,
  validateSubmitChallengeResultRequest,
} from "./socialAuthority.js";

const sessionID = "A713738E-D9ED-4337-986E-09205089D42E";
const challengeID = "2CB446D8-4F39-43A6-A95C-2486E47155BC";
const nowMs = Date.UTC(2026, 6, 11, 12);

/**
 * Builds one persisted session fixture with focused overrides.
 * @param {Record<string, unknown>} overrides Fields to replace.
 * @return {Record<string, unknown>} Persisted session data.
 */
function session(
  overrides: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    id: sessionID,
    transcript: "A complete real rep with enough evidence.",
    duration: 42,
    date: nowMs / 1_000,
    score: 8,
    isRated: true,
    isEvaluationFixture: false,
    fixtureID: null,
    headline: "Clear structure",
    ...overrides,
  };
}

test("validates and canonicalizes every exact social request", () => {
  assert.deepEqual(validateRecordPeerSessionRequest({
    schemaVersion: 1,
    sessionID: sessionID.toLowerCase(),
    displayName: "Jordan",
  }), {
    schemaVersion: 1,
    sessionID,
    displayName: "Jordan",
  });
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
});

test("rejects identity, authority, and oversized fields in requests", () => {
  assert.throws(() => validateRecordPeerSessionRequest({
    schemaVersion: 1,
    sessionID,
    displayName: "Jordan",
    rating: 1_000,
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
    schemaVersion: 1,
    challengeID,
    sessionID,
    score: 10,
  }));
  assert.throws(() => validateSetChallengeReactionRequest({
    schemaVersion: 1,
    challengeID,
    reaction: "🚀",
  }));
});

test("reaction validation covers the complete closed enum", () => {
  for (const reaction of CHALLENGE_REACTIONS) {
    assert.equal(validateSetChallengeReactionRequest({
      schemaVersion: 1,
      challengeID,
      reaction,
    }).reaction, reaction);
  }
});

test("accepts only complete, scored, non-fixture sessions", () => {
  const validated = validateStoredSocialSession(session(), sessionID, nowMs);
  assert.equal(validated.score, 8);
  assert.equal(validated.isRated, true);
  assert.equal(validated.summary, "Clear structure");
  for (const invalid of [
    session({score: 8.5}),
    session({date: "2026-07-11"}),
    session({isRated: "true"}),
    session({isEvaluationFixture: true, fixtureID: "fixture-1"}),
    session({transcript: ""}),
    session({duration: 0}),
  ]) {
    assert.throws(() => validateStoredSocialSession(invalid, sessionID, nowMs));
  }
});

test("ports RatingEngine delta and clamping inputs exactly", () => {
  assert.equal(calculateRatingDelta(400, 8), 13);
  assert.equal(calculateRatingDelta(400, 0), -13);
  assert.equal(calculateRatingDelta(600, 10), 10);
  assert.equal(calculateRatingDelta(800, 10), 3);
  assert.equal(calculateRatingDelta(1_000, 10), 0);
});

test("ISO week keys remain correct across calendar-year edges", () => {
  assert.equal(isoWeekKey(Date.UTC(2025, 11, 29)), "2026-W01");
  assert.equal(isoWeekKey(Date.UTC(2026, 0, 4)), "2026-W01");
  assert.equal(isoWeekKey(Date.UTC(2026, 0, 5)), "2026-W02");
});

test("current streak mirrors the one-grace-day app rule", () => {
  assert.equal(calculateCurrentStreak(["2026-07-11"], nowMs), 1);
  assert.equal(calculateCurrentStreak([
    "2026-07-11", "2026-07-09", "2026-07-08",
  ], nowMs), 3);
  assert.equal(calculateCurrentStreak([
    "2026-07-11", "2026-07-08",
  ], nowMs), 1);
  assert.equal(calculateCurrentStreak(["2026-07-10"], nowMs), 1);
});

test("advances rated public state once from raw session evidence", () => {
  const initial = storedSocialState(null, "Jordan", nowMs);
  assert.equal(initial.rating, INITIAL_RATING);
  const validated = validateStoredSocialSession(session(), sessionID, nowMs);
  const result = advanceSocialState(
    initial,
    validated,
    "firebase-user",
    "Jordan",
    nowMs
  );
  assert.equal(result.ratingDelta, 13);
  assert.deepEqual(result.profile, {
    accountID: "firebase-user",
    displayName: "Jordan",
    rating: 413,
    peakRating: 413,
    currentStreak: 1,
    weeklyReps: 1,
    weeklyDelta: 13,
    leagueTier: "silver",
    updatedAt: nowMs / 1_000,
  });
  assert.equal(result.state.currentBucket, "silver_2026-W28");
});

test("unrated sessions count as reps without forging placement", () => {
  const initial = storedSocialState(null, "Jordan", nowMs);
  const validated = validateStoredSocialSession(
    session({isRated: false, score: 7}),
    sessionID,
    nowMs
  );
  const result = advanceSocialState(
    initial,
    validated,
    "firebase-user",
    "Jordan",
    nowMs
  );
  assert.equal(result.profile.rating, INITIAL_RATING);
  assert.equal(result.profile.weeklyReps, 1);
  assert.equal(result.profile.weeklyDelta, 0);
  assert.equal(result.profile.leagueTier, null);
  assert.equal(result.state.currentBucket, null);
});

test("legacy challenge UUIDs are deterministic but not authoritative", () => {
  const first = stableLegacyUUID("firebase-user");
  assert.equal(first, stableLegacyUUID("firebase-user"));
  assert.notEqual(first, stableLegacyUUID("firebase-opponent"));
  assert.match(first, /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab]/);
});

test("challenge envelope emits numeric dates and explicit nulls", () => {
  const value = {
    schemaVersion: 1,
    id: challengeID,
    prompt: "Give a concise project update.",
    createdAt: nowMs / 1_000,
    expiresAt: (nowMs + 86_400_000) / 1_000,
    creatorID: stableLegacyUUID("firebase-user"),
    creatorName: "Jordan",
    creatorAccountID: "firebase-user",
    opponentID: stableLegacyUUID("firebase-opponent"),
    opponentName: "Alex",
    opponentAccountID: "firebase-opponent",
    participantIDs: ["firebase-user", "firebase-opponent"],
    creatorScore: 8,
    creatorDuration: 42,
    creatorSummary: "Clear structure",
    creatorReaction: "👏",
  };
  const envelope = challengeEnvelope(value);
  assert.equal(envelope.createdAt, nowMs / 1_000);
  assert.equal(envelope.creatorScore, 8);
  assert.equal(envelope.opponentScore, null);
  assert.equal(envelope.opponentReaction, null);
});
