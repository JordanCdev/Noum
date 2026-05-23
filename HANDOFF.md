# HANDOFF — M20 Forward Plan: 4-week coach-written program

## Scope

M19 (Big Moment Intake) shipped end-to-end on this branch last session
(`4d82c8c` + `025b546` + `e7f12b2`). The M19 strategy doc
(`docs/M19_strategy.md`) named M20 — Forward Plan — as the next
implementation track, recommended to run in parallel with M19 since
they share no collision-zone files. M19 is locked; this push lands
M20.

User brief: "continue from the existing TO-DO, ensure working towards
getting app towards the vision plan, and all-round A+, make my dream
come true too, ensure working on the redesign branch." Translation:
ship the next milestone the strategy doc named (M20), against the
vision pillars (personalized coaching + believable progress), on
the `Redesign` branch.

## What shipped

The £130/hr coach handoff artifact lands in Noum: a written four-week
program tied to the user's actual baseline + voice goal + Big Moment
(when set). It persists per-account, renders as a coach turn in the
Ask Noum thread, surfaces a live progress card on Profile, and feeds
the AI coach's context block so every reply can quote the current
week's focus.

### Move 1 — `Noum/ForwardPlanStore.swift` (NEW)

Per-account UserDefaults store keyed `forwardPlan.<accountID>`,
MainActor singleton, mirrors the BigMomentStore lifecycle pattern
(`replace(_:)` / `clearPlan()` / `reloadForCurrentAccount()` /
`endSession()` / `deleteAllData(for:)`). Carries the `ForwardPlan`
value type — `id` + exactly-4 `weeks: [PlanWeek]` + `generatedAt` +
`bigMomentID: UUID?` (for stale detection) + `voiceAtGeneration:
SpeakingStyleGoal?` + `isAIBacked: Bool` (honest provenance).

Pure-function helpers on the model (`currentWeekIndex(now:calendar:)`
clamps 1...4, `currentWeek(now:calendar:)`, `dateRange(forWeek:
calendar:)` half-open seven-day windows, `isInvalidated(by:)`) let
every consumer compute the same view of the plan without UI
threading. `ForwardPlanProgress.currentWeekProgress(plan:sessions:
now:calendar:)` is the single source of truth for completed-vs-target
counts so the Profile card and the PLAN context section never drift.

### Move 2 — `Noum/ForwardPlanService.swift` (NEW)

Actor wrapping the same OpenAI / DeepSeek / Gemini plumbing as
`AIInsightsService`. JSON-strict response shape
(`{"weeks":[{"weekIndex":1,"focus":"...","mode":"...",
"sessionTarget":N,"rationale":"..."}, ...]}`); validates exactly 4
weeks with indices 1..4, focus enum-matched, mode enum-matched,
target ∈ 2...5, rationale ≤ 240 chars. Falls back to the
deterministic rule-based path on every cold path (no provider,
non-English locale, network error, parse failure, count mismatch) so
the caller never has to handle nil.

Deterministic path (`nonisolated static func deterministicPlan(input:)`
— exposed for tests):

- **Week 1** picks the weakest skill area: high-confidence declining
  trend first (urgent signal), then weak-stable trend (persistent
  problem), then baseline thresholds (filler rate ≥ 3.0, pace ≥ 165,
  pause rate < 1.0, structure quality < 1.8), then `.structure`
  fallback. Mode is the canonical drill for that area
  (`fillerReduction` → ahCounter, structure → timed, confidence →
  suddenDeath, vocalEmphasis → imConversation).
- **Week 2** moves toward the user's voice goal via
  `SpeakingStyleGoal.primaryAlignedSkillArea`. Mode is the
  voice-best mode (authoritative/executive → suddenDeath, warm/
  storytelling → imConversation, concise/persuasive → timed).
- **Week 3** is always suddenDeath (pressure escalation). Focus
  defaults to `.confidence`; if Week 1 already drilled
  fillerReduction, Week 3 sticks with `.confidence` to avoid stacking.
  Otherwise focus is `.fillerReduction` so the user gets a real
  pressure test on the most common breakdown axis.
- **Week 4** mocks the Big Moment when set
  (`BigMomentCategory.interview/conversation/review` → imConversation;
  presentation/publicSpeaking/other → timed). Rationale references
  days remaining ("9 days out", "Today is the day"). When no Big
  Moment: consolidation week on the user's strongest baseline
  dimension so the program closes with a confidence rep.

