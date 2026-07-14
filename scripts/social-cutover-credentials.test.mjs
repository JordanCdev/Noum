import assert from "node:assert/strict";
import test from "node:test";

import {
  createGcloudUserAuthClient,
  createGcloudUserCredential,
  loadGcloudUserAccessToken,
  parseSocialCutoverOptions,
  SOCIAL_CUTOVER_EMULATOR_OPT_IN,
  SocialCutoverCredentialMode,
} from "./social-cutover-credentials.mjs";

const TOKEN_ONE = "ya29.test-token-one-1234567890";
const TOKEN_TWO = "ya29.test-token-two-0987654321";

test("application-default remains the default credential mode", () => {
  const options = parseSocialCutoverOptions(["--project=noum-d0b6f"]);

  assert.equal(
    options.credentialMode,
    SocialCutoverCredentialMode.applicationDefault
  );
  assert.equal(options.apply, false);
});

test("gcloud user credentials are accepted for read-only inventory", () => {
  const options = parseSocialCutoverOptions([
    "--project=noum-d0b6f",
    "--gcloud-user-credentials",
  ]);

  assert.equal(options.credentialMode, SocialCutoverCredentialMode.gcloudUser);
  assert.equal(options.apply, false);
  assert.equal(options.purgeLegacySocial, false);
});

test("explicit emulator mode pins demo-noum and loopback without ADC", () => {
  for (const emulatorHost of [
    "localhost:8080",
    "127.0.0.1:8080",
    "[::1]:8080",
  ]) {
    const options = parseSocialCutoverOptions([
      "--project=demo-noum",
      "--emulator-only",
      "--apply",
      "--confirm-project=demo-noum",
    ], {
      FIRESTORE_EMULATOR_HOST: emulatorHost,
      [SOCIAL_CUTOVER_EMULATOR_OPT_IN]: "1",
    });
    assert.equal(
      options.credentialMode,
      SocialCutoverCredentialMode.emulatorOnly
    );
    assert.equal(options.projectID, "demo-noum");
    assert.equal(options.apply, true);
  }
});

test("emulator mode rejects production, non-loopback, and missing opt-in", () => {
  const baseArguments = ["--project=demo-noum", "--emulator-only"];
  assert.throws(
    () => parseSocialCutoverOptions([
      "--project=noum-d0b6f",
      "--emulator-only",
    ], {
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
      [SOCIAL_CUTOVER_EMULATOR_OPT_IN]: "1",
    }),
    /requires --project=demo-noum/
  );
  assert.throws(
    () => parseSocialCutoverOptions(baseArguments, {
      FIRESTORE_EMULATOR_HOST: "0.0.0.0:8080",
      [SOCIAL_CUTOVER_EMULATOR_OPT_IN]: "1",
    }),
    /loopback FIRESTORE_EMULATOR_HOST/
  );
  assert.throws(
    () => parseSocialCutoverOptions(baseArguments, {
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
    }),
    new RegExp(`${SOCIAL_CUTOVER_EMULATOR_OPT_IN}=1`)
  );
});

test("ambient emulator routing is refused without the explicit mode", () => {
  assert.throws(
    () => parseSocialCutoverOptions(["--project=noum-d0b6f"], {
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
    }),
    /requires the explicit --emulator-only mode/
  );
  assert.throws(
    () => parseSocialCutoverOptions(["--project=noum-d0b6f"], {
      [SOCIAL_CUTOVER_EMULATOR_OPT_IN]: "1",
    }),
    /requires --emulator-only/
  );
});

test("emulator mode cannot acquire gcloud user credentials", () => {
  assert.throws(
    () => parseSocialCutoverOptions([
      "--project=demo-noum",
      "--emulator-only",
      "--gcloud-user-credentials",
    ], {
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
      [SOCIAL_CUTOVER_EMULATOR_OPT_IN]: "1",
    }),
    /cannot be combined/
  );
});

test("gcloud user credentials refuse apply before credential acquisition", () => {
  assert.throws(
    () => parseSocialCutoverOptions([
      "--project=noum-d0b6f",
      "--gcloud-user-credentials",
      "--apply",
      "--confirm-project=noum-d0b6f",
    ]),
    /restricted to remote-read-only inventory/
  );
});

test("gcloud user credentials refuse every purge spelling", () => {
  for (const purgeArgument of [
    "--purge-legacy-social",
    "--approve-purge=DELETE_LEGACY_SOCIAL",
  ]) {
    assert.throws(
      () => parseSocialCutoverOptions([
        "--project=noum-d0b6f",
        "--gcloud-user-credentials",
        purgeArgument,
      ]),
      /all purge options require application-default credentials/
    );
  }
});

