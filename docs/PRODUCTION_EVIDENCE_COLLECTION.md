# Noum production-evidence collection

This runbook turns Noum's existing external-evidence contracts into an operator
workflow. It serves the M14 launch gate and the VISION validation stage. It does
not lower the release bar and it cannot turn locally generated examples into
production evidence.

The authoritative acceptance logic remains
`tools/coach-arena/runners/readiness_gate.py`. The workflow adds source binding,
attachment integrity, independence attestations, separation of duties, and
guarded promotion around that validator.

## Non-negotiable boundary

- Do not invent reviewer identities, signatures, ratings, outcomes, receipts,
  device results, deployment logs, or App Store confirmations.
- Do not edit a negative result into a pass. Mixed or negative outcomes remain
  in the cohort; unresolved adverse outcomes keep the gate closed.
- Do not store names, raw speech, transcripts, credentials, unredacted StoreKit
  receipts, or App Store secrets in a run. Use pseudonymous hashes and redacted
  exports stored under the approved access-control policy.
- `validate` means the files satisfy the evidence contracts. It does not mean
  Noum is launch-ready. Only the complete readiness gate can make that decision.

## 1. Export current source authority

First refresh the existing source sidecars and professional-calibration packet
for the exact release candidate. This is performed by the existing coach-arena
workflow, not by the release-evidence tool:

```bash
export NOUM_COACH_EVAL_DUMP_DIR=/private/tmp/noum-coach-eval
NOUM_COACH_XCODE_DESTINATION='platform=iOS Simulator,name=iPhone 17' \
  ./tools/coach-arena/run.sh evidence-refresh --no-fail
```

Confirm the dump contains:

- `source-git-commit.txt`;
- `source-coach-fingerprint.txt`;
- `coach-chat-conversation-expert-calibration-v2.json`.

The initialization command refuses stale sidecars, dirty coach source, an
invalid packet, or a packet below the existing 39-conversation/78-review floor.

Before collecting Apple evidence, run the local signing/TestFlight preflight
against an unsigned generic-iOS archive:

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

This is preliminary, fail-closed diagnostics. It separates source/archive
correctness, the current Mac's installed distribution authority, and evidence
already accepted by the readiness validator. It does not sign, export, upload,
or contact Apple for provisioning updates, and its output is deliberately
redacted. Passing the local source or signing sections is not production
evidence. The overall command remains nonzero until real physical-TestFlight and
operational-launch artifacts are independently collected and accepted. The
archive section also rejects a simulator-shaped or version-drifted archive,
stale dSYMs, missing compiled StoreKit/Apple-authentication paths, and missing
app-owned privacy/export metadata. Installed App Store profiles only count when
their embedded distribution certificate matches an installed valid identity.

## 2. Initialize a non-passing run

Use an encrypted, access-controlled location outside the repository:

```bash
RUN=/secure/noum-release-evidence/rc-<build>
./tools/release-evidence/run.sh init \
  --run-dir "$RUN" \
  --source-dump "$NOUM_COACH_EVAL_DUMP_DIR" \
  --initialized-by-id '<operator identifier>' \
  --initialized-by-role '<operator role>'
```

Initialization copies the source sidecars and packet, binds their commit,
fingerprint, and packet SHA-256 into `release-evidence-run-v1.json`, and creates
four deliberately failing templates. It never inserts names, ratings, results,
or confirmations.

## 3. Register real supporting evidence

Every evidence reference used by the four artifacts must resolve to a nonempty,
non-symlinked file beneath the run and match its registered SHA-256. Register a
real attachment like this:

```bash
./tools/release-evidence/run.sh register-attachment \
  --run-dir "$RUN" \
  --id 'device-live-activity-screen-recording' \
  --kind 'screenRecording' \
  --file '/secure/capture/live-activity.mov' \
  --captured-at '2026-07-13T12:00:00Z' \
  --verified-by-id '<independent verifier identifier>'
```

The command prints `evidence://device-live-activity-screen-recording`. Put that
reference into the matching JSON field. If a redacted attachment still contains
personal data, add `--contains-personal-data` and a real
`--access-control-reference`.

The evidence kinds are not interchangeable. The workflow checks each kind
against the current readiness contract.

## 4. Professional-coach calibration

File: `coach-chat-conversation-expert-calibration-results-v2.json`.

Send the exported packet without Noum-authorship labels that would break
blinding. For every conversation, collect the packet's required number of
independent reviews. Each reviewer must:

