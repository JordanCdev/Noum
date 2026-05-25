# HANDOFF — M24 deferred slate (round 8): trust/tension trend chips on the IM History list row

## Scope

Round 7 (commit `5cd4132`) shipped the per-scenario `relationalTrend`
pure helper and surfaced it as two directional chips on the
`IMScenarioDetailView` header, plus a tone-match chip on the
`IMHistoryBreakdownCard` row. It forwarded six "Future moves" and named
the top one explicitly: now that `relationalTrend` is a pure, tested
helper, the IM **History list row** could carry the same directional
chips the detail header shows — "the list would read the relational arc
per scenario without a drill-in." It was deferred only to keep the row
from getting visually crowded, and it asked for "a quick layout QA pass
to confirm the row still reads at a glance with trend + tone chips
together." This push closes it.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- **#5 — Trust/tension trend chips on the `IMHistoryBreakdownCard`
  row.** Surface the round-7 `relationalTrend` read one rung up the
  navigation tree, on the IM History list, so the user reads each
  scenario's relational arc ("Trust ↑ / Tension ↓") without drilling
  into the scenario.

The round-7 deferral reason was the only real risk, and it was a
layout one. **I cannot run the iOS simulator in this environment (no
Xcode / Swift toolchain on the build host), so I could not do the
visual QA pass round 7 asked for.** Rather than ship a change that
*might* crowd and hope it reads, I resolved the crowding **structurally**
so it cannot clip regardless of device width — see Track 2.

The remaining four "Future moves" stay deferred for the reasons in
**Future moves** below.

## What shipped

### Track 1 — Trend chips read on the list row (reuse, no new data layer)

`Noum/IMHistoryBreakdownCard.swift` now reads the existing pure helper
`IMHistorySummary.relationalTrend(from:scenario:)` per row (new private
wrap `relationalTrend(for:)`) and renders the same two trend chips the
scenario detail header carries:

- `trendChip(label:movement:goodWhenUp:)` — `@ViewBuilder`, a verbatim
  mirror of the `IMScenarioDetailView` chip so the two surfaces can
  never read differently. Self-hides on a flat metric. Arrow glyph
  (`arrow.up.right` / `arrow.down.right`) shows the **raw** numeric
  direction; tint reads the **value judgment** — `goodWhenUp` flips the
  green (`AppColor.positive`) / amber (`AppColor.caution`) assignment so
  trust-up and tension-down both read green, the reverse amber.
- No new data-layer code. The trend math, the `IMScenarioRelationalTrend`
  value type, the `0.5` threshold, and the ≥4-rep / non-overlapping-window
  contracts all landed in round 7 and are already locked by the 10-case
  `IMScenarioRelationalTrendTests`. This round is the view layer plus an
  integration test for the list-row gating (Track 3).

### Track 2 — Crowding resolved structurally (the round-7 layout-QA risk)

Instead of cramming the trend chips next to the tone chip inside the
row's narrow title column (where round 7 placed the tone chip, under the
subtitle), `breakdownRow` is restructured into a `VStack`:

1. the existing main `HStack` (title + subtitle on the left, the three
   stat columns `avg`/`trust`/`tension` and chevron on the right), then
2. a new full-width `chipRow(for:)` beneath it.

`chipRow` renders an `HStack` of the trend chips **plus** the round-7
tone-match chip, on its own line with the whole card width to work
with. Up to three small capsules ("↑ Trust", "↓ Tension", "Tone X/Y")
read side-by-side without clipping even on the narrowest device — the
constraint that made round 7 defer is gone by construction, not by
hoping it fits. This also lifts the tone chip out of the cramped title
column, a small improvement to the round-7 placement.

`chipRow` self-hides entirely (returns nothing) when the scenario has
**neither** a non-flat trend **nor** a recorded tone, so a cold-start
scenario adds no empty strip and no extra vertical space.

### Track 3 — List-row gating contract (the one genuinely new test surface)

The trend math is already exhaustively tested. What was *not* yet
locked is the contract the **list row** newly depends on: the row
appears for any scenario with ≥1 rep, but the trend chip must appear
only when there is honest signal — the two must never disagree. New
`IMHistoryBreakdownTrendContractTests` in `NoumTests/NoumTests.swift`
(3 cases) pin exactly that:

- a ≥4-rep improving scenario yields **both** a `breakdowns` row **and**
  a non-nil trend with `hasSignal == true` (chip shows on that row);
- a 2-rep scenario renders a row (its stats are real) but
  `relationalTrend` returns `nil` → the chip self-hides, no fabricated
  flat reading on a row that legitimately has stat data;