test("application-default apply retains exact project confirmation", () => {
  assert.throws(
    () => parseSocialCutoverOptions([
      "--project=noum-d0b6f",
      "--apply",
    ]),
    /requires --confirm-project to match --project/
  );

  const options = parseSocialCutoverOptions([
    "--project=noum-d0b6f",
    "--apply",
    "--confirm-project=noum-d0b6f",
  ]);
  assert.equal(options.apply, true);
  assert.equal(
    options.credentialMode,
    SocialCutoverCredentialMode.applicationDefault
  );
});

test("unknown arguments fail closed", () => {
  assert.throws(
    () => parseSocialCutoverOptions([
      "--project=noum-d0b6f",
      "--gcloud-user-credential",
    ]),
    /Unknown argument/
  );
});

test("gcloud token command is noninteractive and returns only the token", async () => {
  let invocation;
  const token = await loadGcloudUserAccessToken({
    env: {PATH: "/test/bin"},
    run: async (...args) => {
      invocation = args;
      return {stdout: `${TOKEN_ONE}\n`, stderr: ""};
    },
  });

  assert.equal(token, TOKEN_ONE);
  assert.deepEqual(invocation.slice(0, 2), [
    "gcloud",
    ["auth", "print-access-token", "--quiet"],
  ]);
  assert.equal(invocation[2].env.CLOUDSDK_CORE_DISABLE_PROMPTS, "1");
  assert.equal(invocation[2].encoding, "utf8");
  assert.equal(invocation[2].timeout, 20_000);
});

test("gcloud command failure never exposes command output or token", async () => {
  await assert.rejects(
    loadGcloudUserAccessToken({
      run: async () => {
        const error = new Error(`provider rejected ${TOKEN_ONE}`);
        error.stdout = TOKEN_ONE;
        error.stderr = `Bearer ${TOKEN_ONE}`;
        throw error;
      },
    }),
    (error) => {
      assert.match(error.message, /Unable to obtain a gcloud user access token/);
      assert.doesNotMatch(error.message, /ya29|Bearer|provider rejected/);
      return true;
    }
  );
});

test("malformed token output is rejected without echoing it", async () => {
  const malformed = `short token ${TOKEN_ONE}`;
  await assert.rejects(
    loadGcloudUserAccessToken({
      run: async () => ({stdout: malformed, stderr: ""}),
    }),
    (error) => {
      assert.doesNotMatch(error.message, /short token|ya29/);
      return true;
    }
  );
});

test("credential coalesces concurrent refresh and refreshes later calls", async () => {
  const tokens = [TOKEN_ONE, TOKEN_TWO];
  let calls = 0;
  let releaseFirst;
  const firstRefresh = new Promise((resolve) => {
    releaseFirst = resolve;
  });
  const credential = createGcloudUserCredential({
    loadToken: async () => {
      const index = calls++;
      if (index === 0) await firstRefresh;
      return tokens[index];
    },
  });

  const first = credential.getAccessToken();
  const concurrent = credential.getAccessToken();
  releaseFirst();
  assert.deepEqual(await first, {
    access_token: TOKEN_ONE,
    expires_in: 60,
  });
  assert.deepEqual(await concurrent, {
    access_token: TOKEN_ONE,
    expires_in: 60,
  });
  assert.equal(calls, 1);

  assert.deepEqual(await credential.getAccessToken(), {
    access_token: TOKEN_TWO,
    expires_in: 60,
  });
  assert.equal(calls, 2);
});

test("credential refresh failure does not expose loader secrets", async () => {
  const credential = createGcloudUserCredential({
    loadToken: async () => {
      throw new Error(TOKEN_ONE);
    },
  });

  await assert.rejects(credential.getAccessToken(), (error) => {
    assert.doesNotMatch(error.message, /ya29/);
    return true;
  });
});

test("auth client reuses briefly then refreshes the opaque token", async () => {
  let currentTime = 1_000;
  let calls = 0;
  const credential = {
    async getAccessToken() {
      calls += 1;
      return {
        access_token: calls === 1 ? TOKEN_ONE : TOKEN_TWO,
        expires_in: 60,
      };
    },
  };
  const authClient = createGcloudUserAuthClient({
    credential,
    now: () => currentTime,
    projectID: "noum-d0b6f",
  });

  assert.deepEqual(await authClient.getAccessToken(), {token: TOKEN_ONE});
  assert.deepEqual(await authClient.getRequestHeaders(), {
    Authorization: `Bearer ${TOKEN_ONE}`,
  });
  assert.equal(calls, 1);

  currentTime += 30_001;
  assert.deepEqual(await authClient.getRequestHeaders(), {
    Authorization: `Bearer ${TOKEN_TWO}`,
  });
  assert.equal(calls, 2);
  assert.equal(await authClient.getProjectId(), "noum-d0b6f");
});
