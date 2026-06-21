# Run: 2026-06-21 · branch:ux-overhaul · HEAD de38004 · goal setup inline UX

## Mode

light, with targeted extra captures for the changed setup surfaces.

## Changes shipped (this run)

- `Noum/NoumApp.swift:160` — first-run setup now renders as the temporary app root instead of a full-screen cover over Home.
- `Noum/CoachingOnboardingView.swift:154` — first-run intro no longer says "Settings"; intro copy is friendlier and coach-led.
- `Noum/DeferredProfileCapture.swift:284` — goal refresh is now a direction-check flow with the same manager/state owner.
- `Noum/DeferredProfileCapture.swift:366` — added `GoalRefreshInlineCard`, with confirm, adjust, dismiss, edit, accessibility IDs, and reduced-motion-aware transitions.
- `Noum/ContentView.swift:287` — goal refresh no longer suppresses Home accessibility as a modal surface.
- `Noum/ContentView.swift:402` and `Noum/ContentView.swift:499` — due direction checks render at the top of Home, above the coach hero, so actions are visible without scrolling.
- `Noum/PathJourneyView.swift:478` — "Still true?" became "Check direction" and opens the same inline card instead of a sheet.
- `NoumUITests/ScreenshotTour.swift:212` — screenshot tour now names the forced surface `26-goal-refresh-inline`.
- `docs/GOAL_SETUP_DESIGN_ANIMATION_BRIEF.md:1` — shareable paid designer/animator brief added.

## Screenshots

- `goal-refresh-inline-fixed.png` — forced goal-refresh state. Direction check renders inline at top of Home; Adjust and Still right are visible and not blocked by the floating tab dock.
- `first-run-setup-root-final.png` — real first-run setup path. Setup appears as the app root, not as a popup over Home.
- `goal-refresh-inline.png` — failed intermediate capture; card was inline but too low and clipped by the bottom dock. Kept as evidence of the issue caught and corrected.
- `first-run-setup-root.png` — first capture before final rebuild; same visual result as final capture.

## VISION gap

The setup moment now better supports personalized coaching and coaching trust: it reads as an intake, not a generic configuration modal. The direction check is still a functional card rather than a fully polished motion concept; a designer/motion pass should refine its entry, edit transition, and confirm/dismiss behavior without adding spectacle.

## Next steps to reach desired state

1. Use `docs/GOAL_SETUP_DESIGN_ANIMATION_BRIEF.md` to hire a senior iOS product designer/motion designer for one focused sprint.
2. Stress-test the inline card with very long goal text and Dynamic Type sizes.
3. Replace any remaining goal/why capture sheets when they are part of the coaching relationship rather than explicit Settings actions.

## Regressions checked

- Focused tests: `HomeAccessibilityModalGateTests` and `PracticeModeGoalGroundingTests` passed.
- First-run setup root: `first-run-setup-root-final.png` verified no underlying Home/popup presentation.
- Forced goal refresh: `goal-refresh-inline-fixed.png` verified inline card placement and visible actions.

## Surfaces needing visual verification

- Goal refresh edit mode after typing a long replacement goal.
- Path Journey inline card placement after tapping "Check direction."
- Full onboarding progression screenshots after the root-presentation change.

## For next run

- Local: run the detailed screenshot tour once this branch is otherwise stable.
- Cloud: review remaining modal coaching prompts and propose which should become inline cards versus deliberate Settings sheets.
