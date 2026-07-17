# Run: 2026-07-17 · branch:ux-overhaul · release commit 86334ed45 · Ask Noum v2 production deployment

## Mode

targeted production verification

## Changes

- Added a committed, source-bound release wrapper limited to `coachChatV2` and `coachChatAvailability`.
- Kept blanket Functions, Firestore, social, and competitive deployment paths closed.
- Revoked the two previously exposed Firebase CLI sessions and authenticated fresh as `jordancoaten98@gmail.com`.
- Restored the documented least-privilege Cloud Build grants to the default build identity: source-bucket object viewer, regional `gcf-artifacts` writer, and project log writer.
- Deployed the exact two-function source from commit `86334ed4556b40d34fd3696b7bc17e7dfab1e422` with Functions SHA-256 `b0a09d34ee090fdabb31a106554e531fee0a3c57f0b66a935b485c14dcb132eb`.

## Production readback

- `coachChatV2`: `ACTIVE`, Node 22, `europe-west2`, source hash `f5c8c1a1b509fb519a749a48b79337357cbf6634`.
- `coachChatAvailability`: `ACTIVE`, Node 22, `europe-west2`, same source hash.
- Both use `noum-coach-runtime@noum-d0b6f.iam.gserviceaccount.com`.
- Unauthenticated endpoint probes fail closed with HTTP 403/401.

## Screenshot

- `01_ask_noum_after_deploy.png` — the installed iPhone 17 simulator build opens the typed Ask Noum route without the backend-version banner and with the composer enabled.

## Verification

- Functions lint passed.
- Functions tests passed 161/161 on every release attempt.
- Scoped-deploy contracts passed 8/8.
- Static cloud source validator passed all four source assertions; its Python contract suite passed 19/19 before release.
- The first cloud build exposed missing source-bucket access; the second exposed missing Artifact Registry/logging permissions; the third completed both function operations after only the documented narrow grants were restored.
- Live Firebase inventory readback confirms both selected functions active.

## Remaining gaps

- No generated message has yet been sent from the real composer after deployment.
- Reporter acceptance, professional review, mixed v1/v2 smoke, rollback proof, signed physical-device/TestFlight verification, and the external evidence set remain open.
- Production readiness remains NO-GO; this deployment closes the verified availability blocker only.
