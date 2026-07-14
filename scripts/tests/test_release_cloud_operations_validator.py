import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "release_cloud_operations_validator.py"
SPEC = importlib.util.spec_from_file_location(
    "release_cloud_operations_validator", SCRIPT
)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = validator
SPEC.loader.exec_module(validator)


def function_fixture(name, constant, *, state="ACTIVE", region=None):
    region = region or validator.PRODUCTION_REGION
    return {
        "name": (
            f"projects/{validator.PRODUCTION_PROJECT}/locations/{region}/"
            f"functions/{name}"
        ),
        "state": state,
        "serviceConfig": {
            "serviceAccountEmail": validator.runtime_email(constant)
        },
    }


def complete_snapshot():
    return {
        "functions": [
            function_fixture(name, constant)
            for name, constant in validator.EXPECTED_CALLABLES.items()
        ],
        "project_policy": {
            "bindings": [
                {
                    "role": "roles/aiplatform.user",
                    "members": [
                        "serviceAccount:"
                        + validator.runtime_email(
                            "COACH_RUNTIME_SERVICE_ACCOUNT"
                        )
                    ],
                }
            ]
        },
        "secret_policy": {
            "bindings": [
                {
                    "role": "roles/secretmanager.secretAccessor",
                    "members": [
                        "serviceAccount:"
                        + validator.runtime_email(
                            "TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT"
                        )
                    ],
                }
            ]
        },
    }


class SourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (
            Path(__file__).resolve().parents[2] / "functions/src/index.ts"
        ).read_text(encoding="utf-8")

    def test_current_source_has_exact_reviewed_callable_contract(self):
        passes = validator.validate_source_contract(self.source)
        self.assertEqual(len(passes), 3)

    def test_live_probe_consumes_the_validator_roster_for_unauthenticated_checks(self):
        probe = (
            Path(__file__).resolve().parents[1]
            / "release-cloud-operations-probe.sh"
        ).read_text(encoding="utf-8")
        self.assertIn(
            'callable_names="$(python3 "$runtime_validator" '
            '--print-callable-names)"',
            probe,
        )
        self.assertIn("for function_name in $callable_names; do", probe)

    def test_missing_and_unexpected_callable_fail_closed(self):
        changed = self.source.replace(
            "export const coachChat = onCall(",
            "export const lookalikeCoach = onCall(",
            1,
        )
        with self.assertRaises(validator.ContractError) as context:
            validator.validate_source_contract(changed)
        message = str(context.exception)
        self.assertIn("Missing callable exports: coachChat", message)
        self.assertIn("Unexpected callable exports: lookalikeCoach", message)

    def test_missing_app_check_fails_closed(self):
        changed = self.source.replace("enforceAppCheck: true", "", 1)
        with self.assertRaisesRegex(
            validator.ContractError,
            "coachChatAvailability must enforce App Check",
        ):
            validator.validate_source_contract(changed)

    def test_missing_shared_trusted_caller_fails_closed(self):
        changed = self.source.replace(
            "assertTrustedCaller(request.auth, request.app);", "", 1
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "coachChatAvailability must call the shared trusted-caller boundary",
        ):
            validator.validate_source_contract(changed)

    def test_wrong_service_account_mapping_fails_closed(self):
        changed = self.source.replace(
            "serviceAccount: RECOMMENDATION_RUNTIME_SERVICE_ACCOUNT,",
            "serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,",
            1,
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "syncRecommendationState must use RECOMMENDATION_RUNTIME_SERVICE_ACCOUNT",
        ):
            validator.validate_source_contract(changed)


