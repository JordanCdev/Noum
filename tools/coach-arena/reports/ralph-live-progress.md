# RALPH live progress — 2026-07-08

Branch: `ux-overhaul` → work branch `ralph-app-path-evidence-0708` (worktree; draft PR).
Session constraint: **no `ANTHROPIC_API_KEY`** — live prompt-layer generation and the
live LLM judge are credential-blocked, so no live prompt-layer run or dual-arm A/B
was possible. All numbers below are from deterministic engines (node validate/test,
python app-path over a real Swift-pipeline dump, replay-mode regression) plus real
Xcode simulator test runs.

## Headline state (verified this session)

| Criterion | Target | Result | Pass |
|---|---|---|---|
| Prompt-layer gold mean | ≥70 | 67.6 (committed live run 2026-07-07) | ❌ ceiling |
| App-path score (real Swift dump, HEAD) | ≥70 | **73.84** | ✅ |
| App-path deepAssessment | ≥70 | 76.0 | ✅ |
| App-path trustRepair | ≥65 | 76.67 | ✅ |
| App-path groundedRead | ≥70 | 76.5 | ✅ |
| App-path quickMove | ≥70 | 68.76 | ❌ (type avg only) |
| Placeholder/fallback leaks | 0 | 0 (both real engines) | ✅ |
| node validate | 0 err | 51 fixtures · 0 err · 0 warn | ✅ |
| node arena unit tests | green | 58/58 | ✅ |
| **Full NoumTests unit suite (HEAD, sim)** | green | **3302 / 3302 pass · 0 fail** | ✅ |
| Real traces prove pipeline | complete | 50/50 complete traces (retrieval, provider fallback, gates, latency, confidence, proof-dedup) | ✅ |
| 10 end-to-end transcripts | yes | `ralph-transcripts-2026-07-08.md` | ✅ |

## What I actually found and did

### 1. The committed app-path report was STALE and hid a real HEAD regression
The pipeline (`CoachContextBuilder`, `AICoachChatService`, `CoachReliabilityGate`,
`CoachReasoningPass`, `CoachChatEvaluationFixtures`) was rewritten in **aefc7a5c
(2026-07-07 23:46)** — *after* the last app-path dump (2026-07-07 08:29). The
committed `reports/app-path/latest.json` therefore did not reflect HEAD. I
regenerated the dump from HEAD by running `CoachChatConversationArtifactDumpXCTest`
on the clean simulator (udid 546006D0…), then re-scored and re-committed the report.

**Note on the run command:** class-level `-only-testing:NoumTests/CoachChatConversationEvaluationTests`
matched **0 tests** (Swift-Testing suite id ≠ file name; the suite is
`@Suite("CoachChatConversationCorpusTests")`). Use the XCTest bridge
`NoumTests/CoachChatConversationArtifactDumpXCTest` (writes the dump reliably) and the
suite id `NoumTests/CoachChatConversationCorpusTests` for the gate tests.

### 2. The worst real failure at HEAD: two RED app-path tests (confidence collapse)
`scriptedConversationAppPathReportCoversFullCorpusWithoutClaimingReadiness` and
`scriptedLiveConversationAppPathReportProvesTwoSpeedLocalReadWithoutClaimingReadiness`
FAIL at HEAD. Root cause, traced deterministically:

- The app-path corpus is an **evidence-free substrate** — it seeds coach turns only
  (`seedCoachReplies`), never the source fixtures' practice sessions. The pipeline
  reads sessions from the process-global `PracticeSessionStore.shared`, which is empty
  for every conversation.
- `UserTrajectoryCache.evidenceCoverage([]) → 0.05` (empty-session cap), and
  `CoachReasoningPass.confidence` correctly applies the **deliberate**
  `coverage < 0.15 → 0.20` thin-evidence invariant (the one the handoff says MUST be
  kept). So every turn's `assessmentConfidence` is exactly **0.20** →
  `assessmentConfidenceDistinctRoundedCount == 1`.
- The tests assert `>= 3` distinct rounded values. On an evidence-free substrate that
  contradicts the invariant and pressures the harness to fabricate session variation
  "just to hit the count" (exactly what the handoff warns against).
- The BEFORE dump's 0.21/0.22 variation was fragile/incidental (3 distinct), not a
  meaningful signal; aefc7a5c's confidence-path change removed it.

Confidence **calibration** (that it rises with real coverage 0.05→0.76) is already
proven by `CoachJudgementLayerTests.assessmentConfidenceMovesWithEvidenceCoverage`, so
the app-path `>= 3` demand is both redundant and self-contradictory for this substrate.

### 3. Same root cause explains the 26/50 app-path floor failures
Turns whose scripted reply cites fixture evidence (e.g. "your last rep shows…") trip
the `floorConfidenceWithEvidence` reliability gate — because the reply claims evidence
while the evidence-free trajectory pins confidence to the floor. This is the reliability
gate working **correctly**; the failures are an artifact of the evidence-free harness,
not a pipeline bug. The corpus tests tolerate floor failures by design (conditional
branches; the suite is a "WithoutClaimingReadiness" measurement) — the BEFORE dump had
18–19 of them too — so they do NOT fail the tests. Only confidence-distinctness did.

### 4. Fix applied (this loop): principled option (b) — honest assertion, no fabrication
I chose the handoff's honest option (b) — "relax the assertion for an evidence-free
corpus" — implemented as a *strengthening*, not a loosening: assert the substrate's
true thin-evidence behavior. In both tests (`NoumTests/CoachChatConversationEvaluationTests.swift`):
- `assessmentConfidenceDistinctRoundedCount == 1` (was `>= 3`), plus every turn's
  confidence `<= 0.20` — pins the exact invariant floor value.
