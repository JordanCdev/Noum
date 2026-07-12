#!/usr/bin/env python3
import argparse
import hashlib
import json
import math
import os
import plistlib
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


ARENA_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ARENA_ROOT.parents[1]
DEFAULT_REPORT = ARENA_ROOT / "reports" / "app-path" / "latest.json"
CANONICAL_APP_PATH_REPORT_DIR = ARENA_ROOT / "reports" / "app-path"
DEFAULT_DUMP_DIR = Path(os.environ.get("NOUM_COACH_EVAL_DUMP_DIR", "/private/tmp/noum-coach-eval"))
READY_CLAIM = "productionReadyEvidenceAvailable"
READY_SCORE = 85
READY_LOCAL_TARGET_SHAPE_SCORE = 85
SOURCE_SIDECARS = [
    "source-git-commit.txt",
    "source-coach-fingerprint.txt",
]

COACH_SOURCE_STATUS_PATHS = [
    "Noum/AICoachChatService.swift",
    "Noum/AskNoumStore.swift",
    "Noum/CoachAssessment.swift",
    "Noum/CoachAssessmentCache.swift",
    "Noum/CoachContextBuilder.swift",
    "Noum/CoachPromptBundle.swift",
    "Noum/CoachReasoningPass.swift",
    "Noum/CoachReplyPipeline.swift",
    "Noum/CoachReliabilityGate.swift",
    "Noum/CoachTurnDepth.swift",
    "Noum/CoachingKnowledgeBase.swift",
    "Noum/GoalRubric.swift",
    "Noum/GoalRubricStore.swift",
    "Noum/KnowledgeRetriever.swift",
    "Noum/KnowledgeSemanticReranker.swift",
    "Noum/PrimaryFocusMemory.swift",
    "Noum/TurnDepthClassifier.swift",
    "Noum/UserTrajectoryCache.swift",
    "Noum/UserTrajectorySnapshot.swift",
    "NoumTests/CoachBrainRerankTests.swift",
    "NoumTests/CoachBrainTests.swift",
    "NoumTests/CoachChatEvaluationFixtures.swift",
    "NoumTests/CoachChatConversationEvaluationTests.swift",
    "NoumTests/CoachProviderChainTests.swift",
    "NoumTests/CoachReadCalibrationBaselineTests.swift",
    "NoumTests/CoachLiveEvaluationTests.swift",
    "NoumTests/CoachJudgementLayerTests.swift",
    "NoumTests/CoachPlaceholderLeakStripTests.swift",
    "NoumTests/CoachReportVoiceRegenerationProofTests.swift",
    "NoumTests/CoachReliabilityGateTests.swift",
    "NoumTests/GoalRubricVoiceRoutingTests.swift",
    "NoumTests/NoumTests.swift",
]


LOCAL_GATE_REQUIREMENTS = [
    {
        "key": "scoreThresholdsPass",
        "label": "localScoreAndFixtureThresholds",
        "gate": (
            "The latest app-path report must pass the score floors, placeholder "
            "leak cap, and app-path fixture floor."
        ),
        "nextStep": (
            "Run the app-path evaluator, inspect reports/app-path/failures.md, "
            "and fix any low-scoring or leaking fixture before launch."
        ),
    },
    {
        "key": "realPipelineEvidencePasses",
        "label": "realPipelineEvidence",
        "gate": (
            "The latest app-path report must be backed by real Swift pipeline "
            "traces, not Python reference replies or scripted local-only output."
        ),
        "nextStep": (
            "Regenerate the XCTest artifact dump, rerun app-path-source, then "
            "rerun app-path scoring against the refreshed dump."
        ),
    },
    {
        "key": "traceQualityPasses",
        "label": "traceQualityEvidence",
        "gate": (
            "Every scored app-path row must carry usable trace evidence for "
            "retrieval, cache/source freshness, depth routing, and quality gates."
        ),
        "nextStep": (
            "Inspect traceQualityFailures in the app-path report and repair the "
            "missing trace or retrieval surface before claiming readiness."
        ),
    },
]


EVIDENCE_REQUIREMENTS = {
    "noLiveProviderTranscriptSweep": {
        "rowKey": "liveProviderTranscriptSweep",
        "artifact": "coach-live-eval-v1.json",
        "expectedSchemaVersion": "coach-live-eval-v1",
        "requiredTopLevelKeys": [
            "schemaVersion",
            "sourceGitCommit",
            "sourceCoachFingerprint",
            "fixtureCount",
            "longFormConversationCount",
            "longFormConversationIDsPassingProductionFloor",
            "longFormConversationFailureIDs",
            "longFormConversations",
            "providerChain",
            "passesProductionFloor",
            "passesRunReadinessFloor",
            "summary",
            "rows",
        ],
        "owner": "live provider eval",
        "gate": (
            "Real provider transcript sweep over the required app-path fixtures, "
            "with matching sourceGitCommit and sourceCoachFingerprint sidecars."
        ),
        "nextStep": (
            "Run app-path-source, refresh the live provider evaluation artifact, "
            "then rerun the Swift production-readiness manifest test."
        ),
    },
    "noProfessionalCoachCalibration": {
        "rowKey": "professionalCoachCalibration",
        "artifact": "coach-chat-conversation-expert-calibration-results-v2.json",
        "expectedSchemaVersion": "coach-chat-conversation-expert-calibration-results-v2",
        "requiredTopLevelKeys": [
            "schemaVersion",
            "sourcePacketSchemaVersion",
            "sourcePacketFingerprint",
            "rubricVersion",
            "reviewerRole",
            "reviewCount",
            "summary",
            "rows",
        ],
        "owner": "professional coach reviewers",
        "gate": (
            "Blinded professional-coach reviews for the required calibration "
            "packet, meeting the rubric and review-count floor."
        ),
        "nextStep": (
            "Collect the signed calibration results from real reviewers and place "
            "the artifact in NOUM_COACH_EVAL_DUMP_DIR."
        ),
    },
    "noRealUserLongitudinalTransferOutcomes": {
        "rowKey": "realUserLongitudinalTransferOutcomes",
        "artifact": "coach-real-user-transfer-outcomes-v2.json",
        "expectedSchemaVersion": "coach-real-user-transfer-outcomes-v2",
        "requiredTopLevelKeys": [
            "schemaVersion",
            "studyProtocolVersion",
            "cohortDescription",
            "outcomeCount",
            "summary",
            "rows",
        ],
        "owner": "closed beta outcome study",
        "gate": (
            "Longitudinal real-user transfer outcomes with follow-up delay, "
            "real-world moments, linked interventions, and evidence references."
        ),
        "nextStep": (
            "Complete the beta follow-up cohort and export the verified outcomes "
            "artifact. Local fixtures cannot earn this row."
        ),
    },
    "noRealDeviceTestFlightVerification": {
        "rowKey": "realDeviceTestFlightVerification",
        "artifact": "coach-real-device-testflight-qa-v2.json",
        "expectedSchemaVersion": "coach-real-device-testflight-qa-v2",
        "requiredTopLevelKeys": [
            "schemaVersion",
            "testRunID",
            "appVersion",
            "buildNumber",
            "deviceModel",
            "osVersion",
            "testerRole",
            "summary",
            "rows",
        ],
        "owner": "real device QA",
        "gate": (
            "Physical-device TestFlight verification for liveActivity, "
            "aiPromptLatency, soundscapeAudioSession, and paywallPurchase."
        ),
        "nextStep": (
            "Run the release candidate on a physical TestFlight device and attach "
            "screen recordings, latency trace, audio-session log, and receipt proof."
        ),
    },
    "operationalLaunchChecklistIncomplete": {
        "rowKey": "operationalLaunchChecklist",
        "artifact": "coach-operational-launch-checklist-v2.json",
        "expectedSchemaVersion": "coach-operational-launch-checklist-v2",
        "requiredTopLevelKeys": [
            "schemaVersion",
            "checklistVersion",
            "releaseCandidateBuild",
            "completedByRole",
            "summary",
            "items",
        ],
        "owner": "release manager",
        "gate": (
            "M14 launch checklist covering Firestore rules, privacy URL, Settings "
            "privacy link, App Store privacy disclosure review, TestFlight upload, "
            "and release-blocking bug triage."
        ),
        "nextStep": (
            "Complete every required launch item against the release candidate "
            "build and attach the deploy/review/output references."
        ),
    },
}


LIVE_REQUIRED_FIXTURE_IDS = [
    "cold-start-interview-baseline",
    "filler-pressure-prescription",
    "metric-action-without-read",
    "critique-trust-repair",
    "markdown-tts-trust-repair",
    "assistant-explainer-register",
    "authoritative-distance-deep-assessment",
    "what-next-single-move",
    "overclaim-hypothesis-boundary",
    "personal-pattern-hypothesis-confirmation",
    "leadership-transfer-setup",
    "pace-control-next-rep",
    "closing-ask-proof-test",
    "opening-verdict-next-rep",
    "pause-before-answer-drill",
    "concise-answer-next-rep",
    "structure-one-reason-proof",
    "confidence-clean-stop",
    "answer-depth-one-example",
    "closing-stop-no-summary",
]

LIVE_REQUIRED_LONG_FORM_IDS = [
    "long-form-cold-start-interview-baseline-conversation",
    "long-form-filler-pressure-prescription-conversation",
    "long-form-metric-action-without-read-conversation",
    "long-form-critique-trust-repair-conversation",
    "long-form-markdown-tts-trust-repair-conversation",
    "long-form-assistant-explainer-register-conversation",
    "long-form-authoritative-distance-deep-assessment-conversation",
    "long-form-what-next-single-move-conversation",
    "long-form-overclaim-hypothesis-boundary-conversation",
    "long-form-leadership-transfer-setup-conversation",
    "long-form-polite-pushback-attunement-conversation",
]

LIVE_REQUIRED_LONG_FORM_TURN_COUNTS = {
    conversation_id: 5 for conversation_id in LIVE_REQUIRED_LONG_FORM_IDS
}

LIVE_REQUIRED_TURN_DEPTHS = [
    "quickMove",
    "groundedRead",
    "deepAssessment",
    "trustRepair",
]

GENERIC_PLACEHOLDER_REPLY_FRAGMENTS = [
    "focused coach reply with concrete evidence",
    "grounded coach reply with a proof test",
    "generic coach reply",
    "placeholder",
    "practice more and communicate clearly",
    "based on your data",
    "keep practicing and track your progress",
]

PROFESSIONAL_CALIBRATION_PACKET_FILE = "coach-chat-conversation-expert-calibration-v2.json"
PROFESSIONAL_CALIBRATION_PACKET_SCHEMA = "coach-chat-conversation-expert-calibration-v2"
PROFESSIONAL_CALIBRATION_RESULTS_SCHEMA = "coach-chat-conversation-expert-calibration-results-v2"
PROFESSIONAL_CALIBRATION_RUBRIC = "coach-parity-conversation-calibration-v2"
PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION = 2
PROFESSIONAL_CALIBRATION_MIN_CONVERSATION_COUNT = 39
PROFESSIONAL_CALIBRATION_MIN_REVIEW_COUNT = (
    PROFESSIONAL_CALIBRATION_MIN_CONVERSATION_COUNT
    * PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION
)
MIN_TRAJECTORY_CACHE_HIT_RATIO = 0.10


UI_FLOW_BOUNDARY = {
    "maestroSmokeFlows": [
        "maestro/chat_smoke.yaml",
        "maestro/chat_reject_smoke.yaml",
    ],
    "covered": [
        "Ask Noum type-chat happy path with deterministic markdown reply.",
        "Ask Noum deterministic rejection notice path.",
    ],
    "notLaunchProof": [
        "Physical TestFlight device coverage.",
        "Live Activity surface.",
        "AI prompt latency budget on real device.",
        "Soundscape audio-session behavior.",
        "Paywall purchase and receipt path.",
    ],
    "realDeviceArtifact": "coach-real-device-testflight-qa-v2.json",
}


