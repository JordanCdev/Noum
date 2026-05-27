# HANDOFF — M24 deferred slate (round 13): teach the coach to acknowledge a *closed* tone gap

## Scope

Round 12 (commit `7505d71`) threaded the IM tone-drill *trajectory* read
into the two surfaces the user talks to between reps — Ask Noum and the
post-rep coach note — so a drill that is recovering/slipping/stalled reads
the same in conversation as it does on the next-practice card. Round 12
named the next move and flagged it #3:

> **Surface the trajectory even when the scenario has *recovered above* the
> drill bar.** Today both new surfaces only read the trajectory while the
> scenario is still a prescribed drill (sub-40% overall). A scenario that
> climbed from 10% to 60% no longer produces a signal, so the coach stops
> acknowledging the win the moment it's won. A standalone "recently-resolved
> tone" read (the `resolved` analog of `TrendDirection`) would let the coach
> say "your calm tone in Difficult Conversation is solved — it's holding at
> 60%+." Pure-helper work.

This push closes it — on the same two surfaces, with the same honest bar.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- `IMToneDrillSignal` is built to *stop* reporting a scenario the moment its
  overall hit rate climbs back over the 40% drill bar — that's correct for a
  recommendation engine (don't keep prescribing a drill that's done). But it
  meant every coaching surface went silent on the gap at the exact moment
  the user earned a word for closing it. A real coach who spent three weeks
  on your calm tone in Difficult Conversation doesn't just stop mentioning it
  once you've got it — they say "that's holding now, let's move on." This
  round gives the coach that line.

## What shipped

### Track 1 — The resolved read (`IMHistorySummary` + model)

`Noum/PracticeSupport.swift` (model) + `Noum/IMHistorySummary.swift`
(computation):

- New `IMToneDrillResolved` value type (next to `IMToneDrillSignal` /
  `IMToneDrillProgress`): the scenario, the committed tone, the overall
  `matchRate` (now ≥ the drill bar), and the earliest/latest window rates so
  "was 0%, now 100%" reads identically to the trajectory line.
- New `toneDrillResolvedThreshold = 0.6` — strictly above the 0.4 drill bar,
  so "solved" means a confident hold, not a scrape over the line.
- New per-scenario `toneDrillResolved(from:scenario:)`: returns a read only
  when the scenario cleared the drill bar overall **and** its earliest window
  sat below the bar **and** its latest window holds at/above the resolved
  bar. Reuses the already-tested `toneMatchStats` (overall rate),
  `toneDrillProgress` (the two disjoint windows + the nil-below-4-reps
  contract), and `dominantEvaluatedTone` (the tone) — so a "resolved" claim
  is exactly as conservative as the drill it closes. **Mutually exclusive
  with `toneDrillSignal` by construction**: the drill requires overall <
  0.4, this requires overall ≥ 0.4, so a scenario can never be both at once.
- New cross-scenario `toneDrillResolved(from:)`: the single most
  worth-acknowledging win (strongest current hold, tiebreak freshest rep) for
  the chat coach, which has no "current rep".

### Track 2 — Ask Noum acknowledges the win (`CoachContextBuilder`)

`Noum/CoachContextBuilder.swift`:

- The `userContext` tone section is now a precedence: an **active drill**
  (`toneDrillSignal`) still emits `TONE-DRILL TRAJECTORY` (round 12,
  unchanged); only when **no** scenario is still a drill does it emit a new
  `TONE-DRILL RESOLVED` section from `toneDrillResolved(from:)`. One tone read
  at a time — current work takes priority, the resolved win is surfaced when
  there's nothing left to fix.
- New pure helper `toneDrillResolvedLines(for:)` — same terse, citeable
  register as the trajectory helper (data line "Confident tone in Networking:
  tone-match 0% to 100% (earliest vs latest reps) — gap closed, now holding."
  + a guidance clause). Non-optional: the resolved struct is already
  evidence-validated, so there's no nil case to guard.
