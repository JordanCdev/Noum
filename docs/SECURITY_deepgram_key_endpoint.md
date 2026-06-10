# Security: Deepgram key endpoint leaks an account-level API key

**Severity:** Critical (credential exposure)
**Status:** OPEN — key rotation + backend fix required
**Found:** 2026-06-10, voice-pipeline audit
**Component:** Transcription backend (AWS API Gateway, `us-east-1`) — source lives **outside this repo**
**Client touchpoint:** [`DeepgramProvider.swift`](../DeepgramProvider.swift) `fetchBackendScopedKey()`

---

## 1. Do this first — rotate the exposed key (manual, cannot be automated from here)

The currently-served Deepgram key has already been handed to unauthenticated callers, so it
**must be treated as fully compromised** regardless of any backend fix. Rotate before anything else:

1. Deepgram dashboard → the project behind Jordan's personal account (key created 2025-06-13) →
   **Settings → API Keys**.
2. **Delete / revoke** the leaked key (the `account:write` key the endpoint returns).
3. Create a new key **for server-side use only** with the minimum scope needed to _mint_ scoped keys
   (`keys:write` on the project). This becomes the backend's admin key — store it in AWS Secrets
   Manager (or SSM Parameter Store, `SecureString`). **Never** ship it in the app or commit it.
4. Confirm the old key is dead:
   ```sh
   curl -s https://api.deepgram.com/v1/auth/token \
     -H "Authorization: Token <OLD_LEAKED_KEY>"
   # expect 401 / invalid credentials
   ```
5. Check Deepgram usage for anomalies (unexpected spend / requests) during the exposure window and
   note them here.

### Rotation ordering — avoid taking an outage

Rotation is **delete-old + create-new** (Deepgram keys are immutable). The deployed backend currently
serves this one static key, so **deleting it instantly breaks transcription** for every client until
the backend serves a different key. Pick the right order:

- **Track A — zero downtime (do this if there are live users):** deploy the hardened backend first
  (section 3) so it mints fresh `usage:write` keys from a new **server-only** admin key, verify with
  `scripts/verify_deepgram_endpoint.sh`, **then** delete the old leaked `account:write` key. The
  endpoint never serves a static key again.
- **Track B — stop-the-bleed now (fine if pre-launch / no real users):** delete the leaked key in the
  dashboard immediately to kill active abuse; transcription is down until you ship Track A (or, as a
  stopgap, point the backend at a new non-account-scoped key via its secret store). If the backend
  reads its Deepgram key from an env var / Secrets Manager rather than hardcoding it, this stopgap is
  just a secret swap + redeploy — no code change.

Whichever track: the leaked key must end up **deleted**, and the replacement must **never** be
`account:write`.

Until the endpoint itself is fixed (sections 3–4), assume any key it returns is also public.

---

## 2. What's wrong

`GET {BACKEND_BASE_URL}/v1/transcribe/deepgram-key` returns a **real, static, account-level**
Deepgram key to **any caller**, with no real authentication.

- `BACKEND_BASE_URL` is `https://091pe6vtbc.execute-api.us-east-1.amazonaws.com`, read from
  [`Noum/BackendConfig.plist`](../Noum/BackendConfig.plist) and **shipped inside the app** — trivially
  extractable from the IPA.
- The only "auth" the client sends is two plain headers, `X-Noum-Account-ID` and
  `X-Noum-Auth-Provider` (see `fetchBackendScopedKey()`), both **fully spoofable**. A probe with
  `X-Noum-Account-ID: test` and nothing else returned **HTTP 200** with a working key.
- The returned key authenticates against `https://api.deepgram.com/v1/auth/token` and carries scopes
  `["account:write"]` — i.e. it is an **account-management** key, not the short-lived
  `usage:write` key the client code's own comments describe.
- `BACKEND_API_KEY` in `BackendConfig.plist` is **empty**, so the client doesn't even send the
  `X-Noum-API-Key` header today — the backend has nothing to check even if it wanted to.

**Impact:** anyone who reads the base URL out of the shipped app can mint unlimited transcription
usage on Jordan's personal Deepgram account, and an `account:write` key may allow account/project
management beyond transcription. Direct financial + account-takeover risk.

### Expected vs. actual

`DeepgramProvider.swift` already documents the intended design:

> The backend creates a scoped key via Deepgram's API:
> `POST https://api.deepgram.com/v1/keys/{projectId}` with `time_to_live_in_seconds` and limited
> scopes (e.g. `["usage:write"]`).

The deployed backend does **none** of that — it returns a static account-level key unconditionally.

---

## 3. Required backend fix

The endpoint must do three things it currently doesn't:

1. **Authenticate the caller.**
   - **Minimum / interim:** require a shared `X-Noum-API-Key` that matches a server-held secret
     (constant-time compare) **and** a non-empty `X-Noum-Account-ID` that exists in the user store.
     Note: a shared key baked into the app is also extractable, so this only raises the bar + enables
     per-key rate limiting — it is **not** real per-user auth.
   - **Strong / target:** have the client send a **verifiable** credential and verify it server-side.
     The app already uses Firebase Auth (Apple/Google → Firebase UID, see
     [`Noum/AuthManager.swift`](../Noum/AuthManager.swift)). Send the Firebase **ID token** as
     `Authorization: Bearer <idToken>` and verify it with the Firebase Admin SDK; derive the account
     ID from the verified token, not from a spoofable header.
