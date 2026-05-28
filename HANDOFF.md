# HANDOFF — M24 deferred slate (round 15): preserve the just-finished IM scenario/tone on Practice Again

## Scope

Round 14 (the prior HANDOFF) headlined the tone-drill WIN on the post-rep
coach note, closing round-13 "Future move" #1 (Ask Noum already named a
solved tone gap; the surface the user sees every rep — `CoachReadCard` —
now names it too, exactly on the crossing rep). Round 14 named the next
move and flagged it #2 in its "Future moves":

> **Preserve the just-finished IM scenario/tone on "Practice Again".**
> `SummaryView.onPracticeAgain` re-runs an IM rep with
> `.imPractice(scenario: nil, tone: nil)`, dropping the user back on the
> scenario grid even though `imConversationDetails.setup` carries the exact
> scenario + tone. Small, high-confidence, uses the existing prefill
> plumbing.

This push closes it.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- The Summary screen's "Practice Again" CTA worked clean for Timed,
  Sudden Death, and Ah-Counter — those modes have no per-rep setup, so
  relaunching their own surface is the whole story. For IM Mode, the
  finished rep carries a `setup` (`scenario`, `targetTone`) that fully
  defines what the user just ran. Hard-coding `imPractice(scenario: nil,
  tone: nil)` on Practice Again threw that away and made the user reselect
  the same Difficult Conversation + Calm pair they just spent five minutes
  inside. The IMPracticeView already consumes `preferredScenario` /
  `preferredTone` (the same plumbing Quick Start and the path-node CTAs
  use) — this round threads the finished rep's setup through to it.

## What shipped

### Track 1 — the pure router (`PracticeSupport.swift`)

`Noum/PracticeSupport.swift`:

- New `SummaryPracticeAgainRouter.destination(for:imSetup:)` placed
  directly below the `AppDestination` enum it returns. Carved out of
  `SummaryView`'s path-based init so the destination choice is
  independent of SwiftUI/`NavigationPath`/`SummaryDataStore` and can be
  locked under `swift test` without any UI scaffolding.
- IM-mode reps now route to `.imPractice(scenario:tone:)` populated from
  the setup the finalizer already stored on `IMConversationDetails.setup`.
  When the setup is unavailable (e.g. the data-store entry got evicted),
  the router falls back to `(nil, nil)` — the picker stays as the safe
  default rather than crashing.
- The other three modes ignore any IM setup passed alongside them and
  route to their plain practice destinations. The tests pin this so the
  cross-pollination can't happen.

### Track 2 — the wiring (`SummaryView.swift`)

`Noum/SummaryView.swift`:

- Path-based init captures `entry?.imConversationDetails?.setup` once,
  before the closure, into a local `practiceAgainIMSetup`. The
  `onPracticeAgain` closure now calls
  `SummaryPracticeAgainRouter.destination(for: payloadMode, imSetup:
  practiceAgainIMSetup)` instead of the inline switch. The pop sequence
  and the 0.05s async hop (separates the store mutation from the nav
  push, same pattern Ask-Noum uses) are unchanged.

### Track 3 — locked the contract (`NoumTests/NoumTests.swift`)

- New `SummaryPracticeAgainRouterTests` (+5): IM rep re-arms scenario +
  tone (`difficultConversation` + `.calm` round-trips through the router);
  IM rep without setup falls back to `.imPractice(nil, nil)` so the picker
  remains the safe default; Timed routes to `.timedPractice` regardless of
  whether an IM setup is passed in; Sudden Death routes to
  `.suddenDeathPractice` regardless of whether an IM setup is passed in;
  Ah-Counter routes to `.ahCounterPractice` regardless of whether an IM
  setup is passed in. The last three pin that an IM-shaped setup leaking
  into a non-IM payload (defensive worst case) cannot mis-route the user.

### Vision alignment

