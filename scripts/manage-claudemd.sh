#!/usr/bin/env bash
# Manage the robro-owned section in .claude/CLAUDE.md
# Usage: manage-claudemd.sh [project_root]
#
# Reads version from plugin.json, template from claude-md-template.md.
# Handles: file missing, no markers, start only, both (same/diff version), duplicates.
# Backward compat: detects both old and new marker formats.
# Code-block-aware: skips markers inside triple-backtick fenced blocks.
#
# New markers:
#   <!-- robro@{version}:managed:start -->
#   <!-- robro:managed:end -->

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${1:-.}"

# Read version from plugin.json
VERSION=$(jq -r '.version' "${PLUGIN_ROOT}/.claude-plugin/plugin.json")
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  echo "Error: Could not read version from plugin.json" >&2
  exit 1
fi

# Read template
TEMPLATE_FILE="${PLUGIN_ROOT}/skills/setup/claude-md-template.md"
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template file not found: $TEMPLATE_FILE" >&2
  exit 1
fi
TEMPLATE=$(cat "$TEMPLATE_FILE")

TARGET_DIR="${PROJECT_ROOT}/.claude"
TARGET_FILE="${TARGET_DIR}/CLAUDE.md"

START_MARKER="<!-- robro@${VERSION}:managed:start -->"
END_MARKER="<!-- robro:managed:end -->"

MANAGED_BLOCK="${START_MARKER}
${TEMPLATE}
${END_MARKER}"

# Case 1: File does not exist
if [ ! -f "$TARGET_FILE" ]; then
  mkdir -p "$TARGET_DIR"
  printf '%s\n' "$MANAGED_BLOCK" > "$TARGET_FILE"
  echo "Created new .claude/CLAUDE.md with robro section (v${VERSION})"
  exit 0
fi

# File exists — use awk to mask fenced code blocks for marker detection
MASKED_CONTENT=$(awk '
  /^```/ { in_fence = !in_fence }
  in_fence { print "###FENCED###"; next }
  { print }
' "$TARGET_FILE")

# Detect start marker (both old and new format) outside code blocks
# Old format: <!-- robro:managed:start [VERSION] -->
# New format: <!-- robro@VERSION:managed:start -->
START_LINE=$(echo "$MASKED_CONTENT" | grep -n 'robro[@:][^>]*managed:start\|robro:managed:start' | head -1 | cut -d: -f1)

# Case 2: No start marker found — append
if [ -z "$START_LINE" ]; then
  printf '\n%s\n' "$MANAGED_BLOCK" >> "$TARGET_FILE"
  echo "Added robro section to existing .claude/CLAUDE.md (v${VERSION})"
  exit 0
fi

# Extract version from existing start marker
EXISTING_START=$(sed -n "${START_LINE}p" "$TARGET_FILE")
EXISTING_VERSION=""

# Try new format: <!-- robro@VERSION:managed:start -->
if echo "$EXISTING_START" | grep -q 'robro@[^:]*:managed:start'; then
  EXISTING_VERSION=$(echo "$EXISTING_START" | sed 's/.*robro@\([^:]*\):managed:start.*/\1/')
# Try old format: <!-- robro:managed:start [VERSION] -->
elif echo "$EXISTING_START" | grep -q 'robro:managed:start \['; then
  EXISTING_VERSION=$(echo "$EXISTING_START" | sed 's/.*\[\([^]]*\)\].*/\1/')
fi

[ -z "$EXISTING_VERSION" ] && EXISTING_VERSION="0.0.0"

# Detect end marker after start
END_LINE=$(echo "$MASKED_CONTENT" | tail -n +"$START_LINE" | grep -n 'robro:managed:end' | head -1 | cut -d: -f1)

# Case 3: Start marker found, no end marker — replace to EOF
if [ -z "$END_LINE" ]; then
  BEFORE=""
  if [ "$START_LINE" -gt 1 ]; then
    BEFORE=$(head -n $((START_LINE - 1)) "$TARGET_FILE")
  fi
  if [ -n "$BEFORE" ]; then
    printf '%s\n%s\n' "$BEFORE" "$MANAGED_BLOCK" > "$TARGET_FILE"
  else
    printf '%s\n' "$MANAGED_BLOCK" > "$TARGET_FILE"
  fi
  echo "Repaired robro section (missing end marker) in .claude/CLAUDE.md (v${EXISTING_VERSION} -> v${VERSION})"
  exit 0
fi

# Both markers found
ACTUAL_END_LINE=$((START_LINE + END_LINE - 1))

# Check for duplicates
MARKER_COUNT=$(echo "$MASKED_CONTENT" | grep -c 'robro[@:][^>]*managed:start\|robro:managed:start' || true)
if [ "$MARKER_COUNT" -gt 1 ]; then
  echo "Warning: Found duplicate robro managed marker pairs. Using the first pair." >&2
fi

# Case 4: Same version — skip
if [ "$EXISTING_VERSION" = "$VERSION" ]; then
  echo "Robro section already current (v${VERSION}) — no changes"
  exit 0
fi

# Case 5: Different version — replace block
TOTAL_LINES=$(wc -l < "$TARGET_FILE")
BEFORE=""
if [ "$START_LINE" -gt 1 ]; then
  BEFORE=$(head -n $((START_LINE - 1)) "$TARGET_FILE")
fi
AFTER=""
if [ "$ACTUAL_END_LINE" -lt "$TOTAL_LINES" ]; then
  AFTER=$(tail -n $((TOTAL_LINES - ACTUAL_END_LINE)) "$TARGET_FILE")
fi

{
  [ -n "$BEFORE" ] && printf '%s\n' "$BEFORE"
  printf '%s\n' "$MANAGED_BLOCK"
  [ -n "$AFTER" ] && printf '%s\n' "$AFTER"
} > "$TARGET_FILE"

echo "Updated robro section (v${EXISTING_VERSION} -> v${VERSION}) in .claude/CLAUDE.md"
