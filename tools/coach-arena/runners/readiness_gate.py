#!/usr/bin/env python3
import argparse
import json
import os
import re
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


def source_freshness_audit(report, artifact_audit):
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

    return {
        "validationBoundary": (
            "Source freshness compares staged source sidecars against embedded "
            "report trace metadata when both are available; missing sidecars "
            "are handled by the artifact gate."
        ),
        "sidecarCoachFingerprint": sidecar_fingerprint,
        "sidecarGitCommit": sidecar_commit,
        "reportCoachFingerprints": report_fingerprints,
        "reportGitCommits": report_commits,
        "mismatches": mismatches,
        "passes": not mismatches,
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


def evidence_artifact_contract_status(path, requirement):
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
    required = []
    for blocker, requirement in EVIDENCE_REQUIREMENTS.items():
        artifact = requirement["artifact"]
        path = root / artifact
        present = path.is_file()
        contract = evidence_artifact_contract_status(path, requirement)
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

    source_sidecars = []
    for file_name in SOURCE_SIDECARS:
        path = root / file_name
        present = path.is_file()
        value_preview = None
        if present:
            value_preview = path.read_text(encoding="utf-8", errors="replace").strip()[:80]
        source_sidecars.append({
            "fileName": file_name,
            "path": str(path),
            "present": present,
            "valuePreview": value_preview,
        })

    missing = [item for item in required if not item["present"]]
    present_but_blocked = [item for item in required if item["presentButStillBlocked"]]
    return {
        "dumpDir": str(root),
        "dumpDirExists": root.is_dir(),
        "validationBoundary": (
            "Python performs a lightweight JSON/schema-version staging check; "
            "Swift manifest loaders still validate source freshness, counts, "
            "warnings, and evidence floors."
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
    return failures


def file_text(root, relative_path):
    path = Path(root) / relative_path
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8", errors="replace")


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
            "match /profiles_public/{accountID}" in firestore_rules and
            "request.resource.data.keys().hasOnly" in firestore_rules,
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
    source_audit = source_freshness_audit(report, artifact_audit)
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
        f"- Required sidecars passing lightweight contract: `{artifact_audit.get('validArtifactContractCount')}/{artifact_audit.get('requiredArtifactCount')}`",
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
