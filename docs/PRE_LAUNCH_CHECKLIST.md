# Noum pre-launch promotion checklist

Use this checklist to decide whether one immutable release candidate may move
through:

`local development -> internal TestFlight -> closed beta -> open beta -> GA`

This is the operator entrypoint and decision record. It does not replace the
detailed procedures in the linked runbooks, and an unchecked box is not proof
that a step failed. It means the required evidence is not yet attached.

Noum's current release phase is M14/M15 validation and production readiness.
The product goal is a trustworthy communication coach: weak evidence must stay
soft, repeated patterns may earn stronger intervention, real speech must not be
misclassified as filler, and pressure modes must remain fair. A build that is
technically stable but breaks those coaching invariants is not releasable.

## 1. Rules for every promotion

- [ ] Assign one release owner and one independent verifier.
- [ ] Record the exact Git commit, marketing version, build number, archive
      SHA-256, App Store Connect build ID, Firebase project, and deployed
      backend revision/configuration used by the candidate.
- [ ] Keep the tested archive immutable. Do not rebuild the same build number
      and assume it is equivalent.
- [ ] Store release evidence in the approved encrypted location outside the
      repository. Commit only redacted references or digests, never credentials,
      speech, transcripts, receipts, personal data, or signing material.
- [ ] Treat `[x]` as “evidence reviewed,” not “someone remembers doing it.”
- [ ] Mark `N/A` only with a written reason and named approver.
- [ ] Any app code, resource, entitlement, build-setting, privacy disclosure,
      Firebase rule/function, feature-flag default, or production configuration
      change invalidates the affected checks. Create a new candidate or record
      the narrowly scoped re-verification.
- [ ] Do not waive a security, privacy, cross-account data, data-loss,
      purchase/entitlement, account-deletion, launch/crash, or baseline
      accessibility blocker.
- [ ] Promote only when all gates for the destination stage are green and the
      release owner plus independent verifier record `GO`.

The canonical external-evidence validator remains
[`tools/coach-arena/runners/readiness_gate.py`](../tools/coach-arena/runners/readiness_gate.py).
This document must never be used to turn missing real-world evidence into a
pass.

## 2. Candidate record

Copy this table into the release issue or evidence record for each candidate.
Do not edit this template to imply a release is currently approved.

| Field | Value |
|---|---|
| Candidate name | `RC-____` |
| Marketing version | `____` |
| Build number | `____` |
| Git commit (40 characters) | `____` |
| Branch | `____` |
| Archive SHA-256 | `____` |
| App Store Connect build ID | `____` |
| Firebase app / project | `____` |
| Backend revision/config digest | `____` |
| Feature-flag snapshot/digest | `____` |
| Evidence run directory / ID | `____` |
| Release owner | `____` |
| Independent verifier | `____` |
| Decision date/time (UTC) | `____` |
| Destination stage | internal TestFlight / closed beta / open beta / GA |
| Decision | GO / NO-GO |
| Open accepted risks | `____` |
| Rollback owner and route | `____` |

## 3. Severity and decision policy

| Severity | Meaning | Promotion rule |
|---|---|---|
| P0 | Security/privacy incident, cross-account exposure, data loss, unsafe coaching, or purchase/account-deletion integrity failure | Stop testing, contain, and investigate. No promotion. |
| P1 | Core journey unusable, repeatable crash/hang, production dependency unavailable, App Check rejection, or baseline accessibility failure | Fix or remove the affected capability before promotion. |
| P2 | Non-blocking defect with a safe workaround and no trust/integrity impact | May be accepted only with an owner, rationale, scope, and target release. |
| P3 | Cosmetic or low-impact polish | Track normally; confirm it does not hide a more serious failure. |

Missing evidence is `NO-GO`, not accepted risk. A simulator pass cannot satisfy
a physical-device gate, and an exported archive cannot satisfy a processed
TestFlight-build gate.

## 4. Stage A — local release candidate

### Candidate and scope

