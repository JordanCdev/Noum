# Run: 2026-07-15 · branch:ux-overhaul · HEAD 3969c817 · render honest recommendation capability loss at tap

## Mode

light

## Changes shipped (this run)

- `Noum/RecommendationTapCapabilityLossUITestFixture.swift` — adds a Release-inert, DEBUG-gated source/tap fixture that can render a coherent Pressure recommendation and remove its capability only at launch time without mutating recommendation, analytics, or navigation state.
- `Noum/PracticeModeSelectionView.swift` — keeps Train on the existing recommendation/availability/launch projection while feeding it distinct rendered and live capability snapshots.
- `Noum/HomeCoachCard.swift` — reuses the same projection and clears an interrupted Quick Start handshake before a non-accepting operational fallback; this Home branch is source-covered but not rendered in this run.
- `NoumTests/RecommendationTapCapabilityLossUITestFixtureTests.swift` — proves ordinary launches are unchanged, Pressure loss changes only Pressure availability, Conversation loss updates both established guards, and invalid/non-UI-test arguments are inert.
- `NoumUITests/RecommendationSurfaceRoutingUITests.swift` — renders Pressure Drill, removes Pressure at tap, verifies exact default manual Timed setup, and reads the content-free shown-only diagnostic back at exact 0% acceptance; the adjacent normal Timed route still reaches its prompt.
- `docs/CURRENT_STATE.md`, `docs/DEVELOPMENT_PLAN.md`, and `docs/RESEARCH_IMPLEMENTATION_AUDIT.md` — record the bounded local closure while retaining the external NO-GO.

The checkout already contained in-flight source, localization, tests, docs, and
31 staged screenshot handoffs. This run preserved those changes and staged only
this handoff; source and documentation remain unstaged.

## Screenshots

- `01_home_top.png` — seeded Home tab and current coaching action.
- `01_train_top.png` — seeded Train recommendation and practice library.
- `01_review_top.png` — seeded Review movement and saved-rep history.
- `01_profile_top.png` — seeded Profile rating and coaching evidence.
- `01_settings_top.png` — seeded Settings controls.
- `02_train_pressure_recommendation.png` — Accessibility XXXL Pressure Drill recommendation before the simulated tap-time loss.
- `03_timed_capability_fallback_setup.png` — default manual Timed setup after loss, with no recommended difficulty or automatically mounted prompt.
- `04_prescription_shown_only.png` — content-free flow diagnostic showing 0% prescription acceptance, `prescription.shown`, and no accepted event.

The initial unseeded light sweep reached the known account-bootstrap save error
and was discarded. The five retained tab tops were relaunched with the
established `improvingIntermediate` deterministic seed. The focused captures
came from the mic-granted passing UI lane. All eight retained images were
visually inspected.

## VISION gap

Train now visibly protects coaching trust when a recommendation cannot execute:
the displayed Pressure action fails closed to a calm, usable Timed setup and is
not counted as accepted. The existing production projections and content-free
ledger remain authoritative. This is one deterministic simulator branch, not a
real hardware/provider capability transition; Home/Summary and Conversation
loss, the later IM destination race, wider prescription destinations,
population benefit, and signed-device behavior remain outside this evidence.

## Next steps to reach desired state

1. Add a rendered mixed Review-only history boundary using the existing progress-eligibility, Review, chart, and Profile owners; keep raw saved rows inspectable while thin/non-finite/fixture rows cannot drive coaching evidence.
2. Render Home/Summary or Conversation capability loss only if a separately ranked research gap justifies another Release-inert seam; do not generalize this Pressure lane.
3. Run manual VoiceOver and the attachment-backed signed full scheme, optimized Release scan, physical TestFlight checklist, and real capability/provider transitions when the required environment and authority are available.
4. Collect all five independent external readiness artifacts; simulator evidence cannot raise the production verdict.

## Regressions checked

- Recommendation availability, attribution, fixture, and all recommendation-surface UI tests — `.build-roleplay-terminal/Logs/Test/Test-Noum-2026.07.15_12-54-47-+0100.xcresult` — 24/24 passed with zero failures or skips. Both relevant actions are hittable and at least 44 points high; the fallback setup and 0% diagnostic labels are exact. Xcode emitted two non-failing QoS priority-inversion warnings.
- Complete current-source unsigned unit target — `.build-roleplay-terminal/Logs/Test/Test-Noum-2026.07.15_12-50-45-+0100.xcresult` — 4,228 unique tests / 4,247 device executions passed with zero failures or skips.
- Current-source unsigned Release simulator build — `xcodebuild build -configuration Release` with code signing disabled — succeeded; the optimized bundle scan and signed full scheme were not rerun.
- Quick Start contrast — the ordinary Timed recommendation reached the real prompt while the Pressure-loss fallback remained on manual Timed setup.
- Accessibility configuration — the focused lane launched at Accessibility XXXL; the iPhone 17 Pro / iOS 26.5 base simulator had Reduce Motion enabled and microphone permission granted.
- Seeded Home / Train / Review / Profile / Settings light sweep — `01_*.png` — expected destinations rendered without a blocking regression.
- Localization preservation — `Noum/Resources/Localizable.xcstrings` — the pre-existing SHA-256 `ee0a735ed8a3c17d5f589d5926a6f2c14e2080a5e35002ed2db3aafb80a6f16a` remained unchanged by this run.

## Surfaces needing visual verification (cloud → local queue)

- Home and Summary capability loss after their recommendation is visibly settled.
- Conversation Practice capability loss and the later IM destination availability race.
- Manual VoiceOver focus and announcement order across the fallback and diagnostic states.
- Real capability/provider changes, physical-device behavior, signed Release, and TestFlight.

## For next run

- **If cloud**: implement or audit the mixed Review-only history boundary without adding a second history/progress owner; do not manufacture simulator or external evidence.
- **If local**: capture the mixed Review/Profile boundary at Accessibility XXXL with Reduce Motion, or collect signed physical evidence when credentials, promotion, hardware, and operator authority exist.
