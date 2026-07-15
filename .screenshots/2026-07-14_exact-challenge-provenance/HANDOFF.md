# Run: 2026-07-14 · branch:ux-overhaul · HEAD 1fb3639d · exact challenge capture provenance

## Mode
light — capture skipped because the changed challenge route is release-disabled, has no production call site, and introduces no reachable rendered-state change.

## Changes shipped (this run)
- `Noum/TimedPracticePromptHandoff.swift` — carries an exact server challenge prompt and its content-free observation intent atomically through the existing opaque account-bound route token.
- `Noum/SocialFriendSheets.swift` and `Noum/TimedPracticeView.swift` — bind the post-create challenge route to Timed capture and drop authority on account or prompt mismatch.
- `Noum/ChallengesManager.swift` and `Noum/SocialAuthorityContracts.swift` — require byte-exact armed prompts and the server's bounded outer-trimmed prompt shape.
- Focused client tests and production-state/audit documents — record the local proof and the still-missing production route/evidence.

## Screenshots
No PNGs. Both `speakOffs` and `competitiveObservation` remain unavailable, the challenge sheets have no production call site, and forcing the dormant route through test-only UI authority would weaken the release boundary rather than verify shipping behavior.

## VISION gap
Exact provenance improves pressure-mode fairness and coaching trust: Noum can no longer silently authorize a whitespace-, case-, or Unicode-different challenge. It still cannot provide a believable peer pressure flow because no calibrated evaluator, eligible producer, hydrated/opponent launch route, or two-device proof exists.

## Next steps to reach desired state
1. Define and independently calibrate the deterministic competitive evaluator and evidence floor before creating any eligible producer.
2. Obtain deployed TTL/retention, live-provider, IAM/App Check, and transformed/post-window replay evidence.
3. Only after authority is earned, connect hydrated/opponent challenges through one coherent production Social launch route and verify it on two TestFlight devices.
4. Disarm abandoned challenge launches when that reachable route is designed; do not add a second challenge or prompt owner.

## Regressions checked
- Five focused iOS suites: 56/56 passed on iPhone 17, iOS 26.4.
- Functions authority contracts: 109/109 passed; deploy blocker: 6/6 passed.
- Ordinary Timed prompt normalization, opaque-token routing, and account teardown remain covered.
- All competitive/social release capability assertions remain false with user-facing explanations.

## Surfaces needing visual verification (cloud → local queue)
- None for the current disabled implementation.
- Future Social challenge list/detail/post-create/Timed flow after an authorized capability exists.

## For next run
- **If cloud**: continue evaluator/evidence-floor contract work without adding an eligible writer.
- **If local**: preserve the disabled route; resume screenshots only after a signed, production-reachable challenge flow exists.
