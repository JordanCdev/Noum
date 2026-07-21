# Coach Arena Latest Report

- Generated: `2026-07-21T08:38:18+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `81.16/100`
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

- `deepAssessment`: `83.5/100`
- `groundedRead`: `82.89/100`
- `quickMove`: `80.47/100`
- `trustRepair`: `77.44/100`

## VISION Readiness Boundary

- Production ready: `False`
- Score: `20/100`
- Maximum allowed score: `20/100`
- Claim: `localEvaluationSubstrateOnly`
- Blockers: `noLiveProviderTranscriptSweep`, `noProfessionalCoachCalibration`, `noRealUserLongitudinalTransferOutcomes`, `noRealDeviceTestFlightVerification`, `operationalLaunchChecklistIncomplete`

VISION production readiness 20/100; local target-shape 90/100; claim localEvaluationSubstrateOnly; blockers: noLiveProviderTranscriptSweep, noProfessionalCoachCalibration, noRealUserLongitudinalTransferOutcomes, noRealDeviceTestFlightVerification, operationalLaunchChecklistIncomplete.

## Trace Audit

- Real-pipeline trace fixtures: `50`
- Complete traces: `50`
- Missing-trace fixture count: `0`
- Candidate sources: `appPathReport` `50`

## Trace Quality

- Eligible real-pipeline traces: `50`
- Passes: `True`
- Styled assessment traces: `18`
- Declared-neutral assessment traces: `32`
- Invalid assessment-provenance traces: `0`
- Unique proof-test hashes: `12`
- Max proof-test hash reuse: `4`
- Max proof-test hash reuse allowed: `4`
- Unique final-reply hashes: `50`
- Max final-reply hash reuse: `1`
- Distinct rounded confidence values: `4`
- Trajectory-cache hits: `3`
- Trajectory-cache hits required: `1`
- Missing trajectory-cache telemetry: `0`
- Empty retrieval-card traces: `0`
- Allowed empty retrieval-card traces: `39`
- Slow first-token traces: `0`

## Previous Run

- Status: `compared`
- Previous generated: `2026-07-20T18:42:37+00:00`
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
- Source trace git commits: `6a27e42cd`
- Source traces missing git commit: `0`
- Current git commit: `6a27e42cd`
- Source trace coach fingerprints: `sha256:380608d818a505a4e30c749233c03f82f4e6df04b749e1d92f4123a6bebcc038`
- Source traces missing coach fingerprint: `0`
- Current coach source fingerprint: `sha256:380608d818a505a4e30c749233c03f82f4e6df04b749e1d92f4123a6bebcc038`
- Source fingerprint matches current: `True`
- Dirty coach source files: `0`
- Source freshness passes: `True`
- Coverage passes: `True`
- Requested fixtures: `50`
- Matched fixtures: `50`
- Unmatched fixtures: `0`
- Ambiguous fixtures: `0`

## Worst Fixtures

- `not-easy-empathy-004` `trustRepair`: `75/100` - no local failure reason
- `concise-answer-023` `quickMove`: `75/100` - no local failure reason
- `barge-in-045` `trustRepair`: `75/100` - no local failure reason
- `grammar-leak-048` `quickMove`: `75/100` - no local failure reason
- `not-informative-trust-repair-002` `trustRepair`: `77/100` - no local failure reason
- `polite-however-pushback-003` `trustRepair`: `77/100` - no local failure reason
- `markdown-tts-015` `trustRepair`: `77/100` - no local failure reason
- `too-much-writing-017` `trustRepair`: `77/100` - no local failure reason
- `authoritative-distance-001` `deepAssessment`: `78/100` - no local failure reason
- `filler-pressure-007` `quickMove`: `78/100` - no local failure reason
