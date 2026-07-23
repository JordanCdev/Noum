import copy
import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "reconcile_app_store_commercial.py"
TEMPLATE = ROOT / "AppStore" / "commercial-reconciliation.template.json"
SPEC = importlib.util.spec_from_file_location("reconcile_app_store_commercial", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class CommercialReconciliationTests(unittest.TestCase):
    start = "2026-01-01"
    end = "2026-01-08"
    dates = [f"2026-01-{day:02d}" for day in range(1, 8)]

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.first_party_path = self.root / "first-party-growth.json"
        self.lifecycle_path = self.root / "asc-lifecycle.csv"
        self.manifest_path = self.root / "reconciliation.json"
        self.write_first_party()
        self.write_lifecycle()
        self.manifest = self.make_manifest()
        self.write_manifest()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def first_party_payload(self, *, currency: str = "USD") -> dict:
        lifecycle_days = []
        ai_cost_days = []
        for index, day in enumerate(self.dates):
            value = index + 1
            lifecycle_days.append({
                "dateUTC": day,
                "eventCounts": {
                    "growth.subscription.trialStarted": value,
                    "growth.subscription.entitlementRenewed": value + 1,
                    "growth.subscription.billingFailed": value + 2,
                    "growth.subscription.purchaseRefunded": value + 3,
                    "growth.subscription.entitlementExpired": value + 4,
                },
            })
            ai_cost_days.append({
                "dateUTC": day,
                "estimatedAICostMicros": 1_001,
                "estimatedAICostCurrency": currency,
                "unpricedAIUsageCount": 0,
            })
        return {
            "schemaVersion": MODULE.FIRST_PARTY_PAYLOAD_SCHEMA_VERSION,
            "lifecycle": {
                "source": MODULE.FIRST_PARTY_LIFECYCLE_SOURCE,
                "environment": MODULE.FIRST_PARTY_LIFECYCLE_ENVIRONMENT,
                "days": lifecycle_days,
            },
            "aiCost": {
                "source": MODULE.FIRST_PARTY_AI_COST_SOURCE,
                "days": ai_cost_days,
            },
        }

    def write_first_party(self, payload: dict | None = None) -> None:
        self.first_party_path.write_text(
            json.dumps(payload or self.first_party_payload()),
            encoding="utf-8",
        )

    def lifecycle_rows(self) -> list[str]:
        rows = [",".join(MODULE.ASC_LIFECYCLE_HEADER)]
        for index, day in enumerate(self.dates):
            value = index + 1
            rows.append(
                ",".join(str(item) for item in (
                    day,
                    value,
                    value + 1,
                    value + 2,
                    value + 3,
                    value + 4,
                ))
            )
        return rows

    def write_lifecycle(self, rows: list[str] | None = None) -> None:
        self.lifecycle_path.write_text(
            "\n".join(rows or self.lifecycle_rows()) + "\n",
            encoding="utf-8",
        )

    def make_manifest(self) -> dict:
        return {
            "schemaVersion": 1,
            "templateStatus": "COLLECTED_REAL_EXPORTS",
            "releaseBinding": {
                "sourceGitCommit": "a" * 40,
                "appVersion": "1.1",
                "buildScope": "all-app-versions-and-builds",
            },
            "comparison": {
                "periodStartDate": self.start,
                "periodEndDateExclusive": self.end,
                "asOfDate": "2026-01-09",
                "cohortKind": "calendar-event",
                "firstPartyTimeZone": "UTC",
                "appStoreConnectTimeZone": "America/Los_Angeles",
                "storefrontScope": "all-storefronts",
                "subscriptionScope": "all-noum-subscriptions",
                "metrics": list(MODULE.LIFECYCLE_METRICS),
            },
            "sources": {
                "firstParty": {
                    "schema": MODULE.FIRST_PARTY_SCHEMA,
                    "path": self.first_party_path.name,
                    "sha256": digest(self.first_party_path),
                    "rawExportSha256": "c" * 64,
                },
                "appStoreConnectLifecycle": {
                    "schema": "asc-subscription-events-normalized-v1",
                    "reportKind": "subscription-event-report-1_3",
                    "path": self.lifecycle_path.name,
                    "sha256": digest(self.lifecycle_path),
                    "rawExportSha256": "d" * 64,
                },
                "appStoreConnectProceeds": None,
                "currencyConversion": None,
            },
        }

    def refresh_hashes(self) -> None:
        self.manifest["sources"]["firstParty"]["sha256"] = digest(self.first_party_path)
        self.manifest["sources"]["appStoreConnectLifecycle"]["sha256"] = digest(self.lifecycle_path)
        proceeds = self.manifest["sources"]["appStoreConnectProceeds"]
        if proceeds is not None:
            proceeds["sha256"] = digest(self.root / proceeds["path"])
        conversion = self.manifest["sources"]["currencyConversion"]
        if conversion is not None:
            conversion["sha256"] = digest(self.root / conversion["path"])

    def write_manifest(self) -> None:
        self.refresh_hashes()
        self.manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")

    def add_proceeds(self, *, currency: str = "USD", per_day: int = 1_000_000) -> Path:
        path = self.root / "asc-proceeds.csv"
        rows = [",".join(MODULE.ASC_PROCEEDS_HEADER)]
        rows.extend(f"{day},{per_day},{currency}" for day in self.dates)
        path.write_text("\n".join(rows) + "\n", encoding="utf-8")
        self.manifest["sources"]["appStoreConnectProceeds"] = {
            "schema": "asc-proceeds-normalized-v1",
            "reportKind": "sales-and-trends-estimated-proceeds",
            "path": path.name,
            "sha256": digest(path),
            "rawExportSha256": "e" * 64,
        }
        return path

    def add_conversion(
        self,
        *,
        from_currency: str = "USD",
        to_currency: str = "GBP",
        numerator: int = 79,
        denominator: int = 100,
    ) -> Path:
        path = self.root / "currency-conversion.json"
        path.write_text(json.dumps({
            "schemaVersion": 1,
            "fromCurrency": from_currency,
            "toCurrency": to_currency,
            "rateNumerator": numerator,
            "rateDenominator": denominator,
            "effectiveDate": "2026-01-04",
            "sourceEvidenceSha256": "b" * 64,
        }), encoding="utf-8")
        self.manifest["sources"]["currencyConversion"] = {
            "schema": "currency-conversion-v1",
            "path": path.name,
            "sha256": digest(path),
        }
        return path

    def test_exact_counts_remain_observational_and_no_conversion_is_computed(self) -> None:
        result = MODULE.reconcile(self.manifest_path)
        self.assertEqual(result["status"], "COUNTS_MATCH_WITH_TIMEZONE_CAUTION")
        self.assertFalse(result["comparisonBoundary"]["exactTimestampAlignment"])
        self.assertFalse(result["authority"]["conversionCohortsComputed"])
        self.assertTrue(all(row["difference"] == 0 for row in result["lifecycleComparisons"]))
        self.assertEqual(result["financialObservation"]["status"], "not-provided")
        self.assertEqual(result["commercialReadiness"], "BLOCKED_MISSING_PROCEEDS")

    def test_discrepancy_is_visible_without_paths_or_identifiers(self) -> None:
        self.lifecycle_path.rename(self.root / "sensitive-product-identifier.csv")
        self.lifecycle_path = self.root / "sensitive-product-identifier.csv"
        rows = self.lifecycle_rows()
        fields = rows[1].split(",")
        fields[1] = "99"
        rows[1] = ",".join(fields)
        self.write_lifecycle(rows)
        self.manifest = self.make_manifest()
        self.write_manifest()

        result = MODULE.reconcile(self.manifest_path)
        encoded = json.dumps(result, sort_keys=True)
        self.assertEqual(result["status"], "DISCREPANCY_REVIEW_REQUIRED")
        self.assertNotIn("sensitive-product-identifier", encoded)
        self.assertNotIn("subscriberID", encoded)
        self.assertNotIn("productID", encoded)
        self.assertNotIn(str(self.root), encoded)

    def test_source_hash_mismatch_is_refused(self) -> None:
        self.manifest["sources"]["firstParty"]["sha256"] = "0" * 64
        self.manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        with self.assertRaisesRegex(MODULE.ContractError, "SHA-256 does not match"):
            MODULE.reconcile(self.manifest_path)

    def test_raw_export_binding_and_report_kind_are_required(self) -> None:
        del self.manifest["sources"]["appStoreConnectLifecycle"]["rawExportSha256"]
        self.manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        with self.assertRaisesRegex(MODULE.ContractError, "aggregate-only schema"):
            MODULE.reconcile(self.manifest_path)

        self.manifest = self.make_manifest()
        self.manifest["sources"]["appStoreConnectLifecycle"]["reportKind"] = "sales-and-trends-estimated-proceeds"
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "report kind is unsupported"):
            MODULE.reconcile(self.manifest_path)

    def test_install_or_trial_cohort_math_is_refused(self) -> None:
        self.manifest["comparison"]["cohortKind"] = "trial-start-cohort"
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "conversion cohorts remain App Store Connect-only"):
            MODULE.reconcile(self.manifest_path)

    def test_timezone_relabeling_is_refused(self) -> None:
        self.manifest["comparison"]["appStoreConnectTimeZone"] = "UTC"
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "Pacific Time"):
            MODULE.reconcile(self.manifest_path)

    def test_missing_or_duplicate_dates_are_refused(self) -> None:
        payload = self.first_party_payload()
        payload["lifecycle"]["days"].pop()
        self.write_first_party(payload)
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "one explicit row for every date"):
            MODULE.reconcile(self.manifest_path)

        self.write_first_party()
        rows = self.lifecycle_rows()
        rows[-1] = rows[-2]
        self.write_lifecycle(rows)
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "duplicate date"):
            MODULE.reconcile(self.manifest_path)

    def test_identifier_column_in_apple_extract_is_refused(self) -> None:
        rows = self.lifecycle_rows()
        rows[0] += ",subscription_id"
        rows[1:] = [row + ",do-not-retain" for row in rows[1:]]
        self.write_lifecycle(rows)
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "identifier-free normalized contract"):
            MODULE.reconcile(self.manifest_path)

        rows = self.lifecycle_rows()
        rows[1] += ",unheaded-identifier"
        self.write_lifecycle(rows)
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "identifier-free normalized contract"):
            MODULE.reconcile(self.manifest_path)

    def test_identifier_key_in_first_party_extract_is_refused(self) -> None:
        payload = self.first_party_payload()
        payload["lifecycle"]["days"][0]["accountID"] = "do-not-retain"
        self.write_first_party(payload)
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "aggregate-only schema"):
            MODULE.reconcile(self.manifest_path)

    def test_legacy_combined_first_party_contract_is_refused(self) -> None:
        current = self.first_party_payload()
        legacy_days = []
        for lifecycle_day, ai_cost_day in zip(
            current["lifecycle"]["days"],
            current["aiCost"]["days"],
        ):
            legacy_days.append({**lifecycle_day, **ai_cost_day})
        self.write_first_party({"schemaVersion": 1, "days": legacy_days})
        self.write_manifest()

        with self.assertRaisesRegex(MODULE.ContractError, "aggregate-only schema"):
            MODULE.reconcile(self.manifest_path)

    def test_lifecycle_projection_requires_production_assn_v2(self) -> None:
        payload = self.first_party_payload()
        payload["lifecycle"]["source"] = MODULE.FIRST_PARTY_AI_COST_SOURCE
        self.write_first_party(payload)
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "Server Notifications V2"):
            MODULE.reconcile(self.manifest_path)

        payload = self.first_party_payload()
        payload["lifecycle"]["environment"] = "sandbox"
        self.write_first_party(payload)
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "production notifications only"):
            MODULE.reconcile(self.manifest_path)

    def test_ai_cost_projection_requires_consented_client_aggregates(self) -> None:
        payload = self.first_party_payload()
        payload["aiCost"]["source"] = MODULE.FIRST_PARTY_LIFECYCLE_SOURCE
        self.write_first_party(payload)
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "consented client aggregates"):
            MODULE.reconcile(self.manifest_path)

    def test_open_window_and_future_evidence_are_refused(self) -> None:
        self.manifest["comparison"]["asOfDate"] = "2026-01-07"
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "not closed"):
            MODULE.reconcile(self.manifest_path)

        self.manifest["comparison"]["asOfDate"] = "2099-01-01"
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "future"):
            MODULE.reconcile(self.manifest_path)

    def test_mixed_or_unconverted_currency_is_refused(self) -> None:
        self.add_proceeds(currency="GBP")
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "hashed conversion receipt"):
            MODULE.reconcile(self.manifest_path)

        proceeds = self.root / "asc-proceeds.csv"
        rows = proceeds.read_text(encoding="utf-8").splitlines()
        rows[-1] = rows[-1].removesuffix("GBP") + "EUR"
        proceeds.write_text("\n".join(rows) + "\n", encoding="utf-8")
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "cannot mix currencies"):
            MODULE.reconcile(self.manifest_path)

    def test_hashed_currency_conversion_is_applied_with_explicit_rounding(self) -> None:
        self.add_proceeds(currency="GBP", per_day=2_000_000)
        self.add_conversion(numerator=79, denominator=100)
        self.write_manifest()

        result = MODULE.reconcile(self.manifest_path)
        financial = result["financialObservation"]
        expected_cost = MODULE.convert_micros(7 * 1_001, 79, 100)
        self.assertEqual(financial["status"], "comparable-with-hashed-conversion")
        self.assertEqual(result["commercialReadiness"], "CONTRIBUTION_MARGIN_EVALUABLE")
        self.assertEqual(financial["aiCostInProceedsCurrencyMicros"], expected_cost)
        self.assertEqual(financial["currencyConversion"]["rounding"], "half-up-to-micros")
        self.assertIn("currencyConversionSha256", result["sourceBindings"])

    def test_unpriced_ai_usage_blocks_margin_without_erasing_known_cost(self) -> None:
        payload = self.first_party_payload()
        payload["aiCost"]["days"][2]["unpricedAIUsageCount"] = 1
        self.write_first_party(payload)
        self.add_proceeds(currency="USD", per_day=2_000_000)
        self.write_manifest()

        result = MODULE.reconcile(self.manifest_path)
        financial = result["financialObservation"]
        self.assertEqual(result["commercialReadiness"], "BLOCKED_UNPRICED_AI_USAGE")
        self.assertEqual(financial["status"], "blocked-unpriced-ai-usage")
        self.assertEqual(financial["estimatedAICostMicros"], 7 * 1_001)
        self.assertEqual(financial["aiCostInProceedsCurrencyMicros"], 7 * 1_001)
        self.assertEqual(financial["unpricedAIUsageCount"], 1)
        self.assertIsNone(financial["residualAfterAICostMicros"])
        self.assertIsNone(financial["residualAfterAICostBasisPoints"])

    def test_missing_or_unbounded_unpriced_ai_usage_is_refused(self) -> None:
        payload = self.first_party_payload()
        del payload["aiCost"]["days"][0]["unpricedAIUsageCount"]
        self.write_first_party(payload)
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "aggregate-only schema"):
            MODULE.reconcile(self.manifest_path)

        payload = self.first_party_payload()
        payload["aiCost"]["days"][0]["unpricedAIUsageCount"] = MODULE.MAXIMUM_COUNT + 1
        self.write_first_party(payload)
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "bounded non-negative integer"):
            MODULE.reconcile(self.manifest_path)

    def test_negative_daily_proceeds_are_supported_without_hiding_currency(self) -> None:
        proceeds = self.add_proceeds(currency="USD", per_day=1_000_000)
        rows = proceeds.read_text(encoding="utf-8").splitlines()
        rows[1] = f"{self.dates[0]},-500000,USD"
        proceeds.write_text("\n".join(rows) + "\n", encoding="utf-8")
        self.write_manifest()

        result = MODULE.reconcile(self.manifest_path)
        financial = result["financialObservation"]
        self.assertEqual(financial["developerProceedsMicros"], 5_500_000)
        self.assertEqual(financial["developerProceedsCurrency"], "USD")

    def test_same_currency_rejects_unnecessary_conversion(self) -> None:
        self.add_proceeds(currency="USD")
        self.add_conversion(from_currency="USD", to_currency="USD")
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "must not be supplied"):
            MODULE.reconcile(self.manifest_path)

    def test_template_and_partial_windows_cannot_claim_evidence(self) -> None:
        checked_in = json.loads(TEMPLATE.read_text(encoding="utf-8"))
        self.assertEqual(checked_in["templateStatus"], "AWAITING_REAL_EXPORTS")
        self.assertEqual(checked_in["comparison"]["metrics"], list(MODULE.LIFECYCLE_METRICS))
        self.assertEqual(checked_in["releaseBinding"]["buildScope"], MODULE.BUILD_SCOPE)
        self.assertEqual(
            checked_in["sources"]["firstParty"]["schema"],
            MODULE.FIRST_PARTY_SCHEMA,
        )

        self.manifest["templateStatus"] = "AWAITING_REAL_EXPORTS"
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "templates are not evidence"):
            MODULE.reconcile(self.manifest_path)

        self.manifest["templateStatus"] = "COLLECTED_REAL_EXPORTS"
        self.manifest["comparison"]["periodEndDateExclusive"] = "2026-01-05"
        self.write_manifest()
        with self.assertRaisesRegex(MODULE.ContractError, "7 to 35"):
            MODULE.reconcile(self.manifest_path)

    def test_cli_writes_deterministic_content_free_result(self) -> None:
        first = self.root / "result-one.json"
        second = self.root / "result-two.json"
        self.assertEqual(MODULE.main(["--manifest", str(self.manifest_path), "--output", str(first)]), 0)
        self.assertEqual(MODULE.main(["--manifest", str(self.manifest_path), "--output", str(second)]), 0)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        payload = json.loads(first.read_text(encoding="utf-8"))
        self.assertEqual(payload["sourceBindings"]["firstPartyAggregateSha256"], digest(self.first_party_path))
        self.assertEqual(payload["sourceBindings"]["firstPartyRawExportSha256"], "c" * 64)


if __name__ == "__main__":
    unittest.main()
