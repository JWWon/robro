#!/usr/bin/env bash
# Test: validate-templates.sh script exists, is executable, passes syntax check, and runs successfully
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

SCRIPT="$REPO_ROOT/scripts/validate-templates.sh"

# Existence and permissions
check "validate-templates.sh exists" test -f "$SCRIPT"
check "validate-templates.sh is executable" test -x "$SCRIPT"
check "validate-templates.sh passes bash -n syntax check" bash -n "$SCRIPT"

# Content checks: script validates agent references
check "script checks agent references in skills" grep -q "agents/" "$SCRIPT"
check "script validates hooks.json" grep -q "hooks.json" "$SCRIPT"
check "script checks bash syntax of scripts" grep -q "bash -n" "$SCRIPT"
check "script checks node syntax of mjs files" grep -q "node -c" "$SCRIPT"

# Run the script and verify it exits 0 on the current codebase
if bash "$SCRIPT" >/dev/null 2>&1; then
  echo "PASS: validate-templates.sh exits 0 on current codebase"
  PASS=$((PASS + 1))
else
  echo "FAIL: validate-templates.sh exits non-zero on current codebase"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) checks"
exit $FAIL
