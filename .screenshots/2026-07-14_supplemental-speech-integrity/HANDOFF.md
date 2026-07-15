# Run: 2026-07-14 · branch:ux-overhaul · HEAD c44bd91c · gate supplemental speech progress on terminal capture

## Mode

light

## Changes shipped (this run)

- `Noum/MiniDrillView.swift:284` — waits for provider/microphone readiness before starting the drill clock; terminal failure returns to a retryable state before `onComplete`.
- `Noum/LessonView.swift:665` — Lesson Apply now uses the same awaited readiness/finalization gates and no longer evaluates after an arbitrary 0.6-second delay.
- `NoumTests/SpeechSessionIntegrityTests.swift:187` — pins both supplemental surfaces to awaited lifecycle calls, shared gates, route notices, and removal of fire-and-forget recording calls.

## Screenshots

- `01_home_top.png` — Home tab, seeded top view.
- `01_train_top.png` — Train tab, seeded practice picker.
- `01_review_top.png` — Review tab, seeded recent-movement view.
- `01_profile_top.png` — Profile tab, seeded coaching profile.
- `01_settings_top.png` — Settings tab, top of Practice settings.

The first unseeded launch correctly rendered the onboarding/account recovery state rather than the requested tabs. The sweep was rerun with the existing `UI_TESTING_SEED_FORCE` fixture and every final image was visually inspected. The light sweep does not enter microphone-dependent Mini-drill or Lesson Apply states.

## VISION gap

The touched flows now protect believable progress: no capture means no apparent success, XP, history, or lesson advancement. That matches the trusted-coach and fair-pressure principles. The gap is external and experiential: simulator tab tops do not prove microphone readiness timing, on-device locale availability, interruption recovery, or the calm connecting/retry presentation on a physical device.

## Next steps to reach desired state

1. Add deterministic microphone/provider fixtures for Mini-drill and Lesson Apply so connecting, startup failure, terminal failure, and successful completion can be exercised in UI tests.
2. Apply `transcriptionRouteNotice` to Pace Training, Cut the Crutch, and Roleplay, then verify all speech surfaces under one requested-cloud/resolved-local matrix.
3. Run the interruption, route-change, unsupported-locale, and cloud-startup-failure matrix on signed physical devices/TestFlight.

## Regressions checked

- Home top — `01_home_top.png` — seeded surface rendered normally.
- Train top — `01_train_top.png` — recommendation and practice library rendered normally.
- Review top — `01_review_top.png` — recent movement and history entry rendered normally.
- Profile top — `01_profile_top.png` — coaching focus/profile stack rendered normally.
- Settings top — `01_settings_top.png` — practice controls rendered normally.
- Supplemental speech lifecycle — focused 13-test integrity selection and complete 4,066-test unit target passed on iPhone 17 simulator with zero failures or skips.

## Surfaces needing visual verification (cloud → local queue)

- Mini-drill: connecting, startup failure, finalization failure, and valid result transition.
- Lesson Apply: connecting, startup failure, finalization failure, retry, and valid Apply result.
- Startup-fallback notice placement on both touched surfaces.

## For next run

- **If cloud**: add pure/fake-provider UI seams and complete the remaining route-notice coverage without claiming device behavior.
- **If local**: capture the focused states above with deterministic fixtures, then execute the physical-device transcription matrix.
