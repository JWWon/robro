#!/usr/bin/env bash
# Test: CWD normalization — load-config.sh uses absolute paths via git rev-parse
# Task 1.1: SESSIONS_DIR and WORKTREE_DIR must be absolute (PROJECT_ROOT-prefixed)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

LOAD_CONFIG="$REPO_ROOT/scripts/lib/load-config.sh"
SESSION_START="$REPO_ROOT/scripts/session-start.sh"

# ===========================================================================
# Test 1: load-config.sh defines PROJECT_ROOT
# ===========================================================================
if grep -q 'PROJECT_ROOT' "$LOAD_CONFIG"; then
  pass "load-config.sh defines PROJECT_ROOT"
else
  fail "load-config.sh does not define PROJECT_ROOT"
fi

# ===========================================================================
# Test 2: PROJECT_ROOT uses git rev-parse --show-toplevel
# ===========================================================================
if grep -q 'git rev-parse --show-toplevel' "$LOAD_CONFIG"; then
  pass "PROJECT_ROOT uses git rev-parse --show-toplevel"
else
  fail "PROJECT_ROOT does not use git rev-parse --show-toplevel"
fi

# ===========================================================================
# Test 3: SESSIONS_DIR is prefixed with PROJECT_ROOT (not bare relative)
# ===========================================================================
if grep -q 'SESSIONS_DIR="${PROJECT_ROOT}/.robro/sessions"' "$LOAD_CONFIG"; then
  pass "SESSIONS_DIR uses \${PROJECT_ROOT} prefix"
else
  fail "SESSIONS_DIR is not prefixed with \${PROJECT_ROOT}"
fi

# ===========================================================================
# Test 4: CONFIG_FILE is prefixed with PROJECT_ROOT
# ===========================================================================
if grep -q 'CONFIG_FILE="${PROJECT_ROOT}/.robro/config.json"' "$LOAD_CONFIG"; then
  pass "CONFIG_FILE uses \${PROJECT_ROOT} prefix"
else
  fail "CONFIG_FILE is not prefixed with \${PROJECT_ROOT}"
fi

# ===========================================================================
# Test 5: No bare relative .robro/sessions paths remain in scripts/
# ===========================================================================
bare_sessions=$(grep -rn '\.robro/sessions"' "$REPO_ROOT/scripts/" | grep -v 'PROJECT_ROOT' | grep -v '\.sh:#' | grep -v 'wt_dir' || true)
if [ -z "$bare_sessions" ]; then
  pass "No bare relative .robro/sessions paths in scripts/"
else
  fail "Found bare relative .robro/sessions paths: $bare_sessions"
fi

# ===========================================================================
# Test 6: No bare relative .claude/worktrees paths remain in scripts/
# ===========================================================================
bare_worktrees=$(grep -rn '\.claude/worktrees"' "$REPO_ROOT/scripts/" | grep -v 'PROJECT_ROOT' | grep -v '\.sh:#' || true)
if [ -z "$bare_worktrees" ]; then
  pass "No bare relative .claude/worktrees paths in scripts/"
else
  fail "Found bare relative .claude/worktrees paths: $bare_worktrees"
fi

# ===========================================================================
# Test 7: session-start.sh WORKTREE_DIR uses PROJECT_ROOT
# ===========================================================================
if grep -q 'WORKTREE_DIR="${PROJECT_ROOT}/.claude/worktrees"' "$SESSION_START"; then
  pass "session-start.sh WORKTREE_DIR uses \${PROJECT_ROOT} prefix"
else
  fail "session-start.sh WORKTREE_DIR does not use \${PROJECT_ROOT} prefix"
fi

# ===========================================================================
# Test 8: Sourcing load-config.sh produces absolute SESSIONS_DIR
# ===========================================================================
(
  cd /tmp  # Run from a different directory to verify absolute path works
  source "$LOAD_CONFIG"
  if [[ "$SESSIONS_DIR" == /* ]]; then
    echo "PASS: SESSIONS_DIR is absolute when sourced from /tmp: $SESSIONS_DIR"
  else
    echo "FAIL: SESSIONS_DIR is relative when sourced from /tmp: $SESSIONS_DIR"
    exit 1
  fi
) && PASSES=$((PASSES + 1)) || FAILURES=$((FAILURES + 1))

# ===========================================================================
# Test 9: load-config.sh still passes bash -n syntax check
# ===========================================================================
if bash -n "$LOAD_CONFIG" 2>/dev/null; then
  pass "load-config.sh passes bash -n syntax check"
else
  fail "load-config.sh fails bash -n syntax check"
fi

# ===========================================================================
# Test 10: session-start.sh still passes bash -n syntax check
# ===========================================================================
if bash -n "$SESSION_START" 2>/dev/null; then
  pass "session-start.sh passes bash -n syntax check"
else
  fail "session-start.sh fails bash -n syntax check"
fi

# ===========================================================================
echo ""
echo "Results: ${PASSES} passed, ${FAILURES} failed"
exit $FAILURES
