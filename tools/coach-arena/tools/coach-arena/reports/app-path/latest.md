# Coach Arena Latest Report

- Generated: `2026-07-05T23:09:49+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `72.42/100`
- Passes score/coverage thresholds: `True`
- Production evidence passes: `False`
- Evidence claim: `localEvaluationOnly`
- Trace quality passes: `False`
- Placeholder leaks: `0`

## Type Averages

- `deepAssessment`: `76.0/100`
- `groundedRead`: `72.22/100`
- `quickMove`: `69.12/100`
- `trustRepair`: `76.67/100`

## Production Evidence

- `assessmentConfidence has only 1 distinct rounded value(s)`

## Trace Audit

- Real-pipeline trace fixtures: `50`
- Complete traces: `50`
- Missing-trace fixture count: `0`
- Candidate sources: `appPathReport` `50`

## Trace Quality

- Eligible real-pipeline traces: `50`
- Passes: `False`
- Unique proof-test hashes: `9`
- Max proof-test hash reuse: `9`
- Max proof-test hash reuse allowed: `10`
- Distinct rounded confidence values: `1`
- Empty retrieval-card traces: `0`
- Allowed empty retrieval-card traces: `39`
- Slow first-token traces: `0`
- Trace quality failures: `assessmentConfidence has only 1 distinct rounded value(s)`

## Previous Run

- Status: `noPreviousReport`
- Summary: `No previous latest.json existed in this report directory.`

## Coverage

- Source: `appPathReport`
- Source schema: `coach-chat-conversation-app-path-eval-v1`
- Source surface: `text`
- Source app-path floor: `False`
- Coverage passes: `True`
- Requested fixtures: `50`
- Matched fixtures: `50`
- Unmatched fixtures: `0`
- Ambiguous fixtures: `0`

## Worst Fixtures

- `outcome-not-causation-027` `groundedRead`: `50/100` - reply does not match expected coach move
- `emotional-disconnection-036` `groundedRead`: `50/100` - fixture disqualifier triggered: no reflection check; fixture-specific disqualifier triggered; reply does not match expected coach move
- `semantic-filler-use-040` `groundedRead`: `50/100` - fixture disqualifier triggered: no adjusted rule; fixture-specific disqualifier triggered; low-EQ reply: emotional signal is not acknowledged; reply does not match expected coach move
- `live-latency-short-044` `quickMove`: `50/100` - missing evidence anchor; reply does not match expected coach move
- `real-world-outcome-047` `groundedRead`: `50/100` - fixture disqualifier triggered: no reusable move; fixture-specific disqualifier triggered; reply does not match expected coach move
- `grammar-leak-048` `quickMove`: `50/100` - missing evidence anchor; reply does not match expected coach move
- `placeholder-leak-049` `quickMove`: `50/100` - missing evidence anchor; reply does not match expected coach move
- `lack-conviction-035` `deepAssessment`: `59/100` - deep assessment lacks verdict/evidence calibration
- `examples-from-sessions-010` `groundedRead`: `61/100` - no local failure reason
- `upcoming-conflict-028` `quickMove`: `61/100` - no local failure reason
