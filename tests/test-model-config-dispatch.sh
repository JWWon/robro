#!/usr/bin/env bash
# Test: Task 3.3 — model config reading in Brief phase + agent dispatch model params
# Validates C13: Do skill Brief phase reads model-config.yaml and dispatches agents with tier-appropriate model

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRIEF_FILE="$REPO_ROOT/skills/do/brief-phase.md"
SKILL_FILE="$REPO_ROOT/skills/do/SKILL.md"
HEADSDOWN_FILE="$REPO_ROOT/skills/do/heads-down-phase.md"
REVIEW_FILE="$REPO_ROOT/skills/do/review-phase.md"
RETRO_FILE="$REPO_ROOT/skills/do/retro-phase.md"
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

# === brief-phase.md tests ===

# Test 1: "Load Model Configuration" section exists in brief-phase.md
if grep -q '### 1\.1\. Load Model Configuration' "$BRIEF_FILE"; then
  pass "brief-phase.md contains 'Load Model Configuration' section"
else
  fail "brief-phase.md missing 'Load Model Configuration' section"
fi

# Test 2: Section reads meta.complexity from spec.yaml
if grep -q 'meta\.complexity' "$BRIEF_FILE"; then
  pass "brief-phase.md references meta.complexity from spec.yaml"
else
  fail "brief-phase.md does not reference meta.complexity"
fi

# Test 3: Section reads model-config.yaml
if grep -q 'model-config\.yaml' "$BRIEF_FILE"; then
  pass "brief-phase.md references model-config.yaml"
else
  fail "brief-phase.md does not reference model-config.yaml"
fi

# Test 4: Section contains MODEL_CONFIG structure
if grep -q 'MODEL_CONFIG' "$BRIEF_FILE"; then
  pass "brief-phase.md contains MODEL_CONFIG structure"
else
  fail "brief-phase.md missing MODEL_CONFIG structure"
fi

# Test 5: Section appears BEFORE "Clean Stale Worktrees"
LOAD_LINE=$(grep -n '### 1\.1\. Load Model Configuration' "$BRIEF_FILE" 2>/dev/null | head -1 | cut -d: -f1)
CLEAN_LINE=$(grep -n '### 1\.5\. Clean Stale Worktrees' "$BRIEF_FILE" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$LOAD_LINE" ] && [ -n "$CLEAN_LINE" ] && [ "$LOAD_LINE" -lt "$CLEAN_LINE" ]; then
  pass "Load Model Configuration section appears before Clean Stale Worktrees"
else
  fail "Load Model Configuration section not properly ordered (load=$LOAD_LINE, clean=$CLEAN_LINE)"
fi

# Test 6: Section appears AFTER "Read Current State"
READ_LINE=$(grep -n '### 1\. Read Current State' "$BRIEF_FILE" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$LOAD_LINE" ] && [ -n "$READ_LINE" ] && [ "$LOAD_LINE" -gt "$READ_LINE" ]; then
  pass "Load Model Configuration section appears after Read Current State"
else
  fail "Load Model Configuration section not properly ordered (read=$READ_LINE, load=$LOAD_LINE)"
fi

# === SKILL.md tests ===

# Test 7: SKILL.md Phase 1 Brief summary mentions model config
if grep -q 'Load model-config.yaml' "$SKILL_FILE" || grep -q 'model-config.yaml and select complexity tier' "$SKILL_FILE"; then
  pass "SKILL.md Brief summary mentions model config loading"
else
  fail "SKILL.md Brief summary missing model config reference"
fi

# === heads-down-phase.md tests ===

# Test 8: Inline builder dispatch includes model parameter
if grep -q 'MODEL_CONFIG\.builder' "$HEADSDOWN_FILE"; then
  pass "heads-down-phase.md inline builder dispatch includes MODEL_CONFIG.builder"
else
  fail "heads-down-phase.md inline builder dispatch missing MODEL_CONFIG.builder"
fi

# Test 9: Isolated builder dispatch includes model parameter
# Check there are at least 2 occurrences of MODEL_CONFIG.builder (inline + isolated)
BUILDER_COUNT=$(grep -c 'MODEL_CONFIG\.builder' "$HEADSDOWN_FILE" 2>/dev/null || true)
BUILDER_COUNT=${BUILDER_COUNT:-0}
BUILDER_COUNT=$(echo "$BUILDER_COUNT" | tr -d '[:space:]')
if [ "$BUILDER_COUNT" -ge 2 ]; then
  pass "heads-down-phase.md has model param in both inline and isolated builder dispatches ($BUILDER_COUNT occurrences)"
else
  fail "heads-down-phase.md should have MODEL_CONFIG.builder in at least 2 dispatches, found $BUILDER_COUNT"
fi

# === review-phase.md tests ===

# Test 10: Review phase mentions MODEL_CONFIG for reviewer/architect/critic
if grep -q 'MODEL_CONFIG' "$REVIEW_FILE"; then
  pass "review-phase.md contains MODEL_CONFIG reference"
else
  fail "review-phase.md missing MODEL_CONFIG reference"
fi

# === retro-phase.md tests ===

# Test 11: Retro phase mentions MODEL_CONFIG for retro-analyst
if grep -q 'MODEL_CONFIG' "$RETRO_FILE"; then
  pass "retro-phase.md contains MODEL_CONFIG reference"
else
  fail "retro-phase.md missing MODEL_CONFIG reference"
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
