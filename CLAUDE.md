# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

Robro is a Claude Code plugin that transforms a simple agent into your project companion. It extends Claude Code with custom skills, agents, hooks, and MCP servers.

## Design Philosophy

Robro's planning pipeline prioritizes thoroughness over speed. The goal: collect information exhaustively, review iteratively until confident, and produce plans solid enough for autonomous execution.

**Core principles** (learned from oh-my-claudecode, ouroboros, superpowers):

- **Skills own interaction; agents are workers.** Only skills can use AskUserQuestion. Agents receive context, do analysis, return structured output. Never create an agent that needs to ask the user anything.
- **Quality-driven iteration, not arbitrary caps.** Review loops exit on passing verdicts, not round counts. Every 3 iterations, check in with the user. Never silently give up.
- **Status.yaml drives hooks.** All skills persist their position to `status.yaml` at plan root (`docs/plans/*/status.yaml`). Hooks read it and inject focused "you are HERE, do THIS next" — not a rules dump.
- **Skills get compressed. Hooks don't.** As context grows, Claude compresses skill instructions. Hooks fire fresh every time. Critical guardrails live in hooks + on-disk state files.
- **Challenge modes are inline lenses.** Read the agent file, adopt that analytical perspective, apply it to current state. Only escalate to a subagent when inline analysis is insufficient.
- **Structured agent status protocol.** All agents return `DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED`. The orchestrating skill routes on status before processing output.

### Reference Plugins

These plugins shaped robro's architecture. Consult them when designing new skills or hooks:

- **oh-my-claudecode** (`nicobailon/oh-my-claudecode`) — External state file pattern (`.omc/state/` → our `status.yaml` at plan root). Hooks read state files to inject focused guidance that survives context compression. Also: inline challenge lens pattern (read agent file, adopt that analytical perspective in-place instead of spawning a subagent).
- **ouroboros** (`dnakov/ouroboros`) — Iterative review loops with strong hook guardrails. The "ralph loop" pattern: plan → review → revise → re-review until quality passes. Influenced our quality-driven iteration policy and the principle that hooks must keep the agent on track across long sessions.
- **superpowers** (`anthropics/claude-code-superpowers`) — Structured status protocol for agent dispatch (`DONE | NEEDS_CONTEXT | BLOCKED`). Clean separation of skill orchestration vs agent execution. Influenced our agent status routing and the skill-as-orchestrator pattern.

### Pipeline Flow

```
/robro:idea (PM) ──→ idea.md ──→ /robro:spec (EM) ──→ plan.md + spec.yaml ──→ /robro:build (Builder) ──→ working code
```

The planning phase is the foundation. No code gets written until idea.md has ambiguity ≤ 0.2, plan.md passes automated review, and spec.yaml cross-validates against both.

## Plugin Configuration

The plugin manifest lives at `.claude-plugin/plugin.json`. This is the only file that belongs inside `.claude-plugin/` — all other directories (skills, agents, commands, hooks) go at the plugin root.

### plugin.json Schema

```json
{
  "name": "robro",                          // Required. Unique ID, used as skill namespace (e.g. /robro:skill-name)
  "description": "...",                     // Shown in plugin manager
  "version": "1.0.0",                      // Semver. Bump to trigger updates for installed users
  "author": { "name": "", "email": "", "url": "" },
  "homepage": "https://...",
  "repository": "https://...",
  "license": "MIT",
  "keywords": ["tag1", "tag2"],
  // Component path overrides (supplement defaults, don't replace):
  "commands": "./custom/commands/",         // string | array
  "agents": "./custom/agents/",            // string | array
  "skills": "./custom/skills/",            // string | array
  "hooks": "./config/hooks.json",          // string | array | inline object
  "mcpServers": "./mcp-config.json",       // string | array | inline object
  "lspServers": "./.lsp.json",             // string | array | inline object
  "outputStyles": "./styles/"              // string | array
}
```

### Directory Structure

```
robro/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest (only this goes here)
├── skills/                  # Agent skills (name/SKILL.md structure)
│   ├── idea/SKILL.md        # PM: Socratic interview → idea.md
│   ├── spec/SKILL.md        # EM: Technical spec → plan.md + spec.yaml
│   └── build/SKILL.md       # Builder: evolutionary sprint execution
│       ├── brief-phase.md
│       ├── heads-down-phase.md
│       ├── review-phase.md
│       ├── retro-phase.md
│       ├── level-up-phase.md
│       └── converge-phase.md
├── agents/                  # Subagent markdown definitions
│   ├── researcher.md        # Web + codebase exploration (idea, spec)
│   ├── architect.md         # Technical review (spec)
│   ├── critic.md            # Ambiguity scoring & gap analysis (idea, spec)
│   ├── planner.md           # Task breakdown (spec)
│   ├── contrarian.md        # Challenges assumptions (idea, round 4+)
│   ├── simplifier.md        # YAGNI simplification (idea, round 6+)
│   ├── ontologist.md        # Deep reframing (idea, round 8+)
│   ├── builder.md           # Code execution in worktree isolation (build)
│   ├── reviewer.md          # 3-stage peer review (build)
│   ├── retro-analyst.md     # Structured retro report (build)
│   └── conflict-resolver.md # Merge conflict resolution (build)
├── hooks/
│   └── hooks.json           # Event handler config
├── scripts/                 # Hook shell scripts
│   ├── session-start.sh     # Inject pipeline state + skill awareness on session start
│   ├── keyword-detector.sh  # Detect idea/spec/build keywords in prompts
│   ├── pipeline-guard.sh    # Re-inject planning rules on every prompt (survives compression)
│   ├── spec-gate.sh         # Warn on Write/Edit without a spec + build scope check
│   ├── drift-monitor.sh     # Track progress against active spec + build sprint context
│   ├── pre-compact.sh       # Persist pipeline state before context compression
│   ├── stop-hook.sh         # Auto-continue build execution with circuit breakers
│   └── error-tracker.sh     # Track recent errors for rate limit detection
└── docs/plans/              # Generated plan artifacts (per project)
    └── YYMMDD_{name}/
        ├── idea.md           # Product requirements (from /robro:idea)
        ├── plan.md           # Implementation phases (from /robro:spec)
        ├── spec.yaml         # Validation checklist (from /robro:spec)
        ├── research/         # Temporal: web/codebase findings (gitignored)
        └── discussion/       # Temporal: interview logs, agent deliberation (gitignored)
```

