# Noum — Current state

_Last updated: 2026-05-06 (M5 Coach memory v1 + M6 Peak rating wall shipped)_

## Architecture overview

- **Framework:** SwiftUI, iOS 17 minimum.
- **App targets:** Main iOS app (`Noum`), home-screen + lock-screen widgets
  (`NoumWidget`, also hosts the Live Activity), iMessage extension
  (`NoumMessages`), and a watchOS glance (`NoumWatch`, currently detached
  from the iOS scheme until the watchOS 26.2 simulator runtime is installed
  locally).
- **State management:** `ObservableObject` singletons (`*.shared`) injected into
  views via `@StateObject` — `AuthManager`, `ProfileManager`,
  `PracticeSettingsManager`, `HapticsSettings`, `NotificationManager`,
  `NotificationPrePromptManager`, `PremiumManager`, `CoachingProfileStore`,
  `PracticeSessionStore`, `IMVoicePlaybackSettingsManager`,
  `RecommendationLearningStore`, `RatingStore`, `BaselineStore`,
  `ChallengesManager`, `FriendsManager`, `ClubsManager`, `AchievementStore`,
  `ClutchWordStore`, `LessonStore`, `PathProgressManager`,
  `OnboardingHeroManager`, `StreakFreezeManager`,
  `FirstRepCelebrationManager`, `DeepLinkRouter`. No Observation-framework
  migration yet.
- **Persistence:** `UserDefaults` keyed per-account
  (`<key>.<accountID>`), Keychain for the account ID + provider, and
  `BackendSyncManager` for optional Firebase sync of XP, sessions,
  coaching profile, and recommendation outcomes.
- **Cross-process state:** `SharedNoumState` writes a JSON snapshot
  (streak, freezes, reps-today, next-node) into the
  `group.com.jordancoaten.noum` App Group. `SharedNoumStateMirror` keeps
  it fresh after every session finalize and on every scenePhase active.
  Widget extension + Live Activity read this snapshot — never the main
  app's UserDefaults.
- **Audio / speech:** `AVAudioEngine` capture →
  pluggable `TranscriptionProvider` (AWS Transcribe streaming, Deepgram
  WebSocket, Google Speech-to-Text V2). Provider chosen via the
  `transcriptionProvider` AppStorage key. On-device `SFSpeechRecognizer`
  is **not** used.
- **Backend:** Firebase Auth (Apple, Google, anonymous), Firestore
  via `BackendSyncManager`, optional REST backend for vended AWS
  credentials. Privacy posture documented in `Noum/Noum/PRIVACY_*.md`.
- **AI providers:** Google Gemini, OpenAI, and DeepSeek for coaching
  analysis (`AINPCChatService`, `AIInsightsService`, `GoalParaphraseService`),
  configured in `AIConfig.plist`. Google Cloud TTS for IM voice playback
  with OpenAI fallback.
- **URL scheme:** `noum://` registered in `Info.plist`. `DeepLinkRouter`
  buffers incoming URLs until `ContentView` owns the navigation stack.
  Routes: `noum://lesson/<id>`, `noum://practice`, `noum://friend/<id>`.
- **Design tokens location:** `Noum/DesignSystem.swift` — single source
  of truth for `Spacing`, `CornerRadius`, `AppColor`, springs, shared
  components (`CardView`, `StatCard`, `PrimaryCTA`, `PressableButtonStyle`,
  `LightGradientBackground`, `SectionHeader`, `ErrorCard`,
  `MilestoneCelebrationOverlay`, `EmptyStateView`). **Typography lives in
  `Noum/Typography.swift`** — Figtree (display/rounded) + Manrope
  (text/UI), bundled as variable TTF in `Noum/Resources/Fonts/`,
  registered via `Info.plist` `UIAppFonts`. The default body font is
  set globally on the app root with `.environment(\.font, Typography.body)`.
- **Design spec:** `.claude/skills/noum-design/` — voice rules, color
  palette, type scale, motion, iconography. `DesignSystem.swift` +
  `Typography.swift` win on conflict.

## Key files / modules

### Core practice loop
- `Noum/Noum/PracticeModeSelectionView.swift` — mode picker, drives
  `RecommendationBiasEngine` for the recommended row.
- `Noum/Noum/TimedPracticeView.swift` — Timed mode (3 difficulties,
  optional Pressure Mode, optional thinking time).
- `Noum/Noum/SuddenDeathPracticeView.swift` — pressure mode where one
  filler ends the round. Now exposes a per-mode difficulty
  (Easy/Medium/Hard) that scales filler tolerance and start-window.
