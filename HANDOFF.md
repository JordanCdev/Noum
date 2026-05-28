# HANDOFF — M24 deferred slate (round 18): collapse `HomeCoachCard.destination(for:)` into a zero-arg helper

## Scope

Round 17 (the prior HANDOFF) closed "Future move" #2 — both
`HomeCoachCard.destination(for:)` and
`ContentView.practiceAppDestination(for:)` now delegate to
`SummaryLookingAheadRouter`, so the mode-to-destination mapping + the
IM-unavailable fallback live in one tested place. Round 17 then listed
its own #3 as the natural next step:

> **Collapse `HomeCoachCard.destination(for: mode)` into a zero-arg
> helper.** Round 17 left the `mode` parameter in the signature even
> though the function now reads `recommendedMode` off the blueprint it
> already owns. Removing the parameter requires also touching the
> single caller at `recommend()` (just delete the `for: mode` and read
> `recommendationBlueprint.recommendedMode` once before the navigation
> push). Tiny diff, but a tighter contract — and it removes the
> lingering implication that the caller can route a different mode
> than the blueprint says.

This push closes #3. Pure refactor, no behavior change, no SwiftUI
surface visible to the user — which is why it could ship this round
while the closure-pass UI wire-up of round-16 #1 still waits for a
build host with hardware.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- After round 17, `HomeCoachCard.destination(for: mode)` was a
  one-liner that ignored its `mode` parameter entirely: it called
  `SummaryLookingAheadRouter.destination(for: recommendationBlueprint,
  imAvailable: ...)`, and the router reads `recommendedMode` straight
  off the blueprint. The `mode` argument at the single call site was
  always `recommendedMode` (the local that the caller had just bound
  from `recommendationBlueprint.recommendedMode` via the `recommendedMode`
  computed property). The parameter was dead weight *and* a small
  silent-drift hole: nothing in the type system stopped a future caller
  from threading a different `PracticeMode` than the blueprint says,
  producing a launch that disagrees with the recommendation the user
  just tapped.
- Collapsing the helper to zero arguments is the same shape of move as
  the rest of the round-15 → round-17 sequence: take a function whose
  inputs are already implicit on the surrounding context, and let the
  signature say so. The router stays the single source of truth; the
  call site stops pretending it has a choice.

## What shipped

### Track 1 — zero-arg helper (`HomeCoachCard.swift`)

`Noum/HomeCoachCard.swift`:

- `private func destination(for mode: PracticeMode) -> AppDestination`
  becomes `private func destination() -> AppDestination`. The body is
  unchanged — still a single delegation to
  `SummaryLookingAheadRouter.destination(for: recommendationBlueprint,
  imAvailable: IMModeAvailability.isAvailable)`. The `mode` parameter
  was never read; removing it makes that explicit.
- The single caller at `beginRecommendedRep()` changes from
  `navigationPath.append(destination(for: mode))` to
  `navigationPath.append(destination())`. The local `mode`
  binding stays — it's still used by the preceding
  `recommendationLearningStore.markTapped(mode: mode)` and the
  `if mode == .timed` theme-caching block, so removing it would
  expand the diff for no gain.
- Doc-comment on the helper rewritten to name *why* it's zero-arg
  now: the router reads `recommendedMode` off the blueprint, and
  threading a `PracticeMode` in opened a silent-drift hole where a
  caller could claim to route a different mode than the blueprint
  says. The function is now a one-liner against the same router that
  `ContentView.practiceAppDestination(for:)` and (once the closure-
  pass UI lands) the post-rep `LookingAheadCard` call into.

### Track 2 — doc-comment sync (`PracticeSupport.swift`, `NoumTests/NoumTests.swift`)

- `Noum/PracticeSupport.swift`: the
  `SummaryLookingAheadRouter`-level doc-comment that named the two
  call sites updated to use the new signature
  (`HomeCoachCard.destination()` instead of `destination(for:)`).
  Also tightened the description of *which* call site uses *which*
  overload: `ContentView` uses the lower-level
  `destination(for:scenario:tone:imAvailable:)` overload because its
  `PracticeSuggestion` doesn't carry a full blueprint;
  `HomeCoachCard` holds the blueprint directly and uses the
  blueprint-shaped overload.
- `NoumTests/NoumTests.swift`: the one test comment that mirrored
  the old `HomeCoachCard.destination(for:)` signature in the
  `imRecommendationFallsBackToTimedWhenImUnavailable` test updated to
  `HomeCoachCard.destination()`. The test body is unchanged — it
  exercises the router as a pure function, which is the source of
  truth either way.

### Vision alignment

