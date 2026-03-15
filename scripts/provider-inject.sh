#!/usr/bin/env bash
# UserPromptSubmit hook: Inject available external CLI provider context.
# Fires on every prompt — even without an active pipeline.
# Reads enabled providers from .robro/config.json, validates binary + auth,
# and emits advisory invocation templates for Claude to use.

INPUT=$(cat)

# Skip empty prompts
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .content // ""' 2>/dev/null)
[ ${#PROMPT} -lt 3 ] && exit 0

# Skip direct skill invocations
echo "$PROMPT" | grep -q "^/robro:" && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/load-config.sh"

# Collect available providers
available_names=""
available_templates=""

while IFS=: read -r name model timeout_ms; do
  [ -z "$name" ] && continue

  # Derive timeout in seconds for POSIX timeout command
  timeout_sec=$(( (timeout_ms + 999) / 1000 ))

  # Build invocation template based on provider name
  case "$name" in
    codex)
      template="timeout ${timeout_sec} codex exec --full-auto --ephemeral -c model=\\\"${model}\\\" \"{prompt}\" 2>/dev/null"
      ;;
    gemini)
      template="timeout ${timeout_sec} gemini -p \"{prompt}\" --approval-mode=yolo --output-format json -m ${model} 2>/dev/null | jq -r '.response // .'"
      ;;
    *)
      template="timeout ${timeout_sec} ${name} \"{prompt}\" 2>/dev/null"
      ;;
  esac

  if [ -n "$available_names" ]; then
    available_names="${available_names}, ${name}(${model})"
  else
    available_names="${name}(${model})"
  fi

  if [ -n "$available_templates" ]; then
    available_templates="${available_templates}
  ${name}: ${template}"
  else
    available_templates="  ${name}: ${template}"
  fi

done < <(robro_providers)

# No providers available — exit silently
[ -z "$available_names" ] && exit 0

# Emit advisory context
echo "External advisors available: ${available_names}"
echo "<advisory_templates>"
echo "$available_templates"
echo "</advisory_templates>"
parallel_timeout_ms=$(robro_config '.providers.parallel_timeout_ms' '60000')
echo "Advisory rule: at most 2 delegations per task/phase (parallel allowed). Use run_in_background:true for concurrent calls. Present both outputs labeled: \"[Codex] found...\" / \"[Gemini] suggests...\". Do NOT merge outputs — show both. Wrap each in <external_advisory source=\"{provider}\"> tags. On failure, log warning and continue. Parallel timeout: ${parallel_timeout_ms}ms."

exit 0
