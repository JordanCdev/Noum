# HANDOFF — M24 deferred slate (round 24): post-rep intervention-review prompt — `SummaryView` surfaces `InterventionReviewPromptCard` when the active case-file intervention's `reviewDueAt` cadence has elapsed AND the followed-rep evidence floor is met

## Scope

Rounds 22 and 23 closed two read-side honesty holes on the post-rep
`CoachReadCard` (the rate-limiter publication + the `PremiumManager`
observation for the daily-budget hint). Round 24 picks up the
highest-impact next-step listed in the 2026-05-29 case-intervention
HANDOFF:

> 1. `Noum/SummaryView.swift` — add a concise intervention-review
>    prompt when `CoachIntervention.reviewDueAt` is due and minimum
>    followed reps are met.

The case-file infrastructure already records every field this
prompt needs: `reviewDueAt`, `followedRepCount`,
`minimumFollowedRepsForReview`, `focus`, `title`, `mode`. Until
round 24, those fields fed only the AI context block in
`CoachContextBuilder.interventionCycleLines(...)` — the user
themselves never saw a prompt to revisit the intervention at the
moment the cadence elapsed. The coach silently re-prescribed past
the agreed review date.

That breaks the coaching contract docs/VISION.md names directly:

> **Coach-parity stage #4 (Adaptation).** Compare response across
> multiple attempts and either reinforce, vary, or replace the
> intervention with an explained rationale.

Round 24 closes that gap with the minimum amount of plumbing:

- A pure predicate on `CoachIntervention` so the eligibility math
  is one home + locked by tests.
- A new `InterventionReviewPromptCard` SwiftUI surface with pure
  copy helpers so the headline and body strings are
  tested-against-string, not against-screenshot.
- A new `CoachContextBuilder.interventionReviewOpener(...)` seed
  for the Ask Noum deep-link, voice-mapped on the same
  SpeakingStyleGoal axis as the existing `sessionOpener`.
- Two conditional inserts into `SummaryView` (IM path + standard
  path), placed right before the existing `TalkToNoumCTACard` so
  the review prompt reads as the coach's specific check-in
  preceding the general "Talk to Noum" CTA.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- The honest gap from the 2026-05-29 case-intervention HANDOFF —
  the user never sees the coach honour the review cadence the
  case engine already records — was the highest-value unblocked
  next step on the case-file lineage. Round 24 closes it with a
  contained edit: one pure predicate, one new card, one opener
  helper, two SummaryView conditionals, and 23 tests pinning the
  threshold math + copy branches.
- The contract is narrow on purpose: the predicate accepts a
  `CoachIntervention` + `Date` and answers one yes/no; the card
  reads a single `CoachIntervention` and renders one CTA; the
  opener carries the case scaffolding (mode + focus + followed-
  rep depth) into Ask Noum so the AI reply has the evidence
  basis in scope. No new state owner, no new persisted field, no
  cross-store coupling.
- The redesign-branch invariant: this is a `Redesign`-branch
  push per the user brief. The work lands directly on
  `Redesign` so the round-by-round loop on the redesign lineage
  is preserved.

## What shipped

### Track 1 — `CoachIntervention.isReviewDue(at:)` pure predicate (`PrimaryFocusMemory.swift`)

`Noum/PrimaryFocusMemory.swift:241` — appended after the existing
case-spine fields:

- `func isReviewDue(at now: Date) -> Bool` — both gates must hold
  (`followedRepCount >= minimumFollowedRepsForReview` AND
  `reviewDueAt != nil && now >= reviewDueAt`). The doc-comment
  names why both gates exist: the evidence threshold prevents an
  early prompt on thin observed reps; the cadence threshold
  prevents the coach silently overriding the review date.
- Pure function of the intervention's own fields + `now`, so the
  predicate can be locked by tests without standing up a real
  `CoachMemoryStore`. Used by `SummaryView` to decide whether to
  render `InterventionReviewPromptCard`.

### Track 2 — `InterventionReviewPromptCard` (`InterventionReviewPromptCard.swift`)