- System-prompt intelligence-floor **rule #9**: acknowledge a resolved gap
  once, plainly, then move focus to a new target — never re-prescribe the
  resolved drill, never re-cite the old miss, never oversell (a closed gap is
  a quiet, earned win, not a fanfare); observed association, not causation.

### Track 3 — The post-rep note reads it too (`PostRepCoachNoteService`)

`Noum/PostRepCoachNoteService.swift`:

- `PostRepCoachNoteInput` gains one **additive** field — `imToneDrillResolved:
  Bool = false` — so every existing construction (the finalizer, the
  voice-change regen helper, the test fixtures) compiles unchanged.
- New deterministic momentum **branch 0d** (above the recovering/slipping
  branch, now 0e): when the just-finished IM rep landed in a resolved
  scenario, the note headlines the lock-in via voice-shaped
  `imToneResolvedSentence` (7 voices, single direction; reports the climb that
  closed it, frames it as held/closed + a forward nudge, no exclamation, no
  shame). It sits above the trajectory branch because a resolved scenario
  still reads as *recovering* on the raw windows — "you've held this" is the
  truer, more final line than "this is climbing".
- The AI polish path (`userPrompt`) gets the resolved fact in its `MOMENTUM`
  block too ("gap closed, now holding — acknowledge once, do not
  re-prescribe"), and the recovering/slipping line is now gated off when
  resolved so the AI never gets both.

### Track 4 — The finalizer computes the read (`PracticeSupport`)

`Noum/PracticeSupport.swift`:

- `recordPostRepCoachNote(for:)` now, for IM reps only, sets
  `imToneDrillResolved` from `IMHistorySummary.toneDrillResolved(from:
  allSessions, scenario:)` for the just-finished rep's scenario. Non-IM reps
  pass `false` — the branch never fires off-mode.

### Track 5 — Locked the contracts (`NoumTests/NoumTests.swift`)

- `IMToneDrillResolvedTests` (8 cases): nil on empty / below 4 reps; the
  canonical "gap closed" read (cites 0%→100%, 50% overall, tone, scenario);
  nil while still an active drill (and the signal still prescribes it); nil
  when the gap never existed (always-good scenario); nil when the latest
  window slid back below the resolved bar; cross-scenario picks the strongest
  hold; and the resolved bar sits strictly above the drill bar.
- `ToneDrillResolvedContextTests` (3 cases): the resolved lines are citeable;
  `userContext` surfaces `TONE-DRILL RESOLVED` (and not TRAJECTORY) when a gap
  closed with no active drill; an active drill suppresses the resolved read.
- `PostRepCoachNoteToneResolvedTests` (4 cases): a resolved rep headlines the
  note as held/closed (cites both percentages, no "!"); resolved takes
  priority over the recovering line; an unresolved rep falls back to the
  trajectory line; `imToneResolvedSentence` is voice-shaped and brand-clean
  across all 7 voices.

### Vision alignment

- **Pillar #5 — Personalized coaching** and **coach-parity stage #4 —
  Adaptation.** `docs/VISION.md`'s development instructions: "Surface it
  coherently in Ask Noum, post-rep feedback, and the next-practice
  recommendation." Rounds 9–11 taught the *card* to adapt to the active
  drill; round 12 carried the active-drill trajectory into Ask Noum + the
  post-rep note; this round completes the Adaptation arc — the coach now
  observes the *whole* lifecycle of a tone drill, including its end, on the
  surfaces the user talks to.
- **Anti-goals respected.** No new disconnected AI surface — the resolved
  read is a deterministic helper over the user's own reps; the AI path only
  *polishes* a fact the deterministic path already owns. No fabricated data:
  nil below 4 evaluated reps and below the resolved bar everywhere. No hollow
  praise — a scenario that was always good never reads as "resolved", and the
  copy acknowledges the win once and points forward rather than celebrating.

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+`toneDrillResolvedThreshold`,
  +per-scenario and cross-scenario `toneDrillResolved`)
- **Modified:** `Noum/PracticeSupport.swift` (+`IMToneDrillResolved` model;
  +resolved computation in `recordPostRepCoachNote`)
