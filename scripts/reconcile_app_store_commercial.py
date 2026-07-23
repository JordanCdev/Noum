#!/usr/bin/env python3
"""Reconcile Noum's anonymous lifecycle totals with App Store Connect.

The command consumes *normalized, aggregate-only* evidence files.  It never
accepts subscriber, account, device, installation, or product identifiers and
never writes source paths to its result.  App Store Connect remains the
authority; Noum's counters are an observational coverage signal.

Usage:
    python3 scripts/reconcile_app_store_commercial.py \
        --manifest /secure/noum-commercial/reconciliation.json \
        --output /secure/noum-commercial/reconciliation-result.json

The checked-in contract and normalization rules live in
``AppStore/commercial-reconciliation.md``.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from datetime import date, timedelta, timezone, datetime
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any, Iterable


SCHEMA_VERSION = 1
MANIFEST_STATUS = "COLLECTED_REAL_EXPORTS"
FIRST_PARTY_PAYLOAD_SCHEMA_VERSION = 2
FIRST_PARTY_SCHEMA = "noum-growth-daily-v2"
FIRST_PARTY_LIFECYCLE_SOURCE = "appStoreServerNotificationsV2"
FIRST_PARTY_LIFECYCLE_ENVIRONMENT = "production"
FIRST_PARTY_AI_COST_SOURCE = "consented-client-growth-aggregates-v2"
ASC_LIFECYCLE_SCHEMA = "asc-subscription-events-normalized-v1"
ASC_PROCEEDS_SCHEMA = "asc-proceeds-normalized-v1"
FX_SCHEMA = "currency-conversion-v1"
FIRST_PARTY_TIME_ZONE = "UTC"
ASC_TIME_ZONE = "America/Los_Angeles"
COHORT_KIND = "calendar-event"
STOREFRONT_SCOPE = "all-storefronts"
SUBSCRIPTION_SCOPE = "all-noum-subscriptions"
BUILD_SCOPE = "all-app-versions-and-builds"
MINIMUM_WINDOW_DAYS = 7
MAXIMUM_WINDOW_DAYS = 35
MAXIMUM_COUNT = 10_000_000
MAXIMUM_MONEY_MICROS = 10_000_000_000_000
MAXIMUM_SOURCE_BYTES = 2 * 1024 * 1024

LIFECYCLE_METRICS = (
    "trial_started",
    "renewal",
    "billing_failure",
    "refund",
    "expiry",
)

FIRST_PARTY_EVENT_KEYS = {
    "trial_started": "growth.subscription.trialStarted",
    "renewal": "growth.subscription.entitlementRenewed",
    "billing_failure": "growth.subscription.billingFailed",
    "refund": "growth.subscription.purchaseRefunded",
    "expiry": "growth.subscription.entitlementExpired",
}

ASC_LIFECYCLE_HEADER = ("event_date_pt", *LIFECYCLE_METRICS)
ASC_PROCEEDS_HEADER = (
    "event_date_pt",
    "developer_proceeds_micros",
    "currency",
)

SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
GIT_COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){1,2}$")
CURRENCY_PATTERN = re.compile(r"^[A-Z]{3}$")


class ContractError(ValueError):
    """A safe, non-content-bearing input-contract failure."""


@dataclass(frozen=True)
class BoundSource:
    schema: str
    path: Path
    sha256: str
    raw_export_sha256: str | None = None
    report_kind: str | None = None


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def require_exact_keys(value: dict[str, Any], expected: set[str], context: str) -> None:
    require(
        set(value) == expected,
        f"{context} does not match the aggregate-only schema",
    )


def parse_json_object(path: Path, context: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ContractError(f"{context} is not a readable JSON object") from error
    require(isinstance(value, dict), f"{context} must be a JSON object")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_source(manifest_path: Path, value: Any, expected_schema: str, context: str) -> BoundSource:
    require(isinstance(value, dict), f"{context} source is required")
    allowed = {"schema", "path", "sha256"}
    if expected_schema != FX_SCHEMA:
        allowed.add("rawExportSha256")
    if expected_schema in {ASC_LIFECYCLE_SCHEMA, ASC_PROCEEDS_SCHEMA}:
        allowed.add("reportKind")
    require_exact_keys(value, allowed, context)
    require(value.get("schema") == expected_schema, f"{context} schema is unsupported")
    raw_path = value.get("path")
    require(isinstance(raw_path, str) and raw_path.strip(), f"{context} path is required")
    relative = Path(raw_path)
    require(not relative.is_absolute() and ".." not in relative.parts, f"{context} path must stay inside the evidence directory")
    base = manifest_path.resolve().parent
    cursor = base
    for part in relative.parts:
        cursor /= part
        require(not cursor.is_symlink(), f"{context} source cannot traverse a symlink")
    path = (base / relative).resolve()
    require(path.is_file() and not path.is_symlink(), f"{context} source is missing")
    require(base == path.parent or base in path.parents, f"{context} source resolves outside the evidence directory")
    require(0 < path.stat().st_size <= MAXIMUM_SOURCE_BYTES, f"{context} source exceeds the bounded evidence-file size")
    expected_hash = value.get("sha256")
    require(isinstance(expected_hash, str) and SHA256_PATTERN.fullmatch(expected_hash) is not None, f"{context} SHA-256 is invalid")
    require(sha256_file(path) == expected_hash, f"{context} SHA-256 does not match")
    raw_export_hash = value.get("rawExportSha256")
    if expected_schema != FX_SCHEMA:
        require(
            isinstance(raw_export_hash, str)
            and SHA256_PATTERN.fullmatch(raw_export_hash) is not None,
            f"{context} raw-export SHA-256 is invalid",
        )
    report_kind = value.get("reportKind")
    if "reportKind" in allowed:
        expected_report_kinds = {
            ASC_LIFECYCLE_SCHEMA: {"subscription-event-report-1_3"},
            ASC_PROCEEDS_SCHEMA: {
                "sales-and-trends-estimated-proceeds",
            },
        }[expected_schema]
        require(report_kind in expected_report_kinds, f"{context} report kind is unsupported")
    return BoundSource(expected_schema, path, expected_hash, raw_export_hash, report_kind)


def resolve_optional_source(
    manifest_path: Path,
    value: Any,
    expected_schema: str,
    context: str,
) -> BoundSource | None:
    if value is None:
        return None
    return resolve_source(manifest_path, value, expected_schema, context)


def parse_date(value: Any, context: str) -> date:
    require(isinstance(value, str), f"{context} must be YYYY-MM-DD")
    try:
        parsed = date.fromisoformat(value)
    except ValueError as error:
        raise ContractError(f"{context} must be YYYY-MM-DD") from error
    require(parsed.isoformat() == value, f"{context} must use canonical YYYY-MM-DD")
    return parsed


def parse_nonnegative_int(value: Any, context: str, maximum: int = MAXIMUM_COUNT) -> int:
    require(type(value) is int and 0 <= value <= maximum, f"{context} must be a bounded non-negative integer")
    return value


def parse_csv_int(value: str | None, context: str, maximum: int = MAXIMUM_COUNT) -> int:
    require(isinstance(value, str) and re.fullmatch(r"0|[1-9][0-9]*", value) is not None, f"{context} must be a canonical non-negative integer")
    parsed = int(value)
    require(parsed <= maximum, f"{context} exceeds the aggregate ceiling")
    return parsed


def parse_csv_signed_int(value: str | None, context: str, maximum: int) -> int:
    require(
        isinstance(value, str)
        and re.fullmatch(r"0|-?[1-9][0-9]*", value) is not None,
        f"{context} must be a canonical signed integer",
    )
    parsed = int(value)
    require(abs(parsed) <= maximum, f"{context} exceeds the aggregate ceiling")
    return parsed


def expected_dates(start: date, end: date) -> list[date]:
    return [start + timedelta(days=offset) for offset in range((end - start).days)]


def validate_exact_daily_coverage(actual: Iterable[date], expected: list[date], context: str) -> None:
    received = list(actual)
    require(len(received) == len(set(received)), f"{context} contains a duplicate date")
    require(sorted(received) == expected, f"{context} must contain one explicit row for every date in the comparison window")


def parse_manifest(manifest_path: Path) -> tuple[dict[str, Any], BoundSource, BoundSource, BoundSource | None, BoundSource | None]:
    manifest = parse_json_object(manifest_path, "reconciliation manifest")
    require_exact_keys(
        manifest,
        {"schemaVersion", "templateStatus", "releaseBinding", "comparison", "sources"},
        "reconciliation manifest",
    )
    require(manifest.get("schemaVersion") == SCHEMA_VERSION, "reconciliation manifest schema version is unsupported")
    require(manifest.get("templateStatus") == MANIFEST_STATUS, "checked-in or incomplete reconciliation templates are not evidence")

    binding = manifest.get("releaseBinding")
    require(isinstance(binding, dict), "release binding is required")
    require_exact_keys(binding, {"sourceGitCommit", "appVersion", "buildScope"}, "release binding")
    require(isinstance(binding.get("sourceGitCommit"), str) and GIT_COMMIT_PATTERN.fullmatch(binding["sourceGitCommit"]) is not None, "release source commit is invalid")
    require(isinstance(binding.get("appVersion"), str) and VERSION_PATTERN.fullmatch(binding["appVersion"]) is not None, "release app version is invalid")
    require(binding.get("buildScope") == BUILD_SCOPE, "reconciliation must cover all app versions and builds because Apple's report has no app-version dimension")

    comparison = manifest.get("comparison")
    require(isinstance(comparison, dict), "comparison boundary is required")
    require_exact_keys(
        comparison,
        {
            "periodStartDate",
            "periodEndDateExclusive",
            "asOfDate",
            "cohortKind",
            "firstPartyTimeZone",
            "appStoreConnectTimeZone",
            "storefrontScope",
            "subscriptionScope",
            "metrics",
        },
        "comparison boundary",
    )
    start = parse_date(comparison.get("periodStartDate"), "comparison start date")
    end = parse_date(comparison.get("periodEndDateExclusive"), "comparison end date")
    as_of = parse_date(comparison.get("asOfDate"), "comparison as-of date")
    days = (end - start).days
    require(MINIMUM_WINDOW_DAYS <= days <= MAXIMUM_WINDOW_DAYS, "comparison window must contain 7 to 35 complete days")
    require(as_of >= end, "comparison window is not closed as of the declared evidence date")
    require(as_of <= datetime.now(timezone.utc).date(), "comparison as-of date cannot be in the future")
    require(comparison.get("cohortKind") == COHORT_KIND, "only calendar-event reconciliation is allowed; conversion cohorts remain App Store Connect-only")
    require(comparison.get("firstPartyTimeZone") == FIRST_PARTY_TIME_ZONE, "first-party daily periods must remain UTC")
    require(comparison.get("appStoreConnectTimeZone") == ASC_TIME_ZONE, "App Store Connect Sales and Trends dates must remain Pacific Time")
    require(comparison.get("storefrontScope") == STOREFRONT_SCOPE, "reconciliation cannot mix partial storefront scope with all-storefront totals")
    require(comparison.get("subscriptionScope") == SUBSCRIPTION_SCOPE, "reconciliation must include every Noum subscription plan")
    require(comparison.get("metrics") == list(LIFECYCLE_METRICS), "comparison metrics must use the complete canonical lifecycle set")

    sources = manifest.get("sources")
    require(isinstance(sources, dict), "reconciliation sources are required")
    require_exact_keys(
        sources,
        {"firstParty", "appStoreConnectLifecycle", "appStoreConnectProceeds", "currencyConversion"},
        "reconciliation sources",
    )
    first_party = resolve_source(manifest_path, sources["firstParty"], FIRST_PARTY_SCHEMA, "first-party aggregate")
    asc_lifecycle = resolve_source(manifest_path, sources["appStoreConnectLifecycle"], ASC_LIFECYCLE_SCHEMA, "App Store Connect lifecycle")
    require(asc_lifecycle.report_kind == "subscription-event-report-1_3", "lifecycle evidence must derive from Subscription Event Report 1_3")
    proceeds = resolve_optional_source(manifest_path, sources["appStoreConnectProceeds"], ASC_PROCEEDS_SCHEMA, "App Store Connect proceeds")
    fx = resolve_optional_source(manifest_path, sources["currencyConversion"], FX_SCHEMA, "currency conversion")
    require(not (fx is not None and proceeds is None), "currency conversion evidence is not allowed without proceeds evidence")
    return manifest, first_party, asc_lifecycle, proceeds, fx


def parse_first_party(source: BoundSource, dates: list[date]) -> tuple[dict[str, int], int, str, int]:
    payload = parse_json_object(source.path, "first-party aggregate")
    require_exact_keys(
        payload,
        {"schemaVersion", "lifecycle", "aiCost"},
        "first-party aggregate",
    )
    require(
        payload.get("schemaVersion") == FIRST_PARTY_PAYLOAD_SCHEMA_VERSION,
        "first-party aggregate schema version is unsupported",
    )

    lifecycle = payload.get("lifecycle")
    require(isinstance(lifecycle, dict), "first-party lifecycle projection is required")
    require_exact_keys(
        lifecycle,
        {"source", "environment", "days"},
        "first-party lifecycle projection",
    )
    require(
        lifecycle.get("source") == FIRST_PARTY_LIFECYCLE_SOURCE,
        "first-party lifecycle projection must come from App Store Server Notifications V2",
    )
    require(
        lifecycle.get("environment") == FIRST_PARTY_LIFECYCLE_ENVIRONMENT,
        "first-party lifecycle projection must contain production notifications only",
    )
    lifecycle_rows = lifecycle.get("days")
    require(
        isinstance(lifecycle_rows, list),
        "first-party lifecycle projection days must be an array",
    )

    ai_cost = payload.get("aiCost")
    require(isinstance(ai_cost, dict), "first-party AI-cost projection is required")
    require_exact_keys(
        ai_cost,
        {"source", "days"},
        "first-party AI-cost projection",
    )
    require(
        ai_cost.get("source") == FIRST_PARTY_AI_COST_SOURCE,
        "first-party AI-cost projection must come from consented client aggregates",
    )
    ai_cost_rows = ai_cost.get("days")
    require(
        isinstance(ai_cost_rows, list),
        "first-party AI-cost projection days must be an array",
    )

    counts = {metric: 0 for metric in LIFECYCLE_METRICS}
    lifecycle_dates: list[date] = []
    expected_event_keys = set(FIRST_PARTY_EVENT_KEYS.values())
    for row in lifecycle_rows:
        require(isinstance(row, dict), "first-party lifecycle day must be an object")
        require_exact_keys(
            row,
            {"dateUTC", "eventCounts"},
            "first-party lifecycle day",
        )
        day = parse_date(row.get("dateUTC"), "first-party lifecycle date")
        lifecycle_dates.append(day)
        event_counts = row.get("eventCounts")
        require(isinstance(event_counts, dict), "first-party lifecycle event counts must be an object")
        require_exact_keys(
            event_counts,
            expected_event_keys,
            "first-party lifecycle event counts",
        )
        for metric, event_key in FIRST_PARTY_EVENT_KEYS.items():
            value = parse_nonnegative_int(event_counts[event_key], "first-party lifecycle count")
            counts[metric] += value
            require(counts[metric] <= MAXIMUM_COUNT, "first-party lifecycle total exceeds the aggregate ceiling")

    validate_exact_daily_coverage(
        lifecycle_dates,
        dates,
        "first-party lifecycle projection",
    )

    cost = 0
    unpriced_usage = 0
    currency: str | None = None
    ai_cost_dates: list[date] = []
    for row in ai_cost_rows:
        require(isinstance(row, dict), "first-party AI-cost day must be an object")
        require_exact_keys(
            row,
            {
                "dateUTC",
                "estimatedAICostMicros",
                "estimatedAICostCurrency",
                "unpricedAIUsageCount",
            },
            "first-party AI-cost day",
        )
        day = parse_date(row.get("dateUTC"), "first-party AI-cost date")
        ai_cost_dates.append(day)
        row_cost = parse_nonnegative_int(row.get("estimatedAICostMicros"), "first-party AI cost", MAXIMUM_MONEY_MICROS)
        cost += row_cost
        require(cost <= MAXIMUM_MONEY_MICROS, "first-party AI cost total exceeds the aggregate ceiling")
        unpriced_usage += parse_nonnegative_int(
            row.get("unpricedAIUsageCount"),
            "first-party unpriced AI usage count",
        )
        require(
            unpriced_usage <= MAXIMUM_COUNT,
            "first-party unpriced AI usage total exceeds the aggregate ceiling",
        )
        row_currency = row.get("estimatedAICostCurrency")
        require(isinstance(row_currency, str) and CURRENCY_PATTERN.fullmatch(row_currency) is not None, "first-party AI cost currency must be one ISO-4217 code")
        if currency is None:
            currency = row_currency
        require(currency == row_currency, "first-party AI costs cannot mix currencies")

    validate_exact_daily_coverage(
        ai_cost_dates,
        dates,
        "first-party AI-cost projection",
    )
    require(currency is not None, "first-party AI cost currency is required")
    return counts, cost, currency, unpriced_usage


def read_csv_rows(source: BoundSource, expected_header: tuple[str, ...], context: str) -> list[dict[str, str]]:
    try:
        handle = source.path.open("r", encoding="utf-8", newline="")
    except (OSError, UnicodeError) as error:
        raise ContractError(f"{context} is not a readable UTF-8 CSV") from error
    with handle:
        reader = csv.DictReader(handle)
        require(tuple(reader.fieldnames or ()) == expected_header, f"{context} CSV header does not match the identifier-free normalized contract")
        try:
            rows = list(reader)
        except csv.Error as error:
            raise ContractError(f"{context} is malformed CSV") from error
    require(rows, f"{context} must contain explicit daily rows")
    expected_keys = set(expected_header)
    require(
        all(set(row) == expected_keys and all(value is not None for value in row.values()) for row in rows),
        f"{context} CSV rows do not match the identifier-free normalized contract",
    )
    return rows


def parse_asc_lifecycle(source: BoundSource, dates: list[date]) -> dict[str, int]:
    rows = read_csv_rows(source, ASC_LIFECYCLE_HEADER, "App Store Connect lifecycle")
    counts = {metric: 0 for metric in LIFECYCLE_METRICS}
    received_dates: list[date] = []
    for row in rows:
        day = parse_date(row.get("event_date_pt"), "App Store Connect event date")
        received_dates.append(day)
        for metric in LIFECYCLE_METRICS:
            value = parse_csv_int(row.get(metric), "App Store Connect lifecycle count")
            counts[metric] += value
            require(counts[metric] <= MAXIMUM_COUNT, "App Store Connect lifecycle total exceeds the aggregate ceiling")
    validate_exact_daily_coverage(received_dates, dates, "App Store Connect lifecycle")
    return counts


def parse_asc_proceeds(source: BoundSource, dates: list[date]) -> tuple[int, str]:
    rows = read_csv_rows(source, ASC_PROCEEDS_HEADER, "App Store Connect proceeds")
    received_dates: list[date] = []
    total = 0
    currency: str | None = None
    for row in rows:
        day = parse_date(row.get("event_date_pt"), "App Store Connect proceeds date")
        received_dates.append(day)
        value = parse_csv_signed_int(row.get("developer_proceeds_micros"), "App Store Connect proceeds", MAXIMUM_MONEY_MICROS)
        total += value
        require(abs(total) <= MAXIMUM_MONEY_MICROS, "App Store Connect proceeds total exceeds the aggregate ceiling")
        row_currency = row.get("currency")
        require(isinstance(row_currency, str) and CURRENCY_PATTERN.fullmatch(row_currency) is not None, "App Store Connect proceeds currency must be one ISO-4217 code")
        if currency is None:
            currency = row_currency
        require(currency == row_currency, "App Store Connect proceeds cannot mix currencies")
    validate_exact_daily_coverage(received_dates, dates, "App Store Connect proceeds")
    require(currency is not None, "App Store Connect proceeds currency is required")
    return total, currency


def parse_fx(source: BoundSource, from_currency: str, to_currency: str, start: date, end: date) -> tuple[int, int, str]:
    payload = parse_json_object(source.path, "currency conversion")
    require_exact_keys(
        payload,
        {"schemaVersion", "fromCurrency", "toCurrency", "rateNumerator", "rateDenominator", "effectiveDate", "sourceEvidenceSha256"},
        "currency conversion",
    )
    require(payload.get("schemaVersion") == SCHEMA_VERSION, "currency conversion schema version is unsupported")
    require(payload.get("fromCurrency") == from_currency and payload.get("toCurrency") == to_currency, "currency conversion direction does not match the evidence currencies")
    numerator = parse_nonnegative_int(payload.get("rateNumerator"), "currency conversion numerator", 1_000_000_000)
    denominator = parse_nonnegative_int(payload.get("rateDenominator"), "currency conversion denominator", 1_000_000_000)
    require(numerator > 0 and denominator > 0, "currency conversion rate must be positive")
    effective = parse_date(payload.get("effectiveDate"), "currency conversion effective date")
    require(start <= effective < end, "currency conversion effective date must fall inside the comparison window")
    evidence_hash = payload.get("sourceEvidenceSha256")
    require(isinstance(evidence_hash, str) and SHA256_PATTERN.fullmatch(evidence_hash) is not None, "currency conversion source evidence SHA-256 is invalid")
    return numerator, denominator, evidence_hash


def relative_difference_basis_points(first_party: int, authority: int) -> int | None:
    if authority == 0:
        return None
    difference = Decimal(first_party - authority) * Decimal(10_000) / Decimal(authority)
    return int(difference.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def convert_micros(value: int, numerator: int, denominator: int) -> int:
    converted = Decimal(value) * Decimal(numerator) / Decimal(denominator)
    return int(converted.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def reconcile(manifest_path: Path) -> dict[str, Any]:
    manifest, first_source, asc_source, proceeds_source, fx_source = parse_manifest(manifest_path)
    comparison = manifest["comparison"]
    start = parse_date(comparison["periodStartDate"], "comparison start date")
    end = parse_date(comparison["periodEndDateExclusive"], "comparison end date")
    dates = expected_dates(start, end)

    first_counts, ai_cost, ai_currency, unpriced_ai_usage = parse_first_party(
        first_source,
        dates,
    )
    asc_counts = parse_asc_lifecycle(asc_source, dates)

    comparisons: list[dict[str, Any]] = []
    has_discrepancy = False
    for metric in LIFECYCLE_METRICS:
        first_value = first_counts[metric]
        authority_value = asc_counts[metric]
        difference = first_value - authority_value
        if difference != 0:
            has_discrepancy = True
        comparisons.append({
            "metric": metric,
            "firstPartyObservedCount": first_value,
            "appStoreConnectAuthorityCount": authority_value,
            "difference": difference,
            "absoluteDifference": abs(difference),
            "relativeDifferenceBasisPoints": relative_difference_basis_points(first_value, authority_value),
            "status": "exact-count-match" if difference == 0 else "discrepancy-review-required",
        })

    financial: dict[str, Any]
    source_hashes = {
        "firstPartyAggregateSha256": first_source.sha256,
        "firstPartyRawExportSha256": first_source.raw_export_sha256,
        "appStoreConnectLifecycleSha256": asc_source.sha256,
        "appStoreConnectLifecycleRawExportSha256": asc_source.raw_export_sha256,
    }
    if proceeds_source is None:
        financial = {
            "status": (
                "blocked-unpriced-ai-usage"
                if unpriced_ai_usage > 0
                else "not-provided"
            ),
            "estimatedAICostMicros": ai_cost,
            "estimatedAICostCurrency": ai_currency,
            "unpricedAIUsageCount": unpriced_ai_usage,
            "developerProceedsMicros": None,
            "developerProceedsCurrency": None,
            "aiCostInProceedsCurrencyMicros": None,
            "residualAfterAICostMicros": None,
            "residualAfterAICostBasisPoints": None,
            "note": (
                "Unpriced off-device AI usage exists; contribution-margin arithmetic is blocked."
                if unpriced_ai_usage > 0
                else "No App Store Connect proceeds extract was supplied; no margin arithmetic was attempted."
            ),
        }
    else:
        proceeds, proceeds_currency = parse_asc_proceeds(proceeds_source, dates)
        source_hashes["appStoreConnectProceedsSha256"] = proceeds_source.sha256
        source_hashes["appStoreConnectProceedsRawExportSha256"] = proceeds_source.raw_export_sha256
        converted_ai_cost = ai_cost
        fx_summary: dict[str, Any] | None = None
        if ai_currency != proceeds_currency:
            require(fx_source is not None, "AI cost and proceeds currencies differ; a hashed conversion receipt is required")
            numerator, denominator, evidence_hash = parse_fx(fx_source, ai_currency, proceeds_currency, start, end)
            converted_ai_cost = convert_micros(ai_cost, numerator, denominator)
            source_hashes["currencyConversionSha256"] = fx_source.sha256
            fx_summary = {
                "fromCurrency": ai_currency,
                "toCurrency": proceeds_currency,
                "rateNumerator": numerator,
                "rateDenominator": denominator,
                "rounding": "half-up-to-micros",
                "sourceEvidenceSha256": evidence_hash,
            }
        else:
            require(fx_source is None, "currency conversion evidence must not be supplied when currencies already match")
        residual = None if unpriced_ai_usage > 0 else proceeds - converted_ai_cost
        margin_bps = None
        if proceeds > 0 and residual is not None:
            margin_bps = int(
                (Decimal(residual) * Decimal(10_000) / Decimal(proceeds)).quantize(
                    Decimal("1"), rounding=ROUND_HALF_UP
                )
            )
        financial = {
            "status": (
                "blocked-unpriced-ai-usage"
                if unpriced_ai_usage > 0
                else "comparable" if fx_summary is None
                else "comparable-with-hashed-conversion"
            ),
            "proceedsReportKind": proceeds_source.report_kind,
            "estimatedAICostMicros": ai_cost,
            "estimatedAICostCurrency": ai_currency,
            "unpricedAIUsageCount": unpriced_ai_usage,
            "developerProceedsMicros": proceeds,
            "developerProceedsCurrency": proceeds_currency,
            "aiCostInProceedsCurrencyMicros": converted_ai_cost,
            "residualAfterAICostMicros": residual,
            "residualAfterAICostBasisPoints": margin_bps,
            "currencyConversion": fx_summary,
            "note": (
                "Known priced AI cost is retained, but unpriced off-device usage blocks residual and margin claims."
                if unpriced_ai_usage > 0
                else "Residual excludes any variable costs not present in these two aggregate exports."
            ),
        }

    if unpriced_ai_usage > 0:
        commercial_readiness = "BLOCKED_UNPRICED_AI_USAGE"
    elif proceeds_source is None:
        commercial_readiness = "BLOCKED_MISSING_PROCEEDS"
    elif financial["residualAfterAICostBasisPoints"] is None:
        commercial_readiness = "BLOCKED_MARGIN_NOT_COMPUTABLE"
    else:
        commercial_readiness = "CONTRIBUTION_MARGIN_EVALUABLE"

    return {
        "schemaVersion": SCHEMA_VERSION,
        "status": "DISCREPANCY_REVIEW_REQUIRED" if has_discrepancy else "COUNTS_MATCH_WITH_TIMEZONE_CAUTION",
        "releaseBinding": manifest["releaseBinding"],
        "comparisonBoundary": {
            "periodStartDate": start.isoformat(),
            "periodEndDateExclusive": end.isoformat(),
            "asOfDate": comparison["asOfDate"],
            "cohortKind": COHORT_KIND,
            "firstPartyTimeZone": FIRST_PARTY_TIME_ZONE,
            "appStoreConnectTimeZone": ASC_TIME_ZONE,
            "storefrontScope": STOREFRONT_SCOPE,
            "subscriptionScope": SUBSCRIPTION_SCOPE,
            "exactTimestampAlignment": False,
        },
        "sourceBindings": source_hashes,
        "lifecycleComparisons": comparisons,
        "financialObservation": financial,
        "commercialReadiness": commercial_readiness,
        "authority": {
            "subscriptionOutcomesAndProceeds": "App Store Connect",
            "firstPartyRole": "anonymous observational coverage and AI cost estimate",
            "conversionCohortsComputed": False,
        },
        "requiredReviewNotes": [
            "Apple Sales and Trends event dates are Pacific Time while Noum batches are closed UTC days; equal date labels are not exact timestamp windows.",
            "A discrepancy is a coverage investigation signal, not permission to replace App Store Connect authority.",
            "Do not derive download-to-trial, trial-to-paid, retention, refund rate, or subscriber-level linkage from this result.",
        ],
    }


def write_result(path: Path, result: dict[str, Any]) -> None:
    require(not path.exists() or (path.is_file() and not path.is_symlink()), "output path cannot be a symlink or directory")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True, help="Filled reconciliation manifest in the protected evidence directory")
    parser.add_argument("--output", type=Path, required=True, help="Path for the content-free discrepancy result")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = reconcile(args.manifest)
        write_result(args.output, result)
    except ContractError as error:
        print(f"Commercial reconciliation refused: {error}", file=sys.stderr)
        return 2
    print(
        f"Commercial reconciliation written: {result['status']} "
        f"({len(result['lifecycleComparisons'])} aggregate metrics)",
        file=sys.stdout,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
