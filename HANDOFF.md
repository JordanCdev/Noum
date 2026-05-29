# HANDOFF — M24 deferred slate (round 20): SOLVED ribbon on the hero score card

## Scope

Round 19 (the prior HANDOFF) closed "Future move" #1 — wired
`SummaryLookingAheadRouter` into `LookingAheadCard` with an opt-in
subordinate launch CTA. Round 19's own "Future moves" list rolled the
top item forward unchanged from rounds 16–18:

> **Surface the SOLVED win on the summary card itself, not only the
> coach note.** Round 14 names the win in the `CoachReadCard` prose;
> the `LookingAheadCard` / `HeroScoreCard` still move silently to the
> next focus. A small "you just solved X" ribbon on the crossing rep's
> summary — reading the same `imToneDrillResolved` the note already
> computes — would make the moment unmissable. Deferred: new summary
> UI wants device QA. Could ship the data plumbing (an
> `imToneDrillResolved` property on `SummaryView` reading the same
> store) in a closure-pass-shape round and gate the ribbon render
> behind a small visual treatment that the device QA pass refines.

This push closes that item — the artifact a user can hold once
compiled is *a quiet mode-tinted SOLVED capsule on the hero score card
of the rep that just pushed an IM scenario's tone hit rate over the
bar.* Pure-presentation card surface + crossing-detection wiring +
6 tests locking the opt-in contract. The visual treatment stays
deliberately restrained (a 0.10-alpha IM-tinted capsule between the
score ring and the headline, with a `checkmark.seal.fill` glyph
+ "Solved · Calm tone in Difficult Conversation" label) because the
comment from rounds 16–19 was that the *visual treatment* wants device
QA, not the closure-pass itself; this round ships the smallest possible
ribbon that signals "you just closed the gap the coach has been
working on with you" without competing with the score ring.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- Rounds 14+ taught the post-rep `CoachReadCard` (prose) to *headline*
  the SOLVED win on the crossing rep — the rep that pushes a scenario
  from "below the 40% drill bar" to "holding above the 60% hold bar."
  That landed the win in the coach's *voice*, which is necessary but
  not sufficient: a user who skims the score ring and stops there
  never sees the SOLVED moment named. The crossing rep deserves a
  visual tag, not just a prose mention.
- The crossing-detection primitive (`IMHistorySummary.toneDrillResolved`)
  + its 12 tests in `IMToneDrillResolvedTests` have been in place since
  round 13; surfacing it on the hero is a pure addition. The same
  with-vs-without-this-rep comparison the finalizer already does
  (`PracticeSessionFinalizer.recordPostRepCoachNote` lines ~6629–6639)
  is repeated in `SummaryView.heroToneDrillResolvedRibbon`, so the
  ribbon and the note's SOLVED sentence light up on the *same* rep and
  never double-celebrate. A scenario solved before this rep stays
  quiet; a genuine relapse-then-reclear correctly reads as a new
  crossing — same shape as the note logic.
- The visual treatment stays small on purpose. The score ring is the
  loud signal ("here's your score"); the headline is the next loudest
  ("Strong delivery"); the SOLVED ribbon is the third register down
  ("and you also just closed something with me"), sitting in the same
  capsule shape as the existing "Best this week" chip on the per-mode
  breakdown cards and the "Toward your <voice>" chip on the
  LookingAheadCard. Same restraint contract.

## What shipped

### Track 1 — `HeroScoreCard` SOLVED ribbon (`SummaryCards.swift`)

`Noum/SummaryCards.swift`:

- `HeroScoreCard` grows an additive
  `var toneDrillResolvedRibbon: ToneDrillResolvedRibbon? = nil`.
  Default-nil so every existing call site keeps compiling and renders
  the pre-round-20 descriptive-only hero. The ribbon is opt-in, not
  opt-out: a future call site that doesn't compute the resolved read
  can omit the argument and never accidentally celebrate.
- New nested value type `ToneDrillResolvedRibbon: Equatable` carries
  `scenarioTitle: String` + `toneTitle: String`. Two display strings
  so the renderer doesn't depend on the iOS-17-gated
  `IMHistorySummary` / `IMToneDrillResolved` types — the owning view
  does the lookup, the card stays pure presentation. `Equatable` so
  SwiftUI's diff-aware re-renders treat a stable scenario+tone pair as
  equal and the capsule doesn't flicker on parent re-renders.
- New testable predicate `shouldShowToneDrillResolvedRibbon: Bool`
  returns `toneDrillResolvedRibbon != nil`. The body reads this gate
  via `if let label = toneDrillResolvedRibbonLabel` — lifting the
  predicate makes the gate locked-by-test without rendering SwiftUI.
