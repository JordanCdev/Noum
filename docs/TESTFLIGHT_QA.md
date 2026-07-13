# Noum — TestFlight QA checklist (M14)

Real-device QA pass before promoting a TestFlight build to public review.
Most surfaces are covered by simulator + unit tests; this list is the
specific set of things that **only work right on hardware** or that have
never been touched on a real device this milestone series.

Runtime sign-off is recorded in `coach-real-device-testflight-qa-v3.json` as
an exact 14-surface, 77-check contract. The check-key mapping and required
attachment kinds are documented in `docs/PRODUCTION_EVIDENCE_COLLECTION.md`.
Pre-flight security, deployment, Apple configuration, upload, and triage work
stays in `coach-operational-launch-checklist-v2.json`.

**Current verdict (2026-07-11): NO-GO for external TestFlight or App Store
release.** Checked infrastructure items below are configuration evidence only;
they do not override an unchecked release blocker or signed-device test.

## Pre-flight

- [ ] **Historical Deepgram incident contained** — complete every closure
      check in `docs/SECURITY_deepgram_key_endpoint.md`. The replacement
      Firebase path is live, but the exposed legacy credentials and AWS routes
      remain an open incident. Revoke the credentials, disable or authenticate
      every legacy transcription/IM/TTS route, and audit provider usage and
      billing before inviting external users.
- [x] **Production transcription boundary configured** — the release app uses
      the Firebase `transcriptionToken` callable, which requires Firebase Auth
      and App Check, rate-limits by UID, and returns short-lived Deepgram access
      minted from a server-only Secret Manager credential. This still requires
      the physical-device checks below.
- [ ] **Social cutover completed** — **do not deploy the repository's social
      Firestore rules or social functions yet.** First back up and quarantine
      the legacy client-authored social data, complete the explicit cutover,
      and deploy a trusted server-side session-evidence producer. Then rerun
      emulator authorization/replay tests and deploy the reviewed rules and
      functions together. Until then, league/challenge actions must remain
      unavailable rather than accepting client-authored ratings or results.
      Only after that gate passes, the coordinated release includes
      `firebase deploy --only firestore:rules`; this command is recorded here
      for the approved cutover, not as authorization to run it now.
- [x] **Firebase Hosting privacy page deployed** — verify
      `https://noum-d0b6f.web.app/privacy` returns the current styled Noum
      policy. This is the live privacy URL currently used by the app. The
      repeatable deployment command is `firebase deploy --only hosting`.
- [ ] **Custom privacy domain connected** — `noum.app` is still serving parked
      GoDaddy DNS, so `https://noum.app/privacy` is not proof of Noum's hosted
      policy. Point the domain at Firebase Hosting and verify TLS plus policy
      content before claiming the custom domain is live.
- [ ] **Apple release services configured** — configure Sign in with Apple as
      a Firebase provider and use a paid Apple Developer team with the required
      entitlements/signing. Verify the StoreKit products and metadata in App
      Store Connect. Apple authentication, archive signing, StoreKit purchase/
      restore, and all signed-device QA remain blocked until this is complete.
- [ ] **Build version bumped** in Xcode + change notes drafted in App
      Store Connect.

## High-risk surfaces (must verify on device)

### Live Activity
- [ ] Start a Sudden Death session, lock the device.
- [ ] Confirm Dynamic Island compact + expanded states render (filler
      count + round badge).
- [ ] Confirm lock-screen presentation matches design (no cropped
      content, no fallback rectangle).
- [ ] Finish the session — Live Activity dismisses cleanly.
- [ ] Force-quit mid-round — Live Activity ends, doesn't ghost.

### Audio session + soundscape
- [ ] In Settings → Pre-rep prep, pick **Focus**, **Calm**, **Steady**.
- [ ] Verify each plays cleanly during the thinking phase of a Timed
      session and **stops the moment recording starts** (not after
      first word).
- [ ] Phone call mid-rep — audio yields, returns cleanly.
- [ ] Spotify playing → start a rep → soundscape mixes politely;
      Spotify keeps playing.