`sessionTarget(weeklyReps:base:)` clamps to 2...5 with a +1 for heavy
users (≥5/week) and −1 for light users (≤1/week). Honest target, not
aspirational — light users don't get a five-rep wall of failure.

### Move 3 — `Noum/ForwardPlanRenderer` (NEW, same file as service)

Pure-function helper that turns a `ForwardPlan` into the coach-voice
text the Ask Noum thread renders. Multi-paragraph shape: opening
references the Big Moment when set and is honest about provenance
("I shaped it around your last few reps" for AI, "Built from your
data without an AI pass — straight rules, no invention." for
deterministic); one paragraph per week (`"Week N — Skill Area.
Mode, N reps. Rationale."`); voice-shaped closing line catalogue
covering all 6 voices + nil.

Brand-voice contract honoured throughout: no exclamation marks
(locked by `rendererCarriesNoExclamationMarks` test across all voices
× BigMoment-or-not combinations).

### Move 4 — `Noum/ForwardPlanCoordinator` (NEW)

MainActor enum that bridges the plan-generation pipeline to the live
SwiftUI surfaces. `buildInput()` assembles `ForwardPlanInput` from
the live stores (CoachingProfile + Baseline + sessions + rating +
BigMoment + days-until + SkillTrendStore snapshots → TrendAnalyzer
trends + StreakFreezeManager + DrillHistoryStore). `generateAndAnnounce()`
calls the service, persists via `ForwardPlanStore.replace(_:)`, and
injects the rendered coach message via `AskNoumStore.injectCoachTurn(_:)`.

The "two effects" shape mirrors M19's `BigMomentStore.setMoment` +
intake-view-on-dismiss pattern: state and conversational artifact
land together so the Profile card lights up the same moment the
chat thread shows the program.

### Move 5 — `CoachContextBuilder.userContext` extended

New `forwardPlan: ForwardPlan? = nil` parameter. When non-nil, a
`PLAN` section renders:

```
PLAN
- Week N of 4 focus: <SkillArea> via <Mode>.
- Why this week: <rationale>
- Progress: M of T reps this week.
```

When the plan's `bigMomentID` no longer matches the user's active
BigMoment (or one side has cleared), a leading line is added warning
the coach that the plan is stale and recommending regeneration rather
than quoting outdated guidance:

```
- Active plan is stale — the user's big moment changed since
  generation. Recommend regenerating before quoting this plan as
  current.
```

Section ordering: GOAL → BIG MOMENT → PLAN → RATING → BASELINE →
STREAK → RECENT → PATH → TRENDS → PROOFS. PLAN sits next to BIG
MOMENT so the model reads them as one coherent block: where you're
going, when, and the program for getting there.

### Move 6 — `AskNoumStore.injectCoachTurn(_:)`

New method that appends a `.coach` row directly without a
corresponding user turn. Used by `ForwardPlanCoordinator` to drop
the rendered plan into the thread. Trims whitespace, rejects empty
text (returns nil + appends nothing — defensive against a renderer
that returns blank), and crucially does NOT set `isAwaitingReply`
since direct injects bypass the request lifecycle and must not lock
the input bar.

### Move 7 — Profile `CoachingPlanCard`

New `Noum/CoachingPlanCard.swift` carries both the resolver and the
view. Pure `CoachingPlanCardVisibility.resolve(plan:profile:sessions:
activeBigMomentID:now:calendar:)` returns a four-state enum:

- `.hidden` — no profile (silent for pre-onboarding users) OR no
  plan + fewer than 3 sessions (silent until the user has data to
  read a plan against).
- `.prompt` — ≥3 sessions, no plan yet. Renders a brand-purple-bordered
  ambient card with "A four-week coach plan, written for you." and a
  voice-shaped CTA ("Ask Noum to plan four weeks" / "Plan four weeks.
  One ask." / "Brief: plan my next four weeks." / etc., one per voice
  + nil fallback).
- `.live(plan, completed)` — plan exists AND aligns with active
  BigMomentID (or both nil). Renders current week's focus + mode
  rationale + (completed / target) progress capsule. A subtle
  "RULE-BASED" tag when `isAIBacked == false` so the surface is
  honest about provenance.
