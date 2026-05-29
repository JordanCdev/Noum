# HANDOFF — M24 deferred slate (round 19): wire `SummaryLookingAheadRouter` into `LookingAheadCard`

## Scope

Round 18 (the prior HANDOFF) closed "Future move" #3 — collapsed
`HomeCoachCard.destination(for: mode)` into a zero-arg
`destination()` so the helper signature stops claiming the caller can
route a different `PracticeMode` than the blueprint says. Round 18's
own "Future moves" #1 was carried forward from rounds 16 and 17:

> **Wire `SummaryLookingAheadRouter` into `LookingAheadCard`.**
> Unchanged from round 16/17. Thread an `onStart` closure through
> `SummaryView`'s init and `expandableDetailsSection`, render a
> subordinate CTA on `LookingAheadCard`, and call
> `SummaryLookingAheadRouter.destination(for: summaryRecommendation,
> imAvailable: IMModeAvailability.isAvailable)` from it.

This push closes #1 — the artifact a user can hold once compiled is
*A "Looking ahead" card that launches the recommended rep, sharing
the same destination switch as the home coach card and the mode-picker
tile.* Closure-pass + subordinate CTA + path-init wiring + 6 tests
locking the opt-in contract. The visual treatment stays deliberately
restrained (a quiet text-link capsule, mode-tinted, in the existing
voice of the card) because the comment from rounds 16–18 was that
the *visual treatment* wants device QA, not the closure-pass itself;
this round ships the closure-pass + the smallest possible CTA that
still signals "tap to start" without competing with the in-the-moment
drill CTA above the disclosure.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- The post-rep `LookingAheadCard` already names the recommended next
  mode (e.g. "For your next session, try Sudden Death.") and explains
  why, but the user has no way to act on it from the card itself —
  they have to back out of the summary, find the mode picker, and
  start it manually. That's a frictional gap a £130/hr coach would
  never leave: "do X next" without a door labelled X on the same page.
- The router and its 13 tests have been in place since rounds 16–17;
  every branch (IM with scenario+tone, IM nil-pair fallback to picker,
  IM-unavailable fallback to Timed, plain Timed/SD/Ah-Counter) is
  already locked. Wiring the card to that router is a pure addition.
- The visual treatment stays small on purpose. The drill CTA above
  the disclosure is the loud action; this is the quiet follow-on for
  "and when you come back, this is where you should go." A subordinate
  capsule in the mode tint, on its own row below the descriptive copy,
  matches the existing "Toward your <voice>" chip's restraint.

## What shipped

### Track 1 — `LookingAheadCard` opt-in CTA (`SummaryCards.swift`)

`Noum/SummaryCards.swift`:

- `LookingAheadCard` grows an additive `var onStart: (() -> Void)? = nil`.
  Default-nil so every existing call site (`SummaryView.expandable-
  DetailsSection` before this round, and every test in
  `LookingAheadCardVoiceAlignmentTests`) keeps compiling and renders the
  pre-round-19 descriptive-only card. The CTA is opt-in, not opt-out.
- New testable predicate `shouldShowStartCTA: Bool` returns `onStart != nil`.
  The body reads this gate via `if let onStart` — lifting the
  predicate makes the gate locked-by-test without rendering SwiftUI.
- New testable property `startCTALabel: String` returns
  `"Start \(hint.mode.displayLabel)"` — the canonical display label
  from `DesignSystem.swift`'s `PracticeMode.displayLabel` ("Timed" /
  "Sudden Death" / "Ah-Counter" / "IM Mode"). Pinning the label
  through the canonical helper means a future rename propagates to
  the CTA automatically with no manual sync.
- New body branch: when `onStart` is non-nil, the card appends a
  `Button { onStart() } label: { ... }` row beneath the voice-alignment
  chip. Label is `arrow.forward.circle.fill` + `startCTALabel`, both
  rendered in `AppColor.tint(for: hint.mode)` with a 0.10-alpha
  mode-tinted capsule background. `buttonStyle(.plain)` so the touch
  region stays the capsule, not the full row. `padding(.top, 4)`
  separates the CTA from the chip above it. Accessibility identifier
  `summary.lookingAhead.startCTA` for future UI test coverage;
  accessibility label is `startCTALabel` (mirrors the visual text so
  VoiceOver reads "Start Sudden Death", not the icon name).
- Doc-comment rewritten to name *what* the new closure does and *why*
  the destination lives in `SummaryLookingAheadRouter` instead of the
  card. The card stays pure presentation: it takes a closure and
  calls it; the destination contract lives in the router (where it
  was already tested by `SummaryLookingAheadRouterTests`).

### Track 2 — `SummaryView` wiring (`SummaryView.swift`)

`Noum/SummaryView.swift`:

