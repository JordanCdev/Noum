import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

import {
  ACCOUNT_DELETION_CALLABLE_CLOUD_RUN_SERVICE,
  ACCOUNT_DELETION_DEPLOY_SCOPE,
  ACCOUNT_DELETION_FUNCTION_SELECTOR,
  ACCOUNT_DELETION_FUNCTIONS,
  ACCOUNT_DELETION_RECONCILER_CLOUD_RUN_SERVICE,
  BackendDeployUnavailableError,
  COACH_V2_CLOUD_RUN_SERVICES,
  COACH_V2_DEPLOY_SCOPE,
  COACH_V2_FUNCTION_SELECTOR,
  COACH_V2_REGION,
  DEPLOYMENT_BLOCKERS,
  FIREBASE_TOOLS_VERSION,
  PRODUCTION_PROJECT,
  PRODUCTION_RUNBOOK,
  backendDeployHelp,
  backendDeployRefusal,
  parseBackendDeployArguments,
  validateScopedAccountDeletionDeploymentAuthorization,
  validateScopedCoachDeploymentAuthorization,
} from "./release-backend-deploy.mjs";

const EXPECTED_BLOCKERS = [
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
];

const FIREBASE_DEPLOYMENT_BLOCKER =
  'node "$PROJECT_DIR/scripts/release-backend-deploy.mjs"';

test("the exact actionable blocker roster is stable", () => {
  assert.deepEqual([...DEPLOYMENT_BLOCKERS], EXPECTED_BLOCKERS);
  const refusal = backendDeployRefusal();
  for (const blocker of EXPECTED_BLOCKERS) {
    assert.equal(refusal.includes(`- ${blocker}`), true);
  }
  assert.match(refusal, new RegExp(PRODUCTION_RUNBOOK));
});

test("help keeps blanket deployment closed and names only scoped paths", () => {
  assert.deepEqual(parseBackendDeployArguments(["--help"]), {help: true});
  assert.match(backendDeployHelp(), /Blanket backend deployment is intentionally unavailable/i);
  assert.match(backendDeployHelp(), /deploy-coach-v2\.mjs --execute/);
  assert.match(
    backendDeployHelp(),
    /deploy-account-deletion\.mjs --execute/
  );
  assert.match(backendDeployHelp(), /--confirm-source=<git-commit>/);
  assert.match(backendDeployHelp(), new RegExp(PRODUCTION_RUNBOOK));
});

test("no arguments is a deploy attempt, not an execute authorization", () => {
  assert.deepEqual(parseBackendDeployArguments([]), {help: false});
  assert.match(backendDeployRefusal(), /^Backend deployment refused\./);
});

test("every mutation-looking argument is rejected", () => {
  for (const args of [
    ["--execute"],
    ["--authorization=/tmp/release.json"],
    ["--project=noum-d0b6f"],
    ["--only=functions,firestore:rules"],
    ["--force"],
    ["deploy"],
    ["--help", "--execute"],
  ]) {
    assert.throws(
      () => parseBackendDeployArguments(args),
      (error) => error instanceof BackendDeployUnavailableError &&
        /scoped deployment wrapper/.test(error.message),
      args.join(" ")
    );
  }
});

test("blocker source cannot perform the Firebase deployment itself", async () => {
  const source = await readFile(
    new URL("./release-backend-deploy.mjs", import.meta.url),
    "utf8"
  );
  for (const forbidden of [
    "spawn(",
    "fetch(",
    "node:http",
    "node:https",
    "npx",
    "firebase-tools",
  ]) {
    assert.equal(source.includes(forbidden), false, forbidden);
  }
});

test("scoped authorization is exact, source-bound, clean, and short-lived", () => {
  const now = 1_800_000_000_000;
  const commit = "a".repeat(40);
  const sourceDigest = "b".repeat(64);
  const environment = {
    NOUM_BACKEND_DEPLOY_SCOPE: COACH_V2_DEPLOY_SCOPE,
    NOUM_BACKEND_DEPLOY_PROJECT: PRODUCTION_PROJECT,
    NOUM_BACKEND_DEPLOY_FUNCTIONS: COACH_V2_FUNCTION_SELECTOR,
    NOUM_BACKEND_DEPLOY_COMMIT: commit,
    NOUM_BACKEND_DEPLOY_SOURCE_SHA256: sourceDigest,
    NOUM_BACKEND_DEPLOY_EXPIRES_AT: String(now + 10 * 60 * 1000),
    GCLOUD_PROJECT: PRODUCTION_PROJECT,
  };
  assert.deepEqual(
    validateScopedCoachDeploymentAuthorization(environment, {
      now,
      commit,
      sourceDigest,
      releaseInputsClean: true,
    }),
    {
      project: PRODUCTION_PROJECT,
      functions: ["coachChatV2", "coachChatAvailability"],
      commit,
      sourceDigest,
      expiresAt: now + 10 * 60 * 1000,
    }
  );

  const invalidCases = [
    ["NOUM_BACKEND_DEPLOY_SCOPE", "all"],
    ["NOUM_BACKEND_DEPLOY_PROJECT", "lookalike-noum"],
    ["GCLOUD_PROJECT", "lookalike-noum"],
    ["NOUM_BACKEND_DEPLOY_FUNCTIONS", "functions"],
    ["NOUM_BACKEND_DEPLOY_COMMIT", "c".repeat(40)],
    ["NOUM_BACKEND_DEPLOY_SOURCE_SHA256", "d".repeat(64)],
    ["NOUM_BACKEND_DEPLOY_EXPIRES_AT", String(now - 1)],
    ["NOUM_BACKEND_DEPLOY_EXPIRES_AT", String(now + 16 * 60 * 1000)],
  ];
  for (const [key, value] of invalidCases) {
    assert.throws(
      () => validateScopedCoachDeploymentAuthorization(
        {...environment, [key]: value},
        {now, commit, sourceDigest, releaseInputsClean: true}
      ),
      BackendDeployUnavailableError,
      key
    );
  }
  assert.throws(
    () => validateScopedCoachDeploymentAuthorization(environment, {
      now,
      commit,
      sourceDigest,
      releaseInputsClean: false,
    }),
    /committed and clean/
  );
});