New file `Noum/InterventionReviewPromptCard.swift`:

- Restrained card: purple eyebrow ("REVIEW DUE"), one-line
  headline, one-paragraph body, one CTA ("Review with coach").
  Mirrors `CoachReadCard`'s purple-stroke register so the user
  reads it as a continuation of the same coach voice rather than
  a separate system notification.
- Two pure-function copy helpers — `headlineCopy(for:)` and
  `bodyCopy(for:)` — so the strings can be locked by tests.
  Headline names the focus (lower-cased per brand voice, falls
  back to `title` when `focus` is nil or empty so the noun phrase
  is never blank). Body names the followed-rep depth so the user
  sees the basis of the prompt and frames the review question
  ("keep going, adapt, or replace it?").
- Brand-voice compliant: no exclamation, no "Let's", no urgency
  framing, no "running out." The coach is a professional
  revisiting a plan.

### Track 3 — `CoachContextBuilder.interventionReviewOpener(intervention:voice:)` (`CoachContextBuilder.swift`)

`Noum/CoachContextBuilder.swift:746` — added after `sessionOpener`:

- Shape mirrors `sessionOpener` exactly so the AskNoumView render
  logic stays uniform: short fact-lead + voice-shaped ask.
- Lead: `"Time to review the active case: <mode> for <focus>, <N>
  followed rep(s) in."` — carries the case scaffolding so the AI
  reply has the verdict scaffolding already in scope.
- Voice-shaped ask: maps each `SpeakingStyleGoal` to a single
  question the user wants to ask. `.authoritative` →
  `"Is this still the right intervention, or do we adapt?"`,
  `.warm` → `"Is this still feeling like the right work?"`,
  `.concise` → `"Keep, adapt, or replace?"`, etc. Falls back to a
  neutral ask when `voice == nil`.

### Track 4 — `SummaryView` wiring (`SummaryView.swift`)

`Noum/SummaryView.swift`:

- Two new computed helpers right after `sessionAnchoredOpener`:
  - `activeReviewDueIntervention: CoachIntervention?` — reads
    `coachMemoryStore.currentMemory`, returns the active
    intervention iff `isReviewDue(at: Date())` is true.
  - `interventionReviewOpener(for:)` — thin wrapper that routes
    through `CoachContextBuilder.interventionReviewOpener` so the
    voice mapping contract lives next to the existing
    `sessionOpener` voice mapping (one home for both).
- Two conditional inserts in the view hierarchy, both placed
  right before the existing `TalkToNoumCTACard`:
  - **IM path** (after `BaselineComparisonCard`, line ~632) —
    the IM summary's coaching-first card stack continues into
    the case-review prompt before the general Ask Noum CTA.
  - **Standard path** (after `SessionReflectionInlineCard`, line
    ~741) — the user's own reflection captures the felt
    experience for THIS rep; the review prompt then asks the
    user about the active intervention with that fresh
    reflection in mind; the general Ask Noum CTA closes.
- Both call sites pass the same closure: `onReview: {
  onAskNoumAboutRep?(interventionReviewOpener(for:
  reviewIntervention)) }` — reusing the existing Ask Noum bridge
  the round-19 onward summary surfaces already use. No new
  navigation plumbing.

### Track 5 — `InterventionReviewPromptTests` (23 tests, `NoumTests/NoumTests.swift`)

A new `@MainActor struct InterventionReviewPromptTests` appended
after `CoachReadCardDailyBudgetHintTests`. All tests call pure
functions on small value types — no `CoachMemoryStore` or
`AskNoumStore` is stood up. The helper `makeIntervention(...)`
fixture builds a baseline `CoachIntervention` where every
predicate gate is in the negative state by default, and each test
mutates only the field it asserts against.

**Predicate guards (3):**
- `reviewIsNotDueWhenReviewDueAtIsNil` — nil cadence stamp
- `reviewIsNotDueWhenFollowedRepsBelowMinimum` — thin evidence
- `reviewIsNotDueWhenDueDateInFuture` — cadence not yet elapsed

