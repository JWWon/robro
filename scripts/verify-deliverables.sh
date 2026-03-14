#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
output=$(echo "$input" | jq -r '.tool_result // ""' 2>/dev/null)
if [ -n "$output" ]; then
  if ! echo "$output" | grep -qiE '\*\*Status\*\*:\s*(DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED)'; then
    echo "Advisory: Subagent output missing standard Status protocol line."
  fi
fi
