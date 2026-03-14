#!/usr/bin/env bash
# Test: Verify all docs/plans/ references have been migrated to .robro/sessions/
# Spec items: C6, C7, C8, C9

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

check_no_docs_plans() {
  local file="$1"
  local spec_id="$2"
  local filepath="$REPO_ROOT/$file"

  if [ ! -f "$filepath" ]; then
    echo "FAIL [$spec_id]: File not found: $file"
    FAIL=$((FAIL + 1))
    return
  fi

  local count
  count=$(grep -c 'docs/plans' "$filepath" 2>/dev/null || true)

  if [ "$count" -gt 0 ]; then
    echo "FAIL [$spec_id]: $file has $count references to 'docs/plans'"
    grep -n 'docs/plans' "$filepath" | while read -r line; do
      echo "  $line"
    done
    FAIL=$((FAIL + 1))
  else
    echo "PASS [$spec_id]: $file has zero docs/plans references"
    PASS=$((PASS + 1))
  fi
}

check_has_robro_sessions() {
  local file="$1"
  local spec_id="$2"
  local filepath="$REPO_ROOT/$file"

  if [ ! -f "$filepath" ]; then
    echo "FAIL [$spec_id]: File not found: $file"
    FAIL=$((FAIL + 1))
    return
  fi

  local count
  count=$(grep -c '.robro/sessions' "$filepath" 2>/dev/null || true)

  if [ "$count" -eq 0 ]; then
    echo "FAIL [$spec_id]: $file has zero references to '.robro/sessions' (expected some)"
    FAIL=$((FAIL + 1))
  else
    echo "PASS [$spec_id]: $file has $count references to '.robro/sessions'"
    PASS=$((PASS + 1))
  fi
}

echo "=== Session Path Migration Test ==="
echo ""

# C6: skills/idea/SKILL.md has zero docs/plans/ references
echo "--- C6: skills/idea/SKILL.md ---"
check_no_docs_plans "skills/idea/SKILL.md" "C6"
check_has_robro_sessions "skills/idea/SKILL.md" "C6"

# C7: skills/plan/SKILL.md has zero docs/plans/ references
echo "--- C7: skills/plan/SKILL.md ---"
check_no_docs_plans "skills/plan/SKILL.md" "C7"
check_has_robro_sessions "skills/plan/SKILL.md" "C7"

# C8: skills/do/SKILL.md and skills/tune/SKILL.md have zero docs/plans/ references
echo "--- C8: skills/do/SKILL.md ---"
check_no_docs_plans "skills/do/SKILL.md" "C8"
check_has_robro_sessions "skills/do/SKILL.md" "C8"

echo "--- C8: skills/tune/SKILL.md ---"
check_no_docs_plans "skills/tune/SKILL.md" "C8"
check_has_robro_sessions "skills/tune/SKILL.md" "C8"

# C9: CLAUDE.md, README.md, skills/setup/claude-md-template.md have zero docs/plans/ references
echo "--- C9: CLAUDE.md ---"
check_no_docs_plans "CLAUDE.md" "C9"
check_has_robro_sessions "CLAUDE.md" "C9"

echo "--- C9: README.md ---"
check_no_docs_plans "README.md" "C9"
check_has_robro_sessions "README.md" "C9"

echo "--- C9: skills/setup/claude-md-template.md ---"
check_no_docs_plans "skills/setup/claude-md-template.md" "C9"
check_has_robro_sessions "skills/setup/claude-md-template.md" "C9"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
