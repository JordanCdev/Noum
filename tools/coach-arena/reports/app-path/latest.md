# Coach Arena Latest Report

- Generated: `2026-07-08T22:05:07+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-live-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `78.56/100`
- Passes score/coverage thresholds: `True`
- Real-pipeline evidence passes: `True`
- Evidence claim: `realPipelineEvidence`
- Trace quality passes: `True`
- Placeholder/fallback leaks: `0`
- Local fixture failures: `0`

## Report Lens and Canonical Paths

- Current report: `app-path`
- Current report path: `tools/coach-arena/reports/app-path/latest.md`
- Comparable prompt-layer report: `tools/coach-arena/reports/latest.md`
- Canonical app-path source of truth: `tools/coach-arena/reports/app-path/latest.md`
- Nested duplicate app-path path: stale duplicate present at tools/coach-arena/tools/coach-arena/reports/app-path/latest.json (generated 2026-07-05T23:09:49+00:00); ignore this path

## Type Averages

- `deepAssessment`: `80.67/100`
- `groundedRead`: `79.83/100`
- `quickMove`: `77.18/100`
- `trustRepair`: `77.22/100`

## VISION Readiness Boundary

- Production ready: `False`
- Score: `18/100`
- Maximum allowed score: `20/100`
- Claim: `localEvaluationSubstrateOnly`
- Blockers: `noLiveProviderTranscriptSweep`, `noProfessionalCoachCalibration`, `noRealUserLongitudinalTransferOutcomes`, `noRealDeviceTestFlightVerification`, `operationalLaunchChecklistIncomplete`

VISION production readiness 18/100; local target-shape 85/100; claim localEvaluationSubstrateOnly; blockers: noLiveProviderTranscriptSweep, noProfessionalCoachCalibration, noRealUserLongitudinalTransferOutcomes, noRealDeviceTestFlightVerification, operationalLaunchChecklistIncomplete.

## Trace Audit

- Real-pipeline trace fixtures: `50`
- Complete traces: `50`
- Missing-trace fixture count: `0`
- Candidate sources: `appPathReport` `50`

## Trace Quality

- Eligible real-pipeline traces: `50`
- Passes: `True`
- Unique proof-test hashes: `28`
- Max proof-test hash reuse: `4`
- Max proof-test hash reuse allowed: `10`
- Distinct rounded confidence values: `11`
- Empty retrieval-card traces: `0`
- Allowed empty retrieval-card traces: `43`
- Slow first-token traces: `0`

## Previous Run

- Status: `compared`
- Previous generated: `2026-07-08T22:04:17+00:00`
- Previous candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Candidate changed: `True`
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
- Source schema: `coach-chat-live-app-path-eval-v1`
- Source surface: `live`
- Source app-path floor: `True`
- Source app-path floor failures: `0`
- App-path local fixture floor: `True`
- Source target-reply mismatches: `0`
- Source app-path failure samples: `0` of `0`
- Source trace git commits: `da978b2f`
- Source traces missing git commit: `0`
- Current git commit: `da978b2f`
- Source trace coach fingerprints: `sha256:2b637c7f785df79623806d1b3a5ee7d6906fd8eb3777f8968d225b34aac58a08`
- Source traces missing coach fingerprint: `0`
- Current coach source fingerprint: `sha256:2b637c7f785df79623806d1b3a5ee7d6906fd8eb3777f8968d225b34aac58a08`
- Source fingerprint matches current: `True`
- Dirty coach source files: `5`
- Source freshness passes: `True`
- Coverage passes: `True`
- Requested fixtures: `50`
- Matched fixtures: `50`
- Unmatched fixtures: `0`
- Ambiguous fixtures: `0`

## Worst Fixtures

- `cold-generic-016` `trustRepair`: `70/100` - no local failure reason
- `pace-rushing-019` `groundedRead`: `70/100` - no local failure reason
- `confidence-clean-stop-025` `quickMove`: `70/100` - no local failure reason
- `not-easy-empathy-004` `trustRepair`: `71/100` - no local failure reason
- `filler-pressure-007` `quickMove`: `71/100` - no local failure reason
- `quote-guard-043` `groundedRead`: `71/100` - no local failure reason
- `interview-prep-006` `quickMove`: `72/100` - no local failure reason
- `leadership-transfer-capture-026` `quickMove`: `72/100` - no local failure reason
- `semantic-filler-use-040` `groundedRead`: `72/100` - no local failure reason
- `prompt-echo-041` `groundedRead`: `72/100` - no local failure reason
