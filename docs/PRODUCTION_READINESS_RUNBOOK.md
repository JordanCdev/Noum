# Noum Production Readiness Runbook

Source of truth: `docs/VISION.md`.

This runbook is for the M14 launch gate: Firestore rules, hosted privacy URL,
TestFlight, and proof that Chat with Noum is ready for production use. A green
local eval or smoke flow is evidence, but it is not enough to claim production
readiness.

## Current Recovery Status (2026-07-11)

**Release verdict: NO-GO for external TestFlight or App Store release.**

- The production transcription route now exists: the iOS release path calls
  the authenticated, App Check-enforced Firebase `transcriptionToken` callable,
  which rate-limits by Firebase UID and returns short-lived Deepgram access from
  a server-only Secret Manager credential. This is a configured production
  boundary, not proof that real-device recording succeeds.
- The historical Deepgram/AWS credential incident in
  `docs/SECURITY_deepgram_key_endpoint.md` remains open. The replacement path
  does not revoke the exposed legacy credentials, disable every legacy route,
  or provide the missing usage and billing audit.
- `https://noum-d0b6f.web.app/privacy` is live and serves the current Noum
  policy. The custom `noum.app` domain is still parked at GoDaddy; it must not be
  described as connected to Firebase Hosting until DNS, TLS, and policy content
  are verified.
- The repository's hardened social rules and functions must **not** be deployed
  until legacy social data is backed up and quarantined, the explicit cutover is
  complete, and a trusted server-side evidence producer exists. Client-authored
  ratings or results are not acceptable production evidence.
- Two cached Firebase CLI user sessions were exposed during release inspection
  on 2026-07-13. An authorized operator must revoke both sessions, reauthenticate
  the required release account, and independently verify the revocation before
  any Firebase deployment or release evidence is accepted.
- Sign in with Apple provider configuration, paid-team archive signing,
  App Store Connect StoreKit verification, and the signed-device TestFlight
  sweep remain blocked. Simulator evidence cannot close these items.

## Fast Verdict

```bash
./tools/coach-arena/run.sh app-path
./tools/coach-arena/run.sh readiness
./tools/coach-arena/run.sh readiness --probe-live
```

`readiness` exits nonzero until the latest app-path report has:

- local score/fixture thresholds passing
- real Swift pipeline evidence passing
- trace-quality evidence passing
- Swift `localTargetShapeScore >= 85`

and the Swift readiness audit reports:

- score >= 85
- claim = `productionReadyEvidenceAvailable`
- blockers = `[]`

and the selected evidence directory contains:

- all five required launch-evidence sidecars
- `source-git-commit.txt`
- `source-coach-fingerprint.txt`

and the selected repo root passes static operational preflight:

- `firebase.json` points Firestore deploys at `firestore.rules`
- Firebase Hosting serves `public/` and rewrites `/privacy`
- `public/privacy.html`, bundled `PrivacyPolicy.md`, Settings privacy entry,
  and `NoumWebURLs.privacy` are present and aligned
- `docs/TESTFLIGHT_QA.md` covers deploy, privacy, and high-risk hardware surfaces

When `--probe-live` is enabled, `readiness` also exits nonzero unless the
configured hosted privacy URL is publicly reachable and serves Noum privacy
policy content. Keep this opt-in for offline CI; use it before any launch claim.

Use `./tools/coach-arena/run.sh readiness --no-fail` when you only want the
human-readable report during an in-progress launch pass.

Point it at an explicit evidence directory when staging release-candidate
sidecars:

```bash
./tools/coach-arena/run.sh readiness --dump-dir /private/tmp/noum-coach-eval --no-fail
./tools/coach-arena/run.sh readiness --repo-root /path/to/Noum --no-fail
./tools/coach-arena/run.sh readiness --probe-live --no-fail
```

The evidence-directory section is a lightweight staging audit. It rejects
missing files, malformed JSON, missing `schemaVersion`, wrong schema versions,
and missing top-level evidence sections. The Swift manifest loaders still decide
whether those files actually earn the VISION rows by validating source
freshness, counts, warnings, coverage floors, reviewer diversity, real-device
proof, and real-world outcome quality.

The operational static preflight is also local-only. It cannot prove Firestore
rules were deployed, the privacy URL is live, App Store privacy disclosures were
reviewed, TestFlight was uploaded, or release bugs were triaged. Those remain
the job of `coach-operational-launch-checklist-v2.json`.

The operational live probe is narrower: it checks the public privacy URL only.
It does not prove Firestore rule deployment, TestFlight upload, App Store privacy
review, or release-blocking bug triage.

At present, a successful privacy probe applies to the Firebase Hosting
`web.app` URL. It does not prove that `noum.app` is serving Noum content while
the registrar DNS remains parked.

