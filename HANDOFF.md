# HANDOFF — M24 deferred slate (round 12): thread the tone-drill trajectory into the chat coach + post-rep note

## Scope

Round 11 (commit `c19d4e4`) taught the next-practice recommendation card
to *adapt* to the IM tone-drill Adaptation read: it observes whether the
prescribed scenario's tone-match rate is recovering, stalled, or slipping
and changes its rationale accordingly. Round 11 named the next move and
flagged it #1:

> **Thread the trajectory into Ask Noum + the post-rep coach note.** This
> round teaches the *recommendation* to adapt; the persistent chat coach
> and the post-rep `CoachReadCard` don't yet read `toneDrillProgress`.
> `CoachContextBuilder.userContext(...)` could carry a one-line "tone-drill
> trajectory" note … so the coach can speak to the response in
> conversation, not only in the next-practice card. Pure-helper +
> context-string work, no device QA — a natural logic-only next round.

This push closes it — on both surfaces.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- The Adaptation read already lived on the signal (`IMToneDrillSignal.
  progress`) and already changed the *card's* copy. But the two surfaces
  the user actually talks to between reps — the persistent Ask Noum chat
  coach and the post-rep coach note on the Summary — still spoke as if the
  drill had never moved. A real coach who tells you in the recommendation
  card "your calm tone is recovering" doesn't then, ten seconds later in
  conversation, repeat the flat "you miss it 25% of the time." Now all
  three surfaces read the same trajectory.

## What shipped

### Track 1 — Ask Noum reads the trajectory (`CoachContextBuilder`)

`Noum/CoachContextBuilder.swift`:

