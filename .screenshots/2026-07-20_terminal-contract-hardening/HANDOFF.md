# Run: 2026-07-20 · branch:codex/vision-gap-closure · source 6b1dabcfc · harden terminal contracts and accessibility

## Mode

light

## Changes shipped (this run)

- `Noum/AuthManager.swift:303` — removed the Swift 6 actor-isolation warning from the guest-promotion retry constant.
- `Noum/FlowObservability.swift:121` and `Noum/SettingsView.swift:1704` — detect and visibly label duplicate or malformed request terminal events without exposing content.
- `Noum/SettingsView.swift:601` — stack the practice and daily-goal pickers at accessibility Dynamic Type sizes.
- `NoumTests/ProductJourneyContractTests.swift:220` and `NoumTests/AskNoumReplyAccountIsolationTests.swift:72` — regress duplicate terminals, ignored provider cancellation, and exact 3,000-character persistence.
- `tools/coach-arena/runners/readiness_gate.py:663` — keep the independent readiness audit aligned with the transcript-practice local evidence points.

## Screenshots

- `01_home_top.png` — Home tab after consuming a pre-existing simulator promotion overlay.
- `02_train_top.png` — Train tab with one dominant recommended rep.
- `03_review_top.png` — Review tab empty state.
- `04_profile_top.png` — Profile coaching story.
- `05_settings_top.png` — Settings tab at standard Dynamic Type.
- `06_settings_dark_axxxl.png` — Settings at accessibility-extra-extra-extra-large after the adaptive-row fix. The simulator requested dark appearance, but the app root forces light.

All six PNGs are nonblank, 1206×2622, and were visually inspected from the normally signed build produced in `/private/tmp/noum-vision-gap-screenshots-2282efd49`.

## VISION gap

The current app expresses the intended journey and the local terminal/evidence contracts are coherent. The remaining gap is proof and accessibility breadth: the five external readiness artifacts are absent, the same-target retry has not been exercised with a real microphone, VoiceOver and Reduce Motion need interactive inspection, and the app is light-only despite a dark-appearance request.

## Next steps to reach desired state

1. Follow `docs/MANUAL_LAUNCH_ACTIONS.md` against the exact TestFlight release candidate and collect all five structured external artifacts.
2. Run the transcript ladder through a real microphone, retry the exact prescribed rung, and verify the intervention adapts on the same trace.
3. Complete interactive VoiceOver and Reduce Motion checks across ladder, retry, memory, Debug traces, weekly check-in, Big Moment, and every tab root.
4. Decide whether light-only appearance is intentional launch scope; otherwise remove the root light override and implement/inspect dark tokens across the full journey.

## Regressions checked

- Five tab roots — `01_home_top.png` through `05_settings_top.png` — render the expected destinations.
- Largest Dynamic Type — `06_settings_dark_axxxl.png` — picker labels no longer collapse into character-width columns.
- Serialized iOS unit target — 4,545/4,545 passed with no failures or skips.
- Transcript practice corpus — 20/20 passed.
- Canonical app path — 53 conversations / 109 turns, 50/50 scored, 50 complete traces, source freshness passing.

## Surfaces needing visual verification (cloud → local queue)

- Transcript ladder and retry comparison with real speech.
- Memory editor/deletion and Debug trace viewer with populated failure states.
- Weekly check-in and Big Moment sheets at accessibility extremes.
- Offline and provider-error UI.
- VoiceOver, Reduce Motion, and app-wide dark appearance.

## For next run

- **If cloud**: review source-bound reports and prepare no fabricated external evidence.
- **If local**: use a physical TestFlight device and complete the manual 14-surface / 77-check hardware sweep.
