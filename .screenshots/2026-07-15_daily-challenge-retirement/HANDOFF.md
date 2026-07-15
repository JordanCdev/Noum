# Run: 2026-07-15 · branch:ux-overhaul · HEAD 46bb1c9b · retire the unreachable Daily Challenge lifecycle

## Mode
light

## Changes shipped (this run)
- `Noum/DailyChallengesManager.swift:49` — made compatibility-manager initialization side-effect free and removed its session subscription.
- `Noum/NotificationManager.swift:73` — retained one exact retired identifier for pending/delivered upgrade cleanup while removing every re-arm path.
- `Noum/AccountDataRegistry.swift:411` — preserved legacy export/deletion coverage without hydrating the retired manager.
- `NoumTests/RetiredDailyChallengeLifecycleTests.swift:20` — added source contracts for the production, notification, and account-data boundaries.

## Screenshots
- `01_home_top.png` — blocked by “Your coaching profile is not ready”; Home did not render.
- `01_train_top.png` — same account-persistence blocker; frame also rendered partially black.
- `01_review_top.png` — same account-persistence blocker; Review did not render.
- `01_profile_top.png` — same account-persistence blocker; frame also rendered partially black.
- `01_settings_top.png` — same account-persistence blocker; Settings did not render.

No mounted UI changed in this slice. These captures prove the build installed and launched, but they do not prove any tab surface or the retired notification cleanup.

## VISION gap
M14 requires source-bound physical TestFlight QA and operational evidence. Local source now prevents new Daily Challenge lifecycle work and removes the exact legacy notification request on launch/refresh, but this simulator state cannot prove an upgrade from a build that had already armed the repeating request. Production readiness remains NO-GO at 18/100 with 0/5 required external artifacts.

## Next steps to reach desired state
1. Verify on a physical upgrade install that pending and delivered `noum.daily.challengeExpiry` requests are removed while unrelated notification identifiers survive.
2. Repair or reset the local simulator account/keychain state before the next visual sweep; do not treat these intercepted frames as UI regression evidence.
3. Fix Roleplay’s “same objection, slower” path in `Noum/RoleplayView.swift` so the retry retains the actual objection instead of selecting a fresh one.

## Regressions checked
- Retirement/Home/account focused selection — 30 unique tests passed with zero failures or skips.
- Complete `NoumTests` target — 4,169 unique tests / 4,186 device executions passed with zero failures or skips.
- Five-tab light sweep — blocked on every route by account persistence; no visual-regression claim.

## Surfaces needing visual verification (cloud → local queue)
- Home, Train, Review, Profile, and Settings tab tops after simulator account recovery.
- Physical-device pending/delivered notification cleanup after upgrading from a build that armed the retired identifier.

## For next run
- **If cloud**: audit and test Roleplay objection continuity without claiming device behavior.
- **If local**: recover the simulator account state, repeat the five-tab sweep, then run the notification upgrade check on physical TestFlight hardware when an eligible build exists.
