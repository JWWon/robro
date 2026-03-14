#!/usr/bin/env bash
# Shared config loader for robro hook scripts.
# Source this file: source "${SCRIPT_DIR}/lib/load-config.sh"
#
# Constants:
#   SESSIONS_DIR  — path to session artifacts (.robro/sessions)
#   CONFIG_FILE   — path to project config.json (.robro/config.json)
#
# Functions:
#   robro_config          — read config values with defaults
#   get_mtime             — cross-platform file modification time
#   status_field          — extract field from simple YAML file
#   find_latest_session   — find most recent session file, optionally filtered
#   spec_counts           — count spec.yaml items (total passed superseded)
#   has_artifact          — check if any session has a specific file

SESSIONS_DIR=".robro/sessions"
CONFIG_FILE=".robro/config.json"

# Read a value from .robro/config.json with a default fallback.
# Usage: robro_config <jq_path> <default_value>
robro_config() {
  local jq_path="$1"
  local default_val="$2"
  if [ -f "$CONFIG_FILE" ]; then
    local val
    val=$(jq -r "$jq_path // empty" "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$val" ]; then
      echo "$val"
      return
    fi
  fi
  echo "$default_val"
}

# Cross-platform file modification time (epoch seconds).
get_mtime() {
  if stat -f %m "$1" >/dev/null 2>&1; then
    stat -f %m "$1"
  else
    stat -c %Y "$1"
  fi
}

# Extract a field value from a simple YAML file (top-level scalar fields only).
# Usage: skill=$(status_field "$file" "skill")
status_field() {
  grep "^${2}:" "$1" 2>/dev/null | head -1 | sed "s/^${2}: *//; s/\"//g"
}

# Find most recent file with given name in sessions dir.
# Optional filter: only return files where a YAML field matches a value.
# Usage: find_latest_session "status.yaml"
#        find_latest_session "status.yaml" "skill" "do"
find_latest_session() {
  local filename="$1" filter_field="${2:-}" filter_value="${3:-}"
  local latest_mtime=0 result=""

  [ -d "$SESSIONS_DIR" ] || return 1

  for dir in "$SESSIONS_DIR"/*/; do
    [ -d "$dir" ] || continue
    local candidate="${dir}${filename}"
    [ -f "$candidate" ] || continue

    if [ -n "$filter_field" ]; then
      local val
      val=$(status_field "$candidate" "$filter_field")
      [ "$val" = "$filter_value" ] || continue
    fi

    local mtime
    mtime=$(get_mtime "$candidate")
    if [ "$mtime" -gt "$latest_mtime" ]; then
      latest_mtime=$mtime
      result=$candidate
    fi
  done

  [ -n "$result" ] && echo "$result"
}

# Count spec.yaml items. Echoes "total passed superseded".
# Usage: read total passed superseded <<< "$(spec_counts "$spec_file")"
spec_counts() {
  local total passed superseded
  total=$(grep -c "passes:" "$1" 2>/dev/null || echo "0")
  passed=$(grep -c "passes: true" "$1" 2>/dev/null || echo "0")
  superseded=$(grep -c "status: superseded" "$1" 2>/dev/null || echo "0")
  echo "$total $passed $superseded"
}

# Check if any session has a specific artifact file.
# Usage: if has_artifact "spec.yaml"; then ...
has_artifact() {
  [ -d "$SESSIONS_DIR" ] || return 1
  for dir in "$SESSIONS_DIR"/*/; do
    [ -f "${dir}${1}" ] && return 0
  done
  return 1
}
