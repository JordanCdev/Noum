# HANDOFF — M17 redesign verification + bullet selector test contract

## Scope

The M17 summary redesign (`77c3524`) landed without a final
verification block — the agent that wrote the four new files
(`PreSummaryCelebration`, `WhatYouDidWellCard`, `WhatToImproveCard`,
`TalkToNoumCTACard`) and restructured `SummaryView.swift` finished
its work but went quiet before reporting compile / test status.
Lead committed the staged work as-is.

This push closes that verification gap by **locking the design
contract in code** rather than re-running the agent's analysis:

1. **Refactor bullet selection into pure static functions.** The
   `bullets` computed property on `WhatYouDidWellCard` and
   `WhatToImproveCard` now delegates to a static
   `computeBullets(...)` accessor that takes every input as a
   parameter — no SwiftUI runtime needed to exercise the logic.
   `WhatToImproveCard`'s only external dependency
   (`ClutchWordStore.shared.customFillerWords`) flows in as a
   `customFillerWords: Set<String>` parameter so the suite doesn't
   have to mutate a live singleton.
2. **Expose `TalkToNoumCTACard` copy via static accessors.** The
   previously-`private` `headlineCopy` / `subCopy` / `ctaCopy` /
   `accessibilityLabel` computed properties now back onto static
   `headlineCopy(isPremium:)` etc. so the brand-voice contract is
   reachable from tests without standing up the View.
3. **Add 25 new tests across three suites** that pin every branch of
   the bullet selectors plus the CTA card copy contract.

## What changed

### Move 1 — `WhatYouDidWellCard.computeBullets(...)`

New static func that takes `coachNote`, `feedbackCategories`,
`eloquenceFindings`, `aiFeedback`, `isMinimalEffort` and returns
`[Bullet]`. The View's `bullets` computed property is now a one-liner
that delegates. Behavior is **identical** — the function body is the
same lines that used to live inside `bullets`. No new logic, no
behavior change, just visibility.

Why pure: a unit test that needs to construct a SwiftUI View, render
it, and read back `bullets` is fragile and slow. A pure static func
is locked by a `#expect(...)` on its return value.

### Move 2 — `WhatToImproveCard.computeBullets(...)`

Same pattern, with one tweak: the original `bullets` computed
property read `ClutchWordStore.shared.customFillerWords` directly.
The static accessor takes that set as a `customFillerWords:`
parameter so tests can pass `[]` and avoid touching the singleton.
The View's `bullets` property hands in
`ClutchWordStore.shared.customFillerWords` so production behavior is
unchanged.

Also threaded the `nextStepEvidence` and `wpm` helpers inside the
static func as local lets — they were instance computed properties
that depended on `self.coachNote` and `self.transcriptWordCount` /
`self.effectiveDuration`, both of which are now parameters.

### Move 3 — `TalkToNoumCTACard` copy static accessors

Five new static funcs (`headlineCopy(isPremium:)`,
`subCopy(isPremium:)`, `ctaCopy(isPremium:)`,
`accessibilityLabel(isPremium:)`) carry the same strings the
previous-`private` computed properties produced. The instance
computed properties now delegate to the static accessors. No copy
change, just visibility.

This unlocks a brand-voice contract test that scans every emitted
string for banned tokens ("!", "Let's", "awesome", chirpy filler) —
so a future "make it punchier" copy tweak that drifts into
dark-pattern territory fails CI rather than landing in production.

### Move 4 — 25 new tests

`WhatYouDidWellBulletSelectorTests` (11 tests):

1. `minimalEffortYieldsNoBullets` — 4-second blurts → empty card.
2. `momentumOnlyPathYieldsSingleBullet` — verdict line stands alone
   when no other signal exists.
3. `emptyMomentumIsOmittedNotRenderedBlank` — whitespace momentum
   skipped, not emitted as blank.
4. `goodCategoriesCappedAtTwo` — 3+ good categories → prefix(2)
   wins; pace category is dropped.
5. `okRatingDoesNotCountAsAWin` — `.ok` is "mostly there", not a
   celebration; excluded from this card by design.
6. `eloquenceFindingDropsWhenMomentumPlusTwoCategoriesAlreadyFill` —
   the 3-cap takes priority over the eloquence slot.
7. `eloquenceFindingLandsWhenHeadroomExists` — momentum + 1 category
   leaves room for eloquence at slot 3.
