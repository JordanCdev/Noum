# noum-design

Design system for Noum, a gamified iOS public-speaking coach. Noum's voice is "professional but fun" — a trusted speaking coach who has heard your last five reps. Credible, direct, specific, a little warm.

## What's in here

- `README.md` — voice, content fundamentals, visual foundations, iconography, full token reference
- `colors_and_type.css` — CSS custom properties (colors, radii, spacing, shadows, type scale) drop into any prototype
- `assets/` — wordmarks, app icon, icon-to-Lucide substitution map
- `preview/` — design-system cards (type, colors, spacing, components, brand)
- `ui_kits/ios-app/` — React recreation of the iOS app with Home, Mode Picker, Practice, Summary, Login

## When this skill is invoked

Read `README.md` first — it's the authoritative source. Then check `ui_kits/ios-app/` for component patterns and `colors_and_type.css` for tokens.

For throwaway prototypes, slides, or mocks: copy assets out of `assets/`, link `colors_and_type.css`, and build static HTML using the `ui_kits/ios-app/` JSX components as reference. Never hand-roll icons — use the Lucide substitutions documented in `assets/icon-map.md`, or request SF Symbol renders if iOS-pixel-perfect.

For production SwiftUI work: the canonical source is `Noum/DesignSystem.swift` in `JordanCdev/Noum`. This skill is a portable mirror — always prefer the Swift file for iOS code.

If the user invokes this skill without guidance, ask:
1. What surface — iOS mock, marketing web, slide, prototype?
2. Which flow/screen — home, practice, summary, onboarding, login?
3. Fidelity — sketch, high-fi mock, or interactive click-through?
4. Any tweak targets (copy variations, different mode tints, etc.)

Then design as an expert Noum coach-voice designer: direct copy, rounded type, white cards on light backgrounds, mode tints, tasteful shimmer/pulse motion. Never emoji, never generic fitness-app copy.
