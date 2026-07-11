# Run: 2026-07-11 · branch:codex/cohesive-ui-language-pass · HEAD 17be7a07 · cohesive UI, copy, and journey pass

## Mode
detailed

## Changes shipped (this run)
- `DesignSystem.swift` — shared neutral reading, grouped-destination, coaching-brief, and quiet-sheet presentation grammar.
- `Noum/HomeCoachCard.swift` and `Noum/PracticeModeSelectionView.swift` — one prioritized Home action and one coherent Train recommendation backed by the same current coaching focus.
- `Noum/SummaryView.swift`, `Noum/ReviewInsightCards.swift`, and `ProfileView.swift` — bounded debrief, one Review story, compact Profile blocks, evidence-scaled language, and genuine-peer-only comparison.
- `Noum/SettingsView.swift` and `Noum/SettingsRow.swift` — native grouped configuration, wrapping values, and explicit VoiceOver value semantics.
- `Noum/AskNoumView.swift` and `Noum/AskNoumStore.swift` — compact typed/voice shell with transient unavailable and retry states outside the persisted coach thread.
- `Noum/TrendAnalyzer.swift` and `Noum/AuthManager.swift` — account-scoped trend evidence with one-time legacy migration and account-switch isolation.
- Lessons, Speech Projects, Path, onboarding, paywall, practice setup, supporting sheets, and production copy now use the same hierarchy and action vocabulary.

## Screenshots
- `latest_default_*.png` — the five final tab roots at default text size.
- `latest_a11y_large_*.png` — all five tab roots plus Summary at Accessibility Large.
- `tour_*.png` — the 34-destination detailed tour covering tab roots, practice setups, Lessons, Projects, Ask Noum, Path, Peer Comparison, and key sheets.
- `final_A-cold-*.png` — true cold-start Home, Train, Review, Profile, Ask Noum, Path, and Peer Comparison states.
- `final_O-*.png`, `final_P-*.png`, and `final_S-*.png` — onboarding, paywall, and Summary flows.
- `audit_A-*` through `audit_D-*` — cold, beginner, improving, and plateaued evidence-depth sweeps.

## VISION gap
The simulator experience now reads as one calm communication system and keeps Home, Train, Review, and Profile on one evidence-backed focus. Production launch proof still requires the deployed Firebase/Vertex path with live App Check, signed-device microphone and Live Activity verification, professional-coach calibration, and longitudinal real-user transfer evidence. The Functions emulator could not run locally because this Mac has no Java runtime; the non-emulator Functions suite passed.

## Next steps to reach desired state
1. Deploy and validate Firebase Functions, Vertex IAM/billing, App Check, Fast/Ultra parameters, cancellation, and rate limiting in the production project.
2. Repeat the matrix in a signed TestFlight build on physical devices with VoiceOver, keyboard, microphone, Live Activities, and network-loss scenarios.
3. Complete professional-coach calibration and collect consented longitudinal transfer evidence before claiming launch readiness.

## Regressions checked
- Core journey — final default and Accessibility Large captures preserve one dominant surface, one primary action, tab clearance, and readable expansion.
- Practice — all existing mode setup routes and state-machine entry points pass the detailed tour with canonical exercise names.
- Summary — top, mid-scroll, and bottom captures preserve the status area and expose one combined debrief, next rep, Ask Noum, details, and Done.
- Thin evidence — true cold state shows no fabricated rating, peer standings, coaching pattern, or first-rep celebration.
- Ask Noum — success, unavailable, draft retention, retry deduplication, and legacy-notice filtering are covered by unit and UI gates.
- Navigation — native tab roots, per-tab paths, deep links, onboarding, login, paywall, Path, Lessons, Projects, friends, and sheets remain reachable.

## Surfaces needing visual verification (cloud → local queue)
- Real microphone input, live transcription, keyboard dictation, and interruption handling require physical hardware.
- App Attest/App Check, Live Activities, signed Release entitlements, and production callable streaming require the deployed environment.

## For next run
- **If cloud**: close Firebase/Vertex deployment and operational launch evidence without replacing this simulator baseline.
- **If local**: run the signed physical-device matrix and append TestFlight evidence to this handoff.
