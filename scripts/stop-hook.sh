#!/usr/bin/env bash
# Stop hook: Auto-continue build execution with circuit breakers
# Reads status.yaml from plan root. If build is active, blocks the stop
# and injects a continuation prompt via the "reason" field.
#
# Circuit breakers:
# 1. Max 50 reinforcements per session
# 2. Rate limit detection (from error-tracker.sh output)
# 3. stop_hook_active + high count (proxy for context pressure)
# 4. Sprint hard cap (30)

INPUT=$(cat)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

PLANS_DIR="docs/plans"

# Find active build status.yaml (at plan root, not discussion/)
status_file=""
if [ -d "$PLANS_DIR" ]; then
  latest_mtime=0
  for dir in "$PLANS_DIR"/*/; do
    [ -d "$dir" ] || continue
    candidate="${dir}status.yaml"
    [ -f "$candidate" ] || continue
    skill=$(grep "^skill:" "$candidate" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
    [ "$skill" = "build" ] || continue
    if stat -f %m "$candidate" >/dev/null 2>&1; then
      mtime=$(stat -f %m "$candidate")
    else
      mtime=$(stat -c %Y "$candidate")
    fi
    if [ "$mtime" -gt "$latest_mtime" ]; then
      latest_mtime=$mtime
      status_file=$candidate
    fi
  done
fi

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
echo "$count" > "$COUNTER_FILE"

# Circuit breaker 1: Max 50 reinforcements
if [ "$count" -ge 50 ]; then
  exit 0
fi

# Circuit breaker 2: Rate limit detection
if [ -f "$ERROR_FILE" ]; then
  recent_429=$(grep -ci "429\|rate.limit\|rate limit\|quota" "$ERROR_FILE" 2>/dev/null || echo "0")
  if [ "$recent_429" -gt 0 ]; then
    exit 0
  fi
fi

# Circuit breaker 3: stop_hook_active + high count (context pressure proxy)
if [ "$STOP_ACTIVE" = "true" ] && [ "$count" -ge 30 ]; then
  exit 0
fi

# Circuit breaker 4: Sprint hard cap
sprint=$(grep "^sprint:" "$status_file" 2>/dev/null | head -1 | sed 's/^sprint: *//; s/"//g')
if [ -n "$sprint" ] && [ "$sprint" -ge 30 ] 2>/dev/null; then
  exit 0
fi

# Build is active — block the stop and inject continuation prompt
phase=$(grep "^phase:" "$status_file" 2>/dev/null | head -1 | sed 's/^phase: *//; s/"//g')
next_action=$(grep "^next:" "$status_file" 2>/dev/null | head -1 | sed 's/^next: *//; s/"//g')
detail=$(grep "^detail:" "$status_file" 2>/dev/null | head -1 | sed 's/^detail: *//; s/"//g')

# Read spec progress
spec_progress=""
spec_file="${plan_dir}/spec.yaml"
if [ -f "$spec_file" ]; then
  total=$(grep -c "passes:" "$spec_file" 2>/dev/null || echo "0")
  passed=$(grep -c "passes: true" "$spec_file" 2>/dev/null || echo "0")
  spec_progress=" Spec: ${passed}/${total} passing."
fi

# Build the continuation reason (this IS the prompt for the next turn)
reason="Build active: Sprint ${sprint:-?}, ${phase:-?} phase.${spec_progress}"
[ -n "$detail" ] && reason="${reason} Current: ${detail}."
[ -n "$next_action" ] && reason="${reason} Next: ${next_action}."
reason="${reason} Continue with /robro:build to resume."

# Output the block decision
jq -n --arg reason "$reason" '{"decision":"block","reason":$reason}'
