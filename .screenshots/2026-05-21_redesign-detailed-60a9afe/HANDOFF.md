# Run: 2026-05-21 · branch:Redesign · HEAD 60a9afe · detailed sweep request — captured light only, tour blocked

## Mode
detailed (requested) — degraded to light because the Noum test target fails to compile

## Changes shipped (this run)
- None — capture-only session. App build (`** BUILD SUCCEEDED **`) and install on `iPhone 17 / iOS 26.4 (BD2DE1AB-…)` were clean.

## Screenshots
- 01_home_top.png — Home tab. Sudden Death "Start clean." coach card, journey card (Mission 4/20, First IM rep), tab strip visible.
- 01_train_top.png — Mode picker ("Pick your next rep"). Sudden Death is the recommended/selected card.
- 01_review_top.png — Review tab. Sessions = 2, Avg 5.0, Strongest = Sudden Death; Replay Your Misses + Mistakes to Fix surfaces populated.
- 01_profile_top.png — Profile. Speaker stage "Beginner Speaker II", 1,388 XP, Speaking Rating 612, working-on chip.
- 01_settings_top.png — Settings. Practice defaults + Voice cues / Real-time filler highlight toggles.
- tour_*.png — **NOT CAPTURED.** UI-test tour aborted (see Blocked).

## VISION gap
Light captures only verify the 5 tab roots. The 22-surface tour (in-rep states, mode setup screens, Lessons, Speech Projects, League, Path Journey, Goal Refresh sheet, Notification pre-prompt) is currently unverifiable visually because the test target won't build. Means we can't visually confirm post-M14 redesign coverage on advancement surfaces this session.

## Next steps to reach desired state
1. Fix test-target compile errors in `NoumTests/NoumTests.swift` — add `@MainActor` to the proof-moments tests introduced in 60a9afe. Specifically the methods around `freshStore(account:)` (line 5804), `recordPersistsSingleProof()` (5828), `recordIsIdempotentOnSessionID()` (5838), and any peers that call `ProofMomentStore.record/remove` or read `.records`. Errors look like:
   - `5808:16 error: call to main actor-isolated initializer 'init(defaults:accountIDProvider:)' in a synchronous nonisolated context`
   - `5832:15 error: call to main actor-isolated instance method 'record(_:for:at:)' in a synchronous nonisolated context`
   - `'records' can not be referenced from a nonisolated context` (multiple sites in `#expect` macro expansions)
2. Re-run `xcodebuild test -only-testing:NoumUITests/ScreenshotTour/testCaptureAdvancementSurfaces` to get the 22 tour PNGs.
3. Append tour captures to this folder (or a fresh-dated folder) and update this HANDOFF.

## Regressions checked
- Home / Train / Review / Profile / Settings tab tops — all render cleanly, layouts intact, no obvious M14 follow-on regressions in the static frames.

## Surfaces needing visual verification (cloud → local queue)
- All 22 tour surfaces (mode setup screens, in-rep dynamic states, Lessons, Speech Projects, League, Path Journey, Goal Refresh sheet, Notification pre-prompt). Cloud should not attempt — these need the local simulator + a passing test target.

## For next run
- **If cloud**: fix the `@MainActor` annotations on the new proof-moments tests in `NoumTests/NoumTests.swift` (no simulator required to compile-check; can validate with `xcodebuild build-for-testing`). Don't change the production `ProofMomentStore` actor isolation — the tests are what need to enter MainActor context.
- **If local**: after the test target compiles, re-run the detailed tour and capture the missing 22 frames. Then this folder graduates from light → detailed.
