#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import plistlib
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "release_testflight_preflight.py"
SPEC = importlib.util.spec_from_file_location("release_testflight_preflight", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
release = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = release
SPEC.loader.exec_module(release)


def write_plist(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(value))


def valid_settings() -> dict[str, dict[str, str]]:
    settings = {}
    for target, expected in release.EXPECTED_TARGETS.items():
        settings[target] = {
            "PRODUCT_BUNDLE_IDENTIFIER": expected["bundle"],
            "CODE_SIGN_ENTITLEMENTS": expected["entitlements"],
            "CODE_SIGN_STYLE": "Automatic",
            "CODE_SIGNING_ALLOWED": "YES",
            "CODE_SIGNING_REQUIRED": "YES",
            "PROVISIONING_PROFILE_SPECIFIER": "",
            "PROVISIONING_PROFILE": "",
            "SKIP_INSTALL": expected["skip_install"],
            "WRAPPER_EXTENSION": expected["wrapper"],
            "MARKETING_VERSION": "1.1",
            "CURRENT_PROJECT_VERSION": "2",
            "DEVELOPMENT_TEAM": "TESTTEAM1",
        }
    settings["Noum"]["APP_ATTEST_ENVIRONMENT"] = "production"
    return settings


def app_store_profile(target: str, expires: datetime | None = None) -> dict:
    entitlements = {
        "application-identifier": f"TESTTEAM1.{release.EXPECTED_TARGETS[target]['bundle']}",
        "com.apple.security.application-groups": [release.EXPECTED_APP_GROUP],
        "get-task-allow": False,
    }
    if target == "Noum":
        entitlements["com.apple.developer.applesignin"] = ["Default"]
        entitlements["com.apple.developer.devicecheck.appattest-environment"] = "production"
    return {
        "TeamIdentifier": ["TESTTEAM1"],
        "ExpirationDate": expires or datetime.now(timezone.utc) + timedelta(days=30),
        "Entitlements": entitlements,
    }


class PreflightTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self._write_repository_fixture()
        self.archive = self._write_archive_fixture()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _write_repository_fixture(self) -> None:
        write_plist(
            self.root / "Noum.entitlements",
            {
                "com.apple.security.application-groups": [release.EXPECTED_APP_GROUP],
                "com.apple.developer.applesignin": ["Default"],
                "com.apple.developer.devicecheck.appattest-environment": "$(APP_ATTEST_ENVIRONMENT)",
            },
        )
        for target in ("NoumWidget", "NoumMessages", "NoumWatch"):
            write_plist(
                self.root / f"{target}/{target}.entitlements",
                {"com.apple.security.application-groups": [release.EXPECTED_APP_GROUP]},
            )
        for name in ("Info.plist", "AIConfig.plist", "BackendConfig.plist"):
            write_plist(self.root / f"Noum/{name}", {"fixture": True})
        write_plist(
            self.root / "Noum/GoogleService-Info.plist",
            {"BUNDLE_ID": release.EXPECTED_TARGETS["Noum"]["bundle"]},
        )
        write_plist(
            self.root / "scripts/TestFlightExportOptions.plist",
            {
                "method": "app-store-connect",
                "destination": "export",
                "signingStyle": "automatic",
                "manageAppVersionAndBuildNumber": False,
                "uploadSymbols": True,
                "stripSwiftSymbols": True,
            },
        )
        project = """
/* Begin PBXCopyFilesBuildPhase section */
    NoumWidget.appex in Embed App Extensions
    NoumMessages.appex in Embed App Extensions
    name = "Embed App Extensions";
/* End PBXCopyFilesBuildPhase section */
"""
        path = self.root / "Noum.xcodeproj/project.pbxproj"
        path.parent.mkdir(parents=True)
        path.write_text(project, encoding="utf-8")

    def _write_archive_fixture(self) -> Path:
        archive = self.root / "Noum.xcarchive"
        for target, relative in release.ARCHIVED_PRODUCTS.items():
            write_plist(
                archive / relative / "Info.plist",
                {
                    "CFBundleIdentifier": release.EXPECTED_TARGETS[target]["bundle"],
                    "CFBundleShortVersionString": "1.1",
                    "CFBundleVersion": "2",
                },
            )
        for name in ("Noum.app.dSYM", "NoumWidget.appex.dSYM", "NoumMessages.appex.dSYM"):
            (archive / "dSYMs" / name).mkdir(parents=True)
        return archive

    def test_parse_build_settings_keeps_target_sections(self) -> None:
        output = """Build settings for action build and target Noum:\n    PRODUCT_BUNDLE_IDENTIFIER = com.jordancoaten.noum\nBuild settings for action build and target NoumWidget:\n    PRODUCT_BUNDLE_IDENTIFIER = com.jordancoaten.noum.NoumWidget\n"""
        parsed = release.parse_build_settings(output)
        self.assertEqual(parsed["Noum"]["PRODUCT_BUNDLE_IDENTIFIER"], "com.jordancoaten.noum")
        self.assertEqual(parsed["NoumWidget"]["PRODUCT_BUNDLE_IDENTIFIER"], "com.jordancoaten.noum.NoumWidget")

    def test_repository_contract_accepts_complete_unsigned_archive(self) -> None:
        checks = release.repository_checks(
            self.root,
            valid_settings(),
            True,
            self.archive,
            scanner=lambda _: True,
        )
        self.assertTrue(all(item.passed for item in checks), [item for item in checks if not item.passed])

    def test_release_app_attest_must_be_production(self) -> None:
        settings = valid_settings()
        settings["Noum"]["APP_ATTEST_ENVIRONMENT"] = "development"
        checks = release.repository_checks(
            self.root, settings, True, self.archive, scanner=lambda _: True
        )
        self.assertFalse(next(item for item in checks if item.key == "releaseAppAttestProduction").passed)

    def test_bundle_identifier_drift_fails_target_shape(self) -> None:
        settings = valid_settings()
        settings["NoumWidget"]["PRODUCT_BUNDLE_IDENTIFIER"] = "com.example.widget"
        checks = release.repository_checks(
            self.root, settings, True, self.archive, scanner=lambda _: True
        )
        self.assertFalse(next(item for item in checks if item.key == "releaseTargetSigningShape").passed)

    def test_export_options_cannot_pin_team_or_profile(self) -> None:
        path = self.root / "scripts/TestFlightExportOptions.plist"
        value = plistlib.loads(path.read_bytes())
        value["teamID"] = "TESTTEAM1"
        write_plist(path, value)
        checks = release.repository_checks(
            self.root, valid_settings(), True, self.archive, scanner=lambda _: True
        )
        self.assertFalse(next(item for item in checks if item.key == "appStoreExportOptionsSafe").passed)

    def test_ignored_provider_config_in_archive_fails(self) -> None:
        write_plist(
            self.archive / release.ARCHIVED_PRODUCTS["Noum"] / "AIConfig.plist",
            {"fixture": True},
        )
        checks = release.archive_checks(self.root, self.archive, scanner=lambda _: True)
        self.assertFalse(next(item for item in checks if item.key == "archiveIgnoredConfigsExcluded").passed)

    def test_distribution_authority_requires_identity_and_three_profiles(self) -> None:
        checks = release.authority_checks(
            valid_settings(),
            {"valid": 2, "development": 2, "distribution": 0},
            [],
        )
        self.assertFalse(all(item.passed for item in checks))
        self.assertFalse(next(item for item in checks if item.key == "appleDistributionIdentity").passed)

    def test_distribution_authority_accepts_exact_capability_profiles(self) -> None:
        profiles = [app_store_profile(target) for target in ("Noum", "NoumWidget", "NoumMessages")]
        checks = release.authority_checks(
            valid_settings(),
            {"valid": 1, "development": 0, "distribution": 1},
            profiles,
        )
        self.assertTrue(all(item.passed for item in checks), checks)

    def test_development_profile_does_not_count_as_app_store(self) -> None:
        profile = app_store_profile("NoumWidget")
        profile["ProvisionedDevices"] = ["TEST-DEVICE"]
        profile["Entitlements"]["get-task-allow"] = True
        checks = release.authority_checks(
            valid_settings(),
            {"valid": 1, "development": 0, "distribution": 1},
            [profile],
        )
        self.assertFalse(next(item for item in checks if item.key == "appStoreProfileNoumWidget").passed)

    def test_missing_app_group_does_not_count_as_matching_profile(self) -> None:
        profile = app_store_profile("NoumMessages")
        profile["Entitlements"]["com.apple.security.application-groups"] = []
        checks = release.authority_checks(
            valid_settings(),
            {"valid": 1, "development": 0, "distribution": 1},
            [profile],
        )
        self.assertFalse(next(item for item in checks if item.key == "appStoreProfileNoumMessages").passed)

    def test_external_evidence_is_required(self) -> None:
        checks = release.evidence_checks(None)
        self.assertFalse(all(item.passed for item in checks))

    def test_existing_validator_must_accept_both_external_artifacts(self) -> None:
        readiness = {
            "artifactAudit": {
                "requiredArtifacts": [
                    {
                        "blocker": "noRealDeviceTestFlightVerification",
                        "passesLightweightContract": True,
                        "activeBlocker": False,
                    },
                    {
                        "blocker": "operationalLaunchChecklistIncomplete",
                        "passesLightweightContract": True,
                        "activeBlocker": False,
                    },
                ]
            }
        }
        self.assertTrue(all(item.passed for item in release.evidence_checks(readiness)))

    def test_direct_development_install_status_cannot_pass(self) -> None:
        readiness = {
            "artifactAudit": {
                "requiredArtifacts": [
                    {
                        "blocker": "noRealDeviceTestFlightVerification",
                        "passesLightweightContract": False,
                        "activeBlocker": True,
                        "contractFailures": ["testFlightDistributionChannelNotProven"],
                    }
                ]
            }
        }
        checks = release.evidence_checks(readiness)
        self.assertFalse(next(item for item in checks if item.key == "physicalTestFlightEvidence").passed)

    def test_overall_result_cannot_pass_without_external_evidence(self) -> None:
        green = release.Check("fixture", True, "redacted", "none")
        payload = release.result_payload(
            (
                release.Section("repository", "Repository", (green,)),
                release.Section("authority", "Authority", (green,)),
                release.Section("evidence", "Evidence", tuple(release.evidence_checks(None))),
            )
        )
        self.assertFalse(payload["passed"])
        self.assertFalse(payload["evidenceBoundary"]["directDevelopmentInstallIsTestFlightEvidence"])

    def test_identity_summary_never_returns_names_or_hashes(self) -> None:
        raw = (
            '  1) ABCDEF "Apple Development: Sensitive Name (TESTTEAM1)"\n'
            '  2) FEDCBA "Apple Distribution: Sensitive Name (TESTTEAM1)"\n'
            '     2 valid identities found\n'
        )
        summary = release.identity_counts(raw)
        self.assertEqual(summary, {"valid": 2, "development": 1, "distribution": 1})
        self.assertNotIn("Sensitive", repr(summary))
        self.assertNotIn("TESTTEAM1", repr(summary))


if __name__ == "__main__":
    unittest.main(verbosity=2)
