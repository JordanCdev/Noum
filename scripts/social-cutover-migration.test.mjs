import assert from "node:assert/strict";
import test from "node:test";

import {
  applyRecoverableCutover,
  canonicalSHA256,
  createBackupEnvelope,
  CUTOVER_JOURNAL_PATH,
  CUTOVER_PHASES,
  decodeFirestoreValue,
  encodeFirestoreValue,
  MemoryMigrationStore,
  rollbackRecoverableCutover,
  validatePrivateProfile,
  verifyBackupEnvelope,
} from "./social-cutover-migration.mjs";

const SOURCE_BINDING = Object.freeze({
  repositoryCommit: "a".repeat(40),
  implementationSHA256: "b".repeat(64),
});
const RUN_ID = "release-2026-07-14";
const ACCOUNT_A = "account-a";
const ACCOUNT_B = "account-b";
const CHALLENGE_ID = "783AB966-E91B-4CA4-8F7A-7E50113FA2C6";

function validPrivateProfile(overrides = {}) {
  return {
    speakingContext: "work",
    primaryGoal: "reduceFillers",
    confidenceLevel: "rebuilding",
    biggestChallenge: "fillerWords",
    customChallengeText: null,
    desiredOutcome: "concise",
    speakingStyleGoal: "warm",
    chosenStyleGoal: null,
    styleReference: "",
    coachingBrief: "Speak with control.",
    motivationWhyNow: "A presentation is approaching.",
    successVision: "Make the point without rushing.",
    paraphrasedGoal: null,
    bigMomentID: null,
    secondaryStyleGoal: null,
    ...overrides,
  };
}

function inventory(overrides = {}) {
  return {
    profiles: [{
      path: `profiles_public/${ACCOUNT_A}`,
      data: {
        accountID: ACCOUNT_A,
        displayName: "Alex",
        rating: 9_999,
        clientAuthoredResult: "never-trust-this",
        updatedAt: {$noumType: "timestamp", seconds: 1_720_000_000, nanoseconds: 0},
      },
    }],
    leagueMemberships: [{
      path: `leagues/gold_2026-W29/members/${ACCOUNT_A}`,
      data: {
        accountID: ACCOUNT_A,
        rating: 9_999,
        weeklyDelta: 500,
      },
    }],
    privateProfiles: [
      {
        path: `users/${ACCOUNT_A}/profile/main`,
        data: validPrivateProfile(),
      },
      {
        path: `users/${ACCOUNT_B}/profile/main`,
        data: validPrivateProfile({
          speakingContext: "interviews",
          chosenStyleGoal: "executive",
          secondaryStyleGoal: "storytelling",
          customChallengeText: "I lose the thread in panel interviews.",
          paraphrasedGoal: "Answer panel questions with a clear through-line.",
          bigMomentID: CHALLENGE_ID,
        }),
      },
    ],
    challenges: [{
      path: `challenges/${CHALLENGE_ID}`,
      data: {
        creatorAccountID: ACCOUNT_A,
        opponentAccountID: ACCOUNT_B,
        creatorScore: 1_000,
        opponentScore: 0,
      },
    }],
    friendLinks: [
      {
        path: `_socialFriendLinks/${ACCOUNT_A}/friends/${ACCOUNT_B}`,
        data: {createdAt: 1_720_000_000},
      },
      {
        path: `_socialFriendLinks/${ACCOUNT_B}/friends/${ACCOUNT_A}`,
        data: {createdAt: 1_720_000_000},
      },
    ],
    existingManifests: [{
      path: `_socialReferences/${ACCOUNT_A}`,
      data: {
        leagueMembershipPaths: [
          `leagues/gold_2026-W29/members/${ACCOUNT_A}`,
        ],
        challengeIDs: [],
        friendAccountIDs: [],
        updatedAt: {$noumType: "timestamp", seconds: 1_720_000_000, nanoseconds: 0},
      },
    }],
    existingCutover: null,
    ...overrides,
  };
}

