# Run: 2026-08-29 · branch:ux-experiment · HEAD ab95c3f68 · Replace the generic splash bubble with the shipping AppIcon characters

## Mode
light

## Changes shipped (this run)
- `Noum/SplashScreenView.swift:5` — Added the bounded cold-launch policy, 1.80s motion timeline, reduced-motion path, and AppIcon-traced SwiftUI character geometry.
- `Noum/NoumApp.swift:279` — Mounted the splash as the stable root before the existing authoritative app flow, with UI-test bypass/opt-in behavior.
- `DesignSystem.swift:151` — Added colors sampled from the shipping AppIcon for the orange and yellow characters.
- `Noum/Assets.xcassets/LaunchBackground.colorset/Contents.json:1` — Added a fixed white native launch color so dark mode cannot tint the opening frame gray.
- `Noum.xcodeproj/project.pbxproj:832` — Removed Xcode's generated launch-screen override so the source `UILaunchScreen` dictionary remains authoritative.
- `scripts/release-materialize-ci-config.sh:120` — Injected the white launch-screen asset into the gitignored Info.plist during CI materialization.
- `Noum/Resources/Lottie/noum-splash-conversation.json:1` — Added the synchronized pure-vector Lottie animation.
- `tools/gen_noum_splash_lottie.py:191` — Added the deterministic Lottie generator for the traced character silhouettes and motion beats.
- `NoumTests/SplashScreenTests.swift:6` — Added launch-policy, timing, reduced-motion, fixed-white-launch, and no-rounded-rectangle Lottie contract coverage.
- `scripts/tests/test_release_materialize_ci_config.py:58` — Added release-materialization coverage for the launch color contract.
- [Figma motion file](https://www.figma.com/design/4De4jDdqrXlGEuMfZCEBkZ) — Added editable AppIcon-traced storyboard frames and a synchronized 1.80s motion timeline.

## Screenshots
- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab (Practice mode picker).
- `01_review_top.png` — Review tab (Session history).
- `01_profile_top.png` — Profile tab.
- `01_settings_top.png` — Settings tab.
- `focus_01_rear_character.png` — White opening field with the real rear AppIcon character.
- `focus_02_appicon_pair.png` — Both AppIcon characters in the conversation beat.
- `focus_03_orange_takeover.png` — Zoom/takeover transition into the brand field.
- `focus_04_noum_wordmark.png` — Final orange field with the white Noum wordmark.

## VISION gap
The launch now behaves like a calm, premium identity moment and uses the same two-character silhouette as the shipping AppIcon instead of a generic chat glyph. The remaining identity gap is upstream: the shipping icon exists only as a textured 1024px raster, so SwiftUI, Figma, and Lottie use a carefully matched vector trace and sampled colors rather than an original outlined brand master.

## Next steps to reach desired state
1. When brand artwork changes, replace the shared traced geometry in `Noum/SplashScreenView.swift` and `tools/gen_noum_splash_lottie.py` from the same approved vector master, then regenerate the Lottie file.
2. Add a committed golden-image fixture for the paired-character phase so silhouette/proportion regressions fail automatically, not only through the light screenshot sweep.

## Regressions checked
- Cold launch — `focus_01_rear_character.png` through `focus_04_noum_wordmark.png` — white start, correct character order, orange takeover, wordmark, and home handoff verified.
- Home routing — `01_home_top.png` — no regression.
- Train routing — `01_train_top.png` — no regression.
- Review routing — `01_review_top.png` — no regression.
- Profile routing — `01_profile_top.png` — no regression.
- Settings routing — `01_settings_top.png` — no regression.

## Surfaces needing visual verification (cloud → local queue)
- None for this run; all touched launch phases and the five tab tops were verified on the designated iPhone 17 simulator.

## For next run
- **If cloud**: Regenerate `Noum/Resources/Lottie/noum-splash-conversation.json` after any geometry change and run the focused splash plus CI-materializer tests.
- **If local**: Re-capture the four focus phases whenever the AppIcon, launch timing, status-bar treatment, or wordmark changes.
