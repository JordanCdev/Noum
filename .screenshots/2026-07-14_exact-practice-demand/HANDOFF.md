# Run: 2026-07-14 · branch:ux-overhaul · HEAD ea7a3845 · exact practice-demand provenance

## Mode

light

## Changes shipped (this run)

- `Noum/PracticeSupport.swift` — current Timed, Pressure Drill, and Speech Project demand now has one versioned session value; exact-demand comparison fails closed for legacy history.
- `Noum/SpeechRecognizerViewModel.swift` and practice views — the demand that actually executed is captured before recording and persisted through the existing session owner.
- `Noum/ShareableSessionCard.swift` — current Timed shares show the persisted difficulty; legacy unknown-demand shares stay generic instead of claiming a one-minute rep.
- `firestore.rules` — current metric provenance and strictly mode-coupled demand are admitted by the private-session validator.

## Screenshots

- `01_home_top.png`
- `01_train_top.png`
- `01_review_top.png`
- `01_profile_top.png`
- `01_settings_top.png`

All five captures reached the same account bootstrap recovery surface: “Your coaching profile is not ready” / “Noum couldn't save this account on this device. Try again.” The requested tab tops and the changed share-card label were therefore not visually verified. Two frames also contain black/redacted rendering regions from the failed launch state and are not usable product baselines.

## VISION gap

Exact executed demand now supports believable comparison, but local screenshots do not prove the changed share-card presentation because this simulator account cannot complete profile bootstrap. Home's suggested Timed difficulty also remains display-only at routing time; this pass records what actually ran and does not claim exact prescribed-difficulty adherence.

## Next steps to reach desired state

1. Repair or reset the light-sweep simulator account bootstrap, then recapture the five tab tops.
2. Add a deterministic share-card capture for current Hard Timed, current Speech Project, and legacy unknown-demand sessions.
3. Extend the existing recommendation launch projection with bounded prescribed demand before treating a difficulty-specific recommendation as followed.

## Regressions checked

- App install and launch — all five files were created, but profile bootstrap blocked navigation; no tab-level regression conclusion is possible.
- Exact-demand logic — covered separately by the source-bound focused simulator test result; screenshots are not logic proof.

## Surfaces needing visual verification (cloud → local queue)

- Shareable Timed session card with exact current difficulty.
- Shareable legacy Timed session card without fabricated difficulty.
- Home, Train, Review, Profile, and Settings after account bootstrap succeeds.

## For next run

- **If cloud**: implement the mode-owner extension for prescribed Timed demand without adding a parallel route or store.
- **If local**: fix the simulator bootstrap state and capture deterministic current/legacy share cards.
