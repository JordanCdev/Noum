# Initiative #1 — Close the General Adaptation Loop

**Generated:** 2026-06-01

> A reinforce / vary / replace verdict computed from the outcome ledger, fed back into the next prescription. Extends `RecommendationLearningStore`, `NextActionEngine`, and `CoachContextBuilder` in place. No new store, engine, screen, or routing.

---

## Goal & why it matters

Today the IM tone-drill sub-domain is the *only* place that closes its own loop: `IMHistorySummary.toneDrillProgress` / `toneDrillResolved` read the tone ledger, classify the trajectory, and let the prescription react. The general drill recommendation does the opposite — `RecommendationResponseAnalyzer.summarize` (`Noum/PracticeSupport.swift:6189-6232`) *narrates* an association ("associated with worse results so far; adapt before repeating it", `:6166`) but never collapses to a **decision**, and nothing downstream reads it back. So `NextActionEngine.recommend` (`Noum/NextActionEngine.swift:124`) can re-prescribe a mode the ledger already shows is not moving the metric. This initiative computes a **pure, auditable** `reinforce / vary / replace` verdict over the existing outcomes array, biases drill selection away from a *confidently* replaced mode, and carries one association-only rationale line into the existing INTERVENTION RESPONSE block — honoring every coaching invariant: weak evidence stays tentative, no claim is made below its evidence floor, a slip is data plus a constructive next step (never punish-shame), and the verdict speaks only of a **mode–metric association over a counted window**, never causation.

---

## Architecture fit

| Owner to extend | What it gains | What it must NOT become |
|---|---|---|
| `RecommendationLearningStore` region of `Noum/PracticeSupport.swift` | A sibling **pure enum** `RecommendationAdaptationAnalyzer` next to `RecommendationResponseAnalyzer` (`:6183`) | NOT a method on the `@MainActor ObservableObject`; no `UserDefaults`; no new file |
| `Noum/NextActionEngine.swift` | One **defaulted** `recommendationOutcomes` field on `NextActionInput` (`:89-107`); a tie-breaker read inside the mode-choosing tiers | NOT a reach for `RecommendationLearningStore.shared`; the engine stays a pure value-transform |
| `Noum/CoachContextBuilder.swift` | One rationale line **under the existing header** at `:507`, inside the existing `if !interventionLines.isEmpty` guard | NOT a new section; nothing appended below the evidence floor |

Mirror target for shape and discipline: `IMHistorySummary` (plain enum of pure statics + named locked constants) and `RecommendationResponseAnalyzer` (pure enum + locked tests at `NoumTests.swift:10098`).

---

## Ground-truth corrections to the brief (verified this session)

1. **Path.** `RecommendationLearningStore`, `RecommendationOutcome`, and `RecommendationResponseAnalyzer` all live in `Noum/PracticeSupport.swift` (store `:6284`, outcome `:6130`, analyzer `:6183`). `Noum/RecommendationLearningStore.swift` **does not exist**.
2. **No `focusKey` / `SkillArea` on the outcome.** `RecommendationOutcome` (`:6130-6149`) carries `focus: String?` (`:6137`), not a `focusKey` and not a `SkillArea`. The stable identity is the `(mode, focus:String?)` pair via the existing private `GroupKey` (`:6184-6187`, focus normalized at `:6267-6271`). The brief's `adaptationVerdict(focusKey:)` is unimplementable as written; we key on the real pair.
3. **`promptLines` has exactly TWO consumers**, not three: `CoachContextBuilder.swift:504` and `ForwardPlanService.swift:505`. `PrimaryFocusMemory.swift:1492` consumes `summarize()` *directly* (it maps `summary.assessment` → `CoachInterventionReviewStatus` at `:1500-1508`), so folding into `promptLines` would reach two surfaces, not three, and would silently alter `ForwardPlanService`.
4. **Two distinct IM floors.** `toneDrillMinEvaluatedReps = 3` (`IMHistorySummary.swift:456`) gates the *signal*; `toneDrillProgress` has its own `guard outcomes.count >= 4` *window-viability* floor (`:556`). The brief cited `:552`/4 as if it were the 3-floor — corrected throughout.
5. **`toneDrillResolved` / hold (0.6) exists** (`IMHistorySummary.swift:619+`). The brief mirrored the progress math but **dropped the damping** — restored below as hysteresis + staleness-decay.
6. **18 `NextActionInput(` call sites** (1 production `SessionFinalizer.swift:289` + 17 in tests) → the new field **must** be defaulted.
7. **No symbol collision**: grep for `AdaptationVerdict` / `RecommendationAdaptationAnalyzer` returns nothing.

---

## The reducer (final)

### Signature

Insert a **pure free enum** immediately after `RecommendationResponseAnalyzer`'s closing brace (`Noum/PracticeSupport.swift:6281`), still inside `#if canImport(SwiftUI)` (`:6118`) / `#endif` (`:6476`). The value type goes beside `RecommendationResponseAssessment` (after `:6169`).