### Core Skills

- **`/robro:idea`** — Product Manager role. Socratic interview that transforms vague thoughts into structured product requirements (`idea.md`). Uses ambiguity scoring with a ≤ 0.2 threshold gate.
- **`/robro:spec`** — Engineering Manager role. Converts `idea.md` into a technical implementation plan (`plan.md`) and validation checklist (`spec.yaml`). Multi-agent review loop ensures technical soundness.
- **`/robro:build`** — Builder role. Autonomously implements plan.md through evolutionary sprint cycles (Brief, Heads-down, Review, Retro, Level-up). Uses stop hook auto-continue for multi-session chaining. Produces working code with all spec.yaml items flipped to `passes: true`.

### Plan Artifacts

Each plan lives in `docs/plans/YYMMDD_{name}/`:
- **`idea.md`** — Markdown + YAML frontmatter. Product requirements, constraints, success criteria.
- **`plan.md`** — Markdown + YAML frontmatter. Phased task breakdown with dependency ordering and parallel execution.
- **`spec.yaml`** — Pure YAML. Validation source of truth. Checklist items with `passes: false/true` flags. All tests and verification derive from this file. Items can never be removed — only `passes` can be flipped.
- **`research/`** — Gitignored. Temporal web/codebase findings gathered during interviews.
- **`discussion/`** — Gitignored. Interview transcripts, agent deliberation logs.
- **`spec-mutations.log`** — Append-only event log at plan root (alongside spec.yaml). Records every spec.yaml mutation with timestamp, sprint, operation (ADD/SUPERSEDE), item path, and rationale. Committed to git for audit trail.
- **`status.yaml`** — At plan root (not discussion/). Gitignored. Tracks full lifecycle state (idea/spec/build). Drives hook injection and cross-session resume.
- **`build-progress.md`** — In discussion/. Append-only implementation log with learnings, patterns, failures. Injected into agent context on session resume.
- **`*.bak.*`** — Gitignored. Previous versions preserved before overwrites.

### Spec Mutation Rules (Build Phase)

During `/robro:build`, spec.yaml evolves through restricted mutations:

- **ADD**: New checklist item with `passes: false`. Must reference an existing section.
- **SUPERSEDE**: Mark an item as superseded. Original text preserved. Add `status: superseded` and `superseded_by: CXX` fields. Superseded items are excluded from completeness gate.
- **FLIP**: Toggle `passes` from `false` to `true` (or `true` to `false` on regression).
- **No in-place modification**: Item descriptions and acceptance criteria cannot be edited. To change an item, supersede it and add a replacement.

Every mutation is logged to `spec-mutations.log` in tab-separated format:
```
{ISO-timestamp}\tSPRINT:{N}\t{ADD|SUPERSEDE|FLIP}\t{item-path}\t{value}\tREASON: {rationale}
```

The immutability rule from `/robro:spec` (items can never be removed or edited) is refined for build: items can be superseded (preserving the original) but never deleted or silently modified.

### Key Concepts

- **Skills** (`skills/<name>/SKILL.md`): Model-invoked capabilities. Claude auto-uses them based on task context. Invoked as `/robro:<skill-name>`.
- **Agents** (`agents/*.md`): Subagents with frontmatter (`name`, `description`) and a system prompt body.
- **Hooks** (`hooks/hooks.json`): Event handlers for `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, etc. Types: `command`, `prompt`, `agent`.
- **`${CLAUDE_PLUGIN_ROOT}`**: Environment variable resolving to plugin install path. Use in hooks, MCP configs, and scripts.

### Testing

```bash
# Load plugin locally for development
claude --plugin-dir .

# Load multiple plugins
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two

# Reload after changes (inside Claude Code TUI)
/reload-plugins

# Debug plugin loading issues
claude --debug
```

### Distribution

- Version with semver. Users won't see changes unless version is bumped.
- Submit to official marketplace at claude.ai/settings/plugins/submit or platform.claude.com/plugins/submit.
- Install scopes: `user` (default, global), `project` (shared via VCS), `local` (gitignored).
