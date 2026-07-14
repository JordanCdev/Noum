import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

import {
  BackendDeployUnavailableError,
  DEPLOYMENT_BLOCKERS,
  PRODUCTION_RUNBOOK,
  backendDeployHelp,
  backendDeployRefusal,
  parseBackendDeployArguments,
} from "./release-backend-deploy.mjs";

const EXPECTED_BLOCKERS = [
  "Trusted server-observed competitive evidence producer and deterministic " +
    "evaluator are missing; implement and verify them before deployment.",
  "Reciprocal friendship authority is missing; implement and verify it " +
    "before deployment.",
  "Independently trusted deployment authorization evidence is missing; " +
    "obtain and verify it before deployment.",
  "An immutable source-bound deployment artifact is missing; build and " +
    "verify it before deployment.",
];

test("the exact actionable blocker roster is stable", () => {
  assert.deepEqual([...DEPLOYMENT_BLOCKERS], EXPECTED_BLOCKERS);
  const refusal = backendDeployRefusal();
  for (const blocker of EXPECTED_BLOCKERS) {
    assert.equal(refusal.includes(`- ${blocker}`), true);
  }
  assert.match(refusal, new RegExp(PRODUCTION_RUNBOOK));
});

test("help states deployment is intentionally unavailable", () => {
  assert.deepEqual(parseBackendDeployArguments(["--help"]), {help: true});
  assert.match(backendDeployHelp(), /deployment is intentionally unavailable/i);
  assert.match(backendDeployHelp(), /does not currently expose an authorization or execute path/);
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
        /no execute path/.test(error.message),
      args.join(" ")
    );
  }
});

test("blocker source contains no process, network, or file-read primitive", async () => {
  const source = await readFile(
    new URL("./release-backend-deploy.mjs", import.meta.url),
    "utf8"
  );
  for (const forbidden of [
    "node:child_process",
    "execFile",
    "spawn(",
    "fetch(",
    "node:http",
    "node:https",
    "npx",
    "firebase",
    "git status",
    "readFile",
    "authorization=",
    "--execute",
  ]) {
    assert.equal(source.includes(forbidden), false, forbidden);
  }
  assert.doesNotMatch(source, /^import\s/m);
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
  assert.match(
    packageJSON.scripts.test,
    /node --test \.\.\/scripts\/release-backend-deploy\.test\.mjs/
  );
  assert.doesNotMatch(packageJSON.scripts.deploy, /firebase|npx|--execute/);
});
