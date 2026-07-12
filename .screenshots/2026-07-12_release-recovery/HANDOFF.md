# Run: 2026-07-12 · branch:ux-overhaul · HEAD b9258cb7 · release-readiness recovery

## Mode

Light screenshot sweep: the five top-level destinations were launched through signed Debug deep links and inspected on the iPhone simulator.

## Changes shipped

- `Noum/KeychainHelper.swift`: made identity persistence update-or-add so an existing Keychain item no longer causes a silent save failure.
- `Noum/PracticeSupport.swift`: enforced the cloud-processing consent boundary and retained only explicit DEBUG UI-test overrides.
- `Noum/SpeechRecognizerViewModel.swift`: added typed recording lifecycle and deterministic provider-start test seams.
- `functions/src/index.ts`: made account deletion fail closed until the social-data cutover is complete.
- `docs/PRODUCTION_READINESS_RUNBOOK.md`: recorded the current no-go gates and evidence requirements.

## Screenshots

- `01_home_top.png` — Home cold state and primary navigation.
- `02_train_top.png` — Training mode selection.
- `03_review_top.png` — Review cold state.
- `04_profile_top.png` — Profile and progress surface.
- `05_settings_top.png` — Settings and honest simulator microphone-blocked state.

## Vision gap

The visual system remains calm, cohesive, and premium across the main destinations. Release trust is still blocked by evidence outside this simulator sweep: the historical credential incident is not contained, Apple/StoreKit and real-microphone behavior are not verified on a signed physical device, social competitive evidence is not yet server-produced, account deletion cannot complete through every provider path, and the custom privacy domain is still parked.

## Regressions checked

- Fresh-install identity and onboarding persistence.
- Cloud-processing consent allow/decline behavior.
- Failed recording start does not create progress.
- Signed Release simulator build and bundle-secret scan.
- Complete signed simulator unit and UI suites.
- Functions lint, build, unit tests, and Firestore emulator rules.
- Hosted privacy disclosure and cloud-operation probes.
- VoiceOver-facing top-level navigation labels in the UI suite.

## Next steps

1. Contain the historical Deepgram/AWS credential incident and document revocation and usage review.
2. Configure Apple authentication and StoreKit under the paid Apple Developer team, then run the signed physical-device/TestFlight sweep.
3. Obtain explicit approval before backing up and purging untrusted legacy social rows; do not enable competitive social writes until a trusted evidence producer exists.
4. Point `noum.app` DNS at Firebase Hosting and verify `/privacy` over valid TLS.

## Next local run

Use a signed physical device to verify App Check, real microphone/provider behavior, Bluetooth and interruptions, purchase/restore, Apple and Google account linking, deletion, notifications, widgets, Live Activities, VoiceOver, Dynamic Type, and reduced motion.
