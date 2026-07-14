#!/usr/bin/env node

import {createHash} from "node:crypto";
import {execFile} from "node:child_process";
import {
  chmod,
  mkdir,
  readFile,
  stat,
  writeFile,
} from "node:fs/promises";
import {createRequire} from "node:module";
import {resolve} from "node:path";
import {promisify} from "node:util";

import {
  applyRecoverableCutover,
  canonicalJSONStringify,
  createBackupEnvelope,
  decodeFirestoreValue,
  encodeFirestoreValue,
  rollbackRecoverableCutover,
  SOCIAL_LIMITS,
  verifyBackupEnvelope,
} from "./social-cutover-migration.mjs";
import {
  createGcloudUserAuthClient,
  parseSocialCutoverOptions,
  SocialCutoverCredentialMode,
} from "./social-cutover-credentials.mjs";

const rawArguments = process.argv.slice(2);
const extraExactFlags = new Set(["--rollback"]);
const extraValuePrefixes = [
  "--backup-file=",
  "--backup-digest=",
  "--run-id=",
];
const legacyArguments = rawArguments.filter((argument) =>
  !extraExactFlags.has(argument) &&
  !extraValuePrefixes.some((prefix) => argument.startsWith(prefix))
);
const options = parseSocialCutoverOptions(legacyArguments);

if (options.help) {
  process.stdout.write(`
Usage:
  node scripts/migrate-social-reference-cutover.mjs --project=PROJECT_ID
  node scripts/migrate-social-reference-cutover.mjs --project=PROJECT_ID \\
    --gcloud-user-credentials
  node scripts/migrate-social-reference-cutover.mjs --project=PROJECT_ID \\
    --apply --confirm-project=PROJECT_ID --purge-legacy-social \\
    --approve-purge=DELETE_LEGACY_SOCIAL --run-id=RUN_ID \\
    --backup-file=PATH --backup-digest=SHA256
  node scripts/migrate-social-reference-cutover.mjs --project=PROJECT_ID \\
    --apply --rollback --confirm-project=PROJECT_ID --run-id=RUN_ID \\
    --backup-file=PATH --backup-digest=SHA256

Default mode is remote-read-only. It inventories bounded social data and every
users/{uid}/profile/main document, validates the exact current private-profile
contract, and writes a mode-0600 project/source-bound backup. It performs zero
remote writes.

Apply requires that reviewed backup, its canonical SHA-256 digest, a stable run
ID, exact project confirmation, and the legacy-social purge approval. It writes
a non-complete global journal before any mutation, copies each legacy public
profile and league row into server-only quarantine in the same transaction that
deletes the source, verifies the exact final inventory, and only then writes the
complete marker. Reissuing the same run and digest resumes safely. A different
run or digest is refused.

Rollback is allowed only before completion. It restores exact source documents
and manifests, verifies the restored inventory, removes quarantine, and deletes
the non-complete journal last.

--gcloud-user-credentials remains read-only. Application-default credentials
are the only credentials eligible for apply or rollback.
`);
  process.exit(0);
}

function optionValue(prefix) {
  const matches = rawArguments.filter((argument) =>
    argument.startsWith(`${prefix}=`)
  );
  if (matches.length > 1) throw new Error(`${prefix} may be passed only once.`);
  return matches[0]?.slice(prefix.length + 1);
}

const rollback = rawArguments.includes("--rollback");
const backupFile = optionValue("--backup-file");
const backupDigest = optionValue("--backup-digest");
const runID = optionValue("--run-id");
if (rollback && !options.apply) throw new Error("Rollback requires --apply.");
if (!options.apply && (rollback || backupFile || backupDigest || runID)) {
  throw new Error("Backup, digest, run ID, and rollback flags are mutation-only.");
}
if (options.apply && (!backupFile || !backupDigest || !runID)) {
  throw new Error("Apply requires --backup-file, --backup-digest, and --run-id.");
}

