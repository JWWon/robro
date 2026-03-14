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

Plans live in `.robro/sessions/YYMMDD_{name}/`:
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
| PostToolUse (Write/Edit) | Oscillation detection — tracks same-file edit counts and warns when cycles suggest the approach needs a lateral shift |
| UserPromptSubmit | Skill injection — loads learned skills from `.robro/skills/` matching prompt keywords into the active session |
| SessionStart | Update check — notifies when a newer robro version is available (cached to `~/.robro/.update-cache.json`) |
| SubagentStop | Deliverable verification — advisory check that subagent output includes the standard Status protocol line |

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
| Wonder | Exploratory insight agent — surfaces unexpected connections and reframes problems from novel angles |

### Ambiguity Scoring

Used by idea and plan skills to gate progression.

**Greenfield** (no existing codebase): Goal 40%, Constraints 30%, Criteria 30%.
**Brownfield** (existing codebase): Goal 35%, Constraints 25%, Criteria 25%, Context 15%.

Threshold: ambiguity ≤ 0.1 (formula: `1 - weighted_sum`).

### Learned Skills (v0.2.0+)

Robro supports project-specific learned skills stored in `.robro/skills/`. During build cycles, the retro phase can extract reusable patterns and save them as skill files. These are automatically indexed (`.robro/.skill-index.json`) and injected into future sessions.

Customization follows a 4-tier hierarchy (highest priority first):

1. **Session overrides** — per-session status.yaml directives
2. **Project config** — `.robro/config.json` settings
3. **Learned skills** — `.robro/skills/` discovered patterns
4. **Plugin defaults** — built-in robro configuration

### Resuming Interrupted Work

If a pipeline was interrupted, robro auto-detects the state on session start. Check `status.yaml` in the active plan directory for current position.
