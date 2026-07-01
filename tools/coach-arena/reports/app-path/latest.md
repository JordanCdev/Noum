# Coach Arena Latest Report

- Generated: `2026-07-01T00:06:22+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `68.54/100`
- Passes score/coverage thresholds: `False`
- Production evidence passes: `True`
- Evidence claim: `realPipelineEvidence`
- Trace quality passes: `True`
- Placeholder leaks: `0`

## Type Averages

- `deepAssessment`: `75.5/100`
- `groundedRead`: `63.33/100`
- `quickMove`: `67.41/100`
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
- Distinct rounded confidence values: `4`
- Empty retrieval-card traces: `0`
- Allowed empty retrieval-card traces: `3`
- Slow first-token traces: `0`

## Previous Run

- Status: `compared`
- Previous generated: `2026-06-30T23:58:49+00:00`
- Previous candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Candidate changed: `False`
- Fixture count changed: `False`
- Average delta: `0.5`
- Failure count delta: `-1`
- Placeholder leak delta: `0`
- Pass state changed: `False`
- Type average deltas: `deepAssessment` `0.0`, `groundedRead` `0.0`, `quickMove` `0.0`, `trustRepair` `2.77`
- Cleared failures: `assistant-wrapper-050`
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

- `examples-from-sessions-010` `groundedRead`: `50/100` - fixture disqualifier triggered: no example; fixture-specific disqualifier triggered; reply does not match expected coach move
- `outcome-not-causation-027` `groundedRead`: `50/100` - reply does not match expected coach move
- `networking-intro-029` `quickMove`: `50/100` - reply does not match expected coach move
- `presentation-nerves-030` `groundedRead`: `50/100` - reply does not match expected coach move
- `sales-pitch-031` `quickMove`: `50/100` - reply does not match expected coach move
- `fear-disagreement-034` `groundedRead`: `50/100` - reply does not match expected coach move
- `lack-conviction-035` `deepAssessment`: `50/100` - deep assessment lacks verdict/evidence calibration; reply does not match expected coach move
- `emotional-disconnection-036` `groundedRead`: `50/100` - fixture disqualifier triggered: no reflection check; fixture-specific disqualifier triggered; reply does not match expected coach move
- `semantic-filler-use-040` `groundedRead`: `50/100` - fixture disqualifier triggered: no adjusted rule; fixture-specific disqualifier triggered; low-EQ reply: emotional signal is not acknowledged; reply does not match expected coach move
- `prompt-echo-041` `groundedRead`: `50/100` - fixture disqualifier triggered: no fairness boundary; fixture-specific disqualifier triggered; reply does not match expected coach move
