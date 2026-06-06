# M19–M23 Proposed Milestones
# Coach-Grade Personalization: From Pattern-Matching to a Coach Who Knows You

_Authored by research track `m19-plan` · 2026-05-22 · Read-only research; do not implement directly._

---

## Top-level framing

The £130/hr human coach delivers something Noum does not yet deliver at scale: a coach who remembers your history, asks about the moment in your life that made you pick up the phone, holds you accountable to a forward plan with named milestones, and adjusts the plan when reality intervenes. The M14–M17 arc built the data foundation — goal voice, baselines, proof moments, growth library, Ask Noum chat — but the personalization still sits at the surface level: the coach adapts its *tone* to the user's voice and quotes their *filler rate*, but it does not yet know *why* this person showed up, *what they are training for*, or *where they should be in 60 days*. M19–M23 must close that gap. Every milestone in this arc reinforces communication improvement and coaching trust; none introduce gamification, ad surfaces, hearts-and-lives gating, or leaderboard mechanics that expose what the user said. The five milestones below sequence from intake through forward planning to in-the-moment situational coaching, each one unlocking the next.

---

## Milestone 1 — M19: Big Moment Intake

**Hypothesis:** A coach who knows the specific high-stakes moment the user is preparing for can anchor every rep, every debrief, and every forward plan to something concrete — transforming generic "improve your speaking" motivation into named-event urgency.

**User-visible promise:** On first open after this milestone lands, the user is asked one question: "Is there a specific moment you're preparing for?" — a board presentation, a performance review, a TEDx talk, a job interview, a difficult conversation. If they name it and give a rough date, every subsequent coaching surface shifts register. The home coach card reads "12 days to your board pitch." Ask Noum says "You said your board pitch is in 12 days — let's talk about how Tuesday's rep moves you toward it." The weekly digest notification mentions the countdown. This is not a streak; it is not a badge. It is the thing a human coach would ask in their first session and remember forever.

**Architecture sketch:**
- **New — State ownership:** `Noum/BigMomentStore.swift` — `ObservableObject`, `static let shared`, per-account UserDefaults key `bigMoment.<accountID>`. Stores `BigMoment: Codable` with fields `title: String`, `date: Date?`, `category: BigMomentCategory` (`.presentation`, `.interview`, `.review`, `.conversation`, `.publicSpeaking`, `.other`), `createdAt: Date`. Max one active moment; archiving on expiry (date passes) to a `BigMomentArchive` array (capped at 5) so the coach can reference "last time you had a board pitch." Auth deletion wipes both keys.
- **New — UI view:** `Noum/BigMomentIntakeView.swift` — a single-screen, low-friction sheet (not a multi-step onboarding). Category picker (6 SF Symbol rows) + text field for the name + optional date picker. Dismissible; never blocks. Reachable from `CoachingOnboardingView` as an appended step, from Settings → Coaching Direction, and via `noum://bigmoment` deep link.
- **Extended — State ownership:** `CoachingProfile` in `PracticeSupport.swift` — add `bigMomentID: UUID?` pointing at the active `BigMoment`. Keeps the two stores decoupled; `CoachingProfile` is the gate for coach-aware surfaces.
- **Extended — Pure-function logic:** `CoachContextBuilder.userContext(...)` — add a `BIG MOMENT` section after `GOAL` when a `BigMoment` is active: `"- Preparing for: <title> (<category>). <N> days away."` The model can then ground any reply in the countdown without being told to.
- **Extended — UI view:** `HomeCoachCard.swift` — when a `BigMoment` is set and `daysUntil <= 30`, the `coachSubtitle` variant switches to countdown register: `"<N> days to your <title>."` Suppressed when `daysUntil > 60` (too far out to feel urgent) or when the moment has passed.
- **Extended — Notification:** `NotificationManager.swift` — one new surface: a `scheduleBigMomentCountdown` that fires at the T-7 and T-1 day marks with lock-screen-safe copy referencing the category, not the verbatim title (privacy rule: never expose user-authored text on the lock screen).
- **Extended — Navigation:** `ContentView.swift` — `onboarding` flow appends `BigMomentIntakeView` as a post-`CoachingOnboardingView` push; `AppDestination.bigMomentIntake` case added to `PracticeSupport.swift`. Single-track: `ContentView.swift` + `PracticeSupport.swift` are collision-zone files.
- **Tests:** `NoumTests/NoumTests.swift` — `BigMomentStoreTests` (persistence round-trip, per-account isolation, archive-on-expiry, auth-wipe contract); `BigMomentCountdownTests` (correct day delta, suppression rules); `CoachContextBuilderBigMomentTests` (section present when active, absent when nil, absent when > 60 days out).