test("account-deletion authorization admits exactly the callable and recovery schedule", () => {
  const now = 1_800_000_000_000;
  const commit = "c".repeat(40);
  const sourceDigest = "d".repeat(64);
  const environment = {
    NOUM_BACKEND_DEPLOY_SCOPE: ACCOUNT_DELETION_DEPLOY_SCOPE,
    NOUM_BACKEND_DEPLOY_PROJECT: PRODUCTION_PROJECT,
    NOUM_BACKEND_DEPLOY_FUNCTIONS: ACCOUNT_DELETION_FUNCTION_SELECTOR,
    NOUM_BACKEND_DEPLOY_COMMIT: commit,
    NOUM_BACKEND_DEPLOY_SOURCE_SHA256: sourceDigest,
    NOUM_BACKEND_DEPLOY_EXPIRES_AT: String(now + 10 * 60 * 1000),
    GCLOUD_PROJECT: PRODUCTION_PROJECT,
  };
  assert.deepEqual(
    validateScopedAccountDeletionDeploymentAuthorization(environment, {
      now,
      commit,
      sourceDigest,
      releaseInputsClean: true,
    }),
    {
      project: PRODUCTION_PROJECT,
      functions: [...ACCOUNT_DELETION_FUNCTIONS],
      commit,
      sourceDigest,
      expiresAt: now + 10 * 60 * 1000,
    }
  );
  for (const selector of [
    "functions:deleteAccount",
    `${ACCOUNT_DELETION_FUNCTION_SELECTOR},functions:recordGrowthAggregate`,
    "functions",
  ]) {
    assert.throws(
      () => validateScopedAccountDeletionDeploymentAuthorization(
        {...environment, NOUM_BACKEND_DEPLOY_FUNCTIONS: selector},
        {now, commit, sourceDigest, releaseInputsClean: true}
      ),
      BackendDeployUnavailableError,
      selector
    );
  }
  assert.throws(
    () => validateScopedCoachDeploymentAuthorization(environment, {
      now,
      commit,
      sourceDigest,
      releaseInputsClean: true,
    }),
    BackendDeployUnavailableError
  );
});

test("functions deploy and CI test scripts route through the blocker", async () => {
  const packageJSON = JSON.parse(await readFile(
    new URL("../functions/package.json", import.meta.url),
    "utf8"
  ));
  assert.equal(
    packageJSON.scripts.deploy,
    "node ../scripts/release-backend-deploy.mjs"
  );
  assert.equal(
    packageJSON.scripts["deploy:coach-v2"],
    "node ../scripts/deploy-coach-v2.mjs"
  );
  assert.equal(
    packageJSON.scripts["deploy:account-deletion"],
    "node ../scripts/deploy-account-deletion.mjs"
  );
  assert.match(
    packageJSON.scripts.test,
    /node --test \.\.\/scripts\/release-backend-deploy\.test\.mjs/
  );
  assert.match(
    packageJSON.scripts.test,
    /\.\.\/scripts\/release-hosting-deploy\.test\.mjs/
  );
  assert.doesNotMatch(packageJSON.scripts.deploy, /firebase|npx|--execute/);
});

test("scoped coach deployment restores only the callable transport bindings", async () => {
  assert.equal(COACH_V2_REGION, "europe-west2");
  assert.deepEqual([...COACH_V2_CLOUD_RUN_SERVICES], [
    "coachchatv2",
    "coachchatavailability",
  ]);
  const source = await readFile(
    new URL("./deploy-coach-v2.mjs", import.meta.url),
    "utf8"
  );
  assert.match(source, /add-iam-policy-binding/);
  assert.match(source, /--member=allUsers/);
  assert.match(source, /--role=roles\/run\.invoker/);
  assert.match(source, new RegExp(`firebase-tools@\\$\\{FIREBASE_TOOLS_VERSION\\}`));
  assert.match(source, /--app-store-contract/);
  assert.match(source, /--functions-lockfile/);
  assert.doesNotMatch(source, /roles\/(owner|editor)/i);
  assert.doesNotMatch(source, /firebase-tools@latest/);
});