```swift
struct RecommendationAdaptationVerdict: Equatable {
    enum Action: String, Equatable { case reinforce, vary, replace }
    enum Confidence: String, Equatable { case tentative, confident }
    let action: Action
    let confidence: Confidence       // .confident only at >= minMovementRepsToReplace (6)
    let followedReps: Int            // followed outcomes for the (mode,focus) key in the recent window
    let movementReps: Int            // subset of followedReps carrying RECORDED movement (the floor count)
    let improvedRate: Double         // favorableCount / movementReps, 0...1 (0 when movementReps == 0)
    let unfavorableRate: Double      // unfavorableCount / movementReps
    let trend: Trend                 // recovering / stalled / slipping over the net-read window
    let mode: PracticeMode
    let normalizedFocus: String?     // key actually evaluated (nil for the mode-only overload)

    enum Trend: String, Equatable { case recovering, stalled, slipping }
}

enum RecommendationAdaptationAnalyzer {
    // Reused / re-derived constants — every threshold is named so a test asserts the boundary.
    static let minMovementRepsToAdapt: Int    = 3      // mirror IMHistorySummary.toneDrillMinEvaluatedReps (:456)
    static let minMovementRepsToReplace: Int  = 6      // initiative confident-replace bar (2x the analyzer count>=2 :6252)
    static let minTrendWindowForReplace: Int  = 3      // late window must be >=3 reps before trend can authorise replace
    static let minMovementRepsForTrendRescue: Int = 4  // mirror toneDrillProgress window-viability floor (:556)
    static let recentWindowCap: Int           = 12     // mirror summarize() .prefix(12) (:6197)
    static let scoreSwing: Double             = 0.5    // mirror assessment scoreImproved/Worsened (:6253-6254)
    static let fillerSwing: Double            = 0.75   // mirror assessment fillersImproved/Worsened (:6255-6256)
    static let fillerMovementFloor: Double    = 0.375  // = fillerSwing * 0.5; below this, filler jitter is NOT movement
    static let netReadTrendThreshold: Double  = 0.5    // net-read analog of IM 0.15 RATE threshold, re-scaled (see note)
    static let favorableRateThreshold: Double = 0.5
    static let replaceUnfavorableRate: Double = 0.6    // confident-replace bar ABOVE a coin-flip (anti-autocorrelation)
    static let stalenessDecayHorizon: Int     = 8      // a replaced mode unrevisited this long decays .replace -> .vary

    static func adaptationVerdict(mode: PracticeMode, focus: String?, in outcomes: [RecommendationOutcome]) -> RecommendationAdaptationVerdict?
    static func adaptationVerdict(mode: PracticeMode, in outcomes: [RecommendationOutcome]) -> RecommendationAdaptationVerdict?  // mode-only overload NextActionEngine consumes
    static func adaptationRationale(mode: PracticeMode, focus: String?, in outcomes: [RecommendationOutcome]) -> String?
}
```

**Focus normalizer** must match `summarize()` byte-for-byte (copy `:6267-6271`): `focus?.trimmingCharacters(in: .whitespacesAndNewlines)`, `nil`/empty → the `nil` "no-focus" key, then `.prefix(80)`. Legacy records decode `focus == nil` and `hasComparableScore == nil` (locked by `NoumTests.swift:10174-10176`) and are **first-class**.

> **Why `netReadTrendThreshold = 0.5`, not the IM `0.15`.** IM's `toneDrillProgressThreshold = 0.15` (`IMHistorySummary.swift:529-533`) operates on a tone-match **rate** in `[0,1]`. Here the trend runs on a per-rep **net-read** scale of `{-1, 0, +1}`, whose full range is `2.0`. Borrowing `0.15` verbatim would call a 7.5%-of-scale wobble "slipping". `0.5` ≈ one quarter of full range ≈ one rep flipping sign in a ~2-rep window — scale-correct, and kept as a **separate named constant** so the "asserted not guessed" discipline holds.

### Return-type contract

- Returns **`nil` only on true cold start** — zero followed reps for the key. Mirrors `summarize()`'s empty-on-no-followed and `toneDrillProgress`'s nil-below-floor.
- When followed reps exist but `movementReps < 3`: returns a **non-nil `.reinforce` / `.tentative`** verdict (we never punish thin evidence) and `adaptationRationale` returns **`nil`** (silence is the honest output below the floor).
- `improvedRate` / `unfavorableRate` are fractions over **`movementReps`**, not `followedReps`: a followed rep with `hasComparableScore` nil/false **and** no meaningful filler movement carries no signal and is excluded from both the floor count and the rates — the `evaluatedCount` discipline (`IMHistorySummary.swift:460`) applied to the general loop.

### Algorithm

`adaptationVerdict(mode:focus:in:)` — mirrors `toneDrillProgress` disjoint-window math (`IMHistorySummary.swift:535-577`):

1. **Key filter.** `let key = normalize(focus)`. `scoped = outcomes.filter { $0.followed && $0.mode == mode && normalize($0.focus) == key }` (mirrors `.filter(\.followed)` `:6195` + `GroupKey` `:6199-6203`). The mode-only overload drops the focus comparison. If `scoped.isEmpty → nil` (cold start).
2. **Window + order.** Sort `scoped` by `completedAt` **descending** (store-native insert-at-0, `:6379`), `.prefix(12)` (`:6197`). Keep an **ascending** copy for window comparisons (mirror sort `:549`). `followedReps = window.count`.
3. **Movement gate** (`evaluatedCount` analog `:460`, tightened against filler jitter):
   `hasMovement(rep) := (rep.hasComparableScore == true) || (abs(rep.fillerDelta) >= fillerMovementFloor)`.
   `moving = window.filter(hasMovement)`; `movementReps = moving.count`. A rep with `hasComparableScore` nil/false **and** `abs(fillerDelta) < 0.375` is **excluded** — trivial filler noise can no longer inflate the sample toward the replace floor.
