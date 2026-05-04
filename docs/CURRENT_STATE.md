# Noum — Current state

_Last updated: 2026-05-04_

## Architecture overview

- **Framework:** SwiftUI, iOS 17 minimum.
- **State management:** `ObservableObject` singletons (`*.shared`) injected into
  views via `@StateObject` — `AuthManager`, `ProfileManager`,
  `PracticeSettingsManager`, `HapticsSettings`, `NotificationManager`,
  `PremiumManager`, `CoachingProfileStore`, `PracticeSessionStore`,
  `IMVoicePlaybackSettingsManager`, `RecommendationLearningStore`,
  `RatingStore`, `BaselineStore`, `ChallengesManager`, `FriendsManager`,
  `ClubsManager`, `AchievementStore`, `ClutchWordStore`. No
  Observation-framework migration yet.
- **Persistence:** `UserDefaults` keyed per-account
  (`<key>.<accountID>`), Keychain for the account ID + provider, and
  `BackendSyncManager` for optional Firebase sync of XP, sessions,
  coaching profile, and recommendation outcomes.
- **Audio / speech:** `AVAudioEngine` capture →
  pluggable `TranscriptionProvider` (AWS Transcribe streaming, Deepgram
  WebSocket, Google Speech-to-Text V2). Provider chosen via the
  `transcriptionProvider` AppStorage key. On-device `SFSpeechRecognizer`
  is **not** used.
- **Backend:** Firebase Auth (Apple, Google, anonymous), Firestore
  via `BackendSyncManager`, optional REST backend for vended AWS
  credentials. Privacy posture documented in `Noum/Noum/PRIVACY_*.md`.
- **AI providers:** Google Gemini and OpenAI for coaching analysis
  (`AINPCChatService`, configured in `AIConfig.plist`). Google Cloud
  TTS for IM voice playback with OpenAI fallback.
- **Design tokens location:** `Noum/DesignSystem.swift` — single source
  of truth for `Spacing`, `CornerRadius`, `AppColor`, springs, shared
  components (`CardView`, `StatCard`, `PrimaryCTA`, `PressableButtonStyle`,
  `LightGradientBackground`, `SectionHeader`, `ErrorCard`,
  `MilestoneCelebrationOverlay`). **Typography lives in
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
  filler ends the round.
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

### Progression & retention
- `Noum/Noum/ProfileManager.swift` — XP store (per-account), level
  ladder (`Beginner/Novice/Average/Professional/World Class` × I/II/III),
  rank symbol/tint/title.
- `Noum/Noum/AchievementStore.swift` — 7 tracks (Volume, Consistency,
  Clarity, Scores, Endurance, Modes, Mastery), real unlock conditions.
- `Noum/Noum/ChallengesManager.swift` — daily/weekly/streak/social
  challenge models; `RetentionLoopEngine` produces an "active challenge"
  snapshot for the home screen.
- `Noum/Noum/PathJourneyView.swift` — visual journey (scenes that
  reveal as session count grows).
- `Noum/Noum/RewardEngine.swift` (`Noum/`) — emits XP, streak, and
  milestone events.

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
- `Noum/Noum/NotificationManager.swift` — single follow-up reminder
  per session.

### Settings & UX primitives
- `Noum/Noum/SettingsView.swift` — production settings (refactored).
- `Noum/Noum/SettingsRow.swift` — `SettingsToggleRow`, `SettingsNavRow`,
  `SettingsStatusRow`, `SettingsSectionLabel`.
- `Noum/Noum/HapticsSettings.swift` — global haptics gate, honored
  by `CoachHaptic` and every `.sensoryFeedback`.
- `Noum/Noum/CoachHaptic.swift` — every haptic pattern routes through
  `HapticsSettings.isEnabledSync`.

## Feature status

### Implemented (shipping end-to-end)

- **Eloquence detection** — `EloquenceEngine` runs on every session
  transcript and surfaces rhetorical devices (tricolon, anaphora,
  epistrophe, alliteration, isocolon, antithesis, polysyndeton,
  asyndeton, diacope, epizeuxis, rhetorical question) as positive
  coaching in the summary's `EloquenceFindingsCard`. Conservative
  thresholds; the card hides when there's nothing notable. Inspired
  by Forsyth's *Elements of Eloquence*. Unit-tested (9 tests in
  `EloquenceEngineTests`).
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
- **Streaks** — calculated from session dates, surfaced in home,
  profile, and reminder copy.
