import tempfile
import unittest
from pathlib import Path

from scripts.release_xcresult_gate import declared_test_count, validate


def passing_summary(passed: int = 2) -> dict[str, object]:
    return {
        "passedTests": passed,
        "failedTests": 0,
        "skippedTests": 0,
        "expectedFailures": 0,
        "totalTestCount": passed,
        "result": "Passed",
    }


class ReleaseXCResultGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.tests_root = Path(self.temporary.name)
        (self.tests_root / "JourneyUITests.swift").write_text(
            """
            final class JourneyUITests {
                func testFirstJourney() throws {}
                func testSecondJourney() async throws {}
            }
            """,
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_counts_source_declared_test_methods(self) -> None:
        self.assertEqual(declared_test_count(self.tests_root), 2)

    def test_accepts_complete_zero_skip_summary(self) -> None:
        self.assertEqual(validate(passing_summary(), self.tests_root), [])

    def test_rejects_skipped_or_expected_failures(self) -> None:
        skipped = passing_summary()
        skipped["passedTests"] = 1
        skipped["skippedTests"] = 1
        expected = passing_summary()
        expected["passedTests"] = 1
        expected["expectedFailures"] = 1

        self.assertTrue(
            any(
                "skipped UI tests" in error
                for error in validate(skipped, self.tests_root)
            )
        )
        self.assertTrue(
            any(
                "expected UI test failures" in error
                for error in validate(expected, self.tests_root)
            )
        )

    def test_rejects_zero_or_partial_execution(self) -> None:
        partial = passing_summary(passed=1)

        errors = validate(partial, self.tests_root)

        self.assertTrue(any("source declares 2" in error for error in errors))

    def test_rejects_missing_or_invalid_summary_schema(self) -> None:
        invalid = passing_summary()
        del invalid["skippedTests"]
        invalid["result"] = "Unknown"

        errors = validate(invalid, self.tests_root)

        self.assertTrue(any("skippedTests" in error for error in errors))
        self.assertTrue(any("status is not Passed" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
