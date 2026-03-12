#!/usr/bin/env bash
# PreCompact hook: Ensure pipeline state is persisted before context compression
# Skill-aware: tells the agent which files matter for the active skill.

PLANS_DIR="docs/plans"

# Find active status file
for f in "$PLANS_DIR"/*/discussion/status.yaml; do
  [ -f "$f" ] || continue
  skill=$(grep "^skill:" "$f" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
  [ -z "$skill" ] || [ "$skill" = "none" ] && continue

  plan_dir=$(dirname "$(dirname "$f")")
  plan_name=$(basename "$plan_dir")

  echo "Context compression imminent for '${plan_name}'. Persist state NOW:"
  echo "- Update discussion/status.yaml with current step, detail, next, and gate."

  if [ "$skill" = "idea" ]; then
    echo "- Update discussion/interview-state.md with current round, scores, requirements, and open threads."
  elif [ "$skill" = "spec" ]; then
    echo "- Ensure discussion/ agent outputs (architect-review.md, critic-assessment.md) are current."
    echo "- Note current review iteration count in status.yaml detail field."
  fi

  echo "These files drive session resume — without them, progress is lost."
  exit 0
done

exit 0
