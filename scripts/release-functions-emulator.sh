#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [[ "$node_major" != "22" ]]; then
  echo "Node 22 is required; found Node $node_major." >&2
  exit 2
fi

java_output="$(java -XshowSettings:properties -version 2>&1 || true)"
java_version="$(printf '%s\n' "$java_output" \
  | awk -F= '/^[[:space:]]*java.version =/{gsub(/[[:space:]]/, "", $2); print $2; exit}')"
if [[ "$java_version" != 21.* ]]; then
  echo "Java 21 is required; found ${java_version:-no Java runtime}." >&2
  exit 2
fi

env_file="$repo_root/functions/.env.local"
secret_file="$repo_root/functions/.secret.local"
if [[ -e "$env_file" || -e "$secret_file" ]]; then
  echo "Refusing to replace existing Functions local environment files." >&2
  echo "Run this release gate from a clean checkout." >&2
  exit 2
fi

cleanup() {
  rm -f "$env_file" "$secret_file"
}
trap cleanup EXIT INT TERM
umask 077
printf '%s\n' \
  'COACH_MODEL=gemini-2.5-flash' \
  'COACH_ULTRA_MODEL=gemini-2.5-pro' \
  'VERTEX_LOCATION=europe-west1' \
  'COACH_EMULATOR_STUB=1' > "$env_file"
printf '%s\n' \
  'DEEPGRAM_MANAGEMENT_KEY=emulator-only-management-key' > "$secret_file"

npm --prefix functions run build
npx --yes "firebase-tools@${FIREBASE_TOOLS_VERSION:-15.19.1}" \
  emulators:exec \
  --project demo-noum \
  --only functions,auth,firestore \
  "node --test functions/lib/emulator.integration.test.js && \
NOUM_SOCIAL_CUTOVER_EMULATOR=1 node --test --test-concurrency=1 \
scripts/social-cutover-firestore.integration.test.mjs"
