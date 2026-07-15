# Run: 2026-07-14 · branch:ux-overhaul · HEAD 5aa8e728 · bounded cross-account competitive replay authority

## Mode
light

## Changes shipped (this run)
- `functions/src/competitiveObservation.ts` and `functions/src/index.ts` — replaced per-account exact-audio replay state with one bounded server-only cross-account claim.
- `firestore.rules` and `firestore.indexes.json` — denied the global claim collection and declared source TTL fields.
- `privacy/processors.json` and generated disclosure surfaces — disclosed the account-unlinked seven-day replay tombstone and deletion exception.
- `docs/RESEARCH_IMPLEMENTATION_AUDIT.md` — preserved the NO-GO score and missing external proof.

## Screenshots
- `01_home_top.png` — deep link intercepted by account persistence recovery screen; Home was not verified.
- `01_train_top.png` — same recovery screen; Train was not verified.
- `01_review_top.png` — same recovery screen; Review was not verified.
- `01_profile_top.png` — same recovery screen; Profile was not verified.
- `01_settings_top.png` — same recovery screen; Settings and the in-app privacy disclosure were not verified.

## VISION gap
The backend change strengthens coaching trust and fair pressure-aware competition without enabling the unfinished competitive path. The local simulator cannot currently reach the calm, cohesive product surfaces because account bootstrap fails before navigation, so visual coherence and the updated in-app privacy copy remain unproved.

## Next steps to reach desired state
1. Diagnose the simulator account-persistence failure through the existing `AuthManager` / coaching-profile bootstrap owners before capturing visual evidence.
2. Re-run the light sweep from the same source-bound build after bootstrap succeeds, then open `PrivacyPolicyView.swift` for focused disclosure verification.
3. Keep competitive observation disabled until deployed TTL, provider, evaluator, provenance, and external release evidence exist.

## Regressions checked
- App launch — all five captures — app renders an explicit retry state rather than crashing, but tab navigation is blocked and therefore not regression-verified.
- Generated privacy manifest — clean arm64 Release simulator build succeeded; visual disclosure rendering was not reached.

## Surfaces needing visual verification (cloud → local queue)
- Home, Train, Review, Profile, and Settings tab tops after account bootstrap succeeds.
- In-app privacy policy section describing the seven-day account-unlinked replay claim.

## For next run
- **If cloud**: continue backend/evaluator contract work that does not require simulator evidence.
- **If local**: repair or seed account bootstrap, then repeat the light sweep and capture the privacy disclosure.
