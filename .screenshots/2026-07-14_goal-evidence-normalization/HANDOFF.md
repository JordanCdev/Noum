# Run: 2026-07-14 · branch:ux-overhaul · HEAD 5bbb850b · Quantity-qualified goal and trajectory evidence

## Mode
light

## Changes shipped (this run)
- `Noum/UserTrajectorySnapshot.swift:40` — exposes the shared quantity floor and qualified filler burden on the existing latest-rep evidence pack.
- `Noum/UserTrajectoryCache.swift:312` — withholds WPM and recent filler trends when speech quantity is insufficient.
- `Noum/CoachReasoningPass.swift:107` — uses qualified filler rate and missing-evidence reads for goal reasoning.
- `Noum/TrajectorySummaryBuilder.swift:173` — labels the public weekly signal as filler rate and requires qualified weekly evidence.
- `Noum/NextActionEngine.swift:795` — passes finalized trend input into the existing drill engine deterministically.

## Screenshots
- `01_home_top.png` — Home tab, one-rep state with restrained evidence language.
- `01_train_top.png` — Train tab with the existing Timed fallback recommendation.
- `01_review_top.png` — Review tab, one-rep state correctly says there is not enough evidence for a pattern.
- `01_profile_top.png` — Profile tab with current coaching focus.
- `01_settings_top.png` — Settings tab, top of view.

## VISION gap
The five tab tops remain calm and cohesive, and the one-rep Review state avoids overclaiming. The desired believable-progress system is not fully closed: Summary hero, `CoachingPlanner`, and coach-context filler comparisons still need the same duration-fair boundary. Standalone Pace Training also lacks a canonical persisted mode/demand and followed-rep attribution.

## Next steps to reach desired state
1. Normalize the remaining Summary hero comparison in its existing state owner without introducing another metric store.
2. Extend the existing planner and coach-context projections to consume qualified filler burden.
3. Make the backend-schema and mixed-client decision required for durable Pace Training attribution before routing adaptive actions there.

## Regressions checked
- Home top — `01_home_top.png` — no clipping, overlay, or navigation regression.
- Train top — `01_train_top.png` — recommendation card and fallback explanation render coherently.
- Review top — `01_review_top.png` — insufficient-evidence copy is visible and appropriately cautious.
- Profile top — `01_profile_top.png` — goal and coaching-focus hierarchy remains intact.
- Settings top — `01_settings_top.png` — controls and tab bar render normally.

## Surfaces needing visual verification (cloud → local queue)
- Expanded Review progress with two qualified weeks, to verify the public `Filler rate` label and rate-per-minute example.
- A post-rep goal card for a sub-floor sample, to verify the insufficient-evidence state end to end.

## For next run
- **If cloud**: audit and normalize the remaining Summary/planner/coach-context comparisons with focused contracts.
- **If local**: seed two qualified weeks plus one sub-floor latest rep and capture expanded progress and Summary evidence states.
