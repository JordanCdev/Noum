# Run: 2026-08-29 · branch:ux-experiment · HEAD ab95c3f68 · make the splash read as a calm mouth-led conversation

## Mode
light

## Changes shipped (this run)
- `Noum/SplashScreenView.swift:17` — retimed the one-shot launch from 1.8s to 3.85s with slower pair, takeover, and wordmark transitions.
- `Noum/SplashScreenView.swift:105` — removed independent character bobbing/scaling; both bodies remain fixed while their mouth geometry changes across two speech beats each.
- `Noum/SplashScreenView.swift:84` — replaced the title-case treatment with the canonical lowercase `noum` wordmark.
- `Noum/Typography.swift:40` — aligned the launch wordmark to Figtree ExtraBold at 44pt with restrained tracking.
- `tools/gen_noum_splash_lottie.py:1` — mirrored the mouth-only choreography, app-icon gradients/rims/shadow, 3.85s timing, shared 8% takeover zoom, and lowercase wordmark in the LottieFiles handoff.
- `NoumTests/SplashScreenTests.swift:1` — extended the splash contract to cover the slower timeline, static positions, animated mouth paths, app-icon gradients, and Figtree wordmark.

## Screenshots
- `00-splash-overview.png` — nine-frame launch overview from first character through Home.
- `01-first-bubble.png` — white opening beat with the rear app-icon character.
- `02-pair-rest.png` — both characters visible with fixed body positions.
- `03-orange-mouth-open.png` / `04-orange-mouth-rest.png` — rear character speech-mouth comparison.
- `05-yellow-mouth-open.png` / `06-yellow-mouth-rest.png` — foreground character mouth-notch comparison.
- `07-takeover.png` — gradual orange field takeover with the shared mark fading.
- `08-wordmark.png` — lowercase Figtree ExtraBold wordmark on orange.
- `09-home-handoff.png` — completed transition into the authoritative Home root.
- `10-home-top.png` — Home tab, top of view.
- `10-train-top.png` — Practice tab, top of view.
- `10-review-top.png` — Progress tab, top of view.
- `10-profile-top.png` — You/Profile tab, top of view.
- `10-settings-top.png` — Settings tab, top of view.

## VISION gap
M14 asks launch polish to reinforce Noum as one calm, premium communication system. The splash now uses the actual app-icon character language and makes communication legible through mouth states, not playful body motion. The remaining evidence gap is physical-device cold-launch timing; simulator, Figma, and LottieFiles Creator have been checked.

## Next steps to reach desired state
1. Run one physical-device cold launch and confirm the 3.85s sequence feels equally calm at 60Hz/120Hz and under real startup load.
2. Preserve the mouth-only and maximum 8% shared-scale constraints in any future motion iteration.

## Regressions checked
- Cold launch sequence — `01-first-bubble.png` through `09-home-handoff.png` — no body shake, correct mouth exchange, takeover, wordmark, or routing regression.
- Home — `10-home-top.png` — correct deep link and post-splash root.
- Practice — `10-train-top.png` — correct recommended-practice surface.
- Progress — `10-review-top.png` — correct empty progress state.
- Profile — `10-profile-top.png` — correct profile and coaching-plan surface.
- Settings — `10-settings-top.png` — correct settings surface.

## Surfaces needing visual verification (cloud → local queue)
- Physical-device cold launch only; simulator coverage is complete.

## For next run
- **If cloud**: keep any launch refinements inside the existing `SplashTimeline` and shape owners; do not add an animation runtime or parallel routing state.
- **If local**: verify one physical-device cold launch and Reduced Motion handoff.
