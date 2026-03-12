#!/usr/bin/env bash
# Test: setup skill — CLAUDE.md section management workflow (Task 3.3)
# Validates that Step 1 of skills/setup/SKILL.md contains the full
# CLAUDE.md management workflow per spec items C1, C2, C5.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/setup/SKILL.md"
FAILURES=0

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

# Prerequisite: file must exist
if [[ ! -f "$SKILL_FILE" ]]; then
  fail "skills/setup/SKILL.md does not exist"
  echo "Stopping early — file must exist for remaining tests."
  echo ""
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

# Test 1: Placeholder is gone
if grep -q '{To be implemented in Task 3.3}' "$SKILL_FILE"; then
  fail "Placeholder '{To be implemented in Task 3.3}' still present"
else
  pass "Placeholder removed"
fi

# Test 2: References robro:managed:start marker (at least once for detection logic)
START_COUNT=$(grep -c 'robro:managed:start' "$SKILL_FILE" || true)
if [[ "$START_COUNT" -ge 2 ]]; then
  pass "robro:managed:start marker referenced $START_COUNT times (detection + usage)"
else
  fail "robro:managed:start should appear 2+ times, found $START_COUNT"
fi

# Test 3: References robro:managed:end marker
END_COUNT=$(grep -c 'robro:managed:end' "$SKILL_FILE" || true)
if [[ "$END_COUNT" -ge 2 ]]; then
  pass "robro:managed:end marker referenced $END_COUNT times (detection + usage)"
else
  fail "robro:managed:end should appear 2+ times, found $END_COUNT"
fi

# Test 4: Total robro:managed references (start + end combined) >= 4
TOTAL_COUNT=$(grep -c 'robro:managed' "$SKILL_FILE" || true)
if [[ "$TOTAL_COUNT" -ge 4 ]]; then
  pass "Total robro:managed references: $TOTAL_COUNT (>= 4)"
else
  fail "Total robro:managed references should be >= 4, found $TOTAL_COUNT"
fi

# Test 5: References the template file
if grep -q 'claude-md-template.md' "$SKILL_FILE"; then
  pass "References claude-md-template.md template file"
else
  fail "Should reference claude-md-template.md template file"
fi

# Test 6: References reading the template via plugin root path
if grep -q 'CLAUDE_PLUGIN_ROOT' "$SKILL_FILE"; then
  pass "References \${CLAUDE_PLUGIN_ROOT} for template path"
else
  fail "Should reference \${CLAUDE_PLUGIN_ROOT} for template path"
fi

# Test 7: Contains idempotency check (compare / identical / unchanged / skip / no changes)
if grep -qi 'identical\|unchanged\|already current\|no changes\|idempoten\|skip' "$SKILL_FILE"; then
  pass "Contains idempotency check language"
else
  fail "Should contain idempotency logic (identical/unchanged/skip)"
fi

# Test 8: Handles file-does-not-exist case
if grep -qi 'does not exist\|not exist\|create.*\.claude/' "$SKILL_FILE"; then
  pass "Handles file-does-not-exist case"
else
  fail "Should handle case where .claude/CLAUDE.md does not exist"
fi

# Test 9: Handles start-without-end edge case
if grep -qi 'without.*end\|start.*without\|missing.*end\|no.*end.*marker' "$SKILL_FILE"; then
  pass "Handles start-without-end marker edge case"
else
  fail "Should handle start marker without end marker edge case"
fi

# Test 10: Handles duplicate markers edge case
if grep -qi 'duplicate\|multiple.*marker\|multiple.*pair\|first.*pair' "$SKILL_FILE"; then
  pass "Handles duplicate markers edge case"
else
  fail "Should handle duplicate marker pairs edge case"
fi

# Test 11: Handles markers inside code blocks
if grep -qi 'code block\|fenced\|triple.*backtick\|ignore.*marker' "$SKILL_FILE"; then
  pass "Handles markers inside code blocks"
else
  fail "Should handle markers inside triple-backtick code blocks"
fi

# Test 12: Contains project root detection
if grep -q 'git rev-parse\|PROJECT_ROOT\|project root' "$SKILL_FILE"; then
  pass "Contains project root detection"
else
  fail "Should contain project root detection (git rev-parse or PROJECT_ROOT)"
fi

# Test 13: Reports what was done (action feedback)
if grep -qi 'Created.*CLAUDE.md\|Updated.*robro section\|already current\|no changes' "$SKILL_FILE"; then
  pass "Contains action reporting messages"
else
  fail "Should report what action was taken (created/updated/unchanged)"
fi

# Test 14: References .claude/ directory creation
if grep -q '\.claude/' "$SKILL_FILE"; then
  pass "References .claude/ directory"
else
  fail "Should reference .claude/ directory"
fi

echo ""
TOTAL=14
PASSED=$((TOTAL - FAILURES))
echo "Results: $PASSED passed, $FAILURES failed"
exit $FAILURES
