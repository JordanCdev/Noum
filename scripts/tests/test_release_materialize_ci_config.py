import base64
import os
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "release-materialize-ci-config.sh"
REVERSED_CLIENT_ID = "com.googleusercontent.apps.test-client"


def encoded_plist(value: dict) -> str:
    return base64.b64encode(plistlib.dumps(value)).decode("ascii")


class ReleaseMaterializeCIConfigTests(unittest.TestCase):
    def run_materializer(self, schemes: list[str]) -> tuple[subprocess.CompletedProcess[str], Path]:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        script = root / "scripts" / SCRIPT.name
        script.parent.mkdir(parents=True)
        shutil.copy2(SCRIPT, script)
        script.chmod(0o700)

        info = {
            "CFBundleURLTypes": [{"CFBundleURLSchemes": schemes}],
            "NSCameraUsageDescription": "Camera",
            "NSMicrophoneUsageDescription": "Microphone",
            "NSSpeechRecognitionUsageDescription": "Speech",
        }
        google = {
            "API_KEY": "test-api-key",
            "BUNDLE_ID": "uk.co.otherpath.noum",
            "CLIENT_ID": "test-client.apps.googleusercontent.com",
            "GOOGLE_APP_ID": "1:123:ios:test",
            "PROJECT_ID": "test-project",
            "REVERSED_CLIENT_ID": REVERSED_CLIENT_ID,
        }
        environment = os.environ.copy()
        environment.update({
            "NOUM_INFO_PLIST_BASE64": encoded_plist(info),
            "NOUM_GOOGLE_SERVICE_INFO_PLIST_BASE64": encoded_plist(google),
        })
        completed = subprocess.run(
            [str(script)],
            cwd=root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )
        return completed, root

    def test_materializes_only_when_app_and_google_url_schemes_are_present(self) -> None:
        completed, root = self.run_materializer(["noum", REVERSED_CLIENT_ID])

        self.assertEqual(completed.returncode, 0, completed.stderr)
        info_path = root / "Noum/Info.plist"
        self.assertTrue(info_path.is_file())
        self.assertTrue((root / "Noum/GoogleService-Info.plist").is_file())
        with info_path.open("rb") as handle:
            materialized_info = plistlib.load(handle)
        self.assertEqual(
            materialized_info["UILaunchScreen"],
            {"UIColorName": "LaunchBackground"},
        )

    def test_missing_app_url_scheme_fails_before_writing_plists(self) -> None:
        completed, root = self.run_materializer([REVERSED_CLIENT_ID])

        self.assertEqual(completed.returncode, 2)
        self.assertIn("required noum URL scheme", completed.stderr)
        self.assertFalse((root / "Noum/Info.plist").exists())
        self.assertFalse((root / "Noum/GoogleService-Info.plist").exists())


if __name__ == "__main__":
    unittest.main()
