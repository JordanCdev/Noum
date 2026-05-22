# M19 Strategy — From Pattern-Matching Coach to Coach Who Knows You

_Integrated synthesis of 3 parallel research tracks. 2026-05-22. Branch `Redesign`._

---

## TL;DR

Jordan's product thesis: **make £130/hr communication coaching accessible to the 99% priced out of it.** Three independent research tracks (`m19-audit` on data flow, `m19-coach` on human-coach workflow, `m19-plan` on milestone proposal) ran in isolation today and produced striking convergence on **one foundational gap and one obvious next move**:

1. **Noum captures rich data but doesn't capture the one thing a human coach asks first: what specific high-stakes moment are you preparing for?** No `BigMoment` data exists today. Every other personalization gap downstream depends on this.
2. **The persistent AI coach (Ask Noum) is starved of the trends + dormant intake fields Noum already has.** `TrendAnalyzer` knows the user's filler rate has been declining for 3 weeks — `CoachContextBuilder` never tells the coach. `successVision` is the user's own words about why this matters — the coach never sees them. 4 of 11 intake fields are fully dormant.

**The M19-M23 roadmap below addresses both.** It also surfaces a real strength worth preserving: **Noum's drill prescription (Phase 4 in a coach engagement) is genuinely strong** — `TrendAnalyzer.primaryFocus` + `RecommendationBiasEngine` + the mode differentiation are the load-bearing pieces of the coach-grade promise. We're not rebuilding; we're closing the surrounding gaps.

**Shipped this session** (already on `Redesign`):
- M18 Sudden Death rework (mechanic + arcade result screen) — `dd3489f` + `7434b7c`
- M19 crash + prompt-cutoff hardening — `8bff781`
- 3 research docs as committed artifacts — `1febd77`, `594def0`, `4eec8e8`

---

## Cross-track convergence (what all 3 tracks independently agreed on)

The two strongest signals — both surfaced by ≥2 of the 3 tracks reasoning in isolation:

### Convergence 1 — Big Moment is the universal gap

| Track | How it surfaced |
| --- | --- |
| `m19-audit` | Gap #1 in "data that doesn't exist": no upcoming event capture |
| `m19-coach` | Gap #1 in highest-leverage closures: chains Phase 1 (intake) → Phase 7 (capstone) — every phase references it |
| `m19-plan` | Milestone 1 (M19) and trigger for Milestone 5 (M23) |

This is not a coincidence — three different framings of the problem all land here. **M19 should be the Big Moment intake.**

### Convergence 2 — Adaptation is silent / TrendAnalyzer never reaches the coach

| Track | How it surfaced |
| --- | --- |
| `m19-audit` | "TrendAnalyzer direction outputs never reach CoachContextBuilder — the coach cannot say 'your filler rate has been declining for 3 weeks'" |
| `m19-coach` | Phase 6 gap: TrendAnalyzer shifts focus silently; user experiences it as the coach changing its mind without explanation |
| `m19-plan` | Implicit in M20 (forward plan needs trend context) and M22 (monthly letter needs longitudinal numbers) |

**This is the lowest-cost / highest-trust fix in the whole slate.** ~20 lines of conditional copy in `AIWeeklyInsightCard` + one new `UserDefaults` key for the prior focus.

### Worth preserving — Phase 4 (Drill Prescription) is genuinely strong

`m19-coach` explicitly called this out as the place Noum already delivers coach-grade quality. `TrendAnalyzer.primaryFocus` + `RecommendationBiasEngine` + per-mode differentiation cover this phase well. Future milestones should **extend** this surface, not rebuild it.

### Honest weakness — the AI coach is structurally generic until the context block expands

The Ask Noum coach reads the `userContext` block in `CoachContextBuilder`. The audit found that the block today **excludes**: `speakingContext`, `biggestChallenge`, `confidenceLevel`, `desiredOutcome`, `styleReference`, `successVision`, trend direction outputs, mode mastery, recommendation outcomes, word choice trends, eloquence/grammar history, prompt theme engagement, upcoming event (doesn't exist), within-session decay (doesn't exist).

Every "the coach feels generic" reply Jordan has seen is rooted here. **A context-expansion pass is its own deferrable mini-milestone (a "M19.5 / M20.5") and may be the right first track of M20** — pure refactor, no new UI, demonstrable AI quality lift.

