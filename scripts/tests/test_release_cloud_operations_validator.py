import importlib.util
import json
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

TEST_APP_APPLE_ID = "123456789"


def function_fixture(name, constant, *, state="ACTIVE", region=None):
    region = region or validator.PRODUCTION_REGION
    service_config = {
        "serviceAccountEmail": validator.runtime_email(constant)
    }
    enable_keys = {
        "appStoreServerNotificationsV2":
            "APP_STORE_PRODUCTION_NOTIFICATIONS_ENABLED",
        "appStoreServerNotificationsV2Sandbox":
            "APP_STORE_SANDBOX_NOTIFICATIONS_ENABLED",
    }
    if name in enable_keys:
        service_config["environmentVariables"] = {
            "APP_STORE_APP_APPLE_ID": TEST_APP_APPLE_ID,
            enable_keys[name]: "false",
        }
        service_config["secretEnvironmentVariables"] = [{
            "key": "APP_STORE_ROOT_CERTIFICATES_BASE64",
            "secret": "APP_STORE_ROOT_CERTIFICATES_BASE64",
            "version": "latest",
        }]
    return {
        "name": (
            f"projects/{validator.PRODUCTION_PROJECT}/locations/{region}/"
            f"functions/{name}"
        ),
        "state": state,
        "serviceConfig": service_config,
    }