- **Pillar #4 — Frictionless reps.** The whole "Practice Again" CTA
  exists so the user can keep reps moving without thinking about the
  picker. For IM the picker reappearing every rep undercut the entire
  loop: a user who picked Difficult Conversation + Calm and wanted three
  reps had to pick the pair three times. This round restores parity with
  the other modes — Practice Again means "same shape, again" — without
  taking away the user's ability to switch (the IM view still surfaces
  its scenario/tone steps; the prefill just spares the re-selection).
- **Pillar #5 — Personalized coaching.** Round 14 named the win on the
  crossing rep. The natural next move *after* the user sees that win is
  another rep in the same scenario to feel the new state hold. The
  Practice Again button was sending them to the picker instead. This
  round closes that loop too — the win names itself, then the same CTA
  drops them straight back into the same scenario + tone for the
  confirming rep.
- **Anti-goals respected.** No new AI surface — this is pure
  navigation-helper plumbing over data the finalizer already wrote. No
  new persistent state — the setup is read off the existing
  `IMConversationDetails.setup` field. No coupling between modes — the
  router fans out by mode, and the non-IM branches don't even look at
  the IM setup parameter.

## Files touched

- **Modified:** `Noum/PracticeSupport.swift` (+`SummaryPracticeAgainRouter`
  next to `AppDestination`)
- **Modified:** `Noum/SummaryView.swift` (path-based init captures
  `practiceAgainIMSetup` and the `onPracticeAgain` closure now routes
  through `SummaryPracticeAgainRouter`)
- **Modified:** `NoumTests/NoumTests.swift` (+5 tests in
  `SummaryPracticeAgainRouterTests`)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief, continuing the
round loop on the redesign lineage. A draft PR tracks the redesign work
into `main`.

The artifact a user can now hold:

**Practice Again means "same rep, again", on every mode.** Run a
Difficult Conversation in Calm; the rep wraps; the Summary lands; tap
Practice Again and you're back inside Difficult Conversation in Calm — no
detour through the scenario grid, no detour through the tone grid. The
shortcut works whether the just-finished rep delivered a win, a wobble,
or the moment the coach finally names a tone gap solved.

## Future moves

(Updated priority list — round-14 item #2 closed this round; remaining
items carried forward and re-prioritised:)

1. **Make the `LookingAheadCard` itself launch the drill.** Today the
   summary card *describes* the prescribed IM drill but isn't tappable.
   Threading `scenario`/`tone` + an `onStart` closure through
   `SummaryView`'s init and rendering a subordinate CTA would complete the
   loop on the most-seen post-rep surface. Deferred: new interactive
   recommendation UI wants real-device QA this build host lacks.
2. **Surface the SOLVED win on the summary card itself, not only the coach
   note.** Round 14 names the win in the `CoachReadCard` prose; the
   `LookingAheadCard`/`HeroScoreCard` still move silently to the next focus.
   A small "you just solved X" ribbon on the crossing rep's summary —
   reading the same `imToneDrillResolved` the note already computes — would
   make the moment unmissable. Deferred: new summary UI wants device QA.
3. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
4. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor pass
   with proper visual QA (and a real device).
5. **Rate-limiter live refresh.** Make `AIRateLimiter` an `ObservableObject`
   so the Settings AI-usage card AND the `CoachReadCard` daily-budget hint
   refresh mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this
round was compiled or run — not the app, not the test suite. The change is
deliberately small and matches the existing, tested patterns line-for-line:
`SummaryPracticeAgainRouter.destination(for:imSetup:)` is a pure switch
over `PracticeMode` that returns the same `AppDestination` cases the
inline switch did before, plus the IM-setup forwarding the router was
written to add; the captured `practiceAgainIMSetup` is a `let` derived from
the same `entry?.imConversationDetails` that the init already pulls one
line earlier into `self.imConversationDetails`; the closure body is
otherwise byte-identical (same pop sequence, same 0.05s async hop, same
`append` target). The new tests exercise the router as a pure value
function — no SwiftUI, no `NavigationPath`, no `SummaryDataStore` — so
they'll run cleanly under `swift test` when a build host is available.
