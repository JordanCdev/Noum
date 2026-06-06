# Initiative #13 — Stated-vs-measured concordance (surface a divergence QUESTION, never a silent focus switch)

Generated: 2026-06-01 · Branch `Redesign` · Status: **built + statically verified (brace-balanced, exact-symbol-matched, fixtures hand-traced against the real maps + floor); pending `xcodebuild test` on a Mac toolchain**

Slice id: `slice-4` of the comprehensive coach-parity push.

## Boxes this ticks

- **DIAGNOSE-3** — Reconcile the measured read with the user's STATED challenge.
- **HONESTY-7** — No silent focus switches on a stated-vs-measured divergence.

This closes the last open DIAGNOSE box plus its paired HONESTY box in one small,
pure, fully-testable diff. DIAGNOSE-1 (baseline) and DIAGNOSE-2 (name the
high-leverage weakness) were already strong; this rounds out the diagnosis stage.

## Why this exists (the coaching-guardrail finding)

`CoachMemoryEngine.selectLever` (`Noum/PrimaryFocusMemory.swift`) is the single
diagnosis owner — it picks the current coaching lever from telemetry. Its
priority order was: strongest qualifying **trend** → first persistent **blocker**
→ stated **voice goal**. It never consulted the one thing the user said in their
own words at onboarding: `CoachingProfile.biggestChallenge` (`PracticeSupport.swift:494`).

Two failures fell out of that gap, both **silent**:

1. On a **thin baseline**, the engine could pick a lever the user never asked for
   and present it with no acknowledgement that it diverges from their stated goal.
2. **Above the evidence floor**, the measured lever could land on a different
   SkillArea than the user's stated challenge — and the engine simply carried the
   measured lever as the focus, with nothing telling the coach that the user had
   asked for something else.

