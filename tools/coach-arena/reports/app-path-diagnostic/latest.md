# Coach Arena Latest Report

- Generated: `2026-07-22T21:18:38+00:00`
- Candidate: `/private/tmp/noum-coach-arena-current.CmFX8Q/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `81.16/100`
- Passes score/coverage thresholds: `True`
- Real-pipeline evidence passes: `False`
- Evidence claim: `localEvaluationOnly`
- Trace quality passes: `True`
- Placeholder/fallback leaks: `0`
- Local fixture failures: `0`

## Report Lens and Canonical Paths

- Current report: `app-path`
- Current report path: `tools/coach-arena/reports/app-path-diagnostic/latest.md`
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

## Real-Pipeline Evidence

- `source Swift app-path freshness: dirty coach source files after app-path dump: .gitleaks.toml,.screenshots/2026-07-22_ui-polish/Archive.zip,AppStore/README.md,AppStore/aso-experiment.template.json,AppStore/commercial-reconciliation.md,AppStore/commercial-reconciliation.template.json,AppStore/launch-gates.md,AppStore/metadata/en-GB.json,+121 more`
- `source Swift app-path freshness: unfingerprinted dirty behavior source: .gitleaks.toml,.screenshots/2026-07-22_ui-polish/Archive.zip,AppStore/README.md,AppStore/aso-experiment.template.json,AppStore/commercial-reconciliation.md,AppStore/commercial-reconciliation.template.json,AppStore/launch-gates.md,AppStore/metadata/en-GB.json,+115 more`

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
- Trajectory-cache hits: `30`
- Trajectory-cache hits required: `1`
- Missing trajectory-cache telemetry: `0`
- Empty retrieval-card traces: `0`
- Allowed empty retrieval-card traces: `39`
- Slow first-token traces: `0`

## Previous Run

- Status: `compared`
- Previous generated: `2026-07-10T03:37:43+00:00`
- Previous candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Candidate changed: `True`
- Fixture count changed: `False`
- Average delta: `1.38`
- Failure count delta: `0`
- Placeholder leak delta: `0`
- Pass state changed: `False`
- Type average deltas: `deepAssessment` `2.83`, `groundedRead` `2.39`, `quickMove` `1.71`, `trustRepair` `-2.23`
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
- Source trace git commits: `d90bb8922`
- Source traces missing git commit: `0`
- Current git commit: `d90bb8922`
- Source trace coach fingerprints: `sha256:fbfd50448e59ee42b191b650f79f0e5af7683c51bdea4a4a05b2ba678ba5f563`
- Source traces missing coach fingerprint: `0`
- Current coach source fingerprint: `sha256:fbfd50448e59ee42b191b650f79f0e5af7683c51bdea4a4a05b2ba678ba5f563`
- Source fingerprint matches current: `True`
- Dirty coach source files: `129`
- Source freshness passes: `False`
- Coverage passes: `True`
- Requested fixtures: `50`
- Matched fixtures: `50`
- Unmatched fixtures: `0`
- Ambiguous fixtures: `0`
- Source freshness failures: `dirty coach source files after app-path dump: .gitleaks.toml,.screenshots/2026-07-22_ui-polish/Archive.zip,AppStore/README.md,AppStore/aso-experiment.template.json,AppStore/commercial-reconciliation.md,AppStore/commercial-reconciliation.template.json,AppStore/launch-gates.md,AppStore/metadata/en-GB.json,+121 more`; `unfingerprinted dirty behavior source: .gitleaks.toml,.screenshots/2026-07-22_ui-polish/Archive.zip,AppStore/README.md,AppStore/aso-experiment.template.json,AppStore/commercial-reconciliation.md,AppStore/commercial-reconciliation.template.json,AppStore/launch-gates.md,AppStore/metadata/en-GB.json,+115 more`

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
