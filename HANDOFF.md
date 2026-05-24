# HANDOFF — M24 deferred slate (round 3): Settings AI-budget + SD result history-export menu + Ah-Counter breakdown

## Scope

The previous push (commit `060843a`) closed three of the six M24
"Future moves": AI rate limiter at the service layer, per-difficulty
drill-down on the SD breakdown card, and plain-text SD history export
from the drill-down. It left three deferred items — peer SD scores
(blocked on schema work), `coachNoteRevealed` cleanup (animation-
chain risk), and "mode-specific stat surfaces for other modes" — and
three new candidates the prior HANDOFF surfaced as natural next steps.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round: of the six items the prior HANDOFF
forwarded, three are now closeable without device-only QA and
without architecture work. This push closes them. The remaining
three (peer scores, `coachNoteRevealed`, the rest of the per-mode
stat surfaces) stay deferred — peer scores still need
`PublicProfileSnapshot` schema work, `coachNoteRevealed` still
carries the same animation-chain risk, and the IM + Timed per-mode
surfaces are a natural next step once this Ah-Counter pattern
proves out under real-device QA.

## What shipped

### Track 1 — Rate-limiter settings surface (#5 from prior HANDOFF)

The user-facing answer to "why did my coach go rule-based today?"
The rate limiter that landed in the prior push silently demotes the
AI-polished coach voice to the deterministic fallback when the daily
budget is exhausted. Without a surface to read the budget, that
honest soft-degrade reads as a "the AI is broken" bug. This track
gives the user a place to look.

#### Move 1 — `SettingsView` AI usage section

New `aiUsageCard` private view + `aiUsageCardIsVisible` gate in
`Noum/SettingsView.swift`. Lives in the Account cluster between
Subscription and Privacy & data — the user thinks about budgets as
an account-level concept, not a Practice setting.

Visibility gate: only renders when
`AISettingsManager.shared.activeProvider != nil`. A user with no
API keys configured would otherwise see "0 of 12 remaining" with
no explanation, which would read as a broken state rather than
honest absence. The whole section disappears cleanly when there's
no AI configured.

The card surfaces TWO budgets:
- **Coach notes today** (`AIRateLimiter.remainingToday(.postRepCoachNote)`)
  — daily cap, resets at midnight in the user's local calendar.
- **Session debriefs** (`AISettingsManager.remainingAnalyses`) —
  monthly cap, resets on the first of the month.

One row shape per budget. Left column: title + reset copy.
Right column: a headline "X of Y" tile + small-caps "X remaining"
sublabel (which flips to "Rule-based today" + `AppColor.caution`
tint when the budget is exhausted). Restrained — no progress bar,
no urgency copy, no "running out!" framing. Brand-voice compliant.

#### Move 2 — Free-tier upgrade CTA (in-card)

When `!premium.isPremium`, the card adds a final row: "Pro gets
40/day · 100/month" with a `crown.fill` glyph, opening the existing
paywall sheet on tap. The copy is generated from the actual
constants — `AIRateLimiter.premiumDailyCap` and
`AISettingsManager.premiumMonthlyDebriefLimit` — so a future cap
bump can never produce stale marketing copy in the Settings card.

