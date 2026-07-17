#!/usr/bin/env node

import {createHash} from "node:crypto";
import {execFileSync} from "node:child_process";
import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";
import path from "node:path";

export const PRODUCTION_RUNBOOK = "docs/PRODUCTION_READINESS_RUNBOOK.md";
export const PRODUCTION_PROJECT = "noum-d0b6f";
export const COACH_V2_DEPLOY_SCOPE = "coach-v2";
export const COACH_V2_FUNCTIONS = Object.freeze([
  "coachChatV2",
  "coachChatAvailability",
]);
export const COACH_V2_FUNCTION_SELECTOR = COACH_V2_FUNCTIONS
  .map((name) => `functions:${name}`)
  .join(",");

export const DEPLOYMENT_BLOCKERS = Object.freeze([
  "Eligible competitive evidence production is missing: the local " +
    "server-observation substrate remains disabled and ineligible, has no " +
    "calibrated deterministic evaluator, and its bounded exact-audio replay " +
    "and retention contracts lack deployed TTL and live-provider evidence.",
  "Local reciprocal friendship authority and invite-retention policy are " +
    "not deployed or live-verified, and the client capability remains " +
    "disabled; complete the guarded cutover and independent verification " +
    "before release.",
  "Independently trusted deployment authorization evidence is missing; " +
    "obtain and verify it before deployment.",
  "An immutable source-bound deployment artifact is missing; build and " +
    "verify it before deployment.",
]);

export class BackendDeployUnavailableError extends Error {
  constructor(message) {
    super(message);
    this.name = "BackendDeployUnavailableError";
  }
}

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
export const repositoryRoot = path.resolve(scriptDirectory, "..");

function gitOutput(args, cwd = repositoryRoot) {
  return execFileSync("git", args, {cwd, encoding: "utf8"}).trim();
}

export function currentSourceCommit() {
  return gitOutput(["rev-parse", "HEAD"]);
}

export function trackedFunctionsSourceDigest() {
  const files = gitOutput(["ls-files", "functions"])
    .split("\n")
    .filter(Boolean)
    .sort();
  if (files.length === 0) {
    throw new BackendDeployUnavailableError(
      "No tracked Functions source was found."
    );
  }
  const digest = createHash("sha256");
  for (const relativePath of files) {
    digest.update(relativePath);
    digest.update("\0");
    digest.update(readFileSync(path.join(repositoryRoot, relativePath)));
    digest.update("\0");
  }
  return digest.digest("hex");
}

export function backendReleaseInputsAreClean() {
  const status = gitOutput([
    "status",
    "--porcelain",
    "--",
    "functions",
    "firebase.json",
    "scripts/release-backend-deploy.mjs",
    "scripts/deploy-coach-v2.mjs",
    "scripts/release-backend-deploy.test.mjs",
  ]);
  return status.length === 0;
}

export function validateScopedCoachDeploymentAuthorization(
  environment,
  {
    now = Date.now(),
    commit = currentSourceCommit(),
    sourceDigest = trackedFunctionsSourceDigest(),
    releaseInputsClean = backendReleaseInputsAreClean(),
  } = {}
) {
  const fail = (message) => {
    throw new BackendDeployUnavailableError(message);
  };
  if (environment.NOUM_BACKEND_DEPLOY_SCOPE !== COACH_V2_DEPLOY_SCOPE) {
    fail("The exact coach-v2 deployment scope is required.");
  }
  if (environment.NOUM_BACKEND_DEPLOY_PROJECT !== PRODUCTION_PROJECT ||
      environment.GCLOUD_PROJECT !== PRODUCTION_PROJECT) {
    fail(`The deployment must target ${PRODUCTION_PROJECT}.`);
  }
  if (environment.NOUM_BACKEND_DEPLOY_FUNCTIONS !== COACH_V2_FUNCTION_SELECTOR) {
    fail("The deployment must contain exactly the two reviewed coach-v2 functions.");
  }
  if (!releaseInputsClean) {
    fail("Backend release inputs must be committed and clean.");
  }
  if (environment.NOUM_BACKEND_DEPLOY_COMMIT !== commit) {
    fail("The deployment authorization is not bound to the current commit.");
  }
  if (environment.NOUM_BACKEND_DEPLOY_SOURCE_SHA256 !== sourceDigest) {
    fail("The deployment authorization is not bound to the current Functions source.");
  }
  const expiresAt = Number(environment.NOUM_BACKEND_DEPLOY_EXPIRES_AT);
  if (!Number.isSafeInteger(expiresAt) || expiresAt <= now ||
      expiresAt > now + 15 * 60 * 1000) {
    fail("The deployment authorization is expired or exceeds fifteen minutes.");
  }
  return {
    project: PRODUCTION_PROJECT,
    functions: [...COACH_V2_FUNCTIONS],
    commit,
    sourceDigest,
    expiresAt,
  };
}

export function parseBackendDeployArguments(args) {
  if (args.length === 0) return {help: false};
  if (args.length === 1 && args[0] === "--help") return {help: true};
  throw new BackendDeployUnavailableError(
    `Unsupported deployment argument: ${args[0] ?? "unknown"}. ` +
    "Use the checked-in scoped deployment wrapper."
  );
}

export function backendDeployHelp() {
  return [
    "Blanket backend deployment is intentionally unavailable.",
    "",
    "The additive coach-v2 functions have one source-bound scoped path:",
    "node scripts/deploy-coach-v2.mjs --execute " +
      `--confirm-project=${PRODUCTION_PROJECT} --confirm-source=<git-commit>`,
    `All other backend release work remains governed by ${PRODUCTION_RUNBOOK}.`,
    "",
  ].join("\n");
}

export function backendDeployRefusal() {
  return [
    "Backend deployment refused.",
    ...DEPLOYMENT_BLOCKERS.map((blocker) => `- ${blocker}`),
    `See ${PRODUCTION_RUNBOOK}.`,
    "",
  ].join("\n");
}

const isMain = process.argv[1]?.endsWith("release-backend-deploy.mjs") === true;
if (isMain) {
  try {
    const options = parseBackendDeployArguments(process.argv.slice(2));
    if (options.help) {
      process.stdout.write(backendDeployHelp());
    } else if (process.env.NOUM_BACKEND_DEPLOY_SCOPE === COACH_V2_DEPLOY_SCOPE) {
      const authorization = validateScopedCoachDeploymentAuthorization(process.env);
      process.stdout.write(
        `Authorized scoped coach-v2 deployment for ${authorization.project} ` +
        `at ${authorization.commit.slice(0, 12)}.\n`
      );
    } else {
      process.stderr.write(backendDeployRefusal());
      process.exitCode = 1;
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown argument.";
    process.stderr.write(`${message}\n${backendDeployRefusal()}`);
    process.exitCode = 2;
  }
}
