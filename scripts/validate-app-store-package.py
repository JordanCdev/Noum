#!/usr/bin/env python3
"""Fail closed when Noum's source-controlled App Store package drifts.

Repository validation is the default. ``--verify-live-urls`` additionally
checks that every page at the app's active public origin returns the exact
reviewed source bytes. ``--verify-custom-domain-cutover`` checks both the
Firebase origin and the eventual custom origin before or after source cutover.

``--verify-release-assets`` verifies a separately filled release-asset
manifest, every bound file, image/video properties, and the clean Git binding.
``--verify-aso-experiment-results`` verifies a separately filled App Store
Connect product-page optimization result. The checked-in templates deliberately
cannot pass either evidence mode.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import struct
import subprocess
import sys
import zlib
from datetime import datetime
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from urllib.error import HTTPError, URLError
from urllib.request import Request


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "AppStore"
RELEASE_ASSET_TEMPLATE = PACKAGE / "release-assets.template.json"
ASO_EXPERIMENT_TEMPLATE = PACKAGE / "aso-experiment.template.json"

# The shared module keeps network response diagnostics content-free and bounds
# every body read. Add this script directory explicitly because unit tests load
# this file through importlib rather than invoking it as a script.
SCRIPT_DIRECTORY = Path(__file__).resolve().parent
if str(SCRIPT_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIRECTORY))
from privacy_body_verifier import (  # noqa: E402
    CUSTOM_HOSTING_ORIGIN,
    FIREBASE_HOSTING_ORIGIN,
    HOSTING_ORIGINS_BY_TARGET,
    MAX_HOSTED_PAGE_BODY_BYTES,
    active_hosting_target_from_source,
    build_no_redirect_opener,
    verify_hosted_page_response,
)

PUBLIC_PAGE_SOURCES = {
    "/": ROOT / "public" / "index.html",
    "/privacy": ROOT / "public" / "privacy.html",
    "/support": ROOT / "public" / "support.html",
    "/how-noum-coaches": ROOT / "public" / "how-noum-coaches.html",
}
APPROVED_PUBLIC_ORIGINS = frozenset({FIREBASE_HOSTING_ORIGIN, CUSTOM_HOSTING_ORIGIN})
NO_REDIRECT_OPENER = build_no_redirect_opener()

SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
GIT_COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){1,2}$")
FIXTURE_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{2,127}$")

DEFAULT_SCREENSHOT_IDS = (
    "default-01-pressure",
    "default-02-spoken-rep",
    "default-03-evidence",
    "default-04-next-move",
    "default-05-pattern-evidence",
    "default-06-real-moment",
    "default-07-privacy",
)
DEFAULT_SCREENSHOT_PURPOSES = (
    "Communicate clearly under pressure",
    "Complete a focused spoken rep",
    "See evidence from your own words",
    "Follow one next move",
    "Watch a pattern become evidence",
    "Prepare for the real moment",
    "Your words stay under your control",
)
CUSTOM_PAGE_LEADS = {
    "interview": "cpp-interview-01",
    "leadership-meetings": "cpp-leadership-meetings-01",
    "presentations": "cpp-presentations-01",
}
PPO_LEADS = {
    "evidence": "ppo-evidence-01",
    "pressure": "ppo-pressure-01",
    "plan": "ppo-plan-01",
}
EXPECTED_SCREENSHOT_IDS = set(DEFAULT_SCREENSHOT_IDS) | set(CUSTOM_PAGE_LEADS.values()) | set(PPO_LEADS.values())
EXPECTED_LOCALES = ["en-GB", "en-US"]
EXPECTED_STOREFRONTS = ["GB", "US"]
EXPECTED_ARM_IDS = ["default", "evidence", "pressure", "plan"]


def display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path)


def load(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise AssertionError(f"{display_path(path)} must contain a JSON object")
    return value


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def require_exact_keys(value: dict, expected: set[str], context: str) -> None:
    actual = set(value)
    require(actual == expected, f"{context}: expected keys {sorted(expected)}, received {sorted(actual)}")


def require_sha256(value: object, context: str) -> str:
    require(isinstance(value, str) and SHA256_PATTERN.fullmatch(value) is not None,
            f"{context}: SHA-256 must be 64 lowercase hexadecimal characters")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_bound_file(manifest_path: Path, relative_value: object, context: str) -> Path:
    require(isinstance(relative_value, str) and relative_value.strip(), f"{context}: file path is required")
    relative = Path(relative_value)
    require(not relative.is_absolute() and ".." not in relative.parts,
            f"{context}: file path must be relative and cannot traverse out of the evidence directory")
    base = manifest_path.resolve().parent
    unresolved = base / relative
    cursor = base
    for part in relative.parts:
        cursor /= part
        require(not cursor.is_symlink(), f"{context}: symlinked evidence paths are not accepted")
    candidate = unresolved.resolve()
    require(candidate == base or base in candidate.parents, f"{context}: file resolves outside the evidence directory")
    require(candidate.is_file() and not candidate.is_symlink(), f"{context}: bound file is missing or symlinked")
    require(candidate.stat().st_size > 0, f"{context}: bound file is empty")
    return candidate


def verify_bound_file(manifest_path: Path, relative_value: object, expected_sha: object, context: str) -> Path:
    path = resolve_bound_file(manifest_path, relative_value, context)
    expected = require_sha256(expected_sha, context)
    require(sha256_file(path) == expected, f"{context}: SHA-256 does not match {path.name}")
    return path


def parse_iso8601(value: object, context: str) -> datetime:
    require(isinstance(value, str) and value, f"{context}: timestamp is required")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise AssertionError(f"{context}: invalid ISO-8601 timestamp") from error
    require(parsed.tzinfo is not None, f"{context}: timestamp must include a timezone")
    return parsed


def require_url(value: object, host: str, context: str, query_key: str | None = None) -> str:
    require(isinstance(value, str) and value, f"{context}: URL is required")
    parsed = urlparse(value)
    require(parsed.scheme == "https" and parsed.hostname == host, f"{context}: expected an HTTPS {host} URL")
    if query_key is not None:
        require(bool(parse_qs(parsed.query).get(query_key)), f"{context}: URL must include {query_key}")
    return value


def read_image_properties(path: Path) -> tuple[int, int, bool]:
    data = path.read_bytes()
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        cursor = 8
        width = height = 0
        bit_depth = color_type = -1
        idat = bytearray()
        saw_header = False
        saw_end = False
        has_alpha = False
        while cursor + 12 <= len(data):
            length = struct.unpack(">I", data[cursor:cursor + 4])[0]
            chunk_type = data[cursor + 4:cursor + 8]
            require(cursor + 12 + length <= len(data), f"{path.name}: truncated PNG chunk")
            payload = data[cursor + 8:cursor + 8 + length]
            expected_crc = struct.unpack(">I", data[cursor + 8 + length:cursor + 12 + length])[0]
            require((zlib.crc32(chunk_type + payload) & 0xFFFFFFFF) == expected_crc,
                    f"{path.name}: invalid PNG chunk checksum")
            if not saw_header:
                require(chunk_type == b"IHDR" and length == 13, f"{path.name}: PNG must begin with IHDR")
                width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
                require(width > 0 and height > 0, f"{path.name}: invalid PNG dimensions")
                require(bit_depth == 8 and color_type in {0, 2, 3, 4, 6},
                        f"{path.name}: validator accepts only 8-bit PNG screenshots")
                require(compression == 0 and filtering == 0 and interlace == 0,
                        f"{path.name}: PNG must use standard non-interlaced encoding")
                has_alpha = color_type in {4, 6}
                saw_header = True
            if chunk_type == b"tRNS":
                has_alpha = True
            if chunk_type == b"IDAT":
                idat.extend(payload)
            cursor += 12 + length
            if chunk_type == b"IEND":
                require(length == 0, f"{path.name}: malformed PNG end chunk")
                saw_end = True
                break
        require(saw_header and saw_end and cursor == len(data) and idat,
                f"{path.name}: PNG is incomplete or has trailing bytes")
        channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
        try:
            pixels = zlib.decompress(bytes(idat))
        except zlib.error as error:
            raise AssertionError(f"{path.name}: PNG pixel data is invalid") from error
        row_size = 1 + width * channels
        require(len(pixels) == row_size * height, f"{path.name}: PNG pixel data has an unexpected size")
        require(all(pixels[offset] <= 4 for offset in range(0, len(pixels), row_size)),
                f"{path.name}: PNG contains an invalid scanline filter")
        return width, height, has_alpha

    if data.startswith(b"\xff\xd8"):
        require(data.endswith(b"\xff\xd9"), f"{path.name}: JPEG is missing its end marker")
        cursor = 2
        start_of_frame_markers = {
            0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
            0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF,
        }
        while cursor + 4 <= len(data):
            while cursor < len(data) and data[cursor] != 0xFF:
                cursor += 1
            while cursor < len(data) and data[cursor] == 0xFF:
                cursor += 1
            require(cursor < len(data), f"{path.name}: malformed JPEG")
            marker = data[cursor]
            cursor += 1
            if marker in {0xD8, 0xD9}:
                continue
            require(cursor + 2 <= len(data), f"{path.name}: malformed JPEG segment")
            length = struct.unpack(">H", data[cursor:cursor + 2])[0]
            require(length >= 2 and cursor + length <= len(data), f"{path.name}: malformed JPEG segment")
            if marker in start_of_frame_markers:
                require(length >= 7, f"{path.name}: malformed JPEG frame")
                height, width = struct.unpack(">HH", data[cursor + 3:cursor + 7])
                return width, height, False
            cursor += length
        raise AssertionError(f"{path.name}: JPEG dimensions were not found")

    raise AssertionError(f"{path.name}: screenshot must be PNG or JPEG")


def probe_video(path: Path) -> dict:
    executable = shutil.which("ffprobe")
    require(executable is not None, "ffprobe is required to verify release preview media")
    completed = subprocess.run(
        [
            executable,
            "-v", "error",
            "-show_entries", "stream=codec_name,profile,codec_tag_string,width,height,avg_frame_rate,duration:format=duration",
            "-of", "json",
            str(path),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    require(completed.returncode == 0, f"{path.name}: ffprobe failed ({completed.stderr.strip()})")
    try:
        value = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise AssertionError(f"{path.name}: ffprobe returned invalid JSON") from error
    require(isinstance(value, dict), f"{path.name}: ffprobe returned an invalid payload")
    return value


def frame_rate(value: object) -> float:
    require(isinstance(value, str) and value, "App preview frame rate is missing")
    try:
        if "/" in value:
            numerator, denominator = value.split("/", 1)
            require(float(denominator) != 0, "App preview frame rate denominator cannot be zero")
            return float(numerator) / float(denominator)
        return float(value)
    except ValueError as error:
        raise AssertionError("App preview frame rate is invalid") from error


def validate_video(path: Path, expected_width: int, expected_height: int, minimum: int, maximum: int) -> None:
    require(path.suffix.lower() in {".mov", ".m4v", ".mp4"},
            f"{path.name}: app preview must use .mov, .m4v, or .mp4")
    require(path.stat().st_size <= 500_000_000, f"{path.name}: app preview exceeds Apple's 500 MB limit")
    probe = probe_video(path)
    streams = probe.get("streams", [])
    videos = [item for item in streams if isinstance(item, dict) and item.get("width") is not None]
    require(len(videos) == 1, f"{path.name}: expected exactly one video stream")
    video = videos[0]
    require((video.get("width"), video.get("height")) == (expected_width, expected_height),
            f"{path.name}: expected {expected_width}x{expected_height} preview dimensions")
    codec = video.get("codec_name")
    require(codec in {"h264", "prores"}, f"{path.name}: preview codec must be H.264 or ProRes")
    if codec == "prores":
        profile = str(video.get("profile", "")).casefold()
        tag = str(video.get("codec_tag_string", "")).casefold()
        require("hq" in profile or tag == "apch", f"{path.name}: only ProRes 422 HQ is accepted")
    measured_frame_rate = frame_rate(video.get("avg_frame_rate"))
    require(0 < measured_frame_rate <= 30.01, f"{path.name}: preview frame rate must be positive and no more than 30 fps")
    raw_duration = video.get("duration") or probe.get("format", {}).get("duration")
    try:
        duration = float(raw_duration)
    except (TypeError, ValueError) as error:
        raise AssertionError(f"{path.name}: preview duration is missing") from error
    require(minimum <= duration <= maximum,
            f"{path.name}: preview duration must be between {minimum} and {maximum} seconds")


def active_public_origin() -> str:
    source_path = ROOT / "Noum" / "NoumWebURLs.swift"
    source = source_path.read_text(encoding="utf-8")
    try:
        origin = HOSTING_ORIGINS_BY_TARGET[active_hosting_target_from_source(source)]
    except ValueError as error:
        raise AssertionError(
            "NoumWebURLs.swift must declare exactly one approved literal hostingOrigin"
        ) from error
    required_routes = (
        'static let landing = hostingOrigin',
        'static let privacy = hostingOrigin.appendingPathComponent("privacy")',
        'static let support = hostingOrigin.appendingPathComponent("support")',
        'static let coachingMethod = hostingOrigin.appendingPathComponent("how-noum-coaches")',
    )
    require(all(fragment in source for fragment in required_routes),
            "NoumWebURLs public pages must all derive from the single hostingOrigin")
    return origin


def validate_metadata(path: Path, public_origin: str) -> None:
    value = load(path)
    name = value.get("name", "")
    subtitle = value.get("subtitle", "")
    promotional = value.get("promotionalText", "")
    description = value.get("description", "")
    keywords = value.get("keywords", [])

    require(0 < len(name) <= 30, f"{path.name}: name must be 1–30 characters")
    require(0 < len(subtitle) <= 30, f"{path.name}: subtitle must be 1–30 characters")
    require(len(promotional) <= 170, f"{path.name}: promotional text exceeds 170 characters")
    require(0 < len(description) <= 4_000, f"{path.name}: description must be 1–4,000 characters")
    require(isinstance(keywords, list) and all(isinstance(item, str) for item in keywords),
            f"{path.name}: keywords must be a string array")
    require(len(",".join(keywords)) <= 100, f"{path.name}: comma-separated keywords exceed 100 characters")

    for key, suffix in (
        ("supportURL", "/support"),
        ("privacyURL", "/privacy"),
        ("marketingURL", ""),
    ):
        expected = f"{public_origin}{suffix}"
        require(value.get(key) == expected, f"{path.name}: {key} must be {expected}")

    forbidden = (
        "best app",
        "guaranteed results",
        "guarantees results",
        "replaces a human coach",
        "clinically proven",
    )
    searchable = f"{name} {subtitle} {promotional} {description}".lower()
    for phrase in forbidden:
        require(phrase not in searchable, f"{path.name}: unsupported claim contains {phrase!r}")


def validate_product_pages() -> dict:
    value = load(PACKAGE / "product-pages.json")
    custom_pages = value.get("customProductPages", [])
    variants = value.get("productPageOptimization", [])
    require(len(custom_pages) == 3, "Exactly three custom product-page briefs are required")
    require(len(variants) == 3, "Exactly three product-page optimization variants are required")
    require(len({item.get("id") for item in custom_pages}) == 3, "Custom product-page IDs must be unique")
    require(len({item.get("id") for item in variants}) == 3, "Optimization variant IDs must be unique")
    require({item.get("id") for item in custom_pages} == set(CUSTOM_PAGE_LEADS),
            "Custom product-page IDs must match the release-asset contract")
    require({item.get("id") for item in variants} == set(PPO_LEADS),
            "Optimization variant IDs must match the release-asset contract")
    return value


def validate_device_targets(value: object, context: str) -> dict[str, dict]:
    require(isinstance(value, list) and len(value) == 2, f"{context}: exactly two device targets are required")
    targets: dict[str, dict] = {}
    for item in value:
        require(isinstance(item, dict), f"{context}: every device target must be an object")
        identifier = item.get("id")
        require(isinstance(identifier, str) and identifier not in targets,
                f"{context}: device target IDs must be unique strings")
        targets[identifier] = item

    screenshot = targets.get("iphone-6.9-1320x2868-portrait")
    require(screenshot == {
        "id": "iphone-6.9-1320x2868-portrait",
        "platform": "iOS",
        "displayClass": "6.9-inch",
        "orientation": "portrait",
        "widthPixels": 1320,
        "heightPixels": 2868,
        "screenshotFormat": "png-or-jpeg",
        "allowsAlpha": False,
    }, f"{context}: the primary 6.9-inch screenshot target drifted")
    preview = targets.get("iphone-preview-886x1920-portrait")
    require(preview == {
        "id": "iphone-preview-886x1920-portrait",
        "platform": "iOS",
        "displayClass": "iPhone-app-preview",
        "orientation": "portrait",
        "widthPixels": 886,
        "heightPixels": 1920,
        "previewFormat": "h264-or-prores422hq",
        "maximumFrameRate": 30,
    }, f"{context}: the iPhone preview target drifted")
    return targets


def validate_page_mapping(
    item: object,
    expected_id: str,
    expected_lead: str,
    all_asset_ids: set[str],
    context: str,
    is_custom_page: bool,
) -> None:
    require(isinstance(item, dict), f"{context}: mapping must be an object")
    link_key = "appStoreConnectDeepLink" if is_custom_page else "appStoreConnectTreatmentDeepLink"
    keys = {"id", link_key, "screenshotAssetIDs"}
    if is_custom_page:
        keys.add("publicProductPageURL")
    require_exact_keys(item, keys, context)
    require(item.get("id") == expected_id, f"{context}: unexpected page ID")
    asset_ids = item.get("screenshotAssetIDs")
    require(isinstance(asset_ids, list) and len(asset_ids) == 7,
            f"{context}: mapping must contain exactly seven screenshots")
    require(asset_ids == [expected_lead, *DEFAULT_SCREENSHOT_IDS[1:]],
            f"{context}: mapping must use its dedicated lead and default shots 2–7")
    require(len(set(asset_ids)) == 7 and set(asset_ids) <= all_asset_ids,
            f"{context}: mapping contains duplicate or unknown screenshot IDs")


def validate_release_asset_manifest(path: Path, verify_files: bool) -> None:
    value = load(path)
    context = display_path(path)
    require_exact_keys(
        value,
        {"schemaVersion", "templateStatus", "releaseBinding", "deviceTargets", "screenshotAssets", "pageMappings", "appPreview"},
        context,
    )
    require(value.get("schemaVersion") == 1, f"{context}: unsupported release-asset schema")
    expected_status = "COLLECTED_RELEASE_ASSETS" if verify_files else "TEMPLATE_NOT_RELEASE_EVIDENCE"
    require(value.get("templateStatus") == expected_status,
            f"{context}: status must be {expected_status}")
    targets = validate_device_targets(value.get("deviceTargets"), f"{context}.deviceTargets")

    binding = value.get("releaseBinding")
    require(isinstance(binding, dict), f"{context}.releaseBinding must be an object")
    require_exact_keys(
        binding,
        {
            "sourceGitCommit", "marketingVersion", "buildNumber", "fixtureID",
            "captureDistributionChannel", "releaseCandidateEvidencePath",
            "releaseCandidateEvidenceSha256", "sourceTreeClean",
        },
        f"{context}.releaseBinding",
    )

    raw_assets = value.get("screenshotAssets")
    require(isinstance(raw_assets, list) and len(raw_assets) == len(EXPECTED_SCREENSHOT_IDS),
            f"{context}: exactly {len(EXPECTED_SCREENSHOT_IDS)} screenshot assets are required")
    assets: dict[str, dict] = {}
    for index, item in enumerate(raw_assets):
        asset_context = f"{context}.screenshotAssets[{index}]"
        require(isinstance(item, dict), f"{asset_context}: asset must be an object")
        require_exact_keys(item, {"id", "sequence", "purpose", "deviceTargetID", "filePath", "sha256"}, asset_context)
        identifier = item.get("id")
        require(isinstance(identifier, str) and identifier not in assets,
                f"{asset_context}: asset ID must be a unique string")
        require(item.get("deviceTargetID") == "iphone-6.9-1320x2868-portrait",
                f"{asset_context}: screenshot must use the primary iPhone target")
        require(isinstance(item.get("purpose"), str) and item["purpose"].strip(),
                f"{asset_context}: purpose is required")
        expected_sequence = int(identifier.split("-", 2)[1]) if identifier.startswith("default-") else 1
        require(item.get("sequence") == expected_sequence, f"{asset_context}: sequence does not match its asset ID")
        assets[identifier] = item
    require(set(assets) == EXPECTED_SCREENSHOT_IDS, f"{context}: screenshot asset IDs do not match the contract")
    for identifier, purpose in zip(DEFAULT_SCREENSHOT_IDS, DEFAULT_SCREENSHOT_PURPOSES, strict=True):
        require(assets[identifier]["purpose"] == purpose, f"{context}: default screenshot purpose drifted for {identifier}")
    product_pages = load(PACKAGE / "product-pages.json")
    for item in product_pages["customProductPages"]:
        require(assets[CUSTOM_PAGE_LEADS[item["id"]]]["purpose"] == item["firstScreenshot"],
                f"{context}: custom product-page lead does not match product-pages.json")
    for item in product_pages["productPageOptimization"]:
        require(assets[PPO_LEADS[item["id"]]]["purpose"] == item["firstScreenshot"],
                f"{context}: PPO lead does not match product-pages.json")

    mappings = value.get("pageMappings")
    require(isinstance(mappings, dict), f"{context}.pageMappings must be an object")
    require_exact_keys(mappings, {"default", "customProductPages", "productPageOptimization"}, f"{context}.pageMappings")
    default = mappings.get("default")
    require(isinstance(default, dict), f"{context}.pageMappings.default must be an object")
    require_exact_keys(default, {"locales", "appStoreConnectDeepLink", "screenshotAssetIDs"}, f"{context}.pageMappings.default")
    require(default.get("locales") == EXPECTED_LOCALES, f"{context}: default mapping must cover en-GB and en-US")
    require(default.get("screenshotAssetIDs") == list(DEFAULT_SCREENSHOT_IDS),
            f"{context}: default page must map the seven-shot sequence in order")

    custom_pages = mappings.get("customProductPages")
    require(isinstance(custom_pages, list) and len(custom_pages) == 3,
            f"{context}: exactly three custom product-page mappings are required")
    custom_by_id = {item.get("id"): item for item in custom_pages if isinstance(item, dict)}
    require(set(custom_by_id) == set(CUSTOM_PAGE_LEADS), f"{context}: custom page mapping IDs drifted")
    for identifier, lead in CUSTOM_PAGE_LEADS.items():
        validate_page_mapping(
            custom_by_id[identifier], identifier, lead, set(assets),
            f"{context}.customProductPages.{identifier}", True,
        )

    variants = mappings.get("productPageOptimization")
    require(isinstance(variants, list) and len(variants) == 3,
            f"{context}: exactly three PPO mappings are required")
    variants_by_id = {item.get("id"): item for item in variants if isinstance(item, dict)}
    require(set(variants_by_id) == set(PPO_LEADS), f"{context}: PPO mapping IDs drifted")
    for identifier, lead in PPO_LEADS.items():
        validate_page_mapping(
            variants_by_id[identifier], identifier, lead, set(assets),
            f"{context}.productPageOptimization.{identifier}", False,
        )

    referenced_assets = set(default["screenshotAssetIDs"])
    for item in [*custom_pages, *variants]:
        referenced_assets.update(item["screenshotAssetIDs"])
    require(referenced_assets == set(assets), f"{context}: every declared screenshot must be mapped to a page")

    preview = value.get("appPreview")
    require(isinstance(preview, dict), f"{context}.appPreview must be an object")
    require_exact_keys(
        preview,
        {"id", "locales", "deviceTargetID", "minimumDurationSeconds", "maximumDurationSeconds", "filePath", "sha256"},
        f"{context}.appPreview",
    )
    require(preview.get("id") == "default-rep-evidence-next-action", f"{context}: preview ID drifted")
    require(preview.get("locales") == EXPECTED_LOCALES, f"{context}: preview must cover en-GB and en-US")
    require(preview.get("deviceTargetID") == "iphone-preview-886x1920-portrait",
            f"{context}: preview device target drifted")
    require(preview.get("minimumDurationSeconds") == 20 and preview.get("maximumDurationSeconds") == 30,
            f"{context}: preview must enforce the planned 20–30 second window")

    if not verify_files:
        for key in (
            "sourceGitCommit", "marketingVersion", "buildNumber", "fixtureID",
            "captureDistributionChannel", "releaseCandidateEvidencePath", "releaseCandidateEvidenceSha256",
        ):
            require(binding.get(key) == "", f"{context}: template binding {key} must remain empty")
        require(binding.get("sourceTreeClean") is False, f"{context}: template cannot claim a clean binding")
        for item in assets.values():
            require(item.get("filePath") == "" and item.get("sha256") == "",
                    f"{context}: checked-in template cannot contain screenshot evidence")
        require(preview.get("filePath") == "" and preview.get("sha256") == "",
                f"{context}: checked-in template cannot contain preview evidence")
        require(default.get("appStoreConnectDeepLink") == "",
                f"{context}: checked-in template cannot claim an App Store Connect listing")
        for item in custom_pages:
            require(item.get("appStoreConnectDeepLink") == "" and item.get("publicProductPageURL") == "",
                    f"{context}: checked-in template cannot claim a custom product page")
        for item in variants:
            require(item.get("appStoreConnectTreatmentDeepLink") == "",
                    f"{context}: checked-in template cannot claim a PPO treatment")
        return

    commit = binding.get("sourceGitCommit")
    require(isinstance(commit, str) and GIT_COMMIT_PATTERN.fullmatch(commit) is not None,
            f"{context}: exact source Git commit is required")
    require(isinstance(binding.get("marketingVersion"), str) and VERSION_PATTERN.fullmatch(binding["marketingVersion"]) is not None,
            f"{context}: marketing version must be numeric dotted version")
    require(isinstance(binding.get("buildNumber"), str) and binding["buildNumber"].isdigit(),
            f"{context}: build number must be a numeric string")
    require(isinstance(binding.get("fixtureID"), str) and FIXTURE_PATTERN.fullmatch(binding["fixtureID"]) is not None,
            f"{context}: deidentified fixture ID is required")
    require(binding.get("captureDistributionChannel") == "TestFlight",
            f"{context}: final media must be captured from the signed TestFlight candidate")
    require(binding.get("sourceTreeClean") is True, f"{context}: manifest must attest a clean source tree")
    verify_bound_file(
        path, binding.get("releaseCandidateEvidencePath"), binding.get("releaseCandidateEvidenceSha256"),
        f"{context}.releaseBinding.releaseCandidateEvidence",
    )

    git_commit = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True, capture_output=True, text=True,
    ).stdout.strip()
    require(commit == git_commit, f"{context}: source commit does not match the current checkout")
    dirty = subprocess.run(
        ["git", "status", "--porcelain", "--untracked-files=all"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    require(not dirty, f"{context}: release assets require a completely clean source checkout")

    screenshot_paths: set[Path] = set()
    screenshot_hashes: set[str] = set()
    target = targets["iphone-6.9-1320x2868-portrait"]
    for identifier, item in assets.items():
        asset_context = f"{context}.screenshotAssets.{identifier}"
        screenshot_path = verify_bound_file(path, item.get("filePath"), item.get("sha256"), asset_context)
        require(screenshot_path.suffix.lower() in {".png", ".jpg", ".jpeg"},
                f"{asset_context}: screenshot extension must be PNG or JPEG")
        require(screenshot_path not in screenshot_paths, f"{asset_context}: each asset must use a distinct file path")
        require(item["sha256"] not in screenshot_hashes, f"{asset_context}: duplicate screenshot content is not accepted")
        screenshot_paths.add(screenshot_path)
        screenshot_hashes.add(item["sha256"])
        width, height, has_alpha = read_image_properties(screenshot_path)
        require((width, height) == (target["widthPixels"], target["heightPixels"]),
                f"{asset_context}: expected {target['widthPixels']}x{target['heightPixels']} pixels")
        require(not has_alpha, f"{asset_context}: App Store screenshots cannot contain alpha/transparency")

    require_url(default.get("appStoreConnectDeepLink"), "appstoreconnect.apple.com",
                f"{context}.pageMappings.default.appStoreConnectDeepLink")
    for item in custom_pages:
        identifier = item["id"]
        require_url(item.get("appStoreConnectDeepLink"), "appstoreconnect.apple.com",
                    f"{context}.customProductPages.{identifier}.appStoreConnectDeepLink")
        require_url(item.get("publicProductPageURL"), "apps.apple.com",
                    f"{context}.customProductPages.{identifier}.publicProductPageURL", "ppid")
    for item in variants:
        require_url(item.get("appStoreConnectTreatmentDeepLink"), "appstoreconnect.apple.com",
                    f"{context}.productPageOptimization.{item['id']}.appStoreConnectTreatmentDeepLink")

    preview_path = verify_bound_file(path, preview.get("filePath"), preview.get("sha256"), f"{context}.appPreview")
    preview_target = targets["iphone-preview-886x1920-portrait"]
    validate_video(
        preview_path,
        preview_target["widthPixels"],
        preview_target["heightPixels"],
        preview["minimumDurationSeconds"],
        preview["maximumDurationSeconds"],
    )


def validate_aso_experiment_manifest(path: Path, verify_results: bool) -> None:
    value = load(path)
    context = display_path(path)
    require_exact_keys(value, {"schemaVersion", "templateStatus", "experiment", "results"}, context)
    require(value.get("schemaVersion") == 1, f"{context}: unsupported ASO experiment schema")
    expected_status = "COLLECTED_ASO_EXPERIMENT_EVIDENCE" if verify_results else "TEMPLATE_NOT_EXPERIMENT_EVIDENCE"
    require(value.get("templateStatus") == expected_status, f"{context}: status must be {expected_status}")

    experiment = value.get("experiment")
    require(isinstance(experiment, dict), f"{context}.experiment must be an object")
    require_exact_keys(
        experiment,
        {
            "experimentID", "appStoreConnectExperimentDeepLink", "hypothesis", "platform",
            "appVersion", "sourceGitCommit", "storefronts", "controlArmID", "treatmentArmIDs",
            "primaryMetric", "decisionRequirements", "startedAtISO8601", "endedAtISO8601",
        },
        f"{context}.experiment",
    )
    require(isinstance(experiment.get("hypothesis"), str) and len(experiment["hypothesis"].strip()) >= 30,
            f"{context}: a falsifiable experiment hypothesis is required")
    require(experiment.get("platform") == "iOS", f"{context}: launch experiment platform must be iOS")
    require(experiment.get("storefronts") == EXPECTED_STOREFRONTS,
            f"{context}: results must be pre-registered for GB and US storefronts")
    require(experiment.get("controlArmID") == "default", f"{context}: default must remain the control arm")
    require(experiment.get("treatmentArmIDs") == EXPECTED_ARM_IDS[1:],
            f"{context}: treatment arms must match the three PPO briefs")
    require(experiment.get("primaryMetric") == {
        "denominator": "uniqueImpressions",
        "numerator": "firstTimeDownloads",
    }, f"{context}: the conversion numerator/denominator contract drifted")
    requirements = experiment.get("decisionRequirements")
    require(isinstance(requirements, dict), f"{context}: decision requirements must be an object")
    require_exact_keys(
        requirements,
        {
            "minimumObservationWindowDays", "maximumObservationWindowDays",
            "minimumUniqueImpressionsPerArmPerStorefront", "minimumAppleConfidenceBasisPointsForWinner",
            "requireSingleAppVersion", "requireStorefrontBreakdown",
            "requireAppStoreConnectResultExport", "requireIndependentVerification",
        },
        f"{context}.experiment.decisionRequirements",
    )
    fixed_requirements = {
        "minimumObservationWindowDays": 7,
        "maximumObservationWindowDays": 90,
        "minimumAppleConfidenceBasisPointsForWinner": 9000,
        "requireSingleAppVersion": True,
        "requireStorefrontBreakdown": True,
        "requireAppStoreConnectResultExport": True,
        "requireIndependentVerification": True,
    }
    require(all(requirements.get(key) == expected for key, expected in fixed_requirements.items()),
            f"{context}: fixed decision requirements drifted")
    registered_denominator = requirements.get("minimumUniqueImpressionsPerArmPerStorefront")
    if verify_results:
        require(isinstance(registered_denominator, int) and not isinstance(registered_denominator, bool)
                and registered_denominator > 0,
                f"{context}: a positive per-arm/storefront denominator must be pre-registered")
    else:
        require(registered_denominator is None,
                f"{context}: template denominator must remain unset until App Store Connect estimates traffic")

    results = value.get("results")
    require(isinstance(results, dict), f"{context}.results must be an object")
    require_exact_keys(
        results,
        {
            "rows", "armSummaries", "appStoreConnectResultExportPath", "appStoreConnectResultExportSha256",
            "decision", "selectedArmID", "decisionRationale", "decidedAtISO8601", "decidedByID",
            "verifiedAtISO8601", "verifiedByID", "decisionRecordPath", "decisionRecordSha256",
        },
        f"{context}.results",
    )

    if not verify_results:
        for key in (
            "experimentID", "appStoreConnectExperimentDeepLink", "appVersion", "sourceGitCommit",
            "startedAtISO8601", "endedAtISO8601",
        ):
            require(experiment.get(key) == "", f"{context}: template experiment {key} must remain empty")
        require(results.get("rows") == [] and results.get("armSummaries") == [] and results.get("decision") == "pending",
                f"{context}: checked-in template cannot claim PPO results")
        for key in (
            "appStoreConnectResultExportPath", "appStoreConnectResultExportSha256", "selectedArmID",
            "decisionRationale", "decidedAtISO8601", "decidedByID", "verifiedAtISO8601",
            "verifiedByID", "decisionRecordPath", "decisionRecordSha256",
        ):
            require(results.get(key) == "", f"{context}: template result {key} must remain empty")
        return

    require(isinstance(experiment.get("experimentID"), str) and FIXTURE_PATTERN.fullmatch(experiment["experimentID"]) is not None,
            f"{context}: stable experiment ID is required")
    require_url(experiment.get("appStoreConnectExperimentDeepLink"), "appstoreconnect.apple.com",
                f"{context}.experiment.appStoreConnectExperimentDeepLink")
    require(isinstance(experiment.get("appVersion"), str) and VERSION_PATTERN.fullmatch(experiment["appVersion"]) is not None,
            f"{context}: exact app version is required")
    commit = experiment.get("sourceGitCommit")
    require(isinstance(commit, str) and GIT_COMMIT_PATTERN.fullmatch(commit) is not None,
            f"{context}: exact source commit is required")
    commit_check = subprocess.run(
        ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    require(commit_check.returncode == 0, f"{context}: source commit does not resolve in this repository")

    started = parse_iso8601(experiment.get("startedAtISO8601"), f"{context}.experiment.startedAtISO8601")
    ended = parse_iso8601(experiment.get("endedAtISO8601"), f"{context}.experiment.endedAtISO8601")
    duration_days = (ended - started).total_seconds() / 86_400
    require(requirements["minimumObservationWindowDays"] <= duration_days <= requirements["maximumObservationWindowDays"],
            f"{context}: experiment window must be 7–90 complete days")

    rows = results.get("rows")
    expected_pairs = {(storefront, arm) for storefront in EXPECTED_STOREFRONTS for arm in EXPECTED_ARM_IDS}
    require(isinstance(rows, list) and len(rows) == len(expected_pairs),
            f"{context}: one result row per storefront and arm is required")
    seen_pairs: set[tuple[str, str]] = set()
    all_denominators_met = True
    for index, row in enumerate(rows):
        row_context = f"{context}.results.rows[{index}]"
        require(isinstance(row, dict), f"{row_context}: row must be an object")
        require_exact_keys(row, {"storefront", "armID", "uniqueImpressions", "firstTimeDownloads"}, row_context)
        pair = (row.get("storefront"), row.get("armID"))
        require(pair in expected_pairs and pair not in seen_pairs, f"{row_context}: duplicate or unknown storefront/arm")
        seen_pairs.add(pair)
        denominator = row.get("uniqueImpressions")
        numerator = row.get("firstTimeDownloads")
        require(isinstance(denominator, int) and not isinstance(denominator, bool) and denominator >= 0,
                f"{row_context}: unique impressions must be a nonnegative integer")
        require(isinstance(numerator, int) and not isinstance(numerator, bool) and 0 <= numerator <= denominator,
                f"{row_context}: first-time downloads must be between zero and views")
        all_denominators_met = all_denominators_met and denominator >= registered_denominator
    require(seen_pairs == expected_pairs, f"{context}: result matrix is incomplete")

    summaries = results.get("armSummaries")
    require(isinstance(summaries, list) and len(summaries) == len(EXPECTED_ARM_IDS),
            f"{context}: one Apple result summary per arm is required")
    summaries_by_arm: dict[str, dict] = {}
    allowed_statuses = {"baseline", "performing-better", "performing-worse", "collecting-data", "likely-inconclusive"}
    for index, summary in enumerate(summaries):
        summary_context = f"{context}.results.armSummaries[{index}]"
        require(isinstance(summary, dict), f"{summary_context}: summary must be an object")
        require_exact_keys(
            summary,
            {
                "armID", "uniqueImpressions", "estimatedConversionRateBasisPoints",
                "estimatedRelativeLiftBasisPoints", "confidenceBasisPoints", "appleStatus",
            },
            summary_context,
        )
        arm = summary.get("armID")
        require(arm in EXPECTED_ARM_IDS and arm not in summaries_by_arm,
                f"{summary_context}: duplicate or unknown arm")
        require(isinstance(summary.get("uniqueImpressions"), int) and not isinstance(summary["uniqueImpressions"], bool)
                and summary["uniqueImpressions"] >= 0,
                f"{summary_context}: unique impressions must be a nonnegative integer")
        conversion = summary.get("estimatedConversionRateBasisPoints")
        lift = summary.get("estimatedRelativeLiftBasisPoints")
        require(isinstance(conversion, int) and not isinstance(conversion, bool) and 0 <= conversion <= 10_000,
                f"{summary_context}: estimated conversion rate must be 0–10,000 basis points")
        require(isinstance(lift, int) and not isinstance(lift, bool) and lift >= -10_000,
                f"{summary_context}: relative lift must be an integer no lower than -10,000 basis points")
        status = summary.get("appleStatus")
        require(status in allowed_statuses, f"{summary_context}: unknown Apple performance status")
        confidence = summary.get("confidenceBasisPoints")
        if arm == "default":
            require(status == "baseline" and confidence is None and lift == 0,
                    f"{summary_context}: default arm must be the confidence-free baseline")
        else:
            require(status != "baseline", f"{summary_context}: only default can be the baseline")
            require(isinstance(confidence, int) and not isinstance(confidence, bool) and 0 <= confidence <= 10_000,
                    f"{summary_context}: treatment confidence must be 0–10,000 basis points")
            if status in {"performing-better", "performing-worse"}:
                require(confidence >= requirements["minimumAppleConfidenceBasisPointsForWinner"],
                        f"{summary_context}: Apple better/worse status requires at least 90% confidence")
        summaries_by_arm[arm] = summary
    require(set(summaries_by_arm) == set(EXPECTED_ARM_IDS), f"{context}: Apple arm summary matrix is incomplete")

    result_export = verify_bound_file(
        path,
        results.get("appStoreConnectResultExportPath"),
        results.get("appStoreConnectResultExportSha256"),
        f"{context}.results.appStoreConnectResultExport",
    )
    require(result_export.suffix.lower() in {".csv", ".json", ".pdf"},
            f"{context}: App Store Connect result export must be CSV, JSON, or PDF")
    decision_record = verify_bound_file(
        path,
        results.get("decisionRecordPath"),
        results.get("decisionRecordSha256"),
        f"{context}.results.decisionRecord",
    )
    require(decision_record.suffix.lower() in {".json", ".pdf", ".txt", ".md"},
            f"{context}: decision record must be a reviewable JSON, PDF, text, or Markdown file")

    decision = results.get("decision")
    require(decision in {"adopt-treatment", "retain-control", "inconclusive"},
            f"{context}: final decision must adopt a treatment, retain control, or remain inconclusive")
    selected = results.get("selectedArmID")
    if decision == "adopt-treatment":
        require(all_denominators_met, f"{context}: a treatment cannot be adopted below the registered denominator")
        require(selected in EXPECTED_ARM_IDS[1:], f"{context}: adopted treatment must name a PPO arm")
        selected_summary = summaries_by_arm[selected]
        require(
            selected_summary["appleStatus"] == "performing-better"
            and selected_summary["confidenceBasisPoints"] >= requirements["minimumAppleConfidenceBasisPointsForWinner"],
            f"{context}: adopted treatment must be Apple's performing-better result at 90%+ confidence",
        )
    elif decision == "retain-control":
        require(all_denominators_met, f"{context}: control cannot be retained as winner below the registered denominator")
        require(selected == "default", f"{context}: retain-control decision must select default")
        require(
            not any(
                summary["appleStatus"] == "performing-better"
                and summary["confidenceBasisPoints"] >= requirements["minimumAppleConfidenceBasisPointsForWinner"]
                for arm, summary in summaries_by_arm.items() if arm != "default"
            ),
            f"{context}: control cannot be retained while Apple marks a treatment performing better",
        )
    else:
        require(selected == "", f"{context}: inconclusive result cannot select a winning arm")
    require(isinstance(results.get("decisionRationale"), str) and len(results["decisionRationale"].strip()) >= 30,
            f"{context}: decision rationale is required")
    decided = parse_iso8601(results.get("decidedAtISO8601"), f"{context}.results.decidedAtISO8601")
    verified = parse_iso8601(results.get("verifiedAtISO8601"), f"{context}.results.verifiedAtISO8601")
    require(decided >= ended and verified >= decided,
            f"{context}: decision and verification must follow the experiment window")
    decider = results.get("decidedByID")
    verifier = results.get("verifiedByID")
    require(isinstance(decider, str) and decider.strip() and isinstance(verifier, str) and verifier.strip(),
            f"{context}: decision-maker and verifier IDs are required")
    require(decider != verifier, f"{context}: PPO result requires independent verification")


def validate_hosting_sources() -> None:
    firebase = load(ROOT / "firebase.json")
    rewrites = {
        item.get("source"): item.get("destination")
        for item in firebase.get("hosting", {}).get("rewrites", [])
    }
    expected = {
        "/privacy": "/privacy.html",
        "/support": "/support.html",
        "/how-noum-coaches": "/how-noum-coaches.html",
    }
    require(all(rewrites.get(source) == target for source, target in expected.items()),
            "Firebase Hosting rewrites are missing a required public launch page")
    for route, source in PUBLIC_PAGE_SOURCES.items():
        require(source.is_file(), f"Missing hosted source for {route}: {display_path(source)}")


def open_live_url(request: Request, timeout: int):
    """Open one response while leaving any HTTP redirect as a 3xx error."""

    return NO_REDIRECT_OPENER.open(request, timeout=timeout)


def validate_live_origin(origin: str) -> None:
    require(origin in APPROVED_PUBLIC_ORIGINS,
            f"{origin}: live verification accepts only approved Noum Hosting origins")
    for route, source in PUBLIC_PAGE_SOURCES.items():
        url = f"{origin}{route}"
        request = Request(url, headers={"User-Agent": "NoumReleaseValidator/1.0"})
        try:
            with open_live_url(request, timeout=12) as response:
                status = response.status
                content_type = response.headers.get("Content-Type", "")
                final_url = response.geturl()
                observed_body = response.read(MAX_HOSTED_PAGE_BODY_BYTES + 1)
        except HTTPError as error:
            status = error.code
            content_type = error.headers.get("Content-Type", "") if error.headers else ""
            final_url = error.geturl() or url
            observed_body = error.read(MAX_HOSTED_PAGE_BODY_BYTES + 1)
            error.close()
        except (URLError, TimeoutError) as error:
            raise AssertionError(
                f"{url}: approved Hosting page is unreachable ({type(error).__name__})"
            ) from error
        observed_complete = len(observed_body) <= MAX_HOSTED_PAGE_BODY_BYTES
        verification = verify_hosted_page_response(
            expected_body=source.read_bytes(),
            observed_body=observed_body,
            requested_url=url,
            final_url=final_url,
            status=status,
            content_type=content_type,
            redirect_count=0,
            observed_complete=observed_complete,
            observed_size=len(observed_body),
        )
        require(
            verification.passed,
            f"{url}: exact-body verification failed ({','.join(verification.errors)}; "
            f"{verification.safe_body_observation})",
        )


def validate_live_urls(public_origin: str, *, include_cutover_pair: bool = False) -> None:
    origins = [public_origin]
    if include_cutover_pair:
        origins = [FIREBASE_HOSTING_ORIGIN, CUSTOM_HOSTING_ORIGIN]
    for origin in dict.fromkeys(origins):
        validate_live_origin(origin)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--verify-live-urls",
        action="store_true",
        help="Require all four pages at the app's active origin to match exact source bytes",
    )
    parser.add_argument(
        "--verify-custom-domain-cutover",
        action="store_true",
        help="Require all four pages at both Firebase Hosting and noum.app to match exact source bytes",
    )
    parser.add_argument(
        "--verify-release-assets",
        type=Path,
        metavar="MANIFEST",
        help="Verify a filled release-asset manifest, its files, media properties, links, and clean source binding",
    )
    parser.add_argument(
        "--verify-aso-experiment-results",
        type=Path,
        metavar="MANIFEST",
        help="Verify a filled App Store Connect product-page optimization result manifest",
    )
    arguments = parser.parse_args()
    public_origin = active_public_origin()
    metadata = sorted((PACKAGE / "metadata").glob("*.json"))
    require({path.stem for path in metadata} == {"en-GB", "en-US"},
            "The launch package must contain exactly en-GB and en-US metadata")
    for path in metadata:
        validate_metadata(path, public_origin)
    validate_product_pages()
    validate_release_asset_manifest(RELEASE_ASSET_TEMPLATE, verify_files=False)
    validate_aso_experiment_manifest(ASO_EXPERIMENT_TEMPLATE, verify_results=False)
    validate_hosting_sources()
    if arguments.verify_live_urls or arguments.verify_custom_domain_cutover:
        validate_live_urls(
            public_origin,
            include_cutover_pair=arguments.verify_custom_domain_cutover,
        )
    if arguments.verify_release_assets is not None:
        validate_release_asset_manifest(arguments.verify_release_assets.resolve(), verify_files=True)
    if arguments.verify_aso_experiment_results is not None:
        validate_aso_experiment_manifest(arguments.verify_aso_experiment_results.resolve(), verify_results=True)
    require((PACKAGE / "screenshot-brief.md").is_file(), "Missing screenshot brief")
    require((PACKAGE / "launch-gates.md").is_file(), "Missing launch/growth gate contract")
    verified = []
    if arguments.verify_live_urls:
        verified.append("active live public origin")
    if arguments.verify_custom_domain_cutover:
        verified.append("Firebase/custom-domain exact-body cutover")
    if arguments.verify_release_assets is not None:
        verified.append("release assets")
    if arguments.verify_aso_experiment_results is not None:
        verified.append("ASO experiment results")
    suffix = f" with {', '.join(verified)}" if verified else ""
    print(f"App Store package validation passed{suffix}")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as error:
        print(f"App Store package validation failed: {error}", file=sys.stderr)
        raise SystemExit(1) from None
