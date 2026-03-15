#!/usr/bin/env bash
set -euo pipefail
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${PLUGIN_ROOT}/scripts/advisory-start.sh"

pass=0; fail=0

# Test 1: non-mandatory agent → no hookSpecificOutput
output=$(echo '{"agent_type":"robro:builder","agent_id":"test-001"}' | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$SCRIPT" 2>/dev/null || true)
if echo "$output" | grep -q "hookSpecificOutput"; then
  echo "FAIL: non-mandatory emitted output"; fail=$((fail+1))
else
  echo "PASS: non_mandatory_silent"; pass=$((pass+1))
fi

# Test 2: missing agent_type → no output
output=$(echo '{"agent_id":"test-002"}' | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$SCRIPT" 2>/dev/null || true)
if echo "$output" | grep -q "hookSpecificOutput"; then
  echo "FAIL: missing_type emitted output"; fail=$((fail+1))
else
  echo "PASS: missing_type_silent"; pass=$((pass+1))
fi

# Test 3: no state file for non-mandatory
FAKE_ID="test-nonmandatory-$$"
echo '{"agent_type":"robro:builder","agent_id":"'"$FAKE_ID"'"}' | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$SCRIPT" 2>/dev/null || true
if [ ! -f "/tmp/robro-advisory-${FAKE_ID}.state" ]; then
  echo "PASS: no_state_for_nonmandatory"; pass=$((pass+1))
else
  echo "FAIL: state written for non-mandatory"; rm -f "/tmp/robro-advisory-${FAKE_ID}.state"; fail=$((fail+1))
fi

# Test 4: syntax check
if bash -n "$SCRIPT" 2>/dev/null; then
  echo "PASS: syntax_check"; pass=$((pass+1))
else
  echo "FAIL: syntax_check"; fail=$((fail+1))
fi

# Test 5: is executable
if [ -x "$SCRIPT" ]; then
  echo "PASS: is_executable"; pass=$((pass+1))
else
  echo "FAIL: is_executable"; fail=$((fail+1))
fi

echo ""; echo "Results: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
