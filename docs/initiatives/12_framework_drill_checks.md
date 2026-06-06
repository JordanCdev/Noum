# Initiative #12 — Verified deliberate-practice for named frameworks (slice-3)

Generated: 2026-06-01 · Branch `Redesign` · Status: **built, pending `xcodebuild test`**

## Why this exists (the repertoire gap)

The initiative #8 audit named the single biggest CONTENT gap a human coach owns:
the **named-exercise library**. A coach doesn't just react to a rep — they assign
the right exercise (impromptu, STAR storytelling, persuasion frameworks, the
elevator pitch, …) with an observable target stated *before* the rep, then check
whether the target was hit.

Noum already displayed framework instructions (the PREP Stack drill, the
`SpeechProject` prompts), but three of the highest-value exercises whose
objectives are **deterministically verifiable** were "displayed instruction" with
no checked target:

- **STAR / narrative storytelling** — a story without a *turn* is just a
  description. Nothing checked for the pivot from setup to change.
- **Persuasion with a counter** (claim-evidence-warrant / counter-acknowledgement)
  — a one-sided assertion is not a persuasive case. Nothing checked for the
  acknowledge-then-bridge move.
- **Timed elevator pitch** — a self-introduction with one hook inside a time box.
  Nothing checked for named-self + single hook + landing in the box.

This slice converts those three from *displayed instruction* into *real
deliberate practice with an observable, checked target* — the deterministic
subset that can be honestly ticked statically.

## What was built (6 files + 3 test suites)

Pure depth on existing owners — **no new store, router, or MiniDrillView screen**.
A single new `MiniDrillType` case routes three new catalog entries through the
existing standard recording UI; one new pure detector file holds the structural
checks; the verdict surfaces through the existing mini-drill copy seam.

