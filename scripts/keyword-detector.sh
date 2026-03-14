#!/usr/bin/env bash
# UserPromptSubmit hook: Detect keywords and suggest relevant skills
# Reads hook input as JSON on stdin

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .content // ""' 2>/dev/null)

# Normalize: lowercase, trim
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | xargs)

# Load shared config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/load-config.sh"

# Skip if empty or too short
[ ${#PROMPT_LOWER} -lt 3 ] && exit 0

# Skip if already invoking a robro skill
echo "$PROMPT_LOWER" | grep -q "^/robro:" && exit 0

# Check for active spec in sessions dir
has_spec=false
if [ -d "$SESSIONS_DIR" ]; then
  for dir in "$SESSIONS_DIR"/*/; do
    [ -f "${dir}spec.yaml" ] && has_spec=true && break
  done
fi

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
esac

# Tier 2: Natural language triggers for /robro:idea
# Match phrases that suggest the user has a vague idea needing clarification
idea_patterns=(
  "i have an idea"
  "i want to build"
  "i want to create"
  "i want to add"
  "let's build"
  "let's create"
  "what if we"
  "how about we"
  "feature request"
  "new feature"
  "i'm thinking"
  "we should add"
  "we need to build"
  "can we build"
  "can we add"
  "i need a"
  "we need a"
)

for pattern in "${idea_patterns[@]}"; do
  if echo "$PROMPT_LOWER" | grep -q "$pattern"; then
    # Only suggest idea if no spec exists yet
    if [ "$has_spec" = false ]; then
      echo "It sounds like you have an idea to explore. Consider using /robro:idea to shape it into clear requirements before implementation."
    fi
    exit 0
  fi
done

# Tier 2.5: Natural language triggers for /robro:plan
spec_patterns=(
  "plan this"
  "break this down"
  "break it down"
  "create a spec"
  "create a plan"
  "implementation plan"
  "tech spec"
  "technical spec"
  "task breakdown"
  "spec this"
  "let's plan"
  "plan it out"
)

for pattern in "${spec_patterns[@]}"; do
  if echo "$PROMPT_LOWER" | grep -q "$pattern"; then
    if [ "$has_spec" = false ]; then
      # Check if idea.md exists
      has_idea=false
      if [ -d "$SESSIONS_DIR" ]; then
        for dir in "$SESSIONS_DIR"/*/; do
          [ -f "${dir}idea.md" ] && has_idea=true && break
        done
      fi
      if [ "$has_idea" = true ]; then
        echo "An idea.md exists. Consider using /robro:plan to generate the technical spec and implementation plan."
      else
        echo "No idea.md found. Consider running /robro:idea first to define requirements, then /robro:plan for the technical plan."
      fi
    fi
    exit 0
  fi
done

# Tier 2.7: Natural language triggers for /robro:tune
tune_patterns=(
  "audit config"
  "review config"
  "optimize setup"
  "tune setup"
  "check my setup"
  "improve config"
  "configuration audit"
  "check configuration"
)

for pattern in "${tune_patterns[@]}"; do
  if echo "$PROMPT_LOWER" | grep -q "$pattern"; then
    echo "Consider using /robro:tune to audit your project's Claude Code configuration for gaps and improvements."
    exit 0
  fi
done

# Tier 3: Implementation triggers — warn if no spec exists
impl_patterns=(
  "implement this"
  "start coding"
  "let's implement"
  "write the code"
  "start building"
  "begin implementation"
  "code this up"
)

for pattern in "${impl_patterns[@]}"; do
  if echo "$PROMPT_LOWER" | grep -q "$pattern"; then
    if [ "$has_spec" = true ]; then
      echo "A spec exists. Consider using /robro:do for structured autonomous execution."
    elif [ "$has_spec" = false ]; then
      echo "No spec found. Consider running /robro:idea then /robro:plan before implementing to ensure clear requirements and a validated plan."
    fi
    exit 0
  fi
done

exit 0