- New pure helper `toneDrillTrajectoryLines(for: IMToneDrillSignal) ->
  [String]?`. Turns the Adaptation read on a signal into the terse,
  citeable register the system prompt's intelligence floor expects: a data
  line ("Calm tone in Difficult Conversation: tone-match 0% to 50%
  (earliest vs latest reps) — recovering.") plus a per-direction guidance
  clause (reinforce / change-the-open / name-the-plateau). Returns `nil`
  when the signal carries no `progress` — the coach never invents a
  movement it can't see.
- `userContext(...)` now appends a `TONE-DRILL TRAJECTORY` section,
  computed from `IMHistorySummary.toneDrillSignal(from: sessions)`, right
  after `INTERVENTION RESPONSE` (its IM analog). Zero new parameters — it
  computes from the `sessions` the function already receives, exactly as
  the `MOMENTUM` section does, so every one of the ~dozen call sites is
  unchanged.
- System-prompt intelligence-floor **rule #8**: when `TONE-DRILL
  TRAJECTORY` is present, reinforce a recovering drill, change the approach
  on a slipping one, treat a stalled one as a plateau — never re-issue the
  original miss, never claim a drill *caused* the change (observed
  association only, same honesty bar as `INTERVENTION RESPONSE` and
  `REAL-WORLD TRANSFER`).

### Track 2 — The post-rep coach note reads it too (`PostRepCoachNoteService`)

`Noum/PostRepCoachNoteService.swift`:

- `PostRepCoachNoteInput` gains three **additive** fields —
  `imToneDrillProgress: IMToneDrillProgress?`, `imToneDrillScenarioTitle:
  String?`, `imToneDrillToneTitle: String?` — all defaulted `nil`, so every
  existing construction (the finalizer, the voice-change regen helper, and
  the test fixtures) compiles byte-for-byte unchanged. Titles travel as
  plain strings so the Foundation-only service stays decoupled from the IM
  enums.
- New deterministic momentum **branch 0d** in `metricSentence`: when the
  just-finished rep was an IM conversation whose committed tone is
  recovering or slipping (stalled falls through — a flat read isn't worth
  bumping the per-rep metric note), the note headlines the trajectory ahead
  of the per-rep metrics, via voice-shaped `imToneTrajectorySentence` (7
  voices × 2 directions; reports the climb/drop, no shame, no exclamation).
- The AI polish path (`userPrompt`) gets the same fact appended to its
  `MOMENTUM` block, so an AI-backed note can reference the trajectory too
  rather than losing it.

### Track 3 — The finalizer computes the read (`PracticeSessionFinalizer`)

`Noum/PracticeSupport.swift`:

- `recordPostRepCoachNote(for:)` now, for IM reps only, computes
  `IMHistorySummary.toneDrillProgress(from: allSessions, scenario:)` for the
  just-finished rep's scenario and passes it (with the scenario + committed
  tone titles) into `PostRepCoachNoteInput`. Non-IM reps pass `nil` for all
  three — the branch never fires off-mode.

### Track 4 — Locked the contracts (`NoumTests/NoumTests.swift`)

- `ToneDrillTrajectoryContextTests` (6 cases): `toneDrillTrajectoryLines`
  nil-when-no-progress; recovering reinforces + cites "0% to 50%"; slipping
  changes the approach + cites "100% to 0%"; stalled names the plateau;
  end-to-end `userContext` surfaces the section for a recovering history;
  and omits it entirely when no IM history clears the drill bar.
- `PostRepCoachNoteToneTrajectoryTests` (5 cases): recovering headlines the
  deterministic note (cites scenario + tone + both percentages, no "!");
  slipping points at a different opening; stalled and non-IM both fall
  through to the metric note (scenario name absent); `imToneTrajectorySentence`
  is voice-shaped and brand-clean across all 7 voices.

### Vision alignment

- **Pillar #5 — Personalized coaching** and **coach-parity stage #4 —
  Adaptation.** `docs/VISION.md`'s development instructions require every
  coaching feature to strengthen a stage of the loop *coherently across
  surfaces*: "Surface it coherently in Ask Noum, post-rep feedback, and the
  next-practice recommendation." Round 11 did the recommendation; this round
  finishes the set so the coach's read of "is the work landing?" is the same
  whether the user reads the card, the post-rep note, or asks in chat.
- **Anti-goals respected.** No new disconnected AI surface — both reads are
  deterministic helpers over the user's own reps; the AI path only *polishes*
  a fact the deterministic path already owns. No fabricated data: nil below
  4 evaluated reps everywhere. No shame: a slip is framed as a percentage
  plus a constructive "open it differently," never a failure state. No
  causation claim: rule #8 and the existing prompt rules forbid it.

## Files touched

- **Modified:** `Noum/CoachContextBuilder.swift` (+`toneDrillTrajectoryLines`
  helper, +`TONE-DRILL TRAJECTORY` section in `userContext`, +system-prompt
  rule #8)
- **Modified:** `Noum/PostRepCoachNoteService.swift` (+3 additive
  `PostRepCoachNoteInput` fields, +branch 0d, +`imToneTrajectorySentence`,
  +AI `MOMENTUM` line)
- **Modified:** `Noum/PracticeSupport.swift` (+IM-trajectory computation in
  `recordPostRepCoachNote`)
- **Modified:** `NoumTests/NoumTests.swift` (+11 tests across 2 structs)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief.

The artifact a user can now hold:

**The coach's read of "is the work landing?" is consistent everywhere.**
Keep missing your calm tone in Difficult Conversation, start landing it
more often, and not only does the next-practice card stop nagging — the
post-rep note headlines the climb ("your calm tone in Difficult
Conversation is recovering — 0% to 50%"), and if you open Ask Noum and ask
about it, the chat coach already knows the drill is working and tells you
to push once more. Backslide and all three change their tune to a different
opening instead of repeating the same line.

## Future moves

(Updated priority list — round-11 item #1 closed this round; remaining
items carried forward and re-prioritised:)

1. **Make the `LookingAheadCard` itself launch the drill.** Today the
   summary card *describes* the prescribed IM drill but isn't tappable.
   Threading `scenario`/`tone` + an `onStart` closure through
   `SummaryView`'s init and rendering a subordinate CTA would complete the
   loop on the most-seen post-rep surface. Deferred: new interactive
   recommendation UI wants real-device QA this build host lacks.
2. **Preserve the just-finished IM scenario/tone on "Practice Again".**
   `SummaryView.onPracticeAgain` re-runs an IM rep with
   `.imPractice(scenario: nil, tone: nil)`, dropping the user back on the
   scenario grid even though `imConversationDetails.setup` carries the exact
   scenario + tone. Small, high-confidence, uses the existing prefill
   plumbing.
3. **Surface the trajectory even when the scenario has *recovered above*
   the drill bar.** Today both new surfaces only read the trajectory while
   the scenario is still a prescribed drill (sub-40% overall). A scenario
   that climbed from 10% to 60% no longer produces a signal, so the coach
   stops acknowledging the win the moment it's won. A standalone
   "recently-resolved tone" read (the `resolved` analog of
   `TrendDirection`) would let the coach say "your calm tone in Difficult
   Conversation is solved — it's holding at 60%+." Pure-helper work.
4. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
5. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor pass
   with proper visual QA (and a real device).
6. **Rate-limiter live refresh.** Make `AIRateLimiter` an `ObservableObject`
   so the Settings AI-usage card AND the `CoachReadCard` daily-budget hint
   refresh mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes were written to match the existing, tested patterns line-for-line:
`toneDrillTrajectoryLines` and the new `userContext` section reuse the
already-tested `IMHistorySummary.toneDrillSignal`; the three new
`PostRepCoachNoteInput` fields are additive (defaulted `nil`, custom init
unchanged for callers); branch 0d mirrors the existing momentum branches
(0a–0c) exactly; and `imToneTrajectorySentence` follows the per-voice shape
of every other sentence builder in the file. Before this lands in a
TestFlight build it still wants a real `xcodebuild test` and a glance at (a)
Ask Noum for a test account with a sub-40% tone-match scenario whose recent
reps are improving — to confirm the chat coach reinforces — and (b) the
post-rep `CoachReadCard` after an IM rep in that scenario — to confirm it
headlines the trajectory rather than the per-rep metric. Treat the
behaviour as designed-for, not observed.