- `Noum/Noum/AhCounterView.swift` — free-form speak with live filler
  and pacing tracking.
- `Noum/Noum/IMPracticeView.swift` — live AI conversation reps with
  tone/scenario control.
- `Noum/BeatTheBrakeView.swift`, `LandThePauseView.swift`,
  `PREPStackView.swift` — focused mini-drills layered on top of the
  main modes.
- `Noum/Noum/PressureTimerEngine.swift` — auto-ramping round configs:
  start window 12s→3s, filler tolerance 3→0, follow-ups in R2/3/5,
  fresh prompt in R4.
- `Noum/Noum/LiveEloquenceHUD.swift` — in-session detection chip; pops
  briefly when `EloquenceEngine` recognises a rhetorical device mid-rep.
- `Noum/Noum/PressureLiveActivityCoordinator.swift` — Live Activity
  that mirrors a Sudden Death session to the Dynamic Island + lock
  screen. Shipped end-to-end; needs real-device QA (Live Activity is
  not testable on simulator).

### Lessons (Duolingo-style teaching layer)
- `Noum/Noum/Lesson.swift` + `LessonsCatalog.swift` — five lessons
  across rhetoric, structure, presence, and recovery, each with three
  steps (concept → spot it → say it).
- `Noum/Noum/LessonStore.swift` — 0–5 crown progression per lesson,
  per-account; emits a `LessonCelebration` (unlocked / levelUp /
  mastered) on each pass that the home screen consumes.
- `Noum/Noum/LessonView.swift` + `LessonsHomeView.swift` — catalog
  browser with crown rows, summary strip, first-time empty state, and
  the `LessonCelebrationOverlay` that fires on every crown gain.
- Lessons feed back into the path: `PathProgressInput.totalLessonCrowns`
  and `maxLessonCrown` are read by criteria like
  `totalLessonCrowns(N)` / `lessonMastered`.

### Speech & feedback
- `Noum/Noum/SpeechRecognizerViewModel.swift` — provider-agnostic
  capture + filler highlight + recording.
- `Noum/Noum/FillerWordDetector.swift` — semantic vs disfluency
  classification, prompt-echo exclusion, confidence scoring 0.15–0.95.
- `Noum/Noum/WPMEvaluator.swift` — mode + tone + scenario aware WPM
  bands (Timed 130–160, Sudden Death 140–170, IM 100–135).
- `Noum/Noum/RatingEngine.swift` + `RatingStore.swift` — ELO-inspired
  100–1000 rating, only Pressure Mode sessions move it, K-factor decays.
- `Noum/Noum/BaselineEngine.swift` + `BaselineStore.swift` — 0–10
  session score, strengths, persistent blockers, pressure profile.
- `Noum/Noum/TrendAnalyzer.swift` — improvement/stable/declining/
  newIssue/resolved classification per skill snapshot.
- `Noum/Noum/EloquenceEngine.swift` — eleven rhetorical-device
  detectors (tricolon, anaphora, epistrophe, alliteration, isocolon,
  antithesis, polysyndeton, asyndeton, diacope, epizeuxis, rhetorical
  question). Conservative thresholds; covered by 9 unit tests.
- `Noum/Noum/EloquenceXP.swift` — 5–25 XP per detected device,
  60-cap per session, diminishing returns inside a single rep.
- `Noum/Noum/AIInsightsService.swift` — narrative insight generator
  (weeklyNarrative / sessionDebrief / patternBreak). Reuses the
  Gemini/OpenAI/DeepSeek provider plumbing; falls back to a template
  when no AI provider is configured. Cached per week-bucket so quota
  isn't re-spent on the same input.

### Progression & retention
- `Noum/Noum/ProfileManager.swift` — XP store (per-account), level
  ladder (`Beginner/Novice/Average/Professional/World Class` × I/II/III),
  rank symbol/tint/title.
- `Noum/Noum/ModeMastery.swift` (in `PracticeSupport.swift`) — per-mode
  mastery (Bronze/Silver/Gold/Platinum) computed from session count +
  baseline score within that mode. Surfaced on the profile and read by
  path criteria (`modeMasteryLevel`, `modeMasteryAnyLevel`).
- `Noum/Noum/AchievementStore.swift` + `Noum/Noum/AchievementsTreeView.swift`
  — 7 tracks (Volume, Consistency, Clarity, Scores, Endurance, Modes,
  Mastery) plus a hierarchical tree view that visualises locked /
  unlocked branches.