---

## Proposed M19-M23 slate (refined from `m19-plan`, validated against the audit + coach map)

This is the integrated roadmap. Each milestone has an architecture sketch in [`docs/M19_proposed_milestones.md`](M19_proposed_milestones.md) — only the headlines + the cross-track validation appear here.

### M19 — Big Moment Intake _(do first)_
- **What ships**: new `BigMomentStore` + `BigMomentIntakeView` + `BigMoment` field on `CoachingProfile` + `BIG MOMENT` section in `CoachContextBuilder.userContext` + countdown copy in `HomeCoachCard` + T-7/T-1 notifications
- **Why first**: every other milestone in this slate either reads from `BigMomentStore` (M21 intent, M23 prep mode) or is degraded without it (M20 plan, M22 letter, M21 intent)
- **Cross-track validation**: ✅ all 3 tracks independently identified this as the foundational gap
- **Parallelism**: 2 agents (state+UI; context+notification)

### M20 — Forward Plan _(coach writes a 4-week program)_
- **What ships**: `ForwardPlanStore` + `ForwardPlanService` (AI generation + deterministic fallback) + `PLAN` section in `CoachContextBuilder.userContext` + `CoachingPlanCard` on Profile
- **Why this milestone**: `m19-coach` Phase 3 gap (plan is invisible); `m19-audit` confirms that the user's own goal (`paraphrasedGoal`) reaches the coach but there's no forward-looking artifact tying it to upcoming reps
- **Quiet first sub-track**: **context-block expansion** — fold the dormant intake fields (`successVision`, `biggestChallenge`, `confidenceLevel` derived from session history, `desiredOutcome`) into `CoachContextBuilder.userContext`. Pure refactor, immediately lifts AI coach quality, ships before the plan service
- **Parallelism**: 2 agents (store+service; context+ProfileView card)

### M21 — Session Intent _(what are you training today?)_
- **What ships**: `SessionIntentStore` + `SessionIntentEngine` (derives options from forward plan / trend focus / goal) + pre-rep overlay in Timed + Sudden Death + intent-match chips on `WhatYouDidWellCard` / `WhatToImproveCard` + `intentFocus` field on `PracticeSession`
- **Why this milestone**: `m19-coach` Phase 5 gap (check-in is one-directional — coach narrates without asking the user to bring something). Reading the user's declared intent and quoting it back post-rep closes the loop that no current Noum surface provides.
- **Cross-track validation**: only `m19-plan` proposed this explicitly, but `m19-coach` + `m19-audit` both flagged "user rep sentiment / subjective signal" as gap material — this is the structured form of that signal.
- **Risk**: adds pre-rep friction. Strict UX contract: 1 tap to dismiss, never blocks countdown, auto-selects "Open rep". If usage drops, gate behind Settings.
- **Parallelism**: 2 agents (state+engine+context; UI overlay+match chips)

### M22 — Monthly Coach Letter _(longitudinal review)_
- **What ships**: `CoachLetterStore` (24-letter cap) + `CoachLetterService` (AI + deterministic fallback) + `CoachLetterBubble` variant in `AskNoumView` + monthly notification
- **Why this milestone**: `m19-coach` Phase 5 + Phase 6 gaps — the weekly insight is passive; the user never receives a written artifact that says "here is your read after 30 days." This is the felt-value moment.
- **Cross-track validation**: `m19-audit`'s "trend direction never reaches coach" gap is partly closed by this — the letter is the canonical surface for trend narration.
- **Risk**: low-session-count users (≤5 reps in a month). The deterministic fallback must explicitly say "Not enough reps this month for a full read" rather than fabricate a verdict (anti-goal: fake certainty).
- **Parallelism**: 2 agents (store+service+notification; AskNoumView bubble variant)
- **Sequence note**: most independent of the 5 — can run truly in parallel with M21 if bandwidth exists.

