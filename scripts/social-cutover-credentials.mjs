import {execFile} from "node:child_process";

export const SocialCutoverCredentialMode = Object.freeze({
  applicationDefault: "application-default",
  gcloudUser: "gcloud-user",
  emulatorOnly: "emulator-only",
});

export const SOCIAL_CUTOVER_EMULATOR_PROJECT_ID = "demo-noum";
export const SOCIAL_CUTOVER_EMULATOR_OPT_IN =
  "NOUM_SOCIAL_CUTOVER_EMULATOR";

const exactFlags = new Set([
  "--help",
  "--apply",
  "--purge-legacy-social",
  "--gcloud-user-credentials",
  "--emulator-only",
]);
const valueFlags = [
  "--project=",
  "--confirm-project=",
  "--approve-purge=",
];

function hasFlag(args, name) {
  return args.includes(name);
}

function valueFor(args, name) {
  return args
    .find((argument) => argument.startsWith(`${name}=`))
    ?.slice(name.length + 1);
}

function isLoopbackFirestoreEmulatorHost(value) {
  if (typeof value !== "string" || value !== value.trim()) return false;
  const match = /^(localhost|127\.0\.0\.1|\[::1\]):([0-9]{1,5})$/i.exec(value);
  if (!match) return false;
  const port = Number(match[2]);
  return Number.isInteger(port) && port >= 1 && port <= 65_535;
}

export function validateSocialCutoverRuntime({
  credentialMode,
  projectID,
  env = process.env,
}) {
  const emulatorHost = env.FIRESTORE_EMULATOR_HOST;
  const emulatorOptIn = env[SOCIAL_CUTOVER_EMULATOR_OPT_IN];
  if (credentialMode === SocialCutoverCredentialMode.emulatorOnly) {
    if (projectID !== SOCIAL_CUTOVER_EMULATOR_PROJECT_ID) {
      throw new Error(
        `--emulator-only requires --project=${SOCIAL_CUTOVER_EMULATOR_PROJECT_ID}.`
      );
    }
    if (emulatorOptIn !== "1") {
      throw new Error(
        `--emulator-only requires ${SOCIAL_CUTOVER_EMULATOR_OPT_IN}=1.`
      );
    }
    if (!isLoopbackFirestoreEmulatorHost(emulatorHost)) {
      throw new Error(
        "--emulator-only requires a loopback FIRESTORE_EMULATOR_HOST."
      );
    }
    return;
  }

  if (emulatorHost !== undefined) {
    throw new Error(
      "FIRESTORE_EMULATOR_HOST requires the explicit --emulator-only mode."
    );
  }
  if (emulatorOptIn !== undefined) {
    throw new Error(
      `${SOCIAL_CUTOVER_EMULATOR_OPT_IN} requires --emulator-only.`
    );
  }
}

export function parseSocialCutoverOptions(args, env = process.env) {
  const unknownArgument = args.find((argument) =>
    !exactFlags.has(argument) &&
    !valueFlags.some((prefix) => argument.startsWith(prefix))
  );
  if (unknownArgument) {
    throw new Error(`Unknown argument: ${unknownArgument}`);
  }

  const help = hasFlag(args, "--help");
  if (help) return {help};

  const projectID = valueFor(args, "--project") ?? env.GCLOUD_PROJECT;
  const apply = hasFlag(args, "--apply");
  const purgeLegacySocial = hasFlag(args, "--purge-legacy-social");
  const confirmedProject = valueFor(args, "--confirm-project");
  const purgeApproval = valueFor(args, "--approve-purge");
  const usesGcloudUserCredentials = hasFlag(
    args,
    "--gcloud-user-credentials"
  );
  const usesEmulatorOnly = hasFlag(args, "--emulator-only");

  if (!projectID) throw new Error("Pass --project=PROJECT_ID.");

  if (usesGcloudUserCredentials && usesEmulatorOnly) {
    throw new Error(
      "--gcloud-user-credentials and --emulator-only cannot be combined."
    );
  }

  if (usesGcloudUserCredentials &&
      (apply || purgeLegacySocial || purgeApproval !== undefined)) {
    throw new Error(
      "gcloud user credentials are restricted to remote-read-only " +
      "inventory. --apply and all purge options require " +
      "application-default credentials."
    );
  }
  if (apply && confirmedProject !== projectID) {
    throw new Error("--apply requires --confirm-project to match --project.");
  }
  if (purgeLegacySocial && !apply) {
    throw new Error("Legacy purge requires --apply.");
  }
  if (purgeLegacySocial && purgeApproval !== "DELETE_LEGACY_SOCIAL") {
    throw new Error(
      "Legacy purge requires --approve-purge=DELETE_LEGACY_SOCIAL."
    );
  }

  const credentialMode = usesEmulatorOnly ?
    SocialCutoverCredentialMode.emulatorOnly :
    usesGcloudUserCredentials ?
      SocialCutoverCredentialMode.gcloudUser :
      SocialCutoverCredentialMode.applicationDefault;
  validateSocialCutoverRuntime({credentialMode, projectID, env});

  return {
    help: false,
    projectID,
    apply,
    purgeLegacySocial,
    confirmedProject,
    purgeApproval,
    credentialMode,
  };
}