- `Noum/Noum/ChallengesManager.swift` — daily/weekly/streak/social
  challenge models; `RetentionLoopEngine` produces an "active challenge"
  snapshot for the home screen.
- `Noum/Noum/PathNode.swift` + `PathNodeCelebration.swift` +
  `PathProgressManager.swift` — node-by-node path with concrete entry
  conditions evaluated against `PathProgressInput` (sessions, baseline,
  rating, streak, mode-mastery, lesson crowns). The home screen surfaces
  the next node with a one-tap CTA. Past + current + next-3 visible on
  the path map; further-out nodes stay masked. **M3 milestone shipped.**
- `Noum/Noum/PathJourneyView.swift` — map surface that combines the new
  node grid with retained decorative artwork.
- `Noum/Noum/StreakFreezeManager.swift` — weekly-replenishing streak
  freeze; protects the streak across one missed day per ISO week.
  Wires the app icon badge through `UNUserNotificationCenter.setBadgeCount`
  (passively gated on authorization, never triggers a prompt).
- `Noum/Noum/NoumCharacter.swift` — abstract speaker-character composed
  from SF Symbols (waveform variants + halos + glow), four moods (calm /
  listening / excited / coaching), state-specific accents (sparkle ribbon
  on excited, symmetric arc-pulses on listening, slight tilt on coaching).
  Used on the home hero, FirstRepCelebration, ProfileView header, and
  AchievementsTreeView hero strip. Brand-rule compliant: motion + color
  + shape, no illustration.
- `Noum/Noum/PauseMetrics.swift` + `Noum/Noum/PauseSummaryCard.swift` —
  M4 v1: pause statistics (count, mean, longest, filled-vs-unfilled
  ratio) computed from word timings during finalize. Card hides when
  no metrics; integrates into BaselineEngine + ProgressionCharts +
  TrendAnalyzer + path-node criteria (`heldSilentPause`,
  `cleanPauseSession`).
- `Noum/Noum/WordChoiceMetrics.swift` + `Noum/Noum/WordChoiceCard.swift`
  — M4 v1: unique-content-word ratio + top 3 repeated content words
  after stop-word + filler filtering. Card hides for sessions under
  20 content words.
- `Noum/Noum/PrivacyInfo.xcprivacy` — App Store privacy manifest
  declaring data collection categories (audio, name, user ID,
  product interaction, crash + performance), API usage reasons
  (UserDefaults `CA92.1`, system boot time `35F9.1`, file timestamp
  `C617.1`), and `NSPrivacyTracking=false`. Required for App Store
  submission since May 2024.
- `Noum/Noum/SoundscapeEngine.swift` + `Noum/Noum/SoundscapePickerView.swift`
  — pre-rep ambience generator (`AVAudioSourceNode`-based pink/brown
  noise + sine drones), 4 modes (Off/Focus/Calm/Steady), Pro-gated for
  non-Off modes. Wired into Timed thinking-window, AhCounter launch
  countdown, and SuddenDeath countdown phase. Cuts the moment recording
  starts so it never bleeds onto the rep.
- `Noum/Noum/TierPromotionOverlay.swift` — full-screen tier-up
  celebration (Bronze→Silver, etc.). Detected by `LeagueManager` via
  `lastSeenTier` persistence; fires through `fullScreenCover(item:)` so
  promotions earned mid-session show on next home open. First-launch
  guard prevents false promotion celebrations on brand-new installs.
- `Noum/Noum/FirstRepCelebration.swift` + `Noum/Noum/ConfettiLayer.swift`
  — first-rep moment: full-screen overlay + share sheet rendered via
  `ImageRenderer`. Fires once, persists per-account.
- `Noum/Noum/OnboardingHeroView.swift` + `OnboardingHeroManager.swift`
  — three-screen value-prop intro presented on first launch via
  `fullScreenCover`. Skipped under `UI_TESTING` and
  `UI_TESTING_SEED` arguments.
- `Noum/Noum/ProgressionCharts.swift` — animated `SwiftUI Chart` views
  (LineMark + AreaMark) for filler trend, score trend, and pace
  trend on the profile. Replaces the older "trend pill only" surface.
- `Noum/Noum/WeakAreasCard.swift` + `Noum/Noum/MistakeReplayCard.swift`
  — Review-tab surfaces that summarise the patterns the user is
  repeating and let them tap into a re-prompted rep.
- `Noum/RewardEngine.swift` (`Noum/`) — emits XP, streak, and
  milestone events.

