# Run: 2026-07-14 · branch:ux-overhaul · HEAD 4da56e3e · duration-fair speech coaching evidence

## Mode

light

## Changes shipped (this run)

- `Noum/BaselineEngine.swift:964` — exposes the existing 15-second / 20-word quantity floor for non-baseline evidence checks and rejects non-finite duration.
- `Noum/NextActionEngine.swift:650` — requires qualifying quantity plus finite WPM before an immediate severe-pace prescription.
- `Noum/PracticeSupport.swift:7063` — normalizes Timed and Ah Counter filler scoring, XP, feedback, categories, moments, insights, and practice trends by duration while preserving exact-zero evidence and Sudden Death semantics.
- `NoumTests/NoumTests.swift:1337` and `NoumTests/NoumTests.swift:6484` — cover pace evidence floors, established-evidence fall-through, equivalent filler rates, concentrated rates, sub-floor withholding, and Sudden Death zero tolerance.
- `docs/RESEARCH_IMPLEMENTATION_AUDIT.md` — records the closed local fairness gap and the still-incomplete raw-count goal/trajectory path.

## Screenshots

- `01_home_top.png` — first-run goal selection; Home tab did not become reachable through the deep link.
- `01_train_top.png` — invalid dark/incomplete simulator frame after both 3-second and 8-second waits; not accepted as visual evidence.
- `01_review_top.png` — first-run goal selection; Review tab did not become reachable through the deep link.
- `01_profile_top.png` — first-run goal selection after the longer recapture; Profile tab did not become reachable through the deep link.
- `01_settings_top.png` — first-run goal selection; Settings tab did not become reachable through the deep link.

The implementation changes no layout. This light sweep therefore proves only
that the fresh build launches and that first-run goal selection renders; it does
not prove the five tab tops or any post-evaluation copy state.

## VISION gap

The touched evaluation path is now fair across ordinary and long-form speech,
which supports believable improvement and coaching trust. The qualitative goal
read still consumes duration-biased raw filler counts through
`UserTrajectoryCache`, `TrajectorySummaryBuilder`, and `CoachReasoningPass`, so
it is not yet coherent enough to select the next rep. The standalone Pace
Training surface also lacks durable recommendation/outcome attribution.

## Next steps to reach desired state

1. Normalize the goal/trajectory evidence pack through the existing `FillerBurden` policy before connecting `GoalOutcomeRead.nextDimension` to `NextActionEngine`.
2. Add durable `PracticeSession` and recommendation outcome attribution to standalone Pace Training before considering it as an adaptive destination.
3. Run a seeded or fully completed-onboarding visual tour when UI-facing evaluator copy changes; the current light deep-link path is gated by first-run onboarding.

## Regressions checked

- Timed/Ah evaluation and immediate next-action routing — 53 unique focused tests — no regression.
- Complete Noum unit target — 4,075 unique tests / 4,090 executions — zero failures or skips.
- Fresh Debug simulator build — succeeded on iPhone 17 / iOS 26.4.
- First-run goal selection — Home/Review/Profile/Settings captures — rendered consistently.
- Five tab tops — light sweep — not verified because first-run onboarding retained route ownership; Train additionally produced an invalid dark frame.

## Surfaces needing visual verification (cloud → local queue)

- Timed and Ah Counter result copy for low-rate long speech, concentrated filler speech, and sub-15-second speech when a deterministic audio fixture is available.
- Five ordinary tab tops from a seeded/completed-onboarding account.

## For next run

- **If cloud**: normalize trajectory/goal filler evidence and add pure duration-equivalence contracts.
- **If local**: use a seeded account to verify evaluator result copy and rerun the five-tab sweep.
