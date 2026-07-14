/* eslint-disable require-jsdoc, max-len */

import assert from "node:assert/strict";
import test from "node:test";
import {
  decideRecommendationMutation,
  normalizeStoredRecommendationState,
  validateRecommendationMutation,
} from "./recommendationState.js";

const firstMutationID = "2cb446d8-4f39-43a6-a95c-2486e47155bc";
const secondMutationID = "783ab966-e91b-4ca4-8f7a-7e50113fa2c6";

function request(overrides: Record<string, unknown> = {}) {
  return {
    schemaVersion: 1,
    mutationID: firstMutationID,
    expectedRemoteRevision: 0,
    pendingExposure: null,
    outcomes: [],
    ...overrides,
  };
}

test("absent and exact legacy state normalize at revision zero", () => {
  assert.deepEqual(normalizeStoredRecommendationState(undefined), {
    schemaVersion: 1,
    remoteRevision: 0,
    lastMutationID: null,
    pendingExposure: null,
    outcomes: [],
  });
  assert.equal(normalizeStoredRecommendationState({
    pendingExposure: null,
    outcomes: [],
  }).remoteRevision, 0);
});

test("matching revision commits and advances exactly once", () => {
  const input = validateRecommendationMutation(request());
  const first = decideRecommendationMutation(
    normalizeStoredRecommendationState(undefined),
    input
  );
  assert.equal(first.status, "committed");
  assert.equal(first.state.remoteRevision, 1);
  assert.equal(first.state.lastMutationID, firstMutationID);

  const replay = decideRecommendationMutation(first.state, input);
  assert.equal(replay.status, "alreadyCommitted");
  assert.equal(replay.state.remoteRevision, 1);
});

test("stale revision returns authoritative state without overwriting it", () => {
  const current = decideRecommendationMutation(
    normalizeStoredRecommendationState(undefined),
    validateRecommendationMutation(request())
  ).state;
  const stale = validateRecommendationMutation(request({
    mutationID: secondMutationID,
    expectedRemoteRevision: 0,
    outcomes: [{
      id: secondMutationID,
      fingerprint: "timed|fillers",
      title: "Clean the opening",
      mode: "timed",
      sessionID: firstMutationID,
      followed: true,
      completedAt: 1_720_000_010,
      scoreDelta: 1,
      fillerDelta: -1,
      durationDelta: 0,
    }],
  }));
  const conflict = decideRecommendationMutation(current, stale);
  assert.equal(conflict.status, "conflict");
  assert.deepEqual(conflict.state, current);
});

test("malformed and unknown-version documents fail closed", () => {
  assert.throws(() => normalizeStoredRecommendationState({outcomes: []}));
  assert.throws(() => normalizeStoredRecommendationState({
    schemaVersion: 2,
    remoteRevision: 1,
    lastMutationID: firstMutationID,
    pendingExposure: null,
    outcomes: [],
  }));
  try {
    normalizeStoredRecommendationState({
      schemaVersion: 1,
      remoteRevision: 1,
      lastMutationID: 17,
      pendingExposure: null,
      outcomes: [],
    });
    assert.fail("malformed stored mutation identity should fail");
  } catch (error) {
    assert.equal((error as {code?: string}).code, "failed-precondition");
  }
});

test("a replayed mutation ID must carry the exact committed body", () => {
  const input = validateRecommendationMutation(request());
  const current = decideRecommendationMutation(
    normalizeStoredRecommendationState(undefined),
    input
  ).state;
  const changedReplay = validateRecommendationMutation(request({
    pendingExposure: {
      fingerprint: "timed|fillers",
      title: "Clean the opening",
      focus: "filler control",
      target: "Below 2 fillers/min",
      mode: "timed",
      isAIBacked: false,
      shownAt: 1_720_000_000,
    },
  }));

  assert.throws(() => decideRecommendationMutation(current, changedReplay));
});

test("public request rejects account identity, oversized ledgers, and bad enums", () => {
  assert.throws(() => validateRecommendationMutation({
    ...request(),
    accountID: "forged",
  }));
  assert.throws(() => validateRecommendationMutation(request({
    expectedRemoteRevision: Number.MAX_SAFE_INTEGER,
  })));
  assert.throws(() => validateRecommendationMutation(request({
    outcomes: Array.from({length: 41}, () => ({})),
  })));
  assert.throws(() => validateRecommendationMutation(request({
    pendingExposure: {
      fingerprint: "timed|fillers",
      title: "Clean the opening",
      focus: "filler control",
      target: "Below 2 fillers/min",
      mode: "invented",
      isAIBacked: false,
      shownAt: 1_720_000_000,
    },
  })));
  const duplicateID = "088d28ee-1400-452c-8880-2ed23faae45e";
  const duplicateSessionID = "a8117892-0cb3-454b-87d3-e8850d57c43f";
  const outcome = {
    id: duplicateID,
    fingerprint: "timed|fillers",
    title: "Clean the opening",
    mode: "timed",
    sessionID: duplicateSessionID,
    followed: true,
    completedAt: 1_720_000_010,
    scoreDelta: 1,
    fillerDelta: -1,
    durationDelta: 0,
  };
  assert.throws(() => validateRecommendationMutation(request({
    outcomes: [outcome, {...outcome}],
  })));
  assert.throws(() => validateRecommendationMutation(request({
    outcomes: [{...outcome, wordsPerMinute: -1}],
  })));
  assert.throws(() => validateRecommendationMutation(request({
    outcomes: [{...outcome, comparisonSchemaVersion: 2}],
  })));
});

test("current versioned state validates its bounded nested payload", () => {
  const current = normalizeStoredRecommendationState({
    schemaVersion: 1,
    remoteRevision: 4,
    lastMutationID: firstMutationID,
    pendingExposure: {
      fingerprint: "timed|fillers",
      title: "Clean the opening",
      focus: "filler control",
      target: "Below 2 fillers/min",
      mode: "timed",
      isAIBacked: false,
      shownAt: 1_720_000_000,
      observabilityID: secondMutationID,
    },
    outcomes: [],
    updatedAt: {},
  });
  assert.equal(current.remoteRevision, 4);
  assert.equal(current.pendingExposure?.mode, "timed");
});
