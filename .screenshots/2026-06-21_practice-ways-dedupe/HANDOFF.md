# Run: 2026-06-21 · branch:ux-overhaul · HEAD ddff056 · Practice ways dedupe

## Mode
light

## Changes shipped (this run)
- `Noum/PracticeModeSelectionView.swift` — the recommended-rep hero now keeps one primary action only; the duplicate `Pick another` affordance is removed, leaving `Other ways to practice` as the single catalog-expansion control.
- `NoumUITests/NoumUITests.swift` / `NoumUITests/ScreenshotTour.swift` / `NoumUITests/M17VerificationTour.swift` — practice-mode reveal helpers expand through `practiceModes.otherWays`.
- `NoumTests/NoumTests.swift` — copy contract no longer expects the removed escape label.

## Screenshots
- Light screenshot sweep was not captured: the follow-up simulator UI command was blocked by the Codex usage limit before it could run.

## VISION gap
The Train picker should feel like a coach prescription with a calm escape route, not a dashboard with duplicate commands. This change keeps the recommendation decisive while preserving secondary mode discovery.

## Next steps to reach desired state
1. Run the light screenshot sweep locally when quota is available and verify the Train picker has one visible alternatives control.
2. Re-run `NoumUITests/NoumUITests/testPracticeModesOpenAvailableScreens` if simulator access is available.

## Regressions checked
- Practice-mode copy contract — `PracticeModePrescriptionCopyTests` passed.
- Source hygiene — `git diff --check` passed.

## Surfaces needing visual verification (cloud/local queue)
- `noum://practice` top of Train picker after seeded launch.
- Expanded `Other ways to practice` section.

## For next run
- **If cloud**: review the code/test diff only; no simulator screenshots.
- **If local**: capture Train picker collapsed and expanded states.
