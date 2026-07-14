import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {mkdir, mkdtemp, readFile, rm, unlink, writeFile} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join, resolve} from "node:path";
import test from "node:test";

import {
  BackendDeployError,
  backendDeployUsage,
  COORDINATED_DEPLOY_TARGET,
  FIREBASE_TOOLS_VERSION,
  PRODUCTION_PROJECT_ID,
  REQUIRED_EVIDENCE_ATTACHMENTS,
  runBackendDeploy,
  validateBackendDeployAuthorization,
  validateTrustedEvidenceProducerRoster,
} from "./release-backend-deploy.mjs";

const COMMIT = "a".repeat(40);
const NOW_MS = Date.parse("2026-07-14T15:00:00.000Z");
const PRODUCER_SOURCE = `
const EVIDENCE_RUNTIME_SERVICE_ACCOUNT =
  "noum-evidence-runtime@noum-d0b6f.iam.gserviceaccount.com";

export const verifySessionEvidence = onCall(
  {
    enforceAppCheck: true,
    serviceAccount: EVIDENCE_RUNTIME_SERVICE_ACCOUNT,
  },
  async (request) => {
    assertTrustedCaller(request.auth, request.app);
    return {verified: true};
  }
);
`;
const CLOUD_CONTRACT_SOURCE = `
RUNTIME_IDENTITIES = {
    "EVIDENCE_RUNTIME_SERVICE_ACCOUNT": "noum-evidence-runtime",
}
EXPECTED_CALLABLES = {
    "verifySessionEvidence": "EVIDENCE_RUNTIME_SERVICE_ACCOUNT",
}
`;

function digest(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "noum-backend-deploy-test-"));
  await mkdir(join(root, "functions/src"), {recursive: true});
  await mkdir(join(root, "scripts"), {recursive: true});
  await writeFile(join(root, "functions/src/index.ts"), PRODUCER_SOURCE);
  await writeFile(
    join(root, "scripts/release_cloud_operations_validator.py"),
    CLOUD_CONTRACT_SOURCE
  );
  const attachments = {};
  for (const [index, name] of REQUIRED_EVIDENCE_ATTACHMENTS.entries()) {
    const bytes = Buffer.from(`reviewed-${name}-${index}`);
    const path = join(root, `${name}.json`);
    await writeFile(path, bytes);
    attachments[name] = {path, sha256: digest(bytes)};
  }
  const authorization = {
    schemaVersion: 1,
    projectID: PRODUCTION_PROJECT_ID,
    sourceGitCommit: COMMIT,
    socialCutoverRunID: "release-2026-07-14",
    backupDigest: "b".repeat(64),
    issuedAt: "2026-07-14T14:45:00.000Z",
    expiresAt: "2026-07-14T15:15:00.000Z",
    target: COORDINATED_DEPLOY_TARGET,
    attachments,
  };
  const authorizationPath = join(root, "authorization.json");
  const saveAuthorization = async () => {
    await writeFile(authorizationPath, `${JSON.stringify(authorization)}\n`);
  };
  await saveAuthorization();
  return {
    root,
    attachments,
    authorization,
    authorizationPath,
    saveAuthorization,
    async close() {
      await rm(root, {recursive: true, force: true});
    },
  };
}

function commandHarness({commit = COMMIT, staticError = null} = {}) {
  const calls = [];
  const executeFile = async (command, args, options) => {
    calls.push({command, args: [...args], options});
    if (command === "git" && args[0] === "status") return {stdout: ""};
    if (command === "git" && args[0] === "rev-parse") {
      return {stdout: `${commit}\n`};
    }
    if (command.endsWith("/scripts/release-static-readiness.sh")) {
      if (staticError) throw staticError;
      return {stdout: "Operational static readiness passed.\n"};
    }
    if (command === "npx") return {stdout: "firebase invocation intercepted\n"};
    throw new Error(`Unexpected command ${command}`);
  };
  return {calls, executeFile};
}

async function runFixture(current, harness, execute = false) {
  return runBackendDeploy([
    `--authorization=${current.authorizationPath}`,
    ...(execute ? ["--execute"] : []),
  ], {
    repoRoot: current.root,
    now: () => NOW_MS,
    executeFile: harness.executeFile,
  });
}

test("current source remains closed without the trusted evidence producer", async () => {
  const repoRoot = resolve(new URL("..", import.meta.url).pathname);
  const [functionsSource, cloudSource] = await Promise.all([
    readFile(join(repoRoot, "functions/src/index.ts"), "utf8"),
    readFile(join(repoRoot, "scripts/release_cloud_operations_validator.py"), "utf8"),
  ]);
  assert.throws(
    () => validateTrustedEvidenceProducerRoster(functionsSource, cloudSource),
    /verifySessionEvidence producer is missing/
  );
});