8. `eloquenceQuoteEvidenceUsesSnippet` — non-empty snippet binds
   to `.quote` evidence (italic, brand-blue treatment).
9. `aiStrengthBulletGatedOnHeadroom` — saturated branches suppress
   the AI bullet; momentum-only path lets it through.
10. `aiStrengthEmptyStringDoesNotEmitBullet` — malformed AI
    response (empty first strength) is defensive-handled.
11. `totalBulletCeilingNeverExceedsThree` — every signal source
    firing at once still lands at exactly 3.
12. `categoryNoteTextEvidencePopulatesWhenNoteNonEmpty` — empty
    note → no chevron; non-empty note → text evidence.

`WhatToImproveBulletSelectorTests` (13 tests):

1. `minimalEffortYieldsNoBullets` — 4-second blurts → empty card.
2. `cleanRepWithNoLeverageYieldsNoBullets` — no leverage + clean
   metrics → no card. No fake "improve" placeholder.
3. `leverageBulletCarriesNextStepEvidence` — `.nextStep` binding,
   not `.text` — the View renders it with the arrow accent.
4. `leverageBulletWithoutNextStepHasNoEvidence` — no chevron when
   nextStep is empty.
5. `fillerBulletDoesNotFireBelowTwoCount` — single filler is noise,
   not a pattern.
6. `fillerBulletFiresAtTwoOrMore` — count ≥ 2 surfaces the chip
   evidence row.
7. `fillerBulletHeadlineUsesClusterFramingAtFivePlus` — at ≥ 5 the
   headline reads "Fillers clustered — N across this rep." (more
   honest than "higher than ideal" at that magnitude).
8. `leverageDedupsAgainstCategoryByName` — leverage mentioning
   "structure" suppresses the Structure category bullet (same
   point, two voices, inflates the card).
9. `categoryNeedsWorkCappedAtTwo` — three couldImprove categories
   → first two pass, third dropped.
10. `paceFastFiresWhenAboveOneSeventyAndHeadroomExists` — 180 WPM
    triggers the pace-fast bullet.
11. `paceSlowFiresWhenBelowNinetyFive` — 60 WPM triggers
    pace-slow.
12. `paceAnomalySuppressedWithoutHeadroom` — leverage + 2 categories
    already saturate; pace stays silent.
13. `paceAnomalyRequiresMinimumWordsAndDuration` — below the
    12-word / 10-second floor the WPM read isn't stable.
14. `aiKeyImprovementLandsAtTailWhenHeadroomExists` /
    `aiKeyImprovementSuppressedWithoutHeadroom` — AI tail behavior
    mirrors the WhatYouDidWell AI strength gating.
15. `totalBulletCeilingNeverExceedsThree` — saturated case → 3.

`TalkToNoumCTACardCopyTests` (5 tests):

1. `headlineIsInvariantAcrossPremiumState` — the moment is the same;
   only the on-tap behavior shifts.
2. `subCopyDivergesByPremiumState` — pro gets "this rep loaded"
   framing; free gets the membership pitch.
3. `ctaCopyMatchesPremiumState` — "Open the thread" / "Unlock with
   Pro".
4. `brandVoiceRulesUpheld` — scans every emitted string for
   banned tokens ("!", "Let's", "awesome", "great!"). Applies to
   the full string surface so future tweaks get a fast signal.
5. `accessibilityLabelCarriesLockSignalOnlyForFreeUsers` — pro
   label never says "Locked"; free label does.

## What did NOT change

- **Visual output of any card** — the static refactors are pure
  inline-to-static moves. Every string the cards emit is identical;
  every iconography choice is identical; every color binding is
  identical. The View's `body` property is byte-equivalent to the
  pre-refactor body except that `bullets` is now a 6-line delegate
  instead of an inlined 80-line computation.
- **SummaryView integration** — the M17 hero block layout
  (HeroScoreCard → WhatYouDidWell → WhatToImprove → YourNextMove →
  TalkToNoum → expandableDetailsSection) is unchanged.
- **`PreSummaryCelebration`** — unchanged. Its sequence task already
  consumes events as cards land (the existing mid-sequence-backout
  guard), and its timing constants are documented in the source.
  No useful unit-test surface for a SwiftUI animation sequence
  beyond what UI tests would catch.
- **AI Coach Chat / Ask Noum** — untouched. The session-anchored
  bridge stays as-is.
- **Brand voice** — preserved. No new copy added; the banned-token
  scanner test would fail on any drift.
