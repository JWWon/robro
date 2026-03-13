#!/usr/bin/env bash
# Test: Task 2.3 — session-start.sh worktree scan for cross-session resume
# Validates C7: session-start.sh detects active worktree plans for cross-session resume

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/session-start.sh"
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

# Test 1: Script passes bash syntax check
if bash -n "$SCRIPT" 2>/dev/null; then
  pass "session-start.sh passes bash -n syntax check"
else
  fail "session-start.sh has syntax errors"
fi

# Test 2: Script references .claude/worktrees or WORKTREE_DIR
WORKTREE_REFS=$(grep -ic "worktree" "$SCRIPT" 2>/dev/null || true)
WORKTREE_REFS=$(echo "$WORKTREE_REFS" | tr -d '[:space:]')
if [ "$WORKTREE_REFS" -ge 5 ]; then
  pass "session-start.sh has at least 5 worktree references (found $WORKTREE_REFS)"
else
  fail "session-start.sh should have at least 5 worktree references, found $WORKTREE_REFS"
fi

# Test 3: Script contains WORKTREE_DIR variable assignment
if grep -q 'WORKTREE_DIR=' "$SCRIPT"; then
  pass "session-start.sh defines WORKTREE_DIR variable"
else
  fail "session-start.sh missing WORKTREE_DIR variable definition"
fi

# Test 4: Script scans worktree plan directories for status.yaml
if grep -q '\.claude/worktrees' "$SCRIPT" || grep -q '${wt_dir}docs/plans' "$SCRIPT" || grep -q '"${wt_dir}docs/plans"' "$SCRIPT"; then
  pass "session-start.sh scans worktree plan directories"
else
  fail "session-start.sh does not scan worktree plan directories for status.yaml"
fi

# Test 5: Script outputs EnterWorktree resume guidance
if grep -q 'EnterWorktree' "$SCRIPT"; then
  pass "session-start.sh includes EnterWorktree resume guidance"
else
  fail "session-start.sh missing EnterWorktree resume guidance"
fi

# Test 6: Worktree scan is a fallback (only runs if no active status found)
if grep -q 'WORKTREE RESUME' "$SCRIPT"; then
  pass "session-start.sh contains WORKTREE RESUME context marker"
else
  fail "session-start.sh missing WORKTREE RESUME context marker"
fi

# Test 7: The worktree block appears AFTER the main status.yaml scan and BEFORE the plan listing
WORKTREE_LINE=$(grep -n 'WORKTREE_DIR=' "$SCRIPT" 2>/dev/null | head -1 | cut -d: -f1)
MAIN_FI_LINE=$(grep -n '^fi$' "$SCRIPT" 2>/dev/null | head -1 | cut -d: -f1)
LIST_LINE=$(grep -n '# List all plans briefly' "$SCRIPT" 2>/dev/null | head -1 | cut -d: -f1)

if [ -n "$WORKTREE_LINE" ] && [ -n "$MAIN_FI_LINE" ] && [ -n "$LIST_LINE" ]; then
  if [ "$WORKTREE_LINE" -gt "$MAIN_FI_LINE" ] && [ "$WORKTREE_LINE" -lt "$LIST_LINE" ]; then
    pass "Worktree scan block is positioned after main scan fi and before plan listing"
  else
    fail "Worktree scan block position incorrect (worktree=$WORKTREE_LINE, main_fi=$MAIN_FI_LINE, list=$LIST_LINE)"
  fi
else
  fail "Could not determine block positions (worktree=$WORKTREE_LINE, main_fi=$MAIN_FI_LINE, list=$LIST_LINE)"
fi

# Test 8: Script reads wt_skill from status.yaml in worktree
if grep -q 'wt_skill' "$SCRIPT"; then
  pass "session-start.sh reads wt_skill from worktree status.yaml"
else
  fail "session-start.sh missing wt_skill extraction from worktree status.yaml"
fi

# === Summary ===
echo ""
echo "Results: $PASSES passed, $FAILURES failed"
if [ "$FAILURES" -gt 0 ]; then
  exit 1
else
  echo "All tests passed!"
  exit 0
fi
