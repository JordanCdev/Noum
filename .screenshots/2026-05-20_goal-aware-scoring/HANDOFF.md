# Run: 2026-05-20 · branch:Redesign · M14 goal-aware delivery bonus closes the scoring edge

The last open M14 verdict-loop edge from `docs/VISION.md` ("Evaluation *scoring* (weighting goal-aligned dimensions inside `BaselineEngine`) is the remaining edge — copy is closed end-to-end") is closed. Every line of coaching copy already speaks the user's chosen voice; now the 0–10 score does too. `PracticeEvaluator.voiceDeliveryBonus` adds a small lift (≤0.6 raw, ≤1 of 10 on a borderline case) to the raw score when the *delivery profile* — fillers, pace, duration, word count — fits the user's voice goal. Restraint matches the existing copy enrichments: silent when no goal, silent when delivery doesn't fit (no double-penalty layered on top of the dimension weights). Score, copy, and drill are now goal-aware end-to-end.

## Mode
Linux blind — no simulator, no Xcode. All changes flagged for visual verification on the next local run.

## What shipped

| File | Change |
|---|---|
| `Noum/PracticeSupport.swift` | Added `PracticeEvaluator.voiceDeliveryBonus(profile:wordCount:duration:fillerCount:wordsPerMinute:)`. Wired into all three scoring paths: `evaluateTimedPractice`, `evaluateSuddenDeathPractice`, `evaluateAhCounterPractice`. The bonus is added to the existing `rawScore` expression alongside `styleAlignment` — they're orthogonal signals (`styleAlignment` reads word choice, `voiceDeliveryBonus` reads delivery). |
| `NoumTests/NoumTests.swift` | Eleven new `VoiceDeliveryBonusTests` cases lock the restraint contract on all six voices — bonus fires only when delivery fits, returns 0 with no profile, returns 0 on trivial / mismatched delivery, caps at 0.6 raw. |
| `docs/VISION.md` | The "underweight" paragraph now reflects that scoring is closed end-to-end. Score, copy, and drill are all goal-aware. |
| `docs/CURRENT_STATE.md` | Header trail-of-breadcrumbs updated to include "goal-aware delivery bonus closes the scoring edge — score, copy, and drill are all goal-aware end-to-end". |

## API addition

```swift
// New `internal` helper (accessible to tests via `@testable import Noum`).
static func voiceDeliveryBonus(
    profile: CoachingProfile?,
    wordCount: Int,
    duration: TimeInterval,
    fillerCount: Int,
    wordsPerMinute: Double
) -> Double
```

Returns 0.0–0.6 (`.concise`) or 0.0–0.5 (other voices).

## Voice deltas (each mirrors `SpeakingStyleGoal.alignedSkillAreas`)

| Voice | Lift fires when… | Caps at |
|---|---|---|
| `.concise` | fillerCount ≤ 1, duration ≤ 35s + wordCount ≥ 15, pace in 110–145 WPM | 0.6 |
| `.warm` | pace in 125–155 WPM, wordCount ≥ 30 | 0.5 |
| `.authoritative` | fillerCount == 0, duration ≥ 25s | 0.5 |
| `.persuasive` | wordCount ≥ 40, duration ≥ 30s | 0.5 |
| `.executive` | fillerCount == 0, pace in 115–150 WPM | 0.5 |
| `.storytelling` | duration ≥ 35s, wordCount ≥ 50 | 0.5 |

Each delta uses a 0.3 / 0.2 split (cap 0.5–0.6). The two halves are independent — a partial match (one condition out of two) still earns half the bonus, so the signal degrades gracefully instead of going binary.

## Restraint contract (locked by tests)

- No profile / no goal → 0. Voice-blind path is unchanged.
- Profile set, delivery doesn't fit the voice → 0. The existing dimension weights already penalise misses; layering a second penalty here would double-hit the user.
- Trivial delivery (`wordCount < 8` or `duration < 8`) → 0. Same restraint as the existing styleAlignment path — a 5-word stub shouldn't move the score.
- Bonus is bounded at 0.6 raw, so a borderline final score lifts by at most 1 point. No mid-stream shock.

## Surfaces needing visual verification

The bonus lands invisibly inside the score. To eyeball the change, run a session in each of these conditions and compare against the pre-change behavior:

1. **TimedPracticeView → SummaryView, `concise` voice goal, ~25s of tight clean delivery (≤45 words, 0 fillers, ~125 WPM).**
   Expected: Score is 1 point higher than the same delivery would have scored before this change (e.g. a borderline 7 lifts to 8). All other surfaces unchanged.

2. **TimedPracticeView → SummaryView, `concise` voice goal, ~70s of rambling delivery (>150 words, 6 fillers, 175 WPM).**
   Expected: Score is unchanged from pre-bonus behaviour. The bonus stays silent on mismatched delivery — restraint test. This is the "no fake personalization" guarantee at the score layer.

3. **TimedPracticeView → SummaryView, no goal set (anonymous user / onboarding skipped).**
   Expected: Score is unchanged from pre-bonus behaviour. Voice-blind path is preserved.

4. **SuddenDeathPracticeView → SummaryView, `authoritative` voice goal, zero-filler 40s run.**
   Expected: Score is 1 point higher than the same run would have scored before. Sudden Death already rewards zero-filler runs heavily, so the lift is most visible on borderline cases.

The four conditions cover every code path; if all four render correctly, the restraint contract is verified visually.

## VISION gap closing (estimate)

The M14 "goal-aware loop" was tracked as closed across every *copy* surface (pre-rep banner, mid-rep HUD, momentum line, profile ring, home chip, looking-ahead chip, leverage line, next-step line, drill rationale). The previous handoff flagged scoring weighting as the single remaining open edge. This change closes it.

Every layer that touches the user's session — score, copy, drill picker, drill rationale, in-session HUD, home recommendation — now reads the voice goal when there's real signal and stays neutral when there isn't.

Operational M14 work (Firestore rules deploy, hosted privacy URL, TestFlight build) is still pending and requires Mac / cloud creds — none possible from Linux blind.

## Branch + commit SHA

Branch: `Redesign`
Commit SHA: will be set on push.

## Risks

- Score uplift is small (≤ 1 point on a borderline rounding case) and one-sided (no penalty). Mid-stream impact on existing users: a small subset will see a 1-point uplift on goal-fit sessions starting today. No score will *decrease* relative to the previous formula.
- The pace bands and word-count thresholds in each voice match the existing WPM bands documented in `WPMEvaluator.swift` (Timed 130–160, Sudden Death 140–170, IM 100–135) and the content-cap behaviour in `evaluateTimedPractice`. They are intentionally narrow so the bonus fires on real fits, not aspirational averages.
- No backend / persistence changes. Pure score-formula logic. The bonus is recomputed on every evaluator call.
