#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): Remind about spec when actively implementing
# Reads hook input as JSON on stdin

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)

# Skip if no file path or if editing non-source files
[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  docs/*|*.md|*.json|*.yaml|*.yml|*.toml|*.lock|*.config.*|.*)
    exit 0
    ;;
esac

# Try to match the edited file to a specific spec by checking plan.md File Maps
# Fall back to most recently modified spec if no match found
matched_spec=""
if [ -d "docs/plans" ]; then
  for plan in docs/plans/*/plan.md; do
    [ -f "$plan" ] || continue
    # Check if file path appears in this plan's File Map
    if grep -q "$(basename "$FILE_PATH")" "$plan" 2>/dev/null; then
      dir=$(dirname "$plan")
      [ -f "${dir}/spec.yaml" ] && matched_spec="${dir}/spec.yaml" && break
    fi
  done
fi

# Fall back to most recently modified spec
if [ -z "$matched_spec" ] && [ -d "docs/plans" ]; then
  latest_mtime=0
  for spec in docs/plans/*/spec.yaml; do
    [ -f "$spec" ] || continue
    if stat -f %m "$spec" >/dev/null 2>&1; then
      mtime=$(stat -f %m "$spec")
    else
      mtime=$(stat -c %Y "$spec")
    fi
    if [ "$mtime" -gt "$latest_mtime" ]; then
      latest_mtime=$mtime
      matched_spec=$spec
    fi
  done
fi

if [ -n "$matched_spec" ]; then
  plan_dir=$(dirname "$matched_spec")
  plan_name=$(basename "$plan_dir")

  # Count incomplete checklist items
  incomplete=$(grep -c "passes: false" "$matched_spec" 2>/dev/null || echo "0")
  total=$(grep -c "passes:" "$matched_spec" 2>/dev/null || echo "0")

  if [ "$incomplete" -gt 0 ]; then
    echo "Active spec: ${plan_name}/spec.yaml (${incomplete}/${total} items remaining). Validate changes against checklist items and flip passes to true when verified."
  fi

  # During active build, show current task context
  status_candidate="${plan_dir}/status.yaml"
  if [ -f "$status_candidate" ]; then
    build_skill=$(grep "^skill:" "$status_candidate" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
    if [ "$build_skill" = "do" ]; then
      sprint=$(grep "^sprint:" "$status_candidate" 2>/dev/null | head -1 | sed 's/^sprint: *//; s/"//g')
      phase=$(grep "^phase:" "$status_candidate" 2>/dev/null | head -1 | sed 's/^phase: *//; s/"//g')
      echo "Build sprint ${sprint}, ${phase} phase."
    fi
  fi
fi

exit 0
