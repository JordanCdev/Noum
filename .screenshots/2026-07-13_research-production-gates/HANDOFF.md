# Run: 2026-07-13 · branch:ux-overhaul · HEAD b05258ab · research production gates

## Mode

light

## Changes shipped (this run)

- `Noum/ReviewExperimentContract.swift:59` — added fail-closed Test B assignment, rendered exposure, bounded segmentation, and later-rep attribution.
- `Noum/GoalStyleCalibration.swift:11` — added a calibration-only deterministic score candidate with missing-evidence and external evidence-package gates.
- `tools/coach-arena/runners/live_evidence.py:52` — added atomic source-bound live-provider capture and publication.
- `tools/release-evidence/release_evidence.py:258` — added source-bound external evidence collection, validation, and guarded promotion.
- `scripts/social-cutover-credentials.mjs:30` — added a gcloud-user credential mode that is structurally read-only.
- `scripts/verify_deepgram_endpoint.sh:22` — made the active unauthenticated credential leak return a failing process status.

## Screenshots

- `01_home_top.png` — Home tab, current stakeholder-prep state.
- `02_train_top.png` — Train tab and finalizer-owned recommended rep.
- `03_review_top.png` — Review tab, recent movement and replay entry points.
- `04_profile_top.png` — Profile tab, qualitative goal target and bounded outcome question.
- `05_settings_top.png` — Settings tab, practice and language controls.

All five deep links rendered the intended tab with no blank, crash, splash, or navigation regression. Test B is inactive by default, so this light sweep correctly shows the shipping outcome loop rather than manufacturing a control assignment.

## VISION gap

The local product now has coherent goal-to-evidence-to-next-rep behavior and production-shaped experiment/evidence contracts. It still cannot claim validated transformation or launch readiness: the numeric candidate has no professional calibration, Test B has no approved allocation or population analysis, the legacy AWS endpoint remains an active credential leak, the social cutover is not authorized, and signed Apple/TestFlight release services are not configured.

## Next steps to reach desired state

1. Revoke the exposed Deepgram credential and protect or disable the legacy AWS endpoint, then rerun `scripts/verify_deepgram_endpoint.sh`.
2. Configure an eligible Apple Developer team, provisioning, App Store Connect, and TestFlight build before physical QA can count as release evidence.
3. Bind a deidentified source-evidence package and collect independent professional calibration through the documented evidence workflow.
4. Approve the legacy social-data disposition before any protected cutover apply or purge.

## Regressions checked

- Five-tab navigation — all five screenshots — no regression.
- Home-to-recommended-rep hierarchy — `01_home_top.png` and `02_train_top.png` — one dominant next action remains clear.
- Review/Profile qualitative progress — `03_review_top.png` and `04_profile_top.png` — no public 0–100 goal-style identity score appears.
- Settings practice/language controls — `05_settings_top.png` — no layout or launch regression.

## Surfaces needing visual verification (cloud → local queue)

- Test B generic-review Summary card under an approved non-production Remote Config allocation.
- Signed physical-device fallback notice, permissions, VoiceOver, Dynamic Type, and reduced-motion matrix.
- Actual TestFlight installation, Live Activity, latency, soundscape, purchase, and restore evidence.

## For next run

- **If cloud**: adjudicate provider capacity and prepare deidentified reviewer/beta protocols without creating placeholder evidence.
- **If local**: capture TestFlight physical-device evidence only after Apple provisioning and the legacy credential incident are closed.