### Notifications (4 surfaces, soft-sell pre-prompt)
- `Noum/Noum/NotificationManager.swift` — three daily-rhythm surfaces
  (`scheduleDailyReminder`, `scheduleStreakWarning`, `scheduleWeeklyDigest`)
  plus the legacy 18h follow-up. `refreshScheduledNotifications` is
  called on every scenePhase active, but is **passive** — it reads
  `UNUserNotificationCenter.notificationSettings()` and only re-arms
  when status is authorized/provisional/ephemeral. The hard system
  prompt is reserved for the explicit `set*Enabled(true)` toggles
  fired from the pre-prompt sheet.
- `Noum/Noum/NotificationCopy.swift` — lock-screen-safe streak-aware
  copy. Title/body adapts to streak length, freezes available, and
  reps today.
- `Noum/Noum/NotificationPrePrompt.swift` — soft-sell sheet shown
  exactly once after the first finished rep (`sessionCount == 1`).
  "Maybe later" honours a 30-day cool-down. The accept path enables
  all three daily-rhythm surfaces in sequence so iOS only prompts once.

### Social
- `Noum/Noum/FriendsManager.swift` — local friends list, names only,
  no phone numbers. Optional `accountID` per friend so peer stats can
  be fetched from `profiles_public/{accountID}` (M2).
- `Noum/Noum/ChallengesManager.swift` — async challenge model
  (two participants, prompt, results). Backend round-trip via
  `BackendSyncManager.syncAsyncChallenge` / `fetchAsyncChallenges`.
- `Noum/Noum/ClubsManager.swift` — clubs scaffolding.
- `Noum/Noum/SocialProfileView.swift` — older public-facing profile
  view (not the active surface; `ProfileView.swift` at the project root
  is what the home nav routes to).
- `Noum/Noum/LeagueManager.swift` + `Noum/Noum/LeagueView.swift` —
  weekly league with tier-from-rating bucketing
  (`{tier}_{ISO-year}-W{week}`), reads top 20 members per bucket.
- `Noum/Noum/PublicProfileSnapshot.swift` — Codable subset written to
  `profiles_public/{accountID}` and to `leagues/{bucket}/members/{id}`.
  Read by friends + league.
- `FIRESTORE_RULES.md` (project root) — rules required to deploy the M2
  collections safely (peer-readable but owner-write only).

### Premium & infra
- `Noum/Noum/PremiumManager.swift` — StoreKit 2 (Monthly/Annual),
  feature gates, monthly video-analysis credits.
- `Noum/Noum/AuthManager.swift` — Apple, Google, anonymous, account
  delete with full per-account UserDefaults wipe.
- `Noum/Noum/BackendSyncManager.swift` — Firebase + REST sync.

### Widgets, Live Activity, iMessage, watchOS
- `NoumWidget/` — five widget sizes (small/medium/large for streak +
  lock-screen rectangular/circular). Reads `SharedNoumState` from the
  App Group. Hosts the Live Activity bundle.
- `NoumWidget/PracticeLiveActivity.swift` — Live Activity layout for
  Sudden Death rounds (Dynamic Island compact / expanded / minimal).
- `Noum/PracticeLiveActivityAttributes.swift` (also copied into the
  widget target) — shared `ActivityAttributes` definition; both targets
  must compile against the exact same struct.
- `NoumMessages/` — iMessage extension scaffolding for sharing rep
  results / async-challenge invites inline.
- `NoumWatch/` — watchOS 10+ glance. Detached from the iOS scheme
  pending local install of the watchOS 26.2 simulator runtime.

### Settings & UX primitives
- `Noum/Noum/SettingsView.swift` — production settings (refactored).
- `Noum/Noum/SettingsRow.swift` — `SettingsToggleRow`, `SettingsNavRow`,
  `SettingsStatusRow`, `SettingsSectionLabel`.
- `Noum/Noum/EmptyStateView.swift` — reusable empty-state component
  (large tinted SF Symbol → headline → body → optional capsule CTA).
  Used on Lessons, Session History, Friends, Friend Leaderboard, and
  Async Speak-offs surfaces.
- `Noum/Noum/HapticsSettings.swift` — global haptics gate, honored
  by `CoachHaptic` and every `.sensoryFeedback`.
- `Noum/Noum/CoachHaptic.swift` — every haptic pattern routes through
  `HapticsSettings.isEnabledSync`.

## Feature status

### Implemented (shipping end-to-end)

