# M19 Personalization Audit — What Noum Captures vs Uses vs Leaves Dormant

_Audited: 2026-05-22 · branch `Redesign` · HEAD `088ff63`_

---

## 1. Sign-up Intake (CoachingProfile fields)

`CoachingProfile` is defined at `Noum/PracticeSupport.swift:368`. The onboarding surface is `Noum/CoachingOnboardingView.swift`. Fields flow through `CoachingProfileStore.shared`.

| Field | Type | Set at | Read by | Verdict |
|---|---|---|---|---|
| `speakingContext` | `SpeakingContext` enum (work / interviews / presentations / social) | `CoachingOnboardingView:42` | `GoalParaphraseService:98`, `AIPromptGeneratorService:163`, `PracticeTopics:611` (maps context → preferred topic theme), `SettingsView:584` (display tag only) | **PARTIALLY USED** — shapes AI topic theme selection and paraphrase input; never reaches `CoachContextBuilder.userContext` so the live AI coach never sees it directly |
| `primaryGoal` | `CoachingPriority` enum (reduceFillers / moreConcise / thinkFaster / calmerDelivery) | `CoachingOnboardingView:42` | `TrendAnalyzer.primaryFocus:366` (highest-impact driver), `FeedbackEngine:142` (verdict copy), `AISessionDebriefCard:168` (`distanceFromGoal`), `AIWeeklyInsightCard:251`, `AIPromptGeneratorService:161`, `PracticeTopics:609`, `GoalParaphraseService:97`, `SettingsView:585`, `PressureFollowUpService:133` | **USED** — this is the most wired field; feeds drill selection, debrief copy, and weekly insight |
| `confidenceLevel` | `ConfidenceLevel` enum (beginner / rebuilding / inconsistent / confident) | `CoachingOnboardingView:42` | `NextActionEngine:67` (uses `action.confidenceLevel.label` but this is a NextAction field, not the profile field — see note) | **DORMANT** — `CoachingProfile.confidenceLevel` is persisted but not passed to `CoachContextBuilder`, `FeedbackEngine`, or any AI prompt. `NextActionEngine` uses its own `confidenceLevel` computed from context. The AI coach has no idea how the user self-rated their confidence at sign-up. |
| `biggestChallenge` | `SpeakingChallenge` enum (fillerWords / rambling / freezing / rushing) | `CoachingOnboardingView:42` | `GoalParaphraseService:101`, `AIPromptGeneratorService:164`, `PracticeTopics:611,613`, `PathJourneyView:574` (copy variant), `HomeCoachCard:360` (coach subtitle variant), `SettingsView:586`, `ContentView:1859` (change-detection hash) | **PARTIALLY USED** — shapes AI prompt topics and some copy variants; never appears in `CoachContextBuilder.userContext` so the live AI coach cannot cite "you said your biggest challenge is freezing" |
| `desiredOutcome` | `SpeakingOutcome` enum (concise / composed / persuasive / spontaneous) | `CoachingOnboardingView:42` | `GoalParaphraseService:100`, `ContentView:1859` (hash only) | **DORMANT** — captured, used only to compute the AI paraphrase once, then ignored. Never reaches `FeedbackEngine`, `TrendAnalyzer`, or `CoachContextBuilder`. |
| `speakingStyleGoal` | `SpeakingStyleGoal` enum (authoritative / warm / concise / persuasive / executive / storytelling) | `CoachingOnboardingView:44` | `CoachContextBuilder.systemPrompt:37` (entire coach personality), `CoachContextBuilder.userContext:194` (GOAL section), `FeedbackEngine` (copy register), `SummaryView` (multiple surfaces), `SessionFinalizer:285,310,325`, `FirstRepCelebration:240,417`, `AskNoumView` (starter prompts, follow-up chips), `ContentView:1859` | **USED** — the most deeply wired field; shapes the entire AI coach personality and every voice-specific copy surface |
| `styleReference` | `String` (free text — "who do I want to sound like?") | `CoachingOnboardingView:45` | `GoalParaphraseService:102` (one-time paraphrase input only) | **DORMANT** — after the paraphrase pass at onboarding, `styleReference` is never read again. The AI coach never sees "I want to sound like Obama." |
| `coachingBrief` | `String` (free text — "what's your goal?") | `CoachingOnboardingView:45` | `CoachContextBuilder.userContext:197–199` (via `paraphrasedGoal` — the raw brief is NOT passed; only the AI paraphrase is), `DeferredProfileCapture:132,170,303,331` (capture / edit path), `GoalParaphraseService:103` | **PARTIALLY USED** — the raw text is paraphrased once by AI and then the raw string is effectively shelved. The paraphrase (not the raw words) reaches the coach. If the paraphrase failed or was empty, neither form reaches the coach context. |
| `motivationWhyNow` | `String` (free text — "why does this matter now?") | `CoachingOnboardingView:46` | `CoachContextBuilder.userContext:201–204` (as `whyNowReference`, IF non-empty), `DeferredProfileCapture:134,172`, `GoalParaphraseService:104`, `PRIVACY_REMEDIATION.md:276` (streak notification template — documentation artifact, not live code) | **PARTIALLY USED** — does reach the AI coach context when non-empty, but only as a raw text appended; not structurally parsed. Many users leave it blank → the AI coach never learns what prompted them to sign up. |
| `successVision` | `String` (free text — "what would success look like?") | `CoachingOnboardingView:47` | `DeferredProfileCapture:60,136,174`, `GoalParaphraseService:105` (paraphrase input only) | **DORMANT** — the most forward-looking signal captured (the user's own vision of transformation) is used only as paraphrase input. It never appears in `CoachContextBuilder`, never reaches the AI coach, and is never surfaced in any coaching card. |
| `paraphrasedGoal` | `String?` (AI-generated summary of the above) | `GoalParaphraseService` (async, post-save) | `CoachContextBuilder.userContext:197–199` (GOAL section — "In their words") | **USED** — the one synthesized field that actually reaches the live coach; but its quality depends on how well the raw fields were populated |

**Intake summary: 3 USED, 4 PARTIALLY USED, 4 DORMANT** out of 11 fields.

---

## 2. Performance Signals (per-session + longitudinal)

`PracticeSession` is defined at `Noum/SpeechRecognizerViewModel.swift:577`. `CommunicationBaseline` at `Noum/BaselineEngine.swift:167`. `SkillSnapshot` at `Noum/TrendAnalyzer.swift:7`.

| Metric | Computed at | Persisted in | Surfaced in UI | Reaches AI Coach | Verdict |
|---|---|---|---|---|---|
| Filler count / rate | `FillerWordDetector` → `SpeechRecognizerViewModel` | `PracticeSession.fillerWordCount`, `BaselineStat fillerRate` in `CommunicationBaseline`, `SkillSnapshot.fillerCount` | Summary, History, Trends chart, Home (VoiceMetricsCard indirect), WhatToImproveCard | `CoachContextBuilder.userContext` (baseline fillers/min + recent 3 session counts), `BaselineEngine.promptContext` (for session debrief AI) | **USED** |
| Duration | `SpeechRecognizerViewModel` | `PracticeSession.duration`, `BaselineStat durationTendency` | Summary, History | `CoachContextBuilder.userContext` (recent sessions show duration), `BaselineEngine.promptContext` | **USED** |
| WPM / Pace | `WPMEvaluator` | `PracticeSession` (via score context), `BaselineStat pace` | Summary pace card, Trends chart, WhatToImproveCard | `CoachContextBuilder.userContext` (baseline pace), `BaselineEngine.promptContext` | **USED** |
| Session score (0–10) | `BaselineEngine` | `PracticeSession.score`, `BaselineStat averageScore` | Summary, Profile charts, Rating card | `CoachContextBuilder.userContext` (recent sessions scores, average), `BaselineEngine.promptContext` | **USED** |
| Rating (ELO) | `RatingEngine` | `SpeakingRating` in `RatingStore` | Profile, League, Peak Rating Wall | `CoachContextBuilder.userContext` (overall, peak, delta) | **USED** |
| Pause metrics (count, mean, longest, filled/unfilled ratio) | `PauseMetrics` (word-timing analysis) | `PracticeSession.pauseMetrics`, `BaselineStat pauseRate`, `SkillSnapshot.pauseRate`, `SkillSnapshot.pauseFilledRatio` | `PauseSummaryCard` in Summary, `VoiceMetricsCard` on Home, Trends chart (Pauses pillar), path node criteria | `CoachContextBuilder.userContext` (baseline `pauseRate` when confidence ≥ initial), `BaselineEngine.promptContext` (pause rate). **BUT:** `pauseFilledRatio` (filled vs unfilled quality) is in `SkillSnapshot` and `BaselineStore` but NOT in `CoachContextBuilder` — the coach knows count but not quality of pauses | **PARTIALLY USED** |
| Pitch / monotone score | `PitchAnalyzer` → `PitchMetrics` | `PracticeSession.pitchMetrics`, `BaselineStat pitchVariation`, `SkillSnapshot.pitchMonotone` | Trends chart (Pitch pillar), `BaselineEngine.identifyStrengths/Blockers` → `CommunicationBaseline.topStrengths/persistentBlockers` | `CoachContextBuilder.userContext` (baseline `pitchVariation` when confidence ≥ initial), `BaselineEngine.promptContext` (pitch baseline label + monotone score) | **USED** |
| Hedging rate (kind of / sort of / I think) | `BaselineEngine` (computed from transcripts) | `BaselineStat hedgingRate` in `CommunicationBaseline` | Not exposed in any card or chart directly (only feeds AI context) | `CoachContextBuilder.userContext` (baseline hedging/min), `BaselineEngine.promptContext` | **PARTIALLY USED** — computed, stored, fed to AI, but never shown to the user in any card. The user cannot see their own hedging trend. |
| Word choice (unique ratio, repeated words) | `WordChoiceMetrics.compute()` | Computed on-demand per session; NOT persisted to `PracticeSession` or `BaselineStore` | `WordChoiceCard` in Summary, `VoiceMetricsCard` on Home (rolling compute) | **Not in `CoachContextBuilder` at all** | **DORMANT** as a coaching signal — shown in UI but never given to the AI coach. The AI cannot say "your vocabulary breadth is 68%, up from 55% last month." |
| Eloquence findings (11 rhetorical devices) | `EloquenceEngine` per session | `PracticeSession` has no `eloquenceFindings` field — findings are computed in `SessionFinalizer` and displayed in `EloquenceFindingsCard` but not persisted per-session | `EloquenceFindingsCard` in Summary, `LiveEloquenceHUD` (in-session, now removed for Sudden Death) | **Not in `CoachContextBuilder`** | **DORMANT** — the coach cannot reference "you've used tricolon three times this week" because that longitudinal data isn't tracked |
| Grammar findings | `GrammarFeedbackService` (Pro only) | `PracticeSession.grammarFindings` (nullable) | `GrammarPolishCard` in Summary | **Not in `CoachContextBuilder`**; not in baseline | **DORMANT** — grammar errors per session are shown once and not fed into longitudinal coaching |
| Clutch words (verbal habit filler phrases) | `ClutchWordStore` + `BaselineEngine.updateWithClutchWords` | `BaselineStat` per word in `CommunicationBaseline.clutchWordFrequencies` | Profile (implied via `topStrengths` / `persistentBlockers`) | `BaselineEngine.promptContext:1022–1028` (top 3 significant clutch words) — but `BaselineEngine.promptContext` is used for session-debrief AI calls, NOT for `CoachContextBuilder` (persistent chat). The Ask Noum coach never sees clutch words. | **PARTIALLY USED** |
| Transcript confidence score | `SpeechRecognizerViewModel` | `PracticeSession.transcriptConfidence` | Not shown in UI | **Not in `CoachContextBuilder`** | **DORMANT** |
| IM conversation details | `IMPracticeView` → `IMConversationDetails` | `PracticeSession.imConversationDetails` | `SessionHistoryDetailView` (IM conversation card) | **Not in `CoachContextBuilder`** — the coach cannot reference IM tone or scenario settings | **PARTIALLY USED** |
| Practice mode | `PracticeMode` enum | `PracticeSession.mode` | History, Summary | `CoachContextBuilder.userContext` (recent sessions show mode label) | **USED** |
| Pressure level | `PressureLevel` enum | `PracticeSession.pressureLevel` | Summary (pressure mode badge) | Only via `BaselineEngine.promptContext` (session-level debrief), not in `CoachContextBuilder` persistent chat | **PARTIALLY USED** |
| Prompt used | `String?` | `PracticeSession.prompt` | History detail view | **Not in `CoachContextBuilder`** — coach cannot reference "last time you tried the boardroom prompt" | **DORMANT** |
| Theme used | `PromptTheme?` | `PracticeSession.theme` | History detail view | **Not in `CoachContextBuilder`** | **DORMANT** |
| Drill result | `DrillResult?` | `PracticeSession.drillResult`, `SkillSnapshot.drillCompleted` | Summary (drill outcome) | `TrendAnalyzer` (drill success feeds `SkillTrend`), `SkillProgressionStore`; **not in `CoachContextBuilder`** | **PARTIALLY USED** |

---

## 3. Derived Insights (rollups, trends, comparisons)

| Insight | Computed by | Shown to user | Reaches AI Coach | Verdict |
|---|---|---|---|---|
| `TrendAnalyzer.analyze()` — skill trends (improving / declining / stable / newIssue / resolved per dimension) | `TrendAnalyzer.swift:220` | Feeds `FeedbackEngine` verdict copy in Summary, `WhatYouDidWellCard`, `WhatToImproveCard` | **Not in `CoachContextBuilder`** — the persistent AI chat has no access to "filler rate declining for 3 weeks" trend direction | **PARTIALLY USED** |
| `TrendAnalyzer.primaryFocus()` — dominant skill area needing attention | `TrendAnalyzer.swift:366` | Drives drill selection in `FeedbackEngine`, `SessionFinalizer` | **Not in `CoachContextBuilder`** | **PARTIALLY USED** |
| `CommunicationBaseline.topStrengths` / `persistentBlockers` | `BaselineEngine.identifyStrengths/Blockers` | Profile (implied) | `CoachContextBuilder.userContext:294–299` (TRENDS section — strings like "Filler control" or "Rushing") | **USED** |
| `PressureProfile.pressureResilience` | `BaselineEngine.swift:440` | `SummaryCards.swift:605` (pressure resilience ring) | `BaselineEngine.promptContext:1035` (session debrief only, not persistent chat) | **PARTIALLY USED** |
| `SkillProgressionStore` — level-up events (fillerFree / speedControl / endurance / etc.) | `SkillProgressionStore.swift` | `PreSummaryCelebration.swift` (celebration screen) | **Not in `CoachContextBuilder`** | **PARTIALLY USED** |
| `ProofMomentStore` — verbatim transcript moments | `ProofMomentService` | `GrowthLibraryView` (browseable), `AIWeeklyInsightCard` (proof of week), `PathNodeCelebration` | `CoachContextBuilder.userContext:309–320` (PROOFS block, max 3) | **USED** |
| `RecommendationLearningStore` — mode recommendation outcomes (shown, tapped, resulted in good score) | `PracticeSupport.swift:5901` | Feeds `RecommendationBiasEngine` → mode picker recommended row | **Not in `CoachContextBuilder`** — the coach cannot say "you respond well to Ah-Counter reps" | **DORMANT** |
| League tier / ranking | `LeagueManager` | `LeagueView`, Profile, `TierPromotionOverlay` | `CoachContextBuilder.userContext:217` (rating tier label only) | **PARTIALLY USED** |
| Streak length | `StreakFreezeManager` | Home, Profile, Widget, Notification | `CoachContextBuilder.userContext:261` (streak days) | **USED** |
| Path chapter / mission status | `PathProgressManager` | Home journey card, Path map | `CoachContextBuilder.userContext:280–287` (PATH section) | **USED** |
| Mode mastery level (Bronze/Silver/Gold/Platinum per mode) | `ModeMasteryStore` | Profile | **Not in `CoachContextBuilder`** — the coach cannot reference "you've reached Gold in Ah-Counter" | **DORMANT** |
| Lesson crowns | `LessonStore` | Lesson catalog, Path criteria | **Not in `CoachContextBuilder`** | **DORMANT** |
| Prompt history (seen prompts, last 14 days) | `PromptHistoryStore` | Implicit (dedup logic in `PracticeTopics`) | **Not in `CoachContextBuilder`** | **DORMANT** |
| Word of the day usage | `WordOfTheDayManager` | Home utility strip ("used today" indicator) | **Not in `CoachContextBuilder`** | **DORMANT** |

---

## 4. The Delta — What a Real Coach Would Know That Noum Doesn't

### Gap 1 — The "Big Moment" (no upcoming event capture)
A real coach asks "what are you preparing for?" at every session or check-in — a board pitch next Tuesday, a job interview on Thursday, a difficult conversation with a manager. Noum captures `speakingContext` (a category) and a one-time `coachingBrief` (a goal) but never asks "what's coming up for you this week?" The AI coach cannot say "your pitch is in 3 days — here's what to drill."
**Minimal capture:** a recurring "upcoming event" field in the post-session bridge or a lightweight weekly check-in prompt (one question, dismissible). Stored as `UpcomingEvent: { title, date, eventType }` on `CoachingProfileStore`, surfaced to `CoachContextBuilder`.

### Gap 2 — Chronic failure pattern across sessions (no time-of-session breakdown)
A real coach notices "you always fall apart at minute 2." Noum's `PressureProfile` captures casual vs high-pressure deltas, but does not capture within-session decay — the fact that filler rate climbs in the second half of long reps, or that the user freezes specifically in the first 15 seconds. `SkillSnapshot` has no `timePhaseBreakdown` field.
**Minimal capture:** add `firstHalfFillerRate` and `secondHalfFillerRate` to `SkillSnapshot`; surface a "consistency" dimension in `TrendAnalyzer`; feed it to `CoachContextBuilder`.

### Gap 3 — Stylistic preferences (no "liked / didn't like this rep" signal)
After a rep, a user might feel proud or cringe. Noum captures score and fillers but has no subjective signal. A real coach asks "how did that feel?" `AskNoumView` lets the user describe feelings in chat, but this is not persisted as structured data — it evaporates when the thread clears.
**Minimal capture:** a single-tap "felt good / felt off" binary on `SummaryView` (not a rating, just a signal), persisted to `PracticeSession.userSentiment: Bool?`. Feed it to `CoachContextBuilder` so the coach can say "you rated this one 'felt good' and scored 8 — trust that instinct."

### Gap 4 — Confidence level never revisited (static onboarding field)
`confidenceLevel` is captured once at onboarding and never updated. A coach continuously recalibrates: after 30 sessions a "beginner" may feel confident, but Noum still treats them as a beginner internally because the field was never rewired.
**Minimal capture:** recompute `confidenceLevel` dynamically from session history (e.g., `averageScore ≥ 7.5` over last 10 reps → "confident"; `averageScore < 5.0` → "rebuilding"). Feed the derived level to `CoachContextBuilder` instead of the stale onboarding value.

### Gap 5 — `successVision` never surfaced post-onboarding
The user wrote "I want to feel calm in my next performance review." This is the most emotionally motivating thing Noum captures. Yet it never appears in the AI coach's context, in any notification, or in any progress card. A real coach references the client's own vision of success regularly to maintain motivation.
**Minimal capture:** pass `profile.successVisionReference` into `CoachContextBuilder.userContext` as a GOAL sub-line (alongside `whyNowReference`); use it in streak-warning notification copy ("one more rep toward feeling calm in that review").

### Gap 6 — Recommendation learning not surfaced to the coach
`RecommendationLearningStore` tracks which modes the user was shown, whether they tapped, and what score resulted. This is behavioral preference data — the user implicitly votes on what works for them. The AI coach never sees "you respond 40% better to Ah-Counter reps than Timed."
**Minimal capture:** add a `PREFERENCE` block to `CoachContextBuilder.userContext` with the top-1 mode by average score delta from `RecommendationLearningStore.outcomes`.

### Gap 7 — Word choice trend invisible to the coach
`WordChoiceMetrics` is computed per-session and shown in `WordChoiceCard` and `VoiceMetricsCard`, but is never persisted to `BaselineStore` or `SkillSnapshot`. The coach cannot reference vocabulary breadth longitudinally.
**Minimal capture:** persist `uniqueContentWordRatio` to `SkillSnapshot` (new optional field); add a `wordChoice` rolling stat to `CommunicationBaseline`; surface in `CoachContextBuilder.userContext`.

### Gap 8 — Mode mastery invisible to the coach
A user who has reached Gold in Ah-Counter has demonstrated mastery of filler-avoidance in low-stakes conditions. The coach should route them to Sudden Death. `ModeMasteryStore` exists and is surfaced on Profile but never reaches `CoachContextBuilder`.
**Minimal capture:** pass top-mastered mode(s) into `CoachContextBuilder.userContext` as a MASTERY line; let the coach reason about readiness for harder modes.

---

## 5. Bottom-Line Summary

**Fields captured at intake:** 11  
**Used meaningfully (reaches live coaching or shapes AI behavior):** 3 (`speakingStyleGoal`, `primaryGoal`, `paraphrasedGoal`)  
**Partially used (reaches some surfaces but not the live AI coach):** 4 (`speakingContext`, `biggestChallenge`, `motivationWhyNow`, `coachingBrief`)  
**Dormant (captured but no real downstream coaching consumer):** 4 (`confidenceLevel`, `desiredOutcome`, `styleReference`, `successVision`)

### Top 5 dormant intake fields by coaching impact if surfaced
1. **`successVision`** — the user's own words about why this matters; direct motivational leverage in every coaching surface
2. **`confidenceLevel`** (static) → should become a derived, updated signal; currently shapes nothing in the live coach
3. **`desiredOutcome`** — "sound composed" vs "sound persuasive" is meaningfully different coaching direction, currently used only in the one-time paraphrase
4. **`styleReference`** — "I want to sound like X" is prime material for the coach to frame feedback ("that opener was the opposite of what Jobs would have done")
5. **`biggestChallenge`** — present in topic selection but absent from the AI coach's awareness; the coach cannot open with "you said freezing is your enemy — here's what I saw in that pause"

### Top 5 gaps where Noum can't personalize because the data doesn't exist
1. **Upcoming event / Big Moment** — no mechanism to capture what the user is preparing for; the coach is always generic-future rather than specifically-next-week
2. **Within-session decay pattern** — no first-half/second-half breakdown; the coach cannot catch the "minute-2 collapse" pattern
3. **User-rated rep sentiment** — no subjective "felt good/felt off" signal; the coach works only from objective metrics
4. **Prompt/theme engagement** — no data on which prompts the user found challenging vs easy; the coach cannot say "you struggle with professional scenarios specifically"
5. **Mode mastery as coaching input** — the coach cannot use demonstrated mode mastery to route toward harder challenges or acknowledge growth in specific modes
