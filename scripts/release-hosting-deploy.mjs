#!/usr/bin/env node

import {createHash} from "node:crypto";
import {execFileSync} from "node:child_process";
import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";
import path from "node:path";

export const HOSTING_PRODUCTION_PROJECT = "noum-d0b6f";
export const HOSTING_DEPLOY_SCOPE = "public-four-page-v1";
export const HOSTING_FIREBASE_TOOLS_VERSION = "15.19.1";
export const HOSTING_PUBLIC_FILES = Object.freeze([
  "public/how-noum-coaches.html",
  "public/index.html",
  "public/privacy.html",
  "public/support.html",
]);
export const HOSTING_DEPLOYMENT_HOOK =
  'node "$PROJECT_DIR/scripts/release-hosting-deploy.mjs"';

export class HostingDeployUnavailableError extends Error {
  constructor(message) {
    super(message);
    this.name = "HostingDeployUnavailableError";
  }
}

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
export const hostingRepositoryRoot = path.resolve(scriptDirectory, "..");

function gitOutput(args) {
  return execFileSync("git", args, {
    cwd: hostingRepositoryRoot,
    encoding: "utf8",
  }).trim();
}

export function currentHostingSourceCommit() {
  return gitOutput(["rev-parse", "HEAD"]);
}

function trackedPublicFiles() {
  return gitOutput(["ls-files", "public"])
    .split("\n")
    .filter(Boolean)
    .sort();
}

export function trackedPublicSourceDigest() {
  const files = trackedPublicFiles();
  if (files.length !== HOSTING_PUBLIC_FILES.length ||
      !files.every((file, index) => file === HOSTING_PUBLIC_FILES[index])) {
    throw new HostingDeployUnavailableError(
      "Hosting must contain exactly the four reviewed public source files."
    );
  }
  const digest = createHash("sha256");
  for (const relativePath of files) {
    digest.update(relativePath);
    digest.update("\0");
    digest.update(readFileSync(path.join(hostingRepositoryRoot, relativePath)));
    digest.update("\0");
  }
  return digest.digest("hex");
}

export function hostingReleaseInputsAreClean() {
  const status = gitOutput([
    "status",
    "--porcelain",
    "--",
    ".firebaserc",
    "firebase.json",
    "public",
    "scripts/deploy-hosting.mjs",
    "scripts/release-hosting-deploy.mjs",
    "scripts/release-hosting-deploy.test.mjs",
    "scripts/release-live-web-probe.sh",
    "scripts/privacy_body_verifier.py",
  ]);
  return status.length === 0;
}

export function validateHostingConfiguration(configuration) {
  const fail = (message) => {
    throw new HostingDeployUnavailableError(message);
  };
  if (!configuration || typeof configuration !== "object" ||
      Array.isArray(configuration)) {
    fail("Firebase Hosting configuration must be an object.");
  }
  const targets = Array.isArray(configuration.hosting) ?
    configuration.hosting : [configuration.hosting];
  if (targets.length !== 1 || !targets[0] ||
      targets[0].public !== "public") {
    fail("Exactly one Firebase Hosting target must publish public/. ");
  }
  const target = targets[0];
  const rewrites = new Map((target.rewrites ?? []).map((item) => [
    item?.source,
    item?.destination,
  ]));
  const requiredRewrites = new Map([
    ["/privacy", "/privacy.html"],
    ["/support", "/support.html"],
    ["/how-noum-coaches", "/how-noum-coaches.html"],
  ]);
  if (rewrites.size !== requiredRewrites.size ||
      ![...requiredRewrites].every(([source, destination]) =>
        rewrites.get(source) === destination
      )) {
    fail("Firebase Hosting must retain exactly the three reviewed rewrites.");
  }
  if (!Array.isArray(target.predeploy) ||
      target.predeploy.length !== 1 ||
      target.predeploy[0] !== HOSTING_DEPLOYMENT_HOOK) {
    fail("Firebase Hosting must retain its exact source-bound predeploy hook.");
  }
  return true;
}

export function validateHostingDeploymentAuthorization(
  environment,
  {
    now = Date.now(),
    commit = currentHostingSourceCommit(),
    publicDigest = trackedPublicSourceDigest(),
    releaseInputsClean = hostingReleaseInputsAreClean(),
  } = {}
) {
  const fail = (message) => {
    throw new HostingDeployUnavailableError(message);
  };
  if (environment.NOUM_HOSTING_DEPLOY_SCOPE !== HOSTING_DEPLOY_SCOPE) {
    fail("The exact four-page Hosting deployment scope is required.");
  }
  if (environment.NOUM_HOSTING_DEPLOY_PROJECT !==
        HOSTING_PRODUCTION_PROJECT ||
      environment.GCLOUD_PROJECT !== HOSTING_PRODUCTION_PROJECT) {
    fail(`Hosting deployment must target ${HOSTING_PRODUCTION_PROJECT}.`);
  }
  if (!releaseInputsClean) {
    fail("Hosting release inputs must be committed and clean.");
  }
  if (environment.NOUM_HOSTING_DEPLOY_COMMIT !== commit) {
    fail("Hosting authorization is not bound to the current commit.");
  }
  if (environment.NOUM_HOSTING_DEPLOY_PUBLIC_SHA256 !== publicDigest) {
    fail("Hosting authorization is not bound to the reviewed public bytes.");
  }
  const expiresAt = Number(environment.NOUM_HOSTING_DEPLOY_EXPIRES_AT);
  if (!Number.isSafeInteger(expiresAt) || expiresAt <= now ||
      expiresAt > now + 15 * 60 * 1000) {
    fail("Hosting authorization is expired or exceeds fifteen minutes.");
  }
  return {
    project: HOSTING_PRODUCTION_PROJECT,
    commit,
    publicDigest,
    expiresAt,
  };
}

export function hostingDeployHelp() {
  return [
    "Direct Firebase Hosting deployment is intentionally unavailable.",
    "",
    "Use the source-bound four-page wrapper:",
    "node scripts/deploy-hosting.mjs --execute " +
      `--confirm-project=${HOSTING_PRODUCTION_PROJECT} ` +
      "--confirm-source=<git-commit>",
    "The wrapper always performs the Firebase-origin exact-body probe.",
    "",
  ].join("\n");
}

const isMain = process.argv[1]?.endsWith("release-hosting-deploy.mjs") === true;
if (isMain) {
  if (process.argv.length === 3 && process.argv[2] === "--help") {
    process.stdout.write(hostingDeployHelp());
  } else if (process.argv.length !== 2) {
    process.stderr.write(
      "Unsupported Hosting deployment argument. Use the checked-in wrapper.\n"
    );
    process.exitCode = 2;
  } else {
    try {
      const authorization = validateHostingDeploymentAuthorization(process.env);
      const configuration = JSON.parse(readFileSync(
        path.join(hostingRepositoryRoot, "firebase.json"),
        "utf8"
      ));
      validateHostingConfiguration(configuration);
      process.stdout.write(
        `Authorized four-page Hosting deployment for ${authorization.project} ` +
        `at ${authorization.commit.slice(0, 12)} ` +
        `(public SHA-256 ${authorization.publicDigest}).\n`
      );
    } catch (error) {
      const message = error instanceof Error ? error.message :
        "Unknown Hosting deployment refusal.";
      process.stderr.write(`${message}\n${hostingDeployHelp()}`);
      process.exitCode = 1;
    }
  }
}
