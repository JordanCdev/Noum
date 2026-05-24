# HANDOFF — M24 deferred slate (round 5): IM scenario drill-down + WPM zone band + best-this-week chips

## Scope

Round 4 (commit `1f3529f` / `8764476`) landed four moves from the prior
"Future moves" list: Timed + IM history breakdown cards, the post-rep
daily-cap hint on `CoachReadCard`, and the Profile-level SD share
row. It explicitly forwarded six remaining items:

1. Peer SD scores (blocked on `PublicProfileSnapshot` schema work)
2. `coachNoteRevealed` cleanup (animation-chain risk)
3. Rate-limiter live refresh (low priority — Settings is modal in
   practice)
4. IM per-scenario drill-down (natural next step now that the
   breakdown card exists)
5. WPM zone band visualization on `TimedHistoryBreakdownCard`
6. Best-rep-of-the-week chip across all four per-mode breakdown cards

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round: of the six items the prior HANDOFF
forwarded, three are now closeable without device-only QA, without
schema work, and without touching the animation chain — items 4, 5,
and 6. This push closes them. The remaining three (peer SD scores,
`coachNoteRevealed` cleanup, rate-limiter live refresh) stay deferred
for the same reasons noted in round 4.

## What shipped

### Track 1 — IM per-scenario drill-down (#4 from prior HANDOFF)

The IM breakdown card was wired with an `onSelectScenario` callback
shape in round 4 but the destination view didn't exist yet. This
round delivers it as the parallel to `SuddenDeathDifficultyRunsView`
so the History surface keeps one design language across modes: tap a
per-mode row → land on the per-row drill-down.

#### Move 1 — `AppDestination.imScenarioDetail(scenario:)`

New case on `Noum/PracticeSupport.swift:AppDestination`. Mirrors the
shape of the existing `suddenDeathDifficultyDetail(difficulty:)`
case. Hashable, Equatable, NavigationPath-compatible — locked by four
new `AppDestinationSessionDetailTests` cases (equality on same
scenario, distinctness on different scenario, distinctness from the
SD detail case, Set round-trip dedup).

#### Move 2 — `IMScenarioDetailView`

New `Noum/IMScenarioDetailView.swift` (~290 LOC). Reached when the
user filters History to IM Mode and taps a scenario row in the
breakdown card. Layout mirrors `SuddenDeathDifficultyRunsView`:

- Mode-tinted (Timed-IM purple-blue) summary header — scenario title
  + scenario summary (one line) + rep count + three stat tiles (best
  score, avg trust, avg tension).
- Per-rep row list, newest-first. Each row carries: score (or "—"
  for unscored reps), target-tone chip, absolute date/time stamp,
  trust + tension chips at the trailing edge. Trophy icon next to
  the top-scoring rep so the user reads "this is the peak in this
  scenario" without scanning the numbers.
- Tap a row → pushes the standard `sessionDetail(sessionID:)` route
  so the user can drill into full transcript / coach read / IM
  conversation card for any rep.
- Trailing toolbar `ShareLink` exports the scenario history as
  plain text via the new `IMHistoryExport.formatPlainText(sessions:
  scenario:)` helper — same anti-goal contract as the SD export
  (zero transcripts; only outcome numbers + scenario + target tone).

Wired into `ContentView`'s `navigationDestination(for:)` switch.
`SessionHistoryView` now passes `onSelectScenario:` through to the
breakdown card, so a tap on any IM scenario row pushes the new
destination — read-only callers (tests, previews) are unaffected
because the callback is still optional.

#### Move 3 — `IMHistoryExport` plain-text formatter

New `Noum/IMHistoryExport.swift` (~120 LOC). Mirrors the shape of
`SuddenDeathHistoryExport`:

```swift
enum IMHistoryExport {
    static func formatPlainText(sessions:, scenario:) -> String
    static func formatPlainText(sessions:) -> String
    static func headerRow() -> String
    static func formatRow(_ session:) -> String
    static func isoDate(_ date:) -> String
}
```

