# Coach Arena Latest Report

- Generated: `2026-07-08T00:34:25+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `73.8/100`
- Passes score/coverage thresholds: `True`
- Production evidence passes: `True`
- Evidence claim: `realPipelineEvidence`
- Trace quality passes: `True`
- Placeholder leaks: `0`

## Type Averages

- `deepAssessment`: `76.0/100`
- `groundedRead`: `76.5/100`
- `quickMove`: `68.76/100`
- `trustRepair`: `76.44/100`

## Trace Audit

- Real-pipeline trace fixtures: `50`
- Complete traces: `50`
- Missing-trace fixture count: `0`
- Candidate sources: `appPathReport` `50`

## Trace Quality

- Eligible real-pipeline traces: `50`
- Passes: `True`
- Unique proof-test hashes: `9`
- Max proof-test hash reuse: `9`
- Max proof-test hash reuse allowed: `10`
- Distinct rounded confidence values: `10`
- Empty retrieval-card traces: `0`
- Allowed empty retrieval-card traces: `39`
- Slow first-token traces: `0`

## Previous Run

- Status: `compared`
- Previous generated: `2026-07-08T00:24:02+00:00`
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
- Source app-path floor: `False`
- Coverage passes: `True`
- Requested fixtures: `50`
- Matched fixtures: `50`
- Unmatched fixtures: `0`
- Ambiguous fixtures: `0`

## Worst Fixtures

- `upcoming-conflict-028` `quickMove`: `50/100` - fixture disqualifier triggered: too broad; fixture-specific disqualifier triggered; missing evidence anchor; reply does not match expected coach move
- `sales-pitch-031` `quickMove`: `50/100` - missing evidence anchor; reply does not match expected coach move
- `placeholder-leak-049` `quickMove`: `50/100` - reply does not match expected coach move
- `lack-conviction-035` `deepAssessment`: `59/100` - deep assessment lacks verdict/evidence calibration
- `grammar-leak-048` `quickMove`: `60/100` - no local failure reason
- `examples-from-sessions-010` `groundedRead`: `61/100` - no local failure reason
- `networking-intro-029` `quickMove`: `63/100` - no local failure reason
- `evasive-polished-037` `deepAssessment`: `63/100` - no local failure reason
- `live-latency-short-044` `quickMove`: `63/100` - no local failure reason
- `real-world-outcome-047` `groundedRead`: `67/100` - no local failure reason
