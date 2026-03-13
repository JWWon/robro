#!/usr/bin/env bash
# Test: Task 5.1 — Merge approval flow in converge-phase.md
# Validates C8, C9, C18, C19
# C8: AskUserQuestion merge approval with Merge/Keep/Discard options
# C9: Squash merge flow: ExitWorktree → git merge --squash → commit → worktree remove → branch delete
# C18: ExitWorktree called with 'keep' action before squash merge
# C19: Worktree and branch cleaned up after successful merge

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$REPO_ROOT/skills/do/converge-phase.md"
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

# --- C8: AskUserQuestion merge approval with Merge/Keep/Discard ---

# Test 1: Convergence Reached section contains AskUserQuestion
if grep -q 'AskUserQuestion' "$FILE"; then
  pass "C8: converge-phase.md contains AskUserQuestion"
else
  fail "C8: converge-phase.md missing AskUserQuestion"
fi

# Test 2: Three options presented: Merge, Keep, Discard
if grep -q '"Merge"' "$FILE" && grep -q '"Keep"' "$FILE" && grep -q '"Discard"' "$FILE"; then
  pass "C8: All three options (Merge/Keep/Discard) are present"
else
  fail "C8: Missing one or more of Merge/Keep/Discard options"
fi

# Test 3: Merge summary includes sprints, spec items, branch, commit count
if grep -q 'Sprints:' "$FILE" && grep -q 'Spec items:' "$FILE" && grep -q 'Branch:' "$FILE" && grep -q 'Commits on branch:' "$FILE"; then
  pass "C8: Merge summary includes sprints, spec items, branch, and commit count"
else
  fail "C8: Merge summary missing required fields (sprints/spec items/branch/commits)"
fi

# --- C9: Squash merge flow sequence ---

# Test 4: git merge --squash present in merge flow
if grep -q 'git merge --squash plan/{slug}' "$FILE"; then
  pass "C9: git merge --squash plan/{slug} present"
else
  fail "C9: Missing git merge --squash plan/{slug}"
fi

# Test 5: git commit with descriptive message present
if grep -q 'git commit -m' "$FILE"; then
  pass "C9: git commit with message present"
else
  fail "C9: Missing git commit -m command"
fi

# Test 6: git worktree remove present
if grep -q 'git worktree remove .claude/worktrees/{slug}' "$FILE"; then
  pass "C9: git worktree remove present"
else
  fail "C9: Missing git worktree remove .claude/worktrees/{slug}"
fi

# Test 7: git branch -D present
if grep -q 'git branch -D plan/{slug}' "$FILE"; then
  pass "C9: git branch -D plan/{slug} present"
else
  fail "C9: Missing git branch -D plan/{slug}"
fi

# --- C18: ExitWorktree with 'keep' before squash merge ---

# Test 8: ExitWorktree(action: "keep") present in Merge flow
if grep -q 'ExitWorktree(action: "keep")' "$FILE"; then
  pass "C18: ExitWorktree(action: \"keep\") present in Merge flow"
else
  fail "C18: Missing ExitWorktree(action: \"keep\")"
fi

