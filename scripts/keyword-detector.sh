#!/usr/bin/env bash
# UserPromptSubmit hook: Detect keywords and suggest relevant skills
# Reads hook input as JSON on stdin

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .content // ""' 2>/dev/null)

# Load shared config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/load-config.sh"

# Sanitize prompt: strip XML tags, URLs, file paths, and code blocks
sanitize_prompt() {
  local prompt="$1"
  echo "$prompt" \
    | sed 's/<[^>]*>//g' \
    | sed 's|https\?://[^ ]*||g' \
    | sed 's|/[a-zA-Z_./]*\.[a-zA-Z]*||g' \
    | sed '/^```/,/^```/d' \
    | tr '[:upper:]' '[:lower:]'
}

# Apply sanitization before keyword matching
PROMPT_LOWER=$(sanitize_prompt "$PROMPT")

# Skip if empty or too short
[ ${#PROMPT_LOWER} -lt 3 ] && exit 0

# Skip if already invoking a robro skill
echo "$PROMPT_LOWER" | grep -q "^/robro:" && exit 0

# Check for active artifacts
has_spec=false
has_artifact "spec.yaml" && has_spec=true

# Tier 1: Direct skill triggers
case "$PROMPT_LOWER" in
  *"robro idea"*|*"robro:idea"*)
    echo "Suggestion: Use /robro:idea to start a structured requirements interview."
    exit 0
    ;;
  *"robro plan"*|*"robro:plan"*)
    echo "Suggestion: Use /robro:plan to generate technical spec and implementation plan."
    exit 0
    ;;
  *"robro do"*|*"robro:do"*)
    echo "Suggestion: Use /robro:do to start autonomous execution of the plan."
    exit 0
    ;;
  *"robro tune"*|*"robro:tune"*)
    echo "Suggestion: Use /robro:tune to audit and optimize your project's Claude Code configuration."
    exit 0
    ;;
  *"robro review"*|*"robro:review"*)
    echo "Suggestion: Use /robro:review to run a structured review (plan, code, or bug mode)."
    exit 0
    ;;
  *"robro qa"*|*"robro:qa"*)
    echo "Suggestion: Use /robro:qa to run automated tests and generate a pass/fail report."
    exit 0
    ;;
esac

# Tier 2: Natural language triggers for /robro:idea (single regex instead of 18 subprocesses)
if echo "$PROMPT_LOWER" | grep -qE "i have an idea|i want to build|i want to create|i want to add|let's build|let's create|what if we|how about we|feature request|new feature|i'm thinking|we should add|we need to build|can we build|can we add|i need a|we need a"; then
  if ! $has_spec; then
    echo "It sounds like you have an idea to explore. Consider using /robro:idea to shape it into clear requirements before implementation."
  fi
  exit 0
fi

# Tier 2.5: Natural language triggers for /robro:plan (single regex instead of 12 subprocesses)
if echo "$PROMPT_LOWER" | grep -qE "plan this|break this down|break it down|create a spec|create a plan|implementation plan|tech spec|technical spec|task breakdown|spec this|let's plan|plan it out"; then
  if ! $has_spec; then
    has_idea=false
    has_artifact "idea.md" && has_idea=true
    if $has_idea; then
      echo "An idea.md exists. Consider using /robro:plan to generate the technical spec and implementation plan."
    else
      echo "No idea.md found. Consider running /robro:idea first to define requirements, then /robro:plan for the technical plan."
    fi
  fi
  exit 0
fi

# Tier 2.7: Natural language triggers for /robro:tune (single regex instead of 8 subprocesses)
if echo "$PROMPT_LOWER" | grep -qE "audit config|review config|optimize setup|tune setup|check my setup|improve config|configuration audit|check configuration"; then
  echo "Consider using /robro:tune to audit your project's Claude Code configuration for gaps and improvements."
  exit 0
fi

# Tier 2.8: Natural language triggers for /robro:review
if echo "$PROMPT_LOWER" | grep -qE "review my|review the|check my|check the plan|code review|review this|audit my|look for bugs|find issues|review for bugs"; then
  echo "Consider using /robro:review to run a structured review of your plan, code, or a specific bug."
  exit 0
fi

# Tier 2.9: Natural language triggers for /robro:qa
if echo "$PROMPT_LOWER" | grep -qE "run tests|run the tests|check tests|test coverage|verify tests|qa check|does it pass|all tests pass|run qa"; then
  echo "Consider using /robro:qa to run automated tests and generate a structured pass/fail report."
  exit 0
fi

# Tier 3: Implementation triggers — warn if no spec exists (single regex instead of 7 subprocesses)
if echo "$PROMPT_LOWER" | grep -qE "implement this|start coding|let's implement|write the code|start building|begin implementation|code this up"; then
  if $has_spec; then
    echo "A spec exists. Consider using /robro:do for structured autonomous execution."
  else
    echo "No spec found. Consider running /robro:idea then /robro:plan before implementing to ensure clear requirements and a validated plan."
  fi
  exit 0
fi

exit 0
