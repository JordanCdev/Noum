# HANDOFF — M24 deferred slate (round 13): surface the tone-drill WIN, not only the in-flight drill

## Scope

Round 12 (the prior HANDOFF) threaded the IM tone-drill *Adaptation* read
into the two surfaces the user talks to between reps — Ask Noum and the
post-rep coach note — so the coach speaks to whether a prescribed drill is
recovering, stalled, or slipping. Round 12 named the next move and flagged
it #3 in its "Future moves":

> **Surface the trajectory even when the scenario has *recovered above*
> the drill bar.** Today both new surfaces only read the trajectory while
> the scenario is still a prescribed drill (sub-40%). A scenario that
> climbed from 10% to 60% no longer produces a signal, so the coach stops
> acknowledging the win the moment it's won. A standalone
> "recently-resolved tone" read (the `resolved` analog of `TrendDirection`)
> would let the coach say "your calm tone in Difficult Conversation is
> solved — it's holding at 60%+." Pure-helper work.

This push closes it.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- `IMHistorySummary.toneDrillSignal` and `toneDrillProgress` both fire
  *only while a scenario is still below the drill bar*. That is correct
  for the recommendation engine — once a gap is closed, stop prescribing
  it — but it means the moment the user finally lands their calm tone in
  Difficult Conversation, the coach goes quiet about it. A real coach who
  pushed you on that tone for two weeks notices when it finally holds and
  names the win before moving you on. This round gives the coach that
  read.

## What shipped

### Track 1 — the pure helper (`IMHistorySummary`)

`Noum/IMHistorySummary.swift`:

- New pure helper `toneDrillResolved(from:) -> IMToneDrillResolved?`, the
  complement to `toneDrillSignal`. It scans every scenario and fires only
  on **genuine turnaround evidence**, all required:
  - enough evaluated reps to compare two disjoint windows (reuses the same
    4-rep / `min(3, count/2)` bar as `toneDrillProgress`)
  - the **earliest** window was *below* the drill bar — a real gap existed,
    not steady competence the user always had
  - the **latest** window holds *at or above* the new
    `toneDrillResolvedHoldRate` (0.6) — the climb stuck, it isn't one lucky
    rep
  - the **overall** rate is at/above the drill bar, so the active
    `toneDrillSignal` has already self-cleared for this scenario — "solved"
    and "still drilling" can never both fire for the same scenario (they
    CAN co-exist across two scenarios: one solved, another being drilled)
- Returns the single **freshest** win (most-recent evaluated rep first;
  tiebreak by larger climb, then more evidence) so the coach acknowledges
  what the user just earned, not a month-old recovery. `nil` when nothing
  clears the bar — the coach stays quiet rather than inventing a victory.
- New constant `toneDrillResolvedHoldRate = 0.6`, asserted in tests to sit
  above the 0.4 drill bar so "solved" means *held*, not *scraped over*.

### Track 2 — the type (`PracticeSupport`)

`Noum/PracticeSupport.swift`:

- New `IMToneDrillResolved: Equatable` (`scenario`, `targetTone`,
  `earlierRate`, `recentRate`, `evaluatedCount`, `lastEvaluatedDate`),
  placed beside `IMToneDrillSignal`/`IMToneDrillProgress` with a doc
  comment spelling out the mutual-exclusion-per-scenario contract.

### Track 3 — Ask Noum reads the win (`CoachContextBuilder`)

`Noum/CoachContextBuilder.swift`:

- New pure helper `toneDrillResolvedLines(for: IMToneDrillResolved) ->
  [String]`: the same terse, citeable register as `toneDrillTrajectoryLines`
  ("Calm tone in Difficult Conversation: tone-match 0% to 100% (earliest vs
  latest reps) — holding above the drill bar now.") plus a guidance clause
  that tells the model to name the win once and point the user at the next
  target rather than re-prescribing a beaten drill.
- `userContext(...)` now appends a `TONE-DRILL SOLVED` section, computed
  from `IMHistorySummary.toneDrillResolved(from: sessions)`, right after
  the `TONE-DRILL TRAJECTORY` section (its in-flight sibling). Zero new
  parameters — computed from the `sessions` the function already receives,
  exactly as the trajectory section does, so every call site is unchanged.