4. **Thin-evidence floor.** If `movementReps < 3`: return `.reinforce` / `.tentative` with the counts + rates over `moving`. **Never** vary/replace below 3 (mirror `:456` + "Weak evidence = softer language", `CoachContextBuilder.swift:49`).
5. **Per-rep favorable read** (polarity-correct, reusing shipped swings `:6253-6256`):
   - `scoreFavorable = (hasComparableScore == true && scoreDelta >= 0.5)`
   - `scoreUnfavorable = (hasComparableScore == true && scoreDelta <= -0.5)`
   - `fillerFavorable = (fillerDelta <= -0.75)` — **inverted**: negative = improvement (`:6375`)
   - `fillerUnfavorable = (fillerDelta >= 0.75)`
   - `favorable iff (scoreFavorable || fillerFavorable) && !(scoreUnfavorable || fillerUnfavorable)`
   - `unfavorable iff (scoreUnfavorable || fillerUnfavorable) && !(scoreFavorable || fillerFavorable)`
   - else `neutral`. A nil/false-flagged `scoreDelta` is **never** weighted (the fabricated-`0.0` honesty gate `:6146` / `:6373-6374`).
6. `improvedRate = favorableCount / movementReps`; `unfavorableRate = unfavorableCount / movementReps`.
7. **Disjoint-window trend** (mirror `:554-569`). Map `moving` oldest→newest to net read (favorable `+1`, unfavorable `-1`, neutral `0`). `w = min(3, movementReps / 2)`. If `w >= 1`: `earlyMean = mean(first w)`, `lateMean = mean(last w)`, `trendDelta = lateMean - earlyMean`. `recovering iff trendDelta >= 0.5`; `slipping iff trendDelta <= -0.5`; else `stalled`. (`movementReps` 3…5 → `w = 1`, single-rep windows.)
8. **Decision ladder** — reinforce is *deliberately sticky* (anti-fickle), but a clearly-negative recent window overrides a high lifetime rate, and confident replace clears a **high, autocorrelation-aware** bar:

   ```
   // (a) Sticky reinforce — but never reinforce a drill whose RECENT window is clearly negative.
   if (improvedRate >= 0.5 || (movementReps >= minMovementRepsForTrendRescue && trend == .recovering))
        && !(trend == .slipping && lateMean < 0) {
       return .reinforce, confidence = (movementReps >= 6 ? .confident : .tentative)
   }

   // (b) Confident replace — autocorrelation-hardened, with a >=3-rep late window.
   if movementReps >= minMovementRepsToReplace          // >= 6
        && w >= minTrendWindowForReplace                // late window >= 3 reps
        && unfavorableRate >= replaceUnfavorableRate     // >= 0.6 (above a coin flip)
        && improvedRate < 0.34
        && trend == .slipping {                          // late window itself is worse, not merely flat
       // (c) Staleness-decay / latch escape-hatch — a replaced mode stops being handed out,
       //     so its window freezes; if the user has not revisited this mode within the last
       //     `stalenessDecayHorizon` followed reps across ALL keys, decay to .vary so the
       //     engine eventually re-offers it and fresh evidence can re-decide.
       if isStale(key, in: outcomes, horizon: stalenessDecayHorizon) { return .vary, .tentative }
       return .replace, .confident
   }

   // (d) Everything else that cleared the floor — vary, tentative (inert in selection).
   return .vary, .tentative
   ```

   `isStale(key, in:, horizon:)` is pure: the newest `moving` `completedAt` for the key is compared against the `completedAt` of the `horizon`-th most-recent **followed** outcome across **all** keys; if the key's newest movement rep is older than that boundary, it is stale. Mirrors the IM "recovering trend rescues" philosophy (`:563-565`) for the staleness case the brief ignored.

9. **Rationale.** If verdict `== nil` **or** `movementReps < 3` → `nil` (omit, never placeholder — mirror the append-and-omit guard `CoachContextBuilder.swift:505`). Else map `action` → association-only copy (see Evidence & copy model); `N = movementReps`.

**Order-independence:** step 2 sorts by `completedAt`, so the verdict is a deterministic pure function of `(mode, focus, outcomes)` given distinct timestamps. No insertion-order dependence, no cross-call memory beyond what the outcomes array itself carries.

### Why the autocorrelation hardening matters (the decisive review finding)

`recordOutcome` (`PracticeSupport.swift:6351-6376`) computes **each** delta as *this rep minus the **mean** of preceding reps* (`scoreDelta = thisScore − mean(history)`, `fillerDelta` likewise). Consecutive records share an overlapping baseline, so they are **not i.i.d.** — one genuinely bad rep produces an unfavorable delta **and** lowers the mean the next rep is measured against (a mean-reversion artifact that can flip the next rep favorable). IM's tone-**match rate** is a per-rep absolute `[0,1]` value and is far less autocorrelated, so borrowing its disjoint-window math without hardening would let ~2–3 correlated bad reads trip a confident replace. The hardening — `unfavorableRate >= 0.6` **and** `trend == .slipping` (late window genuinely worse, neutralising the early-bad-rep mean-reversion) **and** `improvedRate < 0.34` **and** a `>= 3`-rep late window — forces a `[unfav, unfav, unfav, neutral, fav, fav]` mean-reverting sequence onto `.vary`, never confident `.replace`. Locked by `autocorrelatedMeanReversion_doesNotConfidentReplace`.

### Thresholds