- **Onboarding hero** — `OnboardingHeroView` shows on every brand-new
  account install. Three-screen value prop ("speak with more clarity"
  → "real-time coaching" → "believable progress"). Skip + Begin both
  persist `hasSeen`. Bypassed under `UI_TESTING` so the screenshot
  tour isn't gated by it.
- **Lessons system (Duolingo-style)** — five lessons × three steps ×
  0–5 crowns, with celebration overlay on every crown gain. Surface
  reachable from the home tab; lesson progress feeds the path via
  `totalLessonCrowns` / `maxLessonCrown` so the curriculum and the
  path are one progression, not two.
- **Path nodes (M3 v1)** — node-by-node gameplay with concrete entry
  conditions (`scoreAtLeast`, `streakAtLeast`, `modeMasteryLevel`,
  `cleanRunsInWindow`, `totalLessonCrowns`, etc.). Home shows the next
  node with one-tap CTA. Path map renders past + current + next-3 with
  state indicators; further-out nodes stay masked.
- **Eloquence detection + XP** — `EloquenceEngine` runs on every
  session transcript and surfaces eleven rhetorical devices in the
  summary's `EloquenceFindingsCard` plus a brief in-session HUD.
  Detections award 5–25 XP each, capped at 60/session with diminishing
  returns. Conservative thresholds; the card hides when there's nothing
  notable. Inspired by Forsyth's *Elements of Eloquence*. Unit-tested.
- **Speech projects** — Toastmasters-inspired structured prepared
  speeches in `Noum/SpeechProject.swift` + `SpeechProjectsView`. Eight
  projects (Ice Breaker, Table Topic, Vocal Variety, Body of Evidence,
  Storytelling Arc, Persuade with Structure, Teach It in 90,
  Inspire Your Audience) with concrete objectives and curated prompts.
  Reachable from the practice picker; project context is handed off
  to `TimedPracticeView` via `SpeechProjectContext.current`.
- **Speech-to-text** — three providers (AWS Transcribe streaming,
  Deepgram WS, Google Speech V2) with quality metrics tracked per
  provider.
- **Filler word detection** — semantic ("like" as simile vs filler),
  prompt-echo aware, confidence-graded. Not a naive keyword match.
- **Pace / WPM** — computed, mode + tone + scenario aware, persisted
  on every session, surfaced in summaries.
- **Scoring** — `BaselineEngine` 0–10 score every session;
  `RatingEngine` ELO-style rating for Pressure Mode sessions only.
- **Recording** — audio is implicit via transcription. Video via
  `VideoRecordingManager` saved to the app sandbox; gated to Pro.
- **Auth & accounts** — Apple, Google, anonymous "Guest" via Firebase.
  Account deletion wipes per-account UserDefaults, Firebase Auth user,
  and backend records.
- **Premium tier** — StoreKit 2 with Monthly ($4.99) and Annual ($29.99),
  feature gates for Coach Mode, Live Transcript, Filler Tracking,
  Trends, Video, Saved Transcripts, Unlimited Async Challenges, AI
  Video Analysis (5/mo), 100 AI coaching reads.
- **Streaks + freeze** — calculated from session dates; one weekly-
  replenishing freeze auto-protects the streak across a missed day.
  Surfaced in home, profile, reminder copy, widget, and the soft-sell
  pre-prompt's value-prop bullets. App icon badge mirrors the current
  streak via `setBadgeCount`.
- **First-rep celebration** — full-screen overlay + share sheet on
  the user's first finished rep. Persists per-account.
- **XP / levels / ranks** — XP persistent per-account, levels derived
  (`xp / 1000` with sub-level Roman numerals), rank surface on home,
  profile, and Settings hero.
- **Per-mode mastery** — Bronze/Silver/Gold/Platinum per
  PracticeMode, derived from session count + baseline score within
  the mode. Surfaced on the profile and read by path criteria.
- **Achievements + tree view** — 7 tracks, real unlock paths, unlock
  dates stored, badge animations, plus a hierarchical
  `AchievementsTreeView` that visualises locked/unlocked branches.
- **Difficulty levels — Timed and Sudden Death** — Easy / Medium /
  Hard for both. Sudden Death difficulty scales filler tolerance and
  start-window.
- **Topic / prompt generation** — 200+ curated prompts in
  `PracticeTopics.swift` across 8 themes. **No AI generation.**
- **AI coaching reads** — Coach Mode + Coach Read via
  `AINPCChatService` (Gemini / OpenAI / DeepSeek), gated to Pro,
  100/mo limit.
