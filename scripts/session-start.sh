#!/usr/bin/env bash
# SessionStart hook: Detect active pipeline and guide resume
# Principle: tell the agent WHERE it is and WHAT to do. Not the rules — the skill handles that.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/load-config.sh"

context="Robro plugin active. Skills: /robro:idea (PM) | /robro:plan (EM) | /robro:do (Builder)"

# Find the most recently modified status.yaml (always at plan root)
status_file=$(find_latest_session "status.yaml")

# If there's an active pipeline status, inject focused resume guidance
if [ -n "$status_file" ]; then
  plan_dir=$(dirname "$status_file")
  plan_name=$(basename "$plan_dir")
  skill=$(status_field "$status_file" "skill")
  step=$(status_field "$status_file" "step")
  detail=$(status_field "$status_file" "detail")
  next_action=$(status_field "$status_file" "next")

  if [ -n "$skill" ] && [ "$skill" != "none" ]; then
    context="${context}

RESUME: '${plan_name}' — /robro:${skill}, step ${step}"
    [ -n "$detail" ] && context="${context} (${detail})"

    # Point to the right state file to read
    if [ "$skill" = "idea" ] && [ -f "${plan_dir}/discussion/interview-state.md" ]; then
      context="${context}
Read ${plan_dir}/discussion/interview-state.md to restore interview state."
    elif [ "$skill" = "plan" ]; then
      context="${context}
Read ${plan_dir}/discussion/ files to restore pipeline state."
    elif [ "$skill" = "do" ]; then
      sprint=$(status_field "$status_file" "sprint")
      phase=$(status_field "$status_file" "phase")

      # Count spec.yaml passes
      if [ -f "${plan_dir}/spec.yaml" ]; then
        read total passed superseded <<< "$(spec_counts "${plan_dir}/spec.yaml")"
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
Use /robro:do to continue execution."
    fi

    [ -n "$next_action" ] && context="${context}
Next: ${next_action}"
  fi
fi

# If no active status found in sessions dir, check worktrees for active plans
if [ -z "$status_file" ] || [ -z "$skill" ] || [ "$skill" = "none" ]; then
  WORKTREE_DIR="${PROJECT_ROOT}/.claude/worktrees"
  if [ -d "$WORKTREE_DIR" ]; then
    for wt_dir in "$WORKTREE_DIR"/*/; do
      [ -d "$wt_dir" ] || continue
      for wt_plan_dir in "${wt_dir}.robro/sessions"/*/; do
        [ -d "$wt_plan_dir" ] || continue
        candidate="${wt_plan_dir}status.yaml"
        [ -f "$candidate" ] || continue
        wt_skill=$(status_field "$candidate" "skill")
        [ -z "$wt_skill" ] || [ "$wt_skill" = "none" ] && continue
        wt_name=$(basename "$wt_dir")
        wt_step=$(status_field "$candidate" "step")
        wt_detail=$(status_field "$candidate" "detail")
        # Check spec completion for build worktrees
        if [ "$wt_skill" = "do" ] && [ -f "${wt_plan_dir}spec.yaml" ]; then
          read spec_total spec_passed spec_superseded <<< "$(spec_counts "${wt_plan_dir}spec.yaml")"
          spec_effective=$((spec_total - spec_superseded))

          if [ "$spec_passed" -ge "$spec_effective" ] && [ "$spec_effective" -gt 0 ]; then
            context="${context}

WORKTREE READY: Plan '$(basename "$wt_plan_dir")' — all ${spec_passed}/${spec_effective} spec items pass.
Branch: plan/$(basename "$wt_plan_dir") in worktree '${wt_name}'.
To merge: Run EnterWorktree(name: \"${wt_name}\"), then use /robro:do to run convergence and merge."
          else
            context="${context}

WORKTREE RESUME: Plan '$(basename "$wt_plan_dir")' — build in progress (${spec_passed}/${spec_effective} passing).
Skill: /robro:${wt_skill}, step ${wt_step} (${wt_detail})
To resume: Run EnterWorktree(name: \"${wt_name}\") to continue building."
          fi
        else
          # Non-build skills (idea, plan) — generic resume message
          context="${context}

WORKTREE RESUME: Plan '$(basename "$wt_plan_dir")' is active in worktree '${wt_name}'.
Skill: /robro:${wt_skill}, step ${wt_step} (${wt_detail})
To resume: Run EnterWorktree(name: \"${wt_name}\") to switch to the worktree."
        fi
        break 2
      done
    done
  fi
fi

# List all plans briefly
all_plans=""
if [ -d "$SESSIONS_DIR" ]; then
  for dir in "$SESSIONS_DIR"/*/; do
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
