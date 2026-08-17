import pathlib
import unittest


class TestFlightPreflightHostGuardTests(unittest.TestCase):
    def test_shell_wrapper_fails_with_a_clear_host_boundary(self) -> None:
        root = pathlib.Path(__file__).resolve().parents[1]
        source = (root / "scripts" / "release-testflight-preflight.sh").read_text()

        self.assertIn('"$(uname -s)" != "Darwin"', source)
        self.assertIn("requires macOS with Xcode and Apple signing tools", source)
        self.assertIn("xcodebuild xcrun security", source)


if __name__ == "__main__":
    unittest.main()
