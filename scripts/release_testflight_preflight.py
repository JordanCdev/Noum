#!/usr/bin/env python3
"""Fail-closed local Apple signing and TestFlight production preflight.

This command separates three different claims:

1. the repository and an unsigned archive have the expected release shape;
2. the current Mac has paid-team distribution identities and profiles; and
3. the existing external-evidence validator accepts physical TestFlight QA.

It never requests provisioning updates, signs in to Apple, signs an archive,
exports or uploads an IPA, or treats a direct development install as TestFlight.
Certificate names, team identifiers, profile UUIDs, and profile names are never
printed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Iterable


SCRIPT_ROOT = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_ROOT.parent
EXPECTED_APP_GROUP = "group.com.jordancoaten.noum"
EXPECTED_TARGETS = {
    "Noum": {
        "bundle": "com.jordancoaten.noum",
        "entitlements": "Noum.entitlements",
        "skip_install": "NO",
        "wrapper": "app",
    },
    "NoumWidget": {
        "bundle": "com.jordancoaten.noum.NoumWidget",
        "entitlements": "NoumWidget/NoumWidget.entitlements",
        "skip_install": "YES",
        "wrapper": "appex",
    },
    "NoumMessages": {
        "bundle": "com.jordancoaten.noum.NoumMessages",
        "entitlements": "NoumMessages/NoumMessages.entitlements",
        "skip_install": "YES",
        "wrapper": "appex",
    },
    "NoumWatch": {
        "bundle": "com.jordancoaten.noum.watchkitapp",
        "entitlements": "NoumWatch/NoumWatch.entitlements",
        "skip_install": "NO",
        "wrapper": "app",
    },
}
ARCHIVED_PRODUCTS = {
    "Noum": Path("Products/Applications/Noum.app"),
    "NoumWidget": Path("Products/Applications/Noum.app/PlugIns/NoumWidget.appex"),
    "NoumMessages": Path("Products/Applications/Noum.app/PlugIns/NoumMessages.appex"),
}
ARCHIVED_EXTENSION_POINTS = {
    "NoumWidget": "com.apple.widgetkit-extension",
    "NoumMessages": "com.apple.message-payload-provider",
}
FORBIDDEN_ARCHIVE_CONFIGS = {
    "AIConfig.plist",
    "BackendConfig.plist",
    "Transcribe.plist",
    "TranscriptionProviders.plist",
}
STOREKIT_PRODUCT_CONSTANTS = ("monthlyID", "annualID")
SOURCE_COMMIT_INFO_KEY = "NoumSourceGitCommit"
SOURCE_COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
APPLE_SERVICE_BINARY_MARKERS = (
    b"/AuthenticationServices.framework/AuthenticationServices",
    b"/StoreKit.framework/StoreKit",
)


@dataclass(frozen=True)
class Check:
    key: str
    passed: bool
    observed: str
    next_step: str


@dataclass(frozen=True)
class Section:
    key: str
    label: str
    checks: tuple[Check, ...]

    @property
    def passed(self) -> bool:
        return bool(self.checks) and all(check.passed for check in self.checks)

    def serializable(self) -> dict[str, Any]:
        return {
            "key": self.key,
            "label": self.label,
            "passed": self.passed,
            "passedCheckCount": sum(check.passed for check in self.checks),
            "checkCount": len(self.checks),
            "checks": [asdict(check) for check in self.checks],
        }


def check(key: str, passed: bool, observed: str, next_step: str) -> Check:
    return Check(key=key, passed=passed, observed=observed, next_step=next_step)


def parse_build_settings(output: str) -> dict[str, dict[str, str]]:
    """Parse xcodebuild -showBuildSettings without retaining log preamble."""
    targets: dict[str, dict[str, str]] = {}
    current: dict[str, str] | None = None
    header = re.compile(r"^Build settings for action \S+ and target (.+):$")
    setting = re.compile(r"^\s{4}([A-Z0-9_]+) = ?(.*)$")
    for line in output.splitlines():
        match = header.match(line)
        if match:
            current = targets.setdefault(match.group(1), {})
            continue
        if current is None:
            continue
        match = setting.match(line)
        if match:
            current[match.group(1)] = match.group(2).strip()
    return targets


def _read_plist(path: Path) -> dict[str, Any]:
    value = plistlib.loads(path.read_bytes())
    if not isinstance(value, dict):
        raise ValueError("plist root is not a dictionary")
    return value


def _relative_nonempty_files(repo_root: Path, paths: Iterable[str]) -> bool:
    return all((repo_root / path).is_file() and (repo_root / path).stat().st_size > 0 for path in paths)


def _target_shape_is_valid(settings: dict[str, dict[str, str]]) -> bool:
    for target, expected in EXPECTED_TARGETS.items():
        actual = settings.get(target, {})
        if actual.get("PRODUCT_BUNDLE_IDENTIFIER") != expected["bundle"]:
            return False
        if actual.get("CODE_SIGN_ENTITLEMENTS") != expected["entitlements"]:
            return False
        if actual.get("CODE_SIGN_STYLE") != "Automatic":
            return False
        if actual.get("SKIP_INSTALL") != expected["skip_install"]:
            return False
        if actual.get("WRAPPER_EXTENSION") != expected["wrapper"]:
            return False
        if actual.get("CODE_SIGNING_ALLOWED") != "YES":
            return False
        if actual.get("CODE_SIGNING_REQUIRED") != "YES":
            return False
        if actual.get("PROVISIONING_PROFILE_SPECIFIER", ""):
            return False
        if actual.get("PROVISIONING_PROFILE", ""):
            return False
    return True


def _versions_align(settings: dict[str, dict[str, str]]) -> bool:
    versions = {
        (
            settings.get(target, {}).get("MARKETING_VERSION"),
            settings.get(target, {}).get("CURRENT_PROJECT_VERSION"),
        )
        for target in EXPECTED_TARGETS
    }
    return len(versions) == 1 and None not in next(iter(versions), (None, None))


def _teams_align(settings: dict[str, dict[str, str]]) -> bool:
    teams = {settings.get(target, {}).get("DEVELOPMENT_TEAM", "") for target in EXPECTED_TARGETS}
    return len(teams) == 1 and bool(next(iter(teams), ""))


def _entitlements_are_valid(repo_root: Path) -> bool:
    try:
        main = _read_plist(repo_root / "Noum.entitlements")
        widget = _read_plist(repo_root / "NoumWidget/NoumWidget.entitlements")
        messages = _read_plist(repo_root / "NoumMessages/NoumMessages.entitlements")
        watch = _read_plist(repo_root / "NoumWatch/NoumWatch.entitlements")
    except (OSError, ValueError, plistlib.InvalidFileException):
        return False
    expected_group = [EXPECTED_APP_GROUP]
    return (
        main.get("com.apple.security.application-groups") == expected_group
        and main.get("com.apple.developer.applesignin") == ["Default"]
        and main.get("com.apple.developer.devicecheck.appattest-environment")
        == "$(APP_ATTEST_ENVIRONMENT)"
        and widget.get("com.apple.security.application-groups") == expected_group
        and messages.get("com.apple.security.application-groups") == expected_group
        and watch.get("com.apple.security.application-groups") == expected_group
    )


def _embedding_is_valid(repo_root: Path) -> bool:
    try:
        text = (repo_root / "Noum.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    except OSError:
        return False
    start = text.find("/* Begin PBXCopyFilesBuildPhase section */")
    end = text.find("/* End PBXCopyFilesBuildPhase section */")
    if start < 0 or end <= start:
        return False
    copy_section = text[start:end]
    return (
        "NoumWidget.appex in Embed App Extensions" in copy_section
        and "NoumMessages.appex in Embed App Extensions" in copy_section
        and "NoumWatch.app in Embed" not in copy_section
        and "name = \"Embed App Extensions\";" in copy_section
    )


def _export_options_are_valid(repo_root: Path) -> bool:
    try:
        options = _read_plist(repo_root / "scripts/TestFlightExportOptions.plist")
    except (OSError, ValueError, plistlib.InvalidFileException):
        return False
    forbidden = {"teamID", "provisioningProfiles", "signingCertificate", "installerSigningCertificate"}
    return (
        options.get("method") == "app-store-connect"
        and options.get("destination") == "export"
        and options.get("signingStyle") == "automatic"
        and options.get("manageAppVersionAndBuildNumber") is False
        and options.get("uploadSymbols") is True
        and options.get("stripSwiftSymbols") is True
        and not forbidden.intersection(options)
    )


def _google_bundle_matches(repo_root: Path) -> bool:
    try:
        google = _read_plist(repo_root / "Noum/GoogleService-Info.plist")
    except (OSError, ValueError, plistlib.InvalidFileException):
        return False
    return google.get("BUNDLE_ID") == EXPECTED_TARGETS["Noum"]["bundle"]


def current_source_commit(repo_root: Path) -> str | None:
    completed = subprocess.run(
        ["git", "-C", str(repo_root), "rev-parse", "HEAD"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    value = completed.stdout.strip().lower()
    return value if completed.returncode == 0 and SOURCE_COMMIT_PATTERN.fullmatch(value) else None


def source_tree_is_clean(repo_root: Path) -> bool:
    completed = subprocess.run(
        ["git", "-C", str(repo_root), "status", "--porcelain", "--untracked-files=all"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    return completed.returncode == 0 and not completed.stdout.strip()


def _storekit_product_ids(repo_root: Path) -> tuple[str, ...]:
    try:
        source = (repo_root / "Noum/PremiumManager.swift").read_text(encoding="utf-8")
    except OSError:
        return ()
    product_ids: list[str] = []
    for constant in STOREKIT_PRODUCT_CONSTANTS:
        match = re.search(
            rf'\bstatic\s+let\s+{re.escape(constant)}\s*=\s*"([A-Za-z0-9.-]+)"',
            source,
        )
        if match is None:
            return ()
        product_ids.append(match.group(1))
    if len(set(product_ids)) != len(STOREKIT_PRODUCT_CONSTANTS):
        return ()
    required_runtime_paths = (
        "Product.products(for: productIDs)",
        "Transaction.currentEntitlements",
        "AppStore.sync()",
    )
    return tuple(product_ids) if all(path in source for path in required_runtime_paths) else ()


def run_dwarf_uuids(path: Path) -> frozenset[tuple[str, str]]:
    completed = subprocess.run(
        ["dwarfdump", "--uuid", str(path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        return frozenset()
    matches = re.findall(
        r"^UUID:\s+([0-9A-Fa-f-]{36})\s+\(([^)]+)\)",
        completed.stdout,
        flags=re.MULTILINE,
    )
    return frozenset((uuid.upper(), architecture) for uuid, architecture in matches)


def archive_checks(
    repo_root: Path,
    archive_path: Path | None,
    scanner: Callable[[Path], bool] | None = None,
    expected_version: tuple[str | None, str | None] | None = None,
    expected_source_commit: str | None = None,
    uuid_reader: Callable[[Path], frozenset[tuple[str, str]]] | None = None,
) -> list[Check]:
    if archive_path is None:
        return [
            check(
                "unsignedArchivePresent",
                False,
                "not supplied",
                "Build an unsigned generic-iOS archive or pass --archive-path; this proves archive shape only.",
            )
        ]
    archive_path = archive_path.resolve()
    app = archive_path / ARCHIVED_PRODUCTS["Noum"]
    present = archive_path.is_dir() and app.is_dir()
    checks = [
        check(
            "unsignedArchivePresent",
            present,
            "present" if present else "missing or incomplete",
            "Produce the archive with --build-unsigned-archive and CODE_SIGNING_ALLOWED=NO.",
        )
    ]
    if not present:
        return checks

    try:
        archive_info = _read_plist(archive_path / "Info.plist")
    except (OSError, ValueError, plistlib.InvalidFileException):
        archive_info = {}

    product_infos: dict[str, dict[str, Any]] = {}
    bundle_shape = True
    for target, relative in ARCHIVED_PRODUCTS.items():
        product = archive_path / relative
        try:
            info = _read_plist(product / "Info.plist")
        except (OSError, ValueError, plistlib.InvalidFileException):
            bundle_shape = False
            continue
        product_infos[target] = info
        expected_package_type = "APPL" if target == "Noum" else "XPC!"
        bundle_shape = bundle_shape and (
            info.get("CFBundleIdentifier") == EXPECTED_TARGETS[target]["bundle"]
            and info.get("CFBundlePackageType") == expected_package_type
        )
    checks.append(
        check(
            "archiveProductShape",
            bundle_shape,
            "main app plus Widget and Messages extensions" if bundle_shape else "product or bundle identifier mismatch",
            "Repair the source-controlled target/embed configuration; do not compensate with export-time overrides.",
        )
    )
    version_pairs = {
        (info.get("CFBundleShortVersionString"), info.get("CFBundleVersion"))
        for info in product_infos.values()
    }
    version_shape = (
        len(product_infos) == len(ARCHIVED_PRODUCTS)
        and len(version_pairs) == 1
        and None not in next(iter(version_pairs), (None, None))
    )
    if expected_version is not None:
        version_shape = version_shape and next(iter(version_pairs), (None, None)) == expected_version
    checks.append(
        check(
            "archiveVersionMetadata",
            version_shape,
            "app and extensions align with Release version/build" if version_shape else "missing or mismatched version/build metadata",
            "Set aligned MARKETING_VERSION and CURRENT_PROJECT_VERSION values before archiving.",
        )
    )
    archived_source_commit = product_infos.get("Noum", {}).get(SOURCE_COMMIT_INFO_KEY)
    source_commit_bound = bool(
        expected_source_commit
        and SOURCE_COMMIT_PATTERN.fullmatch(expected_source_commit)
        and archived_source_commit == expected_source_commit
    )
    checks.append(
        check(
            "archiveSourceCommitBound",
            source_commit_bound,
            "archive embeds the exact clean source commit" if source_commit_bound else "archive source commit missing or stale",
            "Build from a clean checkout with the preflight so the exact Git commit is embedded in the app Info.plist.",
        )
    )

    app_properties = archive_info.get("ApplicationProperties")
    app_properties = app_properties if isinstance(app_properties, dict) else {}
    architectures = app_properties.get("Architectures")
    architectures = architectures if isinstance(architectures, list) else []
    device_platform_shape = (
        archive_info.get("ArchiveVersion") == 2
        and app_properties.get("ApplicationPath") == "Applications/Noum.app"
        and app_properties.get("CFBundleIdentifier") == EXPECTED_TARGETS["Noum"]["bundle"]
        and "arm64" in architectures
        and set(architectures).issubset({"arm64", "arm64e"})
        and len(product_infos) == len(ARCHIVED_PRODUCTS)
    )
    product_binaries: dict[str, Path] = {}
    for target, info in product_infos.items():
        executable = info.get("CFBundleExecutable")
        product = archive_path / ARCHIVED_PRODUCTS[target]
        binary = product / executable if isinstance(executable, str) and executable else None
        if binary is None or not binary.is_file() or binary.stat().st_size == 0:
            device_platform_shape = False
        else:
            product_binaries[target] = binary
        device_platform_shape = device_platform_shape and (
            info.get("DTPlatformName") == "iphoneos"
            and info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"]
            and isinstance(info.get("MinimumOSVersion"), str)
            and bool(info.get("MinimumOSVersion"))
        )
    checks.append(
        check(
            "archiveDevicePlatformShape",
            device_platform_shape,
            "generic iPhoneOS arm64 archive with executable products" if device_platform_shape else "archive platform, architecture, or executable mismatch",
            "Rebuild with destination generic/platform=iOS; simulator or incomplete products cannot pass.",
        )
    )

    extension_shape = all(
        product_infos.get(target, {}).get("NSExtension", {}).get("NSExtensionPointIdentifier")
        == extension_point
        for target, extension_point in ARCHIVED_EXTENSION_POINTS.items()
    )
    checks.append(
        check(
            "archiveExtensionPoints",
            extension_shape,
            "Widget and Messages extension points match" if extension_shape else "embedded extension point mismatch",
            "Repair the extension Info.plist/build configuration and rebuild the archive.",
        )
    )

    uuid_reader = uuid_reader or run_dwarf_uuids
    symbols_match = len(product_binaries) == len(ARCHIVED_PRODUCTS)
    for target, binary in product_binaries.items():
        wrapper = ARCHIVED_PRODUCTS[target].name
        executable = product_infos[target].get("CFBundleExecutable")
        dsym_binary = archive_path / "dSYMs" / f"{wrapper}.dSYM/Contents/Resources/DWARF" / str(executable)
        binary_uuids = uuid_reader(binary)
        dsym_uuids = uuid_reader(dsym_binary) if dsym_binary.is_file() and dsym_binary.stat().st_size > 0 else frozenset()
        symbols_match = symbols_match and bool(binary_uuids) and binary_uuids == dsym_uuids
    checks.append(
        check(
            "archiveSymbolsPresent",
            symbols_match,
            "all app-owned dSYMs UUID-match their binaries" if symbols_match else "missing, unreadable, or stale app-owned dSYM",
            "Keep Release debug information in dSYM form and rebuild every embedded product in one archive.",
        )
    )

    storekit_product_ids = _storekit_product_ids(repo_root)
    try:
        main_binary = product_binaries["Noum"].read_bytes()
    except (KeyError, OSError):
        main_binary = b""
    apple_code_paths = (
        len(storekit_product_ids) == len(STOREKIT_PRODUCT_CONSTANTS)
        and all(product_id.encode("utf-8") in main_binary for product_id in storekit_product_ids)
        and all(marker in main_binary for marker in APPLE_SERVICE_BINARY_MARKERS)
    )
    checks.append(
        check(
            "archiveAppleServiceCodePaths",
            apple_code_paths,
            "StoreKit products and AuthenticationServices compiled into app" if apple_code_paths else "StoreKit or Apple authentication release path missing",
            "Restore the existing StoreKit 2 and Sign in with Apple source integration before archiving.",
        )
    )

    main_info = product_infos.get("Noum", {})
    try:
        privacy_manifest = _read_plist(app / "PrivacyInfo.xcprivacy")
    except (OSError, ValueError, plistlib.InvalidFileException):
        privacy_manifest = {}
    app_store_metadata = (
        isinstance(main_info.get("ITSAppUsesNonExemptEncryption"), bool)
        and privacy_manifest.get("NSPrivacyTracking") is False
        and isinstance(privacy_manifest.get("NSPrivacyCollectedDataTypes"), list)
        and isinstance(privacy_manifest.get("NSPrivacyAccessedAPITypes"), list)
    )
    checks.append(
        check(
            "archiveAppStoreMetadata",
            app_store_metadata,
            "root privacy manifest and export-compliance declaration present" if app_store_metadata else "privacy manifest or export-compliance declaration missing",
            "Restore the app-owned privacy manifest and explicit encryption declaration before upload.",
        )
    )

    forbidden = sorted({path.name for path in app.rglob("*") if path.name in FORBIDDEN_ARCHIVE_CONFIGS})
    checks.append(
        check(
            "archiveIgnoredConfigsExcluded",
            not forbidden,
            "development/provider configs excluded" if not forbidden else f"forbidden config count={len(forbidden)}",
            "Remove ignored provider configuration from the target resources and rebuild the archive.",
        )
    )
    scanner = scanner or (lambda bundle: run_bundle_scanner(repo_root, bundle))
    scan_passed = scanner(app)
    checks.append(
        check(
            "archiveCredentialScan",
            scan_passed,
            "redacted bundle scan passed" if scan_passed else "redacted bundle scan failed",
            "Resolve every scanner finding without printing the matched credential material.",
        )
    )
    return checks


def repository_checks(
    repo_root: Path,
    settings: dict[str, dict[str, str]],
    settings_collected: bool,
    archive_path: Path | None,
    scanner: Callable[[Path], bool] | None = None,
    expected_source_commit: str | None = None,
    uuid_reader: Callable[[Path], frozenset[tuple[str, str]]] | None = None,
) -> list[Check]:
    expected_names = set(EXPECTED_TARGETS)
    checks = [
        check(
            "releaseBuildSettingsCollected",
            settings_collected,
            "xcodebuild Release settings captured in memory" if settings_collected else "xcodebuild settings unavailable",
            "Provide a local SourcePackages cache and rerun; provisioning updates are neither needed nor allowed.",
        ),
        check(
            "releaseTargetsPresent",
            expected_names.issubset(settings),
            f"expected target count={len(expected_names)}" if expected_names.issubset(settings) else "one or more release targets missing",
            "Restore the expected app, Widget, Messages, and detached Watch target definitions.",
        ),
        check(
            "releaseTargetSigningShape",
            _target_shape_is_valid(settings),
            "automatic signing with no pinned profiles" if _target_shape_is_valid(settings) else "bundle/signing/install shape mismatch",
            "Keep target identifiers and entitlements source-controlled; do not pin personal profile UUIDs.",
        ),
        check(
            "releaseVersionsAligned",
            _versions_align(settings),
            "all distributable targets share version/build" if _versions_align(settings) else "version/build mismatch",
            "Align MARKETING_VERSION and CURRENT_PROJECT_VERSION across distributable targets.",
        ),
        check(
            "releaseTeamSettingAligned",
            _teams_align(settings),
            "one redacted team setting across targets" if _teams_align(settings) else "missing or inconsistent team setting",
            "Select one authorized paid team in Xcode; the preflight never prints or changes its identifier.",
        ),
        check(
            "releaseAppAttestProduction",
            settings.get("Noum", {}).get("APP_ATTEST_ENVIRONMENT") == "production",
            "production" if settings.get("Noum", {}).get("APP_ATTEST_ENVIRONMENT") == "production" else "not production",
            "Keep App Attest development-only in Debug and production in Release.",
        ),
        check(
            "sourceEntitlementsAligned",
            _entitlements_are_valid(repo_root),
            "app group aligned; main app adds Apple Sign In and App Attest" if _entitlements_are_valid(repo_root) else "entitlement mismatch",
            "Repair the source entitlement files before requesting new profiles.",
        ),
        check(
            "embeddedExtensionsAligned",
            _embedding_is_valid(repo_root),
            "Widget and Messages embedded; Watch remains detached" if _embedding_is_valid(repo_root) else "embed/dependency mismatch",
            "Embed only the shipping extensions; keep the known detached Watch target explicit.",
        ),
        check(
            "buildPlistsPresent",
            _relative_nonempty_files(
                repo_root,
                (
                    "Noum/Info.plist",
                    "Noum/GoogleService-Info.plist",
                    "Noum/AIConfig.plist",
                    "Noum/BackendConfig.plist",
                ),
            ),
            "four gitignored build plists present" if _relative_nonempty_files(
                repo_root,
                (
                    "Noum/Info.plist",
                    "Noum/GoogleService-Info.plist",
                    "Noum/AIConfig.plist",
                    "Noum/BackendConfig.plist",
                ),
            ) else "one or more build plists missing",
            "Re-copy Info, GoogleService-Info, AIConfig, and BackendConfig from the protected primary workspace.",
        ),
        check(
            "firebaseBundleIdentifierAligned",
            _google_bundle_matches(repo_root),
            "Firebase client bundle matches main app" if _google_bundle_matches(repo_root) else "Firebase client bundle mismatch",
            "Use the production Firebase client plist registered to the release bundle identifier.",
        ),
        check(
            "appStoreExportOptionsSafe",
            _export_options_are_valid(repo_root),
            "App Store Connect export; automatic signing; no team/profile pins" if _export_options_are_valid(repo_root) else "unsafe or malformed export options",
            "Restore scripts/TestFlightExportOptions.plist; never commit team IDs or profile UUIDs.",
        ),
        check(
            "sourceStoreKitContract",
            len(_storekit_product_ids(repo_root)) == len(STOREKIT_PRODUCT_CONSTANTS),
            "two distinct StoreKit 2 product identifiers with purchase/restore paths" if len(_storekit_product_ids(repo_root)) == len(STOREKIT_PRODUCT_CONSTANTS) else "StoreKit product or runtime contract missing",
            "Restore the existing StoreKit 2 product, entitlement, and restore contract before archive verification.",
        ),
    ]
    expected_version = (
        settings.get("Noum", {}).get("MARKETING_VERSION"),
        settings.get("Noum", {}).get("CURRENT_PROJECT_VERSION"),
    )
    expected_source_commit = expected_source_commit or current_source_commit(repo_root)
    checks.extend(
        archive_checks(
            repo_root,
            archive_path,
            scanner=scanner,
            expected_version=expected_version,
            expected_source_commit=expected_source_commit,
            uuid_reader=uuid_reader,
        )
    )
    return checks


def run_bundle_scanner(repo_root: Path, app_bundle: Path) -> bool:
    scanner = repo_root / "scripts/release-scan-app-bundle.sh"
    if not scanner.is_file():
        return False
    completed = subprocess.run(
        [str(scanner), str(app_bundle)],
        cwd=repo_root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return completed.returncode == 0


def identity_counts(output: str) -> dict[str, int]:
    development = 0
    distribution = 0
    valid_total = 0
    for line in output.splitlines():
        if "Apple Development:" in line or "iPhone Developer:" in line:
            development += 1
        if "Apple Distribution:" in line or "iPhone Distribution:" in line:
            distribution += 1
        match = re.search(r"(\d+) valid identities found", line)
        if match:
            valid_total = int(match.group(1))
    return {
        "valid": valid_total,
        "development": development,
        "distribution": distribution,
    }


def distribution_identity_fingerprints(output: str) -> frozenset[str]:
    matches = re.findall(
        r'^\s*\d+\)\s+([0-9A-Fa-f]{40})\s+"(?:Apple|iPhone) Distribution:',
        output,
        flags=re.MULTILINE,
    )
    return frozenset(match.upper() for match in matches)


def _decode_profile(path: Path) -> dict[str, Any] | None:
    raw = path.read_bytes()
    try:
        value = plistlib.loads(raw)
    except plistlib.InvalidFileException:
        completed = subprocess.run(
            ["security", "cms", "-D", "-i", str(path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if completed.returncode != 0:
            return None
        try:
            value = plistlib.loads(completed.stdout)
        except plistlib.InvalidFileException:
            return None
    return value if isinstance(value, dict) else None


def load_profiles(profile_dirs: Iterable[Path]) -> tuple[list[dict[str, Any]], int]:
    profiles: list[dict[str, Any]] = []
    unreadable = 0
    seen: set[Path] = set()
    for directory in profile_dirs:
        if not directory.is_dir():
            continue
        for pattern in ("*.mobileprovision", "*.provisionprofile"):
            for path in sorted(directory.glob(pattern)):
                resolved = path.resolve()
                if resolved in seen:
                    continue
                seen.add(resolved)
                try:
                    profile = _decode_profile(path)
                except OSError:
                    profile = None
                if profile is None:
                    unreadable += 1
                else:
                    profiles.append(profile)
    return profiles, unreadable


def _profile_kind(profile: dict[str, Any]) -> str:
    if profile.get("ProvisionsAllDevices") is True:
        return "enterprise"
    if profile.get("ProvisionedDevices"):
        entitlements = profile.get("Entitlements") or {}
        return "development" if entitlements.get("get-task-allow") is True else "ad-hoc"
    return "app-store"


def _profile_bundle(profile: dict[str, Any]) -> str:
    entitlements = profile.get("Entitlements") or {}
    identifier = entitlements.get("application-identifier") or entitlements.get("com.apple.application-identifier") or ""
    return identifier.split(".", 1)[1] if "." in identifier else identifier


def _profile_team(profile: dict[str, Any]) -> str:
    teams = profile.get("TeamIdentifier")
    return teams[0] if isinstance(teams, list) and teams else ""


def _profile_is_unexpired(profile: dict[str, Any], now: datetime) -> bool:
    expiration = profile.get("ExpirationDate")
    if not isinstance(expiration, datetime):
        return False
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=timezone.utc)
    return expiration > now


def _profile_has_expected_capabilities(profile: dict[str, Any], target: str) -> bool:
    entitlements = profile.get("Entitlements") or {}
    groups = entitlements.get("com.apple.security.application-groups") or []
    if EXPECTED_APP_GROUP not in groups:
        return False
    if target != "Noum":
        return True
    apple_sign_in = entitlements.get("com.apple.developer.applesignin") or []
    return (
        "Default" in apple_sign_in
        and entitlements.get("com.apple.developer.devicecheck.appattest-environment") == "production"
    )


def _profile_certificate_fingerprints(profile: dict[str, Any]) -> frozenset[str]:
    certificates = profile.get("DeveloperCertificates")
    if not isinstance(certificates, list):
        return frozenset()
    return frozenset(
        hashlib.sha1(certificate).hexdigest().upper()
        for certificate in certificates
        if isinstance(certificate, bytes) and certificate
    )


def _matching_app_store_profiles(
    profiles: Iterable[dict[str, Any]],
    target: str,
    team: str,
    now: datetime,
    distribution_fingerprints: frozenset[str],
) -> int:
    expected_bundle = EXPECTED_TARGETS[target]["bundle"]
    return sum(
        _profile_kind(profile) == "app-store"
        and _profile_bundle(profile) == expected_bundle
        and _profile_team(profile) == team
        and _profile_is_unexpired(profile, now)
        and _profile_has_expected_capabilities(profile, target)
        and bool(_profile_certificate_fingerprints(profile).intersection(distribution_fingerprints))
        for profile in profiles
    )


def authority_checks(
    settings: dict[str, dict[str, str]],
    identities: dict[str, int],
    profiles: list[dict[str, Any]],
    unreadable_profiles: int = 0,
    now: datetime | None = None,
    distribution_fingerprints: frozenset[str] = frozenset(),
) -> list[Check]:
    now = now or datetime.now(timezone.utc)
    team = settings.get("Noum", {}).get("DEVELOPMENT_TEAM", "")
    app_store_count = sum(_profile_kind(profile) == "app-store" for profile in profiles)
    checks = [
        check(
            "appleDistributionIdentity",
            identities.get("distribution", 0) > 0,
            f"distribution identities={identities.get('distribution', 0)}; development identities={identities.get('development', 0)}",
            "An authorized paid-team operator must install or create an Apple Distribution identity in Xcode.",
        ),
        check(
            "provisioningProfilesReadable",
            unreadable_profiles == 0,
            f"installed profiles={len(profiles)}; unreadable={unreadable_profiles}",
            "Remove or replace unreadable profiles through Xcode; do not hand-edit signed profile payloads.",
        ),
    ]
    for target in ("Noum", "NoumWidget", "NoumMessages"):
        count = (
            _matching_app_store_profiles(
                profiles,
                target,
                team,
                now,
                distribution_fingerprints,
            )
            if team
            else 0
        )
        checks.append(
            check(
                f"appStoreProfile{target}",
                count > 0,
                f"identity-bound matching App Store profiles={count}; installed App Store profiles={app_store_count}",
                "Use the authorized paid team to install an identity-bound profile with the required capabilities.",
            )
        )
    return checks


def _artifact_status(readiness: dict[str, Any], blocker: str) -> dict[str, Any] | None:
    artifact_audit = readiness.get("artifactAudit")
    if not isinstance(artifact_audit, dict):
        return None
    artifacts = artifact_audit.get("requiredArtifacts")
    if not isinstance(artifacts, list):
        return None
    return next(
        (
            artifact
            for artifact in artifacts
            if isinstance(artifact, dict) and artifact.get("blocker") == blocker
        ),
        None,
    )


def evidence_checks(readiness: dict[str, Any] | None) -> list[Check]:
    if readiness is None:
        return [
            check(
                "physicalTestFlightEvidence",
                False,
                "no validated evidence directory supplied",
                "Collect and validate coach-real-device-testflight-qa-v3.json from an actual TestFlight install.",
            ),
            check(
                "operationalLaunchEvidence",
                False,
                "no validated evidence directory supplied",
                "Complete the externally verified operational launch artifact, including Apple services and upload proof.",
            ),
            check(
                "appleReleaseServicesEvidence",
                False,
                "no accepted Apple release-services prerequisite",
                "Verify paid-team signing, Sign in with Apple/Firebase configuration, and both StoreKit products in App Store Connect.",
            ),
            check(
                "storeKitTestFlightEvidence",
                False,
                "no accepted physical StoreKit purchase/restore evidence",
                "Collect the redacted StoreKit receipt row from the same physical TestFlight build.",
            ),
        ]

    def accepted(blocker: str) -> bool:
        artifact = _artifact_status(readiness, blocker)
        return bool(
            artifact
            and artifact.get("passesLightweightContract") is True
            and artifact.get("activeBlocker") is False
        )

    testflight = accepted("noRealDeviceTestFlightVerification")
    operational = accepted("operationalLaunchChecklistIncomplete")
    return [
        check(
            "physicalTestFlightEvidence",
            testflight,
            "existing validator accepted physical TestFlight artifact" if testflight else "missing or rejected by existing validator",
            "A development-device install, simulator run, or unsigned archive cannot satisfy this gate.",
        ),
        check(
            "operationalLaunchEvidence",
            operational,
            "existing validator accepted operational launch artifact" if operational else "missing or rejected by existing validator",
            "Attach independently verified Apple-service, TestFlight-upload, and launch-operation proof.",
        ),
        check(
            "appleReleaseServicesEvidence",
            operational,
            "existing validator accepted exact Apple release-services prerequisite" if operational else "Apple release-services prerequisite missing or rejected",
            "The redacted evidence must cover paid-team signing, Apple/Firebase Sign in with Apple, and exact StoreKit metadata.",
        ),
        check(
            "storeKitTestFlightEvidence",
            testflight,
            "existing validator accepted physical TestFlight StoreKit row" if testflight else "physical TestFlight StoreKit row missing or rejected",
            "A local StoreKit configuration or direct install cannot prove sandbox purchase and restore.",
        ),
    ]


def result_payload(sections: Iterable[Section]) -> dict[str, Any]:
    sections = tuple(sections)
    passed = bool(sections) and all(section.passed for section in sections)
    return {
        "schemaVersion": "noum-testflight-signing-preflight-v1",
        "passed": passed,
        "verdict": "READY" if passed else "BLOCKED",
        "sections": [section.serializable() for section in sections],
        "evidenceBoundary": {
            "unsignedArchiveIsTestFlightEvidence": False,
            "directDevelopmentInstallIsTestFlightEvidence": False,
            "simulatorRunIsTestFlightEvidence": False,
            "physicalTestFlightEvidenceRequiredForPass": True,
        },
        "privacyBoundary": {
            "certificateNamesPrinted": False,
            "teamIdentifiersPrinted": False,
            "profileNamesOrUUIDsPrinted": False,
        },
    }


def collect_identity_authority() -> tuple[dict[str, int], frozenset[str]]:
    completed = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    output = completed.stdout if completed.returncode in (0, 1) else ""
    return identity_counts(output), distribution_identity_fingerprints(output)


def collect_build_settings(repo_root: Path, source_packages: Path | None) -> tuple[dict[str, dict[str, str]], bool]:
    if source_packages is None or not source_packages.is_dir():
        return {}, False
    command = [
        "xcodebuild",
        "-project",
        "Noum.xcodeproj",
        "-alltargets",
        "-configuration",
        "Release",
        "-showBuildSettings",
        "-clonedSourcePackagesDirPath",
        str(source_packages),
        "-disableAutomaticPackageResolution",
    ]
    completed = subprocess.run(
        command,
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    settings = parse_build_settings(completed.stdout)
    return settings, completed.returncode == 0 and set(EXPECTED_TARGETS).issubset(settings)


def build_unsigned_archive(
    repo_root: Path,
    archive_path: Path,
    derived_data: Path,
    source_packages: Path | None,
    source_commit: str | None,
) -> Check:
    if archive_path.exists():
        return check(
            "unsignedArchiveBuild",
            False,
            "refused to overwrite existing archive path",
            "Choose a new archive path; the preflight never removes an existing archive.",
        )
    if source_packages is None or not source_packages.is_dir():
        return check(
            "unsignedArchiveBuild",
            False,
            "local SourcePackages cache missing",
            "Pass --source-packages; this preflight will not resolve packages over the network.",
        )
    if source_commit is None or not source_tree_is_clean(repo_root):
        return check(
            "unsignedArchiveBuild",
            False,
            "source checkout is dirty or has no exact Git commit",
            "Commit the intended source and remove unrelated untracked files before building release evidence.",
        )
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    derived_data.mkdir(parents=True, exist_ok=True)
    command = [
        "xcodebuild",
        "archive",
        "-project",
        "Noum.xcodeproj",
        "-scheme",
        "Noum",
        "-configuration",
        "Release",
        "-destination",
        "generic/platform=iOS",
        "-archivePath",
        str(archive_path),
        "-derivedDataPath",
        str(derived_data),
        "-clonedSourcePackagesDirPath",
        str(source_packages),
        "-disableAutomaticPackageResolution",
        "CODE_SIGNING_ALLOWED=NO",
        "CODE_SIGNING_REQUIRED=NO",
        f"INFOPLIST_KEY_{SOURCE_COMMIT_INFO_KEY}={source_commit}",
    ]
    completed = subprocess.run(
        command,
        cwd=repo_root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return check(
        "unsignedArchiveBuild",
        completed.returncode == 0,
        "unsigned generic-iOS archive built" if completed.returncode == 0 else f"xcodebuild archive exit={completed.returncode}",
        "Fix repository/archive errors locally; do not enable signing or provisioning updates to hide them.",
    )


def collect_readiness(repo_root: Path, evidence_dir: Path | None) -> dict[str, Any] | None:
    if evidence_dir is None or not evidence_dir.is_dir():
        return None
    command = [
        str(repo_root / "tools/coach-arena/run.sh"),
        "readiness",
        "--repo-root",
        str(repo_root),
        "--dump-dir",
        str(evidence_dir),
        "--json",
        "--no-fail",
    ]
    completed = subprocess.run(
        command,
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        return None
    try:
        value = json.loads(completed.stdout)
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, dict) else None


def default_profile_dirs() -> tuple[Path, ...]:
    home = Path.home()
    return (
        home / "Library/MobileDevice/Provisioning Profiles",
        home / "Library/Developer/Xcode/UserData/Provisioning Profiles",
    )


def resolve_source_packages(repo_root: Path, explicit: str | None) -> Path | None:
    candidates = [
        explicit,
        os.environ.get("SOURCE_PACKAGES_PATH"),
        str(repo_root / ".build/fast-lane-release/SourcePackages"),
    ]
    for candidate in candidates:
        if candidate:
            path = Path(candidate).expanduser().resolve()
            if path.is_dir():
                return path
    return None


def print_human(payload: dict[str, Any]) -> None:
    print(f"Noum Apple signing/TestFlight preflight: {payload['verdict']}")
    for section in payload["sections"]:
        status = "PASS" if section["passed"] else "BLOCKED"
        print(
            f"\n{section['label']}: {status} "
            f"({section['passedCheckCount']}/{section['checkCount']})"
        )
        for item in section["checks"]:
            marker = "PASS" if item["passed"] else "BLOCKED"
            print(f"- {marker} {item['key']}: {item['observed']}")
            if not item["passed"]:
                print(f"  Next: {item['next_step']}")
    print(
        "\nBoundary: unsigned archives, simulator runs, and direct development installs "
        "are never TestFlight evidence."
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    archive_group = parser.add_mutually_exclusive_group()
    archive_group.add_argument(
        "--archive-path",
        help="Inspect an existing unsigned .xcarchive without modifying it.",
    )
    archive_group.add_argument(
        "--build-unsigned-archive",
        metavar="PATH",
        help="Build a new unsigned generic-iOS archive at PATH; refuses overwrite.",
    )
    parser.add_argument(
        "--derived-data",
        help="Derived-data path for --build-unsigned-archive.",
    )
    parser.add_argument(
        "--source-packages",
        help="Existing local SourcePackages cache; no package network resolution is attempted.",
    )
    parser.add_argument(
        "--evidence-dir",
        help="Existing coach-evidence dump validated by the current readiness gate.",
    )
    parser.add_argument("--json", action="store_true", help="Emit the redacted JSON report.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo_root = REPO_ROOT
    source_packages = resolve_source_packages(repo_root, args.source_packages)
    settings, settings_collected = collect_build_settings(repo_root, source_packages)
    source_commit = current_source_commit(repo_root)

    archive_path: Path | None = None
    build_check: Check | None = None
    if args.build_unsigned_archive:
        archive_path = Path(args.build_unsigned_archive).expanduser().resolve()
        derived_data = Path(
            args.derived_data
            or f"{args.build_unsigned_archive}.derivedData"
        ).expanduser().resolve()
        build_check = build_unsigned_archive(
            repo_root,
            archive_path,
            derived_data,
            source_packages,
            source_commit,
        )
        if not build_check.passed:
            archive_path = None
    elif args.archive_path:
        archive_path = Path(args.archive_path).expanduser().resolve()

    repo_checks = repository_checks(
        repo_root,
        settings,
        settings_collected,
        archive_path,
        expected_source_commit=source_commit,
    )
    if build_check is not None:
        repo_checks.insert(0, build_check)

    identities, distribution_fingerprints = collect_identity_authority()
    profiles, unreadable = load_profiles(default_profile_dirs())
    authority = authority_checks(
        settings,
        identities,
        profiles,
        unreadable,
        distribution_fingerprints=distribution_fingerprints,
    )

    evidence_dir_value = args.evidence_dir or os.environ.get("NOUM_COACH_EVAL_DUMP_DIR")
    evidence_dir = Path(evidence_dir_value).expanduser().resolve() if evidence_dir_value else None
    readiness = collect_readiness(repo_root, evidence_dir)
    evidence = evidence_checks(readiness)

    sections = (
        Section(
            key="repositoryBuildCorrectness",
            label="Repository/build correctness",
            checks=tuple(repo_checks),
        ),
        Section(
            key="localSigningAuthority",
            label="Local paid-team/provisioning authority",
            checks=tuple(authority),
        ),
        Section(
            key="externalTestFlightEvidence",
            label="External TestFlight/launch evidence",
            checks=tuple(evidence),
        ),
    )
    payload = result_payload(sections)
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print_human(payload)
    return 0 if payload["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