test("trusted producer requires source and cloud roster identity binding", () => {
  assert.equal(
    validateTrustedEvidenceProducerRoster(PRODUCER_SOURCE, CLOUD_CONTRACT_SOURCE),
    true
  );
  assert.throws(
    () => validateTrustedEvidenceProducerRoster(
      PRODUCER_SOURCE.replace(
        "EVIDENCE_RUNTIME_SERVICE_ACCOUNT",
        "SOCIAL_RUNTIME_SERVICE_ACCOUNT"
      ),
      CLOUD_CONTRACT_SOURCE
    ),
    /dedicated runtime identity/
  );
  assert.throws(
    () => validateTrustedEvidenceProducerRoster(
      PRODUCER_SOURCE,
      CLOUD_CONTRACT_SOURCE.replace("verifySessionEvidence", "recordPeerSession")
    ),
    /Cloud operations roster/
  );
});

test("producer roster validator matches the real Python mapping structure", async () => {
  const repoRoot = resolve(new URL("..", import.meta.url).pathname);
  const [currentFunctions, currentCloud] = await Promise.all([
    readFile(join(repoRoot, "functions/src/index.ts"), "utf8"),
    readFile(join(repoRoot, "scripts/release_cloud_operations_validator.py"), "utf8"),
  ]);
  const futureFunctions = currentFunctions
    .replace(
      "const SOCIAL_RUNTIME_SERVICE_ACCOUNT =",
      "const EVIDENCE_RUNTIME_SERVICE_ACCOUNT =\n" +
      "  \"noum-evidence-runtime@noum-d0b6f.iam.gserviceaccount.com\";\n" +
      "const SOCIAL_RUNTIME_SERVICE_ACCOUNT ="
    ) + `\n${PRODUCER_SOURCE}`;
  const futureCloud = currentCloud
    .replace(
      '    "SOCIAL_RUNTIME_SERVICE_ACCOUNT": "noum-social-runtime",',
      '    "SOCIAL_RUNTIME_SERVICE_ACCOUNT": "noum-social-runtime",\n' +
      '    "EVIDENCE_RUNTIME_SERVICE_ACCOUNT": "noum-evidence-runtime",'
    )
    .replace(
      '    "deleteAccount": "ACCOUNT_RUNTIME_SERVICE_ACCOUNT",',
      '    "deleteAccount": "ACCOUNT_RUNTIME_SERVICE_ACCOUNT",\n' +
      '    "verifySessionEvidence": "EVIDENCE_RUNTIME_SERVICE_ACCOUNT",'
    );
  assert.equal(
    validateTrustedEvidenceProducerRoster(futureFunctions, futureCloud),
    true
  );
});

test("usage has no patch-marker prefix", () => {
  assert.match(backendDeployUsage(), /\n    --authorization=/);
  assert.doesNotMatch(backendDeployUsage(), /\n\+    --authorization=/);
});

function authorizationFixture(overrides = {}) {
  return {
    schemaVersion: 1,
    projectID: PRODUCTION_PROJECT_ID,
    sourceGitCommit: COMMIT,
    socialCutoverRunID: "run-1",
    backupDigest: "b".repeat(64),
    issuedAt: "2026-07-14T14:45:00.000Z",
    expiresAt: "2026-07-14T15:15:00.000Z",
    target: COORDINATED_DEPLOY_TARGET,
    attachments: Object.fromEntries(REQUIRED_EVIDENCE_ATTACHMENTS.map((name) => [
      name,
      {path: `${name}.json`, sha256: "c".repeat(64)},
    ])),
    ...overrides,
  };
}

function validateAuthorization(value) {
  return validateBackendDeployAuthorization(value, {
    currentCommit: COMMIT,
    nowMs: NOW_MS,
    authorizationDirectory: "/evidence",
  });
}

test("authorization rejects wrong project, commit, target, and extra keys", () => {
  assert.throws(
    () => validateAuthorization(authorizationFixture({projectID: "demo-noum"})),
    /project/
  );
  assert.throws(
    () => validateAuthorization(authorizationFixture({
      sourceGitCommit: "d".repeat(40),
    })),
    /current Git/
  );
  assert.throws(
    () => validateAuthorization(authorizationFixture({target: "functions"})),
    /target/
  );
  assert.throws(
    () => validateAuthorization(authorizationFixture({unreviewed: true})),
    /exact reviewed keys/
  );
  const extraAttachment = authorizationFixture();
  extraAttachment.attachments[REQUIRED_EVIDENCE_ATTACHMENTS[0]].note = "trust me";
  assert.throws(
    () => validateAuthorization(extraAttachment),
    /exact reviewed keys/
  );
  const duplicateAttachment = authorizationFixture();
  const [first, second] = REQUIRED_EVIDENCE_ATTACHMENTS;
  duplicateAttachment.attachments[second].path =
    duplicateAttachment.attachments[first].path;
  assert.throws(
    () => validateAuthorization(duplicateAttachment),
    /distinct file/
  );
});