**Success criteria:**
1. User names a moment + date; `HomeCoachCard` subtitle changes to countdown copy within the same session.
2. Ask Noum reply for a new chat thread cites the big moment by category and days remaining without the user mentioning it.
3. T-7 notification fires on the right calendar day with lock-screen-safe copy (no verbatim title exposed).

**Risk:** Users who don't have an imminent high-stakes moment may feel the intake is irrelevant — the sheet must be genuinely skippable and the home card must stay substantive without a `BigMoment` set (the existing goal-voice subtitle holds).

**Estimated track count:** 2 parallel agents — one owns `BigMomentStore` + `BigMomentIntakeView` + tests; one owns `CoachContextBuilder` extension + `HomeCoachCard` + notification surface. `ContentView.swift` and `PracticeSupport.swift` must be owned by exactly one agent (assign to track 1).

---

## Milestone 2 — M20: Forward Plan — Coach Writes a 4-Week Program

**Hypothesis:** A human coach doesn't just give you feedback on the last rep — they hand you a written plan at the end of session 1 that tells you what to practice each week and why. Noum has all the data to generate this plan; it just hasn't assembled it into a single written artifact the user can hold.

**User-visible promise:** After the user's third rated session — or any time they ask "Plan my next month" in Ask Noum — Noum generates a concrete 4-week practice program. Week 1 addresses the user's weakest baseline dimension; Week 2 introduces the mode that best targets their voice goal; Week 3 adds a pressure escalation; Week 4 is a mock run for their Big Moment (if set) or a consolidation week. The plan is presented in Ask Noum as a coach-written message (not a card, not a dashboard), stored in `CoachingProfile` so every subsequent session can reference it. Each weekly rep the user completes checks off against the plan in the coach's context. This is the tangible artifact of £130/hr value: a written, named, coach-signed program.

**Architecture sketch:**
- **New — State ownership:** `Noum/ForwardPlanStore.swift` — per-account `ForwardPlan: Codable` with `weeks: [PlanWeek]` (each: `focus: CoachingPriority`, `suggestedMode: PracticeMode`, `sessionTarget: Int`, `rationale: String`), `generatedAt: Date`, `bigMomentID: UUID?` (so the plan invalidates itself when the Big Moment changes). Single plan per account; regeneration replaces.
- **New — AI service:** `Noum/ForwardPlanService.swift` — actor mirroring `AIInsightsService`'s provider plumbing. System prompt instructs the model to read the `CONTEXT` block (goal, baseline, trends, big moment, path chapter) and produce a JSON `{ weeks: [{focus, mode, sessionTarget, rationale}] }` response. Deterministic fallback when no provider: a rule-based 4-week plan derived from `TrendAnalyzer.primaryFocus` + `SpeakingStyleGoal.primaryAlignedSkillArea` + path-node gating. No template fallback that invents progress; the rule-based version is honest about being rule-based.
- **Extended — AI coach chat:** `AskNoumStore.swift` — expose `triggerPlanGeneration()` which calls `ForwardPlanService`, then injects the rendered plan as a coach turn in the thread. Render is a plain multi-paragraph coach message, not a structured card — consistent with Ask Noum's existing register.
- **Extended — Pure-function logic:** `CoachContextBuilder.userContext(...)` — add a `PLAN` section when `ForwardPlanStore.shared.activePlan` is non-nil: current week's focus + session target + how many sessions the user has done this week toward it. Model can then say "You're at 2 of 3 sessions this week — your plan says to lock in a Sudden Death rep today."
- **Extended — UI view:** `ProfileView.swift` (at project root) — add a `CoachingPlanCard` inside the Coaching Direction section below the goal ring. Shows the current week's focus + rep target + progress bar (sessions this week / target). Tap navigates to `AppDestination.askNoum` (not a new surface). Hides when no plan exists; shows "Ask Noum for your plan" prompt copy when the user has ≥3 sessions but no plan.
- **Tests:** `NoumTests/NoumTests.swift` — `ForwardPlanStoreTests` (persistence, invalidation on big-moment change, auth wipe); `ForwardPlanContextTests` (PLAN section present/absent, session-count accuracy); `CoachingPlanCardVisibilityTests` (≥3 sessions + plan → shows; no plan → shows prompt; <3 sessions → hides).

