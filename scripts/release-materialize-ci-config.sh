#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
info_path="$repo_root/Noum/Info.plist"
google_path="$repo_root/Noum/GoogleService-Info.plist"

if [[ "${1:-}" == "--clean" ]]; then
  rm -f "$info_path" "$google_path" "$info_path.tmp" "$google_path.tmp"
  exit 0
fi

if [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--clean]" >&2
  exit 2
fi

umask 077
python3 - "$info_path" "$google_path" <<'PY'
import base64
import binascii
import os
import plistlib
import sys
from pathlib import Path

targets = [
    (
        "NOUM_INFO_PLIST_BASE64",
        Path(sys.argv[1]),
        {
            "CFBundleURLTypes",
            "NSCameraUsageDescription",
            "NSMicrophoneUsageDescription",
            "NSSpeechRecognitionUsageDescription",
        },
    ),
    (
        "NOUM_GOOGLE_SERVICE_INFO_PLIST_BASE64",
        Path(sys.argv[2]),
        {
            "API_KEY",
            "BUNDLE_ID",
            "CLIENT_ID",
            "GOOGLE_APP_ID",
            "PROJECT_ID",
            "REVERSED_CLIENT_ID",
        },
    ),
]

missing = [name for name, _, _ in targets if not os.environ.get(name, "").strip()]
if missing:
    print(
        "Missing required GitHub Actions secrets: " + ", ".join(missing),
        file=sys.stderr,
    )
    print(
        "Store each complete plist as single-line base64; no fallback values "
        "are accepted.",
        file=sys.stderr,
    )
    raise SystemExit(2)

decoded = {}
for name, path, required_keys in targets:
    try:
        raw = base64.b64decode(os.environ[name].strip(), validate=True)
    except (ValueError, binascii.Error):
        print(f"{name} is not valid base64.", file=sys.stderr)
        raise SystemExit(2)
    try:
        value = plistlib.loads(raw)
    except plistlib.InvalidFileException:
        print(f"{name} does not contain a valid plist.", file=sys.stderr)
        raise SystemExit(2)
    if not isinstance(value, dict):
        print(f"{name} must decode to a plist dictionary.", file=sys.stderr)
        raise SystemExit(2)
    absent = sorted(key for key in required_keys if not value.get(key))
    if absent:
        print(
            f"{name} is missing required keys: {', '.join(absent)}",
            file=sys.stderr,
        )
        raise SystemExit(2)
    decoded[name] = {"value": value, "raw": raw, "path": path}

google = decoded["NOUM_GOOGLE_SERVICE_INFO_PLIST_BASE64"]["value"]
if google["BUNDLE_ID"] != "uk.co.otherpath.noum":
    print(
        "NOUM_GOOGLE_SERVICE_INFO_PLIST_BASE64 has the wrong BUNDLE_ID.",
        file=sys.stderr,
    )
    raise SystemExit(2)

info = decoded["NOUM_INFO_PLIST_BASE64"]["value"]
schemes = {
    scheme
    for item in info.get("CFBundleURLTypes", [])
    if isinstance(item, dict)
    for scheme in item.get("CFBundleURLSchemes", [])
    if isinstance(scheme, str)
}
if google["REVERSED_CLIENT_ID"] not in schemes:
    print(
        "Info.plist does not include the Firebase REVERSED_CLIENT_ID URL scheme.",
        file=sys.stderr,
    )
    raise SystemExit(2)
if "noum" not in schemes:
    print(
        "Info.plist does not include the required noum URL scheme.",
        file=sys.stderr,
    )
    raise SystemExit(2)

temporaries = []
for item in decoded.values():
    path = item["path"]
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(item["raw"])
    temporary.chmod(0o600)
    temporaries.append((temporary, path))
for temporary, path in temporaries:
    temporary.replace(path)

print("Materialized required iOS CI plists with mode 0600.")
PY
