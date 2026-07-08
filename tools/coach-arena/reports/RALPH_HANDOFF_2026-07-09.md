# RALPH handoff — 2026-07-09 (supersedes 2026-07-08 for the app-path items)

Work branch `ralph-app-path-evidence-0708` → **draft PR #210** (base `ux-overhaul`).
5 focused commits, all verified on the iOS simulator. Local `ux-overhaul` HEAD is
`d8898b57` (2 cron commits `aefc7a5c`+`d8898b57` are local-only, not yet on origin).

## DONE this session — do NOT redo
1. **HEAD app-path confidence regression FIXED.** `aefc7a5c` rewrote the pipeline after
   the last dump, collapsing app-path `assessmentConfidence` to a flat 0.20 (correct
   thin-evidence value for the then-evidence-free harness) → 2 corpus tests RED.
2. **Option (a) LANDED (the product-truth fix).** `CoachReplyPipeline.generate` gained an
   optional `sessionsOverride: [PracticeSession]? = nil` (default nil = production + every
   real caller UNCHANGED; mirrors the existing `store`/`coachService` injectable params).
   The app-path harness now injects each conversation's real
   `CoachChatConversationCorpus.sourceFixture(for:).sessions`, so `evidenceCoverage` varies
   per conversation and confidence rises LEGITIMATELY (distinct 1→10, 0.20 cold-start→0.38
   evidence-rich). App-path engine now reports **`realPipelineEvidence`**, productionEvidence
   + traceQuality PASS, score 73.8, 0 leaks. Floor failures 26→21, no cascade.
3. **Cache-state capture added** to the app-path trace (`trajectoryCacheHit`/
   `assessmentCacheHit` on the turn row + transcript `CACHE:` line + assertions). Proves
   caching end-to-end: trajectory False on turn 0 (cold miss) → True on turns 1-2 (warm).
4. **Verified:** corpus suite 70/70; **full `NoumTests` unit target 3302/3302** with the
   product change; node validate 51·0·0; node arena 58 (0 fail). 10 transcripts regenerated
   with real varying confidence + cache; `reports/app-path/latest.*` regenerated.

## Invariants that MUST stay
- `CoachReasoningPass` `coverage < 0.15 → 0.20` thin-evidence floor (deliberate; a cold-start
  conversation with no sessions SHOULD read 0.20). Confidence calibration is pinned by
  `CoachJudgementLayerTests.assessmentConfidenceMovesWithEvidenceCoverage`.
- `sessionsOverride` must stay `nil`-default — never wire it into a production call path.

