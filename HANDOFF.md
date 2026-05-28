# HANDOFF — M24 deferred slate (round 16): pure router for the post-rep "Looking ahead" launch

## Scope

Round 15 (the prior HANDOFF) closed the "Practice Again preserves the
just-finished IM scenario + tone" item by adding
`SummaryPracticeAgainRouter.destination(for:imSetup:)` and threading it
through `SummaryView.onPracticeAgain`. Round 15 named the next move and
flagged it #1 in its "Future moves":

> **Make the `LookingAheadCard` itself launch the drill.** Today the
> summary card *describes* the prescribed IM drill but isn't tappable.
> Threading `scenario`/`tone` + an `onStart` closure through
> `SummaryView`'s init and rendering a subordinate CTA would complete the
> loop on the most-seen post-rep surface. Deferred: new interactive
> recommendation UI wants real-device QA this build host lacks.

This push lands the **Track-1 pre-work** for that item — the pure router
that the closure-pass UI wire-up will call. The interactive CTA itself
stays deferred (still wants device QA) but the contract it will call
through is now locked under tests, so the remaining work shrinks to a
small closure-pass through `SummaryView`'s init.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- `LookingAheadCard` sits at the bottom of the expandable details on the
  post-rep summary. It already reads from `summaryRecommendation`
  (`RecommendationBiasEngine.blueprint(...)`), and the blueprint already
  carries `recommendedScenario` + `recommendedTone` whenever the
  tone-drill signal fires — but the card itself never threads those down,
  and the user has no way to tap into the recommended scenario from
  there. The natural next move is a subordinate CTA on the card.
- The destination calculation behind that CTA is identical in shape to
  `HomeCoachCard.destination(for: mode)` (`HomeCoachCard.swift:594`) and
  `ContentView.practiceAppDestination(for: suggestion)`
  (`ContentView.swift:2106`): pick the practice destination for the
  recommended mode, with the IM-mode branch carrying scenario + tone and
  falling back to `.timedPractice` when IM is unconfigured.
- Locking that calculation as a pure router *first* lets the closure-pass
  UI wire-up be a one-liner — and the same router can later collapse the
  two duplicated copies in `HomeCoachCard` and `ContentView` when those
  surfaces are touched, without expanding scope this round.

## What shipped

### Track 1 — the pure router (`PracticeSupport.swift`)

`Noum/PracticeSupport.swift`:

- New `SummaryLookingAheadRouter.destination(for:imAvailable:)` placed
  directly below `SummaryPracticeAgainRouter`, next to the
  `AppDestination` enum both routers return. Takes a
  `RecommendationBiasBlueprint` and the `IMModeAvailability.isAvailable`
  flag and returns the destination launching the recommendation should
  push.
- Timed / Sudden Death / Ah-Counter recommendations route to their plain
  practice destinations regardless of the IM fields on the blueprint —
  goal-biased blueprints can carry leftover scenario/tone nils, and
  defensive cross-pollination from a future bug can't mis-route a non-IM
  recommendation into the IM picker.
- IM recommendations route to `.imPractice(scenario:tone:)` populated
  from `blueprint.recommendedScenario` / `recommendedTone` when
  `imAvailable` is true, and fall back to `.timedPractice` when the
  device has IM Mode unconfigured — mirroring the existing fallbacks in
  `HomeCoachCard.destination(for:)` and
  `ContentView.practiceAppDestination`, so the recommendation never
  sends a user into a surface they can't run.
- Doc-comment names the two duplicate call sites the router can collapse
  later (HomeCoachCard / ContentView) without taking on that refactor
  this round.

### Track 2 — locked the contract (`NoumTests/NoumTests.swift`)

- New `SummaryLookingAheadRouterTests` (+6) right after
  `SummaryPracticeAgainRouterTests`, with a private `blueprint(...)`
  helper that fills the non-routing fields with neutral placeholders so
  each test reads as scenario + tone + mode only:
  1. IM recommendation with scenario + tone re-arms both (Difficult
     Conversation + Calm round-trips through the router).
  2. IM recommendation with nil scenario/tone (goal-biased fallback)
     routes to `.imPractice(nil, nil)` — picker stays the safe default,
     no substitution to Timed.
  3. IM recommendation falls back to `.timedPractice` when
     `imAvailable == false`, *even when* scenario + tone are set — the
     IM picker would just bounce off `IMPracticeView`'s availability
     guard.
  4. Timed recommendation ignores IM fields under both availability
     states (true and false).
  5. Sudden Death recommendation ignores IM fields under both
     availability states.
  6. Ah-Counter recommendation ignores IM fields under both
     availability states.