function envelope(overrides = {}) {
  return createBackupEnvelope({
    projectID: "noum-d0b6f",
    capturedAt: "2026-07-14T12:00:00.000Z",
    binding: SOURCE_BINDING,
    inventory: inventory(overrides),
  });
}

function documentsForStore(sourceInventory = inventory()) {
  return [
    ...sourceInventory.profiles,
    ...sourceInventory.leagueMemberships,
    ...sourceInventory.privateProfiles,
    ...sourceInventory.challenges,
    ...sourceInventory.friendLinks,
    ...sourceInventory.existingManifests,
  ];
}

function initialSnapshot(store) {
  return [...store.documents.entries()].sort(([left], [right]) =>
    left.localeCompare(right)
  );
}

test("canonical backup digest binds project, source, and key-order-independent data", () => {
  const backup = envelope();
  assert.equal(backup.digest.value, canonicalSHA256(backup.payload));
  assert.equal(backup.payload.projectID, "noum-d0b6f");
  assert.deepEqual(backup.payload.sourceBinding, SOURCE_BINDING);
  verifyBackupEnvelope(backup, {
    projectID: "noum-d0b6f",
    expectedDigest: backup.digest.value,
    binding: SOURCE_BINDING,
  });

  const tampered = structuredClone(backup);
  tampered.payload.inventory.profiles[0].data.rating = 1;
  assert.throws(
    () => verifyBackupEnvelope(tampered),
    /digest does not match/
  );
});

test("private profile inventory accepts only current enums, fields, and bounds", () => {
  assert.equal(validatePrivateProfile(validPrivateProfile()).speakingContext, "work");
  assert.doesNotThrow(() => validatePrivateProfile(validPrivateProfile({
    customChallengeText: "c".repeat(90),
    paraphrasedGoal: "p".repeat(220),
    styleReference: "s".repeat(500),
    coachingBrief: "b".repeat(2_000),
    motivationWhyNow: "m".repeat(1_000),
    successVision: "v".repeat(1_000),
  })));

  for (const invalid of [
    {speakingContext: "meetings"},
    {chosenStyleGoal: "confident"},
    {secondaryStyleGoal: "calm"},
    {customChallengeText: "c".repeat(91)},
    {paraphrasedGoal: "p".repeat(221)},
    {bigMomentID: "not-a-uuid"},
    {inventedField: true},
  ]) {
    assert.throws(() => validatePrivateProfile(validPrivateProfile(invalid)));
  }
});

test("lowercase challenge document and manifest IDs fail closed", () => {
  const lowercaseID = CHALLENGE_ID.toLowerCase();
  assert.throws(
    () => envelope({
      challenges: [{
        path: `challenges/${lowercaseID}`,
        data: {
          creatorAccountID: ACCOUNT_A,
          opponentAccountID: ACCOUNT_B,
        },
      }],
    }),
    /not canonical uppercase/
  );
  assert.throws(
    () => envelope({
      existingManifests: [{
        path: `_socialReferences/${ACCOUNT_A}`,
        data: {
          leagueMembershipPaths: [],
          challengeIDs: [lowercaseID],
          friendAccountIDs: [],
        },
      }],
    }),
    /noncanonical challenge reference/
  );
});

test("backup construction is local-only and performs zero remote writes", () => {
  const store = new MemoryMigrationStore(documentsForStore());
  const before = initialSnapshot(store);
  const backup = envelope();
  verifyBackupEnvelope(backup);
  assert.equal(store.remoteWrites, 0);
  assert.deepEqual(initialSnapshot(store), before);
});