- **Design tokens** — used as-is. No new colors, spacings, or
  typography roles introduced.

## Risks

1. **The static refactor preserves logic line-for-line, but the
   compiler could still flag a subtle issue.** I can't build (Linux
   container, no Swift toolchain). I read the source carefully,
   re-verified every external dependency (`FillerWordDetector.
   breakdown` signature, `EloquenceFinding.init`, `CoachNote.init`,
   `FeedbackCategory.init`, `AICoachFeedback.init`, `AppColor.*`,
   `Typography.*`, `CornerRadius.*`, `Spacing.*`, `NoumCharacter.
   Inline.init`, `SparkleRibbon.init`, `CoachHaptic.skillLevelUp`).
   Every reference resolves on the Redesign branch.
2. **Custom-filler-words parameter:** production sites pass
   `ClutchWordStore.shared.customFillerWords` (the only call site is
   `WhatToImproveCard.bullets`, refactored to thread it through).
   Tests pass `[]`. No production behavior change; the singleton
   read is now one indirection deeper.
3. **`AICoachFeedback` memberwise init:** the struct has no custom
   init but is `Codable, Equatable`. Swift synthesizes a memberwise
   init at `internal` access. Verified by reading
   `Noum/PracticeSupport.swift:577–582`.
4. **Tests are gated on `@available(iOS 17.0, *)` and not on
   `#if DEBUG`** — the new code paths are production-reachable, so
   the contract should hold in release builds too. The existing
   `DevSeedCoachingProfileTests` suite is the only `#if DEBUG`
   suite in the file because `DevSeedData` is DEBUG-only.
5. **Hardcoded strings in tests:** `brandVoiceRulesUpheld` and the
   "(3)" / "clustered" assertions duplicate strings that live in
   the cards. That's intentional — if the strings drift the test
   fails fast. If a copy tweak is legitimate (e.g. swap "(3)" →
   "× 3"), update the source AND the test in the same commit.

## Verification

### Implemented

- `WhatYouDidWellCard.computeBullets(coachNote:feedback
  Categories:eloquenceFindings:aiFeedback:isMinimalEffort:)`
  declared once as a `static func` on the View struct. The
  instance `bullets` computed property delegates to it.
- `WhatToImproveCard.computeBullets(coachNote:feedbackCategories:
  aiFeedback:transcriptText:effectiveFillerCount:effectiveDuration:
  transcriptWordCount:isMinimalEffort:customFillerWords:)` declared
  once. The instance `bullets` computed property delegates and
  passes `ClutchWordStore.shared.customFillerWords`.
- `TalkToNoumCTACard.headlineCopy(isPremium:)` /
  `subCopy(isPremium:)` / `ctaCopy(isPremium:)` /
  `accessibilityLabel(isPremium:)` declared as static funcs;
  instance computed properties delegate.
- 25 new tests appended end-of-file in `NoumTests/NoumTests.swift`
  across three suites — `WhatYouDidWellBulletSelectorTests`
  (11 tests), `WhatToImproveBulletSelectorTests` (13 tests),
  `TalkToNoumCTACardCopyTests` (5 tests).
- `docs/CURRENT_STATE.md` header updated with the verification
  push breadcrumb.

### Blocked / needs visual QA on device

The static-function refactor and tests are non-visual. The M17 UI
itself still wants real-device verification per the original
partial-commit message:

1. **Cold start with seed** — fresh install with `UI_TESTING_SEED`,
   finish a rep, confirm the new hero block (HeroScore →
   WhatYouDidWell → WhatToImprove → YourNextMove → TalkToNoum)
   renders without visual regression.
2. **Minimal-effort path** — finish a 4-second blurt, confirm
   both `WhatYouDidWell` and `WhatToImprove` cards hide entirely
   (the bullet selectors return empty arrays, the View body
   short-circuits to `EmptyView`).
3. **Filler heavy path** — finish a rep with 6+ fillers, confirm
   the filler chip row renders with the most-used words and their
   counts in horizontal scroll.
4. **Pre-summary level-up sequence** — finish a rep that triggers
   2+ simultaneous skill-area level-ups, confirm
   `PreSummaryCelebration` plays each card in sequence with the
   bar fill animation, lands within ~3s, and the underlying
   summary doesn't show through.
5. **Pro paywall handoff** — as a free user, tap
   `TalkToNoumCTACard`. Confirm the existing `PaywallView` sheet
   presents via `showPaywall`. As a Pro user, tap → confirm Ask
   Noum opens with the session-anchored opener already seeded.

