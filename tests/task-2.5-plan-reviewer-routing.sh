#!/usr/bin/env bash
# Test: plan skill uses standard status protocol for reviewer routing
# Task 2.5: Update plan skill reviewer routing

set -euo pipefail

SKILL_FILE="skills/plan/SKILL.md"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$REPO_ROOT/$SKILL_FILE"

errors=0

# Test 1: Standard statuses are present (need more than the 3 from generic routing)
count=$(grep -c 'DONE_WITH_CONCERNS\|NEEDS_CONTEXT\|BLOCKED' "$FILE" || true)
if [ "$count" -ge 6 ]; then
  echo "PASS: Found $count references to standard status protocol (reviewer sections included)"
else
  echo "FAIL: Expected >= 6 references to standard statuses, found $count (reviewer routing not updated)"
  errors=$((errors + 1))
fi

# Test 2: No legacy APPROVED or ISSUES_FOUND references
legacy=$(grep -ci 'APPROVED\|ISSUES_FOUND' "$FILE" || true)
if [ "$legacy" -eq 0 ]; then
  echo "PASS: No legacy APPROVED/ISSUES_FOUND references"
else
  echo "FAIL: Found $legacy legacy APPROVED/ISSUES_FOUND references"
  errors=$((errors + 1))
fi

# Test 3: Step 5 has explicit status routing
step5_routing=$(sed -n '/### Step 5:/,/### Step 5.5:/p' "$FILE" | grep -c 'DONE\|DONE_WITH_CONCERNS\|NEEDS_CONTEXT\|BLOCKED' || true)
if [ "$step5_routing" -ge 4 ]; then
  echo "PASS: Step 5 has $step5_routing status routing references"
else
  echo "FAIL: Step 5 missing status routing (found $step5_routing, need >= 4)"
  errors=$((errors + 1))
fi

# Test 4: Step 7 has explicit status routing
step7_routing=$(sed -n '/### Step 7:/,/### Step 8:/p' "$FILE" | grep -c 'DONE\|DONE_WITH_CONCERNS\|NEEDS_CONTEXT\|BLOCKED' || true)
if [ "$step7_routing" -ge 4 ]; then
  echo "PASS: Step 7 has $step7_routing status routing references"
else
  echo "FAIL: Step 7 missing status routing (found $step7_routing, need >= 4)"
  errors=$((errors + 1))
fi

if [ "$errors" -gt 0 ]; then
  echo "FAILED: $errors test(s) failed"
  exit 1
fi

echo "All tests passed"