test("apply quarantines and deletes atomically without trusting client scores", async () => {
  const backup = envelope();
  const store = new MemoryMigrationStore(documentsForStore());
  const result = await applyRecoverableCutover({
    store,
    envelope: backup,
    runID: RUN_ID,
  });
  assert.equal(result.status, "complete");
  assert.equal(await store.get(`profiles_public/${ACCOUNT_A}`), null);
  assert.equal(
    await store.get(`leagues/gold_2026-W29/members/${ACCOUNT_A}`),
    null
  );
  const manifest = await store.get(`_socialReferences/${ACCOUNT_A}`);
  assert.deepEqual(manifest, {
    leagueMembershipPaths: [],
    challengeIDs: [CHALLENGE_ID],
    friendAccountIDs: [ACCOUNT_B],
  });
  assert.equal("rating" in manifest, false);
  assert.equal("clientAuthoredResult" in manifest, false);
  for (const quarantine of result.plan.quarantine) {
    const stored = await store.get(quarantine.path);
    assert.deepEqual(stored, quarantine.data);
  }
  const marker = await store.get(CUTOVER_JOURNAL_PATH);
  assert.equal(marker.status, "complete");
  assert.equal(marker.inventoryDigest, marker.verifiedInventoryDigest);
  assert.equal(marker.sourceGitCommit, SOURCE_BINDING.repositoryCommit);
});

test("complete-marker replay requires equal verified inventory digests", async () => {
  const backup = envelope();
  const store = new MemoryMigrationStore(documentsForStore());
  await applyRecoverableCutover({store, envelope: backup, runID: RUN_ID});
  const marker = await store.get(CUTOVER_JOURNAL_PATH);
  store.documents.set(CUTOVER_JOURNAL_PATH, {
    ...marker,
    verifiedInventoryDigest: "0".repeat(64),
  });
  await assert.rejects(
    applyRecoverableCutover({store, envelope: backup, runID: RUN_ID}),
    /complete cutover marker is invalid/
  );
});

test("same run and digest resumes idempotently after every apply phase", async () => {
  for (const phase of CUTOVER_PHASES) {
    const backup = envelope();
    const store = new MemoryMigrationStore(documentsForStore());
    await assert.rejects(
      applyRecoverableCutover({
        store,
        envelope: backup,
        runID: RUN_ID,
        faultAfterPhase: phase,
      }),
      new RegExp(`Injected fault after ${phase}`)
    );
    const resumed = await applyRecoverableCutover({
      store,
      envelope: backup,
      runID: RUN_ID,
    });
    assert.equal(resumed.status, "complete", phase);
    assert.equal(resumed.resumed, true, phase);
    const marker = await store.get(CUTOVER_JOURNAL_PATH);
    assert.equal(marker.inventoryDigest, marker.verifiedInventoryDigest, phase);
  }
});

test("a different run or digest cannot take over an in-progress journal", async () => {
  const backup = envelope();
  const store = new MemoryMigrationStore(documentsForStore());
  await assert.rejects(applyRecoverableCutover({
    store,
    envelope: backup,
    runID: RUN_ID,
    faultAfterPhase: "journaled",
  }));
  await assert.rejects(
    applyRecoverableCutover({store, envelope: backup, runID: "other-run"}),
    /different run or backup digest/
  );

  const differentBackup = createBackupEnvelope({
    projectID: "noum-d0b6f",
    capturedAt: "2026-07-14T12:01:00.000Z",
    binding: SOURCE_BINDING,
    inventory: inventory(),
  });
  await assert.rejects(
    applyRecoverableCutover({
      store,
      envelope: differentBackup,
      runID: RUN_ID,
    }),
    /different run or backup digest/
  );
});

test("pre-completion rollback restores exact source and manifest bytes", async () => {
  for (const phase of [
    "journaled", "quarantined", "manifests-written", "verified",
  ]) {
    const sourceInventory = inventory();
    const backup = envelope();
    const store = new MemoryMigrationStore(documentsForStore(sourceInventory));
    const before = initialSnapshot(store);
    await assert.rejects(applyRecoverableCutover({
      store,
      envelope: backup,
      runID: RUN_ID,
      faultAfterPhase: phase,
    }));
    const rolledBack = await rollbackRecoverableCutover({
      store,
      envelope: backup,
      runID: RUN_ID,
    });
    assert.equal(rolledBack.status, "rolled-back", phase);
    assert.deepEqual(initialSnapshot(store), before, phase);
    assert.equal(await store.get(CUTOVER_JOURNAL_PATH), null, phase);
  }
});

