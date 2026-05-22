# HANDOFF — Growth Library (Profile-launched proof timeline)

## Scope

This push closes the open follow-on flagged in the previous
HANDOFF — making the per-account `ProofMomentArchive` *visible* to
the user. The previous push (proof-aware coaching context) put the
archive on disk and into the Ask Noum system prompt, but the user
could only see a count chip on Profile; the underlying evidence —
verbatim transcript moments + technique tags + voice-shaped claims —
stayed invisible.

Files in this push:

- `Noum/GrowthLibraryView.swift` (NEW, ~210 LOC) — Profile-launched
  scrollable timeline rendering the archive as quote cards grouped
  by ISO week.
- `Noum/ProofMomentArchive.swift` (+~70 LOC) — new
  `nonisolated static weeklyGroups(from:now:calendar:)` pure helper
  + instance wrapper `weeklyGroups(now:calendar:)` for the view +
  private `weekLabel(...)` formatter. Pure-function; testable
  without SwiftUI.
- `Noum/PracticeSupport.swift` (+1 case) — `AppDestination.growthLibrary`
  threads the new destination through the existing nav stack
  contract.
- `Noum/ContentView.swift` (+5 LOC) — `.navigationDestination(...)`
  case for `.growthLibrary` → `GrowthLibraryView()`; deep-link router
  case for `"growth"` / `"library"` hosts.
- `ProfileView.swift` (~+10 / -3 LOC) — wraps `insightsBankedChip` in
  a `NavigationLink(value: AppDestination.growthLibrary)`, adds a
  chevron + accessibility identifier `profile.insightsBanked.link`.
  Cold-state behaviour unchanged (chip stays hidden when archive is
  empty, so the link is reachable only when there's something to
  show).
- `NoumTests/NoumTests.swift` (+~115 LOC) — six new tests in
  `GrowthLibraryWeeklyGroupingTests` (no MainActor — the helper is
  pure / nonisolated).
- `docs/CURRENT_STATE.md` (header breadcrumbs + new Growth Library
  bullet + deep-link route list).
- `HANDOFF.md` (this file, rewritten).

## What changed

### Move 1 — `ProofMomentStore.weeklyGroups(from:now:calendar:)`

Bucketing logic lives on the store as a `nonisolated static` so
tests can drive it without crossing the MainActor boundary the
class normally requires. The instance method `weeklyGroups()` is a
thin wrapper that the SwiftUI view binds to (MainActor-context-safe
since `records` is read from the store's published state).

Contract:

- `dateInterval(of: .weekOfYear, for: sessionDate)?.start` is the
  bucket key. Falls back to `startOfDay(for:)` if the calendar
  somehow returns nil — defensive, untriggerable in practice.
- Buckets emerge newest-week-first (keys sorted descending).
- Inside each bucket, records sort most-recent-first by
  `proof.sessionDate` (not `addedAt` — a re-fetch of an old
  session's proof shouldn't make it look fresh; the surface is
  about *when the user spoke*, not when the AI re-ran).
- Labels: "This week" when the bucket key matches the current
  week's start; "Last week" when the bucket key matches the
  current week's start minus 7d; "Week of MMM d" otherwise, with
  a year suffix when the bucket year differs from the current
  year ("Week of Dec 14, 2025"). So a January 2025 vs January
  2026 entry can never blur.

### Move 2 — `GrowthLibraryView`

Scrollable view with three states:

1. **Empty archive** — honest empty card. "Nothing banked yet" +
   short coach-voice explanation. No fabricated quotes, no fake
   placeholder rows.
2. **Populated** — header eyebrow "YOUR EVIDENCE" + sectionHero
   "N banked moments" + secondary body explaining the surface.
   Then week sections, each with a micro-tracked label and one
   quote card per record.
3. **Quote card** — technique chip (Pro-purple pill at 12% alpha
   over `AppColor.cardBackground`) + relative date (tertiary, right-
   aligned) + verbatim quote (Typography.body italic, prefixed by
   a muted `quote.opening` glyph) + claim (caption, secondary) +
   honest source badge:
     - `sparkles` + Pro-purple + "Coach reading" → AI-backed proof.
     - `checkmark.seal` + brandBlue + "Pattern match" →
       deterministic-template proof.
   The badge replaces the previous unsurfaced `isAIBacked` flag with
   a label the user can read.

Visual register:
- Card chrome matches the existing `peakRatingWallLink` shape
  (rounded rect, `AppColor.cardBackground`, hairline overlay).
- Stroke uses `AppColor.pro.opacity(0.16)` so the cards read as
  the coach's tracking, not the brand-blue practice-loop register.
- Background gradient matches Profile's `LightGradientBackground`
  family so it feels like the same surface family.

### Move 3 — `AppDestination.growthLibrary` + deep link

- One new case in `enum AppDestination`. Hashable conformance is
  free (no associated value).
- `ContentView.swift`'s `navigationDestination(for: AppDestination.self)`
  switch gains the new case → `GrowthLibraryView()`.
- `consumeDeepLink(_:)` gains a `"growth"` / `"library"` host case
  matching the existing `noum://` family. The deep link uses
  `navigationPath.append(...)` (no `NavigationPath()` reset),
  matching `noum://path` and `noum://league` which behave the same
  way — these are *within-tab* deep links rather than top-level
  resets. (Compare to `noum://ask`, which DOES reset.)
- The current Profile entry-point is a tap on the existing chip;
  no Home card is added in this push. Discoverability ladder:
  Profile chip → library → tap an evidence card (no follow-on
  navigation yet — quotes are read-only). Future move: link a
  quote card back to the source session in Review.

### Move 4 — `insightsBankedChip` becomes a `NavigationLink`

Profile's chip retains its existing register (icon + caption text +
recency footnote) but now wraps in a `NavigationLink(value:)`. A
small chevron lands at the trailing edge to telegraph
"tappable" without changing the chip's visual weight. Accessibility
ID `profile.insightsBanked.link` + hint "Opens your growth
library." Hidden state contract preserved — the chip (and therefore
the only entry point in this push) remains invisible until the
archive has at least one record.