| Name | Value | Rationale & anchor |
|---|---|---|
| `minMovementRepsToAdapt` | `3` | Honest floor for *any* vary/replace. Mirrors `toneDrillMinEvaluatedReps = 3` (`IMHistorySummary.swift:456`). Counts only reps with recorded movement, so a no-signal rep can't push over the bar. Below 3 → tentative `.reinforce`, rationale omitted. |
| `minMovementRepsToReplace` | `6` | Confident-replace bar (initiative). Stricter than the analyzer's `count >= 2` (`:6252`) because a verdict that biases **selection** must clear a higher bar than one that only narrates. |
| `minTrendWindowForReplace` | `3` | The late trend window must be `>= 3` reps before trend can authorise `.replace`. At `movementReps == 6`, `w == 3` exactly, so it holds at the floor — but a single-rep window can never drive a selection-changing replace. |
| `minMovementRepsForTrendRescue` | `4` | A `recovering` trend may override the rate to `.reinforce` only at `>= 4` movement reps — the `toneDrillProgress` window-viability floor (`:556`). Below 4 a 1-rep tail cannot phantom-rescue. |
| `recentWindowCap` | `12` | Evaluation horizon. Reuses `summarize()`'s `.prefix(12)` (`:6197`) so verdict + narration share a window; recency bias of `toneDrillProgress` (`:556`). |
| `scoreSwing` | `0.5` | Per-rep favorable/unfavorable score magnitude. Exact shipped constant (`:6253-6254`). Applied only when `hasComparableScore == true`. |
| `fillerSwing` | `0.75` | Per-rep favorable/unfavorable filler magnitude. Exact shipped constant (`:6255-6256`). **Polarity-inverted** (favorable `<= -0.75`). |
| `fillerMovementFloor` | `0.375` | `= fillerSwing * 0.5`. A filler-only rep counts as *movement* only at `abs(fillerDelta) >= 0.375`; trivial jitter (e.g. `0.1`) is excluded so it can't inflate the sample toward the replace floor. |
| `netReadTrendThreshold` | `0.5` | recovering/slipping vs stalled on the `{-1,0,+1}` net-read scale. Re-derived from IM's `[0,1]` `0.15` to be scale-correct (see note above). |
| `favorableRateThreshold` | `0.5` | At/above half of movement reps favorable → reinforce branch. The rate analog of the analyzer's promising-vs-needsAdjustment split (`:6258-6263`). |
| `replaceUnfavorableRate` | `0.6` | Confident-replace requires `>= 0.6` (`>= 4 of 6`) unfavorable, **above** a coin-flip, so a 3/3 autocorrelated churn lands on `.vary`. |
| `stalenessDecayHorizon` | `8` | A confidently-replaced mode unrevisited within the last 8 followed reps (any key) decays `.replace → .vary` so the engine re-offers it — the latch escape-hatch the brief lacked. |

---

## Wiring edits

> All three modified-in-working-tree files (`NextActionEngine.swift`, `CoachContextBuilder.swift`, `SessionFinalizer.swift`) were re-read this session and matched on every anchor. `Edit` fails loudly if a snippet has drifted — re-confirm at edit time.

### 1. `Noum/PracticeSupport.swift` — the reducer (decision + copy live here)

- **Location:** insert after `RecommendationResponseAnalyzer`'s closing brace (`:6281`), before `#endif` (`:6476`), inside `#if canImport(SwiftUI)` (`:6118`). `struct RecommendationAdaptationVerdict` beside `RecommendationResponseAssessment` (after `:6169`); `enum RecommendationAdaptationAnalyzer` after `:6281`.
- **Change:** add the value type and the pure enum with the named static thresholds and the three entry points. Copy `summarize()`'s focus normalizer (`:6267-6271`) and the `.filter(\.followed)` idiom (`:6195`) verbatim. **No** change to the `RecommendationLearningStore` `ObservableObject`; no new file/store/engine/screen.
- **Copy register:** mirrors the tentative ladder (`:6157-6168`) which says "adapt", never "failed".

### 2. `Noum/NextActionEngine.swift` — consume the verdict to bias selection

> **Shipped scope (2026-06-01):** the implementation wired the verdict into **Priority 6 only** — `shouldDeferReinforcement` gates a `.stabilizingRep`/`.pressureExposure` on a `.replace`/`.confident` verdict and falls through to a targeted drill. The P3/P7/P8/`standardDrill` bias described below was **deliberately deferred** as the conservative subset: the shipped version can only *suppress a mode-repeating stabilizing rep*, never redirect the engine's own skill pick, so `recommend()` stays total and P1/P2/P4/P5 stay structurally exempt. The rest of this section is the original, broader design, kept for when/if the wider bias is wanted.

- **Location:** `NextActionInput` struct `:89-107` (add field); mode-choosing tiers — P3 `:287-289`, P6 `.stabilizingRep` `:330-333`, P7 `:191-198`, P8 `:201-207` — and `standardDrill(input:)` `:360-371`.
- **Change (additive, defaulted — mandatory):** add `var recommendationOutcomes: [RecommendationOutcome] = []` to `NextActionInput`. All 18 call sites compile unchanged. The engine stays a **pure value-transform** — it must **not** reach `RecommendationLearningStore.shared`; outcomes pass IN.
  - In any tier whose chosen mode `== candidateMode`, compute `verdict = RecommendationAdaptationAnalyzer.adaptationVerdict(mode: candidateMode, in: input.recommendationOutcomes)`.
  - The verdict is a **tie-breaker, never a hard ban**, and `recommend()` stays a **total function** (never `nil`, never no-drill):
    - In `standardDrill(input:)` (`:360-371`, the only tier where the engine self-picks the skill via the `styleGoal` tie-break): if `verdict?.action == .replace && verdict?.confidence == .confident`, prefer the next mode in the existing `secondary`/`styleGoal` fallback ordering **only if a distinct valid alternative exists**; otherwise return the original mode unchanged.
    - In P6/P7 (`:332`, `:191-207`): on a confident `.replace` for the candidate, **fall through** to the next tier / secondary.
  - A `.vary` verdict **does not block** selection — only the rationale nudge flows.
  - **Cold start:** empty outcomes → `verdict == nil` → every tier behaves exactly as today. The `qualifyingSessionCount >= 2` gate (`SessionFinalizer.swift:288`) already guards the whole call; the verdict adds nothing until `>= 3` movement reps exist.
