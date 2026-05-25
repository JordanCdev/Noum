# HANDOFF — M24 deferred slate (round 7): per-scenario trust/tension trend chips + tone-match list chip

## Scope

Round 6 (commit `4513e3d`) closed three of the six items the round-5
HANDOFF forwarded — all on `IMScenarioDetailView` (trust/tension trace,
tone-match strip, empty-state CTA). It forwarded an updated priority
list of six "Future moves". Two of those — items 4 and 5 — are a tight,
coherent pair: both take a per-scenario signal that is *already
computed and tested* in `IMHistorySummary` and surface it as a small
one-glance chip, one rung up the navigation tree from where the full
read lives. This push closes them together.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- **#5 — Trust/tension trend chip on `IMScenarioDetailView` header.**
  The round-6 trace *chart* shows the shape of the relational arc; a
  user still has to read the curve. Two chips in the summary header
  ("Trust ↑" / "Tension ↓") carry the read in one glance.
- **#4 — Tone-match chip on `IMHistoryBreakdownCard`.** The round-6
  tone-match strip lives one tap *inside* the scenario. A compact
  "Tone X/Y" chip on the History list row lets the user read the same
  signal without drilling in.

Both reuse pure helpers that already exist and are already tested
(`tracePoints`, `toneMatchStats`, `matches`), so the only new logic is
one pure trend-reduction helper. The remaining four "Future moves"
(peer SD scores, `coachNoteRevealed` cleanup, rate-limiter live
refresh, per-scenario drill recommendations) stay deferred for the
reasons in **Future moves** below.

## What shipped

### Track 1 — Per-scenario relational trend helper (#5 data layer)

New pure helper `IMHistorySummary.relationalTrend(from:scenario:)` in
`Noum/IMHistorySummary.swift`. It reduces the per-rep trust/tension
trace into a single directional read by comparing the mean of the
earliest `window` reps against the mean of the latest `window` reps,
where `window = min(3, count / 2)`. That bound guarantees the two
windows **never overlap** (2·window ≤ count for every count), so the
"first stretch" and the "recent stretch" are genuinely disjoint — no
rep is double-counted on both sides of the comparison.

New nested types:

- `IMScenarioRelationalTrend` (Equatable): `trust` / `tension` of type
  `Movement` (`.up` / `.down` / `.flat`), `trustDelta` / `tensionDelta`
  (latest-window mean − earliest-window mean, rounded to 0.1),
  `windowSize`, and a `hasSignal` convenience (`true` when at least one
  metric is non-flat).
- `Movement` is the **raw numeric** direction — the helper stays honest
  about what the numbers did and leaves the good/bad value judgment to
  the view (which knows trust-up is good, tension-down is good).
- `relationalTrendThreshold = 0.5` — shared with the test suite so the
  flat-vs-trend boundary is asserted, not guessed.

Defensive contracts (locked by `IMScenarioRelationalTrendTests`, 10
cases):

- reuses `tracePoints(from:scenario:)`, so it inherits the same
  `.imConversation` filter, final-state requirement, scenario filter,
  and oldest→newest ordering for free
- returns `nil` below 4 contributing reps — fewer than that can't
  separate a first stretch from a recent stretch honestly
- the two averaging windows never overlap (the `min(3, count / 2)` bound)
- `.flat` when |delta| < 0.5, per metric independently
- a stable-but-sufficient history returns a non-nil struct with
  `hasSignal == false` (enough data, no trend → header chips self-hide)

### Track 2 — Trend chips on `IMScenarioDetailView` header (#5 view layer)

`Noum/IMScenarioDetailView.swift` summary header gains a chip row
beneath the three stat tiles, rendered only when `relationalTrend` is
non-nil *and* `hasSignal` is true:

- `trendChip(label:movement:goodWhenUp:)` — `@ViewBuilder`, self-hides
  on a flat metric. Arrow glyph (`arrow.up.right` / `arrow.down.right`)
  shows the **raw** numeric direction; tint reads the **value
  judgment** — `goodWhenUp` flips the green (`AppColor.positive`) /
  amber (`AppColor.caution`) assignment so trust-up and tension-down
  both read green, trust-down and tension-up both read amber.
- Calm capsule register (0.12-alpha tint background) — matches the
  tone-match strip; it's data, not a celebration or a penalty.
