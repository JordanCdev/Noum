# HANDOFF — M24 deferred slate (round 25): empty-state "Review this case" starter chip on `AskNoumView` — surfaces the case-review opener when the user opens Ask Noum directly (not through the post-rep summary)

## Scope

Round 24 closed the post-rep gap on the case-review cadence —
`InterventionReviewPromptCard` now renders on `SummaryView` the
moment the active `CoachIntervention.isReviewDue(at:)` predicate
returns true, with a CTA that drops the case-anchored
`interventionReviewOpener` into the Ask Noum thread via the
existing `AskNoumStore.injectUserTurn` bridge.

The honest gap that left open: a user who opens Ask Noum directly
from the tab bar (not via the post-rep summary) never sees the
review prompt at all. The case file knows the cadence elapsed —
the summary card honours it — but the chat surface stays silent.
That breaks the coach-parity promise at the moment of highest
intent: the user navigated to the coach themselves.

Round 25 picks up step #1 from the round-24 "Future moves" list:

> 1. **Empty-state "Review this case" starter chip on `AskNoumView`.**
>    Carry forward from the 2026-05-29 HANDOFF (step #2). The round-
>    24 opener already routes correctly through the AskNoum bridge;
>    the chip would let a user who opens Ask Noum directly (not
>    from summary) start the same case-review conversation.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- The round-24 opener helper (`CoachContextBuilder.interventionReviewOpener`)
  already carries the full case scaffolding (mode + focus +
  followed-rep depth) and a voice-shaped review ask. Round 25
  reuses it verbatim from a second surface; the dispatched chat
  thread is identical whether the user arrived from the summary
  card or from the empty-state chip.
- The contract is narrow on purpose: one new pure helper on
  `CoachContextBuilder` (a compact display-label generator), one
  new `@ViewBuilder` on `AskNoumView`'s empty state (conditionally
  rendered on the SAME `isReviewDue(at:)` predicate the summary
  uses), and three new tests pinning the helper's three copy
  branches. No new state owner, no new persisted field, no
  cross-store coupling.
- The redesign-branch invariant: this is a `Redesign`-branch push
  per the user brief. The work lands directly on `Redesign` so the
  round-by-round loop on the redesign lineage is preserved.

## What shipped

### Track 1 — `CoachContextBuilder.interventionReviewStarterHeadline(for:)` pure helper (`CoachContextBuilder.swift`)

`Noum/CoachContextBuilder.swift:818` — appended right after
`interventionReviewOpener`:

- Returns the compact display label for the AskNoumView chip:
  `"Review the active case — <focus, lower-cased>"`.
- Mirrors `InterventionReviewPromptCard.headlineCopy(for:)`'s
  focus-or-title fallback chain (focus → title → empty-string
  guard), so the user reads continuous voice across the two
  surfaces. The chip and the post-rep card name the same noun
  phrase whichever surface surfaces first.
- Brand-voice rules carried in: no exclamation, no "Let's", no
  urgency framing, lower-cased focus mid-sentence after the
  em-dash.
- The DISPLAY label only. The actual opener dispatched on tap is
  the full `interventionReviewOpener(intervention:voice:)` —
  same string the summary card sends — so the AI reply lands
  with the case scaffolding already in scope. The chip and the
  card produce the identical chat thread.

### Track 2 — `caseReviewStarterChip` on `AskNoumView` empty state (`AskNoumView.swift`)

`Noum/AskNoumView.swift`:

- One new `@ViewBuilder` `caseReviewStarterChip` added below
  `emptyStateHeadline` (line ~318). Reads
  `coachMemoryStore.currentMemory?.activeIntervention?
  .isReviewDue(at: Date())` to decide whether to render — same
  predicate the summary uses, so the eligibility math has one
  home on `PrimaryFocusMemory.swift:253` and both surfaces stay
  in lockstep across cadence-engine changes.
- One conditional insert in `emptyState` (line ~259): the chip
  renders between `emptyStateBody` and the `Text("Starters")`
  eyebrow, so the priority signal lands above the regular
  starter prompts but below the empty-state intro framing.
- Distinct visual register vs the regular starter chips:
  `calendar.badge.clock` icon (same glyph the summary card
  uses), brand-purple eyebrow (`"REVIEW DUE"`), brand-purple
  tinted background + heavier stroke, trailing `arrow.right`
  glyph. The user reads it as the coach's priority check-in
  rather than as just another suggested prompt.