- [ ] Review [`docs/VISION.md`](VISION.md) and
      [`docs/CURRENT_STATE.md`](CURRENT_STATE.md) for the candidate's actual
      milestone, known gaps, and product invariants.
- [ ] Define the release scope, release-disabled capabilities, migration scope,
      and user-visible changes for this exact build.
- [ ] Confirm the source checkout is clean before source binding and archiving.
- [ ] Confirm the version/build is newer than every prior uploaded build and
      draft release notes for that exact version.
- [ ] Review every known issue. Separate release blockers from explicitly
      accepted P2/P3 defects; do not use a broad “known issues” waiver.

### Automated local and CI gates

- [ ] The GitHub `Release readiness` workflow is green for the exact commit:
      full-history secret scan, Functions lint/unit tests, Firebase emulator
      integration, static release boundaries, Release build/unit suite, focused
      UI smoke, and the configured live public-page probe.
- [ ] From a clean checkout at the exact candidate commit, create and push a
      new annotated tag named `rc-<version>-<build>`. An `rc-*` tag
      automatically runs the source-controlled full UI gate as well as the
      normal release workflow. Never move, delete, or reuse an RC tag; a changed
      candidate requires a new build number and a new tag.
- [ ] After the workflow exists on the default branch, the equivalent manual
      release-candidate run may be dispatched against an immutable RC tag with
      the full UI gate and active-host public-page probe enabled:

      ```bash
      gh workflow run release-readiness.yml \
        --ref '<immutable-candidate-tag>' \
        -f run_full_ui_suite=true \
        -f run_live_web_probe=true \
        -f probe_custom_domain=false
      ```

      Switch `probe_custom_domain` to `true` for cutover approval only after
      `noum.app` is configured and expected to serve the same launch pages.

      The `Full serialized iOS UI release gate` job must pass all methods in the
      `NoumUITests` target with one worker. Retain its `.xcresult` artifact and
      verify the workflow run's head SHA matches the candidate record. A
      skipped, cancelled, timed-out, or partially selected suite is `NO-GO`.
- [ ] Run the static operational gate locally:

      ```bash
      ./scripts/release-static-readiness.sh
      ```

- [ ] Run the App Store source-package validator. Before GA, also verify the
      public URLs:

      ```bash
      python3 scripts/validate-app-store-package.py
      python3 scripts/validate-app-store-package.py --verify-live-urls
      ```

- [ ] Refresh current-source coaching evidence without claiming missing
      external evidence:

      ```bash
      export NOUM_COACH_EVAL_DUMP_DIR=/private/tmp/noum-coach-eval
      export NOUM_COACH_XCODE_DESTINATION='platform=iOS Simulator,id=<exact-disposable-simulator-UDID>'
      export NOUM_COACH_DISPOSABLE_SIMULATOR=1
      ./tools/coach-arena/run.sh evidence-refresh --no-fail
      ```

- [ ] Run the complete unit and UI targets on the pinned Xcode/simulator
      configuration and attach the `.xcresult` summaries. The focused PR smoke
      does not replace the full release-candidate UI gate. Zero silently skipped
      tests are allowed unless the skip is reviewed and justified.
- [ ] Run the relevant smoke journeys and a current-source screenshot sweep.
      Visually inspect the artifacts; nonblank images alone are not visual QA.
- [ ] Recheck the release audit findings in
      [`docs/M15_release_audit.md`](M15_release_audit.md), including VoiceOver,
      Dynamic Type, and Reduce Motion on changed surfaces.

### Security, privacy, and environment boundary

- [ ] Run the checked-in full-history secret scan and adjudicate every finding
      under the existing baseline. Do not paste matches into a release issue.
- [ ] Scan the built `.app` with
      [`scripts/release-scan-app-bundle.sh`](../scripts/release-scan-app-bundle.sh)
      and attach only the redacted result plus bundle digest.
- [ ] Confirm local development uses Firebase emulators or an approved
      development/staging project and cannot casually mutate production user
      data. If `noum-d0b6f` is shared, document the bounded test accounts/data,
      operator authorization, and migration plan to a separate environment.
