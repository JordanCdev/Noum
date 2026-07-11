#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks is required for the full-history secret scan." >&2
  exit 2
fi

# Scan every reachable commit, not only the checked-out tree. Redaction is
# mandatory so a detection cannot copy credential material into CI logs.
gitleaks git "$repo_root" --redact=100 --no-banner

echo "Full-history secret scan passed."