- New stored callback `var onStartLookingAhead: ((AppDestination) -> Void)?`.
  Mirrors `onPracticeAgain` in shape — the path init owns the
  navigation push (pop summary + pop prior practice, then push the
  new destination), the view owns the destination computation
  (because `summaryRecommendation` depends on view-side
  `@StateObject`s the init doesn't have in scope). Doc-comment names
  why the callback takes an `AppDestination` and not, say, the
  blueprint or the mode — it's the smallest type that survives the
  view-to-init boundary.
- In `expandableDetailsSection`, the `LookingAheadCard` call site
  threads `onStart:` through. The closure is built with
  `onStartLookingAhead.map { callback in { ... } }` so when the
  outer callback is nil the inner closure is also nil → the card
  stays the descriptive-only nudge. When the outer callback is
  wired (path-based init), the inner closure computes the destination
  inside the closure body (per-tap, so the freshest blueprint reads):
  `SummaryLookingAheadRouter.destination(for: summaryRecommendation,
  imAvailable: IMModeAvailability.isAvailable)`. The router is the
  exact same one `HomeCoachCard.destination()` and
  `ContentView.practiceAppDestination(for:)` call into (rounds 16–17),
  so all three launch surfaces produce the same destination for the
  same data shape — the IM-unavailable fallback to Timed lands once
  and propagates everywhere.
- Path-based init (extension at file foot) gains the
  `onStartLookingAhead` assignment alongside `onPracticeAgain`. The
  pop-then-push sequence is byte-for-byte the same shape as
  `onPracticeAgain` — `SummaryDataStore.shared.remove(for: payloadId)`,
  pop up to 2 entries (summary + prior practice), `.asyncAfter(0.05)`
  before the push so the path mutation settles before the
  `navigationDestination` switch re-renders. The user is launching a
  NEW rep in a (possibly) different mode, so the stale summary
  shouldn't be reachable via the back chevron — same UX contract as
  Practice Again.

### Track 3 — tests (`NoumTests/NoumTests.swift`)

6 new tests in a new `LookingAheadCardStartCTAContractTests` struct
beneath `SummaryLookingAheadRouterTests`:

- `defaultInitOmitsStartCallbackForBackCompat` — locks the additive
  default so the existing `LookingAheadCardVoiceAlignmentTests` (and
  every hint-only call site) compile unchanged. Asserts `onStart == nil`
  AND `shouldShowStartCTA == false` for the hint-only constructor.
- `wiringCallbackEnablesCTARender` — pins the predicate: wiring a
  closure flips the gate to true, so the body's `if let onStart`
  branch renders the CTA. Locked independently of SwiftUI rendering.
- `startCTALabelMatchesModeDisplayLabel` — pins the per-mode CTA
  copy through `PracticeMode.displayLabel`: a future rename of the
  canonical helper propagates to the CTA without a manual sync.
- `startCTALabelHasNoUrgencyOrFanfare` — brand-voice contract.
  Banned: exclamation marks, "let's", "now", "hurry". Locked across
  all four modes so a future copy tweak can't sneak fanfare onto one
  mode without a failing test. Matches the existing
  `LookingAheadCardVoiceAlignmentTests` brand-voice contract.
- `callbackInvokesOnTap` — locks the closure signature (`() -> Void`,
  zero arg). A future refactor that adds an argument (e.g. routing
  the destination through the closure instead of computing it inside
  the view body) is caught here.
- `ctaShowsAcrossEveryMode` — sanity check that the gate predicate
  is mode-agnostic. Round 19 doesn't ship per-mode gating (the IM-
  unavailable fallback to Timed lives in the router, not the card),
  so the CTA must light up for every mode the engine recommends.

### Vision alignment

- **Pillar #5 (Personalized coaching).** A human coach who tells you
  "your next session should be Sudden Death" doesn't then walk out
  of the room — they hand you the door. Round 19 hands the user the
  door: one tap on the post-rep card, the recommended mode launches
  with the right IM scenario + tone if the tone-drill signal fires
  (round 9), or the plain practice destination otherwise. The
  closure-pass is the smallest move that closes the gap between
  "Noum tells you what's next" and "Noum gets you into what's next."
- **Coach-parity stage #3 (Intervention).** The recommendation
  carries the focus, target, mode benefit, why-now, AND now the
  launch button. The user can act on the prescription in the same
  beat the coach delivers it, without a context switch through the
  picker.
- **Anti-drift hygiene.** The router (`SummaryLookingAheadRouter`)
  stays the *single* source of truth for the mode → destination
  mapping. As of round 19, every launch surface (home coach card,
  mode-picker tile, post-rep "Looking ahead" card) routes through
  the same router; the IM-unavailable fallback to Timed lives in
  one place and propagates to all three. The card stays pure
  presentation — it takes a closure and calls it — so a future
  router branch (e.g. a new mode, or a different fallback policy)
  lands once and the card picks it up for free.