- [ ] Confirm the Release build points to the intended Firebase project and iOS
      app. Record both IDs; do not rely on a filename or Xcode UI label.
- [ ] Confirm `FirebaseApp.configure()` runs before any Firebase product is
      used. A release-device log must contain no `I-COR000003` configuration
      warning.
- [ ] Confirm Firebase App Check debug mode is compiled only for Debug or the
      simulator. No debug token, token registration instruction, or debug
      provider may ship as a production exception.
- [ ] Confirm the Firebase Console has the production iOS app registered for
      App Attest with DeviceCheck fallback, and the Apple App ID has the App
      Attest capability enabled.
- [ ] Confirm Release resolves
      `com.apple.developer.devicecheck.appattest-environment` to `production`.
- [ ] Confirm every callable remains Auth/App-Check protected as required, and
      that Firestore rules, Storage rules, IAM, rate limits, and feature gates
      default deny when identity or attestation is missing.
- [ ] Confirm debug App Check tokens are treated as bypass secrets: stored only
      in the Firebase Console/approved secret store, excluded from source and
      screenshots, and removed when no longer needed.
- [ ] Confirm the generated privacy disclosure, app privacy manifest, in-app
      policy, hosted policy, App Store privacy answers, cloud-consent behavior,
      account deletion, and export behavior describe the same processors and
      data flows.
- [ ] Close or explicitly retain disabled every item in
      [`docs/MANUAL_LAUNCH_ACTIONS.md`](MANUAL_LAUNCH_ACTIONS.md). In particular,
      do not enable social capability before the guarded backup, quarantine,
      trusted-evidence cutover, coordinated rules/functions deploy, readback,
      rollback proof, and two-device smoke are complete.

### Archive and upload boundary

- [ ] Run the deterministic preflight tests and build/inspect the exact
      generic-iPhone archive as documented in
      [`docs/PRODUCTION_READINESS_RUNBOOK.md`](PRODUCTION_READINESS_RUNBOOK.md).
- [ ] The preflight repository/archive section is green: identifiers,
      entitlements, App Attest production mode, embedded extensions, privacy
      metadata, dSYMs, bundle scan, source commit, architecture, and versions
      all match.
- [ ] The authorized Mac has a valid Apple Distribution identity and matching,
      unexpired App Store profiles for the app, Widget, and Messages extension.
- [ ] Sign in with Apple/Firebase, StoreKit products, trial, territories,
      pricing, purchase, restore, expiry/grace behavior, and support/privacy
      URLs are configured for the intended environment.
- [ ] Export and upload the same source-bound archive, wait for processing, and
      bind its App Store Connect build ID to this candidate record.
- [ ] The release preflight may remain nonzero only for evidence that inherently
      requires the processed TestFlight build or real-user cohort. Any local,
      signing, security, privacy, configuration, or archive failure remains a
      blocker.

### Stage A decision

- [ ] `GO` is limited to internal TestFlight distribution for hardware and
      production-service evidence. It is not approval for external testers,
      public beta, App Review, or GA.
- [ ] Release owner: `____`
- [ ] Independent verifier: `____`
- [ ] Decision/evidence link: `____`

## 5. Stage B — internal TestFlight

Use a small, named internal group to establish that the processed build behaves
like the candidate before exposing external testers.

- [ ] Install from TestFlight on physical devices. A direct Xcode development
      install does not count.
- [ ] Verify build number, embedded source commit, tester account, backend
      revision, and feature-flag snapshot match the candidate record.
- [ ] Run the exact 14-surface/84-check physical-device contract from
      [`docs/TESTFLIGHT_QA.md`](TESTFLIGHT_QA.md) and record it through
      [`docs/PRODUCTION_EVIDENCE_COLLECTION.md`](PRODUCTION_EVIDENCE_COLLECTION.md).
