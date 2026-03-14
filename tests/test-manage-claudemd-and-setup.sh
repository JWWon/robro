#!/usr/bin/env bash
# Test: Task 4.1-4.4 — manage-claudemd.sh + setup skill updates
# Validates:
#   C15: manage-claudemd.sh exists, executable, passes bash -n,
#        uses robro@{version}:managed:start format, detects both old and new markers,
#        code-block-aware
#   C17: setup skill .gitignore section lists 5 rules for .robro/sessions/ + .claude/worktrees/
#   C18: setup skill Step 1 calls manage-claudemd.sh, includes Step 3.7 for config.json creation offer

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_FILE="$REPO_ROOT/scripts/manage-claudemd.sh"
SKILL_FILE="$REPO_ROOT/skills/setup/SKILL.md"
FAILURES=0

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
}

echo "=== C15: manage-claudemd.sh ==="

# C15-1: Script file exists
if [[ -f "$SCRIPT_FILE" ]]; then
  pass "manage-claudemd.sh exists"
else
  fail "manage-claudemd.sh does not exist"
fi

# C15-2: Script is executable
if [[ -x "$SCRIPT_FILE" ]]; then
  pass "manage-claudemd.sh is executable"
else
  fail "manage-claudemd.sh is not executable"
fi

# C15-3: Script passes bash -n syntax check
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  pass "manage-claudemd.sh passes bash -n"
else
  fail "manage-claudemd.sh fails bash -n syntax check"
fi

# C15-4: Uses new marker format robro@{version}:managed:start
if grep -q 'robro@.*:managed:start' "$SCRIPT_FILE" 2>/dev/null; then
  pass "Uses robro@{version}:managed:start format"
else
  fail "Does not use robro@{version}:managed:start format"
fi

# C15-5: Uses robro:managed:end marker
if grep -q 'robro:managed:end' "$SCRIPT_FILE" 2>/dev/null; then
  pass "Uses robro:managed:end marker"
else
  fail "Does not use robro:managed:end marker"
fi

# C15-6: Detects old marker format (robro:managed:start [VERSION])
if grep -q 'robro:managed:start \[' "$SCRIPT_FILE" 2>/dev/null || grep -q 'robro:managed:start.*\\\[' "$SCRIPT_FILE" 2>/dev/null; then
  pass "Detects old marker format"
else
  fail "Does not detect old marker format (robro:managed:start [VERSION])"
fi

# C15-7: Code-block-aware (references fenced/code block/backtick)
if grep -qi 'fence\|code.block\|backtick\|```\|FENCED' "$SCRIPT_FILE" 2>/dev/null; then
  pass "Code-block-aware logic present"
else
  fail "No code-block-aware logic found"
fi

# C15-8: Reads version from plugin.json
if grep -q 'plugin.json' "$SCRIPT_FILE" 2>/dev/null; then
  pass "Reads version from plugin.json"
else
  fail "Does not read version from plugin.json"
fi

# C15-9: Reads template from claude-md-template.md
if grep -q 'claude-md-template.md' "$SCRIPT_FILE" 2>/dev/null; then
  pass "Reads template from claude-md-template.md"
else
  fail "Does not read template from claude-md-template.md"
fi

# C15-10: Uses CLAUDE_PLUGIN_ROOT
if grep -q 'CLAUDE_PLUGIN_ROOT' "$SCRIPT_FILE" 2>/dev/null; then
  pass "Uses CLAUDE_PLUGIN_ROOT"
else
  fail "Does not use CLAUDE_PLUGIN_ROOT"
fi

echo ""
echo "=== C17: .gitignore rules in setup skill ==="

# C17-1: Contains .robro/sessions/*/research/ rule
if grep -q '\.robro/sessions/\*/research/' "$SKILL_FILE" 2>/dev/null; then
  pass ".robro/sessions/*/research/ rule present"
else
  fail ".robro/sessions/*/research/ rule not found"
fi

# C17-2: Contains .robro/sessions/*/discussion/ rule
if grep -q '\.robro/sessions/\*/discussion/' "$SKILL_FILE" 2>/dev/null; then
  pass ".robro/sessions/*/discussion/ rule present"
