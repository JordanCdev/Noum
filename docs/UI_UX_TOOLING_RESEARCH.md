# UI, UX, testing, and observability tooling research

Research date: 2026-07-19

## Decision

Use Noum's existing native SwiftUI, XCTest/XCUITest, `FlowEventLog`, and Firebase architecture. Add no dependency in this phase.

The immediate problem was not a missing SDK. It was missing terminal-state coverage, incomplete trace correlation, and an under-explained coaching journey. The current change therefore extends the existing owners and adds a redacted in-app Debug trace viewer. A new vendor would add privacy, retention, release, and operational work before the trace schema is stable.

## Current repository fit

- UI: native SwiftUI with shared typography, color, spacing, card, accessibility, and motion patterns.
- Tests: Swift Testing/XCTest, XCUITest, simulator deep links, and the checked-in Coach Arena evaluation harness.
- Observability: `Logger`/OSLog, `AICallDiagnostics`, and a bounded, account-scoped, content-free `FlowEventLog`.
- Backend: existing Firebase Authentication, App Check, Functions, Firestore, Hosting, and guarded deployment scripts.
- Evaluation: checked-in coach fixtures, app-path generation, professional-calibration packets, and source-bound evidence sidecars.

## Codex skills and MCPs available in this environment

| Capability | Useful now | Decision |
| --- | --- | --- |
| `noum-screenshots` | Repeatable five-tab simulator captures and a reviewable handoff manifest | Adopt for this branch's light visual sweep. |
| Figma SwiftUI/design tools | Design-to-code or code-to-design when an authoritative Figma file exists | Defer. No Figma source was supplied; creating a detached parallel design system would weaken ownership. |
| Computer Use / in-app browser | Signed-in manual workflows and browser inspection | Reserve for external console work by an authorized operator. Simulator CLI/XCUITest is more deterministic for local gates. |
| GitHub plugin | PR, review-thread, and CI triage | Use after local gates if a PR is requested. It is not needed for local implementation. |
| Firebase skills/MCP | Firebase setup and service work | Existing checked-in Firebase scripts and release locks are authoritative here; do not route around them. |

## Tools evaluated

### Native Apple tooling — adopt

Apple's OS logging/signpost APIs can measure named intervals and expose them in Instruments without shipping transcript content. Continue using `Logger`; add `OSSignposter` only for performance intervals that need Instruments analysis, keeping the same opaque trace ID and categorical metadata. [Apple: Recording performance data](https://developer.apple.com/documentation/os/recording-performance-data)

XCUITest's accessibility audit can automatically check common problems including labels, hit regions, and contrast. It complements rather than replaces manual VoiceOver, Dynamic Type, dark-mode, and Reduce Motion passes. Add focused audits to stable journey roots after the new UI has settled. [Apple: Performing accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app)

### swift-snapshot-testing — pilot later, test target only

Point-Free's library is actively maintained; GitHub lists 1.19.3 as the latest release on 2026-07-08. It supports image and data snapshots and explicitly warns that the package should be added to a test target. It is a good candidate for a small pilot covering the transcript ladder and Debug trace card at fixed traits. Do not add it until reference-image ownership, simulator/OS pinning, and review policy are agreed; the current screenshot handoff already gives useful evidence without package churn. [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)

### Pulse — reject for this phase

Pulse 5.2.3 was released on 2026-06-10 and provides an on-device SwiftUI console for local logs and `URLSession` requests. It is maintained and useful for QA builds, but it overlaps the new Debug trace viewer and could retain request bodies or transcripts if integrated carelessly. Reconsider only as a DEBUG-only inspector with body capture disabled/redacted and an explicit deletion policy. [Pulse](https://github.com/kean/Pulse)

### Firebase Performance Monitoring — defer

Firebase custom traces measure duration and can carry custom metrics and attributes. This fits provider latency and time-to-first-visible-token, but enabling production collection changes telemetry and disclosure obligations. Keep local content-free traces until consent, retention, sampling, and exact attribute allowlists are approved. If adopted later, send only opaque trace IDs, enum labels, durations, counts, and status classes—never prompts, replies, transcripts, headers, or user-authored text. [Firebase custom code traces](https://firebase.google.com/docs/perf-mon/custom-code-traces)

### Firebase Crashlytics — defer to a launch-owned phase

Crashlytics can attach custom keys and record nonfatal errors, which could help group terminal failures by categorical code. It should not be used as a transcript/prompt store. Adoption requires explicit collection policy, safe-key tests, privacy-manifest/App Store disclosure review, and operator ownership. The current work keeps failures locally inspectable. [Firebase Crashlytics custom reports](https://firebase.google.com/docs/crashlytics/ios/customize-crash-reports)

### Langfuse — reject for client tracing; consider offline redacted evaluation only

Langfuse provides LLM traces and evaluation, but its documented default is indefinite retention; configurable retention is limited to paid tiers and enterprise self-hosting. Its self-hosted documentation recommends client-side masking when sensitive data must not leave the application and notes that server-side masking can fail open unless configured otherwise. That is a poor default for communication transcripts. A future backend/offline pilot must redact before transmission, fail closed, define deletion/retention, and exclude raw user speech. [Langfuse observability](https://langfuse.com/docs/observability/overview), [retention](https://langfuse.com/docs/administration/data-retention), [masking](https://langfuse.com/self-hosting/security/data-masking)

### Braintrust — reject for client tracing; consider evaluator experiments only

Braintrust supports trace inspection and systematic evaluation. It overlaps Coach Arena and would commonly receive inputs/outputs that are sensitive for Noum. A future comparison should use synthetic or explicitly consented, redacted backend fixtures and must demonstrate material evaluator value over the existing source-bound harness before adoption. [Braintrust traces](https://www.braintrust.dev/docs/observe/examine-traces), [evaluation](https://www.braintrust.dev/docs/evaluate), [security](https://www.braintrust.dev/docs/security)

### promptfoo or another generic prompt CI runner — reject for now

The existing Coach Arena already owns fixtures, Swift app-path execution, source fingerprints, transcript dumps, score floors, and launch artifacts. Adding a generic runner would duplicate the most important contracts while making current-Swift-path provenance harder to prove. Reconsider only if it can consume Coach Arena artifacts without becoming another source of truth.

## Adoption sequence

1. Now: redacted end-to-end `FlowEventLog` trace, Debug viewer, deterministic terminal-state tests, existing screenshot workflow.
2. Before external beta: focused XCUITest accessibility audits plus manual VoiceOver/Dynamic Type/dark-mode/Reduce Motion evidence.
3. Optional pilot: test-target-only snapshot testing on two stable journey components.
4. After consent and retention design: decide whether Firebase Performance/Crashlytics add operational value beyond native logs.
5. Only after a privacy review: compare a redacted backend/offline LLM evaluation vendor with Coach Arena. Do not add both Langfuse and Braintrust.

## Privacy invariants for any future tool

- No secrets, authorization headers, raw audio, full prompts, full replies, or raw transcripts by default.
- Redact before data crosses the app/backend boundary; server-side masking is only a second line of defense.
- Use an opaque trace ID, bounded categorical metadata, timing, counts, hashes, and terminal state.
- Document consent, collection control, retention, deletion, access, incident response, and App Store disclosure before enabling production telemetry.
- Keep release behavior functional when observability is disabled.
