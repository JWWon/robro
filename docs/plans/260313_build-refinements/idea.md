---
type: update
created: 2026-03-13T00:00:00Z
ambiguity_score: 0.07
status: ready
project_type: brownfield
dimensions:
  goal: 0.94
  constraints: 0.92
  criteria: 0.92
  context: 0.92
---

# Build Skill Refinements: Teams, Inline Builders, Squash Merge & Cleanup

## Goal
Refine the build skill's execution model to use inline builders for small/same-category tasks, Claude Code Teams for large/multi-topic parallel work, squash merge for clean history, and auto-cleanup for worktree hygiene.

## Problem Statement
The current build skill creates a worktree for every builder agent dispatch, even for single-line changes. This produced 16 stale worktrees in a single sprint. The worktree-per-builder approach adds unnecessary overhead for small tasks, creates merge complexity, and leaves worktrees/branches uncleaned. Additionally, the setup skill doesn't configure the experimental Teams feature that enables parallel execution.

## Users & Stakeholders
- **Robro plugin users**: Developers using `/robro:build` to implement plans. They benefit from faster builds (inline for small tasks), cleaner git history (squash merge), and no worktree accumulation (auto-cleanup).
- **Robro plugin maintainers**: The build skill becomes simpler — three clear execution paths instead of worktree-for-everything.

## Requirements

### Must Have
- Builder agent works inline (no worktree) — remove `isolation: worktree` from builder.md frontmatter
- Inline builders can run in parallel (multiple Agent tool dispatches) for same-category, small-volume tasks with no cap on count
- Claude Code Teams handle large changes or multi-topic parallel work (max 5 teammates per team)
- Decision trigger in brief phase: same-category + small changes → inline parallel; file overlap or larger scope → isolated parallel; multiple topics → Teams with non-overlapping file sets
- Squash merge from worktree/team branches (`git merge --squash` + explicit `git commit`) replaces `git merge --no-ff`
- Auto-cleanup worktrees (`git worktree remove`) and branches (`git branch -D`) immediately after each squash merge
- Setup skill enables `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` in `.claude/settings.json` env block

### Should Have
- (none identified)

### Won't Have (Non-goals)
- Backward-compatible worktree builder fallback — no legacy path
- Manual cleanup commands or on-demand cleanup skill
- File-overlap heuristic for inline-vs-Teams decision (conflict-resolver agent handles conflicts if they occur)
- Hard cap on inline subagent count
- `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` env var — not found in official docs, dropped during spec

## Constraints
- `isolation: worktree` in agent frontmatter forces worktree on every dispatch — use the Agent tool's dispatch-time `isolation` parameter for dynamic per-dispatch choice instead
- Claude Code Teams require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json env block (experimental feature)
- Teams have limitations: no session resume, task status lag, slow shutdown, one team per session, no nested teams
- Squash merge means branches aren't recognized as merged by git — requires `git branch -D` (force delete) instead of `git branch -d`
- `.claude/settings.json` may not exist yet in target projects — setup skill must handle creation and update

## Success Criteria
1. `builder.md` has no `isolation: worktree` in frontmatter — builders work inline
2. Build skill dispatches multiple inline builders in parallel (via Agent tool) when tasks are same-category and small-volume — no cap on count
3. Build skill creates a Team (via `TeamCreate`, max 5 teammates) when tasks involve large changes or span multiple topics
4. All worktree merges use `git merge --squash` + explicit commit — no `--no-ff`
5. After each squash merge: `git worktree remove` + `git branch -D` runs immediately
6. Setup skill creates/updates `.claude/settings.json` with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` in the `env` block

## Proposed Approach
Surgical edits to existing files. Targeted modifications to:
- `agents/builder.md` — remove `isolation: worktree` from frontmatter
- `skills/build/heads-down-phase.md` — rewrite parallel execution to use inline builders (same-category/small) vs Teams (large/multi-topic); update merge logic to squash + cleanup
- `skills/build/SKILL.md` — update heads-down summary to reflect new execution model
- `skills/setup/SKILL.md` — add step to create/update `.claude/settings.json` with env vars
- Minimal diff, preserves existing structure, low risk of regressions.

## Assumptions Exposed
| Assumption | Status | Resolution |
| --- | --- | --- |
| `isolation: worktree` can be toggled per-dispatch | Verified | Spec phase discovered the Agent tool accepts isolation as a dispatch-time parameter. Frontmatter removed; dynamic dispatch enables 3-path model. |
| Teams are stable enough for production use | Verified | Experimental but functional. Setup skill ensures the flag is set. |
| 3 teammates is the right default | Challenged | User chose 5 to maximize parallelism. |
| Task count alone determines inline vs Teams | Challenged | User refined: it's about change volume and topic diversity, not count. |
| Auto-cleanup risks losing diagnostic data | Challenged (Contrarian) | build-progress.md provides the audit trail. Auto-cleanup is safe. |
| Parallel inline agents don't need worktree | Verified | Same-category small changes are unlikely to conflict. Conflict-resolver is the safety net. |

## Context
- **Existing codebase**: Robro plugin with `agents/builder.md` (has `isolation: worktree`), `skills/build/` (6 phase files), `skills/setup/SKILL.md`
- **Reference patterns**: OMC uses Teams + Ultrawork subagents (3 teammates). Ouroboros uses Agent SDK sessions with post-hoc conflict detection. Neither uses worktrees for parallel execution.
- **Current state**: 16 stale worktrees from the last build sprint. All merges used `git merge --no-ff`.
- **Tech**: Claude Code plugin system, Agent tool with `isolation: worktree` frontmatter, experimental Teams API (`TeamCreate`, `TaskCreate`, `SendMessage`)

## Open Questions
- (none — all threads resolved, ambiguity ≤ 0.1)

## Key Research Findings
- `isolation: worktree` in agent frontmatter forces worktree on every dispatch; however, the Agent tool also accepts `isolation` as a dispatch-time parameter for dynamic per-dispatch choice
- Claude Code Teams require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json` env block
- Teams provide `TeamCreate`, `TaskCreate`, `SendMessage`, `TaskUpdate` tools; max one team per session; no nested teams
- OMC (oh-my-claudecode) v4.1.7+ uses Teams as canonical orchestration with Ultrawork engine — does NOT use worktrees for parallel execution
- Ouroboros uses Agent SDK sessions with anyio task groups for parallelism — post-hoc conflict detection, no worktrees or Teams
- Squash merge (`git merge --squash`) collapses all branch commits into one; branch not recognized as merged (requires `git branch -D`)