## EXACT remaining blockers (need resources, not more headless effort)
1. **Prompt-layer ≥70 (currently 67.6).** 17 confirmations that prompt WORDING can't cross
   the noisy 70, and it is UNMEASURABLE without an `ANTHROPIC_API_KEY` (live generation +
   live judge). This blocks task items 11–17 (partial-pushback, trust-repair, emotional-
   frustration, deep-assessment, plan/interview/leadership, metadata-trap, goal-change) —
   they are all prompt-layer coaching-quality fixes whose effect only shows on GENERATED
   replies. Do NOT make blind wording changes (they've net-zeroed 17×). 
2. **"VISION standard genuinely met"** — `CoachVisionProductionReadinessAuditTests` caps this
   local substrate at 18/100 and refuses `productionReady` without real-user longitudinal
   transfer + professional-coach calibration + TestFlight. Structurally unreachable headless
   BY DESIGN. Do not fake it.

## WHEN A KEY IS AVAILABLE — do this first (items 11–17)
1. Live baseline: `ANTHROPIC_API_KEY=… ARENA_INCLUDE_SYNTHETIC=1 ./run.sh run` → record the
   real gold mean + the worst-10 from the ACTUAL replies (not the headline).
2. The ONE untried structural lever (memory + iter16 next-step #2): **CONTEXT-block evidence
   surfacing** in `CoachContextBuilder` — pre-compute "the single signal this turn must cite"
   into the CONTEXT block so quickMove/groundedRead replies anchor one real datum BY
   CONSTRUCTION (kills the "decorative memory"/"missing evidence anchor" cluster that
   dominates the worst fixtures). This is DATA, not wording — the only lever wording-iters
   didn't touch.
3. Attribute EVERY change with a **same-era dual-arm blind A/B** (regenerate BOTH arms in one
   batch, one blind judge) — never the headline `latest.json` delta (judge panels + generation
   both drift per draw). Diagnose gaps from a fresh draw, not one baseline.

## UPDATE: cli-mode NOW WORKS keyless (fixed) — HEAD raw-draft prompt-layer = 64.1
The contamination below is FIXED (commit): the arena's cli provider now uses
`--system-prompt` (replace) instead of `--append-system-prompt`, so nested-in-Claude-Code
runs get clean production-parity `claude-sonnet-4-6` coach + judge output via the OAuth CLI.
`ARENA_PROVIDER=cli ARENA_INCLUDE_SYNTHETIC=1 node runners/replay.mjs run` → **HEAD raw-draft
mean 64.1** (anchor 67.6; within draw variance). KEY FINDING
(`ralph-cli-baseline-analysis-2026-07-08.md`): 24/26 deterministic findings on the 40 sub-70
fixtures are GATE-CAUGHT types (tooLong/scaffold/report-voice) the shipping gate repairs
before display; the other 19 are judge-rubric gaps on a mature prompt (17-iter ceiling). So
prompt-layer<70 is a raw-draft artifact — the faithful gated measure (app-path) passes all
thresholds. If a future loop still wants to chase the raw-draft number: run a cli dual-arm
A/B (old vs new prompt, one blind judge) on the 19 non-gate-caught sub-70 fixtures, testing
the CONTEXT-block evidence-surfacing lever — but it's LOW VALUE (moves a number that
under-states shipped quality; app-path already ≥ target). Do NOT overwrite the committed
anthropic `latest.md` (67.6) with a cli run — restore it via git after.

## (Historical, now FIXED) `ARENA_PROVIDER=cli` was contaminated when nested in Claude Code
`claude -p` IS authenticated in a background/interactive Claude Code session (probe returned
`PROBE_OK`; the cron-context 401 does not apply here). BUT the arena's cli provider calls
`claude -p --model claude-sonnet-4-6 --append-system-prompt "<coach>"` — and nested inside
Claude Code, the coach prompt is APPENDED to Claude Code's own agent system prompt, which
dominates. Direct probe on "That's not informative." returned Claude-Code-agent voice
("What are you referring to? I don't have context from a previous exchange here."), not a
coach reply; a 2-fixture cli run scored mean=44 (vs ~55–68 on the anthropic baseline). So
cli-mode is NOT a valid coach measurement here, and the contamination is large enough to
swamp a dual-arm A/B too. **Conclusion: there is NO valid prompt-layer measurement path in a
nested Claude Code session — a real `ANTHROPIC_API_KEY` (anthropic provider) is required.**
Do not retry cli-mode from within Claude Code. (It may be clean from a plain terminal where
`claude -p` has no agent system prompt — untested; Jordan could run `./run.sh run` there.)

## Testing gotchas (re-confirmed this session)
- Swift-Testing suite id ≠ filename: the corpus suite is `CoachChatConversationCorpusTests`
  (not `…EvaluationTests`); use `-only-testing:NoumTests/CoachChatConversationCorpusTests` for
  the gate tests and the XCTest bridge `NoumTests/CoachChatConversationArtifactDumpXCTest` to
  regenerate the /private/tmp dump (default dir, no env var). A 0-test selection still prints
  `TEST SUCCEEDED` — confirm via `xcresulttool … summary` total.
- A fresh worktree LACKS the gitignored build plists — `cp` the shared checkout's
  `Noum/{Info,AIConfig,BackendConfig,GoogleService-Info}.plist` in before xcodebuild.
- `CoachChatConversationAppPathTurnRow` has TWO construction sites (real-pipeline harness +
  the synthetic "clean-app-path-manifest" builder ~line 4563) — adding a field breaks the
  second one's memberwise init.
- Python engine default reports-dir is the SHARED `reports/` — always pass
  `--reports-dir reports/app-path` for app-path runs or it clobbers the Node `latest.md`.

## Open product decision (do NOT fake)
App-path **quickMove type-avg 68.76** (< 70): the deterministic local_judge flags some
scripted quickMove gold replies "missing evidence anchor". The reply text is FORCED, so
session injection doesn't change it — improving the number means editing gold replies, which
is corpus-gaming. Left as-is; aggregate app-path 73.8 passes. If Jordan wants it moved, the
honest route is authoring stronger gold quickMove replies (a corpus-quality task), not a
harness/judge tweak.

## Concurrency
Cron tasks noum-1/noum2 may commit to local `ux-overhaul` every ~15-40 min. My worktree was
NOT raced this session (local ux-overhaul stayed at d8898b57). If you see interleaved commits
or lock contention, that's why — log it and continue.
