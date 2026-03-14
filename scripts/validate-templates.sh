#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
errors=0

echo "=== Template Validation ==="

# 1. Agent names referenced in skill files match actual agents/*.md
echo "Checking agent references..."
for agent in $(grep -roh 'subagent_type:.*"robro:\([^"]*\)"' skills/ 2>/dev/null | sed 's/.*robro://;s/".*//' | sort -u); do
  if [ ! -f "agents/${agent}.md" ]; then
    echo "ERROR: subagent_type 'robro:${agent}' referenced but agents/${agent}.md not found"
    errors=$((errors + 1))
  fi
done

# Also check **AgentName** agent pattern
for agent in $(grep -roh '\*\*[A-Z][a-z_-]*\*\* agent' skills/ 2>/dev/null | sed 's/\*\*//g;s/ agent//' | tr '[:upper:]' '[:lower:]' | sort -u); do
  if [ ! -f "agents/${agent}.md" ]; then
    # Skip common words that aren't agent names
    case "$agent" in
      the|a|an|any|each|this|that|builder|reviewer) continue ;;
    esac
    echo "WARNING: '${agent}' referenced as agent in skills/ but agents/${agent}.md not found"
  fi
done

# 2. Check template references v0.2.0+ features if plugin version >= 0.2.0
plugin_version=$(jq -r '.version' .claude-plugin/plugin.json 2>/dev/null || echo "")
template_file="skills/setup/claude-md-template.md"
if [ -f "$template_file" ] && [ -n "$plugin_version" ]; then
  # Verify template documents current features (v0.2.0+ sections)
  if echo "$plugin_version" | grep -qE '^0\.[2-9]\.|^[1-9]\.'; then
    if ! grep -q "v0.2.0" "$template_file" 2>/dev/null; then
      echo "WARNING: Template may not document v0.2.0+ features (no v0.2.0 marker found)"
    fi
  fi
fi

# 3. Check all bash scripts pass syntax
echo "Checking bash syntax..."
for f in scripts/*.sh scripts/lib/*.sh; do
  [ -f "$f" ] || continue
  if ! bash -n "$f" 2>/dev/null; then
    echo "ERROR: Syntax error in $f"
    errors=$((errors + 1))
  fi
done

# 4. Check all .mjs scripts pass syntax
echo "Checking Node.js syntax..."
for f in scripts/*.mjs; do
  [ -f "$f" ] || continue
  if ! node -c "$f" 2>/dev/null; then
    echo "ERROR: Syntax error in $f"
    errors=$((errors + 1))
  fi
done

# 5. Check hooks.json is valid JSON
if ! jq . hooks/hooks.json > /dev/null 2>&1; then
  echo "ERROR: hooks/hooks.json is not valid JSON"
  errors=$((errors + 1))
fi

if [ "$errors" -eq 0 ]; then
  echo "PASS: All template validations passed"
  exit 0
else
  echo "FAIL: ${errors} error(s) found"
  exit 1
fi