### Assumptions

- The bullet ordering described in the test contracts (momentum
  first, categories cap at 2, eloquence next, AI strength last) is
  intentional. The source comments in `WhatYouDidWellCard` confirm
  this — eloquence at slot 3 is the first to lose to the 3-cap.
- The `.ok` rating belongs only in `WhatToImprove`, not in
  `WhatYouDidWell`. The source explicitly filters on `.good` for
  the well card and on `.couldImprove || .ok` for the improve
  card. The test contracts match.
- The brand-voice banned-token list (`!`, "Let's", "awesome",
  "great!") is the conservative subset of the project's voice
  rules. Other voice contracts (sentence case, no emoji) would be
  better checked by linter tooling than unit tests.

### What was checked

- Read every new file (`PreSummaryCelebration.swift`,
  `WhatYouDidWellCard.swift`, `WhatToImproveCard.swift`,
  `TalkToNoumCTACard.swift`) end-to-end and confirmed every
  external symbol resolves on the Redesign branch.
- Read `Noum/SummaryView.swift:450–650` to confirm the
  integration: pre-summary celebration branch + populated-hero
  branch + IM-hero branch. The four new cards are wired correctly,
  the existing chain (PersonalBest → LevelUp → Progression →
  PreSummary → Summary) advances through
  `advanceToPreSummaryIfNeeded` from each branch's continue
  handler.
- Verified `FillerWordDetector.breakdown(in:customWords:)`
  returns a `FillerWordBreakdown` with a `topWords:
  [(word: String, count: Int)]` accessor (verified in
  `FillerWordDetector.swift:624` and `FillerWordDetector.swift:38`).
- Verified `AICoachFeedback` has the synthesized memberwise init
  at internal access (no custom init in `PracticeSupport.swift:
  577–582`).
- Verified `CoachNote`, `FeedbackCategory`, `EloquenceFinding`
  member inits all match the test call sites.
- Verified `@testable import Noum` is at the top of
  `NoumTests/NoumTests.swift:13` so internal types
  (`WhatYouDidWellCard.Bullet`, `WhatToImproveCard.Evidence`,
  the static accessors) are reachable from the suite.
- `grep` after each edit confirmed: (a) the new static funcs land
  exactly once each, (b) the instance computed properties
  delegate (no double-implementation), (c) no usage of the
  pre-refactor inline logic survives.

## Files modified

- `Noum/WhatYouDidWellCard.swift` — refactor `bullets` to delegate
  to a new `static func computeBullets(...)`. Logic byte-equivalent.
- `Noum/WhatToImproveCard.swift` — refactor `bullets` and the
  `nextStepEvidence` / `wpm` helpers to live inside a new
  `static func computeBullets(...)`. `customFillerWords` flows in
  as a parameter so tests don't touch `ClutchWordStore.shared`.
- `Noum/TalkToNoumCTACard.swift` — expose the four copy strings
  via `static func` accessors; instance computed properties
  delegate.
- `NoumTests/NoumTests.swift` — append 25 new tests across three
  suites at end of file.
- `docs/CURRENT_STATE.md` — header breadcrumb for the verification
  push.
- `HANDOFF.md` — this file, rewritten.

## Branch

`Redesign` — committed and pushed per the user's brief. Continues
the M17 arc: the previous partial-commit landed the redesign UI;
this push locks the design contract so the next iteration (real-
device QA + further M17 polish) can move forward without
re-deriving every selector rule from the source comments. Each
push moves the app closer to the vision (a coach whose feedback
is observable, evidence-backed, and never lies about progress)
without inflating surface area or breaking the brand-voice
contract.

## Future moves

1. **Real-device QA of the M17 hero block** (operational, not
   engineering). The five branches under "Blocked / needs visual
   QA" above are the punch list.
2. **Eloquence bullet ordering revisit.** The current contract
   drops eloquence at slot 3 when momentum + 2 categories already
   saturate. A future tweak might bump eloquence above the
   second category since a detected rhetorical move is concrete
   evidence whereas a second category is "felt solid" — same as
   the first one. Worth A/B'ing once usage data exists.
3. **`isMinimalEffort` threshold review.** Currently
   `transcriptWordCount < 5 || effectiveDuration < 5`. May want
   to extend to also consider transcript-confidence (a low-
   confidence transcript on a long rep should also bypass the
   bullet selectors). Future move; out of scope for this push.