- **XP / levels / ranks** — XP persistent per-account, levels derived
  (`xp / 1000` with sub-level Roman numerals), rank surface on home,
  profile, and Settings hero.
- **Achievements** — 7 tracks, real unlock paths, unlock dates stored,
  badge animations on the achievements page.
- **Topic / prompt generation** — 200+ curated prompts in
  `PracticeTopics.swift` across 8 themes. **No AI generation.**
- **AI coaching reads** — Coach Mode + Coach Read via
  `AINPCChatService` (Gemini / OpenAI), gated to Pro, 100/mo limit.
- **Pressure Mode** — auto-ramping round configs across Timed and
  Sudden Death; baseline-aware pressure classification.
- **Difficulty levels — Timed only** — Easy / Medium / Hard.
- **Define goal & why** — captured during `CoachingOnboardingView`,
  surfaced in reminder bodies and recommendation context. UI to
  display goal at the top of practice picker was just removed because
  it leaked raw user input; the data is still captured. After capture,
  `GoalParaphraseService` runs a single best-effort AI pass and stores
  the result as `CoachingProfile.paraphrasedGoal`. UI surfaces use the
  paraphrase via `displayableGoal` and fall back to the deterministic
  template when no paraphrase is present (no AI key, network failure,
  legacy profile).
- **Trend direction** — `TrendAnalyzer` produces improving / stable /
  declining / newIssue / resolved classifications. Surfaced as a
  pill on the profile, **not as a chart**.
- **Recommendation engine** — `RecommendationBiasEngine` +
  `CoachingPlanner` produce next-best-mode + reason, with
  `RecommendationLearningStore` tracking whether following the
  recommendation actually moved score/filler/duration deltas.
- **Notifications — single follow-up** — opt-in, fires 18h after a
  session, lock-screen-safe copy that never quotes the user's typed
  goal.
- **Settings** — production-quality refactor with hero profile, Pro/
  Free state, manage-subscription deep link, typed deletion confirm,
  haptics master gate, mic permission status, "Your data" sheet,
  diagnostic copy.

### Partially implemented

- **Pause analysis** — first-class in **Land the Pause** mini-drill
  (lock-in mechanic), but **not measured as a session metric** in
  Timed / Sudden Death / Ah-Counter / IM. Surfaces nowhere in summary
  cards or trends.
- **Word choice** — `ClutchWordStore` tracks user-defined "clutch
  words" (words to avoid) and surfaces a top-5 list. **No vocabulary
  variety, sophistication, or repetition analysis.**
- **Daily / weekly challenges** — model + UI scaffold real, used by
  `RetentionLoopEngine` to produce one "active challenge" tile.
  **Auto-rotation / weekly reset / leaderboard not wired.** It's a
  single rolling status, not a true daily challenge surface.
- **Friends / async challenges (M2 v1)** — round-trip via Firestore
  shared docs at `challenges/{id}` is shipped. Each participant writes
  their own slice and reads the doc. Local persistence is a cache;
  `ChallengesManager.refreshFromBackend()` merges. The simulated
  opponent is removed. Friend invitation by QR code carries the
  inviter's `accountID` so peer stats can be fetched. Friends added
  before M2 (no `accountID`) keep showing "Awaiting sync".
- **Weekly league (M2 v1)** — `LeagueManager` writes the user's snapshot
  to `leagues/{tier}_{ISO-year}-W{week}/members/{accountID}` after every
  session. `LeagueView` reads top 20 of the current bucket. Tier is
  derived from rating (Bronze < 300, Silver < 500, Gold < 700, Platinum
  < 850, Diamond ≥ 850). Pre-launch the league is sparse — the empty
  state explicitly says "your league forms over the week".
- **Clubs** — `ClubsManager.swift` is scaffolding only; no real club
  membership / club challenges / club leaderboard ship.
- **Path Journey** — visual progression (scenes reveal as session
  count grows). **No branching paths, no node-by-node skill
  unlocking, no "next required step" guidance.**
- **Difficulty levels — non-Timed modes** — Sudden Death, Ah-Counter,
  IM Mode have no user-visible difficulty selector. (Pressure Mode
  rounds escalate automatically, but a per-mode skill level isn't
  exposed.)