Honest-data contract — the anti-goal-compliant export rule from
`docs/VISION.md` ("never publishes raw transcripts") applies to IM
just as it does to SD. The IM mode is the richest source of
transcript content in the app (full conversation turns, NPC replies,
final-beat narrative), so the export rule is even more important
here. Locked by `IMHistoryExportTests.crossScenarioExportNever-
ContainsTranscriptContent` — fixtures inject sentences from the
turns + finalState.beat into a session, the export string is then
searched for those substrings and the test fails if any of them
leak.

### Track 2 — WPM zone band visualization on Timed (#5 from prior HANDOFF)

The Timed breakdown card already surfaced an `inZoneRepCount`
integer in the middle stat column. The deferred item flagged that
"a tiny visual band ('12 of 30 reps in zone — 130–160 WPM') would
carry the same data with more legibility."

This round lands the band. New `zoneBand(for:)` `@ViewBuilder` on
`TimedHistoryBreakdownCard` renders beneath the stat row:

```
12 of 30 reps in zone                     130–160 WPM
████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

- Caption line on the left: "N of M reps in zone" — same subtitle
  copy across `inZoneRepCount` (1 / non-1 plural) and `runCount`.
- Range label on the right: `<min>–<max> WPM` — reads from the
  canonical `TimedHistorySummary.zoneMinWPM` / `zoneMaxWPM` constants
  so a future zone shift can never produce stale labels.
- 6pt mode-tinted progress bar: rounded rectangle on a 0.12-alpha
  base, filled to `inZoneRepCount / runCount` at 0.85-alpha. Width
  computed inside a `GeometryReader` so the visual ratio is
  responsive to the card width, not hardcoded.
- VoiceOver: the band itself is `accessibilityHidden(true)`; the
  outer VStack carries a single combined label ("12 of 30 reps in
  zone (130–160 WPM). 40 percent in zone.") so the screen-reader read
  is one chunk, not two.
- Self-hides when `runCount == 0` (defensive belt-and-braces — the
  card body itself self-hides on cold start).

Two `TimedHistoryZoneBandContractTests` lock the contract: range
constants stay at 130/160 (matching `WPMEvaluator` Timed band), and
`inZoneRepCount` cannot exceed `runCount` (the visual band ratio
invariant).

### Track 3 — Best-rep-of-the-week chips (#6 from prior HANDOFF)

The deferred item flagged: "Across all four per-mode breakdown
cards, a 'this week's best' chip would tell the user 'you peaked
today' or 'your peak is from 3 days ago' in one read." This round
ships the underlying helpers AND the visual chips on all four cards
— with two slightly different surface shapes because the per-mode
cards have two slightly different layouts.

#### Move 1 — Pure helpers: `isThisWeek` + `bestThisWeek`

Three new pure functions, one per summary module, all locked by
their own test suites:

```swift
TimedHistorySummary.isThisWeek(date:now:calendar:) -> Bool
AhCounterHistorySummary.isThisWeek(date:now:calendar:) -> Bool
SuddenDeathHistorySummary.bestThisWeek(from:now:calendar:) -> SuddenDeathRunRecord?
IMHistorySummary.bestThisWeek(from:now:calendar:) -> (session:, scenario:, score:)?
```

Defensive contracts (locked by tests):

- "This week" is the inclusive 7-day window from `now`: `now - 7d`
  ≤ date ≤ `now`. Both ends inclusive, boundary alignment between
  the Timed and Ah-Counter helpers locked by an explicit cross-helper
  agreement test (`isThisWeekBoundaryAlignsWithTimedHelper`).
- Future dates (clock drift / fixture mistake) NEVER read as "this
  week" — locked by `isThisWeekFalseForFutureDate`.
- `bestThisWeek` picks the highest `roundsSurvived` (SD) or `score`
  (IM) inside the window. Tiebreak by most-recent date so the user
  reads "today's best" before "Tuesday's best" when both tie.
- IM `bestThisWeek` ignores non-IM-mode sessions — a high-scoring
  Timed rep can never appear in the IM "best this week" picker even
  when it lives in the same `PracticeSessionStore`. Locked by
  `bestThisWeekIgnoresOtherModes`.

#### Move 2 — Surface on Timed + Ah-Counter cards: inline "THIS WEEK" chip

`TimedHistorySummaryStats` gains `bestIsThisWeek: Bool`, computed
from `best.date` against `now` via the new `isThisWeek` helper.
`AhCounterHistorySummaryStats` gains `cleanestIsThisWeek: Bool`, same
shape.

Both breakdown cards (Timed + Ah-Counter) now render a small
`THIS WEEK` capsule next to the "Best rep" / "Cleanest rep" eyebrow
label when the flag is true:

```
TROPHY  BEST REP   ┃THIS WEEK┃
        8/10 · 142 WPM · today
