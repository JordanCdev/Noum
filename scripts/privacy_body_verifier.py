#!/usr/bin/env python3
"""Fail-closed verification for Noum's public Hosting responses.

The caller owns transport. This module owns the shared response contract used
by the shell operator probe and the App Store package validator. It never
returns or prints response text in diagnostics. The legacy filename is retained
because release automation imports it directly.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit


MAX_HOSTED_PAGE_BODY_BYTES = 256 * 1024
# Compatibility for existing callers while the verifier now covers every
# public launch page rather than privacy alone.
MAX_PRIVACY_BODY_BYTES = MAX_HOSTED_PAGE_BODY_BYTES

FIREBASE_HOSTING_ORIGIN = "https://noum-d0b6f.web.app"
CUSTOM_HOSTING_ORIGIN = "https://noum.app"
APPROVED_HOSTING_HTTPS_ORIGINS = frozenset({
    ("https", "noum-d0b6f.web.app", 443),
    ("https", "noum.app", 443),
})
# Compatibility for tests and integrations that use the original name.
APPROVED_PRIVACY_HTTPS_ORIGINS = APPROVED_HOSTING_HTTPS_ORIGINS


def sha256_hex(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _https_origin(url: str) -> tuple[str, str, int] | None:
    try:
        parsed = urlsplit(url)
        port = parsed.port
    except (TypeError, ValueError):
        return None
    if (
        parsed.scheme.lower() != "https"
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
    ):
        return None
    return ("https", parsed.hostname.lower().rstrip("."), port or 443)


def approved_https_origin_matches(requested_url: str, final_url: str) -> bool:
    """Return true only when a response stays on an approved HTTPS origin."""

    requested_origin = _https_origin(requested_url)
    final_origin = _https_origin(final_url)
    return (
        requested_origin in APPROVED_HOSTING_HTTPS_ORIGINS
        and requested_origin == final_origin
    )


@dataclass(frozen=True)
class HostedPageBodyVerification:
    errors: tuple[str, ...]
    expected_sha256: str
    observed_sha256: str | None
    expected_size: int
    observed_size: int
    observed_complete: bool

    @property
    def passed(self) -> bool:
        return not self.errors

    @property
    def safe_body_observation(self) -> str:
        observed_hash = self.observed_sha256 or "unavailable-incomplete"
        size_prefix = "" if self.observed_complete else ">="
        return (
            f"expectedSHA256={self.expected_sha256},"
            f"observedSHA256={observed_hash},"
            f"expectedBytes={self.expected_size},"
            f"observedBytes={size_prefix}{self.observed_size}"
        )


def verify_hosted_page_response(
    *,
    expected_body: bytes,
    observed_body: bytes,
    requested_url: str,
    final_url: str,
    status: int,
    content_type: str,
    max_body_bytes: int = MAX_HOSTED_PAGE_BODY_BYTES,
    observed_complete: bool = True,
    observed_size: int | None = None,
) -> HostedPageBodyVerification:
    """Verify response metadata and exact bytes without exposing body content."""

    if max_body_bytes <= 0:
        raise ValueError("max_body_bytes must be positive")

    errors: list[str] = []
    requested_origin = _https_origin(requested_url)
    final_origin = _https_origin(final_url)
    if requested_origin not in APPROVED_HOSTING_HTTPS_ORIGINS:
        errors.append("requestedURLNotApprovedHTTPS")
    if requested_origin != final_origin:
        errors.append("redirectOriginEscape")
    if not isinstance(status, int) or status != 200:
        errors.append("httpStatusNotSuccessful")

    normalized_content_type = (content_type or "").split(";", 1)[0].strip().lower()
    if normalized_content_type != "text/html":
        errors.append("contentTypeNotHTML")

    expected_size = len(expected_body)
    reported_observed_size = observed_size if observed_size is not None else len(observed_body)
    if expected_size > max_body_bytes:
        errors.append("expectedBodyOversize")
    if (
        not observed_complete
        or reported_observed_size > max_body_bytes
        or len(observed_body) > max_body_bytes
    ):
        errors.append("responseBodyOversize")

    bodies_are_comparable = (
        expected_size <= max_body_bytes
        and observed_complete
        and reported_observed_size <= max_body_bytes
        and len(observed_body) <= max_body_bytes
    )
    if bodies_are_comparable and observed_body != expected_body:
        errors.append("bodyMismatch")

    return HostedPageBodyVerification(
        errors=tuple(dict.fromkeys(errors)),
        expected_sha256=sha256_hex(expected_body),
        observed_sha256=sha256_hex(observed_body) if observed_complete else None,
        expected_size=expected_size,
        observed_size=reported_observed_size,
        observed_complete=observed_complete,
    )


# Compatibility aliases keep older release tooling source-compatible while all
# new callers use the generic four-page contract.
PrivacyBodyVerification = HostedPageBodyVerification


def verify_privacy_response(**arguments) -> HostedPageBodyVerification:
    return verify_hosted_page_response(**arguments)


def _read_observed_file(path: Path, max_body_bytes: int) -> tuple[bytes, bool, int]:
    observed_size = path.stat().st_size
    if observed_size > max_body_bytes:
        with path.open("rb") as handle:
            return handle.read(max_body_bytes + 1), False, observed_size
    return path.read_bytes(), True, observed_size


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Verify a hosted launch page against its exact source body."
    )
    parser.add_argument("--print-max-body-bytes", action="store_true")
    parser.add_argument("--expected-body", type=Path)
    parser.add_argument("--observed-body", type=Path)
    parser.add_argument("--requested-url")
    parser.add_argument("--final-url")
    parser.add_argument("--status", type=int)
    parser.add_argument("--content-type")
    parser.add_argument(
        "--page-id",
        choices=("homepage", "privacy", "support", "coaching-method"),
        default="privacy",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    arguments = parser.parse_args(argv)
    if arguments.print_max_body_bytes:
        print(MAX_HOSTED_PAGE_BODY_BYTES)
        return 0

    required = {
        "--expected-body": arguments.expected_body,
        "--observed-body": arguments.observed_body,
        "--requested-url": arguments.requested_url,
        "--final-url": arguments.final_url,
        "--status": arguments.status,
        "--content-type": arguments.content_type,
    }
    missing = [flag for flag, value in required.items() if value is None]
    if missing:
        parser.error("missing required arguments: " + ", ".join(missing))

    try:
        expected_body = arguments.expected_body.read_bytes()
        observed_body, observed_complete, observed_size = _read_observed_file(
            arguments.observed_body,
            MAX_HOSTED_PAGE_BODY_BYTES,
        )
    except OSError as error:
        print(
            f"Hosted page verification could not read its source files: {type(error).__name__}",
            file=sys.stderr,
        )
        return 2

    verification = verify_hosted_page_response(
        expected_body=expected_body,
        observed_body=observed_body,
        requested_url=arguments.requested_url,
        final_url=arguments.final_url,
        status=arguments.status,
        content_type=arguments.content_type,
        observed_complete=observed_complete,
        observed_size=observed_size,
    )
    page_label = {
        "homepage": "homepage",
        "privacy": "privacy policy",
        "support": "support page",
        "coaching-method": "coaching-method page",
    }[arguments.page_id]
    if verification.passed:
        print(f"Live {page_label} exact-body verification passed.")
        print(verification.safe_body_observation)
        return 0

    print(
        f"Live {page_label} exact-body verification failed: "
        + ",".join(verification.errors),
        file=sys.stderr,
    )
    print(verification.safe_body_observation, file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
