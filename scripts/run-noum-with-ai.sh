#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
config="${NOUM_AI_CONFIG:-$repo_root/Noum/AIConfig.plist}"
transcription_config="${NOUM_TRANSCRIPTION_CONFIG:-$repo_root/Noum/TranscriptionProviders.plist}"
device="${NOUM_SIMULATOR_DEVICE:-booted}"
bundle_id="com.jordancoaten.noum"

if [[ ! -f "$config" ]]; then
  echo "Missing gitignored AI config at $config" >&2
  exit 1
fi

typeset -a child_environment
child_environment+=("SIMCTL_CHILD_NOUM_DIRECT_AI_DEBUG=1")

for key in \
  GEMINI_API_KEY GOOGLE_AI_API_KEY GOOGLE_AGENT_PLATFORM_API_KEY \
  ANTHROPIC_API_KEY OPENAI_API_KEY DEEPSEEK_API_KEY; do
  value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$config" 2>/dev/null || true)
  if [[ -n "$value" ]]; then
    child_environment+=("SIMCTL_CHILD_${key}=${value}")
  fi
done

# Speech credentials remain separate from AI-provider credentials. They are
# passed only to the simulator process and never copied into the app bundle.
if [[ -f "$transcription_config" ]]; then
  for key in DEEPGRAM_API_KEY GOOGLE_SPEECH_API_KEY GOOGLE_SPEECH_PROJECT_ID; do
    value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$transcription_config" 2>/dev/null || true)
    if [[ -n "$value" && "$value" != YOUR_* ]]; then
      child_environment+=("SIMCTL_CHILD_${key}=${value}")
    fi
  done
fi

# A registered Firebase App Check debug token can be supplied by the shell.
# Do not print it or persist it in a scheme or plist.
if [[ -n "${FIREBASE_APPCHECK_DEBUG_TOKEN:-}" ]]; then
  child_environment+=("SIMCTL_CHILD_FIREBASE_APPCHECK_DEBUG_TOKEN=${FIREBASE_APPCHECK_DEBUG_TOKEN}")
fi

# `env` passes values only to simctl and the launched app process. Values are
# never printed, written to DerivedData, or copied into the application bundle.
env "${child_environment[@]}" \
  xcrun simctl launch --terminate-running-process "$device" "$bundle_id" "$@"
