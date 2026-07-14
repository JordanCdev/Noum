#!/usr/bin/env bash
# Shared simulator launch-environment bridge for Coach Arena XCTest evidence.
#
# Xcode 26 can strip both host NOUM_* and SIMCTL_CHILD_* variables before the
# iOS test host starts. Install the same bounded values in the selected
# simulator's launchd environment, then restore its previous state immediately
# after the dump test finishes.

NOUM_COACH_SIMULATOR_ENV_BASE_KEYS=(
  "NOUM_COACH_EVAL_DUMP_DIR"
  "NOUM_SOURCE_GIT_COMMIT"
  "NOUM_SOURCE_COACH_FINGERPRINT"
)
NOUM_COACH_SIMULATOR_ENV_KEYS=("${NOUM_COACH_SIMULATOR_ENV_BASE_KEYS[@]}")
NOUM_COACH_SIMULATOR_ENV_VALUES=()
NOUM_COACH_SIMULATOR_ENV_PREVIOUS_VALUES=()
NOUM_COACH_SIMULATOR_ENV_PREVIOUS_SET=()
NOUM_COACH_SIMULATOR_ENV_ACTIVE=0
NOUM_COACH_SIMULATOR_UDID=""
NOUM_COACH_SIMULATOR_LOCK_DIR=""
NOUM_COACH_SOURCE_GIT_COMMIT=""
NOUM_COACH_SOURCE_COACH_FINGERPRINT=""

noum_coach_trimmed_destination_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

noum_coach_resolve_simulator_udid() {
  local destination="$1"
  local component=""
  local platform=""
  local simulator_id=""
  local simulator_name=""
  local simulator_os=""
  local key=""
  local value=""
  local -a components=()

  IFS=',' read -r -a components <<< "$destination"
  for component in "${components[@]}"; do
    key="$(noum_coach_trimmed_destination_value "${component%%=*}")"
    value="$(noum_coach_trimmed_destination_value "${component#*=}")"
    case "$key" in
      platform) platform="$value" ;;
      id) simulator_id="$value" ;;
      name) simulator_name="$value" ;;
      OS) simulator_os="$value" ;;
    esac
  done

  if [[ "$platform" != "iOS Simulator" ]]; then
    echo "Coach evidence requires an iOS Simulator destination: $destination" >&2
    return 2
  fi
  if [[ -n "$simulator_id" && "$simulator_id" != "placeholder" ]]; then
    printf '%s\n' "$simulator_id"
    return 0
  fi
  if [[ -z "$simulator_name" ]]; then
    echo "Coach evidence destination must include an exact simulator id or name: $destination" >&2
    return 2
  fi

  xcrun simctl list devices available --json | python3 -c '
import json
import re
import sys

name, requested_os = sys.argv[1:3]
payload = json.load(sys.stdin)

def runtime_version(identifier):
    match = re.search(r"\.iOS-(\d+)-(\d+)(?:-(\d+))?$", identifier)
    if not match:
        return ()
    return tuple(int(part) for part in match.groups(default="0"))

def requested_matches(version):
    if not requested_os or requested_os.lower() == "latest":
        return True
    try:
        wanted = tuple(int(part) for part in requested_os.split("."))
    except ValueError:
        return False
    compared_parts = min(len(wanted), 2)
    return version[:compared_parts] == wanted[:compared_parts]

candidates = []
for runtime, devices in payload.get("devices", {}).items():
    version = runtime_version(runtime)
    if not version or not requested_matches(version):
        continue
    for device in devices:
        if device.get("name") != name or device.get("isAvailable", True) is False:
            continue
        candidates.append((version, device.get("state") == "Booted", device.get("udid", "")))

if not candidates:
    detail = f" on iOS {requested_os}" if requested_os and requested_os.lower() != "latest" else ""
    print(f"No available simulator named {name!r}{detail}.", file=sys.stderr)
    raise SystemExit(2)

latest_version = max(candidate[0] for candidate in candidates)
latest = [candidate for candidate in candidates if candidate[0] == latest_version]
latest.sort(key=lambda candidate: (not candidate[1], candidate[2]))
print(latest[0][2])
' "$simulator_name" "$simulator_os"
}

