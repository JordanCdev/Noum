# Run: 2026-07-13 · branch:ux-overhaul · HEAD cd76ce6f · close the research activation and trust gaps

## Mode
light

## Changes shipped (this run)
- `Noum/FirstRunOnboardingManager.swift:201` — exact, versioned Remote Config contract for eligible new-account activation experiments; empty or unknown values remain unassigned.
- `Noum/FlowObservability.swift:392` — account-local, content-free activation assignment, exposure, first-value, and completed-spoken-rep evidence.
- `Noum/TranscriptionRouteNotice.swift:10` — shared, restrained notice when a requested cloud transcription route starts locally.
- `Noum/SpeechRecognizerViewModel.swift:104` — owns the startup route notice without changing the no-midstream-replay invariant.
- `NoumUITests/FastLaneFirstSessionUITests.swift:65` — signed end-to-end timing assertion for permissionless first value under 60 seconds.

## Screenshots
- `01_home_top.png` — Home tab, focused stakeholder-review plan.
- `01_train_top.png` — Train tab, recommended rep and practice library.
- `01_review_top.png` — Review tab, recent movement and rep history.
- `01_profile_top.png` — Profile tab, evidence-bound rating and qualitative outcome check.
- `01_settings_top.png` — Settings tab, practice configuration.

## VISION gap
The five top-level surfaces are coherent, calm, and visibly connect preparation, practice, review, and coaching focus. The research loop is still not production-proven: there is no completed professional calibration study, no real-user longitudinal structured-to-live transfer cohort, and no current-source zero-refusal live-provider sweep. The roleplay curriculum also remains embedded in the existing conversation-practice domain rather than a separately validated curriculum system.

## Next steps to reach desired state
1. Run the physical-device TestFlight matrix and visually/with VoiceOver verify the cloud-to-local startup notice in every mounted practice mode.
2. Complete professional calibration and a real-user longitudinal transfer study before making population-level efficacy claims.
3. Restore live-provider quota/credentials and run the current-source coach-arena sweep to the zero-refusal gate.

## Regressions checked
- Home top — `01_home_top.png` — focused plan and bottom navigation render correctly.
- Train top — `01_train_top.png` — recommendation card, practice library, and tab selection render correctly.
- Review top — `01_review_top.png` — evidence-bound trend and rep links render correctly.
- Profile top — `01_profile_top.png` — rating, coaching focus, and qualitative outcome check render correctly.
- Settings top — `01_settings_top.png` — practice controls and tab selection render correctly.

## Surfaces needing visual verification (cloud → local queue)
- Cloud-requested transcription startup falling back locally in Timed, Sudden Death, Ah-Counter, and Conversation Practice.
- VoiceOver reading order and reduced-motion behavior for the route notice on a physical device.

## For next run
- **If cloud**: inspect source-matched arena results and prepare the professional calibration packet without claiming live-provider readiness.
- **If local**: execute the physical-device fallback-notice and TestFlight operational checklist.
