#!/usr/bin/env bash
# Test script for tasks 5.1, 5.2, 5.3, 6.1, 6.2
# Validates spec items C19-C23

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

# C19: sync-versions.sh exists, executable, passes bash -n, syncs marketplace.json to plugin.json
check "C19a: sync-versions.sh exists" test -f "$REPO_ROOT/scripts/sync-versions.sh"
check "C19b: sync-versions.sh is executable" test -x "$REPO_ROOT/scripts/sync-versions.sh"
check "C19c: sync-versions.sh passes bash -n" bash -n "$REPO_ROOT/scripts/sync-versions.sh"
check "C19d: sync-versions.sh contains jq read of plugin.json version" grep -q "jq.*version.*plugin.json\|PLUGIN_JSON\|plugin_json" "$REPO_ROOT/scripts/sync-versions.sh"
check "C19e: sync-versions.sh contains jq write to marketplace.json" grep -q "marketplace" "$REPO_ROOT/scripts/sync-versions.sh"

# C20: .githooks/pre-push exists, executable, passes bash -n, calls sync-versions.sh
check "C20a: .githooks/pre-push exists" test -f "$REPO_ROOT/.githooks/pre-push"
check "C20b: .githooks/pre-push is executable" test -x "$REPO_ROOT/.githooks/pre-push"
check "C20c: .githooks/pre-push passes bash -n" bash -n "$REPO_ROOT/.githooks/pre-push"
check "C20d: .githooks/pre-push calls sync-versions.sh" grep -q "sync-versions" "$REPO_ROOT/.githooks/pre-push"

# C21: CLAUDE.md has Version Sync section
check "C21a: CLAUDE.md has Version Sync section" grep -q "Version Sync" "$REPO_ROOT/CLAUDE.md"
check "C21b: CLAUDE.md mentions plugin.json as truth" grep -q "single source of truth\|source of truth" "$REPO_ROOT/CLAUDE.md"
check "C21c: CLAUDE.md mentions sync-versions.sh" grep -q "sync-versions.sh" "$REPO_ROOT/CLAUDE.md"
check "C21d: CLAUDE.md mentions pre-push hook" grep -q "pre-push" "$REPO_ROOT/CLAUDE.md"
check "C21e: CLAUDE.md mentions git config core.hooksPath" grep -q "core.hooksPath" "$REPO_ROOT/CLAUDE.md"

# C22: idea skill has Agent() dispatch examples for Steps 2, 5, 7
check "C22a: idea SKILL.md has Agent() dispatch in Step 2" grep -q 'subagent_type.*robro:researcher' "$REPO_ROOT/skills/idea/SKILL.md"
check "C22b: idea SKILL.md has model parameter in dispatch" grep -q 'model:' "$REPO_ROOT/skills/idea/SKILL.md"
check "C22c: idea SKILL.md has Agent() dispatch for challenge agents (Step 5)" grep -q 'subagent_type.*robro:contrarian\|subagent_type.*robro:simplifier\|subagent_type.*robro:ontologist' "$REPO_ROOT/skills/idea/SKILL.md"
# C22d: idea SKILL.md has Agent() dispatch for Step 7 researcher
# Use a subshell to avoid pipefail issues with check function
if grep -A15 "Step 7" "$REPO_ROOT/skills/idea/SKILL.md" | grep -q 'subagent_type\|Agent('; then
  echo "PASS: C22d: idea SKILL.md has Agent() dispatch for Step 7 researcher"
  PASS=$((PASS + 1))
else
  echo "FAIL: C22d: idea SKILL.md has Agent() dispatch for Step 7 researcher"
  FAIL=$((FAIL + 1))
fi

# C23: plan skill has Agent() dispatch examples for Steps 2, 4, 5, 7, 9
check "C23a: plan SKILL.md has Agent() dispatch for researcher in Step 2" grep -q 'subagent_type.*robro:researcher' "$REPO_ROOT/skills/plan/SKILL.md"
check "C23b: plan SKILL.md has Agent() dispatch for architect in Step 2" grep -q 'subagent_type.*robro:architect' "$REPO_ROOT/skills/plan/SKILL.md"
check "C23c: plan SKILL.md has Agent() dispatch for critic in Step 2" grep -q 'subagent_type.*robro:critic' "$REPO_ROOT/skills/plan/SKILL.md"
check "C23d: plan SKILL.md has Agent() dispatch for planner in Step 4" grep -q 'subagent_type.*robro:planner' "$REPO_ROOT/skills/plan/SKILL.md"
check "C23e: plan SKILL.md has model parameter in dispatches" grep -q 'model:.*opus\|model:.*sonnet' "$REPO_ROOT/skills/plan/SKILL.md"
check "C23f: plan SKILL.md has Model Configuration section" grep -q "Model Configuration" "$REPO_ROOT/skills/plan/SKILL.md"
check "C23g: plan SKILL.md mentions agent_overrides precedence" grep -q "agent_overrides" "$REPO_ROOT/skills/plan/SKILL.md"

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) checks"
exit $FAIL
