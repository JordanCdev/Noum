# Initiative #10 — Positional BLUF verdict ("lead vs buried lede" made actually positional)

Generated: 2026-06-01 · Branch `Redesign` · Status: **built, pending `xcodebuild test`**

## Why this exists (the substance-gap + honesty-mismatch finding)

Initiative #8 gave Noum its first real substance read — a shared
`PracticeEvaluator.PromptRelevanceRead` ("did you answer the question") consumed
by the deterministic Relevance rating and threaded into all four coaching
surfaces. But the shared **verdict** that those surfaces key off
(`promptAnswerVerdict`) was **overlap-MAGNITUDE only**: `.buried` fired when the
answer echoed *few* of the question's content words (`overlap < weak`),
regardless of WHERE the point landed.

That created a standing honesty mismatch, sharpest in the post-rep deterministic
fallback and the chat coach: four user-facing surfaces asserted *positional*
"lead vs arrived late" reasoning the engine never performed.

- `AICoachService.deterministicFeedback` `.buried` copy claimed *"The answer was
  in there, but it arrived late"* — but `.buried` fired on a **0%-overlap
  off-topic** rep, where the point never arrived at all. The copy was a lie.
- `CoachContextBuilder` told the chat coach *"the point may be buried"* for the
  same off-topic case.
- The AICoachService system-prompt rubric line (priority 1) instructed the model
  to judge *"where the main point landed — lead (in the first sentence) or
  buried (arrived late)"* — positional language the deterministic verdict that
  feeds the same prompt's PROMPT RELEVANCE context could not back.

"Lead with your point" is the single highest-leverage **substance** thing a coach
checks, and the maps flagged it as the top substance gap. This slice makes the
one shared reducer genuinely positional, so the upgrade lands on the Relevance
read, the live chat coach, the post-rep note, and the Coach Read in one bounded
diff — and the four surfaces' positional copy becomes **true** rather than
asserted.

Boxes ticked: **SUBSTANCE-2** (lead with the point vs buried lede — positional
BLUF/structure); **EXERCISE-4** (concision / "get to the point" / BLUF — the
verdict the BLUF drill keys off is now real); **HONESTY-2** reinforcement
(removes the copy-claimed positional reasoning the engine never did).

## What was built (4 files, +13 tests)

Pure depth on the established single source of truth — **zero new files**, no new
store/screen/engine/routing. One new bounded field, one new pure helper, one
new pure positional dimension folded into the existing verdict mapping.

1. **`Noum/PracticeSupport.swift`** — the single-source change:
   - `PromptRelevanceRead` gains a bounded, **defaulted** field
     `firstSentenceOverlap: Double = 0` (back-compat: an explicit memberwise
     init defaults it, so the below-floor construction site is unchanged; the
     rating never reads it, so a `0` default can never move a score). Always `0`
     below the evidence floor — no positional claim on thin evidence.
   - `relevanceFirstSentence(in:)` — a pure helper that splits the transcript on
     `.`/`!`/`?` and returns the leading span, the **identical** first-sentence
     rule `AICoachService.openerAnchor` uses to pick the quote it shows the user
     (that helper is `private` to another type and cannot be reused cross-type;
     this mirrors the split exactly rather than duplicating it ad-hoc). The
     verdict's notion of "the lead" is the same span the coach copy anchors to.
   - `promptRelevance(...)` now computes `firstSentenceOverlap` over the SAME
     distinct prompt content-word set as the whole-transcript `overlap` (shared
     denominator → `firstSentenceOverlap <= overlap` always holds, since the
     lead is a subset of the whole), reusing `relevanceContentWords`. The numeric
     score path is untouched; the magnitude `overlap`/`progress` is untouched.
   - `promptAnswerVerdict(for:)` re-mapped to be **positional** (still the one
     entry point, still nil below the floor):
     - `.answered` — the point LED (`firstSentenceOverlap >= relevanceStrongOverlap`).
       Because `firstSentenceOverlap <= overlap`, an `.answered` rep also clears
       the strong whole-overlap bar, so the verdict can never say "answered"
       while the rating says weak.
     - `.buried` — the point is present across the rep
       (`overlap >= relevanceStrongOverlap`) but absent from the lead
       (`firstSentenceOverlap < relevanceWeakOverlap`). The "arrived late" claim
       is **true by construction** here: it requires the point to actually be
       present somewhere first.
     - `.partial` — everything else, which now absorbs BOTH the genuinely
       in-between case AND the low-whole-overlap "barely engaged it" off-topic
       case. Neither earns the confident positional `.buried` claim.
   - The deterministic fallback copy re-keyed: `.answered` affirms leading with
     the point; `.partial` says *"The question's key terms didn't clearly lead
     your answer. Make your main point the first sentence…"* (honest for both the
     loose-engagement and off-topic sub-cases — no "arrived late" claim, no claim
     of contact the rep may not have made); `.buried` keeps the now-true "arrived
     late / lead with your point" line.
