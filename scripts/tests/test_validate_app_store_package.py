import copy
import hashlib
import importlib.util
import json
import struct
import subprocess
import tempfile
import unittest
import zlib
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "validate-app-store-package.py"
SPEC = importlib.util.spec_from_file_location("validate_app_store_package", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_png(path: Path, width: int, height: int, color_type: int = 2) -> None:
    channels = {2: 3, 6: 4}[color_type]
    pixel = bytes(range(1, channels + 1))
    pixels = b"".join(b"\x00" + pixel * width for _ in range(height))

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(pixels))
        + chunk(b"IEND", b"")
    )


class AppStorePackageValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.release_template = json.loads(MODULE.RELEASE_ASSET_TEMPLATE.read_text(encoding="utf-8"))
        self.aso_template = json.loads(MODULE.ASO_EXPERIMENT_TEMPLATE.read_text(encoding="utf-8"))

    def test_checked_in_contracts_validate_without_claiming_evidence(self) -> None:
        MODULE.validate_release_asset_manifest(MODULE.RELEASE_ASSET_TEMPLATE, verify_files=False)
        MODULE.validate_aso_experiment_manifest(MODULE.ASO_EXPERIMENT_TEMPLATE, verify_results=False)

    def test_checked_in_release_template_cannot_pass_evidence_mode(self) -> None:
        with self.assertRaisesRegex(AssertionError, "status must be COLLECTED_RELEASE_ASSETS"):
            MODULE.validate_release_asset_manifest(MODULE.RELEASE_ASSET_TEMPLATE, verify_files=True)

    def test_png_reader_verifies_dimensions_and_alpha(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            rgb = root / "rgb.png"
            rgba = root / "rgba.png"
            write_png(rgb, 3, 2, color_type=2)
            write_png(rgba, 4, 5, color_type=6)
            self.assertEqual(MODULE.read_image_properties(rgb), (3, 2, False))
            self.assertEqual(MODULE.read_image_properties(rgba), (4, 5, True))

    def filled_release_manifest(self, root: Path) -> Path:
        manifest = copy.deepcopy(self.release_template)
        manifest["templateStatus"] = "COLLECTED_RELEASE_ASSETS"
        evidence = root / "release-candidate-evidence.json"
        evidence.write_text('{"distribution":"TestFlight"}', encoding="utf-8")
        manifest["releaseBinding"] = {
            "sourceGitCommit": "a" * 40,
            "marketingVersion": "1.0",
            "buildNumber": "101",
            "fixtureID": "appstore-fixture-001",
            "captureDistributionChannel": "TestFlight",
            "releaseCandidateEvidencePath": evidence.name,
            "releaseCandidateEvidenceSha256": digest(evidence),
            "sourceTreeClean": True,
        }
        for index, item in enumerate(manifest["screenshotAssets"]):
            path = root / f"{item['id']}.png"
            path.write_bytes(f"screenshot-{index}".encode("utf-8"))
            item["filePath"] = path.name
            item["sha256"] = digest(path)
        mappings = manifest["pageMappings"]
        mappings["default"]["appStoreConnectDeepLink"] = "https://appstoreconnect.apple.com/apps/123/appstore/ios/version"
        for item in mappings["customProductPages"]:
            item["appStoreConnectDeepLink"] = f"https://appstoreconnect.apple.com/apps/123/custom-product-pages/{item['id']}"
            item["publicProductPageURL"] = f"https://apps.apple.com/app/id123?ppid={item['id']}"
        for item in mappings["productPageOptimization"]:
            item["appStoreConnectTreatmentDeepLink"] = f"https://appstoreconnect.apple.com/apps/123/product-page-optimization/{item['id']}"
        preview = root / "preview.mp4"
        preview.write_bytes(b"real-preview-placeholder-for-probe")
        manifest["appPreview"]["filePath"] = preview.name
        manifest["appPreview"]["sha256"] = digest(preview)
        path = root / "release-assets.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        return path

    def test_filled_release_manifest_verifies_files_media_links_and_clean_binding(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = self.filled_release_manifest(Path(directory))
            git_results = [
                subprocess.CompletedProcess([], 0, stdout="a" * 40 + "\n", stderr=""),
                subprocess.CompletedProcess([], 0, stdout="", stderr=""),
            ]
            probe = {
                "streams": [{
                    "codec_name": "h264",
                    "profile": "High",
                    "codec_tag_string": "avc1",
                    "width": 886,
                    "height": 1920,
                    "avg_frame_rate": "30/1",
                    "duration": "25.0",
                }],
                "format": {"duration": "25.0"},
            }
            with mock.patch.object(MODULE.subprocess, "run", side_effect=git_results), \
                    mock.patch.object(MODULE, "read_image_properties", return_value=(1320, 2868, False)), \
                    mock.patch.object(MODULE, "probe_video", return_value=probe):
                MODULE.validate_release_asset_manifest(manifest, verify_files=True)

    def test_release_manifest_rejects_wrong_screenshot_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = self.filled_release_manifest(Path(directory))
            git_results = [
                subprocess.CompletedProcess([], 0, stdout="a" * 40 + "\n", stderr=""),
                subprocess.CompletedProcess([], 0, stdout="", stderr=""),
            ]
            with mock.patch.object(MODULE.subprocess, "run", side_effect=git_results), \
                    mock.patch.object(MODULE, "read_image_properties", return_value=(1290, 2796, False)):
                with self.assertRaisesRegex(AssertionError, "expected 1320x2868 pixels"):
                    MODULE.validate_release_asset_manifest(manifest, verify_files=True)

    def test_release_manifest_rejects_dirty_source_binding(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = self.filled_release_manifest(Path(directory))
            git_results = [
                subprocess.CompletedProcess([], 0, stdout="a" * 40 + "\n", stderr=""),
                subprocess.CompletedProcess([], 0, stdout=" M Noum/ContentView.swift\n", stderr=""),
            ]
            with mock.patch.object(MODULE.subprocess, "run", side_effect=git_results):
                with self.assertRaisesRegex(AssertionError, "completely clean source checkout"):
                    MODULE.validate_release_asset_manifest(manifest, verify_files=True)

    def filled_aso_manifest(self, root: Path, denominator: int = 1000) -> Path:
        manifest = copy.deepcopy(self.aso_template)
        manifest["templateStatus"] = "COLLECTED_ASO_EXPERIMENT_EVIDENCE"
        commit = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True, capture_output=True, text=True,
        ).stdout.strip()
        experiment = manifest["experiment"]
        experiment.update({
            "experimentID": "ppo-v1-evidence-pressure-plan",
            "appStoreConnectExperimentDeepLink": "https://appstoreconnect.apple.com/apps/123/product-page-optimization/456",
            "appVersion": "1.0",
            "sourceGitCommit": commit,
            "startedAtISO8601": "2026-01-01T00:00:00Z",
            "endedAtISO8601": "2026-01-09T00:00:00Z",
        })
        experiment["decisionRequirements"]["minimumUniqueImpressionsPerArmPerStorefront"] = 1000
        export = root / "app-store-connect-results.csv"
        export.write_text("storefront,arm,views,downloads\n", encoding="utf-8")
        decision = root / "independent-decision.json"
        decision.write_text('{"decision":"adopt-treatment"}', encoding="utf-8")
        rows = []
        for storefront in MODULE.EXPECTED_STOREFRONTS:
            for arm in MODULE.EXPECTED_ARM_IDS:
                rows.append({
                    "storefront": storefront,
                    "armID": arm,
                    "uniqueImpressions": denominator,
                    "firstTimeDownloads": denominator // 10,
                })
        arm_summaries = [
            {
                "armID": "default",
                "uniqueImpressions": denominator * 2,
                "estimatedConversionRateBasisPoints": 1000,
                "estimatedRelativeLiftBasisPoints": 0,
                "confidenceBasisPoints": None,
                "appleStatus": "baseline",
            },
            {
                "armID": "evidence",
                "uniqueImpressions": denominator * 2,
                "estimatedConversionRateBasisPoints": 1200,
                "estimatedRelativeLiftBasisPoints": 2000,
                "confidenceBasisPoints": 9200,
                "appleStatus": "performing-better",
            },
            {
                "armID": "pressure",
                "uniqueImpressions": denominator * 2,
                "estimatedConversionRateBasisPoints": 980,
                "estimatedRelativeLiftBasisPoints": -200,
                "confidenceBasisPoints": 6500,
                "appleStatus": "collecting-data",
            },
            {
                "armID": "plan",
                "uniqueImpressions": denominator * 2,
                "estimatedConversionRateBasisPoints": 1010,
                "estimatedRelativeLiftBasisPoints": 100,
                "confidenceBasisPoints": 5400,
                "appleStatus": "likely-inconclusive",
            },
        ]
        manifest["results"] = {
            "rows": rows,
            "armSummaries": arm_summaries,
            "appStoreConnectResultExportPath": export.name,
            "appStoreConnectResultExportSha256": digest(export),
            "decision": "adopt-treatment",
            "selectedArmID": "evidence",
            "decisionRationale": "The evidence treatment met the pre-registered denominator and was selected from the retained result.",
            "decidedAtISO8601": "2026-01-10T00:00:00Z",
            "decidedByID": "growth-operator-1",
            "verifiedAtISO8601": "2026-01-11T00:00:00Z",
            "verifiedByID": "independent-verifier-2",
            "decisionRecordPath": decision.name,
            "decisionRecordSha256": digest(decision),
        }
        path = root / "aso-experiment.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        return path

    def test_filled_aso_result_requires_version_storefront_window_and_independence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = self.filled_aso_manifest(Path(directory))
            MODULE.validate_aso_experiment_manifest(manifest, verify_results=True)

    def test_aso_result_cannot_select_treatment_below_registered_denominator(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = self.filled_aso_manifest(Path(directory), denominator=999)
            with self.assertRaisesRegex(AssertionError, "cannot be adopted below"):
                MODULE.validate_aso_experiment_manifest(manifest, verify_results=True)

    def test_aso_result_cannot_call_low_confidence_treatment_a_winner(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = self.filled_aso_manifest(Path(directory))
            value = json.loads(manifest.read_text(encoding="utf-8"))
            evidence = next(item for item in value["results"]["armSummaries"] if item["armID"] == "evidence")
            evidence["confidenceBasisPoints"] = 8999
            manifest.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaisesRegex(AssertionError, "requires at least 90% confidence"):
                MODULE.validate_aso_experiment_manifest(manifest, verify_results=True)


if __name__ == "__main__":
    unittest.main()
