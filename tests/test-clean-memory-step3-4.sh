#!/usr/bin/env bash
# Test: clean-memory skill Steps 3 & 4 — user confirmation and deletion
# Validates that skills/clean-memory/SKILL.md Steps 3 and 4 contain the
# full recommendation presentation and user confirmation/deletion workflow
# per spec items C8 and C9.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/clean-memory/SKILL.md"
FAILURES=0

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

# Precondition: file exists
if [[ ! -f "$SKILL_FILE" ]]; then
  fail "skills/clean-memory/SKILL.md does not exist"
  echo "Stopping early — file must exist for remaining tests."
  echo ""
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

# ============================================================
# Step 3: Present Analysis & Recommendations
# ============================================================

# Test 1: Step 3 placeholder is removed
if grep -q '{To be implemented in Task 4.4}' "$SKILL_FILE"; then
  fail "Step 3/4 placeholder still present — not implemented"
else
  pass "Step 3/4 placeholders removed"
fi

# Test 2: Step 3 uses AskUserQuestion for recommendations
if grep -q 'AskUserQuestion' "$SKILL_FILE"; then
  pass "Uses AskUserQuestion for user interaction"
else
  fail "Must use AskUserQuestion for presenting recommendations and plan confirmations"
fi

# Test 3: Recommendation presentation includes type and priority
if grep -q 'Type:.*agent\|type.*agent' "$SKILL_FILE" && grep -q 'Priority:.*high\|priority.*high' "$SKILL_FILE"; then
  pass "Recommendation presentation includes type and priority"
else
  fail "Must present recommendations with type (agent|skill|rule) and priority (high|medium|low)"
fi

# Test 4: Recommendation options include Apply, Skip, Discuss further
if grep -q 'Apply' "$SKILL_FILE" && grep -q 'Skip' "$SKILL_FILE" && grep -q 'Discuss further\|discuss further' "$SKILL_FILE"; then
  pass "Recommendation options: Apply, Skip, Discuss further"
else
  fail "Must offer Apply, Skip, and Discuss further options for each recommendation"
fi

# Test 5: Apply action creates appropriate files for each recommendation type
if grep -q 'agents/.*\.md\|\.claude/agents/' "$SKILL_FILE" && grep -q 'CLAUDE\.md\|rules/' "$SKILL_FILE"; then
  pass "Apply action creates appropriate files per recommendation type"
else
  fail "Must describe file creation for agent, skill, and rule recommendation types"
fi

# Test 6: Handles no-recommendations case
if grep -q 'no recommendation\|No recommendation\|skip to Step 4\|no actionable' "$SKILL_FILE"; then
  pass "Handles no-recommendations case (skip to Step 4)"
else
  fail "Must handle case where no recommendations exist (skip to Step 4)"
fi

# ============================================================
# Step 4: User Confirmation & Deletion
# ============================================================

# Test 7: Per-plan confirmation via AskUserQuestion (C8)
# AskUserQuestion is already checked in test 2; here we check it's per-plan
if grep -q 'For each completed plan\|each completed plan\|each plan' "$SKILL_FILE" | head -1 && grep -q 'AskUserQuestion' "$SKILL_FILE"; then
  pass "Per-plan confirmation via AskUserQuestion"
else
  fail "Must present each plan individually via AskUserQuestion (C8)"
fi

# Test 8: Lists committed files (preserved in git history) per plan (C8)
if grep -q 'preserved in git\|preserved.*git\|git history' "$SKILL_FILE"; then
  pass "Lists committed files as preserved in git history"
else
  fail "Must indicate committed files are preserved in git history (C8)"
fi

# Test 9: Lists gitignored files with PERMANENTLY DELETED warning (C8)
if grep -q 'PERMANENTLY DELETED\|PERMANENTLY deleted\|permanently deleted' "$SKILL_FILE"; then
  pass "PERMANENTLY DELETED warning for gitignored files"
else
  fail "Must include PERMANENTLY DELETED warning for gitignored files (C8)"
fi

# Test 10: Specific gitignored files listed (research/, discussion/, status.yaml, *.bak.*)
if grep -q 'research/' "$SKILL_FILE" && grep -q 'discussion/' "$SKILL_FILE" && grep -q 'status\.yaml' "$SKILL_FILE" && grep -q '\.bak\.' "$SKILL_FILE"; then
  pass "Specific gitignored files listed in deletion prompt"
else
  fail "Must list specific gitignored files: research/, discussion/, status.yaml, *.bak.* (C8)"
fi

# Test 11: Options include Delete, Keep, Delete all remaining
if grep -q '"Delete"' "$SKILL_FILE" && grep -q '"Keep"' "$SKILL_FILE" && grep -q 'Delete all remaining' "$SKILL_FILE"; then
  pass 'Options: "Delete", "Keep", "Delete all remaining"'
else
  fail 'Must offer "Delete", "Keep", "Delete all remaining" options (C8)'
fi

# Test 12: Uses rm -rf for deletion (C9)
if grep -q 'rm -rf' "$SKILL_FILE"; then
  pass "Uses rm -rf for plan directory deletion"
else
  fail "Must use rm -rf to delete entire plan directory (C9)"
fi

# Test 13: Deletes entire plan directory (C9)
if grep -q 'rm -rf docs/plans/' "$SKILL_FILE" || grep -q 'rm -rf.*{plan_name}\|rm -rf.*plan_name\|rm -rf.*plan dir' "$SKILL_FILE"; then
  pass "Deletes entire plan directory path"
else
  fail "Must delete entire docs/plans/{plan_name}/ directory (C9)"
fi

# Test 14: "Delete all remaining" applies to current and all remaining plans
if grep -q 'all remaining\|remaining plans\|without further prompt' "$SKILL_FILE"; then
  pass "Delete all remaining applies to current + remaining plans"
else
  fail "Must document that 'Delete all remaining' applies to current plan AND all remaining"
fi

# Test 15: Reports summary after all plans processed
if grep -q 'plans deleted\|plans kept\|summary' "$SKILL_FILE"; then
  pass "Reports summary of deleted/kept plans"
else
  fail "Must report summary: N plans deleted, M plans kept"
fi

# Test 16: Suggests committing if recommendations were applied
if grep -q 'committing\|commit.*changes\|Commit\|commit.*recommend' "$SKILL_FILE"; then
  pass "Suggests committing changes if recommendations were applied"
else
  fail "Must suggest committing changes if recommendations were applied in Step 3"
fi

# Test 17: Minimum keyword count check from plan.md verify step
# grep -c 'PERMANENTLY|AskUserQuestion|rm -rf' should return 3+
KEYWORD_COUNT=$(grep -c 'PERMANENTLY\|AskUserQuestion\|rm -rf' "$SKILL_FILE" || true)
if [[ "$KEYWORD_COUNT" -ge 3 ]]; then
  pass "Sufficient keyword references (found $KEYWORD_COUNT, need 3+)"
else
  fail "Insufficient keyword references: PERMANENTLY|AskUserQuestion|rm -rf (found $KEYWORD_COUNT, need 3+)"
fi

echo ""
TOTAL=17
PASSED=$((TOTAL - FAILURES))
echo "Results: $PASSED passed, $FAILURES failed"
exit $FAILURES
