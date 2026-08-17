# Noum — TestFlight QA checklist (M14)

Real-device QA pass before promoting a TestFlight build to public review.
Most surfaces are covered by simulator + unit tests; this list is the
specific set of things that **only work right on hardware** or that have
never been touched on a real device this milestone series.

Runtime sign-off is recorded in `coach-real-device-testflight-qa-v3.json` as
an exact 14-surface, 84-check contract. The check-key mapping and required
attachment kinds are documented in `docs/PRODUCTION_EVIDENCE_COLLECTION.md`.
Pre-flight security, deployment, Apple configuration, upload, and triage work
stays in `coach-operational-launch-checklist-v2.json`.

**Current verdict (2026-07-19): NO-GO for external TestFlight or App Store
release.** Checked infrastructure items below are configuration evidence only;
they do not override an unchecked release blocker or signed-device test.

## Pre-flight

- [x] **Historical Deepgram incident contained** — the 2026-07-18 closure in
      `docs/SECURITY_deepgram_key_endpoint.md` records deletion of the legacy
      API, revocation/replacement of the exposed credentials, usage review, and
      a fail-closed full-history scan. The residual AWS account-wide resource
      inventory and independently verified operational evidence remain launch
      actions; they do not reopen the known endpoint incident or satisfy the
      operational launch artifact by themselves.
- [ ] **Firebase release sessions re-established safely** — revoke both cached
      Firebase CLI sessions exposed during the 2026-07-13 inspection,
      reauthenticate the required release account, and obtain independent
      verification. Historical CLI output is not proof that this workspace is
      currently or safely authenticated.
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
      functions together. Before that deployment, inventory private profile
      enum values and migrate any unknown legacy value explicitly so the
      stricter Codable-aligned write contract cannot strand an existing profile.
      Until then, league/challenge actions must remain
      unavailable rather than accepting client-authored ratings or results.
      Only after that gate passes, the coordinated release includes
      `firebase deploy --only firestore:rules`; this command is recorded here
      for the approved cutover, not as authorization to run it now.
- [x] **Firebase Hosting privacy page deployed** — verify
      `https://noum-d0b6f.web.app/privacy` returns a styled Noum policy. This
      checked item proves the live hosting endpoint exists; it does not prove
      the manifest-v3 generated body was redeployed after the latest processor
      change. The URL is the live privacy URL currently used by the app. The
      source-bound wrapper is `node scripts/deploy-hosting.mjs --execute`; it
      is the only authorized route for the underlying
      `firebase deploy --only hosting` operation, but it
      is not authorized from this workspace until the exposed-session closure
      above is complete. After authorized verification or deployment, compare
      the hosted body with the generated disclosure before release sign-off.
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
- [ ] With an eligible sandbox account, Annual shows the seven-day trial,
      exact trial end date, renewal price/period, cancellation route, and
      StoreKit-confirmed eligibility. Starting it produces an active trial.
- [ ] With an ineligible sandbox account, Annual never promises a trial.
- [ ] Advance StoreKit time through renewal — entitlement and the lifecycle
      snapshot remain active without a duplicate purchase.
- [ ] Cancel while active — access remains until the verified expiry date,
      then closes at expiry.
- [ ] Exercise billing retry and any configured grace period. Noum follows the
      verified StoreKit state and never grants access from stale local state.
- [ ] Refund/revoke the transaction — Pro access closes and the lifecycle read
      records revocation/refund without retaining receipt or account content.
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

## Supplemental research-loop regression

These checks supplement the fixed 14-surface/84-check release-evidence schema;
they do not silently change or satisfy that independent contract.

- [ ] On Train with no rated evidence, a Pressure recommendation resolves as
      one coherent Timed card: title, rationale, focus/target, CTA, and route all
      describe Timed. Repeat with Conversation unavailable; no stale scenario or
      tone survives.
- [ ] Leave Train visible while Pressure or Conversation capability is removed,
      then tap the previously rendered action. It falls back to Timed without
      logging acceptance of the unavailable mode. Capability returning does not
      silently upgrade a Timed fallback the user already saw.
- [ ] Open Prep with Pressure locked and Conversation unavailable. The three
      planned rehearsal shapes remain distinct, fallback steps use honest Timed
      labels/routes, and completing Timed does not mark Pressure or audience
      simulation rehearsed. Each unavailable pressure/audience step receives a
      category-appropriate prompt containing no custom moment title or transcript,
      and that prompt appears only on the Timed route launched from that step.
