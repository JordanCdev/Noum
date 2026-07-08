# Coach Arena — run_2026-07-08_19-32-18

Provider: `replay` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `667735c8` on `ux-overhaul` (+4 dirty) · prompt: CoachContextBuilder.swift@08e780cddc2e2106, AICoachChatService.swift@c55a47f9ddaba868

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **70.2** (±0) | 70 | ✅ |
| Deep-assessment mean | 76.7 (±0) | 70 | ✅ |
| Trust-repair mean | 72.3 (±0) | 65 | ✅ |
| Missing captures | 0 | 0 | ✅ |
| Fixture score floor | 22 | 60 | ❌ |
| Sub-70 fixtures | 16 | 0 | ❌ |
| Placeholder leaks | 2 | 0 | ❌ |

Scored 51/51 fixtures · range 22–88 · median 74.
Finalizer changed 40 generated replies before user display (displaySanitizer 36, reportVoiceResidue 16). 40 replay judge(s) remain scored against raw captured text.

## Report lens and canonical paths

| Field | Value |
|---|---|
| Current report | prompt-layer / Node prompt-faithful |
| Current report path | `tools/coach-arena/reports/latest.md` |
| Comparable app-path report | `tools/coach-arena/reports/app-path/latest.md` |
| App-path source of truth | canonical `tools/coach-arena/reports/app-path/` only |
| Nested duplicate app-path path | stale duplicate present at tools/coach-arena/tools/coach-arena/reports/app-path/latest.json (generated 2026-07-05T23:09:49+00:00); ignore this path |
| Latest canonical app-path generated | `2026-07-08T19:03:47+00:00` |
| Latest canonical app-path average | `77.5/100` |
| App-path evidence gate (incl. source freshness) | `false` · claim `localEvaluationOnly` |
| App-path trace-level quality (traces real/complete/unique) | `true` |
| Latest canonical app-path leaks/failures | leaks `1` · failures `1` |
| Latest canonical app-path VISION boundary | score `18` · claim `localEvaluationSubstrateOnly` |

## Prompt-cache usage (this run)

No usage data on this run (replay/cli provider, or no scored requests).

## Finalized deterministic audit

Diagnostic only: replay judge scores remain tied to raw captured replies, and replay cannot execute the live quality-gate repair path.

| Metric | Value |
|---|---|
| Replies checked | 51 |
| Changed from scored reply | 40 |
| Reliability fallback mirrored | 1 |
| Replies with deterministic hard caps | 4 |
| Likely blocked/repaired by live gate | 4 |
| No production backstop identified | 0 |
| Placeholder/fallback leaks after surface mirror | 0 |
| Cap breakdown | voiceIntegrity 4 |
| Unbacked capped fixture IDs | none |

## App-path evidence

| Metric | Value |
|---|---|
| Status | unavailable (prompt-layer run) |
| App-path score | unavailable |
| Why | This run used the Node prompt-faithful engine. It does not execute the Swift retrieval, memory, caching, provider fallback, live quality gate, or UI pipeline. Run ./tools/coach-arena/run.sh python with a fresh app-path dump to produce this evidence. |

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 19.7 | 18.6 | 14.5 | 12.1 | 11.7 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| cold-start | 1 | 22 | (±0) |
| off-topic | 1 | 45 | (±0) |
| goal-change | 3 | 52.7 | (±0) |
| emotional-frustration | 1 | 56 | (±0) |
| greeting | 1 | 56 | (±0) |
| leadership-update | 1 | 60 | (±0) |
| metadata-trap | 1 | 64 | (±0) |
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
| deep-assessment | 5 | 77.2 | (±0) |
| emotional | 4 | 78.5 | (±0) |
| fabrication-trap | 1 | 81 | (±0) |
| pressure-mode | 3 | 82 | (±0) |
| confidence-ending | 1 | 83 | (±0) |
| big-moment | 1 | 84 | (±0) |
| readiness-trap | 1 | 85 | (±0) |
| data-question | 1 | 88 | (±0) |

## Reliability caps triggered

- `voiceIntegrity`: 4
- `placeholderOrBroken`: 2
- `ignoresIntent`: 4

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **22** | cold-start-no-data | groundedRead | between | coldStartProductJargon |
| **26** | thats-not-informative | trustRepair | between | roboticPhrase |
| **43** | what-voice-should-i-pick | groundedRead | between | roboticPhrase |
| **45** | off-topic-egg | offTopic | between | sensitiveTurnReportVoice |
| **50** | goal-change-engaging | groundedRead | excellent | roboticPhrase |
| **50** | why-cant-straight-answer | trustRepair | excellent | trustRepairReportVoice |
| **54** | i-ramble | groundedRead | excellent | scaffoldLabel |
| **56** | its-not-easy | trustRepair | between | No next step or presence-close — ends on |
| **56** | greeting-hi | greeting | between | Report-voice residue: recites 'close hel |
| **57** | talk-too-fast | groundedRead | excellent | sensitiveTurnReportVoice |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
