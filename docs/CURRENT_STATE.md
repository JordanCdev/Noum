# Noum — Current state

_Last updated: 2026-05-20 (M5–M13 shipped, M14 in flight: goal-aware coaching surfaces + LookingAheadCard + mid-session voice anchor + goal-aware live HUD + Typography Dynamic Type contract + goal-aware coach note momentum + visible goal-progress ring on the profile + home recommendation voice-alignment chip + calmer-delivery snapshot trend + Looking-Ahead voice chip closes the loop + goal-aware drill picker closes the inside of the loop + goal-aware leverage + next step + drill rationale closes the verdict copy edge + goal-aware delivery bonus closes the scoring edge — score, copy, and drill are all goal-aware end-to-end + **Home Coach Card hero redesign** + **6-surface premium hero pattern** (Profile/Review/Settings/Mode Picker/Path Journey/Bottom Nav) + **noum-screenshots skill + SessionEnd hook + 27-shot detailed tour** + **tab-level `noum://` deep links** + **UI_TESTING_SEED_FORCE + celebration suppression** + **VoiceAlignmentChip on hero** + **NoumCharacterStage 5-stage story arc** + **Path-centric Home (second hero with Chapter/Mission framing)** + **VoiceMetricsCard (Pause + Word Choice first-class)** + **PathNodeCelebration cinematic upgrade** + **Mission framing copy** + **SummaryView "Mission cleared" headline on path unlock** + **AIWeeklyInsightCard chapter eyebrow mirrors path chapter** + **HomeCoachCard now serves the empty state too — unified premium first impression** + **Ah-Counter hero parity with other modes** + **Coach voice audit — 7 user-facing exclamations dropped** + **NoumCharacterStage test coverage**)_

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
  Routes: `noum://lesson/<id>`, `noum://practice`/`train`,
  `noum://review`/`history`, `noum://profile`/`social`, `noum://settings`,
  `noum://home`, `noum://league`, `noum://path`, `noum://lessons`,
  `noum://friend/<id>`. Tab-level routes were added M14 for the
  `noum-screenshots` skill — each resets `navigationPath` and pushes
  the corresponding `AppDestination` for atomic tab jumps. Cold-start
  routing via `-DeepLink <noum://...>` launch arg lets `simctl launch
  --terminate-running-process` drive nav without iOS's "Open in Noum?"
  confirmation blocking headless capture.
- **Screenshot + handoff workflow:** `noum-screenshots` skill at
  `.claude/skills/noum-screenshots/` with three modes (off/light/
  detailed) stored in a `.mode` file. Light = 5 tab tops via
  `-DeepLink` (~30s); detailed = 27-shot tour via
  `xcodebuild test -only-testing:NoumUITests/ScreenshotTour/...` (~3min).
  `SessionEnd` hook in `.claude/settings.json` auto-runs light at
  session end. HANDOFF.md files commit to git (cross-machine
  protocol); PNGs are gitignored (local artifact).
- **Cloud routine prompts:** six markdown briefs in `.routines/`
  (vision drift audit, refactor backlog grinder, coach voice copy
  audit, localization migration, test coverage scan, M5 goal-aware
  HUD step). Each prompt is self-contained for scheduled cloud
  agents to run cold.
- **Test-mode launch args:** `UI_TESTING` (skip onboarding hero),
  `UI_TESTING_SEED` (seed if empty), `UI_TESTING_SEED_FORCE` (always
  reseed — used by the tour for deterministic state),
  `FORCE_GOAL_REFRESH` / `FORCE_NOTIFICATION_PROMPT` (force-fire
  conditional sheets for capture). Celebration suppression
  (`LeagueManager.suppressCelebrationsForTesting()` +
  `DailyGoalManager.consumeGoalCelebration()` + `PathProgressManager.
  consumeCelebration()` + `LessonStore.consumeCelebration()`) fires
  after seed inject so overlay celebrations don't block tour taps.
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

### Home (M14 redesign)
- `Noum/HomeCoachCard.swift` — unified home hero. Single composed
  card carrying `NoumCharacter` (90pt, mode-tinted) + `coachTitle`
  + `coachSubtitle` + `VoiceAlignmentChip` + "Begin · <Mode>" CTA.
  Background: Pro-purple radial wash + faint mode-tinted trailing
  accent + purple hairline border + soft purple elevation shadow.
  Two registers: purple = "your coach speaking", mode tint = "this
  is what to do." **Now serves both the empty-state (brand-new
  user) and populated-state (returning user)** — replaces the
  legacy `heroCard + firstSessionCard` pair on empty state. The
  no-signal branch reads `.listening` mood (the coach is hearing
  you for the first time, not advising you yet) + profile-aware
  subtitle (picks up `CoachingProfile.biggestChallenge` if the
  user finished onboarding) + "Begin · First rep" CTA. ~155 LOC
  of duplicated empty-state UI deleted from `ContentView`.
