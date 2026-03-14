---
type: update
created: 2026-03-14T12:00:00+09:00
ambiguity_score: 0.09
status: ready
project_type: brownfield
dimensions:
  goal: 0.95
  constraints: 0.9
  criteria: 0.9
  context: 0.85
---

# Robro v0.2.0 — Plugin Diagnosis & Enhancement

## Goal
Enhance robro's reliability, intelligence, and project-adaptability by addressing gaps identified through competitive analysis of ouroboros, superpowers, oh-my-claudecode, gstack, and long-running harness patterns — while preserving robro's core opinions on evolving setup, multi-agent interviews, spec-driven checklists, worktree enforcement, and customizable bundles.

## Problem Statement
Robro v0.1.2 has a sound architecture but lacks several capabilities that peer plugins demonstrate are important for long-running autonomous builds: no stagnation/drift detection means stuck builds just hit hard caps, no self-evolution means project-specific learnings don't persist across sessions, unreliable state management (hardcoded relative paths, dead fields, unbounded files) creates silent failures, and inconsistent agent protocols create gaps in the dispatch routing model. These gaps reduce robro's effectiveness on real-world projects where sessions are long, domains vary, and builds need intelligent self-correction.

## Users & Stakeholders
- **Plugin users**: Developers who install robro to manage planning and autonomous builds. They need robro to work reliably across projects of different sizes, languages, and domains. They benefit from robro getting smarter per-project over time.
- **Plugin author (you)**: Needs robro's codebase to be auditable and maintainable as it evolves. Template system and protocol consistency serve this need.
- **Future contributors**: Need clear separation between immutable core, configurable core, and project-scoped customization to know what they can change.

## Requirements

### Must Have
- **Stagnation/drift detection (both layers)**: Hook-based oscillation detector (file change hashing, triggers at ≥ 3 same-file edit cycles within a sprint) + full Wonder agent dispatched at sprint boundaries with isolated context window, returning structured `{blind_spots[], lateral_recommendation?}` output. Wonder agent can recommend a lateral thinking mode (contrarian, simplifier, etc.) when it detects the build needs a perspective shift; the do-cycle dispatches that agent.
- **Self-evolution (full learner pattern)**: Level-up phase writes project-scoped skill files to `.robro/skills/*.md` with YAML frontmatter containing keyword `triggers` array. SessionStart hook auto-injects matching skills (up to a cap) when prompt keywords match triggers. Skills can be auto-generated (by level-up) or manually created (by user). User-scoped skills at `~/.robro/skills/*.md` apply across all projects.
- **State reliability fixes**: Remove dead `attempt` and `reinforcement_count` fields from status.yaml templates. Normalize `SESSIONS_DIR` to absolute path via `git rev-parse --show-toplevel` in `lib/load-config.sh`. Bound build-progress.md to last N sprints (configurable, default 5) before injection into retro context. Use atomic file writes for state mutations (temp file + rename pattern).
- **Compression resistance**: Add rationalization tables to a bootstrap skill (mapping common rationalizations to rebuttals, à la superpowers). Add verification-before-completion gate that fires before an agent can claim work is done (explicit checklist of verification steps).
- **Agent protocol consistency**: Refactor plan reviewers (plan-reviewer-prompt.md, spec-reviewer-prompt.md) to return standard `status: DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED` instead of current `APPROVED|ISSUES_FOUND`. Update plan skill routing logic to handle standard protocol.
- **Operational polish**: (a) Version update check on SessionStart — compare local plugin version vs remote (24h cached, non-blocking). (b) SKILL.md template validation — CI-runnable script that verifies SKILL.md agent/config references match actual `agents/*.md` files and `config.json` schema, AND that CLAUDE.md managed block matches actual plugin state. (c) Fill `plugin.json` component paths (`skills`, `agents`, `hooks`).
- **4-tier customization model**: (1) Immutable Core — pipeline structure, status protocol, spec mutations, worktree, hooks, ambiguity gate, sprint lifecycle. (2) Configurable Core — model tiers, thresholds, stagnation params, wonder frequency via `.robro/config.json`. (3) Project-Scoped Generated — learned skills, review checklists, project memory, build verification commands at `.robro/`. (4) User-Scoped Global — `~/.robro/skills/`, `~/.robro/config.json` for cross-project heuristics.

