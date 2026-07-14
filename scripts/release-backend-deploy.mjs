#!/usr/bin/env node

import {createHash} from "node:crypto";
import {execFile as execFileCallback} from "node:child_process";
import {constants as fsConstants} from "node:fs";
import {open, readFile} from "node:fs/promises";
import {isAbsolute, dirname, resolve} from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";
import {promisify} from "node:util";

export const PRODUCTION_PROJECT_ID = "noum-d0b6f";
export const COORDINATED_DEPLOY_TARGET = "functions,firestore:rules";
export const FIREBASE_TOOLS_VERSION = "15.19.1";
export const AUTHORIZATION_SCHEMA_VERSION = 1;
export const MAX_AUTHORIZATION_LIFETIME_MS = 30 * 60 * 1_000;
export const REQUIRED_EVIDENCE_ATTACHMENTS = Object.freeze([
  "active-client-inventory",
  "minimum-client-policy",
  "writer-suspension",
  "legacy-data-disposition",
  "rollback-owner-plan",
]);

const GIT_COMMIT_PATTERN = /^[a-f0-9]{40}$/;
const SHA256_PATTERN = /^[a-f0-9]{64}$/;
const RUN_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
const AUTHORIZATION_KEYS = Object.freeze([
  "schemaVersion",
  "projectID",
  "sourceGitCommit",
  "socialCutoverRunID",
  "backupDigest",
  "issuedAt",
  "expiresAt",
  "target",
  "attachments",
]);
const ATTACHMENT_KEYS = Object.freeze(["path", "sha256"]);
const MAX_AUTHORIZATION_BYTES = 64 * 1_024;
const execFilePromise = promisify(execFileCallback);

export class BackendDeployError extends Error {
  constructor(message) {
    super(message);
    this.name = "BackendDeployError";
  }
}

function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireExactKeys(value, expected, label) {
  if (!isRecord(value)) {
    throw new BackendDeployError(`${label} must be an object.`);
  }
  const actual = Object.keys(value).sort();
  const required = [...expected].sort();
  if (actual.length !== required.length ||
      actual.some((key, index) => key !== required[index])) {
    throw new BackendDeployError(`${label} must contain only its exact reviewed keys.`);
  }
}

function canonicalISODate(value, label) {
  if (typeof value !== "string") {
    throw new BackendDeployError(`${label} must be an ISO-8601 timestamp.`);
  }
  const milliseconds = Date.parse(value);
  if (!Number.isFinite(milliseconds) || new Date(milliseconds).toISOString() !== value) {
    throw new BackendDeployError(`${label} must be a canonical ISO-8601 timestamp.`);
  }
  return milliseconds;
}

export function parseBackendDeployArguments(args) {
  const unknown = args.find((argument) =>
    argument !== "--execute" &&
    argument !== "--help" &&
    !argument.startsWith("--authorization=")
  );
  if (unknown) throw new BackendDeployError(`Unknown argument: ${unknown}`);
  if (args.filter((argument) => argument === "--execute").length > 1) {
    throw new BackendDeployError("--execute may be passed only once.");
  }
  if (args.filter((argument) => argument === "--help").length > 1) {
    throw new BackendDeployError("--help may be passed only once.");
  }
  const authorizationArguments = args.filter((argument) =>
    argument.startsWith("--authorization=")
  );
  if (authorizationArguments.length > 1) {
    throw new BackendDeployError("--authorization may be passed only once.");
  }
  if (args.includes("--help")) {
    if (args.length !== 1) {
      throw new BackendDeployError("--help cannot be combined with deployment arguments.");
    }
    return {help: true, execute: false, authorizationPath: null};
  }
  const authorizationPath = authorizationArguments[0]?.slice(
    "--authorization=".length
  );
  if (!authorizationPath) {
    throw new BackendDeployError("Pass --authorization=PATH.");
  }
  return {
    help: false,
    execute: args.includes("--execute"),
    authorizationPath: resolve(authorizationPath),
  };
}

