#!/usr/bin/env bash
# Test: review skill directory and frontmatter
# Validates that skills/review/SKILL.md exists with correct structure per spec C3, C4, C5

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/review/SKILL.md"
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
  pass "skills/review/SKILL.md exists"
else
  fail "skills/review/SKILL.md does not exist"
  echo "Stopping early — file must exist for remaining tests."
  echo ""
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

# Test 2 (C3): frontmatter name: review
if grep -q '^name: review$' "$SKILL_FILE"; then
  pass "frontmatter contains 'name: review'"
else
  fail "frontmatter missing 'name: review'"
fi

# Test 3 (C3): Mode Detection section exists
if grep -q 'Mode Detection' "$SKILL_FILE"; then
  pass "Mode Detection section exists"
else
  fail "Mode Detection section missing"
fi

# Test 4 (C3): priority chain — explicit flag
if grep -q 'Explicit flag' "$SKILL_FILE" || grep -q 'explicit flag' "$SKILL_FILE"; then
  pass "Mode Detection contains explicit flag priority"
else
  fail "Mode Detection missing explicit flag priority"
fi

# Test 5 (C3): priority chain — bug keywords
if grep -q 'Bug keywords' "$SKILL_FILE" || grep -q 'bug keywords' "$SKILL_FILE"; then
  pass "Mode Detection contains bug keywords priority"
else
  fail "Mode Detection missing bug keywords priority"
fi

# Test 6 (C3): priority chain — plan phase
if grep -q 'Plan phase' "$SKILL_FILE" || grep -q 'plan phase' "$SKILL_FILE"; then
  pass "Mode Detection contains plan phase priority"
else
  fail "Mode Detection missing plan phase priority"
fi

# Test 7 (C3): priority chain — code diff
if grep -q 'Code diff' "$SKILL_FILE" || grep -q 'code diff' "$SKILL_FILE"; then
  pass "Mode Detection contains code diff priority"
else
  fail "Mode Detection missing code diff priority"
fi

# Test 8 (C3): status-review.yaml write instructions
if grep -q 'status-review.yaml' "$SKILL_FILE"; then
  pass "SKILL.md contains status-review.yaml write instructions"
else
  fail "SKILL.md missing status-review.yaml write instructions"
fi

# Test 9 (C4): report template with Summary section
if grep -q 'Summary' "$SKILL_FILE"; then
  pass "Report template contains Summary section"
else
  fail "Report template missing Summary section"
fi

# Test 10 (C4): report template with Findings section
if grep -q 'Findings' "$SKILL_FILE"; then
  pass "Report template contains Findings section"
else
  fail "Report template missing Findings section"
fi

# Test 11 (C4): report template with Spec Coverage section
if grep -q 'Spec Coverage' "$SKILL_FILE"; then
  pass "Report template contains Spec Coverage section"
else
  fail "Report template missing Spec Coverage section"
fi

# Test 12 (C4): report template with Suggested Spec Flips section
if grep -q 'Suggested Spec Flips' "$SKILL_FILE"; then
  pass "Report template contains Suggested Spec Flips section"
else
  fail "Report template missing Suggested Spec Flips section"
fi

# Test 13 (C4): report template with Recommended Actions section
if grep -q 'Recommended Actions' "$SKILL_FILE"; then
  pass "Report template contains Recommended Actions section"
else
  fail "Report template missing Recommended Actions section"
fi

# Test 14 (C5): AskUserQuestion usage
if grep -q 'AskUserQuestion' "$SKILL_FILE"; then
  pass "SKILL.md contains AskUserQuestion usage"
else
  fail "SKILL.md missing AskUserQuestion usage"
fi

# Test 15 (C5): review is read-only w.r.t. spec.yaml until confirmed
if grep -q 'read-only\|never.*auto-flip\|NEVER flip\|Never.*flip' "$SKILL_FILE"; then
  pass "SKILL.md states review is read-only until user confirms"
else
  fail "SKILL.md missing read-only spec.yaml statement"
fi

# Test 16 (C5): FLIP logged to spec-mutations.log with REVIEW source
if grep -q 'FLIP' "$SKILL_FILE" && grep -q 'spec-mutations.log' "$SKILL_FILE" && grep -q 'REVIEW' "$SKILL_FILE"; then
  pass "SKILL.md contains FLIP logging to spec-mutations.log with REVIEW source"
else
  fail "SKILL.md missing FLIP logging pattern with REVIEW source"
fi

# Summary
echo ""
TOTAL=16
PASSED=$((TOTAL - FAILURES))
echo "Results: $PASSED passed, $FAILURES failed"

if [[ $FAILURES -gt 0 ]]; then
  exit 1
fi
exit 0