### Should Have
- SubagentStop deliverable verification (check expected output files exist after agent completes)
- Project memory auto-detection on SessionStart (auto-scan tech stack, build commands, conventions → `.robro/project-memory.json`)
- Prompt sanitization before keyword matching (strip URLs, file paths, code blocks, XML tags to reduce false positives)
- Context budget priority rules embedded in agent prompts (explicit "if running low on context, preserve X over Y" directives)

### Won't Have (Non-goals)
- SQLite event store (too heavy for robro's shell+markdown philosophy; status.yaml + file-based state is sufficient)
- Multi-provider architecture (Claude-only; no Codex/Gemini backend support)
- TUI dashboard / HUD statusline (useful but not aligned with robro's lightweight ethos)
- Compiled browser daemon (gstack-specific, not generalizable)
- Per-generation git tags with automatic rollback (ouroboros pattern; robro's worktree isolation serves the same purpose)

## Constraints
- **Breaking release**: This is v0.2.0. Existing v0.1.x users re-run `/robro:setup` to migrate. Document all breaking changes.
- **Node.js allowed**: New hook scripts can use Node.js (.mjs files) since Claude Code guarantees Node.js is present. Validate presence gracefully as good practice.
- **Zero npm dependencies**: All .mjs scripts must be self-contained. No package.json, no npm install step. Parse YAML with regex/simple parser or shell.
- **Core opinions immutable**: The following are non-negotiable architectural decisions: evolving claude code setup, multi-agent interviews with spawned reviewers, spec-driven checklists steering agents, worktree enforcement for builds, customizable bundle setup.
- **Shell scripts remain primary**: Existing bash hooks stay bash. Node.js is additive for complex new features (skill injection, stagnation detection, update check), not a replacement.

## Success Criteria
1. Oscillation hook detects same file edited ≥ 3 times in a sprint (verified by unit test on detection script)
2. Wonder agent returns `{blind_spots[], lateral_recommendation?}` structured output (verified by output schema validation)
3. Level-up writes ≥ 1 skill file to `.robro/skills/` with valid frontmatter (triggers array, description) after a multi-sprint build
4. SessionStart loads ≥ 1 matching skill from `.robro/skills/` when prompt keywords match triggers (verified by hook output inspection)
5. All hooks resolve SESSIONS_DIR to absolute path via `git rev-parse --show-toplevel` (verified by running from subdirectory)
6. build-progress.md truncated to last 5 sprints before retro injection (configurable via `.robro/config.json`)
7. Plan reviewers return standard DONE/BLOCKED status protocol (verified by prompt template grep)
8. Rationalization tables + verification-before-completion gate present (verified by skill text audit)
9. SessionStart emits update-available notice when local version < remote (24h cached, verified by stale-cache test)
10. Template validation script reports PASS when SKILL.md references match actual agents/ and config.json (CI-runnable)

## Proposed Approach
**Foundation-first, 5-phase implementation:**

**Phase 1 — State Reliability + Infrastructure** (foundation)
Fix CWD normalization, remove dead status.yaml fields, bound build-progress.md, add atomic writes, fill plugin.json component paths. Everything downstream depends on reliable state.

**Phase 2 — Stagnation Detection + Agent Protocol** (intelligence)
Hook-based oscillation detector (Node.js .mjs), Wonder agent definition + do-cycle integration, plan reviewer protocol standardization.

**Phase 3 — Self-Evolution** (adaptation)
Full learner pattern: `.robro/skills/*.md` format, skill injection hook (Node.js .mjs), level-up phase integration, `~/.robro/skills/` user-scoped path, keyword trigger matching.

**Phase 4 — Compression Resistance + Should-Haves** (resilience)
Rationalization tables, verification-before-completion gate, SubagentStop verification, prompt sanitization, context budget priority rules, project memory auto-detection.

**Phase 5 — Operational Polish** (maintenance)
Version update check, SKILL.md template validation script, CLAUDE.md managed block sync validation, 4-tier customization documentation.

**Rationale**: Fix foundation first so new features build on reliable state. Stagnation/Wonder before self-evolution because the learner needs sprint cycles to produce skills, and sprint cycles need stagnation detection to be effective.

## Assumptions Exposed

| Assumption | Status | Resolution |
|---|---|---|
| Claude Code hooks receive project root as CWD | Open | If false, `git rev-parse --show-toplevel` in load-config.sh fixes it regardless |
| Node.js is guaranteed present (Claude Code is Node) | Verified | All references (OMC, gstack) rely on this. Confirmed by platform architecture. |
| plugin.json auto-discovery from conventional paths works | Verified | Current v0.1.2 works without explicit paths. Adding them is additive safety. |
| Zero-dep .mjs scripts can parse YAML adequately | Open | Simple YAML (status.yaml, skill frontmatter) has predictable structure. Regex parsing sufficient for these cases. |
| Skill keyword matching doesn't need NLP/embeddings | Verified | OMC uses simple regex keyword matching with a 5-skill cap. Works in production. |
| build-progress.md truncation to 5 sprints preserves enough context | Open | May need tuning per-project. Made configurable in .robro/config.json. |

## Context
Robro v0.1.2 is a structurally mature Claude Code plugin with 5 skills, 11 agents, 8 hook scripts, and a shared `lib/load-config.sh` library. The architecture (skills orchestrate, agents execute, hooks inject focused state) is sound. Key strengths: spec immutability model, config effectiveness feedback loop (CONFIG_BASELINE → retro-analyst → level-up), and inline challenge lens pattern. The codebase is lean (~4,500 lines across skills/agents/hooks/scripts) and recently refactored.

**Competitive landscape**: ouroboros (1,262 stars, Python MCP backend, SQLite event store, mathematical convergence), oh-my-claudecode (9,696 stars, compiled TypeScript hooks, learner skill, HUD), superpowers (marketplace plugin, structured status protocol, rationalization tables), gstack (8,000+ stars, compiled Playwright daemon, external checklists, suppression lists).

**Tech stack for new features**: Existing bash scripts + new Node.js .mjs files (zero-dep). Config via `.robro/config.json` (JSON Schema validated). State via status.yaml + file-based operations.

## Open Questions
(None — ambiguity ≤ 0.1)

## Key Research Findings
Detailed research files in `research/`:
- **ouroboros.md**: 4-pattern stagnation detector (spinning, oscillation, no-drift, diminishing returns), Wonder engine with temperature 0.7, PAL model router with auto-escalation, per-generation git tags + rollback, drift measurement formula `(goal×0.5) + (constraint×0.3) + (ontology×0.2)`
- **oh-my-claudecode.md**: `/learner` skill extracts project-specific heuristics into `.omc/skills/*.md` with keyword triggers (max 5 injected per session), atomic state management with O_EXCL file locking, SubagentStop deliverable verification, prompt sanitization before keyword detection, session-scoped state isolation
- **superpowers.md**: Rationalization tables mapping rationalizations to rebuttals (compression-resistant), verification-before-completion as standalone guardrail, subagent context isolation principle (never forward session history), DONE_WITH_CONCERNS routing specifics
- **gstack.md**: External checklist files read at runtime (project-customizable), DO NOT flag suppression lists, SKILL.md template system (source-driven, CI-validated), daily update check with 24h cache, context budget priority rules in skill prompts
- **long-running-harness.md**: Session succession (not continuity) as design principle, 3-strike escalation model, scale harness complexity with session duration, spinning/oscillation detection via Wonder Phase
- **robro-current-state.md**: Dead status.yaml fields (attempt, reinforcement_count), SESSIONS_DIR hardcoded relative path, missing plugin.json component paths, plan reviewers break status protocol, build-progress.md unbounded growth, ambiguity table only shows brownfield weights
