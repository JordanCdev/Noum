# Run: 2026-07-14 · branch:ux-overhaul · implementation HEAD 1e8e3e5e · rendered Home/Train recommendation ownership

## Mode

light

## Changes shipped (this run)

- `Noum/AppShellView.swift` — lends the shell's selected-tab ownership to retained tab roots so off-tab content cannot claim an exposure.
- `Noum/HomeCoachCard.swift` — records only a settled, selected Home prescription while preserving synchronous fast-tap exposure.
- `Noum/PracticeModeSelectionView.swift` — moves Train exposure out of recommendation computation and onto the settled rendered hero; exposes its canonical mode to accessibility.
- `Noum/SettingsView.swift` — exposes the existing account-local flow log only to an opt-in DEBUG UI-test launch.
- `NoumUITests/RecommendationSurfaceRoutingUITests.swift` — proves exact Home/Train Filler Control copy, 44-point actions, real destinations, and correlated shown/accepted flow events.

## Screenshots

- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab, recommended-rep hero.
- `01_review_top.png` — Review tab, recent movement.
- `01_profile_top.png` — Profile tab, current coaching focus.
- `01_settings_top.png` — Settings tab, top of view.
- `home-recommendation-rendered.png` — seeded Home Filler Control prescription.
- `home-recommendation-destination.png` — Home action at Filler Control setup.
- `home-recommendation-correlated-acceptance.png` — Home flow log at 100% with shown and accepted.
- `train-recommendation-rendered.png` — seeded Train Filler Control hero.
- `train-recommendation-destination.png` — Train action inside Filler Control countdown.
- `train-recommendation-correlated-acceptance.png` — Train flow log at 100% with shown and accepted.

## VISION gap

Home and Train now behave as one coherent communication-improvement loop for the current four `PracticeMode` destinations: one visible prescription, one matching launch, and honest account-local measurement. The original research still asks for prescription destinations across Roleplay, Lessons, Projects, Path, and pace; those remain outside this rendered proof. Production effectiveness and launch confidence also still require live-provider, professional-reviewer, longitudinal-user, physical-TestFlight, and operational evidence.

## Next steps to reach desired state

1. Extend the existing next-action destination model and router with one coherent classification for Roleplay, Lessons, Projects, Path, and pace before adding any new recommendation UI.
2. Collect the five externally earned readiness artifacts through the existing release workflow; do not substitute simulator screenshots for those gates.

## Regressions checked

- Home recommendation → Filler Control → account-local acceptance — focused attachments — no regression.
- Train recommendation → Filler Control → account-local acceptance — focused attachments — no regression; retained off-tab Home no longer inflates the denominator.
- Home, Train, Review, Profile, Settings tab tops — `01_*_top.png` — all rendered the expected selected tab.
- Shared availability, Home copy variants, and KPI correlation — 31 focused unit tests — no regression.

## Surfaces needing visual verification (cloud → local queue)

- Physical-device and TestFlight Home/Train behavior remains externally gated.
- The wider Roleplay/Lessons/Projects/Path/pace prescription catalog has no rendered end-to-end proof yet.

## For next run

- **If cloud**: audit destination classification and state ownership for the wider prescription catalog without creating parallel routing.
- **If local**: add a focused rendered proof only after the shared destination contract exists, then repeat the screenshot and accessibility checks.
