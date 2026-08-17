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
        self.assertIn(
            "python3 -m unittest discover -s scripts/tests -p 'test_*.py'",
            workflow,
        )

    def test_secret_scanner_uses_the_declared_pinned_go_module(self) -> None:
        workflow = self.source(".github/workflows/release-readiness.yml")

        self.assertIn(
            "go install github.com/zricethezav/gitleaks/v8@v8.30.1",
            workflow,
        )
        self.assertNotIn("github.com/gitleaks/gitleaks/v8", workflow)

    def test_emulator_invokes_the_firebase_binary_explicitly(self) -> None:
        script = self.source("scripts/release-functions-emulator.sh")

        self.assertIn(
            'npx --yes --package "firebase-tools@${FIREBASE_TOOLS_VERSION:-15.19.1}" firebase',
            script,
        )
        self.assertIn("'APP_STORE_APP_APPLE_ID=1234567890'", script)
        self.assertIn(
            "'APP_STORE_PRODUCTION_NOTIFICATIONS_ENABLED=false'",
            script,
        )
        self.assertIn(
            "'APP_STORE_SANDBOX_NOTIFICATIONS_ENABLED=false'",
            script,
        )

    def test_emulator_integration_closes_its_admin_app(self) -> None:
        source = self.source("functions/src/emulator.integration.test.ts")

        self.assertIn('import test, {after} from "node:test";', source)
        self.assertIn('import {deleteApp, initializeApp}', source)
        self.assertIn("after(async () => {", source)
        self.assertIn("await deleteApp(adminApp);", source)

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
