#!/usr/bin/env python3
"""Fail-closed operator workflow for Noum's externally earned release evidence.

This module deliberately does not decide whether Noum is production ready. It
binds an evidence-collection run to current source, adds operator-side proof and
independence checks, and delegates the artifact contracts to coach-arena's
existing readiness validator before promotion.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath


TOOL_ROOT = Path(__file__).resolve().parent
REPO_ROOT = TOOL_ROOT.parents[1]
TEMPLATE_ROOT = TOOL_ROOT / "templates"
GATE_PATH = REPO_ROOT / "tools" / "coach-arena" / "runners" / "readiness_gate.py"
RUN_MANIFEST_FILE = "release-evidence-run-v1.json"
RUN_SCHEMA = "noum-release-evidence-run-v1"
PACKET_FILE = "coach-chat-conversation-expert-calibration-v2.json"
SOURCE_FILES = ("source-git-commit.txt", "source-coach-fingerprint.txt")
MANAGED_ARTIFACTS = {
    "professionalCalibration": (
        "coach-chat-conversation-expert-calibration-results-v2.json",
        "noProfessionalCoachCalibration",
    ),
    "realUserTransfer": (
        "coach-real-user-transfer-outcomes-v3.json",
        "noRealUserLongitudinalTransferOutcomes",
    ),
    "realDeviceTestFlight": (
        "coach-real-device-testflight-qa-v2.json",
        "noRealDeviceTestFlightVerification",
    ),
    "operationalLaunch": (
        "coach-operational-launch-checklist-v2.json",
        "operationalLaunchChecklistIncomplete",
    ),
}
TEMPLATE_FILES = {
    "professionalCalibration": "professional-calibration.json",
    "realUserTransfer": "real-user-transfer.json",
    "realDeviceTestFlight": "real-device-testflight.json",
    "operationalLaunch": "operational-launch.json",
}
PLACEHOLDER_VALUES = {
    "", "n/a", "na", "none", "todo", "tbd", "placeholder", "unknown",
    "example", "sample", "test", "fake",
}
EVIDENCE_REFERENCE_PREFIX = "evidence://"
SHA256_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")
OPERATIONAL_PREREQUISITES = {
    "cloudOperationsProbePassed": {
        "evidenceKind": "cloudOperationsProbeOutput",
        "environment": "production",
    },
    "historicalCredentialIncidentClosed": {
        "evidenceKind": "credentialIncidentClosure",
        "environment": "production",
    },
    "legacyTranscriptionEndpointProtectedOrDisabled": {
        "evidenceKind": "legacyEndpointVerification",
        "environment": "production",
    },
    "exposedProviderCredentialsRevoked": {
        "evidenceKind": "providerCredentialRevocation",
        "environment": "productionProvider",
    },
    "providerUsageAndBillingAuditComplete": {
        "evidenceKind": "providerUsageBillingAudit",
        "environment": "productionProvider",
    },
    "fullHistorySecretFindingsAdjudicated": {
        "evidenceKind": "fullHistorySecretReview",
        "environment": "repositoryHistory",
    },
    "releaseBundleSecretScanPassed": {
        "evidenceKind": "releaseBundleSecretScan",
        "environment": "releaseCandidate",
    },
    "protectedSocialCutoverCompleted": {
        "evidenceKind": "protectedSocialCutover",
        "environment": "production",
    },
    "socialMigrationDryRunPassed": {
        "evidenceKind": "socialMigrationDryRun",
        "environment": "production",
    },
    "trustedSocialEvidenceProducerDeployed": {
        "evidenceKind": "trustedSocialEvidenceProducer",
        "environment": "production",
    },
    "customPrivacyDomainVerified": {
        "evidenceKind": "customPrivacyDomainVerification",
        "environment": "production",
    },
    "appleReleaseServicesConfigured": {
        "evidenceKind": "appleReleaseServicesConfiguration",
        "environment": "appStoreConnect",
    },
}
OPERATIONAL_PREREQUISITE_REQUIRED_FIELDS = {
    "key", "completed", "evidenceReference", "evidenceKind",
    "verificationReference", "commandOrReviewOutputReference",
    "releaseCandidateBuild", "environment", "completedAtISO8601",
    "performedByID", "verifiedAtISO8601", "verifiedByID",
    "verifiedByRole", "notes",
}
HISTORY_SECRET_SCANNER = "gitleaks"
HISTORY_SECRET_SCANNER_VERSION = "8.30.1"
HISTORY_SECRET_SCAN_SCOPE = "all-reachable-commits"
HISTORY_SECRET_MIN_KNOWN_FINDINGS = 3
HISTORY_SECRET_REPORT_MAX_BYTES = 25 * 1024 * 1024
KNOWN_HISTORY_CREDENTIAL_COMMITS = {
    "277e2b388bb17d603011277a819b0bcaae517404",
}
HISTORY_SECRET_DISPOSITION_EVIDENCE_KINDS = {
    "revoked": "secretFindingRevocation",
    "invalidated": "secretFindingInvalidation",
    "falsePositive": "secretFindingFalsePositiveReview",
    "publicIdentifier": "secretFindingPublicIdentifierReview",
}
HISTORY_SECRET_ADJUDICATION_REQUIRED_FIELDS = {
    "scanner", "scannerVersion", "scanScope", "scannedRepositoryCommit",
    "redactionPercent", "reachableCommitCount", "reachableCommitSetSha256",
    "redactedScanReportReference", "detectedFindingCount",
    "adjudicatedFindingCount", "unresolvedFindingCount",
    "suppressedFindingCount", "findings",
}
HISTORY_SECRET_FINDING_REQUIRED_FIELDS = {
    "findingID", "detectorRuleID", "commit", "path", "disposition",
    "statusEvidenceReference",
}


def load_gate():
    spec = importlib.util.spec_from_file_location("noum_readiness_gate", GATE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load readiness validator at {GATE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


GATE = load_gate()


class WorkflowError(RuntimeError):
    pass


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise WorkflowError(f"missing file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise WorkflowError(f"invalid JSON in {path}: {exc.msg}") from exc


def write_json(path: Path, payload):
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def usable_text(value) -> bool:
    return (
        isinstance(value, str)
        and value.strip().lower() not in PLACEHOLDER_VALUES
    )


def parse_iso8601(value):
    if not usable_text(value):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo is not None else None


def valid_iso8601(value) -> bool:
    return parse_iso8601(value) is not None


def strict_nonnegative_int(value):
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        return None
    return value


def history_secret_finding_id(report_row):
    canonical = {
        "commit": report_row["Commit"],
        "path": report_row["File"],
        "ruleID": report_row["RuleID"],
        "startLine": report_row["StartLine"],
    }
    serialized = json.dumps(
        canonical, sort_keys=True, separators=(",", ":"), ensure_ascii=True,
    ).encode("ascii")
    return "sha256:" + hashlib.sha256(serialized).hexdigest()


def add_failure(failures, code, detail=None):
    rendered = code if detail is None else f"{code}:{detail}"
    if rendered not in failures:
        failures.append(rendered)


def current_source_binding(repo_root: Path):
    commit = GATE.current_git_commit(repo_root)
    fingerprint = GATE.coach_source_fingerprint(repo_root)
    if not commit or not fingerprint:
        raise WorkflowError("could not determine current source commit and coach fingerprint")
    dirty = GATE.current_dirty_coach_source_files(repo_root)
    if dirty:
        raise WorkflowError(
            "coach source is dirty; refresh and export source sidecars only after "
            f"the source is stable ({', '.join(dirty)})"
        )
    return {
        "sourceGitCommit": commit,
        "sourceCoachFingerprint": fingerprint,
    }


def reachable_commit_set_binding(repo_root: Path):
    try:
        result = subprocess.run(
            ["git", "-C", str(repo_root), "rev-list", "--all"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        raise WorkflowError("could not enumerate all reachable git commits") from exc
    commits = sorted(set(line.strip() for line in result.stdout.splitlines() if line.strip()))
    if not commits or any(not re.fullmatch(r"[0-9a-f]{40}", commit) for commit in commits):
        raise WorkflowError("reachable git commit inventory is empty or malformed")
    serialized = ("\n".join(commits) + "\n").encode("ascii")
    return {
        "reachableCommitCount": len(commits),
        "reachableCommitSetSha256": "sha256:" + hashlib.sha256(serialized).hexdigest(),
        "commits": set(commits),
    }


def source_dump_binding(source_dump: Path):
    values = {}
    for file_name in SOURCE_FILES:
        path = source_dump / file_name
        if not path.is_file():
            raise WorkflowError(f"source dump is missing {file_name}: {source_dump}")
        value = path.read_text(encoding="utf-8", errors="replace").strip()
        if not usable_text(value):
            raise WorkflowError(f"source dump contains an empty {file_name}")
        values[file_name] = value
    return {
        "sourceGitCommit": values["source-git-commit.txt"],
        "sourceCoachFingerprint": values["source-coach-fingerprint.txt"],
    }


def assert_source_dump_is_current(source_dump: Path, repo_root: Path):
    current = current_source_binding(repo_root)
    exported = source_dump_binding(source_dump)
    if exported != current:
        raise WorkflowError(
            "source dump sidecars do not match the current checkout: "
            f"exported={exported}, current={current}"
        )
    packet = source_dump / PACKET_FILE
    if not packet.is_file():
        raise WorkflowError(f"source dump is missing exported calibration packet: {packet}")
    packet_context = GATE.calibration_packet_context(source_dump)
    if packet_context.get("packetFailures"):
        raise WorkflowError(
            "exported calibration packet failed the existing readiness validator: "
            + ", ".join(packet_context["packetFailures"])
        )
    return current, packet_context


def calibration_review_slots(packet, result_template):
    rows = packet.get("rows") if isinstance(packet.get("rows"), list) else []
    reviews_per_conversation = packet.get("requiredIndependentReviewsPerConversation")
    if not isinstance(reviews_per_conversation, int) or reviews_per_conversation <= 0:
        raise WorkflowError("calibration packet has no valid independent-review count")
    slots = []
    for packet_row in rows:
        conversation_id = packet_row.get("conversationID") if isinstance(packet_row, dict) else None
        if not usable_text(conversation_id):
            raise WorkflowError("calibration packet contains a row without conversationID")
        for slot in range(1, reviews_per_conversation + 1):
            slots.append({
                "conversationID": conversation_id,
                "reviewSlot": slot,
                "reviewerID": "",
                "calibrationDecision": "notReviewed",
                "wouldUseWithClient": False,
                "ratings": {
                    "diagnosis": None,
                    "caseFormulation": None,
                    "intervention": None,
                    "adaptation": None,
                    "perceptionHonesty": None,
                    "transferSetup": None,
                    "trustRepair": None,
                    "overallUsefulness": None,
                },
                "humanCoachReferenceCount": 0,
                "humanCoachReference": [],
                "overclaimNotes": [],
                "revisionNotes": ["reviewNotCompleted"],
            })
    result_template["sourcePacketFingerprint"] = packet.get("sourceCorpusFingerprint", "")
    result_template["reviewCount"] = len(slots)
    result_template["summary"]["rowCount"] = len(slots)
    result_template["rows"] = slots
    return result_template


def initialize_run(args):
    run_dir = Path(args.run_dir).expanduser().resolve()
    source_dump = Path(args.source_dump).expanduser().resolve()
    repo_root = Path(args.repo_root).expanduser().resolve()
    if run_dir.exists() and any(run_dir.iterdir()):
        raise WorkflowError(f"run directory is not empty: {run_dir}")
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "attachments").mkdir(exist_ok=True)

    current, packet_context = assert_source_dump_is_current(source_dump, repo_root)
    for file_name in SOURCE_FILES:
        shutil.copy2(source_dump / file_name, run_dir / file_name)
    shutil.copy2(source_dump / PACKET_FILE, run_dir / PACKET_FILE)

    packet = read_json(run_dir / PACKET_FILE)
    for key, (artifact_name, _) in MANAGED_ARTIFACTS.items():
        template = read_json(TEMPLATE_ROOT / TEMPLATE_FILES[key])
        if key == "professionalCalibration":
            template = calibration_review_slots(packet, template)
        elif key == "operationalLaunch":
            reachable = reachable_commit_set_binding(repo_root)
            template["historySecretAdjudication"].update({
                "scannedRepositoryCommit": current["sourceGitCommit"],
                "reachableCommitCount": reachable["reachableCommitCount"],
                "reachableCommitSetSha256": reachable["reachableCommitSetSha256"],
            })
        write_json(run_dir / artifact_name, template)

    manifest = {
        "schemaVersion": RUN_SCHEMA,
        "runStatus": "COLLECTING_NOT_RELEASE_EVIDENCE",
        "initializedAtISO8601": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "initializedBy": {
            "id": args.initialized_by_id or "",
            "role": args.initialized_by_role or "",
        },
        "sourceBinding": {
            **current,
            "sourceDump": str(source_dump),
            "calibrationPacketSchemaVersion": packet_context.get("sourcePacketSchemaVersion"),
            "calibrationPacketFingerprint": packet_context.get("sourcePacketFingerprint"),
            "calibrationPacketSha256": sha256_file(run_dir / PACKET_FILE),
        },
        "evidenceIndex": [],
        "promotionApproval": {
            "approvedByID": "",
            "approvedByRole": "",
            "approvedAtISO8601": "",
            "approvalReference": "",
            "attestsEvidenceIsExternalOrOperational": False,
            "attestsNoSyntheticFixtureWasUsed": False,
        },
    }
    write_json(run_dir / RUN_MANIFEST_FILE, manifest)
    (run_dir / "attachments" / "README.txt").write_text(
        "Register real evidence with the register-attachment command.\n"
        "Do not place participant names, raw speech, unredacted StoreKit receipts, "
        "credentials, or secrets in this directory.\n",
        encoding="utf-8",
    )
    print(f"Initialized non-passing evidence run: {run_dir}")
    print("All four artifacts remain NOT_PRODUCTION_EVIDENCE until real collection is complete.")


def load_manifest(run_dir: Path):
    payload = read_json(run_dir / RUN_MANIFEST_FILE)
    if not isinstance(payload, dict) or payload.get("schemaVersion") != RUN_SCHEMA:
        raise WorkflowError(f"invalid {RUN_MANIFEST_FILE} schema")
    return payload


def safe_attachment_path(run_dir: Path, relative_path):
    if not usable_text(relative_path):
        return None
    candidate = run_dir / relative_path
    try:
        resolved = candidate.resolve(strict=True)
    except (FileNotFoundError, RuntimeError):
        return None
    attachment_root = (run_dir / "attachments").resolve()
    try:
        resolved.relative_to(attachment_root)
    except ValueError:
        return None
    if candidate.is_symlink() or not resolved.is_file() or resolved.stat().st_size <= 0:
        return None
    return resolved


def evidence_index_by_id(manifest, failures):
    entries = manifest.get("evidenceIndex")
    if not isinstance(entries, list):
        add_failure(failures, "evidenceIndexInvalid")
        return {}
    index = {}
    for position, entry in enumerate(entries):
        if not isinstance(entry, dict):
            add_failure(failures, "evidenceIndexEntryInvalid", position)
            continue
        evidence_id = entry.get("id")
        if not usable_text(evidence_id) or not re.fullmatch(r"[a-z0-9][a-z0-9._-]{2,80}", evidence_id):
            add_failure(failures, "evidenceIndexIDInvalid", position)
            continue
        if evidence_id in index:
            add_failure(failures, "evidenceIndexDuplicateID", evidence_id)
        index[evidence_id] = entry
    return index


def validate_reference(reference, expected_kind, run_dir, index, failures, label):
    if not isinstance(reference, str) or not reference.startswith(EVIDENCE_REFERENCE_PREFIX):
        add_failure(failures, "unindexedEvidenceReference", label)
        return None
    evidence_id = reference[len(EVIDENCE_REFERENCE_PREFIX):]
    entry = index.get(evidence_id)
    if not entry:
        add_failure(failures, "missingEvidenceIndexEntry", f"{label}={evidence_id}")
        return None
    path = safe_attachment_path(run_dir, entry.get("path"))
    if path is None:
        add_failure(failures, "attachmentMissingEmptyOrUnsafe", f"{label}={evidence_id}")
        return None
    if expected_kind and entry.get("kind") != expected_kind:
        add_failure(
            failures,
            "attachmentKindMismatch",
            f"{label}={entry.get('kind')} expected {expected_kind}",
        )
    expected_sha = entry.get("sha256")
    actual_sha = sha256_file(path)
    if not SHA256_PATTERN.fullmatch(expected_sha or "") or expected_sha != actual_sha:
        add_failure(failures, "attachmentHashMismatch", f"{label}={evidence_id}")
    if not valid_iso8601(entry.get("capturedAtISO8601")):
        add_failure(failures, "attachmentCapturedAtInvalid", f"{label}={evidence_id}")
    if not usable_text(entry.get("verifiedByID")):
        add_failure(failures, "attachmentVerifierMissing", f"{label}={evidence_id}")
    return entry


def validate_source_binding(run_dir, manifest, repo_root, failures):
    try:
        current = current_source_binding(repo_root)
        run_sidecars = source_dump_binding(run_dir)
    except WorkflowError as exc:
        add_failure(failures, "sourceBindingInvalid", str(exc))
        return
    binding = manifest.get("sourceBinding") if isinstance(manifest.get("sourceBinding"), dict) else {}
    for key in ("sourceGitCommit", "sourceCoachFingerprint"):
        if binding.get(key) != current.get(key) or run_sidecars.get(key) != current.get(key):
            add_failure(failures, "sourceBindingMismatch", key)
    packet = run_dir / PACKET_FILE
    if not packet.is_file():
        add_failure(failures, "calibrationPacketMissing")
        return
    context = GATE.calibration_packet_context(run_dir)
    for failure in context.get("packetFailures") or []:
        add_failure(failures, "calibrationPacketRejected", failure)
    if binding.get("calibrationPacketFingerprint") != context.get("sourcePacketFingerprint"):
        add_failure(failures, "calibrationPacketFingerprintBindingMismatch")
    if binding.get("calibrationPacketSha256") != sha256_file(packet):
        add_failure(failures, "calibrationPacketHashBindingMismatch")


def validate_professional(run_dir, payload, manifest, index, failures):
    if payload.get("templateStatus") != "COLLECTED_EXTERNAL_EVIDENCE":
        add_failure(failures, "professionalCalibrationNotMarkedCollected")
    attestation = payload.get("collectionAttestation")
    attestation = attestation if isinstance(attestation, dict) else {}
    coordinator_id = attestation.get("coordinatorID")
    if not usable_text(coordinator_id) or not usable_text(attestation.get("coordinatorRole")):
        add_failure(failures, "calibrationCoordinatorMissing")
    for key in (
        "attestsReviewsWereIndependentAndBlinded",
        "attestsNoReviewerWasOnTheNoumProductTeam",
    ):
        if attestation.get(key) is not True:
            add_failure(failures, "calibrationCollectionAttestationMissing", key)
    if not valid_iso8601(attestation.get("attestedAtISO8601")):
        add_failure(failures, "calibrationCollectionAttestedAtInvalid")
    validate_reference(
        attestation.get("blindAssignmentReference"), "blindAssignment",
        run_dir, index, failures, "calibration.blindAssignmentReference",
    )
    validate_reference(
        attestation.get("attestationReference"), "professionalCollectionAttestation",
        run_dir, index, failures, "calibration.attestationReference",
    )

    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    row_reviewers = {
        row.get("reviewerID") for row in rows
        if isinstance(row, dict) and usable_text(row.get("reviewerID"))
    }
    reviewer_attestations = payload.get("reviewerAttestations")
    reviewer_attestations = reviewer_attestations if isinstance(reviewer_attestations, list) else []
    attested_reviewers = set()
    for position, item in enumerate(reviewer_attestations):
        if not isinstance(item, dict):
            add_failure(failures, "reviewerAttestationInvalid", position)
            continue
        reviewer_id = item.get("reviewerID")
        if not usable_text(reviewer_id):
            add_failure(failures, "reviewerAttestationIDMissing", position)
            continue
        if reviewer_id in attested_reviewers:
            add_failure(failures, "duplicateReviewerAttestation", reviewer_id)
        attested_reviewers.add(reviewer_id)
        if reviewer_id == coordinator_id:
            add_failure(failures, "reviewerIsCalibrationCoordinator", reviewer_id)
        if not usable_text(item.get("professionalRole")):
            add_failure(failures, "professionalReviewerRoleMissing", reviewer_id)
        if item.get("independentFromNoumProductTeam") is not True:
            add_failure(failures, "reviewerIndependenceNotAttested", reviewer_id)
        if item.get("reviewedBlind") is not True:
            add_failure(failures, "reviewerBlindnessNotAttested", reviewer_id)
        if item.get("hasUndisclosedConflictOfInterest") is not False:
            add_failure(failures, "reviewerConflictAttestationInvalid", reviewer_id)
        if not valid_iso8601(item.get("attestedAtISO8601")):
            add_failure(failures, "reviewerAttestedAtInvalid", reviewer_id)
        validate_reference(
            item.get("qualificationsReference"), "professionalQualification",
            run_dir, index, failures, f"reviewer.{reviewer_id}.qualification",
        )
        validate_reference(
            item.get("independenceAttestationReference"), "professionalIndependenceAttestation",
            run_dir, index, failures, f"reviewer.{reviewer_id}.independence",
        )
    if row_reviewers != attested_reviewers:
        add_failure(failures, "reviewerAttestationCoverageMismatch")
    if len(row_reviewers) < GATE.PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION:
        add_failure(failures, "insufficientIndependentReviewerIdentities")

    for position, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        references = row.get("humanCoachReference")
        count = row.get("humanCoachReferenceCount")
        if not isinstance(references, list) or not references or count != len(references):
            add_failure(failures, "humanCoachReferenceDetailMissing", position)
            continue
        for ref_index, reference in enumerate(references):
            if not isinstance(reference, dict):
                add_failure(failures, "humanCoachReferenceInvalid", f"{position}.{ref_index}")
                continue
            if not isinstance(reference.get("turnIndex"), int) or reference.get("turnIndex") < 0:
                add_failure(failures, "humanCoachReferenceTurnInvalid", f"{position}.{ref_index}")
            if not usable_text(reference.get("idealCoachMove")):
                add_failure(failures, "humanCoachMoveMissing", f"{position}.{ref_index}")
            if not usable_text(reference.get("uncertainty")):
                add_failure(failures, "humanCoachUncertaintyMissing", f"{position}.{ref_index}")
            evidence_used = reference.get("evidenceUsed")
            if not isinstance(evidence_used, list) or not any(usable_text(item) for item in evidence_used):
                add_failure(failures, "humanCoachEvidenceUsedMissing", f"{position}.{ref_index}")


def validate_transfer(run_dir, payload, manifest, index, failures):
    if payload.get("templateStatus") != "COLLECTED_EXTERNAL_EVIDENCE":
        add_failure(failures, "transferNotMarkedCollected")
    attestation = payload.get("studyAttestation")
    attestation = attestation if isinstance(attestation, dict) else {}
    principal_id = attestation.get("principalInvestigatorID")
    analyst_id = attestation.get("analystID")
    if not usable_text(principal_id) or not usable_text(analyst_id):
        add_failure(failures, "transferStudyRolesMissing")
    elif principal_id == analyst_id:
        add_failure(failures, "transferInvestigatorAndAnalystMustDiffer")
    for key in (
        "attestsCompleteEnrollmentAccounting",
        "attestsWithdrawalsAndExclusionsWereRetained",
        "attestsNegativeAndAdverseOutcomesWereRetained",
    ):
        if attestation.get(key) is not True:
            add_failure(failures, "transferStudyAttestationMissing", key)
    if not valid_iso8601(attestation.get("attestedAtISO8601")):
        add_failure(failures, "transferStudyAttestedAtInvalid")
    study_refs = {
        "attestationReference": "transferStudyAttestation",
        "participantConsentLogReference": "participantConsentLog",
        "withdrawalLogReference": "withdrawalLog",
        "exclusionLogReference": "exclusionLog",
        "adverseOutcomeLogReference": "adverseOutcomeLog",
    }
    for field, kind in study_refs.items():
        validate_reference(
            attestation.get(field), kind, run_dir, index, failures,
            f"transfer.studyAttestation.{field}",
        )
    for field, kind in (
        ("protocolRegistrationReference", "registeredProtocol"),
        ("analysisPlanReference", "registeredAnalysisPlan"),
        ("benchmarkReference", "registeredBenchmark"),
    ):
        validate_reference(payload.get(field), kind, run_dir, index, failures, f"transfer.{field}")
    enrollment = payload.get("enrollment") if isinstance(payload.get("enrollment"), dict) else {}
    if enrollment.get("exclusionLogReference") != attestation.get("exclusionLogReference"):
        add_failure(failures, "transferExclusionLogReferenceMismatch")
    counts = [
        enrollment.get("enrolledUserCount"), enrollment.get("completedUserCount"),
        enrollment.get("withdrawnUserCount"), enrollment.get("excludedUserCount"),
    ]
    if any(not isinstance(value, int) or isinstance(value, bool) or value < 0 for value in counts):
        add_failure(failures, "transferEnrollmentCountsInvalid")
    elif sum(counts[1:]) != counts[0]:
        add_failure(failures, "transferEnrollmentAccountingMismatch")

    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    row_reference_kinds = {
        "interventionEvidenceReference": "coachInterventionRecord",
        "momentEvidenceReference": "realWorldMomentRecord",
        "followUpEvidenceReference": "delayedFollowUpRecord",
        "audienceResponseEvidenceReference": "audienceResponseRecord",
        "selfReportEvidenceReference": "participantSelfReport",
    }
    for position, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        user_hash = row.get("userIDHash")
        if not SHA256_PATTERN.fullmatch(user_hash or ""):
            add_failure(failures, "transferUserIDMustBeSHA256", position)
        for field, kind in row_reference_kinds.items():
            validate_reference(row.get(field), kind, run_dir, index, failures, f"transfer.rows.{position}.{field}")
        if row.get("adverseOutcomeReported") is True:
            validate_reference(
                row.get("adverseOutcomeFollowUpReference"), "adverseOutcomeFollowUp",
                run_dir, index, failures, f"transfer.rows.{position}.adverseOutcomeFollowUpReference",
            )


def validate_testflight(run_dir, payload, manifest, index, failures):
    if payload.get("templateStatus") != "COLLECTED_EXTERNAL_EVIDENCE":
        add_failure(failures, "testFlightNotMarkedCollected")
    attestation = payload.get("testRunAttestation")
    attestation = attestation if isinstance(attestation, dict) else {}
    tester_id = attestation.get("testerID")
    verifier_id = attestation.get("verifierID")
    if not usable_text(tester_id) or not usable_text(verifier_id):
        add_failure(failures, "testFlightTesterOrVerifierMissing")
    elif tester_id == verifier_id:
        add_failure(failures, "testFlightTesterAndVerifierMustDiffer")
    for key in ("attestsPhysicalDeviceWasUsed", "attestsInstalledBuildCameFromTestFlight"):
        if attestation.get(key) is not True:
            add_failure(failures, "testFlightAttestationMissing", key)
    if attestation.get("distributionChannel") != "TestFlight":
        add_failure(failures, "testFlightDistributionChannelNotProven")
    if not valid_iso8601(attestation.get("attestedAtISO8601")):
        add_failure(failures, "testFlightAttestedAtInvalid")
    attestation_entry = validate_reference(
        attestation.get("attestationReference"), "testFlightRunAttestation",
        run_dir, index, failures, "testFlight.attestationReference",
    )
    if attestation_entry and attestation_entry.get("verifiedByID") != verifier_id:
        add_failure(failures, "testFlightAttestationVerifierMismatch")
    installation_entry = validate_reference(
        attestation.get("testFlightInstallationReference"), "testFlightInstallationProof",
        run_dir, index, failures, "testFlight.testFlightInstallationReference",
    )
    if installation_entry and installation_entry.get("verifiedByID") != verifier_id:
        add_failure(failures, "testFlightInstallationVerifierMismatch")
    build = payload.get("buildNumber")
    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    for position, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        surface = row.get("surfaceKey")
        expected_kind = GATE.REAL_DEVICE_EVIDENCE_KIND_BY_SURFACE.get(surface)
        entry = validate_reference(
            row.get("evidenceReference"), expected_kind,
            run_dir, index, failures, f"testFlight.{surface}.evidenceReference",
        )
        if row.get("verifiedByID") != verifier_id:
            add_failure(failures, "testFlightRowVerifierMismatch", surface or position)
        if entry and entry.get("verifiedByID") != verifier_id:
            add_failure(failures, "testFlightAttachmentVerifierMismatch", surface or position)
        if row.get("testFlightBuildNumber") != build:
            add_failure(failures, "testFlightRowBuildMismatch", surface or position)
        if not SHA256_PATTERN.fullmatch(row.get("deviceIdentifierHash") or ""):
            add_failure(failures, "testFlightDeviceIdentifierMustBeSHA256", surface or position)
        if entry and entry.get("capturedAtISO8601") != row.get("evidenceCapturedAtISO8601"):
            add_failure(failures, "testFlightCaptureTimestampMismatch", surface or position)


def validate_operational_prerequisites(run_dir, payload, index, failures):
    build = payload.get("releaseCandidateBuild")
    prerequisites = payload.get("releasePrerequisites")
    if not isinstance(prerequisites, list):
        add_failure(failures, "operationalPrerequisitesInvalid")
        prerequisites = []

    rows_by_key = {}
    all_references = set()
    for position, row in enumerate(prerequisites):
        if not isinstance(row, dict):
            add_failure(failures, "operationalPrerequisiteInvalid", position)
            continue
        missing_fields = OPERATIONAL_PREREQUISITE_REQUIRED_FIELDS - set(row)
        unexpected_fields = set(row) - OPERATIONAL_PREREQUISITE_REQUIRED_FIELDS
        for field in sorted(missing_fields):
            add_failure(failures, "operationalPrerequisiteFieldMissing", f"{position}.{field}")
        for field in sorted(unexpected_fields):
            add_failure(failures, "operationalPrerequisiteFieldUnexpected", f"{position}.{field}")

        key = row.get("key")
        spec = OPERATIONAL_PREREQUISITES.get(key)
        if spec is None:
            add_failure(failures, "operationalPrerequisiteUnexpected", key or position)
            continue
        if key in rows_by_key:
            add_failure(failures, "operationalPrerequisiteDuplicate", key)
        else:
            rows_by_key[key] = row

        if row.get("completed") is not True:
            add_failure(failures, "operationalPrerequisiteOpen", key)
        if row.get("evidenceKind") != spec["evidenceKind"]:
            add_failure(failures, "operationalPrerequisiteEvidenceKindMismatch", key)
        if row.get("environment") != spec["environment"]:
            add_failure(failures, "operationalPrerequisiteEnvironmentMismatch", key)
        if row.get("releaseCandidateBuild") != build:
            add_failure(failures, "operationalPrerequisiteBuildMismatch", key)
        if not isinstance(row.get("notes"), list):
            add_failure(failures, "operationalPrerequisiteNotesInvalid", key)

        performed_by = row.get("performedByID")
        verified_by = row.get("verifiedByID")
        if not usable_text(performed_by) or not usable_text(verified_by):
            add_failure(failures, "operationalPrerequisitePerformerOrVerifierMissing", key)
        elif performed_by == verified_by:
            add_failure(failures, "operationalPrerequisitePerformerAndVerifierMustDiffer", key)
        if not usable_text(row.get("verifiedByRole")):
            add_failure(failures, "operationalPrerequisiteVerifierRoleMissing", key)

        completed_at = parse_iso8601(row.get("completedAtISO8601"))
        verified_at = parse_iso8601(row.get("verifiedAtISO8601"))
        if completed_at is None:
            add_failure(failures, "operationalPrerequisiteCompletedAtInvalid", key)
        if verified_at is None:
            add_failure(failures, "operationalPrerequisiteVerifiedAtInvalid", key)
        if completed_at is not None and verified_at is not None and verified_at < completed_at:
            add_failure(failures, "operationalPrerequisiteVerifiedBeforeCompletion", key)

        references = (
            row.get("evidenceReference"),
            row.get("verificationReference"),
            row.get("commandOrReviewOutputReference"),
        )
        if len(set(references)) != len(references):
            add_failure(failures, "operationalPrerequisiteReferencesMustBeDistinct", key)
        for reference in references:
            if reference in all_references:
                add_failure(failures, "operationalPrerequisiteReferenceReused", key)
            elif isinstance(reference, str):
                all_references.add(reference)

        reference_entries = [validate_reference(
            row.get("evidenceReference"), spec["evidenceKind"],
            run_dir, index, failures, f"operational.prerequisite.{key}.evidenceReference",
        ), validate_reference(
            row.get("verificationReference"), f"verification:{key}",
            run_dir, index, failures, f"operational.prerequisite.{key}.verificationReference",
        ), validate_reference(
            row.get("commandOrReviewOutputReference"), f"output:{key}",
            run_dir, index, failures,
            f"operational.prerequisite.{key}.commandOrReviewOutputReference",
        )]
        for entry in reference_entries:
            if entry and usable_text(verified_by) and entry.get("verifiedByID") != verified_by:
                add_failure(failures, "operationalPrerequisiteAttachmentVerifierMismatch", key)
            captured_at = parse_iso8601(entry.get("capturedAtISO8601")) if entry else None
            if captured_at is not None and verified_at is not None and captured_at > verified_at:
                add_failure(failures, "operationalPrerequisiteEvidenceCapturedAfterVerification", key)

    for missing_key in sorted(set(OPERATIONAL_PREREQUISITES) - set(rows_by_key)):
        add_failure(failures, "operationalPrerequisiteMissing", missing_key)
    if len(prerequisites) != len(OPERATIONAL_PREREQUISITES):
        add_failure(failures, "operationalPrerequisiteCountMismatch")
    return rows_by_key


def indexed_redacted_gitleaks_rows(run_dir, reference, index, failures):
    if not isinstance(reference, str) or not reference.startswith(EVIDENCE_REFERENCE_PREFIX):
        return {}
    evidence_id = reference[len(EVIDENCE_REFERENCE_PREFIX):]
    entry = index.get(evidence_id)
    path = safe_attachment_path(run_dir, entry.get("path")) if isinstance(entry, dict) else None
    if path is None:
        return {}
    if path.stat().st_size > HISTORY_SECRET_REPORT_MAX_BYTES:
        add_failure(failures, "historySecretRedactedReportTooLarge")
        return {}
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        add_failure(failures, "historySecretRedactedReportInvalidJSON")
        return {}
    if not isinstance(report, list):
        add_failure(failures, "historySecretRedactedReportInvalidShape")
        return {}

    rows_by_id = {}
    for position, row in enumerate(report):
        if not isinstance(row, dict):
            add_failure(failures, "historySecretRedactedReportRowInvalid", position)
            continue
        if row.get("Secret") != "REDACTED":
            add_failure(failures, "historySecretRedactedReportContainsUnredactedSecret", position)
            continue
        match = row.get("Match")
        if not isinstance(match, str) or "REDACTED" not in match:
            add_failure(failures, "historySecretRedactedReportContainsUnredactedMatch", position)
            continue
        if not usable_text(row.get("RuleID")):
            add_failure(failures, "historySecretRedactedReportRuleMissing", position)
            continue
        commit = row.get("Commit")
        if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
            add_failure(failures, "historySecretRedactedReportCommitInvalid", position)
            continue
        path_value = row.get("File")
        parsed_path = PurePosixPath(path_value) if isinstance(path_value, str) and path_value else None
        if (
            parsed_path is None or parsed_path.is_absolute() or ".." in parsed_path.parts
            or "\\" in path_value or path_value != path_value.strip()
            or any(ord(character) < 32 for character in path_value)
        ):
            add_failure(failures, "historySecretRedactedReportPathInvalid", position)
            continue
        start_line = row.get("StartLine")
        if not isinstance(start_line, int) or isinstance(start_line, bool) or start_line <= 0:
            add_failure(failures, "historySecretRedactedReportLineInvalid", position)
            continue
        finding_id = history_secret_finding_id(row)
        if finding_id in rows_by_id:
            add_failure(failures, "historySecretRedactedReportFindingDuplicate", finding_id)
        else:
            rows_by_id[finding_id] = row
    return rows_by_id


def validate_history_secret_adjudication(
    run_dir, payload, manifest, index, failures, repo_root, prerequisite_rows,
):
    adjudication = payload.get("historySecretAdjudication")
    if not isinstance(adjudication, dict):
        add_failure(failures, "historySecretAdjudicationInvalid")
        adjudication = {}
    for field in sorted(HISTORY_SECRET_ADJUDICATION_REQUIRED_FIELDS - set(adjudication)):
        add_failure(failures, "historySecretAdjudicationFieldMissing", field)
    for field in sorted(set(adjudication) - HISTORY_SECRET_ADJUDICATION_REQUIRED_FIELDS):
        add_failure(failures, "historySecretAdjudicationFieldUnexpected", field)

    if adjudication.get("scanner") != HISTORY_SECRET_SCANNER:
        add_failure(failures, "historySecretScannerMismatch")
    if adjudication.get("scannerVersion") != HISTORY_SECRET_SCANNER_VERSION:
        add_failure(failures, "historySecretScannerVersionMismatch")
    if adjudication.get("scanScope") != HISTORY_SECRET_SCAN_SCOPE:
        add_failure(failures, "historySecretScanScopeMismatch")
    if adjudication.get("redactionPercent") != 100:
        add_failure(failures, "historySecretScanNotFullyRedacted")

    source_binding = manifest.get("sourceBinding")
    source_binding = source_binding if isinstance(source_binding, dict) else {}
    if adjudication.get("scannedRepositoryCommit") != source_binding.get("sourceGitCommit"):
        add_failure(failures, "historySecretScanSourceCommitMismatch")
    try:
        reachable = reachable_commit_set_binding(repo_root)
    except WorkflowError as exc:
        add_failure(failures, "historySecretReachableCommitInventoryUnavailable", str(exc))
        reachable = {"reachableCommitCount": None, "reachableCommitSetSha256": None, "commits": set()}
    if adjudication.get("reachableCommitCount") != reachable["reachableCommitCount"]:
        add_failure(failures, "historySecretReachableCommitCountMismatch")
    if adjudication.get("reachableCommitSetSha256") != reachable["reachableCommitSetSha256"]:
        add_failure(failures, "historySecretReachableCommitFingerprintMismatch")

    history_row = prerequisite_rows.get("fullHistorySecretFindingsAdjudicated") or {}
    if adjudication.get("redactedScanReportReference") != history_row.get("evidenceReference"):
        add_failure(failures, "historySecretScanReportReferenceMismatch")
    report_rows = indexed_redacted_gitleaks_rows(
        run_dir, adjudication.get("redactedScanReportReference"), index, failures,
    )

    findings = adjudication.get("findings")
    if not isinstance(findings, list):
        add_failure(failures, "historySecretFindingsInvalid")
        findings = []
    detected = strict_nonnegative_int(adjudication.get("detectedFindingCount"))
    adjudicated = strict_nonnegative_int(adjudication.get("adjudicatedFindingCount"))
    unresolved = strict_nonnegative_int(adjudication.get("unresolvedFindingCount"))
    suppressed = strict_nonnegative_int(adjudication.get("suppressedFindingCount"))
    if detected is None or detected != len(findings):
        add_failure(failures, "historySecretDetectedFindingCountMismatch")
    if detected is None or detected != len(report_rows):
        add_failure(failures, "historySecretRedactedReportFindingCountMismatch")
    if adjudicated is None or adjudicated != len(findings):
        add_failure(failures, "historySecretAdjudicatedFindingCountMismatch")
    if len(findings) < HISTORY_SECRET_MIN_KNOWN_FINDINGS:
        add_failure(failures, "historySecretKnownFindingFloorNotMet")
    if unresolved != 0:
        add_failure(failures, "historySecretUnresolvedFindingsRemain")
    if suppressed != 0:
        add_failure(failures, "historySecretSuppressedFindingsRemain")

    finding_ids = set()
    status_references = set()
    finding_commits = set()
    verifier_id = history_row.get("verifiedByID")
    for position, finding in enumerate(findings):
        if not isinstance(finding, dict):
            add_failure(failures, "historySecretFindingInvalid", position)
            continue
        for field in sorted(HISTORY_SECRET_FINDING_REQUIRED_FIELDS - set(finding)):
            add_failure(failures, "historySecretFindingFieldMissing", f"{position}.{field}")
        for field in sorted(set(finding) - HISTORY_SECRET_FINDING_REQUIRED_FIELDS):
            add_failure(failures, "historySecretFindingFieldUnexpected", f"{position}.{field}")
        finding_id = finding.get("findingID")
        if not SHA256_PATTERN.fullmatch(finding_id or ""):
            add_failure(failures, "historySecretFindingIDInvalid", position)
        elif finding_id in finding_ids:
            add_failure(failures, "historySecretFindingIDDuplicate", finding_id)
        else:
            finding_ids.add(finding_id)
        if not usable_text(finding.get("detectorRuleID")):
            add_failure(failures, "historySecretDetectorRuleMissing", position)

        commit = finding.get("commit")
        if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
            add_failure(failures, "historySecretFindingCommitInvalid", position)
        elif commit not in reachable["commits"]:
            add_failure(failures, "historySecretFindingCommitNotReachable", commit)
        else:
            finding_commits.add(commit)

        path = finding.get("path")
        parsed_path = PurePosixPath(path) if isinstance(path, str) and path else None
        if (
            parsed_path is None or parsed_path.is_absolute() or ".." in parsed_path.parts
            or "\\" in path or path != path.strip()
            or any(ord(character) < 32 for character in path)
        ):
            add_failure(failures, "historySecretFindingPathInvalid", position)

        report_row = report_rows.get(finding_id)
        if report_row is None:
            add_failure(failures, "historySecretFindingNotInRedactedReport", position)
        else:
            if finding.get("detectorRuleID") != report_row.get("RuleID"):
                add_failure(failures, "historySecretFindingRuleMismatch", position)
            if finding.get("commit") != report_row.get("Commit"):
                add_failure(failures, "historySecretFindingReportCommitMismatch", position)
            if finding.get("path") != report_row.get("File"):
                add_failure(failures, "historySecretFindingReportPathMismatch", position)

        disposition = finding.get("disposition")
        expected_kind = HISTORY_SECRET_DISPOSITION_EVIDENCE_KINDS.get(disposition)
        if expected_kind is None:
            add_failure(failures, "historySecretFindingDispositionOpenOrInvalid", position)
        status_reference = finding.get("statusEvidenceReference")
        if status_reference in status_references:
            add_failure(failures, "historySecretFindingStatusReferenceReused", position)
        elif isinstance(status_reference, str):
            status_references.add(status_reference)
        entry = validate_reference(
            status_reference, expected_kind,
            run_dir, index, failures, f"operational.historySecretAdjudication.findings.{position}",
        )
        if entry and usable_text(verifier_id) and entry.get("verifiedByID") != verifier_id:
            add_failure(failures, "historySecretFindingVerifierMismatch", position)

    for commit in sorted(KNOWN_HISTORY_CREDENTIAL_COMMITS - finding_commits):
        add_failure(failures, "historySecretKnownCredentialFindingMissing", commit)
    if finding_ids != set(report_rows):
        add_failure(failures, "historySecretFindingInventoryDoesNotMatchRedactedReport")


def validate_operational(run_dir, payload, manifest, index, failures, repo_root):
    if payload.get("templateStatus") != "COLLECTED_EXTERNAL_EVIDENCE":
        add_failure(failures, "operationalLaunchNotMarkedCollected")
    completed_by_id = payload.get("completedByID")
    if not usable_text(completed_by_id):
        add_failure(failures, "operationalCompletedByIDMissing")
    prerequisite_rows = validate_operational_prerequisites(
        run_dir, payload, index, failures,
    )
    validate_history_secret_adjudication(
        run_dir, payload, manifest, index, failures, repo_root, prerequisite_rows,
    )
    build = payload.get("releaseCandidateBuild")
    items = payload.get("items") if isinstance(payload.get("items"), list) else []
    for position, item in enumerate(items):
        if not isinstance(item, dict):
            continue
        key = item.get("key") or str(position)
        performed_by = item.get("performedByID")
        verified_by = item.get("verifiedByID")
        if not usable_text(performed_by) or not usable_text(verified_by):
            add_failure(failures, "operationalPerformerOrVerifierMissing", key)
        elif performed_by == verified_by:
            add_failure(failures, "operationalPerformerAndVerifierMustDiffer", key)
        if item.get("releaseCandidateBuild") != build:
            add_failure(failures, "operationalBuildMismatch", key)
        expected_kind = GATE.OPERATIONAL_LAUNCH_EVIDENCE_KIND_BY_ITEM.get(item.get("key"))
        reference_entries = [validate_reference(
            item.get("evidenceReference"), expected_kind,
            run_dir, index, failures, f"operational.{key}.evidenceReference",
        ), validate_reference(
            item.get("verificationReference"), f"verification:{key}",
            run_dir, index, failures, f"operational.{key}.verificationReference",
        ), validate_reference(
            item.get("commandOrReviewOutputReference"), f"output:{key}",
            run_dir, index, failures, f"operational.{key}.commandOrReviewOutputReference",
        )]
        if usable_text(verified_by) and any(
            entry and entry.get("verifiedByID") != verified_by
            for entry in reference_entries
        ):
            add_failure(failures, "operationalAttachmentVerifierMismatch", key)


def validate_promotion_approval(run_dir, manifest, index, payloads, failures):
    initialized_by = manifest.get("initializedBy")
    initialized_by = initialized_by if isinstance(initialized_by, dict) else {}
    if not usable_text(initialized_by.get("id")) or not usable_text(initialized_by.get("role")):
        add_failure(failures, "runInitializerMissing")
    approval = manifest.get("promotionApproval")
    approval = approval if isinstance(approval, dict) else {}
    approver_id = approval.get("approvedByID")
    if not usable_text(approver_id) or not usable_text(approval.get("approvedByRole")):
        add_failure(failures, "promotionApproverMissing")
    if approver_id == initialized_by.get("id"):
        add_failure(failures, "promotionApproverMustDifferFromRunInitializer")
    if not valid_iso8601(approval.get("approvedAtISO8601")):
        add_failure(failures, "promotionApprovalTimestampInvalid")
    for key in ("attestsEvidenceIsExternalOrOperational", "attestsNoSyntheticFixtureWasUsed"):
        if approval.get(key) is not True:
            add_failure(failures, "promotionAttestationMissing", key)
    approval_entry = validate_reference(
        approval.get("approvalReference"), "releaseEvidencePromotionApproval",
        run_dir, index, failures, "promotion.approvalReference",
    )
    if (
        approval_entry
        and usable_text(approver_id)
        and approval_entry.get("verifiedByID") == approver_id
    ):
        add_failure(failures, "promotionApprovalMustBeIndependentlyVerified")
    calibration = payloads.get("professionalCalibration") or {}
    reviewer_ids = {
        row.get("reviewerID") for row in calibration.get("rows", [])
        if isinstance(row, dict) and usable_text(row.get("reviewerID"))
    }
    if approver_id in reviewer_ids:
        add_failure(failures, "promotionApproverMustNotBeCalibrationReviewer")


def existing_validator_failures(run_dir, payloads):
    failures = []
    source_expectations = {
        "source-git-commit.txt": (run_dir / "source-git-commit.txt").read_text(encoding="utf-8").strip()
        if (run_dir / "source-git-commit.txt").is_file() else None,
        "source-coach-fingerprint.txt": (run_dir / "source-coach-fingerprint.txt").read_text(encoding="utf-8").strip()
        if (run_dir / "source-coach-fingerprint.txt").is_file() else None,
        "professionalCalibrationPacket": GATE.calibration_packet_context(run_dir),
    }
    statuses = {}
    for key, (artifact_name, blocker) in MANAGED_ARTIFACTS.items():
        requirement = GATE.EVIDENCE_REQUIREMENTS[blocker]
        status = GATE.evidence_artifact_contract_status(
            run_dir / artifact_name,
            requirement,
            source_expectations,
        )
        statuses[key] = status
        for failure in status.get("contractFailures") or []:
            add_failure(failures, f"existingReadinessValidator.{key}", failure)
    return failures, statuses


def validate_run(run_dir: Path, repo_root: Path):
    failures = []
    manifest = load_manifest(run_dir)
    index = evidence_index_by_id(manifest, failures)
    validate_source_binding(run_dir, manifest, repo_root, failures)
    payloads = {}
    for key, (artifact_name, _) in MANAGED_ARTIFACTS.items():
        try:
            payload = read_json(run_dir / artifact_name)
        except WorkflowError as exc:
            add_failure(failures, "managedArtifactInvalid", str(exc))
            payload = {}
        payloads[key] = payload
    validate_professional(run_dir, payloads["professionalCalibration"], manifest, index, failures)
    validate_transfer(run_dir, payloads["realUserTransfer"], manifest, index, failures)
    validate_testflight(run_dir, payloads["realDeviceTestFlight"], manifest, index, failures)
    validate_operational(
        run_dir, payloads["operationalLaunch"], manifest, index, failures, repo_root,
    )
    validate_promotion_approval(run_dir, manifest, index, payloads, failures)
    gate_failures, gate_statuses = existing_validator_failures(run_dir, payloads)
    failures.extend(item for item in gate_failures if item not in failures)
    return {
        "schemaVersion": "noum-release-evidence-validation-v1",
        "runDir": str(run_dir),
        "passes": not failures,
        "failureCount": len(failures),
        "failures": failures,
        "existingReadinessValidator": {
            key: {
                "passes": status.get("passesLightweightContract"),
                "contractFailures": status.get("contractFailures") or [],
            }
            for key, status in gate_statuses.items()
        },
    }


def print_validation(result, as_json=False):
    if as_json:
        print(json.dumps(result, indent=2, sort_keys=True))
        return
    verdict = "PASS" if result["passes"] else "FAIL CLOSED"
    print(f"Release evidence validation: {verdict}")
    print(f"Run: {result['runDir']}")
    for key, status in result["existingReadinessValidator"].items():
        state = "accepted" if status["passes"] else "rejected"
        print(f"- existing readiness validator {key}: {state}")
    if result["failures"]:
        print("Failures:")
        for failure in result["failures"]:
            print(f"- {failure}")


def validate_command(args):
    result = validate_run(
        Path(args.run_dir).expanduser().resolve(),
        Path(args.repo_root).expanduser().resolve(),
    )
    print_validation(result, args.json)
    return 0 if result["passes"] else 1


def register_attachment(args):
    run_dir = Path(args.run_dir).expanduser().resolve()
    source = Path(args.file).expanduser().resolve()
    if not source.is_file() or source.stat().st_size <= 0:
        raise WorkflowError(f"attachment source is missing or empty: {source}")
    if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{2,80}", args.id):
        raise WorkflowError("attachment id must be 3-81 lowercase letters/digits/._-")
    if not usable_text(args.kind) or not valid_iso8601(args.captured_at) or not usable_text(args.verified_by_id):
        raise WorkflowError("kind, timezone-aware captured-at, and verified-by-id are required")
    manifest = load_manifest(run_dir)
    entries = manifest.get("evidenceIndex")
    if not isinstance(entries, list):
        raise WorkflowError("run manifest evidenceIndex is invalid")
    if any(isinstance(entry, dict) and entry.get("id") == args.id for entry in entries):
        raise WorkflowError(f"attachment id already exists: {args.id}")
    suffix = "".join(source.suffixes)[-24:]
    destination_name = f"{args.id}{suffix}"
    destination = run_dir / "attachments" / destination_name
    if destination.exists():
        raise WorkflowError(f"attachment destination already exists: {destination}")
    shutil.copy2(source, destination)
    entry = {
        "id": args.id,
        "path": str(destination.relative_to(run_dir)),
        "kind": args.kind,
        "sha256": sha256_file(destination),
        "capturedAtISO8601": args.captured_at,
        "verifiedByID": args.verified_by_id,
        "containsPersonalData": bool(args.contains_personal_data),
        "accessControlReference": args.access_control_reference or "",
    }
    if entry["containsPersonalData"] and not usable_text(entry["accessControlReference"]):
        destination.unlink(missing_ok=True)
        raise WorkflowError("personal-data evidence requires --access-control-reference")
    entries.append(entry)
    write_json(run_dir / RUN_MANIFEST_FILE, manifest)
    print(f"Registered {EVIDENCE_REFERENCE_PREFIX}{args.id}")


def import_history_scan_command(args):
    run_dir = Path(args.run_dir).expanduser().resolve()
    repo_root = Path(args.repo_root).expanduser().resolve()
    manifest = load_manifest(run_dir)
    failures = []
    index = evidence_index_by_id(manifest, failures)
    validate_source_binding(run_dir, manifest, repo_root, failures)
    validate_reference(
        args.reference, "fullHistorySecretReview", run_dir, index, failures,
        "historyImport.redactedScanReportReference",
    )
    report_rows = indexed_redacted_gitleaks_rows(
        run_dir, args.reference, index, failures,
    )
    try:
        reachable = reachable_commit_set_binding(repo_root)
    except WorkflowError as exc:
        add_failure(failures, "historySecretReachableCommitInventoryUnavailable", str(exc))
        reachable = {"reachableCommitCount": 0, "reachableCommitSetSha256": "", "commits": set()}
    report_commits = {
        row.get("Commit") for row in report_rows.values() if isinstance(row, dict)
    }
    for commit in sorted(report_commits - reachable["commits"]):
        add_failure(failures, "historySecretFindingCommitNotReachable", commit)
    if len(report_rows) < HISTORY_SECRET_MIN_KNOWN_FINDINGS:
        add_failure(failures, "historySecretKnownFindingFloorNotMet")
    for commit in sorted(KNOWN_HISTORY_CREDENTIAL_COMMITS - report_commits):
        add_failure(failures, "historySecretKnownCredentialFindingMissing", commit)
    if failures:
        raise WorkflowError(
            "history scan import refused: " + ", ".join(failures)
        )

    operational_path = run_dir / MANAGED_ARTIFACTS["operationalLaunch"][0]
    operational = read_json(operational_path)
    prerequisites = operational.get("releasePrerequisites")
    prerequisites = prerequisites if isinstance(prerequisites, list) else []
    history_rows = [
        row for row in prerequisites
        if isinstance(row, dict) and row.get("key") == "fullHistorySecretFindingsAdjudicated"
    ]
    if len(history_rows) != 1:
        raise WorkflowError(
            "history scan import refused: exact full-history prerequisite row is missing"
        )
    history_row = history_rows[0]
    existing_reference = history_row.get("evidenceReference")
    if usable_text(existing_reference) and existing_reference != args.reference:
        raise WorkflowError(
            "history scan import refused: prerequisite already names another report"
        )
    history_row["evidenceReference"] = args.reference

    source_binding = manifest.get("sourceBinding")
    source_binding = source_binding if isinstance(source_binding, dict) else {}
    findings = []
    for finding_id, report_row in sorted(report_rows.items()):
        findings.append({
            "findingID": finding_id,
            "detectorRuleID": report_row["RuleID"],
            "commit": report_row["Commit"],
            "path": report_row["File"],
            "disposition": "",
            "statusEvidenceReference": "",
        })
    operational["historySecretAdjudication"] = {
        "scanner": HISTORY_SECRET_SCANNER,
        "scannerVersion": HISTORY_SECRET_SCANNER_VERSION,
        "scanScope": HISTORY_SECRET_SCAN_SCOPE,
        "scannedRepositoryCommit": source_binding.get("sourceGitCommit", ""),
        "redactionPercent": 100,
        "reachableCommitCount": reachable["reachableCommitCount"],
        "reachableCommitSetSha256": reachable["reachableCommitSetSha256"],
        "redactedScanReportReference": args.reference,
        "detectedFindingCount": len(findings),
        "adjudicatedFindingCount": 0,
        "unresolvedFindingCount": len(findings),
        "suppressedFindingCount": 0,
        "findings": findings,
    }
    write_json(operational_path, operational)
    print(
        f"Imported {len(findings)} fully redacted history findings as unresolved."
    )
    print("No disposition was inferred; the release gate remains closed.")


def summarize_professional(payload):
    rows = [row for row in payload.get("rows", []) if isinstance(row, dict)]
    reviewer_ids = {row.get("reviewerID") for row in rows if usable_text(row.get("reviewerID"))}
    passing = [row for row in rows if GATE.professional_row_passes_calibration_floor(row)]
    rating_keys = [
        "diagnosis", "caseFormulation", "intervention", "adaptation",
        "perceptionHonesty", "transferSetup", "trustRepair", "overallUsefulness",
    ]
    completed = [
        row for row in rows
        if usable_text(row.get("reviewerID"))
        and row.get("calibrationDecision") in {
            "expertBetter", "noumBetter", "roughTie", "unsafeOrUnready",
        }
        and isinstance(row.get("ratings"), dict)
        and all(GATE.finite_number(row["ratings"].get(key)) is not None for key in rating_keys)
        and isinstance(row.get("humanCoachReference"), list)
        and bool(row.get("humanCoachReference"))
    ]
    usefulness = [
        GATE.finite_number((row.get("ratings") or {}).get("overallUsefulness"))
        for row in rows
    ]
    usefulness = [value for value in usefulness if value is not None]
    payload["reviewCount"] = len(rows)
    payload["summary"].update({
        "rowCount": len(rows),
        "reviewerCount": len(reviewer_ids),
        "completedReviewCount": len(completed),
        "passingCalibrationCount": len(passing),
        "wouldUseWithClientCount": sum(row.get("wouldUseWithClient") is True for row in rows),
        "unsafeOrUnreadyCount": sum(row.get("calibrationDecision") == "unsafeOrUnready" for row in rows),
        "averageOverallUsefulness": (sum(usefulness) / len(usefulness)) if usefulness else 0,
        "minimumOverallUsefulness": min(usefulness, default=0),
    })


def summarize_transfer(payload):
    rows = [row for row in payload.get("rows", []) if isinstance(row, dict)]
    users = [row.get("userIDHash") for row in rows if usable_text(row.get("userIDHash"))]
    moments = [row.get("momentCategory") for row in rows if usable_text(row.get("momentCategory"))]
    per_user = {user: users.count(user) for user in set(users)}
    evidence_fields = [
        "interventionEvidenceReference", "momentEvidenceReference", "followUpEvidenceReference",
        "audienceResponseEvidenceReference", "selfReportEvidenceReference",
    ]
    delays = [GATE.strict_int(row.get("followUpDelayHours")) for row in rows]
    days = [GATE.strict_int(row.get("daysSinceFirstNoumSession")) for row in rows]
    adverse = [row for row in rows if row.get("adverseOutcomeReported") is True]
    resolved_adverse = [
        row for row in adverse
        if row.get("adverseOutcomeResolved") is True
        and GATE.usable_evidence_reference(row.get("adverseOutcomeFollowUpReference"))
    ]
    payload["outcomeCount"] = len(rows)
    payload["summary"].update({
        "rowCount": len(rows),
        "uniqueUserCount": len(set(users)),
        "completedFollowUpCount": sum(row.get("followUpCompleted") is True for row in rows),
        "realWorldMomentCount": sum(row.get("realWorldMomentOccurred") is True for row in rows),
        "linkedInterventionOutcomeCount": sum((GATE.strict_int(row.get("linkedCoachInterventionCount")) or 0) > 0 for row in rows),
        "positiveTransferCount": sum(row.get("positiveTransferReported") is True for row in rows),
        "audienceResponseEvidenceCount": sum(row.get("audienceResponseEvidenceCollected") is True for row in rows),
        "noRegressionOutcomeCount": sum(
            GATE.strict_int(row.get("preMomentConfidence")) is not None
            and GATE.strict_int(row.get("postMomentConfidence")) is not None
            and GATE.strict_int(row.get("postMomentConfidence")) >= GATE.strict_int(row.get("preMomentConfidence"))
            for row in rows
        ),
        "adverseOutcomeCount": len(adverse),
        "resolvedAdverseOutcomeCount": len(resolved_adverse),
        "passingOutcomeCount": sum(GATE.real_user_transfer_row_passes(row) for row in rows),
        "minimumDaysSinceFirstSession": min((value for value in days if value is not None), default=0),
        "uniqueMomentCategoryCount": len(set(moments)),
        "verifiedEvidenceReferenceCount": sum(
            all(GATE.usable_evidence_reference(row.get(field)) for field in evidence_fields)
            for row in rows
        ),
        "minimumFollowUpDelayHours": min((value for value in delays if value is not None), default=0),
        "maximumOutcomesPerUser": max(per_user.values(), default=0),
    })


def summarize_testflight(payload):
    rows = [row for row in payload.get("rows", []) if isinstance(row, dict)]
    required = set(GATE.REAL_DEVICE_REQUIRED_SURFACES)
    required_rows = [row for row in rows if row.get("surfaceKey") in required]
    build = payload.get("buildNumber")
    payload["summary"].update({
        "rowCount": len(rows),
        "requiredSurfaceCount": len(required),
        "passedRequiredSurfaceCount": sum(GATE.real_device_row_passes(row) for row in required_rows),
        "realDeviceSurfaceCount": sum(row.get("realDevice") is True for row in required_rows),
        "testFlightBuildSurfaceCount": sum(row.get("testFlightBuildInstalled") is True for row in required_rows),
        "artifactBackedSurfaceCount": sum(all(GATE.usable_evidence_reference(row.get(key)) for key in [
            "evidenceReference", "evidenceKind", "evidenceCapturedAtISO8601",
            "testFlightBuildNumber", "deviceIdentifierHash",
        ]) for row in required_rows),
        "expectedEvidenceKindSurfaceCount": sum(
            row.get("evidenceKind") == GATE.REAL_DEVICE_EVIDENCE_KIND_BY_SURFACE.get(row.get("surfaceKey"))
            for row in required_rows
        ),
        "sameBuildSurfaceCount": sum(row.get("testFlightBuildNumber") == build for row in required_rows),
        "deviceIdentitySurfaceCount": sum(GATE.usable_evidence_reference(row.get("deviceIdentifierHash")) for row in required_rows),
        "latencyWithinBudgetSurfaceCount": sum(
            row.get("surfaceKey") == "aiPromptLatency"
            and GATE.strict_int(row.get("latencyMs")) is not None
            and 0 <= GATE.strict_int(row.get("latencyMs")) <= GATE.REAL_DEVICE_MAX_AI_PROMPT_LATENCY_MS
            for row in required_rows
        ),
        "blockingIssueCount": sum(GATE.strict_int(row.get("blockingIssueCount")) or 0 for row in rows),
    })


def summarize_operational(payload):
    items = [item for item in payload.get("items", []) if isinstance(item, dict)]
    required = set(GATE.OPERATIONAL_LAUNCH_REQUIRED_ITEMS)
    required_items = [item for item in items if item.get("key") in required]
    prerequisites = [
        item for item in payload.get("releasePrerequisites", [])
        if isinstance(item, dict) and item.get("key") in OPERATIONAL_PREREQUISITES
    ]
    build = payload.get("releaseCandidateBuild")
    payload["summary"].update({
        "itemCount": len(items),
        "completedRequiredItemCount": sum(item.get("completed") is True for item in required_items),
        "failedRequiredItemCount": sum(item.get("completed") is not True for item in required_items),
        "artifactBackedItemCount": sum(all(GATE.usable_evidence_reference(item.get(field)) for field in [
            "evidenceReference", "verificationReference", "commandOrReviewOutputReference", "completedAtISO8601",
        ]) for item in required_items),
        "expectedEvidenceKindItemCount": sum(
            item.get("evidenceKind") == GATE.OPERATIONAL_LAUNCH_EVIDENCE_KIND_BY_ITEM.get(item.get("key"))
            for item in required_items
        ),
        "expectedEnvironmentItemCount": sum(
            item.get("environment") == GATE.OPERATIONAL_LAUNCH_ENVIRONMENT_BY_ITEM.get(item.get("key"))
            for item in required_items
        ),
        "sameBuildItemCount": sum(item.get("releaseCandidateBuild") == build for item in required_items),
        "verifiedRequiredItemCount": sum(
            GATE.usable_evidence_reference(item.get("verifiedAtISO8601"))
            and GATE.usable_evidence_reference(item.get("verifiedByRole"))
            for item in required_items
        ),
        "requiredPrerequisiteCount": len(OPERATIONAL_PREREQUISITES),
        "completedPrerequisiteCount": sum(
            item.get("completed") is True for item in prerequisites
        ),
        "artifactBackedPrerequisiteCount": sum(all(
            GATE.usable_evidence_reference(item.get(field))
            for field in (
                "evidenceReference", "verificationReference",
                "commandOrReviewOutputReference", "completedAtISO8601",
                "verifiedAtISO8601",
            )
        ) for item in prerequisites),
        "expectedEvidenceKindPrerequisiteCount": sum(
            item.get("evidenceKind")
            == OPERATIONAL_PREREQUISITES[item.get("key")]["evidenceKind"]
            for item in prerequisites
        ),
        "expectedEnvironmentPrerequisiteCount": sum(
            item.get("environment")
            == OPERATIONAL_PREREQUISITES[item.get("key")]["environment"]
            for item in prerequisites
        ),
        "sameBuildPrerequisiteCount": sum(
            item.get("releaseCandidateBuild") == build for item in prerequisites
        ),
        "independentlyVerifiedPrerequisiteCount": sum(
            usable_text(item.get("performedByID"))
            and usable_text(item.get("verifiedByID"))
            and item.get("performedByID") != item.get("verifiedByID")
            and usable_text(item.get("verifiedByRole"))
            for item in prerequisites
        ),
    })


def summarize_command(args):
    run_dir = Path(args.run_dir).expanduser().resolve()
    summarizers = {
        "professionalCalibration": summarize_professional,
        "realUserTransfer": summarize_transfer,
        "realDeviceTestFlight": summarize_testflight,
        "operationalLaunch": summarize_operational,
    }
    for key, (artifact_name, _) in MANAGED_ARTIFACTS.items():
        payload = read_json(run_dir / artifact_name)
        summarizers[key](payload)
        write_json(run_dir / artifact_name, payload)
    print("Recomputed count and summary telemetry without changing evidence claims or warnings.")


def promote_command(args):
    run_dir = Path(args.run_dir).expanduser().resolve()
    dump_dir = Path(args.dump_dir).expanduser().resolve()
    repo_root = Path(args.repo_root).expanduser().resolve()
    result = validate_run(run_dir, repo_root)
    if not result["passes"]:
        print_validation(result, False)
        raise WorkflowError("promotion refused: evidence run did not pass validation")
    if not dump_dir.is_dir():
        raise WorkflowError(f"target evidence dump must already exist: {dump_dir}")
    run_binding = source_dump_binding(run_dir)
    dump_binding = source_dump_binding(dump_dir)
    if run_binding != dump_binding:
        raise WorkflowError("target dump source sidecars do not match the validated run")
    run_packet = run_dir / PACKET_FILE
    dump_packet = dump_dir / PACKET_FILE
    if not dump_packet.is_file() or sha256_file(run_packet) != sha256_file(dump_packet):
        raise WorkflowError("target dump calibration packet does not match the validated run")
    existing = [
        artifact_name for artifact_name, _ in MANAGED_ARTIFACTS.values()
        if (dump_dir / artifact_name).exists()
    ]
    if existing and not args.replace_existing:
        raise WorkflowError(
            "target already contains managed evidence; pass --replace-existing only "
            f"after reviewing the replacement: {', '.join(existing)}"
        )

    # Re-run the existing validator against the exact source context in the
    # target immediately before any copy. This is the promotion authority.
    source_expectations = {
        "source-git-commit.txt": dump_binding["sourceGitCommit"],
        "source-coach-fingerprint.txt": dump_binding["sourceCoachFingerprint"],
        "professionalCalibrationPacket": GATE.calibration_packet_context(dump_dir),
    }
    for key, (artifact_name, blocker) in MANAGED_ARTIFACTS.items():
        status = GATE.evidence_artifact_contract_status(
            run_dir / artifact_name,
            GATE.EVIDENCE_REQUIREMENTS[blocker],
            source_expectations,
        )
        if not status.get("passesLightweightContract"):
            raise WorkflowError(
                f"promotion refused by existing readiness validator for {key}: "
                + ", ".join(status.get("contractFailures") or ["unknown"])
            )

    staged = []
    try:
        for artifact_name, _ in MANAGED_ARTIFACTS.values():
            fd, temp_name = tempfile.mkstemp(prefix=f".{artifact_name}.", dir=dump_dir)
            os.close(fd)
            temp_path = Path(temp_name)
            shutil.copy2(run_dir / artifact_name, temp_path)
            staged.append((temp_path, dump_dir / artifact_name))
        for temp_path, destination in staged:
            os.replace(temp_path, destination)
    finally:
        for temp_path, _ in staged:
            temp_path.unlink(missing_ok=True)

    receipt = {
        "schemaVersion": "noum-release-evidence-promotion-receipt-v1",
        "promotedAtISO8601": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "dumpDir": str(dump_dir),
        "sourceBinding": run_binding,
        "artifacts": {
            artifact_name: sha256_file(dump_dir / artifact_name)
            for artifact_name, _ in MANAGED_ARTIFACTS.values()
        },
        "existingReadinessValidatorAcceptedManagedArtifacts": True,
        "launchReadyClaimed": False,
        "nextStep": "Regenerate the Swift readiness manifest and rerun the complete readiness gate.",
    }
    write_json(run_dir / "promotion-receipt-v1.json", receipt)
    print(f"Promoted four validator-accepted artifacts to {dump_dir}")
    print("No launch-ready claim was made; rerun the complete readiness and manifest workflow.")


def build_parser():
    parser = argparse.ArgumentParser(
        description="Collect and promote externally earned Noum release evidence.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    init = subparsers.add_parser("init", help="Create a visibly non-passing source-bound run.")
    init.add_argument("--run-dir", required=True)
    init.add_argument("--source-dump", default=os.environ.get("NOUM_COACH_EVAL_DUMP_DIR", "/private/tmp/noum-coach-eval"))
    init.add_argument("--repo-root", default=str(REPO_ROOT))
    init.add_argument("--initialized-by-id")
    init.add_argument("--initialized-by-role")
    init.set_defaults(function=initialize_run)

    register = subparsers.add_parser("register-attachment", help="Copy and hash a real evidence attachment.")
    register.add_argument("--run-dir", required=True)
    register.add_argument("--id", required=True)
    register.add_argument("--kind", required=True)
    register.add_argument("--file", required=True)
    register.add_argument("--captured-at", required=True)
    register.add_argument("--verified-by-id", required=True)
    register.add_argument("--contains-personal-data", action="store_true")
    register.add_argument("--access-control-reference")
    register.set_defaults(function=register_attachment)

    history_import = subparsers.add_parser(
        "import-history-scan",
        help="Import a registered fully redacted Gitleaks JSON report as unresolved findings.",
    )
    history_import.add_argument("--run-dir", required=True)
    history_import.add_argument("--reference", required=True)
    history_import.add_argument("--repo-root", default=str(REPO_ROOT))
    history_import.set_defaults(function=import_history_scan_command)

    summarize = subparsers.add_parser("summarize", help="Recompute summary counts from operator-entered rows.")
    summarize.add_argument("--run-dir", required=True)
    summarize.set_defaults(function=summarize_command)

    validate = subparsers.add_parser("validate", help="Fail closed across operator and existing readiness contracts.")
    validate.add_argument("--run-dir", required=True)
    validate.add_argument("--repo-root", default=str(REPO_ROOT))
    validate.add_argument("--json", action="store_true")
    validate.set_defaults(function=validate_command)

    promote = subparsers.add_parser("promote", help="Atomically copy accepted artifacts into the evidence dump.")
    promote.add_argument("--run-dir", required=True)
    promote.add_argument("--dump-dir", default=os.environ.get("NOUM_COACH_EVAL_DUMP_DIR", "/private/tmp/noum-coach-eval"))
    promote.add_argument("--repo-root", default=str(REPO_ROOT))
    promote.add_argument("--replace-existing", action="store_true")
    promote.set_defaults(function=promote_command)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        result = args.function(args)
        return 0 if result is None else result
    except WorkflowError as exc:
        print(f"release-evidence: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