**Success criteria:**
1. After generating a plan via Ask Noum, the user sees their current week's focus + rep target on `ProfileView` without opening the chat.
2. Ask Noum reply on day 3 of week 2 references "your plan says X this week" and the specific reps completed.
3. The plan references the Big Moment for the final week when one is set (verified by inspecting `ForwardPlan.weeks[3].rationale`).

**Risk:** The AI-generated plan may be generic if the context block isn't rich enough at 3 sessions. The rule-based fallback must be honest ("based on your baseline so far") rather than presenting itself as AI insight.

**Estimated track count:** 2 parallel agents — track 1 owns `ForwardPlanStore` + `ForwardPlanService` + tests; track 2 owns `CoachContextBuilder` extension + `ProfileView` card. `AskNoumStore.swift` must go to one track (assign to track 1 since it calls the service).

---

## Milestone 3 — M21: Session Intent — What Are You Training Today?

**Hypothesis:** A human coach begins every session with "What are we working on today?" — not to fill time, but because declared intent changes behavior during the rep and sharpens the post-session verdict. Noum currently picks the drill for the user; a coach asks first.

**User-visible promise:** Before each rep in Timed and Sudden Death modes, a brief one-question intent prompt appears: "Today's focus?" with three tappable options drawn from the user's active plan week + their weakest baseline + one free-form option. The selection takes 1 tap and takes under 2 seconds. After the rep, the summary cards reference the declared intent: "You said you were training pauses — you held 3 clean pauses, up from 1.4 avg." The coach in Ask Noum can also cite it: "You came into today's rep wanting to work on pacing." This closes the loop between intention and feedback that no current Noum surface provides.

