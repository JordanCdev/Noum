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
import {resolve} from "node:path";
import {promisify} from "node:util";

import {
  applyRecoverableCutover,
  canonicalJSONStringify,
  createBackupEnvelope,
  CUTOVER_PHASES,
  rollbackRecoverableCutover,
  verifyBackupEnvelope,
} from "./social-cutover-migration.mjs";
import {
  parseSocialCutoverOptions,
  SocialCutoverCredentialMode,
} from "./social-cutover-credentials.mjs";
import {createFirestoreMigrationAdapter} from
  "./social-cutover-firestore-adapter.mjs";

const rawArguments = process.argv.slice(2);
const extraExactFlags = new Set(["--rollback"]);
const extraValuePrefixes = [
  "--backup-file=",
  "--backup-digest=",
  "--run-id=",
  "--fault-after-phase=",
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
  NOUM_SOCIAL_CUTOVER_EMULATOR=1 \\
    node scripts/migrate-social-reference-cutover.mjs --project=demo-noum \\
    --emulator-only [production-shaped options]

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
are the only production credentials eligible for apply or rollback. Emulator
mode requires the exact demo-noum project, an explicit opt-in environment value,
and a loopback Firestore emulator host. Ambient emulator routing is refused.
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
const faultAfterPhase = optionValue("--fault-after-phase");
if (rollback && !options.apply) throw new Error("Rollback requires --apply.");
if (!options.apply &&
    (rollback || backupFile || backupDigest || runID || faultAfterPhase)) {
  throw new Error(
    "Backup, digest, run ID, rollback, and fault flags are mutation-only."
  );
}
if (options.apply && (!backupFile || !backupDigest || !runID)) {
  throw new Error("Apply requires --backup-file, --backup-digest, and --run-id.");
}
if (faultAfterPhase &&
    options.credentialMode !== SocialCutoverCredentialMode.emulatorOnly) {
  throw new Error("Fault injection is restricted to explicit emulator mode.");
}
const rollbackFaultPhases = new Set([
  "sources-restored",
  "manifests-restored",
  "rollback-verified",
]);
const acceptedFaultPhases = rollback ? rollbackFaultPhases :
  new Set(CUTOVER_PHASES);
if (faultAfterPhase && !acceptedFaultPhases.has(faultAfterPhase)) {
  throw new Error(
    `Invalid ${rollback ? "rollback" : "apply"} fault phase.`
  );
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
    new URL("./social-cutover-firestore-adapter.mjs", import.meta.url),
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
const binding = await currentSourceBinding();
const {store} = createFirestoreMigrationAdapter({projectID, credentialMode});
if (!apply) {
  const envelope = createBackupEnvelope({
    projectID,
    capturedAt: new Date().toISOString(),
    binding,
    inventory: await store.readInventory(),
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

if (rollback) {
  const result = await rollbackRecoverableCutover({
    store,
    envelope,
    runID,
    faultAfterPhase,
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
  const result = await applyRecoverableCutover({
    store,
    envelope,
    runID,
    faultAfterPhase,
  });
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
