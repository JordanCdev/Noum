#!/usr/bin/env node

import {spawnSync} from "node:child_process";

import {
  COACH_V2_CLOUD_RUN_SERVICES,
  COACH_V2_DEPLOY_SCOPE,
  COACH_V2_FUNCTION_SELECTOR,
  COACH_V2_REGION,
  PRODUCTION_PROJECT,
  backendReleaseInputsAreClean,
  currentSourceCommit,
  repositoryRoot,
  trackedFunctionsSourceDigest,
} from "./release-backend-deploy.mjs";

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

function run(command, args, environment = process.env) {
  const result = spawnSync(command, args, {
    cwd: repositoryRoot,
    env: environment,
    stdio: "inherit",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

const args = new Set(process.argv.slice(2));
const commit = currentSourceCommit();
const required = new Set([
  "--execute",
  `--confirm-project=${PRODUCTION_PROJECT}`,
  `--confirm-source=${commit}`,
]);
for (const argument of args) {
  if (!required.has(argument)) fail(`Unsupported argument: ${argument}`);
}
for (const argument of required) {
  if (!args.has(argument)) fail(`Missing required argument: ${argument}`);
}
if (!backendReleaseInputsAreClean()) {
  fail("Backend release inputs must be committed and clean before deployment.");
}

const sourceDigest = trackedFunctionsSourceDigest();
process.stdout.write(
  `Preparing ${COACH_V2_FUNCTION_SELECTOR} for ${PRODUCTION_PROJECT}\n` +
  `Source commit: ${commit}\n` +
  `Functions SHA-256: ${sourceDigest}\n`
);

run("npm", ["--prefix", "functions", "run", "lint"]);
run("npm", ["--prefix", "functions", "test"]);
run("python3", [
  "scripts/release_cloud_operations_validator.py",
  "--source-contract",
  "functions/src/index.ts",
]);

const authorizationEnvironment = {
  ...process.env,
  GCLOUD_PROJECT: PRODUCTION_PROJECT,
  NOUM_BACKEND_DEPLOY_SCOPE: COACH_V2_DEPLOY_SCOPE,
  NOUM_BACKEND_DEPLOY_PROJECT: PRODUCTION_PROJECT,
  NOUM_BACKEND_DEPLOY_FUNCTIONS: COACH_V2_FUNCTION_SELECTOR,
  NOUM_BACKEND_DEPLOY_COMMIT: commit,
  NOUM_BACKEND_DEPLOY_SOURCE_SHA256: sourceDigest,
  NOUM_BACKEND_DEPLOY_EXPIRES_AT: String(Date.now() + 10 * 60 * 1000),
};
run("npx", [
  "-y",
  "firebase-tools@latest",
  "deploy",
  "--only",
  COACH_V2_FUNCTION_SELECTOR,
  "--project",
  PRODUCTION_PROJECT,
  "--non-interactive",
], authorizationEnvironment);

// Generation-2 callable services must admit the Firebase callable protocol at
// Cloud Run before the Functions framework can verify Firebase Auth and App
// Check. A missing invoker binding makes Cloud Run interpret a Firebase ID
// token as a Google IAM token and reject every signed-in app request with 401.
// This transport binding is intentionally limited to the exact two reviewed
// callables; both functions still fail closed on Auth and App Check in source.
for (const service of COACH_V2_CLOUD_RUN_SERVICES) {
  run("gcloud", [
    "run",
    "services",
    "add-iam-policy-binding",
    service,
    `--region=${COACH_V2_REGION}`,
    `--project=${PRODUCTION_PROJECT}`,
    "--member=allUsers",
    "--role=roles/run.invoker",
    "--quiet",
  ]);
}