**Architecture sketch:**
- **New — State ownership:** `Noum/SessionIntentStore.swift` — lightweight per-account store with `pendingIntent: SessionIntent?` and `intentHistory: [IntentRecord]` (capped at 30, one per session). `SessionIntent: Codable` carries `focus: CoachingPriority`, `label: String` (display copy), `sessionID: UUID?` (linked post-session). Cleared after each `SessionFinalizer` run.
- **New — Pure-function logic:** `Noum/SessionIntentEngine.swift` — produces `[SessionIntent]` options from `ForwardPlanStore.activePlan?.currentWeekFocus`, `TrendAnalyzer.primaryFocus(...)`, `CoachingProfile.primaryGoal`, and a generic "Open rep" fallback. Pure function: inputs in, array out. Ensures the options feel earned, not random.
- **Extended — UI view:** `TimedPracticeView.swift` + `SuddenDeathPracticeView.swift` — add a `SessionIntentPromptView` inline overlay in the pre-rep setup phase (before the countdown). Dismiss-by-tap-outside → "Open rep" auto-selected. Single overlay component, used from both views. Reduces to hidden under `reduce_motion` — the intent question still works as plain capsule buttons.
- **Extended — State ownership:** `PracticeSession` in `SpeechRecognizerViewModel.swift` — add optional `intentFocus: CoachingPriority?` field. `SessionFinalizer` writes the active `SessionIntentStore.pendingIntent?.focus`. Existing sessions decode cleanly with `nil`.
- **Extended — Pure-function logic:** `CoachContextBuilder.userContext(...)` — when the most-recent session has `intentFocus != nil`, add one line to the `RECENT` section: `"- Intent declared: <label>."` The model sees what the user said they were training and can reference it.
- **Extended — UI view:** `WhatYouDidWellCard.swift` + `WhatToImproveCard.swift` — when `intentFocus` matches a bullet's `SkillArea`, that bullet gets a quiet intent-match chip ("You aimed for this") adjacent to its evidence row. Uses existing evidence-row pattern; no structural change to the card.
- **Tests:** `NoumTests/NoumTests.swift` — `SessionIntentEngineTests` (plan-week-first ordering, fallback to trend-focus, always includes generic option, no duplicates); `SessionIntentContextTests` (intent appears in RECENT when set, absent when nil); `IntentMatchChipTests` (chip appears on matching bullet, absent on non-matching).

**Success criteria:**
1. User taps a focus before a rep; post-rep `WhatYouDidWellCard` or `WhatToImproveCard` shows an intent-match chip on the relevant bullet.
2. `CoachContextBuilder.userContext` string includes the declared intent for Ask Noum to quote back.
3. Intent options presented are derived from the forward plan (when set) rather than generic — verified by seeding a `ForwardPlan` with a specific `currentWeekFocus` and asserting the first option matches.

**Risk:** The overlay adds pre-rep friction. It must be: one tap to dismiss, no blocking the countdown, and genuinely optional (auto-selects "Open rep" on countdown start). If user testing shows drop in rep starts, the feature should become opt-in via Settings.

**Estimated track count:** 2 parallel agents — track 1 owns `SessionIntentStore` + `SessionIntentEngine` + `PracticeSession` field + context extension + tests; track 2 owns the UI overlay in `TimedPracticeView` + `SuddenDeathPracticeView` + intent-match chips in the summary cards. `SummaryView.swift` is a collision-zone file — it must be owned by exactly one agent; assign to track 2. `TimedPracticeView.swift` and `SuddenDeathPracticeView.swift` are not collision-zone files individually but must each be single-agent.

---

## Milestone 4 — M22: Longitudinal Coaching Review — Monthly Coach Letter

**Hypothesis:** A human coach sends a written summary at the end of each month: what you improved, what's still blocking you, and what the next 30 days should look like. This artifact is what creates the feeling of a coach who "has been watching" — not just responding to the last rep.

**User-visible promise:** On the first app open after the 28th day of each month, or on explicit request via Ask Noum, Noum generates a coach letter. It arrives in the Ask Noum thread, written in the user's coach voice. It opens with a one-sentence verdict on the month. It names one thing that genuinely changed (with a number: "Your filler rate dropped from 6.2 to 3.8 per minute across 12 sessions"). It names one thing still blocking progress. It closes with the suggested focus for the coming month. The letter is stored in `CoachingProfile`; the user can scroll back to it in the Ask Noum thread. Old letters persist — a user opening Noum after 3 months can read their monthly letter from month 1 and see how the coach's read has evolved.