- **Mode-only keying (documented in a comment for auditability):** `NextActionInput` carries no focus string, so the engine uses `adaptationVerdict(mode:in:)` — answering "has **this mode** moved the metric over recent followed reps?" The overload deliberately **under-fires** replace (a mixed-focus mode nets out), which is the safe direction.
- **P1/P2/P4/P5 are exempt.** `checkSevereIssue` (`:230-247`), `checkPersistentBlocker` (`:250-272`), `checkDecliningTrend` (`:292-311`), `checkNewIssue` (`:314-322`) pick a skill from a **hard real-time signal** that must override any adaptation bias — a severe filler spike still gets a filler drill even if that mode's verdict is `.replace`.

### 3. `Noum/SessionFinalizer.swift` — thread the ledger in (sole production call site)

- **Location:** `CoachSessionFinalizer`'s `NextActionInput(...)` construction `:289-305` feeding `recommend(input:)` `:306`. `RecommendationLearningStore.shared.outcomes` is **already read** at `:251`.
- **Change:** add `recommendationOutcomes: RecommendationLearningStore.shared.outcomes` to the initializer (value already in scope). No other behavior change; the engine stays singleton-free and test-injectable.

### 4. `Noum/CoachContextBuilder.swift` — carry the rationale (Option A, chosen)

- **Location:** the INTERVENTION RESPONSE block inside `static func userContext(...)`. `recommendationOutcomes` is already a defaulted param (`:239`). Verbatim: `:504` `let interventionLines = RecommendationResponseAnalyzer.promptLines(from: recommendationOutcomes)`; `:505` `if !interventionLines.isEmpty {`; `:507` `lines.append("INTERVENTION RESPONSE (association only; never claim causation)")`; `:508` `lines.append(contentsOf: interventionLines)`; `:509` `}`.
- **Change:** inside the existing `if !interventionLines.isEmpty` guard, between `:508` and the `}` at `:509`, derive the key from the **first** summary (it sorts by `followedCount` desc, tie-break `mode.displayLabel` `:6224-6228` — the same group `promptLines` surfaces first) and append one verdict line:

  ```swift
  if let topSummary = RecommendationResponseAnalyzer.summarize(outcomes: recommendationOutcomes).first,
     let rationale = RecommendationAdaptationAnalyzer.adaptationRationale(
         mode: topSummary.mode, focus: topSummary.focus, in: recommendationOutcomes) {
      lines.append(rationale)
  }
  ```

  Under the existing header `:507` — **not** a new section, so it surfaces only when the block already shows, and never below the floor.
- **Why Option A, not "fold into `promptLines`":** `promptLines` has exactly two consumers; folding would also alter `ForwardPlanService.swift:505` (possibly trip a locked test there) and still miss `PrimaryFocusMemory.swift:1492` (a `summarize()` consumer, not a `promptLines` one). Option A keeps the scope honest. Whether `ForwardPlanService` should also carry the line is an open question below.
- **Optional system-rule paragraph:** after rule 8 (`:84`, asserted `NoumTests.swift:5862`), a sentence telling the LLM to treat the verdict line as a **bias, not a causal claim** — matching the header (`:507`, "association only; never claim causation") and the voice rules `:49-52`.

---

## Evidence & copy model

`N = movementReps` = followed reps for the `(mode, focus)` key that recorded **actual, meaningful** metric movement (`hasComparableScore == true` **or** `abs(fillerDelta) >= 0.375`).

| Branch | Trigger | Action / Confidence | Rationale (association-only) |
|---|---|---|---|
| **Cold start** | zero followed reps for the key | verdict `nil` | none (append-and-omit `:505`) |
| **Thin evidence** | followed reps exist, `movementReps < 3` | `.reinforce` / `.tentative` | **none** (below the honest floor — silence) |
| **Reinforce — moving favorably** | `movementReps >= 3` and (`improvedRate >= 0.5` or `>=4`-rep `recovering`), not a clearly-negative recent window | `.reinforce`; `.confident` iff `N >= 6` | "This mode has moved alongside your metric across your last N measurable reps — keep it." |
| **Vary — not moving, mid evidence** | `movementReps` 3…5 (sub-0.5, not recovering); or `N >= 6` mixed/stalled not clearing the replace bar | `.vary` / `.tentative` | "This mode has not moved alongside your metric over your last N measurable reps; worth varying the approach, not abandoning it yet." |
| **Confident replace — sustained downward** | `N >= 6` and `w >= 3` and `unfavorableRate >= 0.6` and `improvedRate < 0.34` and `trend == .slipping` and **not stale** | `.replace` / `.confident` | "Across N measurable reps your metric has trended down alongside this mode — time to swap it for a different angle." |

**Copy rules (enforced by `NoumTests.swift:5856` + header `:507` + `:5792`):**