Hidden on Pro accounts entirely (no awkward "you're already
maxed" line).

#### Move 3 — Expose `AISettingsManager` constants

`AISettingsManager` had `private static let premiumMonthlyLimit = 100`
and `private static let freeMonthlyLimit = 20`. The Settings CTA
needs them, so this push lifts both into internal `static let`s
under cleaner names:

```swift
static let premiumMonthlyDebriefLimit: Int = 100
static let freeMonthlyDebriefLimit: Int = 20
private static let premiumMonthlyLimit = premiumMonthlyDebriefLimit
private static let freeMonthlyLimit = freeMonthlyDebriefLimit
```

The runtime cap path (`monthlyLimit`) still reads the same
constants, so the runtime behaviour is byte-identical; only the
external-readability gate has changed.

Test contract: `AISettingsManagerPremiumConstantsTests` (2 tests)
locks `premiumMonthlyDebriefLimit > freeMonthlyDebriefLimit` and
`freeMonthlyDebriefLimit > 0` so a future regression that flips the
inequality (or accidentally zeros the free cap) trips a test
rather than landing in production.

### Track 2 — SD Result history-export menu (#6 from prior HANDOFF)

The prior push shipped `SuddenDeathHistoryExport.formatPlainText(runs:)`
— the cross-difficulty export — but only wired it into the per-
difficulty drill-down's toolbar. A user on the Result screen who
wanted their full SD track record had to navigate History → filter
to Sudden Death → tap a difficulty → tap the share icon. Four
taps for what's now a one-tap-and-pick affordance.

#### Move 1 — Convert single Share button to a Menu

`Noum/SuddenDeathResultView.swift` `actionButtons` row previously
carried a single `Button` labelled "Share" that opened the original
one-line brag (`shareText`). This push lifts that into a Menu when
the user has more than one recorded SD run:

```
Share ▼
  ↳ Share this run            (the original brag — bolt.fill glyph)
  ↳ Share full history (N)    (cross-difficulty table — list.bullet.rectangle glyph)
```

When `runHistoryStore.runs.count <= 1`, the menu collapses back to
the plain Button — restraint over redundant choice. A user who's
finished one run never sees "Share full history (1 runs)"; that
would just duplicate the brag option.

#### Move 2 — Two-payload share sheet

New `ShareKind` enum (`thisRun` / `fullHistory`) + new
`pendingShareKind: ShareKind` `@State` on the view. When a menu
item is tapped, the state is set BEFORE the sheet flips open;
the sheet binding reads through `resolvedShareText` which switches
on the state. Decouples the menu close animation from the sheet
present, so the user never sees the sheet flicker between values
mid-animation.

New `fullHistoryShareText` computed property reads
`SuddenDeathHistoryExport.formatPlainText(runs: runHistoryStore.runs)`
— the same store the recent-runs card reads from, so the artifact
the user shares always matches the data they see on screen.

#### Honest-contract reuse

The cross-difficulty export already carries the same anti-goal
contract as the per-difficulty variant — `SuddenDeathHistoryExportTests.exportNeverContainsTranscriptContent`
locks "no transcript fields, no `said` markers" at the row-format
level, so adding a new caller for the same helper doesn't
introduce a new leak surface. The leaderboard rule from
`docs/VISION.md` ("never publishes raw transcripts") holds end-to-
end across both share affordances.

### Track 3 — Ah-Counter mode-specific History breakdown (#4 from prior HANDOFF)

The prior HANDOFF flagged "mode-specific stat surfaces for History"
as a natural extension of the SD breakdown pattern, citing
Ah-Counter, IM, and Timed as the candidates. This push proves the
pattern with Ah-Counter first — the cleanest test case because
the mode is named for filler-eradication, so the natural per-mode
signal (filler-rate over time) is already on every PracticeSession
row. No new persistence; just a new aggregation.

#### Move 1 — `AhCounterHistorySummary` pure helper

New `Noum/AhCounterHistorySummary.swift` mirrors `SuddenDeathHistorySummary`:
pure functions over a list of `PracticeSession`, producing a
single optional `AhCounterHistorySummaryStats` struct.

Public surface:

```swift
struct AhCounterHistorySummaryStats: Equatable {
    let runCount: Int
    let averageFillersPerMinute: Double?
    let cleanest: CleanestRep?
    let cleanRepCount: Int
    let trend: TrendComparison?
}

enum AhCounterHistorySummary {
    static func summarize(sessions: [PracticeSession],
                          now: Date = Date(),
                          calendar: Calendar = .current) -> AhCounterHistorySummaryStats?
    static func ratePerMinute(fillerCount: Int, durationSeconds: TimeInterval) -> Double
    static func trendComparison(sessions: [PracticeSession],
                                 now: Date,
                                 calendar: Calendar) -> AhCounterHistorySummaryStats.TrendComparison?
}
```

Defensive contracts:
- `summarize(sessions:)` filters to `.ahCounter` mode internally —
  upstream filter mistakes produce empty/nil, not a mixed-mode
  aggregate.
- Zero-duration sessions are dropped from rate calculations so a
  divide-by-zero can never crash the summary. Sessions with
  `duration == 0` AND `fillerWordCount == 0` would otherwise tie
  for "cleanest" at 0.0/min — explicit drop keeps the cleanest-rep
  read honest.
- Cleanest-rep tiebreak by date (most-recent wins) so the user
  reads "today's clean rep" before "last month's clean rep" when
  both qualify at the same rate.
- Trend comparison requires BOTH the 7-day window AND the prior
  7-day window to have ≥1 measurable rep. Otherwise `trend == nil`
  so the UI omits the chip rather than fabricating a single-point
  "direction" off one window.
- Trend direction threshold: |Δrate| < 0.5/min reads as `.steady`.
  A 30-second rep with one filler shifts the rate by ~2/min — the
  threshold filters that noise so a single fluke rep doesn't flip
  the user's read from "steady" to "worsening."

#### Move 2 — `AhCounterHistoryBreakdownCard`

New `Noum/AhCounterHistoryBreakdownCard.swift` — SwiftUI hero card
mirroring `SuddenDeathHistoryBreakdownCard`:

- Mode-tinted hero background (`AppColor.modeAhCounter` radial wash
  + tint border) so the History surface reads as one design
  language across modes.
- Header row: mode title + rep count + optional trend chip
  (`arrow.down.right` improving / `arrow.up.right` worsening /
  `equal` steady — paired with brand-voice copy "Down 1.2/min vs
  last week" rather than the alarming "Filler rate UP 30%!" copy
  some other apps would render).
- Stat row: three columns — avg fillers/min, clean reps, best
  fillers/min.
- Cleanest-rep cell at the bottom, optionally tappable. When
  `onSelectCleanestRep` is provided, the cell opens
  `AppDestination.sessionDetail(sessionID:)` — same destination as
  a row tap, so the user can drill from "this was my cleanest rep"
  straight to the source session.

Self-hides when `summarize(sessions:)` returns nil (cold start, no
Ah-Counter reps yet). Mirrors the SD pattern: rendering "0 reps"
on the History screen would be visual noise for a user who hasn't
touched the mode.

#### Move 3 — Wire into `SessionHistoryView`

`Noum/SessionHistoryView.swift` already carried the per-mode
breakdown pattern for SD. This push adds the symmetric branch:

```swift
if selectedModeFilter == .ahCounter {
    AhCounterHistoryBreakdownCard(
        sessions: filteredSessions,
        onSelectCleanestRep: { sessionID in
            navigationPath.append(AppDestination.sessionDetail(sessionID: sessionID))
        }
    )
    .padding(.horizontal, Spacing.screenH)
    .padding(.bottom, 16)
}
```

Reads from the existing `filteredSessions` — no new store, no new
fetch. The card only sees the already-filtered Ah-Counter rows; the
summary helper does a defensive re-filter as belt-and-braces but the
expected call site is post-filter.

#### Tests — `AhCounterHistorySummaryTests` (19 cases)

- **ratePerMinute (4):** zero fillers → 0, fillers-per-minute matches
  filler count when duration is 60s, halves at 120s, zero duration
  → 0 (defensive divide-by-zero).
- **summarize empty + filtering (3):** empty input → nil, mixed-mode
  input filters out non-`.ahCounter`, all-non-`.ahCounter` → nil.
- **cleanest rep (3):** lowest fillers/min wins, tiebreak by most
  recent date, zero-duration sessions dropped from consideration
  even at 0 fillers.
- **averages (2):** rounds to one decimal place, returns nil when
  every session has zero duration.
- **cleanRepCount (1):** tracks `fillerWordCount == 0` count.
- **runCount (1):** reflects the post-filter Ah-Counter count.
- **trend (5):** nil when recent window empty, nil when prior
  window empty, improving when recent < prior by ≥0.5/min,
  worsening when recent > prior by ≥0.5/min, steady when |Δ| < 0.5.

## What did NOT change

- **`AIRateLimiter.swift`** — the rate limiter itself is untouched.
  This push only adds a read-side surface for the budget it tracks;
  the consumption path through `PostRepCoachNoteService.generate`
  still runs identically.
- **`AISettingsManager.monthlyLimit`** — the runtime cap still reads
  `Self.premiumMonthlyLimit` / `Self.freeMonthlyLimit`, which now
  alias the same constants exposed publicly. Byte-identical runtime
  behaviour; only external readability changed.
- **`SuddenDeathHistoryExport.swift`** — the cross-difficulty
  formatter that the new Result-screen menu calls into is untouched.
  Same anti-goal contract, same column shape.
- **`SuddenDeathHistoryBreakdownCard.swift`** — the History-tab
  breakdown card is untouched. Only `SessionHistoryView` (the caller)
  gains a symmetric Ah-Counter branch.
- **`SuddenDeathResultView.actionButtons` core layout** — the row
  still has Go-Again on top + Share + See Full Summary on the
  bottom row. Only the Share button itself was lifted into a Menu
  (when there's history to share) or kept as a plain Button (when
  there isn't).
- **`SessionHistoryView` core layout** — the WeakAreasCard, filter
  chips, section header, and session list are all unchanged. Only
  the per-mode breakdown injection point gained a new branch.

## Risks

1. **Settings AI-usage card refresh cadence.** `AIRateLimiter` is
   `@MainActor final class` but NOT `ObservableObject`. When the
   card is visible, a budget consumption from another path (a rep
   finishing in the background) won't trigger an immediate refresh.
   Mitigation: in practice, the Settings sheet is modal — the user
   can't finish a rep with Settings open. The card re-evaluates on
   every body recomputation (e.g. when `aiSettings.objectWillChange`
   fires for the monthly debrief count), which is enough. A future
   refactor to make `AIRateLimiter` an `ObservableObject` would
   close this edge cleanly; out of scope for this push because the
   read-side surface doesn't need live updates today.
2. **Ah-Counter trend threshold tuned by spec, not telemetry.** The
   0.5-fillers-per-minute threshold for "steady" was chosen against
   the "single 30-second rep with one filler shifts the rate by
   ~2/min" envelope. If real user data shows the threshold reads as
   "always steady" or "always worsening," a one-constant tune is the
   fix. Locked by `trendSteadyWhenDeltaWithinThreshold` so a future
   threshold change updates the test in lockstep.
3. **Mode-specific surfaces are now non-uniform.** SD has a per-
   difficulty breakdown card + a per-difficulty drill-down + a full-
   history export. Ah-Counter has only the breakdown card (no
   "drill-down at this filler-rate band" — the natural Ah-Counter
   analog is the source session, which is reachable via the cleanest-
   rep cell). IM and Timed are still nothing. This is by design —
   each mode's per-mode signal is different — but it means a future
   "every mode has the same shape" expectation would need to be
   negotiated against the actual signal each mode produces. Not a
   bug; a design decision worth flagging.
4. **`AhCounterHistoryBreakdownCard.onSelectCleanestRep` couples
   to `AppDestination.sessionDetail`.** The view takes a closure
   so the call site decides the destination, but the closure shape
   `(UUID) -> Void` already implies "session ID resolution lives
   downstream." A future refactor that adds a richer destination
   type would land at both this and the SD breakdown card; same
   pattern, same blast radius.

## Verification

### Implemented (source-only, compiler-locked)

- `aiUsageCard` is a private computed `some View` returning a
  `cardContainer` — the same pattern every other Settings card
  uses. `cardContainer` is `@ViewBuilder`, so the Divider() +
  conditional upgrade CTA compile as ViewBuilder children.
- `aiUsageCardIsVisible` gate is a one-line read of
  `aiSettings.activeProvider != nil` — same pattern the SummaryView
  uses for AI surfaces, so a backend-not-configured developer sees
  the gate fire identically.
- `AISettingsManager.premiumMonthlyDebriefLimit` /
  `freeMonthlyDebriefLimit` are `static let Int` — directly
  inlineable in string interpolation in the Settings card without
  a Bool/Optional dance.
- `SuddenDeathResultView.shareMenu` returns `some View` via
  `@ViewBuilder` — Menu and Button are both Views, so the if/else
  branches resolve into `_ConditionalContent` cleanly.
- `pendingShareKind: @State` is set BEFORE `showingShareSheet = true`
  in both menu item closures; the sheet's `resolvedShareText`
  read sees the freshest value. No race between the menu close
  and the sheet present.
- `AhCounterHistorySummary` is `@available(iOS 17.0, *)` matching
  the rest of the History surface; the new card carries the same
  annotation.
- `AhCounterHistoryBreakdownCard` uses the same hero-background
  treatment as `SuddenDeathHistoryBreakdownCard` — RoundedRectangle
  + radial wash + tint border + shadow.
- `SessionHistoryView` gains one new branch in the filter switch;
  the existing SD branch is untouched.
- 21 new tests across `AhCounterHistorySummaryTests` (19) and
  `AISettingsManagerPremiumConstantsTests` (2). All use the
  `Swift Testing` framework already in `NoumTests/NoumTests.swift`.

### Blocked / needs visual QA on device

- **Settings AI-usage card layout** — the right-column "X of Y"
  number + "X remaining" sublabel uses `.monospacedDigit()` so the
  cap and used counts align on changing digits. Needs a quick
  eyes-on at iPhone SE width to confirm the "Pro gets 40/day ·
  100/month" upgrade row doesn't truncate.
- **SD Result Menu affordance** — `Menu` on iOS shows a dropdown
  with check-style item icons. The visual difference between
  Menu (chevron implicit) and a plain Button is small enough that
  some users may not notice the affordance. Worth a hands-on tap to
  confirm the menu opens cleanly with `accessibilityHint` reading
  "Share this run, or your full Sudden Death track record."
- **Ah-Counter breakdown card** — the cleanest-rep cell tap should
  push the session detail view; visually identical to the SD
  per-difficulty row tap. Needs a real device confirm the back
  button + navigation bar render correctly.

## Files modified

- **New:** `Noum/AhCounterHistorySummary.swift` (~165 lines)
- **New:** `Noum/AhCounterHistoryBreakdownCard.swift` (~245 lines)
- **Modified:** `Noum/SettingsView.swift` (+~130 lines — `aiUsageCard`
  computed view + `aiUsageRow` helper + `aiUsageCardIsVisible` gate
  + `aiSettings` @StateObject + section injection in `body`)
- **Modified:** `Noum/PracticeSupport.swift` (+5 lines — lift
  `premiumMonthlyDebriefLimit` / `freeMonthlyDebriefLimit` to
  `static let` so the Settings CTA can read them)
- **Modified:** `Noum/SuddenDeathResultView.swift` (+~85 lines —
  `fullHistoryShareText` computed + `ShareKind` enum +
  `pendingShareKind` state + `shareMenu` @ViewBuilder + sheet
  binding via `resolvedShareText`)
- **Modified:** `Noum/SessionHistoryView.swift` (+15 lines — symmetric
  Ah-Counter branch in the filter switch)
- **Modified:** `NoumTests/NoumTests.swift` (+~230 lines — 21 new
  test cases across 2 structs)
- **Modified:** `HANDOFF.md` (this file)

## Branch

`Redesign` — committed and pushed per the user's brief.

Closes three of the deferred items from the M24 round-2 HANDOFF.
The remaining three (peer SD scores, `coachNoteRevealed` cleanup,
IM/Timed per-mode stat surfaces) stay deferred for the reasons
noted in **Scope** above.

The artifact a user can now hold:

1. **They can see why their coach went rule-based.** Settings →
   Account → AI usage shows the daily coach-notes budget +
   monthly debriefs budget, both as honest "X of Y" reads with
   the right-now-active cap (free vs Pro). No more "is the AI
   broken?" panic — the surface reads "rule-based today" in the
   correct tier register and points to the soft-degrade contract.
2. **They can share their full SD track record from the Result
   screen.** One tap on Share → pick "this run" (the original
   brag) or "full history (N runs)" — the cross-difficulty
   plain-text table the per-difficulty drill-down already wired.
   Zero transcript content (locked by test); only the outcome
   numbers the engine emitted at finalize.
3. **Their Ah-Counter track record reads as a per-mode hero.**
   Filter History to Ah-Counter → see the same shape SD shows:
   total reps, average fillers/min, clean reps, best-rep cell,
   and a trend chip when both 7-day windows have data. The
   cleanest-rep cell taps through to the source session, so the
   user can re-read the rep that produced their best read.

All three moves are vision-aligned on the personalization (#5),
believable-progress (#4), and "honest fallbacks" anti-goal pillars
of `docs/VISION.md`.

## Future moves

(Updated priority list — items closed in this push removed, items
that became natural next steps as a result of this push added:)

1. **Peer Sudden Death scores via `FriendsManager`.** Still
   blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated
   refactor pass with proper visual QA.
3. **Per-mode stat surfaces for IM and Timed.** Ah-Counter has
   proved the pattern (this push). IM's natural signal is the
   per-scenario trust/tension averages from
   `IMConversationDetails`; Timed's natural signal is the WPM
   distribution + per-difficulty average score. Both are sources
   already on `PracticeSession` — no new persistence, just
   aggregation.
4. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` (or expose a publisher) so the Settings
   AI-usage card refreshes mid-view when a background rep
   finalizes and consumes budget. Low priority because Settings
   is modal in practice.
5. **In-Summary "remaining today" hint** for users on free who
   are at >75% daily coach-note budget. Mirrors the existing
   `aiSettings.isApproachingLimit` hint in SummaryView, but on
   the daily-cap axis instead of the monthly-cap axis. The
   `AIRateLimiter` already publishes `remainingToday(kind:)`;
   just needs a one-line caller in SummaryView's tail copy.
6. **Cross-difficulty SD history export from Profile.** A user
   browsing their Profile / Achievements may want their full SD
   record without finishing a fresh run first. One `ShareLink`
   on a Profile row — same helper, new entry point.