- [ ] Include fresh install/onboarding, microphone permission, real speech,
      transcription consent, offline/reconnect, audio interruptions/routes,
      background/foreground, notifications, Live Activities, widgets,
      multilingual practice, purchase/restore/expiry, authentication, account
      upgrade, and account deletion.
- [ ] Verify VoiceOver, largest supported Dynamic Type, Reduce Motion, dark
      mode, and critical actions on the supported device/OS matrix.
- [ ] Verify a real production App Check token is accepted. Firebase logs and
      App Check metrics show the expected app/provider, and the device does not
      use the registered simulator debug token.
- [ ] Verify there are no repeated `403 App attestation failed`, placeholder
      token fallbacks, Firebase-before-configure warnings, or unexpected
      unauthenticated callable failures.
- [ ] Verify crash and hang reporting, redacted diagnostics, customer-support
      routing, and kill switches can be observed and operated.
- [ ] Exercise each rollback/disable route without destructive production
      mutation. Record the owner and expected recovery time.
- [ ] File every failed check separately with severity, reproduction steps,
      logs/attachment references, owner, and affected build.

### Stage B decision

- [ ] Every required physical-device row passes on the same build, with a
      different performer and verifier.
- [ ] No open P0/P1 exists.
- [ ] The candidate is approved only for the named closed-beta cohort.
- [ ] Release owner: `____`
- [ ] Independent verifier: `____`
- [ ] Decision/evidence link: `____`

## 6. Stage C — closed beta

Closed beta proves product trust and operational behavior over time; it is not
merely a larger smoke test.

- [ ] Define the cohort, inclusion criteria, consent, support channel,
      observation window, success/failure thresholds, and stop conditions
      before enrollment.
- [ ] Use the evidence sequence and cohort floors in
      [`AppStore/launch-gates.md`](../AppStore/launch-gates.md): qualified coach
      review, four-week closed beta, at least 30 qualitative participants and
      200 installs, complete enrollment/attrition accounting, delayed
      follow-up, and retained negative outcomes.
- [ ] Collect the source-bound live-provider evaluation and blinded review by
      qualified communication coaches. Automated model judging cannot replace
      professional calibration.
- [ ] Confirm coaching remains evidence-calibrated: no invented claims, no
      semantic-speech-as-filler errors, no unjustified certainty from small
      samples, and no unfair pressure-mode penalties.
- [ ] Verify the first-value, first-rep, completed-summary, retention, and
      follow-up events use documented denominators and do not mix synthetic,
      staff, and real-user cohorts.
- [ ] Review crashes, hangs, App Check failures, auth failures, transcription
      failures, account deletion, purchase/restore, support contacts, refunds,
      provider latency, quota, rate limiting, and AI cost at an agreed cadence.
- [ ] Verify raw speech/transcripts and personal data follow consent, retention,
      export, deletion, redaction, and access-control policy in real accounts.
- [ ] Confirm Remote Config/capability gates fail closed and do not expose
      uncut-over social, unsupported coaching, or unavailable cloud features.
- [ ] Triage all adverse outcomes and complaints. Do not delete negative data
      from the release cohort to improve a metric.
- [ ] Re-run affected internal/device gates after every candidate or production
      backend/configuration change.

### Stage C decision

- [ ] The pre-registered closed-beta window is complete and its evidence
      validates against the exact candidate/source fingerprint.
- [ ] No open P0/P1 exists; every accepted P2 has an owner and target release.
- [ ] Operational load, support, privacy, coaching quality, and rollback owners
      approve expansion.
- [ ] Release owner: `____`
- [ ] Independent verifier: `____`
- [ ] Decision/evidence link: `____`

## 7. Stage D — open beta

For iOS, “open beta” means the approved external TestFlight build and public
link/cohort—not an App Store production release.

- [ ] Closed-beta evidence and professional calibration are accepted; no
      unresolved result is hidden by aggregate metrics.
- [ ] The public TestFlight description, privacy explanation, feedback route,
      eligibility, tester cap, and expiry expectations are accurate.
- [ ] Support coverage, incident owner, monitoring cadence, escalation route,
      and rollback/disable authority are scheduled for the expansion window.
