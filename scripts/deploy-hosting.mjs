#!/usr/bin/env node

import {spawnSync} from "node:child_process";
import {readFileSync} from "node:fs";
import path from "node:path";

import {
  HOSTING_DEPLOY_SCOPE,
  HOSTING_FIREBASE_TOOLS_VERSION,
  HOSTING_PRODUCTION_PROJECT,
  currentHostingSourceCommit,
  hostingReleaseInputsAreClean,
  hostingRepositoryRoot,
  trackedPublicSourceDigest,
  validateHostingConfiguration,
} from "./release-hosting-deploy.mjs";

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

function run(command, args, environment = process.env) {
  const result = spawnSync(command, args, {
    cwd: hostingRepositoryRoot,
    env: environment,
    stdio: "inherit",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

const args = new Set(process.argv.slice(2));
const commit = currentHostingSourceCommit();
const required = new Set([
  "--execute",
  `--confirm-project=${HOSTING_PRODUCTION_PROJECT}`,
  `--confirm-source=${commit}`,
]);
for (const argument of args) {
  if (!required.has(argument)) fail(`Unsupported argument: ${argument}`);
}
for (const argument of required) {
  if (!args.has(argument)) fail(`Missing required argument: ${argument}`);
}
if (!hostingReleaseInputsAreClean()) {
  fail("Hosting release inputs must be committed and clean before deployment.");
}

const configuration = JSON.parse(readFileSync(
  path.join(hostingRepositoryRoot, "firebase.json"),
  "utf8"
));
validateHostingConfiguration(configuration);
const publicDigest = trackedPublicSourceDigest();
process.stdout.write(
  `Preparing four reviewed public pages for ${HOSTING_PRODUCTION_PROJECT}\n` +
  `Source commit: ${commit}\n` +
  `Public SHA-256: ${publicDigest}\n`
);

run("python3", [
  "-m",
  "unittest",
  "scripts.tests.test_privacy_body_verifier",
]);

const authorizationEnvironment = {
  ...process.env,
  GCLOUD_PROJECT: HOSTING_PRODUCTION_PROJECT,
  NOUM_HOSTING_DEPLOY_SCOPE: HOSTING_DEPLOY_SCOPE,
  NOUM_HOSTING_DEPLOY_PROJECT: HOSTING_PRODUCTION_PROJECT,
  NOUM_HOSTING_DEPLOY_COMMIT: commit,
  NOUM_HOSTING_DEPLOY_PUBLIC_SHA256: publicDigest,
  NOUM_HOSTING_DEPLOY_EXPIRES_AT: String(Date.now() + 10 * 60 * 1000),
};
run("npx", [
  "--yes",
  "--package",
  `firebase-tools@${HOSTING_FIREBASE_TOOLS_VERSION}`,
  "firebase",
  "deploy",
  "--only",
  "hosting",
  "--project",
  HOSTING_PRODUCTION_PROJECT,
  "--non-interactive",
], authorizationEnvironment);

// A successful upload is not accepted until all four direct Firebase-origin
// responses match the exact source bytes. The probe follows no redirects and
// prints only bounded sizes and SHA-256 values, never response bodies.
run("bash", ["scripts/release-live-web-probe.sh", "firebase"]);
process.stdout.write(
  "Source-bound Firebase Hosting deployment and four-page readback passed.\n"
);
