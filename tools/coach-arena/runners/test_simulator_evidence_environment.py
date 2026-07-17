import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


HELPER = Path(__file__).resolve().parents[1] / "simulator-evidence-environment.sh"
COACH_ARENA_ROOT = HELPER.parent
EXPLICIT_UDID = "BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E"
LATEST_UDID = "LATEST-IOS-26-5-UDID"


FAKE_XCRUN = r'''#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

args = sys.argv[1:]
log_path = Path(os.environ["NOUM_FAKE_XCRUN_LOG"])
state_path = Path(os.environ["NOUM_FAKE_XCRUN_STATE"])
with log_path.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(args) + "\n")

if args == ["simctl", "list", "devices", "available", "--json"]:
    print(json.dumps({
        "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-26-4": [
                {"name": "iPhone 17 Pro", "udid": "OLDER-IOS-26-4-UDID", "state": "Booted", "isAvailable": True}
            ],
            "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
                {"name": "iPhone 17 Pro", "udid": "LATEST-IOS-26-5-UDID", "state": "Shutdown", "isAvailable": True}
            ],
        }
    }))
    raise SystemExit(0)

if args[:2] == ["simctl", "boot"]:
    raise SystemExit(0)
if args[:2] == ["simctl", "bootstatus"]:
    raise SystemExit(2 if os.environ.get("NOUM_FAKE_XCRUN_FAIL_BOOTSTATUS") == "1" else 0)

if len(args) >= 6 and args[:2] == ["simctl", "spawn"] and args[3] == "launchctl":
    action, key = args[4:6]
    state = json.loads(state_path.read_text(encoding="utf-8"))
    if action == "getenv":
        if key not in state:
            raise SystemExit(1)
        print(state[key])
        raise SystemExit(0)
    if action == "setenv":
        state[key] = args[6]
    elif action == "unsetenv":
        state.pop(key, None)
    else:
        raise SystemExit(64)
    state_path.write_text(json.dumps(state, sort_keys=True), encoding="utf-8")
    raise SystemExit(0)

raise SystemExit(64)
'''