### Production transcription + cloud consent
- [ ] On an erased install, finish guest identity bootstrap, complete
      onboarding, grant cloud-processing consent, and finish a real-microphone
      rep through the production Firebase-to-Deepgram token path.
- [ ] Inspect network traffic: no audio, transcript, profile, or session data
      leaves the device before the versioned consent record is accepted.
- [ ] Decline and later revoke consent. Confirm supported on-device
      transcription/local coaching remains local; where unavailable, show the
      cloud-required explanation and Settings route without transmitting.
- [ ] Simulate provider-start failure, mid-session disconnect, interruption,
      Bluetooth route change, silence, and final-word delay. No failed or empty
      attempt may persist, score, award XP, or advance a timer as a valid rep.
- [ ] Inspect the signed `.app`/archive and confirm it contains no long-lived
      provider credential or ignored development configuration plist.

### Paywall + StoreKit 2
- [ ] Settings → Subscription → opens the paywall card.
- [ ] Tap Monthly — sandbox purchase flow shows native iOS sheet.
- [ ] Tap Annual — same.
- [ ] **Restore Purchase** while signed into a previous-test sandbox
      account — entitlements re-apply.
- [ ] Subscription status reflected in: Coach Mode unlocked, Live
      Transcript unlocked, Filler Tracking unlocked.

### AI prompt latency (M7)
- [ ] With cloud consent accepted and the production provider selected, tap
      Begin on a Timed session a few times in a row.
- [ ] Confirm the 3-second budget actually caps slow API calls
      (UI never hangs more than ~3.2s before the prompt appears).
- [ ] On airplane mode, Timed session still gets a curated-pool
      prompt instantly.

### Pitch metrics (M10)
- [ ] Record a clearly varied-pitch rep (questioning intonation,
      emphasis on key words). Pitch summary card shows "Varied
      delivery" with stdev ≥ 25Hz.
- [ ] Record a deliberately monotone rep. Card shows "Pitch sat
      flat" with stdev ≤ 10Hz.
- [ ] Record a 3-second whisper. Card hides itself (insufficient
      voiced ratio).

### Multilingual (M12 + M13)
- [ ] Settings → Practice language → Spanish. Run a Spanish rep —
      transcription works, filler detection picks up "este"/"pues"/
      "eh" correctly.
- [ ] Same for French — "euh"/"ben"/"alors".
- [ ] AI debrief on a non-English session shows the deterministic
      template fallback (not English coaching text).
- [ ] Switch back to English → next session uses the AI-generated
      prompt path again.
- [ ] Settings section labels translate to Spanish/French when the
      locale is switched (Practice → Práctica → Entraînement).

## Smoke tests (one rep per mode)

- [ ] Timed (15s / 30s / 60s difficulty)
- [ ] Sudden Death (Easy / Medium / Hard)
- [ ] Ah Counter (free-form)
- [ ] IM Conversation (workUpdate scenario, professional tone)
- [ ] One mini-drill: BeatTheBrake / LandThePause / PREPStack
- [ ] Cut the Crutch
- [ ] One Lesson (any of the five)
- [ ] One path node unlock

## Settings + lifecycle

- [ ] After the Apple/Firebase setup prerequisite passes, sign out → sign back
      in via Apple → all data reloads cleanly.
- [ ] Sign in via Google → same.
- [ ] Sign in as Guest → upgrade to Apple later → guest data merges
      (or is preserved per the documented account-merge flow).
- [ ] **Delete account** in Settings → confirm a server failure keeps the user
      signed in with retry UI. On success, confirm every registered local and
      remote data store is removed, the Firebase Auth user is deleted, Apple
      authorization is revoked when applicable, and the app returns to
      onboarding without claiming that an App Store subscription was cancelled.
- [ ] Reduce Motion on → splash orbs + confetti are subdued.
- [ ] Dynamic Type at largest accessibility size → home + summary
      don't crop critical CTAs (known partial-coverage issue per
      the grade card; flag any new regressions).

## Notifications

