# HANDOFF — M24 deferred slate (round 25): empty-state "Review this case" starter chip on `AskNoumView` — surfaces the same review prompt the SummaryView card surfaces when the user reaches Ask Noum directly (not via the post-rep bridge)

## Scope

Round 24 closed the post-rep summary side of the case-file review-
cadence gap: when `CoachIntervention.isReviewDue(at:)` holds, the
`InterventionReviewPromptCard` surfaces on Summary and tapping
"Review with coach" hands a case-anchored opener to Ask Noum via
the existing `onAskNoumAboutRep` bridge.

Round 25 picks up the highest-impact next-step listed in the
round-24 HANDOFF (`Future moves` #1):

> 1. **Empty-state "Review this case" starter chip on `AskNoumView`.**
>    Carry forward from the 2026-05-29 HANDOFF (step #2). The round-
>    24 opener already routes correctly through the AskNoum bridge;
>    the chip would let a user who opens Ask Noum directly (not
>    from summary) start the same case-review conversation.

That gap matters: round 24 only honours the review cadence at the
moment a rep finalizes. A user who finishes their training day,
closes the app, then re-opens it the next morning and taps Ask
Noum from the home surface never sees the prompt — even though
the case file is now even more overdue. The coach silently re-
prescribes past the agreed review date for everyone who doesn't
re-enter through Summary.

That breaks the same contract round 24 closed, on a different
entry path:

> **Coach-parity stage #4 (Adaptation).** Compare response across
> multiple attempts and either reinforce, vary, or replace the
> intervention with an explained rationale.

Round 25 closes the second half of that gap with the minimum
amount of plumbing:

- One new pure copy helper on `InterventionReviewPromptCard`
  (`emptyStateChipLabel(for:)`).
- One new `activeReviewDueIntervention` computed on `AskNoumView`,
  mirroring the round-24 helper on `SummaryView` exactly so both
  surfaces share the same gating contract.
- One new `reviewDueChip(intervention:)` `@ViewBuilder` on
  `AskNoumView` rendered above the generic "Starters" list when
  the predicate holds.
- 5 new tests pinning the chip-copy contract.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- The honest gap from round 24 — review-cadence honour only on the
  Summary entry path — was the round-24 HANDOFF's #1 future-move.
  Round 25 closes the second half with a contained edit: one new
  pure copy helper, one new computed (same pattern as the
  SummaryView mirror), one new chip view, 5 tests pinning the
  copy branches.
- The contract is narrow on purpose: the chip uses the same
  predicate (`CoachIntervention.isReviewDue(at:)`) as the summary
  card, so the two surfaces never disagree about whether a review
  is due. The chip tap fires the same `interventionReviewOpener`
  the summary card fires, so the AI reply gets the same case
  scaffolding regardless of entry path.
- The redesign-branch invariant: this is a `Redesign`-branch
  push per the user brief. The work lands directly on
  `Redesign` so the round-by-round loop on the redesign lineage
  is preserved.

## What shipped

### Track 1 — `InterventionReviewPromptCard.emptyStateChipLabel(for:)` pure helper (`InterventionReviewPromptCard.swift`)

`Noum/InterventionReviewPromptCard.swift` — appended after the
existing `bodyCopy(for:)` pure helper:

- `static func emptyStateChipLabel(for intervention: CoachIntervention) -> String`
  — returns `"Review my work on \(focus.lowercased())"` where
  `focus` falls back to `title` on nil/empty (same fallback
  contract as `headlineCopy(for:)`). No trailing period — chip
  strings read better without one.
- Lives next to `headlineCopy(for:)` and `bodyCopy(for:)` so all
  three copy surfaces have one home and one set of fallback
  rules. Pure function, locked by tests on the same struct.
- Does NOT name followed-rep count or cadence stamps — the chip
  is a one-glance CTA, not a paragraph. The followed-rep depth
  lives in the opener (which carries the evidence scaffolding to
  the model). Pinned by `chipLabelDoesNotDependOnFollowedRepCount`.

### Track 2 — `AskNoumView.activeReviewDueIntervention` computed (`AskNoumView.swift`)

`Noum/AskNoumView.swift` — added after `emptyStateBody`:

- Mirrors `SummaryView.activeReviewDueIntervention` byte-for-
  byte. Same `coachMemoryStore.currentMemory` read, same
  `intervention.isReviewDue(at: Date())` gate, same nil
  fall-through. One source of truth for the gate — the pure
  predicate — locked by `InterventionReviewPromptTests` (round 24)
  in `NoumTests.swift`.
- The mirror is deliberate: if the predicate gate ever evolves
  (e.g. an additional confidence floor on top of the followed-
  rep + cadence gates), both readers get the new behaviour the
  same body turn. Pinning the same helper shape on both views
  also makes future consolidation (e.g. lifting the helper into
  `CoachMemoryStore`) a one-step move.

### Track 3 — `AskNoumView.reviewDueChip(intervention:)` view (`AskNoumView.swift`)

`Noum/AskNoumView.swift` — new private `@ViewBuilder` below
`activeReviewDueIntervention`:

- Rendered conditionally in `emptyState` ABOVE the existing
  "Starters" eyebrow (round 19 onward), so the review prompt
  reads as the coach's priority CTA rather than one suggestion
  among several. Generic starter chips remain below.
- Visual register matches the `InterventionReviewPromptCard`:
  - Purple eyebrow ("REVIEW DUE", tracked caps).
  - `calendar.badge.clock` SF Symbol on the eyebrow row.
  - Card body shows the chip label with a `Spacer` + trailing
    `arrow.right` so the row reads as a tap target.
  - `AppColor.pro` stroke at 0.32 opacity (slightly stronger
    than the generic starter chip stroke at 0.18) — the review
    chip has a louder visual register so the user reads it as
    priority.
- Tap fires `send(CoachContextBuilder.interventionReviewOpener(
  intervention: intervention, voice: voice))` — the same opener
  helper the summary card routes through. The existing `send`
  pipeline appends the user turn and fires `runReply` for the
  coach reply. No new navigation plumbing, no new store seam,
  no new bridge contract.

### Track 4 — `AskNoumReviewChipCopyTests` (5 tests, `NoumTests/NoumTests.swift`)

Appended inside the existing `InterventionReviewPromptTests`
struct (after the opener voice-mapping tests) — same fixture,
same `@MainActor` register, same value-only test discipline (no
`CoachMemoryStore` or `AskNoumStore` stood up).

**Chip copy branches (3):**
- `chipLabelNamesFocusLowerCased` — happy path, focus is lower-
  cased mid-phrase per the brand voice.
- `chipLabelFallsBackToTitleWhenFocusIsNil` — defensive nil
  fallback.
- `chipLabelFallsBackToTitleWhenFocusIsEmpty` — defensive empty-
  string fallback.

**Chip contract (2):**
- `chipLabelHasNoTrailingPeriod` — pins the no-trailing-period
  contract so a future refactor that adds one (to match the card
  headline) surfaces as a test failure rather than as a quietly-
  styled chip.
- `chipLabelDoesNotDependOnFollowedRepCount` — pins the voice-
  stable contract so a refactor that smuggles rep counts into
  the chip (e.g. "Review my work on filler reduction (4 reps in)")
  surfaces as a test failure.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  "compare response across multiple attempts and either
  reinforce, vary, or replace the intervention with an explained
  rationale." Round 24 closed the post-rep entry path. Round 25
  closes the second entry path — the user who reaches Ask Noum
  directly. Together, the two surfaces guarantee the coach
  honours the review cadence regardless of how the user enters
  the chat.
- **Pillar #5 (Personalized coaching).** A real coach revisits
  the prescribed plan at the cadence they agreed, whether the
  user comes through the front door or the side door. The chip
  honours that on the side door.
- **Pillar #4 (Believable progress).** The chip is a credibility
  receipt the same way the card is: the user sees the coach
  honour the review cadence the moment they open the chat,
  not weeks later when the next session ends.
- **Anti-goal alignment (no "hearts-and-lives gating").** The
  chip never blocks the chat; the user can ignore it and use
  the regular starters or type their own question. The chip is
  one tap path, not the only path.

### Branch + redesign-alignment notes

- All edits land on `Redesign`, the redesign-lineage branch the
  rolling M24 deferred-slate work has been shipping on since
  round 11. The user brief explicitly calls this out: "ensure
  working on the redesign branch too (very important)." This
  round preserves the round-by-round loop on the redesign
  lineage.

## Future moves

(Updated priority list — round 25 closes the round-24 #1
future-move; the rest roll forward.)

1. **Record user confirmation / rejection of the working
   hypothesis.** Carry forward from the 2026-05-29 HANDOFF
   (step #3) and round 24. The post-review reply from the coach
   should be followed by a single-tap acknowledgement that
   updates `CoachMemory.workingHypothesis` confidence. Requires a
   PrimaryFocusMemory addition + a small Ask Noum response chip
   surface — bigger lift than rounds 24/25, but the natural
   follow-on.
2. **Peer Sudden Death scores via `FriendsManager`.** Still blocked
   on `PublicProfileSnapshot` schema work.
3. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated
   refactor pass with proper visual QA (and a real device).
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
9. **Lift `activeReviewDueIntervention` into `CoachMemoryStore`.**
   New note from round 25. Both `SummaryView` and `AskNoumView`
   now carry a byte-identical helper. A future round could lift
   it into `CoachMemoryStore` (e.g. `currentReviewDueIntervention(
   at: Date()) -> CoachIntervention?`) and have both surfaces
   read through the store. Low value today (the duplication is
   four lines), worth doing if a third reader appears.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so
nothing in this round was compiled or run — not the app, not the
test suite. The changes are:

- A pure copy helper on `InterventionReviewPromptCard` —
  `static func emptyStateChipLabel(for:) -> String`. Three
  lines, one fallback ternary, no I/O. Uses the same lookup
  pattern as `headlineCopy(for:)` which is already locked by
  round-24 tests.
- A new computed helper + new private `@ViewBuilder` on
  `AskNoumView`. The computed reads
  `coachMemoryStore.currentMemory?.activeIntervention?.isReviewDue(at:)`
  — every property already in scope (the `@StateObject` was
  already wired in line 41 of `AskNoumView.swift`). The view
  uses only design tokens already in scope: `Typography.body`,
  `Typography.micro`, `AppColor.pro`, `AppColor.cardBackground`,
  `AppColor.textPrimary`, `CornerRadius.medium`, `Spacing.xs`,
  `Spacing.sm`, `Spacing.md` — every one referenced in the
  surrounding `emptyState`.
- One conditional insert above the "Starters" eyebrow on
  `emptyState` — same `if let` pattern as `SummaryView` uses.
- 5 new tests appended inside the existing
  `InterventionReviewPromptTests` struct. They reuse the
  `makeIntervention(...)` fixture from rounds 24 — no new
  fixture, no new test scaffolding.
- The `Noum.xcodeproj` uses Xcode 16
  `fileSystemSynchronizedGroups` for the `Noum/` folder, so the
  edited `InterventionReviewPromptCard.swift` and
  `AskNoumView.swift` continue to be auto-included in the target
  without a pbxproj edit.

All checks the next agent should run on a real build host:

1. `swift test --filter InterventionReviewPromptTests` — the
   round-24 tests (23) + round-25 chip tests (5) should all pass
   in the same struct.
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
   `reviewDueAt` is a date in the past, then open Ask Noum
   directly (e.g. from the home surface, not via the post-rep
   Summary). Confirm:
   - The "REVIEW DUE" chip renders ABOVE the "Starters" eyebrow
     on the empty state.
   - Chip label reads "Review my work on <focus>" with focus
     lower-cased (e.g. "Review my work on filler reduction").
   - Tap → the chat appends the case-anchored opener as a user
     turn and the model reply lands inline, with the same case
     scaffolding the summary card's CTA produces.
   - When `followedRepCount` is one short OR `reviewDueAt` is
     in the future, the chip does NOT render.
   - When the active intervention has no focus AND no title,
     the fallback path runs without crashing (defensive — the
     pure helper handles this; the view path should too).
   - Same Ask Noum thread, returning after a reply has landed:
     the chip is hidden (the empty state itself is hidden once
     `store.messages.isEmpty == false`).