### Vision alignment

- **Pillar #4 — Frictionless reps.** Round 15 made Practice Again
  drop the user back into the same IM scenario + tone they just ran;
  round 16 is the same idea projected forward — when the coach already
  knows the next scenario + tone to drill (because the tone-drill signal
  fires on a scenario the user reliably misses), the recommendation
  launch should land them directly inside that pair instead of inside
  the picker. The router is the contract; the closure-pass UI wire-up
  closes the surface.
- **Pillar #5 — Personalized coaching.** The blueprint's
  `recommendedScenario` / `recommendedTone` are populated by the
  *Adaptation* read — a real human coach wouldn't just *describe* the
  drill they want you to do, they'd put you straight into it. Locking
  the destination contract is the precondition for that.
- **Anti-goals respected.** No new AI surface — pure value-function over
  data the recommendation engine already computes. No new persistent
  state. No SwiftUI imports, no `@MainActor` requirement, no nav-path
  coupling — the router runs cleanly under `swift test` with zero
  scaffolding. The IM-availability check is a parameter, not an embedded
  lookup, so the router has no global-state dependency.

## Files touched

- **Modified:** `Noum/PracticeSupport.swift`
  (+`SummaryLookingAheadRouter` directly below
  `SummaryPracticeAgainRouter`)
- **Modified:** `NoumTests/NoumTests.swift` (+6 tests in
  `SummaryLookingAheadRouterTests`)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief, continuing the
round loop on the redesign lineage. A draft PR tracks the redesign work
into `main`.

The artifact a user can hold once the closure-pass UI lands:

**A "Looking ahead" card that launches the recommended rep.** Today the
card *describes* the next move ("For your next session, try IM
Mode — keep the same Difficult Conversation scenario and hold Calm end
to end"). Tomorrow, tapping the card threads scenario + tone through to
the IM rep directly — same prescription, one tap to start it, exactly
like the home tile already does. The router landed this round is the
contract that closure-pass calls through.

## Future moves

(Updated priority list — the *router* half of round-15 item #1 closed
this round; the UI closure-pass remains; lower-priority items carried
forward:)

1. **Wire `SummaryLookingAheadRouter` into `LookingAheadCard`.**
   Thread an `onStart` closure through `SummaryView`'s init and
   `expandableDetailsSection`, render a subordinate CTA on
   `LookingAheadCard`, and call `SummaryLookingAheadRouter.destination(
   for: summaryRecommendation, imAvailable: IMModeAvailability.isAvailable)`
   from it. Deferred: still wants real-device QA. The closure-pass is
   small; the visual treatment of the CTA on the card is what wants the
   device read.
2. **Collapse the duplicate destination-mapping in
   `HomeCoachCard.destination(for:)` and
   `ContentView.practiceAppDestination(for:)`** through the new router.
   Both call sites already have a blueprint (or build a
   `PracticeSuggestion` *from* a blueprint), so the refactor is a small
   diff per call site. Deferred to keep this round small; the router
   doc-comment names the targets so the next agent doesn't have to
   re-derive them.
3. **Surface the SOLVED win on the summary card itself, not only the
   coach note.** Round 14 names the win in the `CoachReadCard` prose;
   the `LookingAheadCard`/`HeroScoreCard` still move silently to the
   next focus. A small "you just solved X" ribbon on the crossing rep's
   summary — reading the same `imToneDrillResolved` the note already
   computes — would make the moment unmissable. Deferred: new summary
   UI wants device QA.
4. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
5. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor pass
   with proper visual QA (and a real device).
6. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` so the Settings AI-usage card AND the
   `CoachReadCard` daily-budget hint refresh mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this
round was compiled or run — not the app, not the test suite. The change is
deliberately small and matches the existing, tested patterns line-for-line:
`SummaryLookingAheadRouter.destination(for:imAvailable:)` is a pure switch
over `RecommendationBiasBlueprint.recommendedMode` that returns the same
`AppDestination` cases the existing duplicate destination-mappers in
`HomeCoachCard` and `ContentView` produce; the IM-mode branch threads
`recommendedScenario` / `recommendedTone` and falls back to
`.timedPractice` when `imAvailable` is false, mirroring those existing
call sites exactly. The new tests exercise the router as a pure value
function — no SwiftUI, no `NavigationPath`, no `SummaryDataStore`, no
`IMModeAvailability` lookup — so they'll run cleanly under `swift test`
when a build host is available.
