#!/usr/bin/env bash
# Shared config loader for robro hook scripts.
# Source this file: source "${CLAUDE_PLUGIN_ROOT}/scripts/lib/load-config.sh"
#
# Exports:
#   SESSIONS_DIR  — path to session artifacts (constant: .robro/sessions)
#   CONFIG_FILE   — path to project config.json (.robro/config.json)
#   robro_config  — function to read config values with defaults

SESSIONS_DIR=".robro/sessions"
CONFIG_FILE=".robro/config.json"

# Read a value from .robro/config.json with a default fallback.
# Usage: robro_config <jq_path> <default_value>
# Example: robro_config '.thresholds.sprint_hard_cap' '30'
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