def complete_snapshot():
    return {
        "functions": [
            function_fixture(name, constant)
            for name, constant in validator.EXPECTED_FUNCTIONS.items()
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
                },
                {
                    "role": "roles/datastore.user",
                    "members": [
                        "serviceAccount:"
                        + validator.runtime_email(
                            "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT"
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
        "app_store_secret_policy": {
            "bindings": [
                {
                    "role": "roles/secretmanager.secretAccessor",
                    "members": [
                        "serviceAccount:"
                        + validator.runtime_email(
                            "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT"
                        )
                    ],
                }
            ]
        },
        "app_store_effective_policy": {
            "policyResults": [{
                "fullResourceName": (
                    "//secretmanager.googleapis.com/projects/123456789/"
                    "secrets/APP_STORE_ROOT_CERTIFICATES_BASE64"
                ),
                "policies": [
                    {
                        "attachedResource": (
                            "//secretmanager.googleapis.com/projects/123456789/"
                            "secrets/APP_STORE_ROOT_CERTIFICATES_BASE64"
                        ),
                        "policy": {
                            "bindings": [{
                                "role": "roles/secretmanager.secretAccessor",
                                "members": [
                                    "serviceAccount:"
                                    + validator.runtime_email(
                                        "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT"
                                    )
                                ],
                            }]
                        },
                    },
                    {
                        "attachedResource": (
                            "//cloudresourcemanager.googleapis.com/projects/"
                            + validator.PRODUCTION_PROJECT
                        ),
                        "policy": {
                            "bindings": [{
                                "role": "roles/datastore.user",
                                "members": [
                                    "serviceAccount:"
                                    + validator.runtime_email(
                                        "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT"
                                    )
                                ],
                            }]
                        },
                    },
                ],
            }]
        },
        "ttl_policies": [{
            "name": (
                f"projects/{validator.PRODUCTION_PROJECT}/databases/(default)/"
                "collectionGroups/_appStoreNotificationMarkers/fields/expiresAt"
            ),
            "ttlConfig": {"state": "ACTIVE"},
        }],
    }


def replace_in_callable(source, name, old, new):
    match = next(
        item
        for item in validator.CALLABLE_PATTERN.finditer(source)
        if item.group("name") == name
    )
    block = validator._trigger_block(source, match)
    if old not in block:
        raise AssertionError(f"{old!r} is not present in {name}")
    changed = block.replace(old, new, 1)
    return source[:match.start()] + changed + source[match.start() + len(block):]


class SourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = Path(__file__).resolve().parents[2]
        cls.source = (root / "functions/src/index.ts").read_text(encoding="utf-8")
        cls.app_store_source = (
            root / "functions/src/appStoreServerNotifications.ts"
        ).read_text(encoding="utf-8")
        cls.functions_lockfile = (
            root / "functions/package-lock.json"
        ).read_text(encoding="utf-8")

    def test_current_source_has_exact_reviewed_callable_contract(self):
        passes = validator.validate_source_contract(self.source)
        self.assertEqual(len(passes), 6)

    def test_current_apple_verifier_and_lock_are_release_bound(self):
        passes = validator.validate_app_store_verifier_contract(
            self.app_store_source,
            self.functions_lockfile,
        )
        self.assertEqual(len(passes), 6)
        self.assertRegex(passes[0], r"SHA-256: [0-9a-f]{64}$")
        self.assertRegex(passes[1], r"SHA-256: [0-9a-f]{64}$")

    def test_apple_product_allowlist_matches_the_client_storekit_contract(self):
        cases = (
            (
                'monthly: "com.noum.pro.monthly"',
                'monthly: "com.lookalike.pro.monthly"',
                "exact monthly StoreKit product",
            ),
            (
                'annual: "com.noum.pro.annual"',
                'annual: "com.lookalike.pro.annual"',
                "exact annual StoreKit product",
            ),
        )
        for old, new, expected in cases:
            with self.subTest(product=old):
                changed = self.app_store_source.replace(old, new, 1)
                self.assertNotEqual(changed, self.app_store_source)
                with self.assertRaisesRegex(validator.ContractError, expected):
                    validator.validate_app_store_verifier_contract(
                        changed,
                        self.functions_lockfile,
                    )

    def test_apple_online_and_nested_verification_fail_closed(self):
        cases = (
            (
                "configuration.rootCertificates,\n    true,",
                "configuration.rootCertificates,\n    false,",
                "online checks",
            ),
            (
                "verifier.verifyAndDecodeTransaction(",
                "verifier.decodeTransactionWithoutVerification(",
                "nested transaction JWS",
            ),
            (
                "configuration.appAppleID\n  );",
                "undefined\n  );",
                "exact app identity inputs",
            ),
        )
        for old, new, expected in cases:
            with self.subTest(old=old):
                changed = self.app_store_source.replace(old, new, 1)
                self.assertNotEqual(changed, self.app_store_source)
                with self.assertRaisesRegex(validator.ContractError, expected):
                    validator.validate_app_store_verifier_contract(
                        changed,
                        self.functions_lockfile,
                    )

    def test_apple_library_lock_version_and_integrity_fail_closed(self):
        package_lock = json.loads(self.functions_lockfile)
        locked = package_lock["packages"][
            "node_modules/@apple/app-store-server-library"
        ]
        locked["version"] = "3.2.0"
        changed = json.dumps(package_lock)
        with self.assertRaisesRegex(
            validator.ContractError,
            "library version must equal the reviewed value",
        ):
            validator.validate_app_store_verifier_contract(
                self.app_store_source,
                changed,
            )

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
        self.assertIn("--app-store-contract", probe)
        self.assertIn("--functions-lockfile", probe)
        self.assertIn("gcloud firestore fields ttls list", probe)
        self.assertIn("gcloud asset get-effective-iam-policy", probe)

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

    def test_additive_secure_coach_callable_is_required(self):
        changed = self.source.replace(
            "export const coachChatV2 = onCall(",
            "const coachChatV2 = onCall(",
            1,
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "Missing callable exports: coachChatV2",
        ):
            validator.validate_source_contract(changed)
        self.assertEqual(
            validator.EXPECTED_CALLABLES["coachChatV2"],
            "COACH_RUNTIME_SERVICE_ACCOUNT",
        )

    def test_growth_aggregate_is_required_with_a_dedicated_identity(self):
        self.assertEqual(
            validator.RUNTIME_IDENTITIES["GROWTH_RUNTIME_SERVICE_ACCOUNT"],
            "noum-growth-runtime",
        )
        self.assertEqual(
            validator.EXPECTED_CALLABLES["recordGrowthAggregate"],
            "GROWTH_RUNTIME_SERVICE_ACCOUNT",
        )
        changed = self.source.replace(
            "export const recordGrowthAggregate = onCall(",
            "const recordGrowthAggregate = onCall(",
            1,
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "Missing callable exports: recordGrowthAggregate",
        ):
            validator.validate_source_contract(changed)

    def test_growth_aggregate_security_boundary_fails_closed(self):
        cases = (
            (
                "enforceAppCheck: true",
                "enforceAppCheck: false",
                "recordGrowthAggregate must enforce App Check",
            ),
            (
                "serviceAccount: GROWTH_RUNTIME_SERVICE_ACCOUNT,",
                "serviceAccount: ACCOUNT_RUNTIME_SERVICE_ACCOUNT,",
                "recordGrowthAggregate must use GROWTH_RUNTIME_SERVICE_ACCOUNT",
            ),
            (
                "assertTrustedCaller(request.auth, request.app);",
                "",
                (
                    "recordGrowthAggregate must call the shared "
                    "trusted-caller boundary"
                ),
            ),
        )
        for old, new, expected in cases:
            with self.subTest(old=old):
                changed = replace_in_callable(
                    self.source,
                    "recordGrowthAggregate",
                    old,
                    new,
                )
                with self.assertRaisesRegex(
                    validator.ContractError,
                    expected,
                ):
                    validator.validate_source_contract(changed)

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

    def test_missing_scheduled_reconciler_fails_closed(self):
        changed = self.source.replace(
            "export const reconcileAccountDeletionTombstones = onSchedule(",
            "const reconcileAccountDeletionTombstones = onSchedule(",
            1,
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "Missing scheduled exports: reconcileAccountDeletionTombstones",
        ):
            validator.validate_source_contract(changed)

    def test_scheduled_reconciler_contract_fails_closed(self):
        for old, new, expected in (
            (
                'schedule: "every 15 minutes",',
                'schedule: "every 30 minutes",',
                "must retain the reviewed 15-minute schedule",
            ),
            (
                "serviceAccount: ACCOUNT_RUNTIME_SERVICE_ACCOUNT,",
                "serviceAccount: SOCIAL_RUNTIME_SERVICE_ACCOUNT,",
                "must use ACCOUNT_RUNTIME_SERVICE_ACCOUNT",
            ),
        ):
            with self.subTest(old=old):
                changed = self.source.replace(old, new, 1)
                with self.assertRaisesRegex(
                    validator.ContractError,
                    expected,
                ):
                    validator.validate_source_contract(changed)

    def test_app_store_http_receivers_are_exact_and_verified(self):
        self.assertEqual(
            validator.RUNTIME_IDENTITIES[
                "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT"
            ],
            "noum-appstore-notifications-runtime",
        )
        self.assertEqual(
            set(validator.EXPECTED_HTTP_FUNCTIONS),
            {
                "appStoreServerNotificationsV2",
                "appStoreServerNotificationsV2Sandbox",
            },
        )
        changed = self.source.replace(
            "export const appStoreServerNotificationsV2 = onRequest(",
            "const appStoreServerNotificationsV2 = onRequest(",
            1,
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "Missing public HTTP exports: appStoreServerNotificationsV2",
        ):
            validator.validate_source_contract(changed)

        for old, new, expected in (
            (
                'invoker: "public",',
                'invoker: "private",',
                "must retain Apple's public HTTPS admission",
            ),
            (
                "serviceAccount: APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT,",
                "serviceAccount: GROWTH_RUNTIME_SERVICE_ACCOUNT,",
                "must use APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT",
            ),
            (
                "secrets: [appStoreRootCertificates],",
                "secrets: [],",
                "must mount only the reviewed Apple root secret",
            ),
        ):
            with self.subTest(old=old):
                changed = self.source.replace(old, new, 1)
                with self.assertRaisesRegex(
                    validator.ContractError,
                    expected,
                ):
                    validator.validate_source_contract(changed)


class SnapshotContractTests(unittest.TestCase):
    def validate(self, snapshot, *, phase="pre-enable"):
        return validator.validate_cloud_snapshot(
            functions=snapshot["functions"],
            project_policy=snapshot["project_policy"],
            secret_policy=snapshot["secret_policy"],
            app_store_secret_policy=snapshot["app_store_secret_policy"],
            app_store_effective_policy=snapshot["app_store_effective_policy"],
            ttl_policies=snapshot["ttl_policies"],
            project=validator.PRODUCTION_PROJECT,
            region=validator.PRODUCTION_REGION,
            project_number="123456789",
            app_store_app_apple_id=TEST_APP_APPLE_ID,
            app_store_notification_phase=phase,
        )

    def test_complete_snapshot_passes(self):
        passes = self.validate(complete_snapshot())
        self.assertEqual(len(passes), 9)

    def test_missing_function_fails(self):
        snapshot = complete_snapshot()
        snapshot["functions"] = [
            item
            for item in snapshot["functions"]
            if not item["name"].endswith(
                "/functions/reconcileAccountDeletionTombstones"
            )
        ]
        with self.assertRaisesRegex(
            validator.ContractError,
            "Missing deployed functions: reconcileAccountDeletionTombstones",
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
            "Unexpected deployed functions: legacyCredentialVendor",
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

    def test_growth_runtime_identity_is_exact_in_snapshot(self):
        snapshot = complete_snapshot()
        growth = next(
            item
            for item in snapshot["functions"]
            if item["name"].endswith("/functions/recordGrowthAggregate")
        )
        growth["serviceConfig"]["serviceAccountEmail"] = (
            validator.runtime_email("ACCOUNT_RUNTIME_SERVICE_ACCOUNT")
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "recordGrowthAggregate uses noum-account-runtime",
        ):
            self.validate(snapshot)

    def test_app_store_runtime_identity_is_exact_in_snapshot(self):
        snapshot = complete_snapshot()
        endpoint = next(
            item
            for item in snapshot["functions"]
            if item["name"].endswith(
                "/functions/appStoreServerNotificationsV2"
            )
        )
        endpoint["serviceConfig"]["serviceAccountEmail"] = (
            validator.runtime_email("GROWTH_RUNTIME_SERVICE_ACCOUNT")
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "appStoreServerNotificationsV2 uses noum-growth-runtime",
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
                            "GROWTH_RUNTIME_SERVICE_ACCOUNT"
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
                    "GROWTH_RUNTIME_SERVICE_ACCOUNT"
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
            + validator.runtime_email("GROWTH_RUNTIME_SERVICE_ACCOUNT")
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "Deepgram secret must be readable only by the transcription runtime",
        ):
            self.validate(snapshot)

    def test_app_store_root_secret_remains_exclusive(self):
        snapshot = complete_snapshot()
        snapshot["app_store_secret_policy"]["bindings"][0]["members"].append(
            "serviceAccount:"
            + validator.runtime_email("GROWTH_RUNTIME_SERVICE_ACCOUNT")
        )
        with self.assertRaisesRegex(
            validator.ContractError,
            "Apple root secret must be readable only by the App Store",
        ):
            self.validate(snapshot)

    def test_app_store_runtime_project_roles_are_an_exact_allowlist(self):
        snapshot = complete_snapshot()
        snapshot["project_policy"]["bindings"] = [
            binding
            for binding in snapshot["project_policy"]["bindings"]
            if binding["role"] != "roles/datastore.user"
        ]
        with self.assertRaisesRegex(
            validator.ContractError,
            "project roles must equal roles/datastore.user exactly",
        ):
            self.validate(snapshot)

        snapshot = complete_snapshot()
        snapshot["project_policy"]["bindings"].append({
            "role": "roles/firebaseauth.admin",
            "members": [
                "serviceAccount:"
                + validator.runtime_email(
                    "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT"
                )
            ],
        })
        with self.assertRaisesRegex(
            validator.ContractError,
            "project roles must equal roles/datastore.user exactly",
        ):
            self.validate(snapshot)

    def test_project_and_inherited_secret_roles_fail_closed(self):
        snapshot = complete_snapshot()
        snapshot["project_policy"]["bindings"].append({
            "role": "roles/secretmanager.secretAccessor",
            "members": ["user:project-reader@example.com"],
        })
        with self.assertRaisesRegex(
            validator.ContractError,
            "Project-level secret data role",
        ):
            self.validate(snapshot)

        snapshot = complete_snapshot()
        snapshot["app_store_effective_policy"]["policyResults"][0][
            "policies"
        ].append({
            "attachedResource": "//cloudresourcemanager.googleapis.com/folders/42",
            "policy": {"bindings": [{
                "role": "roles/secretmanager.admin",
                "members": ["group:inherited-admins@example.com"],
            }]},
        })
        with self.assertRaisesRegex(
            validator.ContractError,
            "Inherited secret data role roles/secretmanager.admin",
        ):
            self.validate(snapshot)

    def test_non_accessor_secret_local_role_fails_closed(self):
        snapshot = complete_snapshot()
        snapshot["app_store_secret_policy"]["bindings"].append({
            "role": "roles/secretmanager.admin",
            "members": ["user:secret-admin@example.com"],
        })
        with self.assertRaisesRegex(
            validator.ContractError,
            "may contain only the reviewed secretAccessor binding",
        ):
            self.validate(snapshot)

    def test_marker_ttl_must_be_present_and_active(self):
        for ttl_policies in ([], [{
            "name": complete_snapshot()["ttl_policies"][0]["name"],
            "ttlConfig": {"state": "CREATING"},
        }]):
            with self.subTest(ttl_policies=ttl_policies):
                snapshot = complete_snapshot()
                snapshot["ttl_policies"] = ttl_policies
                with self.assertRaisesRegex(
                    validator.ContractError,
                    "expiresAt TTL must exist exactly once and be ACTIVE",
                ):
                    self.validate(snapshot)

    def test_app_store_parameter_and_secret_readback_fail_closed(self):
        mutations = (
            (
                "environmentVariables",
                "APP_STORE_APP_APPLE_ID",
                "987654321",
                "exact App Apple ID readback",
            ),
            (
                "environmentVariables",
                "APP_STORE_PRODUCTION_NOTIFICATIONS_ENABLED",
                "true",
                "is not pre-enable",
            ),
            (
                "secretEnvironmentVariables",
                0,
                {"key": "WRONG", "secret": "WRONG"},
                "exact Apple root secret readback",
            ),
        )
        for container, key, value, expected in mutations:
            with self.subTest(container=container, key=key):
                snapshot = complete_snapshot()
                endpoint = next(
                    item for item in snapshot["functions"]
                    if item["name"].endswith(
                        "/functions/appStoreServerNotificationsV2"
                    )
                )
                endpoint["serviceConfig"][container][key] = value
                with self.assertRaisesRegex(validator.ContractError, expected):
                    self.validate(snapshot)

    def test_reviewed_enable_phases_require_exact_readback(self):
        sandbox = complete_snapshot()
        sandbox_endpoint = next(
            item for item in sandbox["functions"]
            if item["name"].endswith(
                "/functions/appStoreServerNotificationsV2Sandbox"
            )
        )
        sandbox_endpoint["serviceConfig"]["environmentVariables"][
            "APP_STORE_SANDBOX_NOTIFICATIONS_ENABLED"
        ] = "true"
        self.validate(sandbox, phase="sandbox-enabled")

        production = complete_snapshot()
        for item in production["functions"]:
            environment = item["serviceConfig"].get("environmentVariables", {})
            for key in (
                "APP_STORE_PRODUCTION_NOTIFICATIONS_ENABLED",
                "APP_STORE_SANDBOX_NOTIFICATIONS_ENABLED",
            ):
                if key in environment:
                    environment[key] = "true"
        self.validate(production, phase="production-enabled")


if __name__ == "__main__":
    unittest.main()
