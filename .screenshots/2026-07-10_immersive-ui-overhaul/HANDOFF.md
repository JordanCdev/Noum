# Run: 2026-07-10 · branch:codex/immersive-ui-overhaul · HEAD pending · production-readiness UI/UX overhaul

## Mode
detailed

## Changes shipped (this run)
- `Noum/AppShellView.swift` — native five-tab shell with per-tab navigation and deep-link tab selection.
- `Noum/FocusedPracticeScaffold.swift` — shared full-screen practice canvas used across the existing mode state machines.
- `Noum/AskNoumStore.swift` and `Noum/CoachChatTransport.swift` — transient availability/retry states and secure Firebase streaming transport.
- `Noum/PracticeSupport.swift`, `Noum/ProgressionCharts.swift`, and `ProfileView.swift` — concise, evidence-scaled recommendations and progressive disclosure.
- `NoumUITests/ScreenshotTour.swift` — deterministic coverage for 34 named tab, practice, coaching, lesson, project, path, league, and sheet surfaces.

## Screenshots
- `01_home_top.png` — Home tab at default text size.
- `02_train_top.png` — Train tab at default text size.
- `03_review_top.png` — Review tab at default text size.
- `04_profile_top.png` — Profile tab at default text size.
- `05_settings_top.png` — Settings tab at default text size.
- `a11y_*.png` — all five tab roots at Accessibility Large.
- `tour_*.png` — 34 named detailed-tour captures, including every focused setup plus Lessons, Projects, Ask Noum, Path, League, and key sheets.

## VISION gap
The app now reads as one calm communication system: neutral reading/configuration surfaces, a single native shell, focused practice canvases, and coaching language scaled to evidence. Production launch evidence is still incomplete outside the simulator: professional calibration, longitudinal real-user transfer, and physical-device/TestFlight verification remain required before claiming the coaching system is launch-ready.

## Next steps to reach desired state
1. Run the signed TestFlight build on physical devices and repeat VoiceOver, keyboard, App Attest, microphone, Live Activity, and bundle-secret checks.
2. Complete professional-coach calibration and a consented live-provider transcript sweep.
3. Collect longitudinal transfer evidence from real users and close the operational launch checklist.

## Regressions checked
- Five native tab roots — `01_*.png` and `a11y_*.png` — correct selection, safe-area layout, and Dynamic Type reflow.
- Focused practice setups — `tour_14-*` through `tour_18c-*` — shared immersive grammar without replacing mode state ownership.
- Review/Profile/Settings — `tour_04-*` through `tour_12-*` — readable hierarchy and no pushed-root Back/Done chrome.
- Ask Noum — `tour_25b-*` and `tour_25d-*` — clean coach surface and typed reply state.
- Lessons/Projects/Path/League/sheets — corresponding `tour_*.png` captures — present and navigable.

## Surfaces needing visual verification (cloud → local queue)
- In-rep microphone and live transcription phases require physical audio input.
- App Attest, Live Activities, and signed Release entitlements require device/TestFlight verification.

## For next run
- **If cloud**: evaluate canonical coaching artifacts and operational evidence without modifying simulator captures.
- **If local**: run the signed physical-device matrix and append TestFlight evidence rather than replacing this simulator baseline.