2. **`Noum/CoachContextBuilder.swift`** — the `PROMPT RELEVANCE` chat-context
   section made positional: the data line now reports **both** the first-sentence
   overlap and the whole-rep overlap (so the coach can cite the gap that defines
   a buried lede), and the per-verdict phrases speak position ("the point led" /
   "the point arrived late — present across the rep but missing from the lead" /
   "the point did not clearly lead"). System-prompt **rule 14** rewritten to
   describe the positional read. The association disclaimer ("never proof the
   answer was off-topic") is preserved on the buried + partial guidance.
3. **`Noum/FeedbackEngine.swift`** — `buildPromptRelevanceNote` (Layer 2b) still
   fires ONLY on `.buried`, now a genuine buried lede, so its copy is honest by
   construction: *"Your main point was in there but arrived late — leading with
   it in the first sentence keeps the answer anchored to the question."* An
   off-topic low-overlap rep is now `.partial` and fires no note (no "arrived
   late" implied about an answer whose point is nowhere in the rep).
4. **`NoumTests/NoumTests.swift`** — `PromptRelevanceFollowOnTests` migrated to
   the positional reality + new boundary coverage (see below).

The AICoachService system-prompt rubric line (priority 1) needed **no change** —
it already used positional language ("lead (in the first sentence) or buried
(arrived late)"); it is now truthfully backed by the deterministic verdict that
feeds the same prompt's PROMPT RELEVANCE context. That is the honesty mismatch
this slice closes from the engine side.

## Invariants honored (the proven contract)

- **Rubric:** content-word overlap of the question against the FIRST
  sentence/clause vs the whole transcript; `.buried` requires HIGH whole-overlap
  AND LOW first-sentence overlap; `.answered` requires the point in the lead;
  `.partial` otherwise. Reuses `relevanceContentWords` + the `openerAnchor`
  first-sentence split — not duplicated.
- **Grounding / score-safety:** the `evidenceFloorMet` gate and the `0.45`
  progress clamp are untouched, so weak evidence never asserts a confident
  off-topic; the verdict still feeds the RATING never the deterministic score
  (`firstSentenceOverlap` is read only by the verdict — score path verified
  separate at `PracticeSupport.swift` content-progress).
- **Single source of truth:** `promptAnswerVerdict` stays the one entry point;
  `CoachContextBuilder` PROMPT RELEVANCE, `FeedbackEngine.buildPromptRelevanceNote`,
  the `AICoachService.deterministicFeedback` fallback, and the AICoachService
  rubric line all consume the now-positional verdict and can never disagree.
- **Fallback / locale:** pure logic, runs identically offline / non-English (no
  provider needed); the copy that once asserted "arrived late" is now TRUE.
- **Bounded / decode-safe / defaulted:** the new field is a single `Double`
  defaulted to `0`; the struct is constructed in only two reducer sites (both
  updated) and decoded nowhere; synthesized `Equatable` is inert (the read is
  compared by `==` nowhere).
- **Coach-lens + brand:** one coherent positional read across every surface;
  patient-but-decisive copy in the restrained voice; all three deterministic
  strings pass `fieldPassesBrandVoice` (no "!", no chirpy filler, <320 chars).

## Tests (the deterministic seams)

`PromptRelevanceFollowOnTests` fixtures migrated from magnitude-only to
positional, and new boundary tests added — every fixture hand-traced against the
REAL stop set + `>=4`-char filter + tokenizer + first-sentence split + the named
constants (`relevanceStrongOverlap=0.30`, `relevanceWeakOverlap=0.12`):

- **Front-vs-buried boundary (the slice's lock):**
  `verdictAnsweredWhenLeadCarriesPointEvenWithFewExactWords` — a rep that LEADS
  with the answer using few exact question words but clears the strong lead bar
  → `.answered`, NOT `.buried`. `verdictPartialWhenLedSubstanceButLowWholeOverlap`
  — leads with substance but whole overlap is also low → `.partial` (proves
  `.buried` needs BOTH high whole AND a missing lead).
  `verdictBuriedWhenPointPresentButNotInLead` — whole 1.0, lead 0.0 → `.buried`.
- **Off-topic reclassification (the honesty fix):**
  `verdictOffTopicLowWholeOverlapIsPartialNotBuried` and
  `deterministicOffTopicLowOverlapDoesNotClaimArrivedLate` — a 0%-overlap rep is
  `.partial` and its deterministic copy must NOT say "arrived late".
- **Asymmetry lock:** `verdictPartialWhenPresentButLeadBetweenWeakAndStrong` —
  high whole overlap, lead between weak and strong (0.20) → `.partial`, proving
  `.buried` needs the lead `< weak`, not merely `< strong`.
- **Evidence floor → nil:** `verdictNilBelowEvidenceFloor` (nil prompt / thin
  transcript / sub-3-content-word prompt) — no positional claim on thin data.
- **0.45 clamp still holds:** `promptRelevanceOffTopicLongAnswerLowOverlapRatesDownNotConfidentMiss`
  (pre-existing, unchanged) — off-topic still rates `.ok` (progress 0.45), never
  a confident off-topic.
- **Surfaces never disagree:** `oneReadDrivesBothSurfaces` — the SAME positional
  read produces `.buried`, fires the Timed note, and yields the buried
  chat-context guidance. `contextSurfacesPositionalOverlapNumbersForTimedRep`
  pins the new "first sentence 0% / whole answer 100%" data line.
- **Deterministic fallback parity:**
  `deterministicVerdictAnsweredLeadsToAnsweredKeyImprovement` (now also asserts
  "led with the point") and `deterministicVerdictBuriedLeadsToLeadWithPointKeyImprovement`
  (transcript replaced with a genuine buried lede so the `.buried`→"arrived late"
  path stays exercised and honest).

## Verification (this run)

No Swift/Xcode toolchain on the build host, so verification is static analysis +
hand-tracing. Every test fixture's `(whole, lead) → verdict` was computed by a
standalone model that mirrors the Swift tokenizer, stop set, `>=4`-char filter,
first-sentence split, and the named thresholds **exactly** — all 12 fixtures map
as asserted (no off-by-one). The deterministic copy strings were checked against
`fieldPassesBrandVoice` and the `keyImprovement` substring assertions. Cross-file
"cannot find type" SourceKit noise (no module index) is expected and not a
compile error.

**Gate (yours):** `xcodebuild build-for-testing` + `xcodebuild test
-only-testing:NoumTests/PromptRelevanceFollowOnTests` on a Mac, then the full
suite as the pre-TestFlight gate. Felt LLM response quality (the chat coach + AI
Coach Read now reading the positional section) can only be judged by on-device QA
with real keys — the deterministic seams above are what this run locks.
