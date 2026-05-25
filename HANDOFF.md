# HANDOFF — M24 deferred slate (round 8): per-scenario tone-drill recommendation (diagnose → prescribe)

## Scope

Round 7 (commit `4169a8e`) closed two more "Future moves" (per-scenario
trust/tension trend chips on the detail header + a tone-match chip on
the History list row). It forwarded a five-item priority list. This
push takes **#1 — per-scenario drill recommendations**, the highest-
leverage remaining item, because it's the one that closes a *coaching
loop* rather than adding another read: the round-6/7 work made the
per-scenario tone-match rate visible (diagnosis); this round turns that
diagnosis into a prescription the user can act on in one tap.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

### Scoping decision (read this)

The round-7 HANDOFF deferred #1 because the natural home looked like
`RecommendationBiasEngine` in `PracticeSupport.swift`, which feeds
**seven** consumer surfaces (`PracticeModeSelectionView`, `SummaryView`,
`HomeCoachCard`, `PracticeTopics`, `ContentView`, `SummaryCards`) — a
new trigger there wants a dedicated push with recommendation-surface QA,
not a rider on a smaller change.

That risk is real, so this round lands the *same coaching outcome* on a
**self-contained surface instead**: the `IMScenarioDetailView` drill-
down. The prescription appears exactly where the user is already reading
the diagnosis (the tone-match strip), reuses the launch path the
empty-state CTA already uses (`AppDestination.imPractice(scenario:tone:)`),
and touches **no** shared engine. It closes the diagnose→prescribe loop
for the IM/tone case end-to-end without the 7-surface blast radius. The
broader `RecommendationBiasEngine` integration (surfacing the same
signal on Home / mode-selection) stays a dedicated future push — see
**Future moves**.

This is the PLAN.md §8.3 "data layer first" discipline: the decision is
a pure, fully-tested helper; the view is a thin render of it.

## What shipped

### Track 1 — Pure decision helper (data layer)

New pure helper `IMHistorySummary.toneDrillRecommendation(from:scenario:)`
in `Noum/IMHistorySummary.swift`, returning a new nested value type
`IMScenarioToneDrillRecommendation?`.

