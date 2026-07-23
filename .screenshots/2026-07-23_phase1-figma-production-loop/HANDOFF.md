# Run: 2026-07-23 · `ux-overhaul` · `d90bb8922`

## Mode

Light five-tab baseline plus targeted detailed UI-test captures for the Phase 1 Figma production loop.

## Changes shipped in this run

- Populated the existing Figma file as the Phase 1 visual source of truth: current UX audit, target journey/navigation, variables and components, production screens, loading/error/empty/accessibility states, interactive prototype, and SwiftUI handoff.
- Added a repository-owned Figma ↔ SwiftUI contract in `docs/FIGMA_SWIFTUI_COMPONENT_MAP.json` and `docs/FIGMA_SWIFTUI_HANDOFF.md`. Live Code Connect publication is intentionally not required.
- Preserved the existing owners for onboarding, sessions, plans, prescriptions, coaching evidence, Path progress, Ask context, memory, and achievements instead of creating parallel state.
- Implemented and verified the evidence-first post-rep sequence: verified quote and provenance, one bounded observation, original transcript, one-step upgrade, aspirational end state, and one same-prompt/same-target retry.
- Added contextual Ask Noum presentation, a compact Path journey, truthful Coaching Memory, and a single calm progression destination.
- Replaced full-screen achievement/progression celebration inconsistency with restrained inline outcomes while preserving existing unlock data.
- Added Dynamic Type/VoiceOver presentation contracts and respected existing reduced-motion owners on the touched surfaces.

## Screenshots

- `01_home_top.png` — Home / Today baseline.
- `01_train_top.png` — prescribed-plan-first Train baseline.
- `01_review_top.png` — Review destination baseline.
- `01_profile_top.png` — Profile baseline.
- `01_settings_top.png` — Settings baseline.
- `tour_F-01-evidence-first-summary.png` — verified evidence, bounded observation, and the single upgrade lane.
- `tour_F-02-review-transcript-ladder.png` — source-bound original → one-step Review ladder.
- `tour_F-02b-review-aspiration-retry.png` — aspirational end state and one retry action.
- `tour_F-03-targeted-retry.png` — exact source prompt and target, microphone gated behind Start.
- `tour_F-04-coaching-memory.png` — Coaching Memory with provenance and uncertainty.
- `tour_F-05-coaching-memory-details.png` — stable Memory projection; it intentionally does not invent unsupported per-card editing.
- `tour_F-06-unified-progress.png` — calm unified progress surface.
- `tour_F-07-unified-progress-details.png` — outcome and landmark detail.
- `tour_path-marker-top.png` / `tour_path-marker-bottom.png` — compact Path hierarchy and destination continuity.
- `tour_F-08-ask-contextual.png` — inspectable bounded context before typing.
- `tour_F-09-ask-contextual-response.png` — contextual coach response grounded in the attached focus.

## VISION alignment

- Reinforces Noum as an evidence-led communication operating system rather than a collection of exercise modes.
- Makes the coaching contract legible: one current lever, evidence from the user's own words, one bounded improvement, and immediate deliberate practice.
- Keeps progress believable by distinguishing verified evidence, user-confirmed memory, forming reads, and aspirations that are not scored.
- Reduces navigation and achievement noise without weakening real state or adding shallow gamification.

## Regressions checked

- Focused same-lever contract: 29 tests across 5 suites passed.
- Rewrite normalization and related contracts: 44 tests across 2 suites passed.
- Summary observation/composition: 20 tests across 3 suites passed.
- Path, Memory, and unified progress presentation: 17 tests across 3 suites passed.
- Final Review + Ask UI tour: 2 UI tests passed.
- Post-critic Review recapture: 1 UI test passed.
- `jq empty docs/FIGMA_SWIFTUI_COMPONENT_MAP.json` passed.
- `git diff --check` passed.

## Remaining visual refinements

1. Make the featured verified quote the exact excerpt being edited when evidence ranking permits it.
2. Compress the Ask context card and add the approved contextual prompt shortcuts so the first response appears higher.
3. Standardize “concrete example” versus “proof point” terminology across plan, retry, and Ask copy.
4. Recapture Ask with the user bubble fully visible; the grounded response itself is verified.

## Surfaces still requiring physical/TestFlight verification

- Real microphone permission, interruption, route-change, and offline behavior.
- Accessibility at the largest supported text sizes with VoiceOver on physical hardware.
- Reduced Motion on physical hardware.
- StoreKit, notifications, App Check, and live-provider behavior.

## For the next run

- Use the Figma component/node references and repository mapping before changing a core screen.
- Keep one source-bound lever across Summary → Review → Retry; do not reintroduce a generic competing action.
- Do not add direct Memory editing until the existing data owners expose a truthful correction/removal contract.
- Treat the four remaining refinements above as polish, not justification for a parallel UI or state system.
