# Coach Arena Latest Report

- Generated: `2026-07-12T21:30:07+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `79.76/100`
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
- `groundedRead`: `80.44/100`
- `quickMove`: `78.76/100`
- `trustRepair`: `79.67/100`

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
- Unique proof-test hashes: `30`
- Max proof-test hash reuse: `5`
- Max proof-test hash reuse allowed: `10`
- Unique final-reply hashes: `50`
- Max final-reply hash reuse: `1`
- Distinct rounded confidence values: `11`
- Trajectory-cache hits: `3`
- Trajectory-cache hits required: `1`
- Missing trajectory-cache telemetry: `0`
- Empty retrieval-card traces: `0`
- Allowed empty retrieval-card traces: `40`
- Slow first-token traces: `0`

## Previous Run

- Status: `compared`
- Previous generated: `2026-07-12T20:53:57+00:00`
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
- Source app-path floor failures: `0`
- App-path local fixture floor: `True`
- Source target-reply mismatches: `0`
- Source app-path failure samples: `0` of `0`
- Source trace git commits: `5aa6b8ff`
- Source traces missing git commit: `0`
- Current git commit: `5aa6b8ff`
- Source trace coach fingerprints: `sha256:deab3935f807243486dcf41c1652880bb5875744bed621a1866be8a20d252b8e`
- Source traces missing coach fingerprint: `0`
- Current coach source fingerprint: `sha256:deab3935f807243486dcf41c1652880bb5875744bed621a1866be8a20d252b8e`
- Source fingerprint matches current: `True`
- Dirty coach source files: `7`
- Source freshness passes: `True`
- Coverage passes: `True`
- Requested fixtures: `50`
- Matched fixtures: `50`
- Unmatched fixtures: `0`
- Ambiguous fixtures: `0`

## Worst Fixtures

- `confidence-clean-stop-025` `quickMove`: `70/100` - no local failure reason
- `not-informative-trust-repair-002` `trustRepair`: `71/100` - no local failure reason
- `quote-guard-043` `groundedRead`: `71/100` - no local failure reason
- `confidence-ending-009` `groundedRead`: `72/100` - no local failure reason
- `leadership-transfer-capture-026` `quickMove`: `72/100` - no local failure reason
- `semantic-filler-use-040` `groundedRead`: `72/100` - no local failure reason
- `prompt-echo-041` `groundedRead`: `72/100` - no local failure reason
- `grammar-leak-048` `quickMove`: `73/100` - no local failure reason
- `leadership-update-008` `quickMove`: `74/100` - no local failure reason
- `closing-ask-020` `quickMove`: `74/100` - no local failure reason
