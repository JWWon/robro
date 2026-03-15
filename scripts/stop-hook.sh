#!/usr/bin/env bash
# Stop hook: Auto-continue build execution with circuit breakers
# Reads status.yaml from plan root. If build is active, blocks the stop
# and injects a continuation prompt via the "reason" field.
#
# Circuit breakers:
# 1. Max 50 reinforcements per session
# 2. Rate limit detection (from error-tracker.sh output)
# 3. stop_hook_active + high count (proxy for context pressure)
# 4. Sprint hard cap (configurable, default 30)

INPUT=$(cat)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

# Load shared config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/load-config.sh"

SPRINT_HARD_CAP=$(robro_config '.thresholds.sprint_hard_cap' '30')

# Find active build status.yaml (at plan root, not discussion/)
status_file=$(find_workflow_status "do")

# No active build — allow stop
[ -z "$status_file" ] && exit 0

plan_dir=$(dirname "$status_file")
COUNTER_FILE="${plan_dir}/discussion/.stop-hook-counter"
ERROR_FILE="${plan_dir}/discussion/.recent-errors.json"

# Ensure discussion dir exists
mkdir -p "${plan_dir}/discussion"

# Read and increment counter
count=0
[ -f "$COUNTER_FILE" ] && count=$(cat "$COUNTER_FILE" 2>/dev/null)
count=$((count + 1))
echo "$count" | atomic_write "$COUNTER_FILE"

# Circuit breaker 1: Max 50 reinforcements
[ "$count" -ge 50 ] && exit 0

# Circuit breaker 2: Rate limit detection
if [ -f "$ERROR_FILE" ]; then
  recent_429=$(grep -ci '429\|rate[_. ]limit\|quota' "$ERROR_FILE" 2>/dev/null || echo "0")
  [ "$recent_429" -gt 0 ] && exit 0
fi

# Circuit breaker 3: stop_hook_active + rapid consecutive blocks
[ "$STOP_ACTIVE" = "true" ] && [ "$count" -ge 5 ] && exit 0

# Circuit breaker 4: Sprint hard cap
sprint=$(status_field "$status_file" "sprint")
if [ -n "$sprint" ] && [ "$sprint" -ge "$SPRINT_HARD_CAP" ] 2>/dev/null; then
  exit 0
fi

# Build is active — block the stop and inject continuation prompt
phase=$(status_field "$status_file" "phase")
next_action=$(status_field "$status_file" "next")
detail=$(status_field "$status_file" "detail")

# Read spec progress
spec_progress=""
if [ -f "${plan_dir}/spec.yaml" ]; then
  read total passed superseded <<< "$(spec_counts "${plan_dir}/spec.yaml")"
  spec_progress=" Spec: ${passed}/${total} passing."
fi

# Build the continuation reason (this IS the prompt for the next turn)
reason="Build active: Sprint ${sprint:-?}, ${phase:-?} phase.${spec_progress}"
[ -n "$detail" ] && reason="${reason} Current: ${detail}."
[ -n "$next_action" ] && reason="${reason} Next: ${next_action}."
reason="${reason} Continue with /robro:do to resume."

# Output the block decision
jq -n --arg reason "$reason" '{"decision":"block","reason":$reason}'