export function validateBackendDeployAuthorization(
  value,
  {currentCommit, nowMs, authorizationDirectory}
) {
  requireExactKeys(value, AUTHORIZATION_KEYS, "Authorization");
  if (value.schemaVersion !== AUTHORIZATION_SCHEMA_VERSION) {
    throw new BackendDeployError("Authorization schema version is unsupported.");
  }
  if (value.projectID !== PRODUCTION_PROJECT_ID) {
    throw new BackendDeployError(`Authorization project must be ${PRODUCTION_PROJECT_ID}.`);
  }
  if (value.target !== COORDINATED_DEPLOY_TARGET) {
    throw new BackendDeployError(
      `Authorization target must be ${COORDINATED_DEPLOY_TARGET}.`
    );
  }
  if (typeof currentCommit !== "string" || !GIT_COMMIT_PATTERN.test(currentCommit)) {
    throw new BackendDeployError("Current Git commit is invalid.");
  }
  if (value.sourceGitCommit !== currentCommit) {
    throw new BackendDeployError("Authorization does not bind the current Git commit.");
  }
  if (typeof value.socialCutoverRunID !== "string" ||
      !RUN_ID_PATTERN.test(value.socialCutoverRunID)) {
    throw new BackendDeployError("Authorization social cutover run ID is invalid.");
  }
  if (typeof value.backupDigest !== "string" ||
      !SHA256_PATTERN.test(value.backupDigest)) {
    throw new BackendDeployError("Authorization backup digest is invalid.");
  }
  const issuedAtMs = canonicalISODate(value.issuedAt, "issuedAt");
  const expiresAtMs = canonicalISODate(value.expiresAt, "expiresAt");
  if (!Number.isFinite(nowMs) || issuedAtMs > nowMs || expiresAtMs <= nowMs ||
      expiresAtMs <= issuedAtMs ||
      expiresAtMs - issuedAtMs > MAX_AUTHORIZATION_LIFETIME_MS ||
      nowMs - issuedAtMs > MAX_AUTHORIZATION_LIFETIME_MS) {
    throw new BackendDeployError("Authorization is stale, premature, or exceeds 30 minutes.");
  }
  requireExactKeys(
    value.attachments,
    REQUIRED_EVIDENCE_ATTACHMENTS,
    "Authorization attachments"
  );
  const attachments = Object.fromEntries(REQUIRED_EVIDENCE_ATTACHMENTS.map((name) => {
    const attachment = value.attachments[name];
    requireExactKeys(attachment, ATTACHMENT_KEYS, `Attachment ${name}`);
    if (typeof attachment.path !== "string" || attachment.path.length < 1 ||
        attachment.path.includes("\u0000")) {
      throw new BackendDeployError(`Attachment ${name} path is invalid.`);
    }
    if (typeof attachment.sha256 !== "string" ||
        !SHA256_PATTERN.test(attachment.sha256)) {
      throw new BackendDeployError(`Attachment ${name} digest is invalid.`);
    }
    const path = isAbsolute(attachment.path) ?
      resolve(attachment.path) : resolve(authorizationDirectory, attachment.path);
    return [name, {path, sha256: attachment.sha256}];
  }));
  if (new Set(Object.values(attachments).map(({path}) => path)).size !==
      REQUIRED_EVIDENCE_ATTACHMENTS.length) {
    throw new BackendDeployError("Each evidence attachment must be a distinct file.");
  }
  return {
    schemaVersion: value.schemaVersion,
    projectID: value.projectID,
    sourceGitCommit: value.sourceGitCommit,
    socialCutoverRunID: value.socialCutoverRunID,
    backupDigest: value.backupDigest,
    issuedAt: value.issuedAt,
    expiresAt: value.expiresAt,
    target: value.target,
    attachments,
  };
}

