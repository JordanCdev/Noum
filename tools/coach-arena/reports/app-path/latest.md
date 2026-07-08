# Coach Arena Latest Report

- Generated: `2026-07-08T14:19:03+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `74.54/100`
- Passes score/coverage thresholds: `True`
- Real-pipeline evidence passes: `False`
- Evidence claim: `localEvaluationOnly`
- Trace quality passes: `True`
- Placeholder leaks: `0`

## Type Averages

- `deepAssessment`: `78.0/100`
- `groundedRead`: `76.5/100`
- `quickMove`: `70.18/100`
- `trustRepair`: `76.56/100`

## VISION Readiness Boundary

- Production ready: `False`
- Score: `18/100`
- Maximum allowed score: `20/100`
- Claim: `localEvaluationSubstrateOnly`
- Blockers: `noLiveProviderTranscriptSweep`, `noProfessionalCoachCalibration`, `noRealUserLongitudinalTransferOutcomes`, `noRealDeviceTestFlightVerification`, `operationalLaunchChecklistIncomplete`

VISION production readiness 18/100; local target-shape 86/100; claim localEvaluationSubstrateOnly; blockers: noLiveProviderTranscriptSweep, noProfessionalCoachCalibration, noRealUserLongitudinalTransferOutcomes, noRealDeviceTestFlightVerification, operationalLaunchChecklistIncomplete.

## Real-Pipeline Evidence

- `source Swift app-path readiness warnings: appPathFloorFailures,targetReplyMismatch`
- `source Swift app-path report did not pass its app-path floor`

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
- Allowed empty retrieval-card traces: `3`
- Slow first-token traces: `0`

## Previous Run

- Status: `compared`
- Previous generated: `2026-07-08T14:03:33+00:00`
- Previous candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Candidate changed: `False`
- Fixture count changed: `False`
- Average delta: `0.04`
- Failure count delta: `0`
- Placeholder leak delta: `0`
- Pass state changed: `False`
- Type average deltas: `deepAssessment` `0.33`, `groundedRead` `0.0`, `quickMove` `0.0`, `trustRepair` `0.0`
- Cleared failures: `none`
- New failures: `none`

## Coverage

- Source: `appPathReport`
- Source schema: `coach-chat-conversation-app-path-eval-v1`
- Source surface: `text`
- Source app-path floor: `False`
- Source app-path floor failures: `1`
- Source target-reply mismatches: `1`
- Source app-path failure samples: `1` of `1`
- Coverage passes: `True`
- Requested fixtures: `50`
- Matched fixtures: `50`
- Unmatched fixtures: `0`
- Ambiguous fixtures: `0`

### Source App-Path Failure Samples

- `filler-pressure-prescription` / `not-easy-empathy-conversation` turn `1`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:deterministicAssessmentAfterContentRejected`

## Worst Fixtures

- `placeholder-leak-049` `quickMove`: `50/100` - reply does not match expected coach move
- `upcoming-conflict-028` `quickMove`: `57/100` - no local failure reason
- `evasive-polished-037` `deepAssessment`: `60/100` - fixture disqualifier triggered: personality judgment; fixture-specific disqualifier triggered
- `grammar-leak-048` `quickMove`: `60/100` - no local failure reason
- `examples-from-sessions-010` `groundedRead`: `61/100` - no local failure reason
- `networking-intro-029` `quickMove`: `63/100` - no local failure reason
- `live-latency-short-044` `quickMove`: `63/100` - no local failure reason
- `sales-pitch-031` `quickMove`: `67/100` - no local failure reason
- `real-world-outcome-047` `groundedRead`: `67/100` - no local failure reason
- `outcome-not-causation-027` `groundedRead`: `69/100` - no local failure reason
