## Robro Plugin

Robro extends Claude Code with a structured planning and execution pipeline.

### Pipeline

```
/robro:idea (PM) → idea.md → /robro:spec (EM) → plan.md + spec.yaml → /robro:build (Builder) → working code
```

### Available Skills

| Skill | Role | Description |
|-------|------|-------------|
| `/robro:idea` | Product Manager | Socratic interview that transforms vague ideas into structured requirements (idea.md). Uses ambiguity scoring with ≤ 0.1 threshold. |
| `/robro:spec` | Engineering Manager | Converts idea.md into phased implementation plan (plan.md) and validation checklist (spec.yaml). Multi-agent review loop. |
| `/robro:build` | Builder | Autonomously implements plan.md through evolutionary sprint cycles. Dispatches builder agents, runs peer review, evolves project knowledge. |
| `/robro:setup` | Setup | Configures project for robro: CLAUDE.md section, MCP/skill recommendations, .gitignore rules. |
| `/robro:clean-memory` | Cleanup | Analyzes completed plans for patterns, recommends improvements, then deletes confirmed plans. |
| `/robro:tune` | Configuration | Audits and optimizes project Claude Code configuration (agents, skills, rules, CLAUDE.md, MCPs). Codebase + git history analysis. |

### Plan Artifacts

Plans live in `docs/plans/YYMMDD_{name}/`:
- `idea.md` — Product requirements from /robro:idea
- `plan.md` — Phased implementation tasks from /robro:spec
- `spec.yaml` — Validation checklist (source of truth for testing)
- `status.yaml` — Pipeline state (drives hooks, gitignored)
- `spec-mutations.log` — Append-only audit trail for spec changes during build

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

**Planning (/robro:idea, /robro:spec):** No arbitrary iteration caps. Loops exit on passing verdicts from both Architect and Critic. Every 3 iterations, check in with the user. Never silently give up.

**Build (/robro:build):** Fully autonomous — no user check-ins during execution. Sprint hard cap: 30. Stop hook reinforcement cap: 50 per session. Circuit breakers: rate limit (429), high reinforcement count.

Spec.yaml checklist items during build use restricted mutation: ADD or SUPERSEDE only, never in-place modification. Every mutation logged to spec-mutations.log.

### Hooks

Robro hooks fire fresh on every event to inject focused guidance that survives context compression. The injection pattern is "you are HERE, do THIS next" — not a rules dump.

| Event | Purpose |
|-------|---------|
| SessionStart | Detect active pipeline phase, restore state for resume |
| UserPromptSubmit | Detect keywords → suggest skills; re-inject planning rules every prompt |
| PreToolUse (Write/Edit) | Warn if writing code without an approved spec |
| PostToolUse (Write/Edit) | Track progress against active spec during implementation |
| PreCompact | Persist pipeline state before context compression |
| Stop | Auto-continue build execution with circuit breakers |
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

Used by idea and spec skills to gate progression:

| Dimension | Weight |
|-----------|--------|
| Goal Clarity | 35% |
| Constraint Clarity | 25% |
| Success Criteria | 25% |
| Context Clarity | 15% |

Threshold: ambiguity ≤ 0.1 (formula: `1 - weighted_sum`).

### Resuming Interrupted Work

If a pipeline was interrupted, robro auto-detects the state on session start. Check `status.yaml` in the active plan directory for current position.