- **AI narrative insights** — `AIInsightsService` produces weekly
  narrative + post-session debrief + pattern-break insights. Cached
  per week-bucket. Falls back to a rich template insight when no
  provider is configured so the card stays useful offline.
- **Pressure Mode** — auto-ramping round configs across Timed and
  Sudden Death; baseline-aware pressure classification.
- **Pressure Live Activity** — Sudden Death rounds mirror to the
  Dynamic Island + lock screen via `PressureLiveActivityCoordinator`.
  Shipped end-to-end; needs real-device QA.
- **Define goal & why (M5 Coach memory v1)** — captured during
  `CoachingOnboardingView`, surfaced in reminder bodies and recommendation
  context. After capture, `GoalParaphraseService` runs a single best-effort
  AI pass and stores the result as `CoachingProfile.paraphrasedGoal`. UI
  surfaces use the paraphrase via `displayableGoal`. **M5 additions:**
  `GoalRefreshManager` fires a lightweight "still your goal?" sheet every
  14 days (after session 20+); `CommunicationBaseline.distanceFromGoal(_:)`
  returns a normalized 0–1 proximity metric per `CoachingPriority`;
  `AIInsightInput.goalDistance` is passed to AI prompts so the session
  debrief opens with a goal-grounding sentence; `RecommendationBiasBlueprint`
  gains `suggestedTimedDifficulty` and `suggestedTheme` (goal-mapped),
  seeded into the practice session on quick-start tap.
- **Trend charts** — `ProgressionCharts` renders animated SwiftUI
  `Chart` line + area marks for filler / score / pace on the profile.
  `TrendAnalyzer` data also surfaces as the existing trend pill.
- **Peak rating wall (M6)** — `SpeakingRating.weekPeakRating` tracks
  the highest rating reached within the current ISO week. Resets at
  every week boundary (legacy data decodes cleanly with current overall
  as the default week peak). `PeakRatingWallCard` on `ProfileView`
  shows three rows — Best ever (`peakRating`), Best this week
  (`weekPeakRating` if `isWeekPeakCurrent`, else "—"), Best in friends
  (max `lastKnownPeakRating` across linked-account friends). Honest
  empty states: "Awaiting sync" when no friend has been backend-synced;
  "No linked friends" when all friends are local-only; "You lead" when
  the user's peak exceeds every friend's; "Tied with [name]" when
  matched. Friend peer reads need `FIRESTORE_RULES.md` deployed for
  real data — card handles empty `members` arrays correctly today.
- **Recommendation engine** — `RecommendationBiasEngine` +
  `CoachingPlanner` produce next-best-mode + reason, with
  `RecommendationLearningStore` tracking whether following the
  recommendation actually moved score/filler/duration deltas.
- **Notifications — four surfaces, soft-sell pre-prompt** — opt-in
  via `NotificationPrePromptSheet` after the first finished rep, then
  three daily-rhythm surfaces (daily reminder, streak warning, weekly
  digest) plus the legacy 18h follow-up. Lock-screen-safe copy that
  never quotes the user's typed goal. Passive scenePhase refresh —
  no surprise prompts.
- **Widget extension** — five sizes (small/medium/large + lock-screen
  rectangular/circular) reading the App Group `SharedNoumState`
  snapshot. Updates after every session finalize and on scenePhase
  active.
- **Deep linking** — `noum://` URL scheme registered. `DeepLinkRouter`
  buffers the URL; `ContentView` consumes it once it owns the nav
  stack. Routes: `/lesson/<id>`, `/practice`, `/friend/<id>`.
- **Friends / async challenges (M2 v1)** — round-trip via Firestore
  shared docs at `challenges/{id}` is shipped. Each participant writes
  their own slice and reads the doc. Friend invitation by QR code
  carries the inviter's `accountID` so peer stats can be fetched.
- **Weekly league (M2 v1)** — `LeagueManager` writes the user's
  snapshot to `leagues/{tier}_{ISO-year}-W{week}/members/{accountID}`
  after every session. `LeagueView` reads top 20 of the current bucket.
  Tier is derived from rating (Bronze < 300, Silver < 500, Gold < 700,
  Platinum < 850, Diamond ≥ 850).
- **Settings** — production-quality refactor with hero profile, Pro/
  Free state, manage-subscription deep link, typed deletion confirm,
  haptics master gate, mic permission status, "Your data" sheet,
  diagnostic copy.