### Move 5 — Six new tests in `GrowthLibraryWeeklyGroupingTests`

The bucketing helper is the only new logic worth testing in
isolation (the rendering surface is SwiftUI). The new test struct
uses a fixed Gregorian/GMT/POSIX calendar so the assertions are
locale-independent.

1. `emptyArchiveReturnsNoBuckets` — empty input produces no
   buckets so the SwiftUI view collapses to the empty state.
2. `sameWeekRecordsCollapseIntoOneBucket` — two records inside
   the same ISO week land in one bucket, sorted newest-first.
3. `bucketsEmergeNewestWeekFirst` — across weeks, the newest
   bucket sorts to the top.
4. `thisWeekAndLastWeekLabelsRender` — relative labels resolve
   for the immediate two-week window.
5. `olderBucketsUseExplicitWeekOfLabel` — three weeks ago does
   NOT fall back to "Last week", which would lie.
6. `crossYearBucketIncludesYearInLabel` — December 2025 vs
   February 2026 bucket carries the year so the user is never
   confused. The same-year case is asserted in the previous test
   ("must not contain '202'") to lock the gating.

## What did NOT change

- `ProofMomentService.swift` — untouched. Persistence still
  happens through the existing MainActor hops; the new surface
  consumes the same store.
- `ProofMoment` struct — untouched. The new view reads only
  fields that already exist.
- `AskNoumView.swift` — untouched. Chat continues to read the
  archive via `ProofMomentStore.shared.recent(limit: 3)`.
- `AIWeeklyInsightCard.swift`, `PathNodeCelebration.swift`,
  `PersonalBestCelebrationScreen` — untouched. Existing
  surface-tier proof rendering is unchanged.
- `Localizable.xcstrings` — untouched. Hardcoded English copy
  matches the rest of the M14/M15 surfaces.
- Brand voice — preserved. Sentence case in the body; no
  exclamations; the empty-state copy ("Nothing banked yet")
  matches the coach's restrained register.
- Design tokens — used as-is (Spacing, CornerRadius, AppColor,
  Typography). No new constants.

## Risks

1. **Two profile entry points to the same archive look ambiguous.**
   The chip near the rating card is the new library entry; the
   Coaching Direction card's "Ask Noum about your goal →" link
   remains. These serve different intents — the chip leads to
   evidence (read-only), the Ask Noum link to a conversation —
   but a user could expect the same destination from both. Reads
   fine in audit; revisit if usage data suggests confusion.
2. **No empty-state entry point.** Cold-start users can't see the
   library because the chip is hidden until the archive
   populates. This is intentional (matches the "never fabricate"
   contract) but means the surface is invisible until the first
   proof lands. Mitigated by `ProofMomentService` writing on
   every successful proof generation, which currently fires from
   Personal Best / Path Celebration / Weekly Insight — those land
   early enough that an active user gets a proof inside their
   first week.
3. **No "forget this moment" affordance.** The store has a
   `remove(sessionID:)` API but the library doesn't surface it.
   If a user generates a transcript they regret quoting, they
   can't currently scrub it from the library (they CAN clear all
   via Settings → account delete, which wipes everything). Open
   for a future move; out of scope here because the proof system
   already filters to coach-voice-positive moments — the
   "regrettable quote" case is rare.
4. **Sendable boundary on `weeklyGroups()`.** The instance method
   is MainActor-isolated (the class is MainActor); the static
   variant is `nonisolated`. Tests use the static path. Callers
   inside the SwiftUI view stay on MainActor and use the instance
   wrapper. No `@Sendable` annotation needed on the closure
   because `Dictionary(grouping:by:)` runs synchronously.
5. **Locale-sensitivity of week boundaries.** `Calendar.current`
   in production observes the user's locale, so the bucket
   boundaries are correct for the user even though the tests use
   a fixed POSIX calendar. The pure-function shape makes this
   testable; the rendering surface defaults to `.current` which
   is what we want for users.
