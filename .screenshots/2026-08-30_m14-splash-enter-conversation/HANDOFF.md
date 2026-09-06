# Run: 2026-08-30 · branch:ux-experiment · HEAD ab95c3f68 · immersive conversation splash redesign

## Mode
light

## Changes shipped (this run)
- `Noum/SplashScreenView.swift` — 5.25-second mouth-only exchange, 5.2× camera push into the shared speaking point, orange/yellow conversation field, reduced-motion path, and oversized lowercase wordmark.
- `Noum/NoumApp.swift` — one-shot cold-launch ownership and a restrained 0.40-second reveal of the authoritative app root.
- `Noum/Typography.swift` — dedicated fixed-size 120-point Figtree splash wordmark token without changing the existing Dynamic Type display roles.
- `tools/gen_noum_splash_lottie.py` and `Noum/Resources/Lottie/noum-splash-conversation.json` — matching 60 fps Lottie handoff with traced icon gradients, mouth phonemes, camera motion, field, and wordmark.
- Figma frame `2:10` — synced static design and 5.25-second motion timeline; LottieFiles Creator scene `noum-splash-conversation_6` imported and left active.

## Screenshots
- `01_home_top.png` — Home/Today tab after splash completion.
- `02_train_top.png` — Practice tab.
- `03_review_top.png` — Progress tab.
- `04_profile_top.png` — You/profile tab.
- `05_settings_top.png` — Settings screen.
- `noum-splash-enter-conversation.mp4` — trimmed 30 fps simulator recording from white canvas through Home.

## VISION gap
The cold launch now reinforces Noum as a communication system by making the user enter a conversation rather than watch a logo dance. Physical-device cold-start latency, reduced-motion appearance, and the final App Store launch asset still need release-device validation.

## Next steps to reach desired state
1. Verify `SplashScreenView.swift` on one physical iPhone in normal and Reduce Motion modes before release sign-off.
2. Confirm the Figtree wordmark resolves identically in the downstream Lottie player used for marketing/export; use the native SwiftUI implementation for production launch.

## Regressions checked
- Splash → Home — `noum-splash-enter-conversation.mp4` — completes once and reveals the seeded Home screen.
- Today — `01_home_top.png` — no regression.
- Practice — `02_train_top.png` — no regression.
- Progress — `03_review_top.png` — no regression.
- You/profile — `04_profile_top.png` — no regression.
- Settings — `05_settings_top.png` — no regression.

## Surfaces needing visual verification (cloud → local queue)
- Reduced Motion cold launch on a physical device.
- Dynamic Type at the largest accessibility sizes during the wordmark hold.

## For next run
- **If cloud**: keep the SwiftUI and generated Lottie timing constants synchronized when changing the splash.
- **If local**: capture one normal and one Reduce Motion cold launch on a physical iPhone.
