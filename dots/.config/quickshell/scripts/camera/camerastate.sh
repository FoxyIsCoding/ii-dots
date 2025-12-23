#!/usr/bin/env bash
# quickshell/scripts/camera/camerastate.sh
#
# Writes a list of applications currently using camera devices to a state file.
# Output format:
#   - One process name per line when camera is in use
#   - The word "none" when no camera usage is detected
#
# Usage:
#   camerastate.sh [OUTPUT_PATH]
# If OUTPUT_PATH is not provided, it defaults to:
#   ${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/camera/apps.txt
#
# Notes:
# - This script detects camera usage by querying processes that have /dev/video* open via lsof.
# - On some systems using PipeWire portals, direct /dev/video* access might be abstracted away.
#   If that’s the case, adapt this script to your environment and write detected apps to the state file.

set -euo pipefail

# Resolve output path
DEFAULT_STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}"
DEFAULT_OUTPUT_PATH="${DEFAULT_STATE_ROOT}/quickshell/user/generated/camera/apps.txt"
OUTPUT_PATH="${1:-$DEFAULT_OUTPUT_PATH}"

# Ensure directory exists
mkdir -p "$(dirname -- "${OUTPUT_PATH}")"

# Helper: write to state file atomically
write_state() {
  # Use a temp file in the same directory for atomic replace
  local tmp
  tmp="$(mktemp --tmpdir="$(dirname -- "${OUTPUT_PATH}")" camerastate.XXXXXX)"
  printf "%s\n" "$1" > "${tmp}"
  mv -f -- "${tmp}" "${OUTPUT_PATH}"
}

# Detect camera usage via lsof
detect_camera_apps_v4l2() {
  # Query processes that have /dev/video* open (V4L2 direct access)
  if ! command -v lsof >/dev/null 2>&1; then
    echo ""
    return 0
  fi
  lsof -w -n /dev/video* 2>/dev/null | awk 'NR>1{print $1}' | sort -u | sed '/^[[:space:]]*$/d' || true
}

detect_camera_apps_pipewire() {
  # Detect PipeWire video source nodes with active clients (Wayland/portal usage)
  # Requires pw-cli; if missing, return empty
  if ! command -v pw-cli >/dev/null 2>&1; then
    echo ""
    return 0
  fi

  # List nodes, pick those with media.class = "Video/Source", and extract client.process properties if present.
  # Fallback to node.name when process info is unavailable.
  # Then, extract unique names.
  pw-cli ls Node 2>/dev/null \
    | awk '
      BEGIN { RS="Object"; FS="\n"; }
      {
        hasVideo=0; name=""; proc=""; appname="";
        for (i=1;i<=NF;i++) {
          line=$i;
          if (line ~ /media.class.*Video\/Source/) { hasVideo=1; }
          if (line ~ /node\.name[[:space:]]*=/) {
            sub(/^.*node\.name[[:space:]]*=/, "", line);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line);
            name=line;
          }
          if (line ~ /client\.process\.binary[[:space:]]*=/) {
            sub(/^.*client\.process\.binary[[:space:]]*=/, "", line);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line);
            proc=line;
          }
          if (line ~ /application\.name[[:space:]]*=/) {
            sub(/^.*application\.name[[:space:]]*=/, "", line);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line);
            appname=line;
          }
        }
        if (hasVideo) {
          if (proc != "") { print proc; }
          else if (appname != "") { print appname; }
          else if (name != "") { print name; }
        }
      }
    ' \
    | sed '/^[[:space:]]*$/d' \
    | sort -u || true
}

detect_camera_apps() {
  # Combine V4L2 and PipeWire detections
  local v4l2 pipewire combined
  v4l2="$(detect_camera_apps_v4l2)"
  pipewire="$(detect_camera_apps_pipewire)"
  combined="$(printf "%s\n%s\n" "${v4l2}" "${pipewire}" | sed '/^[[:space:]]*$/d' | sort -u)"
  echo "${combined}"
}

main() {
  local apps
  apps="$(detect_camera_apps)"

  # If empty, write "none"; otherwise write unique app names line-by-line
  if [[ -z "${apps}" ]]; then
    write_state "none"
  else
    # Normalize whitespace and ensure newline-separated (guard against accidental spaces)
    write_state "$(echo "${apps}" | sed '/^[[:space:]]*$/d')"
  fi
}

main
