#!/usr/bin/env bash
# Test: setup skill directory and frontmatter
# Validates that skills/setup/SKILL.md exists with correct structure

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

# Test 1: File exists
if [[ -f "$SKILL_FILE" ]]; then
  pass "skills/setup/SKILL.md exists"
else
  fail "skills/setup/SKILL.md does not exist"
  echo "Stopping early — file must exist for remaining tests."
  echo ""
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

# Test 2: Frontmatter starts with ---
HEAD=$(head -1 "$SKILL_FILE")
if [[ "$HEAD" == "---" ]]; then
  pass "Frontmatter opens with ---"
else
  fail "First line should be '---', got: '$HEAD'"
fi

# Test 3: name field is 'setup'
if grep -q '^name: setup$' "$SKILL_FILE"; then
  pass "name: setup present"
else
  fail "name: setup not found in frontmatter"
fi

# Test 4: disable-model-invocation is true
if grep -q '^disable-model-invocation: true$' "$SKILL_FILE"; then
  pass "disable-model-invocation: true present"
else
  fail "disable-model-invocation: true not found in frontmatter"
fi

# Test 5: description field exists and mentions setup/configure
if grep -q '^description:.*[Cc]onfigure' "$SKILL_FILE"; then
  pass "description mentions configure"
else
  fail "description should mention 'configure'"
fi

# Test 6: argument-hint field exists
if grep -q '^argument-hint:' "$SKILL_FILE"; then
  pass "argument-hint field present"
else
  fail "argument-hint field not found"
fi

# Test 7: Contains workflow steps
if grep -q '## Workflow' "$SKILL_FILE"; then
  pass "## Workflow section present"
else
  fail "## Workflow section not found"
fi

# Test 8: Contains CLAUDE.md section management step
if grep -q 'CLAUDE.md' "$SKILL_FILE"; then
  pass "CLAUDE.md management referenced"
else
  fail "CLAUDE.md management not referenced"
fi

# Test 9: Contains MCP/Skill detection step
if grep -q 'MCP' "$SKILL_FILE"; then
  pass "MCP detection referenced"
else
  fail "MCP detection not referenced"
fi

# Test 10: Contains .gitignore step
if grep -q '\.gitignore' "$SKILL_FILE"; then
  pass ".gitignore configuration referenced"
else
  fail ".gitignore configuration not referenced"
fi

# Test 11: Contains completion summary step
if grep -q 'Completion Summary' "$SKILL_FILE"; then
  pass "Completion Summary step present"
else
  fail "Completion Summary step not found"
fi

# Test 12: Frontmatter is properly closed
CLOSE_COUNT=$(head -20 "$SKILL_FILE" | grep -c '^---$')
if [[ "$CLOSE_COUNT" -ge 2 ]]; then
  pass "Frontmatter properly closed (two --- delimiters)"
else
  fail "Frontmatter not properly closed (expected 2 --- delimiters, found $CLOSE_COUNT)"
fi

echo ""
PASSED=$((12 - FAILURES))
echo "Results: $PASSED passed, $FAILURES failed"
exit $FAILURES
