# Screenshot Handoff - Sudden Death Results

## Run context

- Date: 2026-05-27
- Branch: Redesign
- Capture mode: targeted UI-test capture, requested for this result flow
- Device: iPhone 17 simulator

## What was implemented

- Made completed Sudden Death result states deterministic in DEBUG/UI tests so the screen can be regenerated instead of relying on temporary screenshots.
- Preserved older stored runs when newer points and multiplier fields are absent.
- Replaced the length-based `Articulate` multiplier label with the truthful `Developed` label.
- Changed failed run path markers from a negative `x` to a neutral stop marker.
- Collapsed long run paths into a scalable cleared-tier summary and renamed the metric row to `Cleared`.

## Captured screens

- `28-sudden-death-result-filler.png`: short run stopped by a filler, showing 275 points, two cleared tiers, and recent-run comparison.
- `29-sudden-death-result-filler-lower.png`: lower portion of the short-run result, including full recent history and replay controls.
- `30-sudden-death-result-long.png`: long run with a new best, truthful multipliers, and the collapsed run path.
- `31-sudden-death-result-long-lower.png`: lower portion of the long-run result, including comparison copy, XP, and replay controls.

## Product decisions

- Points, tier progress, time survived, and replay remain the Sudden Death motivation loop rather than a 1-10 coaching score.
- No word-choice multiplier was added yet: vocabulary or language-strength rewards should wait for a real analysis signal.
- Recent runs remain visible as comparative motivation, while the run path no longer attempts to display unlimited individual rounds.

## Verification

- Passed `ScreenshotTour.testCaptureSuddenDeathResults()` on the iPhone 17 simulator.
- Visually inspected all four captured PNGs for layout, truncation, and control visibility.
- Focused unit verification covers points/multiplier behavior and backward-compatible history decoding.

## Next visual questions

- Decide whether XP should remain on the game result or be subordinated further to the points loop.
- Evaluate whether recent-run comparison should stay directly on the post-run screen after broader playtesting.
- Add a true word-choice or clarity reward only when the scoring signal can explain itself reliably.
