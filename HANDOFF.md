# HANDOFF — M24 deferred slate (round 22): `AIRateLimiter` becomes an `ObservableObject` so the Settings AI-usage card + `CoachReadCard` daily-budget hint refresh mid-view

## Scope

Round 21 (the prior HANDOFF) closed the round-20 "Future move" #1 —
lifted the SOLVED crossing-detection predicate into
`IMHistorySummary.toneDrillCrossing(in:scenario:currentRepId:)` so the
post-rep coach note and the hero score-card ribbon can never drift
apart by construction. Round 21's own "Future moves" list rolled its
remaining items forward; the next-most-actionable item on that list
that doesn't need a real iOS device, an unblocked Firestore schema, or
a high-risk animation refactor pass is item #3:

> **Rate-limiter live refresh.** Make `AIRateLimiter` an
> `ObservableObject` so the Settings AI-usage card AND the
> `CoachReadCard` daily-budget hint refresh mid-view. Low priority.

This push closes that item. The artifact a user can hold once compiled
is the same Settings AI-usage card and the same post-rep coach card —
but they now **observe** the limiter instead of reading it once at
body construction. A rep finalizing in the practice tab while
Settings is pinned in a sheet now correctly tickles the AI-usage
card's "coach notes today" row down by one in the same MainActor
turn; a user re-mounting a still-visible CoachReadCard after the
limiter's `consumeIfAllowed` lands sees the daily-budget hint cross
its 75%-used threshold mid-view instead of staying frozen at the
stale pre-finalize value.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- The honest gap from round 21 ("a rep consumed elsewhere while the
  card is open leaves the rendered count stale") was the smallest
  remaining mechanical hole on the surfaces the coach voice owns.
  Round 22 closes it with the minimum amount of plumbing — one
  `@Published` token, three `&+=` bumps, two `@StateObject`
  swaps — and adds 8 tests locking the publication contract so a
  future agent reordering bumps or adding a new lifecycle hook
  doesn't silently break the read-side observers.
- The contract is narrow on purpose: bump on writes that change
  what `remainingToday(kind:)` would return; stay quiet on
  no-op writes (debounce-block, cap-reached, other-account wipe).
  That's the same self-discipline the round-21
  `IMHistorySummary.toneDrillCrossing` predicate exercises — one
  function, one contract, no view-driven rerender storms.
- The redesign-branch invariant: this is a `Redesign`-branch push
  per the user brief. The branch the agent runs on
  (`claude/nifty-meitner-h2Pwd`) is merged forward into `Redesign`
  so the round-22 work lands on `Redesign` directly. No fork in the
  lineage.

## What shipped

### Track 1 — `AIRateLimiter` becomes an `ObservableObject` (`AIRateLimiter.swift`)

`Noum/AIRateLimiter.swift`:

- `import Combine` added at the top so `@Published` resolves. Mirrors
  the existing `PostRepCoachNoteStore` pattern (also `@MainActor`,
  also `ObservableObject`, also imports Combine).
- `final class AIRateLimiter` → `final class AIRateLimiter:
  ObservableObject`. No subclassing; no callers depend on a non-
  observable surface (verified by grep — every call site reads
  through the public method API, never via a generic constraint).
- New `@Published private(set) var changeToken: UInt64 = 0`. Bumps
  on every state change that affects what `remainingToday(kind:)`
  would return; stays quiet on every no-op state change. The token
  is `UInt64` with wrapping addition (`&+=`) so heavy-usage
  overflow can't crash the limiter — the maths is ~580 billion
  years of one-second-bursts before the counter wraps once. A
  re-render on wrap is harmless (it's an identity change SwiftUI
  honors the same way it honors any +1).
- `consumeIfAllowed(kind:)` (line ~135). Adds `changeToken &+= 1`
  AFTER the `defaults.set(current + 1, forKey: countKey)` write,
  so any observer's body recomputation reads the post-consume
  `remainingToday` value, never the pre-consume one. The
  debounce-block and cap-reached early-return paths stay token-
  silent; they didn't move the read-side count.
- `endSession()` (line ~179). Doc-comment added that explicitly
  names the publication contract: this hook only clears the
  in-memory `lastCallTimestamp` debounce window; views don't
  observe debounce, so no token bump. Bumping here would re-render
  every observing surface every sign-out for nothing.
- `deleteAllData(for accountID:)` (line ~187). Adds `changeToken
  &+= 1` INSIDE the existing `accountIDProvider() == accountID`
  guard. Other-account wipes (a stale signed-out account's
  counters being scrubbed at logout) don't affect what
  `remainingToday(kind:)` would return for the current account, so
  the bump is gated behind the active-account check. Active-account
  wipes reset every (kind × day) counter to 0 and bump exactly
  once so observing surfaces re-read and surface the wider budget.
- Top-of-file doc-comment updated with the new "Read-side
  observability" design rule, explaining the publication contract
  so the next agent doesn't have to re-derive why three writes bump
  and one stays quiet.

### Track 2 — Settings AI-usage card observes the limiter (`SettingsView.swift`)

`Noum/SettingsView.swift`:

- New `@StateObject private var rateLimiter = AIRateLimiter.shared`
  declared alongside the other settings observers (line ~43, right
  after `@StateObject private var aiSettings`). Doc-comment names
  the contract: this is what makes the AI-usage card's "coach notes
  today" row refresh mid-view as the budget is consumed elsewhere.
- `aiUsageCard` (line ~950). The local `let rateLimiter =
  AIRateLimiter.shared` line is removed — the view-property
  observer carries the same instance, and dropping the local
  rebinding is what hooks the observation up. The
  `coachNotesRemaining` / `coachNotesCap` reads stay verbatim
  (`rateLimiter.remainingToday(kind: .postRepCoachNote)` /
  `rateLimiter.currentCap()`), so the card body is identical.
- No visual change. The card renders the same numbers it used to,
  but now `objectWillChange` from the limiter triggers a fresh
  body computation when the budget is consumed elsewhere — so the
  numbers stay honest.

### Track 3 — `CoachReadCard` observes the limiter (`CoachReadCard.swift`)

`Noum/CoachReadCard.swift`:

- New `@StateObject private var rateLimiter = AIRateLimiter.shared`
  declared alongside the other card observers (line ~62, after
  `coachingProfileStore`). Doc-comment explains the three
  surfaces this protects: the AI-upgrade pass on a still-mounted
  summary card, a deferred rep finalize landing while the user is
  still reading the previous summary, and a deletion from "Clear
  all data" while the card is rendered.
- The doc-comment also explicitly notes premium tier changes are
  NOT observed here: the summary card is short-lived, the typical
  Pro-upgrade path leaves the surface (paywall → checkout → back
  to home), and the cap is still read at call time via
  `rateLimiter.currentCap()` so a re-mount after an upgrade reads
  the wider budget. Right-sized observation — we don't pull
  `PremiumManager` into the card just for an edge case that the
  re-mount handles for free.
- `dailyCoachNoteRemaining` (line ~68) and `dailyCoachNoteCap`
  (line ~71) switched from `AIRateLimiter.shared.remainingToday`
  / `.currentCap` to `rateLimiter.remainingToday` / `.currentCap`.
  Same underlying instance (the singleton), but now read through
  the view-property observer so SwiftUI tracks the dependency.
- No visual change. The daily-budget hint renders the same string
  at the same threshold, but now the threshold-crossing actually
  refreshes the hint while the card is visible.

### Track 4 — `AIRateLimiterPublicationTests` (8 tests, `NoumTests/NoumTests.swift`)

A new `@MainActor struct AIRateLimiterPublicationTests` appended
after `HeroScoreCardToneDrillRibbonContractTests`. Same hermetic
pattern as `PostRepCoachNoteStoreTests` (round-prior round) —
each test stands up a fresh limiter with an in-memory `UserDefaults`
suite, a frozen clock, a fixed account id, and a premium override
so the cap and debounce floor are deterministic.

- `changeTokenStartsAtZeroForFreshInstance` — initial-state
  contract. A brand-new limiter's token reads zero so an observer's
  `.onAppear` baseline isn't preceded by a spurious render.
- `consumeBumpsChangeTokenOnSuccess` — the primary positive path.
  A successful `consumeIfAllowed` bumps the token by exactly 1
  alongside the `UserDefaults` write.
- `consumeIsMonotonicAcrossSuccessfulCalls` — the +1, never +2
  contract. Pinning each successful consume to a single bump (no
  double-publish from a future refactor that splits the write
  path).
- `consumeDoesNotBumpOnDebounceBlock` — the first negative
  contract. The second consume inside the 1.5s debounce floor
  returns false without writing to `UserDefaults` and without
  bumping the token. The frozen clock holds the call inside the
  debounce window.
- `consumeDoesNotBumpOnCapReached` — the second negative contract.
  A limiter clocked forward past the debounce window between each
  consume gets pushed to exactly `freeDailyCap` successful
  consumes; the +1 call returns false and the token reads
  identical to its at-cap value. Pinned with a sanity assert that
  the token bumped exactly `freeDailyCap` times up to that point.
- `endSessionDoesNotBumpChangeToken` — the lifecycle-hook quiet
  contract. `endSession` clears the in-memory debounce window only
  and must not re-render every observing surface.
- `deleteAllDataBumpsTokenForActiveAccount` — the active-account
  wipe contract. The bump fires when the wiped id matches the
  current `accountIDProvider` return value, AND the read-side
  effect lines up (`remainingToday` reads back at the full cap
  after the wipe).
- `deleteAllDataDoesNotBumpForDifferentAccount` — the gated-bump
  contract. Wiping a different account's counters cannot affect
  what `remainingToday(kind:)` would return for the current
  account; a bump here would re-render every observer for no
  visible reason.
- `tokenAndRemainingTodayStayInLockstep` — the integration
  contract. Across 5 successful consumes (clock advancing past
  the debounce window each time), every token bump corresponds
  to exactly a -1 change in `remainingToday`. That's the contract
  a SwiftUI body relies on: "if the token moved, the number I
  read is different from last time."

### Vision alignment

- **Pillar #4 (Believable progress).** The "coach notes today" row
  in Settings and the "1 AI coach note remaining today" hint in
  CoachReadCard are part of the user's honesty-contract surface
  — they explain WHY the AI-polish layer might step aside today.
  An observer reading a stale count is the kind of credibility
  hole that makes a user wonder "is this broken or is the AI just
  off?" Routing both through one `@Published` token makes the
  read-side honest by construction.
- **Pillar #5 (Personalized coaching).** A real human coach
  doesn't say "I have 8 hours of work in me today" while staring
  at a calendar from yesterday morning. The rate-limiter is the
  closest the in-app coach has to a "today's energy budget" — it
  has to read live.
- **Coach-parity stage #4 (Adaptation).** Per the
  `docs/VISION.md` development instructions: "Every recommendation
  must have evidence, purpose, an observable target, and an
  honest evidence threshold for changing the plan." The daily-
  budget hint IS the honest threshold the coach voice exposes for
  why it's reading rule-based today. Threshold-crossing must
  refresh the hint as the threshold is actually crossed, not at
  the next re-mount.
- **Anti-goal alignment (no "hearts-and-lives gating").** The
  publication contract preserves the soft-degrade promise: the
  user always gets a coach note. Observing the limiter is a
  read-side honesty improvement, not a new way to gate practice.

### Branch + redesign-alignment notes

- All four edits land on `Redesign`, the redesign-lineage branch
  the rolling M24 deferred-slate work has been shipping on since
  round 11. The user brief explicitly calls this out: "ensure
  working on the redesign branch too (very important)." This
  round preserves the round-by-round loop on the redesign lineage.
  The draft PR tracking the redesign work into `main` picks up
  this round's changes automatically.
- The branch the agent runs on (`claude/nifty-meitner-h2Pwd`) is
  merged forward into `Redesign` so the round-22 work lands on
  `Redesign` directly. No fork in the lineage.

## Future moves

(Updated priority list — round-21 "Future move" #3 closed this round;
the rest roll forward.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked
   on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from rounds 19–21. Pure visual work, not destination logic — the
   router stays the single source of truth either way.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–21. The current capsule is the minimum-
   viable shape: IM-tinted, quiet, in register with the existing
   "Toward your <voice>" chip. A real-device read may want the
   capsule to grow into a full-width strip across the score ring,
   or stay a chip but gain a one-shot pulse animation on first
   render. Pure visual work, not crossing logic — the round-21
   helper stays the single source of truth either way.
5. **Extend the crossing helper to the chat-coach context line.**
   Carried forward from round 21 as a note for the record (not an
   action item): `CoachContextBuilder.toneDrillResolvedLines(for:)`
   currently calls the cross-scenario read; if a future chat-coach
   surface ever wants to read only "fresh crossings from this
   session," the helper is there to route through.
6. **NEW — observe `PremiumManager` in `CoachReadCard` if real-device
   usage shows mid-summary upgrades.** The round-22 doc-comment
   explicitly skipped this on cost-of-observation grounds (summary
   card is short-lived, paywall is full-screen, re-mount handles
   it). Worth a real-device check — if a paywall sheet on top of
   the summary triggers a Pro upgrade WITHOUT dismissing the
   summary underneath, the hint stays stale until the user
   navigates away. Cheap fix if needed: one more `@StateObject`
   line. No code change this round.
7. **NEW — day-rollover refresh for long-mounted observers.** The
   round-22 publication only fires on writes. A user who pins
   Settings open across midnight would still see yesterday's
   counters until the next consume bumps the token. The
   `dayKey(for:)` rollover doesn't auto-publish. Real-world
   relevance is low (nobody actually leaves Settings open across
   midnight), but worth a note. A future round could subscribe to
   `UIApplication.significantTimeChangeNotification` and bump the
   token from there, or add a `.task(id: Calendar.current.dayKey)`
   to the observing views. No code change this round — the call
   would be premature optimization without real-device evidence.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing
in this round was compiled or run — not the app, not the test suite.
The changes are a pure conformance addition + 3 line bumps on the
write paths + 2 `@StateObject` swaps:

- `AIRateLimiter` now conforms to `ObservableObject`. The
  conformance is automatic (the `@Published` wrapper provides the
  `objectWillChange` publisher); no manual `objectWillChange.send()`
  is required. `@MainActor` + `ObservableObject` is the same pair
  `PostRepCoachNoteStore` uses, which is already shipping. Confirmed
  via grep that no caller depends on a non-`ObservableObject`-shaped
  surface.
- The three `changeToken &+= 1` bumps are after the persisted writes
  (`consumeIfAllowed` write happens, then bump) so an observer
  reading post-bump sees the post-write value. The deleteAllData
  bump is inside the active-account guard so other-account wipes
  stay token-silent.
- The two `@StateObject` swaps (in `SettingsView` and
  `CoachReadCard`) follow the same pattern the rest of those views
  use for shared singleton stores. `@StateObject` with a singleton
  is the canonical SwiftUI pattern — the closure runs once per
  view first-mount, returns the same shared instance, and SwiftUI
  subscribes to `objectWillChange` from there. No new memory; same
  instance.
- The 8 `AIRateLimiterPublicationTests` mirror the
  `PostRepCoachNoteStoreTests` pattern byte-for-byte: same
  `@MainActor struct`, same hermetic `UserDefaults(suiteName:
  UUID().uuidString)!` per test, same `init` test seam
  (`defaults`, `accountIDProvider`, `now`, `premiumProvider`).
  The `tokenAndRemainingTodayStayInLockstep` test is the
  integration anchor — every token bump corresponds to a
  remainingToday change.

All checks the next agent should run on a real build host:

1. `swift test --filter AIRateLimiterPublicationTests` — the 8 new
   tests should all pass.
2. `swift test --filter PostRepCoachNoteStoreTests` — the existing
   ObservableObject-style tests should still pass; they exercise a
   sibling class with the same MainActor + Published pattern, so a
   working harness for them is a working harness for the new tests.
3. `swift test --filter IMToneDrillCrossingTests` — the round-21
   helper tests should still pass (no changes to
   `IMHistorySummary.toneDrillCrossing` this round).
4. `swift test --filter HeroScoreCardToneDrillRibbonContractTests`
   — the round-20 ribbon-contract tests should still pass.
5. `swift test --filter LookingAheadCardStartCTAContractTests` —
   the round-19 launch-CTA tests should still pass.
6. Boot the app on simulator, open Settings → AI Usage, pin it in a
   sheet (e.g. via the Settings deep link from Home), then finish a
   rep in another tab. Confirm:
   - The "coach notes today" row's "remaining" number drops by one
     in the same render — no stale read until the user dismisses
     and re-opens Settings.
   - The "used / cap" tile re-flows around the new number.
   - The CoachReadCard's "X AI coach notes remaining today" hint
     (visible at 75%+ used) refreshes the same way on a deferred
     finalize that lands while the previous summary is still on
     screen.
   - Crossing the 75%-used threshold mid-view actually starts
     showing the hint without a re-mount.
   - Sign-out → sign-back-in with the same account: the AI-usage
     card reflects the persisted counter, and the daily-budget
     hint reads honestly against it.