6. **Project file auto-sync.** `Noum.xcodeproj` uses
   `PBXFileSystemSynchronizedRootGroup`, so the new
   `GrowthLibraryView.swift` is picked up automatically. Verified
   via `grep -c "fileSystemSynchronized"` on
   `project.pbxproj` (8 hits — multiple synced groups).

## Verification

### Implemented

- `nonisolated static func weeklyGroups(from:now:calendar:)` lives
  in `Noum/ProofMomentArchive.swift`. Pure-function shape, tested
  in isolation.
- `GrowthLibraryView` lives in `Noum/GrowthLibraryView.swift`,
  picked up by the auto-synced project group.
- `AppDestination.growthLibrary` threads through the existing
  Hashable conformance — no manual cases needed.
- `noum://growth` (and the `library` alias) route to the new
  destination via the existing `consumeDeepLink` switch.
- Profile chip wraps in a `NavigationLink(value:)` with a chevron
  + accessibility identifier `profile.insightsBanked.link`.
- Six `GrowthLibraryWeeklyGroupingTests` lock the bucketing
  contract.

### Blocked / needs visual QA on device

Surface is new; visual QA goal:

1. **Cold start** — fresh install, no sessions. Profile chip is
   hidden (no link visible). Open `noum://growth` directly via
   `xcrun simctl openurl` — the empty state should render.
2. **Populated** — after at least one finished session that
   produces a proof (which happens on Personal Best / Path
   Celebration / Weekly Insight surface paths), the chip becomes
   tappable on Profile. Tap → library. The card should show a
   real verbatim quote from the user's transcript.
3. **Honest source badge** — generate a proof with an AI provider
   configured ("Coach reading"). Generate one without
   ("Pattern match"). Both labels should render correctly.
4. **Two-week timeline** — populate proofs across "this week"
   and "last week"; confirm labels render relatively. Populate a
   proof from > 2 weeks ago; confirm it gets "Week of MMM d".

### Assumptions

- The right bucket boundary is the ISO week. Daily-bucketing
  would be too granular (a user with 3 reps in one day would see
  3 same-day buckets in a row, which is visually noisy);
  monthly bucketing would lose the weekly-rhythm framing that
  the rest of the app uses (League buckets are `ISO-year-Wweek`,
  AI Weekly Insight is per-week).
- The "Coach reading" vs "Pattern match" label is the right
  honest framing for the `isAIBacked` flag. Earlier surfaces
  hid this; the library is the right place to surface it because
  the user is asking "what did I actually earn" — they deserve
  to know which proofs came from a model reading their
  transcript vs a template matching their stats.
- The visual register tracks Pro-purple because the source
  archive is associated with the coach-presence (Ask Noum)
  register. BrandBlue would conflict with the practice-loop
  register (paths, modes, ratings).

### What was checked

- File reads + edits applied via Read / Edit / Write. Sandboxed
  Linux environment; no Xcode toolchain available to build.
- `grep` after each edit confirmed: (a) the new file lands in
  `Noum/`, (b) the new `AppDestination.growthLibrary` case
  appears exactly once in `PracticeSupport.swift`, (c) the
  `case .growthLibrary` lands exactly once in
  `ContentView.swift`'s destination switch, (d) the deep-link
  case `"growth"` / `"library"` lands exactly once in
  `consumeDeepLink`, (e) the Profile chip wraps in a
  `NavigationLink(value:)` once.
- Tests added to `NoumTests/NoumTests.swift` end-of-file, follow
  the existing `@Test` + `#expect(...)` rhythm.
- Sendability — the pure helper is `nonisolated` and uses only
  Sendable values (`Date`, `Calendar`, `String`, `ProofMomentRecord`).
- Brand voice — header copy uses sentence case + uppercase
  micro-eyebrow; empty-state line "Nothing banked yet" matches
  the coach's restrained register; no exclamations; no emoji;
  no Let's.

## Files modified

- `Noum/GrowthLibraryView.swift` (NEW, ~210 LOC).
- `Noum/ProofMomentArchive.swift` (+~70 LOC — `weeklyGroups` +
  helpers).
- `Noum/PracticeSupport.swift` (+1 line — `AppDestination.growthLibrary`).
- `Noum/ContentView.swift` (+5 LOC — destination switch case + deep
  link route).
- `ProfileView.swift` (~+15 / -3 LOC — chip wraps in
  NavigationLink + chevron + a11y).
- `NoumTests/NoumTests.swift` (+~115 LOC — six tests).
- `docs/CURRENT_STATE.md` (header breadcrumbs + new bullet under
  Ask Noum section + deep-link route list).
- `HANDOFF.md` (this file).

## Branch

`Redesign` — committed and pushed per the user's brief. The user
explicitly requested work on the Redesign branch ("ensure working
on the redesign branch too (very important)"). Continues the
post-M15 pattern of small, voice-coherent additions that close
loops opened by earlier pushes.
