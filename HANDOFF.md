# HANDOFF — M24 deferred slate (round 11): tone-drill Adaptation read

## Scope

Round 10 (commit `6b3a8f3`) made the IM tone-drill prescription
*reachable everywhere* — Home, the practice picker, and the post-rep
summary all read the same `toneDrillSignal` and launch the prescribed
scenario + tone. Round 10 named the next move and flagged it #3:

> **Close the Adaptation half: did the drill work?** This round (and
> round 9) *prescribes* the drill across every surface; neither yet
> *observes the response*. The deeper coach-parity move is to read
> whether the tone-match rate on a drilled scenario improved across the
> reps that followed the recommendation, and either reinforce ("calm is
> landing now — hold it") or vary the intervention with an explained
> rationale. That is the "Adaptation" stage in `docs/VISION.md`'s
> coach-parity loop.

This push closes it.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- Before this round the coach *prescribed* the same drill with the same
  flat "your calm tone landed only 25% of the time" line every visit —
  whether the user's tone was clawing its way back up or sliding
  further. A real coach reads the trajectory: when the work is paying
  off they say "it's landing more now — one more"; when it isn't they
  change the approach instead of repeating the identical ask. Now the
  recommendation does the same: it observes the response and adapts the
  rationale, the fourth coach-parity stage.

## What shipped

### Track 1 — The Adaptation read (`IMHistorySummary.toneDrillProgress`)

`Noum/IMHistorySummary.swift`:

- New pure helper `toneDrillProgress(from:scenario:) ->
  IMToneDrillProgress?`. It compares the tone-match hit rate of a
  scenario's **earliest** `window` evaluated reps against its **latest**
  `window`, where `window = min(3, count / 2)` — the exact non-overlap
  bound `relationalTrend` already uses, so the two stretches are always
  disjoint. Reps are ordered oldest→newest and pass through the same
  `.imConversation` + scenario filter and the same missing/whitespace
  `actualTone` exclusion as `toneMatchStats`, so a rep the evaluator
  never read is missing data, not a miss.
- Returns `nil` below 4 evaluated reps (fewer can't separate a first
  stretch from a recent stretch honestly).
- New `toneDrillProgressThreshold = 0.15`, shared with the test suite.
  It sits below the smallest possible non-zero swing (one rep flipping a
  2-rep window is 0.5) and above 0, so a flat history reads `.stalled`
  and any genuine flip reads directional — robust to fractional
  rounding.

### Track 2 — The signal carries the trajectory (`IMToneDrillSignal`)

`Noum/PracticeSupport.swift`:

- New non-gated value type `IMToneDrillProgress` (`direction:
  .recovering / .stalled / .slipping`, `earlierRate`, `recentRate`,
  `windowSize`). It lives next to `IMToneDrillSignal` (also non-gated)
  exactly as that type lives next to the gated helper that produces it.
- `IMToneDrillSignal` gains an **additive** `progress:
  IMToneDrillProgress?` via a custom init that defaults it to `nil` — so
  every existing construction (the engine and all the test fixtures) is
  byte-for-byte unchanged and still compiles.
- `IMHistorySummary.toneDrillSignal` now computes the progress for the
  **winner** scenario only — the other candidates are never prescribed,
  so their trajectory isn't needed — and attaches it to the returned
  signal.

### Track 3 — The blueprint adapts the rationale (`toneDrillBlueprint`)

`Noum/PracticeSupport.swift`:

- `toneDrillBlueprint` now branches on `signal.progress?.direction`:
  - **`.recovering`** — reinforces the drill the user is already on.
    `whyMode`: "your calm tone is landing more often than it was — the
    drill is working. One more focused rep locks it in." `whyNow` names
    the climb ("up to 50% from 0%").
  - **`.slipping`** — varies the intervention rather than repeating the
    identical ask. `whyMode`: "slipped back — same scenario, but change
    how you open it." `whyNow`: "dropped to X% down from Y%, re-run it
    slower and commit to the tone from the first beat."
  - **`.stalled` / `nil`** — keeps the neutral overall-rate prescription,
    unchanged from before this round.
- The recommended **mode / scenario / tone** prefill is identical across
  all three branches — only the rationale adapts. So all four
  recommendation surfaces (`ContentView`, `HomeCoachCard`,
  `PracticeModeSelectionView`, `SummaryView`) pick the adaptive copy up
  for free: they already pass the signal straight through.

### Track 4 — Locked the contracts (`NoumTests/NoumTests.swift`)

- New `IMToneDrillProgressTests` (9 cases): nil on empty + below-4-reps;
  blank/`nil` `actualTone` exclusion keeps a thin history below the bar;
  recovering / slipping / stalled classification with exact earlier and
  recent rates; 6-rep non-overlapping windows at `windowSize == 3`;
  scenario + mode filter isolation; threshold-constant robustness bounds
  (`0 < threshold < 0.5`).
- 4 new engine-copy cases on `IMToneDrillSignalTests`:
  `blueprintReinforcesWhenDrillRecovering`,
  `blueprintVariesWhenDrillSlipping`,
  `blueprintStaysNeutralWhenProgressStalledOrAbsent` (covers both
  `.stalled` and the pre-Adaptation `nil`), and
  `signalCarriesProgressWhenEnoughReps` (end-to-end: a low-but-recovering
  history yields a signal whose `progress.direction == .recovering` for
  the prescribed scenario).

### Vision alignment

- **Pillar #5 — Personalized coaching** and **coach-parity stage #4 —
  Adaptation:** "compare response across multiple attempts and either
  reinforce, vary, or replace the intervention with an explained
  rationale." Rounds 9–10 built the prescribe side; this round adds the
  observe-and-adapt side, which `docs/VISION.md` calls the explicit
  *next standard* ("intervention-aware: did that prescribed work help
  this specific user's stated goal, and what should the coach change
  next?").
- **Anti-goals respected.** No new disconnected AI surface (the read is
  a deterministic helper over the user's own reps). No fabricated data:
  no recovering/slipping claim without ≥4 evaluated reps AND a real
  ≥0.15 swing. No shame: a slip is framed as data plus a constructive
  next step, never a failure state.

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+`toneDrillProgress`
  helper, +`toneDrillProgressThreshold`, winner-progress attach in
  `toneDrillSignal`)
- **Modified:** `Noum/PracticeSupport.swift` (+`IMToneDrillProgress`
  type, +`progress` field/custom-init on `IMToneDrillSignal`, branched
  `toneDrillBlueprint` copy)
- **Modified:** `NoumTests/NoumTests.swift` (+13 tests)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief.

The artifact a user can now hold:

**The coach reads whether the drill is working and changes its tune.**
Keep missing your calm tone in Difficult Conversation and the card
prescribes the re-rep. Start landing it more often and the card stops
nagging — it tells you the drill is working and to push once more.
Backslide and it changes the approach instead of repeating itself. Same
prescription, an honest read of your response on top.

## Future moves

(Updated priority list — round-10 item #3 closed this round; remaining
items carried forward and re-prioritised:)

1. **Thread the trajectory into Ask Noum + the post-rep coach note.**
   This round teaches the *recommendation* to adapt; the persistent chat
   coach and the post-rep `CoachReadCard` don't yet read
   `toneDrillProgress`. `CoachContextBuilder.userContext(...)` could
   carry a one-line "tone-drill trajectory" note (e.g., "calm in
   Difficult Conversation: 0% → 50% over the last 4 reps — recovering")
   so the coach can speak to the response in conversation, not only in
   the next-practice card. Pure-helper + context-string work, no device
   QA — a natural logic-only next round.
2. **Make the `LookingAheadCard` itself launch the drill.** Today the
   summary card *describes* the prescribed IM drill but isn't tappable.
   Threading `scenario`/`tone` + an `onStart` closure through
   `SummaryView`'s init and rendering a subordinate CTA would complete
   the loop on the most-seen post-rep surface. Deferred again: new
   interactive recommendation UI wants real-device QA this build host
   lacks.
3. **Preserve the just-finished IM scenario/tone on "Practice Again".**
   `SummaryView.onPracticeAgain` re-runs an IM rep with
   `.imPractice(scenario: nil, tone: nil)`, dropping the user back on the
   scenario grid even though `imConversationDetails.setup` carries the
   exact scenario + tone. Small, high-confidence, uses the existing
   prefill plumbing.
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
changes were written to match the existing, tested patterns line-for-
line: `toneDrillProgress` mirrors `relationalTrend`'s windowing and
filter shape exactly; the `IMToneDrillSignal` change is purely additive
(a custom init defaulting `progress` to `nil`, so the four callers and
every existing test construct it unchanged); and the `toneDrillBlueprint`
branch is pure string selection over an enum that the new tests cover.
Before this lands in a TestFlight build it still wants a real
`xcodebuild test` and a glance at the home coach card / practice picker
for a test account with (a) a sub-40% tone-match scenario whose recent
reps are improving — to confirm the card reinforces rather than nags —
and (b) one whose recent reps are sliding — to confirm it changes the
approach. Treat the behaviour as designed-for, not observed.
