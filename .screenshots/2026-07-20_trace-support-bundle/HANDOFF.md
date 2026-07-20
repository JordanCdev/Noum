# Run: 2026-07-20 · branch:codex/vision-gap-closure · HEAD 7b8552d79 · redacted trace support export

## Mode
light, plus one focused rendered Developer Tools capture

## Changes shipped (this run)
- `Noum/FlowObservability.swift` — structured, content-free per-request support bundle joined to matching AI diagnostics by trace ID.
- `Noum/SettingsView.swift` — independently accessible trace-ID and redacted-bundle copy controls.
- `tools/coach-arena/runners/trace_replay.py` — fail-closed local terminal-path replay and validation.
- `NoumUITests/CoachTraceSupportUITests.swift` — rendered Settings export regression and focused screenshot.

## Screenshots
- `01_home_top.png` — Home tab; one dominant upcoming-moment coaching step and contextual Ask Noum entry.
- `01_train_top.png` — Train tab; one prescribed Timed Practice rep above the library.
- `01_review_top.png` — Review tab; one recent-movement story and latest-rep CTA.
- `01_profile_top.png` — Profile tab; voice target, current coaching focus, and reality-check loop.
- `01_settings_top.png` — Settings tab top.
- `02_debug_trace_support_bundle.png` — content-free provider/gate/persistence/UI terminal path, both export controls, and successful export toast.

## VISION gap
The local observability journey now has a real support export and content-free replay path rather than a human-readable log alone. This supports coaching trust and reliability without retaining user communication content. It does not satisfy VISION's live-provider, professional-coach, longitudinal-transfer, physical-device/TestFlight, or operational launch evidence gates.

## Next steps to reach desired state
1. Finish the requirement-to-evidence audit and close remaining locally actionable reliability/accessibility gaps.
2. Run the broad serialized unit suite and a fresh Release simulator build at the eventual committed source.
3. Collect independent external evidence only through the guarded production-evidence workflow; do not infer it from simulator screenshots.

## Regressions checked
- Home/Train/Review/Profile/Settings tab roots — five `01_*_top.png` captures — all nonblank and routed to distinct expected surfaces.
- Developer trace export — `02_debug_trace_support_bundle.png` — provider refusal, fallback selection, persistence, UI commit, terminal state, copy controls, and toast are visible.
- Accessibility interaction — rendered UI test — both copy controls remain individually discoverable and hittable.

## Surfaces needing visual verification (cloud → local queue)
- Largest Dynamic Type and VoiceOver reading order for a populated multi-attempt trace.
- Physical-device Settings export/share workflow.
- Real provider failure trace with current-source production diagnostics.

## For next run
- **If cloud**: continue static requirement mapping and evaluator-contract tests; do not claim device or live-provider closure.
- **If local**: capture populated trace at accessibility XXXL, then continue physical TestFlight evidence only after signing and release-account prerequisites are satisfied.