- New testable property `toneDrillResolvedRibbonLabel: String?` returns
  `"Solved · \(toneTitle) tone in \(scenarioTitle)"` (e.g. "Solved ·
  Calm tone in Difficult Conversation") or nil when no ribbon is wired.
  Mirrors the post-rep coach-note's `Your <tone> tone in <scenario> is
  solved` phrasing but compressed to a chip label: names the outcome as
  observed hit rate, never claims a drill *caused* the win, never
  re-prescribes.
- New body branch: when the label is non-nil, the card renders a
  `HStack` row between the score ring and the headline with
  `checkmark.seal.fill` glyph + the label, both in `AppColor.modeIM`
  tint, with a 0.10-alpha IM-tinted capsule background. Visual register
  stays deliberately restrained — in line with the existing "Toward
  your <voice>" chip on `LookingAheadCard` and the "Best this week"
  chip on the per-mode breakdown cards. Accessibility identifier
  `summary.hero.toneDrillSolvedRibbon` for future UI test coverage;
  accessibility label mirrors the visual text so VoiceOver reads
  "Solved · Calm tone in Difficult Conversation" (no double-read of
  the icon name).
- Doc-comments name *what* the ribbon does and *why* the crossing
  logic lives in `SummaryView`, not the card. The card stays pure
  presentation: it takes a string pair and renders a capsule; the
  crossing contract (which scenario, which rep crossed) lives next
  to the same store + scenario derivation the post-rep coach-note
  finalizer uses.

### Track 2 — `SummaryView` crossing-detection wiring (`SummaryView.swift`)

`Noum/SummaryView.swift`:

- New computed property `heroToneDrillResolvedRibbon:
  HeroScoreCard.ToneDrillResolvedRibbon?` performs the crossing
  detection and returns the display-string bundle. Mirrors
  `PracticeSessionFinalizer.recordPostRepCoachNote`'s crossing logic
  byte-for-byte:
  - `IMModeAvailability.isAvailable` guard (mirrors `imToneDrillSignal`'s
    guard so the post-rep ribbon and the next-practice tone-drill
    prescription share the same availability gate).
  - `imConversationDetails != nil` — only IM reps can resolve an IM
    tone drill; every other mode returns nil.
  - `if #available(iOS 17.0, *)` guard around the
    `IMHistorySummary.toneDrillResolved(from:scenario:)` call (the
    helper is iOS-17 gated; the property defaults nil on older
    targets — same shape as `imToneDrillSignal`).
  - `sessions = sessionStore.sessions`,
    `priorSessions = Array(sessions.dropFirst())` — the latest rep is
    the just-finalized one (`PracticeSessionStore` prepends). Resolved
    now reads from all sessions (including this rep); resolved before
    strips the latest. Both calls scope to the just-finished rep's
    `scenario` (from `imConversationDetails.setup.scenario`).
  - `resolvedNow != nil && resolvedBefore == nil` — this rep is the
    crossing rep. A scenario already solved before this rep stays
    quiet (no repeat); a genuine relapse-then-reclear correctly reads
    as a new crossing.
- The closure threading through `HeroScoreCard(..., toneDrillResolvedRibbon:
  heroToneDrillResolvedRibbon)` adds one argument to the existing call
  in `expandableDetailsSection`'s sibling block (the non-Sudden-Death
  hero branch, line ~614). All other arguments unchanged.
- Doc-comment names the contract: nil when the just-finished rep isn't
  IM, when no scenario crosses on this rep, or when IM Mode is
  unavailable. The ribbon stays quiet rather than inventing a victory —
  same honesty contract as every other vision-aligned coach surface.

### Track 3 — tests (`NoumTests/NoumTests.swift`)

6 new tests in a new `HeroScoreCardToneDrillRibbonContractTests` struct
beneath `LookingAheadCardStartCTAContractTests`:

