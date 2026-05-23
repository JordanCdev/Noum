# HANDOFF — M24 Track 2 + Track 3: Summary dedupe + Sudden Death run history

## Scope

The previous session shipped **M24 Track 1** (`18d13a9`) — Coach
Persona + Post-Rep Coach Note Service — and explicitly deferred
**Track 2 (Summary dedupe)** and **Track 3 (Sudden Death scoring
view + SuddenDeathRunHistoryStore + friends scores)** to the next
session. This push picks up both deferred tracks.

User brief: "continue from the existing TO-DO, ensure working
towards getting app towards the vision plan, and all-round A+, make
my dream come true too, ensure working on the redesign branch."

Translation: close the named TODOs (Track 2 + Track 3), keep the
£130/hr personal coach vision intact (`docs/VISION.md` pillar #5 —
Personalized coaching + pillar #4 — Believable progress), and ship
on `Redesign`. Friends scores via `FriendsManager` is descoped from
Track 3 because the `PublicProfileSnapshot` schema doesn't carry
Sudden Death scores today — adding that would require backend +
peer-sync work that's substantially larger than the rest of Track 3
and would block the local-history surface unnecessarily. Local run
history lands here; cross-account peer scores remain a future move.

## What shipped

### Track 2 — Summary dedupe

The Summary surface had four coach-voice surfaces stacked on top of
each other after M24 Track 1 landed: the new hero `CoachReadCard`,
the hero `WhatYouDidWellCard` (momentum), the hero `WhatToImprove-`
`Card` (leverage), the hero `YourNextMoveCard` (next step), and
THEN inside the expandable details, the legacy `CoachNoteCard`
re-rendered the same momentum/leverage/nextStep triple again. Five
coach voices, three of them saying the same thing. Track 2 drops
`CoachNoteCard` from the details disclosure. The AI-backed
`AISessionDebriefCard` stays — it sources a different read
(post-hoc AI insight, not the templated mid-rep coach note) so it
adds genuine depth rather than restating.

**Move**: `Noum/SummaryView.swift` `expandableDetailsSection` —
`CoachNoteCard(coachNote:coachNoteRevealed:)` removed from the
`if !isIMSummary` block; explanatory comment updated.

The `coachNoteRevealed` `@State` and the staggered reveal animation
chain stay in place (low blast radius — touching the celebration
timing chain risks bleeding into unrelated reveals) but no longer
drive a visible surface. The `coachNote` computed property still
feeds the M14 hero cards (`WhatYouDidWellCard` / `WhatToImprove-`
`Card` / `YourNextMoveCard`) so it remains in the file.

### Track 3 — Sudden Death run history

The deferred TODO named "`SuddenDeathRunHistoryStore` + 'Previous
Runs' section in `SuddenDeathResultView`." Lands here as three new
files plus a result-screen wiring pass.

#### Move 1 — `Noum/SuddenDeathRunRecord.swift` (NEW)

Value type carrying the honest facts of a completed Sudden Death
run: `id` + `completedAt` + `difficulty` + `roundsSurvived` +
`totalFillers` + `totalWords` + `score` + `xpEarned` +
`finalOutcome` (the `RoundOutcome` that ended the run) +
`wasNewBestAtTime`. Codable so the store can persist; `Equatable`
+ `Identifiable` so SwiftUI can render lists by `id`. The
`wasNewBestAtTime` flag is snapshotted at record-time so a later
run beating it doesn't retroactively un-flag the prior peak — the
list badge represents "this WAS the best when it happened," which
is the honest read.

Extends `RoundOutcome` with `Codable` conformance via a custom
single-key `{ "kind": "survived" }` payload so the enum can ride
inside the run record without polluting the rest of the codebase
(no other site currently encodes `RoundOutcome`; verified).

#### Move 2 — `Noum/SuddenDeathRunHistoryStore.swift` (NEW)

Per-account, bounded persistence for `SuddenDeathRunRecord` values.
Mirrors the `PostRepCoachNoteStore` testable-init pattern
(`defaults:` + `accountIDProvider:`) instead of the pure-singleton
pattern other stores use, because the service path needs hermetic
tests and a custom UserDefaults suite makes that trivial without
touching `KeychainHelper`.

Capacity contract: 60 runs total per account. With three
difficulties active that's ~20 per difficulty before oldest rolls
off — plenty for the result-screen "Recent Runs" section (shows
last 5 for the current difficulty) and for any future History tab
read-through. Bounded to keep the per-account UserDefaults blob
light.

API:
- `record(_:)` — de-dupes on `id` so a fast double-mount of the
  result view doesn't double-record. Sorted newest-first by
  `completedAt`; oldest evicted at the cap.
- `recentRuns(difficulty:limit:)` — filter + slice for the result
  surface; `limit: nil` returns the full per-difficulty history.
- `allRuns` — escape hatch for future surfaces.
- `clearAll()` — wipe for the current account.
- `reloadForCurrentAccount()` / `endSession()` / `deleteAllData(for:)`
  — lifecycle hooks wired through `AuthManager`.

The store sits ALONGSIDE the existing `SuddenDeathHighScoreStore`
(which remains the single source of truth for the best round count
per difficulty). The high-score store is the API for "what's the
peak"; this store is the API for "what did the last N runs look
like." Both are written from the same `recordRun` call site in
`SuddenDeathResultView.resolveHighScore` so they can't drift.

#### Move 3 — `Noum/SuddenDeathRecentRunsCard.swift` (NEW)

Compact "last N runs at this difficulty" surface for the result
screen. Honest evidence: each row is the actual run the engine
wrote at finalize — rounds survived, filler count, the outcome
that ended the run, the date. No invented trend lines, no
"you're improving!" copy unless the data actually supports it.

Vision-aligned (`docs/VISION.md` pillar #4 — Believable progress):
the user sees their own track record, not a coach-narrated story
about it. The current run renders FIRST and is visually anchored
("Just now" label + filled-in accent background tint) so the user
has a clear "this run vs. those" comparison without having to read.

Row layout:
- Outcome indicator (red ✕ on failure, green ✓ on survival)
- Rounds survived (e.g., "5 rounds") + optional "BEST" trophy
  chip when `wasNewBestAtTime` is true at the record-time snapshot
- Relative date label ("Just now" for the current run, "2 days
  ago" / "5 hr ago" for prior runs via `RelativeDateTimeFormatter`)
- Inline stat chips: filler count (tinted green at zero), score/10

Footer hint: one-line honest read comparing the current run to the
median of priors. Only emits a phrase when the data clearly
supports it:
- Current run ≥ median + 2 → "Above your usual run at <Difficulty>."
- Current run ≤ median − 2 → "Below your usual run at <Difficulty>.
  One rep — not a trend." (the "one rep — not a trend" tail is
  vision anti-goal guard against doomspeak on a single bad rep)
- Otherwise → no hint rendered

Self-hides entirely when `runs.count < 2` (a single-row history is
just a restatement of the stats row above — no signal).

#### Move 4 — `SuddenDeathResultView` integration

- New `@ObservedObject var runHistoryStore: SuddenDeathRunHistoryStore`
  prop on the result view so the card re-reads on store updates.
- New `@State private var currentRunID: UUID = UUID()` — stable id
  pinned for the run we just finished. Used as the record id when
  writing and as the visual anchor (filled-in tint) when rendering
  the row in the "Recent Runs" list. Stable across re-mounts within
  the same view lifecycle so `record(_:)`'s id-based de-dupe works
  even if the result view paints twice (e.g., reduce-motion path).
- New `SuddenDeathRecentRunsCard(...)` slotted between the
  `roundBreakdown` and the `xpChip` — sits below the immediate
  stats but above the XP reward, so the visual hierarchy reads:
  "here's what just happened → here's how it compares to your last
  runs → here's your reward."
- `resolveHighScore()` extended: alongside the existing
  `highScoreStore.recordRun(...)` call, build a `SuddenDeathRun-`
  `Record` with the `wasNewBestAtTime` flag snapshotted from the
  high-score store's return value, then call
  `runHistoryStore.record(record)`. Single call site; the two
  stores can't drift.

#### Move 5 — `SuddenDeathPracticeView` call site

`resultScreen(result:)` now passes `runHistoryStore: .shared`
alongside the existing `highScoreStore: .shared`. No other call
sites for `SuddenDeathResultView` exist (grep'd to confirm).

#### Move 6 — `AuthManager` lifecycle + wipe

`AuthManager.deferStoreReloadForCurrentAccount` now reloads
`SuddenDeathRunHistoryStore.shared`; `deferStoreSessionReset`
calls its `endSession()`. `clearAllUserData(for:)` adds:
- `suddenDeath.runHistory.<accountID>` (M24 Track 3)

#### Move 7 — Test suite

13 new tests in a new `SuddenDeathRunHistoryStoreTests` suite:

- `recordAndFetchRoundTrip` — every field survives the round trip
  including the `wasNewBestAtTime` flag.
- `recordDedupesOnID` — second record with same id replaces;
  newer `completedAt` wins on the replace.
- `capacityEvictsOldestByCompletedAt` — fills cap + 5 records,
  asserts the 5 oldest dropped and the newest 5 retained.
- `recentRunsFiltersByDifficulty` — mixed-difficulty store
  returns only the requested difficulty, newest-first.
- `recentRunsHonorsLimit` — `limit: 5` returns 5 newest;
  `limit: nil` returns everything.
- `recentRunsLimitLargerThanAvailableReturnsAll` — 2 runs +
  `limit: 100` returns 2.
- `emptyHistoryReturnsEmpty` — cold-start contract.
- `clearAllEmptiesStore` — `clearAll()` empties.
- `deleteAllDataWipesByAccountID` — auth-wipe contract.
- `perAccountKeyIsolation` — two stores against the same suite
  but different account IDs don't see each other's runs.
- `reloadReadsPersistedRuns` — writer + fresh reader against the
  same suite + account loads from disk.
- `endSessionClearsInMemoryWithoutErasingDisk` — sign-out
  reset doesn't erase the persisted record.
- `roundOutcomeRoundTripsForEveryCase` — every `RoundOutcome`
  case encode/decodes through the new `Codable` extension.
- `runRecordRoundTripsEveryField` — field-by-field decode
  integrity guard against a future `CodingKeys` oversight
  silently dropping a stat.

## What did NOT change

- **No new modes or surfaces beyond the named TODOs.** Track 2
  drops a card; Track 3 adds one surface (Recent Runs) on an
  existing screen. Neither introduces a new screen, a new tab,
  or a new notification.
- **No friends scores.** Deferred — the `PublicProfileSnapshot`
  schema doesn't carry Sudden Death scores today, so wiring that
  in requires backend changes that are out of scope for this
  push. Captured as a future move (#5 below).
- **No XP, no streak, no celebration on a "Recent Runs" view.**
  The surface is read-only history, not a new gamification loop.
  Vision anti-goals (hollow streaks, fake unlocks) respected.
- **No new tracking signals.** The store reads the run record the
  engine already wrote at finalize; no new sensors, no new
  analytics. The data was already there — it just wasn't
  surfaced anywhere the user could see it.

## Risks

1. **The `coachNoteRevealed` animation chain still fires** even
   though its only consumer (`CoachNoteCard`) is gone. Cost: a few
   `withAnimation` calls per Summary mount that don't drive any
   visible change. Could be cleaned up in a future pass but the
   chain is intertwined with other reveals; touching it risks
   regressing the celebration timing. Left alone for safety.
2. **`SuddenDeathRecentRunsCard` reads `RelativeDateTimeFormatter`
   per row on every paint.** Formatters are heavy. With 5 rows per
   card and re-renders driven by `@ObservedObject` + `@State`, this
   is a minor allocation hit on the result screen. Acceptable
   today (the result screen paints once per session and isn't a
   hot path), but if it ever becomes one, hoist the formatter to a
   `static let` on the card.
3. **The "BEST" badge can collide visually with the "New high
   score" hero badge on the new-best run.** Both render on the
   same screen at the same time — the new-best run gets the hero
   badge above the stats AND a "BEST" chip on its own row. That's
   intentional (the chip is per-row context for someone scanning
   the list), but a sharper-eye design pass might prefer to drop
   the in-list chip on the current run since the hero badge
   already says it. Trivial to gate.
4. **The "Above/Below your usual run" hint uses the median of the
   prior runs.** For a user who started on Easy and just moved to
   Hard, the first Hard run lands without context (only 1 row).
   The card self-hides at `runs.count < 2`, but the hint also
   needs ≥ 3 runs total at that difficulty before it fires. Sub-
   threshold users see the list with no footer hint — which is
   the right honest behavior, but worth knowing.
5. **The `RoundOutcome` Codable extension is additive but global.**
   If a future caller wants a different encoding shape (e.g.,
   bare-string rather than the `{"kind": "..."}` payload), they
   can't get one without breaking persisted records. Worth
   flagging in case the schema ever needs to evolve.

## Verification

### Implemented (compiler-locked, source-only)

- `SuddenDeathRunHistoryStore` per-account persistence + cap +
  de-dupe + lifecycle (13 tests in `SuddenDeathRunHistoryStoreTests`)
- `SuddenDeathRunRecord` + `RoundOutcome` Codable round-trip
  (2 tests in the same suite)
- `SuddenDeathResultView` integration — call site signature
  updated; `resolveHighScore` writes to both stores at the same
  point; the new card slots into the existing layout between
  `roundBreakdown` and `xpChip`.
- `SummaryView.expandableDetailsSection` — `CoachNoteCard`
  removed; `AISessionDebriefCard` retained.
- `AuthManager` — reload + endSession + wipe-list extended for
  `SuddenDeathRunHistoryStore` and the new `suddenDeath.run-`
  `History.<accountID>` UserDefaults key.

### Blocked / needs visual QA on device

No Swift toolchain in this container. Visual QA wants a build:

1. **Track 2 — Summary dedupe** — finish a Timed rep, expand the
   "Session Details" disclosure, confirm only `AISessionDebrief-`
   `Card` (and the speech-quality cards below it) render where
   `CoachNoteCard` used to.
2. **Track 3 — Recent Runs card** — finish 2+ Sudden Death runs at
   the same difficulty in one sitting, confirm the card renders
   between `roundBreakdown` and the XP chip on the second run.
   Verify the current row is tinted, "Just now" label is visible,
   and prior rows show relative dates.
3. **Track 3 — Per-difficulty filtering** — finish a Sudden Death
   run on Easy, then switch to Hard and finish another, confirm
   the Hard result screen shows ONLY the Hard run (and the prior
   Hard runs if any) — Easy runs must not appear.
4. **Track 3 — BEST badge** — finish a record-breaking run,
   confirm the row gets the trophy "BEST" chip; finish a worse run
   afterward, confirm the prior row keeps the badge and the new
   row doesn't get one.
5. **Track 3 — Honest trend footer** — finish 3+ runs at the same
   difficulty with a clearly high last run, confirm "Above your
   usual run at <Difficulty>." appears; finish a clearly low last
   run, confirm the "below… one rep — not a trend" copy appears.
   Mid-pack runs should NOT render a footer phrase.
6. **Track 3 — Auth wipe** — sign out + sign back into a fresh
   account, confirm the new account starts with no run history
   and the prior account's runs never leak across.

### Assumptions

- `KeychainHelper.load(key: "NoumAccountID")` returns a stable
  string for the current account (matches every other per-account
  store in the codebase).
- `SuddenDeathHighScoreStore.recordRun` returns `true` exactly
  when the round count strictly exceeds the prior best for that
  difficulty (verified in `SuddenDeathHighScoreStoreTests` —
  pre-existing).
- `PressureSessionResult.score` + `.xpEarned` are computed
  properties on the engine struct (`PressureTimerEngine.swift:271,
  283`) — both stable across the result lifecycle.
- The single mount point of `SuddenDeathResultView` is
  `SuddenDeathPracticeView.resultScreen(result:)`. No other call
  sites surfaced via grep.

### What was checked

- `grep`'d `RoundOutcome` across the project — no existing Codable
  conformance or encoding usage; the additive extension is safe.
- `grep`'d `CoachNoteCard` across the project — only call site
  was `SummaryView.expandableDetailsSection`. Removing the call
  site doesn't strand any other consumer.
- `grep`'d `SuddenDeathResultView` — single call site in
  `SuddenDeathPracticeView`. The new `runHistoryStore` argument
  is wired there.
- Re-read `AuthManager.clearAllUserData` to confirm key ordering
  + comment continuity; the M24 Track 3 key sits right after the
  Track 1 key for chronological continuity.
- Re-read `PostRepCoachNoteStoreTests` patterns and matched them
  for `SuddenDeathRunHistoryStoreTests` so test maintenance feels
  uniform — same `freshStore()` helper, same suite + account-ID
  injection pattern, same `@MainActor` + `@available(iOS 17.0, *)`
  decoration.

## Files modified

- `Noum/SuddenDeathRunRecord.swift` — NEW. Value type + `RoundOut-`
  `come` Codable conformance.
- `Noum/SuddenDeathRunHistoryStore.swift` — NEW. Per-account
  persistence.
- `Noum/SuddenDeathRecentRunsCard.swift` — NEW. SwiftUI compact
  history card.
- `Noum/SuddenDeathResultView.swift` — `runHistoryStore` prop +
  card slot between `roundBreakdown` and `xpChip`; `resolve-`
  `HighScore` writes to both stores.
- `Noum/SuddenDeathPracticeView.swift` — call site passes
  `runHistoryStore: .shared`.
- `Noum/SummaryView.swift` — `CoachNoteCard` removed from
  `expandableDetailsSection`; explanatory comment updated.
- `Noum/AuthManager.swift` — reload + endSession + wipe-list
  extended for `SuddenDeathRunHistoryStore`.
- `NoumTests/NoumTests.swift` — 13 new tests appended in
  `SuddenDeathRunHistoryStoreTests`.
- `HANDOFF.md` — this file.

## Branch

`Redesign` — committed and pushed per the user's brief.

Closes M24 Track 2 and Track 3 of the M24 deferred slate. The
remaining items in the deferred TODO can run in parallel in the
next session if bandwidth exists.

The artifact a user can now hold:
1. **Cleaner Summary**: the post-rep coach voice doesn't repeat
   itself three different ways across the same screen anymore.
2. **A track record**: after every Sudden Death run, the user can
   see their last 5 runs at the same difficulty without leaving
   the result screen — and the comparison is honest data, not
   coach narration.

Both are vision-aligned moves on the "Believable progress" pillar
of `docs/VISION.md` — visible improvement across sessions, no fake
gamification.

## Future moves

1. **Peer Sudden Death scores via `FriendsManager`.** Extend
   `PublicProfileSnapshot` to carry per-difficulty best round
   counts; render a "Friends · This week" row in `SuddenDeath-`
   `RecentRunsCard` (or below it) when at least one friend has a
   recent best. This was the named Track 3 item; descoped here
   because the snapshot schema change touches backend code that's
   out of scope for a single-session push.
2. **History tab integration.** `SuddenDeathRunHistoryStore.all-`
   `Runs` is exposed for a future History tab read-through —
   could power a "Sudden Death" filter on the History screen
   showing the full per-difficulty run history.
3. **`coachNoteRevealed` cleanup.** Now that `CoachNoteCard` is
   gone, the `@State` and its animation chain in `SummaryView`
   could be removed. Low blast radius but non-trivial because
   the animation chain interleaves with other reveal timings.
4. **`SuddenDeathRunHistoryStore` history-export.** A "Share my
   run history" affordance on the Result screen — plain-text
   table of last 10 runs. No fake-social fabrication (anti-goal
   compliant), just data the user can paste anywhere.
5. **AI generation gating** (carried over from M24 Track 1 future
   moves). Gate `PostRepCoachNoteService.generate` AI path behind
   a Premium flag or per-day rate limit so a heavy user doesn't
   burn 30 AI calls a day on essentially the same delivery
   pattern.
6. **Voice-change retroactive read** (carried over from M24 Track 1
   future moves). When the user changes their `speakingStyleGoal`,
   queue a one-shot AI regeneration of the most-recent note in the
   new voice so the Ask Noum chat coach doesn't quote a prior-
   voice note as the user's current voice.
