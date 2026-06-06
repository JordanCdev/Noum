# Run: 2026-05-21 · branch:Redesign · HEAD 60a9afe · detailed sweep + tour coverage expansion

## Mode
detailed — 34 captures (5 light + 29 tour)

## Changes shipped (this run)
- `NoumTests/NoumTests.swift:5802` — annotated `ProofMomentArchiveTests` with `@MainActor` so the Swift-6 isolation checker stops blocking the test bundle build (the new proof-moments tests in 60a9afe call `@MainActor` `ProofMomentStore` methods).
- `NoumUITests/ScreenshotTour.swift:140-152` — added Speech Project detail capture (taps first `speechProjects.row.*` after landing on the projects screen).
- `NoumUITests/ScreenshotTour.swift:165-181` — added Ask Noum and Friend Leaderboard captures. Ask Noum lands via `noum://ask`. Friend Leaderboard taps the `profile.friendLeaderboard` NavigationLink in Profile.

## Screenshots

### Light sweep (5)
- `01_home_top.png`, `01_train_top.png`, `01_review_top.png`, `01_profile_top.png`, `01_settings_top.png`

### Tour (29)
**Tab roots + scroll states (12):**
- `tour_01-home-top.png`, `tour_02-home-mid.png`, `tour_03-home-bottom.png`
- `tour_04-profile-top.png`, `tour_05-profile-mid.png`, `tour_06-profile-bottom.png`
- `tour_07-review-top.png`, `tour_08-review-bottom.png`, `tour_09-session-detail.png`
- `tour_10-settings-top.png`, `tour_11-settings-mid.png`, `tour_12-settings-bottom.png`

**Practice modes (6):**
- `tour_13-mode-picker.png`
- `tour_14-timed-setup.png`, `tour_15-sudden-death-setup.png`, `tour_16-ah-counter-setup.png`, `tour_17-im-conversation-setup.png`, `tour_18-cut-the-crutch-setup.png`

**Lessons + Speech Projects (4):**
- `tour_19-lessons-home.png`, `tour_20-lesson-detail.png`
- `tour_21-speech-projects.png`, `tour_21b-speech-project-detail.png` (Ice Breaker — new)

**Path / League / Ask (5):**
- `tour_22-league.png`, `tour_23-league-bottom.png`
- `tour_24-path-journey.png`, `tour_25-path-journey-bottom.png`
- `tour_25b-ask-noum.png` (M14 coach chat — new)

**Conditional sheets (2):**
- `tour_26-goal-refresh-sheet.png`, `tour_27-notification-pre-prompt.png`

## VISION gap
Tab-level redesign coverage is solid. The 29-surface tour now reaches Ask Noum (the M14 hero feature) and Speech Project detail. The major remaining gaps are bounded by what's reachable without new launch-arg infrastructure — see "Still missing" below.

## Still missing (and how to fix each)

**Reachable via Settings sheet taps — needs accessibility IDs on row buttons:**
- `tour_settings-paywall.png` (Upgrade row)
- `tour_settings-coaching-profile.png` (Coaching profile sheet)
- `tour_settings-your-data.png` (Privacy & data)
- `tour_settings-privacy-policy.png` (Privacy Policy view)
- `tour_settings-soundscape-picker.png` (`soundscape.picker` already has the ID; just needs a row ID on the Settings entry)
- `tour_settings-locale-picker.png` (Practice Locale)

  → Add `.accessibilityIdentifier("settings.row.paywall")` etc. on each `Button` in `SettingsView` (lines 261, 752, 864, 926, 935, 1120, 1470). Tour can then tap them in sequence.

**Needs a new force-flag launch arg in `NoumApp.init`:**
- `tour_friend-leaderboard.png` — NavLink hidden when `friends.friends.isEmpty` (the seed has no friends). Add `FORCE_FRIEND_LEADERBOARD` that seeds a couple of stub friends OR adds a deep-link case `noum://leaderboard` that pushes `AppDestination.friendLeaderboard`.
- `tour_paywall.png` — add `FORCE_PAYWALL` that flips a paywall-presented flag.
- `tour_login.png` — add `FORCE_LOGOUT` that signs out before launch so `LoginView` is the root.
- `tour_onboarding-hero.png` — add `FORCE_ONBOARDING_HERO` that resets `OnboardingHeroManager.hasSeen` before launch.
- `tour_coaching-onboarding.png` — add `FORCE_COACHING_PROFILE_RESET` that clears the coaching profile so `CoachingOnboardingView` presents.

**Needs audio-level mocking (deferred — not a quick win):**
- In-rep states for each mode: Thinking / Speaking / Summary screens.
- `LiveEloquenceHUD` overlay (only fires mid-utterance).
- `FillerAlertGate` warning toast (audio-driven).
- `FirstRepCelebration` post-rep overlay.
- `TierPromotionOverlay` (rating-change driven).
- `PathNodeCelebration` (path-progress driven).

**Needs friend-state seed:**
- `tour_social-friends-list.png` — Social profile with friends rendered.
- `tour_friend-detail.png` — Tap a friend row.
- `tour_friend-invite-qr.png` — Show friend invite QR sheet.

## Regressions checked
- All 29 tour frames rendered cleanly. Ask Noum opener line + follow-up chips visible (`tour_25b`). Speech Project detail card body, objectives, and Start CTA render correctly (`tour_21b`). No layout breakage post-M14.

## Surfaces needing visual verification (cloud → local queue)
Cloud should not attempt the tour additions above — all require local simulator + the new launch args. Cloud's contribution is purely the launch-arg wiring in `NoumApp.swift` + accessibility IDs in `SettingsView.swift`.

## For next run
- **If cloud**: wire the 5 new `FORCE_*` launch args in `NoumApp.init` and add `.accessibilityIdentifier("settings.row.<name>")` to the 6 Settings row buttons listed above. No simulator needed — `xcodebuild build` validates.
- **If local**: after the launch args land, extend `ScreenshotTour.swift` with the Settings sub-sheet tour + the 5 force-flag captures. Target 44-ish total surfaces. The in-rep / audio-driven surfaces remain blocked until a transcription mock lands.