def load_report(path):
    report_path = Path(path)
    with report_path.open(encoding="utf-8") as handle:
        return json.load(handle)


def readiness_from_report(report):
    summary = report.get("summary") if isinstance(report.get("summary"), dict) else {}
    readiness = summary.get("visionProductionReadiness")
    if isinstance(readiness, dict):
        return readiness
    readiness = report.get("visionProductionReadiness")
    return readiness if isinstance(readiness, dict) else None


def local_gates_from_report(report):
    summary = report.get("summary") if isinstance(report.get("summary"), dict) else {}
    return {
        "scoreThresholdsPass": summary.get("scoreThresholdsPass"),
        "realPipelineEvidencePasses": summary.get(
            "realPipelineEvidencePasses",
            summary.get("productionEvidencePasses"),
        ),
        "traceQualityPasses": summary.get("traceQualityPasses"),
        "localAverage": summary.get("average"),
        "localFixtureFailures": summary.get("failureCount"),
    }


def computed_production_ready(readiness):
    if not readiness:
        return False
    blockers = readiness.get("blockers") or []
    return (
        readiness.get("score", 0) >= READY_SCORE and
        readiness.get("claim") == READY_CLAIM and
        not blockers
    )


def local_gate_failures(local_gates):
    failures = []
    for requirement in LOCAL_GATE_REQUIREMENTS:
        if local_gates.get(requirement["key"]) is not True:
            failure = dict(requirement)
            failure["observed"] = local_gates.get(requirement["key"])
            failures.append(failure)
    return failures


def local_target_shape_failures(readiness):
    if not readiness:
        return []
    score = readiness.get("localTargetShapeScore")
    if isinstance(score, (int, float)) and score >= READY_LOCAL_TARGET_SHAPE_SCORE:
        return []
    return [{
        "key": "localTargetShapeScore",
        "label": "localTargetShapeScore",
        "observed": score,
        "gate": (
            "The Swift VISION audit must report localTargetShapeScore >= "
            f"{READY_LOCAL_TARGET_SHAPE_SCORE}; barely passing fixture floors "
            "are not enough for launch."
        ),
        "nextStep": (
            "Improve low-scoring Ask Noum / Live Coach fixtures, regenerate "
            "the app-path artifacts, and rerun the Swift production-readiness "
            "manifest before treating local quality as launch-shaped."
        ),
    }]


def local_readiness_failures(local_gates, readiness):
    return local_gate_failures(local_gates) + local_target_shape_failures(readiness)


def normalized_report_path(report_path):
    path = Path(report_path)
    if path.is_absolute():
        return path.resolve(strict=False)
    parts = path.parts
    if len(parts) >= 2 and parts[0] == "tools" and parts[1] == "coach-arena":
        return (REPO_ROOT / path).resolve(strict=False)
    return (ARENA_ROOT / path).resolve(strict=False)


def report_source_audit(report, report_path):
    report_family = report.get("reportFamily")
    normalized_path = normalized_report_path(report_path)
    canonical_dir = CANONICAL_APP_PATH_REPORT_DIR.resolve(strict=False)
    canonical_path = (
        normalized_path == canonical_dir or
        canonical_dir in normalized_path.parents
    )
    return {
        "validationBoundary": (
            "Launch readiness only accepts the canonical Swift app-path report. "
            "Prompt-layer replay and stale diagnostic reports are useful for "
            "debugging, but cannot be readiness evidence."
        ),
        "reportFamily": report_family,
        "requiredReportFamily": "app-path",
        "normalizedReportPath": str(normalized_path),
        "canonicalReportDir": str(canonical_dir),
        "canonicalPath": canonical_path,
        "passes": report_family == "app-path" and canonical_path,
    }


def report_source_gate_failures(report_source):
    failures = []
    if report_source.get("reportFamily") != report_source.get("requiredReportFamily"):
        failures.append({
            "key": "reportFamily",
            "label": "reportFamily",
            "observed": report_source.get("reportFamily"),
            "gate": (
                "The readiness gate must read an app-path report generated from "
                "the Swift/XCTest app-path dump, not a prompt-layer replay report."
            ),
            "nextStep": (
                "Refresh the canonical app-path evidence with "
                "`./tools/coach-arena/run.sh app-path` after regenerating the "
                "XCTest dump."
            ),
        })
    if report_source.get("canonicalPath") is not True:
        failures.append({
            "key": "reportPath",
            "label": "reportPath",
            "observed": report_source.get("normalizedReportPath"),
            "gate": (
                "The readiness gate must read the canonical "
                "tools/coach-arena/reports/app-path report, not diagnostic or "
                "ad hoc output."
            ),
            "nextStep": (
                "Use `./tools/coach-arena/run.sh readiness` with the canonical "
                "app-path latest report; keep stale diagnostics in "
                "reports/app-path-diagnostic or another non-readiness location."
            ),
        })
    return failures


def _collect_source_values(value, key):
    values = []
    if isinstance(value, dict):
        for current_key, current_value in value.items():
            if current_key == key and isinstance(current_value, str) and current_value.strip():
                values.append(current_value.strip())
            else:
                values.extend(_collect_source_values(current_value, key))
    elif isinstance(value, list):
        for item in value:
            values.extend(_collect_source_values(item, key))
    return values


def _sidecar_value(artifact_audit, file_name):
    for item in artifact_audit.get("sourceSidecars") or []:
        if item.get("fileName") == file_name and item.get("present"):
            value = (item.get("valuePreview") or "").strip()
            return value or None
    return None


