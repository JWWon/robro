#!/usr/bin/env bash
# Test: verify-deliverables.sh — tool_result bug fix + advisory tag check
# Validates spec items C6, C7

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/verify-deliverables.sh"
FAILURES=0
PASSES=0

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
  PASSES=$((PASSES + 1))
}

# ===========================================================================
# Prerequisites
# ===========================================================================

if [[ ! -f "$SCRIPT" ]]; then
  fail "scripts/verify-deliverables.sh does not exist"
  echo ""
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

if [[ ! -x "$SCRIPT" ]]; then
  fail "scripts/verify-deliverables.sh is not executable"
  echo ""
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

if bash -n "$SCRIPT" 2>/dev/null; then
  pass "scripts/verify-deliverables.sh passes bash -n syntax check"
else
  fail "scripts/verify-deliverables.sh fails bash -n syntax check"
fi

# ===========================================================================
# C6: Read last_assistant_message (not tool_result) — bug fix
# ===========================================================================

# Test 1: Empty last_assistant_message → no false positives
result=$(echo '{"last_assistant_message": ""}' | bash "$SCRIPT" 2>&1)
if [[ -z "$result" ]]; then
  pass "C6: empty last_assistant_message produces no output"
else
  fail "C6: empty last_assistant_message produced unexpected output: $result"
fi

# Test 2: Message with Status protocol → no warning
result=$(echo '{"last_assistant_message": "Some output here\n\n**Status**: DONE\n\nAll done."}' | bash "$SCRIPT" 2>&1)
if ! echo "$result" | grep -qi "missing standard Status protocol"; then
  pass "C6: message with Status protocol produces no status warning"
else
  fail "C6: message with Status protocol incorrectly triggered status warning: $result"
fi

# Test 3: Message without Status protocol → warning emitted
result=$(echo '{"last_assistant_message": "Some output here without any status line."}' | bash "$SCRIPT" 2>&1)
if echo "$result" | grep -qi "missing standard Status protocol"; then
  pass "C6: message without Status protocol correctly triggers status warning"
else
  fail "C6: message without Status protocol did not trigger status warning. Output: $result"
fi

# Verify it no longer reads .tool_result (the old buggy field)
result=$(echo '{"tool_result": "Some output here without any status line."}' | bash "$SCRIPT" 2>&1)
if ! echo "$result" | grep -qi "missing standard Status protocol"; then
  pass "C6: script ignores .tool_result field (old buggy behavior gone)"
else
  fail "C6: script still reads .tool_result (old bug not fixed). Output: $result"
fi

# ===========================================================================
# C7: Advisory tag check for mandatory agents
# ===========================================================================

TEST_ID_MANDATORY="c7-mandatory-$$"
TEST_ID_OPTIONAL="c7-optional-$$"
TEST_ID_NO_TAG="c7-notag-$$"

# Clean up any leftover state files
rm -f "/tmp/robro-advisory-${TEST_ID_MANDATORY}.state"
rm -f "/tmp/robro-advisory-${TEST_ID_OPTIONAL}.state"
rm -f "/tmp/robro-advisory-${TEST_ID_NO_TAG}.state"

# Test 4: Mandatory agent with <external_advisory> tag → no advisory warning
cat > "/tmp/robro-advisory-${TEST_ID_MANDATORY}.state" <<EOF
agent_type=robro:architect
agent_id=${TEST_ID_MANDATORY}
EOF

input=$(cat <<EOF
{
  "agent_id": "${TEST_ID_MANDATORY}",
  "last_assistant_message": "**Status**: DONE\n\nHere is my analysis.\n\n<external_advisory source=\"gemini\">some advice</external_advisory>\n\nAll done."
}
EOF
)
result=$(echo "$input" | bash "$SCRIPT" 2>&1)
if ! echo "$result" | grep -qi "advisory tag"; then
  pass "C7: mandatory agent with external_advisory tag produces no advisory warning"
else
  fail "C7: mandatory agent with external_advisory tag incorrectly triggered advisory warning: $result"
fi