```

- Mode-tinted (Timed blue / Ah-Counter green), 0.12-alpha background,
  bold caption2 typography — quieter than the trend chip above so it
  reads as a status tag, not a celebration.
- VoiceOver: the chip itself is hidden; the row's combined
  accessibility label flips to "Best rep this week: 8/10 · 142 WPM ·
  today" when the flag is true. Single read for screen-reader users.
- Brand-voice contract: no exclamation, no "you peaked!" framing,
  no urgency copy — just the time tag.

#### Move 3 — Surface on Sudden Death + IM cards: header capsule

SD and IM cards lay out rows by difficulty / scenario (not a single
best-rep cell at the bottom), so the "this week" chip sits in the
card header as a one-line summary capsule:

```
[SD card]
  ⚡ Sudden Death history                          12 runs
    Last run yesterday
    ┃ trophy  Best this week · 8 rounds · Hard ┃

[IM card]
  💬 IM history                                    8 reps
    Last rep yesterday
    ┃ trophy  Best this week · 9/10 · Difficult Conversation ┃
```

- Renders only when at least one qualifying run lives inside the
  7-day window. Cold-start users never see a fabricated chip.
- Same mode-tinted register as the inline chips. Reads as the
  card-level "current peak" summary the user can take in without
  scanning the rows.
- Accessibility identifiers `history.suddenDeath.bestThisWeek` and
  `history.im.bestThisWeek` so future UI tests can address the chip
  directly.

### Vision alignment

All three tracks land on the same axes as the round-4 push:

- **Pillar #3 — Conversational intelligence.** The IM drill-down is
  the read the £130/hr human coach would give after reviewing the
  last 10 reps at one scenario; a tap-through path to the per-rep
  detail is the natural extension.
- **Pillar #4 — Believable progress.** The "this week" chips answer
  the "is my best rep current or stale?" question the user can't
  read from the trend chip alone (trend compares averages, chips
  compare peaks). The WPM zone band makes the "12 of 30" integer
  legible as a ratio without leaking the evaluator's internal scoring.
- **Anti-goals.** `IMHistoryExport` carries the same "zero
  transcripts" anti-goal contract as the SD export, locked by test
  fixtures that inject transcript content and assert it never leaks
  into the share string.

## Files touched

- **New:** `Noum/IMScenarioDetailView.swift` (~290 LOC)
- **New:** `Noum/IMHistoryExport.swift` (~125 LOC)
- **Modified:** `Noum/PracticeSupport.swift` (+5 LOC — new
  `imScenarioDetail(scenario:)` AppDestination case)
- **Modified:** `Noum/ContentView.swift` (+2 LOC — new case in the
  navigationDestination switch)
- **Modified:** `Noum/SessionHistoryView.swift` (+5 LOC —
  `onSelectScenario` callback wired in the IM filter branch)
- **Modified:** `Noum/TimedHistoryBreakdownCard.swift` (+~95 LOC —
  `zoneBand(for:)` + `thisWeekChip` + accessibility helper)
- **Modified:** `Noum/TimedHistorySummary.swift` (+~30 LOC —
  `bestIsThisWeek` field + `isThisWeek` pure helper)
- **Modified:** `Noum/AhCounterHistoryBreakdownCard.swift` (+~25 LOC
  — `thisWeekChip` + accessibility helper)
- **Modified:** `Noum/AhCounterHistorySummary.swift` (+~30 LOC —
  `cleanestIsThisWeek` field + `isThisWeek` pure helper)
- **Modified:** `Noum/SuddenDeathHistoryBreakdownCard.swift` (+~30 LOC
  — header `bestThisWeekChip`)
- **Modified:** `Noum/SuddenDeathHistorySummary.swift` (+~30 LOC —
  `bestThisWeek` static picker)
- **Modified:** `Noum/IMHistoryBreakdownCard.swift` (+~30 LOC —
  header `bestThisWeekChip` + computed property)
- **Modified:** `Noum/IMHistorySummary.swift` (+~35 LOC —
  `bestThisWeek` static picker that returns a tuple)
- **Modified:** `NoumTests/NoumTests.swift` (+~410 LOC — 7 new test
  suites: `TimedHistorySummaryBestThisWeekTests`,
  `AhCounterHistorySummaryThisWeekTests`,
  `SuddenDeathBestThisWeekTests`, `IMBestThisWeekTests`,
  `IMHistoryExportTests`, `TimedHistoryZoneBandContractTests`, plus
  4 new cases on the existing `AppDestinationSessionDetailTests`)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief.

Closes three more of the deferred items from the M24 round-4
HANDOFF (IM scenario drill-down, WPM zone band, best-this-week
chips). The remaining three deferred items (peer SD scores,
`coachNoteRevealed` cleanup, rate-limiter live refresh) stay
deferred for the reasons noted in **Scope** above.

The artifact a user can now hold:

1. **They can drill from "Difficult Conversation: 5 reps · best
   9/10" straight to the rep list.** Tap any scenario row in the IM
   breakdown card → land on a per-scenario detail view with score,
   target tone, trust + tension chips for every IM rep at that
   scenario. Tap any row to open the full session detail. Share
   the scenario's history as plain text — zero transcripts, only
   the outcome numbers.

2. **They can see at a glance how often they land inside the
   Timed pace zone.** A 6pt mode-tinted band beneath the stat row
   on `TimedHistoryBreakdownCard` fills to the ratio of in-zone
   reps. "12 of 30 reps in zone — 130–160 WPM" reads in one
   glance; the same data the integer column already showed, just
   legible as a proportion.

3. **They can read "is my peak current or stale?" without
   thinking.** A `THIS WEEK` capsule next to the "Best rep" /
   "Cleanest rep" label on Timed + Ah-Counter cards fires when the
   peak is inside the last 7 days. SD + IM cards carry the same
   signal as a header capsule that names the difficulty / scenario
   on the same line, because their card layouts don't surface a
   single best-rep cell. Quiet visual register; honest fallback to
   "no chip" when no rep is fresh enough.

All three moves are vision-aligned on the conversational-intelligence
(#3) and believable-progress (#4) pillars of `docs/VISION.md`, with
the IM export carrying the same anti-goal contract as the SD export
(zero transcript content, locked by test).

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
4. **Tone-match accuracy chart on `IMScenarioDetailView`.** The
   per-scenario detail view surfaces score + trust + tension at the
   final beat, but doesn't yet plot tone-match accuracy across reps.
   A `Chart` line (or sparkline) showing the user's evaluated-tone-
   matches-target-tone ratio per rep would tell the user "you nail
   warmth on Networking but miss it on Difficult Conversation" — a
   read the rep list can't carry on its own.
5. **Trust/tension trace on `IMScenarioDetailView`.** A two-line
   sparkline plotting `finalState.normalizedTrust` and
   `normalizedTension` across reps in this scenario, ordered by
   date. Mirrors the SD per-difficulty drill-down's potential
   "rounds-survived over time" trace. Pure visual; data is already
   on each `PracticeSession`.
6. **Empty-state CTA on `IMScenarioDetailView`.** Currently the
   empty state reads "Finish an IM rep in this scenario to start a
   track record." A "Launch this scenario" button that pushed
   `AppDestination.imPractice(scenario:tone:)` would close the loop
   so the user can act on the empty state from inside the screen.
   Already wired in `AppDestination`; just a button + handler.
