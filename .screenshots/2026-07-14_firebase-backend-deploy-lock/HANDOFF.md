# Run: 2026-07-14 · branch:ux-overhaul · HEAD 77352b03 · Close checked-in Firebase backend deployment bypasses

## Mode
light — capture skipped because this run changed only deployment lifecycle hooks,
readiness validation, and tests; no app UI changed.

## Changes shipped (this run)
- `firebase.json:15` — makes the existing non-executing release blocker the first hook for every checked-in Functions codebase.
- `firebase.json:23` — applies the same first-hook refusal to Firestore rules/index deployment.
- `scripts/release-backend-deploy.test.mjs:111` — pins all Functions and Firestore targets closed while keeping Hosting independent.
- `tools/coach-arena/runners/readiness_gate.py:3886` — makes missing, altered, reordered, or partially applied deployment locks fail static readiness.
- `tools/coach-arena/runners/test_readiness_gate.py:2695` — covers the fail-closed hook matrix and Hosting isolation.

## Screenshots
- None. Simulator images cannot verify deployment lifecycle enforcement.

## VISION gap
The checked-in Firebase CLI path can no longer deploy disabled social or
competitive backend authority accidentally. Trusted competitive evidence,
professional calibration, production cutover, independent authorization,
immutable artifact binding, and live verification remain absent.

## Next steps to reach desired state
1. Close the credential incident and collect independently trusted deployment authorization.
2. Build and verify one immutable source-bound deployment artifact only after the evaluator, retention, friendship, and cutover gates are satisfied.
3. Replace both backend hooks atomically in a separately reviewed change; never remove only one.
4. Deploy and verify the current privacy body through the independently authorized Hosting path.

## Regressions checked
- Deploy-blocker contracts — 7/7 passed.
- Readiness-gate contracts — 86/86 passed.
- Functions authority contracts — 109/109 passed; lint and TypeScript build passed.
- Cloud operations and operational static readiness — 16/16 and 22/22 passed.
- App visuals — not applicable; no view, navigation, accessibility, localization, or motion source changed.

## Surfaces needing visual verification (cloud → local queue)
- None introduced by this run.

## For next run
- **If cloud**: continue source-local fairness or calibration-custody hardening without manufacturing external evidence.
- **If local**: no visual sweep is needed until a rendered app surface changes.
