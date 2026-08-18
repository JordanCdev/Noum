# Run: 2026-08-18 · branch:ux-experiment · HEAD f153bf691 · close the local UX-experiment build/test gates

## Mode

light (five-surface sweep; the simulator's current appearance was dark/system)

## Changes verified in this local candidate

- `Noum/AICoachChatService.swift` and `Noum/CoachReliabilityGate.swift` — keep coach replies evidence-bound, natural, and fail-closed without masking specific recovery paths.
- `Noum/ContentView.swift`, `Noum/BetaFeedbackView.swift`, and `Noum/CoachSessionView.swift` — restore durable setup and child accessibility routes without adding parallel state owners.
- `ProfileView.swift` — reflow the Current Coach Read at accessibility sizes instead of waiving native clipping failures.
- `Noum/DevSeedData.swift` — provide an explicit DEBUG-only, account-scoped first-week fixture through the production contract and memory owner.
- `scripts/release-*.sh` — keep simulator test hosts ad hoc signed so Keychain entitlements survive local verification.
- Owning unit and UI contracts were updated alongside each change; the final source-bound unit, UI, and Release-simulator gates are green.

## Screenshots

- `01_home_top.png` — Today tab, one-rep mission and coach-to-recording handoff.
- `01_train_top.png` — Practice tab, recommendation-first Timed Practice composition.
- `01_review_top.png` — Progress tab, honest no-evidence state with one route to a first rep.
- `01_profile_top.png` — Profile tab, honest no-verified-reps state and one starting direction.
- `01_settings_top.png` — Settings tab, quiet practice and coaching controls.

Each image was opened and inspected. All five expected destinations rendered; none showed a blank frame, splash stall, crash surface, or obvious default-size text collision.

## VISION gap

The captured tabs now read as one restrained communication-coaching system: one recommendation, evidence-scaled claims, quiet progress, and clear trust controls. This light sweep does not prove the VISION's physical-device, live-audio, VoiceOver, Reduce Motion, interruption, or professional-coach outcome requirements. Progress and Profile are intentionally cold in these captures, so longitudinal evidence presentation still needs same-build real-user proof.

## Next steps to reach desired state

1. Restore an authorized Apple Development identity plus device profiles, and an Apple Distribution identity plus App Store profiles, for the target iPhone 13 Pro and shipping targets.
2. Archive, upload, install, and validate one immutable candidate through TestFlight.
3. Run the physical-device VoiceOver, microphone, Bluetooth, offline, interruption, light/dark, small-screen, Accessibility XXXL, and Reduce Motion matrix.
4. Deploy and independently verify the reviewed support/privacy/coaching-trust pages and `noum.app` before changing the active origin.
5. Complete a current live-provider sweep, blinded professional-coach calibration, and longitudinal transfer evidence.

## Regressions checked

- Today — `01_home_top.png` — mission, exact coach target, and one primary rep action render coherently.
- Practice — `01_train_top.png` — recommendation-first hierarchy and progressive catalogue render coherently.
- Progress — `01_review_top.png` — no evidence produces an honest empty state rather than fake metrics.
- Profile — `01_profile_top.png` — no verified reps produces a bounded starting direction without false attribution.
- Settings — `01_settings_top.png` — core controls remain visible and the trust-oriented hierarchy renders coherently.
- Complete serialized `NoumTests` — 4,963 logical tests: 4,962 passed, one expected failure, zero unexpected failures or skips.
- Complete serialized `NoumUITests` — 94/94 passed with zero failures or skips.
- Clean ad hoc-signed Release simulator build — succeeded with zero warnings/errors; simulator signature and release-bundle scan passed.

## Surfaces needing visual verification (cloud → local queue)

- Current-source physical iPhone 13 Pro: all primary tabs plus live practice, Summary, verified reward, Ask Noum, permission recovery, and first-week read.
- Light appearance, iPhone SE-size, Accessibility XXXL, Reduce Motion, VoiceOver, and interruption/background variants on the exact distributed build.
- StoreKit purchase/restore, auth upgrade/sign-out/sign-in/deletion, and live-service failure recovery after TestFlight installation.

## For next run

- **If cloud**: audit the immutable candidate and external evidence ledger; do not claim device, TestFlight, live-provider, or production readiness from local simulator results.
- **If local**: restore signing authority, build/install the exact candidate on the target iPhone 13 Pro, and execute the same-build device matrix above.