- On tap: builds the full opener via
  `CoachContextBuilder.interventionReviewOpener(intervention:voice:)`
  using the user's `SpeakingStyleGoal` (already in scope on the
  view via the existing `voice` computed property), then
  dispatches via the existing `send(_:)` path — same code path
  every other empty-state chip uses. No new bridge or store
  plumbing.

### Track 3 — `caseReviewStarterHeadline*` tests (3 tests, `NoumTests/NoumTests.swift`)

Appended to `InterventionReviewPromptTests`. All three call the
pure helper on a fixture-built `CoachIntervention` and assert the
exact rendered string. No `CoachMemoryStore` or `AskNoumStore` is
stood up — the helper has no side-effects.

The dispatched opener is already covered by the round-24 opener
tests (`openerLeadNamesModeFocusAndDepth`, the seven voice-mapping
tests, etc.), so only the new chip display label needs new
coverage.

- `caseReviewStarterHeadlineNamesFocus` — happy path; focus is
  present and lower-cased mid-sentence after the em-dash.
- `caseReviewStarterHeadlineFallsBackToTitleWhenFocusIsNil` —
  defensive; matches the card's nil-focus fallback so the chip
  never reads "Review the active case — ."
- `caseReviewStarterHeadlineFallsBackToTitleWhenFocusIsEmpty` —
  symmetric empty-string edge; case-engine refactors that write
  `""` instead of `nil` shouldn't produce an empty noun phrase.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  "compare response across multiple attempts and either
  reinforce, vary, or replace the intervention with an
  explained rationale." Round 24 closed the post-rep gap; round
  25 closes the second gap on the case-review cadence — a user
  who self-navigates to the coach surface now also sees the
  review prompt at the agreed cadence. The chat surface no
  longer falls silent at the moment the user expressed the
  highest intent (opening the coach themselves).
- **Pillar #5 (Personalized coaching).** A real coach revisits
  the prescribed plan whenever the user shows up to talk —
  whether they came in through the post-rep door or the front
  door. The chip closes the front-door path so the coaching
  contract holds regardless of how the user arrived.
- **Pillar #4 (Believable progress).** The chip is a credibility
  receipt at a new surface: the case file is honoured wherever
  the user happens to land. That consistency earns the right to
  keep prescribing.
- **Anti-goal alignment (no "hearts-and-lives gating").** The
  chip never blocks the regular starter prompts; if the user
  ignores it and taps a different starter the chip stays in
  place for the next opening. The only action is a deep-link
  into the same case-review conversation the summary surfaces.

### Branch + redesign-alignment notes

- All three edits land on `Redesign`, the redesign-lineage
  branch the rolling M24 deferred-slate work has been shipping
  on since round 11. The user brief explicitly calls this out:
  "ensure working on the redesign branch too (very important)."
  Round 25 preserves the round-by-round loop on the redesign
  lineage.
- Round 25 explicitly does NOT change the dispatched opener
  string. The summary card and the empty-state chip both call
  the same `interventionReviewOpener(intervention:voice:)`, so
  the AI reply lands the same chat thread either way. Voice
  drift between surfaces (the most common quality-regression
  vector when adding a second entry point) is structurally
  prevented.

## Future moves

(Updated priority list — round-25 closed the round-24 step #1;
the rest roll forward.)

