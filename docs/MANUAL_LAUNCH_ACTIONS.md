# Manual launch actions

Updated: 2026-07-20

This document lists actions that require account ownership, independent verification, a paid Apple team, real users, professional reviewers, or physical devices. It is not evidence that any action is complete.

## Current boundary

- The legacy Deepgram/AWS credential-vending incident is recorded as contained on 2026-07-18 in `docs/SECURITY_deepgram_key_endpoint.md`: the API was deleted, exposed Deepgram and Google keys were revoked/replaced, usage was reviewed, and the history scan was baselined. Do not revert to the stale 2026-07-13 wording.
- `coachChatV2` and `coachChatAvailability` from source commit `08985b39321095edec52c48ca50317763454d736` were deployed and read back active on 2026-07-19. Do not redeploy them merely to collect newer-looking output.
- The latest locally verified behavior/evidence source is `cdce32af9` with
  coach fingerprint
  `sha256:e1c6b655edaee8759e791ed6669a567117a17a283ef283680c3278c01e49cbad`.
  The current app-path report contains 53 conversations / 109 turns, 50/50
  scored fixtures, zero app-path failures, 50 complete traces, and a passing
  source-freshness check. The complete serialized targets pass 4,549/4,549
  unit tests and 79/79 UI tests. This is not a signed archive or processed
  TestFlight build; any later behavior change must receive a new source-bound
  refresh.
- Production remains NO-GO. The operational checklist, social cutover, Apple authority, current-candidate external evidence, and physical TestFlight sweep are not complete.

## 1. Close untrusted Firebase CLI sessions

Why: two cached Firebase CLI user sessions exposed during the 2026-07-13 inspection remain untrusted. A later successful scoped deployment does not independently prove those historical refresh tokens were revoked.

- Provider/dashboard: Google Account, Firebase CLI, and the production operations evidence store.
- Navigation: Google Account → Security → Your connections to third-party apps and services → Firebase CLI (and Google Cloud SDK where present) → remove access. Review Security → Your devices and Recent security activity as well.
- Local commands, run only by the authorized release operator:

```bash
firebase logout --all
firebase login --reauth
firebase projects:list
```

- Security: never paste refresh tokens, browser callback URLs, credential JSON, or `firebase login:ci` output into logs or this repository. Do not create a CI token.
- Required proof: redacted revocation timestamp, reauthentication timestamp, intended production account/project visibility, and review by a different named verifier.
- Pass: both exposed sessions are revoked, fresh access is established, project `noum-d0b6f` is visible, and independent verification is attached.
- Fail: local logout only, self-verification, ambiguous account, retained CI token, or secret-bearing output.
- Dependencies: none.
- Gate: blocks TestFlight and App Store operational sign-off.

## 2. Complete the residual AWS account inventory

Why: the known API Gateway deployment was deleted, but the security closure document records that a full AWS account sweep for other stages, aliases, APIs, or credential-vending integrations was not performed.

- Provider/dashboard: AWS Console in the legacy account, region `us-east-1`, plus AWS CLI if approved.
- Navigation: API Gateway → APIs, Stages, Custom domain names; Lambda → Functions and Function URLs; CloudFormation → Stacks; Secrets Manager; IAM → Access Analyzer/Credential report; CloudTrail → Event history.
- Values/artifacts: inventory of every remaining API/stage/domain/Lambda URL capable of serving the five historical Noum routes, with deletion/protection status and redacted identifiers.
- Security: do not probe with revoked credentials and do not export secret values. Prefer resource inventory and status evidence.
- Required proof: owner-produced inventory, command/dashboard output hash, and independent review confirming no alternate credential-vending route remains.
- Pass: every relevant route/resource is absent or access-controlled, with no unexplained alias/stage/domain.
- Fail: inaccessible account, partial region check, transport errors used as proof, or unreviewed resources.
- Dependencies: action 1 if Firebase/Google evidence is collected in the same operational session; otherwise independent.
- Gate: blocks operational TestFlight/App Store sign-off.

## 3. Perform the guarded social cutover

Why: social ratings/results must come from trusted server evidence. Repository locks intentionally prevent deploying stricter rules/functions onto unquarantined legacy client-authored data.

