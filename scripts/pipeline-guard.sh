#!/usr/bin/env bash
# UserPromptSubmit hook: Inject focused "where you are, what to do next" guidance
# Reads discussion/status.yaml — a lightweight file that skills update at each step.
# Injects ONE focused instruction, not a rules dump.

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .content // ""' 2>/dev/null)
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | xargs)

# Skip if empty or invoking a skill directly
[ ${#PROMPT_LOWER} -lt 3 ] && exit 0
echo "$PROMPT_LOWER" | grep -q "^/robro:" && exit 0

PLANS_DIR="docs/plans"

# Find the most recently modified status.yaml
status_file=""
latest_mtime=0

if [ -d "$PLANS_DIR" ]; then
  for f in "$PLANS_DIR"/*/discussion/status.yaml; do
    [ -f "$f" ] || continue
    if stat -f %m "$f" >/dev/null 2>&1; then
      mtime=$(stat -f %m "$f")
    else
      mtime=$(stat -c %Y "$f")
    fi
    if [ "$mtime" -gt "$latest_mtime" ]; then
      latest_mtime=$mtime
      status_file=$f
    fi
  done
fi

# No active pipeline — exit silently
[ -z "$status_file" ] && exit 0

# Read status fields
skill=$(grep "^skill:" "$status_file" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
step=$(grep "^step:" "$status_file" 2>/dev/null | head -1 | sed 's/^step: *//; s/"//g')
detail=$(grep "^detail:" "$status_file" 2>/dev/null | head -1 | sed 's/^detail: *//; s/"//g')
next_action=$(grep "^next:" "$status_file" 2>/dev/null | head -1 | sed 's/^next: *//; s/"//g')
gate=$(grep "^gate:" "$status_file" 2>/dev/null | head -1 | sed 's/^gate: *//; s/"//g')

# Skip if skill is "none" or empty
[ -z "$skill" ] || [ "$skill" = "none" ] && exit 0

# Build focused injection — one line of context, one line of direction
output="[robro:${skill}] Step ${step}"
[ -n "$detail" ] && output="${output} — ${detail}"
echo "$output"

[ -n "$next_action" ] && echo "Next: ${next_action}"
[ -n "$gate" ] && echo "Gate: ${gate}"

# Inject skill-specific behavioral instruction (survives full context compression)
case "$skill" in
  idea)
    case "$step" in
      0|1|2)
        echo "Action: Complete setup, then begin the Socratic interview using AskUserQuestion."
        ;;
      8)
        echo "Action: Present pre-write confirmation checkpoints via AskUserQuestion."
        ;;
      10|11)
        echo "Action: Write idea.md if gate conditions are met, then suggest /robro:spec."
        ;;
      *)
        echo "Action: Continue Socratic interview. Use AskUserQuestion — one question targeting the weakest ambiguity dimension."
        ;;
    esac
    ;;
  spec)
    case "$step" in
      3.5)
        echo "Action: Present architecture decisions to user via AskUserQuestion for approval."
        ;;
      5.5)
        echo "Action: Present plan summary to user via AskUserQuestion for approval."
        ;;
      8|9|10)
        echo "Action: Cross-validate plan.md and spec.yaml, then run final Architect + Critic review."
        ;;
      *)
        echo "Action: Process agent outputs. Route on Status first, then Verdict. Iterate review loop if needed."
        ;;
    esac
    ;;
esac

exit 0
