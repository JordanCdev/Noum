# Noum

Noum is a communication-training app for deliberate speaking practice,
evidence-bounded coaching, and progress review.

## Speech processing and privacy

Production live transcription uses an authenticated, App Check-enforced
Firebase callable to obtain a short-lived Deepgram credential. Long-lived
provider secrets are never bundled in the app. Users explicitly choose whether
cloud processing is allowed; when it is off, or cloud setup fails before audio
starts streaming, Noum uses Apple's on-device Speech framework for practice
where available.

The app records the provider that actually handled each rep. It does not route
one recording to both cloud and local providers. See the in-app Privacy & Data
section and [Privacy Policy](Noum/PrivacyPolicy.md) for the current data-flow
description.

AWS Transcribe remains a legacy development-only provider. Do not put
long-lived AWS credentials in an app target, plist, repository, or release
environment. Development credentials, if needed for a local legacy test, must
be short-lived and injected outside the app bundle.

Google Sign-In requires its normal OAuth configuration. Production Firebase,
App Check, and backend configuration are supplied through the app's
gitignored configuration files and deployed service environment.

Simulator builds use Firebase's App Check debug provider. Register a dedicated
debug token for the iOS app in Firebase Console, keep it outside the repository,
and launch with `FIREBASE_APPCHECK_DEBUG_TOKEN` through
`scripts/run-noum-with-ai.sh`. Never commit or share a registered debug token;
revoke it if it is exposed.

## Product behavior

Noum detects common disfluencies with locale-aware heuristics, retains session
history for review, and uses an evidence-bounded goal read to prescribe the
next practice action. It intentionally labels weak evidence as incomplete
rather than presenting a precise personality or identity score.

## Requirements

Building Noum requires Xcode 15 or later with Swift 6.1 or newer. The package
manifest uses tools version 6.0 for compatibility, but the app depends on
SwiftUI and Apple platform frameworks.