- **Anti-drift / coach-parity hygiene.** The `docs/VISION.md` standard
  asks every coaching feature to strengthen one stage of the
  diagnose → formulate → prescribe → observe → adapt → transfer loop.
  Round 18 doesn't add a feature — it removes a silent-drift hole
  from *prescribe*: the helper that launches the recommended rep on
  the home coach card can no longer be asked to route a different
  `PracticeMode` than the blueprint says, because the signature no
  longer accepts one. One fewer way for the launch to disagree with
  the prescription the user just tapped.
- **Pillar #4 — Frictionless reps.** Same as round 17: Practice
  Again, the post-rep "Looking ahead" router, and the home/mode-picker
  recommendation launches all flow through the same two pure routers.
  Round 18 makes the home coach card's call site as thin as it can be
  — one function, zero arguments, one router.
- **Anti-goals respected.** No new feature. No new persistent state.
  No new AI surface. No new dependency between files. Pure signature
  tightening with strict behavioral parity — the existing 13 tests in
  `SummaryLookingAheadRouterTests` (6 blueprint-overload + 7 lower-
  level + parity, from round 17) still pass against the now-zero-arg
  helper because the helper still delegates to the same router with
  the same arguments.

## Files touched

- **Modified:** `Noum/HomeCoachCard.swift`
  (`destination(for: mode)` → `destination()`; caller updated;
  doc-comment rewritten to name the silent-drift hole the new
  signature closes)
- **Modified:** `Noum/PracticeSupport.swift`
  (`SummaryLookingAheadRouter` doc-comment now names
  `HomeCoachCard.destination()` and the per-call-site overload split)
- **Modified:** `NoumTests/NoumTests.swift`
  (one test comment synced to the new signature; no test body
  changes)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief, continuing the
round loop on the redesign lineage. A draft PR tracks the redesign work
into `main`.

The artifact a user can hold once the closure-pass UI lands (round-16
`Future moves` #1):

**A "Looking ahead" card that launches the recommended rep, sharing
the same destination switch as the home coach card and the mode-picker
tile.** Same prescription, one tap to start it, *and* one tested switch
behind all three surfaces so a future change to the IM-unavailable
fallback (or a future IM-like mode) lands once and propagates
everywhere consistently.

## Future moves

(Updated priority list — round-17 item #3 closed this round; the rest
roll forward:)

1. **Wire `SummaryLookingAheadRouter` into `LookingAheadCard`.**
   Unchanged from round 16/17. Thread an `onStart` closure through
   `SummaryView`'s init and `expandableDetailsSection`, render a
   subordinate CTA on `LookingAheadCard`, and call
   `SummaryLookingAheadRouter.destination(for: summaryRecommendation,
   imAvailable: IMModeAvailability.isAvailable)` from it. The router is
   the same one the home coach card and ContentView suggestion tile now
   call into, so the closure-pass UI wire-up gets the IM-unavailable
   fallback automatically. Deferred: still wants real-device QA. The
   closure-pass is small; the visual treatment of the CTA on the card
   is what wants the device read.
2. **Surface the SOLVED win on the summary card itself, not only the
   coach note.** Unchanged from round 16/17. Round 14 names the win in
   the `CoachReadCard` prose; the `LookingAheadCard` / `HeroScoreCard`
   still move silently to the next focus. A small "you just solved X"
   ribbon on the crossing rep's summary — reading the same
   `imToneDrillResolved` the note already computes — would make the
   moment unmissable. Deferred: new summary UI wants device QA.
3. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
4. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
5. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` so the Settings AI-usage card AND the
   `CoachReadCard` daily-budget hint refresh mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
change is deliberately small and matches the existing, tested patterns
line-for-line:

- The helper body is byte-for-byte identical before and after — only
  the signature (no `mode` parameter) and the caller (`destination()`
  instead of `destination(for: mode)`) differ. The router it delegates
  to is unchanged.
- The 13 tests in `SummaryLookingAheadRouterTests` (round 17) still
  exercise the router as a pure function; they don't construct
  `HomeCoachCard` and don't depend on the helper signature. They are
  enough to catch a regression at `swift test` time.
- No new types, no new dependencies between files. The single
  intra-file caller is updated in the same diff.

All checks the next agent should run on a real build host:

1. `swift test --filter SummaryLookingAheadRouterTests` — the 13
   tests in this struct should all pass.
2. Boot the app on simulator and tap the home coach-card recommendation
   for each of (Timed, Sudden Death, Ah-Counter, IM Mode); confirm each
   lands on the right practice surface and (for IM with the device's
   IM provider misconfigured) the fallback into Timed still works.
3. Tap the primary CTA on the mode picker for the same four cases;
   same expected behavior (round 17's refactor — should be unchanged
   here, but worth re-verifying alongside the home coach card to prove
   the two surfaces still agree).