- be a real professional communication coach;
- use a stable reviewer ID;
- provide qualification and signed independence-attestation attachments;
- attest that they are independent from the Noum product team, reviewed blind,
  and disclosed conflicts;
- provide all rubric ratings, decision, client-use decision, overclaim notes,
  revision notes, and at least one detailed human-coach reference.

The collection coordinator must be different from the reviewers and attach the
blind-assignment record plus a signed collection attestation. The workflow
checks complete packet coverage, two distinct reviewer IDs per conversation,
the exact packet fingerprint, no unresolved revision notes, and every floor in
the existing readiness validator. It does not calculate or improve ratings.

Set `templateStatus` to `COLLECTED_EXTERNAL_EVIDENCE` only after real signed
collection is complete.

## 5. Longitudinal real-user transfer

File: `coach-real-user-transfer-outcomes-v3.json`.

Register the protocol, analysis plan, benchmark, participant-consent ledger,
withdrawal ledger, exclusion ledger, adverse-outcome ledger, and signed study
attestation. The principal investigator and analyst must be different people.

For every retained outcome:

- hash the participant identifier as `sha256:<64 lowercase hex characters>`;
- link the actual intervention, real-world moment, delayed follow-up, audience
  response, and participant self-report evidence;
- preserve negative outcomes and confidence regressions;
- retain adverse rows and attach follow-up resolution evidence;
- leave `causalityClaims` empty.

Enrollment must balance exactly:

```text
completed + withdrawn + excluded = enrolled
```

The existing v3 validator additionally enforces cohort completion, participant
and moment diversity, delayed follow-up, longitudinal duration, outcome floors,
positive-transfer/non-regression thresholds, and complete adverse-resolution
accounting. A real study that misses a threshold remains a valid study result
but does not earn the release row.

Set `templateStatus` to `COLLECTED_EXTERNAL_EVIDENCE` only after the registered
analysis and accounting are complete.

## 6. Physical-device TestFlight verification

File: `coach-real-device-testflight-qa-v2.json`.

The tester and verifier must be different people. The same TestFlight build and
pseudonymous SHA-256 device identifier must be carried through all four rows:

| Surface | Required attachment kind |
|---|---|
| Live Activity | `screenRecording` |
| AI prompt latency | `latencyTrace` |
| Soundscape audio session | `audioSessionLog` |
| Paywall purchase/restore | `storeKitReceipt` |

Use a redacted StoreKit proof that demonstrates the sandbox transaction and
entitlement without exposing credentials or an unredacted receipt. The AI
latency trace must contain the real measured latency; the existing validator
enforces the 3,000 ms budget. JSON saying `passed: true` is insufficient when
the attachment is missing, empty, has the wrong kind/hash/timestamp, belongs to
a different build, or was not independently verified.

The run attestation must say `distributionChannel: "TestFlight"` and reference
an independently verified `testFlightInstallationProof` attachment. A paired
iPhone, Developer Mode, Apple Development signing, or a successful direct Xcode
install is useful preflight but cannot earn this artifact.

Set `templateStatus` to `COLLECTED_EXTERNAL_EVIDENCE` only after every row and
the signed physical-TestFlight attestation are complete.

This v2 artifact has four structured rows. It does not replace the remainder of
`docs/TESTFLIGHT_QA.md`. Use the same TestFlight build to complete and
independently sign off the real-microphone/App Check/consent path, Sign in with
Apple, deletion, notifications, widgets, accessibility, multilingual checks,
and mode smoke tests. Keep that checklist with the release packet; do not claim
those surfaces from the four-row JSON alone.

## 7. Operational launch evidence

File: `coach-operational-launch-checklist-v2.json`.

Every required item needs three indexed attachments:

- the primary evidence in the exact contract kind;
- an independent verification record with kind `verification:<item-key>`;
- the command or review output with kind `output:<item-key>`.

The performer and verifier for each item must be different people. Every item
must reference the same release-candidate build and exact environment defined by
the existing v2 contract. The required items are Firestore rules deployment,
hosted privacy URL, Settings privacy link, App Store privacy review, TestFlight
build upload, and release-blocking bug triage.

The release-blocking bug-triage evidence must explicitly include the two
Firebase CLI sessions exposed during the 2026-07-13 release inspection. Attach
only redacted account-side revocation and reauthentication proof, verified by a
different operator. Never register an access token, refresh token, ID token, or
Firebase CLI credential file as evidence.

