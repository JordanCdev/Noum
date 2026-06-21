# Run: 2026-06-21 - ux-overhaul - de38004 - Path marker replacement

## Mode
- noum-screenshots light mode plus targeted Path Journey UI capture.
- Simulator: iPhone 17.

## Changes shipped
- `Noum/PathJourneyView.swift`: replaced the blue character/orb walker with a grounded current-position trail marker.
- `Noum/JourneyDayBloomRatchet.swift`: updated the day-bloom contract comment to match the marker language.
- `NoumUITests/ScreenshotTour.swift`: added a targeted Path capture that opens Home, taps Path, asserts the Journey screen, and captures top plus scrolled states.

## Screenshots
- `path-marker-top.png`: Path Journey top state with the new trail marker.
- `path-marker-bottom.png`: scrolled Path Journey state with marker, why card, landmarks, and along-the-way surface visible.
- `path-top.png`: earlier diagnostic capture that landed on Home.
- `path-detail-openurl.png`: earlier diagnostic capture showing the iOS open-url confirmation.

## VISION gap
The current-position affordance now supports progress and trust without introducing a mascot-like blue orb. The broader landscape illustration still has a simple storybook quality; future designer polish should improve atmosphere without adding visual noise.

## Regressions checked
- Release app build succeeded for iPhone 17 simulator.
- Targeted UI test passed: `ScreenshotTour/testCapturePathJourneyOnly`.
- Visual capture confirms the blue orb is gone, Path navigation works from Home, and the existing journey cards still render.

## Remaining polish
- The floating Back button can overlap the artwork after scrolling. It is pre-existing relative to this marker pass and should be handled as navigation chrome polish.
- Full detailed screenshot tour was not rerun for this small Path-artwork change.