test("account-deletion deployment cannot expand beyond its exact backend slice", async () => {
  assert.equal(FIREBASE_TOOLS_VERSION, "15.19.1");
  assert.equal(
    ACCOUNT_DELETION_CALLABLE_CLOUD_RUN_SERVICE,
    "deleteaccount"
  );
  assert.equal(
    ACCOUNT_DELETION_RECONCILER_CLOUD_RUN_SERVICE,
    "reconcileaccountdeletiontombstones"
  );
  assert.deepEqual([...ACCOUNT_DELETION_FUNCTIONS], [
    "deleteAccount",
    "reconcileAccountDeletionTombstones",
  ]);
  const source = await readFile(
    new URL("./deploy-account-deletion.mjs", import.meta.url),
    "utf8"
  );
  assert.match(source, /ACCOUNT_DELETION_FUNCTION_SELECTOR/);
  assert.match(source, /firebase-tools@\$\{FIREBASE_TOOLS_VERSION\}/);
  assert.match(source, /--non-interactive/);
  assert.match(source, /requireActiveAccountDeletionInfrastructure\(\)/);
  assert.match(source, /requireActiveFunctionReadback\(name\)/);
  assert.match(source, /--app-store-contract/);
  assert.match(source, /--functions-lockfile/);
  assert.match(source, /ACCOUNT_DELETION_CALLABLE_CLOUD_RUN_SERVICE/);
  assert.match(source, /ACCOUNT_DELETION_RECONCILER_CLOUD_RUN_SERVICE/);
  assert.match(source, /--member=allUsers/);
  assert.match(source, /--role=roles\/run\.invoker/);
  assert.match(source, /requireExactTransportIAM\(\)/);
  assert.match(source, /recovery schedule must not be publicly invokable/);
  assert.doesNotMatch(source, /firebase-tools@latest/);
  assert.doesNotMatch(source, /firestore:(?:rules|indexes)/);
  assert.doesNotMatch(source, /--force/);
  assert.doesNotMatch(source, /roles\/(?:owner|editor)/i);
});

test("account-deletion slice preserves the social cutover and recovery contracts", async () => {
  const source = await readFile(
    new URL("../functions/src/index.ts", import.meta.url),
    "utf8"
  );
  const executorStart = source.indexOf("async function executeAccountDeletion(");
  const callableStart = source.indexOf("export const deleteAccount", executorStart);
  const executor = source.slice(executorStart, callableStart);
  const markerRead = executor.indexOf("_socialReferenceCutover");
  const cutoverGate = executor.indexOf(
    "assertSocialReferenceCutoverComplete(cutoverSnapshot.data())"
  );
  const pendingFence = executor.indexOf('status: "pending"');
  assert.equal(
    markerRead >= 0 && cutoverGate > markerRead && pendingFence > cutoverGate,
    true
  );

  const scheduler = source.slice(
    source.indexOf("export const reconcileAccountDeletionTombstones")
  );
  assert.match(scheduler, /schedule: "every 15 minutes"/);
  assert.match(scheduler, /executeAccountDeletion\(null, candidate\)/);

  const indexes = JSON.parse(await readFile(
    new URL("../firestore.indexes.json", import.meta.url),
    "utf8"
  ));
  assert.equal(indexes.indexes.filter((item) =>
    item.collectionGroup === "_accountDeletionState" &&
    item.queryScope === "COLLECTION" &&
    item.fields?.[0]?.fieldPath === "status" &&
    item.fields?.[1]?.fieldPath === "updatedAt"
  ).length, 1);
  assert.equal(indexes.fieldOverrides.filter((item) =>
    item.collectionGroup === "_accountDeletionState" &&
    item.fieldPath === "expiresAt" && item.ttl === true
  ).length, 1);
});

test("every checked-in Firebase Functions and Firestore deploy stops at the blocker", async () => {
  const firebaseJSON = JSON.parse(await readFile(
    new URL("../firebase.json", import.meta.url),
    "utf8"
  ));
  const functionsTargets = Array.isArray(firebaseJSON.functions)
    ? firebaseJSON.functions
    : [firebaseJSON.functions];
  const firestoreTargets = Array.isArray(firebaseJSON.firestore)
    ? firebaseJSON.firestore
    : [firebaseJSON.firestore];
  const hostingTargets = Array.isArray(firebaseJSON.hosting)
    ? firebaseJSON.hosting
    : [firebaseJSON.hosting];

  assert.ok(functionsTargets.length > 0);
  for (const target of functionsTargets) {
    assert.equal(target.predeploy?.[0], FIREBASE_DEPLOYMENT_BLOCKER);
  }
  assert.ok(firestoreTargets.length > 0);
  for (const target of firestoreTargets) {
    assert.equal(target.predeploy?.[0], FIREBASE_DEPLOYMENT_BLOCKER);
  }
  for (const target of hostingTargets) {
    assert.equal(
      target.predeploy?.includes(FIREBASE_DEPLOYMENT_BLOCKER) ?? false,
      false
    );
  }
});
