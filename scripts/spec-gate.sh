#!/usr/bin/env bash
# PreToolUse hook (Write|Edit): Warn if writing source files without a spec
# Reads hook input as JSON on stdin

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)

# Load shared config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/load-config.sh"

# Skip if no file path
[ -z "$FILE_PATH" ] && exit 0

# Skip if editing docs, config, or robro plugin files
case "$FILE_PATH" in
  docs/*|*.md|*.json|*.yaml|*.yml|*.toml|*.lock|*.config.*|.*)
    exit 0
    ;;
esac

# Skip if editing test files (tests are always OK)
case "$FILE_PATH" in
  *test*|*spec*|*__tests__*|*__mocks__*)
    exit 0
    ;;
esac

# Check if any spec.yaml exists in sessions dir
has_spec=false
if [ -d "$SESSIONS_DIR" ]; then
  for dir in "$SESSIONS_DIR"/*/; do
    [ -f "${dir}spec.yaml" ] && has_spec=true && break
  done
fi

if [ "$has_spec" = false ]; then
  # Check if any idea.md exists (user at least started the process)
  has_idea=false
  if [ -d "$SESSIONS_DIR" ]; then
    for dir in "$SESSIONS_DIR"/*/; do
      [ -f "${dir}idea.md" ] && has_idea=true && break
    done
  fi

  if [ "$has_idea" = true ]; then
    echo "Warning: Writing source code without a spec. An idea.md exists — consider running /robro:plan to create the technical spec before implementing."
  else
    echo "Warning: Writing source code without a spec or idea. Consider running /robro:idea to define requirements first."
  fi
fi

# During active build, validate that file edits are within scope of current task
if [ "$has_spec" = true ]; then
  # Check if build is active
  for dir in "$SESSIONS_DIR"/*/; do
    [ -d "$dir" ] || continue
    status_candidate="${dir}status.yaml"
    [ -f "$status_candidate" ] || continue
    build_skill=$(grep "^skill:" "$status_candidate" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
    if [ "$build_skill" = "do" ]; then
      phase=$(grep "^phase:" "$status_candidate" 2>/dev/null | head -1 | sed 's/^phase: *//; s/"//g')
      if [ "$phase" = "heads-down" ]; then
        echo "Build active (Heads-down phase). Ensure this edit is within the scope of the current task."
      fi
      break
    fi
  done
fi

exit 0
