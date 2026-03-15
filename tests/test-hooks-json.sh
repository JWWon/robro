#!/usr/bin/env bash
set -euo pipefail
HOOKS="$(cd "$(dirname "$0")/.." && pwd)/hooks/hooks.json"

if jq -e '.hooks.SubagentStart' "$HOOKS" > /dev/null 2>&1; then
  if jq -r '.hooks.SubagentStart[].hooks[].command' "$HOOKS" 2>/dev/null | grep -q "advisory-start.sh"; then
    echo "PASS: SubagentStart hook points to advisory-start.sh"
    exit 0
  else
    echo "FAIL: SubagentStart exists but does not point to advisory-start.sh"
    exit 1
  fi
else
  echo "FAIL: No SubagentStart key in hooks.json"
  exit 1
fi