# Verify state file was cleaned up
if [[ ! -f "/tmp/robro-advisory-${TEST_ID_MANDATORY}.state" ]]; then
  pass "C7: state file cleaned up after mandatory agent check"
else
  fail "C7: state file was not cleaned up after mandatory agent check"
  rm -f "/tmp/robro-advisory-${TEST_ID_MANDATORY}.state"
fi

# Test 5: Mandatory agent without <external_advisory> tag → advisory warning emitted
cat > "/tmp/robro-advisory-${TEST_ID_NO_TAG}.state" <<EOF
agent_type=robro:reviewer
agent_id=${TEST_ID_NO_TAG}
EOF

input=$(cat <<EOF
{
  "agent_id": "${TEST_ID_NO_TAG}",
  "last_assistant_message": "**Status**: DONE\n\nHere is my review. No external advisory consulted."
}
EOF
)
result=$(echo "$input" | bash "$SCRIPT" 2>&1)
if echo "$result" | grep -qi "external_advisory"; then
  pass "C7: mandatory agent without external_advisory tag triggers advisory warning"
else
  fail "C7: mandatory agent without external_advisory tag did not trigger advisory warning. Output: $result"
fi

# Verify state file was cleaned up
if [[ ! -f "/tmp/robro-advisory-${TEST_ID_NO_TAG}.state" ]]; then
  pass "C7: state file cleaned up after no-tag check"
else
  fail "C7: state file was not cleaned up after no-tag check"
  rm -f "/tmp/robro-advisory-${TEST_ID_NO_TAG}.state"
fi

# Test 6: Non-mandatory agent (optional) → no advisory warning even without tag
cat > "/tmp/robro-advisory-${TEST_ID_OPTIONAL}.state" <<EOF
agent_type=robro:researcher
agent_id=${TEST_ID_OPTIONAL}
EOF

input=$(cat <<EOF
{
  "agent_id": "${TEST_ID_OPTIONAL}",
  "last_assistant_message": "**Status**: DONE\n\nHere is my research. No external advisory tag."
}
EOF
)
result=$(echo "$input" | bash "$SCRIPT" 2>&1)
if ! echo "$result" | grep -qi "external_advisory"; then
  pass "C7: non-mandatory agent without tag produces no advisory warning"
else
  fail "C7: non-mandatory agent incorrectly triggered advisory warning: $result"
fi

# Verify state file cleaned up
if [[ ! -f "/tmp/robro-advisory-${TEST_ID_OPTIONAL}.state" ]]; then
  pass "C7: state file cleaned up for optional agent"
else
  fail "C7: state file was not cleaned up for optional agent"
  rm -f "/tmp/robro-advisory-${TEST_ID_OPTIONAL}.state"
fi

# Test 7: No state file → no advisory warning (graceful when no agent_id)
result=$(echo '{"last_assistant_message": "**Status**: DONE\n\nNo agent context here."}' | bash "$SCRIPT" 2>&1)
if ! echo "$result" | grep -qi "external_advisory"; then
  pass "C7: missing state file produces no advisory warning"
else
  fail "C7: missing state file incorrectly triggered advisory warning: $result"
fi

# Test 8: Critic agent (also mandatory) without tag → advisory warning
TEST_ID_CRITIC="c7-critic-$$"
cat > "/tmp/robro-advisory-${TEST_ID_CRITIC}.state" <<EOF
agent_type=robro:critic
agent_id=${TEST_ID_CRITIC}
EOF

input=$(cat <<EOF
{
  "agent_id": "${TEST_ID_CRITIC}",
  "last_assistant_message": "**Status**: DONE\n\nCritic analysis complete. Verdict: PASS."
}
EOF
)
result=$(echo "$input" | bash "$SCRIPT" 2>&1)
if echo "$result" | grep -qi "external_advisory"; then
  pass "C7: robro:critic without external_advisory tag triggers advisory warning"
else
  fail "C7: robro:critic without external_advisory tag did not trigger advisory warning. Output: $result"
fi

# Cleanup
rm -f "/tmp/robro-advisory-${TEST_ID_CRITIC}.state"

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "Results: ${PASSES} passed, ${FAILURES} failed"

if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
exit 0
