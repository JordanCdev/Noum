#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import hashlib
import plistlib
import subprocess
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


TEST_DISTRIBUTION_CERTIFICATE = b"noum-test-distribution-certificate"
TEST_DISTRIBUTION_FINGERPRINT = hashlib.sha1(TEST_DISTRIBUTION_CERTIFICATE).hexdigest().upper()
TEST_DWARF_UUIDS = frozenset({("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "arm64")})
TEST_SOURCE_COMMIT = "a" * 40


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
        "DeveloperCertificates": [TEST_DISTRIBUTION_CERTIFICATE],
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
        premium_source = """
import StoreKit
static let monthlyID = "com.noum.pro.monthly"
static let annualID = "com.noum.pro.annual"
let productIDs = [monthlyID, annualID]
_ = Product.products(for: productIDs)
_ = Transaction.currentEntitlements
_ = AppStore.sync()
"""
        premium_path = self.root / "Noum/PremiumManager.swift"
        premium_path.parent.mkdir(parents=True, exist_ok=True)
        premium_path.write_text(premium_source, encoding="utf-8")
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
        write_plist(
            archive / "Info.plist",
            {
                "ArchiveVersion": 2,
                "ApplicationProperties": {
                    "ApplicationPath": "Applications/Noum.app",
                    "Architectures": ["arm64"],
                    "CFBundleIdentifier": release.EXPECTED_TARGETS["Noum"]["bundle"],
                },
            },
        )
        for target, relative in release.ARCHIVED_PRODUCTS.items():
            executable = target
            info = {
                "CFBundleIdentifier": release.EXPECTED_TARGETS[target]["bundle"],
                "CFBundleShortVersionString": "1.1",
                "CFBundleVersion": "2",
                "CFBundleExecutable": executable,
                "CFBundlePackageType": "APPL" if target == "Noum" else "XPC!",
                "CFBundleSupportedPlatforms": ["iPhoneOS"],
                "DTPlatformName": "iphoneos",
                "MinimumOSVersion": "17.0",
            }
            if target in release.ARCHIVED_EXTENSION_POINTS:
                info["NSExtension"] = {
                    "NSExtensionPointIdentifier": release.ARCHIVED_EXTENSION_POINTS[target]
                }
            if target == "Noum":
                info["ITSAppUsesNonExemptEncryption"] = False
                info[release.SOURCE_COMMIT_INFO_KEY] = TEST_SOURCE_COMMIT
            write_plist(
                archive / relative / "Info.plist",
                info,
            )
            binary = archive / relative / executable
            binary.parent.mkdir(parents=True, exist_ok=True)
            markers = b"fixture-binary"
            if target == "Noum":
                markers += b"\0".join(
                    (
                        *release.APPLE_SERVICE_BINARY_MARKERS,
                        b"com.noum.pro.monthly",
                        b"com.noum.pro.annual",
                    )
                )
            binary.write_bytes(markers)
            wrapper = relative.name
            dsym_binary = archive / "dSYMs" / f"{wrapper}.dSYM/Contents/Resources/DWARF" / executable
            dsym_binary.parent.mkdir(parents=True, exist_ok=True)
            dsym_binary.write_bytes(b"fixture-dsym")
        write_plist(
            archive / release.ARCHIVED_PRODUCTS["Noum"] / "PrivacyInfo.xcprivacy",
            {
                "NSPrivacyTracking": False,
                "NSPrivacyCollectedDataTypes": [],
                "NSPrivacyAccessedAPITypes": [],
            },
        )
        return archive

    def _repository_checks(self, settings: dict[str, dict[str, str]] | None = None):
        return release.repository_checks(
            self.root,
            settings or valid_settings(),
            True,
            self.archive,
            scanner=lambda _: True,
            expected_source_commit=TEST_SOURCE_COMMIT,
            uuid_reader=lambda _: TEST_DWARF_UUIDS,
        )

    def test_parse_build_settings_keeps_target_sections(self) -> None:
        output = """Build settings for action build and target Noum:\n    PRODUCT_BUNDLE_IDENTIFIER = com.jordancoaten.noum\nBuild settings for action build and target NoumWidget:\n    PRODUCT_BUNDLE_IDENTIFIER = com.jordancoaten.noum.NoumWidget\n"""
        parsed = release.parse_build_settings(output)
        self.assertEqual(parsed["Noum"]["PRODUCT_BUNDLE_IDENTIFIER"], "com.jordancoaten.noum")
        self.assertEqual(parsed["NoumWidget"]["PRODUCT_BUNDLE_IDENTIFIER"], "com.jordancoaten.noum.NoumWidget")

    def test_source_commit_binding_requires_a_clean_git_checkout(self) -> None:
        repository = self.root / "source-binding-repository"
        repository.mkdir()
        subprocess.run(["git", "init", "-q", str(repository)], check=True)
        (repository / "tracked.txt").write_text("release source\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(repository), "add", "tracked.txt"], check=True)
        subprocess.run(
            [
                "git", "-C", str(repository),
                "-c", "user.name=Noum Test",
                "-c", "user.email=noum-test@example.invalid",
                "commit", "-q", "-m", "fixture",
            ],
            check=True,
        )

        commit = release.current_source_commit(repository)
        self.assertRegex(commit or "", release.SOURCE_COMMIT_PATTERN)
        self.assertTrue(release.source_tree_is_clean(repository))

        (repository / "untracked.txt").write_text("not part of release\n", encoding="utf-8")
        self.assertFalse(release.source_tree_is_clean(repository))

    def test_repository_contract_accepts_complete_unsigned_archive(self) -> None:
        checks = self._repository_checks()
        self.assertTrue(all(item.passed for item in checks), [item for item in checks if not item.passed])

    def test_release_app_attest_must_be_production(self) -> None:
        settings = valid_settings()
        settings["Noum"]["APP_ATTEST_ENVIRONMENT"] = "development"
        checks = self._repository_checks(settings)
        self.assertFalse(next(item for item in checks if item.key == "releaseAppAttestProduction").passed)

    def test_bundle_identifier_drift_fails_target_shape(self) -> None:
        settings = valid_settings()
        settings["NoumWidget"]["PRODUCT_BUNDLE_IDENTIFIER"] = "com.example.widget"
        checks = self._repository_checks(settings)
        self.assertFalse(next(item for item in checks if item.key == "releaseTargetSigningShape").passed)

    def test_export_options_cannot_pin_team_or_profile(self) -> None:
        path = self.root / "scripts/TestFlightExportOptions.plist"
        value = plistlib.loads(path.read_bytes())
        value["teamID"] = "TESTTEAM1"
        write_plist(path, value)
        checks = self._repository_checks()
        self.assertFalse(next(item for item in checks if item.key == "appStoreExportOptionsSafe").passed)

    def test_ignored_provider_config_in_archive_fails(self) -> None:
        write_plist(
            self.archive / release.ARCHIVED_PRODUCTS["Noum"] / "AIConfig.plist",
            {"fixture": True},
        )
        checks = release.archive_checks(
            self.root,
            self.archive,
            scanner=lambda _: True,
            uuid_reader=lambda _: TEST_DWARF_UUIDS,
        )
        self.assertFalse(next(item for item in checks if item.key == "archiveIgnoredConfigsExcluded").passed)

    def test_archive_versions_must_match_each_other_and_release_settings(self) -> None:
        path = self.archive / release.ARCHIVED_PRODUCTS["NoumWidget"] / "Info.plist"
        value = plistlib.loads(path.read_bytes())
        value["CFBundleVersion"] = "3"
        write_plist(path, value)
        checks = self._repository_checks()
        self.assertFalse(next(item for item in checks if item.key == "archiveVersionMetadata").passed)

    def test_archive_must_match_the_exact_source_commit(self) -> None:
        path = self.archive / release.ARCHIVED_PRODUCTS["Noum"] / "Info.plist"
        value = plistlib.loads(path.read_bytes())
        value[release.SOURCE_COMMIT_INFO_KEY] = "b" * 40
        write_plist(path, value)
        checks = self._repository_checks()
        self.assertFalse(next(item for item in checks if item.key == "archiveSourceCommitBound").passed)

    def test_source_bound_info_generation_is_exact_and_non_destructive(self) -> None:
        source = self.root / "Noum/Info.plist"
        source_before = source.read_bytes()
        destination = self.root / "generated/SourceBoundInfo.plist"

        self.assertTrue(
            release.write_source_bound_info_plist(
                self.root,
                destination,
                TEST_SOURCE_COMMIT,
            )
        )
        generated = plistlib.loads(destination.read_bytes())
        self.assertEqual(generated[release.SOURCE_COMMIT_INFO_KEY], TEST_SOURCE_COMMIT)
        self.assertEqual(source.read_bytes(), source_before)
        self.assertFalse(
            release.write_source_bound_info_plist(
                self.root,
                destination,
                TEST_SOURCE_COMMIT,
            )
        )

    def test_archive_rejects_simulator_platform_shape(self) -> None:
        path = self.archive / release.ARCHIVED_PRODUCTS["Noum"] / "Info.plist"
        value = plistlib.loads(path.read_bytes())
        value["DTPlatformName"] = "iphonesimulator"
        value["CFBundleSupportedPlatforms"] = ["iPhoneSimulator"]
        write_plist(path, value)
        checks = self._repository_checks()
        self.assertFalse(next(item for item in checks if item.key == "archiveDevicePlatformShape").passed)

    def test_archive_rejects_stale_dsym_uuid(self) -> None:
        def mismatched(path: Path) -> frozenset[tuple[str, str]]:
            if ".dSYM" in str(path):
                return frozenset({("FFFFFFFF-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "arm64")})
            return TEST_DWARF_UUIDS

        checks = release.archive_checks(
            self.root,
            self.archive,
            scanner=lambda _: True,
            uuid_reader=mismatched,
        )
        self.assertFalse(next(item for item in checks if item.key == "archiveSymbolsPresent").passed)

    def test_archive_requires_compiled_storekit_and_apple_auth_paths(self) -> None:
        binary = self.archive / release.ARCHIVED_PRODUCTS["Noum"] / "Noum"
        binary.write_bytes(b"fixture-without-apple-service-markers")
        checks = self._repository_checks()
        self.assertFalse(next(item for item in checks if item.key == "archiveAppleServiceCodePaths").passed)

    def test_archive_requires_app_owned_privacy_and_export_metadata(self) -> None:
        (self.archive / release.ARCHIVED_PRODUCTS["Noum"] / "PrivacyInfo.xcprivacy").unlink()
        checks = self._repository_checks()
        self.assertFalse(next(item for item in checks if item.key == "archiveAppStoreMetadata").passed)

    def test_source_storekit_contract_requires_distinct_products(self) -> None:
        path = self.root / "Noum/PremiumManager.swift"
        source = path.read_text(encoding="utf-8")
        path.write_text(
            source.replace('static let annualID = "com.noum.pro.annual"', 'static let annualID = "com.noum.pro.monthly"'),
            encoding="utf-8",
        )
        checks = self._repository_checks()
        self.assertFalse(next(item for item in checks if item.key == "sourceStoreKitContract").passed)

    def test_distribution_authority_requires_identity_and_three_profiles(self) -> None:
        checks = release.authority_checks(
            valid_settings(),
            {"valid": 2, "development": 2, "distribution": 0},
            [],
            distribution_fingerprints=frozenset(),
        )
        self.assertFalse(all(item.passed for item in checks))
        self.assertFalse(next(item for item in checks if item.key == "appleDistributionIdentity").passed)

    def test_distribution_authority_accepts_exact_capability_profiles(self) -> None:
        profiles = [app_store_profile(target) for target in ("Noum", "NoumWidget", "NoumMessages")]
        checks = release.authority_checks(
            valid_settings(),
            {"valid": 1, "development": 0, "distribution": 1},
            profiles,
            distribution_fingerprints=frozenset({TEST_DISTRIBUTION_FINGERPRINT}),
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
            distribution_fingerprints=frozenset({TEST_DISTRIBUTION_FINGERPRINT}),
        )
        self.assertFalse(next(item for item in checks if item.key == "appStoreProfileNoumWidget").passed)

    def test_missing_app_group_does_not_count_as_matching_profile(self) -> None:
        profile = app_store_profile("NoumMessages")
        profile["Entitlements"]["com.apple.security.application-groups"] = []
        checks = release.authority_checks(
            valid_settings(),
            {"valid": 1, "development": 0, "distribution": 1},
            [profile],
            distribution_fingerprints=frozenset({TEST_DISTRIBUTION_FINGERPRINT}),
        )
        self.assertFalse(next(item for item in checks if item.key == "appStoreProfileNoumMessages").passed)

    def test_profile_must_contain_installed_distribution_identity(self) -> None:
        profiles = [app_store_profile(target) for target in ("Noum", "NoumWidget", "NoumMessages")]
        checks = release.authority_checks(
            valid_settings(),
            {"valid": 1, "development": 0, "distribution": 1},
            profiles,
            distribution_fingerprints=frozenset({"F" * 40}),
        )
        self.assertFalse(all(item.passed for item in checks))
        self.assertFalse(next(item for item in checks if item.key == "appStoreProfileNoum").passed)

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
            f'  1) {"A" * 40} "Apple Development: Sensitive Name (TESTTEAM1)"\n'
            f'  2) {TEST_DISTRIBUTION_FINGERPRINT} "Apple Distribution: Sensitive Name (TESTTEAM1)"\n'
            '     2 valid identities found\n'
        )
        summary = release.identity_counts(raw)
        self.assertEqual(summary, {"valid": 2, "development": 1, "distribution": 1})
        self.assertNotIn("Sensitive", repr(summary))
        self.assertNotIn("TESTTEAM1", repr(summary))
        self.assertNotIn(TEST_DISTRIBUTION_FINGERPRINT, repr(summary))
        self.assertEqual(
            release.distribution_identity_fingerprints(raw),
            frozenset({TEST_DISTRIBUTION_FINGERPRINT}),
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