## Apple signing and TestFlight preflight

Run the deterministic fixture tests, then inspect or build an unsigned
generic-iOS archive. Reuse an existing package cache so this local check cannot
resolve packages over the network:

```bash
python3 -m unittest discover \
  -s scripts/tests \
  -p 'test_release_testflight_preflight.py'

export SOURCE_PACKAGES_PATH="${SOURCE_PACKAGES_PATH:-$PWD/.build/fast-lane-release/SourcePackages}"
./scripts/release-testflight-preflight.sh \
  --source-packages "$SOURCE_PACKAGES_PATH" \
  --build-unsigned-archive "/private/tmp/Noum-unsigned-<build>.xcarchive" \
  --derived-data "/private/tmp/Noum-unsigned-derived-<build>" \
  --evidence-dir "$NOUM_COACH_EVAL_DUMP_DIR"
```

The command fails closed and reports three separate sections:

- repository/build correctness: Release identifiers, automatic-signing shape,
  source entitlements, App Attest production selection, extension embedding,
  the StoreKit 2 source contract, export options, source-aligned archive
  versions, the exact clean Git commit embedded in the app, generic-iPhoneOS/
  arm64 products, exact extension points, binary-
  matched dSYMs, compiled StoreKit/AuthenticationServices paths, app-owned
  privacy/export metadata, and the redacted bundle scan;
- local paid-team/provisioning authority: counts of valid Apple Distribution
  identities and matching, unexpired App Store profiles for the main app,
  Widget, and Messages extension. A profile only counts when its embedded
  distribution certificate matches an installed valid identity; and
- external TestFlight/launch evidence: acceptance of the physical-TestFlight
  and operational-launch artifacts by the existing readiness validator, with
  explicit rows for the Apple release-services prerequisite and physical
  StoreKit purchase/restore proof.

The report never prints certificate names, team identifiers, profile names, or
profile UUIDs. It never requests provisioning updates, signs an archive, exports
an IPA, or uploads a build. A green repository section proves release shape only.
The unsigned archive builder refuses a dirty checkout and embeds the exact
40-character source commit in `NoumSourceGitCommit`; an existing archive whose
value is absent or differs from the inspected checkout fails closed even when
its marketing/build versions happen to match.
The complete command must remain nonzero while either the local signing authority
or independently collected external evidence is missing.

On the reviewed local Mac, the repository/archive section passes, but only Apple
Development identities and development profiles are installed. There is no
valid Apple Distribution identity and there are no matching App Store profiles
for the three archived products. This is a host-authority blocker, not a source
configuration failure and not proof about what exists in the Apple Developer
account.

Only an authorized paid-team operator may perform the signed archive and local
App Store Connect export. After the local preflight is green, that operator can
use the equivalent commands below. An Xcode Archive workflow must set the same
`NoumSourceGitCommit` Info.plist value. These commands may contact Apple and are
intentionally outside automated/local preflight:

```bash
test -z "$(git status --porcelain --untracked-files=all)"
SOURCE_COMMIT="$(git rev-parse HEAD)"
SOURCE_BOUND_INFO="/secure/path/Noum-$SOURCE_COMMIT-Info.plist"
python3 scripts/release_testflight_preflight.py \
  --prepare-source-bound-info-plist "$SOURCE_BOUND_INFO"
xcodebuild archive \
  -project Noum.xcodeproj \
  -scheme Noum \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath '/secure/path/Noum-<build>.xcarchive' \
  "INFOPLIST_FILE=$SOURCE_BOUND_INFO" \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath '/secure/path/Noum-<build>.xcarchive' \
  -exportOptionsPlist scripts/TestFlightExportOptions.plist \
  -exportPath '/secure/path/Noum-<build>-export' \
  -allowProvisioningUpdates
```

The export plist uses automatic signing and contains no team ID, certificate
name, or profile mapping. Export is not upload: TestFlight upload, processing,
installation from TestFlight, and the physical-device sweep remain external
operator work and must be captured through the evidence workflow below. An
unsigned archive, simulator run, or direct Xcode development install cannot
close `noRealDeviceTestFlightVerification`.

The generated source-bound Info.plist is a release intermediate copied from the
protected local app configuration. Keep it in the same access-controlled build
location as the archive, never commit it, and use a new path for each candidate.

The current `coach-real-device-testflight-qa-v3` schema structurally validates
the complete runtime portion of the M14 hardware sweep: exactly 14 surfaces and
77 required checks covering Live Activity, prompt latency, audio sessions,
StoreKit purchase/restore/entitlements, production transcription and consent,
capture-failure integrity, pitch, multilingual practice, mode smoke, account
authentication/deletion, accessibility, notifications, and widgets. Every
check must appear once and pass on the same physical TestFlight build. Security
incident closure, deploys, Apple configuration, archive scanning, upload, and
release triage remain in the operational launch artifact rather than being
duplicated here.