- `defaultInitOmitsRibbonForBackCompat` — locks the additive default so
  the existing `HeroScoreCard` call site (and every future call site
  that doesn't compute the resolved read) compiles unchanged. Asserts
  `shouldShowToneDrillResolvedRibbon == false` AND
  `toneDrillResolvedRibbonLabel == nil` for the hint-only constructor.
- `wiringRibbonEnablesRender` — pins the predicate: wiring a non-nil
  ribbon flips the gate to true so the body's `if let label` branch
  renders the capsule. Locked independently of SwiftUI rendering.
- `ribbonLabelShapeNamesToneAndScenario` — pins the per-scenario /
  per-tone label shape across all 4 scenarios × 6 tones the IM engine
  produces (24 combinations). Asserts the label contains the scenario
  title AND the tone title AND leads with "Solved" — so a future
  copy tweak that drops either name or the outcome lede surfaces here.
- `ribbonLabelHasNoUrgencyOrFanfare` — brand-voice contract. Banned:
  exclamation marks, "let's", "now", "hurry", "amazing", "nailed",
  "crushed". Locked across 4 representative (scenario, tone) pairs so
  a future copy tweak can't sneak fanfare onto one pair without a
  failing test. Mirrors `LookingAheadCardStartCTAContractTests.
  startCTALabelHasNoUrgencyOrFanfare` shape so the two restraint
  contracts stay aligned.
- `ribbonStaysHiddenWhenNotWired` — sanity: explicitly passing nil
  keeps the ribbon hidden and the label nil. Locked separately from
  the default-omits case so a refactor that flips the default from
  nil to a sentinel (or vice-versa) still has to keep the explicit-nil
  contract honest.
- `ribbonValueTypeEquatability` — pins the `ToneDrillResolvedRibbon`
  bundle's Equatable contract: same scenario+tone compares equal,
  different scenario compares unequal, different tone compares unequal.
  SwiftUI's diff-aware re-renders depend on stable equality so the
  capsule doesn't flicker on parent re-renders.

### Vision alignment

- **Pillar #5 (Personalized coaching).** Round 14 named the SOLVED
  win in the coach's *voice* (the prose note). Round 20 surfaces the
  same moment as a *visual* tag on the hero score card — the user who
  skims the score ring and stops there now sees the SOLVED moment
  named, not buried in the prose. A £130/hr human coach who pushed
  you on your calm tone for two weeks doesn't just mumble "nice work"
  when it finally holds; they name it visibly so it lands.
- **Coach-parity stage #4 (Adaptation).** "Compare response across
  multiple attempts and either reinforce, vary, or replace the
  intervention with an explained rationale." The SOLVED ribbon is the
  end-state read: the coach reinforced through rounds 11–13 (Adaptation
  trajectory), and round 14 + round 20 close the loop by naming the
  turnaround once it lands. The user sees the arc: "drill prescribed →
  drill recovering → drill solved."
- **Anti-drift hygiene.** The crossing logic in
  `SummaryView.heroToneDrillResolvedRibbon` mirrors the finalizer's
  crossing detection byte-for-byte (same `sessions` / `dropFirst()`
  shape, same scenario derivation from `imConversationDetails.setup`,
  same `resolvedNow != nil && resolvedBefore == nil` predicate). The
  ribbon and the post-rep coach-note SOLVED sentence light up on the
  *same* rep and never double-celebrate. A future change to the
  crossing rule lands in two places — the finalizer (note) and the
  summary view (ribbon) — which is acceptable round 20 friction; a
  follow-up could lift the crossing helper into a shared static
  function on `IMHistorySummary` so both call into one place. Tracked
  as a future move below.
- **Pillar #4 (Believable progress) + brand voice.** The ribbon copy
  is "Solved · Calm tone in Difficult Conversation", not "AMAZING!" or
  "You crushed it!". The visual register stays a quiet mode-tinted
  capsule, not a hero overlay — the score ring above the fold is the
  loud signal; this is the quiet tag beside it. Same voice as the
  "Best this week" chip on the per-mode breakdown cards and the
  "Toward your <voice>" chip on the `LookingAheadCard`.
- **Anti-goals respected.** No new persistent state. No new AI
  surface. No new dependency between files (HeroScoreCard takes a
  string pair, not an `IMHistorySummary` type — so the card stays
  non-iOS-17-gated). The crossing contract is unchanged from round
  14 (`IMHistorySummary.toneDrillResolved` is unchanged); only the
  SwiftUI surface gains an opt-in ribbon.

## Files touched

- **Modified:** `Noum/SummaryCards.swift`
  (`HeroScoreCard` gains `toneDrillResolvedRibbon` field +
  nested `ToneDrillResolvedRibbon: Equatable` value type +
  `shouldShowToneDrillResolvedRibbon` predicate +
  `toneDrillResolvedRibbonLabel` property; body grows the
  opt-in capsule branch between score ring and headline)
- **Modified:** `Noum/SummaryView.swift`
  (+`heroToneDrillResolvedRibbon` computed property doing the
  crossing detection; `HeroScoreCard` call site threads the
  ribbon through)
- **Modified:** `NoumTests/NoumTests.swift`
  (+6 tests in new `HeroScoreCardToneDrillRibbonContractTests` struct
  beneath `LookingAheadCardStartCTAContractTests`)
- **Modified:** `HANDOFF.md` (this file)
- **Modified:** `docs/CURRENT_STATE.md` (rolling summary)

## Branch

`Redesign` — committed and pushed per the user's brief, continuing the
round loop on the redesign lineage. The draft PR tracking the redesign
work into `main` picks up this round's changes automatically.

## Future moves

(Updated priority list — round-19 "Future move" #1 closed this round;
the rest roll forward:)

1. **Lift the crossing-detection helper into `IMHistorySummary`.** The
   "resolved now AND not resolved before" predicate now lives in two
   places — `PracticeSessionFinalizer.recordPostRepCoachNote` (note)
   and `SummaryView.heroToneDrillResolvedRibbon` (ribbon). Both must
   agree forever. A small static helper
   `IMHistorySummary.toneDrillCrossing(in:scenario:)` returning the
   crossed `IMToneDrillResolved?` would collapse both surfaces through
   one tested point — exactly the same hygiene move round 17 made for
   the `SummaryLookingAheadRouter`. Pure refactor, no UI surface, no
   device QA required. Could ship next round.
2. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
3. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
4. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` so the Settings AI-usage card AND the
   `CoachReadCard` daily-budget hint refresh mid-view. Low priority.
5. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from round 19. Pure visual work, not destination logic — the router
   stays the single source of truth either way.
6. **NEW — visual polish pass on the round-20 SOLVED ribbon.** The
   current capsule is the minimum-viable shape: IM-tinted, quiet, in
   register with the existing "Toward your <voice>" chip. A real-device
   read may want the capsule to grow into a full-width strip across
   the score ring, or stay a chip but gain a one-shot pulse animation
   on first render. Pure visual work, not crossing logic — the
   detection stays in `SummaryView` either way.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes mirror existing patterns line-for-line:

- The `HeroScoreCard.toneDrillResolvedRibbon` default-nil opt-in is the
  same shape as `LookingAheadCard.onStart`'s default-nil opt-in (round
  19) and `Hint.styleGoal`'s default-nil opt-in (round 14 in the M14
  chain). Every existing call site is unchanged byte-for-byte; the
  additive body branch reuses the same `AppColor.modeIM` capsule
  pattern the `IMHistoryBreakdownCard` row chip uses.
- `SummaryView.heroToneDrillResolvedRibbon` mirrors
  `PracticeSessionFinalizer.recordPostRepCoachNote`'s crossing logic
  byte-for-byte: same `sessions` / `dropFirst()` shape, same scenario
  derivation from `imConversationDetails.setup`, same
  `resolvedNow != nil && resolvedBefore == nil` predicate. The
  `IMModeAvailability` + `#available(iOS 17.0, *)` guards mirror
  `imToneDrillSignal`'s guards line-for-line.
- The 6 new tests in `HeroScoreCardToneDrillRibbonContractTests`
  exercise the card's opt-in predicate, label shape, brand-voice
  contract, and value-type equality without rendering SwiftUI. They
  do not re-verify the crossing-detection itself — that's already
  locked by `IMToneDrillResolvedTests` (12 tests, round 13) and by
  `PostRepCoachNoteToneResolvedTests` (5 tests, round 14).
- No new types outside the card, no new dependencies between files.
  The single caller of `HeroScoreCard` is updated in the same diff.

All checks the next agent should run on a real build host:

1. `swift test --filter HeroScoreCardToneDrillRibbonContractTests` —
   the 6 new tests should all pass.
2. `swift test --filter IMToneDrillResolvedTests` — the 12 existing
   crossing-primitive tests should still pass (no helper change this
   round).
3. `swift test --filter PostRepCoachNoteToneResolvedTests` — the 5
   existing post-rep note crossing-contract tests should still pass
   (the note path is unchanged).
4. `swift test --filter LookingAheadCardStartCTAContractTests` — the 6
   round-19 launch-CTA tests should still pass (no card change this
   round outside `HeroScoreCard`).
5. Boot the app on simulator, run 6+ IM reps in the same scenario
   (e.g. Difficult Conversation with `Calm` tone), the first 3 missing
   the tone, the latest 3 landing it. Confirm:
   - The SOLVED ribbon renders on the crossing rep's summary, just
     above the headline, in IM purple-blue.
   - The ribbon does NOT render on the next rep after the crossing
     (or any subsequent rep) — the "resolved before == nil" gate
     keeps it from repeating.
   - The post-rep coach note on the same crossing rep also headlines
     the SOLVED sentence (round 14 logic, unchanged) — both surfaces
     light up on the same rep, neither alone.
   - The ribbon does NOT render on non-IM reps (Timed / Sudden Death /
     Ah-Counter), regardless of IM history.
   - VoiceOver reads "Solved · Calm tone in Difficult Conversation"
     (single combined label, no icon double-read).