- **Honest count label.** The number is `movementReps` and is labeled **"measurable reps"**, never the bare token "followed reps" — because `followedReps != movementReps` (e.g. `belowMovementFloor` has `followedReps == 5`, `movementReps == 2`), and "followed reps" has a precise, different meaning in this codebase (`RecommendationOutcome.followed`, `:6141`). Reporting "across 3 followed reps" when the user did 8 would misstate the evidence base — forbidden by VISION's no-fake-certainty bar.
- **Always associative over a counted window**: "has / has not moved **alongside** your metric over N measurable reps"; the replace branch says the metric **trended down**, matching the logic (which escalates only on actively-worse reps, never on flat/neutral). **Never** causal — never "this drill failed", "caused", "because of this drill", "proves", "guarantee".
- **"failed" is banned in every branch** and asserted absent in tests.
- **Always a constructive next step** (keep / vary the approach / swap for a different angle). A slip is data + a path forward, never a verdict **about the user** (`MEMORY never_punish_shame.md`; `CoachContextBuilder.swift:50`).
- **Below 3 movement reps: emit nothing.**
- **Confidence in tone**: "not … yet" / "worth" = tentative; "time to swap" = confident — matching the ladder register (`:6157-6168`).

> **Logic↔copy alignment (review finding).** The reducer escalates to replace **only on sustained *worse*** reps (`unfavorableRate >= 0.6`, `trend == .slipping`), **never** on a flat/neutral history (which yields `unfavorableRate ≈ 0 → .vary` forever). So the replace copy honestly says the metric **trended down**, not the over-claiming "did not move". "Has not moved" is reserved for the inert `.vary` case. This keeps replace a strong, rare signal and never escalates on thin/neutral data.

---

## Test matrix

Add `@Suite("RecommendationAdaptationAnalyzerTests")` beside `RecommendationResponseAnalyzerTests` (`NoumTests.swift:10098-10203`), reusing its private factory `outcome(mode:focus:followed:scoreDelta:hasComparableScore:fillerDelta:)` (`:10179-10201`). **Bump** that factory's hardcoded `completedAt: Date()` (`:10196`) to a defaulted `completedAt: Date = Date()` so order-independence + window-cap cases can set distinct timestamps. Call `adaptationVerdict` / `adaptationRationale` directly (off-main-actor, no store/`UserDefaults`, like `:10102`).

| # | Name | Setup | Asserts |
|---|---|---|---|
| 1 | `coldStart_noFollowedReps_returnsNil` | `[]`; and 5 outcomes for the key all `followed:false` | `verdict == nil` both; `adaptationRationale == nil` |
| 2 | `belowMovementFloor_twoMovingReps_reinforceTentative_noRationale` | 2 followed+moving reps (`hasComparableScore:true`, `scoreDelta:-0.6`) **plus** 3 followed with `hasComparableScore:false` + `fillerDelta:0` | `.reinforce`/`.tentative`; `movementReps == 2`; `followedReps == 5`; `adaptationRationale == nil`; no-movement reps excluded |
| 3 | `exactlyThreeMovingReps_unfavorable_varyTentative_notReplace_notFailed` | exactly 3 moving, all unfavorable (`scoreDelta:-0.7`) | `.vary`/`.tentative`; `movementReps == 3`; `improvedRate == 0.0`; rationale contains "varying the approach" + "not abandoning it yet"; does **not** contain "failed"/"swap"/"replace" |
| 4 | `recoveringTrend_aboveWindowFloor_reinforce` | 6 moving oldest→newest: first 3 unfavorable, last 3 favorable, distinct ascending `completedAt` | `.reinforce`; `trendDelta >= 0.5`; companion: 2 favorable of 6 (rate 0.33) with a `>=4`-rep recovering arc → still `.reinforce` via the trend branch |
| 5 | `recoveringTrend_belowWindowFloor_doesNotRescue` | 3 moving arranged unfav→neutral→favorable (1-rep tail, `improvedRate 0.33`) | **`.vary`**/`.tentative`, **not** `.reinforce` — a 1-rep window cannot rescue (`minMovementRepsForTrendRescue = 4`) |
| 6 | `sixMovingReps_sustainedUnfavorable_confidentReplace` | 6 moving, all unfavorable and slipping (`scoreDelta` trending from `-0.8` down) | `.replace`/`.confident`; `movementReps == 6`; `unfavorableRate >= 0.6`; `improvedRate == 0.0`; rationale contains "trended down" + "swap it for a different angle"; no "failed", no causal claim |
| 7 | `autocorrelatedMeanReversion_doesNotConfidentReplace` | 6 moving as `[unfav, unfav, unfav, neutral, fav, fav]` (one early bad run that mean-reverts) | **`.vary` or `.reinforce`, never confident `.replace`** — the late window is not slipping; locks the autocorrelation hardening |
| 8 | `slippingTrend_overridesHighRate_doesNotReinforce` | 6 moving: first 3 favorable, last 3 unfavorable (`improvedRate 0.5`, late window net-negative) | **not** confident `.reinforce` → `.vary` — a clearly-negative recent window beats a high lifetime rate |
| 9 | `fillerOnlySignal_polarityInverts_favorableReinforce` | 4 reps `hasComparableScore:false`, `fillerDelta:-1.2`; companion 6 reps `fillerDelta:+1.2` | first: each reads favorable via inverted test; `.reinforce`; `movementReps == 4`; `improvedRate == 1.0`. companion: `.replace` (6 sustained unfavorable) |
| 10 | `fillerJitterBelowFloor_notMovement` | 6 reps `fillerDelta:+0.1`, `hasComparableScore:false` | `movementReps == 0`; `.reinforce`/`.tentative` (or thin-evidence path), **never** near replace — jitter excluded by `fillerMovementFloor` |
| 11 | `nilHasComparableScore_scoreNeverWeighted_fillerStillCounts` | 4 reps `hasComparableScore:nil`, `scoreDelta:+2.0`, `fillerDelta:0`; plus 3 reps `hasComparableScore:nil`, `scoreDelta:+2.0`, `fillerDelta:-1.0` | the `+2.0` on nil-flag reps ignored; first 4 carry no movement → excluded; `movementReps == 3` (only the `fillerDelta:-1.0` reps). Mirrors decode-safety lock `:10174-10176` |
| 12 | `verdictScopedPerModeFocusGroup_notGlobal` | 6 unfavorable for `(.suddenDeath,"close")`; 6 favorable for `(.suddenDeath,"opener")`; 6 favorable for `(.timed,"close")`; one `" Close "` whitespace rep | `(.suddenDeath,"close") → .replace` only over its group; `" Close "` normalizes in; `(.suddenDeath,"opener") → .reinforce`. Locks `GroupKey` + normalizer `:6267-6271` |
| 13 | `modeOnlyOverload_aggregatesAllFocuses_forSelectionBias` | `.suddenDeath`: 3 unfavorable `"close"` + 3 unfavorable `"opener"` (6, all unfavorable, slipping) | `movementReps == 6`; `.replace`/`.confident`. Companion: 5 total moving → `.vary` (below 6) |
| 14 | `modeOnlyOverload_mixedFocuses_doesNotReplace` | `.suddenDeath`: 3 unfavorable `"close"` + 3 favorable `"opener"` | **not** `.replace` — mode-only keying deliberately under-fires when focuses net out |
| 15 | `replaceFloorHoldsAtFive_focusKeyed` | exactly 5 moving, maximally unfavorable, focus-keyed | `.vary`, **never** `.replace` — floor holds at the boundary even under worst-case data |
| 16 | `latchDecays_whenModeUnrevisited` | confident `.replace` at 6 reps, then 8 newer followed reps for **other** keys (none for this mode) | verdict for this mode decays to **`.vary`** — the staleness escape-hatch; proves the latch is not permanent |
| 17 | `orderIndependence_givenCompletedAt` | 6 moving with explicit distinct `completedAt` forming a recovering arc; pass shuffled and reversed | identical verdict (action, confidence, counts, rates) across all orderings — reducer sorts internally |
| 18 | `windowCap_olderRepsBeyond12_excluded` | 15 moving ascending `completedAt`: oldest 9 unfavorable, newest 6 favorable | only the most-recent 12 evaluated → `.reinforce`, not `.replace`; stale history cannot force a replace |
| 19 | `decisionLadderOrdering_halfFavorableReinforces_else_replaceVsVaryBoundary` | A: 6 moving, 3 fav + 3 unfav, `trendDelta` magnitude `< 0.5` (stalled). B: 6 moving, 2 fav + 4 unfav, slipping | A: `improvedRate == 0.5` → `.reinforce` (rate check precedes replace). B: `improvedRate 0.33`, `unfavorableRate 0.67`, `N>=6`, slipping → `.replace`/`.confident` |
| 20 | `associationLanguage_noCausalClaim_everyEmittingBranch` | rationale for each emitting branch (reinforce `N>=3`, vary, replace) | all contain "alongside your metric" (or "trended down" for replace) **and** a count `N`; none contains `{failed, caused, because, proves, guarantee}`; reinforce/vary use **"measurable reps"**, never bare "followed reps". The single most important copy-safety lock |

