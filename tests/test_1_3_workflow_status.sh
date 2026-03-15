#!/usr/bin/env bash
# TDD test for task 1.3: Verify all hook scripts use find_workflow_status()
# instead of find_latest_session("status.yaml")
#
# Run before changes to see it FAIL, after changes to see it PASS.

SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)/scripts"
TARGET_SCRIPTS=(
  "${SCRIPTS_DIR}/pipeline-guard.sh"
  "${SCRIPTS_DIR}/stop-hook.sh"
  "${SCRIPTS_DIR}/spec-gate.sh"
  "${SCRIPTS_DIR}/drift-monitor.sh"
  "${SCRIPTS_DIR}/pre-compact.sh"
  "${SCRIPTS_DIR}/error-tracker.sh"
)

PASS=0
FAIL=0

echo "=== Test 1.3: Hook scripts use find_workflow_status() ==="
echo

# C1: No script contains find_latest_session("status.yaml")
echo "--- C1: No legacy find_latest_session(\"status.yaml\") references ---"
for f in "${TARGET_SCRIPTS[@]}"; do
  if grep -q 'find_latest_session "status.yaml"' "$f" 2>/dev/null; then
    echo "FAIL: $f still contains find_latest_session(\"status.yaml\")"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $f"
    PASS=$((PASS + 1))
  fi
done
echo

# C1: drift-monitor.sh uses status-do.yaml instead of status.yaml
echo "--- C1: drift-monitor.sh uses status-do.yaml (not status.yaml) ---"
if grep -q '"${plan_dir}/status.yaml"' "${SCRIPTS_DIR}/drift-monitor.sh" 2>/dev/null; then
  echo "FAIL: drift-monitor.sh still uses \${plan_dir}/status.yaml"
  FAIL=$((FAIL + 1))
else
  echo "PASS: drift-monitor.sh"
  PASS=$((PASS + 1))
fi
echo

# C1: pre-compact.sh looks for status-{wf}.yaml not status.yaml
echo "--- C1: pre-compact.sh uses per-workflow status files ---"
if grep -q '"${dir}status.yaml"' "${SCRIPTS_DIR}/pre-compact.sh" 2>/dev/null; then
  echo "FAIL: pre-compact.sh still uses \${dir}status.yaml"
  FAIL=$((FAIL + 1))
else
  echo "PASS: pre-compact.sh"
  PASS=$((PASS + 1))
fi
echo

# C14: stop-hook.sh only handles "do" (not review/qa) — verify find_workflow_status "do" present
echo "--- C14: stop-hook.sh uses find_workflow_status \"do\" ---"
if grep -q 'find_workflow_status "do"' "${SCRIPTS_DIR}/stop-hook.sh" 2>/dev/null; then
  echo "PASS: stop-hook.sh"
  PASS=$((PASS + 1))
else
  echo "FAIL: stop-hook.sh does not use find_workflow_status \"do\""
  FAIL=$((FAIL + 1))
fi
echo

# C14: spec-gate.sh only handles "do" — verify find_workflow_status "do" present
echo "--- C14: spec-gate.sh uses find_workflow_status \"do\" ---"
if grep -q 'find_workflow_status "do"' "${SCRIPTS_DIR}/spec-gate.sh" 2>/dev/null; then
  echo "PASS: spec-gate.sh"
  PASS=$((PASS + 1))
else
  echo "FAIL: spec-gate.sh does not use find_workflow_status \"do\""
  FAIL=$((FAIL + 1))
fi
echo

# Syntax check all 6 scripts
echo "--- Syntax check: all 6 scripts ---"
for f in "${TARGET_SCRIPTS[@]}"; do
  if bash -n "$f" 2>/dev/null; then
    echo "PASS (syntax): $(basename "$f")"
    PASS=$((PASS + 1))
  else
    echo "FAIL (syntax): $(basename "$f")"
    bash -n "$f" 2>&1 | sed 's/^/  /'
    FAIL=$((FAIL + 1))
  fi
done
echo

echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
