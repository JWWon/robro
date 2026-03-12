#!/usr/bin/env bash
# Test: clean-memory skill Step 1 — plan completion detection
# Validates that skills/clean-memory/SKILL.md Step 1 contains the
# full plan completion detection workflow per spec item C6.

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

# Test 1: Placeholder is removed
if grep -q '{To be implemented in Task 4.2}' "$SKILL_FILE"; then
  fail "Step 1 placeholder still present — not implemented"
else
  pass "Step 1 placeholder removed"
fi

# Test 2: References plan-root status.yaml (primary check)
if grep -q 'status\.yaml' "$SKILL_FILE" && grep -q 'plan.root\|plan root\|plan_dir.*status\.yaml\|{plan_dir}/status\.yaml' "$SKILL_FILE"; then
  pass "References plan-root status.yaml (primary check)"
else
  fail "Must reference plan-root status.yaml as primary completion check"
fi

# Test 3: References discussion/ status.yaml (legacy check)
if grep -q 'discussion/status\.yaml\|discussion.*status\.yaml.*legacy\|legacy.*discussion' "$SKILL_FILE"; then
  pass "References discussion/status.yaml (legacy check)"
else
  fail "Must reference discussion/status.yaml as legacy fallback"
fi

# Test 4: Checks for skill: none in status.yaml
if grep -q 'skill: none\|skill:.*none' "$SKILL_FILE"; then
  pass "Checks for 'skill: none' value in status.yaml"
else
  fail "Must check for 'skill: none' to identify completed plans"
fi

# Test 5: spec.yaml heuristic fallback when no status.yaml exists
if grep -q 'spec\.yaml' "$SKILL_FILE" && grep -q 'heuristic\|fallback' "$SKILL_FILE"; then
  pass "spec.yaml heuristic fallback documented"
else
  fail "Must document spec.yaml heuristic fallback when no status.yaml exists"
fi

# Test 6: Checks for superseded items in spec.yaml heuristic
if grep -q 'supersed' "$SKILL_FILE"; then
  pass "Handles superseded items in spec.yaml heuristic"
else
  fail "Must handle superseded items (skip them) in spec.yaml heuristic"
fi

# Test 7: Checks that all non-superseded items must have passes: true
if grep -q 'passes: true\|passes.*true' "$SKILL_FILE"; then
  pass "Checks for passes: true on checklist items"
else
  fail "Must check that all non-superseded items have passes: true"
fi

# Test 8: Uses Glob tool for directory discovery
if grep -q 'Glob\|glob' "$SKILL_FILE"; then
  pass "Uses Glob tool for plan directory discovery"
else
  fail "Must use Glob tool (not bash) for plan directory discovery"
fi

# Test 9: Uses Read tool for file inspection
if grep -q 'Read' "$SKILL_FILE"; then
  pass "Uses Read tool for file inspection"
else
  fail "Must use Read tool (not bash) for file reading"
fi

# Test 10: Builds metadata list with completion source
if grep -q 'completion source\|Completion source\|completion_source' "$SKILL_FILE"; then
  pass "Tracks completion source metadata"
else
  fail "Must track completion source (plan-root status.yaml / discussion/ / spec.yaml heuristic)"
fi

# Test 11: Checks for committed files (idea.md, plan.md, spec.yaml, spec-mutations.log)
if grep -q 'idea\.md' "$SKILL_FILE" && grep -q 'plan\.md' "$SKILL_FILE" && grep -q 'spec-mutations\.log' "$SKILL_FILE"; then
  pass "Inventories committed files present"
else
  fail "Must inventory committed files (idea.md, plan.md, spec.yaml, spec-mutations.log)"
fi

# Test 12: Checks for gitignored files (research/, discussion/, status.yaml, *.bak.*)
if grep -q 'research/' "$SKILL_FILE" && grep -q '\.bak\.' "$SKILL_FILE"; then
  pass "Inventories gitignored files present"
else
  fail "Must inventory gitignored files (research/, discussion/, status.yaml, *.bak.*)"
fi

# Test 13: Handles no-completed-plans case
if grep -q 'No completed plans\|no completed plans' "$SKILL_FILE"; then
  pass "Handles no-completed-plans case"
else
  fail "Must handle case where no completed plans are found"
fi

# Test 14: Minimum reference count for status.yaml and discussion/ paths
# Spec requires at least 4 references to ensure dual-path detection is thorough
STATUS_COUNT=$(grep -c 'status\.yaml\|discussion/' "$SKILL_FILE" || true)
if [[ "$STATUS_COUNT" -ge 4 ]]; then
  pass "Sufficient references to status.yaml/discussion/ paths (found $STATUS_COUNT, need 4+)"
else
  fail "Insufficient references to status.yaml/discussion/ paths (found $STATUS_COUNT, need 4+)"
fi

echo ""
TOTAL=14
PASSED=$((TOTAL - FAILURES))
echo "Results: $PASSED passed, $FAILURES failed"
exit $FAILURES
