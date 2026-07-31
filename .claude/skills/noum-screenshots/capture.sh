#!/bin/bash
# noum-screenshots auto-capture hook.
# Invoked from the SessionEnd hook in .claude/settings.json.
# Reads .mode file and captures the 5 tab tops via deep link if mode is
# "light" or "detailed" (we don't run the full tour on session end — too
# slow). Silent no-op if mode is "off", not on macOS, or sim not booted.
#
# Folder is timestamped to avoid clobbering Claude's manual captures from
# earlier in the same session.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MODE_FILE="$SCRIPT_DIR/.mode"

# --- Silent guards ---
[[ "$(uname)" != "Darwin" ]] && exit 0
[[ ! -f "$MODE_FILE" ]] && exit 0

MODE=$(tr -d '[:space:]' < "$MODE_FILE")
[[ "$MODE" == "off" || -z "$MODE" ]] && exit 0

# Verify a sim is booted; abort silently otherwise (no point waking one up
# just to grab screenshots, and the user may have closed Simulator on purpose).
BOOTED_LINE=$(xcrun simctl list devices booted 2>/dev/null | grep -E "Booted" | head -1)
[[ -z "$BOOTED_LINE" ]] && exit 0

# Verify the Noum app is installed on the booted sim
xcrun simctl listapps booted 2>/dev/null | grep -q "uk.co.otherpath.noum" || exit 0

# --- Capture ---
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H%M)
SHORT_SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo nogit)
BRANCH=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo unknown)
FOLDER="$REPO_ROOT/.screenshots/${DATE}_autostop-${SHORT_SHA}-${TIME}"
mkdir -p "$FOLDER"

for tab in home train review profile settings; do
  xcrun simctl launch --terminate-running-process booted uk.co.otherpath.noum \
    UI_TESTING -DeepLink "noum://${tab}" > /dev/null 2>&1 || true
  sleep 3
  xcrun simctl io booted screenshot "$FOLDER/01_${tab}_top.png" > /dev/null 2>&1 || true
done

# --- HANDOFF ---
cat > "$FOLDER/HANDOFF.md" <<EOF
# Run: $DATE $TIME · branch:$BRANCH · HEAD $SHORT_SHA · auto-stop capture

Auto-captured by the noum-screenshots SessionEnd hook. If Claude wrote a
richer HANDOFF earlier this session in another \`.screenshots/${DATE}_*\`
folder, that one has the actual session context — this folder is just the
"latest visual state" snapshot for cloud routines.

## Mode
\`$MODE\` (read from \`.claude/skills/noum-screenshots/.mode\`)

## Screenshots
- \`01_home_top.png\` — Home tab
- \`01_train_top.png\` — Train (Practice mode picker)
- \`01_review_top.png\` — Review (Session history)
- \`01_profile_top.png\` — Profile
- \`01_settings_top.png\` — Settings

## What this run did
No session context — this is an auto-stop capture. See the most recent
non-autostop HANDOFF in \`.screenshots/\` for actual session changes.

## For next run
- If cloud: read this HANDOFF + any newer ones for richer context.
- If local: the next session's auto-stop will refresh; nothing to do here.
EOF

# Tell the user the capture happened (Stop/SessionEnd hooks show systemMessage)
echo '{"systemMessage":"noum-screenshots: auto-captured 5 tab tops to .screenshots/'"${DATE}_autostop-${SHORT_SHA}-${TIME}"'/"}'