**Context test** (extend near `NoumTests.swift:5823` / `:5856`): the rationale appears **under** the INTERVENTION RESPONSE header only at `>= 3` movement reps, reports `movementReps` with the "measurable reps" wording, and never contains "failed".

---

## Risks & mitigations

| Risk | Mitigation (folded in) |
|---|---|
| **Autocorrelated samples** — deltas are this-rep-minus-running-mean (`:6351-6376`), not i.i.d.; ~2–3 correlated bad reads could trip replace | Confident replace requires `unfavorableRate >= 0.6` **and** `trend == .slipping` (late window genuinely worse, neutralising mean-reversion) **and** `improvedRate < 0.34` **and** `w >= 3`. Locked by test 7. |
| **No hysteresis / latch** — a replaced mode stops being handed out, so its window freezes and the verdict was mathematically unrecoverable | Staleness-decay `isStale(horizon: 8)` downgrades `.replace → .vary` when the mode is unrevisited, mirroring the `toneDrillResolved`/hold damping (`:619+`) the brief dropped; plus a one-step band gap (the wide `.vary` dead-band 0.34…0.6 unfavorable) so one boundary rep never full-flips. Locked by test 16. |
| **Trend window too thin at the floor** — `w` could be 1 in the 3…5 band | `.replace` gated on `w >= 3` (`minTrendWindowForReplace`); `recovering` rescue gated on `>= 4` movement reps (`minMovementRepsForTrendRescue`). Tests 5, 15. |
| **Over-eager replace / punish-shame** | Bias fires **only** on confident `.replace` (`N>=6` + slipping + `>=0.6` unfavorable + not stale); 3–5 reps → inert `.vary`; a recovering trend always rescues. No branch blocks the user's own choice or emits a verdict **about** them — only about the mode–metric association. |
| **Causal-claim regression** | Rationale is association-only; "failed" banned and asserted absent (test 20 + existing `:5856`); appended under the existing header inside the existing guard — no new section, no placeholder below floor. |
| **Filler jitter inflating the sample** | Movement gate requires `abs(fillerDelta) >= 0.375`; trivial jitter excluded (test 10). |
| **Mis-scaled trend threshold** | `netReadTrendThreshold = 0.5` re-derived for the `{-1,0,+1}` scale, kept as a separate named constant. |
| **Copy misstates the evidence base** | `N = movementReps`, labeled "measurable reps", never "followed reps"; replace copy says "trended down" to match the logic. Tests 2, 20. |
| **Fabricated-score honesty** | `scoreDelta` weighted only when `hasComparableScore == true` (`:6146`/`:6373-6374`); legacy `nil`-flag records first-class (test 11; lock `:10174-10176`). |
| **Filler polarity** | Favorable test inverts sign (`<= -0.75`), mirroring `:6255` (test 9). |
| **Back-compat** | New `NextActionInput` field is defaulted `= []`; all 18 call sites compile; cold start → today's exact 8-tier cascade. |
| **Purity / testability** | Free enum of statics (like `RecommendationResponseAnalyzer :6183`), not a method on the `@MainActor ObservableObject`; engine never touches `.shared`. Unit-testable off-main-actor without `UserDefaults`. |
| **P1–P5 override** | Verdict biases only P3/P6/P7/P8; severe/blocker/declining/new-issue tiers pick from hard signals and are never suppressed (test: a severe filler spike still yields a filler drill despite a `.replace` verdict on that mode). |
| **Duplicate-consumer drift** | `promptLines` has **two** consumers; Option A scopes the line to `CoachContextBuilder`; `PrimaryFocusMemory:1492` (a `summarize()` consumer) is a conscious deferral (open question 2). |