- VoiceOver: the chip row carries one combined label ("Recent trend:
  trust trending up, tension trending down, based on your earliest and
  latest N reps.") via `relationalTrendAccessibilityLabel`. Accessibility
  identifier `history.im.scenario.trendChips`.

### Track 3 — Tone-match chip on `IMHistoryBreakdownCard` row (#4)

`Noum/IMHistoryBreakdownCard.swift` row gains a compact "Tone X/Y" chip
beneath the subtitle in the leading column, rendered only when the
scenario has at least one rep with a recorded `actualTone`
(`evaluatedCount > 0`):

- `toneMatchStats(for:)` reads the same pure helper the scenario
  drill-down uses, so the list row and the detail view never drift on
  the match rate.
- `toneMatchChip(stats:)` — `target` glyph + "Tone X/Y" in the
  mode-tinted calm capsule register. Marked `accessibilityHidden(true)`
  because the row's combined VoiceOver label already folds in the tone
  read (", tone matched X of Y reps") — no double read.
- A scenario the evaluator never produced a tone for shows **no chip**
  rather than a fabricated "0/0" — honest cold-start behaviour, same
  contract as the detail strip.

### Vision alignment

Both moves land on the same axes as rounds 5 and 6:

- **Pillar #3 — Conversational intelligence.** "Your last few
  Difficult Conversation reps recovered trust faster and held tension
  lower" is the read a £130/hr human coach gives after pulling up the
  history. The trend chips put that read on the scenario header; the
  tone-match list chip puts the tone-accuracy read on the History list
  without a drill-in.
- **Pillar #4 — Believable progress.** Every new surface self-hides on
  insufficient or missing data: trend chips need ≥4 reps with a final
  state *and* a non-flat signal; the tone chip needs ≥1 recorded
  `actualTone`. No fabricated points, no placeholder visuals, no
  fake-zero percentages.
- **Anti-goals.** The trend helper reports the *raw* numeric movement
  and reads `normalizedTrust`/`normalizedTension` directly — no
  smoothing, no AI reframe. The tone chip reuses the engine's own
  `actualTone` string via the already-tested substring matcher. No
  punish-shame: a low tone-match or an amber trend chip is informative
  data in a calm capsule, never a red failure state.

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+~85 LOC —
  `IMScenarioRelationalTrend` value type + `Movement` enum +
  `relationalTrendThreshold` + `relationalTrend(from:scenario:)`)
- **Modified:** `Noum/IMScenarioDetailView.swift` (+~55 LOC —
  `relationalTrend` computed wrap, header chip row, `trendChip`
  `@ViewBuilder`, `relationalTrendAccessibilityLabel`)
- **Modified:** `Noum/IMHistoryBreakdownCard.swift` (+~30 LOC —
  `toneMatchStats(for:)`, `toneMatchChip(stats:)`, chip in the leading
  column gated on `evaluatedCount > 0`, tone read folded into the row's
  combined accessibility label)
- **Modified:** `NoumTests/NoumTests.swift` (+~205 LOC — new
  `IMScenarioRelationalTrendTests` suite, 10 cases: nil on empty, nil
  below 4 reps, detects improvement (trust ↑ / tension ↓), detects
  regression, flat when stable, flat below 0.5 threshold, window size
  for 4 reps, threshold inclusive at 0.5, ignores other scenarios +
  Timed modes, drops reps without a final state)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief.

The artifact a user can now hold:

1. **At a scenario, they read the relational arc in one glance.** Two
   chips on the `IMScenarioDetailView` summary header — "Trust ↑" green,
   "Tension ↓" green (or amber for the reverse) — sitting above the
   trace chart that shows the underlying shape. Self-hides below 4 reps
   or when both metrics are flat.

2. **On the IM History list, they read tone accuracy per scenario
   without drilling in.** A compact "Tone X/Y" chip on each
   `IMHistoryBreakdownCard` row. Self-hides for any scenario with no
   recorded `actualTone`.

Both are vision-aligned on the conversational-intelligence (#3) and
believable-progress (#4) pillars, and carry the same honest-data
contracts the round-6 cards established: drop missing data rather than
fabricate it; self-hide rather than render a placeholder.

## Future moves

(Updated priority list — items 4 and 5 closed in this push removed;
remaining items carried forward:)

1. **Per-scenario drill recommendations.** When the tone-match rate on
   a scenario is low (<40%) AND the user has 3+ evaluated reps, the
   `RecommendationBiasEngine` could surface a "Drill the <scenario>
   tone" recommendation that biases toward the relevant skill area +
   auto-fills the scenario. This closes the loop between the
   per-scenario read (now visible at both the list and detail level
   after this round) and the recommendation surface. Deferred because
   `RecommendationBiasEngine` lives in `PracticeSupport.swift` and
   feeds seven consumer surfaces (`PracticeModeSelectionView`,
   `SummaryView`, `HomeCoachCard`, `PracticeTopics`, `ContentView`,
   `SummaryCards`) — a new recommendation trigger wants a dedicated
   push with the recommendation-surface QA, not a rider on a
   chip-rendering change.
2. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
3. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA.
4. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` (or expose a publisher) so the Settings AI-usage
   card AND the `CoachReadCard` daily-budget hint refresh mid-view when
   a background rep finalizes and consumes budget. Low priority because
   Settings is modal in practice.
5. **Trust/tension trend chip on `IMHistoryBreakdownCard` row.** Now
   that `relationalTrend` is a pure helper, the History list row could
   carry the same directional chips the detail header now shows — the
   list would read the relational arc per scenario without a drill-in,
   the same way the tone chip landed this round. Deferred only to keep
   the row from getting visually crowded; wants a quick layout QA pass
   to confirm the row still reads at a glance with trend + tone chips
   together.