- `.stale(plan, completed)` — plan exists but BigMomentID drift
  detected. Same layout as live + an inline voice-shaped CTA pulling
  the user toward regeneration.

Tap behavior:
- `.live` / `.hidden` → opens `noum://ask` (the program lives in
  the thread; this is navigation).
- `.prompt` / `.stale` → fires `ForwardPlanCoordinator.generateAndAnnounce()`
  THEN opens `noum://ask`. The user lands inside a thread that
  already has the rendered plan as a coach turn rather than waiting
  for a network round-trip.

Card sits inside the existing `coachingDirectionCard` in
`ProfileView.swift`, below the captured reflections and above the
`askNoumProfileLink`. Quietly hides when state is `.hidden` so
non-eligible users see exactly what they did before this push.

### Move 8 — Auth wipe + reload contract

`AuthManager.deferStoreReloadForCurrentAccount` now reloads
`ForwardPlanStore.shared`; `deferStoreSessionReset` calls its
`endSession()`. `clearAllUserData(for:)` adds three keys that were
absent from the wipe list (M19 + M20 backfill):
- `forwardPlan.<accountID>` (M20)
- `bigMoment.<accountID>` (M19 — was missed)
- `bigMomentArchive.<accountID>` (M19 — was missed)

### Move 9 — Test suite

50+ new tests across 7 suites:

- **`ForwardPlanCalendarTests`** (12 tests) — week 1 on day 0/6, week 2
  on day 7, week 4 on day 21, week 4 clamp past day 42, currentWeek
  resolution, dateRange seven-day half-open, dateRange clamp on
  out-of-range index, `isInvalidated` mismatch / match / both-nil /
  cleared / added contracts.
- **`ForwardPlanProgressTests`** (5 tests) — in-week sessions counted,
  out-of-range sessions excluded, week-2 sessions counted when current,
  empty list → zero, week-7 boundary fires into week 2 (half-open
  semantics locked).
- **`ForwardPlanServiceDeterministicTests`** (20 tests) — 4-week count,
  `isAIBacked == false`, voice carrying through, declining
  high-confidence trend → week 1, baseline filler rate → week 1, voice
  goal → week 2 alignment, no-voice fallback → `.structure`, week 3 =
  suddenDeath, week 3 avoids stacking filler week, week 4 mocks
  BigMoment for each category, week 4 consolidates without BigMoment,
  `sessionTarget` clamps at floor / ceiling / steady, `modeFor` /
  `bestModeForVoice` / `mockModeFor` mappings, brand-voice exclamation
  contract across all variants, `weakestSkillArea` priority /
  `strongestSkillArea` nil-when-insufficient / strongest-finds-low-filler.
- **`ForwardPlanRendererTests`** (6 tests) — opening references
  BigMoment when set, generic when not, rule-based honesty, AI-backed
  honesty, includes all 4 weeks, voice-shaped closing + no
  exclamations across all 6 voices × BigMoment-or-not combinations.
- **`ForwardPlanContextTests`** (4 tests) — PLAN omitted when nil,
  PLAN present when set, progress count matches sessions filter, stale
  warning surfaces when BigMomentID differs.
- **`CoachingPlanCardVisibilityTests`** (9 tests) — hidden when no
  profile, hidden when <3 sessions, prompt at 3, live on match, live
  on both nil, stale on drift, stale on cleared moment, live carries
  completed count, voice-shaped CTA labels for every voice + live-state
  empty CTA contract.
- **`AskNoumStoreInjectCoachTurnTests`** (5 tests) — nil on empty /
  whitespace-only, append as non-pending coach row, doesn't set
  `isAwaitingReply`, trims leading/trailing whitespace.

## What did NOT change

- **No new screens.** The Profile card opens Ask Noum; the plan
  itself lives in the chat thread (one Coach Reply). Anti-goal
  (dashboard of vanity metrics) respected.
- **No new badges or unlocks.** Generating a plan doesn't award XP
  or fire a celebration. The plan is the artifact; the work is the
  work.
- **No streak gating.** Missing a week of the plan doesn't punish
  or shame. The progress capsule reads honest counts without
  loss-aversion copy.
- **No invented stats.** Both the AI and deterministic paths cite
  the user's actual baseline numbers. The deterministic path is
  explicit about being rule-based (`isAIBacked: false`); the
  renderer surfaces "Built from your data without an AI pass —
  straight rules, no invention." so the surface never claims AI
  intelligence it doesn't have.
