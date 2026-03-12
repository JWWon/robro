# robro

Your project companion -- a Claude Code plugin that transforms a simple agent into a structured planning and execution partner.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Why robro?

Claude Code is powerful, but on complex tasks it tends to jump straight into code -- skipping requirements gathering, writing without a plan, and losing context in long sessions. You end up steering manually, re-explaining constraints, and catching scope drift.

Robro fixes this by adding structure where it matters most: **before code gets written**. It gives Claude three distinct roles -- a PM who interviews you, an EM who plans the work, and a Builder who executes autonomously -- so you get disciplined execution without micromanaging.

## What is robro?

Robro (robot + bro) is a Claude Code plugin built around the coworker vibe -- it's a companion, not a tool. It extends Claude Code with structured skills, agents, and hooks that turn vague ideas into shipped code through a disciplined planning and execution pipeline.

Think of it as having a PM, an EM, and a Builder on your team -- each with their own role, working together to take your project from "I have an idea" to "here's the working code."

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed and configured
- A project repository (robro stores plan artifacts in `docs/plans/`)

## Pipeline Overview

Robro operates through a 3-stage pipeline, each driven by a dedicated skill:

```
/robro:idea (PM) --> idea.md --> /robro:spec (EM) --> plan.md + spec.yaml --> /robro:build (Builder) --> working code
```

| Stage | Role | Input | Output |
|-------|------|-------|--------|
| **Idea** | Product Manager | Your rough idea | `idea.md` -- structured requirements with ambiguity scoring |
| **Spec** | Engineering Manager | `idea.md` | `plan.md` + `spec.yaml` -- phased implementation plan with validation checklist |
| **Build** | Builder | `plan.md` + `spec.yaml` | Working code -- autonomous sprint execution with TDD |

The planning phase is the foundation. No code gets written until the idea has low ambiguity, the plan passes automated review, and the spec cross-validates against both.

## Skills

| Skill | Role | Description |
|-------|------|-------------|
| `/robro:idea` | Product Manager | Socratic interview that transforms vague thoughts into structured product requirements (`idea.md`). Uses ambiguity scoring to gate progression. |
| `/robro:spec` | Engineering Manager | Converts `idea.md` into a technical implementation plan (`plan.md`) and validation checklist (`spec.yaml`). Multi-agent review loop ensures technical soundness. |
| `/robro:build` | Builder | Autonomously implements `plan.md` through evolutionary sprint cycles (Brief, Heads-down, Review, Retro, Level-up). Produces working code with all spec items verified. |
| `/robro:setup` | Configuration | Configures your project for robro: sets up CLAUDE.md sections, MCP/skill checklist, and `.gitignore` entries. |
| `/robro:clean-memory` | Cleanup | Cross-plan analysis of completed plans and deletion of stale artifacts. Keeps your `docs/plans/` directory tidy. |

## Installation

### From GitHub

```bash
# Clone the repository
git clone https://github.com/JWWon/robro.git

# Load the plugin from the cloned directory
claude --plugin-dir /path/to/robro
```

### For development

```bash
# Load the plugin from the repo directory
claude --plugin-dir .

# Debug loading issues
claude --debug

# Reload after changes (inside Claude Code TUI)
/reload-plugins
```

## Quick Start

1. **Configure your project** -- Run `/robro:setup` to set up CLAUDE.md, .gitignore, and other project scaffolding.
2. **Describe what you want to build** -- Have an idea? Just start talking about it.
3. **Gather requirements** -- Run `/robro:idea` for a structured Socratic interview that refines your idea into clear requirements.
4. **Plan the implementation** -- Run `/robro:spec` to turn requirements into a phased technical plan with a validation checklist.
5. **Build autonomously** -- Run `/robro:build` to execute the plan through TDD sprint cycles until all spec items pass.

## How It Works

### Architecture

Robro follows a core design principle: **skills orchestrate, agents execute**. Skills handle user interaction and decision-making. Agents are dispatched as workers that receive context, perform analysis, and return structured output.

```
Skills (user-facing)          Agents (workers)
--------------------          ----------------
/robro:idea  ───────────────> Researcher, Critic, Contrarian, Simplifier, Ontologist
/robro:spec  ───────────────> Researcher, Architect, Critic, Planner
/robro:build ───────────────> Builder, Reviewer, Retro Analyst, Conflict Resolver
```

### Hooks keep the agent on track

As conversations grow long, Claude compresses earlier messages -- including skill instructions. Robro uses **hooks** that fire fresh on every event, reading on-disk state (`status.yaml`) to inject focused guidance:

- **Pipeline guard** -- Re-injects planning rules every prompt so the agent never forgets its current phase
- **Spec gate** -- Warns if code is being written without an approved spec
- **Drift monitor** -- Tracks progress against the active spec during implementation
- **Stop hook** -- Auto-continues build execution across context limits with circuit breakers

### Plan artifacts

Each plan lives in `docs/plans/YYMMDD_{name}/`:

| File | Purpose |
|------|---------|
| `idea.md` | Product requirements, constraints, success criteria |
| `plan.md` | Phased task breakdown with dependency ordering |
| `spec.yaml` | Validation checklist -- the source of truth for what "done" means |
| `status.yaml` | Execution state (gitignored) |

### Quality gates

- **Ambiguity scoring** -- Ideas must reach an ambiguity score of 0.1 or below before spec work begins
- **Multi-agent review** -- Plans are reviewed by Architect and Critic agents in iterative loops until they pass
- **Spec immutability** -- During build, checklist items can never be deleted or silently modified. Changes use ADD or SUPERSEDE operations, logged to an append-only audit trail
- **3-stage peer review** -- Build output goes through mechanical checks, semantic review, and multi-agent consensus

## Credits

Robro's architecture was shaped by these excellent Claude Code plugins:

- **[oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)** -- External state file pattern, CLAUDE.md management, and inline challenge lenses. The approach of hooks reading on-disk state to inject focused guidance that survives context compression came directly from this project.
- **[ouroboros](https://github.com/Q00/ouroboros)** -- Iterative review loops with strong hook guardrails. The "plan, review, revise, re-review until quality passes" pattern and the principle that hooks must keep the agent on track across long sessions were both inspired by ouroboros.
- **[superpowers](https://github.com/obra/superpowers)** -- Structured agent status protocol (`DONE | NEEDS_CONTEXT | BLOCKED`) and clean separation of skill orchestration vs agent execution. The skill-as-orchestrator pattern at robro's core follows this model.

## License

MIT -- see [LICENSE](LICENSE) file.
