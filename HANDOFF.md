# HANDOFF — M24 deferred slate (round 2): AI rate limiter + SD per-difficulty drill-down + history export

## Scope

The previous push (commit `ad8b06a`) closed two of the M24 Tracks
2+3 "Future moves" — Voice-change retroactive read + Sudden Death
runs reachable from History. It left six items on the deferred list,
of which this push closes three: the AI generation gating that the
voice-change-regen path made urgent (#3), the per-difficulty
drill-down on the SD breakdown card (#5), and the plain-text history
export the user can paste outside the app (#4).

User brief, unchanged from prior push: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round: the voice-change retroactive read shipped
in `ad8b06a` introduced a new burn-rate axis — a user switching
voices in onboarding fires one AI regen per change, on top of the
per-rep AI calls — and the prior HANDOFF flagged it as a known risk
("a user is exploring voices in onboarding, that could be several
calls in quick succession"). This push closes that risk before it
hits a real account, while also landing the natural UX next steps
on the SD History surface that the prior push set up.

The remaining three "Future moves" from the prior HANDOFF stay
deferred for the same reasons noted there: friends Sudden Death
scores need `PublicProfileSnapshot` schema work + backend changes
(#1); `coachNoteRevealed` cleanup carries known animation-chain
regression risk (#2); and the "mode-specific stat surfaces for other
modes" item (#6) is bigger than this slate and best done as its own
M25 track.

## What shipped

### Track 1 — AIRateLimiter (#3 from prior HANDOFF)

New `Noum/AIRateLimiter.swift` — per-account, per-day budget for
outbound AI calls on the surfaces that fire on every rep + every
voice change. The post-rep Coach Note service was the immediate
motivator; the design generalises to any AI surface that wants
budget protection (a `Kind` enum gates which surfaces opt in).

#### Move 1 — `AIRateLimiter.consumeIfAllowed(kind:) -> Bool`

```swift
@MainActor
final class AIRateLimiter {
    static let shared = AIRateLimiter()

    enum Kind: String, CaseIterable {
        case postRepCoachNote
    }

    static let freeDailyCap: Int = 12
    static let premiumDailyCap: Int = 40
    static let debounceSeconds: TimeInterval = 1.5

    func consumeIfAllowed(kind: Kind) -> Bool { ... }
    func remainingToday(kind: Kind) -> Int { ... }
    func currentCap() -> Int { ... }
}
```

Atomic check-and-record: one call both verifies the cap + debounce
floor and commits the consumption. Callers don't need a separate
`record()` step (which would create a race in the burst path —
multiple voice changes in onboarding firing concurrent regen tasks).

Two gates in priority order:
1. **Debounce floor** (1.5s) — catches the onboarding burst. A user
   switching voice A→B→C in two seconds gets ONE AI regen, not
   three. The deterministic note still rewrites on each change
   (synchronous, no budget consumed); only the AI polish layer is
   throttled.
2. **Daily cap** — 12/day free, 40/day premium. The free cap was
   chosen against the heavy-user envelope: 10 reps/day + a handful
   of voice changes still fits inside 12. Premium gets 40 so a power
   user grinding all day never feels a difference.

Per-account scoped (account ID via `KeychainHelper`) and per-day
bucketed (`yyyy-MM-dd` in local calendar — matches the rollover
semantics of `AISettingsManager.resetIfNeeded` so a midnight
crossing resets both counters together). Test seam: `defaults`,
`accountIDProvider`, `now`, and the premium check are all
injectable so the rate logic runs hermetic against a custom
UserDefaults suite + frozen clock without touching `KeychainHelper`
or the live `PremiumManager` singleton.

#### Move 2 — `PostRepCoachNoteService.generate(input:)` gate

```swift
guard await rateLimiterAllows() else {
    return fallback
}
```

Inserted AFTER the locale + provider guards and BEFORE the
URLRequest construction, so the limiter only consumes budget when
an AI call is actually about to fire. On a deny, the function
returns the same deterministic fallback it would have returned with
no provider configured at all — the surface degrades silently to
the rule-based coach voice instead of the AI-polished one.

The gate is intentionally placed at this layer (not at the `Task`
launch site in `PracticeSupport.swift`) so EVERY caller benefits —
the original `recordPostRepCoachNote` finalize path AND the
`regenerateMostRecentNoteIfVoiceChanged` voice-change path both
flow through the same `generate(input:)` entry point. One gate,
two consumers, no chance of one path being protected and the other
silently bypassing.

#### Move 3 — `AuthManager` lifecycle wiring

Wired the new singleton into the existing per-account lifecycle so
the rate limiter behaves identically to the other per-account stores
from the user's perspective:

- `deferStoreSessionReset()` calls `AIRateLimiter.shared.endSession()`
  — clears in-memory debounce timestamps on sign-out so the next
  signed-in user's first call isn't blocked by the prior user's
  recent activity.
- `clearAllUserData(for:)` calls `AIRateLimiter.shared.deleteAllData(for:)`
  — sweeps the 30-day rolling window of `(kind × dayKey)` entries
  for the deleted account. Unlike the other stores listed by
  explicit key, the rate limiter's keys roll daily, so a method
  call is the cleanest path; the 30-day window covers "anything
  the rate limiter could possibly have written."

#### Tests — `AIRateLimiterTests` (9 cases)

- `freeUserExhaustsAtFreeCap` — burns 12 calls (with frozen clock
  advancing past debounce), 13th returns false, `remainingToday`
  reads 0.
- `premiumUserGetsHigherCap` — past the free cap, premium still
  allows; asserts `premiumDailyCap > freeDailyCap`.
- `debounceFloorBlocksRapidBurst` — first call allowed, second at
  same instant denied, call just inside window denied, call past
  window allowed.
- `dayRolloverResetsCounter` — burn cap on day 1, advance 30h,
  call on day 2 allowed (day key rolled).
- `remainingTodayDecreasesWithUse` — round-trip on the counter.
- `perAccountIsolation` — two limiters against the same defaults
  suite but different account IDs don't share counts; burning
  alpha leaves beta with full headroom.
- `deleteAllDataResetsAccountCounters` — `deleteAllData(for:)`
  restores `remainingToday` to the full cap.
- `endSessionClearsDebounceTimestamps` — locks the "next user's
  first call isn't blocked by prior user's burst" contract.
- `currentCapReflectsTier` — free returns `freeDailyCap`, premium
  returns `premiumDailyCap`.

All tests use a `Clock` holder that the limiter's `now` closure
reads from, so each test can advance time deterministically without
sleep calls or real-clock dependencies.

### Track 2 — Sudden Death per-difficulty drill-down (#5 from prior HANDOFF)

The prior push surfaced per-difficulty summary stats on the History
breakdown card (best / avg / clean per difficulty). This push lets
the user TAP a difficulty row to see every run at that difficulty —
the natural next step the prior HANDOFF called out as "pure
navigation work; no new persistence."

#### Move 1 — `SuddenDeathHistoryBreakdownCard.onSelectDifficulty`

Added an optional `((SuddenDeathDifficulty) -> Void)?` callback
parameter to the breakdown card. When provided, each row becomes a
`Button` wrapped in `.buttonStyle(.pressable)` (matches the
project-wide press-feedback contract from `Conventions to
preserve`), gains a trailing chevron, and reads an
`accessibilityHint` that the row opens the full run list. When
`nil`, the card renders exactly as before (read-only, no chevron,
no button affordance) — so the existing tests, previews, and any
other call site that wants only the breakdown summary compile
unchanged.

The interactive-vs-read-only distinction is gated on `onSelectDifficulty
!= nil`, not a separate `isInteractive` flag, so the API is
self-documenting: pass a handler iff you want the interactivity.

#### Move 2 — `Noum/SuddenDeathDifficultyRunsView.swift` (NEW)

The destination view. Renders:

- A hero header card with the difficulty title + run count +
  Best / Clean / Avg stat row (mirrors the breakdown card's three
  columns, scaled up to title-size for the detail surface).
- A scrollable list of EVERY run at that difficulty (not just the
  5 visible on the per-run Result screen), sorted newest-first.
  Each row carries the same outcome icon + rounds + best badge +
  filler chip + score chip vocabulary as
  `SuddenDeathRecentRunsCard` so the user reads the same shape
  across surfaces.
- An empty-state for "no runs at this difficulty yet" (a user
  could reach the view via an old deep link after deleting all
  their runs).
- A trailing-toolbar `ShareLink` that exports the full
  per-difficulty run history as plain text (Track 3).

Reads from `SuddenDeathRunHistoryStore.shared` via `@StateObject`,
defensively re-sorts newest-first so the view doesn't depend on
the store's invariant. Accessibility: each row carries an
`accessibilityLabel` derived from `SuddenDeathHistoryExport.outcomeLabel`
so VoiceOver reads the outcome by name, not just the icon.

#### Move 3 — Navigation wiring

- `AppDestination.suddenDeathDifficultyDetail(difficulty:)` added
  to `PracticeSupport.swift`. Hashable via the enum's automatic
  conformance (`SuddenDeathDifficulty` is a `String, Codable,
  Hashable` enum already).
- `ContentView.swift` `navigationDestination` switch — adds the
  case routing to `SuddenDeathDifficultyRunsView(difficulty:)`.
- `SessionHistoryView.swift` — when the Sudden Death filter is
  active, the breakdown card now passes an `onSelectDifficulty`
  closure that appends the destination onto the existing
  `navigationPath`. The view already takes a `navigationPath`
  binding, so the push lands without adding new state plumbing.

### Track 3 — Sudden Death history export (#4 from prior HANDOFF)

#### Move 1 — `Noum/SuddenDeathHistoryExport.swift` (NEW)

Pure helper. Two surface shapes:

```swift
static func formatPlainText(runs: [SuddenDeathRunRecord], difficulty: SuddenDeathDifficulty) -> String
static func formatPlainText(runs: [SuddenDeathRunRecord]) -> String
```

Single-difficulty variant produces a header + summary line + table
of every matching run, sorted newest-first. Full-history variant
groups by difficulty header (Easy → Medium → Hard, stable order so
the artifact reads the same way every time even when the user has
runs in different difficulties).

Both honor a hard contract that's locked by the test suite: the
export NEVER contains transcript content. `SuddenDeathRunRecord`
doesn't carry a transcript today (the engine stores only outcome
numbers), and the test `exportNeverContainsTranscriptContent`
guards against a future refactor that adds one and accidentally
leaks it. This matches the leaderboard rule from `docs/VISION.md`
("never publishes raw transcripts") — a History export should
match the same posture since the user might share it with anyone.

Date format: `yyyy-MM-dd` in the user's local calendar via
`Locale(identifier: "en_US_POSIX")` so the artifact reads cleanly
regardless of system locale. Relative phrases ("2 days ago") are
deliberately avoided — the export should read the same a year
later if the user pastes it from an archive.

#### Move 2 — Wired into `SuddenDeathDifficultyRunsView` toolbar

`ShareLink(item: exportText)` in the topBarTrailing slot. Hidden
when there are no runs at the difficulty (no point sharing "no
runs yet"). Carries an `accessibilityLabel` ("Share run history")
and `accessibilityIdentifier` ("history.suddenDeath.export") so
UI tests can target it.

#### Tests — `SuddenDeathHistoryExportTests` (10 cases)

- `emptyFullExportSaysNoRunsYet` / `emptyDifficultyExportSaysNoRunsAtThisDifficulty`
  / `emptyDifficultyExportAcrossMismatch` — three empty-input
  paths, each produces honest copy rather than empty text.
- `singleDifficultyExportFiltersOthers` — easy + medium + easy
  input filtered to easy renders only the two easy runs.
- `sortsNewestFirstWithinDifficulty` — older + newer input;
  newer row index < older row index in the rendered text.
- `headerRowMentionsAllColumns` — Date, Rounds, Fillers, Score,
  Outcome all present in the shared `headerRow()` string.
- `formattedRowIncludesAllFields` — score format `8/10`, outcome
  name `Survived`, best badge `best` all present for a best-
  flagged run.
- `failedOutcomesLabelHonestly` — `fillerOverload`, `tooShort`,
  `timeoutBeforeStart` all produce non-empty labels that aren't
  `Survived`.
- `fullExportGroupsByDifficultyHeader` — `--- Easy`, `--- Medium`,
  `--- Hard` headers present when runs exist at each.
- `fullExportTotalCountReflectsAllRuns` — total run count matches
  input length.
- `fullExportOrdersDifficultiesStably` — even when input is
  shuffled, the export renders Easy → Medium → Hard in order.
- `exportNeverContainsTranscriptContent` — the row format doesn't
  contain "transcript" or "said" (the obvious markers that would
  appear if a future refactor leaked transcript content).

## What did NOT change

- **`PostRepCoachNoteService.deterministicNote`** — the fallback
  is the same content path as before. The rate limiter only gates
  the AI upgrade; the deterministic path always runs and always
  returns a note.
- **`PracticeSessionFinalizer.recordPostRepCoachNote`** — finalize
  still writes the deterministic note synchronously and fires the
  AI upgrade as a detached Task. The rate limiter intervenes
  inside `generate(input:)`; the call site doesn't need to know
  about it.
- **`PracticeSessionFinalizer.regenerateMostRecentNoteIfVoiceChanged`**
  — voice-change path is identical to the prior push; it also
  routes through the same `generate(input:)` so the limiter
  applies to BOTH the per-rep and the voice-change AI calls
  without duplicating the gate.
- **`SuddenDeathHistoryBreakdownCard.swift`** core layout — the
  rows, stat columns, accessibility labels, and hero background
  treatment are unchanged. Only the new `Button` wrap, chevron,
  and `onSelectDifficulty` parameter are additive.
- **`SuddenDeathRecentRunsCard.swift`** — the Result-screen card
  is untouched. The drill-down view re-implements the row shape
  rather than extracting a shared component because the two
  surfaces have different anchor semantics (`currentRunID` on
  Result, absolute-date label on drill-down).
- **`SessionHistoryView` core layout** — only the breakdown card
  invocation gained the closure argument.

## Risks

1. **Rate limiter cap chosen by spec, not by telemetry.** The
   project doesn't have a way to observe real per-user AI call
   counts on the deployed build. 12/day free was chosen against
   the "10 reps + 2 voice changes" heavy-user envelope; if a
   small number of users routinely exceed that, the cap reads as
   a quiet degradation rather than honest behavior. Two
   mitigations are available without a code change: bump
   `freeDailyCap` (one constant) or surface `remainingToday` in
   a Settings row so users at least know why the AI polish
   dropped today. Both are explicitly out of scope for this push
   to keep the user-visible surface unchanged.
2. **Day rollover via local calendar** — a user travelling across
   timezones could see the day key roll mid-rep. The existing
   `AISettingsManager` uses the same approach, so this is
   consistent with the rest of the app. The day key reads
   `Calendar.current` at write time; a user crossing midnight by
   plane gets a fresh budget early, which is a strictly user-
   favorable behavior.
3. **`SuddenDeathDifficultyRunsView` reads `SuddenDeathRunHistoryStore.shared`
   directly** — couples the new view to the singleton rather than
   accepting an injected store. Followed the same pattern as
   `SessionHistoryView` (which also reads stores directly via
   `@StateObject`), so it's consistent with the codebase; a future
   refactor toward dependency injection across all history views
   would land both at once.
4. **Plain-text export format may not survive future row-shape
   changes** — the format is locked by the test suite at the
   column level (header mentions Date/Rounds/Fillers/Score/Outcome),
   but not at the exact whitespace/separator level. A future change
   to use commas instead of pipes would slip past the tests. This
   is by design: the contract is "user can read it", not "exact
   byte-level format."

## Verification

### Implemented (compiler-locked, source-only)

- `AIRateLimiter` new file compiles standalone (no SwiftUI
  dependencies, no Combine imports, no `@available` mismatches
  with existing code).
- `PostRepCoachNoteService.generate` gate inserted at the right
  layer (after locale + provider checks, before request
  construction) — preserves the existing fallback contract on every
  deny path.
- `SuddenDeathHistoryBreakdownCard.onSelectDifficulty` is
  default-nil so the existing call site in `SessionHistoryView`
  could have remained unchanged; the SessionHistoryView call site
  was explicitly updated to pass the closure so the new affordance
  is live, but ANY external call (e.g. a future preview or
  test) that omits the argument continues to compile.
- `AppDestination.suddenDeathDifficultyDetail(difficulty:)` is
  `Hashable` (string-raw enum associated value), so the
  `navigationPath.append(...)` call type-checks. The exhaustive
  `switch` in `ContentView.navigationDestination` covers the new
  case so the compiler enforces "no new destination drops on the
  floor."
- `SuddenDeathHistoryExport` is pure Foundation, no SwiftUI
  dependencies — the helper file can be linked into the test target
  without dragging in UI types.
- 19 new tests across `AIRateLimiterTests` (9) and
  `SuddenDeathHistoryExportTests` (10). All use the `Swift Testing`
  framework already in `NoumTests/NoumTests.swift`; clock injection
  via a `Clock` holder mirrors a pattern already used in other
  rate-limit-style tests in this codebase.

### Blocked / needs visual QA on device

- **Per-difficulty drill-down navigation** — `NavigationStack` push
  via `navigationPath.append` works the same way as the existing
  `sessionDetail` destination, but the final visual stack on a
  real device needs eyes-on (toolbar back button placement, hero
  card padding under the inline navigation bar). No simulator-
  available risk; the layout is plain SwiftUI components used
  elsewhere.
- **`ShareLink` activity sheet** — the share sheet itself is iOS-
  managed; the `String` content path is the only project-level
  concern and it's tested. The actual presentation of the sheet
  (Messages / Mail / Notes destinations) is iOS behavior.
- **Rate limiter under real load** — the unit tests cover the
  decision logic deterministically, but the live behavior with a
  real `PremiumManager.shared.isPremium` read and concurrent
  finalize + voice-change paths needs at least one device
  validation. Two paths to exercise:
  1. Finish 13 reps in one day, observe that note #13 reads
     deterministic-fallback voice instead of AI-polished.
  2. Switch voice 5 times in onboarding within 5 seconds, observe
     that only 1-2 AI calls fire (network panel) instead of 5.

## Files modified

- **New:** `Noum/AIRateLimiter.swift` (~200 lines)
- **New:** `Noum/SuddenDeathHistoryExport.swift` (~120 lines)
- **New:** `Noum/SuddenDeathDifficultyRunsView.swift` (~250 lines)
- **Modified:** `Noum/PostRepCoachNoteService.swift` (+12 lines —
  one guard + one MainActor helper)
- **Modified:** `Noum/SuddenDeathHistoryBreakdownCard.swift`
  (~30 lines — optional callback, button wrap, chevron, hint)
- **Modified:** `Noum/SessionHistoryView.swift` (+5 lines — pass
  the closure into the breakdown card)
- **Modified:** `Noum/PracticeSupport.swift` (+5 lines — new
  `AppDestination` case)
- **Modified:** `Noum/ContentView.swift` (+2 lines — new
  navigation destination case)
- **Modified:** `Noum/AuthManager.swift` (+5 lines — lifecycle
  wiring for AIRateLimiter)
- **Modified:** `NoumTests/NoumTests.swift` (+~300 lines — 19 new
  test cases across two structs)
- **Modified:** `HANDOFF.md` (this file)

## Branch

`Redesign` — committed and pushed per the user's brief.

Closes three of the six "Future moves" from the M24 Tracks 2 + 3
HANDOFF. The remaining three (peer Sudden Death scores,
`coachNoteRevealed` cleanup, mode-specific stat surfaces for
Ah-Counter / IM / Timed) stay deferred for the reasons noted in
**Scope** above.

The artifact a user can now hold:

1. **Their AI coach call rate is honest and bounded.** The
   £130/hr coach still delivers a personalized note after every
   rep — the rate limiter only throttles the hidden AI polish
   layer, so the deterministic voice fallback (which already
   reads in the user's chosen voice via `CoachPersona`) takes
   over on heavy days. No user-visible failure mode; the worst
   case is "rule-based note today" instead of "AI-polished note
   today."
2. **Their Sudden Death track record is drill-downable.** From
   the History tab, filter to Sudden Death, tap any difficulty
   row in the breakdown card → see every run at that difficulty
   with absolute dates, full stats, and the new-best badges
   the engine flagged at record time.
3. **Their Sudden Death history is portable.** From the
   per-difficulty drill-down, tap the share icon → get a
   plain-text table they can paste into Notes, Messages, or an
   email. Zero transcript content (locked by test); only the
   outcome numbers the engine wrote at finalize.

All three moves are vision-aligned on the personalization (#5),
believable-progress (#4), and "honest fallbacks" anti-goal pillars
of `docs/VISION.md`.

## Future moves

(Carried over from the prior HANDOFF, unchanged in priority order
where still relevant:)

1. **Peer Sudden Death scores via `FriendsManager`.** Still
   blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated
   refactor pass with proper visual QA, not a drive-by.
3. **History-tab integration — full per-difficulty drill-down.**
   ✅ Closed in this push.
4. **Mode-specific stat surfaces for History.** Once the SD
   pattern is proven (now is the time, with both the breakdown
   card AND the drill-down in place), Ah-Counter, IM, and Timed
   could each carry their own mode-specific stat surface
   (Ah-Counter: filler-rate trend; IM: trust/tension averages;
   Timed: WPM distribution). The `SuddenDeathHistorySummary` +
   `SuddenDeathDifficultyRunsView` shape generalises naturally
   — copy the pattern, swap the source store.
5. **Rate limiter settings surface.** A row in Settings → AI Coach
   that surfaces `AIRateLimiter.remainingToday(kind:)` so users
   on a heavy day know why their coach went rule-based. Could
   double as the "upgrade for more AI calls" rail without ever
   blocking practice. Pure read-side; no new state.
6. **Sudden Death history export from the Result screen.** The
   per-difficulty drill-down has the share affordance, but a
   user on the Result screen who wants the cross-difficulty
   history has to navigate History → filter → tap a difficulty
   → share. A direct "share my full SD history" affordance on
   Result would be one more `ShareLink` with the cross-difficulty
   variant of `SuddenDeathHistoryExport.formatPlainText(runs:)`
   — already in place; just needs a UI hook.