1. **`Noum/FrameworkDrillChecks.swift`** *(new, pure)* — three deterministic
   detectors + their bounded `Equatable` verdict enums:
   - `starTurn(transcript:) -> StarTurnVerdict?` — `.turnDetected` on a
     discourse-shift marker (`turnMarkers`: "but then", "until", "that's when",
     "suddenly", …); `.flat` above the floor with no shift; `nil` below the
     `minContentWordsForVerdict = 6` content-word floor. Bare sequencing ("and
     then") is intentionally EXCLUDED; risky bare markers ("one day", "the
     moment") were dropped to err toward false negatives.
   - `claimCounter(transcript:) -> ClaimCounterVerdict?` — `.counterAcknowledged`
     only when an `acknowledgementMarkers` concession appears AND a
     `bridgeMarkers` pivot appears **strictly after it** (ordering enforced via
     `firstIndex` offset comparison — a bare "but" with no prior concession is
     just a continuation, so it stays `.oneSided`); `.oneSided` above the floor
     otherwise; `nil` below it.
   - `elevatorPitch(transcript:duration:) -> ElevatorPitchVerdict?` — checks the
     three observable targets: named-self (`selfNameMarkers`), a concrete hook
     (`>= 6` content words), and landing inside the time box (`<= 30s` AND
     `<= 85` words). Priority of misses: `.missingName` > `.overTime` >
     `.missingHook`; `.landed` when all three pass; `nil` only when BOTH too
     short (`< 8s`) AND too thin (no confident verdict on nothing).

   Every threshold is a named constant. Phrase scanning runs over a `normalised`
   string (lowercased, punctuation → space, apostrophes + curly-quote folded so
   "i'm," still matches "i'm"). Content-word tokenization REUSES
   `PracticeEvaluator.relevanceContentWords` — the same tokenizer the prompt-
   answer verdict reads (no forked tokenizer).

2. **`Noum/PracticeSupport.swift`** — widened `relevanceContentWords(in:)` from
   `private` to internal `static` (matching how `relevanceFirstSentence` /
   `promptAnswerVerdict` are already shared cross-file) so the detectors reuse
   the one canonical content-word rule. No behavior change.

3. **`Noum/DrillSystem.swift`** — three new `DrillVariation` catalog entries
   (`story.starTurn` → `.answerDevelopment`, `structure.claimCounter` →
   `.structure`, `concise.elevatorPitch` → `.conciseSpeaking`), each stating its
   named framework + observable target in `constraint` / `coachingPrinciple` /
   `successDescription` (the rubric clause: target stated before the rep). New
   `MiniDrillType.frameworkCheck` case + `MiniDrillType.from(variationId:)`
   routing + `MiniDrillType.framework(for:)` → bounded `FrameworkDrill` enum.
   `DrillXPEngine.breakdown` handles `.frameworkCheck` with the standard
   word/duration quality bonus — the structural verdict is **never** an XP input.

4. **`Noum/MiniDrillView.swift`** — `finishDrill` derives `drillType` + framework
   from the variation ID (instead of hardcoding `.standard`) and computes the
   structural verdict READ-ONLY via the new `FrameworkDrillVerdict.evaluate`
   factory; `succeeded` stays driven purely by the deterministic
   `evaluateSuccess` thresholds. New `framework` / `frameworkVerdict` fields on
   `MiniDrillOutcome` (defaulted `var` optionals — existing construction sites
   unaffected) + the `FrameworkDrillVerdict` type-erased wrapper.

5. **`Noum/MiniDrillResultView.swift`** + **`ReinforcementCopy.swift`** — the
   verdict surfaces through the existing mini-drill copy seam:
   `DrillCompletionCopy.frameworkFeedback(outcome:)` (the structural analog of
   `prepStackFeedback`) emits ONE constructive nudge keyed to the verdict band,
   and `frameworkTitle(for:)` gives a verdict-keyed result title. Below the
   evidence floor (no verdict) both fall back to the neutral skill-area copy — no
   confident "no turn" / "one-sided" on thin data. `MiniDrillResultView`'s two
   `switch drillType` surfaces route `.frameworkCheck` (feedback + generic stats).

6. **`Noum/SummaryView.swift`** — `drillView(for:)` routes `.frameworkCheck` to
   the standard `MiniDrillView` (reuse, no new screen).

7. **`NoumTests/NoumTests.swift`** — three suites (~28 tests):
   `FrameworkDrillCheckTests` (per-detector boundaries), `FrameworkDrillCatalogTests`
   (catalog/routing integrity), `FrameworkDrillCopyAndScoreTests` (score-safety +
   copy). Every fixture hand-traced against the real `relevanceContentWords` stop
   set + the named constants.

## Proven-contract clauses satisfied

- **RUBRIC** — each drill carries a named framework + an observable target stated
  before the rep, modelled in the `DrillVariation` catalog fields
  (`FrameworkDrillCatalogTests.frameworkVariationsCarryNamedTargetCopy`).
- **GROUNDING GATE / HIGH EVIDENCE FLOOR** — each detector is a conservative,
  bounded discourse-marker reducer with a content-word floor; below the floor it
  returns `nil` (tentative, never a confident negative). Turn-check requires an
  unambiguous shift marker; claim/counter requires acknowledge-THEN-bridge
  ordering; elevator-pitch verifies named-self + single hook + time box.
  Association is never described as causation (copy frames the *move*, never a
  verdict on whether the content was right).
- **DETERMINISTIC FALLBACK / LOCALE** — the detectors are pure and deterministic,
  so they run offline and in any locale with no AI gate. Below-floor reps fall
  back to the existing neutral skill-area copy line (never worse than today,
  never raw error text).
- **SCORE-SAFETY** — the structural verdict surfaces ONE nudge via the copy seam
  and is provably NOT an input to `succeeded` or XP
  (`FrameworkDrillCopyAndScoreTests.structuralVerdictDoesNotMoveXP`: two outcomes
  identical in every numeric input but differing in turn-vs-flat earn identical
  XP).
- **SINGLE SOURCE OF TRUTH** — content-word tokenization reuses
  `PracticeEvaluator.relevanceContentWords`; the verdict routing lives in one
  `FrameworkDrillVerdict.evaluate` factory the recording flow and tests both call;
  one `FrameworkDrill` enum keys all three surfaces (no scattered string compares).
- **BOUNDED / DECODE-SAFE / DEFAULTED** — `FrameworkDrill` is a `String`-raw
  `Codable` enum; the new `MiniDrillOutcome` fields are defaulted optionals so
  every existing construction site is back-compatible.

## Invariants honored

- **EXTEND existing owners** — new `DrillVariation` entries + one `MiniDrillType`
  case in `DrillSystem.swift`; reuse the standard `MiniDrillView` recording UI and
  the `DrillCompletionCopy` mini-drill copy seam. The one new file
  (`FrameworkDrillChecks.swift`) is a pure detector engine per the repo's
  per-engine pattern — no new store, router, or screen.
- **Deliberate practice, not gamification** — the drills check a real structural
  target; no fake unlocks, no points-for-the-verdict, no leaderboard.
- **Never punish-shame** — every miss verdict frames the missing move as the next
  target; below-floor reps get no negative verdict at all.

## Verification (this run)

No Swift toolchain on the build host. Verified by static analysis + hand-tracing:

- All six edited files + the new file are brace- and paren-balanced; the added
  test block (lines 267–588) is balanced (40/40 braces, 165/165 parens). The
  whole-file paren count is off by 3, but that imbalance is PRE-EXISTING in the
  committed `NoumTests.swift` (string-literal artifacts), not from this slice.
- Five exhaustive `switch` sites over `MiniDrillType` / `drillType` were found and
  all handle `.frameworkCheck`: `DrillXPEngine.breakdown`,
  `SummaryView.drillView(for:)`, `MiniDrillResultView.feedbackText` + `.statsRow`,
  `DrillCompletionCopy.title(for:)`.
- The three pre-existing `MiniDrillOutcome` construction sites (BeatTheBrakeView /
  LandThePauseView / PREPStackView) compile unchanged — the new fields are
  defaulted `var` optionals (same memberwise-init behavior the existing metric
  fields rely on).
- Every detector fixture hand-traced against `relevanceContentWords`
  (`>= 4` chars, not in `relevanceStopWords`) + the `FrameworkDrillChecks`
  constants to avoid off-by-one fixture bugs.

**Gate (yours):** `xcodebuild test` on a Mac, plus on-device QA to judge whether
the structural nudges *feel* like a coach (only provable with real reps; the
detectors themselves are deterministic and tested).

## Honest limits

- The detectors are conservative lexical/structural reducers, not semantic
  understanding. A story can pivot without a marker word (false negative — by
  design); an elevator pitch can name a company without a `selfNameMarkers`
  phrase. The floor + false-negative bias keep them from over-claiming, but they
  do not "understand" the narrative the way a human coach would — that is the
  honest ceiling of the deterministic subset.
- Optional LLM enrichment (a richer structural read) is intentionally NOT added
  here; if layered later it must reuse the standard `activeLocaleSupportsAI` gate
  + grounding gate + this deterministic fallback.