- **Pillar #4 (Believable progress) + brand voice.** The CTA copy
  is "Start Timed", not "Begin!" or "Let's go!". The visual register
  stays a quiet mode-tinted capsule, not a hero gradient button —
  the drill CTA above the fold is the loud action; this is the
  quiet follow-on. Same voice as the "Toward your <voice>" chip
  beside it.
- **Anti-goals respected.** No new persistent state. No new AI
  surface. No new dependency between files. The destination
  contract is unchanged (round 16's router is unchanged; round 17's
  lower-level overload is unchanged); only the SwiftUI surface
  gains an opt-in subordinate CTA.

## Files touched

- **Modified:** `Noum/SummaryCards.swift`
  (`LookingAheadCard` gains `onStart`, `shouldShowStartCTA`,
  `startCTALabel`; body grows the opt-in subordinate CTA;
  doc-comment rewritten)
- **Modified:** `Noum/SummaryView.swift`
  (`onStartLookingAhead: ((AppDestination) -> Void)?` field;
  `expandableDetailsSection` threads the closure through to
  `LookingAheadCard`; path-based init wires the pop-and-push)
- **Modified:** `NoumTests/NoumTests.swift`
  (+6 tests in new `LookingAheadCardStartCTAContractTests` struct
  beneath `SummaryLookingAheadRouterTests`)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief, continuing the
round loop on the redesign lineage. A draft PR tracks the redesign work
into `main`.

## Future moves

(Updated priority list — round-18 item #1 closed this round; the rest
roll forward:)

1. **Surface the SOLVED win on the summary card itself, not only the
   coach note.** Unchanged from rounds 16–18. Round 14 names the win
   in the `CoachReadCard` prose; the `LookingAheadCard` /
   `HeroScoreCard` still move silently to the next focus. A small
   "you just solved X" ribbon on the crossing rep's summary — reading
   the same `imToneDrillResolved` the note already computes — would
   make the moment unmissable. Deferred: new summary UI wants device
   QA. Could ship the data plumbing (an `imToneDrillResolved`
   property on `SummaryView` reading the same store) in a closure-
   pass-shape round and gate the ribbon render behind a small
   visual treatment that the device QA pass refines.
2. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
3. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
4. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` so the Settings AI-usage card AND the
   `CoachReadCard` daily-budget hint refresh mid-view. Low priority.
5. **NEW — visual polish pass on the round-19 CTA.** The current
   capsule is the minimum-viable shape: mode-tinted, quiet, in
   register with the "Toward your <voice>" chip. A real-device read
   may want the capsule to grow into a full-width subordinate button,
   or stay a chip but gain a press animation. Pure visual work,
   not destination logic — the router stays the single source of
   truth either way.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes mirror existing patterns line-for-line:

- The `LookingAheadCard.onStart` default-nil opt-in is the same shape
  as `Hint.styleGoal`'s default-nil opt-in (round 14 in the M14 chain).
  Every existing call site is unchanged byte-for-byte; the additive
  body branch reuses the same `AppColor.tint(for:)` + capsule pattern
  the voice-alignment chip uses.
- `SummaryView.onStartLookingAhead` mirrors `SummaryView.onPracticeAgain`
  in field shape AND in path-init wiring (`SummaryDataStore.remove`,
  pop up to 2 entries, `.asyncAfter(0.05)`, push). The closure
  signature `(AppDestination) -> Void` mirrors the router's return
  type so the closure boundary doesn't translate types.
- The 13 tests in `SummaryLookingAheadRouterTests` (rounds 16–17)
  still exercise the router as a pure function. The 6 new tests in
  `LookingAheadCardStartCTAContractTests` exercise the card's opt-in
  predicate and CTA label without rendering SwiftUI (the testable
  `shouldShowStartCTA` + `startCTALabel` lift the gate logic out of
  the body for unit testing).
- No new types, no new dependencies between files. The single
  caller of `LookingAheadCard` is updated in the same diff.

All checks the next agent should run on a real build host:

1. `swift test --filter LookingAheadCardStartCTAContractTests` — the
   6 new tests should all pass.
2. `swift test --filter SummaryLookingAheadRouterTests` — the 13
   existing tests should still pass (no router change this round).
3. `swift test --filter LookingAheadCardVoiceAlignmentTests` — the 6
   existing voice-alignment tests should still pass (default-nil
   contract preserved).
4. Boot the app on simulator, finish a Timed rep, expand "Session
   Details" on the summary, scroll to the "Looking ahead" card at
   the bottom. Confirm:
   - The subordinate CTA renders beneath the descriptive copy when
     the recommendation differs from the just-finished mode.
   - Tapping the CTA navigates to the recommended practice surface
     (Timed → Sudden Death → Ah-Counter → IM picker per the engine).
   - The back chevron from the new practice screen does NOT land
     back on the stale summary (the pop-then-push wiring is correct).
   - With IM Mode unconfigured locally (no AI keys), a tone-drill IM
     recommendation falls back to Timed via the router (the same
     fallback the home coach card already exercises).
