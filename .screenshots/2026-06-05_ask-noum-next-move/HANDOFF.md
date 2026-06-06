# Run: 2026-06-05 - branch:Redesign - HEAD 47d7f47 - Ask Noum live entry cleanup

## Mode
focused manual capture

The configured `.Codex/skills/noum-screenshots/.mode` file was missing, so this run captured the two changed Ask Noum routes instead of a full light/detailed sweep.

## Changes shipped (this run)
- `Noum/LiveCoachCallView.swift:34` - live coach now reads `CoachMemoryStore` and shows a coaching brief instead of stale prior chat on first load.
- `Noum/LiveCoachCallView.swift:63` - resting state now says `Tap Talk to begin`; unavailable voice points users to Type.
- `Noum/LiveCoachCallView.swift:87` - landing brief replaces captions until the current live session produces a new exchange.
- `Noum/LiveCoachCallView.swift:255` - brief is grounded in the active case file when available, with softer baseline copy when evidence is thin.
- `Noum/PracticeSupport.swift:30` - added `askNoumTyped` as a distinct typed coach destination.
- `Noum/ContentView.swift:366` - `askNoum` routes to live; `askNoumTyped` routes to typed mode.
- `Noum/ContentView.swift:1894` - `noum://ask/type`, `noum://ask/chat`, and matching `?mode=` links route to typed mode.
- `Noum/CoachSessionView.swift:22` - session container accepts an initial mode.
- `Noum/AskNoumView.swift:212` - typed route initializes with the actual composer visible.
- `NoumUITests/NoumUITests.swift:233` - focused Ask Noum chat tests now use the typed route.
- `NoumUITests/M17VerificationTour.swift:114` - verification tour uses typed route for chat assertions.

## Screenshots
- `01_live_landing.png` - `noum://ask`; clean live-coach landing with coaching read, no stale transcript.
- `02_typed_route.png` - `noum://ask/type`; existing chat thread with composer visible.

## VISION gap
This improves the first five seconds of Ask Noum so it feels more like a coach opening a session. It does not yet prove human-coach replacement. The live landing now presents a case read, but it still needs stronger follow-through: explicit intervention review, evidence strength, user reflection, and real-world transfer checks across future sessions.

## Next steps to reach desired state
1. Add a live-session follow-up card after the first exchange that asks one reflective question tied to the active intervention and writes the answer into the case file.
2. Tighten the live controls: evaluate whether `Aloud` should be a smaller toggle and whether `Leave` should read less severe than the red `X`.
3. Add a focused UI assertion for `askNoum.live.coachBrief` so the live route contract is covered, not only screenshot-verified.

## Regressions checked
- `xcodebuild build` - succeeded for the app target.
- `NoumUITests.testAskNoumGoalChangeSurfacesConfirmationCard` - passed after typed-route fix.
- `NoumUITests.testNonCanonicalVoiceDescriptorSurfacesCard` - passed after typed-route fix.
- `01_live_landing.png` - no stale coach text or clipped transcript on landing.
- `02_typed_route.png` - typed route exposes the composer.

## Surfaces needing visual verification
- A live exchange after recording/speaking was not captured because simulator audio is not a reliable proxy for device voice capture.
- Full app light/detailed screenshot sweep was skipped because the screenshot mode file was missing.

## For next run
- If local: capture a post-exchange live Ask Noum state on device or with a test-only transcript hook.
- If cloud: implement the live coach brief UI assertion and intervention-reflection persistence without simulator screenshots.
