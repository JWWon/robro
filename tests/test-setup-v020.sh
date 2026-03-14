#!/usr/bin/env bash
# Test: v0.2.0 setup skill updates
# Validates new gitignore rules, .robro/skills/ mention, and template updates

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/setup/SKILL.md"
TEMPLATE_FILE="$REPO_ROOT/skills/setup/claude-md-template.md"
FAILURES=0

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

# --- SKILL.md tests ---

# Test 1: .skill-index.json in gitignore rules
if grep -q '\.skill-index\.json' "$SKILL_FILE"; then
  pass "SKILL.md mentions .skill-index.json gitignore rule"
else
  fail "SKILL.md missing .skill-index.json gitignore rule"
fi

# Test 2: .oscillation-state.json in gitignore rules
if grep -q '\.oscillation-state\.json' "$SKILL_FILE"; then
  pass "SKILL.md mentions .oscillation-state.json gitignore rule"
else
  fail "SKILL.md missing .oscillation-state.json gitignore rule"
fi

# Test 3: .injected-skills.json in gitignore rules
if grep -q '\.injected-skills\.json' "$SKILL_FILE"; then
  pass "SKILL.md mentions .injected-skills.json gitignore rule"
else
  fail "SKILL.md missing .injected-skills.json gitignore rule"
fi

# Test 4: .update-cache.json in gitignore rules
if grep -q '\.update-cache\.json' "$SKILL_FILE"; then
  pass "SKILL.md mentions .update-cache.json gitignore rule"
else
  fail "SKILL.md missing .update-cache.json gitignore rule"
fi

# Test 5: .robro/skills/ directory creation step
if grep -q '\.robro/skills/' "$SKILL_FILE"; then
  pass "SKILL.md mentions .robro/skills/ directory"
else
  fail "SKILL.md missing .robro/skills/ directory creation step"
fi

# Test 6: v0.2.0 migration mentioned
if grep -qi 'v0\.2\.0\|migration' "$SKILL_FILE"; then
  pass "SKILL.md mentions v0.2.0 or migration"
else
  fail "SKILL.md missing v0.2.0 migration reference"
fi

# --- claude-md-template.md tests ---

# Test 7: Wonder agent mentioned
if grep -qi 'wonder' "$TEMPLATE_FILE"; then
  pass "Template mentions Wonder agent"
else
  fail "Template missing Wonder agent"
fi

# Test 8: Skill injection mentioned
if grep -qi 'skill.injec\|skill injection\|learned skill' "$TEMPLATE_FILE"; then
  pass "Template mentions skill injection or learned skills"
else
  fail "Template missing skill injection reference"
fi

# Test 9: Oscillation detection mentioned
if grep -qi 'oscillation' "$TEMPLATE_FILE"; then
  pass "Template mentions oscillation detection"
else
  fail "Template missing oscillation detection reference"
fi

# Test 10: 4-tier customization or learned skills directory
if grep -qi '4-tier\|\.robro/skills' "$TEMPLATE_FILE"; then
  pass "Template mentions 4-tier customization or .robro/skills"
else
  fail "Template missing 4-tier customization or .robro/skills reference"
fi

# Test 11: Update check mentioned
if grep -qi 'update.check\|update check' "$TEMPLATE_FILE"; then
  pass "Template mentions update check"
else
  fail "Template missing update check reference"
fi

echo ""
PASSED=$((11 - FAILURES))
echo "Results: $PASSED passed, $FAILURES failed"
exit $FAILURES