This artifact does not waive the wider blockers in
`docs/PRODUCTION_READINESS_RUNBOOK.md`, including historical credential-incident
closure, protected social cutover, custom-domain verification, Apple release
services, archive signing, and StoreKit configuration. Capture and close those
before the final release decision even when they are not separate v2 item keys.

For that reason, the workflow adds a fail-closed `releasePrerequisites` array
around the existing v2 artifact. It has exactly twelve rows and records:

- the read-only cloud operations probe;
- historical credential-incident closure, legacy endpoint protection or
  disablement, credential revocation, and provider usage/billing audit;
- full-history secret-finding adjudication and the current release-bundle scan;
- the protected social cutover, its migration dry-run, and the trusted
  server-side evidence producer;
- custom privacy-domain verification;
- Apple release-service configuration.

For `appleReleaseServicesConfigured`, the primary and review evidence must cover
all of the following for the same release candidate, with certificate, profile,
and team identifiers redacted from the packet:

- paid-team identifiers/capabilities exist for the app, Widget, and Messages
  extension, and the signed archive validates against them;
- Sign in with Apple is enabled for the app identifier and configured as a
  Firebase Authentication provider;
- the monthly and annual product identifiers compiled from
  `Noum/PremiumManager.swift` exist in App Store Connect with complete
  subscription-group, localization, price, review, and availability metadata;
- agreements, tax, and banking state does not block sale; and
- the independently verified command/review output is bound to the same build.

Configuration evidence does not prove runtime behavior. The StoreKit sandbox
purchase/restore row and physical Sign in with Apple check must still pass from
the actual TestFlight installation.

A successful cloud operations probe can be registered as
`cloudOperationsProbeOutput`, but it cannot override an unauthenticated legacy
endpoint, an unrevoked credential, an unadjudicated history finding, or a failed
social migration dry-run. Each prerequisite has its own structured row and
three-part evidence set; all remain hard-blocking.

Each prerequisite row has the same evidence-bearing shape as an operational
item: `key`, `completed`, `evidenceReference`, `evidenceKind`,
`verificationReference`, `commandOrReviewOutputReference`,
`releaseCandidateBuild`, `environment`, `completedAtISO8601`, `performedByID`,
`verifiedAtISO8601`, `verifiedByID`, `verifiedByRole`, and `notes`. Do not add or
remove rows. The performer and verifier must differ. The row must name the same
release-candidate build as the artifact, use its template-provided evidence kind
and environment, and resolve three distinct indexed attachments. The attachment
verifier must match the row verifier. Unknown, duplicate, self-verified, stale,
or summary-only prerequisites fail validation.

### Legacy endpoint evidence

The repository probe is deliberately unauthenticated and status-only:

```bash
BACKEND_BASE_URL='https://<legacy-api-origin>' \
  ./scripts/verify_deepgram_endpoint.sh
```

It retains no body and accepts only `401`/`403` (protected) or `404`/`410`
(disabled) for both credential routes and every documented IM/TTS sibling.
Capture its redacted output as the command evidence for
`legacyTranscriptionEndpointProtectedOrDisabled`, then have a different person
verify the route inventory and result. A redirect, request-validation response,
rate limit, server error, timeout, or TLS failure is not proof of containment.

Never put an old provider credential into this script or a release attachment.
Credential revocation must be proven separately with a redacted provider/support
record and independent verification. The provider usage/billing audit is another
separate row; endpoint containment does not imply that no abuse occurred.

### Full-history finding adjudication

`fullHistorySecretFindingsAdjudicated` also requires the sibling
`historySecretAdjudication` object. Run the same pinned scanner as CI over a full
clone and write its machine-readable, 100%-redacted JSON report to the approved
evidence location:

```bash
REPORT=/secure/capture/gitleaks-full-history-redacted.json
gitleaks git . --redact=100 --no-banner \
  --report-format json --report-path "$REPORT"
git rev-list --all | LC_ALL=C sort -u | wc -l
git rev-list --all | LC_ALL=C sort -u | shasum -a 256
```

Gitleaks exits nonzero when it finds history that needs adjudication; that is the
expected open-gate state, not permission to discard its report. Register the
JSON as `fullHistorySecretReview`, then import it without assigning any result:

