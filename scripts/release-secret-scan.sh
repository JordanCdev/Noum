#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks is required for the full-history secret scan." >&2
  exit 2
fi

# Scan every reachable commit, not only the checked-out tree. Redaction is
# mandatory so a detection cannot copy credential material into CI logs.
#
# .gitleaks.toml baselines reviewed historical findings by commit SHA. It does not
# disable any rule, so a secret in a new commit still fails this gate. Read the
# editing rules at the top of that file before adding to it.
config="$repo_root/.gitleaks.toml"
if [[ ! -f "$config" ]]; then
  echo "Missing $config — refusing to scan without the reviewed baseline." >&2
  exit 2
fi

gitleaks git "$repo_root" --config "$config" --redact=100 --no-banner

echo "Full-history secret scan passed."
