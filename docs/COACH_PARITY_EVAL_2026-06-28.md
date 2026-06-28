# Coach-parity eval — 2026-06-28 (autonomous `noum-1` run)

Branch: `ux-overhaul`. HEAD at eval: `9c31e7f6` ("noum chat v2" — the coach
judgement layer). Method: 5-role read-only panel (engineering/QA · market · cold
end-user · UX · product-honesty) over the *newly landed, never-before-evaluated*
1863-line judgement layer, each role adversarially verified, plus a real
toolchain build + focused test run.

## Headline

- **Mean role score 7.7/10** (engineering 8.2 · market 7.8 · honesty 7.7 ·
  end-user 7.5 · UX 7.3). Up from the ~7.4–7.5 plateau — the judgement layer adds
  genuine substance, not just polish.
- **The judgement layer is REAL: 5/5 roles independently confirmed genuine
  end-to-end wiring**, not placeholder-presented-as-complete. Data flow traced:
  `TurnDepthClassifier` → `UserTrajectoryCache`/`Snapshot` → `CoachReasoningPass`
  (typed `CoachAssessment`) → `CoachPromptBundle` (depth-routed tier/budget) →
  model call → semantic quality gate (`AICoachChatService.semanticQualityIssue`)
  → rendered reply, with a deterministic `immediateCoachRead` provisional path.
- **Build verified GREEN** with the real toolchain (`xcodebuild build-for-testing`,
  isolated `DerivedData/Noum-eval-verify`, iPhone 17 Pro sim): `** TEST BUILD
  SUCCEEDED **`, 0 errors. (Past runs' "green" claims were never actually compiled
  — this one was.)

## What shipped this run

- **`CoachSemanticQualityGateAdversarialTests`** — 18 new fixtures in
  `NoumTests/CoachJudgementLayerTests.swift` locking the semantic gate's six
  ordered deep-assessment checks, the 0.78/0.70/0.55 confidence thresholds, the
  over-rejection guards (qualified closeness must pass; high-confidence replies
  need not disclose missing evidence), trust-repair, and quick-move. Closes the
  engineering-role gap: "the new layer's tests are tautological / never exercise
  the gate under varied assessments." Test-file only, zero production collision,
  fully headless-verifiable. Each fixture hand-traced through the gate's actual
  check ordering before writing.
- **`docs/SPEC_semantic_gate_dry_run_calibration.md`** — build-ready spec for the
  dry-run gate diagnostic (the lever that gathers calibration ground-truth).
  Deferred from headless landing because it edits the live reply-decision path in a
  hot coach file and its value is runtime-only — a device session should land +
  felt-QA it.

## The 10/10 / A* answer (restated, unchanged, correct)

The literal *"with no doubt replaces a human communications coach"* remains
**refused by design** — `CoachParityReadiness` is capped at `.forming`. This is the
trust moat and Noum's actual competitive wedge; removing it would make the product
worse, not better. On the **achievable** axis (rival Speeko/Orai/Yoodli/Duolingo on
substance + trust + a legible demo moment), Noum is a strong 7.7 and rising.

## Genuine limitations (the real ceiling — none cheaply closeable headless)

1. **Heuristic, uncalibrated scoring.** Dimension scores
   (`CoachReasoningPass.swift:59-108`) and gate cutoffs are lexical/author-chosen,
   not validated against human-coach baselines. This is *the* reason parity stays
   capped. Path: the dry-run telemetry spec above → an expert-eval fixture set →
   tune cutoffs. Requires Jordan (device data + expert labels).
2. **Single rubric.** `GoalRubricStore` routes every voice (.warm, .concise,
   .persuasive, .executive, .storytelling) to the authoritative rubric. Honest
   guardrail today, but warm/storytelling coaching is one-size-fits-all. Adding
   more rubrics safely needs calibration first (don't ship more uncalibrated
   thresholds).
3. **Single-rep goal-readiness is structurally bounded.** With one timed rep and no
   prosody/video/real-stakes signal, the machinery correctly refuses "you're
   ready" — but it also cannot *prove* readiness. That floor is real, not a bug.
4. **Provisional read not rendered in Live Coach.** `LiveCoachCallView:156` reads
   the pending text but sanitizes it through `liveDisplayText`; surfacing the
   structured provisional read needs a text-rendering decision (felt-QA-gated).
5. **The dominant acquisition lever is human-gated.** Auto-guided first-rep
   instant-start is code-complete but default-OFF, gated on device felt-QA only
   Jordan can do. Unchanged from prior runs.

## Recommended next sequence

1. (Device, Jordan) Land + felt-QA the dry-run gate diagnostic
   (`SPEC_semantic_gate_dry_run_calibration.md`); collect `.skipped` reasons.
2. (Device, Jordan) Flip the auto-guided first-rep flag + felt-QA — the dominant
   acquisition move.
3. Build an expert-eval fixture set from the dry-run data; tune cutoffs; label
   "calibration substrate", not validation.
4. Only after (3): add per-voice rubrics beyond authoritative.
