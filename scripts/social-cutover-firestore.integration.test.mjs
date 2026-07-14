import assert from "node:assert/strict";
import {execFile} from "node:child_process";
import {mkdtemp, readFile, rm, stat} from "node:fs/promises";
import {createRequire} from "node:module";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {fileURLToPath} from "node:url";
import {promisify} from "node:util";
import test from "node:test";

import {createFirestoreMigrationAdapter} from
  "./social-cutover-firestore-adapter.mjs";
import {
  SOCIAL_CUTOVER_EMULATOR_OPT_IN,
  SocialCutoverCredentialMode,
} from "./social-cutover-credentials.mjs";
import {canonicalJSONStringify} from "./social-cutover-migration.mjs";

const PROJECT_ID = "demo-noum";
const ACCOUNT_A = "emulator-account-a";
const ACCOUNT_B = "emulator-account-b";
const CHALLENGE_ID = "783AB966-E91B-4CA4-8F7A-7E50113FA2C6";
const MEMBERSHIP_PATH = `leagues/gold_2026-W29/members/${ACCOUNT_A}`;
const PROFILE_PATH = `profiles_public/${ACCOUNT_A}`;
const MANIFEST_PATH = `_socialReferences/${ACCOUNT_A}`;
const JOURNAL_PATH = "_socialReferenceCutover/current";
const CLI_PATH = fileURLToPath(
  new URL("./migrate-social-reference-cutover.mjs", import.meta.url)
);
const execFilePromise = promisify(execFile);
const requireFromFunctions = createRequire(
  new URL("../functions/package.json", import.meta.url)
);
const {deleteApp} = requireFromFunctions("firebase-admin/app");
const {GeoPoint, Timestamp} = requireFromFunctions("firebase-admin/firestore");

function emulatorEnvironment() {
  assert.equal(process.env[SOCIAL_CUTOVER_EMULATOR_OPT_IN], "1");
  assert.match(
    process.env.FIRESTORE_EMULATOR_HOST ?? "",
    /^(localhost|127\.0\.0\.1|\[::1\]):[0-9]+$/i
  );
  return {
    ...process.env,
    GCLOUD_PROJECT: PROJECT_ID,
    // Explicit emulator mode must not consult this intentionally invalid ADC
    // path. A regression to applicationDefault() makes the suite fail closed.
    GOOGLE_APPLICATION_CREDENTIALS:
      "/noum-emulator-test/must-not-read-application-default.json",
  };
}

async function runCLI(arguments_, cwd) {
  return execFilePromise(process.execPath, [CLI_PATH, ...arguments_], {
    cwd,
    env: emulatorEnvironment(),
    encoding: "utf8",
    maxBuffer: 2 * 1_024 * 1_024,
    timeout: 30_000,
  });
}

async function expectCLIError(arguments_, cwd, pattern) {
  try {
    await runCLI(arguments_, cwd);
    assert.fail("Expected the social cutover CLI to fail.");
  } catch (error) {
    const output = [error.message, error.stdout, error.stderr]
      .filter(Boolean)
      .join("\n");
    assert.match(output, pattern);
  }
}

function parseCLISummary(stdout) {
  const end = stdout.indexOf("\n}\n");
  assert.notEqual(end, -1, stdout);
  return JSON.parse(stdout.slice(0, end + 2));
}

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

