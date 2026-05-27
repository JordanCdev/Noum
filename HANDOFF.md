# HANDOFF — M24 deferred slate (round 14): the post-rep note headlines the WIN, not only Ask Noum

## Scope

Round 13 (the prior HANDOFF) added the `resolved` complement to the
tone-drill reads and threaded it into **Ask Noum** — the chat coach now
acknowledges a solved tone drill instead of going silent the moment a
scenario climbs above the drill bar. Round 13 named the next move and
flagged it #1 in its "Future moves":

> **The post-rep note should headline the win too.** This round threads the
> resolved read into Ask Noum; the post-rep `CoachReadCard` still only
> speaks to a drill *in flight* (round-12 branch 0d, recovering/slipping).
> The cleanest add: a momentum branch that, when the just-finished rep is
> the one that pushed a scenario across the bar, headlines "you've solved
> your calm tone in Difficult Conversation" once. Gating is the subtlety —
> it must fire on the crossing rep, not repeat every rep thereafter. Likely
> wants a small "was-resolved-as-of-the-previous-rep" comparison in the
> finalizer. Pure-helper + deterministic-copy work, no device QA.

This push closes it.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- Ask Noum (round 13) can now say "your calm tone in Difficult Conversation
  is solved." But the **post-rep coach note** — the `CoachReadCard` that is
  the single most-seen post-rep surface, rendered on the first frame of
  every Summary screen — was still only reading the *in-flight* trajectory
  (recovering/slipping). So the rep that *actually crosses the line* — the
  one the user most wants acknowledged — produced a generic metric note, and
  the win lived only in a chat surface the user might never open. A real
  coach names the win in the moment it lands. This round gives the post-rep
  note that read, and gates it so the headline fires **once**, on the
  crossing rep, and never repeats.

## What shipped

### Track 1 — the per-scenario resolved read (`IMHistorySummary`)

`Noum/IMHistorySummary.swift`:

- Extracted a new per-scenario overload
  `toneDrillResolved(from:scenario:matchRateThreshold:holdRate:) ->
  IMToneDrillResolved?` out of the existing all-scenarios
  `toneDrillResolved(from:)`. The all-scenarios version now maps over the
  per-scenario one and keeps its freshest-win sort — so the public API and
  every existing test are **unchanged**, but the finalizer can now ask a
  single targeted question: "is *this* scenario resolved given *this*
  history?" That's the building block the crossing-rep detection needs.

### Track 2 — the crossing-rep detection (`PracticeSupport` finalizer)

`Noum/PracticeSupport.swift` (`PracticeSessionFinalizer.recordPostRepCoachNote`):

- After the existing in-flight `toneDrillProgress` computation for an IM
  rep's scenario, the finalizer now runs the **was-resolved-as-of-the-
  previous-rep** comparison round 13 prescribed:
  - `resolvedNow = toneDrillResolved(from: allSessions, scenario:)` —
    `allSessions` already contains the just-appended rep.
  - `resolvedBefore = toneDrillResolved(from: allSessions minus this rep,
    scenario:)`.
  - **Crossing rep == `resolvedNow != nil && resolvedBefore == nil`.** Only
    then are the resolved fields populated on the note input; on every
    other rep (already-solved, never-solved, still-drilling) they stay nil,
    so the headline can't repeat.
- The per-scenario filter (not the all-scenarios read) is what makes the
  gating exact: if scenario S was *already* solved last rep but a *different*
  scenario T was the freshest win, the all-scenarios read would have
  returned T and a naive comparison would re-fire S's headline. Asking per
  scenario removes that false positive.

### Track 3 — the win headline (`PostRepCoachNoteService`)

`Noum/PostRepCoachNoteService.swift`:

- Four new `PostRepCoachNoteInput` fields —
  `imToneDrillResolvedScenarioTitle` / `ToneTitle` / `EarlierRate` /
  `RecentRate` — carried as plain strings + doubles, the same IM-enum
  decoupling the in-flight trajectory trio already uses. All default to
  nil, so every existing call site (incl. `regenerationInput` and the test
  builders) compiles unchanged.
- New **top-priority** `metricSentence` branch (`0·win`), above personal
  best / consecutive-clean / filler-trend / in-flight-trajectory. A solved
  drill is the terminal state of an intervention the coach has been
  pushing, so it headlines. It explicitly outranks the in-flight
  trajectory (0d) because on the crossing rep the same scenario *also*
  reads `.recovering` — "solved" must win over "still climbing."
- New voice-shaped `imToneResolvedSentence(scenario:tone:earlierRate:
  recentRate:persona:)` across all seven voices. Each names the win once
  and cites the held climb ("0% to 100% and holding") as evidence. No
  re-prescription, no causation claim — the honesty bar matches round 13's
  Ask Noum rule #9. Forward motion is left to the note's suffix + the
  next-practice card (which rightly move to the next-weakest scenario);
  this sentence closes the loop on the one just beaten.
- The AI polish path gets a parallel `SOLVED this rep` momentum line in
  `userPrompt`, with the same "name once / don't re-prescribe / don't claim
  causation" guidance, so the AI-backed note headlines the win too rather
  than rewording it away.

### Track 4 — locked the contracts (`NoumTests/NoumTests.swift`)