def current_git_commit(repo_root):
    proc = subprocess.run(
        ["git", "-C", str(Path(repo_root)), "rev-parse", "--short", "HEAD"],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        return None
    return proc.stdout.strip() or None


def current_dirty_coach_source_files(repo_root):
    proc = subprocess.run(
        ["git", "-C", str(Path(repo_root)), "status", "--porcelain", "--", *COACH_SOURCE_STATUS_PATHS],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        return ["<git-status-unavailable>"]
    paths = []
    for line in proc.stdout.splitlines():
        if len(line) < 4:
            continue
        path = line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        if path:
            paths.append(path)
    return sorted(set(paths))


def git_commit_is_ancestor(repo_root, ancestor, descendant):
    if not ancestor or not descendant:
        return False
    proc = subprocess.run(
        [
            "git", "-C", str(Path(repo_root)), "merge-base", "--is-ancestor",
            ancestor, descendant,
        ],
        text=True,
        capture_output=True,
    )
    return proc.returncode == 0


def coach_source_fingerprint(repo_root, paths=COACH_SOURCE_STATUS_PATHS):
    root = Path(repo_root)
    if not any((root / rel_path).exists() for rel_path in paths):
        return None

    digest = hashlib.sha256()
    for rel_path in sorted(paths):
        path = root / rel_path
        digest.update(rel_path.encode("utf-8"))
        digest.update(b"\0")
        if path.exists():
            digest.update(path.read_bytes())
        else:
            digest.update(b"<missing>")
        digest.update(b"\0")
    return "sha256:" + digest.hexdigest()


def _current_source_mismatch(label, current_value, sidecar_value, report_values):
    if not current_value:
        return None
    mismatched_against = []
    if sidecar_value and sidecar_value != current_value:
        mismatched_against.append("sidecar")
    if report_values and current_value not in report_values:
        mismatched_against.append("report")
    if not mismatched_against:
        return None
    return {
        "label": label,
        "current": current_value,
        "sidecar": sidecar_value,
        "reportValues": report_values,
        "mismatchedAgainst": mismatched_against,
    }


def source_freshness_audit(report, artifact_audit, repo_root=None):
    report_fingerprints = sorted(set(
        _collect_source_values(report, "sourceFingerprint") +
        _collect_source_values(report, "sourceCoachFingerprint")
    ))
    report_commits = sorted(set(
        _collect_source_values(report, "gitCommit") +
        _collect_source_values(report, "sourceGitCommit")
    ))
    sidecar_fingerprint = _sidecar_value(artifact_audit, "source-coach-fingerprint.txt")
    sidecar_commit = _sidecar_value(artifact_audit, "source-git-commit.txt")
    current_fingerprint = coach_source_fingerprint(repo_root) if repo_root else None
    current_commit = current_git_commit(repo_root) if repo_root else None
    dirty_source_files = current_dirty_coach_source_files(repo_root) if repo_root else []

    mismatches = []
    if sidecar_fingerprint and report_fingerprints and sidecar_fingerprint not in report_fingerprints:
        mismatches.append({
            "label": "sourceCoachFingerprint",
            "sidecar": sidecar_fingerprint,
            "reportValues": report_fingerprints,
        })
    if sidecar_commit and report_commits and sidecar_commit not in report_commits:
        mismatches.append({
            "label": "sourceGitCommit",
            "sidecar": sidecar_commit,
            "reportValues": report_commits,
        })

    fingerprint_current_mismatch = _current_source_mismatch(
        "currentCoachFingerprint",
        current_fingerprint,
        sidecar_fingerprint,
        report_fingerprints,
    )
    commit_current_mismatch = _current_source_mismatch(
        "currentGitCommit",
        current_commit,
        sidecar_commit,
        report_commits,
    )
    clean_ancestor_commits_accepted = []
    if commit_current_mismatch and repo_root:
        source_commits = sorted(set(
            [value for value in [sidecar_commit, *report_commits] if value]
        ))
        fingerprints_match_current = bool(
            current_fingerprint and
            sidecar_fingerprint == current_fingerprint and
            report_fingerprints and
            all(value == current_fingerprint for value in report_fingerprints)
        )
        clean_ancestor_commits_accepted = [
            value for value in source_commits
            if git_commit_is_ancestor(repo_root, value, current_commit)
        ]
        if (
            not dirty_source_files and
            fingerprints_match_current and
            source_commits and
            len(clean_ancestor_commits_accepted) == len(source_commits)
        ):
            commit_current_mismatch = None

    current_mismatches = [
        mismatch for mismatch in [fingerprint_current_mismatch, commit_current_mismatch]
        if mismatch
    ]

    return {
        "validationBoundary": (
            "Source freshness compares staged source sidecars, embedded report "
            "trace metadata, and the current checkout's coach-source fingerprint "
            "when available; missing sidecars are handled by the artifact gate."
        ),
        "currentCoachFingerprint": current_fingerprint,
        "currentGitCommit": current_commit,
        "dirtyCoachSourceFiles": dirty_source_files,
        "cleanAncestorCommitsAccepted": clean_ancestor_commits_accepted,
        "sidecarCoachFingerprint": sidecar_fingerprint,
        "sidecarGitCommit": sidecar_commit,
        "reportCoachFingerprints": report_fingerprints,
        "reportGitCommits": report_commits,
        "mismatches": mismatches,
        "currentMismatches": current_mismatches,
        "passes": not mismatches and not current_mismatches,
    }


def source_freshness_gate_failures(source_audit):
    failures = []
    for mismatch in source_audit.get("mismatches") or []:
        failures.append({
            "key": mismatch["label"],
            "label": mismatch["label"],
            "observed": "staleReport",
            "gate": (
                "The app-path report must be generated from the same Swift "
                "coach source fingerprint and git commit staged in the dump "
                "directory."
            ),
            "nextStep": (
                "Regenerate the XCTest app-path artifact dump, rerun "
                "`./tools/coach-arena/run.sh app-path-source`, then rerun "
                "app-path scoring so report traces match the current source."
            ),
            "sidecar": mismatch.get("sidecar"),
            "reportValues": mismatch.get("reportValues", []),
        })
    for mismatch in source_audit.get("currentMismatches") or []:
        failures.append({
            "key": mismatch["label"],
            "label": mismatch["label"],
            "observed": "staleCurrentSource",
            "gate": (
                "The readiness report and dump sidecars must describe the "
                "current checkout's Swift coach source fingerprint and git "
                "commit before local evidence can support launch readiness."
            ),
            "nextStep": (
                "Run `./tools/coach-arena/run.sh app-path-source`, regenerate "
                "the XCTest app-path artifact dump from the current checkout, "
                "then rerun app-path scoring and readiness."
            ),
            "current": mismatch.get("current"),
            "sidecar": mismatch.get("sidecar"),
            "reportValues": mismatch.get("reportValues", []),
            "mismatchedAgainst": mismatch.get("mismatchedAgainst", []),
        })
    return failures


def computed_launch_ready(
    readiness,
    local_gates,
    artifact_audit=None,
    ops_preflight=None,
    ops_live_probe=None,
    source_freshness_audit=None,
    report_source_audit=None,
):
    artifact_failures = artifact_gate_failures(artifact_audit) if artifact_audit else []
    ops_failures = operational_static_gate_failures(ops_preflight) if ops_preflight else []
    ops_live_failures = (
        operational_live_gate_failures(ops_live_probe) if ops_live_probe else []
    )
    source_failures = (
        source_freshness_gate_failures(source_freshness_audit)
        if source_freshness_audit else []
    )
    report_source_failures = (
        report_source_gate_failures(report_source_audit)
        if report_source_audit else []
    )
    return (
        computed_production_ready(readiness) and
        not report_source_failures and
        not local_readiness_failures(local_gates, readiness) and
        not source_failures and
        not artifact_failures and
        not ops_failures and
        not ops_live_failures
    )


def blocking_requirements(readiness):
    blockers = readiness.get("blockers") if readiness else None
    if blockers is None:
        blockers = list(EVIDENCE_REQUIREMENTS.keys())
    requirements = []
    for blocker in blockers:
        requirement = dict(EVIDENCE_REQUIREMENTS.get(blocker, {}))
        requirement["blocker"] = blocker
        if "artifact" not in requirement:
            requirement["artifact"] = "not mapped"
            requirement["gate"] = "Unknown VISION blocker. Update readiness_gate.py."
            requirement["nextStep"] = "Map this blocker to a concrete evidence artifact."
        requirements.append(requirement)
    return requirements


def trimmed_non_empty(value):
    if not isinstance(value, str):
        return None
    trimmed = value.strip()
    return trimmed or None


def strict_int(value):
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def finite_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return value if math.isfinite(value) else None


def normalized_string_list(value):
    if not isinstance(value, list):
        return [], True
    normalized = [
        item.strip() for item in value
        if isinstance(item, str) and item.strip()
    ]
    return normalized, len(normalized) != len(value)


def normalized_reply_key(value):
    return re.sub(r"\s+", " ", value or "").strip().lower()


def clean_issue_value(value):
    return normalized_reply_key(value) in {"none", "passed", "clean", "no issue", "no issues"}


def generic_placeholder_reply(value):
    normalized = normalized_reply_key(value)
    if not normalized:
        return False
    return any(fragment in normalized for fragment in GENERIC_PLACEHOLDER_REPLY_FRAGMENTS)


def row_identifier(row):
    if not isinstance(row, dict):
        return None
    value = row.get("fixtureID")
    return value.strip() if isinstance(value, str) and value.strip() else None


def row_has_provider_evidence(row):
    return bool(
        isinstance(row, dict)
        and trimmed_non_empty(row.get("providerChosen"))
        and trimmed_non_empty(row.get("providerModel"))
    )


def row_has_readiness_telemetry(row):
    if not isinstance(row, dict):
        return False
    proof_hash = trimmed_non_empty(row.get("assessmentProofTestHash"))
    reply = trimmed_non_empty(row.get("reply"))
    quality = trimmed_non_empty(row.get("qualityIssue"))
    semantic = trimmed_non_empty(row.get("semanticGateIssue"))
    immediate_expected = row.get("immediateCoachReadExpected") is True
    immediate_satisfied = not immediate_expected or row.get("immediateCoachReadShown") is True
    return (
        trimmed_non_empty(row.get("turnDepth")) is not None
        and finite_number(row.get("timeToFirstVisibleTokenMs")) is not None
        and finite_number(row.get("assessmentConfidence")) is not None
        and isinstance(row.get("trajectoryCacheHit"), bool)
        and proof_hash is not None
        and reply is not None
        and isinstance(row.get("passesRubric"), bool)
        and isinstance(row.get("visionPassesProductionFloor"), bool)
        and quality is not None
        and semantic is not None
        and isinstance(row.get("reliabilityIssues"), list)
        and immediate_satisfied
    )


def row_has_clean_production_telemetry(row):
    return (
        isinstance(row, dict)
        and row.get("liveProductionFloor") is True
        and row.get("passesRubric") is True
        and row.get("visionPassesProductionFloor") is True
        and clean_issue_value(row.get("qualityIssue"))
        and clean_issue_value(row.get("semanticGateIssue"))
        and row.get("reliabilityIssues") == []
    )


def duplicated_reply_ids(rows):
    first_id_by_reply = {}
    duplicate_ids_by_reply = set()
    for row in rows:
        if not isinstance(row, dict):
            continue
        key = normalized_reply_key(row.get("reply"))
        if not key:
            continue
        row_id = row_identifier(row) or "unknown"
        if key in first_id_by_reply:
            duplicate_ids_by_reply.add(first_id_by_reply[key])
            duplicate_ids_by_reply.add(row_id)
        else:
            first_id_by_reply[key] = row_id
    return sorted(duplicate_ids_by_reply)


def min_trajectory_cache_hits(row_count):
    if row_count <= 0:
        return 0
    return max(1, math.ceil(row_count * MIN_TRAJECTORY_CACHE_HIT_RATIO))


def append_ids_failure(failures, label, ids):
    if ids:
        failures.append(f"{label}={','.join(ids)}")


def rating_minimum(ratings):
    if not isinstance(ratings, dict):
        return 0
    expected = [
        "diagnosis",
        "caseFormulation",
        "intervention",
        "adaptation",
        "perceptionHonesty",
        "transferSetup",
        "trustRepair",
        "overallUsefulness",
    ]
    values = []
    for key in expected:
        value = finite_number(ratings.get(key))
        values.append(value if value is not None else 0)
    return min(values) if values else 0


def professional_row_passes_calibration_floor(row):
    if not isinstance(row, dict):
        return False
    return (
        row.get("calibrationDecision") in {"roughTie", "noumBetter"}
        and row.get("wouldUseWithClient") is True
        and rating_minimum(row.get("ratings")) >= 4
        and strict_int(row.get("humanCoachReferenceCount")) is not None
        and strict_int(row.get("humanCoachReferenceCount")) > 0
        and row.get("overclaimNotes") == []
    )


def calibration_packet_context(root):
    packet_path = Path(root) / PROFESSIONAL_CALIBRATION_PACKET_FILE
    context = {
        "packetPath": str(packet_path),
        "packetPresent": packet_path.is_file(),
        "packetFailures": [],
        "requiredConversationIDs": [],
        "requiredReviewCount": None,
        "requiredReviewsPerConversation": PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION,
        "sourcePacketFingerprint": None,
        "sourcePacketSchemaVersion": PROFESSIONAL_CALIBRATION_PACKET_SCHEMA,
    }
    if not packet_path.is_file():
        context["packetFailures"].append("sourcePacketMissing")
        return context
    try:
        payload = json.loads(packet_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        context["packetFailures"].append(f"sourcePacketInvalidJSON:{exc.msg}")
        return context
    if not isinstance(payload, dict):
        context["packetFailures"].append("sourcePacketInvalidTopLevelType")
        return context

    schema = payload.get("schemaVersion")
    if schema != PROFESSIONAL_CALIBRATION_PACKET_SCHEMA:
        context["packetFailures"].append(f"sourcePacketSchemaVersion={schema}")
    fingerprint = trimmed_non_empty(payload.get("sourceCorpusFingerprint"))
    if fingerprint is None:
        context["packetFailures"].append("sourcePacketFingerprintMissing")
    context["sourcePacketFingerprint"] = fingerprint
    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    conversation_ids = [
        item.get("conversationID").strip()
        for item in rows
        if isinstance(item, dict)
        and isinstance(item.get("conversationID"), str)
        and item.get("conversationID").strip()
    ]
    context["requiredConversationIDs"] = conversation_ids
    reviews_per_conversation = payload.get("requiredIndependentReviewsPerConversation")
    if strict_int(reviews_per_conversation) is not None and reviews_per_conversation > 0:
        context["requiredReviewsPerConversation"] = reviews_per_conversation
    required_count = payload.get("requiredReviewCount")
    if strict_int(required_count) is not None and required_count > 0:
        context["requiredReviewCount"] = required_count
    else:
        context["requiredReviewCount"] = len(conversation_ids) * context["requiredReviewsPerConversation"]
    if payload.get("conversationCount") != len(conversation_ids):
        context["packetFailures"].append("sourcePacketConversationCountMismatch")
    if len(set(conversation_ids)) != len(conversation_ids):
        context["packetFailures"].append("sourcePacketDuplicateConversationIDs")
    if context["requiredReviewCount"] != len(conversation_ids) * context["requiredReviewsPerConversation"]:
        context["packetFailures"].append("sourcePacketReviewCountMismatch")
    if len(conversation_ids) < PROFESSIONAL_CALIBRATION_MIN_CONVERSATION_COUNT:
        context["packetFailures"].append("sourcePacketBelowConversationFloor")
    if context["requiredReviewCount"] < PROFESSIONAL_CALIBRATION_MIN_REVIEW_COUNT:
        context["packetFailures"].append("sourcePacketBelowReviewFloor")
    return context


def professional_calibration_contract_failures(payload, context=None):
    failures = []
    context = context or {}
    summary = payload.get("summary") if isinstance(payload.get("summary"), dict) else {}
    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    required_ids = context.get("requiredConversationIDs") or []
    required_reviews_per_conversation = (
        context.get("requiredReviewsPerConversation")
        or PROFESSIONAL_CALIBRATION_DEFAULT_REVIEWS_PER_CONVERSATION
    )
    required_count = context.get("requiredReviewCount")
    if strict_int(required_count) is None or required_count <= 0:
        required_count = len(required_ids) * required_reviews_per_conversation
    required_count = max(required_count, PROFESSIONAL_CALIBRATION_MIN_REVIEW_COUNT)

    for packet_failure in context.get("packetFailures") or []:
        if packet_failure not in failures:
            failures.append(packet_failure)

    if payload.get("sourcePacketSchemaVersion") != PROFESSIONAL_CALIBRATION_PACKET_SCHEMA:
        failures.append(f"sourcePacketSchemaVersion={payload.get('sourcePacketSchemaVersion')}")
    source_fingerprint = trimmed_non_empty(payload.get("sourcePacketFingerprint"))
    expected_fingerprint = trimmed_non_empty(context.get("sourcePacketFingerprint"))
    if source_fingerprint is None:
        failures.append("sourcePacketFingerprintMissing")
    elif expected_fingerprint and source_fingerprint != expected_fingerprint:
        failures.append("sourcePacketFingerprintMismatch")
    elif expected_fingerprint is None:
        failures.append("sourcePacketFingerprintUnavailable")
    if payload.get("rubricVersion") != PROFESSIONAL_CALIBRATION_RUBRIC:
        failures.append(f"rubricVersion={payload.get('rubricVersion')}")

    review_count = payload.get("reviewCount")
    review_count = strict_int(review_count)
    if review_count is None or review_count < required_count or len(rows) < required_count:
        failures.append("fewerThanRequiredReviews")
        failures.append("missingFullConversationCoverage")
    if review_count is not None and review_count != len(rows):
        failures.append("rowCountMismatch")
    if summary.get("rowCount") != len(rows):
        failures.append("rowCountMismatch")

    review_slots = []
    rows_by_conversation = {}
    passing_rows_by_conversation = {}
    reviewer_ids = []
    passing_rows = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        conversation_id = trimmed_non_empty(row.get("conversationID")) or ""
        reviewer_id = trimmed_non_empty(row.get("reviewerID")) or ""
        review_slots.append(f"{conversation_id}|{reviewer_id}")
        rows_by_conversation.setdefault(conversation_id, []).append(row)
        if reviewer_id:
            reviewer_ids.append(reviewer_id)
        if professional_row_passes_calibration_floor(row):
            passing_rows.append(row)
            passing_rows_by_conversation.setdefault(conversation_id, []).append(row)

    if len(set(review_slots)) != len(review_slots):
        failures.append("duplicateConversationReviewerPairs")

    observed_ids = set(rows_by_conversation)
    if required_ids:
        missing_ids = [
            conversation_id for conversation_id in required_ids
            if conversation_id not in observed_ids
        ]
        append_ids_failure(failures, "missingRequiredConversations", missing_ids)
        unexpected_ids = sorted([
            conversation_id for conversation_id in observed_ids
            if conversation_id and conversation_id not in set(required_ids)
        ])
        append_ids_failure(failures, "unexpectedConversationIDs", unexpected_ids)
        insufficient_review_ids = [
            conversation_id for conversation_id in required_ids
            if len(rows_by_conversation.get(conversation_id, [])) < required_reviews_per_conversation
        ]
        append_ids_failure(
            failures,
            "insufficientReviewsPerConversation",
            insufficient_review_ids,
        )
        insufficient_passing_ids = [
            conversation_id for conversation_id in required_ids
            if len(passing_rows_by_conversation.get(conversation_id, [])) < required_reviews_per_conversation
        ]
        append_ids_failure(
            failures,
            "insufficientPassingReviewsPerConversation",
            insufficient_passing_ids,
        )
        insufficient_diversity_ids = []
        for conversation_id in required_ids:
            reviewers = {
                trimmed_non_empty(row.get("reviewerID"))
                for row in rows_by_conversation.get(conversation_id, [])
                if isinstance(row, dict)
            }
            reviewers.discard(None)
            if len(reviewers) < required_reviews_per_conversation:
                insufficient_diversity_ids.append(conversation_id)
        append_ids_failure(
            failures,
            "insufficientReviewerDiversity",
            insufficient_diversity_ids,
        )

    unique_reviewer_ids = set(reviewer_ids)
    reviewer_count = strict_int(summary.get("reviewerCount"))
    completed_review_count = strict_int(summary.get("completedReviewCount"))
    passing_calibration_count = strict_int(summary.get("passingCalibrationCount"))
    would_use_count = strict_int(summary.get("wouldUseWithClientCount"))
    unsafe_count = strict_int(summary.get("unsafeOrUnreadyCount"))
    minimum_usefulness = finite_number(summary.get("minimumOverallUsefulness"))
    average_usefulness = finite_number(summary.get("averageOverallUsefulness"))
    invalid_summary_fields = [
        key for key, value in [
            ("reviewerCount", reviewer_count),
            ("completedReviewCount", completed_review_count),
            ("passingCalibrationCount", passing_calibration_count),
            ("wouldUseWithClientCount", would_use_count),
            ("unsafeOrUnreadyCount", unsafe_count),
            ("minimumOverallUsefulness", minimum_usefulness),
            ("averageOverallUsefulness", average_usefulness),
        ]
        if value is None
    ]
    append_ids_failure(failures, "invalidSummaryTelemetry", invalid_summary_fields)

    if (
        reviewer_count != len(unique_reviewer_ids)
        or reviewer_count is None
        or reviewer_count < required_reviews_per_conversation
        or trimmed_non_empty(payload.get("reviewerRole")) is None
        or any(trimmed_non_empty(row.get("reviewerID")) is None for row in rows if isinstance(row, dict))
    ):
        failures.append("missingProfessionalReviewer")
    if completed_review_count != len(rows):
        failures.append("incompleteReviews")
    if (
        passing_calibration_count != len(passing_rows)
        or passing_calibration_count is None
        or passing_calibration_count < required_count
    ):
        failures.append("insufficientPassingCalibrationRows")
    if would_use_count is None or would_use_count < required_count:
        failures.append("insufficientWouldUseWithClientRows")
    if unsafe_count is None or unsafe_count > 0 or any(
        isinstance(row, dict) and row.get("calibrationDecision") == "unsafeOrUnready"
        for row in rows
    ):
        failures.append("unsafeOrUnreadyRows")
    if any(not professional_row_passes_calibration_floor(row) for row in rows):
        failures.append("rowCalibrationFloorFailures")
    if any(
        isinstance(row, dict)
        and professional_row_passes_calibration_floor(row)
        and row.get("revisionNotes") not in ([], None)
        for row in rows
    ):
        failures.append("unresolvedRevisionNotes")
    if (
        minimum_usefulness is None
        or average_usefulness is None
        or minimum_usefulness < 4
        or average_usefulness < 4.0
    ):
        failures.append("overallUsefulnessBelowFloor")
    readiness_warnings = summary.get("readinessWarnings")
    readiness_warnings = readiness_warnings if isinstance(readiness_warnings, list) else []
    append_ids_failure(failures, "readinessWarnings", [
        item for item in readiness_warnings if isinstance(item, str) and item.strip()
    ])

    deduped = []
    for failure in failures:
        if failure not in deduped:
            deduped.append(failure)
    return deduped


def live_provider_sweep_contract_failures(payload, source_expectations=None):
    failures = []
    source_expectations = source_expectations or {}
    rows = payload.get("rows") if isinstance(payload.get("rows"), list) else []
    summary = payload.get("summary") if isinstance(payload.get("summary"), dict) else {}
    long_form_passing, malformed_passing_ids = normalized_string_list(
        payload.get("longFormConversationIDsPassingProductionFloor")
    )
    long_form_failures, malformed_failure_ids = normalized_string_list(
        payload.get("longFormConversationFailureIDs")
    )
    long_form_details = payload.get("longFormConversations")
    long_form_details = long_form_details if isinstance(long_form_details, list) else []
    if malformed_passing_ids:
        failures.append("invalidLongFormPassingIDs")
    if malformed_failure_ids:
        failures.append("invalidLongFormFailureIDs")
    if any(not isinstance(item, dict) for item in long_form_details):
        failures.append("invalidDetailedLongFormConversationRows")

    source_git_commit = trimmed_non_empty(payload.get("sourceGitCommit"))
    source_coach_fingerprint = trimmed_non_empty(payload.get("sourceCoachFingerprint"))
    if source_git_commit is None:
        failures.append("sourceGitCommitMissing")
    if source_coach_fingerprint is None:
        failures.append("sourceCoachFingerprintMissing")

    expected_commit = trimmed_non_empty(source_expectations.get("source-git-commit.txt"))
    expected_fingerprint = trimmed_non_empty(source_expectations.get("source-coach-fingerprint.txt"))
    if expected_commit and source_git_commit and source_git_commit != expected_commit:
        failures.append("sourceGitCommitMismatch")
    if expected_fingerprint and source_coach_fingerprint and source_coach_fingerprint != expected_fingerprint:
        failures.append("sourceCoachFingerprintMismatch")

    freshness_failures = payload.get("sourceFreshnessFailures")
    if freshness_failures is not None:
        if not isinstance(freshness_failures, list):
            failures.append("invalidSourceFreshnessFailures")
        else:
            for freshness_failure in freshness_failures:
                reason = trimmed_non_empty(freshness_failure)
                if reason and reason not in failures:
                    failures.append(reason)

    fixture_count = payload.get("fixtureCount")
    fixture_count = strict_int(fixture_count)
    if fixture_count is None or fixture_count < 10 or len(rows) < 10:
        failures.append("fewerThanTenRows")
    if fixture_count is None or fixture_count < len(LIVE_REQUIRED_FIXTURE_IDS) or len(rows) < len(LIVE_REQUIRED_FIXTURE_IDS):
        failures.append("missingLatestTranscriptCoverage")

    if fixture_count is not None and fixture_count != len(rows):
        failures.append("rowCountMismatch")
    if summary.get("rowCount") != len(rows):
        failures.append("rowCountMismatch")

    fixture_ids = [row_identifier(row) for row in rows]
    fixture_ids = [item for item in fixture_ids if item]
    if len(set(fixture_ids)) != len(fixture_ids):
        failures.append("duplicateFixtureIDs")
    missing_fixture_ids = [
        fixture_id for fixture_id in LIVE_REQUIRED_FIXTURE_IDS
        if fixture_id not in set(fixture_ids)
    ]
    append_ids_failure(failures, "missingRequiredFixtures", missing_fixture_ids)

    long_form_count = strict_int(payload.get("longFormConversationCount"))
    if (
        long_form_count is None
        or long_form_count < len(LIVE_REQUIRED_LONG_FORM_IDS)
        or len(long_form_passing) < len(LIVE_REQUIRED_LONG_FORM_IDS)
    ):
        failures.append("missingLiveLongFormConversationCoverage")
    if long_form_count is not None and long_form_count != len(long_form_passing) + len(long_form_failures):
        failures.append("longFormConversationCountMismatch")

    long_form_passing_ids = long_form_passing
    if len(set(long_form_passing_ids)) != len(long_form_passing_ids):
        failures.append("duplicateLongFormConversationIDs")
    missing_long_form_ids = [
        conversation_id for conversation_id in LIVE_REQUIRED_LONG_FORM_IDS
        if conversation_id not in set(long_form_passing_ids)
    ]
    append_ids_failure(failures, "missingRequiredLongFormConversations", missing_long_form_ids)
    unexpected_long_form_ids = sorted([
        conversation_id for conversation_id in set(long_form_passing_ids + long_form_failures)
        if conversation_id not in set(LIVE_REQUIRED_LONG_FORM_IDS)
    ])
    append_ids_failure(
        failures,
        "unexpectedLongFormConversationIDs",
        unexpected_long_form_ids,
    )

    detailed_ids = [
        item.get("conversationID", "").strip()
        for item in long_form_details
        if isinstance(item, dict) and isinstance(item.get("conversationID"), str)
    ]
    if not long_form_details:
        failures.append("missingDetailedLongFormConversations")
    if len(set(detailed_ids)) != len(detailed_ids):
        failures.append("duplicateDetailedLongFormConversationIDs")
    if long_form_count is not None and long_form_details and len(long_form_details) != long_form_count:
        failures.append("detailedLongFormConversationCountMismatch")
    missing_detailed_ids = [
        conversation_id for conversation_id in LIVE_REQUIRED_LONG_FORM_IDS
        if conversation_id not in set(detailed_ids)
    ]
    append_ids_failure(
        failures,
        "missingDetailedLongFormConversations",
        missing_detailed_ids,
    )
    unexpected_detailed_ids = sorted([
        conversation_id for conversation_id in set(detailed_ids)
        if conversation_id not in set(LIVE_REQUIRED_LONG_FORM_IDS)
    ])
    append_ids_failure(
        failures,
        "unexpectedDetailedLongFormConversations",
        unexpected_detailed_ids,
    )

    detailed_passing_ids = {
        item.get("conversationID")
        for item in long_form_details
        if isinstance(item, dict) and item.get("liveProductionFloor") is True
    }
    detailed_failure_ids = {
        item.get("conversationID")
        for item in long_form_details
        if isinstance(item, dict) and item.get("liveProductionFloor") is not True
    }
    if long_form_details and set(long_form_passing_ids) != detailed_passing_ids:
        failures.append("longFormConversationPassingSummaryMismatch")
    if long_form_details and set(long_form_failures) != detailed_failure_ids:
        failures.append("longFormConversationFailureSummaryMismatch")

    malformed_long_form = []
    failed_long_form = []
    missing_detailed_provider = []
    missing_detailed_telemetry = []
    detailed_gate_failures = []
    duplicated_detailed_replies = []
    generic_detailed_replies = []
    for conversation in long_form_details:
        if not isinstance(conversation, dict):
            continue
        conversation_id = conversation.get("conversationID") or "unknown"
        nested_rows = conversation.get("rows") if isinstance(conversation.get("rows"), list) else []
        observed = strict_int(conversation.get("observedTurnCount"))
        expected = strict_int(conversation.get("expectedTurnCount"))
        required_expected = LIVE_REQUIRED_LONG_FORM_TURN_COUNTS.get(conversation_id)
        if (
            not nested_rows
            or observed != len(nested_rows)
            or observed != expected
            or expected != required_expected
        ):
            malformed_long_form.append(conversation_id)
        if (
            conversation.get("liveProductionFloor") is not True
            or conversation.get("failure") is not None
            or any(row.get("liveProductionFloor") is not True for row in nested_rows if isinstance(row, dict))
        ):
            failed_long_form.append(conversation_id)
        if any(not row_has_provider_evidence(row) for row in nested_rows):
            missing_detailed_provider.append(conversation_id)
        if any(not row_has_readiness_telemetry(row) for row in nested_rows):
            missing_detailed_telemetry.append(conversation_id)
        if any(not row_has_clean_production_telemetry(row) for row in nested_rows):
            detailed_gate_failures.append(conversation_id)
        if duplicated_reply_ids(nested_rows):
            duplicated_detailed_replies.append(conversation_id)
        if any(generic_placeholder_reply(row.get("reply")) for row in nested_rows if isinstance(row, dict)):
            generic_detailed_replies.append(conversation_id)

    append_ids_failure(failures, "malformedDetailedLongFormConversations", malformed_long_form)
    append_ids_failure(failures, "detailedLongFormProductionFloorFailures", failed_long_form)
    append_ids_failure(failures, "missingDetailedLongFormProviderEvidence", missing_detailed_provider)
    append_ids_failure(failures, "missingDetailedLongFormTelemetry", missing_detailed_telemetry)
    append_ids_failure(failures, "detailedLongFormGateTelemetryFailures", detailed_gate_failures)
    append_ids_failure(failures, "duplicatedDetailedLongFormReplies", duplicated_detailed_replies)
    append_ids_failure(failures, "genericDetailedLongFormReplies", generic_detailed_replies)

    latest_provider_failures = [
        row_identifier(row) or "unknown" for row in rows
        if not row_has_provider_evidence(row)
    ]
    latest_telemetry_failures = [
        row_identifier(row) or "unknown" for row in rows
        if not row_has_readiness_telemetry(row)
    ]
    latest_gate_failures = [
        row_identifier(row) or "unknown" for row in rows
        if not row_has_clean_production_telemetry(row)
    ]
    append_ids_failure(failures, "latestTurnProviderEvidenceFailures", latest_provider_failures)
    append_ids_failure(failures, "latestTurnReadinessTelemetryFailures", latest_telemetry_failures)
    append_ids_failure(failures, "latestTurnGateTelemetryFailures", latest_gate_failures)

    trajectory_cache_hit_rows = [
        row_identifier(row) or "unknown" for row in rows
        if isinstance(row, dict) and row.get("trajectoryCacheHit") is True
    ]
    required_trajectory_hits = min_trajectory_cache_hits(len(rows))
    summary_trajectory_hits = strict_int(summary.get("trajectoryCacheHitCount"))
    if (
        "trajectoryCacheHitCount" in summary
        and summary_trajectory_hits != len(trajectory_cache_hit_rows)
    ):
        failures.append("trajectoryCacheHitSummaryMismatch")
    if len(trajectory_cache_hit_rows) < required_trajectory_hits:
        failures.append(
            "weakTrajectoryCacheCoverage="
            f"{len(trajectory_cache_hit_rows)}/{required_trajectory_hits}"
        )

    duplicated_latest_replies = duplicated_reply_ids(rows)
    append_ids_failure(failures, "duplicatedLatestTurnReplies", duplicated_latest_replies)
    generic_latest_replies = [
        row_identifier(row) or "unknown" for row in rows
        if isinstance(row, dict) and generic_placeholder_reply(row.get("reply"))
    ]
    append_ids_failure(failures, "genericLatestTurnReplies", generic_latest_replies)

    observed_depths = {
        row.get("turnDepth") for row in rows
        if isinstance(row, dict) and isinstance(row.get("turnDepth"), str)
    }
    missing_depths = [
        depth for depth in LIVE_REQUIRED_TURN_DEPTHS
        if depth not in observed_depths
    ]
    append_ids_failure(failures, "missingTurnDepthCoverage", missing_depths)

    provider_chain = payload.get("providerChain")
    if not isinstance(provider_chain, list) or not provider_chain or latest_provider_failures:
        failures.append("missingProviderEvidence")
    if payload.get("passesProductionFloor") is not True:
        failures.append("passesProductionFloor=false")
    if payload.get("passesRunReadinessFloor") is not True:
        failures.append("passesRunReadinessFloor=false")
    production_failure_count = strict_int(summary.get("productionFloorFailureCount"))
    immediate_missing_count = strict_int(summary.get("immediateCoachReadMissingCount"))
    confidence_distinct_count = strict_int(summary.get("assessmentConfidenceDistinctRoundedCount"))
    unique_proof_count = strict_int(summary.get("uniqueProofTestHashCount"))
    repeated_proof_count = strict_int(summary.get("repeatedProofTestHashCount"))
    invalid_summary_fields = [
        key for key, value in [
            ("productionFloorFailureCount", production_failure_count),
            ("immediateCoachReadMissingCount", immediate_missing_count),
            ("assessmentConfidenceDistinctRoundedCount", confidence_distinct_count),
            ("uniqueProofTestHashCount", unique_proof_count),
            ("repeatedProofTestHashCount", repeated_proof_count),
        ]
        if value is None
    ]
    append_ids_failure(failures, "invalidSummaryTelemetry", invalid_summary_fields)

    if production_failure_count is None or production_failure_count > 0 or any(
        isinstance(row, dict) and row.get("liveProductionFloor") is not True
        for row in rows
    ):
        failures.append("productionFloorFailures")
    append_ids_failure(failures, "longFormConversationFailures", [
        item for item in long_form_failures if isinstance(item, str) and item.strip()
    ])
    readiness_warnings = summary.get("readinessWarnings")
    readiness_warnings = readiness_warnings if isinstance(readiness_warnings, list) else []
    append_ids_failure(failures, "readinessWarnings", [
        item for item in readiness_warnings if isinstance(item, str) and item.strip()
    ])
    if immediate_missing_count is None or immediate_missing_count > 0:
        failures.append("missingImmediateCoachRead")
    if confidence_distinct_count is None or confidence_distinct_count < 3:
        failures.append("flatAssessmentConfidence")
    if (
        unique_proof_count is None
        or repeated_proof_count is None
        or unique_proof_count < 3
        or repeated_proof_count > 0
    ):
        failures.append("weakProofTestVariety")

    deduped = []
    for failure in failures:
        if failure not in deduped:
            deduped.append(failure)
    return deduped


def evidence_artifact_contract_status(path, requirement, source_expectations=None):
    if not path.is_file():
        return {
            "parseStatus": "missing",
            "schemaVersion": None,
            "expectedSchemaVersion": requirement.get("expectedSchemaVersion"),
            "schemaVersionMatches": False,
            "missingRequiredKeys": requirement.get("requiredTopLevelKeys", []),
            "passesLightweightContract": False,
            "contractFailures": ["missing"],
        }

    failures = []
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {
            "parseStatus": f"invalidJSON:{exc.msg}",
            "schemaVersion": None,
            "expectedSchemaVersion": requirement.get("expectedSchemaVersion"),
            "schemaVersionMatches": False,
            "missingRequiredKeys": requirement.get("requiredTopLevelKeys", []),
            "passesLightweightContract": False,
            "contractFailures": [f"invalidJSON:{exc.msg}"],
        }

    if not isinstance(payload, dict):
        return {
            "parseStatus": "invalidTopLevelType",
            "schemaVersion": None,
            "expectedSchemaVersion": requirement.get("expectedSchemaVersion"),
            "schemaVersionMatches": False,
            "missingRequiredKeys": requirement.get("requiredTopLevelKeys", []),
            "passesLightweightContract": False,
            "contractFailures": ["invalidTopLevelType"],
        }

    expected_schema = requirement.get("expectedSchemaVersion")
    schema_version = payload.get("schemaVersion")
    if not isinstance(schema_version, str) or not schema_version.strip():
        failures.append("schemaVersionMissing")
    elif expected_schema and schema_version != expected_schema:
        failures.append(f"schemaVersionMismatch:{schema_version}")

    required_keys = requirement.get("requiredTopLevelKeys", [])
    missing_keys = [key for key in required_keys if key not in payload]
    if missing_keys:
        failures.append("missingRequiredKeys:" + ",".join(missing_keys))

    if expected_schema == "coach-live-eval-v1":
        failures.extend(
            live_provider_sweep_contract_failures(payload, source_expectations)
        )
    if expected_schema == PROFESSIONAL_CALIBRATION_RESULTS_SCHEMA:
        failures.extend(
            professional_calibration_contract_failures(
                payload,
                (source_expectations or {}).get("professionalCalibrationPacket"),
            )
        )

    return {
        "parseStatus": "ok",
        "schemaVersion": schema_version if isinstance(schema_version, str) else None,
        "expectedSchemaVersion": expected_schema,
        "schemaVersionMatches": bool(expected_schema and schema_version == expected_schema),
        "missingRequiredKeys": missing_keys,
        "passesLightweightContract": not failures,
        "contractFailures": failures,
    }


def evidence_artifact_audit(dump_dir, readiness=None):
    root = Path(dump_dir)
    blockers = set(readiness.get("blockers") or []) if readiness else set(EVIDENCE_REQUIREMENTS)

    source_sidecars = []
    source_expectations = {}
    source_expectations["professionalCalibrationPacket"] = calibration_packet_context(root)
    for file_name in SOURCE_SIDECARS:
        path = root / file_name
        present = path.is_file()
        value_preview = None
        usable = False
        if present:
            raw_value = path.read_text(encoding="utf-8", errors="replace").strip()
            value_preview = raw_value[:80]
            usable = trimmed_non_empty(raw_value) is not None
            if usable:
                source_expectations[file_name] = raw_value
        source_sidecars.append({
            "fileName": file_name,
            "path": str(path),
            "present": present,
            "usable": usable,
            "valuePreview": value_preview,
        })

    required = []
    for blocker, requirement in EVIDENCE_REQUIREMENTS.items():
        artifact = requirement["artifact"]
        path = root / artifact
        present = path.is_file()
        contract = evidence_artifact_contract_status(
            path,
            requirement,
            source_expectations,
        )
        required.append({
            "blocker": blocker,
            "rowKey": requirement["rowKey"],
            "artifact": artifact,
            "path": str(path),
            "present": present,
            "activeBlocker": blocker in blockers,
            "presentButStillBlocked": present and blocker in blockers,
            **contract,
        })

    missing = [item for item in required if not item["present"]]
    present_but_blocked = [item for item in required if item["presentButStillBlocked"]]
    return {
        "dumpDir": str(root),
        "dumpDirExists": root.is_dir(),
        "validationBoundary": (
            "Python performs structured JSON/schema, source-freshness, coverage, "
            "and telemetry staging checks; Swift manifest loaders remain the "
            "authoritative launch evidence gate."
        ),
        "requiredArtifactCount": len(required),
        "presentArtifactCount": len(required) - len(missing),
        "validArtifactContractCount": sum(
            1 for item in required if item.get("passesLightweightContract")
        ),
        "missingArtifactCount": len(missing),
        "sourceSidecarCount": len(source_sidecars),
        "presentSourceSidecarCount": sum(1 for item in source_sidecars if item["present"]),
        "requiredArtifacts": required,
        "missingArtifacts": missing,
        "invalidArtifacts": [
            item for item in required
            if item["present"] and not item.get("passesLightweightContract")
        ],
        "presentButStillBlockedArtifacts": present_but_blocked,
        "sourceSidecars": source_sidecars,
    }


def artifact_gate_failures(artifact_audit):
    failures = []
    if not artifact_audit.get("dumpDirExists"):
        failures.append({
            "label": "evidenceDumpDirectory",
            "observed": False,
            "gate": "The evidence dump directory must exist for a launch-ready claim.",
            "nextStep": "Create or pass the release-candidate evidence directory with --dump-dir.",
        })
    for item in artifact_audit.get("missingArtifacts") or []:
        failures.append({
            "label": item["artifact"],
            "observed": "missing",
            "gate": "Required VISION evidence sidecar must be staged in the dump directory.",
            "nextStep": f"Place `{item['artifact']}` in `{artifact_audit.get('dumpDir')}` and rerun the Swift manifest.",
        })
    for item in artifact_audit.get("invalidArtifacts") or []:
        failures.append({
            "label": item["artifact"],
            "observed": ",".join(item.get("contractFailures") or ["invalid"]),
            "gate": (
                "Required VISION evidence sidecar must be valid JSON with the "
                "expected schemaVersion and top-level evidence sections."
            ),
            "nextStep": (
                f"Replace `{item['artifact']}` with a real "
                f"`{item.get('expectedSchemaVersion')}` artifact; placeholders "
                "do not count as launch evidence."
            ),
        })
    for item in artifact_audit.get("sourceSidecars") or []:
        if not item.get("present"):
            failures.append({
                "label": item["fileName"],
                "observed": "missing",
                "gate": "Source freshness sidecar must be staged with the evidence artifacts.",
                "nextStep": "Run `./tools/coach-arena/run.sh app-path-source` for the same dump directory.",
            })
        elif not item.get("usable"):
            failures.append({
                "label": item["fileName"],
                "observed": "empty",
                "gate": "Source freshness sidecar must contain a non-empty source identity.",
                "nextStep": "Run `./tools/coach-arena/run.sh app-path-source` for the same dump directory.",
            })
    return failures


def file_text(root, relative_path):
    path = Path(root) / relative_path
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8", errors="replace")


def gitignore_mentions(root, relative_path):
    text = file_text(root, ".gitignore") or ""
    normalized = relative_path.strip().replace("\\", "/").lstrip("/")
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        candidate = stripped.lstrip("/").rstrip("/")
        if candidate == normalized:
            return True
    return False


def git_path_tracked(root, relative_path):
    root = Path(root)
    if not (root / ".git").exists():
        return None
    try:
        result = subprocess.run(
            ["git", "ls-files", "--error-unmatch", relative_path],
            cwd=root,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    except (OSError, ValueError):
        return None
    return result.returncode == 0


def noum_target_membership_exceptions(repo_root=REPO_ROOT):
    project = file_text(repo_root, "Noum.xcodeproj/project.pbxproj")
    if project is None:
        return None
    exception_set = re.search(
        r'/\* Exceptions for "Noum" folder in "Noum" target \*/ = \{(.*?)\n\s*\};',
        project,
        flags=re.DOTALL,
    )
    if not exception_set:
        return None
    membership = re.search(
        r"membershipExceptions\s*=\s*\((.*?)\);",
        exception_set.group(1),
        flags=re.DOTALL,
    )
    if not membership:
        return None
    return {
        entry.partition("/*")[0].strip().strip('"')
        for entry in membership.group(1).split(",")
        if entry.partition("/*")[0].strip()
    }


def privacy_url_from_repo(repo_root=REPO_ROOT):
    web_urls = file_text(repo_root, "Noum/NoumWebURLs.swift") or ""
    match = re.search(r"static\s+let\s+privacy\s*=\s*URL\(string:\s*\"([^\"]+)\"\)", web_urls)
    if match:
        return match.group(1)
    if "https://noum-d0b6f.web.app/privacy" in web_urls:
        return "https://noum-d0b6f.web.app/privacy"
    return None


def default_fetch_url(url, timeout=10):
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "NoumReadinessGate/1.0"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read(8192).decode("utf-8", errors="replace")
        return {
            "status": getattr(response, "status", response.getcode()),
            "finalURL": response.geturl(),
            "bodyPreview": body,
        }


def operational_live_probe(repo_root=REPO_ROOT, fetch_url=default_fetch_url):
    privacy_url = privacy_url_from_repo(repo_root)
    checks = []

    def add(key, label, passed, observed, gate, next_step):
        checks.append({
            "key": key,
            "label": label,
            "passed": bool(passed),
            "observed": observed,
            "gate": gate,
            "nextStep": next_step,
        })

    if not privacy_url:
        add(
            "privacyURLConfigured",
            "privacyURLConfigured",
            False,
            "missing",
            "NoumWebURLs.privacy must point at a public privacy URL.",
            "Restore NoumWebURLs.privacy before probing the hosted policy.",
        )
    else:
        add(
            "privacyURLConfigured",
            "privacyURLConfigured",
            True,
            privacy_url,
            "NoumWebURLs.privacy must point at a public privacy URL.",
            "Restore NoumWebURLs.privacy before probing the hosted policy.",
        )
        try:
            response = fetch_url(privacy_url)
            status = response.get("status")
            body = response.get("bodyPreview") or ""
            add(
                "privacyURLHTTP",
                "privacyURLHTTP",
                isinstance(status, int) and 200 <= status < 400,
                status,
                "The hosted privacy URL must return a successful HTTP status.",
                "Deploy Firebase Hosting or repair the privacy URL.",
            )
            add(
                "privacyURLContent",
                "privacyURLContent",
                "Privacy Policy" in body and "Noum" in body,
                "contentMatched" if "Privacy Policy" in body and "Noum" in body else "contentMissing",
                "The hosted privacy URL must serve the Noum privacy policy content.",
                "Deploy public/privacy.html and the /privacy rewrite.",
            )
        except urllib.error.HTTPError as exc:
            add(
                "privacyURLHTTP",
                "privacyURLHTTP",
                False,
                exc.code,
                "The hosted privacy URL must return a successful HTTP status.",
                "Deploy Firebase Hosting or repair the privacy URL.",
            )
            add(
                "privacyURLContent",
                "privacyURLContent",
                False,
                "notFetched",
                "The hosted privacy URL must serve the Noum privacy policy content.",
                "Deploy public/privacy.html and the /privacy rewrite.",
            )
            try:
                exc.close()
            except Exception:
                pass
        except Exception as exc:
            add(
                "privacyURLHTTP",
                "privacyURLHTTP",
                False,
                type(exc).__name__,
                "The hosted privacy URL must be reachable from the public internet.",
                "Check network access, Firebase Hosting, and the configured privacy URL.",
            )
            add(
                "privacyURLContent",
                "privacyURLContent",
                False,
                "notFetched",
                "The hosted privacy URL must serve the Noum privacy policy content.",
                "Deploy public/privacy.html and the /privacy rewrite.",
            )

    failures = [check for check in checks if not check["passed"]]
    return {
        "validationBoundary": (
            "Live ops probe checks public URL reachability only; it does not prove "
            "Firestore rules deployment, App Store privacy disclosure review, "
            "TestFlight upload, or release-blocking bug triage."
        ),
        "checkCount": len(checks),
        "passCount": len(checks) - len(failures),
        "failureCount": len(failures),
        "checks": checks,
        "failures": failures,
    }


def operational_live_gate_failures(probe):
    failures = []
    if not probe:
        return failures
    for item in probe.get("failures") or []:
        failures.append({
            "label": item["label"],
            "observed": item.get("observed"),
            "gate": item["gate"],
            "nextStep": item["nextStep"],
        })
    return failures


def operational_static_preflight(repo_root=REPO_ROOT):
    root = Path(repo_root)
    checks = []

    def add(key, label, passed, observed, gate, next_step):
        checks.append({
            "key": key,
            "label": label,
            "passed": bool(passed),
            "observed": observed,
            "gate": gate,
            "nextStep": next_step,
        })

    membership_exceptions = noum_target_membership_exceptions(root)
    local_secret_plists = {
        "AIConfig.plist",
        "BackendConfig.plist",
        "Transcribe.plist",
        "TranscriptionProviders.plist",
    }
    protected_client_config = (
        membership_exceptions is not None
        and local_secret_plists.issubset(membership_exceptions)
        and "GoogleService-Info.plist" not in membership_exceptions
    )
    add(
        "mainTargetClientSecretBoundary",
        "mainTargetClientSecretBoundary",
        protected_client_config,
        (
            "localSecretPlistsExcluded;firebaseClientConfigRetained"
            if protected_client_config
            else "targetMembershipUnsafeOrUnparseable"
        ),
        (
            "The main app target must exclude local provider and backend secret "
            "plists while retaining Firebase's public client configuration."
        ),
        (
            "Restore AIConfig.plist, BackendConfig.plist, Transcribe.plist, and "
            "TranscriptionProviders.plist in the Noum target membership exceptions "
            "without excluding GoogleService-Info.plist."
        ),
    )

    ai_config_ignored = gitignore_mentions(root, "Noum/AIConfig.plist")
    ai_config_tracked = git_path_tracked(root, "Noum/AIConfig.plist")
    ai_config_example_present = (root / "Noum/AIConfig.plist.example").is_file()
    repo_secret_boundary = (
        ai_config_ignored
        and ai_config_tracked is not True
        and ai_config_example_present
    )
    tracked_state = (
        "tracked" if ai_config_tracked is True
        else "untracked" if ai_config_tracked is False
        else "trackingUnknown"
    )
    add(
        "aiConfigRepositorySecretBoundary",
        "aiConfigRepositorySecretBoundary",
        repo_secret_boundary,
        (
            f"ignored={ai_config_ignored};{tracked_state};"
            f"examplePresent={ai_config_example_present}"
        ),
        (
            "AIConfig.plist must remain a local-only config with a checked-in "
            "placeholder example, never a tracked source of AI provider keys."
        ),
        (
            "Keep Noum/AIConfig.plist in .gitignore, keep "
            "Noum/AIConfig.plist.example checked in, and remove any tracked "
            "AIConfig.plist from the repository index."
        ),
    )

    privacy_manifest_path = root / "Noum/PrivacyInfo.xcprivacy"
    privacy_manifest = None
    privacy_manifest_error = None
    if privacy_manifest_path.is_file():
        try:
            with privacy_manifest_path.open("rb") as manifest_file:
                privacy_manifest = plistlib.load(manifest_file)
        except (OSError, plistlib.InvalidFileException) as exc:
            privacy_manifest_error = type(exc).__name__
    if privacy_manifest is not None and not isinstance(privacy_manifest, dict):
        privacy_manifest_error = "invalidTopLevelType"
        privacy_manifest = None
    collected_data = {
        item.get("NSPrivacyCollectedDataType"): item
        for item in (privacy_manifest or {}).get("NSPrivacyCollectedDataTypes", [])
        if isinstance(item, dict) and item.get("NSPrivacyCollectedDataType")
    }
    required_user_content_types = {
        "NSPrivacyCollectedDataTypeOtherUserContent",
        "NSPrivacyCollectedDataTypePhotosorVideos",
    }
    invalid_user_content_types = []
    for data_type in sorted(required_user_content_types):
        item = collected_data.get(data_type) or {}
        purposes = item.get("NSPrivacyCollectedDataTypePurposes") or []
        if (
            item.get("NSPrivacyCollectedDataTypeLinked") is not True
            or item.get("NSPrivacyCollectedDataTypeTracking") is not False
            or "NSPrivacyCollectedDataTypePurposeAppFunctionality" not in purposes
        ):
            invalid_user_content_types.append(data_type)
    privacy_user_content_disclosed = (
        privacy_manifest is not None and not invalid_user_content_types
    )
    add(
        "privacyManifestUserContentDisclosure",
        "privacyManifestUserContentDisclosure",
        privacy_user_content_disclosed,
        (
            "linkedNonTrackingAppFunctionality"
            if privacy_user_content_disclosed
            else privacy_manifest_error
            or "missingOrInvalid:" + ",".join(invalid_user_content_types)
        ),
        (
            "The app privacy manifest must disclose user-authored coaching content "
            "and optional video frames as linked, non-tracking app-functionality data."
        ),
        (
            "Declare Other User Content and Photos or Videos in "
            "Noum/PrivacyInfo.xcprivacy with the shipping linkage and purpose."
        ),
    )

    firebase_json_path = root / "firebase.json"
    firebase_config = None
    firebase_error = None
    if firebase_json_path.is_file():
        try:
            firebase_config = json.loads(firebase_json_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            firebase_error = f"invalidJSON:{exc.msg}"
    add(
        "firebaseJson",
        "firebase.json",
        firebase_config is not None,
        "present" if firebase_config is not None else (firebase_error or "missing"),
        "Firebase config must be present and parseable before deploy.",
        "Restore a valid firebase.json with Firestore and Hosting config.",
    )

    firestore_rules_pointer = (
        (firebase_config or {}).get("firestore") or {}
    ).get("rules")
    add(
        "firestoreRulesPointer",
        "firestoreRulesPointer",
        firestore_rules_pointer == "firestore.rules",
        firestore_rules_pointer,
        "firebase.json must point Firestore deploys at firestore.rules.",
        "Set firebase.json firestore.rules to `firestore.rules`.",
    )

    hosting_config = (firebase_config or {}).get("hosting") or {}
    hosting_public = hosting_config.get("public")
    add(
        "hostingPublicDirectory",
        "hostingPublicDirectory",
        hosting_public == "public",
        hosting_public,
        "Firebase Hosting must serve the checked-in public directory.",
        "Set firebase.json hosting.public to `public`.",
    )

    privacy_rewrite_present = any(
        item.get("source") == "/privacy" and item.get("destination") == "/privacy.html"
        for item in hosting_config.get("rewrites", [])
        if isinstance(item, dict)
    )
    add(
        "hostingPrivacyRewrite",
        "hostingPrivacyRewrite",
        privacy_rewrite_present,
        privacy_rewrite_present,
        "Firebase Hosting must rewrite /privacy to /privacy.html.",
        "Add the /privacy -> /privacy.html rewrite to firebase.json.",
    )

    firestore_rules = file_text(root, "firestore.rules")
    add(
        "firestoreRulesFile",
        "firestoreRulesFile",
        firestore_rules is not None,
        "present" if firestore_rules is not None else "missing",
        "The deploy target must have committed Firestore rules.",
        "Restore firestore.rules.",
    )
    if firestore_rules is not None:
        public_profile_guard_present = (
            "match /profiles_public/{accountID}" in firestore_rules and
            (
                "request.resource.data.keys().hasOnly" in firestore_rules or
                (
                    "function updatesOnlyDisplayName(accountID)" in firestore_rules and
                    "affectedKeys().hasOnly(['displayName'])" in firestore_rules and
                    "allow update: if updatesOnlyDisplayName(accountID);" in firestore_rules
                )
            )
        )
        add(
            "firestoreRulesPrivateUsers",
            "firestoreRulesPrivateUsers",
            "match /users/{accountID}/{document=**}" in firestore_rules and
            "request.auth.uid == accountID" in firestore_rules,
            "privateUserRulePresent",
            "Private user documents must be scoped to the signed-in account.",
            "Repair firestore.rules private user ownership guard.",
        )
        add(
            "firestoreRulesPublicProfileWriteGuard",
            "firestoreRulesPublicProfileWriteGuard",
            public_profile_guard_present,
            "publicProfileGuardPresent",
            "Public profile writes must be field-limited and account-owned.",
            "Repair profiles_public write guards in firestore.rules.",
        )
        add(
            "firestoreRulesLeagueAndChallengeScopes",
            "firestoreRulesLeagueAndChallengeScopes",
            "match /leagues/{bucket}/members/{accountID}" in firestore_rules and
            "match /challenges/{challengeID}" in firestore_rules,
            "leagueChallengeRulesPresent",
            "Peer/league launch surfaces need explicit Firestore rules.",
            "Restore league and challenge rule blocks in firestore.rules.",
        )

    privacy_html = file_text(root, "public/privacy.html")
    add(
        "hostedPrivacyHtml",
        "hostedPrivacyHtml",
        privacy_html is not None and "Noum" in privacy_html and "Privacy Policy" in privacy_html,
        "present" if privacy_html is not None else "missing",
        "The hosted privacy page must be staged locally before deploy.",
        "Restore public/privacy.html with Noum privacy policy content.",
    )
    add(
        "landingHtml",
        "landingHtml",
        (root / "public/index.html").is_file(),
        "present" if (root / "public/index.html").is_file() else "missing",
        "Firebase Hosting should have a landing page beside privacy.html.",
        "Restore public/index.html.",
    )
    add(
        "bundledPrivacyPolicy",
        "bundledPrivacyPolicy",
        (root / "Noum/PrivacyPolicy.md").is_file(),
        "present" if (root / "Noum/PrivacyPolicy.md").is_file() else "missing",
        "The in-app privacy policy view must have bundled Markdown content.",
        "Restore Noum/PrivacyPolicy.md.",
    )

    web_urls = file_text(root, "Noum/NoumWebURLs.swift") or ""
    add(
        "appPrivacyURLConstant",
        "appPrivacyURLConstant",
        "https://noum-d0b6f.web.app/privacy" in web_urls,
        "https://noum-d0b6f.web.app/privacy" if "https://noum-d0b6f.web.app/privacy" in web_urls else "missing",
        "The app must point reviewers and users at the staged privacy URL.",
        "Update NoumWebURLs.privacy to the deployed privacy URL.",
    )

    privacy_view = file_text(root, "Noum/PrivacyPolicyView.swift") or ""
    add(
        "inAppPrivacyWebLink",
        "inAppPrivacyWebLink",
        "NoumWebURLs.privacy" in privacy_view and "Open privacy policy on web" in privacy_view,
        "webLinkPresent" if "NoumWebURLs.privacy" in privacy_view else "missing",
        "The in-app privacy policy must expose the hosted policy URL.",
        "Repair PrivacyPolicyView's hosted privacy Link.",
    )

    settings_view = file_text(root, "Noum/SettingsView.swift") or ""
    add(
        "settingsPrivacyEntry",
        "settingsPrivacyEntry",
        "Privacy policy" in settings_view and "showPrivacyPolicy = true" in settings_view,
        "settingsEntryPresent" if "showPrivacyPolicy = true" in settings_view else "missing",
        "Settings must expose the privacy policy before launch.",
        "Restore the Settings privacy row and sheet action.",
    )

    qa_doc = file_text(root, "docs/TESTFLIGHT_QA.md") or ""
    add(
        "testFlightQAChecklist",
        "testFlightQAChecklist",
        all(
            phrase in qa_doc for phrase in [
                "firebase deploy --only firestore:rules",
                "firebase deploy --only hosting",
                "https://noum-d0b6f.web.app/privacy",
                "Live Activity",
                "AI prompt latency",
                "Paywall",
            ]
        ),
        "qaChecklistPresent" if qa_doc else "missing",
        "The release manager needs a hardware/TestFlight QA checklist.",
        "Restore docs/TESTFLIGHT_QA.md with deploy, privacy, and high-risk surface checks.",
    )

    failures = [check for check in checks if not check["passed"]]
    return {
        "repoRoot": str(root),
        "validationBoundary": (
            "Static ops preflight checks local repository wiring only; it does not "
            "prove Firestore rules were deployed, the privacy URL is live, App Store "
            "privacy disclosures were reviewed, TestFlight was uploaded, or release "
            "bugs were triaged."
        ),
        "checkCount": len(checks),
        "passCount": len(checks) - len(failures),
        "failureCount": len(failures),
        "checks": checks,
        "failures": failures,
    }


def operational_static_gate_failures(preflight):
    failures = []
    for item in preflight.get("failures") or []:
        failures.append({
            "label": item["label"],
            "observed": item.get("observed"),
            "gate": item["gate"],
            "nextStep": item["nextStep"],
        })
    return failures


def build_readiness_status(
    report,
    report_path,
    dump_dir=DEFAULT_DUMP_DIR,
    repo_root=REPO_ROOT,
    probe_live=False,
    fetch_url=default_fetch_url,
):
    readiness = readiness_from_report(report)
    summary = report.get("summary") if isinstance(report.get("summary"), dict) else {}
    local_gates = local_gates_from_report(report)
    report_audit = report_source_audit(report, report_path)
    report_source_failures = report_source_gate_failures(report_audit)
    computed_ready = computed_production_ready(readiness)
    local_failures = report_source_failures + local_readiness_failures(local_gates, readiness)
    artifact_audit = evidence_artifact_audit(dump_dir, readiness)
    source_audit = source_freshness_audit(report, artifact_audit, repo_root)
    source_failures = source_freshness_gate_failures(source_audit)
    local_failures = local_failures + source_failures
    artifact_failures = artifact_gate_failures(artifact_audit)
    ops_preflight = operational_static_preflight(repo_root)
    ops_failures = operational_static_gate_failures(ops_preflight)
    ops_live_probe = operational_live_probe(repo_root, fetch_url) if probe_live else None
    ops_live_failures = operational_live_gate_failures(ops_live_probe)
    launch_ready = computed_launch_ready(
        readiness,
        local_gates,
        artifact_audit,
        ops_preflight,
        ops_live_probe,
        source_audit,
        report_audit,
    )
    reported_ready = summary.get("visionProductionReady")
    blockers = readiness.get("blockers") if readiness else None
    if blockers is None:
        blockers = list(EVIDENCE_REQUIREMENTS.keys())
    warnings = []
    if reported_ready is not None and bool(reported_ready) != computed_ready:
        warnings.append("reportedVisionProductionReadyMismatch")
    if readiness is None:
        warnings.append("missingVisionProductionReadiness")
    return {
        "reportPath": str(report_path),
        "reportFamily": report.get("reportFamily") or "missing",
        "reportSourceAudit": report_audit,
        "generatedAt": report.get("generatedAt"),
        "launchReady": launch_ready,
        "localGates": local_gates,
        "localBlockingRequirements": local_failures,
        "artifactBlockingRequirements": artifact_failures,
        "operationalStaticBlockingRequirements": ops_failures,
        "operationalLiveBlockingRequirements": ops_live_failures,
        "vision": {
            "productionReady": computed_ready,
            "score": readiness.get("score") if readiness else None,
            "minimumReadyScore": READY_SCORE,
            "localTargetShapeScore": readiness.get("localTargetShapeScore") if readiness else None,
            "minimumLocalTargetShapeScore": READY_LOCAL_TARGET_SHAPE_SCORE,
            "maximumAllowedScore": readiness.get("maximumAllowedScore") if readiness else None,
            "claim": readiness.get("claim") if readiness else None,
            "requiredClaim": READY_CLAIM,
            "blockers": blockers,
            "summary": readiness.get("summary") if readiness else None,
        },
        "blockingRequirements": blocking_requirements(readiness),
        "artifactAudit": artifact_audit,
        "sourceFreshnessAudit": source_audit,
        "operationalStaticPreflight": ops_preflight,
        "operationalLiveProbe": ops_live_probe,
        "uiFlowBoundary": UI_FLOW_BOUNDARY,
        "warnings": warnings,
    }


def render_markdown(status):
    vision = status["vision"]
    local = status["localGates"]
    report_source = status.get("reportSourceAudit") or {}
    lines = [
        "# Coach Production Readiness Gate",
        "",
        f"- Report: `{status['reportPath']}`",
        f"- Generated: `{status.get('generatedAt')}`",
        f"- Report family: `{status.get('reportFamily')}`",
        f"- Canonical app-path report: `{report_source.get('passes')}`",
        f"- Launch gate ready: `{status.get('launchReady')}`",
        f"- Local score/coverage gates pass: `{local.get('scoreThresholdsPass')}`",
        f"- Real-pipeline evidence passes: `{local.get('realPipelineEvidencePasses')}`",
        f"- Trace quality passes: `{local.get('traceQualityPasses')}`",
        f"- VISION production ready: `{vision.get('productionReady')}`",
        f"- VISION score: `{vision.get('score')}/100`",
        f"- Local target-shape score: `{vision.get('localTargetShapeScore')}/100`",
        f"- Maximum allowed score: `{vision.get('maximumAllowedScore')}/100`",
        f"- Claim: `{vision.get('claim')}`",
        "",
    ]
    if vision.get("summary"):
        lines.extend([vision["summary"], ""])

    requirements = status["blockingRequirements"]
    if requirements:
        lines.extend(["## Blocking Evidence", ""])
        for requirement in requirements:
            lines.append(
                f"- `{requirement['blocker']}` -> `{requirement['artifact']}` "
                f"({requirement.get('owner', 'owner not mapped')})"
            )
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")
    else:
        lines.extend(["## Blocking Evidence", "", "- `none`", ""])

    local_requirements = status["localBlockingRequirements"]
    if local_requirements:
        lines.extend(["## Local Gate Failures", ""])
        for requirement in local_requirements:
            lines.append(
                f"- `{requirement['label']}` observed `{requirement.get('observed')}`"
            )
            if requirement.get("sidecar") is not None:
                lines.append(f"  Sidecar: `{requirement['sidecar']}`")
            if requirement.get("reportValues"):
                rendered_values = ", ".join(f"`{value}`" for value in requirement["reportValues"])
                lines.append(f"  Report values: {rendered_values}")
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")

    lines.extend([
        "## Report Source",
        "",
        f"- Required family: `{report_source.get('requiredReportFamily')}`",
        f"- Observed family: `{report_source.get('reportFamily')}`",
        f"- Canonical path: `{report_source.get('canonicalPath')}`",
        f"- Canonical dir: `{report_source.get('canonicalReportDir')}`",
        f"- Normalized report path: `{report_source.get('normalizedReportPath')}`",
    ])
    if report_source.get("validationBoundary"):
        lines.append(f"- Boundary: {report_source['validationBoundary']}")
    lines.append("")

    artifact_requirements = status["artifactBlockingRequirements"]
    if artifact_requirements:
        lines.extend(["## Artifact Gate Failures", ""])
        for requirement in artifact_requirements:
            lines.append(
                f"- `{requirement['label']}` observed `{requirement.get('observed')}`"
            )
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")

    ops_requirements = status["operationalStaticBlockingRequirements"]
    if ops_requirements:
        lines.extend(["## Operational Static Gate Failures", ""])
        for requirement in ops_requirements:
            lines.append(
                f"- `{requirement['label']}` observed `{requirement.get('observed')}`"
            )
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")

    ops_live_requirements = status.get("operationalLiveBlockingRequirements") or []
    if ops_live_requirements:
        lines.extend(["## Operational Live Gate Failures", ""])
        for requirement in ops_live_requirements:
            lines.append(
                f"- `{requirement['label']}` observed `{requirement.get('observed')}`"
            )
            lines.append(f"  Gate: {requirement['gate']}")
            lines.append(f"  Next: {requirement['nextStep']}")
        lines.append("")

    artifact_audit = status.get("artifactAudit") or {}
    lines.extend([
        "## Evidence Directory",
        "",
        f"- Dump dir: `{artifact_audit.get('dumpDir')}`",
        f"- Dump dir exists: `{artifact_audit.get('dumpDirExists')}`",
        f"- Required sidecars present: `{artifact_audit.get('presentArtifactCount')}/{artifact_audit.get('requiredArtifactCount')}`",
        f"- Required sidecars passing staging contract: `{artifact_audit.get('validArtifactContractCount')}/{artifact_audit.get('requiredArtifactCount')}`",
        f"- Source sidecars present: `{artifact_audit.get('presentSourceSidecarCount')}/{artifact_audit.get('sourceSidecarCount')}`",
    ])
    if artifact_audit.get("validationBoundary"):
        lines.append(f"- Boundary: {artifact_audit['validationBoundary']}")
    missing_artifacts = artifact_audit.get("missingArtifacts") or []
    if missing_artifacts:
        lines.append("- Missing sidecars:")
        for item in missing_artifacts:
            lines.append(f"  - `{item['artifact']}`")
    invalid_artifacts = artifact_audit.get("invalidArtifacts") or []
    if invalid_artifacts:
        lines.append("- Invalid sidecars:")
        for item in invalid_artifacts:
            failures = ", ".join(item.get("contractFailures") or ["invalid"])
            expected = item.get("expectedSchemaVersion") or "unknown schema"
            lines.append(f"  - `{item['artifact']}` -> `{failures}` (expected `{expected}`)")
    present_but_blocked = artifact_audit.get("presentButStillBlockedArtifacts") or []
    if present_but_blocked:
        lines.append("- Staged but still blocked in latest report:")
        for item in present_but_blocked:
            lines.append(
                f"  - `{item['artifact']}` -> rerun the Swift manifest/app-path report to validate it"
            )
    source_sidecars = artifact_audit.get("sourceSidecars") or []
    if source_sidecars:
        lines.append("- Source sidecars:")
        for item in source_sidecars:
            state = "present" if item.get("present") else "missing"
            lines.append(f"  - `{item['fileName']}`: `{state}`")
    lines.append("")

    source_audit = status.get("sourceFreshnessAudit") or {}
    lines.extend([
        "## Source Freshness",
        "",
        f"- Passes: `{source_audit.get('passes')}`",
        f"- Current coach fingerprint: `{source_audit.get('currentCoachFingerprint')}`",
        f"- Current git commit: `{source_audit.get('currentGitCommit')}`",
        f"- Sidecar coach fingerprint: `{source_audit.get('sidecarCoachFingerprint')}`",
        f"- Sidecar git commit: `{source_audit.get('sidecarGitCommit')}`",
    ])
    report_fingerprints = source_audit.get("reportCoachFingerprints") or []
    report_commits = source_audit.get("reportGitCommits") or []
    if report_fingerprints:
        lines.append("- Report coach fingerprints:")
        for value in report_fingerprints:
            lines.append(f"  - `{value}`")
    else:
        lines.append("- Report coach fingerprints: `none found`")
    if report_commits:
        lines.append("- Report git commits:")
        for value in report_commits:
            lines.append(f"  - `{value}`")
    else:
        lines.append("- Report git commits: `none found`")
    if source_audit.get("validationBoundary"):
        lines.append(f"- Boundary: {source_audit['validationBoundary']}")
    freshness_mismatches = (
        (source_audit.get("mismatches") or []) +
        (source_audit.get("currentMismatches") or [])
    )
    if freshness_mismatches:
        lines.append("- Source mismatches:")
        for item in freshness_mismatches:
            observed = item.get("current") or item.get("sidecar")
            against = item.get("mismatchedAgainst") or ["report"]
            lines.append(
                f"  - `{item.get('label')}` observed `{observed}` vs "
                f"`{', '.join(against)}`"
            )
    lines.append("")

    ops_preflight = status.get("operationalStaticPreflight") or {}
    lines.extend([
        "## Operational Static Preflight",
        "",
        f"- Repo root: `{ops_preflight.get('repoRoot')}`",
        f"- Checks passing: `{ops_preflight.get('passCount')}/{ops_preflight.get('checkCount')}`",
    ])
    if ops_preflight.get("validationBoundary"):
        lines.append(f"- Boundary: {ops_preflight['validationBoundary']}")
    failures = ops_preflight.get("failures") or []
    if failures:
        lines.append("- Failed checks:")
        for item in failures:
            lines.append(f"  - `{item['label']}`")
    else:
        lines.append("- Failed checks: `none`")
    lines.append("")

    ops_live_probe = status.get("operationalLiveProbe")
    if ops_live_probe is not None:
        lines.extend([
            "## Operational Live Probe",
            "",
            f"- Checks passing: `{ops_live_probe.get('passCount')}/{ops_live_probe.get('checkCount')}`",
        ])
        configured_url = next(
            (
                item.get("observed") for item in ops_live_probe.get("checks", [])
                if item.get("key") == "privacyURLConfigured"
            ),
            None,
        )
        if configured_url:
            lines.append(f"- Privacy URL: `{configured_url}`")
        if ops_live_probe.get("validationBoundary"):
            lines.append(f"- Boundary: {ops_live_probe['validationBoundary']}")
        failures = ops_live_probe.get("failures") or []
        if failures:
            lines.append("- Failed checks:")
            for item in failures:
                lines.append(f"  - `{item['label']}` observed `{item.get('observed')}`")
        else:
            lines.append("- Failed checks: `none`")
        lines.append("")

    ui = status["uiFlowBoundary"]
    lines.extend([
        "## UI Flow Boundary",
        "",
        "- Maestro smoke flows:",
    ])
    for flow in ui["maestroSmokeFlows"]:
        lines.append(f"  - `{flow}`")
    lines.append("- Covered by smoke:")
    for item in ui["covered"]:
        lines.append(f"  - {item}")
    lines.append(
        f"- Not launch proof until `{ui['realDeviceArtifact']}` covers:"
    )
    for item in ui["notLaunchProof"]:
        lines.append(f"  - {item}")

    if status["warnings"]:
        lines.extend(["", "## Warnings", ""])
        for warning in status["warnings"]:
            lines.append(f"- `{warning}`")
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Report Noum VISION production readiness.")
    parser.add_argument("--report", default=str(DEFAULT_REPORT))
    parser.add_argument("--dump-dir", default=str(DEFAULT_DUMP_DIR))
    parser.add_argument("--repo-root", default=str(REPO_ROOT))
    parser.add_argument(
        "--probe-live",
        action="store_true",
        help="Probe public operational URLs and include failures in launchReady.",
    )
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--no-fail", action="store_true")
    args = parser.parse_args(argv)

    report_path = Path(args.report)
    report = load_report(report_path)
    status = build_readiness_status(
        report,
        report_path,
        Path(args.dump_dir),
        Path(args.repo_root),
        probe_live=args.probe_live,
    )
    if args.json:
        print(json.dumps(status, indent=2, sort_keys=True))
    else:
        print(render_markdown(status))
    if not args.no_fail and not status["launchReady"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
