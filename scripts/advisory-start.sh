#!/usr/bin/env bash
# SubagentStart hook: inject mandatory advisory context for critical agents.
# For mandatory agents (architect, reviewer, critic): injects MUST-language
# advisory instructions and writes a state file for SubagentStop to read.
#
# Input JSON fields: .agent_type, .agent_id
# Output: JSON with hookSpecificOutput.additionalContext (mandatory agents only)

set -euo pipefail

INPUT=$(cat)

agent_type=$(echo "$INPUT" | jq -r '.agent_type // ""' 2>/dev/null)
agent_id=$(echo "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null)

# Fast path: non-mandatory agents exit immediately
case "$agent_type" in
  robro:architect|robro:reviewer|robro:critic)
    ;;  # continue
  *)
    exit 0
    ;;
esac

# Write state file for SubagentStop (verify-deliverables.sh) to read
if [ -n "$agent_id" ]; then
  printf 'agent_type=%s\nagent_id=%s\n' "$agent_type" "$agent_id" > "/tmp/robro-advisory-${agent_id}.state"
fi

# Load config library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/load-config.sh"

# Collect available providers
codex_model="" codex_template=""
gemini_model="" gemini_template=""

while IFS=: read -r name model timeout_ms; do
  [ -z "$name" ] && continue
  timeout_sec=$(( (timeout_ms + 999) / 1000 ))
  case "$name" in
    codex)
      codex_model="$model"
      codex_template="timeout ${timeout_sec} codex exec --full-auto --sandbox --ephemeral -c model=\\\"${model}\\\" \"{prompt}\" 2>/dev/null"
      ;;
    gemini)
      gemini_model="$model"
      gemini_template="timeout ${timeout_sec} gemini -p \"{prompt}\" --approval-mode=yolo --output-format json -m ${model} 2>/dev/null | jq -r '.response // .'"
      ;;
  esac
done < <(robro_providers)

# No providers → nothing to inject
if [ -z "$codex_model" ] && [ -z "$gemini_model" ]; then
  exit 0
fi

# Determine designated provider per agent role
designated_provider="" designated_template="" designated_model=""
case "$agent_type" in
  robro:architect|robro:reviewer)
    if [ -n "$codex_model" ]; then
      designated_provider="codex"; designated_template="$codex_template"; designated_model="$codex_model"
    elif [ -n "$gemini_model" ]; then
      designated_provider="gemini"; designated_template="$gemini_template"; designated_model="$gemini_model"
    fi
    ;;
  robro:critic)
    if [ -n "$codex_model" ]; then
      designated_provider="codex"; designated_template="$codex_template"; designated_model="$codex_model"
    elif [ -n "$gemini_model" ]; then
      designated_provider="gemini"; designated_template="$gemini_template"; designated_model="$gemini_model"
    fi
    ;;
esac

[ -z "$designated_provider" ] && exit 0

# Build MUST-call context
agent_label="${agent_type#robro:}"
context="MANDATORY ADVISORY ENFORCEMENT:
You are a mandatory advisory gate. You MUST call the designated provider (${designated_provider}) before completing your analysis.

Designated provider for ${agent_label}: ${designated_provider}(${designated_model})
Invocation template: ${designated_template}

On provider failure: log warning and continue — do NOT block your output.
Wrap provider response in <external_advisory source=\"${designated_provider}\"> tags."

# Output JSON for hook system
jq -n --arg ctx "$context" \
  '{hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext: $ctx}}'

exit 0