A real £130/hr coach never silently overrules what the client said they want to
work on. When the reps point elsewhere, they **raise it as a question** ("you came
in wanting to work on X — your reps point more at Y; which should we anchor to?")
and let the client choose. That is the box this closes.

## What was built (3 files, no new files)

Pure depth on existing owners — **no new store, no new screen, no new routing, no
auto-flip**. One bounded decode-safe defaulted enum on the lever/`CoachMemory`, a
small pure mapping reusing an existing map, and one context line.

### 1. `Noum/PrimaryFocusMemory.swift`

- **`enum StatedChallengeConcordance: String, Codable, Equatable`** — bounded read
  with four cases: `.unknown` (no stated challenge / nothing to compare),
  `.deferred` (baseline below the floor — defer to the stated challenge, stay
  tentative), `.agree` (above floor, same area), `.divergent` (above floor,
  different area). Defaulted to `.unknown` for back-compat.
- **`LeverSelection`** (the private diagnosis struct): +`concordance` and
  +`statedChallengeArea`, both defaulted, so the struct's existing construction
  sites stay valid; `selectLever` fills them in before returning.
- **`selectLever` restructured** to resolve the measured lever exactly as before
  (telemetry → blocker → voice), then apply the concordance read **AFTER** as a
  read *on* the chosen lever. It never changes WHICH lever is selected — the
  honesty invariant. (`selectLever:1217`.)
- **`static func statedChallengeRead(measuredArea:profile:baseline:)`** — the pure
  reconciliation. Composes `SpeakingChallenge.recommendedPriority` →
  `ForwardPlanService.skillAreaForAIWeek(focus:)` (the **same canonical focus→skill
  map the AI forward plan already uses**, so diagnosis and plan never disagree
  about what a challenge "means" — single source of truth), then compares to the
  measured lever against the evidence floor `BaselineConfidence.isReliable`
  (`>= .moderate`, i.e. 5+ qualifying sessions — the codebase's existing
  "reliable enough to act on" bar). (`statedChallengeRead:1281`.)
- **`CoachMemory`**: +`statedChallengeConcordance: StatedChallengeConcordance` and
  +`statedChallengeArea: SkillArea?`. Wired through the memberwise init (both
  defaulted), the explicit assignment block, the `CodingKeys`, and the custom
  `init(from:)` with `decodeIfPresent ... ?? .unknown` — the identical back-compat
  pattern `hypothesisAcknowledgement` and the momentum fields use. The build call
  site threads `lever?.concordance ?? .unknown` and `lever?.statedChallengeArea`.

### 2. `Noum/ForwardPlanService.swift`

- **No code change.** The slice reuses the existing `nonisolated static func
  skillAreaForAIWeek(focus:)` (`565`) as the canonical map. Confirmed the
  deployment floor (iOS 17.0) satisfies the actor's `@available(iOS 17.0, *)` so
  the non-gated `CoachMemoryEngine` can reference the gated actor's static.

### 3. `Noum/CoachContextBuilder.swift`

- **One context line** emitted from `coachCaseFormulationLines(memory:)`, placed
  directly beside the existing `goalFit` reconciliation so both diagnosis reads
  live in the same CASE FORMULATION section that chat coach, blueprint, and debrief
  all consume (single source of truth). `.divergent` → one question naming both
  the stated area and the measured lever, ending "do not silently switch the focus
  they stated"; `.agree` → a brief affirmation, no question; `.deferred`/`.unknown`
  → silent. (`2360`.)
- **System-prompt rule 15** added to the intelligence floor, mirroring rules 5–14:
  tells the model that a "Stated-vs-measured" line reconciles what the user said
  with what the reps show, to raise a divergence as a question and never silently
  switch away from the stated focus, and that the measured read is evidence, not a
  mandate to override the user's stated goal.

## How each proven-contract clause is satisfied

- **RUBRIC (multi-dimensional, priority-ordered).** `selectLever` keeps its
  telemetry-first priority for *selection*; the concordance read is a separate
  dimension layered on top. On a divergence above the floor it sets
  `.divergent` and the coach surfaces a one-line QUESTION; below the floor it stays
  tentative (`.deferred`) and defers to the stated challenge.
- **GROUNDING GATE.** The divergence line only emits when there is a real stated
  challenge AND a real measured lever AND they map to *different* SkillAreas AND
  the baseline cleared the reliability floor. Below the floor, or with no stated
  challenge, the coach says nothing about concordance — no ungrounded divergence
  claim from thin data.
- **DETERMINISTIC FALLBACK.** The entire path is pure synchronous Swift — it works
  offline, in any locale, with no provider. The divergence/affirmation copy is
  deterministic; there is no LLM in this seam. (Rule 15 governs how the chat LLM
  *uses* the deterministic line; it does not generate it.)
- **LOCALE GATE.** Not applicable to the deterministic logic itself (no model
  call). The line is consumed by `CoachContextBuilder`, which already sits behind
  the chat coach's `LocaleSettingsManager` gate; if the line were ever
  LLM-phrased it would inherit that gate + grounding + fallback.
- **SCORE-SAFETY.** This biases SELECTION copy / context only. It never reads or
  writes the numeric score; `statedChallengeRead` takes the baseline read-only and
  returns an enum + an optional area.
- **SINGLE SOURCE OF TRUTH.** The stated→skill mapping reuses the forward plan's
  `skillAreaForAIWeek` rather than re-deriving a parallel map. The one concordance
  flag persisted on `CoachMemory` is the single value `CoachContextBuilder`
  consumes, so chat coach, blueprint, and debrief reference the same divergence
  read.
- **BOUNDED, DECODE-SAFE, DEFAULTED FIELDS.** `StatedChallengeConcordance` is a
  4-case bounded enum; both new `CoachMemory` fields are defaulted and decoded with
  `decodeIfPresent`, so a blob persisted before this slice decodes cleanly to
  `.unknown` / `nil`.

## Tests added (`NoumTests/NoumTests.swift`, `@Suite "StatedChallengeConcordanceTests"`)

Deterministic seams only — never live model output. Fixtures hand-traced against
the real `SpeakingChallenge.recommendedPriority`, the real `skillAreaForAIWeek`
map, the real `scoreTrend` weights, and the real `BaselineConfidence.from` bands.

- **Mapping chain** — `skillAreaForAIWeek(recommendedPriority)` for all four
  challenges (`fillerWords→Filler Words`, `rambling→Conciseness`,
  `freezing→Confidence`, `rushing→Pauses`).
- **Pure read** — no profile → `.unknown`; stated==measured above floor →
  `.agree`; thin baseline → `.deferred` (even when stated==measured); stated≠measured
  above floor → `.divergent` + stated area carried; the 5-qualifying boundary is
  above the floor (off-by-one guard).
- **`build()` wiring** — agree sets the flag without changing focus; divergent sets
  the flag and **leaves the stored `currentLever` as the measured lever**
  (no auto-flip — the HONESTY box); below-floor defers and keeps the measured focus.
- **Context emission** — a divergent memory yields **exactly one** "Stated-vs-measured"
  line naming both areas and the "do not silently switch" clause; an agree memory
  yields the affirmation and **no** question; a deferred memory yields **no**
  concordance line at all.
- **Decode-safety** — a hand-written legacy `CoachMemory` JSON blob *without* the
  two new keys decodes to `.unknown` / `nil`; a full encode→decode round-trip
  preserves `.divergent` + `.confidence`.

## Deviations

None. The slice was implemented exactly as scoped: extend the existing diagnosis
owner, reuse the existing focus→skill map, add one bounded decode-safe defaulted
field, emit one deterministic context line, no new files, no auto-flip.

## Honest limits (human-gated)

The divergence copy is deterministic and grounded, so its correctness is
statically verifiable. Whether the *phrasing* of the question lands as a real coach
would phrase it — and whether the chat LLM consistently honors rule 15 rather than
quietly steering to the measured lever — can only be judged by on-device QA with a
live model and, ultimately, by expert calibration. This host has no Swift toolchain
and no model keys, so `xcodebuild test` and felt-quality QA remain pending.
