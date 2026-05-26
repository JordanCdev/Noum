# HANDOFF — M24 deferred slate (round 11): the Adaptation stage — did the prescribed tone drill work?

## Scope

Round 9 made the IM tone-drill prescription exist; round 10 made it
*reachable* on every recommendation surface. Both rounds *prescribed* the
drill — neither *observed the response*. Round 10 named that gap explicitly
as the deepest remaining move (carried as Future move #3):

> **Close the Adaptation half: did the drill work?** This round (and round
> 9) *prescribes* the drill across every surface; neither yet *observes the
> response*. The deeper coach-parity move is to read whether the tone-match
> rate on a drilled scenario improved across the reps that followed the
> recommendation, and either reinforce ("calm is landing now — hold it") or
> vary the intervention with an explained rationale. That is the
> "Adaptation" stage in `docs/VISION.md`'s coach-parity loop.

This push closes it — the single most vision-critical item on the slate.
It also folds in Future move #2 (preserve the just-finished IM scenario +
tone on "Practice Again"), a small, high-confidence adjacent win in the
same IM loop.

User brief, unchanged round to round: "continue from the existing TO-DO,
ensure working towards getting the app towards the vision plan, and all
round A+, make my dream I had come true too, ensure working on the redesign
branch too (very important)."

Translation, this round:

- The coach used to *prescribe* the same tone drill forever (until the hit
  rate recovered enough to self-clear) without ever acknowledging whether
  the user was making progress. A human coach watches the response: if the
  tone is starting to land, they reinforce it; if it's still slipping after
  a fair shot, they change the approach instead of repeating the identical
  ask. Noum now reads that response from the user's own session history and
  adapts the coaching voice accordingly — the **prescribe → observe →
  reinforce / vary** loop the vision calls "Adaptation."

## What shipped

### Track 1 — The Adaptation read (`IMHistorySummary.toneDrillAdaptation`)

`Noum/IMHistorySummary.swift` + `Noum/PracticeSupport.swift`:

- New non-gated payload `IMToneDrillAdaptation` (next to `IMToneDrillSignal`
  in `PracticeSupport.swift`): `scenario`, `targetTone`, a `Response`
  (`.landing` / `.stillMissing`), `priorMatchRate`, `recentMatchRate`, and
  the two window counts.
