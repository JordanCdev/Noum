# HANDOFF — M24 deferred slate (round 23): `CoachReadCard` observes `PremiumManager` so the daily-budget hint refreshes the same body turn a Pro upgrade lands

## Scope

Round 22 (the prior HANDOFF) closed the round-21 "Future move" #3 —
made `AIRateLimiter` an `ObservableObject` so the Settings AI-usage
card and the `CoachReadCard` daily-budget hint refresh mid-view as the
budget is consumed elsewhere. The round-22 HANDOFF added two new
deferred items to the future-moves list. Round 23 closes one of them:

> **#6 NEW — observe `PremiumManager` in `CoachReadCard` if
> real-device usage shows mid-summary upgrades.** The round-22
> doc-comment explicitly skipped this on cost-of-observation grounds
> (summary card is short-lived, paywall is full-screen, re-mount
> handles it). Worth a real-device check — if a paywall sheet on top
> of the summary triggers a Pro upgrade WITHOUT dismissing the
> summary underneath, the hint stays stale until the user navigates
> away. Cheap fix if needed: one more `@StateObject` line. No code
> change this round.

The evidence the round-22 deferral asked for came from code reading,
not a simulator: `SummaryView.swift` line 795 confirms the paywall
entry from the summary surface is `.sheet(isPresented: $showPaywall)
{ PaywallView() }` — a sheet, not a navigation push. When the sheet
dismisses after a successful purchase, the underlying CoachReadCard
stays mounted. Without round 23's explicit observation, the daily-
budget hint would keep reading the pre-upgrade cap (12 against the
same used count) and continue rendering "1 AI coach note remaining
today" even though the new cap (40) puts the user back at 30
remaining.