```bash
./tools/release-evidence/run.sh register-attachment \
  --run-dir "$RUN" \
  --id 'gitleaks-full-history-redacted' \
  --kind 'fullHistorySecretReview' \
  --file "$REPORT" \
  --captured-at '<scan timestamp>' \
  --verified-by-id '<independent verifier identifier>'

./tools/release-evidence/run.sh import-history-scan \
  --run-dir "$RUN" \
  --reference 'evidence://gitleaks-full-history-redacted'
```

The importer rejects non-JSON, partially redacted, stale, incomplete, shallow,
or wrong-kind reports. It creates a one-way finding inventory with blank
dispositions, sets every row unresolved, and explicitly leaves the gate closed.
It never prints a match or secret.

Record scanner `gitleaks`, version `8.30.1`, scope
`all-reachable-commits`, the current source commit, the positive reachable-commit
count, and the `sha256:`-prefixed digest of that exact sorted commit stream. Bind
`redactedScanReportReference` to the prerequisite row's primary
`fullHistorySecretReview` attachment.

The finding inventory must exactly match every JSON report row and include at least the three
historical credential findings already documented by the incident review. Use a
tool-derived `sha256:` finding ID—never credential material—plus the detector rule,
40-character historical commit, safe repository-relative path, disposition, and
`statusEvidenceReference`. Only four dispositions are closed:

- `revoked` with `secretFindingRevocation` evidence;
- `invalidated` with `secretFindingInvalidation` evidence;
- `falsePositive` with `secretFindingFalsePositiveReview` evidence;
- `publicIdentifier` with `secretFindingPublicIdentifierReview` evidence.

`detectedFindingCount` and `adjudicatedFindingCount` must equal the inventory;
`unresolvedFindingCount` and `suppressedFindingCount` must both be zero. The
known historical Deepgram finding commit must be present. An active or unknown
credential, an accepted-risk/suppressed finding, an unreachable commit, a stale
commit-set fingerprint, or reused status evidence keeps the gate closed. The
active credential documented today must therefore be revoked before this object
can validate; do not add an allowlist merely to turn CI green.

Set `templateStatus` to `COLLECTED_EXTERNAL_EVIDENCE` only when the real release
operations and independent verification are complete.

## 8. Derive summaries, approve, and validate

After entering real rows, derive the summary counters:

```bash
./tools/release-evidence/run.sh summarize --run-dir "$RUN"
```

This command only derives counts. It does not change ratings, outcomes,
pass/fail values, warnings, attestations, or template status. Inspect every
derived value against the source records. Do not clear a warning until its
underlying issue is resolved.

Complete `promotionApproval` in `release-evidence-run-v1.json` with a real
release approver who is different from the run initializer and professional
reviewers. Register and reference the signed approval; both truth attestations
must be explicit.

Then validate:

```bash
./tools/release-evidence/run.sh validate --run-dir "$RUN"
```

Validation fails closed on source drift, packet drift, missing or modified
attachments, identity collisions, incomplete accounting, missing adverse
follow-up, wrong evidence kind, mismatched build, warnings, or rejection by the
existing readiness validator.

## 9. Promote only accepted artifacts

Promotion targets the source dump used to initialize the run:

```bash
./tools/release-evidence/run.sh promote \
  --run-dir "$RUN" \
  --dump-dir "$NOUM_COACH_EVAL_DUMP_DIR"
```

Promotion refuses a changed source sidecar, changed packet, incomplete approval,
or any artifact rejected by the existing validator. Existing managed artifacts
are never overwritten unless `--replace-existing` is supplied after explicit
review. Accepted files are staged and atomically renamed into the dump.

The promotion receipt deliberately says `launchReadyClaimed: false`. Promotion
does not alter the live-provider artifact or the Swift readiness manifest.

## 10. Recompute the authoritative release verdict

After promotion, rerun the existing Swift evidence refresh and the complete
readiness gate, including the public operational probe:

```bash
NOUM_COACH_XCODE_DESTINATION='platform=iOS Simulator,name=iPhone 17' \
  ./tools/coach-arena/run.sh evidence-refresh

./tools/coach-arena/run.sh readiness \
  --dump-dir "$NOUM_COACH_EVAL_DUMP_DIR" \
  --probe-live
```

Do not release unless the complete command exits zero and every additional
security, social, Apple, signed-device, accessibility, and TestFlight item in
`docs/PRODUCTION_READINESS_RUNBOOK.md` and `docs/TESTFLIGHT_QA.md` is genuinely
closed.
