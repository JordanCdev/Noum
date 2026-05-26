# HANDOFF — M24 deferred slate (round 10): tone-drill on the picker + summary surfaces

## Scope

Round 9 (commit `0b55e2b`) closed the IM tone-drill loop on **Home**:
when one IM scenario reliably misses its committed tone, the home coach
card stops giving generic advice and prescribes a one-tap re-rep of the
exact scenario + tone. Round 9 named the next move explicitly and flagged
it #1:

> **Offer the same drill from the other recommendation surfaces.**
> `PracticeModeSelectionView.computeRecommendation` and `SummaryView`
> also call `RecommendationBiasEngine.blueprint` but currently pass no
> signal, and `PracticeModeSelectionView.appDestination(for: .imConversation)`
> launches with `scenario: nil, tone: nil` even when the blueprint
> carries them. The natural next round is to (a) pass the signal at
> those two sites and (b) have their IM destination honour
> `blueprint.recommendedScenario` / `recommendedTone`, so the drill is
> offered consistently wherever the user lands — not only on Home.

This push closes it.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- Before this round the drill was a Home-only prescription. A user who
  opened the practice picker, or who just finished a non-IM rep, never
  saw it. Now **all four** surfaces that compute a recommendation read
  the same signal, and the two that launch IM honour the prescribed
  scenario + tone — so the coach gives the same answer no matter where
  the user is standing when they ask "what should I practice?"

## What shipped

### Track 1 — The mode picker passes the signal and honours it (`PracticeModeSelectionView`)

`Noum/PracticeModeSelectionView.swift`:

- **Passes the signal.** `computeRecommendation()` now hands
  `IMHistorySummary.toneDrillSignal(from: sessionStore.sessions)` into
  `RecommendationBiasEngine.blueprint(...)`, guarded on
  `IMModeAvailability.isAvailable` — byte-for-byte the same pattern
  `ContentView` and `HomeCoachCard` already use, so the picker's
  recommended-reason line now reflects the drill (`whyNow` reports the
  observed hit rate) when one is live.
- **Caches + honours scenario/tone.** Two new `@State` fields
  (`cachedRecommendedScenario`, `cachedRecommendedTone`) capture
  `blueprint.recommendedScenario` / `recommendedTone`.
  `appDestination(for: .imConversation)` now returns
  `.imPractice(scenario: cachedRecommendedScenario, tone: cachedRecommendedTone)`
  instead of the old `nil, nil`. Because the picker's IM quick-start
  arms `PracticeModeQuickStart` and `IMPracticeView.onAppear` jumps
  straight into the conversation when both are prefilled, a one-tap IM
  launch from the picker now drops the user **directly into the
  prescribed drill** — the same one-tap behaviour Home has.

### Track 2 — The post-rep summary passes the signal (`SummaryView`)

`Noum/SummaryView.swift`:

- New `imToneDrillSignal` computed property wraps the lookup in
  `if #available(iOS 17.0, *)` because `SummaryView` is **not**
  annotated `@available(iOS 17.0, *)` (unlike `ContentView` /
  `HomeCoachCard` / `PracticeModeSelectionView`), and
  `IMHistorySummary` is iOS-17-gated. `IMToneDrillSignal` itself is
  non-gated (it lives next to the engine in `PracticeSupport.swift`),
  so the property's return type compiles in the unannotated view.