- **No M21 surface yet.** Session Intent (pre-rep "what are you
  training today?") is the next track per the strategy doc.

## Risks

1. **The deterministic Week 4 only references a BigMoment when one
   is set.** Users with no BigMoment get a "consolidation" week
   that's less rich than the rehearsal shape. The fallback rationale
   is honest about being consolidation rather than fake-mocking an
   event, but a user might still feel the lift is uneven. Mitigation
   is to set a BigMoment — which the M19 intake surfaces.
2. **The PLAN context section is per-week-coarse.** If a user is on
   Day 3 of Week 2 with 2 of 3 reps done, the coach knows
   "Week 2, 2 of 3" but not which days. This is intentional — finer
   granularity would require day-bucketing the rep history, and the
   coach voice doesn't need it to be useful ("two of three this
   week" beats "two on Monday, one Wednesday gap").
3. **Stale detection is BigMomentID-only.** A baseline shift or a
   voice goal change doesn't currently mark the plan as stale. The
   first one is graceful (the plan is honest about being a snapshot
   in time); the second could be uncomfortable if a user pivots
   voices mid-program. `ForwardPlan.voiceAtGeneration` is persisted
   precisely so a future patch can add the voice-change branch to
   `isInvalidated(by:)` without a model change.
4. **`ForwardPlanCoordinator.buildInput()` reads live stores on the
   main actor.** A massive `PracticeSessionStore.sessions` array
   gets copied into the input snapshot. The deterministic path
   doesn't iterate sessions deeply (uses `.prefix(5)` for the AI
   user prompt), but a future memory-conscious refactor could pass
   a slice rather than the full array.

## Verification

### Implemented (compiler-locked, source-only)

- `ForwardPlan` calendar projection (12 tests in `ForwardPlanCalendarTests`)
- `ForwardPlanProgress` session bucketing (5 tests in `ForwardPlanProgressTests`)
- Deterministic plan generation invariants (20 tests in
  `ForwardPlanServiceDeterministicTests`)
- Renderer voice + provenance contracts (6 tests in `ForwardPlanRendererTests`)
- Context PLAN section presence + progress + stale-warning (4 tests
  in `ForwardPlanContextTests`)
- CoachingPlanCard four-state resolver + CTA voice catalogue
  (9 tests in `CoachingPlanCardVisibilityTests`)
- `AskNoumStore.injectCoachTurn` non-pending + non-awaiting contract
  (5 tests in `AskNoumStoreInjectCoachTurnTests`)

### Blocked / needs visual QA on device

Still no Swift toolchain in this container — all changes are
source-only. The Move 7 + Move 8 changes are visual and want a
build:

1. **Move 7 — Profile card visibility** — clean install, complete
   onboarding (no BigMoment), confirm the card stays hidden until
   the third rated session, then prompts.
2. **Move 7 — Plan generation end-to-end** — tap the prompt CTA;
   confirm the Ask Noum thread receives the rendered plan as a
   single coach message + the Profile card transitions to `.live`
   with the correct week + progress.
3. **Move 7 — Stale state** — generate a plan with a BigMoment set,
   then change/clear the BigMoment; confirm the Profile card flips
   to `.stale` with the regenerate CTA, and that tapping it
   regenerates against the new moment.
4. **Move 5 — Coach context** — open Ask Noum with a plan active;
   ask "What's my focus this week?"; confirm the model cites the
   current week's focus + progress (e.g. "Week 2 focus: pause
   usage. You're at 1 of 3 reps").

### Assumptions

- `Calendar.current.startOfDay(for:)` matches the user's locale
  expectations for week boundaries. The PLAN week math is in user
  local time, not UTC.
- The `ForwardPlan` Codable round-trip will tolerate older app
  versions that don't have the field — there is no older version
  yet, so this is forward-only.
- `AskNoumStore.injectCoachTurn` is safe to call from any path that
  is already on MainActor. The store is `@MainActor` so the compiler
  enforces this.
- The deterministic Week 4 mock-mode mapping (interview →
  imConversation, presentation → timed) reflects the most common
  shape per category. A user with a `.other` BigMoment gets the
  `.timed` fallback which is the most general-purpose mode.

### What was checked