- **Topic generation — AI** — pool is static. The AI infrastructure
  exists (`AINPCChatService`) but isn't wired to generate fresh
  prompts.
- **Behaviour analytics** — trend direction is computed but not
  charted; clutch-word and filler-pattern counters exist but aren't
  rolled into a single "what's changed for you this week" digest.
- **Custom notifications** — only one follow-up per session, no daily
  reminder at a chosen time, no streak-protection nudge, no challenge
  expiry warning, no goal anniversary, no escalation.

### Stubbed / placeholder

- **Goal-driven coaching feedback in mid-session UI** — the goal is
  captured but only used in reminder copy and recommendation rationale.
  It does not influence drill prompt selection, evaluation weighting,
  or session debrief framing.
- **AI-generated recommendation reasons** — `RecommendationBiasEngine`
  produces a structured `reason` per blueprint that is currently
  ignored by the picker (the picker uses pre-baked per-mode lines
  instead).
- **In-app privacy policy** — `Noum/Noum/PrivacyPolicy.md` exists in
  the bundle but is not rendered anywhere; no hosted public URL yet
  (see `PRIVACY_REMEDIATION.md` §1.2).

### Not started

- **Pitch / intonation analysis** — zero pitch tracking. The audio
  pipeline drops the signal at transcription time.
- **Grammar / English-usage evaluation** — no parser, no AST, no
  grammar feedback.
- **Word of the day** — not present.
- **Multilingual support** — every transcription provider is hardcoded
  to `en-US`; all copy and prompts are English.
- **Line / bar charts for progression** — `TrendAnalyzer` data is
  rendered as labels and pills only. No `SwiftUI Chart` usage anywhere.
- **Sponsor / advertisement surfaces** — none, and they conflict with
  the paid model. Mentioned on the original Trello but flagged here
  as "do not build".
- **Lives / hearts gating** — not present (and probably not the right
  loss-aversion mechanic for a speaking app — flagged for VISION).

## Known issues / debt

- **`PremiumManager.restorePurchase()` (no `s`)** at
  `PremiumManager.swift:161` — sets `isPremium = true` without going
  through StoreKit. Looks like a leftover next to `restorePurchases()`
  and `upgradeToPremium()`. Footgun if anything still calls it.
- **Trend graphs not yet rendered** — the data exists end-to-end;
  shipping the first `Chart` view is a high-leverage UX win.
- **Path Journey is decorative** — it implies progression but doesn't
  drive next-best-action. Either tie it to gameplay or demote it.
- **Onboarding goal text quality is variable** — users type free-form
  prose ("the user signed up to be more concise so they can to speak
  like a king…"). The picker used to render this verbatim; that's
  fixed, but the underlying input quality means goal text shouldn't
  be embedded into UI without a sanity check or paraphrase pass.
- **Daily challenge surface is a single tile** — no proper daily reset
  rhythm, no expiry warning before a streak breaks.
- **No "next step here" affordance on the home screen** — the
  recommendation card answers "what mode" but not "what specific
  thing am I working on this week and where am I in it".
- **`AISettingsManager` is referenced but lives inside
  `PracticeSupport.swift`** — that file is 7,800+ lines and a
  long-term refactor target.

## Conventions to preserve

- **State pattern:** new managers follow `final class X: ObservableObject`
  + `static let shared = X()` + `@Published` + UserDefaults persistence.
  Injected into views via `@StateObject private var x = X.shared`.
  **Do not** introduce `@Observable` until the codebase migrates as a
  whole.
- **Per-account scoping:** every persisted user value is keyed
  `<feature>.<accountID>`. Account deletion must clear every key —
  see `AuthManager.clearAllUserData(for:)` for the canonical list.
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
  `reminderBody`.
- **AVAudioApplication.recordPermission** is the iOS 17 API. Don't
  reach for the deprecated `AVAudioSession.requestRecordPermission`.
- **Preview safety:** preview blocks must not mutate real `.shared`
  managers in ways that survive the preview tear-down. Mutations like
  `revokePremium()` / `upgradeToPremium()` are tolerated because they
  reset on relaunch, but new previews should prefer constructor
  injection where the manager surface allows it.