noum_coach_release_simulator_lock() {
  if [[ -n "$NOUM_COACH_SIMULATOR_LOCK_DIR" ]]; then
    rm -f "$NOUM_COACH_SIMULATOR_LOCK_DIR/pid" || true
    rmdir "$NOUM_COACH_SIMULATOR_LOCK_DIR" 2>/dev/null || true
    NOUM_COACH_SIMULATOR_LOCK_DIR=""
  fi
}

noum_coach_acquire_simulator_lock() {
  local simulator_id="$1"
  local lock_root="${NOUM_COACH_SIMULATOR_ENV_LOCK_ROOT:-${TMPDIR:-/private/tmp}}"
  local lock_dir="${lock_root%/}/noum-coach-simulator-env-${simulator_id}.lock"
  local prior_pid=""
  local acquired=0

  mkdir -p "$lock_root"
  if mkdir "$lock_dir" 2>/dev/null; then
    acquired=1
  else
    if [[ -r "$lock_dir/pid" ]]; then
      prior_pid="$(<"$lock_dir/pid")"
    fi
    if [[ "$prior_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$prior_pid" 2>/dev/null; then
      rm -f "$lock_dir/pid" || true
      rmdir "$lock_dir" 2>/dev/null || true
      if mkdir "$lock_dir" 2>/dev/null; then
        acquired=1
      fi
    fi
    if [[ "$acquired" != "1" ]]; then
      echo "Simulator $simulator_id already has an active Coach Arena evidence environment${prior_pid:+ (pid $prior_pid)}." >&2
      return 2
    fi
  fi

  NOUM_COACH_SIMULATOR_LOCK_DIR="$lock_dir"
  printf '%s\n' "$$" > "$lock_dir/pid"
}

noum_coach_simulator_environment_cleanup() {
  local index=0
  local key=""
  local previous_value=""
  local had_previous=0
  local cleanup_failed=0

  if [[ "$NOUM_COACH_SIMULATOR_ENV_ACTIVE" == "1" && -n "$NOUM_COACH_SIMULATOR_UDID" ]]; then
    for ((index=${#NOUM_COACH_SIMULATOR_ENV_KEYS[@]} - 1; index >= 0; index--)); do
      key="${NOUM_COACH_SIMULATOR_ENV_KEYS[$index]}"
      previous_value="${NOUM_COACH_SIMULATOR_ENV_PREVIOUS_VALUES[$index]:-}"
      had_previous="${NOUM_COACH_SIMULATOR_ENV_PREVIOUS_SET[$index]:-0}"
      if [[ "$had_previous" == "1" ]]; then
        xcrun simctl spawn "$NOUM_COACH_SIMULATOR_UDID" launchctl setenv "$key" "$previous_value" >/dev/null || cleanup_failed=1
      else
        xcrun simctl spawn "$NOUM_COACH_SIMULATOR_UDID" launchctl unsetenv "$key" >/dev/null || cleanup_failed=1
      fi
    done
  fi

  NOUM_COACH_SIMULATOR_ENV_ACTIVE=0
  NOUM_COACH_SIMULATOR_ENV_KEYS=("${NOUM_COACH_SIMULATOR_ENV_BASE_KEYS[@]}")
  NOUM_COACH_SIMULATOR_ENV_VALUES=()
  NOUM_COACH_SIMULATOR_ENV_PREVIOUS_VALUES=()
  NOUM_COACH_SIMULATOR_ENV_PREVIOUS_SET=()
  noum_coach_release_simulator_lock
  if [[ "$cleanup_failed" == "1" ]]; then
    echo "Could not fully restore the Coach Arena simulator environment on $NOUM_COACH_SIMULATOR_UDID." >&2
    return 1
  fi
  return 0
}

noum_coach_simulator_environment_exit_trap() {
  local status=$?
  trap - EXIT INT TERM HUP
  noum_coach_simulator_environment_cleanup || true
  exit "$status"
}

noum_coach_install_simulator_environment() {
  local destination="$1"
  local dump_dir="$2"
  shift 2
  local index=0
  local key=""
  local previous_value=""
  local inherited_key=""
  local inherited_value=""

  if [[ "$NOUM_COACH_SIMULATOR_ENV_ACTIVE" == "1" ]]; then
    echo "Coach Arena simulator environment is already installed in this process." >&2
    return 2
  fi
  if [[ ! -s "$dump_dir/source-git-commit.txt" || ! -s "$dump_dir/source-coach-fingerprint.txt" ]]; then
    echo "Missing non-empty Coach Arena source sidecars in: $dump_dir" >&2
    return 2
  fi

  NOUM_COACH_SOURCE_GIT_COMMIT="$(<"$dump_dir/source-git-commit.txt")"
  NOUM_COACH_SOURCE_COACH_FINGERPRINT="$(<"$dump_dir/source-coach-fingerprint.txt")"
  NOUM_COACH_SOURCE_GIT_COMMIT="$(noum_coach_trimmed_destination_value "$NOUM_COACH_SOURCE_GIT_COMMIT")"
  NOUM_COACH_SOURCE_COACH_FINGERPRINT="$(noum_coach_trimmed_destination_value "$NOUM_COACH_SOURCE_COACH_FINGERPRINT")"
  if [[ -z "$NOUM_COACH_SOURCE_GIT_COMMIT" || -z "$NOUM_COACH_SOURCE_COACH_FINGERPRINT" ]]; then
    echo "Coach Arena source sidecars must contain non-empty values: $dump_dir" >&2
    return 2
  fi

  NOUM_COACH_SIMULATOR_ENV_KEYS=("${NOUM_COACH_SIMULATOR_ENV_BASE_KEYS[@]}")
  NOUM_COACH_SIMULATOR_ENV_VALUES=(
    "$dump_dir"
    "$NOUM_COACH_SOURCE_GIT_COMMIT"
    "$NOUM_COACH_SOURCE_COACH_FINGERPRINT"
  )
  for inherited_key in "$@"; do
    if [[ ! "$inherited_key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
      echo "Invalid simulator environment key: $inherited_key" >&2
      noum_coach_simulator_environment_cleanup || true
      return 2
    fi
    if [[ " ${NOUM_COACH_SIMULATOR_ENV_KEYS[*]} " == *" $inherited_key "* ]]; then
      continue
    fi
    inherited_value="${!inherited_key:-}"
    if [[ -z "$inherited_value" ]]; then
      echo "Simulator environment key is missing or empty: $inherited_key" >&2
      noum_coach_simulator_environment_cleanup || true
      return 2
    fi
    NOUM_COACH_SIMULATOR_ENV_KEYS+=("$inherited_key")
    NOUM_COACH_SIMULATOR_ENV_VALUES+=("$inherited_value")
  done

  NOUM_COACH_SIMULATOR_UDID="$(noum_coach_resolve_simulator_udid "$destination")" || return $?
  noum_coach_acquire_simulator_lock "$NOUM_COACH_SIMULATOR_UDID" || return $?

  if ! xcrun simctl boot "$NOUM_COACH_SIMULATOR_UDID" >/dev/null 2>&1; then
    # A booted simulator reports a nonzero "already booted" status on some
    # CoreSimulator releases. bootstatus is the authoritative readiness check.
    :
  fi
  if ! xcrun simctl bootstatus "$NOUM_COACH_SIMULATOR_UDID" -b; then
    noum_coach_simulator_environment_cleanup || true
    return 2
  fi

  for ((index=0; index<${#NOUM_COACH_SIMULATOR_ENV_KEYS[@]}; index++)); do
    key="${NOUM_COACH_SIMULATOR_ENV_KEYS[$index]}"
    if previous_value="$(xcrun simctl spawn "$NOUM_COACH_SIMULATOR_UDID" launchctl getenv "$key" 2>/dev/null)" && [[ -n "$previous_value" ]]; then
      NOUM_COACH_SIMULATOR_ENV_PREVIOUS_SET[$index]=1
      NOUM_COACH_SIMULATOR_ENV_PREVIOUS_VALUES[$index]="$previous_value"
    else
      NOUM_COACH_SIMULATOR_ENV_PREVIOUS_SET[$index]=0
      NOUM_COACH_SIMULATOR_ENV_PREVIOUS_VALUES[$index]=""
    fi
  done

  NOUM_COACH_SIMULATOR_ENV_ACTIVE=1
  for ((index=0; index<${#NOUM_COACH_SIMULATOR_ENV_KEYS[@]}; index++)); do
    key="${NOUM_COACH_SIMULATOR_ENV_KEYS[$index]}"
    if ! xcrun simctl spawn "$NOUM_COACH_SIMULATOR_UDID" launchctl setenv "$key" "${NOUM_COACH_SIMULATOR_ENV_VALUES[$index]}"; then
      noum_coach_simulator_environment_cleanup || true
      return 2
    fi
  done
}

noum_coach_run_xcodebuild_with_simulator_environment() {
  local destination="$1"
  local dump_dir="$2"
  local inherited_count="$3"
  shift 3
  local -a inherited_keys=()
  local -a command=()
  local index=0
  local status=0
  local cleanup_status=0
  local restore_errexit=0
  local destination_count=0

  for ((index=0; index<inherited_count; index++)); do
    inherited_keys+=("$1")
    shift
  done
  command=("$@")
  if [[ "${#command[@]}" == "0" ]]; then
    echo "Missing xcodebuild command." >&2
    return 2
  fi

  if [[ "${#inherited_keys[@]}" -gt 0 ]]; then
    noum_coach_install_simulator_environment "$destination" "$dump_dir" "${inherited_keys[@]}"
  else
    noum_coach_install_simulator_environment "$destination" "$dump_dir"
  fi
  for ((index=0; index<${#command[@]} - 1; index++)); do
    if [[ "${command[$index]}" == "-destination" ]]; then
      destination_count=$((destination_count + 1))
      command[$((index + 1))]="platform=iOS Simulator,id=$NOUM_COACH_SIMULATOR_UDID"
    fi
  done
  if [[ "$destination_count" != "1" ]]; then
    echo "Coach evidence xcodebuild command must contain exactly one -destination option." >&2
    noum_coach_simulator_environment_cleanup || true
    return 2
  fi

  if [[ "$-" == *e* ]]; then
    restore_errexit=1
    set +e
  fi
  "${command[@]}"
  status=$?
  noum_coach_simulator_environment_cleanup
  cleanup_status=$?
  if [[ "$restore_errexit" == "1" ]]; then
    set -e
  fi
  if [[ "$status" == "0" && "$cleanup_status" != "0" ]]; then
    return "$cleanup_status"
  fi
  return "$status"
}

noum_coach_simulator_environment_cli() {
  local command_name="${1:-}"
  shift || true
  local destination=""
  local dump_dir=""
  local -a inherited_keys=()

  if [[ "$command_name" != "run-xcodebuild" ]]; then
    echo "usage: $0 run-xcodebuild --destination DESTINATION --dump-dir DIR [--inherit-env KEY ...] -- xcodebuild ..." >&2
    return 2
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --destination)
        destination="${2:-}"
        shift 2
        ;;
      --dump-dir)
        dump_dir="${2:-}"
        shift 2
        ;;
      --inherit-env)
        inherited_keys+=("${2:-}")
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        echo "Unknown simulator environment option: $1" >&2
        return 2
        ;;
    esac
  done
  if [[ -z "$destination" || -z "$dump_dir" || $# -eq 0 ]]; then
    echo "Simulator destination, dump directory, and xcodebuild command are required." >&2
    return 2
  fi

  trap noum_coach_simulator_environment_exit_trap EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  if [[ "${#inherited_keys[@]}" -gt 0 ]]; then
    noum_coach_run_xcodebuild_with_simulator_environment \
      "$destination" \
      "$dump_dir" \
      "${#inherited_keys[@]}" \
      "${inherited_keys[@]}" \
      "$@"
  else
    noum_coach_run_xcodebuild_with_simulator_environment \
      "$destination" \
      "$dump_dir" \
      0 \
      "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  noum_coach_simulator_environment_cli "$@"
fi