## Live Cloud Operations Probe

With an authenticated `gcloud` identity that can read the production project,
run:

```bash
./scripts/test-release-cloud-operations-probe.sh
./scripts/release-cloud-operations-probe.sh
```

The first command is a local, no-network contract test and is also enforced by
the static-readiness workflow. The second command performs the read-only
production inspection.

The probe is read-only. It verifies the production Firestore recovery settings
and daily backup, required log metrics and routed alert policies, dedicated
function identities, exclusive access to the Deepgram secret, removal of broad
roles from the default compute identity, the hosted privacy page, and 401
responses from the sensitive callables when no Firebase Auth or App Check proof
is supplied. It never reads the Deepgram secret value.

The command is pinned to Firebase project `noum-d0b6f`, Functions region
`europe-west2`, and the documented production operations channel. Environment
overrides that name any other contract fail before credential discovery or a
cloud request. Its output names the accepted project and region so the captured
evidence cannot silently describe a lookalike environment.

This is current cloud-configuration evidence, not signed-device evidence. It
does not prove that App Attest succeeds on an archived build, that StoreKit
entitlements match App Store Connect, or that a real microphone session reaches
Deepgram and finalizes correctly.

The probe's Deepgram checks validate the replacement Firebase boundary without
reading its secret. They do not contain the separate historical incident; that
requires the closure evidence listed in
`docs/SECURITY_deepgram_key_endpoint.md`.

## Legacy Credential Containment Probe

After an authorized operator has protected or disabled the legacy AWS routes,
run the repository's unauthenticated status-only probe:

```bash
BACKEND_BASE_URL='https://<legacy-api-origin>' \
  ./scripts/verify_deepgram_endpoint.sh
```

The script sends no API key, bearer token, provider credential, or user data.
It never downloads or prints a response body and never calls Deepgram. It checks
both legacy credential-vending routes with `GET` plus the three documented
IM/TTS siblings with minimal `{}` `POST` bodies. Each route must return
`401`/`403` (protected) or `404`/`410` (disabled). A `2xx`,
redirect, request-validation response, rate limit, `5xx`, malformed status, TLS
failure, timeout, or other transport error fails the whole probe.

This output can support the
`legacyTranscriptionEndpointProtectedOrDisabled` prerequisite, but it cannot
support `exposedProviderCredentialsRevoked`,
`providerUsageAndBillingAuditComplete`, or the composite
`historicalCredentialIncidentClosed` prerequisite. Those require separately
registered provider/account evidence and independent verification. Do not pass
an old credential to this script and do not use an authenticated provider-token
endpoint as release automation.

## Protected Social Deployment Gate

Do not run a blanket Firestore-rules or Functions deployment from the current
repository while this gate is open. The social contract is a coordinated data
migration and server-authority change, not an independent rules update.

Before deploying the reviewed social rules and functions together:

1. Back up the production legacy social collections and record inventory
   fingerprints and counts.
2. Obtain explicit approval for the legacy-data disposition, then quarantine
   the client-authored public profiles and league rows. Do not promote their
   ratings, streaks, or results into trusted server state.
3. Complete and verify the one-time social reference cutover. Account deletion
   must fail safely before cutover without leaving a deletion tombstone or
   discarding either the legacy or current cleanup worklist.
4. Deploy a trusted server-side session-evidence producer that derives eligible
   competitive results from authenticated, immutable recording evidence. The
   `_verifiedSessionEvidence` consumer contract alone is not a producer.
5. Rerun Functions lint/build/unit tests and Firestore emulator tests for forged
   ratings, cross-user reads/writes, malformed challenges, replayed results,
   deletion retries, and pre-cutover failure cleanup.
6. Perform a dry-run inventory immediately before the coordinated deployment,
   deploy rules/functions, verify the cutover marker and callable-only reads,
   then complete a rollback-aware production smoke test.

Until every step passes, keep league and challenge actions unavailable in the
client. A disabled social surface is safer than accepting untrusted progress.

For the reviewed production inventory on an operator Mac that has an active
gcloud user identity but no Application Default Credentials, use the explicit
read-only credential mode:

```bash
node scripts/migrate-social-reference-cutover.mjs --project=noum-d0b6f \
  --gcloud-user-credentials
```

This mode obtains a short-lived token noninteractively, keeps it in memory only,
and never includes it in console output or the ignored mode-0600 backup. The
script rejects `--apply` and every purge option in this mode before contacting
gcloud or Firestore. Application Default Credentials remain the only credential
path eligible for the separately approved coordinated cutover.

## Local Evidence Path

