# Manual launch actions

Updated: 2026-07-22

This document lists actions that require account ownership, independent verification, a paid Apple team, real users, professional reviewers, or physical devices. It is not evidence that any action is complete.

## Current boundary

- The legacy Deepgram/AWS credential-vending incident is recorded as contained on 2026-07-18 in `docs/SECURITY_deepgram_key_endpoint.md`: the API was deleted, exposed Deepgram and Google keys were revoked/replaced, usage was reviewed, and the history scan was baselined. Do not revert to the stale 2026-07-13 wording.
- `coachChatV2` and `coachChatAvailability` from source commit `08985b39321095edec52c48ca50317763454d736` were deployed and read back active on 2026-07-19. Do not redeploy them merely to collect newer-looking output.
- The latest accepted source-bound coaching evidence remains `cdce32af9` with
  coach fingerprint
  `sha256:e1c6b655edaee8759e791ed6669a567117a17a283ef283680c3278c01e49cbad`.
  That app-path report contains 53 conversations / 109 turns, 50/50
  scored fixtures, zero app-path failures, 50 complete traces, and a passing
  source-freshness check for that older source. It predates the current local
  App Store-success changes and therefore cannot be attached to the eventual
  candidate as current evidence. The current worktree's launch-system, signed
  Day-0, visual, Functions, and release-script checks are recorded in
  `docs/CURRENT_STATE.md`; this is still not a clean source-bound archive or a
  processed TestFlight build. The final candidate requires a new complete
  source-bound evidence refresh.
- The worktree now contains source-controlled App Store metadata, screenshot/
  preview briefs, fail-closed release-asset and ASO experiment contracts,
  StoreKit-derived trial/renewal presentation, and local source pages for
  privacy, support, and **How Noum coaches**. These are preparation, not final
  marketing assets, PPO results, or evidence that App Store Connect or the
  public custom domain is configured.
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

## 3A. Deploy and verify privacy-bounded growth aggregates

Why: the app now records content-free activation, retention, subscription, notification, and AI-cost facts locally, but beta and commercial decisions cannot rely on them until the reviewed aggregate transport is deployed and inspected in production.

- Provider/dashboard: Firebase Functions, Firestore, App Check, Authentication, and the App Store Connect analytics dashboard.
- Required sequence: provision `noum-growth-runtime@noum-d0b6f.iam.gserviceaccount.com` with only `roles/datastore.user` (and grant the authorized deployer `iam.serviceAccounts.actAs` separately), verifying that the runtime has no Owner/Editor, Vertex AI, Secret Manager, or Firebase Authentication privileges; deploy `recordGrowthAggregate` and the matching Firestore rules from the exact reviewed candidate through the guarded release workflow; configure Firestore TTL on `_growthAggregateBatches.expiresAt`; verify App Check, authentication, deletion fencing, the eight-new-batches-per-day ceiling, anonymous batch idempotency, and closed-UTC-day backfill; then reconcile only acquisition/subscription facts against App Store Connect. Do not use these aggregates as the authority for trial conversion, proceeds, refunds, or peer benchmarks.
- Privacy: keep sharing off by default. Prove that opt-out sends nothing, opt-in sends only the allowlisted counters/buckets and USD cost totals, withdrawal stops future uploads, and no prompt, transcript, quote, account ID, device ID, or user identifier appears in payloads or aggregate documents. Update App Store Privacy answers to match this optional first-party analytics flow.
- Required proof: source-bound functions/rules deployment output, App Check/authenticated-call trace, redacted Firestore schema and idempotent-retry inspection, TTL policy screenshot/export, opt-in/withdrawal device trace, and a different verifier. For the App Store Connect reconciliation note, follow `AppStore/commercial-reconciliation.md`, retain the original exports plus reviewed identifier-free normalizations, and run `python3 scripts/reconcile_app_store_commercial.py` against a filled manifest outside the repository. A zero delta still carries the UTC-versus-Pacific boundary warning; a discrepancy must be investigated, not overwritten.
- Pass: one consented closed-day batch is accepted once, an identical retry does not double count, an unconsented client sends nothing, disallowed fields are rejected, TTL is active, and App Store Connect remains the declared commercial authority. The period document preserves known AI cost plus a bounded `unpricedAIUsageCount` equal to its allowlisted event count; any non-zero value blocks residual/contribution-margin arithmetic, while on-device work contributes neither paid nor unpriced provider usage.
- Fail: blanket deploy, missing App Check/auth, raw event upload, user-identifying dimension, transcript/content field, duplicate counting, absent TTL, or conversion math made by dividing incompatible cohorts.
- Dependencies: action 1; reviewed source candidate; current privacy disclosure.
- Gate: blocks measured external beta cohorts, App Store commercial launch, and any contribution-margin or paid-acquisition decision. It does not justify deploying the independently blocked social cutover.