- `IMToneDrillResolvedTests` (+3): the per-scenario read agrees with the
  all-scenarios freshest win and returns nil for an unseen scenario; the
  crossing-rep transition (resolved-now but **not** resolved-before, on a
  4-rep → 5-rep history where the latest 2-rep window flips from 50% to
  100% and the overall rate reaches the 40% bar); and the post-win case
  (a sixth landed rep keeps it resolved, so the finalizer would see
  resolved-before != nil and correctly **not** re-fire).
- New `PostRepCoachNoteToneResolvedTests` (+5): the headline cites
  scenario + tone + the "0% to 100%" climb; the win **outranks** an
  in-flight `.recovering` trajectory present on the same input; the branch
  falls through cleanly when nothing resolved; partial resolved fields (a
  title without the climb rates) do **not** fire the headline (defensive
  all-four-required guard); and the sentence is clean + cites the climb
  across all seven voices.

### Vision alignment

- **Pillar #5 — Personalized coaching** and **coach-parity stage #4 —
  Adaptation.** `docs/VISION.md` stage 4 is "reinforce, vary, or replace
  the intervention with an explained rationale." Round 13 gave the *chat*
  coach the terminal "solved" state; a coach who only closes the loop in a
  surface the user might never open is still effectively nagging in the
  surface they always see. This round moves the win to the post-rep note —
  the first thing rendered after every rep — so the loop visibly closes
  where the work happened.
- **Anti-goals respected.** No new disconnected AI surface — the read is a
  deterministic helper over the user's own reps, reusing round 13's tested
  `toneDrillResolved` building block. No fabricated data: the crossing
  gate requires a genuine, finalizer-confirmed turnaround. No hollow
  celebration: the headline only fires on the exact crossing rep and never
  repeats; a scenario the user was always good at, or a scrape-over-the-bar
  recovery, never reads as a win (inherited from round 13's evidence bar).
  No causation claim: both the deterministic sentence and the AI guidance
  forbid it.

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+per-scenario
  `toneDrillResolved(from:scenario:)` overload; all-scenarios version now
  maps over it)
- **Modified:** `Noum/PracticeSupport.swift` (crossing-rep detection in
  `recordPostRepCoachNote`; four new fields threaded into the note input)
- **Modified:** `Noum/PostRepCoachNoteService.swift` (+4 input fields,
  +`0·win` metric branch, +`imToneResolvedSentence`, +AI `SOLVED` prompt
  line)
- **Modified:** `NoumTests/NoumTests.swift` (+8 tests across 2 structs)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — work targets the Redesign line per the user's brief.

The artifact a user can now hold:

**The coach names the win the moment you land it — on the screen you always
see.** Grind your calm tone in Difficult Conversation from missing it every
time up to landing it consistently, and the rep that finally crosses the
line opens its Summary with the coach saying it out loud: "your calm tone in
Difficult Conversation is solved — 0% to 100% and holding." It says it once,
on that rep; the next rep's note has already moved on, and the next-practice
card points you at the next-weakest scenario. Round 13 put that
acknowledgement in the chat coach; this round puts it where you can't miss
it.

## Future moves

(Updated priority list — round-13 item #1 closed this round; remaining items
carried forward and re-prioritised:)

1. **Make the `LookingAheadCard` itself launch the drill.** Today the
   summary card *describes* the prescribed IM drill but isn't tappable.
   Threading `scenario`/`tone` + an `onStart` closure through `SummaryView`'s
   init and rendering a subordinate CTA would complete the loop on the
   most-seen post-rep surface. Deferred: new interactive recommendation UI
   wants real-device QA this build host lacks.
2. **Preserve the just-finished IM scenario/tone on "Practice Again".**
   `SummaryView.onPracticeAgain` re-runs an IM rep with
   `.imPractice(scenario: nil, tone: nil)`, dropping the user back on the
   scenario grid even though `imConversationDetails.setup` carries the exact
   scenario + tone. Small, high-confidence, uses the existing prefill
   plumbing.
3. **Headline the win on the Home coach card too.** `HomeCoachCard`
   currently reads only the in-flight `toneDrillSignal` (the still-failing
   drill, see `HomeCoachCard.swift:747`); it never surfaces the *resolved*
   win. Threading `toneDrillResolved` in with the same "name once, move on"
   framing — and gating so Home and the post-rep note don't double-announce
   the same win the same day — would close the loop on the home surface too.
   Pure-helper + copy work, no device QA.
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
were written to match the existing, tested patterns line-for-line: the
per-scenario `toneDrillResolved` overload is a verbatim extraction of the
already-tested all-scenarios body (no logic change, only a parameterisation);
the four new input fields mirror the in-flight trajectory trio's shape and
defaults; `imToneResolvedSentence` mirrors `imToneTrajectorySentence`
exactly (same per-voice switch, same percentage formatting); the finalizer's
with/without-this-rep comparison reuses the same `allSessions` /
`$0.id != session.id` filtering the surrounding momentum + recents code
already uses; and the new tests reuse the `imSession(...)` builders and
window math the existing `IMToneDrillResolvedTests` rely on (the crossing
test's 4→5 rep math was worked through by hand against the 0.4 drill bar /
0.6 hold bar to land on a clean unresolved→resolved transition).
