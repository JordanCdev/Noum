# Run: 2026-07-17 · branch:ux-overhaul · HEAD 5c9348b3d · Ask Noum backend-version copy clarification

## Mode

light

## Changes in this working tree

- `Noum/AskNoumView.swift` — clarifies that the unavailable coaching service is a backend rollout issue and that updating the app will not fix it.
- `Noum/AskNoumStore.swift` — uses the same precise explanation in retained-message recovery notices.
- `NoumTests/ProductionReadinessOverhaulTests.swift` — locks the user-facing copy for both the view state and store recovery paths.
- `docs/CURRENT_STATE.md` and `docs/RESEARCH_IMPLEMENTATION_AUDIT.md` — record the live Firebase inventory and retain the production-readiness blocker.

## Screenshots

- `01_home_top.png` — Home top rendered.
- `01_train_top.png` — Train top rendered.
- `01_review_top.png` — Review top rendered.
- `01_profile_top.png` — Profile top rendered.
- `01_settings_top.png` — Settings top rendered.
- `02_ask_noum_backend_version.png` — typed Ask Noum route rendered with the corrected backend-unavailable explanation.

All six final frames were inspected. No blank frame, bootstrap gate, crash
surface, or wrong deep-link destination was observed. The Ask Noum frame shows:
“This build’s Ask Noum service isn’t live yet. Updating the app won’t fix it.”

## VISION gap

Ask Noum still cannot provide a live expert-coach response because the production
Firebase project does not expose `coachChatV2`. The app now explains the problem
accurately and preserves the user's message, but fail-closed copy is not a
substitute for an available, high-quality coaching experience.

## Next steps to reach desired state

1. Perform the authorized backend-first deployment of `coachChatV2` and the matching `coachChatAvailability` contract in `europe-west2`.
2. Read back the deployed function inventory and verify request schema 2 / policy `noum-coach-v2` before enabling the client path.
3. Run App Check-valid live acceptance cases and independently assess reply concision, specificity, naturalness, and coaching usefulness.
4. Keep production readiness at NO-GO until the required external artifacts exist.

## Regressions checked

- Five primary tab tops rendered from the normally signed Debug simulator build.
- The typed Ask Noum deep link reached the expected conversation and displayed the corrected failure state.
- The complete `CoachChatWireContractTests` suite passed 44/44, including `missingV2BackendUsesSpecificRecoverableCopy`, in `/tmp/NoumCoachWireCopy-20260717.xcresult`.
- A read-only `firebase functions:list --project noum-d0b6f --json` showed only `coachChat`, `coachChatAvailability`, `deleteAccount`, and `transcriptionToken`; `coachChatV2` is absent.

## Surfaces needing visual verification

- A successful App Check-valid live `coachChatV2` reply after deployment.
- Long generated conversations, Dynamic Type, reduced motion, VoiceOver, and physical-device presentation.

## For next run

- Deploy only with explicit release authorization and rollback controls; then capture live reply evidence rather than treating local tests or failure-state screenshots as production proof.
