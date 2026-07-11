#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! -d "$1" ]]; then
  echo "Usage: $0 /path/to/Noum.app" >&2
  exit 2
fi

python3 - "$1" <<'PY'
import re
import sys
from pathlib import Path

bundle = Path(sys.argv[1]).resolve()
forbidden_names = {
    "AIConfig.plist",
    "BackendConfig.plist",
    "Transcribe.plist",
    "TranscriptionProviders.plist",
}
secret_patterns = [
    (
        "private key",
        re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    ),
    (
        "OpenAI or Anthropic key",
        re.compile(rb"\bsk-(?:ant-)?[A-Za-z0-9_-]{20,}\b"),
    ),
    (
        "AWS access key",
        re.compile(rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    ),
    (
        "GitHub token",
        re.compile(rb"\bgh[oprsu]_[A-Za-z0-9]{30,}\b"),
    ),
    (
        "provider secret assignment",
        re.compile(
            rb"(?i)(?:OPENAI|ANTHROPIC|DEEPSEEK|DEEPGRAM|GEMINI|"
            rb"GOOGLE_CLOUD_TTS|BACKEND|AWS)_(?:API_)?(?:KEY|SECRET|TOKEN)"
            rb"[ \t]{0,8}[=:][ \t]{0,8}[\"']?[A-Za-z0-9_./+=-]{16,}"
        ),
    ),
]

failures = []
for path in bundle.rglob("*"):
    if path.name in forbidden_names:
        failures.append(("forbidden config", path))

for path in bundle.rglob("*"):
    if path.is_symlink() or not path.is_file():
        continue
    try:
        data = path.read_bytes()
    except OSError:
        failures.append(("unreadable bundle file", path))
        continue
    for label, pattern in secret_patterns:
        if pattern.search(data):
            failures.append((label, path))

if failures:
    print("Release bundle inspection failed:", file=sys.stderr)
    for label, path in sorted(set(failures), key=lambda item: str(item[1])):
        relative = path.relative_to(bundle)
        print(f"- {label}: {relative}", file=sys.stderr)
    print("Matched credential material is intentionally not printed.", file=sys.stderr)
    raise SystemExit(1)

print(f"Release bundle inspection passed: {bundle.name}")
PY