const execFilePromise = promisify(execFile);
async function currentSourceBinding() {
  const {stdout: trackedStatus} = await execFilePromise(
    "git",
    ["status", "--porcelain=v1", "--untracked-files=no"],
    {cwd: new URL("..", import.meta.url), encoding: "utf8", timeout: 10_000}
  );
  if (trackedStatus.trim().length > 0) {
    throw new Error("Social cutover requires a clean tracked source checkout.");
  }
  const {stdout} = await execFilePromise(
    "git",
    ["rev-parse", "HEAD"],
    {cwd: new URL("..", import.meta.url), encoding: "utf8", timeout: 10_000}
  );
  const repositoryCommit = stdout.trim();
  if (!/^[a-f0-9]{40}$/.test(repositoryCommit)) {
    throw new Error("Unable to bind the backup to a Git commit.");
  }
  const implementationFiles = [
    new URL("./migrate-social-reference-cutover.mjs", import.meta.url),
    new URL("./social-cutover-migration.mjs", import.meta.url),
    new URL("./social-cutover-credentials.mjs", import.meta.url),
  ];
  const hash = createHash("sha256");
  for (const file of implementationFiles) {
    hash.update(file.pathname.split("/").at(-1));
    hash.update("\0");
    hash.update(await readFile(file));
    hash.update("\0");
  }
  return {
    repositoryCommit,
    implementationSHA256: hash.digest("hex"),
  };
}

const {projectID, apply, purgeLegacySocial, credentialMode} = options;
const requireFromFunctions = createRequire(
  new URL("../functions/package.json", import.meta.url)
);
const {applicationDefault, initializeApp} = requireFromFunctions(
  "firebase-admin/app"
);
const {
  FieldValue,
  Firestore,
  GeoPoint,
  Timestamp,
  getFirestore,
} = requireFromFunctions("firebase-admin/firestore");
let firestore;
if (credentialMode === SocialCutoverCredentialMode.gcloudUser) {
  const authClient = createGcloudUserAuthClient({projectID});
  firestore = new Firestore({authClient, preferRest: true, projectId: projectID});
} else {
  initializeApp({credential: applicationDefault(), projectId: projectID});
  firestore = getFirestore();
}

async function boundedSnapshot(query, label, limit) {
  const snapshot = await query.limit(limit + 1).get();
  if (snapshot.size > limit) {
    throw new Error(`${label} exceeds the reviewed bound of ${limit}.`);
  }
  return snapshot;
}

const documents = (snapshot) => snapshot.docs.map((snapshotDocument) => ({
  path: snapshotDocument.ref.path,
  data: encodeFirestoreValue(snapshotDocument.data()),
}));

async function readRemoteInventory() {
  const [
    profiles,
    memberships,
    privateProfiles,
    challenges,
    friendLinks,
    manifests,
    cutover,
  ] = await Promise.all([
    boundedSnapshot(
      firestore.collection("profiles_public"),
      "profiles_public",
      SOCIAL_LIMITS.profiles
    ),
    boundedSnapshot(
      firestore.collectionGroup("members"),
      "league memberships",
      SOCIAL_LIMITS.memberships
    ),
    boundedSnapshot(
      firestore.collectionGroup("profile"),
      "private profiles",
      SOCIAL_LIMITS.privateProfiles
    ),
    boundedSnapshot(
      firestore.collection("challenges"),
      "challenges",
      SOCIAL_LIMITS.challenges
    ),
    boundedSnapshot(
      firestore.collectionGroup("friends"),
      "friend links",
      SOCIAL_LIMITS.friendLinks
    ),
    boundedSnapshot(
      firestore.collection("_socialReferences"),
      "existing social manifests",
      SOCIAL_LIMITS.manifests
    ),
    firestore.collection("_socialReferenceCutover").doc("current").get(),
  ]);
  return {
    profiles: documents(profiles),
    leagueMemberships: documents(memberships),
    privateProfiles: documents(privateProfiles),
    challenges: documents(challenges),
    friendLinks: documents(friendLinks),
    existingManifests: documents(manifests),
    existingCutover: cutover.exists ? {
      path: cutover.ref.path,
      data: encodeFirestoreValue(cutover.data()),
    } : null,
  };
}

const decodeAdapters = {
  timestamp: (seconds, nanoseconds) => new Timestamp(seconds, nanoseconds),
  geopoint: (latitude, longitude) => new GeoPoint(latitude, longitude),
  reference: (path) => firestore.doc(path),
  serverTimestamp: () => FieldValue.serverTimestamp(),
};

