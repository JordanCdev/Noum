# Run: 2026-07-15 · branch:ux-overhaul · HEAD c3e018d4 · fail-closed Roleplay filler scoring and complete startup fallback-notice parity

## Mode
light

## Changes shipped (this run)
- `Noum/RoleplayEngine.swift:70` — withholds Roleplay filler penalties until turns retain duration-qualified evidence; existing content and hedge signals remain.
- `Noum/PaceTrainingView.swift:81` — presents the shared transcription-route notice.
- `Noum/CutTheCrutchView.swift:117` — presents the shared transcription-route notice.
- `Noum/RoleplayView.swift:97` — presents the shared transcription-route notice.
- `NoumTests/RoleplayFillerFairnessTests.swift:7` — proves semantic terms and unqualified disfluency cannot lower Roleplay quality or raise retry pressure.
- `NoumTests/SpeechSessionIntegrityTests.swift:224` — proves all nine speech surfaces wire the shared startup-fallback notice.

## Screenshots
- `01_home_top.png` — Home tab, top of view; rendered successfully.
- `01_train_top.png` — Train tab, practice picker; rendered successfully.
- `01_review_top.png` — Review tab, session history; rendered successfully.
- `01_profile_top.png` — Profile tab; rendered successfully.
- `01_settings_top.png` — Settings tab; rendered successfully.

## VISION gap
Noum now fails closed instead of presenting weak filler evidence as confident Roleplay scoring, and every speech surface has the same calm startup-fallback explanation. The light sweep cannot force a real cloud-to-device route change, so the banner still lacks rendered physical-device/TestFlight evidence. Roleplay also lacks durable finalized turn duration, which prevents honest fillers-per-minute coaching there.

## Next steps to reach desired state
1. Define and persist a finalized Roleplay turn-duration contract before reintroducing quantity-qualified filler coaching in `Noum/RoleplayEngine.swift`.
2. Capture a real provider-startup failure on physical TestFlight hardware and verify the shared notice, VoiceOver announcement, and reduced-motion behavior.
3. Resolve the product mapping and evidence policy before attributing Pace Training or Roleplay to the adaptive coaching path.

## Regressions checked
- Home route — `01_home_top.png` — no launch or layout regression.
- Train route — `01_train_top.png` — practice picker and Roleplay entry rendered; no tab-routing regression.
- Review route — `01_review_top.png` — recent movement and saved-rep entry rendered.
- Profile route — `01_profile_top.png` — coaching focus and outcome prompt rendered.
- Settings route — `01_settings_top.png` — practice controls rendered without clipping at the top.

## Surfaces needing visual verification (cloud → local queue)
- Pace Training, Cut the Crutch, and Roleplay during an actual cloud-start failure; the light sweep does not enter in-rep dynamic states.
- Shared fallback notice with VoiceOver and Reduce Motion on physical hardware.

## For next run
- **If cloud**: keep production readiness at NO-GO until external evidence sidecars are real; refine only locally provable contracts.
- **If local**: run the physical/TestFlight provider-failure protocol and capture the fallback notice on each newly wired surface.