- `Noum/HomeUtilityStrip.swift` — slim 36pt row beneath the Coach
  Card. Streak chip on left (taps → Profile), word-of-day on
  right (taps → seeds a Timed rep). No card chrome, low-emphasis
  by design.
- `Noum/Noum/DailyChallengeTile.swift` — coach-voice rewrite
  (5 states). Row subtitles dropped (title + XP only); subtitle
  moves to accessibility label. Inline `NoumCharacter.Inline`
  glyph in the TODAY header. Copy register: "Today's mission" not
  "Today's challenge" — uniform with journey card + path nodes.
- `Noum/VoiceMetricsCard.swift` — first-class Home card surfacing
  Pause + Word Choice metrics (the underweight VISION items).
  Brand-blue ambient. Coach voice: "77% unique words. Up from
  65% last week." Collapses entirely when no qualifying data —
  no placeholder.
- `Noum/NoumCharacterStage.swift` — five-stage character story
  arc (`awakening` 0–500 XP → `voice` 500–1500 → `composure`
  1500–3500 → `command` 3500–8000 → `mastery` 8000+). Pure-
  function `current(xp:)`. Per-account ratchet (UserDefaults key
  `noumCharacter.peakStage.<accountID>`) — never visible
  regression on XP drops. Applied to NoumCharacter atop mood;
  stage = lifetime arc, mood = moment-to-moment state.

### Path / mission gameplay loop
- `Noum/Noum/PathProgressManager.swift` + `Noum/Noum/PathNode.swift`
  — node-by-node unlocks (unchanged this push; consumed widely).
- `Noum/Noum/ContentView.swift` `journeyPreviewCard` — promoted to
  slot 3 (Home position 2 after Coach Card + utility strip). Reads
  as a SECOND HERO: brand-blue ambient + "YOUR JOURNEY · Chapter ·
  <Tier>" eyebrow + "Mission X of N" + node title + gating line +
  "Open the Path" CTA.
- `Noum/HomeCoachCard.swift` — new `mission-within-reach` coach
  title variant when `PathProgressManager.currentNode` is one rep
  / score-point from unlocking. Drives users at the path naturally.
- `Noum/Noum/PathNodeCelebration.swift` — full-screen cinematic
  on path unlock: brand-blue radial backdrop, 140pt stage-aware
  NoumCharacter (`.excited`), "Mission Complete." headline,
  chapter eyebrow, specific stat line ("X reps. Y clean pauses.
  You earned this."), five-beat motion sequence (reduce-motion-
  aware).
- `Noum/Noum/SummaryView.swift` — headline variant: when
  `PathProgressManager.shared.pendingCelebrationNodeID` is set,
  the summary reads "Mission cleared" instead of the score-based
  generic ("Strong delivery" / "Building momentum" / etc.).
- `Noum/Noum/AIWeeklyInsightCard.swift` — chapter eyebrow above
  the headline tied to `PathProgressManager.currentNode.node.tier`
  (the *path-chapter the user is travelling through*), not the
  rating tier — so the eyebrow always matches what the journey
  card on the same screen reads. Falls back to LeagueTier only
  when the path is cleared. Reads "CHAPTER · BRONZE" while still
  in the Bronze section of the path, even if the user's overall
  rating has reached Gold.
