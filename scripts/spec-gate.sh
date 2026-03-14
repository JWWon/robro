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

# Skip if editing docs, config, or meta files
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

if ! has_artifact "spec.yaml"; then
  if has_artifact "idea.md"; then
    echo "Warning: Writing source code without a spec. An idea.md exists — consider running /robro:plan to create the technical spec before implementing."
  else
    echo "Warning: Writing source code without a spec or idea. Consider running /robro:idea to define requirements first."
  fi
else
  # During active build, validate that file edits are within scope of current task
  status_file=$(find_latest_session "status.yaml" "skill" "do")
  if [ -n "$status_file" ]; then
    phase=$(status_field "$status_file" "phase")
    if [ "$phase" = "heads-down" ]; then
      echo "Build active (Heads-down phase). Ensure this edit is within the scope of the current task."
    fi
  fi
fi

exit 0
