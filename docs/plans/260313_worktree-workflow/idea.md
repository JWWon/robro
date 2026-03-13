---
type: update
created: 2026-03-13T00:00:00Z
ambiguity_score: 0.08
status: ready
project_type: brownfield
dimensions:
  goal: 0.95
  constraints: 0.90
  criteria: 0.92
  context: 0.88
complexity: complex
---

# Worktree-Based Workflow & Pipeline Refinement

## Goal

Refactor the robro pipeline to use git worktrees for branch isolation, rename skills for clarity (spec→plan, build→do), add complexity-driven agent model selection, and clean up YAML schemas — producing exactly one squash-merge commit per plan cycle on main.

## Problem Statement

Each plan cycle (idea → spec → build) generates 10+ commits on main, making git history noisy and hard to trace. The skill names "spec" and "build" are unintuitive and too narrow — "build" doesn't naturally cover bugfixes or refactors. Agent model selection is hardcoded with no way to scale compute based on task complexity. The status.yaml and spec.yaml schemas have structural issues (ambiguity buried in plain text, floating-point step numbers).

## Users & Stakeholders

- **Plugin users**: Benefit from cleaner git history, more intuitive skill names, and faster execution for light tasks.
- **Plugin developers**: Benefit from cleaner YAML schemas that are easier to parse in hooks and scripts.

## Requirements

### Must Have

- **Skill renaming**: `spec` → `plan`, `build` → `do`. Pipeline becomes: `/robro:idea` → `/robro:plan` → `/robro:do`
- **Worktree lifecycle**: Created at `/robro:plan` start with branch `plan/{slug}` and directory `.claude/worktrees/{slug}`. `/robro:idea` works on main with zero commits. Plan creates worktree, copies all plan files (including gitignored), cleans up main's working directory.
- **Squash merge via post-stop hook**: After `/robro:do` completes, a post-stop hook presents a summary and asks for merge approval. On approval: squash merge to main + delete worktree and branch.
- **3-tier complexity**: `light`, `standard`, `complex` — declared in idea.md by PM, confirmed/adjusted in spec.yaml by plan skill. Drives agent model selection.
- **Plugin-level model config**: Model mapping per complexity tier defined at the plugin level. Researcher and retro-analyst capped at sonnet (never opus).
- **status.yaml schema redesign**: Typed fields — numeric ambiguity score, integer step numbers, structured detail fields. No more burying data in plain-text strings.
- **spec.yaml gains `complexity` field**: Part of the meta section, read by the do skill to determine agent model dispatch.
- **Remove clean-memory skill**: Replaced by post-stop hook worktree cleanup. Simplify related workflows.
- **Plugin version bump to 0.1.1**: Manual version tagging instructions added to CLAUDE.md (concise).
- **Clean break**: No backward compatibility migration. Old plans stay as-is. Projects update CLAUDE.md next time `/robro:setup` runs.

### Should Have

- **Thinking level control per agent**: If the Claude Code platform supports thinking budget parameters (beyond model selection), implement per-agent thinking level configuration tied to complexity tiers. Research feasibility during plan phase.

### Won't Have (Non-goals)

- Automatic version tagging after merge
- Aliases for old skill names (`/robro:spec`, `/robro:build`)
- Changes to the 6-phase structure (Brief → Heads-down → Review → Retro → Level-up → Converge)
- Migration tooling for existing plans

## Constraints

- Agent tool currently only exposes `model` parameter (haiku/sonnet/opus) — no thinking level parameter. Thinking level control depends on platform support.
- Three CLAUDE.md files must stay in sync (root, `.claude/`, setup template).
- Hook scripts parse status.yaml with `grep + sed` — schema changes must remain parseable by shell tools.
- `.claude/worktrees/` must be gitignored.
- Worktree creation requires being on a branch that can spawn a new branch (typically main).

## Success Criteria

1. Completed plan cycle produces exactly 1 squash-merge commit on main
2. `/robro:plan` and `/robro:do` resolve correctly; all internal references updated
3. Worktree created at `/robro:plan` start, cleaned up after squash merge approval
4. spec.yaml contains `complexity` field; plugin defines model config per tier
5. status.yaml uses typed fields (numeric ambiguity, integer steps, structured detail)
6. Agents dispatch with tier-appropriate models (haiku/sonnet/opus per complexity)
7. Post-stop hook presents merge approval and handles worktree cleanup
8. clean-memory skill removed; related references cleaned up
9. Plugin version = 0.1.1; CLAUDE.md has versioning/tagging instructions
10. Thinking level control implemented if platform supports it; documented limitation if not

## Proposed Approach

**Rename-first**: Rename spec→plan and build→do across all files first, establishing a clean foundation. Then layer on new features:
1. Rename all skill files, agent references, hook scripts, CLAUDE.md files
2. Implement worktree lifecycle (creation at plan, file migration, squash merge, cleanup)
3. Add complexity system (spec.yaml field, plugin-level model configs, agent dispatch logic)
4. Redesign status.yaml/spec.yaml schemas
5. Build post-stop hook for merge approval + worktree cleanup
6. Remove clean-memory skill and simplify related workflows
7. Research and implement thinking level control (if feasible)
8. Version bump and CLAUDE.md updates

## Assumptions Exposed

| Assumption | Status | Resolution |
| --- | --- | --- |
| Git worktree can copy gitignored files from main's working directory | Verified | Manual file copy + cleanup after worktree creation works |
| Agent tool `model` parameter is the only compute control available | Open | Need to research thinking level support in Claude Code 4.6 |
| Hook scripts can parse new status.yaml schema with grep+sed | Verified | Schema stays flat YAML with typed values — grep/sed compatible |
| Clean break won't disrupt active users | Challenged | Accepted — plugin is pre-1.0, old plans archived, setup regenerates CLAUDE.md |
| Researcher/retro don't need opus even for complex tasks | Verified | User confirmed — these agents gather/summarize, don't make architectural decisions |

## Context

Robro is a Claude Code plugin at v0.1.0. The codebase has:
- 6 skills (idea, spec, build, setup, tune, clean-memory) → becomes 5 (idea, plan, do, setup, tune)
- 11 agents with markdown definitions and frontmatter
- 7 hooks across 6 event types, all shell command hooks
- Status.yaml drives hook injection; parsed by grep+sed in shell scripts
- Existing worktree support is ephemeral/agent-scoped (for parallel builder dispatch), not plan-scoped
- One completed plan exists (`260313_level-up-enhancements`) using old schema — will be archived

## Open Questions

- Can Claude Code's Agent tool or agent frontmatter control thinking level/budget? Needs platform research.
- Where should the plugin-level model config per complexity tier live? (plugin.json extension? separate config file? agent frontmatter defaults?)

## Key Research Findings

- The Agent tool supports `model` parameter with values: `haiku`, `sonnet`, `opus`. No thinking level parameter found.
- Agent frontmatter currently supports `name` and `description` fields. Model can be set in agent definitions.
- Status.yaml is flat YAML parsed by shell scripts — extensible but must remain grep/sed-friendly.
- The build skill's heads-down phase already has worktree support for agent isolation (Path B: Isolated Parallel), but this is ephemeral per-agent, not plan-scoped.
- Stop hook uses `{"decision":"block"}` JSON to prevent premature exits. Post-stop hook for merge would use a different mechanism (fires after skill completes, not during).