else
  fail ".robro/sessions/*/discussion/ rule not found"
fi

# C17-3: Contains .robro/sessions/*/status.yaml rule
if grep -q '\.robro/sessions/\*/status\.yaml' "$SKILL_FILE" 2>/dev/null; then
  pass ".robro/sessions/*/status.yaml rule present"
else
  fail ".robro/sessions/*/status.yaml rule not found"
fi

# C17-4: Contains .robro/sessions/*/*.bak.* rule
if grep -q '\.robro/sessions/\*/\*\.bak\.\*' "$SKILL_FILE" 2>/dev/null; then
  pass ".robro/sessions/*/*.bak.* rule present"
else
  fail ".robro/sessions/*/*.bak.* rule not found"
fi

# C17-5: Contains .claude/worktrees/ rule
if grep -q '\.claude/worktrees/' "$SKILL_FILE" 2>/dev/null; then
  pass ".claude/worktrees/ rule present"
else
  fail ".claude/worktrees/ rule not found"
fi

# C17-6: Old docs/plans/ rules are NOT present
OLD_RULES_COUNT=$(grep -c 'docs/plans/' "$SKILL_FILE" 2>/dev/null || true)
if [[ "$OLD_RULES_COUNT" -eq 0 ]]; then
  pass "No old docs/plans/ rules present"
else
  fail "Old docs/plans/ rules still present ($OLD_RULES_COUNT occurrences)"
fi

echo ""
echo "=== C18: Step 1 calls manage-claudemd.sh + Step 3.7 config.json ==="

# C18-1: Step 1 references manage-claudemd.sh
if grep -q 'manage-claudemd.sh' "$SKILL_FILE" 2>/dev/null; then
  pass "Step 1 references manage-claudemd.sh"
else
  fail "Step 1 does not reference manage-claudemd.sh"
fi

# C18-2: Step 1 does NOT have old sub-steps (1a through 1h)
if grep -q '#### 1a\.' "$SKILL_FILE" 2>/dev/null; then
  fail "Old Step 1a still present"
else
  pass "Old Step 1a sub-steps removed"
fi

# C18-3: Step 1 references new marker format
if grep -q 'robro@{version}:managed:start' "$SKILL_FILE" 2>/dev/null || grep -q 'robro@.*:managed:start' "$SKILL_FILE" 2>/dev/null; then
  pass "Step 1 references new marker format"
else
  fail "Step 1 does not reference new marker format"
fi

# C18-4: Step 3.7 exists
if grep -q '### Step 3.7' "$SKILL_FILE" 2>/dev/null; then
  pass "Step 3.7 exists"
else
  fail "Step 3.7 does not exist"
fi

# C18-5: Step 3.7 mentions config.json
if grep -q 'config\.json' "$SKILL_FILE" 2>/dev/null; then
  pass "Step 3.7 mentions config.json"
else
  fail "Step 3.7 does not mention config.json"
fi

# C18-6: Step 3.7 mentions AskUserQuestion
if grep -q 'AskUserQuestion' "$SKILL_FILE" 2>/dev/null; then
  pass "Step 3.7 includes AskUserQuestion"
else
  fail "Step 3.7 does not include AskUserQuestion"
fi

# C18-7: Step 3.7 mentions .robro/config.json
if grep -q '\.robro/config\.json' "$SKILL_FILE" 2>/dev/null; then
  pass "Step 3.7 references .robro/config.json"
else
  fail "Step 3.7 does not reference .robro/config.json"
fi

# C18-8: Step 3.7 mentions $schema
if grep -q '\$schema' "$SKILL_FILE" 2>/dev/null; then
  pass "Step 3.7 includes \$schema reference"
else
  fail "Step 3.7 does not include \$schema reference"
fi

# C18-9: No old-format marker references remain (robro:managed:start [)
if grep -q 'robro:managed:start \[' "$SKILL_FILE" 2>/dev/null; then
  fail "Old marker format references still present in SKILL.md"
else
  pass "No old-format marker references in SKILL.md"
fi

echo ""
TOTAL=25
PASSED=$((TOTAL - FAILURES))
echo "Results: $PASSED passed, $FAILURES failed"
exit $FAILURES
