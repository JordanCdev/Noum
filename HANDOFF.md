# HANDOFF — M24 deferred slate (round 14): headline the tone-drill WIN in the post-rep coach note

## Scope

Round 13 (the prior HANDOFF) added the *resolved* read —
`IMHistorySummary.toneDrillResolved(from:)` — the complement to the
in-flight tone-drill signal, and threaded it into Ask Noum so the chat
coach acknowledges a solved tone gap instead of going silent the moment a
drill is won. Round 13 named the next move and flagged it #1 in its
"Future moves":

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

- The chat coach now names a solved tone gap (round 13), but the surface
  the user sees *every single rep* — the post-rep `CoachReadCard` — still
  only ever says "recovering" / "slipping" while a drill is in flight, and
  goes quiet the moment the gap closes. A real coach who pushed you on your
  calm tone in Difficult Conversation for two weeks notices the rep where
  it *finally holds* and names that win to your face before moving you on.
  This round gives the post-rep note that read — fired on the crossing rep,
  once, never nagged again.

## What shipped

### Track 1 — the primitive (`IMHistorySummary`)

`Noum/IMHistorySummary.swift`:

- New **per-scenario** overload `toneDrillResolved(from:scenario:)` carved
  out of the existing cross-scenario scan, which now simply maps over it.
  Same evidence bar (earliest window below the drill bar, latest window
  holding ≥ `toneDrillResolvedHoldRate`, overall ≥ the drill bar so the
  active-drill signal has already self-cleared). Pure refactor — the
  cross-scenario API and its locked behavior are unchanged.
- This overload is the exact tool the finalizer needs to detect a
  **crossing rep**: ask "is this scenario resolved counting this rep?" vs.
  "was it resolved a rep ago?" and the answer isolates the single rep that
  closed the gap.

### Track 2 — the type plumbing (`PostRepCoachNoteService`)

`Noum/PostRepCoachNoteService.swift`:

- New `PostRepCoachNoteInput` SOLVED trio — `imToneDrillResolved`
  (`IMToneDrillResolved?`) plus `imToneDrillResolvedScenarioTitle` /
  `imToneDrillResolvedToneTitle` (display strings, so the service stays
  decoupled from the IM enums, mirroring the in-flight trajectory trio).
  All default `nil`; set only on the crossing rep.
- New **branch 0** at the very top of `metricSentence` — above branch 0a
  (personal best). A closed prescribed-drill loop is the rarest, most
  coaching-significant momentum signal, so the win outranks every other
  note; the upstream once-only gating means it never crowds the other
  branches on later reps.
- New voice-shaped `imToneResolvedSentence` (all 7 personas) — the terminal
  complement to `imToneTrajectorySentence`. Names the outcome ("solved",
  "turned around") as an observation of the user's *own hit rate*, cites
  the climb (e.g. "0% to 100%, holding now"), and points to the next
  target. Never claims a drill *caused* the recovery; never re-prescribes
  the beaten scenario — the same honesty bar as round 13's chat-coach rule.
- AI path: a `SOLVED this rep` momentum line in `userPrompt` carrying the
  same name-once / point-forward / no-causation guidance, so the AI polish
  layer reads the win the same way the deterministic path does.

### Track 3 — the gating (`PracticeSessionFinalizer`)

`Noum/PracticeSupport.swift`:

- `recordPostRepCoachNote` now computes the crossing for IM reps:
  `allSessions` already includes the just-finalized rep, so it compares
  `toneDrillResolved(from: allSessions, scenario:)` against
  `toneDrillResolved(from: priorSessions, scenario:)` (prior = all minus
  this rep). **Resolved now AND not a rep ago** ⇒ this rep is the crossing
  rep ⇒ populate the SOLVED trio. Otherwise the trio stays `nil` (no
  headline). A scenario already solved before this rep stays quiet; a
  genuine relapse-then-reclear reads as a new crossing, which is correct.

### Track 4 — locked the contracts (`NoumTests/NoumTests.swift`)

