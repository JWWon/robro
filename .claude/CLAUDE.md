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

- `.claude-plugin/` contains **only** `plugin.json`. Never put commands, agents, skills, or hooks inside it.
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

## Agent Dispatch Rules

- Skills orchestrate. Agents execute. Never give an agent user-facing interaction (AskUserQuestion).
- Always check the agent's **Status** field first (`DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, `BLOCKED`) before processing output.
- `NEEDS_CONTEXT` → provide missing info and re-dispatch. `BLOCKED` → fix or escalate to user.
- Critic verdicts (PASS/ACCEPT_WITH_RESERVATIONS/NEEDS_WORK/REJECT) are separate from status — a REJECT verdict still has status DONE.
- Challenge agents (contrarian, simplifier, ontologist) are applied as inline lenses first. Only dispatch as subagent for deep investigation.

## Iteration Policy

**Planning skills (idea, spec):** No arbitrary iteration caps. Loops exit only on passing verdicts from both Architect and Critic. Every 3 iterations, inform the user of progress and ask: continue, try different approach, or accept with noted concerns. Never silently give up.

**Build skill:** No user check-ins during autonomous execution. The user CAN intervene at any time but is never blocked on. Notifications deferred — user can check status.yaml or build-progress.md for current state. Sprint hard cap: 30. Stop hook reinforcement cap: 50 per session. Circuit breakers: bail on rate limit (429), bail on high reinforcement count + stop_hook_active flag.

Spec.yaml checklist items during build use restricted mutation: ADD or SUPERSEDE only, never in-place modification. Every mutation logged to spec-mutations.log.

## Active Hooks

| Event | Script | Purpose |
|-------|--------|---------|
| SessionStart | `session-start.sh` | Detect active pipeline phase, inject state + rules for resume |
| UserPromptSubmit | `keyword-detector.sh` | Detect idea/spec keywords, suggest skills |
| UserPromptSubmit | `pipeline-guard.sh` | Re-inject planning workflow rules every prompt (survives compression) |
| PreToolUse (Write\|Edit) | `spec-gate.sh` | Warn if writing source code without a spec |
| PostToolUse (Write\|Edit) | `drift-monitor.sh` | Show spec progress when actively implementing |
| PreCompact | `pre-compact.sh` | Remind agent to persist pipeline state before context compression |
| Stop | `stop-hook.sh` | Auto-continue build execution with circuit breakers |
| PostToolUseFailure | `error-tracker.sh` | Track recent errors for rate limit detection |

## Hook Design Principle

**Skills get compressed. Hooks don't.** As context grows, Claude compresses older messages — including skill instructions. Hooks fire fresh every time, regardless of context length. Critical planning rules live in hooks so they survive long sessions:
- `pipeline-guard.sh` reads `status.yaml` at plan root and injects focused state: current step, next action, exit gate
- `session-start.sh` restores full pipeline state on session resume
- `pre-compact.sh` ensures state is persisted before compression

**Injection pattern**: "You are HERE, do THIS next" — not a rules dump. The `next` field in status.yaml is written by the skill with full conversation context, so hooks inject precise guidance even after compression.

## Build Phase Agents

Four new agents support the build skill:
- **Builder** (`agents/builder.md`): Executes TDD tasks inline or in worktree isolation (determined at dispatch time via `isolation: "worktree"` parameter). Gets JIT knowledge + project rules context.
- **Reviewer** (`agents/reviewer.md`): Runs 3-stage peer review. Multi-agent consensus (Architect + Critic + Reviewer) replaces multi-model consensus.
- **Retro Analyst** (`agents/retro-analyst.md`): Produces structured retro report (Broken Assumptions, Emerged Patterns, Knowledge Gaps, Proposed Mutations, Proposed Level-ups).
- **Conflict Resolver** (`agents/conflict-resolver.md`): Resolves merge conflicts from squash merges of worktree-isolated agent dispatches. Understands intent from both sides.

Existing agents reused during build:
- **Researcher**: Sprint 1 pre-flight, Brief phase context gathering, JIT knowledge
- **Architect**: Semantic review stage
- **Critic**: Consensus gate stage

## Ambiguity Scoring Model

Used by the `idea` and `spec` skills to gate progression:

| Dimension | Weight |
|-----------|--------|
| Goal Clarity | 35% |
| Constraint Clarity | 25% |
| Success Criteria | 25% |
| Context Clarity | 15% |

Threshold: `ambiguity ≤ 0.1` to proceed. Formula: `ambiguity = 1 - weighted_sum`.