function execFilePromise(command, args, options) {
  return new Promise((resolve, reject) => {
    execFile(command, args, options, (error, stdout, stderr) => {
      if (error) {
        reject(error);
        return;
      }
      resolve({stdout, stderr});
    });
  });
}

function validatedAccessToken(value) {
  const token = typeof value === "string" ? value.trim() : "";
  if (token.length < 20 || token.length > 8_192 || /\s/.test(token)) {
    throw new Error("gcloud returned an invalid access token.");
  }
  return token;
}

const safeCredentialError = () => new Error(
  "Unable to obtain a gcloud user access token. Confirm that gcloud has " +
  "an active identity with read access to the requested project."
);

export async function loadGcloudUserAccessToken({
  run = execFilePromise,
  env = process.env,
} = {}) {
  try {
    const result = await run(
      "gcloud",
      ["auth", "print-access-token", "--quiet"],
      {
        env: {...env, CLOUDSDK_CORE_DISABLE_PROMPTS: "1"},
        encoding: "utf8",
        maxBuffer: 64 * 1_024,
        timeout: 20_000,
      }
    );
    return validatedAccessToken(result?.stdout);
  } catch {
    // Never include command output or the original error: either can contain
    // the credential we are explicitly protecting from logs.
    throw safeCredentialError();
  }
}

export function createGcloudUserCredential({
  loadToken = () => loadGcloudUserAccessToken(),
} = {}) {
  let refreshInFlight;

  return {
    async getAccessToken() {
      if (!refreshInFlight) {
        refreshInFlight = Promise.resolve()
          .then(loadToken)
          .then((token) => ({
            access_token: validatedAccessToken(token),
            // Deliberately short: the auth client will ask again during a long
            // inventory rather than assuming the opaque gcloud token's age.
            expires_in: 60,
          }))
          .catch(() => {
            throw safeCredentialError();
          })
          .finally(() => {
            refreshInFlight = undefined;
          });
      }
      return refreshInFlight;
    },
  };
}

export function createGcloudUserAuthClient({
  credential = createGcloudUserCredential(),
  now = () => Date.now(),
  projectID,
} = {}) {
  let cachedToken;

  async function accessToken() {
    const currentTime = now();
    if (cachedToken && currentTime < cachedToken.refreshAfter) {
      return cachedToken.value;
    }

    const token = await credential.getAccessToken();
    const value = validatedAccessToken(token?.access_token);
    cachedToken = {
      value,
      // Reuse only the first half of the conservative 60-second lifetime.
      refreshAfter: currentTime + Math.min(token.expires_in * 500, 30_000),
    };
    return value;
  }

  return {
    projectId: projectID,
    universeDomain: "googleapis.com",
    async getAccessToken() {
      return {token: await accessToken()};
    },
    async getRequestHeaders() {
      return {Authorization: `Bearer ${await accessToken()}`};
    },
    async getProjectId() {
      return projectID;
    },
  };
}
