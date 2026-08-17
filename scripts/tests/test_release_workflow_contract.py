import re
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


class ReleaseWorkflowContractTests(unittest.TestCase):
    def source(self, relative_path: str) -> str:
        return (REPOSITORY_ROOT / relative_path).read_text(encoding="utf-8")

    def yaml_block(self, source: str, marker: str, indent: int) -> str:
        start = source.index(marker)
        remainder = source[start + len(marker):]
        next_peer = re.search(rf"(?m)^ {{{indent}}}\S", remainder)
        end = (
            len(source)
            if next_peer is None
            else start + len(marker) + next_peer.start()
        )
        return source[start:end]

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
            "scripts/release-full-ui-ci.sh",
        ):
            script = self.source(relative_path)
            self.assertIn("-parallel-testing-enabled NO", script, relative_path)
            self.assertIn("-maximum-parallel-testing-workers 1", script, relative_path)

    def test_full_ui_release_candidate_gate_is_explicit_and_complete(self) -> None:
        workflow = self.source(".github/workflows/release-readiness.yml")
        script = self.source("scripts/release-full-ui-ci.sh")
        full_ui_input = self.yaml_block(
            workflow,
            "      run_full_ui_suite:",
            indent=6,
        )
        full_ui_job = self.yaml_block(
            workflow,
            "  full-ui-release-candidate:",
            indent=2,
        )

        self.assertIn("default: true", full_ui_input)
        self.assertIn("github.event_name == 'workflow_dispatch'", full_ui_job)
        self.assertIn("inputs.run_full_ui_suite", full_ui_job)
        self.assertIn("startsWith(github.ref, 'refs/tags/rc-')", full_ui_job)
        self.assertIn("needs: xcode-release", full_ui_job)
        self.assertIn("./scripts/release-full-ui-ci.sh", full_ui_job)
        self.assertIn("if-no-files-found: error", full_ui_job)
        self.assertIn(
            "./scripts/release-materialize-ci-config.sh --clean",
            full_ui_job,
        )
        self.assertIn("if: always()", full_ui_job)

        self.assertIn("-only-testing:NoumUITests", script)
        self.assertNotIn("-only-testing:NoumUITests/", script)
        self.assertIn('-resultBundlePath "$result_bundle"', script)
        self.assertIn('if [[ -e "$result_bundle" ]]', script)
        self.assertIn("xcresulttool get test-results summary", script)
        self.assertIn("release_xcresult_gate.py", script)
        self.assertIn("Noum/Info.plist", script)
        self.assertIn("Noum/GoogleService-Info.plist", script)

    def test_rc_tags_run_the_full_gate_without_narrowing_branch_pushes(self) -> None:
        workflow = self.source(".github/workflows/release-readiness.yml")
        push_trigger = self.yaml_block(workflow, "  push:", indent=2)

        self.assertIn("branches:", push_trigger)
        self.assertIn("- '**'", push_trigger)
        self.assertIn("tags:", push_trigger)
        self.assertIn("- 'rc-*'", push_trigger)

    def test_full_ui_gate_reuses_only_existing_config_secrets(self) -> None:
        workflow = self.source(".github/workflows/release-readiness.yml")
        full_ui_job = self.yaml_block(
            workflow,
            "  full-ui-release-candidate:",
            indent=2,
        )

        self.assertIn("secrets.NOUM_INFO_PLIST_BASE64", full_ui_job)
        self.assertIn(
            "secrets.NOUM_GOOGLE_SERVICE_INFO_PLIST_BASE64",
            full_ui_job,
        )
        self.assertEqual(full_ui_job.count("secrets."), 2)

    def test_focused_ui_shard_remains_in_the_default_xcode_job(self) -> None:
        workflow = self.source(".github/workflows/release-readiness.yml")
        xcode_job = self.yaml_block(workflow, "  xcode-release:", indent=2)

        self.assertIn("./scripts/release-beta-feedback-ui-smoke.sh", xcode_job)
        self.assertIn("./scripts/release-core-permission-ui-smoke.sh", xcode_job)
        self.assertNotIn("./scripts/release-full-ui-ci.sh", xcode_job)

    def test_live_web_gate_is_mandatory_but_custom_cutover_is_manual(self) -> None:
        workflow = self.source(".github/workflows/release-readiness.yml")
        live_web_job = self.yaml_block(workflow, "  live-web:", indent=2)
        custom_input = self.yaml_block(
            workflow,
            "      probe_custom_domain:",
            indent=6,
        )

        self.assertIn("github.event_name != 'workflow_dispatch'", live_web_job)
        self.assertIn("inputs.run_live_web_probe", live_web_job)
        self.assertIn("./scripts/release-live-web-probe.sh active", live_web_job)
        self.assertIn("github.event_name == 'workflow_dispatch'", live_web_job)
        self.assertIn("inputs.probe_custom_domain", live_web_job)
        self.assertIn("./scripts/release-live-web-probe.sh custom", live_web_job)
        self.assertIn("default: false", custom_input)

        probe = self.source("scripts/release-live-web-probe.sh")
        verifier = self.source("scripts/privacy_body_verifier.py")
        self.assertIn("--print-active-hosting-target", probe)
        self.assertNotIn("--location", probe)
        self.assertIn("httpRedirectNotAllowed", verifier)

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