- expect the `flatAssessmentConfidence` readiness warning to be **present** (was
  asserted absent) — the report honestly flags flat confidence as one reason the
  substrate is not production-ready, consistent with the already-asserted
  `claim == .localEvaluationSubstrateOnly` / `!productionReady`.
- Comments cite the invariant + the calibration test. There is direct codebase
  precedent: `CoachLiveEvaluationTests.swift:437` asserts `distinctRoundedCount == 1`
  + expects the same warning on a thin-evidence live substrate.

Zero production-code change, zero eval-scoring (python judge) change — the report and
warning machinery are entirely test-side, and the python engine's
`productionEvidence: localEvaluationOnly` on flat confidence is left untouched because
it is the *honest* label for an evidence-free substrate.

### 5. Why NOT option (a) this session (recommended deeper follow-up)
Option (a) — seed each conversation's real source-fixture sessions so confidence varies
legitimately (and clears the `floorConfidenceWithEvidence` failures too) — is the
product-truth and the handoff's preferred fix. It also matches Jordan's stated intent
(chat gated behind an established baseline → real evidence exists at chat time). I did
NOT land it this session because it is unsafe/unverifiable under the constraints:
- The pipeline reads five process-global singletons (`PracticeSessionStore`,
  `CoachingProfileStore`, `BaselineStore`/`RatingStore`, `CoachMemoryStore`) with no
  test-injection API. Seeding them mutates shared state under Swift-Testing
  parallelism (the memory already records a shared-store race that forced serialization).
- A pipeline-level injection seam would re-run the semantic/reliability gates against a
  now-rich context for scripted replies authored for the evidence-free context → likely
  broad floor cascade, verifiable only via slow full rebuilds (no live iteration budget).

**Recommendation:** a future loop should implement (a) via a `#if DEBUG` seeding seam
on the stores (or a bundled evidence-override param on `CoachReplyPipeline.generate`,
default nil), seeding `sourceFixture(for:).sessions`, with `CoachChatConversationCorpusTests`
`.serialized`. That would legitimately vary confidence AND resolve most of the 26 floor
failures AND clear the `floorConfidenceWithEvidence` reliability issues — a much bigger,
honest win — but needs the rebuild budget to verify no gate regressions.

## Prompt-layer: at its measurement ceiling (17th confirmation)
The committed live prompt-layer mean is **67.6** (below 70). `aefc7a5c` was another
round of prompt-*wording* rules (anti-scaffold-label, sensitive-turn telemetry,
cold-start, goal-intent fast-lane) and moved 69.4→67.6 (down / within-noise) — the 17th
confirmation that wording does not cross the noisy 70 on this mature prompt. The residual
`tooLong` that dominates the worst-10 is a known Arena-vs-app artifact: the shipping
app's runtime `replyLengthLimits` gate repairs over-length replies before the user sees
them, so the Arena penalizes a draft the real app never ships. deepAssessment (78.6) and
trustRepair (70.5) pass; placeholder leaks 0.

**Blocked, honestly:** crossing a noisy prompt-layer 70 needs either (i) a stronger coach
model, (ii) a live dual-arm A/B of the one untried structural lever (CONTEXT-block
evidence surfacing to kill "decorative memory") — which needs an `ANTHROPIC_API_KEY` I
don't have this session — or (iii) the perception / longitudinal-outcome validation that
VISION explicitly reserves for real users. `CoachVisionProductionReadinessAuditTests`
deliberately caps this whole local substrate at 18/100 and refuses a production-ready
claim without live-provider sweep + professional-coach calibration + real-user
longitudinal outcomes + real-device TestFlight. That refusal is the product working as
designed, not a gap to hack.

## Exact remaining blockers
1. **Prompt-layer ≥70** — not achievable via wording (17 confirmations) and unmeasurable
   this session (no API key). Needs a live A/B of CONTEXT-block evidence surfacing, or a
   stronger coach model. NOT a bug.
2. **App-path quickMove type-avg 68.76** (< 70) — driven by evidence-free scripted quickMove
   turns flagged "missing evidence anchor"; resolves with option (a) seeding (real evidence
   → replies can anchor). Aggregate app-path score (73.84) already passes.
3. **App-path `productionEvidence` = localEvaluationOnly** — honest for an evidence-free
   substrate; flips to `realPipelineEvidence` once option (a) makes confidence vary.
4. **"VISION standard genuinely met"** — gated BY DESIGN on real-user longitudinal
   validation (18/100 audit cap); cannot be produced in a headless session and must not be
   faked.

## Regression check on the aefc7a5c pipeline rewrite
`aefc7a5c` ("chngs") rewrote `AICoachChatService` (+586), `CoachContextBuilder` (+77),
`CoachReliabilityGate`, `CoachReasoningPass`, and `CoachChatEvaluationFixtures` but its
effect was never verified against the full suite. I ran the **entire `NoumTests` unit
target** on the clean simulator: **3302 / 3302 pass, 0 fail**. So beyond the two
confidence-distinctness assertions fixed here, the pipeline rewrite introduced no
unit-test regressions. (The 3 historically-flaky UI failures live in `NoumUITests`,
excluded from this unit-only run.)

## Deliverables this loop
- `reports/app-path/latest.{md,json}` + `failures.md` — regenerated from the HEAD dump.
- `reports/ralph-transcripts-2026-07-08.md` — 10 end-to-end transcripts with full real traces.
- `NoumTests/CoachChatConversationEvaluationTests.swift` — 2 tests fixed (principled b).
- This log.
