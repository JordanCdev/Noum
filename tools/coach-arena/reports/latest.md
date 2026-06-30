# Coach Arena Latest Report

- Generated: `2026-06-30T23:16:47+00:00`
- Candidate: `excellent`
- Fixtures: `50`
- Average: `85.76/100`
- Passes score/coverage thresholds: `True`
- Production evidence passes: `False`
- Evidence claim: `localEvaluationOnly`
- Trace quality passes: `False`
- Placeholder leaks: `0`

## Type Averages

- `deepAssessment`: `85.0/100`
- `groundedRead`: `86.22/100`
- `quickMove`: `85.59/100`
- `trustRepair`: `85.67/100`

## Production Evidence

- `0 of 50 fixtures came from real pipeline sources`
- `0 of 50 fixtures have complete required traces`

## Trace Audit

- Real-pipeline trace fixtures: `0`
- Complete traces: `0`
- Missing-trace fixture count: `50`
- Candidate sources: `excellentAnswerExample` `50`
- Missing trace fields: `context` `50`, `retrieval` `50`, `memory` `50`, `reasoning` `50`, `prompt` `50`, `provider` `50`, `rawReply` `50`, `issues` `50`, `latency` `50`, `cache` `50`, `fallback` `50`

## Trace Quality

- Eligible real-pipeline traces: `0`
- Passes: `False`
- Unique proof-test hashes: `0`
- Max proof-test hash reuse: `0`
- Distinct rounded confidence values: `0`
- Empty retrieval-card traces: `0`
- Slow first-token traces: `0`

## Previous Run

- Status: `compared`
- Previous generated: `2026-06-30T23:12:28+00:00`
- Previous candidate: `excellent`
- Candidate changed: `False`
- Fixture count changed: `False`
- Average delta: `0.0`
- Failure count delta: `0`
- Placeholder leak delta: `0`
- Pass state changed: `False`
- Type average deltas: `deepAssessment` `0.0`, `groundedRead` `0.0`, `quickMove` `0.0`, `trustRepair` `0.0`
- Cleared failures: `none`
- New failures: `none`

## Worst Fixtures

- `examples-from-sessions-010` `groundedRead`: `83/100` - no local failure reason
- `outcome-not-causation-027` `groundedRead`: `83/100` - no local failure reason
- `authoritative-distance-001` `deepAssessment`: `85/100` - no local failure reason
- `not-informative-trust-repair-002` `trustRepair`: `85/100` - no local failure reason
- `filler-pressure-007` `quickMove`: `85/100` - no local failure reason
- `leadership-update-008` `quickMove`: `85/100` - no local failure reason
- `score-not-readiness-011` `deepAssessment`: `85/100` - no local failure reason
- `markdown-tts-015` `trustRepair`: `85/100` - no local failure reason
- `cold-generic-016` `trustRepair`: `85/100` - no local failure reason
- `too-much-writing-017` `trustRepair`: `85/100` - no local failure reason
