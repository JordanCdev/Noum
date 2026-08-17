import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {readFile} from "node:fs/promises";
import test from "node:test";

import {
  HOSTING_DEPLOYMENT_HOOK,
  HOSTING_DEPLOY_SCOPE,
  HOSTING_FIREBASE_TOOLS_VERSION,
  HOSTING_PRODUCTION_PROJECT,
  HOSTING_PUBLIC_FILES,
  HostingDeployUnavailableError,
  hostingDeployHelp,
  trackedPublicSourceDigest,
  validateHostingConfiguration,
  validateHostingDeploymentAuthorization,
} from "./release-hosting-deploy.mjs";

test("public digest binds the exact four reviewed files and their paths", async () => {
  assert.deepEqual([...HOSTING_PUBLIC_FILES], [
    "public/how-noum-coaches.html",
    "public/index.html",
    "public/privacy.html",
    "public/support.html",
  ]);
  const digest = createHash("sha256");
  for (const relativePath of HOSTING_PUBLIC_FILES) {
    digest.update(relativePath);
    digest.update("\0");
    digest.update(await readFile(new URL(`../${relativePath}`, import.meta.url)));
    digest.update("\0");
  }
  assert.equal(trackedPublicSourceDigest(), digest.digest("hex"));
});

test("hosting authorization is exact, clean, source-bound, and short-lived", () => {
  const now = 1_800_000_000_000;
  const commit = "a".repeat(40);
  const publicDigest = "b".repeat(64);
  const environment = {
    NOUM_HOSTING_DEPLOY_SCOPE: HOSTING_DEPLOY_SCOPE,
    NOUM_HOSTING_DEPLOY_PROJECT: HOSTING_PRODUCTION_PROJECT,
    NOUM_HOSTING_DEPLOY_COMMIT: commit,
    NOUM_HOSTING_DEPLOY_PUBLIC_SHA256: publicDigest,
    NOUM_HOSTING_DEPLOY_EXPIRES_AT: String(now + 10 * 60 * 1000),
    GCLOUD_PROJECT: HOSTING_PRODUCTION_PROJECT,
  };
  assert.deepEqual(validateHostingDeploymentAuthorization(environment, {
    now,
    commit,
    publicDigest,
    releaseInputsClean: true,
  }), {
    project: HOSTING_PRODUCTION_PROJECT,
    commit,
    publicDigest,
    expiresAt: now + 10 * 60 * 1000,
  });

  const invalidCases = [
    ["NOUM_HOSTING_DEPLOY_SCOPE", "all"],
    ["NOUM_HOSTING_DEPLOY_PROJECT", "lookalike-noum"],
    ["GCLOUD_PROJECT", "lookalike-noum"],
    ["NOUM_HOSTING_DEPLOY_COMMIT", "c".repeat(40)],
    ["NOUM_HOSTING_DEPLOY_PUBLIC_SHA256", "d".repeat(64)],
    ["NOUM_HOSTING_DEPLOY_EXPIRES_AT", String(now - 1)],
    ["NOUM_HOSTING_DEPLOY_EXPIRES_AT", String(now + 16 * 60 * 1000)],
  ];
  for (const [key, value] of invalidCases) {
    assert.throws(
      () => validateHostingDeploymentAuthorization(
        {...environment, [key]: value},
        {now, commit, publicDigest, releaseInputsClean: true}
      ),
      HostingDeployUnavailableError,
      key
    );
  }
  assert.throws(
    () => validateHostingDeploymentAuthorization(environment, {
      now,
      commit,
      publicDigest,
      releaseInputsClean: false,
    }),
    /committed and clean/
  );
});

test("firebase config keeps one four-page Hosting target behind its own hook", async () => {
  const firebase = JSON.parse(await readFile(
    new URL("../firebase.json", import.meta.url),
    "utf8"
  ));
  assert.equal(validateHostingConfiguration(firebase), true);
  const target = Array.isArray(firebase.hosting) ?
    firebase.hosting[0] : firebase.hosting;
  assert.deepEqual(target.predeploy, [HOSTING_DEPLOYMENT_HOOK]);
  assert.equal(
    target.predeploy.includes(
      'node "$PROJECT_DIR/scripts/release-backend-deploy.mjs"'
    ),
    false
  );

  const expanded = structuredClone(firebase);
  expanded.hosting.rewrites.push({source: "/extra", destination: "/extra.html"});
  assert.throws(
    () => validateHostingConfiguration(expanded),
    /exactly the three reviewed rewrites/
  );
});

test("wrapper deploys Hosting only with pinned tooling and mandatory readback", async () => {
  assert.equal(HOSTING_FIREBASE_TOOLS_VERSION, "15.19.1");
  const source = await readFile(
    new URL("./deploy-hosting.mjs", import.meta.url),
    "utf8"
  );
  assert.match(source, /firebase-tools@\$\{HOSTING_FIREBASE_TOOLS_VERSION\}/);
  assert.match(source, /"--only",\s*\n\s*"hosting"/);
  assert.match(source, /--non-interactive/);
  assert.match(
    source,
    /release-live-web-probe\.sh", "firebase"/
  );
  assert.doesNotMatch(source, /firebase-tools@latest/);
  assert.doesNotMatch(source, /functions:|firestore:|firestore\.rules/);
  assert.doesNotMatch(source, /--force/);
});

test("direct Hosting deploy help exposes only the checked-in wrapper", () => {
  const help = hostingDeployHelp();
  assert.match(help, /Direct Firebase Hosting deployment is intentionally unavailable/);
  assert.match(help, /deploy-hosting\.mjs --execute/);
  assert.match(help, /--confirm-project=noum-d0b6f/);
  assert.match(help, /--confirm-source=<git-commit>/);
  assert.match(help, /exact-body probe/);
});
