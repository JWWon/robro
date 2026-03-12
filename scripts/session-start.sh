#!/usr/bin/env bash
# SessionStart hook: Detect active pipeline and guide resume
# Principle: tell the agent WHERE it is and WHAT to do. Not the rules — the skill handles that.

PLANS_DIR="docs/plans"

context="Robro plugin active. Skills: /robro:idea (PM) | /robro:spec (EM)"

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

# If there's an active pipeline status, inject focused resume guidance
if [ -n "$status_file" ]; then
  plan_dir=$(dirname "$(dirname "$status_file")")
  plan_name=$(basename "$plan_dir")
  skill=$(grep "^skill:" "$status_file" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
  step=$(grep "^step:" "$status_file" 2>/dev/null | head -1 | sed 's/^step: *//; s/"//g')
  detail=$(grep "^detail:" "$status_file" 2>/dev/null | head -1 | sed 's/^detail: *//; s/"//g')
  next_action=$(grep "^next:" "$status_file" 2>/dev/null | head -1 | sed 's/^next: *//; s/"//g')

  if [ -n "$skill" ] && [ "$skill" != "none" ]; then
    context="${context}

RESUME: '${plan_name}' — /robro:${skill}, step ${step}"
    [ -n "$detail" ] && context="${context} (${detail})"

    # Point to the right state file to read
    if [ "$skill" = "idea" ] && [ -f "${plan_dir}/discussion/interview-state.md" ]; then
      context="${context}
Read ${plan_dir}/discussion/interview-state.md to restore interview state."
    elif [ "$skill" = "spec" ]; then
      context="${context}
Read ${plan_dir}/discussion/ files to restore pipeline state."
    fi

    [ -n "$next_action" ] && context="${context}
Next: ${next_action}"
  fi
fi

# List all plans briefly
all_plans=""
if [ -d "$PLANS_DIR" ]; then
  for dir in "$PLANS_DIR"/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    artifacts=""
    [ -f "${dir}idea.md" ] && artifacts="${artifacts}idea "
    [ -f "${dir}plan.md" ] && artifacts="${artifacts}plan "
    [ -f "${dir}spec.yaml" ] && artifacts="${artifacts}spec "
    [ -n "$artifacts" ] && all_plans="${all_plans}\n  - ${name} [$(echo $artifacts | xargs)]"
  done
fi

if [ -n "$all_plans" ]; then
  context="${context}
Plans:$(echo -e "$all_plans")"
fi

echo "$context"
