#!/usr/bin/env bash
# SessionStart hook: Detect active pipeline and guide resume
# Principle: tell the agent WHERE it is and WHAT to do. Not the rules — the skill handles that.

PLANS_DIR="docs/plans"

context="Robro plugin active. Skills: /robro:idea (PM) | /robro:spec (EM) | /robro:build (Builder)"

# Find the most recently modified status.yaml (always at plan root)
status_file=""
latest_mtime=0

if [ -d "$PLANS_DIR" ]; then
  for dir in "$PLANS_DIR"/*/; do
    [ -d "$dir" ] || continue
    candidate="${dir}status.yaml"
    [ -f "$candidate" ] || continue
    if stat -f %m "$candidate" >/dev/null 2>&1; then
      mtime=$(stat -f %m "$candidate")
    else
      mtime=$(stat -c %Y "$candidate")
    fi
    if [ "$mtime" -gt "$latest_mtime" ]; then
      latest_mtime=$mtime
      status_file=$candidate
    fi
  done
fi

# If there's an active pipeline status, inject focused resume guidance
if [ -n "$status_file" ]; then
  plan_dir=$(dirname "$status_file")
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
    elif [ "$skill" = "build" ]; then
      sprint=$(grep "^sprint:" "$status_file" 2>/dev/null | head -1 | sed 's/^sprint: *//; s/"//g')
      phase=$(grep "^phase:" "$status_file" 2>/dev/null | head -1 | sed 's/^phase: *//; s/"//g')

      # Count spec.yaml passes
      if [ -f "${plan_dir}/spec.yaml" ]; then
        total=$(grep -c "passes:" "${plan_dir}/spec.yaml" 2>/dev/null || echo "0")
        passed=$(grep -c "passes: true" "${plan_dir}/spec.yaml" 2>/dev/null || echo "0")
        context="${context}
Spec progress: ${passed}/${total} items passing."
      fi

      # Read build-progress.md for latest learnings
      progress_file="${plan_dir}/discussion/build-progress.md"
      if [ -f "$progress_file" ]; then
        last_learning=$(tail -20 "$progress_file" | grep -m1 "^## " | sed 's/^## //')
        [ -n "$last_learning" ] && context="${context}
Last logged: ${last_learning}"
      fi

      context="${context}
Sprint ${sprint}, phase ${phase}.
Read ${plan_dir}/status.yaml and ${plan_dir}/discussion/build-progress.md to restore build state.
Use /robro:build to continue execution."
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
