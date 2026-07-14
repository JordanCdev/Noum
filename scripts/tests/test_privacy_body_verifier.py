#!/usr/bin/env python3
"""No-network contracts for source-exact hosted privacy verification."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "privacy_body_verifier.py"
PROBE_PATH = REPO_ROOT / "scripts" / "release-live-privacy-probe.sh"
EXPECTED_PATH = REPO_ROOT / "public" / "privacy.html"
REQUEST_URL = "https://noum-d0b6f.web.app/privacy"

SPEC = importlib.util.spec_from_file_location("privacy_body_verifier", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
verifier = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verifier
SPEC.loader.exec_module(verifier)


class PrivacyBodyVerifierTests(unittest.TestCase):
    def verify(self, observed: bytes, **overrides):
        expected = b"<html><h1>Noum Privacy Policy</h1></html>"
        arguments = {
            "expected_body": expected,
            "observed_body": observed,
            "requested_url": REQUEST_URL,
            "final_url": REQUEST_URL,
            "status": 200,
            "content_type": "text/html; charset=utf-8",
        }
        arguments.update(overrides)
        return verifier.verify_privacy_response(**arguments)

    def test_exact_complete_body_passes(self):
        expected = b"<html><h1>Noum Privacy Policy</h1></html>"

        result = self.verify(expected)

        self.assertTrue(result.passed)
        self.assertEqual(result.errors, ())
        self.assertEqual(result.expected_sha256, result.observed_sha256)

    def test_stale_body_with_all_markers_fails(self):
        expected = EXPECTED_PATH.read_bytes()
        stale = expected + b"\n<!-- stale deployment with every current marker retained -->\n"

        result = verifier.verify_privacy_response(
            expected_body=expected,
            observed_body=stale,
            requested_url=REQUEST_URL,
            final_url=REQUEST_URL,
            status=200,
            content_type="text/html",
        )

        self.assertFalse(result.passed)
        self.assertIn("bodyMismatch", result.errors)

    def test_one_byte_drift_fails(self):
        expected = b"<html>Noum Privacy Policy</html>"
        observed = expected[:-1] + b"!"

        result = verifier.verify_privacy_response(
            expected_body=expected,
            observed_body=observed,
            requested_url=REQUEST_URL,
            final_url=REQUEST_URL,
            status=200,
            content_type="text/html",
        )

        self.assertEqual(result.errors, ("bodyMismatch",))

    def test_truncated_body_fails(self):
        expected = b"<html>Noum Privacy Policy and current processors</html>"

        result = verifier.verify_privacy_response(
            expected_body=expected,
            observed_body=expected[:-8],
            requested_url=REQUEST_URL,
            final_url=REQUEST_URL,
            status=200,
            content_type="text/html",
        )

        self.assertIn("bodyMismatch", result.errors)

    def test_oversize_body_fails_before_equality(self):
        expected = b"expected"
        observed = b"x" * 65

        result = verifier.verify_privacy_response(
            expected_body=expected,
            observed_body=observed,
            requested_url=REQUEST_URL,
            final_url=REQUEST_URL,
            status=200,
            content_type="text/html",
            max_body_bytes=64,
        )

        self.assertIn("responseBodyOversize", result.errors)
        self.assertNotIn("bodyMismatch", result.errors)

    def test_wrong_mime_type_fails(self):
        expected = b"<html><h1>Noum Privacy Policy</h1></html>"

        result = self.verify(expected, content_type="text/plain; charset=utf-8")

        self.assertEqual(result.errors, ("contentTypeNotHTML",))

    def test_404_fails(self):
        result = self.verify(b"not found", status=404)

        self.assertIn("httpStatusNotSuccessful", result.errors)

    def test_redirect_origin_escape_fails(self):
        expected = b"<html><h1>Noum Privacy Policy</h1></html>"

        result = self.verify(
            expected,
            final_url="https://lookalike.example/privacy",
        )

        self.assertEqual(result.errors, ("redirectOriginEscape",))

    def test_unapproved_https_origin_fails(self):
        expected = b"<html><h1>Noum Privacy Policy</h1></html>"

        result = self.verify(
            expected,
            requested_url="https://unapproved.example/privacy",
            final_url="https://unapproved.example/privacy",
        )

        self.assertIn("requestedURLNotApprovedHTTPS", result.errors)
        self.assertNotIn("redirectOriginEscape", result.errors)

    def test_cli_diagnostics_never_print_response_body(self):
        secret = "TEST-ONLY-PRIVATE-BODY-MUST-NOT-LEAK"
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            expected_path = root / "expected.html"
            observed_path = root / "observed.html"
            expected_path.write_text("expected", encoding="utf-8")
            observed_path.write_text(secret, encoding="utf-8")
            stdout = io.StringIO()
            stderr = io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                status = verifier.main([
                    "--expected-body", str(expected_path),
                    "--observed-body", str(observed_path),
                    "--requested-url", REQUEST_URL,
                    "--final-url", REQUEST_URL,
                    "--status", "200",
                    "--content-type", "text/html",
                ])

        self.assertEqual(status, 1)
        combined = stdout.getvalue() + stderr.getvalue()
        self.assertNotIn(secret, combined)
        self.assertIn("expectedSHA256=", combined)
        self.assertIn("observedSHA256=", combined)


class LivePrivacyProbeShellTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        fake_curl = self.bin_dir / "curl"
        fake_curl.write_text(
            textwrap.dedent(
                """\
                #!/usr/bin/env python3
                import os
                import shutil
                import sys

                args = sys.argv[1:]
                output = args[args.index("--output") + 1]
                limit = int(args[args.index("--max-filesize") + 1])
                source = os.environ["FAKE_PRIVACY_BODY_PATH"]
                status = int(os.environ.get("FAKE_PRIVACY_STATUS", "200"))
                if os.path.getsize(source) > limit:
                    raise SystemExit(63)
                shutil.copyfile(source, output)
                sys.stdout.write(status.__str__() + "\\n")
                sys.stdout.write(os.environ.get("FAKE_PRIVACY_FINAL_URL", "https://noum-d0b6f.web.app/privacy") + "\\n")
                sys.stdout.write(os.environ.get("FAKE_PRIVACY_CONTENT_TYPE", "text/html; charset=utf-8") + "\\n")
                """
            ),
            encoding="utf-8",
        )
        fake_curl.chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def run_probe(self, body_path: Path, **overrides):
        env = os.environ.copy()
        env.update({
            "PATH": f"{self.bin_dir}{os.pathsep}{env['PATH']}",
            "FAKE_PRIVACY_BODY_PATH": str(body_path),
        })
        env.update(overrides)
        return subprocess.run(
            ["bash", str(PROBE_PATH)],
            cwd=REPO_ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def test_shell_probe_passes_exact_source_body_without_network(self):
        result = self.run_probe(EXPECTED_PATH)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("exact-body verification passed", result.stdout)

    def test_shell_probe_rejects_stale_marker_complete_body_without_leaking_it(self):
        stale_path = self.root / "stale.html"
        stale_marker = "TEST-ONLY-STALE-HOSTED-BODY-MUST-NOT-LEAK"
        stale_path.write_bytes(EXPECTED_PATH.read_bytes() + stale_marker.encode())

        result = self.run_probe(stale_path)

        self.assertEqual(result.returncode, 1)
        combined = result.stdout + result.stderr
        self.assertIn("bodyMismatch", combined)
        self.assertNotIn(stale_marker, combined)

    def test_shell_probe_rejects_redirect_origin_escape(self):
        result = self.run_probe(
            EXPECTED_PATH,
            FAKE_PRIVACY_FINAL_URL="https://lookalike.example/privacy",
        )

        self.assertEqual(result.returncode, 1)
        self.assertIn("redirectOriginEscape", result.stderr)

    def test_shell_probe_rejects_404_via_shared_contract(self):
        result = self.run_probe(
            EXPECTED_PATH,
            FAKE_PRIVACY_STATUS="404",
        )

        self.assertEqual(result.returncode, 1)
        self.assertIn("httpStatusNotSuccessful", result.stderr)


if __name__ == "__main__":
    unittest.main()