class SimulatorEvidenceEnvironmentTests(unittest.TestCase):
    def test_app_path_runners_require_disposable_simulator_and_preserve_signing(self):
        for script_name in ["unblock-app-path.sh", "refresh-evidence.sh"]:
            source = (COACH_ARENA_ROOT / script_name).read_text(encoding="utf-8")
            self.assertNotIn("CODE_SIGNING_ALLOWED=NO", source, script_name)
            self.assertNotIn(
                "platform=iOS Simulator,name=iPhone 17 Pro",
                source,
                script_name,
            )
            self.assertIn(
                '-z "${NOUM_COACH_XCODE_DESTINATION:-}"',
                source,
                script_name,
            )
            self.assertIn(
                '"${NOUM_COACH_DISPOSABLE_SIMULATOR:-}" != "1"',
                source,
                script_name,
            )
            self.assertIn(
                'destination="$NOUM_COACH_XCODE_DESTINATION"',
                source,
                script_name,
            )
            self.assertIn("destination_pattern=", source, script_name)
            self.assertIn("must name one simulator by exact UDID", source, script_name)

    def test_app_path_runners_fail_closed_without_both_disposable_inputs(self):
        incomplete_environments = [
            {},
            {"NOUM_COACH_XCODE_DESTINATION": f"platform=iOS Simulator,id={EXPLICIT_UDID}"},
            {"NOUM_COACH_DISPOSABLE_SIMULATOR": "1"},
        ]
        for script_name in ["unblock-app-path.sh", "refresh-evidence.sh"]:
            script = COACH_ARENA_ROOT / script_name
            for supplied in incomplete_environments:
                environment = os.environ.copy()
                environment.pop("NOUM_COACH_XCODE_DESTINATION", None)
                environment.pop("NOUM_COACH_DISPOSABLE_SIMULATOR", None)
                environment.update(supplied)
                completed = subprocess.run(
                    ["/bin/bash", str(script)],
                    env=environment,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(completed.returncode, 2, script_name)
                self.assertIn("NOUM_COACH_XCODE_DESTINATION", completed.stderr)
                self.assertIn("NOUM_COACH_DISPOSABLE_SIMULATOR=1", completed.stderr)

    def test_app_path_runners_reject_name_only_destination(self):
        environment = os.environ.copy()
        environment.update({
            "NOUM_COACH_XCODE_DESTINATION":
                "platform=iOS Simulator,name=iPhone 17 Pro",
            "NOUM_COACH_DISPOSABLE_SIMULATOR": "1",
        })
        for script_name in ["unblock-app-path.sh", "refresh-evidence.sh"]:
            completed = subprocess.run(
                ["/bin/bash", str(COACH_ARENA_ROOT / script_name)],
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 2, script_name)
            self.assertIn("exact UDID", completed.stderr)

    def run_harness(
        self,
        destination,
        *,
        fail_after_install=False,
        initial_state=None,
        inherited_keys=(),
        inherited_environment=None,
        fail_bootstatus=False,
        use_cli=False,
        command_exit_code=0,
    ):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            fake_xcrun = bin_dir / "xcrun"
            fake_xcrun.write_text(FAKE_XCRUN, encoding="utf-8")
            fake_xcrun.chmod(0o755)
            fake_xcodebuild = bin_dir / "fake-xcodebuild"
            fake_xcodebuild.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "with open(os.environ['NOUM_FAKE_XCRUN_LOG'], 'a', encoding='utf-8') as handle:\n"
                "    handle.write(json.dumps(['xcodebuild', *sys.argv[1:]]) + '\\n')\n"
                "raise SystemExit(int(os.environ.get('NOUM_FAKE_COMMAND_EXIT', '0')))\n",
                encoding="utf-8",
            )
            fake_xcodebuild.chmod(0o755)

            dump_dir = root / "dump dir"
            dump_dir.mkdir()
            (dump_dir / "source-git-commit.txt").write_text("abc123\n", encoding="utf-8")
            (dump_dir / "source-coach-fingerprint.txt").write_text(
                "sha256:test-source\n", encoding="utf-8"
            )
            state_path = root / "state.json"
            state_path.write_text(json.dumps(initial_state or {}), encoding="utf-8")
            log_path = root / "xcrun.jsonl"

            if use_cli:
                script = textwrap.dedent(
                    '''\
                    set -euo pipefail
                    "$NOUM_HELPER" run-xcodebuild \
                      --destination "$NOUM_DESTINATION" \
                      --dump-dir "$NOUM_DUMP_DIR" \
                      -- "$NOUM_FAKE_XCODEBUILD" test -destination "$NOUM_DESTINATION"
                    '''
                )
            else:
                script = textwrap.dedent(
                    f'''\
                set -euo pipefail
                source "$NOUM_HELPER"
                trap noum_coach_simulator_environment_exit_trap EXIT
                trap 'exit 130' INT
                trap 'exit 143' TERM
                trap 'exit 129' HUP
                noum_coach_install_simulator_environment "$NOUM_DESTINATION" "$NOUM_DUMP_DIR" {" ".join(inherited_keys)}
                printf '%s\n' "$NOUM_COACH_SIMULATOR_UDID"
                {"false" if fail_after_install else ":"}
                noum_coach_simulator_environment_cleanup
                '''
                )
            environment = os.environ.copy()
            environment.update({
                "PATH": f"{bin_dir}:{environment['PATH']}",
                "NOUM_HELPER": str(HELPER),
                "NOUM_DESTINATION": destination,
                "NOUM_DUMP_DIR": str(dump_dir),
                "NOUM_FAKE_XCRUN_LOG": str(log_path),
                "NOUM_FAKE_XCRUN_STATE": str(state_path),
                "NOUM_COACH_SIMULATOR_ENV_LOCK_ROOT": str(root / "locks"),
                "NOUM_FAKE_XCODEBUILD": str(fake_xcodebuild),
                "NOUM_FAKE_COMMAND_EXIT": str(command_exit_code),
            })
            environment.update(inherited_environment or {})
            if fail_bootstatus:
                environment["NOUM_FAKE_XCRUN_FAIL_BOOTSTATUS"] = "1"
            completed = subprocess.run(
                ["/bin/bash", "-c", script],
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )
            state = json.loads(state_path.read_text(encoding="utf-8"))
            calls = [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines()]
            lock_entries = list((root / "locks").glob("*"))
            return completed, state, calls, lock_entries

    def test_exact_destination_installs_values_and_restores_previous_state(self):
        initial_state = {"NOUM_SOURCE_GIT_COMMIT": "previous-commit"}
        completed, state, calls, locks = self.run_harness(
            f"platform=iOS Simulator,id={EXPLICIT_UDID}",
            initial_state=initial_state,
        )

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stdout.strip(), EXPLICIT_UDID)
        self.assertEqual(state, initial_state)
        self.assertEqual(locks, [])
        dump_calls = [
            call for call in calls
            if call[4:6] == ["setenv", "NOUM_COACH_EVAL_DUMP_DIR"]
        ]
        self.assertEqual(len(dump_calls), 1)
        self.assertTrue(dump_calls[0][6].endswith("/dump dir"))
        self.assertIn(
            ["simctl", "spawn", EXPLICIT_UDID, "launchctl", "setenv", "NOUM_SOURCE_GIT_COMMIT", "previous-commit"],
            calls,
        )
        self.assertIn(
            ["simctl", "spawn", EXPLICIT_UDID, "launchctl", "unsetenv", "NOUM_SOURCE_COACH_FINGERPRINT"],
            calls,
        )

    def test_failure_after_install_still_cleans_simulator_environment(self):
        completed, state, _, locks = self.run_harness(
            f"platform=iOS Simulator,id={EXPLICIT_UDID}",
            fail_after_install=True,
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(state, {})
        self.assertEqual(locks, [])

    def test_named_destination_selects_latest_runtime_and_pins_exact_udid(self):
        completed, state, calls, locks = self.run_harness(
            "platform=iOS Simulator,name=iPhone 17 Pro"
        )

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stdout.strip(), LATEST_UDID)
        self.assertEqual(state, {})
        self.assertEqual(locks, [])
        self.assertIn(["simctl", "list", "devices", "available", "--json"], calls)
        self.assertIn(["simctl", "bootstatus", LATEST_UDID, "-b"], calls)

    def test_additional_live_environment_is_installed_and_removed(self):
        completed, state, calls, locks = self.run_harness(
            f"platform=iOS Simulator,id={EXPLICIT_UDID}",
            inherited_keys=("NOUM_LIVE_AI_EVAL",),
            inherited_environment={"NOUM_LIVE_AI_EVAL": "1"},
        )

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(state, {})
        self.assertEqual(locks, [])
        self.assertIn(
            ["simctl", "spawn", EXPLICIT_UDID, "launchctl", "setenv", "NOUM_LIVE_AI_EVAL", "1"],
            calls,
        )
        self.assertIn(
            ["simctl", "spawn", EXPLICIT_UDID, "launchctl", "unsetenv", "NOUM_LIVE_AI_EVAL"],
            calls,
        )

    def test_boot_failure_releases_lock_without_changing_prior_environment(self):
        initial_state = {
            "NOUM_COACH_EVAL_DUMP_DIR": "/existing/dump",
            "NOUM_SOURCE_GIT_COMMIT": "existing-commit",
        }
        completed, state, calls, locks = self.run_harness(
            f"platform=iOS Simulator,id={EXPLICIT_UDID}",
            initial_state=initial_state,
            fail_bootstatus=True,
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(state, initial_state)
        self.assertEqual(locks, [])
        self.assertFalse(any(call[3:4] == ["launchctl"] for call in calls))

    def test_cli_without_extra_environment_pins_destination_and_cleans_on_failure(self):
        completed, state, calls, locks = self.run_harness(
            "platform=iOS Simulator,name=iPhone 17 Pro",
            use_cli=True,
            command_exit_code=7,
        )

        self.assertEqual(completed.returncode, 7, completed.stderr)
        self.assertEqual(state, {})
        self.assertEqual(locks, [])
        xcodebuild_call = next(call for call in calls if call[0] == "xcodebuild")
        destination_index = xcodebuild_call.index("-destination")
        self.assertEqual(
            xcodebuild_call[destination_index + 1],
            f"platform=iOS Simulator,id={LATEST_UDID}",
        )


if __name__ == "__main__":
    unittest.main()
