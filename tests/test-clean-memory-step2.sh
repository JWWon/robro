#!/usr/bin/env bash
# Test: clean-memory skill Step 2 — cross-plan pattern analysis
# Validates that skills/clean-memory/SKILL.md Step 2 contains the
# full cross-plan pattern analysis workflow per spec item C7.

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

# Test 1: Step 2 placeholder is removed
if grep -q '{To be implemented in Task 4.3}' "$SKILL_FILE"; then
  fail "Step 2 placeholder still present — not implemented"
else
  pass "Step 2 placeholder removed"
fi

# Test 2: Reads spec-mutations.log from each plan
if grep -q 'spec-mutations\.log' "$SKILL_FILE"; then
  pass "References spec-mutations.log"
else
  fail "Must reference spec-mutations.log as a data source"
fi

# Test 3: Parses TSV format with correct column names
if grep -q 'TSV\|tab-separated\|tab.separated' "$SKILL_FILE" && grep -q 'timestamp' "$SKILL_FILE"; then
  pass "Documents TSV parsing format"
else
  fail "Must document TSV format parsing of spec-mutations.log"
fi

# Test 4: Extracts ADD, SUPERSEDE, and FLIP operations
if grep -q 'ADD' "$SKILL_FILE" && grep -q 'SUPERSEDE' "$SKILL_FILE" && grep -q 'FLIP' "$SKILL_FILE"; then
  pass "Extracts ADD, SUPERSEDE, and FLIP operations"
else
  fail "Must extract ADD, SUPERSEDE, and FLIP mutation operations"
fi

# Test 5: Reads spec.yaml from each plan
if grep -q 'spec\.yaml' "$SKILL_FILE"; then
  pass "References spec.yaml as data source"
else
  fail "Must reference spec.yaml as a data source for analysis"
fi

# Test 6: Aggregates recurring mutation types across plans
if grep -q 'recurring\|Recurring' "$SKILL_FILE" && grep -q 'mutation' "$SKILL_FILE"; then
  pass "Aggregates recurring mutation types"
else
  fail "Must aggregate recurring mutation types across plans"
fi

# Test 7: Identifies common section patterns
if grep -q 'section pattern\|Common section\|common section' "$SKILL_FILE"; then
  pass "Identifies common section patterns across plans"
else
  fail "Must identify common section patterns across plans"
fi

# Test 8: Calculates build velocity metrics
if grep -q 'velocity\|Velocity' "$SKILL_FILE"; then
  pass "Calculates build velocity"
else
  fail "Must calculate build velocity (items vs passed vs superseded)"
fi

# Test 9: Compares against current agents
if grep -q 'agents/\*\.md\|agents/' "$SKILL_FILE" && grep -q 'agent' "$SKILL_FILE"; then
  pass "Compares patterns against current agents"
else
  fail "Must compare patterns against current agents (agents/*.md)"
fi

# Test 10: Compares against current skills
if grep -q 'skills/\*/SKILL\.md\|skills/' "$SKILL_FILE"; then
  pass "Compares patterns against current skills"
else
  fail "Must compare patterns against current skills"
fi

# Test 11: Compares against CLAUDE.md for rules
if grep -q 'CLAUDE\.md' "$SKILL_FILE"; then
  pass "Compares patterns against CLAUDE.md rules"
else
  fail "Must compare patterns against CLAUDE.md for existing rules"
fi

# Test 12: Generates typed recommendations (agent | skill | rule)
if grep -q 'recommendation\|Recommendation' "$SKILL_FILE" && grep -q 'agent.*skill.*rule\|Type:.*agent\|type.*agent' "$SKILL_FILE"; then
  pass "Generates typed recommendations (agent | skill | rule)"
else
  fail "Must generate typed recommendations with type: agent | skill | rule"
fi

# Test 13: Recommendations include evidence and priority
if grep -q 'Evidence\|evidence' "$SKILL_FILE" && grep -q 'Priority\|priority' "$SKILL_FILE"; then
  pass "Recommendations include evidence and priority"
else
  fail "Must include evidence and priority in each recommendation"
fi

# Test 14: Handles single-plan case
if grep -q 'single plan\|Single plan\|only 1\|1 completed' "$SKILL_FILE"; then
  pass "Handles single completed plan case"
else
  fail "Must handle case where only 1 completed plan exists (cross-plan comparison limited)"
fi

# Test 15: Handles missing spec-mutations.log gracefully
if grep -q "no mutation log\|doesn't exist\|does not exist\|file missing\|not exist" "$SKILL_FILE"; then
  pass "Handles missing spec-mutations.log gracefully"
else
  fail "Must handle missing spec-mutations.log (skip mutation analysis for that plan)"
fi

# Test 16: Minimum reference count for cross-plan analysis keywords
# Plan.md specifies: grep -c 'spec-mutations.log|cross-plan|recommendation' should return 5+
CROSSPLAN_COUNT=$(grep -c 'spec-mutations\.log\|cross-plan\|recommendation' "$SKILL_FILE" || true)
if [[ "$CROSSPLAN_COUNT" -ge 5 ]]; then
  pass "Sufficient cross-plan analysis references (found $CROSSPLAN_COUNT, need 5+)"
else
  fail "Insufficient cross-plan analysis references (found $CROSSPLAN_COUNT, need 5+)"
fi

echo ""
TOTAL=16
PASSED=$((TOTAL - FAILURES))
echo "Results: $PASSED passed, $FAILURES failed"
exit $FAILURES
