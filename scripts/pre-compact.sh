#!/usr/bin/env bash
# PreCompact hook: Ensure pipeline state is persisted before context compression
# Skill-aware: tells the agent which files matter for the active skill.

PLANS_DIR="docs/plans"

# Find active status file (always at plan root)
if [ -d "$PLANS_DIR" ]; then
  for dir in "$PLANS_DIR"/*/; do
    [ -d "$dir" ] || continue
    candidate="${dir}status.yaml"
    [ -f "$candidate" ] || continue
    skill=$(grep "^skill:" "$candidate" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
    [ -z "$skill" ] || [ "$skill" = "none" ] && continue

    plan_dir=$(dirname "$candidate")
    plan_name=$(basename "$plan_dir")

  echo "Context compression imminent for '${plan_name}'. Persist state NOW:"
  echo "- Update status.yaml with current step, detail, next, and gate."

  if [ "$skill" = "idea" ]; then
    echo "- Update discussion/interview-state.md with current round, scores, requirements, and open threads."
  elif [ "$skill" = "plan" ]; then
    echo "- Ensure discussion/ agent outputs (architect-review.md, critic-assessment.md) are current."
    echo "- Note current review iteration count in status.yaml detail field."
  elif [ "$skill" = "do" ]; then
    echo "- Update status.yaml with current sprint, phase, task, and next action."
    echo "- Ensure discussion/build-progress.md has latest learnings appended."
    echo "- If in Heads-down phase, note which tasks are complete and which are pending."
    echo "- If in Review phase, note which review stages have passed."
  fi

  echo "These files drive session resume — without them, progress is lost."
  break
  done
fi

exit 0