2. **Mint a per-request, short-TTL, narrowly-scoped key** via
   `POST https://api.deepgram.com/v1/keys/{projectId}` using the **server-held admin key** (from
   section 1, in Secrets Manager). Scope `["usage:write"]`, `time_to_live_in_seconds: 1800`. Return
   only `{ apiKey, expiresAt }`. Never return a static or account-scoped key.
3. **Rate-limit + log** per account (e.g. N keys / hour), and alert on spikes.

### Reference Lambda (Node 20+, API Gateway proxy integration)

Drop-in shape for the handler behind `GET /v1/transcribe/deepgram-key`. Verify the exact
auth model against your real user store / Firebase setup before deploying.

```js
// handler.mjs
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
import { timingSafeEqual } from "node:crypto";

const sm = new SecretsManagerClient({});
let cache; // { adminKey, projectId, backendApiKey }

async function secrets() {
  if (cache) return cache;
  const out = await sm.send(new GetSecretValueCommand({ SecretId: process.env.SECRET_ID }));
  cache = JSON.parse(out.SecretString); // { adminKey, projectId, backendApiKey }
  return cache;
}

function safeEq(a, b) {
  const x = Buffer.from(String(a)), y = Buffer.from(String(b));
  return x.length === y.length && timingSafeEqual(x, y);
}

const json = (status, body) => ({
  statusCode: status,
  headers: { "content-type": "application/json", "cache-control": "no-store" },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  const { adminKey, projectId, backendApiKey } = await secrets();
  const h = event.headers ?? {};
  const get = (k) => h[k] ?? h[k.toLowerCase()];

  // 1a. Shared backend key (interim gate / rate-limit anchor)
  if (!backendApiKey || !safeEq(get("X-Noum-API-Key") ?? "", backendApiKey)) {
    return json(401, { error: "unauthorized" });
  }

  // 1b. Per-user identity — STRONG path: verify a Firebase ID token.
  //     Replace the placeholder below with real verification before trusting accountId.
  //     e.g. const decoded = await getAuth().verifyIdToken(bearer); accountId = decoded.uid;
  const accountId = get("X-Noum-Account-ID");
  if (!accountId /* || !(await userExists(accountId)) */) {
    return json(401, { error: "unauthorized" });
  }

  // 2. (Optional) per-account rate limit check here → 429 on exceed.

  // 3. Mint a short-TTL, usage-scoped key.
  const ttl = 1800; // 30 min
  const res = await fetch(`https://api.deepgram.com/v1/keys/${projectId}`, {
    method: "POST",
    headers: { authorization: `Token ${adminKey}`, "content-type": "application/json" },
    body: JSON.stringify({
      comment: `noum-client ${accountId}`,
      scopes: ["usage:write"],
      time_to_live_in_seconds: ttl,
    }),
  });
  if (!res.ok) {
    return json(502, { error: "key_mint_failed" });
  }
  const { key } = await res.json(); // Deepgram returns the secret key once, here.
  const expiresAt = new Date(Date.now() + ttl * 1000).toISOString();

  return json(200, { apiKey: key, expiresAt });
};
```

Notes:
- The admin key never leaves the server; only short-TTL `usage:write` keys reach the client.
- `usage:write` keys can stream transcription but cannot manage the account or other keys.
- Keep API Gateway throttling on top of per-account limits.

---

## 4. Paired client change (ready to apply, not yet committed)

The shipped client must actually send what the hardened backend checks. Two parts:

1. **Supply the backend API key without committing a secret.** `BACKEND_API_KEY` in
   `BackendConfig.plist` is empty and `BackendConfig.plist` is tracked in git, so do **not** paste a
   key there. Inject it at build time (xcconfig / CI secret → Info.plist) or via the
   `BACKEND_API_KEY` env var the code already reads first in `fetchBackendScopedKey()`. Keep the
   plist value empty in git.
2. **(Target path) send a verifiable token.** Add an `Authorization: Bearer <firebaseIdToken>`
   header in `fetchBackendScopedKey()` using `Auth.auth().currentUser?.getIDToken()`, and have the
   backend derive the account ID from the verified token. The current `X-Noum-Account-ID` /
   `X-Noum-Auth-Provider` headers can stay as a transition aid but must not be trusted for auth.

Neither change was committed here because it can't be verified end-to-end without the hardened
backend deployed. Apply alongside the backend deploy and test the full path.

---

## 5. Verification (after fix)

1. Old key revoked — `auth/token` probe with the old key returns 401 (section 1, step 4).
2. Unauthenticated probe rejected:
   ```sh
   curl -i "$BACKEND_BASE_URL/v1/transcribe/deepgram-key" -H "X-Noum-Account-ID: test"
   # expect 401, no apiKey in body
   ```
3. Authenticated probe (valid backend key + valid identity) returns a key whose
   `auth/token` scopes are exactly `["usage:write"]` and which **expires** (`expiresAt` ~30 min out,
   stops working after TTL).
4. The returned key **cannot** hit account-management endpoints (e.g. listing/creating keys → 403).
5. Real app records a transcription session end-to-end with a freshly minted key.

Steps 1–4 are automated by [`scripts/verify_deepgram_endpoint.sh`](../scripts/verify_deepgram_endpoint.sh)
(read-only, never prints secret material). Run it before the fix to confirm the leak, and after to
confirm closure.

---

## 6. Why this happened / guardrails

- A static account-level key behind an unauthenticated endpoint is the failure mode the client
  comments were specifically written to avoid — the backend was never brought up to that spec.
- Add a CI/secret-scan check so account-scoped Deepgram keys never sit in a place the client can
  reach, and a synthetic monitor that fails if the endpoint returns 200 to an unauthenticated probe.
