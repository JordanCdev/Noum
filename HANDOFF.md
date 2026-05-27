# HANDOFF — M24 deferred slate (round 15): preserve the just-finished IM scenario/tone on "Practice Again"

## Scope

Round 14 (the prior HANDOFF) headlined the tone-drill *win* on the post-rep
`CoachReadCard`, closing round-13's "Future move" #1. Round 14 named the next
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

- A coach who just ran you through *Difficult Conversation* on a *calm* tone
  and then asks "want to go again?" does not then hand you a blank menu of
  every scenario. They keep you in the room. But that's exactly what Noum
  did: the post-rep "Practice Again" button on an IM summary re-launched IM
  with no scenario and no tone, so the user landed back on the scenario grid
  and had to re-pick the thing they'd just finished. Every other mode
  ("Practice Again" for Timed / Sudden Death / Ah-Counter) re-enters its own
  surface directly — IM was the one mode that lost the user's place. This
  round carries the just-finished scenario + tone forward so "again" means
  *again*, landing the user on the pre-filled setup, one tap from the same
  conversation.

## What shipped

### Track 1 — the primitive (`AppDestination.practiceAgain`)

`Noum/PracticeSupport.swift`:

- New pure static helper `AppDestination.practiceAgain(mode:imSetup:)` beside
  the `AppDestination` enum (Foundation-only, not behind the SwiftUI guard, so
  it's reachable from the test target). It centralises the post-summary
  "Practice Again" routing that previously lived as an inline `switch` inside
  `SummaryView`'s init closure:
  - `.timed` → `.timedPractice`, `.suddenDeath` → `.suddenDeathPractice`,
    `.ahCounter` → `.ahCounterPractice` — unchanged, and the `imSetup`
    argument is ignored for these (it can never leak into another mode's
    destination).
  - `.imConversation` → `.imPractice(scenario: imSetup?.scenario, tone:
    imSetup?.targetTone)` — the behaviour change. A non-nil setup carries the
    finished pairing forward; a nil setup falls back to
    `.imPractice(scenario: nil, tone: nil)`, the pre-redesign grid behaviour,
    so a missing entry degrades gracefully instead of crashing or
    mis-routing.

### Track 2 — the consume side was already correct (`IMPracticeView`)

`Noum/IMPracticeView.swift` (no change — verified):

- `onAppear` already prefills from `preferredScenario` / `preferredTone`:
  with **both** non-nil it sets `scenario` + `targetTone` and advances
  `setupStep = .tone`, landing the user on the pre-filled tone-confirmation
  step rather than the scenario grid. The fix only had to *supply* the pair;
  the prefill plumbing the round-14 note promised was genuinely already
  there.

### Track 3 — the wiring (`SummaryView`)

`Noum/SummaryView.swift`:

- The path-based init now captures `let imPracticeAgainSetup =
  entry?.imConversationDetails?.setup` alongside the existing
  `payloadId` / `payloadMode` / `pathBinding` locals — a local `let`, never a
  capture of `self`, matching every other closure in this init.
- `onPracticeAgain` drops its inline four-case `switch` and delegates to
  `AppDestination.practiceAgain(mode: payloadMode, imSetup:
  imPracticeAgainSetup)`. The nav-path pop + async-hop push are unchanged.

### Track 4 — locked the contract (`NoumTests/NoumTests.swift`)

- `AppDestinationPracticeAgainTests` (+5): IM round-trips its scenario + tone
  (`difficultConversation` / `calm`); a **second** pairing (`networking` /
  `warm`) round-trips too, guarding against a hardcoded social-catch-up /
  confident default; a nil setup falls back to the grid
  (`.imPractice(scenario: nil, tone: nil)`); the three non-IM modes resolve to
  their own surfaces and **ignore** a stray IM setup; and the non-IM modes
  resolve identically with no setup.

### Vision alignment

- **Pillar #5 — Personalized coaching** and **pillar #6 — Real-world
  transfer.** IM Mode is where Noum rehearses the actual conversations that
  matter — the difficult talk, the networking intro, the work update. A coach
  keeps you in the scenario you're working; losing the user's place on
  "again" is exactly the kind of generic-app friction the vision's anti-goals
  warn against ("a noisy productivity app"). This keeps the loop tight: finish
  a rep, tap again, you're back in the same room.
- **Anti-goals respected.** No new surface, no AI call, no telemetry — a pure
  routing helper over data the summary already holds. The change is behaviour
  the user can feel, not a metric to display.

## Files touched

- **Modified:** `Noum/PracticeSupport.swift` (+`AppDestination.practiceAgain(mode:imSetup:)`)
- **Modified:** `Noum/SummaryView.swift` (+`imPracticeAgainSetup` local capture; `onPracticeAgain` delegates to the helper)
- **Modified:** `NoumTests/NoumTests.swift` (+5 tests in `AppDestinationPracticeAgainTests`)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` lineage — this round's work is committed on the designated
working branch (`claude/adoring-dijkstra-Q40Et`), which was fast-forwarded
onto `origin/Redesign` first so the change sits on the redesign lineage, and
a draft PR tracks it into `Redesign` per the user's brief.

The artifact a user can now hold:

**"Again" keeps you in the room.** Finish an IM rep — Difficult Conversation,
calm tone — tap "Practice Again", and instead of being dumped back on the
grid of every scenario, you land right back on Difficult Conversation with
the calm tone pre-filled, one tap from the same conversation. Want a
different scenario? It's one back-tap away. The default is continuity, the way
a coach who just worked you on something would keep going.

## Future moves

(Updated priority list — round-14 item #2 closed this round; remaining items
carried forward and re-prioritised:)

1. **Make the `LookingAheadCard` itself launch the drill.** Today the summary
   card *describes* the prescribed IM drill but isn't tappable. Threading
   `scenario`/`tone` + an `onStart` closure through `SummaryView`'s init and
   rendering a subordinate CTA would complete the loop on the most-seen
   post-rep surface. Deferred: new interactive recommendation UI wants
   real-device QA this build host lacks. **Note for the next agent:** the
   `AppDestination.practiceAgain` helper this round added is exactly the
   routing such a CTA would call — a tappable card and "Practice Again" both
   want "launch IM on *this* scenario+tone", so reuse the helper rather than
   re-deriving the destination.
2. **Surface the SOLVED win on the summary card itself, not only the coach
   note.** Round 14 names the win in the `CoachReadCard` prose; the
   `LookingAheadCard`/`HeroScoreCard` still move silently to the next focus. A
   small "you just solved X" ribbon on the crossing rep's summary — reading
   the same `imToneDrillResolved` the note already computes — would make the
   moment unmissable. Deferred: new summary UI wants device QA.
3. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
4. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving
   with celebration timing. Worth a dedicated refactor pass with proper visual
   QA (and a real device).
5. **Rate-limiter live refresh.** Make `AIRateLimiter` an `ObservableObject`
   so the Settings AI-usage card AND the `CoachReadCard` daily-budget hint
   refresh mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this
round was compiled or run — not the app, not the test suite. The changes were
written to match the existing, tested patterns line-for-line: the
`practiceAgain` helper reproduces the exact four-case mapping the
`SummaryView` switch already ran (Timed/SuddenDeath/AhCounter unchanged, IM
now supplied with the setup's scenario/tone); the consume side
(`IMPracticeView.onAppear`) was read and confirmed to already prefill from a
both-non-nil pair; the local-`let` capture mirrors the sibling
`payloadId`/`payloadMode` captures; and the new tests reuse the
`AppDestinationSessionDetailTests` shape and the real `IMConversationScenario`
/ `IMTargetTone` cases. The behaviour change (IM "Practice Again" landing on
the pre-filled setup) wants a quick on-device sanity check before release,
but the routing contract is locked by the deterministic tests.