class FirestoreMigrationStore {
  serverTimestampValue() {
    return {$noumType: "server-timestamp"};
  }

  async get(path) {
    const snapshot = await firestore.doc(path).get();
    return snapshot.exists ? encodeFirestoreValue(snapshot.data()) : null;
  }

  async transaction(operation) {
    await firestore.runTransaction(async (nativeTransaction) => {
      const transaction = {
        get: async (path) => {
          const snapshot = await nativeTransaction.get(firestore.doc(path));
          return snapshot.exists ? encodeFirestoreValue(snapshot.data()) : null;
        },
        set: (path, data) => nativeTransaction.set(
          firestore.doc(path),
          decodeFirestoreValue(data, decodeAdapters)
        ),
        delete: (path) => nativeTransaction.delete(firestore.doc(path)),
      };
      await operation(transaction);
    });
  }

  readInventory() {
    return readRemoteInventory();
  }
}

const binding = await currentSourceBinding();
if (!apply) {
  const envelope = createBackupEnvelope({
    projectID,
    capturedAt: new Date().toISOString(),
    binding,
    inventory: await readRemoteInventory(),
  });
  const backupDirectory = resolve(process.cwd(), "backups");
  await mkdir(backupDirectory, {recursive: true, mode: 0o700});
  const backupName = `social-cutover-${envelope.payload.capturedAt
    .replaceAll(":", "-")}.json`;
  const backupPath = resolve(backupDirectory, backupName);
  await writeFile(
    backupPath,
    `${canonicalJSONStringify(envelope)}\n`,
    {flag: "wx", mode: 0o600}
  );
  await chmod(backupPath, 0o600);
  process.stdout.write(`${JSON.stringify({
    mode: "dry-run",
    credentialMode,
    projectID,
    backupPath,
    backupDigest: envelope.digest.value,
    sourceBinding: binding,
    profileDocuments: envelope.payload.inventory.profiles.length,
    leagueMembershipDocuments:
      envelope.payload.inventory.leagueMemberships.length,
    privateProfileDocuments: envelope.payload.inventory.privateProfiles.length,
    challengeDocuments: envelope.payload.inventory.challenges.length,
    friendLinkDocuments: envelope.payload.inventory.friendLinks.length,
    manifestDocuments: envelope.payload.inventory.existingManifests.length,
  }, null, 2)}\n`);
  process.stdout.write("Dry run complete. No remote writes were performed.\n");
  process.exit(0);
}

const backupPath = resolve(process.cwd(), backupFile);
const backupStat = await stat(backupPath);
if (!backupStat.isFile() || (backupStat.mode & 0o777) !== 0o600) {
  throw new Error("Apply requires a regular backup file with mode 0600.");
}
let envelope;
try {
  envelope = JSON.parse(await readFile(backupPath, "utf8"));
} catch {
  throw new Error("Unable to parse the reviewed backup file.");
}
verifyBackupEnvelope(envelope, {
  projectID,
  expectedDigest: backupDigest,
  binding,
});
const legacyCount = envelope.payload.inventory.profiles.length +
  envelope.payload.inventory.leagueMemberships.length;
if (!rollback && legacyCount > 0 && !purgeLegacySocial) {
  throw new Error(
    "Apply with legacy rows requires the explicit purge approval flags."
  );
}

const store = new FirestoreMigrationStore();
if (rollback) {
  const result = await rollbackRecoverableCutover({
    store,
    envelope,
    runID,
  });
  process.stdout.write(`${JSON.stringify({
    mode: "rollback",
    projectID,
    runID,
    backupDigest,
    status: result.status,
    resumed: result.resumed,
  }, null, 2)}\n`);
  process.stdout.write("Rollback verified; the non-complete journal is removed.\n");
} else {
  const result = await applyRecoverableCutover({store, envelope, runID});
  process.stdout.write(`${JSON.stringify({
    mode: "apply",
    projectID,
    runID,
    backupDigest,
    status: result.status,
    resumed: result.resumed,
    quarantinedDocuments: result.plan.legacy.length,
    manifestDocuments: result.plan.manifests.length,
  }, null, 2)}\n`);
  process.stdout.write("Exact inventory verified; global cutover is complete.\n");
}
