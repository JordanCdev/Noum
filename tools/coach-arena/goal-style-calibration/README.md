# Goal-style score calibration packet

This tooling exports calibration candidates for professional review. It does
not enable a product score.

## Artifact

`goal-style-score-professional-calibration-v1.json` contains:

- the explicit rubric used for every case;
- a deterministic 0–100 candidate and per-dimension contributions;
- evidence depth, confidence, missing dimensions, and insufficiency reasons;
- opaque source-assessment and evidence-reference IDs;
- a formula fingerprint per candidate and a packet fingerprint for reviewer
  result binding.

The artifact excludes account identifiers, raw transcript, audio,
user-authored goal text, coach replies, and session content. Proposed goals are
permitted only as `proposedExplicitRubric`; they do not add a
`SpeakingStyleGoal` case or become a product claim.

The JSON packet is not sufficient evidence for a professional review. Every
opaque evidence-reference ID must resolve in a separately delivered source-
evidence package that is:

- blinded and deidentified;
- access-controlled by the calibration coordinator;
- fingerprinted as a complete package;
- kept outside this repository and its generated artifacts.

The default repository export is intentionally
`blockedPendingAccessControlledEvidencePackage`, with no package fingerprint.
It cannot accept reviewer results. The coordinator must regenerate the packet
with a `GoalStyleCalibrationEvidencePackageDescriptor` whose reference-ID set
exactly matches the packet and whose fingerprint is the SHA-256 digest of the
separately delivered package.

## Export

With a simulator available:

```sh
NOUM_COACH_EVAL_DUMP_DIR=/private/tmp/noum-coach-eval \
xcodebuild test \
  -project Noum.xcodeproj \
  -scheme Noum \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:NoumTests/CoachChatConversationArtifactDumpXCTest/testDumpGoalStyleCalibrationPacket
```

The XCTest bridge writes the sorted JSON artifact into
`NOUM_COACH_EVAL_DUMP_DIR`.

## Reviewer-result binding

Reviewer rows must use schema
`goal-style-score-professional-calibration-results-v1` and echo all of:

- the packet fingerprint;
- the separate evidence-package fingerprint;
- the calibration case ID;
- the candidate formula fingerprint.

Each row must also carry a coordinator-issued evidence-package access receipt
ID and set `reviewerAttestsEvidenceWasReviewed` to `true`. A review based only
on this repository packet is invalid.

Every calibration case requires at least three distinct reviewers whose role is
exactly `professional-communication-coach`. Each row must provide the complete
rubric-dimension key set, using an integer from 0 through 100 or `null` when the
dimension is unjudgeable. `overclaimRisk` is limited to `low`, `medium`, or
`high`; notes are bounded to 2,000 characters; and one coordinator access
receipt cannot be attributed to different reviewers.

`GoalStyleCalibrationPacket.rejectionReasons(for:)` rejects an unbound evidence
package, an evidence-package mismatch, empty or partial case coverage,
insufficient reviewer independence, malformed review rows, missing evidence-
review attestation, missing or shared access receipts, and stale packet/formula
fingerprints. Negative professional judgments remain structurally valid
calibration evidence: the validator does not turn disagreement into approval or
discard it. A completed review packet remains calibration evidence, not
authorization for user-facing numeric scoring; a separate product/privacy
decision and longitudinal transfer evidence are still required.
