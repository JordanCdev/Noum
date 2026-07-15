# Run: 2026-07-15 · branch:ux-overhaul · HEAD b5747542 · exact Path unlock provenance

## Mode
light

## Changes shipped (this run)
- `Noum/PathProgressManager.swift` — compares a pre-append unlock snapshot with post-finalization state and retains the exact triggering session ID.
- `Noum/PracticeSupport.swift` — emits the Path event inside the common durable practice finalization boundary.
- `Noum/PathNode.swift` — gives all general Path criteria one shared finalized-rep eligibility floor while preserving stricter filler evidence.
- `Noum/ContentView.swift` and `Noum/PathNodeCelebration.swift` — resolve proof and stat copy from the triggering session instead of array position.

## Screenshots
- `01_home_top.png` — Home tab, top of view; expected Timed fallback card rendered.
- `01_train_top.png` — Train tab, recommended rep and practice library rendered.
- `01_review_top.png` — Review tab, recent movement and rep links rendered.
- `01_profile_top.png` — Profile tab, coaching focus and outcome check rendered.
- `01_settings_top.png` — Settings tab, practice controls rendered.

## VISION gap
VISION requires believable progress and coaching trust. The implementation now binds a Path landmark to the exact finalized rep that earned it and prevents sub-floor or evaluation-only sessions from advancing general criteria. This light sweep proves the surrounding shell still renders, but it does not force a real landmark event and therefore does not visually prove the overlay's exact-session evidence line.

## Next steps to reach desired state
1. Add a deterministic, account-isolated launch fixture or UI test in `NoumUITests/ScreenshotTour.swift` that finalizes one eligible rep across a known Path threshold and asserts the resulting landmark copy against that session.
2. Repeat the earned-unlock flow on a signed physical TestFlight device with VoiceOver and Reduce Motion enabled.

## Regressions checked
- Home top — `01_home_top.png` — no launch, routing, or top-level layout regression.
- Train top — `01_train_top.png` — no launch, routing, or top-level layout regression.
- Review top — `01_review_top.png` — no launch, routing, or top-level layout regression.
- Profile top — `01_profile_top.png` — no launch, routing, or top-level layout regression.
- Settings top — `01_settings_top.png` — no launch, routing, or top-level layout regression.

## Surfaces needing visual verification (cloud → local queue)
- Earned `PathNodeCelebration` with exact triggering-session stat and proof.
- Reduce Motion and VoiceOver behavior for the earned celebration.

## For next run
- **If cloud**: add a deterministic source/pure contract only if it preserves the current store and routing owners.
- **If local**: capture the exact earned landmark overlay and its reduced-motion state; do not infer it from the five-tab sweep.