Evidence gate (mirrors VISION.md: "every recommendation must have
evidence, an observable target, and an honest evidence threshold"):

- **≥ `toneDrillMinimumReps` (3)** reps in this scenario recorded an
  `actualTone` reading — fewer can't establish a pattern, only a single
  rep, and a coach doesn't prescribe off one rep.
- **match rate < `toneDrillMatchRateCeiling` (40%)** — above that the
  user lands the tone more than they miss it, so a nudge would be
  nagging, not coaching. The ceiling is **exclusive**: exactly 40%
  (e.g. 2 of 5) returns `nil`.
- Both thresholds are `static let` constants shared with the test suite
  so the boundary is asserted, not guessed.

The rate read is the **same `toneMatchStats` value the visible strip
displays** (the helper calls into it), so the prescription and the
diagnosis it's based on can never disagree — including the two-decimal
rounding (3 of 8 → 0.38, which is `< 0.40` → recommend).

The **prescribed tone** is the tone the user *aimed for and missed most
often* in this scenario — the modal missed `targetTone`, tie-broken by
the most-recent miss (so it tracks what they're fighting right now),
with a final `rawValue` tiebreak for full determinism. It reuses the
same `matches(targetTone:actualTone:)` matcher the strip uses, so a
"miss" here means exactly what a non-matched chip means there. The coach
drills the specific gap, not a scenario default guess.

Brand-voice copy lives on the value type as pure computed properties
(testable without a view):

- `headline` — "Your <Tone> tone is the opportunity here" (frames the
  gap as the next edge, never a weakness)
- `body` — states the evidence, then prescribes one focused rep; the
  match count is rendered as a warm phrase (`haven't matched it yet` /
  `matched it once` / `matched it twice` / `matched it N times`) — data,
  not a verdict, no punish-shame
- `ctaLabel` — "Drill <Tone> tone"

### Track 2 — Coach-nudge card (view layer)

`Noum/IMScenarioDetailView.swift` gains a `toneDrillCard(_:)`, rendered
directly beneath the tone-match strip when `toneDrillRecommendation` is
non-nil (so the user reads "3 of 8 matched" → "here's the rep that
closes that"). Calm register: same mode-tinted `cardBackground` chrome
as the trace + tone cards, a "COACH NUDGE" eyebrow, `scope` glyph, and
an accent-capsule CTA identical in shape to the empty-state launch
button. The CTA pushes `AppDestination.imPractice(scenario:tone:)` with
**both** the scenario and the prescribed tone pre-filled — the user
lands in exactly the rep the coach just named, zero setup friction.
Accessibility id `history.im.scenario.toneDrillCTA`.

### Vision alignment

- **Coach-parity loop (the north star).** VISION.md defines parity as
  diagnose → formulate → prescribe → observe → adapt → transfer. The
  round-6/7 tone-match surfaces did the *diagnose*; this round adds the
  *prescribe* stage for the tone case: a reason ("matched it once across
  3 reps"), a named observable target (the specific tone), and a one-tap
  intervention. That's the exact shape the dev-instructions demand:
  "prescribe a drill for a reason, name the observable target."
- **Pillar #3 — Conversational intelligence.** "You keep aiming for Calm
  in Difficult Conversation and landing it once in three — run it again
  with Calm as the only thing to nail" is the move a £130/hr coach makes
  after pulling the history.
- **Pillar #4 — Believable progress.** The card self-hides until the
  evidence bar is met. No prescription off one rep; no nag when the user
  is already matching the tone. Honest cold-start: nothing renders.
- **Anti-goals.** No fabricated data (every number is the engine's own
  `actualTone` read through the existing matcher). No punish-shame (the
  miss count is calm data in a mode-tinted card, never a red failure
  state). No new AI surface — the decision is deterministic.

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+~95 LOC —
  `IMScenarioToneDrillRecommendation` value type with computed copy +
  `toneDrillMinimumReps` / `toneDrillMatchRateCeiling` constants +
  `toneDrillRecommendation(from:scenario:)`)
- **Modified:** `Noum/IMScenarioDetailView.swift` (+~60 LOC —
  `toneDrillRecommendation` computed wrap, `toneDrillCard(_:)`, render
  gate beneath the tone-match strip)
- **Modified:** `NoumTests/NoumTests.swift` (+~250 LOC — new
  `IMScenarioToneDrillRecommendationTests` suite, 15 cases: nil on
  empty, nil below 3 reps, nil at 40% ceiling (exclusive), nil above
  ceiling, recommends below ceiling with stats carried through, boundary
  3-of-8 rounds to 0.38 → recommends, most-missed tone is modal, tie-
  break by recency, ignores reps without `actualTone`, ignores cross-
  scenario reps (and confirms the other scenario still recommends),
  ignores non-IM modes, rate matches `toneMatchStats` exactly, copy has
  no exclamations across all match counts, copy has no punish-shame
  language, copy names the tone, match-phrase variants read naturally)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief (via the
working branch + a draft PR into `Redesign`).

The artifact a user can now hold: at any IM scenario where they've been
missing the tone they aim for (3+ reps, under 40% landed), the coach
surfaces a calm, evidence-stated nudge and a one-tap drill that drops
them into that exact scenario with the most-missed tone pre-selected —
the diagnose→prescribe loop closed for the tone case.

## Future moves

(Updated priority list — item #1 closed on a self-contained surface this
round; the engine-wide variant carried forward:)

1. **Per-scenario tone signal on `RecommendationBiasEngine`.** Now that
   `toneDrillRecommendation` is a pure, tested helper, the same signal
   could feed the *home / mode-selection* recommendation surfaces so a
   user who never opens the IM History drill-down still gets nudged
   toward their weakest scenario+tone. Still wants a dedicated push:
   `RecommendationBiasEngine.blueprint(...)` feeds seven consumers and a
   new trigger wants recommendation-surface QA, not a rider on a
   render-only change. The decision layer is now done — this is the
   wiring + QA half.
2. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
3. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor pass
   with proper visual QA.
4. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` (or expose a publisher) so the Settings AI-usage
   card AND the `CoachReadCard` daily-budget hint refresh mid-view when a
   background rep finalizes and consumes budget. Low priority because
   Settings is modal in practice.
5. **Trust/tension trend chip on `IMHistoryBreakdownCard` row.** The
   History list row could carry the same directional chips the detail
   header now shows. Deferred only to keep the row from getting visually
   crowded (it already gained a tone chip in round 7); wants a quick
   layout QA pass to confirm the row still reads at a glance with trend +
   tone chips together.
