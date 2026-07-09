# Run: 2026-07-09 · branch:integration/prod-readiness · app source e15f88cb · production-readiness UI gate sweep

## Mode
light

## Changes shipped (this run)
- `Noum/CoachSessionView.swift:91` — routes day-zero users to the existing typed Ask Noum surface and rechecks completed-practice evidence before exposing a live call.
- `Noum/LiveCoachCallView.swift:261` — defensively blocks live-call startup, microphone activation, and utterance dispatch when no completed rep exists.
- `Noum/SummaryView.swift:768` — puts the prescribed drill directly after FIX FIRST, ahead of Ask/Pro and the final exit actions.
- `Noum/PostRepVerdictCard.swift:599` — centralizes the prescribed-drill rendering in `SummaryDrillActionCard`, preserving one recommendation owner and one routing path.
- `Noum/PremiumManager.swift:534` — presents renewal disclosure and legal links beside storefront-localized pricing; this surface is outside the light sweep.
- `Noum/ContentView.swift:422` — reserves clearance above the shortcut dock and gives its existing backdrop an opaque top edge so scrolling card text cannot compete beneath the controls.

## Screenshots
- `01_home_top.png` — Home surface, top of view
- `01_train_top.png` — Train deep link (next-rep practice picker)
- `01_review_top.png` — Review surface (progress and coaching read)
- `01_profile_top.png` — Profile surface
- `01_settings_top.png` — Settings surface

## VISION gap
The captured tab tops reinforce the evidence-led loop: Home keeps the upcoming real moment and next practice prominent, Train gives one observable target, Review frames thin movement as worth a closer look, and Profile names the evidence depth behind its read. The two UI changes most important to this run are not visible in light mode, however: the zero-rep Ask Noum typed gate and the post-rep FIX FIRST → prescribed drill ordering need seeded, dedicated captures before they have visual release evidence. Home was recaptured after the dock-clearance fix; the next card remains a scroll cue while an opaque calm backdrop prevents readable content from competing beneath the controls. Professional-coach parity also remains unproven until these coherent in-app reads are validated against real-world transfer and repeated user outcomes.

## Next steps to reach desired state
1. Add deterministic zero-rep Ask Noum and seeded Summary launch states to `NoumUITests/ScreenshotTour.swift`, then capture the typed evidence gate, absence of “Start coach call,” and the complete FIX FIRST → prescribed drill → Ask/Pro → Done sequence.
2. Add Paywall and in-app Privacy Policy captures to `NoumUITests/ScreenshotTour.swift` to verify localized pricing, renewal copy, legal-link hierarchy, and the updated processor disclosure on-device.

## Regressions checked
- Home deep link — `01_home_top.png` — expected evidence-led dashboard rendered after the dock-clearance patch; no splash/crash and no readable card content competes beneath the floating controls.
- Train deep link — `01_train_top.png` — recommended Timed Practice, proof target, primary CTA, and adjustment affordance rendered without clipping.
- Review deep link — `01_review_top.png` — stable progress chart and Coach's read rendered correctly after six seconds; the first three-second capture caught an incomplete header transition, so launch-transition polish remains worth checking.
- Profile deep link — `01_profile_top.png` — rating, evidence-depth label, and coach read rendered without blank or overlapping content.
- Settings deep link — `01_settings_top.png` — profile card, practice defaults, and toggles rendered without blank or overlapping content.

## Surfaces needing visual verification (cloud → local queue)
- Zero-session Ask Noum typed gate, including hidden live-call action and first-rep explanation.
- Returning-user live-call entry and reduced-motion type/live transitions.
- Post-rep Summary order, prescribed-drill CTA variants, and final Done/Practice again actions.
- Paywall localized price, renewal disclosure, Privacy Policy link, and EULA link.
- In-app Privacy Policy processor/retention copy.
- Dynamic Type and VoiceOver focus order for every changed surface.

## For next run
- **If cloud**: add deterministic launch fixtures and accessibility assertions for the uncaptured Ask Noum, Summary, Paywall, and Privacy surfaces without changing production state ownership.
- **If local**: switch to detailed mode after the fixtures land, capture those focus surfaces, and verify the Home dock backdrop at large Dynamic Type sizes.