function sourceDocuments(firestore) {
  return new Map([
    [PROFILE_PATH, {
      accountID: ACCOUNT_A,
      displayName: "Alex",
      rating: 9_999,
      clientAuthoredResult: "never-trust-this",
      nativeTimestamp: new Timestamp(1_720_000_000, 123),
      nativeGeoPoint: new GeoPoint(51.5072, -0.1276),
      nativeBytes: Buffer.from("noum-cutover"),
      nativeReference: firestore.doc("migrationFixtures/referenceTarget"),
    }],
    [MEMBERSHIP_PATH, {
      accountID: ACCOUNT_A,
      rating: 9_999,
      weeklyDelta: 500,
    }],
    [`users/${ACCOUNT_A}/profile/main`, validPrivateProfile()],
    [`users/${ACCOUNT_B}/profile/main`, validPrivateProfile({
      speakingContext: "interviews",
      chosenStyleGoal: "executive",
      secondaryStyleGoal: "storytelling",
      bigMomentID: CHALLENGE_ID,
    })],
    [`challenges/${CHALLENGE_ID}`, {
      creatorAccountID: ACCOUNT_A,
      opponentAccountID: ACCOUNT_B,
      creatorScore: 1_000,
      opponentScore: 0,
    }],
    [`_socialFriendLinks/${ACCOUNT_A}/friends/${ACCOUNT_B}`, {
      createdAt: new Timestamp(1_720_000_000, 0),
    }],
    [`_socialFriendLinks/${ACCOUNT_B}/friends/${ACCOUNT_A}`, {
      createdAt: new Timestamp(1_720_000_000, 0),
    }],
    [MANIFEST_PATH, {
      leagueMembershipPaths: [MEMBERSHIP_PATH],
      challengeIDs: [],
      friendAccountIDs: [],
      rating: 9_999,
      clientAuthoredResult: "never-promote-this",
      updatedAt: new Timestamp(1_720_000_000, 0),
    }],
  ]);
}

async function seedSource(firestore) {
  const documents = sourceDocuments(firestore);
  await Promise.all([...documents].map(([path, data]) =>
    firestore.doc(path).set(data)
  ));
  return documents;
}

async function encodedDocuments(store, paths) {
  const entries = [];
  for (const path of paths) entries.push([path, await store.get(path)]);
  return entries;
}

async function flushDemoProject() {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(host);
  const response = await fetch(
    `http://${host}/emulator/v1/projects/${PROJECT_ID}` +
      "/databases/(default)/documents",
    {method: "DELETE"}
  );
  assert.equal(response.ok, true, await response.text());
}

async function quarantineCount(firestore, runID) {
  const snapshot = await firestore.collection("_socialReferenceQuarantine")
    .doc(runID).collection("documents").get();
  return snapshot.size;
}

function dryRunArguments() {
  return [`--project=${PROJECT_ID}`, "--emulator-only"];
}

function mutationArguments({summary, runID, rollback = false, fault}) {
  return [
    `--project=${PROJECT_ID}`,
    "--emulator-only",
    "--apply",
    ...(rollback ? ["--rollback"] : [
      "--purge-legacy-social",
      "--approve-purge=DELETE_LEGACY_SOCIAL",
    ]),
    `--confirm-project=${PROJECT_ID}`,
    `--run-id=${runID}`,
    `--backup-file=${summary.backupPath}`,
    `--backup-digest=${summary.backupDigest}`,
    ...(fault ? [`--fault-after-phase=${fault}`] : []),
  ];
}

async function createCLIBackup(cwd) {
  const {stdout} = await runCLI(dryRunArguments(), cwd);
  const summary = parseCLISummary(stdout);
  assert.equal(summary.mode, "dry-run");
  assert.equal(summary.credentialMode, "emulator-only");
  assert.equal(summary.projectID, PROJECT_ID);
  assert.match(summary.sourceBinding.repositoryCommit, /^[a-f0-9]{40}$/);
  assert.match(summary.sourceBinding.implementationSHA256, /^[a-f0-9]{64}$/);
  const metadata = await stat(summary.backupPath);
  assert.equal(metadata.isFile(), true);
  assert.equal(metadata.mode & 0o777, 0o600);
  return {
    summary,
    envelope: JSON.parse(await readFile(summary.backupPath, "utf8")),
  };
}