### M23 — Situational Preparation Mode _(coach me for my moment)_
- **What ships**: `PrepSessionPlanner` (pure-function 3-rep sequencer) + `PrepSessionView` (orchestrates existing Timed/Sudden Death/IM via NavigationStack) + `PrepSessionSummaryCard` (ready-signal readout) + `HomeCoachCard` CTA when `BigMoment.daysUntil <= 14`
- **Why last**: depends on M19 (BigMomentStore) and ideally M21 (SessionIntent informs the warm-up rep selection). Also the highest-risk piece of the slate — chaining three practice modes that weren't designed to compose.
- **Cross-track validation**: `m19-coach` Phase 7 (capstone) gap directly maps here. `m19-plan` Milestone 5 is the architectural sketch.
- **Risk**: each existing practice mode owns its own `SpeechRecognizerViewModel` + session lifecycle. A `PrepSessionCoordinator` may be necessary to stitch outcomes into one `PrepSession` record. **Prototype before full build.**
- **Parallelism**: 2 agents (planner+view+summary card; HomeCard CTA + ContentView/PracticeSupport destination)

---

## Sequencing

```
M19 (Big Moment) ─────┬──→ M21 (Session Intent) ──┐
                      │                            ├──→ M23 (Prep Mode)
                      └──→ M22 (Monthly Letter) ───┘
M20 (Forward Plan) ────────────────────────────────┘  (parallel with M19)
```

- **M19 + M20 in parallel** — no collision-zone overlap (M19 owns `BigMomentStore` + intake UI + `HomeCoachCard` subtitle; M20 owns `ForwardPlanStore` + service + Profile card). Both touch `CoachContextBuilder.userContext` — single-agent ownership of that file per session; alternate.
- **M21 after M19** — reads `BigMomentStore` directly for intent option priority
- **M22 in parallel with M21** if bandwidth exists — strictly independent
- **M23 last** — depends on M19 + M21 + the prep-coordinator prototype

---

## Anti-goal check (from `docs/VISION.md`)

Each milestone explicitly avoids:

| Anti-goal | How M19-M23 stays clear |
| --- | --- |
| Shallow gamification | No new badges, no streaks-for-intent, no "complete 3 prep sessions for a reward". Path's fire-on-upward-only invariant respected throughout. |
| Fake AI features | M20 + M22 both have **deterministic fallbacks** that are explicit about being rule-based. No template copy presented as AI insight. |
| Dashboard / vanity metrics | M22's letter arrives in Ask Noum thread (conversational), not a metrics panel. M23's ready-signal is a card inside `SummaryView`, not a new tab. |
| Streak shame / hearts-and-lives | M23's PrepSessionView does NOT block on completing all 3 reps — partial completion finalizes normally. M21's intent prompt auto-selects "Open rep" on dismiss. |
| Leaderboards that expose user-authored text | `BigMoment.title` is explicitly excluded from lock-screen notifications (T-7 notification surfaces category only) and from `PublicProfileSnapshot`. |

---

## What landed RIGHT NOW (M19 hardening, this session)

Cherry-picked onto `Redesign`, build green, ready to smoke:

- **SpeechRecognizer crash guard** — `installTap` now refuses 0-channel inputFormat with a typed error instead of crashing in NSException. Audio session options include `.allowBluetooth` (required for valid sim input format after `.playback` → `.playAndRecord` transition).
- **Sudden Death prompt cutoff fix** — cloud TTS path now estimates readout duration from word count (0.55s/word + overhead) and waits before transitioning phase. NPC card collapsed line limit bumped 2→3 as gating-failure safety net.
- **3 committed research docs** — `docs/M19_audit_personalization.md`, `docs/M19_audit_coach_workflow.md`, `docs/M19_proposed_milestones.md`

5 commits ahead of origin:
```
[strategy doc — about to commit]
4eec8e8 M19 research — M19-M23 milestone proposal
594def0 M19 research — £130/hr coach workflow map
1febd77 M19 research — personalization data audit
8bff781 M19 fix — SpeechRecognizer crash + prompt cutoff
```

---

## Decision Jordan needs to make next

1. **Read the 3 source docs** if you want deeper detail than the synthesis above. The audit doc has every file:line ref; the coach map has the per-phase verdict; the milestone doc has the per-milestone architecture sketch.
2. **Confirm or amend the M19-M23 slate.** Push back on any milestone that doesn't feel right; the research is decision-grade but you own the product call.
3. **Approve M19 (Big Moment Intake) as the next implementation track** — the convergence signal is strong enough that I recommend starting here without further research.
4. **Push or hold** — `Redesign` is 5 commits ahead of `origin/Redesign`. Saying "push" sends them all.

I will not implement M19 or push without explicit go-ahead.