- [ ] Save a safe rewrite, open Phrase bank, choose “Use in Week N”, and confirm
      Home offers the current-week saved-line action. Tap it and verify Timed
      receives that exact bounded prompt once.
- [ ] Delete or replace the assigned phrase, regenerate/change the current plan,
      and cross a plan-week boundary before tapping an older Home action. Each
      stale path is withheld or shows the unavailable message rather than
      launching old text.
- [ ] Arm a saved phrase, then sign out or switch accounts before Timed consumes
      it. The next account receives no prompt; relaunching the app also clears
      the process-local handoff.
- [ ] Arm prompts from two different surfaces, or abandon one route before a
      later prompt is armed. Open each captured Timed destination in turn: a
      stale/abandoned token consumes nothing, the newer matching token receives
      only its own prompt once, and neither route can steal or replace the
      other's visible launch intent.

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

- [x] 2026-07-20 — exact-source local candidate `cdce32af9` passes the
      complete serialized unit target (4,549/4,549) and complete serialized UI
      target (79/79), with zero failures or skips. Result bundles:
      `/private/tmp/noum-vision-full-unit-final-pass2.xcresult` and
      `/private/tmp/noum-vision-full-ui-final-pass2.xcresult`. The UI target
      includes all long screenshot tours, nine coaching-journey accessibility
      states, both in-chat goal-confirmation variants, active-week Phrase Bank
      execution, and the full Ask Noum terminal-state class.
- [x] 2026-07-20 — the exact-source Release simulator app at `cdce32af9`
      builds with one Xcode job; the app and embedded extensions pass strict,
      deep signature verification. The product is 1.1 build 2 with an expected
      simulator ad-hoc signature. This is not an Apple Distribution archive or
      TestFlight upload.
- [x] 2026-07-19 — current-source Release simulator build at `6712ee74d`:
      `BUILD SUCCEEDED` on iPhone 17 with serialized compilation and isolated
      DerivedData. The three selected journey UI regressions pass: locked free
      rewrite preview, Summary prescription return, and transcript-ladder
      one-step practice handoff. Ten product-journey contract tests also pass.
      This is simulator evidence only and does not satisfy signing/device QA.
- [x] 2026-07-20 — fresh serialized broad unit run at behavior source
      `5f25e6a24` is fully green: 4,546 passed / 0 failed / 0 skipped. The run
      used one iPhone 17 Pro simulator, serialized execution, isolated
      DerivedData, and the source-bound package cache. Result bundle:
      `/private/tmp/noum-vision-closure-all-units-final.xcresult`. This supersedes the
      2026-07-19 4,502/33 failure row; it remains simulator evidence only.
- [x] 2026-07-20 — the complete Ask Noum rendered reliability class passes
      10/10 in `/private/tmp/noum-vision-closure-chat-flow-final.xcresult`.
      The new lifecycle case accepts a delayed turn, backgrounds/foregrounds
      the app, then proves one stable terminal row, one matching user row, and
      no lingering thinking state. This does not replace live-provider or
      physical-device lifecycle QA.
- [x] 2026-07-20 — the exact-source Release simulator app at `5f25e6a24`
      builds successfully and the app, Messages extension, and Widget
      extension all pass strict signature verification. This is not an Apple
      Distribution archive or TestFlight upload.
- [x] 2026-07-20 — light screenshot sweep produced five seeded tab-root
      captures plus an expanded redacted Debug trace/support-export state, all
      nonblank at 1206×2622, in
      `.screenshots/2026-07-20_trace-support-bundle/`. All six were visually
      inspected. The trace UI test independently opened Settings, expanded
      Developer, exported the bundle, and observed the confirmation toast in
      `/private/tmp/noum-trace-support-focus.xcresult`.
- [x] 2026-07-19 — light screenshot sweep produced five seeded tab-root and
      five cold-profile recovery captures, all nonblank at 1206×2622, in
      `.screenshots/2026-07-19_product-journey/`. The tab roots confirm the
      dominant next step and current navigation hierarchy; the recovery set
      confirms an unavailable profile is surfaced as retryable instead of
      fabricating coaching. Debug-detail, memory editing, transcript-ladder
      accessibility extremes, and real-speech retry still require focused QA.

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