- [ ] Firebase/App Check metrics show valid production attestation across the
      supported device/OS mix. Unexpected invalid/unknown traffic is explained
      before changing enforcement.
- [ ] For every Firebase product in scope, record whether App Check enforcement
      is already enabled, monitoring only, or blocked. Enable enforcement in a
      staged manner only after valid-traffic metrics and rollback steps are
      reviewed; verify callable-level enforcement remains active throughout.
- [ ] Quotas, provider limits, budgets/alerts, rate limits, abuse controls, and
      operational dashboards cover the planned cohort size.
- [ ] Production privacy/support/coaching pages resolve over valid HTTPS and
      match the reviewed source. App privacy answers and beta disclosures match
      actual runtime behavior.
- [ ] Backend deployment and rollback have immutable source/digest binding,
      least-privilege operator access, independent review, and successful
      readback. Never use blanket Firebase deployment for convenience.
- [ ] Compare observed Day-0/Day-1/Day-7 and commercial signals with the
      predeclared thresholds in [`AppStore/launch-gates.md`](../AppStore/launch-gates.md).
      Do not scale acquisition on an underpowered or incomplete cohort.

### Stage D decision

- [ ] The open-beta cohort size and ramp schedule are approved.
- [ ] No open P0/P1 exists; support and rollback capacity match the ramp.
- [ ] Release owner: `____`
- [ ] Independent verifier: `____`
- [ ] Decision/evidence link: `____`

## 8. Stage E — GA / App Store release

- [ ] The authoritative readiness run exits zero for the immutable candidate
      and validates the retained release-evidence run:

      ```bash
      export NOUM_RELEASE_EVIDENCE_RUN_DIR=/secure/noum-release-evidence/rc-<build>
      ./tools/coach-arena/run.sh app-path
      ./tools/coach-arena/run.sh readiness
      ./tools/coach-arena/run.sh readiness --probe-live
      ```

- [ ] All five managed external artifacts are accepted: live-provider sweep,
      professional-coach calibration, longitudinal real-user transfer,
      same-build physical TestFlight QA, and operational launch checklist.
- [ ] Every action in
      [`docs/MANUAL_LAUNCH_ACTIONS.md`](MANUAL_LAUNCH_ACTIONS.md) is closed for
      the exact candidate, including independent verification.
- [ ] App Store Connect metadata, screenshots/previews, category, age rating,
      review notes/demo access, privacy nutrition labels, export compliance,
      content rights, support/marketing/privacy URLs, territories, price,
      subscription group, trial, and reviewer contact are complete and match
      the app.
- [ ] Sign in with Apple, Google/guest paths in scope, purchases, restore,
      subscription-state transitions, account deletion, and support escalation
      pass on the App Review build.
- [ ] App Check production providers are registered and healthy; production
      enforcement decisions are recorded per Firebase product. No active debug
      token is accepted as GA device evidence.
- [ ] Production Firestore rules/functions/indexes/IAM have been deployed only
      through the reviewed guarded path and read back. Release-disabled
      capabilities remain disabled until their own gates pass.
- [ ] Crash/hang, backend, auth, App Check, provider, cost, support, and product
      trust dashboards are ready; alert recipients and on-call owner are named.
- [ ] The staged App Store release strategy is set. Prefer phased release where
      operationally appropriate; record who may pause it.
- [ ] The final release notes list the exact build and do not overclaim coaching
      effectiveness, certainty, or production evidence.
- [ ] Release owner and independent verifier sign the final `GO`. App Store
      submission/release references the exact processed build in this record.

## 9. Post-promotion monitoring

Perform this after every external cohort increase and after GA.

| Window | Required review |
|---|---|
| First 2 hours | Launch/login, crashes/hangs, App Check/auth rejection, callable health, transcription, purchases, deletion, support queue, unexpected spend. |
| 24 hours | Device/OS distribution, failed journeys, consent/privacy reports, quota/rate limiting, provider latency, coaching complaints, P0/P1 triage. |
| 72 hours | Retention denominators, repeat failures, refunds, account lifecycle, accessibility reports, data/export/deletion completion, rollback readiness. |
| 7 days | Cohort outcomes, negative outcomes, Day-1/Day-7 signals when mature, cost/margin, support themes, accepted-risk review, next ramp decision. |