- `summaryRecommendation` passes that signal to the blueprint. The only
  consumer is `lookingAheadHint`, whose `blueprint.recommendedMode !=
  currentMode` guard means: **after a non-IM rep** with a live signal,
  the "Looking ahead" card now says "try IM Conversation" and its
  `whyNow` names the exact weak scenario and the observed hit rate,
  instead of a generic mode nudge. (After an IM rep the card stays
  suppressed — you don't suggest the mode you just finished.)

### Track 3 — Locked the destination contract both ways (`IMToneDrillSignalTests`)

`NoumTests/NoumTests.swift`:

- Extended `blueprintWithoutSignalKeepsNormalBias` to also assert
  `recommendedTone == nil` on a non-IM recommendation. This is the
  invariant the new picker wiring leans on: the engine sets
  `recommendedScenario`/`recommendedTone` **only** when the recommended
  mode is IM, so forwarding them blindly into the IM destination is
  safe — a free-choice IM launch (engine recommended something else)
  carries `nil, nil` and opens the normal scenario grid, never a stale
  prefill.
- New `goalBasedIMRecommendationCarriesScenarioAndTone` locks the other
  half: a calmer-delivery / social / warm-voice profile prioritises IM,
  and the blueprint carries a concrete `socialCatchUp` + `warm` — so the
  picker prefills the goal-based default (not just the tone drill),
  matching Home.

### Vision alignment

- **Pillar #5 — Personalized coaching** and the **coach-parity
  Intervention stage.** Round 9 made the prescription exist; this round
  makes it *reachable*. A human coach doesn't only mention the right
  drill when you happen to be on one screen — they give the same answer
  whether you ask before practice (the picker) or right after a rep (the
  summary). Consistency of the recommendation across surfaces is part of
  the coach being trustworthy, not just present.
- **Anti-goals respected.** No new disconnected AI surface (every change
  routes through the existing deterministic engine + signal), no
  fabricated data (the same ≥3-rep / sub-40% bar gates everything,
  self-clears at ≥40%), no shame copy. The off-IM `nil` contract means
  the picker never lies about a drill that isn't warranted.

## Files touched

- **Modified:** `Noum/PracticeModeSelectionView.swift` (+~20 LOC — two
  `@State` fields, `imToneSignal:` arg + availability guard in
  `computeRecommendation`, cache the blueprint scenario/tone, honour them
  in `appDestination`)
- **Modified:** `Noum/SummaryView.swift` (+~12 LOC — `imToneDrillSignal`
  computed property with `if #available` guard; pass it into
  `summaryRecommendation`)
- **Modified:** `NoumTests/NoumTests.swift` (+~30 LOC — extended one test,
  added `goalBasedIMRecommendationCarriesScenarioAndTone`)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief.

The artifact a user can now hold:

**The tone drill the home card prescribes is now the same answer the
practice picker and the post-rep summary give.** Open the picker with a
weak-tone scenario on record and a one-tap IM launch drops you straight
into that exact scenario + tone; finish a Timed rep and the "Looking
ahead" card names the scenario you keep missing and your real hit rate.
The coach is consistent wherever the user lands — and it all self-clears
the moment the hit rate recovers.

## Future moves

(Updated priority list — round-9 item #1 closed this round; remaining
items carried forward and re-prioritised:)

1. **Make the `LookingAheadCard` itself launch the drill.** Today the
   summary card *describes* the prescribed IM drill but isn't tappable
   (it's deliberately informational, placed below the in-the-moment drill
   CTA). Adding a one-tap launch — thread `scenario`/`tone` + an `onStart`
   closure through `SummaryView`'s init (next to `onPracticeAgain`) and
   render a modest subordinate CTA only when the card carries a concrete
   IM drill — would complete the loop on the most-seen post-rep surface.
   Deferred here for the same reason round 9 deferred *this* round: new
   interactive recommendation UI wants real-device QA, which this build
   host lacks. Logic-only wiring shipped first; the button is the next
   honest step.
2. **Preserve the just-finished IM scenario/tone on "Practice Again".**
   `SummaryView.onPracticeAgain` re-runs an IM rep with
   `.imPractice(scenario: nil, tone: nil)`, dropping the user back on the
   scenario grid even though `imConversationDetails.setup` carries the
   exact scenario + tone they just did. "Practice again" should re-run
   the *same* setup. Small, high-confidence, uses the existing prefill
   plumbing — left out of this round only to keep it focused on the
   tone-drill recommendation loop.
3. **Close the Adaptation half: did the drill work?** This round (and
   round 9) *prescribes* the drill across every surface; neither yet
   *observes the response*. The deeper coach-parity move is to read
   whether the tone-match rate on a drilled scenario improved across the
   reps that followed the recommendation (reuse the existing
   `RecommendationOutcome` / `RecommendationLearningStore` machinery), and
   either reinforce ("calm is landing now — hold it") or vary the
   intervention with an explained rationale. That is the "Adaptation"
   stage in `docs/VISION.md`'s coach-parity loop.
4. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
5. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor pass
   with proper visual QA (and a real device).
6. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` so the Settings AI-usage card AND the
   `CoachReadCard` daily-budget hint refresh mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes were written to match the existing, tested patterns line-for-line:
the picker's `imToneSignal:` call is byte-for-byte the `ContentView` /
`HomeCoachCard` pattern; the `appDestination` change reuses the exact
`.imPractice(scenario:tone:)` shape `ContentView` already routes to; the
new test reuses the existing `IMToneDrillSignalTests` `input()` helper and
the `CoachingProfile` builder shape from elsewhere in the suite. The
`SummaryView` `if #available` guard is the conservative choice for the one
unannotated caller — it compiles whether or not the deployment target
makes the guard redundant. Before this lands in a TestFlight build it
still wants a real `xcodebuild test` and a glance at (a) the practice
picker for a test account with a sub-40% tone-match scenario, to confirm
a one-tap IM launch lands in the prescribed scenario + tone, and (b) the
post-rep "Looking ahead" card after a Timed rep, to confirm it names the
weak scenario and the hit rate. Treat the behaviour as designed-for, not
observed.
