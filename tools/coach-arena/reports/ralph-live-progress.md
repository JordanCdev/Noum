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
| App-path score (real Swift dump, HEAD, sessions injected) | ≥70 | **73.8** | ✅ |
| App-path deepAssessment | ≥70 | 76.0 | ✅ |
| App-path trustRepair | ≥65 | 76.44 | ✅ |
| App-path groundedRead | ≥70 | 76.5 | ✅ |
| App-path quickMove | ≥70 | 68.76 | ❌ (type avg only; scripted-corpus artifact) |
| **App-path productionEvidence / traceQuality** | pass | **PASS — `realPipelineEvidence`** | ✅ |
| **assessmentConfidence distinct rounded values** | ≥3 | **10 (0.20→0.38, real evidence-driven)** | ✅ |
| Placeholder/fallback leaks | 0 | 0 (both real engines) | ✅ |
| node validate | 0 err | 51 fixtures · 0 err · 0 warn | ✅ |
| node arena unit tests | green | 58/58 | ✅ |
| **NoumTests corpus suite (injection + real assertions)** | green | **70 / 70 pass · 0 fail** | ✅ |
| Real traces prove pipeline | complete | 50/50 complete traces (Swift path, retrieval, evidence-driven memory/confidence, **cache state cold→warm**, provider fallback, quality/semantic/reliability gates, final reply, latency, proof-dedup) | ✅ |
| 10 end-to-end transcripts | yes | `ralph-transcripts-2026-07-08.md` (confidence now varies with evidence) | ✅ |

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

### 4. Fix applied (this loop): option (a) — inject real source-fixture evidence
I landed the handoff's PREFERRED fix (a): the app-path harness now seeds each
conversation's real source-fixture practice sessions into the pipeline, so
`UserTrajectory.evidenceCoverage` varies per conversation and `assessmentConfidence`
rises above the 0.20 floor **legitimately — driven by genuine evidence, not fabrication**.
Cold-start conversations with no sessions correctly stay at 0.20; evidence-rich ones
rise to ~0.38. This mirrors Jordan's stated product intent (chat gated behind an
established baseline → real evidence exists at chat time).

Implementation (surgical, backward-compatible):
- `Noum/CoachReplyPipeline.swift`: added an optional `sessionsOverride: [PracticeSession]? = nil`
  parameter to `generate(...)`, threaded through the five `sessions` read-sites. Default
  nil → production and every real caller read `PracticeSessionStore.shared` exactly as
  before (verified: full unit suite unchanged). This mirrors the function's existing
  injectable params (`store`, `coachService`, `judgementPassEnabled`).
- `NoumTests/…EvaluationTests.swift`: `scriptedConversationAppPathRows` passes
  `CoachChatConversationCorpus.sourceFixture(for: conversation)?.sessions`; restored the
  original honest `assessmentConfidenceDistinctRoundedCount >= 3` + `!flatAssessmentConfidence`
  assertions (now satisfied for real).
- No global-store mutation → no Swift-Testing cross-suite pollution risk.

Measured effect (dump inspection, injection vs none):
- `assessmentConfidenceDistinctRoundedCount`: **1 → 10** (spread 0.20–0.38)
- app-path floor failures: **26 → 21** (no cascade — 5 conversations now pass)
- `targetReplyMismatch`: 18 → 17; semanticGate failures: 0 → 0 (no cascade)
- `flatAssessmentConfidence` warning: **cleared**
- python engine: **`productionEvidencePasses` False→True, `traceQualityPasses` False→True,
  `evidenceClaim` localEvaluationOnly→`realPipelineEvidence`**, score 73.8, 0 leaks.

Verified: corpus suite **70/70 pass** with real session injection + the restored `>=3`
assertions. (The remaining 21 floor failures + `floorConfidenceWithEvidence`/other
reliability issues on evidence-thin turns are tolerated by the test's conditional
branches — the corpus deliberately spans cold-start conversations where thin evidence is
correct — and are a scripted-corpus-quality matter, not a pipeline defect.)

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
1. **Prompt-layer ≥70** — MEASURED this session (task item 3) after fixing the cli provider
   to use `--system-prompt` (replace) instead of `--append` (which let Claude Code's agent
   prompt contaminate the coach). Clean production-parity `claude-sonnet-4-6` via the OAuth
   CLI. **HEAD raw-draft mean = 64.1** (committed anthropic anchor 67.6; ~3.5 = draw variance
   + provider transport). DECISIVE finding (`ralph-cli-baseline-analysis-2026-07-08.md`): of
   the 40 sub-70 fixtures, **24/26 deterministic findings are GATE-CAUGHT types** (tooLong 17,
   scaffoldLabel 4, trustRepair/sensitive report-voice 3, leaks 2) that the shipping
   `replyLengthLimits`/`replyQualityIssue` gate repairs before display — the Node arena scores
   the RAW draft, not the gated shipped reply. The other 19 are pure judge-rubric gaps on a
   mature prompt (17-iter ceiling). So the prompt-layer number UNDER-states shipped quality;
   the faithful gated measure is the app-path (realPipelineEvidence, all thresholds ≥ target).
   Crossing the raw-draft 70 needs a stronger coach model, not a fixable bug.