**Architecture sketch:**
- **New — State ownership:** `Noum/CoachLetterStore.swift` — per-account store with `letters: [CoachLetter]` (each: `month: String` in `"YYYY-MM"` format, `content: String`, `voice: SpeakingStyleGoal`, `generatedAt: Date`, `injectedMessageID: UUID?`). Bounded at 24 letters (2 years). Persist to UserDefaults keyed `coachLetter.archive.<accountID>`. Auth deletion wipes.
- **New — AI service:** `Noum/CoachLetterService.swift` — actor. Generates the letter by passing the full `userContext` block + a 30-day session window (not just the last 3 sessions) + the user's current forward plan + big moment status. System prompt demands: one verdict sentence, one named improvement with a number, one persistent blocker, one 30-day focus. Deterministic fallback when no provider: a rule-based letter using `TrendAnalyzer` + `BaselineEngine.topStrengths` + `BaselineEngine.persistentBlockers` + honest "based on your data" framing.
- **Extended — AI coach chat:** `AskNoumStore.swift` — `injectCoachLetter(content:)` method that prepends the letter as a coach turn with a `CoachLetter` metadata tag (so it renders with a distinct `CoachLetterBubble` style, not just a plain chat bubble — visually distinguishable as a formal review).
- **Extended — UI view:** `AskNoumView.swift` — `CoachLetterBubble` variant: same left-aligned white card as standard coach turns but with a `"MONTHLY REVIEW · <Month>"` eyebrow label in micro uppercase + a subtle brand-blue left border rule. Distinguishes the formal review from a conversational reply without introducing a new screen.
- **Extended — Notification:** `NotificationManager.swift` — one new surface: `scheduleMonthlyCoachLetter` fires on the 1st of each month, lock-screen copy: "Your coach has written your monthly review." Opt-in via Settings toggle.
- **Tests:** `NoumTests/NoumTests.swift` — `CoachLetterStoreTests` (persistence, 24-letter cap, per-account isolation, auth wipe); `CoachLetterServiceFallbackTests` (deterministic path produces non-empty letter, all three required sections present); `CoachLetterContextTests` (letter includes improvement number from 30-day window, matches `BaselineEngine` output for the window).

**Success criteria:**
1. After 28+ days of use with ≥5 sessions, the coach letter is generated and appears in the Ask Noum thread with the `CoachLetterBubble` eyebrow on first open of a new month.
2. The letter's improvement number (e.g. filler rate change) is derivable from `sessions.filter { month-in-window }.map(\.fillerWordCount)` — it cites real data, not invented.
3. A second letter generated 30 days later appears below the first in the thread, giving the user a scrollable history of their coaching arc.

**Risk:** If the user only has 3–5 sessions in a month, the letter may over-claim. The service must gate on "insufficient data" honestly — the deterministic fallback should say "Not enough reps this month for a full read; here's what I can see" rather than fabricate a verdict.

**Estimated track count:** 2 parallel agents — track 1 owns `CoachLetterStore` + `CoachLetterService` + notification surface + tests; track 2 owns `AskNoumView` `CoachLetterBubble` variant + `AskNoumStore.injectCoachLetter`. `AskNoumView.swift` and `AskNoumStore.swift` are non-collision-zone files but must be single-agent (assign to track 2).

---

## Milestone 5 — M23: Situational Preparation Mode — Coach Me for My Moment

**Hypothesis:** A human coach's highest-value session is the one right before the high-stakes moment — a mock interview, a presentation rehearsal, a difficult-conversation simulation. Noum has all the practice infrastructure (IM mode, Sudden Death, Timed) but no surface that assembles them into a named "preparation session" for a specific real-world event.

**User-visible promise:** When the user has a `BigMoment` set and it's within 14 days, a new entry point appears on the home `HomeCoachCard`: "Prepare for your <title>." Tapping it opens a `PrepSessionView` — a new screen that frames the upcoming practice as a rehearsal, not a generic rep. The coach names the scenario ("You have a board pitch in 9 days. Here is your warm-up sequence:"), then queues a short multi-mode session: a 2-minute Timed rep on the user's weakest dimension, then a Sudden Death round at medium pressure to build composure, then an IM round with the AI playing a sceptical audience member asking questions the user might face. At the end, the summary carries a `PrepSessionSummary` variant: "Ready-signal check — here is where you stand today with 9 days left." The AI cites concrete numbers ("Your filler rate was 2.1 in today's warm-up vs your 3.8 average — that's composure under pressure") and gives one named drill to do each of the remaining days.

