# Coach Arena — run_2026-07-21_07-56-12

Provider: `replay` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `cf7ddc980` on `ux-overhaul` (+38 dirty) · prompt: CoachContextBuilder.swift@60f4e431af2889da, AICoachChatService.swift@63c0994da7ff1738

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **69.6** (▲ +0.7) | 70 | ❌ |
| Deep-assessment mean | 78.4 (▲ +1.7) | 70 | ✅ |
| Trust-repair mean | 72 (▲ +0.7) | 65 | ✅ |
| Missing captures | 0 | 0 | ✅ |
| Fixture score floor | 22 | 60 | ❌ |
| Sub-70 fixtures | 21 | 0 | ❌ |
| Placeholder leaks | 4 | 0 | ❌ |

Scored 63/63 fixtures · range 22–94 · median 73.
Finalizer changed 45 generated replies before user display (displaySanitizer 41, reportVoiceResidue 15). 45 replay judge(s) remain scored against raw captured text.

## Report lens and canonical paths

| Field | Value |
|---|---|
| Current report | prompt-layer / Node prompt-faithful |
| Current report path | `tools/coach-arena/reports/latest.md` |
| Comparable app-path report | `tools/coach-arena/reports/app-path/latest.md` |
| App-path source of truth | canonical `tools/coach-arena/reports/app-path/` only |
| Nested duplicate app-path path | stale duplicate present at tools/coach-arena/tools/coach-arena/reports/app-path/latest.json (generated 2026-07-05T23:09:49+00:00); ignore this path |
| Latest canonical app-path generated | `2026-07-20T18:42:37+00:00` |
| Latest canonical app-path average | `81.16/100` |
| App-path evidence gate (incl. source freshness) | `true` · claim `realPipelineEvidence` |
| App-path trace-level quality (traces real/complete/unique) | `true` |
| Latest canonical app-path leaks/failures | leaks `0` · failures `0` |
| Latest canonical app-path VISION boundary | score `20` · claim `localEvaluationSubstrateOnly` |

## Prompt-cache usage (this run)

No usage data on this run (replay/cli provider, or no scored requests).

## Finalized deterministic audit

Diagnostic only: replay judge scores remain tied to raw captured replies, and replay cannot execute the live quality-gate repair path.

| Metric | Value |
|---|---|
| Replies checked | 63 |
| Changed from scored reply | 55 |
| Reliability fallback mirrored | 32 |
| Replies with deterministic hard caps | 1 |
| Likely blocked/repaired by live gate | 0 |
| No production backstop identified | 1 |
| Placeholder/fallback leaks after surface mirror | 0 |
| Cap breakdown | ignoresIntent 1 |
| Unbacked capped fixture IDs | conv-goal-change-arc__t1 |

## App-path evidence

| Metric | Value |
|---|---|
| Status | unavailable (prompt-layer run) |
| App-path score | unavailable |
| Why | This run used the Node prompt-faithful engine. It does not execute the Swift retrieval, memory, caching, provider fallback, live quality gate, or UI pipeline. Run ./tools/coach-arena/run.sh python with a fresh app-path dump to produce this evidence. |

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 19.6 | 18.4 | 14.6 | 12.1 | 11.8 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| cold-start | 1 | 22 | (±0) |
| off-topic | 1 | 45 | (±0) |
| goal-change | 3 | 46 | (±0) |
| emotional-frustration | 1 | 56 | (±0) |
| greeting | 1 | 56 | (±0) |
| leadership-update | 1 | 60 | (±0) |
| metadata-trap | 1 | 64 | (±0) |
| synthetic-conversation | 11 | 66.3 | (▲ +2.1) |
| mechanics | 6 | 67.2 | (±0) |
| trust-repair | 9 | 68.3 | (±0) |
| repetition-callout | 1 | 69 | (±0) |
| partial-pushback | 1 | 70 | (±0) |
| plan-request | 1 | 71 | (±0) |
| filler-pressure | 1 | 73 | (±0) |
| memory-recall | 1 | 73 | (±0) |
| score-question | 1 | 74 | (±0) |
| interview-prep | 1 | 75 | (±0) |
| transfer | 3 | 77 | (±0) |
| emotional | 4 | 78.5 | (±0) |
| deep-assessment | 6 | 80 | (▲ +2.8) |
| fabrication-trap | 1 | 81 | (±0) |
| pressure-mode | 3 | 82 | (±0) |
| confidence-ending | 1 | 83 | (±0) |
| big-moment | 1 | 84 | (±0) |
| readiness-trap | 1 | 85 | (±0) |
| data-question | 1 | 88 | (±0) |

## Reliability caps triggered

- `voiceIntegrity`: 5
- `placeholderOrBroken`: 4
- `ignoresIntent`: 5

## Worst 10

| Score | Fixture | Turn | closerTo | Class | Top issue |
|---|---|---|---|---|---|
| **22** | cold-start-no-data | groundedRead | between | substance | coldStartProductJargon |
| **26** | thats-not-informative | trustRepair | between | substance | roboticPhrase |
| **30** | goal-change-engaging | groundedRead | excellent | substance | roboticPhrase |
| **30** | conv-goal-change-arc__t1 | groundedRead | between | substance | roboticPhrase |
| **43** | what-voice-should-i-pick | groundedRead | between | substance | roboticPhrase |
| **45** | off-topic-egg | offTopic | between | substance | sensitiveTurnReportVoice |
| **46** | conv-skeptic__t1 | trustRepair | between | substance | trustRepairReportVoice |
| **50** | why-cant-straight-answer | trustRepair | excellent | substance | trustRepairReportVoice |
| **54** | i-ramble | groundedRead | excellent | residue | scaffoldLabel |
| **55** | conv-cold-start-first-rep__t0 | groundedRead | excellent | substance | Cold-start ceiling: no individual signal |

Class: `substance` = real coaching gap · `residue` = judge-excellent reply capped for voice/report-voice residue (cosmetic, ux/chat-owned).

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