## 3B. Configure and verify App Store Server Notifications V2

Why: device StoreKit observations do not cover renewals, cancellations, billing
failures, refunds, and expiry when the app is not running. The checked-in
receivers are disabled by default and production has no configured Apple app
ID, root-certificate secret, endpoint URLs, or deployed runtime identity.

- Provider/dashboard: Apple PKI; App Store Connect → Apps → Noum → App Information → App Store Server Notifications; Google Cloud IAM, Secret Manager, Functions, and Firestore.
- Required sequence: download the current DER Apple root certificate(s) from [Apple PKI](https://www.apple.com/certificateauthority/); encode each complete DER certificate as padded base64 and store only a JSON string array in the `APP_STORE_ROOT_CERTIFICATES_BASE64` Secret Manager secret; set `APP_STORE_APP_APPLE_ID` to Noum's numeric App Store app ID; leave `APP_STORE_PRODUCTION_NOTIFICATIONS_ENABLED=false` and `APP_STORE_SANDBOX_NOTIFICATIONS_ENABLED=false` until the exact source is deployed and read back; provision `noum-appstore-notifications-runtime@noum-d0b6f.iam.gserviceaccount.com` with exactly `roles/datastore.user` at project scope plus secret accessor on that one Apple-root secret (deployer `iam.serviceAccounts.actAs` remains separate), with no project or inherited Secret Manager data role; deploy `appStoreServerNotificationsV2`, `appStoreServerNotificationsV2Sandbox`, and the matching rules through the guarded release workflow; configure Firestore TTL on `_appStoreNotificationMarkers.expiresAt`; then run `NOUM_APP_STORE_APP_APPLE_ID=<numeric-id> scripts/release-cloud-operations-probe.sh` in its default `pre-enable` phase. Retain its helper-source and package-lock SHA-256 values, locked Apple library version, effective-IAM export, ACTIVE TTL export, exact App-ID/secret readback, and both disabled readbacks. Enter each exact HTTPS function URL in App Store Connect's production and sandbox Version 2 URL fields; enable sandbox first and rerun with `NOUM_APP_STORE_NOTIFICATION_PHASE=sandbox-enabled`, send Apple's test notification, exercise a sandbox trial/purchase lifecycle, inspect the anonymous counters, and only then enable production and rerun with `NOUM_APP_STORE_NOTIFICATION_PHASE=production-enabled`. The official Node server library must continue to verify the outer JWS and every present nested transaction/renewal JWS with online certificate checks, exact bundle `uk.co.otherpath.noum`, exact environment, and production app ID. No In-App Purchase private key is required for signature verification and none belongs in this runtime.
- Privacy and deletion: persist only source/environment/day, allowlisted lifecycle counters, a domain-separated SHA-256 of Apple's notification UUID for replay protection, timestamps, and TTL. Never retain the signed payload, receipt, notification UUID, product ID, transaction/original-transaction ID, subscription-group ID, app-account token, account/device/install ID, price, storefront, or speech content. These aggregates cannot be joined to an account, so account deletion has no notification-owned user row to erase. Do not later add entitlement mutation or account-token mapping to this aggregate receiver.
- Retry/idempotency: return 200 only after cryptographic verification and the Firestore transaction commits. Identical notification retries must hit one marker and not increment the period twice. Retryable Apple certificate/OCSP, configuration, or storage failures return 503. Apple retries both 4xx and 5xx Version 2 responses, so forged, malformed, wrong-app, wrong-environment, and incomplete recognized lifecycle payloads write nothing and receive the documented 204 permanent-invalid acknowledgement; do not return a 4xx for this no-retry path. Unknown but correctly verified future/test notification types are committed to the replay marker, acknowledged once, and add no lifecycle fact.
- Required proof: exact helper-source and package-lock SHA-256 binding plus locked Apple-library version; project, per-secret, and effective inherited IAM exports; disabled-before-deploy parameter readback; App Store Connect production/sandbox URL screenshots; Apple test-notification status; redacted sandbox lifecycle trace; one duplicate delivery with unchanged counters; wrong-app/forged 204 no-write trace and retryable 503 trace; redacted Firestore period/marker schemas; ACTIVE TTL policy; production-enabled readback; cloud-operations validator output; and independent review. The evidence must show no identifier or signed payload value.
- Pass: both environment-specific endpoints use the dedicated identity and official verifier, a verified sandbox lifecycle produces one bounded source-separated counter, replay is idempotent, TTL is active, malformed/forged input writes nothing, and production stays disabled until App Store Connect identity and URL proof are complete.
- Fail: client-authored lifecycle authority, decoded-without-verified JWS, a shared broad runtime, missing online certificate checks, accepting sandbox on the production endpoint, storing a receipt/JWS/identifier/product, no TTL, acknowledging before commit, or enabling before readback.
- Dependencies: action 1; reviewed source candidate; App Store app record/numeric ID from action 5; guarded Functions/rules deployment authorization.
- Gate: blocks trustworthy server-side subscription lifecycle evidence and commercial launch reconciliation. It does not replace StoreKit entitlement checks or App Store Connect proceeds/conversion reports.

## 4. Connect and verify `noum.app`

Why: source pages exist for privacy, support, and coaching boundaries, but the
custom domain still serves placeholder/lander content and cannot yet be claimed
as Noum's production support or policy surface.

- Provider/dashboard: Firebase Console → Hosting → Add custom domain; GoDaddy → Domain Portfolio → DNS for `noum.app`.
- Values: use the exact TXT/A/AAAA records Firebase supplies. Do not copy records from another project. Preserve required email/MX records.
- Required proof: DNS record screenshot/export, Firebase connected status,
  valid public TLS certificate, and successful
  `python3 scripts/validate-app-store-package.py --verify-live-urls` output
  proving `/privacy`, `/support`, and `/how-noum-coaches` serve the reviewed
  Noum bodies rather than a lander.
- Pass: public DNS resolves to Firebase Hosting, HTTPS is valid without redirect/certificate warnings, and all three reviewed bodies match.
- Fail: parked page, pending certificate, redirect-only proof, stale policy, or only `noum-d0b6f.web.app` verified.
- Dependencies: approved current privacy disclosure; safe Firebase operator session.
- Gate: blocks App Store launch/marketing claim; treat it as an operational TestFlight blocker if the candidate exposes `noum.app` as its user-facing policy URL.

## 5. Configure Apple release services and StoreKit

Why: this Mac currently lacks a valid Apple Distribution identity and matching App Store profiles for the app, widget, and Messages extension; Apple authentication and subscription behavior also require console configuration.

Complete the signing, authentication, and StoreKit portion before action 6.
After action 6 produces a processed TestFlight candidate, return here to bind
and upload the final listing assets and finish CPP/PPO configuration. The live
PPO result comes later and is a scale gate.

- Provider/dashboard: Apple Developer → Certificates, Identifiers & Profiles; App Store Connect → Apps → Noum → App Information, App Privacy, Subscriptions, TestFlight; Firebase Console → Authentication → Sign-in method → Apple.
- Bundle IDs: use the exact identifiers emitted by `scripts/release-testflight-preflight.sh`; do not guess or create parallel identifiers.
- Configure: Sign in with Apple capability and Firebase provider; paid-team Apple Distribution certificate; App Store provisioning for all three archived products; StoreKit monthly (`com.noum.pro.monthly`, GBP 11.99) and annual (`com.noum.pro.annual`, GBP 79.99) products; a seven-day annual introductory free trial; price/territory/metadata, subscription group, grace/expiry behavior, and restore entitlement; support/contact and privacy URLs; App Privacy declarations that match the current privacy manifest/policy. If the business is eligible, enroll the account in Apple's Small Business Program and retain the accepted-enrollment/commission-status evidence; otherwise model the actual commission tier rather than assuming 15%. Upload the final seven-shot default listing and 20–30 second preview from the signed candidate, create the Interview, Leadership meetings, and Presentations custom product pages, and create all three pre-registered PPO treatments. Apple-returned localized price and eligibility remain the only runtime authority.
- Asset binding: copy `AppStore/release-assets.template.json` into the protected release-evidence directory. Fill it only with the exact signed TestFlight source commit, marketing version/build, deidentified fixture, real relative file paths and SHA-256 values, default/CPP/PPO mappings, default App Store Connect listing link, all three CPP App Store Connect and public `ppid` URLs, and all three PPO treatment links. From that exact clean checkout run `python3 scripts/validate-app-store-package.py --verify-release-assets <manifest>`. Repository QA screenshots and an unsigned simulator capture cannot satisfy this proof.
- PPO result: copy `AppStore/aso-experiment.template.json` into the protected evidence directory before starting the experiment. Use App Store Connect's traffic estimate to fill the deliberately unset positive per-arm/storefront denominator, then preserve the hypothesis, exact app version/source commit, GB/US storefront matrix, unique-impression denominators, first-time-download numerators, 7–90 day window, Apple's conversion/lift/status and confidence output, App Store Connect result export, final or inconclusive decision, and a different verifier. Run `python3 scripts/validate-app-store-package.py --verify-aso-experiment-results <manifest>`. A treatment cannot be selected below the registered denominator or without Apple's `Performing Better` result at 90%+ confidence; missing or inconclusive results must not be rewritten as a win. Apple permits a PPO test to run only when the app is Ready for Distribution and live, so this result is a post-launch paid-acquisition/scale gate, not an impossible first-release gate.
- Security: private keys and `.p12` files belong in the operator's secure keychain/vault, never the repo. Use least privilege in App Store Connect.
- Required first-release proof: redacted preflight report, console screenshots/exports, sandbox purchase/restore/expiry result, actual commission-tier evidence (including Small Business Program acceptance when applicable), strict release-asset validator output, uploaded default-listing/CPP/PPO configuration links, the pre-registered PPO contract, and an independent review of every binding. These materials belong in the existing `appleReleaseServicesConfigured` prerequisite's three attachments; do not add a thirteenth prerequisite or alter the v2 schema. Once the live PPO window completes, retain its strict result manifest and independent verification in the same Apple evidence packet for the separate scale decision.
- First-release pass: the release preflight's local signing-authority section is green; StoreKit/Apple sign-in work on a signed physical build; the exact final media is uploaded and source-bound; all CPP/PPO configuration links resolve to the intended version; and a different person verifies the packet.
- Paid-acquisition/scale pass: the later live PPO result is retained truthfully, independently verified, and passes the strict result validator. An inconclusive result is valid evidence but is not a winning treatment.
- Fail: development identity only, wildcard/ad-hoc profiles, missing extension profile, unverified product, simulator/QA imagery presented as final marketing media, missing/mismatched file hash, dirty or different source binding, unresolved CPP/PPO link, fabricated PPO win, or self-verification.
- Dependencies: final source-bound candidate, processed TestFlight build, privacy review, and completed listing capture/upload. The PPO result additionally depends on a live Ready-for-Distribution app and its completed observation window. Signed-RC capture, video encoding, App Store Connect upload/page creation, and PPO results remain external work.
- Gate: Apple signing/StoreKit blocks TestFlight upload; final listing/CPP/PPO configuration blocks App Store submission; the completed PPO result blocks material paid acquisition and scale, not the first release.

## 6. Produce, upload, and bind the release candidate

Why: a simulator build is not a source-bound signed archive and export is not an upload.

- Increment the marketing/build version to a value newer than any prior App Store/TestFlight build and draft change notes for that exact build.
- Require a clean checkout and bind `NoumSourceGitCommit` using the checked-in preflight workflow in `docs/PRODUCTION_READINESS_RUNBOOK.md`.
- Build the signed generic-iPhone archive, rerun preflight against that exact archive, export with `scripts/TestFlightExportOptions.plist`, upload through Xcode Organizer or Apple's approved transporter, and wait for processing.
- Security: do not use `-allowProvisioningUpdates` outside the authorized paid-team operator session. Do not copy signing material into the worktree.
- Required proof: source commit, archive hash, version/build, preflight output, App Store Connect processed-build ID, upload timestamp, and independent verifier.
- After processing, capture the final App Store screenshots/preview from this
  exact build and bind them through the strict release-asset manifest. Do not
  reuse the earlier simulator QA sweep as listing media.
- Pass: clean source, exact embedded commit, all three products/signatures/dSYMs pass, and the same build is processed in TestFlight.
- Fail: dirty/moved checkout, absent/mismatched source commit, unsigned archive, export-only evidence, or a different processed build.
- Dependencies: action 1 and the signing/authentication/StoreKit portion of
  action 5; code/local gates green. The post-processing asset and PPO portions
  of action 5 deliberately follow this upload.
- Gate: blocks TestFlight and App Store launch.

## 7. Run same-build physical TestFlight QA

Why: microphone, audio route changes, App Attest/App Check, StoreKit, Live Activities, widgets, interruptions, signing, and real provider behavior cannot be proven by a simulator.

- Install the processed build from TestFlight on physical devices. Execute the exact 14-surface, 84-check contract described by `docs/TESTFLIGHT_QA.md` and `docs/PRODUCTION_EVIDENCE_COLLECTION.md`.
- Include erased-install onboarding/consent, real Firebase-to-Deepgram transcription, offline/failure paths, StoreKit trial eligibility/start/renewal/cancellation/billing failure/refund/expiry/restore, account deletion, notifications, multilingual speech, Reduce Motion, VoiceOver, largest Dynamic Type, dark mode, widgets, and all practice smoke modes.
- Required proof: `coach-real-device-testflight-qa-v3.json` plus all required attachments, same build/commit, distinct performer and verifier.
- Pass: every required row passes on the exact candidate with no release-blocking bug.
- Fail: simulator build, side-loaded development build, partial checklist, self-verification, or mixed build numbers.
- Dependencies: action 6; production service access; physical devices/test accounts.
- Gate: blocks TestFlight promotion and App Store submission.

## 8. Collect coaching-quality and transfer evidence

Why: local fixtures and model-judge scores cannot prove human coaching quality or transfer to real communication.

- Live provider: run the current-source app-path sweep with `--probe-live`; produce `coach-live-eval-v1.json` whose source commit and coach fingerprint match the candidate sidecars.
- Professional calibration: send the blinded packet to qualified communication coaches; produce `coach-chat-conversation-expert-calibration-results-v2.json` at the required review-count/rubric floor.
- Longitudinal transfer: run the pre-registered four-week closed beta with at
  least 30 qualitative participants and at least 200 installs for the initial
  D1/D7 cohort; retain enrollment/attrition accounting, delayed real-world
  follow-ups, linked interventions, and negative outcomes; produce
  `coach-real-user-transfer-outcomes-v4.json`. Reach at least 500 qualified
  installs before treating trial conversion as stable enough for material paid
  acquisition.
- Security/privacy: use consented, minimum-necessary material; redact identities; do not place raw participant transcripts in the repository.
- Pass: each validator accepts the source-bound artifact and attachments.
- Fail: synthetic users presented as real, current-head mismatch, summary-only artifact, missing negative outcomes, or automated judge substituted for human review.
- Dependencies: stable candidate; consent/research operations; action 7 where the same build is required.
- Gate: blocks production/App Store launch; the live-provider sweep also blocks credible external TestFlight coaching acceptance.

## 9. Complete operational sign-off and submit

Why: the release requires one exact operational artifact tying security, backend, privacy, Apple, upload, and triage to the candidate.

- Produce `coach-operational-launch-checklist-v2.json` with the exact 12 prerequisite rows, distinct performer/verifier identities, timestamps, and three distinct hashed attachments per row. The existing `appleReleaseServicesConfigured` row must include the final listing/CPP/PPO configuration and pre-registration packet described in action 5; add the independently verified PPO result to the same retained Apple packet when it becomes available after launch. Do not change the exact row count or add an ASO-only row.
- Run the complete source-bound evidence refresh and release preflight without `--no-fail`.
- Triage each release-blocking defect separately. Do not convert missing proof into accepted risk merely to make the validator green.
- Pass: all five external artifacts validate, local gates pass, no release blocker is open, and App Store Connect submission references the exact candidate.
- Fail: placeholder sidecars, stale/mismatched source, duplicate evidence, self-verification, unchecked prerequisite, or waived critical issue.
- Dependencies: actions 1–8.
- Gate: blocks App Store submission and production launch.

## Exact next manual action

Start with action 1: revoke the two historical Firebase CLI sessions, reauthenticate the intended release account without creating a CI token, and have a second person verify the closure. Until that authority boundary is trustworthy, do not perform a social, hosting, or broad Firebase deployment.
