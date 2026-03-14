#!/usr/bin/env bash
# PostToolUseFailure hook: Track recent errors for rate limit detection
# Writes recent errors to discussion/.recent-errors.json so the stop hook
# can detect rate limiting patterns and bail gracefully.

INPUT=$(cat)
ERROR=$(echo "$INPUT" | jq -r '.error // ""' 2>/dev/null)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Skip if no error
[ -z "$ERROR" ] && exit 0

# Load shared config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/load-config.sh"

# Find active build status.yaml
status_file=$(find_latest_session "status.yaml" "skill" "do")

# No active build — exit silently
[ -z "$status_file" ] && exit 0

plan_dir=$(dirname "$status_file")
ERROR_FILE="${plan_dir}/discussion/.recent-errors.json"

# Ensure discussion dir exists
mkdir -p "${plan_dir}/discussion"

# Get current timestamp
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create or update the error file (keep last 20 errors)
if [ -f "$ERROR_FILE" ]; then
  # Read existing, append new, keep last 20
  existing=$(cat "$ERROR_FILE")
  new_entry=$(jq -n --arg ts "$timestamp" --arg tool "$TOOL" --arg err "$ERROR" \
    '{"timestamp":$ts,"tool":$tool,"error":$err}')
  echo "$existing" | jq --argjson entry "$new_entry" \
    '. + [$entry] | .[-20:]' 2>/dev/null | atomic_write "$ERROR_FILE"
else
  # Create new file with first entry
  jq -n --arg ts "$timestamp" --arg tool "$TOOL" --arg err "$ERROR" \
    '[{"timestamp":$ts,"tool":$tool,"error":$err}]' | atomic_write "$ERROR_FILE"
fi

exit 0
