#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): Remind about spec when actively implementing
# Reads hook input as JSON on stdin

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)

# Load shared config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/load-config.sh"

# Skip if no file path or if editing non-source files
[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  docs/*|*.md|*.json|*.yaml|*.yml|*.toml|*.lock|*.config.*|.*)
    exit 0
    ;;
esac

# Compute relative path for precise plan matching
project_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$project_root" ]; then
  relative_path="${FILE_PATH#$project_root/}"
else
  relative_path=$(basename "$FILE_PATH")
fi

# Try to match the edited file to a specific spec by checking plan.md File Maps
matched_spec=""
if [ -d "$SESSIONS_DIR" ]; then
  for plan in "$SESSIONS_DIR"/*/plan.md; do
    [ -f "$plan" ] || continue
    # Match relative path (not just basename) for precision
    if grep -qF "$relative_path" "$plan" 2>/dev/null; then
      dir=$(dirname "$plan")
      [ -f "${dir}/spec.yaml" ] && matched_spec="${dir}/spec.yaml" && break
    fi
  done
fi

# Fall back to most recently modified spec
if [ -z "$matched_spec" ]; then
  matched_spec=$(find_latest_session "spec.yaml")
fi

if [ -n "$matched_spec" ]; then
  plan_dir=$(dirname "$matched_spec")
  plan_name=$(basename "$plan_dir")

  # Count incomplete checklist items
  read total passed superseded <<< "$(spec_counts "$matched_spec")"
  incomplete=$((total - passed))

  if [ "$incomplete" -gt 0 ]; then
    echo "Active spec: ${plan_name}/spec.yaml (${incomplete}/${total} items remaining). Validate changes against checklist items and flip passes to true when verified."
  fi

  # During active build, show current task context
  status_candidate="${plan_dir}/status.yaml"
  if [ -f "$status_candidate" ]; then
    build_skill=$(status_field "$status_candidate" "skill")
    if [ "$build_skill" = "do" ]; then
      sprint=$(status_field "$status_candidate" "sprint")
      phase=$(status_field "$status_candidate" "phase")
      echo "Build sprint ${sprint}, ${phase} phase."
    fi
  fi
fi

exit 0
