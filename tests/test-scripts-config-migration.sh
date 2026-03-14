#!/usr/bin/env bash
# Test: verify session-start.sh, pipeline-guard.sh, error-tracker.sh,
#       pre-compact.sh, stop-hook.sh source load-config.sh and use $SESSIONS_DIR
#       with zero inline docs/plans references.
# Also verifies stop-hook.sh reads sprint_hard_cap from config.
# Spec items C3, C14.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

assert() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

assert_not() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

SCRIPTS=("scripts/session-start.sh" "scripts/pipeline-guard.sh" "scripts/error-tracker.sh" "scripts/pre-compact.sh" "scripts/stop-hook.sh")

echo "=== Test: Config Loader Migration (C3) ==="

for script in "${SCRIPTS[@]}"; do
  filepath="${SCRIPT_DIR}/${script}"
  name=$(basename "$script")
  echo ""
  echo "--- ${name} ---"

  # 1. Must source load-config.sh
  assert "${name} sources load-config.sh" \
    grep -q 'source.*load-config\.sh' "$filepath"

  # 2. Must NOT contain any literal 'docs/plans' references
  assert_not "${name} has zero docs/plans references" \
    grep -q 'docs/plans' "$filepath"

  # 3. Must use SESSIONS_DIR variable
  assert "${name} uses \$SESSIONS_DIR" \
    grep -q 'SESSIONS_DIR' "$filepath"

  # 4. Must pass bash syntax check
  assert "${name} passes bash -n syntax check" \
    bash -n "$filepath"
done

echo ""
echo "=== Test: stop-hook.sh sprint_hard_cap config (C14) ==="
echo ""

STOP_HOOK="${SCRIPT_DIR}/scripts/stop-hook.sh"

# 5. stop-hook.sh must call robro_config for sprint_hard_cap
assert "stop-hook.sh calls robro_config for sprint_hard_cap" \
  grep -q 'robro_config.*sprint_hard_cap' "$STOP_HOOK"

# 6. stop-hook.sh must use SPRINT_HARD_CAP variable (at least in 2 places: assignment + usage)
sprint_cap_count=$(grep -c 'SPRINT_HARD_CAP' "$STOP_HOOK" 2>/dev/null || echo "0")
assert "stop-hook.sh uses SPRINT_HARD_CAP in at least 2 places (found ${sprint_cap_count})" \
  [ "$sprint_cap_count" -ge 2 ]

# 7. stop-hook.sh must NOT have hardcoded 30 in the sprint cap check line
assert_not "stop-hook.sh has hardcoded 30 in sprint -ge check" \
  grep -q 'sprint.*-ge 30' "$STOP_HOOK"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