**Architecture sketch:**
- **New — Pure-function logic:** `Noum/PrepSessionPlanner.swift` — pure function: `plan(bigMoment:baseline:voice:daysRemaining:) -> PrepSessionPlan`. `PrepSessionPlan` is a struct: `warmingRep: (PracticeMode, PracticeDifficulty)`, `pressureRound: (PracticeMode, PracticeDifficulty)`, `imScenario: IMScenarioConfig`, `introductionCopy: String`. No AI in the planner — it is a deterministic rules engine. The IM scenario config seeds `IMPracticeView` with a sceptical-audience persona and 2–3 adversarial starter prompts derived from `BigMomentCategory` (board pitch → finance/strategy questions, interview → behavioural questions, public speaking → "why this topic?" probes). This pure-function layer is the one place to add category-specific scenario intelligence without touching the core IM engine.
- **New — UI view:** `Noum/PrepSessionView.swift` — orchestrates the three-rep sequence. Uses existing `TimedPracticeView`, `SuddenDeathPracticeView`, and `IMPracticeView` via `NavigationStack` pushes — no new practice engines. Shows the coach intro on a `PrepSessionIntroCard` (brand-purple, coach voice, countdown to moment), then launches reps in sequence. Between reps, a brief inter-rep card ("Rep 1 done. Filler count: 2. Moving to pressure round.") — single SwiftUI view, no animation complexity.
- **New — UI view:** `Noum/PrepSessionSummaryCard.swift` — rendered at the end of `SummaryView` when `session.isPrepSession == true`. Shows "Ready-signal" readout: green/amber/red on three dimensions (fillers, composure/sudden-death result, IM fluency). Coach copy frames it as a snapshot, not a verdict ("This is where you stand today — 9 days of deliberate reps still to come").
- **Extended — State ownership:** `PracticeSession` — add `isPrepSession: Bool = false` and `bigMomentID: UUID?`. `SessionFinalizer` writes these from the active `BigMomentStore` state.
- **Extended — UI view:** `HomeCoachCard.swift` — add `prepSessionCTA` variant when `BigMomentStore.activeMoment` is non-nil and `daysUntil <= 14`. Shares the existing CTA button pattern; navigates to `AppDestination.prepSession`. Single-track: `ContentView.swift` owns the `AppDestination.prepSession` case (collision zone).
- **Extended — Navigation:** `ContentView.swift` + `PracticeSupport.swift` — `AppDestination.prepSession` case; destination switch routes to `PrepSessionView`. Single agent owns both files.
- **Tests:** `NoumTests/NoumTests.swift` — `PrepSessionPlannerTests` (correct mode sequence, IM scenario seeds from `BigMomentCategory`, plan changes with remaining days, pure-function — no I/O); `PrepSessionSummaryCardTests` (ready-signal copy at high/medium/low filler count, `isPrepSession` gate, 9-days copy vs 2-days copy shift).

**Success criteria:**
1. User with a `BigMoment` set to 9 days away sees the "Prepare for your <title>" CTA on `HomeCoachCard`; tapping opens `PrepSessionView` with an intro card naming the moment and days remaining.
2. The three-rep sequence completes end-to-end: Timed → Sudden Death → IM, each using existing practice engines with no new speech-recognition or scoring code.
3. Post-session `PrepSessionSummaryCard` shows a ready-signal readout with a number from today's session and a comparison to the user's baseline average.