```bash
NOUM_COACH_XCODE_DESTINATION='platform=iOS Simulator,name=iPhone 17' \
  ./tools/coach-arena/run.sh evidence-refresh --no-fail
```

This single command refreshes the source sidecars, text/live Swift app-path
reports, professional-calibration packet, readiness manifest, arena scoring,
and final artifact audit. It does not create external evidence or remove any
VISION blocker unless the sidecars below are present in
`NOUM_COACH_EVAL_DUMP_DIR` and pass both the Swift and Python contracts. For a
release decision, rerun without `--no-fail` and include `--probe-live`.

## Required Launch Evidence

| Blocker | Artifact | Must Prove |
|---|---|---|
| `noLiveProviderTranscriptSweep` | `coach-live-eval-v1.json` | Real provider transcript sweep over the required app-path fixtures, with `sourceGitCommit` and `sourceCoachFingerprint` matching the source sidecars. |
| `noProfessionalCoachCalibration` | `coach-chat-conversation-expert-calibration-results-v2.json` | Blinded professional-coach reviews for the required calibration packet, meeting the rubric and review-count floor. |
| `noRealUserLongitudinalTransferOutcomes` | `coach-real-user-transfer-outcomes-v3.json` | Pre-registered closed-beta cohort with complete enrollment/attrition accounting, delayed real-world follow-ups, linked interventions, retained negative outcomes, and evidence references. |
| `noRealDeviceTestFlightVerification` | `coach-real-device-testflight-qa-v3.json` | Same-build physical-device TestFlight verification for the exact 14-surface, 77-check runtime sweep. |
| `operationalLaunchChecklistIncomplete` | `coach-operational-launch-checklist-v2.json` | M14 launch checklist plus the exact structured release prerequisites: historical credential-incident closure, every legacy route protected/disabled, exposed credentials revoked, provider usage/billing audited, full-history findings adjudicated, release bundle scanned, guarded social cutover, hosted privacy/custom domain, Apple release services, TestFlight upload, and release-blocking bug triage. |

Do not create placeholder sidecars. Empty or summary-only transfer, device, and
launch artifacts fail the same row-level floors as the Swift manifest; missing
proof should stay missing.

The operational artifact's `releasePrerequisites` is an exact 12-row contract,
not a notes field. Every row must be complete for the same release-candidate
build, carry the expected environment and evidence kind, name different
performer and verifier identities, use valid completion/verification times, and
resolve three distinct hashed attachments: primary evidence, independent
verification, and command/review output. Missing, duplicate, unknown, stale, or
self-verified rows fail closed.

The full-history row also requires `historySecretAdjudication`: Gitleaks 8.30.1
over all reachable commits with 100% redaction, bound to the current source
commit and a SHA-256 fingerprint of the reachable commit set. Every detected
finding must appear once with only a hashed finding ID, detector rule, historical
commit/path, a closed disposition, and independently verified status evidence.
Active, unknown, accepted-risk, omitted, or suppressed credentials cannot be
adjudicated into a pass.

## UI Flow Boundary

The Maestro smoke flows are valuable, but they are smoke coverage:

```bash
bash maestro/run_chat_demo_smoke.sh
```

They cover:

- `maestro/chat_smoke.yaml`: Ask Noum type-chat happy path with deterministic markdown reply.
- `maestro/chat_reject_smoke.yaml`: deterministic rejection notice path.

They do not replace `coach-real-device-testflight-qa-v3.json`, which must cover
real-device TestFlight behavior for the launch surfaces listed above.

## Definition Of Ready

The launch bar is not "UI exists" or "tests pass." The product is production
ready only when:

- the app-path report passes local score, real-pipeline, and trace-quality gates
- the VISION readiness gate exits 0
- Maestro smoke flows pass on the installed simulator build
- the historical Deepgram/AWS credential incident has documented closure
- every documented legacy credential/IM/TTS route returns only a protective or
  disabled status to an unverified caller, without relying on a transport error
- every exposed provider credential is independently proven revoked or invalid,
  provider usage/billing has been audited, and the redacted full-history finding
  inventory is complete with no unresolved or suppressed finding
- both Firebase CLI sessions exposed during the 2026-07-13 inspection have been
  revoked, release access has been reauthenticated, and a different operator has
  verified that closure
- the legacy social backup/quarantine, cutover, trusted evidence producer, and
  coordinated rules/functions deployment have all passed
- Firebase Hosting privacy content is live and the `noum.app` custom domain is
  no longer parked
- Sign in with Apple, paid-team archive signing, and App Store Connect StoreKit
  products are configured and verified
- the candidate marketing version/build number is newer than the prior release
  or TestFlight upload, and change notes are drafted for that exact candidate
- real-device TestFlight evidence is attached
- external coach calibration and longitudinal user outcomes are attached
- the operational launch checklist is complete against the release candidate
