# HANDOFF — M24 deferred slate (round 6): IMScenarioDetailView analytics + empty-state CTA

## Scope

Round 5 (commit `e701d21`) landed three moves from the prior "Future
moves" list: the IM per-scenario drill-down view, the WPM zone band on
the Timed breakdown card, and the best-this-week chips across all four
per-mode breakdown cards. It explicitly forwarded six remaining items:

1. Peer SD scores (blocked on `PublicProfileSnapshot` schema work)
2. `coachNoteRevealed` cleanup (animation-chain risk)
3. Rate-limiter live refresh (low priority — Settings is modal)
4. Tone-match accuracy chart on `IMScenarioDetailView`
5. Trust/tension trace on `IMScenarioDetailView`
6. Empty-state CTA on `IMScenarioDetailView`

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round: of the six items the prior HANDOFF
forwarded, three are now closeable in a single coherent push because
they all land on the same view (`IMScenarioDetailView`) and reuse the
same per-scenario data the drill-down already reads — items 4, 5, and
6. This push closes them. The remaining three (peer SD scores,
`coachNoteRevealed` cleanup, rate-limiter live refresh) stay deferred
for the same reasons noted in round 5.

## What shipped

### Track 1 — Trust/tension trace sparkline (#5 from prior HANDOFF)

The IM per-scenario detail view already surfaced average trust + average
tension as summary tiles, but a single mean across N reps couldn't show
the user whether their relational delivery was trending up or down at
this scenario. A two-line sparkline reads "you closed the last three
networking chats with higher trust and lower tension than your first
five" without the user having to scan numeric rows.

#### Move 1 — New pure helper `IMHistorySummary.tracePoints(from:scenario:)`

Lives in `Noum/IMHistorySummary.swift`. Returns
`[IMScenarioTracePoint]` ordered oldest-to-newest so a Chart consumer
reads left-to-right as time-moves-forward. Each point carries `id`,
`date`, `trust`, `tension`. Defensive contracts (locked by
`IMScenarioTracePointsTests`):

- filters to `.imConversation` internally — an upstream filter
  mistake produces an empty result, not a mixed-mode trace
