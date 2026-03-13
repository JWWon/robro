# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Workflow

```bash
# Test the plugin during development
claude --plugin-dir .

# Debug loading issues
claude --debug
```

After making changes to skills, commands, agents, or hooks, run `/reload-plugins` inside the TUI to pick up updates. LSP server config changes require a full restart.

## Architecture Rules

- `.claude-plugin/` contains `plugin.json` and `marketplace.json`. Never put commands, agents, skills, or hooks inside it.
- All component paths in `plugin.json` must be relative and start with `./`.
- Hook scripts must be executable (`chmod +x`) and use `${CLAUDE_PLUGIN_ROOT}` for paths.
- Hooks receive input as JSON on stdin — use `jq` to extract fields.
- Installed plugins are cached at `~/.claude/plugins/cache`. Paths that traverse outside the plugin root (`../`) won't resolve after installation.
- If the plugin needs external files, symlink them into the plugin directory (symlinks are honored during cache copy).

## Skill Authoring

Skills use `skills/<name>/SKILL.md` with frontmatter:

```yaml
---
name: skill-name
description: When and why Claude should use this skill
---
```

- `$ARGUMENTS` placeholder captures user input after the skill name.
- Skills can include supporting files (scripts, references) alongside SKILL.md.
- `disable-model-invocation: true` in frontmatter makes a skill user-only (not auto-invoked).

## Agent Authoring

Agents use `agents/<name>.md` with frontmatter:

```yaml
---
name: agent-name
description: What this agent does and when to invoke it
---
```

The body is the agent's system prompt. Agents appear in `/agents` and can be auto-invoked by Claude.

## Hook Events

Available events (case-sensitive): `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `UserPromptSubmit`, `Notification`, `Stop`, `SubagentStart`, `SubagentStop`, `SessionStart`, `SessionEnd`, `TeammateIdle`, `TaskCompleted`, `PreCompact`.

Hook types: `command` (shell), `prompt` (LLM eval), `agent` (agentic verifier).

<!-- robro:managed:start [0.1.0] -->
## Robro Plugin

Robro extends Claude Code with a structured planning and execution pipeline.

### Pipeline

```
/robro:idea (PM) → idea.md → /robro:plan (EM) → plan.md + spec.yaml → /robro:do (Builder) → working code
```

### Available Skills

| Skill | Role | Description |
|-------|------|-------------|
| `/robro:idea` | Product Manager | Socratic interview that transforms vague ideas into structured requirements (idea.md). Uses ambiguity scoring with ≤ 0.1 threshold. |
| `/robro:plan` | Engineering Manager | Converts idea.md into phased implementation plan (plan.md) and validation checklist (spec.yaml). Multi-agent review loop. |
| `/robro:do` | Builder | Autonomously implements plan.md through evolutionary sprint cycles. Dispatches builder agents, runs peer review, evolves project knowledge. |
| `/robro:setup` | Setup | Configures project for robro: CLAUDE.md section, MCP/skill recommendations, .gitignore rules. |
| `/robro:tune` | Configuration | Audits and optimizes project Claude Code configuration (agents, skills, rules, CLAUDE.md, MCPs). Codebase + git history analysis. |

### Plan Artifacts

Plans live in `docs/plans/YYMMDD_{name}/`:
- `idea.md` — Product requirements from /robro:idea
- `plan.md` — Phased implementation tasks from /robro:plan
- `spec.yaml` — Validation checklist (source of truth for testing)
- `status.yaml` — Pipeline state (drives hooks, gitignored)
- `spec-mutations.log` — Append-only audit trail for spec changes during build

### Worktree Workflow

Each plan cycle uses a git worktree for branch isolation. `/robro:idea` works on main (no commits). `/robro:plan` creates a worktree at `.claude/worktrees/{slug}/` and works on branch `plan/{slug}`. `/robro:do` works inside the worktree, committing freely. The converge phase squash-merges to main -- one clean commit per plan cycle. On session start, `session-start.sh` detects active worktrees and prompts re-entry.

### Key Rules

- **Skills orchestrate, agents execute.** Only skills interact with the user. Agents receive context, do work, return structured output.
- **No code without a spec.** Implementation requires plan.md + spec.yaml.
- **Status.yaml drives hooks.** All pipeline state is persisted to status.yaml at plan root.
- **Quality-driven iteration.** Review loops exit on passing verdicts, not arbitrary caps.
- **Spec immutability during build.** Checklist items can never be deleted or silently modified. Changes use ADD or SUPERSEDE operations, logged to spec-mutations.log.

### Agent Dispatch

- Always check the agent's **Status** field first (`DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, `BLOCKED`) before processing output.
- `NEEDS_CONTEXT` → provide missing info and re-dispatch. `BLOCKED` → fix or escalate to user.
- Critic verdicts (PASS/ACCEPT_WITH_RESERVATIONS/NEEDS_WORK/REJECT) are separate from status.
- Challenge agents (contrarian, simplifier, ontologist) are applied as inline lenses first. Only dispatch as subagent for deep investigation.

### Iteration Policy

**Planning (/robro:idea, /robro:plan):** No arbitrary iteration caps. Loops exit on passing verdicts from both Architect and Critic. Every 3 iterations, check in with the user. Never silently give up.

**Build (/robro:do):** Fully autonomous — no user check-ins during execution. Sprint hard cap: 30. Stop hook reinforcement cap: 50 per session. Circuit breakers: rate limit (429), high reinforcement count.

Spec.yaml checklist items during build use restricted mutation: ADD or SUPERSEDE only, never in-place modification. Every mutation logged to spec-mutations.log.

### Hooks

Robro hooks fire fresh on every event to inject focused guidance that survives context compression. The injection pattern is "you are HERE, do THIS next" — not a rules dump.

| Event | Purpose |
|-------|---------|
| SessionStart | Detect active pipeline phase, restore state for resume; detect active worktrees and prompt re-entry |
| UserPromptSubmit | Detect keywords → suggest skills; re-inject planning rules every prompt |
| PreToolUse (Write/Edit) | Warn if writing code without an approved spec |
| PostToolUse (Write/Edit) | Track progress against active spec during implementation |
| PreCompact | Persist pipeline state before context compression |
| Stop | Auto-continue do execution with circuit breakers |
| PostToolUseFailure | Track recent errors for rate limit detection |

### Build Agents

| Agent | Role |
|-------|------|
| Builder | TDD task execution (inline or worktree-isolated) |
| Reviewer | 3-stage peer review (mechanical → semantic → consensus) |
| Retro Analyst | Structured sprint retrospective |
| Conflict Resolver | Merge conflict resolution from parallel dispatches |
| Researcher | Context gathering and JIT knowledge |
| Architect | Semantic review |
| Critic | Consensus gate |

### Ambiguity Scoring

Used by idea and plan skills to gate progression:

| Dimension | Weight |
|-----------|--------|
| Goal Clarity | 35% |
| Constraint Clarity | 25% |
| Success Criteria | 25% |
| Context Clarity | 15% |

Threshold: ambiguity ≤ 0.1 (formula: `1 - weighted_sum`).

### Resuming Interrupted Work

If a pipeline was interrupted, robro auto-detects the state on session start. Check `status.yaml` in the active plan directory for current position.
<!-- robro:managed:end -->
