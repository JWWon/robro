# robro

Your project companion -- a Claude Code plugin that transforms a simple agent into a structured planning and execution partner.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## What is robro?

Robro (robot + bro) is a Claude Code plugin built around the coworker vibe -- it's a companion, not a tool. It extends Claude Code with structured skills, agents, and hooks that turn vague ideas into shipped code through a disciplined planning and execution pipeline.

Think of it as having a PM, an EM, and a Builder on your team -- each with their own role, working together to take your project from "I have an idea" to "here's the working code."

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

Install from the Claude Code plugin marketplace:

```bash
claude plugin install robro
```

For local development:

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

## Credits

Robro's architecture was shaped by these excellent Claude Code plugins:

- **[oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)** -- External state file pattern, CLAUDE.md management, and inline challenge lenses. The approach of hooks reading on-disk state to inject focused guidance that survives context compression came directly from this project.
- **[ouroboros](https://github.com/Q00/ouroboros)** -- Iterative review loops with strong hook guardrails. The "plan, review, revise, re-review until quality passes" pattern and the principle that hooks must keep the agent on track across long sessions were both inspired by ouroboros.
- **[superpowers](https://github.com/obra/superpowers)** -- Structured agent status protocol (`DONE | NEEDS_CONTEXT | BLOCKED`) and clean separation of skill orchestration vs agent execution. The skill-as-orchestrator pattern at robro's core follows this model.

## License

MIT -- see [LICENSE](LICENSE) file.