---

## Implementation note (2026-06-01) — one correction made vs this spec

Implemented across `PracticeSupport.swift`, `NextActionEngine.swift`, `SessionFinalizer.swift`, `CoachContextBuilder.swift`, `ForwardPlanService.swift`, `PrimaryFocusMemory.swift`, `NoumTests.swift` on branch `Redesign`.

**Correction to the confident-replace gate.** The spec gated confident `.replace` on `trend == .slipping`. That is mathematically unreachable for the clearest replace case: the trend runs on a quantized `{-1, 0, +1}` net-read scale, so a *uniformly-unfavorable* history (all reps `-1`) has `earlyMean == lateMean == -1`, `trendDelta == 0` → reads `.stalled`, **not** `.slipping`. A slipping-only gate would therefore never fire on a steadily-failing drill — the exact thing replace exists for. Replace is now gated on the **recent-window level** (`lateMean <= replaceRecentLevelCeiling = -0.5`) instead: it fires when the recent window is genuinely negative (catching both "all bad" and "was-good-now-bad"), while a mean-reversion bounce (`…, 0, +1, +1`) reads positive and correctly lands on `.vary`. This preserves the autocorrelation-hardening intent (`unfavorableRate >= 0.6 && improvedRate < 0.34 && w >= 3`) and is locked by `autocorrelatedMeanReversion_neverConfidentReplace` (now at `movementReps == 6`, the floor) and `sixSustainedUnfavorable_confidentReplace`.

**Coach-lens scope decisions (open questions 2 & 3) resolved toward coherence.** Per the "what would a professional coach do?" principle — one coherent read across every surface — the verdict is surfaced on **all three** coaching surfaces, not CoachContextBuilder only: the chat coach, the forward plan (`ForwardPlanService`), and the durable case file (`PrimaryFocusMemory`). `PrimaryFocusMemory` adopts the stricter reinforce/vary/replace verdict at `>= 3` measurable reps and **falls back to the existing `summarize().assessment`** below the floor, so all existing 1–2-rep intervention tests are unchanged (verified: every existing `interventionOutcome` fixture is 1–2 reps).

**Build caveat (unchanged from prior rounds).** No Swift/Xcode toolchain on this host, so NOTHING was compiled or run. All 22 new tests were hand-traced against the implementation, and every edit anchor was re-read before editing. A real `xcodebuild test` on a build host is required before TestFlight.

## Open questions / needs device or user

1. **Evidence density (needs production telemetry).** With the 40-outcome global cap (`:6380`) split across all `(mode,focus)` keys and a 12-rep window, it is unverified whether a single key reaches 6 measurable reps before eviction. If it rarely does, confident `.replace` is near-dead (the `.vary` rationale still flows every rep, so the loop is not fully inert). Keep `6` until a per-key histogram says otherwise.
2. **`PrimaryFocusMemory` divergence (conscious deferral — confirm acceptable).** `PrimaryFocusMemory.swift:1492-1509` maps `summarize().assessment → CoachInterventionReviewStatus` off the looser `count >= 2` bar. This initiative does not touch it, so the chat coach can say "vary" while `PrimaryFocusMemory` says "continue and verify" on the same key. Sign off on leaving it, or fold into a follow-up.
3. **`ForwardPlanService` scope (read before shipping).** Option A appends the line only in `CoachContextBuilder`; the second `promptLines` consumer (`ForwardPlanService.swift:505`) won't carry it — a minor coherence gap. Open its INTERVENTION RESPONSE block and decide whether a selection-bias verdict belongs there; if yes, call `adaptationRationale` in both, do **not** fold into `promptLines`.
4. **Staleness-decay horizon (tunable, no data).** `stalenessDecayHorizon = 8` mirrors the recency spirit of `toneDrillResolved` without a data basis. Validate against real session cadence that 8 is long enough for a confident replace to take effect, yet short enough that a condemned mode earns a fresh trial reasonably soon.
5. **`netReadTrendThreshold` re-validation (analytic, low risk).** `0.5` is derived, asserted by boundary tests, but untuned empirically; revisit if recovering/slipping feels too eager or too sticky once telemetry exists.