function callableBlock(source, name) {
  const marker = `export const ${name} = onCall(`;
  const start = source.indexOf(marker);
  if (start < 0) return null;
  let index = start + marker.length - 1;
  let depth = 0;
  let quote = null;
  let escaped = false;
  let lineComment = false;
  let blockComment = false;
  for (; index < source.length; index += 1) {
    const character = source[index];
    const following = source[index + 1] ?? "";
    if (lineComment) {
      if (character === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      if (character === "*" && following === "/") {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote !== null) {
      if (escaped) escaped = false;
      else if (character === "\\") escaped = true;
      else if (character === quote) quote = null;
      continue;
    }
    if (character === "/" && following === "/") {
      lineComment = true;
      index += 1;
      continue;
    }
    if (character === "/" && following === "*") {
      blockComment = true;
      index += 1;
      continue;
    }
    if (["'", "\"", "`"].includes(character)) {
      quote = character;
      continue;
    }
    if (character === "(") depth += 1;
    else if (character === ")") {
      depth -= 1;
      if (depth === 0) return source.slice(start, index + 1);
    }
  }
  return null;
}

export function validateTrustedEvidenceProducerRoster(
  functionsSource,
  cloudContractSource
) {
  const identityDefinition = new RegExp(
    "^const EVIDENCE_RUNTIME_SERVICE_ACCOUNT\\s*=\\s*" +
    "\\\"noum-evidence-runtime@noum-d0b6f\\.iam\\.gserviceaccount\\.com\\\";$",
    "m"
  );
  if (!identityDefinition.test(functionsSource)) {
    throw new BackendDeployError(
      "Trusted verifySessionEvidence producer is missing its dedicated runtime identity."
    );
  }
  const block = callableBlock(functionsSource, "verifySessionEvidence");
  if (!block || !/\benforceAppCheck\s*:\s*true\b/.test(block) ||
      !/\bserviceAccount\s*:\s*EVIDENCE_RUNTIME_SERVICE_ACCOUNT\b/.test(block) ||
      !/\bassertTrustedCaller\(\s*request\.auth\s*,\s*request\.app\s*\)/.test(block)) {
    throw new BackendDeployError(
      "Trusted verifySessionEvidence callable is absent or not fail-closed."
    );
  }
  const cloudIdentity = /^\s*"EVIDENCE_RUNTIME_SERVICE_ACCOUNT"\s*:\s*"noum-evidence-runtime",\s*$/m;
  const cloudCallable = /^\s*"verifySessionEvidence"\s*:\s*"EVIDENCE_RUNTIME_SERVICE_ACCOUNT",\s*$/m;
  if (!cloudIdentity.test(cloudContractSource) ||
      !cloudCallable.test(cloudContractSource)) {
    throw new BackendDeployError(
      "Cloud operations roster does not bind verifySessionEvidence to its evidence runtime."
    );
  }
  return true;
}

async function readRegularFile(path, maximumBytes = Number.POSITIVE_INFINITY) {
  let handle;
  try {
    handle = await open(path, fsConstants.O_RDONLY | fsConstants.O_NOFOLLOW);
    const stats = await handle.stat();
    if (!stats.isFile() || stats.size < 1 || stats.size > maximumBytes) {
      throw new BackendDeployError(`${path} is not a bounded regular file.`);
    }
    return await handle.readFile();
  } catch (error) {
    if (error instanceof BackendDeployError) throw error;
    throw new BackendDeployError(`Unable to read regular file ${path}.`);
  } finally {
    await handle?.close();
  }
}

export async function sha256RegularFile(path) {
  const bytes = await readRegularFile(path);
  return createHash("sha256").update(bytes).digest("hex");
}

async function loadAuthorization(path) {
  const bytes = await readRegularFile(path, MAX_AUTHORIZATION_BYTES);
  let value;
  try {
    value = JSON.parse(bytes.toString("utf8"));
  } catch {
    throw new BackendDeployError("Authorization must be valid JSON.");
  }
  return {
    value,
    digest: createHash("sha256").update(bytes).digest("hex"),
  };
}

export async function verifyAuthorizationAttachments(attachments) {
  for (const name of REQUIRED_EVIDENCE_ATTACHMENTS) {
    const attachment = attachments[name];
    const actualDigest = await sha256RegularFile(attachment.path);
    if (actualDigest !== attachment.sha256) {
      throw new BackendDeployError(`Attachment ${name} digest does not match.`);
    }
  }
  return true;
}

async function inspectGit(repoRoot, executeFile) {
  const status = await executeFile(
    "git",
    ["status", "--porcelain=v1", "--untracked-files=no"],
    {cwd: repoRoot, encoding: "utf8", timeout: 10_000, maxBuffer: 1_048_576}
  );
  if (status.stdout.trim().length > 0) {
    throw new BackendDeployError("Backend deployment requires clean tracked source.");
  }
  const revision = await executeFile(
    "git",
    ["rev-parse", "HEAD"],
    {cwd: repoRoot, encoding: "utf8", timeout: 10_000, maxBuffer: 1_048_576}
  );
  const commit = revision.stdout.trim();
  if (!GIT_COMMIT_PATTERN.test(commit)) {
    throw new BackendDeployError("Unable to bind deployment to the current Git commit.");
  }
  return commit;
}

async function verifiedContext({
  repoRoot,
  authorizationPath,
  nowMs,
  executeFile,
}) {
  const currentCommit = await inspectGit(repoRoot, executeFile);
  const loaded = await loadAuthorization(authorizationPath);
  const authorization = validateBackendDeployAuthorization(loaded.value, {
    currentCommit,
    nowMs,
    authorizationDirectory: dirname(authorizationPath),
  });
  await verifyAuthorizationAttachments(authorization.attachments);
  const [functionsSource, cloudContractSource] = await Promise.all([
    readFile(resolve(repoRoot, "functions/src/index.ts"), "utf8"),
    readFile(
      resolve(repoRoot, "scripts/release_cloud_operations_validator.py"),
      "utf8"
    ),
  ]);
  validateTrustedEvidenceProducerRoster(functionsSource, cloudContractSource);
  return {authorization, authorizationDigest: loaded.digest, currentCommit};
}

export function firebaseDeployInvocation() {
  return {
    command: "npx",
    args: [
      "--yes",
      `firebase-tools@${FIREBASE_TOOLS_VERSION}`,
      "deploy",
      "--only",
      COORDINATED_DEPLOY_TARGET,
      "--project",
      PRODUCTION_PROJECT_ID,
      "--non-interactive",
    ],
  };
}

export async function runBackendDeploy(
  args,
  {
    repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), ".."),
    now = () => Date.now(),
    executeFile = execFilePromise,
  } = {}
) {
  const options = parseBackendDeployArguments(args);
  if (options.help) return {mode: "help"};
  const initial = await verifiedContext({
    repoRoot,
    authorizationPath: options.authorizationPath,
    nowMs: now(),
    executeFile,
  });
  await executeFile(
    resolve(repoRoot, "scripts/release-static-readiness.sh"),
    [],
    {
      cwd: repoRoot,
      encoding: "utf8",
      timeout: 30 * 60 * 1_000,
      maxBuffer: 16 * 1_024 * 1_024,
      env: {...process.env, CI: "1"},
    }
  );
  if (!options.execute) {
    return {
      mode: "preflight",
      projectID: PRODUCTION_PROJECT_ID,
      sourceGitCommit: initial.currentCommit,
      socialCutoverRunID: initial.authorization.socialCutoverRunID,
      authorizationDigest: initial.authorizationDigest,
    };
  }
  const final = await verifiedContext({
    repoRoot,
    authorizationPath: options.authorizationPath,
    nowMs: now(),
    executeFile,
  });
  if (final.authorizationDigest !== initial.authorizationDigest) {
    throw new BackendDeployError("Authorization changed during static readiness.");
  }
  const invocation = firebaseDeployInvocation();
  await executeFile(invocation.command, invocation.args, {
    cwd: repoRoot,
    encoding: "utf8",
    timeout: 60 * 60 * 1_000,
    maxBuffer: 32 * 1_024 * 1_024,
    env: {
      ...process.env,
      CI: "1",
      FIREBASE_CLI_DISABLE_UPDATE_CHECK: "1",
    },
  });
  return {
    mode: "execute",
    projectID: PRODUCTION_PROJECT_ID,
    sourceGitCommit: final.currentCommit,
    socialCutoverRunID: final.authorization.socialCutoverRunID,
    authorizationDigest: final.authorizationDigest,
  };
}

export function backendDeployUsage() {
  return [
    "Usage:",
    "  node scripts/release-backend-deploy.mjs \\",
    "    --authorization=/absolute/path/authorization.json [--execute]",
    "",
    "Without --execute, the command performs the complete local preflight and " +
      "does not invoke Firebase. Execution always targets exactly " +
      `${COORDINATED_DEPLOY_TARGET} in ${PRODUCTION_PROJECT_ID}.`,
    "",
  ].join("\n");
}

const isMain = process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href;
if (isMain) {
  try {
    if (process.argv.slice(2).includes("--help")) {
      parseBackendDeployArguments(process.argv.slice(2));
      process.stdout.write(backendDeployUsage());
    } else {
      const result = await runBackendDeploy(process.argv.slice(2));
      process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
      if (result.mode === "preflight") {
        process.stdout.write("Preflight passed. Add --execute only with active authorization.\n");
      }
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown deploy error.";
    process.stderr.write(`Backend deployment refused: ${message}\n`);
    process.exitCode = 1;
  }
}