- Provider/dashboard: Firebase Console → Firestore Database, Google Cloud IAM/Logging, and the checked-in migration/deploy tooling.
- Required sequence: back up legacy social data; inventory and quarantine client-authored records; inventory private-profile enum values and explicitly migrate unknown values; install/verify the trusted session-evidence producer; execute and verify the schema-v4 reference cutover; run emulator authorization/replay tests; dry-run the production inventory; then deploy the reviewed rules/functions together under explicit authorization.
- Commands: follow `docs/PRODUCTION_READINESS_RUNBOOK.md` exactly. Do not run blanket `firebase deploy`, `npm --prefix functions run deploy`, or deploy Firestore rules separately.
- Security: use Application Default Credentials only on the authorized operator host; capture no document contents or credentials in evidence.
- Required proof: backup/quarantine manifest, cutover receipt, independent data review, emulator results, production dry-run, immutable source/digest binding, deployed readback, TTL/retention proof, and two-device smoke.
- Pass: all guarded rows pass for one source-bound release candidate and disabled capabilities are enabled only after readback.
- Fail: rules-only deploy, client-authored evidence accepted, unknown legacy values stranded, missing rollback, or mismatched commit.
- Dependencies: action 1; reviewed release candidate.
- Gate: blocks TestFlight and App Store launch while social capability is in release scope. Until then the capability must remain unavailable.

## 4. Connect and verify `noum.app`

Why: the Firebase Hosting privacy endpoint is live, but the custom domain remains parked and cannot be claimed as Noum's policy URL.

- Provider/dashboard: Firebase Console → Hosting → Add custom domain; GoDaddy → Domain Portfolio → DNS for `noum.app`.
- Values: use the exact TXT/A/AAAA records Firebase supplies. Do not copy records from another project. Preserve required email/MX records.
- Required proof: DNS record screenshot/export, Firebase connected status, valid public TLS certificate, and an exact-body comparison showing `https://noum.app/privacy` matches the current generated disclosure.
- Pass: public DNS resolves to Firebase Hosting, HTTPS is valid without redirect/certificate warnings, and the body matches.
- Fail: parked page, pending certificate, redirect-only proof, stale policy, or only `noum-d0b6f.web.app` verified.
- Dependencies: approved current privacy disclosure; safe Firebase operator session.
- Gate: blocks App Store launch/marketing claim; treat it as an operational TestFlight blocker if the candidate exposes `noum.app` as its user-facing policy URL.

## 5. Configure Apple release services and StoreKit

Why: this Mac currently lacks a valid Apple Distribution identity and matching App Store profiles for the app, widget, and Messages extension; Apple authentication and subscription behavior also require console configuration.

- Provider/dashboard: Apple Developer → Certificates, Identifiers & Profiles; App Store Connect → Apps → Noum → App Information, App Privacy, Subscriptions, TestFlight; Firebase Console → Authentication → Sign-in method → Apple.
- Bundle IDs: use the exact identifiers emitted by `scripts/release-testflight-preflight.sh`; do not guess or create parallel identifiers.
- Configure: Sign in with Apple capability and Firebase provider; paid-team Apple Distribution certificate; App Store provisioning for all three archived products; StoreKit monthly/annual products, price/territory/metadata, subscription group, grace/expiry behavior, and restore entitlement; support/contact and privacy URLs; App Privacy declarations that match the current privacy manifest/policy.
- Security: private keys and `.p12` files belong in the operator's secure keychain/vault, never the repo. Use least privilege in App Store Connect.
- Required proof: redacted preflight report, console screenshots/exports, sandbox purchase/restore/expiry result, and independent review.
- Pass: the release preflight's local signing-authority section is green and StoreKit/Apple sign-in work on a signed physical build.
- Fail: development identity only, wildcard/ad-hoc profiles, missing extension profile, unverified product, or simulator-only purchase proof.
- Dependencies: final source-bound candidate, privacy review.
- Gate: blocks TestFlight upload and App Store launch.

## 6. Produce, upload, and bind the release candidate

Why: a simulator build is not a source-bound signed archive and export is not an upload.