- `Noum/Noum/ProgressionCharts.swift` — pillar picker (Score /
  Fillers / Pace / Pauses / Pitch) now scrolls horizontally with
  `.fixedSize` on each pill so the labels never wrap mid-word
  ("Fill / ers", "Pa / ce") when the row exceeds the rating
  card's inner width.

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
- **Pitch trend on profile + baseline integration + grammar polish (M11)** —
  M10's known gaps are closed. `CommunicationBaseline.pitchVariation` is a
  new BaseStat dimension; only sessions with `PitchMetrics.isReliable`
  contribute (older / silent / out-of-range reps don't drag the value).
  Decoded with `decodeIfPresent` for backward compat. `SkillSnapshot.pitchMonotone`
  is a new field on the trend store; `SessionFinalizer` writes it after every
  session that captured a reliable reading. `TrendAnalyzer.analyzePitch`
  produces an improving/declining/stable read mapped to `vocalEmphasis` skill
  area (closest existing match — pitch variation is one lever vocal emphasis
  pulls). `ProgressionChartsCard` gains a 5th series — Pitch — rendering
  variation (1 - monotone) so up = better, matching the score series. Series
  is auto-included since `ChartSeries` is `CaseIterable`. New strength
  ("Vocal variety", monotone ≤ 0.35) and persistent blocker ("Monotone
  delivery", ≥ 5 reliable reads at ≥ 0.75 monotone) drop into existing
  identifyStrengths / identifyBlockers paths. AI promptContext now mentions
  pitch baseline so the coach reads can ground feedback in flat-vs-varied
  delivery. **Grammar polish service** — `GrammarFeedbackService` is a Pro-
  gated actor mirroring `AIInsightsService`'s provider plumbing
  (Gemini/OpenAI/DeepSeek). Conservative skip rules: under 12s duration,
  under 25 words, transcript confidence below 0.55, or filler ratio ≥ 30%
  (throat-clearing). System prompt forbids stylistic preferences and
  filler nags (FillerWordDetector owns that surface). Excerpt validation
  drops any note whose quote isn't actually in the transcript — defensive
  against fabrication. Cached per session ID, never re-spends quota for
  the same input. **No template fallback** — without an AI provider we
  show nothing rather than invent grammar issues. `GrammarPolishCard`
  renders up to 3 notes with category chip + severity tint + verbatim
  excerpt + imperative suggestion. "Looks clean" appears when the pass
  ran and found nothing — that's the signal that grammar was reviewed,
  not that the feature is broken. Hidden for free users (belt-and-braces
  gate at both card and service). Skipped sessions render nothing rather
  than a noisy empty state. Unit-tested at the skip-rule + parser level.
- **Pitch / intonation v1 (M10)** — On-device pitch detection via
  `PitchAnalyzer` (Sendable class). The AVAudioEngine `installTap`
  callback captures samples into an `OSAllocatedUnfairLock`-protected
  buffer with zero DSP on the audio thread. At session end, `analyze()`
  walks the buffer in 2048-sample windows (50% overlap) and runs
  vDSP-based normalized autocorrelation. Peak-picking uses first-local-
  max-above-voicing-threshold (0.30) — avoids octave doubling that
  plagues naive argmax-based pitch detectors (validated against pure
  220Hz / 140Hz sines, silent windows, and seeded white noise).
  `PitchMetrics` carries meanHz, stdHz, voicedRatio, windowCount;
  `monotoneScore` (0–1) calibrated to 8–35Hz stdev. `isReliable`
  gates surfacing — needs ≥10 windows, ≥20% voiced, and a mean inside
  70–400Hz vocal range, otherwise the summary card hides itself rather
  than mislead. `PitchSummaryCard` shows a horizontal Varied↔Monotone
  meter alongside coach copy. Legacy `PracticeSession` JSON decodes
  cleanly with nil pitchMetrics.
- **Word of the day (M9)** — `WordOfTheDayCatalog` ships 30 curated
  entries (word, part-of-speech, definition, 30s prompt suggestion, and
  inflected acceptedForms list). `entry(for:)` hashes the ISO day key
  to pick deterministically — same day, same word, no backend.
  `WordOfTheDayManager` (per-account) scans today's session transcripts
  for any acceptedForm using a word-boundary safe tokenizer (matches
  app-wide `wordCount` semantics) so substrings of unrelated words don't
  trigger. "Used" stamps a per-day set in UserDefaults so a future
  vocabulary-streak surface can read from it. `WordOfTheDayTile` on
  populated home shows the word + definition + suggested prompt;
  "Try it" seeds `timedPractice.suggestedPrompt` and pushes
  `AppDestination.timedPractice`. `SessionFinalizer` triggers
  evaluation after each session. Catalog covers ~30 days; needs growth
  to ~365 to satisfy the "no repeats inside a year" target.
- **Daily challenges (M8)** — `DailyChallenge.swift` defines 8 strict
  challenge kinds keyed to real `PracticeSession` fields (held pause
  ≥ 3s unfilled, zero-filler rep ≥ 14 words, score ≥ 8/10, etc.).
  `DailyChallengeGenerator` returns a deterministic 3-of-8 trio per
  ISO date via Splitmix64 — same day produces same trio across launches.
  `DailyChallengesManager` (per-account, `@MainActor`) auto-rolls at
  midnight, re-evaluates after each session via the SessionStore
  subscription, and exposes `readyToClaim` for tile state. Claim is
  user-tap-only; XP awarded via `ProfileManager.shared.addXP`. 9pm
  local soft-expiry switches the tile to a faded treatment (no shame)
  but stays claimable until midnight. `DailyChallengeTile` is the
  third card on populated home, between `DailyGoalCard` and
  `streakCard`. `SessionFinalizer` triggers `ensureForToday()` +
  `recomputeReady()` after every finalize. Per-device claim state —
  not synced across devices yet.
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
- **Topic / prompt generation (M7)** — 200+ curated prompts in
  `PracticeTopics.swift` across 8 themes, plus a 70/30 mix with
  `AIPromptGeneratorService`. The AI generator is an actor that mirrors
  `GoalParaphraseService`'s provider plumbing (Gemini / OpenAI / DeepSeek)
  and produces one prompt biased by `CoachingPriority` + weakest baseline
  dimension. Deterministic `PromptContentFilter` rejects directives,
  missing terminal `?`, length out of bounds, PII shapes, and chained
  exclamations before any prompt reaches the user. `PromptHistoryStore`
  dedupes within a 14-day per-account window. The orchestrator runs the
  AI hop under a strict 3-second latency budget — falls back to the pool
  on any failure or timeout. Without an `AIProvider` configured, all
  sessions use the curated pool (no regression). Wired into
  `TimedPracticeView` and `SuddenDeathPracticeView`; mini-drills and
  async-challenge prompts intentionally keep deterministic seeding.
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
  captured and now reaches post-session coaching surfaces:
  `NextActionEngine.recommend` appends a goal-aligned suffix to the
  reasoning when the chosen drill targets an aligned skill area, and
  `MiniDrillResultView` shows a "Closer to your <voice> voice" capsule
  on successful drills that align with the user's
  `SpeakingStyleGoal`. Alignment map lives on
  `SpeakingStyleGoal.alignedSkillAreas` in `DrillSystem.swift` (e.g.
  `.concise` → `[conciseSpeaking, structure, fillerReduction]`).
  **Mid-session live UI now reads the goal too**: a sister mapping
  `SpeakingStyleGoal.alignedEloquenceDevices` ties each voice to the
  rhetorical moves that most directly serve it (e.g. `.warm` →
  `[anaphora, diacope, rhetoricalQuestion, alliteration]`).
  `LiveEloquenceHUD` accepts a `styleGoal:` and swaps its chip subtext
  from the neutral "noticed" to "toward your <voice> voice" the moment
  a goal-aligned rhetorical move lands during the rep, with a slightly
  brighter stroke + shadow on aligned chips so the visual rhythm
  matches the copy. `VoiceAnchorBanner` (new, restrained) pulses for
  ~4s at the top of `TimedPracticeView` on the first false→true
  transition of `speechVM.isRecording` per session, says "Toward your
  <voice> voice" once, then fades — suppressed when an active drill
  already owns the in-the-moment intent surface, and silent when no
  `CoachingProfile` is set. Together those two surfaces give every
  Timed rep at least one personalized touchpoint (banner) and a richer
  one when the listener earns a goal-aligned rhetorical move (HUD).
  **Post-session momentum line is now goal-aware too**:
  `VerdictEngine.generate` runs `enrichMomentumWithStyleAlignment` when
  a `styleGoal` is set — for any improving `SkillTrend` whose
  `skillArea` lands in `SpeakingStyleGoal.alignedSkillAreas`, the
  Coach Note momentum line gains a clause like "Your pace gain moves
  you toward your warm voice." Restraint built in: the helper only
  fires when there's a real improving trend on a goal-aligned skill,
  so it never invents personalization for off-goal wins. Three unit
  tests cover the celebrate / off-goal-silent / no-goal-silent paths.
  **Profile now visualises distance-from-goal as a real progress
  ring**: `GoalProgressView` (new) sits inside the Coaching Direction
  card and reads `baseline.measuredDistanceFromGoal(primaryGoal)` —
  a sibling of the existing `distanceFromGoal` that returns nil
  instead of the legacy 0.5-default when the underlying dimension is
  `.insufficient`. The ring fills to `(1 - distance) * 100%` and
  colour-bands by proximity (positive ≥ 75%, brandBlue ≥ 50%, caution
  ≥ 25%, secondary otherwise). A week-over-week trend chip ("Closer
  this week" / "Holding steady" / "Slipped this week") fires when
  `GoalProgressTrend.compute` finds ≥ 3 recent + ≥ 3 prior qualifying
  `SkillSnapshot`s. `.calmerDelivery` is now measurable end-to-end:
  `SkillSnapshot.pauseFilledRatio` is a new optional field written by
  `SessionFinalizer` whenever the session contained ≥ 1 pause (zero-
  pause reps stay nil so they can't be mistaken for "perfectly calm"),
  and `CommunicationBaseline.distanceFromGoal(_:, in:)` aggregates the
  qualifying ratios with the same 0.8 saturation target as the
  persistent baseline. The chip stays hidden until the user has
  accumulated ≥ 3 reps with real pause history in each window —
  restraint over coverage. Closes the M14 goal-aware loop end-to-end
  for every voice: the same metric that anchors the pre-rep
  `VoiceAnchorBanner`, biases the mid-rep `LiveEloquenceHUD`, and
  frames the post-rep Coach Note momentum is now visible on the
  profile as a single proximity reading the user can watch move,
  for all four `CoachingPriority` values. Fifteen unit tests cover
  the formula correctness across all four goals, the insufficient-
  data nil paths (including the zero-pause skip), the trend-direction
  classifier, and the chip-copy restraint contract.
  **Home recommendation tile is now goal-aware too**: a fifth surface
  in the chain. `PracticeMode.primarySkillAreas` maps each mode to the
  2–3 skill areas it most directly trains (e.g. `.timed` →
  `[.structure, .answerDevelopment, .openingStrength]`,
  `.ahCounter` → `[.fillerReduction, .paceControl, .pauseUsage]`).
  `SpeakingStyleGoal.aligns(with mode:)` is true iff that mode's primary
  skills overlap with the voice's `alignedSkillAreas`. `VoiceAlignmentChip`
  (new) sits under the subtitle of the home `suggestionLink` and reads
  "Toward your <voice> voice" when the chosen voice and the recommended
  mode line up. Silent in three honest paths: no `CoachingProfile`, no
  `SpeakingStyleGoal` on the profile, or the alignment intersection is
  empty (warm-voice users on a sudden-death recommendation see nothing,
  not a fake nudge). The set design ensures every voice has at least one
  aligned mode (so the chip is reachable for everyone) AND every voice has
  at least one non-aligned mode (so the chip retains meaning when it does
  fire). Twelve unit tests cover the mode→skill mapping, six aligned /
  non-aligned voice×mode cases, the coverage invariants (no orphan modes,
  no always-on voices), and the brand-voice copy guards.
  **Looking Ahead card now wears the same chip**: sixth surface in the
  chain. `LookingAheadCard.Hint` gained an optional `styleGoal:
  SpeakingStyleGoal?` field (defaulted nil so the legacy initializer
  still compiles), and the card renders the existing `VoiceAlignmentChip`
  underneath the body copy with `AppColor.tint(for:)` mirroring the
  mode-color contract used by the home tile. `SummaryView.lookingAheadHint`
  passes `coachingProfileStore.profile?.speakingStyleGoal` through. The
  same three honest silent paths apply on the post-rep surface — no
  profile, no voice goal, or off-mode alignment — so the post-session
  surface respects the same restraint the home surface respects. Six
  unit tests in `LookingAheadCardVoiceAlignmentTests` lock the
  `Hint.shouldShowVoiceAlignment` predicate independently of SwiftUI:
  aligned voice×mode shows the chip; warm→sudden-death stays silent;
  nil voice stays silent; every voice has at least one firing and one
  silent mode; the legacy initializer back-compat is locked. Closes the
  goal-aware coaching loop end-to-end — every surface the app uses to
  recommend, frame, or report on a user's next move now reads from the
  same `SpeakingStyleGoal` source of truth.
  **The drill picker itself is now goal-aware too**: seventh surface,
  closes the inside of the loop. Earlier work covered every *display*
  of the next move (pre-rep banner, mid-rep HUD, post-rep momentum,
  profile ring, home chip, looking-ahead chip) — but the actual choice
  of *which* skill area to drill on still ignored the voice goal.
  `TrendAnalyzer.primaryFocus(...)` now takes an optional
  `styleGoal: SpeakingStyleGoal?` and applies a small `+10` priority
  bonus to goal-aligned trends. The bias is intentionally small: it
  breaks ties between equal-priority candidates and tips near-ties at
  the developing/solid tiers, but the gaps between urgent tiers
  (declining-high-confidence 100, weak-stable 90, new-issue 80) are
  wide enough that an urgent off-goal trend always wins over a
  goal-aligned developing one. Urgency-first, voice-second.
  `DrillEngineV2.recommend(...)` threads `styleGoal:` through
  `determineFocus(...)` → `primaryFocus(...)` (trend path) and
  `sessionOnlyFocus(...)` (day-one path, no trends). The day-one
  fallback no longer returns the generic `.structure` when a voice
  is stated — it returns the voice's canonical
  `primaryAlignedSkillArea` (a new deterministic accessor since
  `alignedSkillAreas` is a `Set` without order). So a brand-new user
  who picks "warm" gets a pace-control drill from their first
  session, not a structure drill. `NextActionEngine.standardDrill`
  resolves `SpeakingStyleGoal` from `NextActionInput.styleGoal` and
  passes it through; `SessionFinalizer` also threads the voice into
  the Coach Note `primaryFocus` lookup so the "leverage" line stays
  aligned with the skill the drill is about to train (no more "your
  biggest opportunity is structure" appearing next to a pace drill).
  `SummaryView.drillRecommendationV2` reads
  `coachingProfileStore.profile?.speakingStyleGoal` too, so the
  view-tier preview matches the persisted recommendation. Ten unit
  tests in `GoalAwareDrillSelectionTests` lock the contract: bias
  breaks ties at the developing tier, bias never overrides
  declining-high / weak-stable / new-issue (three separate tests),
  bias is silent without a goal, day-one fallback maps every voice
  to its canonical lever, and the `primaryAlignedSkillArea`
  mapping itself is asserted against every voice in the catalog so
  a future refactor can't quietly shuffle the order.
- **AI-generated recommendation reasons** — `RecommendationBiasEngine`
  now feeds dynamic per-user `whyNow` / `whyMode` text into the
  practice mode picker's recommended row. Falls back to the pre-baked
  per-mode line when no profile / no session history exists.
  `modeBenefit` + `whyNow` also surface on the post-session summary
  via `LookingAheadCard` at the bottom of the expandable details
  section — gated on ≥3 sessions of signal AND a different
  recommended mode than the one just finished, so the in-the-moment
  drill stays the hero. The blueprint's `focus` and `target` fields
  remain home-screen only.
- **Hosted privacy policy URL** — the bundled `PrivacyPolicy.md` is
  now rendered in-app via `PrivacyPolicyView`, reachable from
  Settings → Privacy & Data → Privacy policy. `public/privacy.html`
  + `public/index.html` are staged and `firebase.json` has the
  hosting + `/privacy` rewrite. `firestore.rules` file is committed
  alongside `FIRESTORE_RULES.md`. Deploy still pending explicit
  greenlight — `firebase.json` needs the `"firestore": {"rules":
  "firestore.rules"}` block added, then
  `firebase deploy --only firestore:rules,hosting --project noum-d0b6f`.
- **SpeakingRatingCard placeholder — resolved.** When
  `rating.ratingHistory` is empty `RatingHistoryChart` returns
  `EmptyView()` from the chart slot, collapsing it entirely. The
  card header (rating number + peak + session count) stays visible
  above, and the trend strip ("Holding steady" / "Trending up" /
  etc.) still surfaces from the live trend computation. No
  placeholder copy is rendered. See `Noum/RatingHistoryChart.swift`
  lines 38–49.

### Not started

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
- **Dynamic Type partial coverage** — every `Typography.*` role now
  binds to a `Font.TextStyle` via `relativeTo:` so the canonical type
  catalog tracks Dynamic Type end-to-end. The `figtree(...)` and
  `manrope(...)` builders require the new argument so the contract is
  compiler-enforced. Hero surfaces (`SplashScreenView`, `ProfileView`
  rank panel + rating display + league panel + goal row + reflections
  + active challenge, `SummaryView` transcript card, `FirstRepCelebration`
  CTAs, `WordChoiceCard`, `PauseSummaryCard`, `PersonalBestHeroCard`)
  migrated off ad-hoc `.system(size:)` onto the catalog or
  `Typography.figtreeNumeric(...)`. Remaining `.system(size:)` call
  sites are intentional: bitmap share card rendered via `ImageRenderer`
  at a fixed 360pt frame (`SummaryView` lines 1860–2033), achievement
  grid badges inside fixed 48pt cells (`ProfileView` 710, 720), and a
  few decorative SF Symbol particles. A unit test
  (`typographyRolesResolveToFonts`) locks the catalog contract so a
  future refactor that drops `relativeTo:` fails the test suite.
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