- [ ] Record the metrics source, window, denominator, version/build, storefront,
      and cohort for every launch/growth claim.
- [ ] Do not mix candidates or treat an incomplete retention window as a pass.
- [ ] Record `continue`, `hold`, `reduce cohort`, `pause distribution`, or
      `rollback/disable` with owner, timestamp, and evidence.

## 10. Immediate stop and rollback triggers

Pause promotion or distribution immediately when any of these is credible:

- cross-account data exposure, unauthorized access, secret leakage, or privacy
  behavior that differs from consent/disclosure;
- data loss/corruption, account deletion that falsely reports success, or
  purchases/entitlements that charge or deny access incorrectly;
- widespread launch, sign-in, App Check, transcription, callable, or core
  practice failure;
- a crash/hang regression in a primary journey or an accessibility regression
  that blocks a critical action;
- coaching that invents evidence, makes unsafe/unsupported claims, repeatedly
  misclassifies semantic speech as filler, or applies unfair punishment;
- unexplained spend, abuse, quota exhaustion, or production traffic that cannot
  be attributed to the approved app/environment;
- inability to observe, support, disable, or roll back the affected capability.

When triggered:

1. Pause the TestFlight public link, cohort ramp, phased App Store release, or
   affected capability using the approved operator path.
2. Preserve redacted logs and evidence; do not destroy incident context.
3. Contain security/privacy exposure and rotate or revoke credentials through
   the provider, never by committing replacements.
4. Roll back or disable only through the reviewed source-bound procedure in
   [`docs/PRODUCTION_READINESS_RUNBOOK.md`](PRODUCTION_READINESS_RUNBOOK.md).
5. Notify the release, security/privacy, support, and product owners appropriate
   to the incident.
6. Create a new candidate or explicitly re-run every affected gate. Do not
   resume on verbal assurance alone.

## 11. Authoritative references

- [`docs/MANUAL_LAUNCH_ACTIONS.md`](MANUAL_LAUNCH_ACTIONS.md) — external
  account, security, Apple, Firebase, upload, coaching, and sign-off actions.
- [`docs/PRODUCTION_READINESS_RUNBOOK.md`](PRODUCTION_READINESS_RUNBOOK.md) —
  technical readiness, signing/archive, cloud operations, social cutover, and
  definition of ready.
- [`docs/PRODUCTION_EVIDENCE_COLLECTION.md`](PRODUCTION_EVIDENCE_COLLECTION.md)
  — source-bound evidence creation, validation, promotion, and chain of custody.
- [`docs/TESTFLIGHT_QA.md`](TESTFLIGHT_QA.md) — exact same-build physical-device
  hardware and lifecycle QA.
- [`AppStore/launch-gates.md`](../AppStore/launch-gates.md) — real-user and
  growth thresholds; these are operating gates, not current claims.
- [`docs/M15_release_audit.md`](M15_release_audit.md) — current product anti-goal
  and accessibility findings.
- [Firebase App Check with App Attest](https://firebase.google.com/docs/app-check/ios/app-attest-provider)
  — production provider registration and client setup.
- [Firebase App Check debug provider](https://firebase.google.com/docs/app-check/ios/debug-provider)
  — local debug-token handling and explicit production warning.
- [Firebase App Check enforcement](https://firebase.google.com/docs/app-check/enable-enforcement)
  — metrics-first, per-product enforcement workflow.
- [Firebase project environment guidance](https://firebase.google.com/docs/projects/dev-workflows/general-best-practices)
  — isolate development and production resources.
- [Apple App Attest preparation](https://developer.apple.com/documentation/DeviceCheck/preparing-to-use-the-app-attest-service)
  — capability and production entitlement boundary.