test("real Firestore adapter closes the recoverable CLI contract", async (t) => {
  const temporaryDirectories = [];
  const {app, firestore, store} = createFirestoreMigrationAdapter({
    projectID: PROJECT_ID,
    credentialMode: SocialCutoverCredentialMode.emulatorOnly,
    env: emulatorEnvironment(),
  });
  const temporaryDirectory = async () => {
    const directory = await mkdtemp(join(tmpdir(), "noum-social-cutover-"));
    temporaryDirectories.push(directory);
    return directory;
  };

  try {
    await flushDemoProject();

    await t.test(
      "dry run inventories native values and performs zero writes",
      async () => {
      const seeded = await seedSource(firestore);
      const sourcePaths = [...seeded.keys()];
      const before = await encodedDocuments(store, sourcePaths);
      const {summary, envelope} = await createCLIBackup(
        await temporaryDirectory()
      );
      assert.equal(summary.backupDigest, envelope.digest.value);

      assert.equal(summary.profileDocuments, 1);
      assert.equal(summary.leagueMembershipDocuments, 1);
      assert.equal(summary.privateProfileDocuments, 2);
      assert.equal(summary.challengeDocuments, 1);
      assert.equal(summary.friendLinkDocuments, 2);
      assert.equal(summary.manifestDocuments, 1);
      assert.deepEqual(await encodedDocuments(store, sourcePaths), before);
      assert.equal(await store.get(JOURNAL_PATH), null);
      assert.equal(await quarantineCount(firestore, "not-started"), 0);

      const encodedProfile = envelope.payload.inventory.profiles[0].data;
      assert.equal(encodedProfile.nativeTimestamp.$noumType, "timestamp");
      assert.equal(encodedProfile.nativeGeoPoint.$noumType, "geopoint");
      assert.equal(encodedProfile.nativeBytes.$noumType, "bytes");
      assert.deepEqual(encodedProfile.nativeReference, {
        $noumType: "reference",
        path: "migrationFixtures/referenceTarget",
      });
      }
    );

    await flushDemoProject();
    await t.test(
      "source drift is rejected before any journal or quarantine",
      async () => {
      const seeded = await seedSource(firestore);
      const cwd = await temporaryDirectory();
      const {summary} = await createCLIBackup(cwd);
      await firestore.doc(PROFILE_PATH).update({displayName: "Changed"});
      await expectCLIError(
        mutationArguments({summary, runID: "adapter-source-drift"}),
        cwd,
        /profiles changed after the source-bound backup/
      );
      assert.equal(await store.get(JOURNAL_PATH), null);
      assert.equal(await quarantineCount(firestore, "adapter-source-drift"), 0);
      await firestore.doc(PROFILE_PATH).set(seeded.get(PROFILE_PATH));
      }
    );

    await flushDemoProject();
    await t.test(
      "faulted quarantine resumes only for the same run and digest",
      async () => {
      await seedSource(firestore);
      const cwd = await temporaryDirectory();
      const {summary} = await createCLIBackup(cwd);
      const runID = "adapter-resume";
      await expectCLIError(
        mutationArguments({
          summary,
          runID,
          fault: "quarantined",
        }),
        cwd,
        /Injected fault after quarantined/
      );
      const journal = await store.get(JOURNAL_PATH);
      assert.equal(journal.status, "in-progress");
      assert.equal(journal.phase, "quarantined");
      assert.equal(await store.get(PROFILE_PATH), null);
      assert.equal(await store.get(MEMBERSHIP_PATH), null);
      assert.equal(await quarantineCount(firestore, runID), 2);

      await expectCLIError(
        mutationArguments({summary, runID: "adapter-takeover"}),
        cwd,
        /different run or backup digest owns the cutover journal/
      );
      const {stdout} = await runCLI(
        mutationArguments({summary, runID}),
        cwd
      );
      const resumed = parseCLISummary(stdout);
      assert.equal(resumed.status, "complete");
      assert.equal(resumed.resumed, true);

      const markerSnapshot = await firestore.doc(JOURNAL_PATH).get();
      const marker = markerSnapshot.data();
      assert.deepEqual(Object.keys(marker).sort(), [
        "backupDigest",
        "completedAt",
        "inventoryDigest",
        "projectID",
        "runID",
        "schemaVersion",
        "sourceGitCommit",
        "sourceImplementationSHA256",
        "status",
        "verifiedInventoryDigest",
      ]);
      assert.equal(marker.schemaVersion, 2);
      assert.equal(marker.status, "complete");
      assert.equal(marker.projectID, PROJECT_ID);
      assert.equal(marker.inventoryDigest, marker.verifiedInventoryDigest);
      assert.equal(marker.completedAt instanceof Timestamp, true);

      const manifest = await store.get(MANIFEST_PATH);
      assert.deepEqual(manifest, {
        leagueMembershipPaths: [],
        challengeIDs: [CHALLENGE_ID],
        friendAccountIDs: [ACCOUNT_B],
      });
      assert.equal("rating" in manifest, false);
      assert.equal("clientAuthoredResult" in manifest, false);
      await expectCLIError(
        mutationArguments({summary, runID, rollback: true}),
        cwd,
        /already complete/
      );
      }
    );

    await flushDemoProject();
    await t.test(
      "pre-completion rollback restores exact native Firestore values",
      async () => {
      const seeded = await seedSource(firestore);
      const sourcePaths = [...seeded.keys()];
      const before = await encodedDocuments(store, sourcePaths);
      const cwd = await temporaryDirectory();
      const {summary} = await createCLIBackup(cwd);
      const runID = "adapter-rollback";
      await expectCLIError(
        mutationArguments({summary, runID, fault: "verified"}),
        cwd,
        /Injected fault after verified/
      );
      assert.equal((await store.get(JOURNAL_PATH)).phase, "verified");

      const {stdout} = await runCLI(
        mutationArguments({summary, runID, rollback: true}),
        cwd
      );
      const rollback = parseCLISummary(stdout);
      assert.equal(rollback.status, "rolled-back");
      assert.deepEqual(await encodedDocuments(store, sourcePaths), before);
      assert.equal(await store.get(JOURNAL_PATH), null);
      assert.equal(await quarantineCount(firestore, runID), 0);

      const restoredProfile = await store.get(PROFILE_PATH);
      assert.equal(restoredProfile.nativeTimestamp.$noumType, "timestamp");
      assert.equal(restoredProfile.nativeGeoPoint.$noumType, "geopoint");
      assert.equal(restoredProfile.nativeBytes.$noumType, "bytes");
      assert.equal(restoredProfile.nativeReference.$noumType, "reference");
      assert.equal(
        canonicalJSONStringify(restoredProfile),
        canonicalJSONStringify(before.find(([path]) => path === PROFILE_PATH)[1])
      );
      }
    );

    await flushDemoProject();
    await t.test(
      "native transaction abort leaves source and quarantine unchanged",
      async () => {
      await seedSource(firestore);
      const before = await store.get(PROFILE_PATH);
      const quarantinePath =
        `_socialReferenceQuarantine/atomic-abort/documents/${"f".repeat(64)}`;
      await assert.rejects(
        store.transaction(async (transaction) => {
          assert.deepEqual(await transaction.get(PROFILE_PATH), before);
          transaction.set(quarantinePath, {
            schemaVersion: 2,
            sourcePath: PROFILE_PATH,
          });
          transaction.delete(PROFILE_PATH);
          throw new Error("abort native transaction");
        }),
        /abort native transaction/
      );
      assert.deepEqual(await store.get(PROFILE_PATH), before);
      assert.equal(await store.get(quarantinePath), null);
      }
    );
  } finally {
    await flushDemoProject();
    if (app) await deleteApp(app);
    await Promise.all(temporaryDirectories.map((directory) =>
      rm(directory, {recursive: true, force: true})
    ));
  }
});
