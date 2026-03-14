#!/usr/bin/env bash
# Test: verify spec-gate.sh, drift-monitor.sh, keyword-detector.sh
#       source load-config.sh and use $SESSIONS_DIR with zero inline docs/plans references.
# Spec item C2.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

assert() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc"
    ((FAIL++))
  fi
}

assert_not() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  FAIL: $desc"
    ((FAIL++))
  else
    echo "  PASS: $desc"
    ((PASS++))
  fi
}

SCRIPTS=("scripts/spec-gate.sh" "scripts/drift-monitor.sh" "scripts/keyword-detector.sh")

echo "=== Test: Config Loader Adoption (C2) ==="

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
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
