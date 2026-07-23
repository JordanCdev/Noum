# Run: 2026-07-21 · branch:ux-overhaul · HEAD 6f0d80352 · App Store success gap foundation

## Mode
light — five source-current tab roots plus two focused Day-0 UI-test captures.

## Changes shipped (this run)
- `Noum/FastLaneOnboardingView.swift:322` — makes the user-started 30-second spoken proof the primary action after permissionless first value.
- `Noum/FirstWeekCoachingContract.swift:247` — projects the activation-relative first-week program from existing evidence owners.
- `Noum/ContentView.swift:1343` — exposes the durable first-week read from Home.
- `Noum/PremiumManager.swift:1120` — renders StoreKit-authoritative plans, verified trial context, purchase state, and restore.
- `Noum/GrowthObservability.swift:12` — adds the bounded growth/commercial event vocabulary and privacy guard.
- `Noum/NotificationCopy.swift:27` — attributes existing notification opens without user speech content.
- `Noum/HowNoumCoachesView.swift:54` — explains evidence floors, uncertainty, and privacy boundaries in-app.
- `Noum/AppReviewPrompt.swift:38` — defers eligible review requests to an explicit Summary exit.

## Screenshots
- `01_home_top.png` — Home, currently showing the seeded upcoming-moment plan.
- `01_train_top.png` — plan-first Train with the full library behind **Choose for myself**.
- `01_review_top.png` — compact evidence-led Review root.
- `01_profile_top.png` — Profile and current coaching focus.
- `01_settings_top.png` — Settings root.
- `02_day0_first_value.png` — permissionless first value, evidence boundary, and spoken-proof action.
- `03_day0_deferred_setup_home.png` — Home after choosing to explore before completing coaching setup.

All seven PNGs were opened and visually inspected. They render nonblank,
portrait, source-current app surfaces with the expected route and no clipped
primary action.

## VISION gap
The app now makes Noum's evidence promise visible at activation, recommends one
rep instead of presenting an exercise wall, and connects the first week to one
unfinished coaching step. It still cannot claim professional calibration or
real-world improvement: those require the live-provider, blinded-coach,
physical-TestFlight, and closed-beta gates in `docs/MANUAL_LAUNCH_ACTIONS.md`.

## Next steps to reach desired state
1. Seed and capture the Day-7 Home card and `firstWeekRead` detail surface.
2. Configure £11.99 monthly / £79.99 annual plus the eligible seven-day annual trial in App Store Connect, then capture the real-store paywall.
3. Deploy `public/privacy.html`, `public/support.html`, and `public/how-noum-coaches.html`; rerun `scripts/validate-app-store-package.py --verify-live-urls`.
4. Complete signed physical TestFlight and the human evidence program before changing production status.

## Regressions checked
- Tab routing — five light captures — each deep link lands on its expected selected tab.
- Plan-first Train — `01_train_top.png` — one recommendation remains primary and free selection remains discoverable.
- Day-0 proof boundary — `02_day0_first_value.png` — written evidence does not claim spoken delivery; microphone capture does not start automatically.
- Deferred setup — `03_day0_deferred_setup_home.png` — Home preserves a clear resume path.
- Source-current automation — 79 focused unit tests and two focused Day-0 UI tests passed on the signed simulator build.

## Surfaces needing visual verification (cloud → local queue)
- Day-7 **Your first week** card and detail with verified-example and insufficient-evidence variants.
- StoreKit paywall in eligible-trial, ineligible, loading, purchase-pending, failure, and restore states.
- **How Noum coaches** in-app detail and the three production web pages after deployment.
- Review request behavior after explicit Summary exit on a physical TestFlight build.

## For next run
- **If cloud**: validate App Store metadata/copy drift and the aggregate event privacy contract.
- **If local**: capture the Day-7 read, StoreKit sandbox paywall, and physical-device permission/lifecycle matrix.
