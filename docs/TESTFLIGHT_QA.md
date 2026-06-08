# Noum — TestFlight QA checklist (M14)

Real-device QA pass before promoting a TestFlight build to public review.
Most surfaces are covered by simulator + unit tests; this list is the
specific set of things that **only work right on hardware** or that have
never been touched on a real device this milestone series.

## Pre-flight

- [ ] **Firestore rules deployed** — `firebase deploy --only firestore:rules`.
      Without this, league + peer surfaces silently return empty arrays.
      Verify via the Firebase console that `profiles_public/*`,
      `leagues/*/members/*`, and `challenges/*` rules match
      `FIRESTORE_RULES.md`.
- [ ] **Hosting deployed** — `firebase deploy --only hosting`.
      Verify `https://noum-d0b6f.web.app/privacy` resolves to the
      styled page; submit that URL in App Store Connect's privacy
      policy field.
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

### Paywall + StoreKit 2
- [ ] Settings → Subscription → opens the paywall card.
- [ ] Tap Monthly — sandbox purchase flow shows native iOS sheet.
- [ ] Tap Annual — same.
- [ ] **Restore Purchase** while signed into a previous-test sandbox
      account — entitlements re-apply.
- [ ] Subscription status reflected in: Coach Mode unlocked, Live
      Transcript unlocked, Filler Tracking unlocked.

### AI prompt latency (M7)
- [ ] In Settings → Developer Tools, pick a real provider with a key.
- [ ] Tap Begin on a Timed session a few times in a row.
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

- [ ] Sign out → sign back in via Apple → all data reloads cleanly.
- [ ] Sign in via Google → same.
- [ ] Sign in as Guest → upgrade to Apple later → guest data merges
      (or is preserved per the documented account-merge flow).
- [ ] **Delete account** in Settings → confirm Firebase user deletes,
      all per-account UserDefaults wipe, app returns to onboarding.
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
      This verifies the local Release simulator configuration only; it
      does not replace device archive, signing, or TestFlight upload QA.
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

## Widgets

- [ ] Add the streak widget to the home screen.
- [ ] Run a session → widget reflects new rep count + streak within
      ~5 minutes.
- [ ] Lock-screen circular widget renders without clipping.

## Known issues (acceptable for this build)

These are documented in `docs/CURRENT_STATE.md` and the brutally-honest
grade card. Don't gate the build on them:

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
