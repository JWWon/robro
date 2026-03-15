#!/usr/bin/env bash
# PostToolUse hook: verify subagent deliverables
# - Checks for standard Status protocol line in last_assistant_message
# - Checks mandatory agents (architect, reviewer, critic) for <external_advisory> tag
# Always exits 0 (non-blocking advisory only)

set -euo pipefail

input=$(cat)

output=$(echo "$input" | jq -r '.last_assistant_message // ""' 2>/dev/null)
agent_id=$(echo "$input" | jq -r '.agent_id // ""' 2>/dev/null)

# Check Status protocol
if [ -n "$output" ]; then
  if ! echo "$output" | grep -qiE '\*\*Status\*\*:\s*(DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED)'; then
    echo "Advisory: Subagent output missing standard Status protocol line."
  fi
fi

# Check advisory tag for mandatory agents
if [ -n "$agent_id" ]; then
  state_file="/tmp/robro-advisory-${agent_id}.state"
  if [ -f "$state_file" ]; then
    agent_type=$(grep '^agent_type=' "$state_file" | cut -d= -f2 | tr -d '[:space:]')
    rm -f "$state_file"

    if echo "$agent_type" | grep -qE '^(robro:architect|robro:reviewer|robro:critic)$'; then
      if ! echo "$output" | grep -q '<external_advisory'; then
        echo "Advisory: Mandatory agent (${agent_type}) output missing <external_advisory> tag. Consider consulting an external provider."
      fi
    fi
  fi
fi

exit 0
