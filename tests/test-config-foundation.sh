#!/usr/bin/env bash
# Test: config foundation — load-config.sh, .gitignore, config.schema.json, config.json
# Validates spec items C1, C4, C11, C12

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

# ===========================================================================
# C1: load-config.sh exists, is executable, passes bash -n,
#     exports SESSIONS_DIR='.robro/sessions' and robro_config function
# ===========================================================================

LOAD_CONFIG="$REPO_ROOT/scripts/lib/load-config.sh"

if [[ -f "$LOAD_CONFIG" ]]; then
  pass "scripts/lib/load-config.sh exists"
else
  fail "scripts/lib/load-config.sh does not exist"
fi

if [[ -x "$LOAD_CONFIG" ]]; then
  pass "load-config.sh is executable"
else
  fail "load-config.sh is not executable"
fi

if bash -n "$LOAD_CONFIG" 2>/dev/null; then
  pass "load-config.sh passes bash -n syntax check"
else
  fail "load-config.sh fails bash -n syntax check"
fi

# Source the file and check exports
if [[ -f "$LOAD_CONFIG" ]]; then
  (
    source "$LOAD_CONFIG"
    if [[ "$SESSIONS_DIR" == ".robro/sessions" ]]; then
      echo "PASS: SESSIONS_DIR='.robro/sessions'"
    else
      echo "FAIL: SESSIONS_DIR expected '.robro/sessions', got '$SESSIONS_DIR'"
      exit 1
    fi
  ) && PASSES=$((PASSES + 1)) || FAILURES=$((FAILURES + 1))

  # Check robro_config function exists
  (
    source "$LOAD_CONFIG"
    if declare -f robro_config > /dev/null 2>&1; then
      echo "PASS: robro_config function is defined"
    else
      echo "FAIL: robro_config function is not defined"
      exit 1
    fi
  ) && PASSES=$((PASSES + 1)) || FAILURES=$((FAILURES + 1))

  # Check robro_config returns default when no config file
  (
    source "$LOAD_CONFIG"
    # Override CONFIG_FILE to a nonexistent path
    CONFIG_FILE="/tmp/nonexistent-robro-config-test.json"
    result=$(robro_config '.thresholds.sprint_hard_cap' '30')
    if [[ "$result" == "30" ]]; then
      echo "PASS: robro_config returns default when config file missing"
    else
      echo "FAIL: robro_config returned '$result' instead of '30'"
      exit 1
    fi
  ) && PASSES=$((PASSES + 1)) || FAILURES=$((FAILURES + 1))

  # Check robro_config reads from a config file
  (
    source "$LOAD_CONFIG"
    TMPFILE=$(mktemp)
    echo '{"thresholds":{"sprint_hard_cap":50}}' > "$TMPFILE"
    CONFIG_FILE="$TMPFILE"
    result=$(robro_config '.thresholds.sprint_hard_cap' '30')
    rm -f "$TMPFILE"
    if [[ "$result" == "50" ]]; then
      echo "PASS: robro_config reads value from config file"
    else
      echo "FAIL: robro_config returned '$result' instead of '50'"
      exit 1
    fi
  ) && PASSES=$((PASSES + 1)) || FAILURES=$((FAILURES + 1))
else
  fail "SESSIONS_DIR check skipped (file missing)"
  fail "robro_config function check skipped (file missing)"
  fail "robro_config default check skipped (file missing)"
  fail "robro_config read check skipped (file missing)"
fi

# ===========================================================================
# C4: .gitignore has .robro/sessions/ rules, no docs/plans/ rules
# ===========================================================================

GITIGNORE="$REPO_ROOT/.gitignore"

for pattern in \
  ".robro/sessions/*/research/" \
  ".robro/sessions/*/discussion/" \
  ".robro/sessions/*/status.yaml" \
  ".robro/sessions/*/*.bak.*"; do
  if grep -qF "$pattern" "$GITIGNORE"; then
    pass ".gitignore contains $pattern"
  else
    fail ".gitignore missing $pattern"
  fi
done

if grep -qF ".claude/worktrees/" "$GITIGNORE"; then
  pass ".gitignore keeps .claude/worktrees/ rule"
else
  fail ".gitignore missing .claude/worktrees/ rule"
fi

if grep -q "docs/plans" "$GITIGNORE"; then
  fail ".gitignore still contains docs/plans rules (should be removed)"
else
  pass ".gitignore has zero docs/plans/ rules"
fi

# ===========================================================================
# C11: config.schema.json exists, is valid JSON, defines model_tiers,
#      thresholds, agent_overrides with $defs for model/model_capped types
# ===========================================================================

SCHEMA="$REPO_ROOT/config.schema.json"

if [[ -f "$SCHEMA" ]]; then
  pass "config.schema.json exists"
else
  fail "config.schema.json does not exist"
fi

if jq . "$SCHEMA" > /dev/null 2>&1; then
  pass "config.schema.json is valid JSON"
else
  fail "config.schema.json is not valid JSON"
fi

# Check top-level properties
for prop in "model_tiers" "thresholds" "agent_overrides"; do
  if jq -e ".properties.$prop" "$SCHEMA" > /dev/null 2>&1; then
    pass "config.schema.json defines property: $prop"
  else
    fail "config.schema.json missing property: $prop"
  fi
done

# Check $defs
for def in "model" "model_capped"; do
  if jq -e '."$defs"."'"$def"'"' "$SCHEMA" > /dev/null 2>&1; then
    pass "config.schema.json defines \$defs/$def"
  else
    fail "config.schema.json missing \$defs/$def"
  fi
done

# Check model enum includes haiku, sonnet, opus
if jq -e '."$defs".model.enum | sort == ["haiku","opus","sonnet"]' "$SCHEMA" > /dev/null 2>&1; then
  pass "model enum has haiku, sonnet, opus"
else
  fail "model enum does not have exactly haiku, sonnet, opus"
fi

# Check model_capped enum includes haiku, sonnet (not opus)
if jq -e '."$defs".model_capped.enum | sort == ["haiku","sonnet"]' "$SCHEMA" > /dev/null 2>&1; then
  pass "model_capped enum has haiku, sonnet (no opus)"
else
  fail "model_capped enum does not have exactly haiku, sonnet"
fi

# ===========================================================================
# C12: config.json has all 11 agents in each tier
# ===========================================================================

CONFIG_JSON="$REPO_ROOT/config.json"

for tier in light standard complex; do
  for agent in builder reviewer architect critic researcher retro-analyst conflict-resolver planner contrarian simplifier ontologist; do
    if jq -e ".model_tiers.$tier | has(\"$agent\")" "$CONFIG_JSON" > /dev/null 2>&1; then
      pass "config.json: $tier tier has $agent"
    else
      fail "config.json: $tier tier missing $agent"
    fi
  done
done

# Check total count per tier (should be 11 agents + default = 12, so 11 non-default)
for tier in light standard complex; do
  count=$(jq -r ".model_tiers.$tier | keys | map(select(. != \"default\")) | length" "$CONFIG_JSON")
  if [ "$count" -eq 11 ]; then
    pass "config.json: $tier tier has exactly 11 agents (excluding default)"
  else
    fail "config.json: $tier tier has $count agents instead of 11"
  fi
done

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "Results: $PASSES passed, $FAILURES failed"

if [[ $FAILURES -gt 0 ]]; then
  exit 1
fi

exit 0