- Re-read `ForwardPlan.currentWeekIndex` math against the test
  assertions; the integer division + clamp is identical across days
  0, 6, 7, 13, 21, 28, 42.
- Re-read `CoachContextBuilder.userContext` section ordering;
  confirmed PLAN sits between BIG MOMENT and RATING, matching the
  intent ("here's where you're going, here's the program for getting
  there, here's where you stand").
- Re-read `ForwardPlanService.deterministicPlan` flow; confirmed
  Week 1 → Week 2 → Week 3 → Week 4 each compose without
  cross-dependency (Week 3 reads Week 1's focus for the
  anti-stacking branch but doesn't mutate state).
- Re-read `CoachingPlanCardVisibility.resolve` against every test
  case; confirmed the resolver hits each branch with the right
  fixture.
- `grep`'d `AuthManager.clearAllUserData` to confirm the M19 +
  M20 keys are present and the existing keys weren't shifted.

## Files modified

- `Noum/ForwardPlanStore.swift` — NEW. ForwardPlan + PlanWeek +
  ForwardPlanProgress + ForwardPlanStore.
- `Noum/ForwardPlanService.swift` — NEW. AI + deterministic
  generator, all pure helpers, ForwardPlanRenderer.
- `Noum/ForwardPlanCoordinator.swift` — NEW. MainActor bridge
  between the service and the live stores.
- `Noum/CoachingPlanCard.swift` — NEW. CoachingPlanCardState +
  CoachingPlanCardVisibility resolver + CoachingPlanCard view.
- `Noum/CoachContextBuilder.swift` — `forwardPlan:` param added to
  `userContext(...)`; PLAN section emitted when non-nil.
- `Noum/AskNoumStore.swift` — `injectCoachTurn(_:)` added.
- `Noum/AskNoumView.swift` — observes `ForwardPlanStore.shared` +
  `BigMomentStore.shared`; passes both into `userContext(...)`.
- `Noum/AuthManager.swift` — reload + endSession + wipe-list
  extended for `ForwardPlanStore` and M19 BigMoment keys.
- `ProfileView.swift` — observes `forwardPlanStore` +
  `bigMomentStore`; renders `coachingPlanCard` inside the existing
  `coachingDirectionCard`.
- `NoumTests/NoumTests.swift` — 50+ tests across 7 suites appended
  end-of-file.
- `HANDOFF.md` — this file.
- `docs/CURRENT_STATE.md` — header breadcrumb for the push.

## Branch

`Redesign` — committed and pushed per the user's brief. Closes M20
of the M19-M23 personalization slate as `docs/M19_strategy.md`
recommended. M19 (Big Moment Intake) shipped last session; M20
(Forward Plan) ships this session — both can now light up the same
Profile surface and the same coach context block, which was the
"parallel tracks" design call.

The artifact a user can now hold: a written four-week program in
their own coach's voice, tied to their own baseline numbers and
their own upcoming Big Moment. That is the £130/hr coach handoff
the £0 user has never had.

## Future moves

1. **M21 — Session Intent (pre-rep "what are you training today?").**
   Reads ForwardPlanStore for the current week's focus as an intent
   option, ties post-rep `WhatYouDidWellCard` /
   `WhatToImproveCard` chips to the declared intent. Single
   forward-only dependency on this push.
2. **Voice-change stale detection.** Extend
   `ForwardPlan.isInvalidated(by:)` to also check
   `voiceAtGeneration` against the current
   `CoachingProfile.speakingStyleGoal`. Already persisted; just
   needs the branch.
3. **Plan regeneration from a Settings entry.** Currently the only
   regen path is the Profile card prompt/stale CTA. A Settings →
   "Reset coaching plan" row would give power users a clean
   regen-from-scratch path without needing a BigMoment change.
4. **`PlanWeek.completedRationale` for past weeks.** Once a week
   has passed, the rationale on display could shift from "here's
   what you should do" to "here's what you did" — a tiny
   continuity nudge that turns the program into a retrospective
   read for past weeks while staying prescriptive for the current.
   Requires bucketed session counts past Week 1.
5. **M22 — Monthly Coach Letter** is independent of M20 and can
   run in parallel with M21 per the strategy doc if bandwidth
   exists. The letter would read the `ForwardPlanStore.activePlan`
   to reference what the user committed to vs what landed.
