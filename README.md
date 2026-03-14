# robro

**Your project companion** -- a Claude Code plugin that transforms a simple agent into a structured planning and execution partner.

> *AI can build anything. The hard part is knowing what to build.*

Robro (robot + bro) gives Claude three distinct roles -- a PM who interviews you, an EM who plans the work, and a Builder who executes autonomously. You get disciplined execution without micromanaging.

[Quick Start](#quick-start) · [Pipeline](#pipeline) · [Skills](#skills) · [How It Works](#how-it-works) · [Credits](#credits)

---

## Quick Start

**Step 1: Install**

```bash
claude plugin marketplace add JWWon/robro
claude plugin install robro@robro
```

Or inside the Claude Code TUI:

```
/plugin marketplace add JWWon/robro
/plugin install robro@robro
```

**Step 2: Setup**

```
/robro:setup
```

This configures your project's CLAUDE.md, recommends MCP servers and skills, and sets up .gitignore rules for plan artifacts.

**Step 3: Build something**

```
/robro:idea "I want to build a task management CLI"
```

That's it. Robro interviews you, plans the work, and builds it -- step by step.

<details>
<summary><strong>What just happened?</strong></summary>

```
/robro:idea   →  Socratic interview exposed hidden assumptions, produced idea.md
/robro:plan   →  Multi-agent review produced plan.md + spec.yaml
/robro:do     →  Autonomous TDD sprints until all spec items pass
```

No code was written until the idea had low ambiguity, the plan passed automated review, and the spec cross-validated against both.

</details>

---

## Why robro?

Claude Code is powerful, but on complex tasks it tends to jump straight into code -- skipping requirements gathering, writing without a plan, and losing context in long sessions. You end up steering manually, re-explaining constraints, and catching scope drift.

Robro fixes this by adding structure where it matters most: **before code gets written**. Think of it as having a PM, an EM, and a Builder on your team -- each with their own role, working together to take your project from "I have an idea" to "here's the working code."

---

## Pipeline

Robro operates through a 3-stage pipeline, each driven by a dedicated skill:

```
/robro:idea (PM) → idea.md → /robro:plan (EM) → plan.md + spec.yaml → /robro:do (Builder) → working code
```

| Stage | Role | Input | Output |
|-------|------|-------|--------|
| **Idea** | Product Manager | Your rough idea | `idea.md` -- structured requirements with ambiguity scoring |
| **Plan** | Engineering Manager | `idea.md` | `plan.md` + `spec.yaml` -- phased implementation plan with validation checklist |
| **Do** | Builder | `plan.md` + `spec.yaml` | Working code -- autonomous sprint execution with TDD |

The planning phase is the foundation. No code gets written until the idea has low ambiguity, the plan passes automated review, and the spec cross-validates against both.

Each plan cycle runs in a git worktree for branch isolation, producing exactly one squash-merge commit on main. See [Worktree isolation](#worktree-isolation) below.

---

## Skills

| Skill | Role | Description |
|-------|------|-------------|
| `/robro:idea` | Product Manager | Socratic interview that transforms vague thoughts into structured product requirements (`idea.md`). Uses ambiguity scoring to gate progression. |
| `/robro:plan` | Engineering Manager | Converts `idea.md` into a technical implementation plan (`plan.md`) and validation checklist (`spec.yaml`). Multi-agent review loop ensures technical soundness. |
| `/robro:do` | Builder | Autonomously implements `plan.md` through evolutionary sprint cycles (Brief, Heads-down, Review, Retro, Level-up). Produces working code with all spec items verified. |
| `/robro:setup` | Configuration | Configures your project for robro: sets up CLAUDE.md sections, MCP/skill checklist, and `.gitignore` entries. |
| `/robro:tune` | Configuration | Audits and optimizes project Claude Code configuration (agents, skills, rules, CLAUDE.md, MCPs) using codebase and git history analysis. |

---

## How It Works

### Architecture

Robro follows a core design principle: **skills orchestrate, agents execute**. Skills handle user interaction and decision-making. Agents are dispatched as workers that receive context, perform analysis, and return structured output.

```
Skills (user-facing)          Agents (workers)
--------------------          ----------------
/robro:idea  ───────────────> Researcher, Critic, Contrarian, Simplifier, Ontologist
/robro:plan  ───────────────> Researcher, Architect, Critic, Planner
/robro:do    ───────────────> Builder, Reviewer, Retro Analyst, Conflict Resolver
```

### Agents

Twelve agents, each with a specialized role. Loaded on-demand, never preloaded:

| Agent | Role | Used By |
|-------|------|---------|
| **Researcher** | Web and codebase exploration for context gathering | idea, plan, do |
| **Critic** | Ambiguity scoring, gap analysis, consensus gate | idea, plan, do |
| **Contrarian** | Challenges every assumption ("What if the opposite were true?") | idea |
| **Simplifier** | Removes complexity ("What's the simplest thing that could work?") | idea |
| **Ontologist** | Deep reframing ("What IS this, really?") | idea |
| **Architect** | Technical review and soundness verification | plan, do |
| **Planner** | Task breakdown with dependency ordering and parallel execution | plan |
| **Builder** | TDD task execution -- inline or worktree-isolated | do |
| **Reviewer** | 3-stage peer review: mechanical, semantic, consensus | do |
| **Retro Analyst** | Structured sprint retrospective with pattern extraction | do |
| **Conflict Resolver** | Merge conflict resolution from parallel dispatches | do |

Challenge agents (Contrarian, Simplifier, Ontologist) are applied as **inline lenses** first -- reading the agent's perspective and applying it in-place. Only escalated to a full subagent when deeper investigation is needed.

### Hooks

As conversations grow long, Claude compresses earlier messages -- including skill instructions. Robro uses **hooks** that fire fresh on every event, reading on-disk state (`status.yaml`) to inject focused guidance that survives context compression:

| Hook | Purpose |
|------|---------|
| **Pipeline guard** | Re-injects planning rules every prompt so the agent never forgets its current phase |
| **Spec gate** | Warns if code is being written without an approved spec |
| **Drift monitor** | Tracks progress against the active spec during implementation |
| **Stop hook** | Auto-continues do execution across context limits with circuit breakers |
| **Error tracker** | Monitors recent errors for rate limit detection |
| **Pre-compact** | Persists pipeline state before context compression |

The injection pattern is "you are HERE, do THIS next" -- not a rules dump.

### Plan artifacts

Each plan lives in `.robro/sessions/YYMMDD_{name}/`:

| File | Purpose |
|------|---------|
| `idea.md` | Product requirements, constraints, success criteria |
| `plan.md` | Phased task breakdown with dependency ordering |
| `spec.yaml` | Validation checklist -- the source of truth for what "done" means |
| `status.yaml` | Execution state (gitignored, drives hooks) |
| `spec-mutations.log` | Append-only audit trail for spec changes during build |

### Quality gates

- **Ambiguity scoring** -- Ideas must reach an ambiguity score of 0.1 or below before spec work begins. Scored across four weighted dimensions: Goal Clarity (35%), Constraint Clarity (25%), Success Criteria (25%), Context Clarity (15%).
- **Multi-agent review** -- Plans are reviewed by Architect and Critic agents in iterative loops until they pass. No arbitrary iteration caps -- loops exit on passing verdicts.
- **Spec immutability** -- During build, checklist items can never be deleted or silently modified. Changes use ADD or SUPERSEDE operations, logged to an append-only audit trail.
- **3-stage peer review** -- Build output goes through mechanical checks ($0 LLM cost), semantic review, and multi-agent consensus.

### Worktree isolation

Robro uses git worktrees to keep plan branches isolated from main:

1. `/robro:idea` works on **main** (creates plan directory, no commits)
2. `/robro:plan` creates a worktree at `.claude/worktrees/{slug}/` and works on branch `plan/{slug}`
3. `/robro:do` works inside the worktree, committing freely to the plan branch
4. The converge phase squash-merges to main after all gates pass

Result: exactly one clean commit per plan cycle on main. If a session starts while a worktree is active, robro auto-detects it and prompts re-entry.

---

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed and configured
- A project repository (robro stores plan artifacts in `.robro/sessions/`)

---

## Credits

Robro's architecture was shaped by these excellent Claude Code plugins:

- **[oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)** -- External state file pattern, CLAUDE.md management, and inline challenge lenses. The approach of hooks reading on-disk state to inject focused guidance that survives context compression came directly from this project.
- **[ouroboros](https://github.com/Q00/ouroboros)** -- Iterative review loops with strong hook guardrails. The "plan, review, revise, re-review until quality passes" pattern and the principle that hooks must keep the agent on track across long sessions were both inspired by ouroboros.
- **[superpowers](https://github.com/obra/superpowers)** -- Structured agent status protocol (`DONE | NEEDS_CONTEXT | BLOCKED`) and clean separation of skill orchestration vs agent execution. The skill-as-orchestrator pattern at robro's core follows this model.

---

## Development

```bash
# Load the plugin from a local directory
claude --plugin-dir /path/to/robro

# Debug loading issues
claude --debug

# Reload after changes (inside Claude Code TUI)
/reload-plugins
```

### Contributing

```bash
git clone https://github.com/JWWon/robro.git
cd robro
claude --plugin-dir .
```

[Issues](https://github.com/JWWon/robro/issues)

---

## License

MIT -- see [LICENSE](LICENSE) file.