test("rollback resumes after every rollback phase without document loss", async () => {
  for (const phase of [
    "sources-restored", "manifests-restored", "rollback-verified",
  ]) {
    const sourceInventory = inventory();
    const backup = envelope();
    const store = new MemoryMigrationStore(documentsForStore(sourceInventory));
    const before = initialSnapshot(store);
    await assert.rejects(applyRecoverableCutover({
      store,
      envelope: backup,
      runID: RUN_ID,
      faultAfterPhase: "verified",
    }));
    await assert.rejects(rollbackRecoverableCutover({
      store,
      envelope: backup,
      runID: RUN_ID,
      faultAfterPhase: phase,
    }));
    const resumed = await rollbackRecoverableCutover({
      store,
      envelope: backup,
      runID: RUN_ID,
    });
    assert.equal(resumed.status, "rolled-back", phase);
    assert.deepEqual(initialSnapshot(store), before, phase);
  }
});

test("source drift fails before the migration journal or any remote write", async () => {
  const backup = envelope();
  const store = new MemoryMigrationStore(documentsForStore());
  store.documents.set(`profiles_public/${ACCOUNT_A}`, {rating: 4});
  const writesBefore = store.remoteWrites;
  await assert.rejects(
    applyRecoverableCutover({store, envelope: backup, runID: RUN_ID}),
    /profiles changed after the source-bound backup/
  );
  assert.equal(store.remoteWrites, writesBefore);
  assert.equal(await store.get(CUTOVER_JOURNAL_PATH), null);
});

test("a transaction failure cannot leave a deletion without quarantine", async () => {
  const backup = envelope();
  class FaultingStore extends MemoryMigrationStore {
    constructor(documents) {
      super(documents);
      this.transactionCount = 0;
    }

    async transaction(operation) {
      this.transactionCount += 1;
      if (this.transactionCount !== 2) return super.transaction(operation);
      const before = initialSnapshot(this);
      const error = new Error("transaction transport failed");
      const draft = new MemoryMigrationStore(
        before.map(([path, data]) => ({path, data}))
      );
      await operation({
        get: (path) => draft.get(path),
        set: (path, data) => draft.documents.set(path, structuredClone(data)),
        delete: (path) => draft.documents.delete(path),
      });
      assert.deepEqual(initialSnapshot(this), before);
      throw error;
    }
  }
  const store = new FaultingStore(documentsForStore());
  await assert.rejects(
    applyRecoverableCutover({store, envelope: backup, runID: RUN_ID}),
    /transaction transport failed/
  );
  assert.notEqual(await store.get(`profiles_public/${ACCOUNT_A}`), null);
  const quarantines = [...store.documents.keys()].filter((path) =>
    path.startsWith("_socialReferenceQuarantine/")
  );
  assert.equal(quarantines.length, 0);
});

test("Firestore type encoding preserves values needed for exact rollback", () => {
  const timestamp = {
    seconds: 1_720_000_000,
    nanoseconds: 123,
    toDate() { return new Date(1_720_000_000_000); },
  };
  const encoded = encodeFirestoreValue({
    timestamp,
    bytes: Buffer.from("noum"),
    date: new Date("2026-07-14T12:00:00.000Z"),
  });
  assert.deepEqual(encoded.timestamp, {
    $noumType: "timestamp",
    seconds: 1_720_000_000,
    nanoseconds: 123,
  });
  const decoded = decodeFirestoreValue(encoded, {
    timestamp: (seconds, nanoseconds) => ({seconds, nanoseconds}),
  });
  assert.deepEqual(decoded.timestamp, {seconds: 1_720_000_000, nanoseconds: 123});
  assert.equal(decoded.bytes.toString("utf8"), "noum");
  assert.equal(decoded.date.toISOString(), "2026-07-14T12:00:00.000Z");
});

test("complete cutover cannot be rolled back", async () => {
  const backup = envelope();
  const store = new MemoryMigrationStore(documentsForStore());
  await applyRecoverableCutover({store, envelope: backup, runID: RUN_ID});
  await assert.rejects(
    rollbackRecoverableCutover({store, envelope: backup, runID: RUN_ID}),
    /already complete/
  );
});