- ignores reps with `imConversationDetails == nil` or `finalState ==
  nil` (can't plot a non-existent state)
- drops cross-scenario reps so the caller can pass the whole
  `PracticeSessionStore` and still get one scenario's trace
- orders oldest → newest (chart `x` axis reads forward in time)
- uses `IMConversationState.normalizedTrust` / `normalizedTension`
  accessors so out-of-range engine output can never plot past the
  visible 1–10 band

New nested type `IMHistorySummary.IMScenarioTracePoint` (Equatable,
Identifiable, public surface).

#### Move 2 — `traceChartCard` view on `IMScenarioDetailView`

New `@ViewBuilder traceChartCard` renders beneath the summary header,
in the same mode-tinted card-background register. Body:

- Header: `waveform.path.ecg` glyph (Timed-IM purple-blue) + "Trust
  vs tension" title + rep-count caption
- `Chart` block (gated by `#if canImport(Charts)`) plotting two
  `LineMark` series (trust = teal, tension = orange) with matching
  `PointMark` overlays so individual reps are addressable. Catmull-Rom
  interpolation, `chartYScale(domain: 1...10)`, axis marks at 1/5/10
  on the y axis + 3 auto-spaced labels on the x axis.
- Legend strip: two color-dot legend entries + "oldest → newest"
  caption so the user reads which side is the most recent rep
- Self-hides when `tracePoints.count < 2` (a single point isn't a
  trace; the card collapses entirely rather than rendering a
  placeholder)
- VoiceOver: the chart itself is `accessibilityHidden(true)`; the
  outer VStack carries a single combined label ("Trust and tension
  trace across N reps. Trust moved from X to Y; tension moved from X
  to Y, on a 1-to-10 scale.") so the screen-reader read is one chunk

### Track 2 — Tone-match strip (#4 from prior HANDOFF)

The deferred item asked for a tone-match accuracy chart across reps.
Rather than a full chart (the per-rep tone-match is a boolean, not a
continuous value), this push lands a more legible visual: a "last 5
reps" chip strip + a ratio caption. The matcher reads the engine's
free-form `actualTone` string against the user's committed
`targetTone.title` via case-insensitive substring containment — the
same shape the server-side evaluator uses when producing the
`actualTone` readout, so the match rate is honest about what the
engine observed.

#### Move 1 — New pure helpers `toneMatchStats(from:scenario:)` + `matches(targetTone:actualTone:)`

Both live in `Noum/IMHistorySummary.swift`. `matches` is exposed as a
pure static for testability — the matcher rule the chart strip relies
on. `toneMatchStats` returns `IMScenarioToneMatchStats` carrying
`evaluatedCount`, `matchCount`, `matchRate: Double?` (rounded to two
decimals), and `lastFive: [LastFiveEntry]` (newest-first, bounded at
5 so the strip reads as a quick recency cue not a deep history).

Defensive contracts (locked by `IMScenarioToneMatchStatsTests`):

- filters to `.imConversation` internally
- ignores reps where `actualTone == nil` or whitespace-only (the
  evaluator didn't actually produce a reading — that's not a miss,
  it's missing data, dropped from both numerator and denominator)
- drops cross-scenario reps
- `lastFive` is ordered newest-first so the visual strip's leftmost
  chip reads as "the most recent rep"
- `matchRate` is `nil` when `evaluatedCount == 0` (no honest
  denominator → no fabricated zero percent)
- case-insensitive substring containment — "warmly confident" matches
  target `.confident`; the evaluator often qualifies the tone and a
  strict equality matcher would over-report misses
- empty / whitespace-only `actualTone` always non-matches at the
  `matches(...)` level (belt-and-braces — the higher-level helper
  filters those out before calling, but the test fixtures still
  exercise the rule)

#### Move 2 — `toneMatchCard` view on `IMScenarioDetailView`

New `toneMatchCard` private computed view, sits beneath the trace
chart card (or beneath the summary header when the trace card
self-hides). Body:

- Header: `target` glyph + "Tone match" title + ratio caption
  ("3 of 5 matched")
- "Last 5 reps" small-caps eyebrow + horizontal chip row of
  checkmark / xmark circles, newest-first
- Match chip: `checkmark.circle` tinted `AppColor.positive` (mode
  neutral green) when matched, `xmark.circle` tinted `AppColor.caution`
  when not. Both at 0.14-alpha background so the row reads as a
  calm sequence, not a celebration/penalty
- Self-hides when `evaluatedCount == 0` (no rep recorded an
  `actualTone` yet — the card collapses)
- VoiceOver: combined label ("Tone match: 3 of 5 reps matched the
  target tone, 60 percent.")

### Track 3 — Empty-state CTA (#6 from prior HANDOFF)

The detail view's empty state previously read "Finish an IM rep in
this scenario to start a track record." with no affordance to act on
the empty state from inside the screen. This round adds a "Launch
this scenario" button that pushes `AppDestination.imPractice(scenario:
tone:)` with `tone: nil` so the IM practice view's own tone picker
resolves it from the user's last preference — same behaviour the
Quick Start CTA uses, so the launch path stays coherent across entry
points.

Button surface: mode-tinted (Timed-IM purple-blue) Capsule with
`play.circle.fill` glyph + "Launch this scenario" label. Accessibility
identifier `history.im.scenario.launchCTA` for future UI test
coverage; accessibility label "Launch <scenario title>".

### Vision alignment

All three tracks land on the same axes as the round-5 push:

- **Pillar #3 — Conversational intelligence.** The trust/tension
  trace + tone-match strip turn the per-scenario detail view from a
  rep list into a per-scenario read — "your last three Difficult
  Conversation reps recovered trust faster than your first five" is
  the kind of insight a £130/hr human coach would surface after
  pulling up the same data.
- **Pillar #4 — Believable progress.** Both new cards self-hide on
  insufficient data (trace: <2 reps with final state; tone match:
  0 reps with `actualTone` recorded). No fabricated points; no
  placeholder visuals. The honest empty state with a real launch CTA
  closes the loop without padding it.
- **Anti-goals.** The tone matcher reads from the engine's own
  `actualTone` string, not an AI-interpreted reframe; the trace
  reads `normalizedTrust` / `normalizedTension` directly, no
  smoothing or invention. The empty-state CTA never auto-launches —
  the user has to tap it.

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+~110 LOC —
  `IMScenarioTracePoint` + `tracePoints(from:scenario:)`,
  `IMScenarioToneMatchStats` + `toneMatchStats(from:scenario:)`,
  `matches(targetTone:actualTone:)`)
- **Modified:** `Noum/IMScenarioDetailView.swift` (+~210 LOC —
  `traceChartCard` + `traceChart` + legend helpers + accessibility
  label, `toneMatchCard` + chip + ratio + accessibility label, empty-
  state CTA button, `tracePoints` + `toneMatchStats` computed wraps)
- **Modified:** `NoumTests/NoumTests.swift` (+~240 LOC — two new
  test suites: `IMScenarioTracePointsTests` (6 cases: empty input,
  scenario filter, ordering, drops reps without final state,
  normalizer clamp, drops non-IM modes) + `IMScenarioToneMatchStatsTests`
  (10 cases: empty input, nil actualTone exclusion, whitespace-only
  exclusion, case insensitivity, substring containment, empty actual
  never matches, scenario filter, last-five newest-first ordering,
  rate rounding to two decimals, non-IM exclusion))
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief.

Closes three more of the deferred items from the M24 round-5
HANDOFF (tone-match accuracy chart, trust/tension trace, empty-state
CTA). The remaining three deferred items (peer SD scores,
`coachNoteRevealed` cleanup, rate-limiter live refresh) stay
deferred for the reasons noted in **Scope** above.

The artifact a user can now hold:

1. **They can see their trust + tension arc at one scenario in one
   glance.** Two-line sparkline beneath the summary header on
   `IMScenarioDetailView`, oldest-to-newest, with mode-tinted card
   chrome + legend dots + "oldest → newest" caption. Self-hides on
   <2 reps with a recorded final state.

2. **They can see at a glance how often the evaluator read their
   actual tone as matching the target tone.** A "last 5 reps" chip
   row + "X of Y matched" ratio caption beneath the trace card.
   Honest data — missing `actualTone` readings are dropped from
   both numerator and denominator. Self-hides on cold start.

3. **They can launch the scenario from inside the empty state.**
   Pill-shaped "Launch this scenario" CTA on the empty state pushes
   `AppDestination.imPractice(scenario:tone:)` with tone nil so the
   IM practice view's own picker resolves it from preference.

All three moves are vision-aligned on the conversational-intelligence
(#3) and believable-progress (#4) pillars of `docs/VISION.md`. The
helpers carry the same honest-data contracts the SD + IM History
breakdown cards already enforce: drop missing data rather than
fabricate it; self-hide rather than render a placeholder.

## Future moves

(Updated priority list — items closed in this push removed,
remaining items carried forward:)

1. **Peer Sudden Death scores via `FriendsManager`.** Still
   blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated
   refactor pass with proper visual QA.
3. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` (or expose a publisher) so the Settings
   AI-usage card AND the new CoachReadCard daily-budget hint
   refresh mid-view when a background rep finalizes and consumes
   budget. Low priority because Settings is modal in practice.
4. **Tone-match trend chip on `IMHistoryBreakdownCard`.** Per-
   scenario row could carry a small "tone match rate" chip ("4/5
   matched" / "2/5 matched") so the History list reads the same
   signal without having to drill in. Pure visual; data is already
   on each `PracticeSession` and the matcher is now the pure helper
   `IMHistorySummary.matches`.
5. **Trust/tension trend chip on `IMScenarioDetailView` header.**
   Compute the slope of the last-3 reps vs first-3 reps for trust +
   tension and surface as a small "trust ↑" / "tension ↓" chip in
   the summary header. The trace chart shows the shape; a chip would
   carry the read in one glance.
6. **Per-scenario drill recommendations.** When the tone-match rate
   on a scenario is low (<40%) AND the user has 3+ evaluated reps,
   the `RecommendationBiasEngine` could surface a "Drill the
   <scenario> tone" recommendation that biases toward the
   `voiceAlignment` skill area + auto-fills the scenario.
   Closes the loop between the per-scenario read and the
   recommendation surface.
