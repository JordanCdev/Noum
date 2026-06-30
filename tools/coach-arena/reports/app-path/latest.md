# Coach Arena Latest Report

- Generated: `2026-06-30T23:16:53+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `25`
- Average: `76.32/100`
- Passes score/coverage thresholds: `False`
- Production evidence passes: `False`
- Evidence claim: `localEvaluationOnly`
- Trace quality passes: `False`
- Placeholder leaks: `0`

## Type Averages

- `deepAssessment`: `82.0/100`
- `groundedRead`: `76.6/100`
- `quickMove`: `75.73/100`
- `trustRepair`: `75.43/100`

## Production Evidence

- `2 real-pipeline trace(s) returned no retrieved cards`
- `25 fixture(s) missing from app-path report`
- `matched 25 of 50 requested fixtures`
- `proofTestHash reused across 17 real-pipeline fixtures`

## Trace Audit

- Real-pipeline trace fixtures: `25`
- Complete traces: `25`
- Missing-trace fixture count: `0`
- Candidate sources: `appPathReport` `25`

## Trace Quality

- Eligible real-pipeline traces: `25`
- Passes: `False`
- Unique proof-test hashes: `5`
- Max proof-test hash reuse: `17`
- Distinct rounded confidence values: `4`
- Empty retrieval-card traces: `2`
- Slow first-token traces: `0`
- Trace quality failures: `2 real-pipeline trace(s) returned no retrieved cards`; `proofTestHash reused across 17 real-pipeline fixtures`

## Previous Run

- Status: `compared`
- Previous generated: `2026-06-30T23:12:37+00:00`
- Previous candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Candidate changed: `False`
- Fixture count changed: `False`
- Average delta: `0.0`
- Failure count delta: `0`
- Placeholder leak delta: `0`
- Pass state changed: `False`
- Type average deltas: `deepAssessment` `0.0`, `groundedRead` `0.0`, `quickMove` `0.0`, `trustRepair` `0.0`
- Cleared failures: `none`
- New failures: `none`

## Coverage

- Source: `appPathReport`
- Source schema: `coach-chat-conversation-app-path-eval-v1`
- Source surface: `text`
- Source app-path floor: `True`
- Coverage passes: `False`
- Requested fixtures: `50`
- Matched fixtures: `25`
- Unmatched fixtures: `25`
- Ambiguous fixtures: `0`
- Coverage failures: `25 fixture(s) missing from app-path report`; `matched 25 of 50 requested fixtures`

## Worst Fixtures

- `cold-generic-016` `trustRepair`: `70/100` - no local failure reason
- `pace-rushing-019` `groundedRead`: `70/100` - no local failure reason
- `confidence-clean-stop-025` `quickMove`: `70/100` - no local failure reason
- `not-easy-empathy-004` `trustRepair`: `71/100` - no local failure reason
- `filler-pressure-007` `quickMove`: `71/100` - no local failure reason
- `interview-prep-006` `quickMove`: `72/100` - no local failure reason
- `leadership-transfer-capture-026` `quickMove`: `72/100` - no local failure reason
- `not-informative-trust-repair-002` `trustRepair`: `73/100` - no local failure reason
- `confidence-ending-009` `groundedRead`: `73/100` - no local failure reason
- `leadership-update-008` `quickMove`: `74/100` - no local failure reason
