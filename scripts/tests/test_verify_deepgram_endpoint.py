#!/usr/bin/env python3
"""Contract tests for the status-only legacy credential containment probe."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "verify_deepgram_endpoint.sh"
ROUTES = (
    "/v1/transcribe/deepgram-key",
    "/v1/transcribe/credentials",
    "/v1/im/context",
    "/v1/tts/im",
    "/v1/im/reply",
)


class LegacyCredentialProbeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        self.curl_log = self.root / "curl-log.jsonl"
        fake_curl = self.bin_dir / "curl"
        fake_curl.write_text(
            textwrap.dedent(
                """\
                #!/usr/bin/env python3
                import json
                import os
                import sys

                args = sys.argv[1:]
                with open(os.environ["FAKE_CURL_LOG"], "a", encoding="utf-8") as handle:
                    handle.write(json.dumps(args) + "\\n")

                url = args[-1]
                route = next(
                    (candidate for candidate in json.loads(os.environ["FAKE_CURL_CODES"])
                     if url.endswith(candidate)),
                    None,
                )
                outcome = json.loads(os.environ["FAKE_CURL_CODES"]).get(route, "401")
                if outcome == "EXIT":
                    raise SystemExit(7)
                if outcome == "MALFORMED":
                    sys.stdout.write("200\\nSHOULD-NOT-APPEAR-SECRET-BODY")
                else:
                    sys.stdout.write(str(outcome))
                """
            ),
            encoding="utf-8",
        )
        fake_curl.chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def run_probe(self, codes=None, base_url="https://legacy.example.test", **extra_env):
        env = os.environ.copy()
        env.update({
            "PATH": f"{self.bin_dir}{os.pathsep}{env['PATH']}",
            "BACKEND_BASE_URL": base_url,
            "FAKE_CURL_LOG": str(self.curl_log),
            "FAKE_CURL_CODES": json.dumps(codes or {route: "401" for route in ROUTES}),
        })
        env.pop("BACKEND_API_KEY", None)
        env.update(extra_env)
        return subprocess.run(
            ["bash", str(SCRIPT)],
            cwd=REPO_ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def curl_calls(self):
        if not self.curl_log.exists():
            return []
        return [json.loads(line) for line in self.curl_log.read_text().splitlines()]

    def test_all_documented_routes_must_return_protective_status(self):
        codes = dict(zip(ROUTES, ("401", "403", "404", "410", "401")))

        result = self.run_probe(codes)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS: every documented legacy route", result.stdout)
        calls = self.curl_calls()
        self.assertEqual(len(calls), len(ROUTES))
        self.assertTrue(all("--output" in call and "/dev/null" in call for call in calls))
        self.assertTrue(all(call[0] == "--disable" for call in calls))
        self.assertTrue(all("--location" not in call for call in calls))
        self.assertEqual({call[-1].removeprefix("https://legacy.example.test") for call in calls}, set(ROUTES))

    def test_credential_response_is_never_downloaded_or_authenticated(self):
        secret = "TEST-ONLY-BACKEND-SECRET-MUST-NOT-LEAK"

        result = self.run_probe(BACKEND_API_KEY=secret)

        self.assertEqual(result.returncode, 2)
        combined = result.stdout + result.stderr
        self.assertNotIn(secret, combined)
        self.assertIn("must be unset", combined)
        self.assertEqual(self.curl_calls(), [])

    def test_any_200_response_fails_the_whole_gate(self):
        codes = {route: "401" for route in ROUTES}
        codes["/v1/transcribe/credentials"] = "200"

        result = self.run_probe(codes)

        self.assertEqual(result.returncode, 1)
        self.assertIn("FAIL CLOSED", result.stderr)
        self.assertNotIn("PASS: every documented legacy route", result.stdout)

    def test_redirect_validation_rate_limit_and_server_error_are_not_closure(self):
        for status in ("302", "400", "429", "500"):
            with self.subTest(status=status):
                codes = {route: "401" for route in ROUTES}
                codes["/v1/im/reply"] = status

                result = self.run_probe(codes)

                self.assertEqual(result.returncode, 1)
                self.assertIn(f"HTTP {status}", result.stdout)

    def test_transport_failure_and_000_status_fail_closed(self):
        for outcome in ("EXIT", "000"):
            with self.subTest(outcome=outcome):
                codes = {route: "401" for route in ROUTES}
                codes["/v1/transcribe/deepgram-key"] = outcome

                result = self.run_probe(codes)

                self.assertEqual(result.returncode, 1)
                self.assertIn("FAIL CLOSED", result.stderr)

    def test_malformed_curl_output_is_not_reflected_to_logs(self):
        codes = {route: "401" for route in ROUTES}
        codes["/v1/transcribe/deepgram-key"] = "MALFORMED"

        result = self.run_probe(codes)

        self.assertEqual(result.returncode, 1)
        combined = result.stdout + result.stderr
        self.assertNotIn("SHOULD-NOT-APPEAR-SECRET-BODY", combined)
        self.assertIn("no trustworthy HTTP status", combined)

    def test_unsafe_base_urls_are_rejected_before_curl(self):
        unsafe = (
            "http://legacy.example.test",
            "https://user:secret@legacy.example.test",
            "https://legacy.example.test?token=secret",
            "https://legacy.example.test#fragment",
            "https://legacy.example.test/path with-space",
        )
        for base_url in unsafe:
            with self.subTest(base_url=base_url):
                result = self.run_probe(base_url=base_url)
                self.assertEqual(result.returncode, 2)
        self.assertEqual(self.curl_calls(), [])


if __name__ == "__main__":
    unittest.main()