class SnapshotContractTests(unittest.TestCase):
    def validate(self, snapshot):
        return validator.validate_cloud_snapshot(
            functions=snapshot["functions"],
            project_policy=snapshot["project_policy"],
            secret_policy=snapshot["secret_policy"],
            project=validator.PRODUCTION_PROJECT,
            region=validator.PRODUCTION_REGION,
            project_number="123456789",
        )

    def test_complete_snapshot_passes(self):
        passes = self.validate(complete_snapshot())
        self.assertEqual(len(passes), 5)

    def test_missing_function_fails(self):
        snapshot = complete_snapshot()
        snapshot["functions"].pop()
        with self.assertRaisesRegex(
            validator.ContractError, "Missing deployed callables: deleteAccount"
        ):
            self.validate(snapshot)

    def test_unexpected_function_fails(self):
        snapshot = complete_snapshot()
        snapshot["functions"].append({
            "name": (
                f"projects/{validator.PRODUCTION_PROJECT}/locations/"
                f"{validator.PRODUCTION_REGION}/functions/legacyCredentialVendor"
            ),
            "state": "ACTIVE",
            "serviceConfig": {
                "serviceAccountEmail": validator.runtime_email(
                    "TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT"
                )
            },
        })
        with self.assertRaisesRegex(
            validator.ContractError,
            "Unexpected deployed callables: legacyCredentialVendor",
        ):
            self.validate(snapshot)

    def test_inactive_function_fails(self):
        snapshot = complete_snapshot()
        snapshot["functions"][0]["state"] = "FAILED"
        with self.assertRaisesRegex(
            validator.ContractError, "coachChatAvailability is not ACTIVE"
        ):
            self.validate(snapshot)

    def test_wrong_region_fails(self):
        snapshot = complete_snapshot()
        snapshot["functions"][0] = function_fixture(
            "coachChatAvailability",
            "COACH_RUNTIME_SERVICE_ACCOUNT",
            region="us-central1",
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "coachChatAvailability is deployed in us-central1",
        ):
            self.validate(snapshot)

    def test_lookalike_project_path_fails(self):
        snapshot = complete_snapshot()
        snapshot["functions"][0]["name"] = snapshot["functions"][0][
            "name"
        ].replace(validator.PRODUCTION_PROJECT, "lookalike-noum", 1)
        with self.assertRaisesRegex(
            validator.ContractError,
            "coachChatAvailability belongs to lookalike-noum",
        ):
            self.validate(snapshot)

    def test_wrong_runtime_identity_fails(self):
        snapshot = complete_snapshot()
        snapshot["functions"][0]["serviceConfig"]["serviceAccountEmail"] = (
            validator.runtime_email("SOCIAL_RUNTIME_SERVICE_ACCOUNT")
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "coachChatAvailability uses noum-social-runtime",
        ):
            self.validate(snapshot)

    def test_owner_and_editor_on_runtime_identities_fail(self):
        for role in ("roles/owner", "roles/editor"):
            with self.subTest(role=role):
                snapshot = complete_snapshot()
                snapshot["project_policy"]["bindings"].append({
                    "role": role,
                    "members": [
                        "serviceAccount:"
                        + validator.runtime_email(
                            "ACCOUNT_RUNTIME_SERVICE_ACCOUNT"
                        )
                    ],
                })
                with self.assertRaisesRegex(
                    validator.ContractError, f"has broad role {role}"
                ):
                    self.validate(snapshot)

    def test_vertex_role_outside_coach_identity_fails(self):
        snapshot = complete_snapshot()
        snapshot["project_policy"]["bindings"].append({
            "role": "roles/aiplatform.user",
            "members": [
                "serviceAccount:"
                + validator.runtime_email(
                    "RECOMMENDATION_RUNTIME_SERVICE_ACCOUNT"
                )
            ],
        })
        with self.assertRaisesRegex(
            validator.ContractError, "has unauthorized Vertex role"
        ):
            self.validate(snapshot)

    def test_deepgram_secret_remains_exclusive(self):
        snapshot = complete_snapshot()
        snapshot["secret_policy"]["bindings"][0]["members"].append(
            "serviceAccount:"
            + validator.runtime_email("COACH_RUNTIME_SERVICE_ACCOUNT")
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "Deepgram secret must be readable only by the transcription runtime",
        ):
            self.validate(snapshot)


if __name__ == "__main__":
    unittest.main()