- [ ] First finished rep → notification pre-prompt sheet appears.
- [ ] Accept all → iOS native prompt fires once, all four surfaces
      arm without re-prompting.
- [ ] Decline → 30-day cooldown honoured (no nag for a month).
- [ ] Streak warning fires evening-before a break (set device clock
      forward to test).

## Simulator regression gates

- [x] 2026-06-08 — `xcodebuild build -scheme Noum -configuration
      Release -destination 'platform=iOS Simulator,name=iPhone 17'`:
      `BUILD SUCCEEDED`. Product:
      `DerivedData/Noum/Build/Products/Release-iphonesimulator/Noum.app`.
      Re-run after the DEBUG-only celebration overlay screenshot harness
      landed in `7715ae3`: `BUILD SUCCEEDED`. This verifies the local
      Release simulator configuration only; it does not replace device
      archive, signing, or TestFlight upload QA.
- [x] 2026-06-08 — `xcodebuild test -scheme Noum -destination
      'platform=iOS Simulator,name=iPhone 17' -only-testing:NoumTests`:
      `TEST SUCCEEDED`. `xcresulttool` summary: 2,257 passed, 0 failed,
      0 skipped. Result bundle:
      `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_17-43-21-+0100.xcresult`.
- [x] 2026-06-08 — `xcodebuild test -scheme Noum -destination
      'platform=iOS Simulator,name=iPhone 17'
      -only-testing:NoumUITests/NoumUITests/testHomeScreenAndPrimaryNavigation
      -only-testing:NoumUITests/NoumUITests/testPracticeModesOpenAvailableScreens
      -only-testing:NoumUITests/NoumUITests/testOnboardingFlowSmoke`:
      `TEST SUCCEEDED`. Result bundle:
      `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_17-31-39-+0100.xcresult`.
- [x] 2026-06-08 — `xcodebuild test -scheme Noum -destination
      'platform=iOS Simulator,name=iPhone 17'
      -only-testing:NoumUITests/ScreenshotTour/testCaptureAdvancementSurfaces`:
      `TEST SUCCEEDED`. Result bundle:
      `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_17-35-42-+0100.xcresult`.
- [x] 2026-06-08 — `xcodebuild test -scheme Noum -destination
      'platform=iOS Simulator,name=iPhone 17'
      -only-testing:NoumUITests/ScreenshotTour/testCaptureCelebrationOverlays`:
      `TEST SUCCEEDED`. Result bundle:
      `DerivedData/Noum/Logs/Test/Test-Noum-2026.06.08_18-08-49-+0100.xcresult`.
      Attachments were exported to `/tmp/noum-overlay-attachments-2` and
      spot-checked for post-session progression, personal-best, level-up,
      and achievement-unlock overlay rendering at default text size.
- [x] 2026-06-08 — light screenshot workflow rerun after the ordinary badge
      typography pass. The app launched and produced five nonblank 1206x2622
      captures in `.screenshots/2026-06-08_autostop-11a1401-1836/`, but all
      five deep-link shots visually landed on the same Home/Train-like surface.
      Do not treat this as per-tab visual QA; use the detailed tour or repair
      the light capture route before relying on it for tab-specific evidence.

## Widgets

- [ ] Add the streak widget to the home screen.
- [ ] Run a session → widget reflects new rep count + streak within
      ~5 minutes.
- [ ] Lock-screen circular widget renders without clipping.

## Known issues (acceptable for this build)

These are documented in `docs/CURRENT_STATE.md` and the brutally-honest
grade card. Don't gate the build on them. The unchecked pre-flight release
blockers above are **not** acceptable known issues and cannot be waived here:

- `NoumWatch` target detached from the iOS scheme until the
  watchOS 26.2 simulator runtime is installed locally.
- Hardcoded English strings remain across most views — only
  Settings section labels + ~30 keys are localised in M13.

## Sign-off

Date: __________
Tester: __________
Build: __________
Result: pass / fail (notes below)

---

If pass: tag in App Store Connect → submit for review.
If fail: file each fail as a separate task; don't bundle.
