#!/usr/bin/env bash
# UserPromptSubmit hook: Detect keywords and suggest relevant skills
# Reads hook input as JSON on stdin

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .content // ""' 2>/dev/null)

# Normalize: lowercase, trim
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | xargs)

# Skip if empty or too short
[ ${#PROMPT_LOWER} -lt 3 ] && exit 0

# Skip if already invoking a robro skill
echo "$PROMPT_LOWER" | grep -q "^/robro:" && exit 0

# Check for active spec in docs/plans/
has_spec=false
if [ -d "docs/plans" ]; then
  for dir in docs/plans/*/; do
    [ -f "${dir}spec.yaml" ] && has_spec=true && break
  done
fi

# Tier 1: Direct skill triggers
case "$PROMPT_LOWER" in
  *"robro idea"*|*"robro:idea"*)
    echo "Suggestion: Use /robro:idea to start a structured requirements interview."
    exit 0
    ;;
  *"robro spec"*|*"robro:spec"*)
    echo "Suggestion: Use /robro:spec to generate technical spec and implementation plan."
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

# Tier 2.5: Natural language triggers for /robro:spec
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
      if [ -d "docs/plans" ]; then
        for dir in docs/plans/*/; do
          [ -f "${dir}idea.md" ] && has_idea=true && break
        done
      fi
      if [ "$has_idea" = true ]; then
        echo "An idea.md exists. Consider using /robro:spec to generate the technical spec and implementation plan."
      else
        echo "No idea.md found. Consider running /robro:idea first to define requirements, then /robro:spec for the technical plan."
      fi
    fi
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
    if [ "$has_spec" = false ]; then
      echo "No spec found in docs/plans/. Consider running /robro:idea then /robro:spec before implementing to ensure clear requirements and a validated plan."
    fi
    exit 0
  fi
done

exit 0