- Increment the marketing/build version to a value newer than any prior App Store/TestFlight build and draft change notes for that exact build.
- Require a clean checkout and bind `NoumSourceGitCommit` using the checked-in preflight workflow in `docs/PRODUCTION_READINESS_RUNBOOK.md`.
- Build the signed generic-iPhone archive, rerun preflight against that exact archive, export with `scripts/TestFlightExportOptions.plist`, upload through Xcode Organizer or Apple's approved transporter, and wait for processing.
- Security: do not use `-allowProvisioningUpdates` outside the authorized paid-team operator session. Do not copy signing material into the worktree.
- Required proof: source commit, archive hash, version/build, preflight output, App Store Connect processed-build ID, upload timestamp, and independent verifier.
- Pass: clean source, exact embedded commit, all three products/signatures/dSYMs pass, and the same build is processed in TestFlight.
- Fail: dirty/moved checkout, absent/mismatched source commit, unsigned archive, export-only evidence, or a different processed build.
- Dependencies: actions 1 and 5; code/local gates green.
- Gate: blocks TestFlight and App Store launch.

## 7. Run same-build physical TestFlight QA

Why: microphone, audio route changes, App Attest/App Check, StoreKit, Live Activities, widgets, interruptions, signing, and real provider behavior cannot be proven by a simulator.

- Install the processed build from TestFlight on physical devices. Execute the exact 14-surface, 77-check contract described by `docs/TESTFLIGHT_QA.md` and `docs/PRODUCTION_EVIDENCE_COLLECTION.md`.
- Include erased-install onboarding/consent, real Firebase-to-Deepgram transcription, offline/failure paths, purchase/restore/expiry, account deletion, notifications, multilingual speech, Reduce Motion, VoiceOver, largest Dynamic Type, dark mode, widgets, and all practice smoke modes.
- Required proof: `coach-real-device-testflight-qa-v3.json` plus all required attachments, same build/commit, distinct performer and verifier.
- Pass: every required row passes on the exact candidate with no release-blocking bug.
- Fail: simulator build, side-loaded development build, partial checklist, self-verification, or mixed build numbers.
- Dependencies: action 6; production service access; physical devices/test accounts.
- Gate: blocks TestFlight promotion and App Store submission.

## 8. Collect coaching-quality and transfer evidence

Why: local fixtures and model-judge scores cannot prove human coaching quality or transfer to real communication.

- Live provider: run the current-source app-path sweep with `--probe-live`; produce `coach-live-eval-v1.json` whose source commit and coach fingerprint match the candidate sidecars.
- Professional calibration: send the blinded packet to qualified communication coaches; produce `coach-chat-conversation-expert-calibration-results-v2.json` at the required review-count/rubric floor.
- Longitudinal transfer: run the pre-registered closed beta with enrollment/attrition accounting, delayed real-world follow-ups, linked interventions, negative outcomes retained, and referenced evidence; produce `coach-real-user-transfer-outcomes-v3.json`.
- Security/privacy: use consented, minimum-necessary material; redact identities; do not place raw participant transcripts in the repository.
- Pass: each validator accepts the source-bound artifact and attachments.
- Fail: synthetic users presented as real, current-head mismatch, summary-only artifact, missing negative outcomes, or automated judge substituted for human review.
- Dependencies: stable candidate; consent/research operations; action 7 where the same build is required.
- Gate: blocks production/App Store launch; the live-provider sweep also blocks credible external TestFlight coaching acceptance.

## 9. Complete operational sign-off and submit

Why: the release requires one exact operational artifact tying security, backend, privacy, Apple, upload, and triage to the candidate.

- Produce `coach-operational-launch-checklist-v2.json` with the exact 12 prerequisite rows, distinct performer/verifier identities, timestamps, and three distinct hashed attachments per row.
- Run the complete source-bound evidence refresh and release preflight without `--no-fail`.
- Triage each release-blocking defect separately. Do not convert missing proof into accepted risk merely to make the validator green.
- Pass: all five external artifacts validate, local gates pass, no release blocker is open, and App Store Connect submission references the exact candidate.
- Fail: placeholder sidecars, stale/mismatched source, duplicate evidence, self-verification, unchecked prerequisite, or waived critical issue.
- Dependencies: actions 1–8.
- Gate: blocks App Store submission and production launch.

## Exact next manual action

Start with action 1: revoke the two historical Firebase CLI sessions, reauthenticate the intended release account without creating a CI token, and have a second person verify the closure. Until that authority boundary is trustworthy, do not perform a social, hosting, or broad Firebase deployment.
