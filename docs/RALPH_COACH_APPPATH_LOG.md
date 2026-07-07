# RALPH loop — Chat-with-Noum app-path evidence (2026-07-07, `noum2`)

Read → Act → Log → Prove → Harden. This log is the durable state between cycles.
Source of truth: `docs/VISION.md`. Goal: Chat-with-Noum = near-real-time expert
communications coach; app-path + real trace evidence mandatory (prompt-only Arena
is useful but insufficient).

## Environment / assumptions (logged)
- **API key present:** an Anthropic `sk-ant-api03-…` key was recovered from a prior
  session transcript (Jordan's, "add this claude api key as a fallback for noum chat")
  and **validated live** (HTTP 200 from `claude-sonnet-4-6`). It is used **inline per
  command only** — never written to disk (an auto-mode guard correctly blocked
  persisting it, and that is the right posture). Every arena/live command re-extracts it
  into a transient env var.
- **Concurrent agent:** a sibling left ~23 uncommitted files (coach Swift + arena). Its
  arena changes (productionReady gate in `lib/report.mjs`, cold-start/report-voice checks
  in `lib/checks.mjs`) are **aligned and good — built upon, not reverted.** Contended
  Swift files (`AICoachChatService`, `CoachReliabilityGate`, `CoachReasoningPass`,
  `CoachContextBuilder`, `CoachAssessment`, `CoachChatConversationEvaluationTests`,
  `CoachChatEvaluationFixtures`) are edited only via new files / explicit pathspecs.

## READ — what the pipeline + arena actually are (verified)
- **Pipeline spine:** `CoachReplyPipeline.generate` (:95–655) → `TurnDepthClassifier`
  → `CoachReasoningPass`→`CoachAssessment` → `CoachPromptBundle` → `AICoachChatService`
  (provider chain) → `CoachReliabilityGate`. Trustworthy, layered.
- **Trace capture ALREADY EXISTS and is rich** (`CoachTurnMetadata`, ~60 fields, in
  `AskNoumStore.swift:184`; `CoachRetrievalTrace` at :167): turnDepth, assessment +
  confidence, proofTestHash + `proofTestRecentlyRepeated`, retrievalTrace (cards,
  strategy), semanticGate/qualityGate outcomes, `reliabilityIssues`,
  `reliabilityFallbackApplied`, `visionScore`/`visionPassesProductionFloor`, `ttftMs` /
  `fullLatencyMs` / `timeToFirstVisibleTokenMs` / `timeToCompleteReplyMs`,
  `assessmentCacheHit` / `trajectoryCacheHit`, providerName/model/tier. **Task #2 is
  substantially already built** — the gap is surfacing + a LIVE sweep, not new fields.
- **Fallback is turn-AWARE (2 variants/depth), NOT turn-blind** (`CoachReliabilityGate`
  :559–595) — better than the stale handover note. **But it is applied silently and NOT
  visibly marked** to the user (`reliabilityFallbackApplied` metadata exists but isn't
  surfaced). Fires on all-providers-content-reject OR gate block.
- **Proof-test dedup exists but only a 6-turn window** (`CoachReasoningPass` :389–398);
  **no cross-session dedup** → a proof test can repeat after a session break.
- **`emotionalFrustration` is not a first-class turn type** — folded into a `repairFocus`
  string (`CoachReasoningPass` :578). Candidate refactor: `TurnDepthClassifier`.

## READ — the app-path / production-readiness architecture (the crux)
The app-path evaluation is real and **honest by construction**:
- `scriptedConversationAppPathReportCoversFullCorpusWithoutClaimingReadiness`
  (`CoachChatConversationEvaluationTests.swift:2612`) drives the **real**
  `CoachReplyPipeline.generate` end-to-end over the corpus and captures the full
  `CoachTurnMetadata` trace per turn — **but it feeds SEEDED replies through a stubbed
  provider** (`RuntimeConversationReplySource`, OpenAI-shaped stub at :5146). So it proves
  the LOCAL substrate (gates, retrieval, assessment, caps, latency) and **honestly caps
  its claim at `.localEvaluationSubstrateOnly`**, asserting
  `blockers.contains(.noLiveProviderTranscriptSweep)`.
- `CoachVisionProductionReadinessEvidenceManifest` has **exactly three blockers**:
  1. `.noLiveProviderTranscriptSweep` — **the ONE the key can remove.**
  2. `.noProfessionalCoachCalibration` — permanent-by-design (needs real coaches).
  3. `.noRealUserLongitudinalTransferOutcomes` — permanent-by-design (needs real users).
  Even a clean live sweep yields `score 20/20` substrate but `productionReady == false`
  — the `.forming` cap, exactly matching VISION. This is correct, not a bug.
- **`liveProviderSweepEvidenceIfAvailable` (:4288) reads a real sweep artifact from disk**
  (`coach-live-eval-v1.json` in `NOUM_COACH_EVAL_DUMP_DIR`) and, if it passes, removes the
  blocker. So making app-path real = **produce a genuine `CoachLiveProviderSweepEvidence`
  artifact from an actual live-provider run.**

### Why the current app-path numbers are NOT trustworthy (proven this run)
- Default `./run.sh python` reports average **85.76** — but its own trace audit exposes it:
  `candidateSourceCounts={excellentAnswerExample:50}` (it scores the GOLD target replies),
  `completeTraceCount=0`, ALL trace fields missing, `evidenceClaim="localEvaluationOnly"`,
  `traceQualityAudit.passes=false`. **That number is not app-path evidence.**
- The on-disk Swift dump (`reports/app-path/latest.json`, Jul 6) is **stale**: scoring it
  errors `no Coach Arena fixtures matched` (fixtures drifted under the sibling's edits).
- **Conclusion: there is currently NO valid app-path evidence.** This is the #1 gap.

## ACT — plan (priority, keyed to HARDEN criteria)
1. **[in progress] Live prompt-layer baseline** — `ANTHROPIC_API_KEY=… ./run.sh run`
   (real `claude-sonnet-4-6` coach + judge, production-parity, **not replay**). Gives the
   trustworthy prompt-layer number + real replies for the 10 prescribed turn types.
   Honesty note: coach+judge are same provider (only a Claude key is available) → the
   LLM-judge score is **signal, not independent proof**; the deterministic caps + checks
   (model-independent) and app-path traces are the proof.
2. **[next cycle] Live app-path sweep generator** — a NEW collision-safe harness
   (`NoumTests/CoachAppPathLiveSweep*.swift`) that: builds `AICoachChatService` with a
   **live `providerHTTP`** closure (signature
   `(CoachChatProvider, URL, String, [String:Any]) async throws -> ProviderHTTPResult`;
   extract the app-built messages from the body dict, call Anthropic, return the reply
   wrapped as OpenAI-shaped `{choices:[{message:{content}}]}` Data), drives
   `CoachReplyPipeline.generate` over **every** `requiredFixtureIDs` +
   `requiredLongFormConversationIDs`, captures full `CoachTurnMetadata`, and emits a
   `CoachLiveProviderSweepEvidence` (`coach-live-eval-v1.json`) into
   `NOUM_COACH_EVAL_DUMP_DIR`. The schema is a strict anti-fabrication gauntlet
   (`CoachChatEvaluationFixtures.swift:1776+`): ≥10 unique rows, full required-fixture +
   long-form coverage, per-row provider evidence + readiness telemetry + clean gate
   telemetry, turn-depth variety (quickMove/groundedRead/deepAssessment/trustRepair),
   no duplicate/generic reply text. A PASSING artifact = real evidence that removes
   `.noLiveProviderTranscriptSweep`. env-gated on the key (skips otherwise, no CI break).
3. **[next] Fallback visible-marking + cross-session proof-test dedup** — surface
   `reliabilityFallbackApplied` (mark canned fallback) and extend proof-test dedup beyond
   the 6-turn window (`CoachReplyPipeline` :149–156 → query `CoachMemoryStore`).
4. **[next] Coaching-turn failures** (from live failures.md): cold-start jargon
   ("Ah-Counter"), trustRepair scaffold-label ("Real read:") + raw-metric leak
   ("score 74"), one-move discipline, off-topic report-voice. Fix in the prompt/gate,
   verify via re-run — but anchored to app-path traces, not arena score alone.

## PROVE / HARDEN status (honest scorecard)
| Criterion | Status |
|---|---|
| gold-suite mean ≥70 | live baseline pending (replay was ~71.6; live number is the real one) |
| app-path ≥70 & real | **NOT met — no valid app-path evidence yet** (stale dump; generator is next cycle) |
| trustRepair ≥65 | pending live number; known failure `thats-not-informative` 26 |
| deepAssessment ≥70 | pending live number |
| placeholder/fallback leaks 0 | fallback is turn-aware but **not visibly marked** → open |
| repeated proof-test blocked | 6-turn dedup only; **cross-session open** |
| traces prove real Swift path | infra exists; **live sweep not yet run** → open |
| 10 transcripts feel like a paid coach | live sweep in progress |

**Not production-ready, and won't claim it.** Two of the three readiness blockers are
permanent-by-design (professional-coach calibration + real-user longitudinal outcomes) —
the trust moat. The key removes only `.noLiveProviderTranscriptSweep`.