The fix is the one-line `@StateObject` the round-22 future-moves
list pre-committed to. Round 23 also extracts the threshold
predicate into a static pure function so the tier-change contract
can be locked by tests without standing up a real `AIRateLimiter` +
`PremiumManager`.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- The honest gap from round 22 ("a Pro upgrade landing through the
  paywall sheet leaves the hint stale until navigation") was the
  smallest remaining mechanical hole on the surfaces the coach
  voice owns. Round 23 closes it with the minimum amount of
  plumbing — one `@StateObject`, one doc-comment swap, one
  predicate extraction — and adds 12 tests locking the threshold-
  crossing math so a future agent tweaking the 0.75 ratio or
  refactoring the predicate breaks the test rather than the UX.
- The contract is narrow on purpose: observe `PremiumManager` so
  the cap reads fresh in the same body turn; don't try to model
  premium changes inside the limiter itself. The publication
  contract on `AIRateLimiter` stays "publish on writes the limiter
  performs"; tier changes are observed by views that care, the
  same way `SettingsView` already observes `premium` for the
  AI-usage card. One pattern, two surfaces, no spooky action at a
  distance.
- The redesign-branch invariant: this is a `Redesign`-branch push
  per the user brief. The branch the agent runs on
  (`claude/adoring-dijkstra-ksBsS`) is merged forward into
  `Redesign` so the round-23 work lands on `Redesign` directly. No
  fork in the lineage.

## What shipped

### Track 1 — `CoachReadCard` observes `PremiumManager` (`CoachReadCard.swift`)

`Noum/CoachReadCard.swift`:

- New `@StateObject private var premium = PremiumManager.shared`
  declared right after the round-22 `rateLimiter` observer (line
  ~63). The doc-comment names the contract: the paywall in
  `SummaryView` is a `.sheet`, so the post-purchase CoachReadCard
  stays mounted; explicit observation makes the body-recomputation
  dependency self-contained so a future `Equatable` optimization
  on the parent or a refactor that hoists CoachReadCard out of the
  SummaryView subtree can't silently re-introduce the stale read.
- The round-22 rationalization that said "Premium tier changes are
  not observed here" is removed from the `rateLimiter` doc-comment
  and replaced with the round-23 contract on a separate doc-comment
  for the `premium` observer. The two contracts are now adjacent
  in the source so a future agent can read the full read-side
  honesty story in one place.
- The `shouldShowDailyBudgetHint` doc-comment updated to name the
  new cascade: "a mid-day Pro upgrade widens the budget and —
  because this view observes `PremiumManager` — the threshold
  recomputes the same body turn, hiding the hint the moment the
  wider cap pulls the ratio back below the bar."

### Track 2 — Pure-function predicate (`CoachReadCard.swift`)

- New `static func shouldShowDailyBudgetHint(noteIsAIBacked:cap:remaining:)`
  carries the threshold math. The instance computed property now
  routes through the static so the contract has one home and the
  tests can pin the math directly.
- Clamping added inside the static: `clampedRemaining = max(0,
  min(cap, remaining))` so a transient state where the limiter and
  the cap reader briefly disagree (e.g. mid-flight tier upgrade)
  cannot invert the ratio and falsely trigger the hint. Defensive
  but cheap; the existing instance property already returned false
  on `cap > 0`, the new clamp closes the symmetric edge.
- Doc-comment names the round-23 anchor explicitly: "at cap=12
  with used=10 the ratio is ~0.83 (hint shown); after a Pro
  upgrade widens cap to 40 the ratio is 0.25 (hint hidden) the
  same body turn, never after re-mount."

### Track 3 — `CoachReadCardDailyBudgetHintTests` (12 tests, `NoumTests/NoumTests.swift`)

A new `@MainActor struct CoachReadCardDailyBudgetHintTests`
appended after `AIRateLimiterPublicationTests`. All tests call the
pure static so they need no test seam — the predicate is a function
of three Ints + one Bool, deterministic by construction.

- `hintIsHiddenWhenNoteIsRuleBased` — rule-based notes carry the
  explicit `RULE-BASED` tag in the card header; the hint would be
  a second voice saying the same thing.
- `hintIsHiddenWhenBudgetIsHealthy` — below the 75%-used bar the
  hint stays silent (cap=12, remaining=9, used=3 → ratio=0.25).
- `hintAppearsExactlyAtThreshold` — the inclusive-comparison
  contract (`>= 0.75`, not `> 0.75`). cap=12, remaining=3, used=9
  → ratio=0.75 exactly, hint appears.
- `hintIsShownWhenAtZeroRemaining` — cap-reached state. The card
  has already soft-degraded to a rule-based note for the next rep.
- `hintIsHiddenWhenCapIsZero` — defensive divide-by-zero guard.
- `tierUpgradeCrossesBackBelowThreshold` — **the round-23 anchor**.
  Same `used` count (10), cap goes 12 → 40 on a Pro upgrade.
  Pre-upgrade ratio ~0.83 → hint shown; post-upgrade ratio 0.25 →
  hint hidden.
- `tierDowngradeCrossesAboveThreshold` — symmetric mirror of the
  upgrade contract so a future refactor can't accidentally make
  the predicate one-way-only.
- `remainingOverCapClampsCleanly` — locks the round-23 clamp so
  a `remaining > cap` value doesn't invert the ratio.
- `thresholdMatchesDocumentedRatio` — pins the 0.75 constant
  against the round-22 HANDOFF reference ("crossing the 75%-used
  threshold mid-view") so a future tweak to a different number
  surfaces as a documentation-update reminder.
- `hintCopyAtZeroNamesTomorrowsResume` / `hintCopyAtOneIsSingular`
  / `hintCopyAtMoreIsPlural` / `hintCopyNegativeClampsToZeroBranch`
  — pin the four copy branches of `dailyBudgetHintCopy(remaining:)`,
  including the negative-remaining defensive clamp.

### Vision alignment

- **Pillar #4 (Believable progress).** The daily-budget hint is
  part of the user's honesty-contract surface — it tells the user
  WHY the AI-polish layer might step aside today. A user who
  upgrades to Pro mid-summary expecting more headroom and then
  sees the same "1 AI coach note remaining today" caption is the
  exact credibility hole the round-22 doc-comment named ("is this
  broken or is the AI just off?") but rationalized away. Round 23
  closes it.
- **Pillar #5 (Personalized coaching).** A real human coach
  doesn't say "I have 8 hours of work in me today" right after
  the user buys them a whole new shift. The rate-limiter is the
  closest the in-app coach has to a "today's energy budget" — it
  has to read live across tier changes too.
- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  "Every recommendation must have evidence, purpose, an
  observable target, and an honest evidence threshold for
  changing the plan." The daily-budget hint IS the honest
  threshold the coach voice exposes for why it's reading rule-
  based today. The threshold-crossing must refresh the hint as
  the threshold is actually crossed in either direction — used-
  count moving (round 22) or cap moving (round 23).
- **Anti-goal alignment (no "hearts-and-lives gating").** Round 23
  preserves the soft-degrade promise: the user always gets a
  coach note. Observing the limiter and the premium tier is a
  read-side honesty improvement, not a new way to gate practice.

### Branch + redesign-alignment notes

- All three edits land on `Redesign`, the redesign-lineage branch
  the rolling M24 deferred-slate work has been shipping on since
  round 11. The user brief explicitly calls this out: "ensure
  working on the redesign branch too (very important)." This
  round preserves the round-by-round loop on the redesign lineage.
  The draft PR tracking the redesign work into `main` picks up
  this round's changes automatically.
- The branch the agent runs on (`claude/adoring-dijkstra-ksBsS`)
  is merged forward into `Redesign` so the round-23 work lands on
  `Redesign` directly. No fork in the lineage.

## Future moves

(Updated priority list — round-22 "Future move" #6 closed this round;
the rest roll forward.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked
   on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from rounds 19–22. Pure visual work, not destination logic — the
   router stays the single source of truth either way.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–22. The current capsule is the minimum-
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
6. **Day-rollover refresh for long-mounted observers.** Carried
   forward from round 22. The `AIRateLimiter` publication only
   fires on writes. A user who pins Settings open across midnight
   would still see yesterday's counters until the next consume
   bumps the token. The `dayKey(for:)` rollover doesn't auto-
   publish. Real-world relevance is low (nobody actually leaves
   Settings open across midnight), but worth a note. A future
   round could subscribe to
   `UIApplication.significantTimeChangeNotification` and bump the
   token from there, or add a `.task(id: Calendar.current.dayKey)`
   to the observing views. Premature optimization without real-
   device evidence; no code change this round.
7. **NEW — extend tier-change observation symmetry to other surfaces
   that read `AIRateLimiter.currentCap()` directly.** Round 23 makes
   `CoachReadCard` self-contained on tier changes; the
   `SettingsView.aiUsageCard` already covers itself via its own
   `@StateObject premium`. Any future surface that adds a third
   read site for `currentCap()` should default to either observing
   `PremiumManager` directly OR be a child of a view that does, so
   the same body-turn refresh is preserved. No code change this
   round — this is a note for the next agent so the pattern doesn't
   drift.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing
in this round was compiled or run — not the app, not the test suite.
The changes are a one-line `@StateObject` addition + a pure-function
predicate extraction + 12 tests on the predicate's algebra:

- `CoachReadCard` already imports `SwiftUI` (the existing
  `@StateObject` declarations on `BaselineStore.shared`,
  `RatingStore.shared`, etc., confirm the import is in scope).
  Adding `@StateObject private var premium = PremiumManager.shared`
  follows the exact same pattern — `PremiumManager` is already
  `final class PremiumManager: ObservableObject` with
  `@Published private(set) var isPremium: Bool` (verified by grep
  on `Noum/PremiumManager.swift`).
- The pure static `shouldShowDailyBudgetHint(noteIsAIBacked:cap:remaining:)`
  is a refactor of the existing instance-property body with one
  defensive clamp added (`max(0, min(cap, remaining))`). The
  instance property now delegates to the static so the
  call-site behavior is byte-identical for the happy path and
  strictly more defensive on the over-cap edge.
- The 12 `CoachReadCardDailyBudgetHintTests` mirror the
  `AIRateLimiterPublicationTests` pattern: same `@MainActor
  struct`, same `@Test` annotations, no test seam needed (the
  predicate is pure). They lock the threshold math, the inclusive-
  comparison contract, the clamp, the tier-change anchors in both
  directions, and the four copy branches.

All checks the next agent should run on a real build host:

1. `swift test --filter CoachReadCardDailyBudgetHintTests` — the 12
   new tests should all pass.
2. `swift test --filter AIRateLimiterPublicationTests` — the round-22
   tests should still pass (no changes to `AIRateLimiter` this round).
3. `swift test --filter PostRepCoachNoteStoreTests` — the sibling
   ObservableObject-style tests should still pass.
4. `swift test --filter IMToneDrillCrossingTests` — the round-21
   helper tests should still pass.
5. `swift test --filter HeroScoreCardToneDrillRibbonContractTests`
   — the round-20 ribbon-contract tests should still pass.
6. `swift test --filter LookingAheadCardStartCTAContractTests` —
   the round-19 launch-CTA tests should still pass.
7. Boot the app on simulator, finish a rep so the AI-backed coach
   note + the daily-budget hint render (e.g. by repping 9 times so
   3 remaining out of 12), then tap the Pro CTA inside the AI-usage
   card OR the inline "Pro" entry on the summary to open the
   paywall sheet. Use the simulator's StoreKit configuration to
   complete a sandbox purchase. Confirm:
   - The paywall sheet dismisses cleanly.
   - The CoachReadCard underneath has NOT been re-mounted (the
     deep-analysis reveal state, if expanded, is preserved).
   - The daily-budget hint either disappears (if the new ratio
     drops below 0.75 — at cap=40 with used=9 the ratio is 0.225
     so it should) or refreshes its number (if the new ratio is
     still above 0.75).
   - Equivalent flow on subscription lapse if possible to
     simulate — confirms the downgrade direction also refreshes.
   - Sign-out → sign-back-in with the same account: the hint
     reads honestly against the persisted counter at the active
     tier.