**Predicate happy path + boundaries (3):**
- `reviewIsDueWhenDueDateInPast` — happy path
- `reviewIsDueWhenDueDateExactlyNow` — inclusive `>=` on the
  cadence axis (round-23-style boundary anchor for date)
- `reviewIsDueWhenFollowedRepsExactlyAtMinimum` — inclusive `>=`
  on the evidence axis

**Predicate symmetric mirror (1):**
- `reviewIsNotDueWhenFollowedRepsOneShortAndCadenceElapsed` —
  evidence floor wins over an elapsed cadence

**Headline copy branches (3):**
- `headlineCopyNamesFocus` — lower-cased focus mid-sentence
- `headlineCopyFallsBackToTitleWhenFocusIsNil` — defensive
- `headlineCopyFallsBackToTitleWhenFocusIsEmpty` — empty-string edge

**Body copy branches (3):**
- `bodyCopyUsesSingularRepNoun` — N=1 singular
- `bodyCopyUsesPluralRepNoun` — N=4 plural
- `bodyCopyUsesPluralForZeroReps` — defensive 0-rep branch

**Opener lead (3):**
- `openerLeadNamesModeFocusAndDepth` — mode + focus + N reps in
- `openerLeadUsesSingularRepNoun` — N=1 singular
- `openerLeadFallsBackToTitleWhenFocusIsNil` — defensive

**Opener voice mapping (7):**
- `openerAskByVoiceAuthoritative`
- `openerAskByVoiceWarm`
- `openerAskByVoiceConcise`
- `openerAskByVoicePersuasive`
- `openerAskByVoiceExecutive`
- `openerAskByVoiceStorytelling`
- `openerAskWhenVoiceIsNil`

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  "compare response across multiple attempts and either
  reinforce, vary, or replace the intervention with an
  explained rationale." Until round 24, the case file recorded
  the review cadence but the user never saw the coach honour it.
  The prompt now lands the same body turn the cadence elapses
  AND the evidence floor is met.
- **Pillar #5 (Personalized coaching).** A real coach revisits
  the prescribed plan at the cadence they agreed. Silently re-
  prescribing the same drill past the agreed review date breaks
  the coaching contract.
- **Pillar #4 (Believable progress).** The prompt is a credibility
  receipt: the user sees the coach honour the review cadence on
  schedule. That earns the right to keep prescribing.
- **Anti-goal alignment (no "hearts-and-lives gating").** The
  prompt never blocks practice; the user can ignore it and keep
  repping. The only action is the deep-link to Ask Noum.

### Branch + redesign-alignment notes

- All five edits land on `Redesign`, the redesign-lineage branch
  the rolling M24 deferred-slate work has been shipping on since
  round 11. The user brief explicitly calls this out: "ensure
  working on the redesign branch too (very important)." This
  round preserves the round-by-round loop on the redesign
  lineage.
- The work also unblocks step #2 from the 2026-05-29 HANDOFF
  ("Ask Noum 'review this case' starter") — the AskNoumView
  already consumes `onAskNoumAboutRep` openers via the
  `AskNoumStore.injectUserTurn` bridge wired in
  `SummaryView.init`, so the round-24 opener flows through that
  pipe without an AskNoumView change. A future round can add a
  voice-shaped starter chip on AskNoumView's empty state for
  users who reach the chat without coming through the summary.

## Future moves

(Updated priority list — the 2026-05-29 HANDOFF's step #1 closed
this round; the rest roll forward, joined by the round-23 list.)

