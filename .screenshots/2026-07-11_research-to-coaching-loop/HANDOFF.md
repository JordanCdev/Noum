# Run: 2026-07-11 · branch: ux-overhaul · research-to-coaching loop

## Mode
light, plus one targeted Review-detail capture

## Changes shipped (this run)
- Transactional first run establishes a verified Firebase or Keychain-backed guest identity before onboarding can persist a coaching profile.
- Restored remote-unknown accounts use a bounded, retryable recovery state; only authoritative server absence can expose onboarding.
- `AuthManager` is the sole anonymous-auth owner; Firebase Core, App Check, and Remote Config start once.
- Session detail adds a semantic **Practice this mode** button using the existing replay router and tab-owned navigation path.
- Noum's top-level privacy manifest and both policy copies now match app-owned data, bundled vendor declarations, local fallback identity, and production Ask Noum transport.
- Finance-specific recommendations from the inaccessible-repository report were rejected because Noum is a communication-training system.

## Screenshots
- `01_home_top.png` — Home top with the active real-world moment, next prep action, Ask Noum, and persistent tab shell.
- `01_train_top.png` — Train top with one recommended Filler Control rep and the structured practice library.
- `01_review_top.png` — Review top with recent movement, evidence count, and entry into the latest rep.
- `01_profile_top.png` — Profile top with rating, evidence qualifier, and current coaching focus.
- `01_settings_top.png` — Settings top with practice defaults and clear toggle states.
- `02_review_detail_practice_mode.png` — targeted session-detail proof of the 64-point mode-tinted **Practice this mode** action.

## VISION gap
The capture shows a coherent coach loop: current evidence names the next focus, Train offers the matching rep, and Review can now send a user directly back into practice. It does not prove human-coach parity, real-world transfer, or longitudinal recommendation quality. Auto-guided first-rep launch remains default-off until real-device felt QA supports enabling it. The hosted privacy source is current, but public deployment and real-device App Check/auth verification remain M14 release work.

## Next steps to reach desired state
1. Run the first-run, restored-account recovery, and Review replay paths on a physical device with poor/no connectivity and VoiceOver enabled.
2. Deploy `public/privacy.html` and Firestore rules, then verify the public policy URL from Settings before TestFlight.
3. Consider a server-authoritative profile-only lookup so restored-account routing is not coupled to slower session/recommendation hydration.

## Regressions checked
- Home, Train, Review, Profile, and Settings deep links rendered populated seeded states without blank screens, clipped headers, or modal interception.
- The erased iOS 26.4 simulator completed guest establishment, onboarding persistence, and Timed Practice routing.
- The Review detail button exposed a semantic button identifier, measured at 64 points high, and navigated to `timedPractice.screen`.
- Existing IM replay routing remains locked to the recorded scenario and target tone by focused contracts.
- Reduced-motion launch/retry surfaces retain their static alternatives; the touched Review action adds no animation owner.

## Surfaces needing visual verification
- Physical-device VoiceOver focus and activation for **Practice this mode**.
- Restored Apple/Google account recovery during a real offline/slow-network transition.
- In-app Privacy & Data policy rendering after the public hosted copy is deployed.
- Large Dynamic Type on the Review detail action and initial-account recovery card.

## For next run
- **If cloud**: keep finance-specific work out of scope; add only deterministic contracts for the profile-only recovery refinement.
- **If local**: use detailed mode on a physical device for VoiceOver, Dynamic Type, connectivity transitions, and public-policy-link QA.