# Test 9: ExitWorktree(action: "keep") comes BEFORE git merge --squash
EXIT_KEEP_LINE=$(grep -n 'ExitWorktree(action: "keep")' "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
MERGE_LINE=$(grep -n 'git merge --squash' "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$EXIT_KEEP_LINE" ] && [ -n "$MERGE_LINE" ]; then
  if [ "$EXIT_KEEP_LINE" -lt "$MERGE_LINE" ]; then
    pass "C18: ExitWorktree(keep) appears before git merge --squash"
  else
    fail "C18: ExitWorktree(keep) should appear before git merge --squash (exit=$EXIT_KEEP_LINE, merge=$MERGE_LINE)"
  fi
else
  fail "C18: Could not find ExitWorktree(keep) or git merge --squash lines"
fi

# Test 10: No ExitWorktree(action: "remove") in Merge flow (only "keep" and "discard")
if grep -q 'ExitWorktree(action: "remove")' "$FILE"; then
  fail "C18: ExitWorktree(action: \"remove\") should NOT appear — only keep and discard"
else
  pass "C18: No ExitWorktree(action: \"remove\") found (correct)"
fi

# --- C19: Cleanup after merge ---

# Test 11: Cleanup happens AFTER merge (git worktree remove after git merge --squash)
REMOVE_LINE=$(grep -n 'git worktree remove' "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$MERGE_LINE" ] && [ -n "$REMOVE_LINE" ]; then
  if [ "$REMOVE_LINE" -gt "$MERGE_LINE" ]; then
    pass "C19: git worktree remove appears after git merge --squash"
  else
    fail "C19: git worktree remove should appear after git merge --squash"
  fi
else
  fail "C19: Could not find merge or worktree remove lines"
fi

# Test 12: branch -D happens after worktree remove
BRANCH_D_LINE=$(grep -n 'git branch -D plan/{slug}' "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$REMOVE_LINE" ] && [ -n "$BRANCH_D_LINE" ]; then
  if [ "$BRANCH_D_LINE" -gt "$REMOVE_LINE" ]; then
    pass "C19: git branch -D appears after git worktree remove"
  else
    fail "C19: git branch -D should appear after git worktree remove"
  fi
else
  fail "C19: Could not find worktree remove or branch -D lines"
fi

# --- Additional: Sprint Hard Cap includes merge option ---

# Test 13: Sprint Hard Cap section mentions AskUserQuestion
HARDCAP_START=$(grep -n '## Sprint Hard Cap' "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
CONVERGENCE_START=$(grep -n '## Convergence Reached' "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$HARDCAP_START" ] && [ -n "$CONVERGENCE_START" ]; then
  # Extract just the hard cap section (between "## Sprint Hard Cap" and "## Convergence Reached")
  HARDCAP_SECTION=$(sed -n "${HARDCAP_START},${CONVERGENCE_START}p" "$FILE")
  if echo "$HARDCAP_SECTION" | grep -q 'AskUserQuestion'; then
    pass "Sprint Hard Cap section includes AskUserQuestion"
  else
    fail "Sprint Hard Cap section missing AskUserQuestion"
  fi
else
  fail "Could not find Sprint Hard Cap or Convergence Reached section headers"
fi

# --- Structural: Unchanged sections ---

# Test 14: 5-gate check is still present
if grep -q '## 5-Gate Convergence Check' "$FILE" && grep -q 'Gate 1: Review Gate' "$FILE" && grep -q 'Gate 5: Confidence Gate' "$FILE"; then
  pass "5-Gate Convergence Check section preserved"
else
  fail "5-Gate Convergence Check section damaged or missing"
fi

# Test 15: Pathology detection is still present
if grep -q '## Pathology Detection' "$FILE" && grep -q 'Spinning' "$FILE" && grep -q 'Oscillation' "$FILE" && grep -q 'Stagnation' "$FILE"; then
  pass "Pathology Detection section preserved"
else
  fail "Pathology Detection section damaged or missing"
fi

# Test 16: Not Yet Converged section is still present
if grep -q '## Not Yet Converged' "$FILE"; then
  pass "Not Yet Converged section preserved"
else
  fail "Not Yet Converged section damaged or missing"
fi

# Test 17: ExitWorktree(action: "discard") in Discard flow
if grep -q 'ExitWorktree(action: "discard")' "$FILE"; then
  pass "ExitWorktree(action: \"discard\") present in Discard flow"
else
  fail "Missing ExitWorktree(action: \"discard\") in Discard flow"
fi

# Test 18: Merge conflict handling mentions presenting to user
if grep -q 'merge conflicts' "$FILE" || grep -q 'Merge conflict' "$FILE"; then
  pass "Merge conflict handling documented"
else
  fail "Missing merge conflict handling documentation"
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