- New pure helper `IMHistorySummary.toneDrillAdaptation(from:)`. It orders a
  scenario's evaluated reps oldest→newest, takes the most-recent 3 as the
  **response window** and the 3 immediately before as the **baseline
  window** (adjacent, disjoint), and reads the scenario **only** when:
  - it has a full `3 + 3` evaluated reps (fewer can't separate "the gap that
    warranted the drill" from "the response to it"), **and**
  - the prior window was itself sub-threshold (`matchRate < 0.40`) — so the
    drill was genuinely warranted. A good-then-bad run produces no
    "adaptation" (nothing was being drilled).
  `.landing` when the recent window recovers to/above 0.40; `.stillMissing`
  when it holds below. Selection across scenarios mirrors `toneDrillSignal`:
  worst recent hit rate first, tiebreak by more evidence, then freshest.
  **Pure function of session history — no new persistence.**

### Track 2 — The engine varies the coaching voice (`RecommendationBiasEngine`)

`Noum/PracticeSupport.swift`:

- `blueprint(...)` gains an optional `imToneAdaptation:` (defaulted nil,
  alongside last round's `imToneSignal:`), threaded into
  `toneDrillBlueprint(signal:adaptation:)`.
- When the adaptation is for the **same scenario** the signal prescribes,
  the drill copy adapts:
  - **`.stillMissing`** → focus "<Scenario> tone — new angle", and the
    `whyMode` / `whyNow` / `target` change the approach ("you've drilled
    this and it's still slipping — same target, smaller bite: nail the tone
    in your opening, then protect it") instead of repeating the identical
    ask.
  - **`.landing`** → focus "<Scenario> tone — keep going", copy reinforces
    the recovery in progress ("your <tone> tone is starting to land — the
    drill is working … hit <tone> X% of the time, up from Y% earlier"). This
    is reachable while the overall signal still fires because old misses keep
    the lifetime rate below the bar even as the recent window recovers.
- **The structural recommendation never changes** — mode, scenario, and the
  user's committed tone are identical in every branch. Only the framing
  adapts, so the user's chosen tone is respected, never swapped out. A
  different scenario's adaptation never reframes this prescription
  (scenario-identity guard).

### Track 3 — Adaptation rides every surface (`ContentView`, `HomeCoachCard`, `PracticeModeSelectionView`, `SummaryView`)

All four surfaces that compute a recommendation now pass
`IMHistorySummary.toneDrillAdaptation(from:)` next to the signal — the same
availability-guarded pattern round 10 used for the signal (the three
iOS-17-annotated views call it directly; the unannotated `SummaryView` wraps
it in an `if #available` computed property `imToneDrillAdaptation`). So the
adapted voice is consistent wherever the user asks "what next?" — Home, the
picker, and the post-rep "Looking ahead" card all read it.

### Track 4 — "Practice Again" re-runs the same IM setup (`SummaryView`)

`Noum/SummaryView.swift`:

- `onPracticeAgain` for an IM rep used to push
  `.imPractice(scenario: nil, tone: nil)`, dumping the user back on the
  scenario grid. It now captures `entry?.imConversationDetails?.setup` and
  pushes `.imPractice(scenario: imReplaySetup?.scenario, tone:
  imReplaySetup?.targetTone)` — the exact setup they just finished. Lands on
  the IM setup with that scenario + tone pre-selected (one tap to begin),
  consistent with how every other mode's "Practice Again" lands on its own
  pre-configured start screen. Falls back to the grid (the old behaviour)
  for non-IM reps and defensively when the conversation metadata is absent.

### Track 5 — Tests (`NoumTests`)

`NoumTests/NoumTests.swift` — new `IMToneDrillAdaptationTests` (13 tests):

- Engine: nil on empty / below the full-window bar; nil when the prior
  window wasn't a gap; `.landing` on recovery; `.stillMissing` when the
  recent window stays low; ignores non-IM and unqualified scenarios; picks
  the worst recent scenario; ignores reps without an `actualTone` (they
  can't pad the window count).
- Engine→copy: `.stillMissing` varies the copy (new-angle framing);
  `.landing` reinforces ("the drill is working", "up from N%"); a
  different-scenario adaptation is ignored (default copy); no adaptation
  keeps the original prescription copy; and an end-to-end path from raw
  sessions → signal + adaptation → varied blueprint copy.

## Vision alignment

- **Closes the "Adaptation" stage** named throughout `docs/VISION.md` as the
  next coach-parity standard: "intervention-aware: did that prescribed work
  help this specific user … and what should the coach change next?" The loop
  is now **prescribe (round 9–10) → observe → reinforce / vary (this
  round)**, read entirely from the user's own evidence.
- **Pillar #5 (Personalized coaching) + Pillar #4 (Believable progress).**
  Every number is the user's real per-scenario hit rate across two disjoint
  windows — no AI reframe, no fabricated encouragement. The reinforcement
  only fires on an actual recovery; the "new angle" only fires after a real,
  fully-evidenced miss-then-miss window.
- **Anti-goals respected.** No new disconnected AI surface (the change rides
  the existing deterministic engine), no shame copy ("still slipping" is
  paired with a concrete smaller-bite action), and the committed tone is
  never silently swapped — the coach changes the *approach*, not the user's
  stated intent.

## Files touched

- **Modified:** `Noum/PracticeSupport.swift` (+`IMToneDrillAdaptation`
  struct; `blueprint` gains `imToneAdaptation:`; `toneDrillBlueprint` gains
  the two adaptive copy branches)
- **Modified:** `Noum/IMHistorySummary.swift` (+`toneDrillAdaptation(from:)`)
- **Modified:** `Noum/ContentView.swift`, `Noum/HomeCoachCard.swift`,
  `Noum/PracticeModeSelectionView.swift` (+`imToneAdaptation:` arg)
- **Modified:** `Noum/SummaryView.swift` (+`imToneDrillAdaptation` property
  passed to the blueprint; IM "Practice Again" preserves scenario + tone)
- **Modified:** `NoumTests/NoumTests.swift` (+`IMToneDrillAdaptationTests`,
  13 tests)
- **Modified:** `HANDOFF.md` (this file), `docs/CURRENT_STATE.md` (rolling
  summary)

## Branch

`Redesign` — committed and pushed per the user's brief (via the working
branch, opened as a draft PR into `Redesign`).

The artifact a user can now hold:

**The coach now notices whether its own advice is working.** Drill the same
weak scenario a few times: if your tone starts landing again, the coach card
changes from "your tone keeps slipping" to "the drill is working — one more
clean rep locks it in," and reports the recovery (e.g. "67%, up from 0%"). If
it's still slipping after a fair shot, it stops repeating itself and changes
the approach ("same target, smaller bite — nail it in your opening first").
And "Practice Again" after an IM rep now re-runs the exact scenario + tone
you just did, not a fresh grid.

## Future moves

(Updated priority list — round-10 items #2 and #3 closed this round;
remaining items carried forward and re-prioritised:)

1. **Surface the `.landing` win on its own surface when the signal fully
   self-clears.** Right now the reinforcement copy is reachable only while
   the lifetime signal still fires (old misses dragging the rate below 0.40
   even as the recent window recovers). Once the lifetime rate crosses 0.40
   the signal goes nil and the coach silently moves on. A brief, one-shot
   "your <tone> in <scenario> is landing now — nice" acknowledgment on the
   recovery itself (post-rep or Home, self-clearing after one view) would
   close the positive half of the loop even on a clean recovery, not only a
   partial one. Logic is ready (`toneDrillAdaptation` already returns
   `.landing`); this is a small new surface that wants real-device QA.
2. **Make the `LookingAheadCard` itself launch the drill.** Still the
   most-seen post-rep surface that *describes* but doesn't *launch* the IM
   drill. Thread `scenario`/`tone` + an `onStart` closure through
   `SummaryView`'s init and render a modest subordinate CTA only when the
   card carries a concrete IM drill. Deferred for the same reason as prior
   rounds: new interactive recommendation UI wants real-device QA this build
   host lacks.
3. **Generalise Adaptation beyond IM tone.** The same prescribe → observe →
   reinforce/vary pattern applies to the filler / pace / structure drills
   that `DrillEngineV2` recommends. `RecommendationLearningStore` already
   records `scoreDelta` / `fillerDelta` / `durationDelta` per followed
   recommendation — wiring those into a general "did the drill move the
   targeted metric?" read would lift Adaptation from one mode to the whole
   drill system.
4. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
5. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor pass
   with proper visual QA (and a real device).
6. **Rate-limiter live refresh.** Make `AIRateLimiter` an `ObservableObject`
   so the Settings AI-usage card AND the `CoachReadCard` daily-budget hint
   refresh mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this
round was compiled or run — not the app, not the test suite. The changes
were written to match the existing, tested patterns line-for-line:

- `toneDrillAdaptation` mirrors `toneDrillSignal`'s structure (same
  `.imConversation` / scenario / blank-`actualTone` filters via the shared
  `matches(...)` and `dominantEvaluatedTone(...)` helpers, same
  worst-first/more-evidence/freshest selection), so it inherits the same
  honest-data contracts.
- The four caller edits are byte-for-byte the round-10 `imToneSignal:`
  pattern with the method name swapped; `SummaryView`'s `if #available`
  property is a copy of the existing `imToneDrillSignal` property.
- The new tests reuse the `imSession` / `input()` fixture shapes from
  `IMToneDrillSignalTests`.

Before this lands in a TestFlight build it still wants a real `xcodebuild
test` and a glance at (a) the Home coach card for a test account that has
drilled one IM scenario 6+ times — confirm the copy reads "the drill is
working" on a recovering scenario and "new angle" on a still-missing one —
and (b) IM "Practice Again", to confirm it lands on the same scenario + tone.
Treat the behaviour as designed-for, not observed.