- `IMToneDrillResolvedTests` (+4): the per-scenario overload returns the
  same win the cross-scenario scan does for a single resolved scenario;
  it's scoped (a resolved Difficult Conversation never surfaces under a
  Networking query); the **crossing fires on the rep, not before** (5 reps
  whose latest window holds only 50% → nil; the 6th match → non-nil); and
  it **does not repeat after crossing** (both the 6-rep and 7-rep states
  read resolved, so the finalizer's "resolved now AND not a rep ago" check
  yields no second headline).
- `PostRepCoachNoteToneResolvedTests` (+5): the win headlines the note
  (scenario + tone + "0%"/"100%" + "solved", no exclamation); it **outranks
  a personal best** on the same rep; it falls through honestly when nothing
  crossed (a personal best headlines instead, no scenario name); and the
  sentence is voice-shaped, clean, forward-pointing, within the note's
  character budget, and passes the brand-voice contract across all 7 voices.

### Vision alignment

- **Pillar #5 — Personalized coaching** and **coach-parity stage #4 —
  Adaptation.** Round 13 let the *chat* coach close the loop on a win;
  this round closes it on the surface the user actually sees after every
  rep. A coach who only ever says "keep working on it" and never "you've
  got this one — next" is nagging, not adapting. The post-rep note now
  names the terminal state of the loop the moment it's earned.
- **Anti-goals respected.** No new disconnected AI surface — the read is a
  deterministic helper over the user's own reps. No hollow celebration: the
  win fires only on a genuine sub-bar → held turnaround, exactly once, on
  the crossing rep. No causation claim: the copy and the AI guidance both
  forbid it. No fabricated data: nil below the evidence bar.

## Files touched

- **Modified:** `Noum/IMHistorySummary.swift` (+per-scenario
  `toneDrillResolved(from:scenario:)`; cross-scenario version delegates)
- **Modified:** `Noum/PostRepCoachNoteService.swift` (+SOLVED input trio,
  +branch 0 in `metricSentence`, +`imToneResolvedSentence`, +AI momentum
  line)
- **Modified:** `Noum/PracticeSupport.swift` (+crossing detection in
  `recordPostRepCoachNote`, +SOLVED args on the `PostRepCoachNoteInput`)
- **Modified:** `NoumTests/NoumTests.swift` (+9 tests across 2 structs)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief, continuing the
round loop on the redesign lineage. A draft PR tracks the redesign work
into `main`.

The artifact a user can now hold:

**The coach says the win to your face, on the rep you earn it.** Grind your
calm tone in Difficult Conversation from missing it every time up to landing
it consistently, and on the very rep that finally pushes you over the line
the post-rep card stops saying "recovering" and says it plainly: "Your calm
tone in Difficult Conversation is solved — 0% to 100%, holding now. Target
met; next one's open." Do another rep in the same scenario and it doesn't
nag — the win was named once, the coach has moved you on.

## Future moves

(Updated priority list — round-13 item #1 closed this round; remaining
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
3. **Surface the SOLVED win on the summary card itself, not only the coach
   note.** This round names the win in the `CoachReadCard` prose; the
   `LookingAheadCard`/`HeroScoreCard` still move silently to the next focus.
   A small "you just solved X" ribbon on the crossing rep's summary —
   reading the same `imToneDrillResolved` the note already computes — would
   make the moment unmissable. Deferred: new summary UI wants device QA.
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
per-scenario `toneDrillResolved` overload is the exact body the
cross-scenario scan already ran (now extracted, with the scan delegating to
it); `imToneResolvedSentence` mirrors `imToneTrajectorySentence`'s shape and
voice switch; the SOLVED input trio mirrors the in-flight trajectory trio;
and the finalizer crossing block sits beside the existing `imToneProgress`
computation it parallels. The new tests reuse the `IMToneDrillResolvedTests`
fixtures and the `PostRepCoachNoteToneTrajectoryTests` `makeInput` shape.
