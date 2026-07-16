# Run: 2026-07-16 · branch:ux-overhaul · HEAD ea667cfd4 · durable account-deletion fence and provider admission

## Mode
light

## Changes shipped (this run)
- `Noum/AccountDeletionFence.swift:1` — adds one durable, fail-closed account/provider/request/phase authority across relaunch.
- `Noum/AuthManager.swift:1` — closes scoped provider admission before remote deletion and restores phase-aware recovery.
- `Noum/SettingsView.swift:2416` — explains the temporary, content-free deletion-security record without claiming all server metadata disappears immediately.
- `functions/src/index.ts:2770` — binds deletion to the verified Firebase UID, retains the stale-token write fence, and adds safe pending-state recovery.
- `firestore.rules:1` — denies private writes while either a pending or completed deletion marker exists.
- `Noum/PrivacyPolicy.md:3` and `public/privacy.html:129` — disclose marker contents, cleanup dependencies, and recovery behavior.

## Screenshots
- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab, practice-mode entry.
- `01_review_top.png` — Review tab, recent movement.
- `01_profile_top.png` — Profile tab, coaching focus.
- `01_settings_top.png` — Settings tab, top of view.

## VISION gap
The five primary tab tops still render as one calm communication-training system, and no unrelated navigation or card regression is visible. The safety work in this run is primarily lifecycle and recovery behavior, however: light mode does not render the destructive confirmation sheet, local-cleanup-only state, support-only ambiguous state, or a relaunch with an active deletion fence. Production deployment, TTL behavior, and stale-token rejection also remain unproved by screenshots.

## Next steps to reach desired state
1. Add a deterministic UI-test fixture for confirmation, local-cleanup-only, support-only, and relaunch recovery states in `NoumUITests` and capture those sheets with accessibility sizes.
2. Deploy the reviewed callable, scheduled reconciliation, rules, index, and TTL configuration together; then collect live stale-token, reconciliation, and expiry evidence.
3. Exercise deletion and recovery on a signed physical device with real Apple and Firebase identities.

## Regressions checked
- Home top — `01_home_top.png` — expected preparation and Ask Noum entry rendered.
- Train top — `01_train_top.png` — expected recommended rep and practice library rendered.
- Review top — `01_review_top.png` — expected recent movement and saved-rep entries rendered.
- Profile top — `01_profile_top.png` — expected rating and coaching-focus hierarchy rendered.
- Settings top — `01_settings_top.png` — expected practice controls rendered with no stuck splash or wrong route.

## Surfaces needing visual verification (cloud → local queue)
- Delete Account confirmation disclosure and typed confirmation.
- Remote-uncertain support-only recovery after relaunch.
- Remote-committed local-cleanup-only recovery after relaunch.
- VoiceOver order, larger Dynamic Type, and reduced-motion behavior for those states.

## For next run
- **If cloud**: review remaining backend work and device-global AI diagnostics against the deletion lifecycle and registry.
- **If local**: capture the deletion-state fixtures above, then run signed-device deletion and recovery evidence.