**Risk:** `PrepSessionView` orchestrating three existing practice modes via `NavigationStack` pushes is the highest-structural-risk piece in M19–M23. The existing modes were not designed to be composed — each manages its own `SpeechRecognizerViewModel` instance and session lifecycle. A `PrepSessionCoordinator` pattern (delegating each mode's session finalization to the coordinator) may be necessary to stitch results into a single `PrepSession` outcome rather than three independent sessions. This must be prototyped before implementation, and `TimedPracticeView` / `SuddenDeathPracticeView` / `IMPracticeView` are not collision-zone files but each must be single-agent for this milestone.

**Estimated track count:** 2 parallel agents — track 1 owns `PrepSessionPlanner` + `PrepSessionView` + `PrepSessionSummaryCard` + `PracticeSession` field extension + tests; track 2 owns `HomeCoachCard` CTA + `ContentView.swift` destination + `PracticeSupport.swift` `AppDestination` case. Track 2 is intentionally small (collision-zone files only) to keep the single-agent constraint.

---

## Sequencing recommendation

M19 (Big Moment Intake) must land before M21 (Session Intent) and M23 (Situational Preparation) because both of those milestones read from `BigMomentStore` — M21 to optionally surface the upcoming moment in the intent prompt, M23 as its primary trigger. M20 (Forward Plan) can begin in parallel with M19 because it reads from `CoachingProfile` (already exists) and `TrendAnalyzer` (already exists); it does not depend on `BigMomentStore` directly, though the plan is richer when a `BigMoment` is set. The recommended sequence is therefore: M19 and M20 in parallel (they do not share any file in the collision zone); M21 after M19 completes (reads `BigMomentStore` and `ForwardPlanStore`); M22 after M20 completes (reads `ForwardPlanStore` for letter generation, though the letter works without a plan); M23 after both M19 and M21 are merged (depends on `BigMomentStore` for the CTA gate and on `SessionIntentStore` to inform the prep-session planner's warm-up selection).

M22 (Monthly Coach Letter) is the most independent of the five — it reads only from existing `PracticeSessionStore`, `BaselineStore`, `TrendAnalyzer`, and `CoachContextBuilder` (extended in M19–M21). It can be run in parallel with M21 if orchestration bandwidth exists. The one sequencing constraint: M22's `CoachLetterService` benefits from the `BIG MOMENT` context section that M19 adds to `CoachContextBuilder.userContext` — without M19, the letter simply omits the big-moment line. This is graceful degradation, not a hard dependency.

---

## Anti-goals respected

- **Not a dashboard of vanity metrics.** No milestone introduces a new metrics screen. M22's coach letter arrives in the Ask Noum thread (a conversational surface, not a graph surface); M23's ready-signal is a card inside the existing `SummaryView` chain, not a new tab. The user sees progress through coaching language, not a KPI panel.
- **Not a streak-and-badge addiction loop.** None of the five milestones awards a badge, an achievement unlock, or a streak for completing a prep session or declaring an intent. M21's session intent chip on the summary card is an informational match signal ("You aimed for this"), not a reward. M20's forward plan tracks sessions-toward-target as a quiet `ProfileView` progress bar, not a claim-and-celebrate moment. The fire-on-upward-only invariant from `LeagueManager` and `PathProgressManager` is respected throughout.
- **Not a hearts-and-lives gating game.** M23's `PrepSessionView` does not gate practice behind completing all three reps. If the user exits after rep 1, the single completed session is finalized normally. No session is ever blocked.
- **Not a generic AI chat wrapper.** M20's forward plan and M22's coach letter are both grounded in the user's actual baseline numbers, trend directions, and named big moment. The deterministic fallbacks (both milestones have them) are explicitly honest about being rule-based when no AI provider is configured — they never present template copy as AI insight. The anti-fabrication rules from `CoachContextBuilder` apply to every new context section added in M19–M21.
- **Not a leaderboard that publishes what the user said.** None of the five milestones touches the `LeagueManager`, `PublicProfileSnapshot`, or `profiles_public` Firestore collection. `BigMoment.title` is user-authored text and is explicitly excluded from lock-screen notifications (the notification surfaces the category, not the title) and from any `PublicProfileSnapshot` field.
