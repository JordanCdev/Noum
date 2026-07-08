# Coach Arena — run_2026-07-08_13-06-43

Provider: `replay` · coach model: `claude-sonnet-4-6` · judge model: `claude-sonnet-4-6`
Git: `a169ff3a` on `ux-overhaul` (+26 dirty) · prompt: CoachContextBuilder.swift@a7463ab634ab8fd1, AICoachChatService.swift@4f2e98c8ac4527c6

## Headline

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **69.5** (±0) | 70 | ❌ |
| Deep-assessment mean | 76.7 (±0) | 70 | ✅ |
| Trust-repair mean | 72.2 (±0) | 65 | ✅ |
| Missing captures | 0 | 0 | ✅ |
| Fixture score floor | 22 | 60 | ❌ |
| Sub-70 fixtures | 21 | 0 | ❌ |
| Placeholder leaks | 2 | 0 | ❌ |

Scored 61/61 fixtures · range 22–88 · median 73.

## Prompt-cache usage (this run)

No usage data on this run (replay/cli provider, or no scored requests).

## App-path evidence

| Metric | Value |
|---|---|
| Status | unavailable (prompt-layer run) |
| App-path score | unavailable |
| Why | This run used the Node prompt-faithful engine. It does not execute the Swift retrieval, memory, caching, provider fallback, live quality gate, or UI pipeline. Run ./tools/coach-arena/run.sh python with a fresh app-path dump to produce this evidence. |

## Dimension means (of max)

| Diagnostic IQ /25 | EQ /25 | Memory /20 | Intervention /15 | Dialogue /15 |
|---|---|---|---|---|
| 19.4 | 18.3 | 14.4 | 12 | 11.7 |

## By category

| Category | n | Mean | Δ |
|---|---|---|---|
| cold-start | 1 | 22 | (±0) |
| off-topic | 1 | 45 | (±0) |
| goal-change | 3 | 45.3 | (±0) |
| emotional-frustration | 1 | 56 | (±0) |
| greeting | 1 | 56 | (±0) |
| leadership-update | 1 | 60 | (±0) |
| metadata-trap | 1 | 64 | (±0) |
| synthetic-conversation | 10 | 66 | (±0) |
| mechanics | 6 | 67.2 | (±0) |
| repetition-callout | 1 | 69 | (±0) |
| partial-pushback | 1 | 70 | (±0) |
| trust-repair | 9 | 70.4 | (±0) |
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

- `placeholderOrBroken`: 2

## Worst 10

| Score | Fixture | Turn | closerTo | Top issue |
|---|---|---|---|---|
| **22** | cold-start-no-data | groundedRead | between | coldStartProductJargon |
| **26** | thats-not-informative | trustRepair | between | roboticPhrase |
| **31** | what-voice-should-i-pick | groundedRead | between | roboticPhrase |
| **45** | off-topic-egg | offTopic | between | sensitiveTurnReportVoice |
| **46** | conv-skeptic__t1 | trustRepair | between | trustRepairReportVoice |
| **48** | conv-goal-change-arc__t1 | groundedRead | between | roboticPhrase |
| **49** | goal-change-engaging | groundedRead | excellent | roboticPhrase |
| **54** | i-ramble | groundedRead | excellent | scaffoldLabel |
| **55** | conv-cold-start-first-rep__t0 | groundedRead | excellent | Cold-start ceiling: no individual signal |
| **56** | its-not-easy | trustRepair | between | No next step or presence-close — ends on |

See `failures.md` for full replies + judge reasoning. Raw: `latest.json`.
