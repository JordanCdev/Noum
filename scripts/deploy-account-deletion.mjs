#!/usr/bin/env node

import {spawnSync} from "node:child_process";
import {readFileSync} from "node:fs";
import path from "node:path";

import {
  ACCOUNT_DELETION_CALLABLE_CLOUD_RUN_SERVICE,
  ACCOUNT_DELETION_DEPLOY_SCOPE,
  ACCOUNT_DELETION_FUNCTIONS,
  ACCOUNT_DELETION_FUNCTION_SELECTOR,
  ACCOUNT_DELETION_RECONCILER_CLOUD_RUN_SERVICE,
  ACCOUNT_RUNTIME_SERVICE_ACCOUNT,
  COACH_V2_REGION,
  FIREBASE_TOOLS_VERSION,
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

function output(command, args) {
  const result = spawnSync(command, args, {
    cwd: repositoryRoot,
    env: process.env,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
  return result.stdout;
}

function parseJSONArray(value, label) {
  let parsed;
  try {
    parsed = JSON.parse(value);
  } catch {
    fail(`${label} did not return valid JSON.`);
  }
  if (!Array.isArray(parsed)) fail(`${label} must return a JSON array.`);
  return parsed;
}

function isAccountDeletionIndex(item) {
  if (!item || typeof item !== "object") return false;
  const collectionGroup = item.collectionGroup ??
    (typeof item.name === "string" &&
      item.name.includes("/collectionGroups/_accountDeletionState/") ?
      "_accountDeletionState" : null);
  const fields = Array.isArray(item.fields) ? item.fields : [];
  const required = [
    ["status", "ASCENDING"],
    ["updatedAt", "ASCENDING"],
  ];
  const leadingFieldsMatch = required.every(([fieldPath, order], index) =>
    fields[index]?.fieldPath === fieldPath && fields[index]?.order === order
  );
  const trailingFieldsAreNames = fields.slice(required.length).every(
    (field) => field?.fieldPath === "__name__"
  );
  return collectionGroup === "_accountDeletionState" &&
    item.queryScope === "COLLECTION" && leadingFieldsMatch &&
    trailingFieldsAreNames;
}

function sourceDeclaresAccountDeletionInfrastructure() {
  const configuration = JSON.parse(readFileSync(
    path.join(repositoryRoot, "firestore.indexes.json"),
    "utf8"
  ));
  const indexes = Array.isArray(configuration.indexes) ?
    configuration.indexes : [];
  const ttlFields = Array.isArray(configuration.fieldOverrides) ?
    configuration.fieldOverrides : [];
  const matchingIndexes = indexes.filter(isAccountDeletionIndex);
  const matchingTTLs = ttlFields.filter((item) =>
    item?.collectionGroup === "_accountDeletionState" &&
    item?.fieldPath === "expiresAt" && item?.ttl === true
  );
  if (matchingIndexes.length !== 1 || matchingTTLs.length !== 1) {
    fail(
      "Source must declare exactly one account-deletion composite index " +
      "and expiresAt TTL."
    );
  }
}

function requireActiveAccountDeletionInfrastructure() {
  const indexes = parseJSONArray(output("gcloud", [
    "firestore",
    "indexes",
    "composite",
    "list",
    `--project=${PRODUCTION_PROJECT}`,
    "--database=(default)",
    "--format=json",
  ]), "Firestore composite-index inventory");
  const readyIndexes = indexes.filter((item) =>
    isAccountDeletionIndex(item) && item.state === "READY"
  );
  if (readyIndexes.length !== 1) {
    fail(
      "The exact account-deletion composite index must exist once and be READY."
    );
  }

  const ttlPolicies = parseJSONArray(output("gcloud", [
    "firestore",
    "fields",
    "ttls",
    "list",
    `--project=${PRODUCTION_PROJECT}`,
    "--database=(default)",
    "--format=json",
  ]), "Firestore TTL inventory");
  const ttlName = `projects/${PRODUCTION_PROJECT}/databases/(default)/` +
    "collectionGroups/_accountDeletionState/fields/expiresAt";
  const activeTTLs = ttlPolicies.filter((item) =>
    item?.name === ttlName && item?.ttlConfig?.state === "ACTIVE"
  );
  if (activeTTLs.length !== 1) {
    fail(
      "The exact account-deletion expiresAt TTL must exist once and be ACTIVE."
    );
  }
}

function requireActiveFunctionReadback(name) {
  const description = JSON.parse(output("gcloud", [
    "functions",
    "describe",
    name,
    "--v2",
    `--project=${PRODUCTION_PROJECT}`,
    `--region=${COACH_V2_REGION}`,
    "--format=json",
  ]));
  const deployedName = typeof description.name === "string" ?
    description.name.split("/").at(-1) : null;
  if (deployedName !== name || description.state !== "ACTIVE" ||
      description.environment !== "GEN_2" ||
      description.buildConfig?.runtime !== "nodejs22" ||
      description.serviceConfig?.serviceAccountEmail !==
        ACCOUNT_RUNTIME_SERVICE_ACCOUNT) {
    fail(`${name} deployment readback did not match the reviewed runtime.`);
  }
}

function requireExactTransportIAM() {
  const policyFor = (service) => JSON.parse(output("gcloud", [
    "run",
    "services",
    "get-iam-policy",
    service,
    `--region=${COACH_V2_REGION}`,
    `--project=${PRODUCTION_PROJECT}`,
    "--format=json",
  ]));
  const publicMembers = new Set(["allUsers", "allAuthenticatedUsers"]);
  const publicInvokers = (policy) => (policy.bindings ?? []).flatMap(
    (binding) => binding?.role === "roles/run.invoker" ?
      (binding.members ?? []).filter((member) => publicMembers.has(member)) : []
  );
  const callablePolicy = policyFor(
    ACCOUNT_DELETION_CALLABLE_CLOUD_RUN_SERVICE
  );
  const reconcilerPolicy = policyFor(
    ACCOUNT_DELETION_RECONCILER_CLOUD_RUN_SERVICE
  );
  const callablePublic = publicInvokers(callablePolicy);
  const reconcilerPublic = publicInvokers(reconcilerPolicy);
  if (callablePublic.length !== 1 || callablePublic[0] !== "allUsers") {
    fail("The account-deletion callable transport must admit allUsers exactly.");
  }
  if (reconcilerPublic.length !== 0) {
    fail("The account-deletion recovery schedule must not be publicly invokable.");
  }
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
  `Preparing ${ACCOUNT_DELETION_FUNCTION_SELECTOR} for ${PRODUCTION_PROJECT}\n` +
  `Source commit: ${commit}\n` +
  `Functions SHA-256: ${sourceDigest}\n`
);

sourceDeclaresAccountDeletionInfrastructure();
run("npm", ["--prefix", "functions", "run", "lint"]);
run("npm", ["--prefix", "functions", "test"]);
run("python3", [
  "scripts/release_cloud_operations_validator.py",
  "--source-contract",
  "functions/src/index.ts",
  "--app-store-contract",
  "functions/src/appStoreServerNotifications.ts",
  "--functions-lockfile",
  "functions/package-lock.json",
]);

// The reconciler's range query and the retained deletion fence are unsafe to
// advertise as operational without their exact production index and TTL.
// These are read-only checks; the mixed social/competitive index bundle is not
// deployed by this scoped path.
requireActiveAccountDeletionInfrastructure();

const authorizationEnvironment = {
  ...process.env,
  GCLOUD_PROJECT: PRODUCTION_PROJECT,
  NOUM_BACKEND_DEPLOY_SCOPE: ACCOUNT_DELETION_DEPLOY_SCOPE,
  NOUM_BACKEND_DEPLOY_PROJECT: PRODUCTION_PROJECT,
  NOUM_BACKEND_DEPLOY_FUNCTIONS: ACCOUNT_DELETION_FUNCTION_SELECTOR,
  NOUM_BACKEND_DEPLOY_COMMIT: commit,
  NOUM_BACKEND_DEPLOY_SOURCE_SHA256: sourceDigest,
  NOUM_BACKEND_DEPLOY_EXPIRES_AT: String(Date.now() + 10 * 60 * 1000),
};
run("npx", [
  "--yes",
  "--package",
  `firebase-tools@${FIREBASE_TOOLS_VERSION}`,
  "firebase",
  "deploy",
  "--only",
  ACCOUNT_DELETION_FUNCTION_SELECTOR,
  "--project",
  PRODUCTION_PROJECT,
  "--non-interactive",
], authorizationEnvironment);

// Only the callable transport is public. Firebase Auth, App Check, recent-auth,
// exact UID binding, Apple revocation, and social-cutover checks remain inside
// the Functions framework and handler. The scheduled reconciler is not public.
run("gcloud", [
  "run",
  "services",
  "add-iam-policy-binding",
  ACCOUNT_DELETION_CALLABLE_CLOUD_RUN_SERVICE,
  `--region=${COACH_V2_REGION}`,
  `--project=${PRODUCTION_PROJECT}`,
  "--member=allUsers",
  "--role=roles/run.invoker",
  "--quiet",
]);

for (const name of ACCOUNT_DELETION_FUNCTIONS) {
  requireActiveFunctionReadback(name);
}
requireExactTransportIAM();
process.stdout.write(
  "Account-deletion callable and recovery schedule are ACTIVE with the " +
  "reviewed runtime identity.\n"
);
