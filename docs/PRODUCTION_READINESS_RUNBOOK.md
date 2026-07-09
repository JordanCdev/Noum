# Noum Production Readiness Runbook

Source of truth: `docs/VISION.md`.

This runbook is for the M14 launch gate: Firestore rules, hosted privacy URL,
TestFlight, and proof that Chat with Noum is ready for production use. A green
local eval or smoke flow is evidence, but it is not enough to claim production
readiness.

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

## Local Evidence Path

```bash
./tools/coach-arena/run.sh app-path-source
xcodebuild test \
  -scheme Noum \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:NoumTests/CoachChatConversationArtifactDumpXCTest
./tools/coach-arena/run.sh app-path
./tools/coach-arena/run.sh readiness --no-fail
```

This proves the real Swift app path and trace quality. It does not remove any
VISION blockers unless the external sidecar artifacts below are present in
`NOUM_COACH_EVAL_DUMP_DIR` and pass the Swift manifest loader.

## Required Launch Evidence

| Blocker | Artifact | Must Prove |
|---|---|---|
| `noLiveProviderTranscriptSweep` | `coach-live-eval-v1.json` | Real provider transcript sweep over the required app-path fixtures, with `sourceGitCommit` and `sourceCoachFingerprint` matching the source sidecars. |
| `noProfessionalCoachCalibration` | `coach-chat-conversation-expert-calibration-results-v2.json` | Blinded professional-coach reviews for the required calibration packet, meeting the rubric and review-count floor. |
| `noRealUserLongitudinalTransferOutcomes` | `coach-real-user-transfer-outcomes-v2.json` | Closed-beta real-user transfer outcomes with follow-up delay, real-world moments, linked interventions, and evidence references. |
| `noRealDeviceTestFlightVerification` | `coach-real-device-testflight-qa-v2.json` | Physical-device TestFlight verification for `liveActivity`, `aiPromptLatency`, `soundscapeAudioSession`, and `paywallPurchase`. |
| `operationalLaunchChecklistIncomplete` | `coach-operational-launch-checklist-v2.json` | M14 launch checklist: Firestore rules, privacy URL, Settings privacy link, App Store privacy disclosures, TestFlight upload, and release-blocking bug triage. |

Do not create placeholder sidecars. `{}` files now fail the Python readiness
preflight, and missing proof should stay missing.

## UI Flow Boundary

The Maestro smoke flows are valuable, but they are smoke coverage:

```bash
bash maestro/run_chat_demo_smoke.sh
```

They cover:

- `maestro/chat_smoke.yaml`: Ask Noum type-chat happy path with deterministic markdown reply.
- `maestro/chat_reject_smoke.yaml`: deterministic rejection notice path.

They do not replace `coach-real-device-testflight-qa-v2.json`, which must cover
real-device TestFlight behavior for the launch surfaces listed above.

## Definition Of Ready

The launch bar is not "UI exists" or "tests pass." The product is production
ready only when:

- the app-path report passes local score, real-pipeline, and trace-quality gates
- the VISION readiness gate exits 0
- Maestro smoke flows pass on the installed simulator build
- real-device TestFlight evidence is attached
- external coach calibration and longitudinal user outcomes are attached
- the operational launch checklist is complete against the release candidate
