import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


class ReleaseWorkflowContractTests(unittest.TestCase):
    def source(self, relative_path: str) -> str:
        return (REPOSITORY_ROOT / relative_path).read_text(encoding="utf-8")

    def test_coach_regression_suites_are_mandatory(self) -> None:
        workflow = self.source(".github/workflows/release-readiness.yml")

        self.assertIn("coach-arena:", workflow)
        self.assertIn("./tools/coach-arena/run.sh test", workflow)
        self.assertIn("./tools/coach-arena/run.sh validate", workflow)

    def test_release_xcode_suites_are_serialized(self) -> None:
        for relative_path in (
            "scripts/release-xcode-ci.sh",
            "scripts/release-beta-feedback-ui-smoke.sh",
            "scripts/release-core-permission-ui-smoke.sh",
        ):
            script = self.source(relative_path)
            self.assertIn("-parallel-testing-enabled NO", script, relative_path)
            self.assertIn("-maximum-parallel-testing-workers 1", script, relative_path)

    def test_core_and_microphone_permission_ui_contracts_are_required(self) -> None:
        workflow = self.source(".github/workflows/release-readiness.yml")
        script = self.source("scripts/release-core-permission-ui-smoke.sh")

        self.assertIn("./scripts/release-core-permission-ui-smoke.sh", workflow)
        self.assertIn(
            "NoumUITests/testFirstRunCreatesAccountThenTimedHarnessReachesFirstVerdict",
            script,
        )
        self.assertIn(
            "GoalOutcomeLoopUITests/testTranscriptLadderPractisesOneStepRewriteFromSummary",
            script,
        )
        self.assertIn(
            "HomePracticePathPolishUITests/testFillerControlMicrophoneDenialOffersSettingsNotStart",
            script,
        )
        self.assertIn(
            "HomePracticePathPolishUITests/testPaceMicrophoneDenialOffersSettingsNotStart",
            script,
        )


if __name__ == "__main__":
    unittest.main()