- a stable 4-rep scenario renders a row with a non-nil trend whose
  `hasSignal == false` → chip hidden, the same "enough data, no trend"
  self-hide the detail header uses.

### Accessibility

The trend read folds into the row's existing combined VoiceOver label
via `relationalTrendCopy(for:)` (", trust trending up and tension
trending down"), appended ahead of the existing tone clause. The visual
`chipRow` is marked `accessibilityHidden(true)` so VoiceOver reads the
row's single combined label once — no double read of the chips. The
trend copy is empty when `hasSignal` is false, so VoiceOver never
announces a trend the chips aren't showing.

### Vision alignment

- **Pillar #3 — Conversational intelligence.** "Your Difficult
  Conversation reps are recovering trust faster and holding tension
  lower lately" is the read a human coach gives after pulling up the
  history. Round 7 put it on the scenario header; this round puts it on
  the History list itself, one tap earlier.
- **Pillar #4 — Believable progress.** Every new surface self-hides on
  insufficient data: trend chips need ≥4 final-state reps with a
  non-flat |Δ|≥0.5 signal; the tone chip needs ≥1 recorded `actualTone`.
  No fabricated points, no placeholder visuals, no fake-zero percentages.
- **Anti-goals.** The chip reports the *raw* numeric movement (arrow =
  direction the numbers actually moved) and only the color carries the
  good/bad judgment. No smoothing, no AI reframe, no punish-shame: an
  amber chip is informative data in a calm capsule, never a red failure.

## Files touched

- **Modified:** `Noum/IMHistoryBreakdownCard.swift` (+~75 LOC —
  `breakdownRow` restructured to a `VStack`; new `chipRow(for:)`,
  `relationalTrend(for:)`, `trendChip(label:movement:goodWhenUp:)`,
  `relationalTrendCopy(for:)`; tone chip moved into `chipRow`; trend
  clause folded into the combined accessibility label; top doc-comment
  updated to describe the chip row)
- **Modified:** `NoumTests/NoumTests.swift` (+~95 LOC — new
  `IMHistoryBreakdownTrendContractTests` suite, 3 cases)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief.

The artifact a user can now hold:

**On the IM History list, they read each scenario's relational arc and
tone accuracy at a glance, without drilling in.** Each
`IMHistoryBreakdownCard` row shows, beneath its stat columns, the two
trend chips ("Trust ↑" green / "Tension ↓" green, or amber for the
reverse) the scenario detail header carries, alongside the round-7
"Tone X/Y" chip. The chip row self-hides for any scenario without ≥4
final-state reps of real movement and without a recorded tone — honest
cold-start behaviour, the same contracts the round-6 and round-7 cards
established.

## Future moves

(Updated priority list — item #5 closed this round; remaining items
carried forward:)

1. **Per-scenario drill recommendations.** When the tone-match rate on
   a scenario is low (<40%) AND the user has 3+ evaluated reps, the
   `RecommendationBiasEngine` could surface a "Drill the <scenario>
   tone" recommendation that biases toward the relevant skill area +
   auto-fills the scenario. With both the relational-trend read and the
   tone read now visible at the list **and** detail level, the read
   side of this loop is fully surfaced — the missing half is the
   recommendation trigger. Still deferred because
   `RecommendationBiasEngine` lives in `PracticeSupport.swift` and feeds
   seven consumer surfaces (`PracticeModeSelectionView`, `SummaryView`,
   `HomeCoachCard`, `PracticeTopics`, `ContentView`, `SummaryCards`); a
   new recommendation trigger wants a dedicated push with the
   recommendation-surface QA, not a rider on a chip-rendering change.
   **This is the natural next round — the read is done; close the loop.**
2. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
3. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device, which this build host
   does not have).
4. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` (or expose a publisher) so the Settings AI-usage
   card AND the `CoachReadCard` daily-budget hint refresh mid-view when
   a background rep finalizes and consumes budget. Low priority because
   Settings is modal in practice.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
change was written to match the existing, tested patterns line-for-line
(`trendChip` mirrors `IMScenarioDetailView`; the new test reuses the
`IMScenarioRelationalTrendTests` session-builder shape), and the
crowding risk was removed structurally rather than verified visually.
Before this lands in a TestFlight build it still wants a real
`xcodebuild test` + a glance at the IM History screen on a narrow
device to confirm the three-chip row reads as intended. Treat the
"reads at a glance" claim as designed-for, not observed.