- **Modified:** `Noum/CoachContextBuilder.swift` (+`toneDrillResolvedLines`
  helper, +`TONE-DRILL RESOLVED` precedence branch in `userContext`,
  +system-prompt rule #9)
- **Modified:** `Noum/PostRepCoachNoteService.swift` (+additive
  `imToneDrillResolved` input field, +branch 0d, +`imToneResolvedSentence`,
  +AI `MOMENTUM` resolved line with the recovering line gated off)
- **Modified:** `NoumTests/NoumTests.swift` (+15 tests across 3 structs)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`claude/gracious-volta-0j0Pq`, based on `Redesign` and opened as a draft PR
**into** `Redesign` (this build host pushes to the agent branch and PRs into
the redesign line rather than committing to `Redesign` directly).

The artifact a user can now hold:

**The coach finishes the story instead of going quiet.** Keep missing your
calm tone in Difficult Conversation and the coach prescribes a drill and
tracks whether it's recovering. Close it — climb past 60% and hold — and the
recommendation card correctly moves on, but now the coach doesn't go silent:
the post-rep note headlines "your calm tone in Difficult Conversation is
holding now — that gap is closed, pick the next one", and if you open Ask
Noum it acknowledges the win once and points you forward instead of repeating
the old miss.

## Future moves

(Updated priority list — round-12 item #3 closed this round; remaining items
carried forward and re-prioritised, plus one new follow-up:)

1. **Preserve the just-finished IM scenario/tone on "Practice Again".**
   `SummaryView.onPracticeAgain` re-runs an IM rep with
   `.imPractice(scenario: nil, tone: nil)`, dropping the user back on the
   scenario grid even though `imConversationDetails.setup` carries the exact
   scenario + tone. Small, high-confidence, uses the existing prefill
   plumbing — a natural logic-light next round.
2. **Acknowledge the resolved gap on the next-practice card too.** This round
   gives the two conversational surfaces a resolved line; the recommendation
   card still just silently pivots to the goal-based bias when a drill
   closes. A one-line "you've locked in your calm tone in Difficult
   Conversation — here's the next edge" subordinate note on the card (when
   `toneDrillResolved(from:)` fires and there's no active drill) would make
   all three surfaces tell the same end-of-drill story. Pure-copy + blueprint
   plumbing; the card body wants a glance on a real device before it ships.
3. **Make the `LookingAheadCard` itself launch the drill.** Today the summary
   card *describes* the prescribed IM drill but isn't tappable. Threading
   `scenario`/`tone` + an `onStart` closure through `SummaryView`'s init and
   rendering a subordinate CTA would complete the loop on the most-seen
   post-rep surface. Deferred: new interactive recommendation UI wants
   real-device QA this build host lacks.
4. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
5. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor pass with
   proper visual QA (and a real device).
6. **Rate-limiter live refresh.** Make `AIRateLimiter` an `ObservableObject`
   so the Settings AI-usage card AND the `CoachReadCard` daily-budget hint
   refresh mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this
round was compiled or run — not the app, not the test suite. The changes were
written to match the existing, tested patterns line-for-line: `IMToneDrillResolved`
mirrors `IMToneDrillSignal`; `toneDrillResolved` reuses the already-tested
`toneMatchStats` / `toneDrillProgress` / `dominantEvaluatedTone` primitives so
its windowing and evidence bar are inherited, not re-implemented; the
`imToneDrillResolved` input field is additive (defaulted `false`, custom init
unchanged for callers); branch 0d mirrors the existing momentum branches; and
`imToneResolvedSentence` follows the per-voice shape of every other sentence
builder in the file. Before this lands in a TestFlight build it still wants a
real `xcodebuild test` and a glance at (a) Ask Noum for a test account whose
tone-match in one scenario climbed past 60% with no remaining sub-40%
scenario — to confirm the chat coach acknowledges the win and pivots — and
(b) the post-rep `CoachReadCard` after an IM rep in that resolved scenario —
to confirm it headlines the lock-in rather than the recovering climb. Treat
the behaviour as designed-for, not observed.