1. **Record user confirmation / rejection of the working
   hypothesis.** Carry forward from the 2026-05-29 HANDOFF
   (step #3). The post-review reply from the coach should be
   followed by a single-tap acknowledgement that updates
   `CoachMemory.workingHypothesis` confidence. Requires a
   PrimaryFocusMemory addition + a small Ask Noum response chip
   surface — bigger lift than round 24/25, but the natural
   follow-on now that BOTH entry surfaces honour the review
   cadence.
2. **Peer Sudden Death scores via `FriendsManager`.** Still
   blocked on `PublicProfileSnapshot` schema work.
3. **`coachNoteRevealed` cleanup.** Still risky — animation
   chain interleaving with celebration timing. Worth a
   dedicated refactor pass with proper visual QA (and a real
   device).
4. **Visual polish pass on the round-19 launch CTA.** Carried
   forward from rounds 19–24. Pure visual work, not destination
   logic — the router stays the single source of truth either way.
5. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–24. Pure visual work, not crossing logic.
6. **Extend the crossing helper to the chat-coach context line.**
   Carried forward from round 21 as a note for the record (not
   an action item).
7. **Day-rollover refresh for long-mounted observers.** Carried
   forward from round 22. The `AIRateLimiter` publication only
   fires on writes. A user who pins Settings open across midnight
   would still see yesterday's counters until the next consume
   bumps the token. A future round could subscribe to
   `Notification.Name.NSCalendarDayChanged` and bump the token
   from there.
8. **Tier-change observation symmetry to other surfaces that read
   `AIRateLimiter.currentCap()` directly.** Carried forward from
   round 23 as a note for the record.
9. **Refresh-on-rotate for the empty-state chip when the
   `CoachMemoryStore` mutates while AskNoumView is mounted.**
   New note from round 25. The chip is computed in the view body
   so it WILL recompute on `coachMemoryStore.objectWillChange`
   emissions (the store is an `@StateObject` on the view). The
   open question is whether a freshly-elapsed cadence (the user
   opens Ask Noum at 11:59 with the cadence due at 12:00) needs
   a periodic re-evaluation. Not an action item — most cadence
   stamps land hours-to-days from "now" — but worth recording.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so
nothing in this round was compiled or run — not the app, not the
test suite. The changes are:

- A pure static func on `CoachContextBuilder` next to the
  existing `interventionReviewOpener` — three lines of focus-
  fallback logic, identical pattern to the round-24
  `InterventionReviewPromptCard.headlineCopy(for:)` helper. No
  new types, no new dependencies.
- A new `@ViewBuilder` on `AskNoumView` that reads design
  tokens already in scope on the same view (`AppColor.pro`,
  `Typography.captionSmall`, `Typography.body`,
  `CornerRadius.medium`, `Spacing.md`, `Spacing.sm`,
  `Spacing.xs`) and calls existing methods (`send(_:)`,
  `CoachContextBuilder.interventionReviewOpener`,
  `CoachContextBuilder.interventionReviewStarterHeadline`,
  `coachMemoryStore.currentMemory?.activeIntervention?
  .isReviewDue(at:)`). The store is already a `@StateObject` on
  the view so the chip recomputes when the case file mutates.
- One conditional insert in `emptyState` that uses the same
  pattern as nearby views (a bare property reference inside the
  outer `VStack`).
- Three new tests on one pure function. They mirror the round-
  24 `headlineCopy` test shape (same `@MainActor struct`, same
  `@Test` annotations, same `makeIntervention(...)` fixture).
- The `Noum.xcodeproj` uses Xcode 16
  `fileSystemSynchronizedGroups` for the `Noum/` folder, so no
  pbxproj edit is required to pick up the helper / chip — both
  land in files already tracked by the synchronized group.

All checks the next agent should run on a real build host:

1. `swift test --filter InterventionReviewPromptTests` — the 23
   round-24 tests plus the 3 new round-25 tests should all pass
   (26 total in the struct).
2. `swift test --filter CoachReadCardDailyBudgetHintTests` — the
   round-23 tests should still pass.
3. `swift test --filter AIRateLimiterPublicationTests` — the
   round-22 tests should still pass.
4. `swift test --filter IMToneDrillCrossingTests` — the round-21
   helper tests should still pass.
5. `swift test --filter HeroScoreCardToneDrillRibbonContractTests`
   — the round-20 ribbon-contract tests should still pass.
6. `swift test --filter LookingAheadCardStartCTAContractTests` —
   the round-19 launch-CTA tests should still pass.
7. Boot the app on simulator, seed a `CoachMemory.activeIntervention`
   where `followedRepCount == minimumFollowedRepsForReview` and
   `reviewDueAt` is a date in the past (the case-file engine
   stamps these naturally after a few followed reps on a
   recommendation), then open Ask Noum directly from the tab
   bar with an empty thread (no messages yet). Confirm:
   - `caseReviewStarterChip` renders between the empty-state
     intro paragraph and the "STARTERS" eyebrow.
   - Eyebrow reads "REVIEW DUE" in brand-purple, body names the
     active focus lower-cased after the em-dash.
   - Tap the chip → Ask Noum dispatches the full
     `interventionReviewOpener` (Time to review the active case
     ... voice-shaped ask), the model reply lands, and the
     thread continues as a normal chat from there.
   - The chip dispatches the SAME string as tapping "Review
     with coach" from the post-rep summary — pop the thread,
     finish a rep that triggers the summary card, tap the
     summary card's CTA, and confirm the seeded user turn text
     is identical to the chip's dispatched text.
   - When `followedRepCount` is one short OR `reviewDueAt` is
     in the future, the chip does NOT render and the starter
     prompts appear in their normal position.
   - With `voice == .authoritative` set in coaching profile,
     the dispatched opener ends with "Is this still the right
     intervention, or do we adapt?"; with `.warm`, "Is this
     still feeling like the right work?"; etc. (same voice
     mapping as the round-24 summary card — they share the
     opener helper).