1. **Empty-state "Review this case" starter chip on `AskNoumView`.**
   Carry forward from the 2026-05-29 HANDOFF (step #2). The round-
   24 opener already routes correctly through the AskNoum bridge;
   the chip would let a user who opens Ask Noum directly (not
   from summary) start the same case-review conversation.
2. **Record user confirmation / rejection of the working
   hypothesis.** Carry forward from the 2026-05-29 HANDOFF
   (step #3). The post-review reply from the coach should be
   followed by a single-tap acknowledgement that updates
   `CoachMemory.workingHypothesis` confidence. Requires a
   PrimaryFocusMemory addition + a small Ask Noum response chip
   surface — bigger lift than round 24, but the natural follow-on.
3. **Peer Sudden Death scores via `FriendsManager`.** Still blocked
   on `PublicProfileSnapshot` schema work.
4. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated
   refactor pass with proper visual QA (and a real device).
5. **Visual polish pass on the round-19 launch CTA.** Carried
   forward from rounds 19–23. Pure visual work, not destination
   logic — the router stays the single source of truth either way.
6. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–23. Pure visual work, not crossing logic.
7. **Extend the crossing helper to the chat-coach context line.**
   Carried forward from round 21 as a note for the record (not
   an action item).
8. **Day-rollover refresh for long-mounted observers.** Carried
   forward from round 22. The `AIRateLimiter` publication only
   fires on writes. A user who pins Settings open across midnight
   would still see yesterday's counters until the next consume
   bumps the token. A future round could subscribe to
   `Notification.Name.NSCalendarDayChanged` and bump the token
   from there.
9. **Tier-change observation symmetry to other surfaces that read
   `AIRateLimiter.currentCap()` directly.** Carried forward from
   round 23 as a note for the record.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so
nothing in this round was compiled or run — not the app, not the
test suite. The changes are:

- A pure predicate addition on an existing `Codable, Equatable`
  struct (`CoachIntervention.isReviewDue(at:)`) — six lines, two
  guards, one `>=` comparison. No new fields, no codable changes.
- A new SwiftUI view file (`InterventionReviewPromptCard.swift`)
  that uses only design tokens already in scope: `Typography.*`,
  `AppColor.pro`, `AppColor.cardBackground`, `AppColor.textPrimary`,
  `AppColor.textSecondary`, `CornerRadius.medium`, and the
  `.pressable` button style — every one referenced in nearby
  cards (`CoachReadCard.swift` uses the same set).
- A new pure static func on `CoachContextBuilder` next to the
  existing `sessionOpener` — same SpeakingStyleGoal exhaustive
  switch pattern, so the compiler enforces all six cases plus
  the optional nil.
- Two computed helpers + two conditional inserts in
  `SummaryView` — both inserts use the same `if let
  reviewIntervention = activeReviewDueIntervention` pattern as
  other conditional cards in the same view (the prior
  `if let details = imConversationDetails` is the immediate
  neighbour for the IM insert).
- 23 new tests on three pure functions plus one pure-pure copy
  helper. They mirror the round-23
  `CoachReadCardDailyBudgetHintTests` shape (same
  `@MainActor struct`, same `@Test` annotations, no test seam
  needed).
- The `Noum.xcodeproj` uses Xcode 16
  `fileSystemSynchronizedGroups` for the `Noum/` folder
  (verified via `grep fileSystemSynchronizedGroups
  Noum.xcodeproj/project.pbxproj`), so the new
  `InterventionReviewPromptCard.swift` is auto-included in the
  target without a pbxproj edit.

All checks the next agent should run on a real build host:

1. `swift test --filter InterventionReviewPromptTests` — the 23
   new tests should all pass.
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
   recommendation), then finish a rep to land on SummaryView.
   Confirm:
   - `InterventionReviewPromptCard` renders between the
     `SessionReflectionInlineCard` and `TalkToNoumCTACard`
     (standard path) or between `BaselineComparisonCard` and
     `TalkToNoumCTACard` (IM path).
   - Headline names the active focus, lower-cased.
   - Body names the followed-rep count with correct singular /
     plural noun.
   - Tap "Review with coach" → Ask Noum opens with the
     case-anchored opener already in the thread, the model
     reply lands.
   - With `voice == .authoritative` set in coaching profile,
     the opener ends with "Is this still the right intervention,
     or do we adapt?"; with `.warm`, "Is this still feeling like
     the right work?"; etc.
   - When `followedRepCount` is one short OR `reviewDueAt` is
     in the future, the card does NOT render.