test("authorization rejects expired, future, and overlong windows", () => {
  assert.throws(
    () => validateAuthorization(authorizationFixture({
      expiresAt: "2026-07-14T15:00:00.000Z",
    })),
    /stale, premature, or exceeds/
  );
  assert.throws(
    () => validateAuthorization(authorizationFixture({
      issuedAt: "2026-07-14T15:00:01.000Z",
    })),
    /stale, premature, or exceeds/
  );
  assert.throws(
    () => validateAuthorization(authorizationFixture({
      issuedAt: "2026-07-14T14:00:00.000Z",
    })),
    /stale, premature, or exceeds/
  );
});

test("missing and tampered evidence attachments fail before static readiness", async () => {
  const current = await fixture();
  try {
    const name = REQUIRED_EVIDENCE_ATTACHMENTS[0];
    await writeFile(current.attachments[name].path, "tampered");
    let harness = commandHarness();
    await assert.rejects(runFixture(current, harness), /digest does not match/);
    assert.equal(
      harness.calls.some((call) =>
        call.command.endsWith("release-static-readiness.sh")
      ),
      false
    );

    await writeFile(
      current.attachments[name].path,
      Buffer.from(`reviewed-${name}-0`)
    );
    await current.saveAuthorization();
    const missingName = REQUIRED_EVIDENCE_ATTACHMENTS[1];
    await unlink(current.attachments[missingName].path);
    harness = commandHarness();
    await assert.rejects(runFixture(current, harness), /Unable to read regular file/);
    assert.equal(harness.calls.some((call) => call.command === "npx"), false);
  } finally {
    await current.close();
  }
});

test("preflight without execute runs static readiness but never Firebase", async () => {
  const current = await fixture();
  try {
    const harness = commandHarness();
    const result = await runFixture(current, harness, false);
    assert.equal(result.mode, "preflight");
    assert.equal(result.projectID, PRODUCTION_PROJECT_ID);
    assert.equal(
      harness.calls.filter((call) =>
        call.command.endsWith("release-static-readiness.sh")
      ).length,
      1
    );
    assert.equal(harness.calls.some((call) => call.command === "npx"), false);
  } finally {
    await current.close();
  }
});

test("static-readiness failure refuses execute before Firebase", async () => {
  const current = await fixture();
  try {
    const harness = commandHarness({staticError: new Error("static failed")});
    await assert.rejects(runFixture(current, harness, true), /static failed/);
    assert.equal(harness.calls.some((call) => call.command === "npx"), false);
  } finally {
    await current.close();
  }
});

test("execute revalidates evidence and emits only the exact Firebase argv", async () => {
  const current = await fixture();
  try {
    const harness = commandHarness();
    const result = await runFixture(current, harness, true);
    assert.equal(result.mode, "execute");
    const firebaseCalls = harness.calls.filter((call) => call.command === "npx");
    assert.equal(firebaseCalls.length, 1);
    assert.deepEqual(firebaseCalls[0].args, [
      "--yes",
      `firebase-tools@${FIREBASE_TOOLS_VERSION}`,
      "deploy",
      "--only",
      "functions,firestore:rules",
      "--project",
      "noum-d0b6f",
      "--non-interactive",
    ]);
    assert.equal(firebaseCalls[0].options.cwd, current.root);
    assert.equal(
      harness.calls.filter((call) =>
        call.command === "git" && call.args[0] === "status"
      ).length,
      2
    );
  } finally {
    await current.close();
  }
});

test("tracked source drift after static readiness fails closed", async () => {
  const current = await fixture();
  try {
    let statusCalls = 0;
    const base = commandHarness();
    const executeFile = async (command, args, options) => {
      if (command === "git" && args[0] === "status") {
        statusCalls += 1;
        return {stdout: statusCalls === 1 ? "" : " M functions/src/index.ts\n"};
      }
      return base.executeFile(command, args, options);
    };
    await assert.rejects(runBackendDeploy([
      `--authorization=${current.authorizationPath}`,
      "--execute",
    ], {
      repoRoot: current.root,
      now: () => NOW_MS,
      executeFile,
    }), /clean tracked source/);
    assert.equal(base.calls.some((call) => call.command === "npx"), false);
  } finally {
    await current.close();
  }
});

test("functions deploy script routes only through the release wrapper", async () => {
  const packageJSON = JSON.parse(await readFile(
    new URL("../functions/package.json", import.meta.url),
    "utf8"
  ));
  assert.equal(
    packageJSON.scripts.deploy,
    "node ../scripts/release-backend-deploy.mjs"
  );
  assert.doesNotMatch(packageJSON.scripts.deploy, /firebase\s+deploy/);
});

test("missing authorization is refused before any command can run", async () => {
  let invoked = false;
  await assert.rejects(
    runBackendDeploy([], {executeFile: async () => { invoked = true; }}),
    (error) => error instanceof BackendDeployError &&
      /authorization/.test(error.message)
  );
  assert.equal(invoked, false);
});
