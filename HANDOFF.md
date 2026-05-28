# HANDOFF — M24 deferred slate (round 15): preserve the just-finished IM scenario + tone on "Practice Again"

## Scope

Round 14 (the prior HANDOFF) taught the post-rep `CoachReadCard` to headline
a tone-drill WIN on the crossing rep, then named the next moves and flagged
this one #2 in its "Future moves":

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

- The IM tone-drill loop now prescribes a scenario + tone, adapts its read
  while the drill is in flight, and names the win the moment it lands
  (rounds 9–14). But the single most-used "do it again" affordance — the
  **Practice Again** button on the summary — threw all of that away: it
  re-launched IM with no scenario and no tone, so a user who just drilled
  *calm tone in Difficult Conversation* and tapped "again" landed on the
  scenario grid and had to re-pick. A human coach who set that drill says
  "go again" — they don't make you re-choose the exercise. This round makes
  "Practice Again" re-enter the **same** drill.

## What shipped

### Track 1 — the pure mapping (`PracticeSupport`)

`Noum/PracticeSupport.swift`:

- New static helper `AppDestination.practiceAgain(mode:imSetup:)` — a total,
  side-effect-free mapping from a finished session's `PracticeMode` (plus the
  optional IM setup) to the destination "Practice Again" should push. Timed /
  Sudden Death / Ah-Counter map to their default entries and ignore the
  setup; `.imConversation` maps to
  `.imPractice(scenario: imSetup?.scenario, tone: imSetup?.targetTone)`. A
  `nil` setup falls through to `nil/nil`, which is the existing grid
  behaviour — so the mapping degrades gracefully and is never lossy.
- Extracted from the inline `switch` previously buried in the `onPracticeAgain`
  closure precisely so the behaviour is unit-testable without driving a
  `NavigationPath` through SwiftUI.

### Track 2 — the wiring (`SummaryView`)

`Noum/SummaryView.swift`:

- The path-based `init(payload:navigationPath:)` now captures
  `entry?.imConversationDetails?.setup` (the scenario + tone of the rep just
  summarised) into a local, then `onPracticeAgain` builds its destination via
  `AppDestination.practiceAgain(mode: payloadMode, imSetup: imPracticeAgainSetup)`.
- No change to the non-IM paths or to the path-popping that precedes the push.

### Existing plumbing this rides on (no change needed)

- `ContentView` already routes `.imPractice(let scenario, let tone)` into
  `IMPracticeView(preferredScenario: scenario, preferredTone: tone)`.
- `IMPracticeView.onAppear` already reads both preferred values: with scenario
  **and** tone set it advances `setupStep` to `.tone` (the ready step), so the
  preserved drill is one tap from starting — the same prefill the picker
  quick-start (round 10) and the IM scenario detail view already use.

### Track 3 — locked the contract (`NoumTests/NoumTests.swift`)

- `PracticeAgainDestinationTests` (+5):
  1. IM rep preserves scenario + tone (`.difficultConversation` + `.calm`).
  2. The mapping round-trips an arbitrary pair (`.networking` + `.warm`) — not
     hardcoded to one drill.
  3. IM with a `nil` setup falls back to `.imPractice(nil, nil)` (grid).
  4. Non-IM modes map to their default entries.
  5. Non-IM modes ignore a stale IM setup (a Timed "again" never smuggles an
     IM scenario into its destination).

### Vision alignment

- **Pillar #5 — Personalized coaching** and **coach-parity stage #3 —
  Intervention.** The prescribe → observe → adapt loop only holds if the
  prescribed drill is *easy to repeat*. Round 14 named the win; this round
  removes the friction between "I want to run that drill again" and actually
  running it. The coach keeps you in the exercise it set.
- **Anti-goals respected.** No new surface, no new AI call, no fabricated
  state. It reuses data the session already carries (`imConversationDetails`)
  and routing that already exists. The only new code is a pure mapping and its
  tests.

## Files touched

- **Modified:** `Noum/PracticeSupport.swift` (+`AppDestination.practiceAgain(mode:imSetup:)`)
- **Modified:** `Noum/SummaryView.swift` (capture IM setup in path-init; route
  `onPracticeAgain` through the new mapping)
- **Modified:** `NoumTests/NoumTests.swift` (+5 tests, `PracticeAgainDestinationTests`)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

Developed on `claude/eager-einstein-ZKMGM`, branched off the `Redesign`
lineage per the user's brief; a draft PR tracks this work **into `Redesign`**
so it lands on the redesign branch the user named.

The artifact a user can now hold:

**"Practice Again" puts you back in the same drill.** Finish a calm-tone rep
in Difficult Conversation, tap "Practice Again", and you're one tap from the
exact same scenario + tone — no re-picking from the grid. Drill a different
pairing and that one comes back instead. The coach keeps you in the exercise
it set.

## Future moves

(Round-14 item #2 closed this round; remaining items carried forward and
re-prioritised:)

1. **Make the `LookingAheadCard` itself launch the drill.** The summary card
   *describes* the prescribed IM drill but isn't tappable. Threading
   `scenario`/`tone` + an `onStart` closure through `SummaryView`'s init and
   rendering a subordinate CTA would complete the loop on the most-seen
   post-rep surface. Deferred: new interactive recommendation UI wants
   real-device QA this build host lacks.
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
5. **Rate-limiter live refresh.** Make `AIRateLimiter` an `ObservableObject` so
   the Settings AI-usage card AND the `CoachReadCard` daily-budget hint refresh
   mid-view. Low priority.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain** (`swift`, `swiftc`,
and `xcodebuild` are all absent), so nothing in this round was compiled or
run — not the app, not the test suite. The changes were written to match the
existing, tested patterns line-for-line: `AppDestination.practiceAgain` is the
exact `switch` that already lived inline in `onPracticeAgain` (now extracted,
with the IM case extended to read the setup); the `SummaryView` capture mirrors
the other locals the path-init already lifts out of `entry`/`payload` for its
closures; and `PracticeAgainDestinationTests` uses plain `IMConversationSetup`
fixtures and `#expect(... == .imPractice(...))` against the `Hashable`
`AppDestination`. The prefill side it depends on (`IMPracticeView.onAppear`
reading `preferredScenario`/`preferredTone`) is unchanged and already shipped.