- **Empty-state primitive** — `EmptyStateView` shipped across Lessons,
  Session History, Friends, Friend Leaderboard, and Async Speak-offs.
  Voice-controlled (no "Let's", no exclamations, no emoji).
- **iMessage extension target (`NoumMessages`)** — scaffolded; share
  rep results / async-challenge invites inline. Not yet promoted to
  prime tab nav.
- **watchOS glance target (`NoumWatch`)** — built; detached from iOS
  scheme until local watchOS 26.2 simulator runtime install. Surfaces
  streak + reps-today + a one-tap "start a quick rep" CTA.

### Partially implemented

- **Pause analysis** — **M4 v1 shipped**. `PauseMetrics` (count, mean,
  longest, filledRatio) computed at finalize for every Timed / Sudden
  Death / Ah-Counter / IM session. Renders in the summary's
  `PauseSummaryCard`, integrated into `BaselineEngine` (`pauseRate` +
  `pauseFilledRatio` dimensions), surfaces as a 4th series in
  `ProgressionCharts`, drives 2 path-node criteria (`heldSilentPause`,
  `cleanPauseSession`) + 2 path nodes ("Hold a silent beat",
  "Composed pauses"), and drives `TrendAnalyzer.analyzePause` so the
  pause direction (improving/stable/declining) folds into the existing
  primary-focus pick. Land the Pause mini-drill remains as a focused
  in-session lock-in mechanic.
- **Word choice** — **M4 v1 shipped**. `WordChoiceMetrics` (unique
  ratio + top 3 repeated content words after stop-word + filler
  filtering, 20-content-word minimum) renders in the summary's
  `WordChoiceCard`. `ClutchWordStore` continues to track user-defined
  "clutch words" alongside. Vocabulary range was already in
  `BaselineEngine` via unique-ratio; no new dimension added (the
  existing vocab signal covers the baseline; the card surfaces the
  detail per-rep).
- **Daily / weekly challenges** — model + UI scaffold real, used by
  `RetentionLoopEngine` to produce one "active challenge" tile.
  **Auto-rotation / weekly reset / leaderboard not wired.** It's a
  single rolling status, not a true daily challenge surface.
- **Clubs** — `ClubsManager.swift` is scaffolding only; no real club
  membership / club challenges / club leaderboard ship.
- **Topic generation — AI** — pool is static. The AI infrastructure
  exists (`AINPCChatService`) but isn't wired to generate fresh
  prompts.
- **iMessage / watchOS surfaces** — both targets compile and ship;
  neither has had a real-device QA pass yet.

### Stubbed / placeholder

- **Goal-driven coaching feedback in mid-session UI** — the goal is
  captured but only used in reminder copy and recommendation rationale.
  It does not influence drill prompt selection, evaluation weighting,
  or session debrief framing.
- **AI-generated recommendation reasons** — `RecommendationBiasEngine`
  now feeds dynamic per-user `whyNow` / `whyMode` text into the
  practice mode picker's recommended row. Falls back to the pre-baked
  per-mode line when no profile / no session history exists. The
  blueprint's `focus`, `target`, and `modeBenefit` fields are still
  unused at the call site — those could feed a richer "Recommended
  for you" expanded card if we want to surface more.
- **Hosted privacy policy URL** — the bundled `PrivacyPolicy.md` is
  now rendered in-app via `PrivacyPolicyView`, reachable from
  Settings → Privacy & Data → Privacy policy. App Store submission
  also requires a hosted public URL — that side is still open
  (see `PRIVACY_REMEDIATION.md` §1.2).

### Not started

- **Pitch / intonation analysis** — zero pitch tracking. The audio
  pipeline drops the signal at transcription time.
- **Grammar / English-usage evaluation** — no parser, no AST, no
  grammar feedback.
- **Word of the day** — not present.
- **Multilingual support** — every transcription provider is hardcoded
  to `en-US`; all copy and prompts are English.
- **Sponsor / advertisement surfaces** — none, and they conflict with
  the paid model. Mentioned on the original Trello but flagged here
  as "do not build".
- **Lives / hearts gating** — not present (and probably not the right
  loss-aversion mechanic for a speaking app — flagged for VISION).

## Known issues / debt

- **Pressure Live Activity needs real-device QA** — Live Activity is
  not testable on simulator; lock-screen rendering and Dynamic Island
  presentation must be verified on hardware before launch.
- **NoumWatch detached from iOS scheme** — watchOS 26.2 simulator
  runtime not installed locally. Either install the runtime and
  re-attach, or keep detached until watch stack is ready for QA.
