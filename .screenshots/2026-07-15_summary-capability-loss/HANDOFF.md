# Run: 2026-07-15 · branch:ux-overhaul · HEAD 3969c817 · Summary capability-loss honesty

## Mode

light

## Changes shipped (this run)

- `Noum/NextActionEngine.swift:344` — Summary projections can recheck the complete live Pressure/Conversation availability snapshot at tap without upgrading a mode that already rendered as Timed.
- `Noum/SummaryView.swift:319` — Summary carries the exact rendered action/projection into shown and tap attribution, records shown synchronously on fallback, and clears interrupted regular-mode Quick Start state before manual Timed routing.
- `Noum/PostRepVerdictCard.swift:932` — the Summary action renderer resolves one full tap-time capability snapshot instead of probing only Conversation availability.
- `Noum/RecommendationTapCapabilityLossUITestFixture.swift:80` — Release-inert fixture renders the real Summary Pressure branch, removes capability at tap, and optionally arms stale Timed quick-start state.
- `NoumUITests/RecommendationSurfaceRoutingUITests.swift:145` — Accessibility XXXL coverage proves Summary Pressure fallback, manual Timed setup, and shown-only diagnostics; the neighboring Timed prompt test now supplies its established microphone precondition.

## Screenshots

- `01_home_top.png` — Home tab, top of view
- `01_train_top.png` — Train tab, top of view
- `01_review_top.png` — Review tab, top of view
- `01_profile_top.png` — Profile tab, top of view
- `01_settings_top.png` — Settings tab, top of view
- `summary_pressure-rendered.png` — real Summary Pressure prescription and 44-point action at Accessibility XXXL
- `summary_timed-manual-fallback.png` — exact default Timed setup after capability loss, with no automatically mounted prompt or stale prescribed demand
- `summary_shown-only-diagnostics.png` — content-free `prescription.shown`, exact 0% acceptance, and no accepted event

## VISION gap

The supported Summary recommendation loop now fails closed honestly when a rendered Pressure capability disappears and preserves truthful exposure/acceptance attribution. This remains deterministic simulator evidence for one branch. It does not establish physical capability transition behavior, rendered Summary Conversation or Home loss, wider adaptive destination coverage, population benefit, professional calibration, longitudinal transfer, or production launch readiness.

## Next steps to reach desired state

1. Re-rank the remaining local gaps; inspect metric-specific speech-quantity qualification before allowing filler-rate or WPM reads to influence coaching, trends, or KPIs.
2. Obtain the five required external artifacts through the authorized release workflow; local simulator evidence cannot raise the production gate.
3. Run manual VoiceOver plus the clean signed full scheme, optimized Release scan, physical TestFlight matrix, and live-provider sweep when the required signing/service authority is available.

## Regressions checked

- Summary Pressure recommendation — `summary_pressure-rendered.png` — 44-point action remains readable and hittable at Accessibility XXXL.
- Capability-loss route — `summary_timed-manual-fallback.png` — reaches default manual Timed setup without Pressure/Conversation destination, prompt, stale demand, or interrupted regular-mode Quick Start.
- Attribution — `summary_shown-only-diagnostics.png` — shown denominator retained at 0% acceptance with no accepted event.
- Recommendation surfaces — complete `RecommendationSurfaceRoutingUITests` pass 5/5, including Home/Train accepted routes, Train/Summary Pressure loss, and exact Timed demand (`.build-roleplay-terminal/Evidence/Recommendation-surfaces-ui-20260715.xcresult`).
- Logic regression — focused selection passes 23/23 (`.build-roleplay-terminal/Evidence/Summary-capability-focused-20260715.xcresult`); complete `NoumTests` passes 4,242 unique tests / 4,261 device executions (`.build-roleplay-terminal/Evidence/NoumTests-full-20260715.xcresult`).
- Release — unsigned Release simulator build succeeds; localization catalog hash remains `ee0a735ed8a3c17d5f589d5926a6f2c14e2080a5e35002ed2db3aafb80a6f16a`.

## Surfaces needing visual verification (cloud → local queue)

- Manual VoiceOver reading order and announcements for the Summary card and fallback setup.
- Physical-device capability loss, microphone permission transition, and signed TestFlight navigation.
- Summary Conversation and Home capability-loss branches.

## For next run

- **If cloud**: audit metric-specific filler-rate/WPM evidence floors and update pure contracts only; do not claim rendered or external proof.
- **If local**: capture any newly changed metric presentation at Accessibility XXXL and Reduce Motion, then run the clean signed/full release gates only if signing prerequisites are actually available.
