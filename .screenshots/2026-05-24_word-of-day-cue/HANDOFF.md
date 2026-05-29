# Run: 2026-05-24 · branch:Redesign · HEAD ad8b06a · Word of the Day cue cleanup

## Mode
off

Screenshot capture skipped because `.agents/skills/noum-screenshots/.mode` is `off`.

## Changes shipped (this run)
- `Noum/CoachContextBuilder.swift:671` — explicit filler mentions (`"um"`, `"uh"`, `filler`) route to filler follow-up chips before pause/silence language.
- `Noum/WordOfTheDay.swift:9` — Word of the Day prompts are neutral and never contain the target word.
- `Noum/HomeUtilityStrip.swift:1` — Home now frames the word tap as a neutral topic plus separate word cue.
- `Noum/TimedPracticeView.swift:576` — Timed Practice consumes `timedPractice.suggestedWord` once and shows it as a separate "Today's word" cue.
- `NoumTests/NoumTests.swift:2907` — catalog test now rejects prompts that pre-use any accepted word form.

## Screenshots
No screenshots captured in `off` mode.

## VISION gap
`docs/VISION.md` still points to M14 release readiness, so this run stayed in polish/verification territory rather than adding a new feature surface.

## Next steps to reach desired state
1. Turn screenshot mode to `light` and capture the Word of the Day -> Timed Practice path on a booted simulator.
2. Continue the M14 release gate work: UI test status, real-device QA, Firestore rules deploy, privacy URL, and TestFlight build.

## Regressions checked
- `WordOfTheDayCatalogTests` + `WordOfTheDayDetectionTests` — passed.
- `CoachContextBuilderTests/followUpTopicDetectionFindsFillers` — passed.

## Surfaces needing visual verification
- Timed Practice setup/thinking/brief reveal with a Word of the Day cue visible separately from the topic prompt.

## For next run
- If cloud: continue non-visual M14 gate cleanup.
- If local: run a light screenshot pass with the simulator booted and screenshot mode enabled.
