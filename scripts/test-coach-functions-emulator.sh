#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
cd "$repo_root"

# Match the deployed Functions runtime instead of silently testing with the
# developer's globally selected Node version.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
  nvm use 22 >/dev/null
fi
if [[ "$(node -p 'process.versions.node.split(".")[0]')" != "22" ]]; then
  echo "Node 22 is required for the Functions emulator gate." >&2
  exit 1
fi

# Homebrew's JDK is intentionally not linked into /usr/local on this Mac.
# Prefer it when present so the Firestore emulator exercises the real
# transaction-backed rate limiter instead of silently skipping that gate.
if [[ -x /opt/homebrew/opt/openjdk/bin/java ]]; then
  export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
  export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
fi

npm --prefix functions run build
COACH_MODEL="${COACH_MODEL:-gemini-2.5-flash}" \
COACH_ULTRA_MODEL="${COACH_ULTRA_MODEL:-gemini-2.5-pro}" \
VERTEX_LOCATION="${VERTEX_LOCATION:-europe-west1}" \
npx -y firebase-tools@latest emulators:exec \
  --project noum-d0b6f \
  --only functions,auth,firestore \
  "node --test functions/lib/emulator.integration.test.js"