- **Onboarding goal text quality is variable** — users type free-form
  prose. The picker no longer renders this verbatim, but the underlying
  input quality means goal text shouldn't be embedded into UI without
  a paraphrase pass.
- **Daily challenge surface is a single tile** — no proper daily reset
  rhythm, no expiry warning before a streak breaks.
- **`AISettingsManager` is referenced but lives inside
  `PracticeSupport.swift`** — that file is 7,800+ lines and a
  long-term refactor target.
- **UI tests are flaky** — four UI tests
  (`testHomeScreenAndPrimaryNavigation`,
  `testPracticeModesOpenAvailableScreens`, `testOnboardingFlowSmoke`,
  `ScreenshotTour.testCaptureAdvancementSurfaces`) fail intermittently.
  Unit tests are stable (111+ tests passing including all M4 work).
  Root cause partially identified: the home tests query elements as
  `app.otherElements[...]` but recent UX work promoted those tiles to
  buttons. The journey card was refactored to use sibling buttons
  instead of nested ones (cleaner hit-testing) and the launch args
  needs `UI_TESTING_SEED` for populated state — but the seed isn't
  reliably injecting in the test environment. Needs a dedicated pass.
- **Dynamic Type partial coverage** — ~90 `.system(size:)` call sites
  don't use `.relativeTo` text styles, so they don't scale with the
  user's preferred text size. Low-impact for most users (the system
  text styles still render fine), but a thoroughness gap. Migrate at
  some point.
- **Hosted privacy policy URL** — bundled `PrivacyPolicy.md` renders
  in-app via `PrivacyPolicyView`. App Store submission also requires
  a hosted public URL (Firebase Hosting or similar). Open.

## Conventions to preserve

- **State pattern:** new managers follow `final class X: ObservableObject`
  + `static let shared = X()` + `@Published` + UserDefaults persistence.
  Injected into views via `@StateObject private var x = X.shared`.
  **Do not** introduce `@Observable` until the codebase migrates as a
  whole.
- **Per-account scoping:** every persisted user value is keyed
  `<feature>.<accountID>`. Account deletion must clear every key —
  see `AuthManager.clearAllUserData(for:)` for the canonical list.
- **Cross-process state:** widgets, Live Activity, and watch glances
  read `SharedNoumState` from the App Group. Never read main-app
  UserDefaults from an extension.
- **Notification authorization:** never trigger the iOS hard prompt
  except from an explicit user action (the `set*Enabled(true)`
  toggles wired off the pre-prompt sheet). Passive surfaces
  (`refreshScheduledNotifications`, `applyAppIconBadge`) read
  `notificationSettings()` and silently no-op when not authorized.
- **Design tokens:** all spacing, radii, and color come from
  `DesignSystem.swift` (`Spacing.*`, `CornerRadius.*`, `AppColor.*`).
  No literal hex, no magic spacing numbers.
- **Voice:** trusted speaking-coach tone. No "Let's", no chirpy
  copy, no emoji in user-facing strings, no exclamation marks
  except on celebration overlays. Sentence case for body, Title
  Case + uppercase + 0.8 tracking for micro-labels.
- **Haptics:** every haptic pattern routes through `CoachHaptic.*`,
  which honors `HapticsSettings.isEnabledSync`. SwiftUI rows with
  `.sensoryFeedback` gate on `HapticsSettings.shared.isEnabled` in
  the trigger condition. Never call `UIImpactFeedbackGenerator`
  directly.
- **Press feedback:** every interactive element uses
  `.buttonStyle(.pressable)`. No bespoke press animations.
- **Lock-screen safety:** notification copy never quotes user-authored
  goal text directly — see `NotificationManager.reminderTitle` /
  `reminderBody`, and `NotificationCopy.swift` for daily-rhythm copy.
- **AVAudioApplication.recordPermission** is the iOS 17 API. Don't
  reach for the deprecated `AVAudioSession.requestRecordPermission`.
- **Preview safety:** preview blocks must not mutate real `.shared`
  managers in ways that survive the preview tear-down. Mutations like
  `revokePremium()` / `upgradeToPremium()` are tolerated because they
  reset on relaunch, but new previews should prefer constructor
  injection where the manager surface allows it.
- **Singleton init reentry:** when a singleton's `init` calls
  `recompute()` or any mirror-write, defer the cross-singleton write
  with `DispatchQueue.main.async`. Direct calls during init can
  re-enter `.shared` and deadlock the dispatch_once.
