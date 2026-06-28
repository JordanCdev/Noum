# SPEC: Semantic-gate dry-run diagnostic (calibration substrate)

Status: build-ready, device-owning session. Default OFF. Not landed headless because
it edits the live `AICoachChatService` reply-decision path (a hot coach file) and its
value is only observable at runtime; a device session should land + felt-QA it.

## Why

The recurring top-severity gap across every coach-parity panel (incl. 2026-06-28) is
the same: the coach judgement layer's rubric thresholds and evidence-scoring heuristics
are **author-chosen, not calibrated** —

- `CoachReasoningPass.swift:59-108` dimension scores (verdict_first, hedge_control,
  salience, pressure_stability …) are lexical/heuristic.
- `CoachReasoningPass.swift:212-216` goalReadiness is a 6-dimension average capped by
  `evidenceCoverage` (`UserTrajectoryCache.swift:113-133`).
- The semantic gate cutoffs in `AICoachChatService.semanticQualityIssue`
  (`:1664-1714`) — `evidenceReferenceCount >= 2`, `confidence < 0.78`, `< 0.70`,
  `< 0.55` — are chosen, not validated.

`CoachParityReadiness` is capped at `.forming` precisely because there is no
validation substrate. This spec creates the first piece of that substrate: a way to
collect *which real replies the gate would reject and why*, without changing what the
user sees, so the cutoffs and keyword lists can be tuned against ground truth.

## Change (exact)

1. `Noum/CoachTurnDepth.swift`, after the `realtimeCoachModeEnabled` flag:

```swift
    /// Dry-run mode for the semantic quality gate. When on, replies that WOULD
    /// trip the gate are logged (outcome = .skipped) instead of being rejected
    /// and repaired, so gate rules can be tuned against real production replies.
    /// Default off; enable via NOUM_SEMANTIC_GATE_DRY_RUN=1.
    nonisolated(unsafe) static var semanticGateDryRunEnabled = {
        ProcessInfo.processInfo.environment["NOUM_SEMANTIC_GATE_DRY_RUN"] == "1"
    }()
```

2. `Noum/AICoachChatService.swift`, at the deep/trust-repair gate decision site
   (`if let semanticIssue = …`, around `:1320`). Before invoking the repair/fallback
   branch, insert:

```swift
    if CoachTurnDepth.semanticGateDryRunEnabled {
        recordChatDiagnostic(
            outcome: .skipped,
            detail: "semantic-gate dry-run: would reject (\(semanticIssue.rawValue))"
        )
        // fall through and accept the draft unchanged
    } else {
        // existing repair + fallback logic, unchanged
    }
```

Keep the change scoped to the *semantic* gate only — do not alter the professional-coach
gate. No new async, no new state, no new locks; it reuses the existing
`recordChatDiagnostic` path (`:3360`).

## Guardrails

- Default OFF: production behaviour is byte-identical unless the env var is set.
- Only the diagnostic outcome string changes when ON; the gate's *decision logic*
  is untouched, so dry-run data reflects exactly what the live gate would do.
- Do NOT ship ON. It is a developer/QA-only instrument for gathering tuning data.

## Verification (device session)

1. Build + run with `NOUM_SEMANTIC_GATE_DRY_RUN=1`, exercise Ask Noum deep-assessment
   and trust-repair turns, confirm replies render unchanged and `.skipped` diagnostics
   carry the issue reason.
2. Build + run WITHOUT the env var, confirm the gate still rejects/repairs as today.
3. Use the collected `.skipped` reasons to calibrate the `:1664-1714` cutoffs and the
   `CoachReasoningPass` keyword lists; label the result "calibration substrate", not
   "validation" (per the handover red lines).

## Companion test coverage already landed

`NoumTests/CoachJudgementLayerTests.swift` →
`CoachSemanticQualityGateAdversarialTests` (2026-06-28) locks the gate's current
decision behaviour across all six ordered deep-assessment checks, the confidence
thresholds, trust-repair, and quick-move — so any calibration change is a deliberate,
test-visible edit rather than silent drift.