- System-prompt intelligence-floor **rule #9**: when `TONE-DRILL SOLVED` is
  present, name the win once and move the user to the next target — never
  re-prescribe the solved drill, never restate the old miss as if still
  open, never claim a drill *caused* the recovery (observed association
  only, same honesty bar as rules #6–#8).

### Track 4 — locked the contracts (`NoumTests/NoumTests.swift`)

- `IMToneDrillResolvedTests` (8 cases): nil on empty; nil below 4 evaluated
  reps; detects the 0%→100% turnaround (scenario/tone/rates/count); nil when
  the user never struggled (earliest window already above the bar); nil when
  the scenario is still an active drill (overall 37.5% < 40%); nil on a
  bouncy recovery whose latest window doesn't hold ≥60%; picks the freshest
  win across two resolved scenarios; and the hold-rate constant sits above
  the drill bar.
- `ToneDrillResolvedContextTests` (4 cases): the resolved line cites the
  scenario + tone + "0% to 100%" + "holding above the drill bar" + a
  "next target" move; `userContext` surfaces the `TONE-DRILL SOLVED`
  section end-to-end; omits it when nothing is resolved; and — the
  coherence case — a drill in one scenario and a win in another **both**
  surface (`TONE-DRILL TRAJECTORY` for Work Update + `TONE-DRILL SOLVED`
  for Networking) in a single context block.

### Vision alignment

- **Pillar #5 — Personalized coaching** and **coach-parity stage #4 —
  Adaptation.** `docs/VISION.md` stage 4 is "reinforce, vary, or replace
  the intervention with an explained rationale." Acknowledging a *solved*
  intervention is the missing terminal state of that loop: a coach who only
  ever says "keep working on it" and never "you've got this one — next" is
  not adapting, just nagging. This round lets the coach close the loop on a
  win and redirect.
- **Anti-goals respected.** No new disconnected AI surface — the read is a
  deterministic helper over the user's own reps. No fabricated data: nil
  below 4 evaluated reps, nil without a genuine sub-bar → held turnaround.
  No hollow celebration (anti-goal "we don't celebrate hollow ones"): a
  scenario the user was always good at never reads as a "win," and a
  scrape-over-the-bar recovery is held to the 60% bar before it counts.
  No causation claim: rule #9 and the guidance line forbid it.

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+`toneDrillResolved` helper,
  +`toneDrillResolvedHoldRate` constant)
- **Modified:** `Noum/PracticeSupport.swift` (+`IMToneDrillResolved` type)
- **Modified:** `Noum/CoachContextBuilder.swift` (+`toneDrillResolvedLines`
  helper, +`TONE-DRILL SOLVED` section in `userContext`, +system-prompt
  rule #9)
- **Modified:** `NoumTests/NoumTests.swift` (+12 tests across 2 structs)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief.

The artifact a user can now hold:

**The coach acknowledges the win, then moves you on.** Grind your calm tone
in Difficult Conversation from missing it every time up to landing it
consistently, and the coach no longer goes silent the moment you cross the
line. Open Ask Noum and it knows: "your calm tone in Difficult Conversation
is holding now — 0% to 100% — here's the next thing." The next-practice card
still rightly moves to your next-weakest scenario; the conversation closes
the loop on the one you just beat instead of pretending it's still open.

## Future moves

(Updated priority list — round-12 item #3 closed this round; remaining
items carried forward and re-prioritised:)

1. **The post-rep note should headline the win too.** This round threads the
   resolved read into Ask Noum; the post-rep `CoachReadCard` still only
   speaks to a drill *in flight* (round-12 branch 0d, recovering/slipping).
   The cleanest add: a momentum branch that, when the just-finished rep is
   the one that pushed a scenario across the bar, headlines "you've solved
   your calm tone in Difficult Conversation" once. Gating is the subtlety —
   it must fire on the crossing rep, not repeat every rep thereafter. Likely
   wants a small "was-resolved-as-of-the-previous-rep" comparison in the
   finalizer. Pure-helper + deterministic-copy work, no device QA.
2. **Make the `LookingAheadCard` itself launch the drill.** Today the
   summary card *describes* the prescribed IM drill but isn't tappable.
   Threading `scenario`/`tone` + an `onStart` closure through
   `SummaryView`'s init and rendering a subordinate CTA would complete the
   loop on the most-seen post-rep surface. Deferred: new interactive
   recommendation UI wants real-device QA this build host lacks.
3. **Preserve the just-finished IM scenario/tone on "Practice Again".**
   `SummaryView.onPracticeAgain` re-runs an IM rep with
   `.imPractice(scenario: nil, tone: nil)`, dropping the user back on the
   scenario grid even though `imConversationDetails.setup` carries the exact
   scenario + tone. Small, high-confidence, uses the existing prefill
   plumbing.
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
`toneDrillResolved` reuses the already-tested `toneDrillProgress` +
`toneMatchStats` + `dominantEvaluatedTone` building blocks and adds no new
parsing; `IMToneDrillResolved` is a plain `Equatable` struct beside its two
siblings; `toneDrillResolvedLines` mirrors `toneDrillTrajectoryLines`
exactly; and the new `userContext` section is a copy of the trajectory
section's shape (compute from `sessions`, append a heading + helper lines).
The test fixtures (`imSession` + `IMConversationDetails`) are byte-for-byte
the ones the round-12 tests use. Before this lands in a TestFlight build it
still wants a real `xcodebuild test` and a glance at Ask Noum for a test
account that ground a sub-40% scenario back up above 60% — to confirm the
chat coach names the win and redirects rather than restating the old miss.
Treat the behaviour as designed-for, not observed.