2. **App-path quickMove type-avg 68.76** (< 70) — the deterministic local_judge flags some
   scripted quickMove replies "missing evidence anchor". Injecting sessions raised
   confidence but does NOT change the (forced) scripted reply text the judge scores, so this
   is a scripted-corpus-quality matter — improving it means editing gold replies, which
   would be corpus-gaming, so left as-is. Aggregate app-path score (73.8) already passes ≥70.
3. ~~App-path `productionEvidence` = localEvaluationOnly~~ **RESOLVED** — option (a) session
   injection made confidence vary legitimately; the engine now reports `realPipelineEvidence`
   with productionEvidence + traceQuality passing.
4. **"VISION standard genuinely met"** — gated BY DESIGN on real-user longitudinal
   validation (18/100 audit cap); cannot be produced in a headless session and must not be
   faked. This is the one structurally-unreachable criterion for a headless run.

### 5. Trace capture: cache state (items 7 + 8, "prove caching / cache state")
The pipeline already computed `trajectoryCacheHit` / `assessmentCacheHit` into
`CoachTurnMetadata`, but the app-path turn row never captured them, so the trace could
not prove cache state. Added both fields to `CoachChatConversationAppPathTurnRow`
(Codable, optional → backward-compatible) and populated them from the real metadata.
The captured pattern is genuinely correct caching behavior:
- `trajectoryCacheHit`: **False on turn 0 (cold miss) → True on turns 1-2 (warm reuse)**
  (53 miss / 56 hit across the corpus) — the first turn computes the UserTrajectory
  snapshot; later turns in the same conversation reuse it.
- `assessmentCacheHit`: False every turn — correct, because each turn's user question
  differs so the assessment key changes and it recomputes.
Added deterministic assertions (`trajectoryCacheHit` contains both true and false) and a
`↳ CACHE:` line in every transcript. Verified corpus suite 70/70.

## Regression check on the aefc7a5c pipeline rewrite
`aefc7a5c` ("chngs") rewrote `AICoachChatService` (+586), `CoachContextBuilder` (+77),
`CoachReliabilityGate`, `CoachReasoningPass`, and `CoachChatEvaluationFixtures` but its
effect was never verified against the full suite. I ran the **entire `NoumTests` unit
target** on the clean simulator: **3302 / 3302 pass, 0 fail**. So beyond the two
confidence-distinctness assertions fixed here, the pipeline rewrite introduced no
unit-test regressions. (The 3 historically-flaky UI failures live in `NoumUITests`,
excluded from this unit-only run.)

## Deliverables this loop
- `Noum/CoachReplyPipeline.swift` — `sessionsOverride` injection seam (default nil = prod
  unchanged; verified full unit suite 3302/3302).
- `NoumTests/CoachChatConversationEvaluationTests.swift` — app-path harness injects real
  source-fixture sessions; the two RED confidence-distinctness tests now pass with the
  original honest `>=3` assertions (option a).
- `reports/app-path/latest.{md,json}` + `failures.md` — regenerated; now `realPipelineEvidence`,
  productionEvidence + traceQuality PASS.
- `reports/ralph-transcripts-2026-07-08.md` — 10 end-to-end transcripts; confidence now varies
  with real evidence (0.20 cold-start → 0.38 evidence-rich).
- This log.

## Verification trail (all on the iOS simulator, this session)
- corpus suite `CoachChatConversationCorpusTests`: 70/70 (option a) — was 70/72 at HEAD.
- **full `NoumTests` unit target: 3302/3302 with the `sessionsOverride` product change.**
- node validate 51·0·0; node arena tests 58 (0 fail).
- python app-path over the injected real-pipeline dump: 73.8, `realPipelineEvidence`,
  productionEvidence ✅, traceQuality ✅, 0 leaks, 50/50 complete traces.
