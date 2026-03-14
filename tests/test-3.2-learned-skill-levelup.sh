#!/usr/bin/env bash
# Test 3.2: Verify level-up-phase.md contains learned skill instructions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FILE="$PROJECT_ROOT/skills/do/level-up-phase.md"

passed=0
failed=0

assert() {
  local condition="$1" message="$2"
  if eval "$condition"; then
    passed=$((passed + 1))
    echo "  PASS: $message"
  else
    failed=$((failed + 1))
    echo "  FAIL: $message"
  fi
}

echo "Test 3.2: Learned Skill integration in level-up-phase.md"

# 1. File must contain "Learned Skill" type header
count=$(grep -c 'Learned Skill' "$FILE" || true)
assert '[ "$count" -ge 1 ]' "Contains 'Learned Skill' section ($count occurrences)"

# 2. Must reference JSON frontmatter format
count=$(grep -c 'JSON frontmatter' "$FILE" || true)
assert '[ "$count" -ge 1 ]' "References JSON frontmatter ($count occurrences)"

# 3. Must reference skill-index
count=$(grep -c 'skill-index' "$FILE" || true)
assert '[ "$count" -ge 1 ]' "References skill-index ($count occurrences)"

# 4. Must include trigger keyword requirements
assert 'grep -q "triggers" "$FILE"' "Contains trigger field documentation"

# 5. Must specify .robro/skills/ path
assert 'grep -q "\.robro/skills/" "$FILE"' "Specifies .robro/skills/ output path"

# 6. Must include quality gates for learned skills
assert 'grep -q "Quality gate" "$FILE" || grep -q "quality gate" "$FILE" || grep -q "Quality Gate" "$FILE"' "Contains quality gates section"

# 7. Must mention specificity requirement (not generic)
assert 'grep -qi "not generic\|specific.*codebase\|actual.*file" "$FILE"' "Requires codebase-specific content"

# 8. Must include index rebuild instructions
assert 'grep -q "skill-index.json" "$FILE"' "Documents skill-index.json rebuild"

# 9. Must describe required frontmatter fields
assert 'grep -q '"'"'"name"'"'"' "$FILE" && grep -q '"'"'"description"'"'"' "$FILE"' "Documents required frontmatter fields (name, description)"

# 10. Must include created_by field
assert 'grep -q "created_by" "$FILE"' "Documents created_by field"

echo ""
echo "Results: $passed passed, $failed failed"
exit $((failed > 0 ? 1 : 0))
