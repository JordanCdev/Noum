# Run: 2026-07-14 · branch:ux-overhaul · HEAD 77b1361a · preserve exact Timed recommendation demand

## Mode
light

## Changes shipped (this run)
- `Noum/PracticeModeSelectionView.swift:589` — render the exact recommended Timed difficulty in the existing Train prescription card.
- `Noum/TimedPracticeView.swift:724` — keep prescribed difficulty instance-local, visible, and separate from the user's saved setting.
- `Noum/PracticeSupport.swift:8972` — persist schema-versioned prescribed/executed demand and require an exact match before an outcome is treated as followed.
- `NoumUITests/RecommendationSurfaceRoutingUITests.swift:88` — assert the seeded exact difficulty and real Timed prompt route serially.

## Screenshots
- `01_home_top.png` — account-bootstrap recovery surface; Home did not render.
- `01_train_top.png` — account-bootstrap recovery surface; Train did not render.
- `01_review_top.png` — account-bootstrap recovery surface; Review did not render.
- `01_profile_top.png` — account-bootstrap recovery surface; Profile did not render.
- `01_settings_top.png` — account-bootstrap recovery surface; Settings did not render.
- `02_train_seeded_beginner.png` — seeded Train prescription card visibly renders `Medium · 30 sec` above the existing primary action.

## VISION gap
The recommendation UI now makes exact Timed demand legible and the local outcome ledger can verify adherence without inferring from current settings. This is still local product substrate: the sweep does not prove the accepted route on a normal account, deployed cross-device persistence, professional coaching validity, or real-user improvement.

## Next steps to reach desired state
1. Repair or provision the simulator account bootstrap so unseeded five-tab visual regression captures can reach their requested destinations.
2. Restore a current clean complete-scheme regression after isolating parallel account/bootstrap contamination.

## Regressions checked
- Train prescription hierarchy — `02_train_seeded_beginner.png` — no visual regression; the demand capsule is restrained and readable.
- Train→Timed route — `/tmp/NoumExactDemandRouteUI.xcresult` — serial UI test passed and retained the prompt destination.
- Unseeded five-tab launch — `01_*_top.png` — blocked by `Your coaching profile is not ready`; no tab-level conclusion is possible.

## Surfaces needing visual verification (cloud → local queue)
- Home's prescribed Timed recommendation with a normal account projection.

## For next run
- **If cloud**: extend pure routing and persistence contracts only; do not treat simulator frames as external evidence.
- **If local**: recapture all five ordinary tab tops after the bootstrap issue is isolated.
