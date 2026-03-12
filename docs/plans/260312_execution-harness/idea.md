---
type: feature
created: 2026-03-12T00:00:00Z
ambiguity_score: 0.08
status: ready
project_type: brownfield
dimensions:
  goal: 0.92
  constraints: 0.95
  criteria: 0.90
  context: 0.90
---

# Execution Harness for Robro — Your Bro Ships the Code

## Goal

Build a `/robro:build` skill that autonomously implements plan.md through evolutionary sprint cycles, proactively gathering current knowledge and evolving project-scoped agents and rules so that each sprint makes the project smarter — not just more complete.

## Problem Statement

Robro's planning pipeline (`/robro:idea` → `/robro:spec`) produces plan.md with TDD-ready tasks and spec.yaml with validation checklists, but execution stops there. Users must manually implement or use generic Claude Code sessions without the structured oversight that robro's planning phase provides.

The deeper problem: LLM agents fail during implementation because of **outdated built-in knowledge** — they ignore library-specific patterns, use deprecated APIs, and apply stale conventions. Generic execution tools don't proactively research current best practices before writing code. Worse, the knowledge they do gather is ephemeral — lost when the session ends.

Robro's core differentiator: a companion that **learns your project** and gets smarter over time. It doesn't just execute tasks — it builds up project-scoped agents and rules that encode domain expertise, coding conventions, and library-specific patterns it discovers. Each sprint cycle makes the next one better.

Reference: Ouroboros (Q00/ouroboros) produced 169,553 LOC in 12.8 hours with zero human intervention at the Ralphthon hackathon. Oh-my-claudecode (Yeachan-Heo/oh-my-claudecode) completed 21/21 user stories in 7 hours at $46.91. Both demonstrate that structured execution harnesses decisively outperform ad-hoc coding sessions.

## Users & Stakeholders

- **Primary**: Developers who use robro's planning pipeline and want a bro that ships autonomously
- **Secondary**: Teams evaluating Claude Code plugins for production workflows
- **Affected**: The robro plugin's existing planning skills (idea, spec) and hook system — both need updates for unified status tracking

## Requirements

### Must Have

1. **Evolutionary sprint cycle**: Each sprint follows five phases with robro's own identity:
   - **Brief** — Review the plan, gather context, fetch current knowledge for upcoming tasks. On Sprint 1, dispatch a **researcher pre-flight** for comprehensive brownfield detection (tech stack, conventions, existing project rules/agents) before any implementation begins.
   - **Heads-down** — Execute tasks in parallel, write code, run tests (TDD)
   - **Review** — 3-stage peer review of the work (mechanical → semantic → consensus)
   - **Retro** — Structured meta-cognitive analysis producing a **retro report** with five sections: Broken Assumptions (what we thought was true but wasn't), Emerged Patterns (recurring code/architecture patterns worth formalizing), Knowledge Gaps (domains where JIT research was needed but insufficient), Proposed Mutations (specific spec.yaml changes with rationale), and Proposed Level-ups (agent/skill/rule candidates with type justification)
   - **Level-up** — Evolve the spec, update project rules, create or improve project-scoped agents. Fully autonomous — no user approval gates. Async notification fires when agents/skills/rules are created or updated.
   The loop continues until multi-gate convergence passes.

2. **Sprint-per-session with stop hook auto-continue**: Each sprint runs as a standalone session invocation. A **stop hook auto-continues** execution between sprints using OMC's persistent-mode pattern:
   - The stop hook reads `status.yaml` and injects a continuation prompt when the build is still active
   - **Circuit breakers** prevent runaway execution: max 50 reinforcements per session, bail on context usage >95%, bail on rate limit (HTTP 429)
   - `status.yaml` captures enough state for the next session to resume at the right sprint
   - This ensures resilience to context window limits and enables multi-hour execution across sessions

3. **Self-evolving project agents, skills, and rules**: The harness creates OR updates project-scoped files **in the target project's `.claude/` directory** (not robro's plugin directory), making them usable by any Claude Code session — not just robro. Follows clear criteria for what becomes what:

   **Agent** = Persona (WHO you are, HOW you think):
   - Has expertise domain, behavioral traits, and response methodology
   - Gets its own context window when dispatched as subagent
   - Is stateless — doesn't track progress or define workflows
   - **Create when**: A recurring domain needs a dedicated analytical perspective with specific expertise boundaries and behavioral constraints (e.g., `auth-specialist.md` for projects with complex auth patterns)
   - **Don't create when**: The knowledge is procedural (use a skill) or a simple constraint (use a rule)
   - Format: `agents/{name}.md` with YAML frontmatter (`name`, `description`) and persona system prompt body. Description ends with activation trigger: "Use PROACTIVELY for {specific trigger}."

   **Skill** = Knowledge package (WHAT to know, HOW to do it):
   - Step-by-step procedures, checklists, gates, anti-patterns
   - Encodes non-obvious domain knowledge Claude wouldn't know from training
   - Owns workflows — orchestrates agents as subagents
   - **Create when**: A recurring procedure needs to be formalized with specific steps, quality gates, and error handling (e.g., `drizzle-migration/SKILL.md` encoding the project's migration pattern)
   - **Don't create when**: The knowledge is just a simple fact/constraint (use a rule) or a persona definition (use an agent)
   - Format: `skills/{name}/SKILL.md` with YAML frontmatter (`name`, `description`). Follows progressive disclosure: metadata always loaded → SKILL.md on activation → `references/` on demand.

   **Rule** = Simple constraint (project-wide convention):
   - One-liner conventions and constraints that don't need a workflow
   - **Create when**: A fact or convention should be enforced but doesn't warrant a full skill (e.g., "Always use Zod for validation", "Never use API routes for mutations")
   - Format: Added to project CLAUDE.md or `.claude/` rules files

   **Create OR update is the critical principle**: The harness analyzes existing project setup first — CLAUDE.md, .claude/ rules, existing agents and skills — and evolves what's there. Existing files get smarter; new files are created only when a genuine gap is identified. These files persist across plans and sprints — each execution makes the project smarter.

   **Level-up 5-step flow**:
   a. **Analyze**: What patterns, conventions, or domain knowledge emerged this sprint?
   b. **Search references**: Search community collections **live at runtime** (ComposioHQ/awesome-claude-skills, wshobson/agents via WebFetch/web search) for existing agents/skills that match the need BEFORE creating from scratch
   c. **Check existing**: Scan the project's current `.claude/` directory — agents, skills, CLAUDE.md, rules files — for overlap
   d. **Decide**: Is this a persona (agent), procedure (skill), or simple constraint (rule)?
   e. **Create OR update**: Enrich what exists, create only when a gap is identified. Follow Claude Code conventions strictly. Fire async notification on every create/update action.

4. **Free spec.yaml mutation with event log**: spec.yaml evolves freely between sprints — items can be added, modified, or marked superseded. Every mutation is recorded in an append-only event log (`discussion/spec-mutations.log`) for full audit trail. This resolves the tension between robro's original immutability rule and the hackathon-proven need for spec evolution at scale.

5. **3-stage peer review pipeline** (the Review phase): Mechanical verification first (build, lint, test — $0 cost). If mechanical passes, semantic LLM review checks intent alignment. If semantic is ambiguous, multi-model consensus resolves. Failed mechanical checks block all subsequent stages.

6. **Multi-gate convergence**: Five gates must all pass before the sprint cycle ends:
   - **Review gate**: 3-stage validation pipeline passes for all items
   - **Completeness gate**: Every non-superseded checklist item has `passes: true`
   - **Regression gate**: No items that previously passed have regressed to `false`
   - **Growth gate**: spec.yaml has actually evolved from the initial version (prevents trivial convergence)
   - **Confidence gate**: No skipped or failed validation steps
   Plus pathology detection: stagnation (no mutations for 3 sprints), oscillation (contradictory changes), spinning (3 similar errors). Hard sprint cap (e.g., 30) as safety net.

7. **Pathology detection and recovery**:
   - **Spinning** (same errors repeating) → Try a different angle: select an alternative implementation approach
   - **Oscillation** (contradictory fixes) → Step back and find a third way that sidesteps the conflict
   - **Stagnation** (no progress, no mutations) → If similarity ≥ 0.95, declare convergence. Otherwise, force a fresh approach.

8. **Project-aware JIT knowledge gathering**: Before implementing tasks that involve external libraries, frameworks, or domain-specific patterns, the harness proactively fetches current documentation and best practices. Implementation:
   - **Researcher pre-flight (Sprint 1 only)**: Before the first sprint, dispatch the Researcher agent for comprehensive brownfield detection — tech stack, conventions, testing framework, lint rules, build commands, existing project rules/agents for accumulated knowledge. This front-loads context that benefits all subsequent sprints.
   - **Brief phase scan**: On sprint start, check existing project rules/agents for accumulated knowledge. Identify knowledge gaps for upcoming tasks.
   - **JIT per task**: Before each task during Heads-down, check if it involves libraries/APIs and fetch current docs (via context7, web search, or codebase patterns)
   - **Level-up persistence**: Knowledge that's broadly applicable gets written to project rules/agents in `.claude/` (not just injected ephemerally)

9. **Level-based parallel execution with git worktrees**: Tasks within a plan.md phase that have no dependencies run in parallel during Heads-down. Each parallel agent gets an isolated git worktree. After the level completes, worktrees merge back with **agent-mediated conflict resolution** — a dedicated agent analyzes the conflict context, understands the intent from both sides, and produces a resolution. Max 3-4 concurrent agents.

10. **Autonomous execution with async notifications**: The harness runs without blocking on user input. Notifications use **Claude Code's Notification hook event** and fire on: phase completion, sprint boundary, pathology detected, convergence reached, critical failures, and Level-up actions (agent/skill/rule created or updated). The user CAN intervene at any time but doesn't have to. Like a bro who works independently but keeps you in the loop.

11. **Unified status.yaml at plan root**: Move status.yaml from `discussion/status.yaml` to `docs/plans/YYMMDD_name/status.yaml`. This single file tracks the full lifecycle from idea through spec through build. Existing idea/spec skills must be updated to write to this location. Hooks read this file for state injection.

12. **Append-only build-progress.md**: Implementation learnings, codebase patterns, file changes, and failures are logged to `discussion/build-progress.md` in append-only format. This accumulates cross-sprint knowledge and is injected into agent context on session resume.

13. **Cross-session resume**: session-start hook detects `skill: build` in status.yaml, reads spec.yaml passes count, reads build-progress.md for learnings, checks project rules/agents in `.claude/` for accumulated knowledge, and injects focused resume guidance: "Sprint N, Heads-down phase, Y/Z items verified. Last learned: {insight}. Next: {action}."

### Should Have

- **Model tier routing**: Route simple tasks to cheaper/faster models, complex tasks to frontier models. Auto-escalate on failure, auto-downgrade on sustained success.
- **Harness-gap loop**: When a regression is detected, generate a failing test case that becomes a permanent new spec.yaml checklist item. Converts one-off failures into systemic coverage.
- **Session isolation**: Add `session_id` to status.yaml to prevent cross-session state contamination.

### Won't Have (Non-goals)

- **Team pipeline / N-agent coordination**: No OMC-style multi-agent team with task lists and stuck worker detection. Parallel execution is limited to level-based worktrees.
- **MCP server dependency**: No Python runtime, SQLite database, or event sourcing infrastructure. State is managed via YAML/markdown files and shell-script hooks.
- **Human approval gates**: No blocking checkpoints that require user input to proceed. Notifications are async and non-blocking.
- **Full event sourcing**: No database-backed event stream. Cross-session resume uses status.yaml + spec.yaml passes + build-progress.md.

## Constraints

- Must stay within Claude Code's plugin system (skills, agents, hooks in markdown/shell)
- Project-scoped agents and rules must follow Claude Code conventions (agents/*.md, skills/*/SKILL.md, .claude/ rules)
- Project-scoped files live in the **target project's `.claude/` directory**, not robro's plugin directory — usable by any Claude Code session
- Hook scripts must be shell-based (bash) for compatibility with existing hook system
- Plugin loads via `claude --plugin-dir .` — no separate setup or install steps
- Spec.yaml mutation event log must be parseable by shell scripts (not a database)
- Max 3-4 concurrent git worktrees (practical limit for most development machines)
- Sprint hard cap (e.g., 30) prevents runaway execution
- Stop hook circuit breakers: max 50 reinforcements per session, bail on context >95%, bail on rate limit 429
- Must not break existing `/robro:idea` and `/robro:spec` workflows during the migration to plan-root status.yaml
- Project-scoped agents/rules created by the harness must be valid Claude Code plugin files — usable by any session, not just robro
- Level-up searches community references **live at runtime** via WebFetch/web search — no bundled index
- Level-up is fully autonomous — no user approval gates, async notification only

## Success Criteria

**Core Loop:**
1. `/robro:build` executes a plan.md autonomously from start to finish, flipping spec.yaml `passes` fields
2. The evolutionary loop produces 2+ sprints on a non-trivial plan (Retro triggers spec mutation during Level-up)
3. Multi-gate convergence terminates the loop when all 5 gates pass and spec stabilizes
4. Pathology detection fires correctly: spinning after 3 similar errors, oscillation on contradictory fixes, stagnation on no mutations for 3 sprints

**Peer Review:**
5. 3-stage review runs in order: mechanical first, semantic only if mechanical passes, consensus only if semantic is ambiguous
6. Failed mechanical checks (build/test) block the semantic stage

**Parallelism & Knowledge:**
7. Independent tasks within a phase execute in parallel via git worktrees (max 3-4 concurrent)
8. JIT knowledge gathering fetches current library docs before implementing tasks that use external libraries
9. Researcher pre-flight runs before Sprint 1 and produces comprehensive brownfield context for all subsequent sprints

**Self-Evolution:**
10. Level-up correctly distinguishes persona (agent) from procedure (skill) from constraint (rule) — each created file follows its type's conventions and serves a genuine gap
11. Level-up searches community reference collections live at runtime before creating from scratch — adapts existing patterns over reinventing
12. Existing project agents, skills, and CLAUDE.md rules are read during Brief and injected into builder agent context — accumulated knowledge actively informs execution
13. Created/updated files persist in target project's `.claude/` directory — a subsequent `/robro:build` on a different plan benefits from prior sprint learnings

**State & Resume:**
14. status.yaml at plan root tracks full lifecycle (idea → spec → build), all hooks read it correctly
15. Cross-session resume reconstructs execution position from status.yaml + spec.yaml passes + build-progress.md
16. Stop hook auto-continue chains sprints with circuit breakers (max 50 reinforcements, bail on context >95% or rate limit 429)

**Integration:**
17. All existing hooks work with the build phase (pipeline-guard, session-start, drift-monitor, pre-compact, spec-gate with adapted behavior)
18. Async notifications fire via Claude Code's Notification hook event on: phase completion, pathology detected, convergence reached, and Level-up actions (agent/skill/rule created or updated)
19. Retro phase produces structured report (Broken Assumptions, Emerged Patterns, Knowledge Gaps, Proposed Mutations, Proposed Level-ups) that directly feeds Level-up decisions

## Proposed Approach

**Sprint-per-session with stop hook auto-continue**: Each sprint runs as a standalone session invocation. The stop hook detects active build state in status.yaml and injects a continuation prompt, chaining sprints automatically. Circuit breakers prevent runaway execution (max 50 reinforcements, bail on context >95% or rate limit 429).

Architecture:
- `/robro:build` skill handles one sprint per invocation
- Stop hook reads status.yaml and auto-continues when build is active
- `status.yaml` captures sprint state (current sprint, phase, task, attempt count, convergence scores)
- `build-progress.md` accumulates learnings across sprints
- `spec-mutations.log` records spec evolution for audit
- session-start hook detects active build and injects resume context

Sprint lifecycle:
1. **Brief** — Read spec.yaml, identify items with `passes: false`. Check existing project rules/agents in `.claude/`. Fetch JIT knowledge for upcoming tasks. Plan this sprint's parallel execution levels. **Sprint 1 only**: Dispatch researcher pre-flight for comprehensive brownfield detection before any implementation begins.
2. **Heads-down** — Dispatch builder agents per task (parallel within levels via worktrees). Each agent gets JIT knowledge + project rules context. TDD flow: failing test → implement → verify → commit. Merge conflicts resolved by a dedicated conflict-resolution agent that understands both sides' intent.
3. **Review** — Run 3-stage peer review on all changed items. Mechanical (build/lint/test) → Semantic (LLM intent check) → Consensus (multi-model, only if needed).
4. **Retro** — Produce structured retro report with five sections: Broken Assumptions, Emerged Patterns, Knowledge Gaps, Proposed Mutations, Proposed Level-ups. This report is the direct input for Level-up decisions.
5. **Level-up** — Evolve the project's knowledge base through the 5-step flow:
   a. **Analyze**: Read the retro report's Emerged Patterns and Knowledge Gaps
   b. **Search references**: Search community collections **live at runtime** (ComposioHQ/awesome-claude-skills, wshobson/agents) for existing agents/skills that match the need
   c. **Check existing**: Scan the target project's `.claude/` directory for overlap with existing agents, skills, rules
   d. **Decide**: Is this a persona (agent), procedure (skill), or simple constraint (rule)?
   e. **Create OR update**: Write to `.claude/` in the target project. Enrich what exists, create only when a gap is identified. Fire async Notification on every create/update action.
   Also: Apply spec mutations from retro report. Log all changes to spec-mutations.log and build-progress.md.
6. **Converge check** — Run 5-gate convergence + pathology detection. If converged, stop and notify. If pathology, apply recovery. Otherwise, persist state and end session.
7. **Next session** — Stop hook detects `skill: build` in status.yaml, injects continuation prompt. session-start hook restores context. Agent begins sprint N+1.

New agents needed:
- **Builder**: Writes code following plan.md TDD steps. Gets JIT knowledge + project rules context. Uses git worktrees for isolation.
- **Reviewer**: Runs 3-stage peer review. Reports per-item PASS/FAIL with evidence.
- **Retro analyst**: Produces structured retro report. Proposes spec mutations and project rule/agent updates.
- **Conflict resolver**: Analyzes merge conflicts from worktree merges. Understands intent from both sides and produces a clean resolution.

Existing agents reused:
- **Researcher**: Pre-flight brownfield detection (Sprint 1), JIT knowledge gathering during Brief, debugging investigation during Heads-down
- **Architect**: Semantic review during the Review phase
- **Critic**: Consensus gate during the Review phase

## Assumptions Exposed

| Assumption | Status | Resolution |
|---|---|---|
| Claude Code's stop hook can chain sessions | Verified | OMC's persistent-mode demonstrates this works. Stop hook reads status.yaml, injects continuation prompt. Circuit breakers (max 50, context >95%, 429) prevent runaway. |
| Git worktrees work with Claude Code's Agent tool | Verified | Claude Code has `isolation: "worktree"` parameter for the Agent tool. |
| JIT knowledge via context7/web search is fast enough | Open | Need to benchmark. May need caching or pre-fetching strategies. |
| 30 sprint hard cap is sufficient for convergence | Reasonable | Ouroboros uses 30 as default. Hackathon winner converged well before this. |
| Shell-based hooks can parse spec mutation events | Reasonable | Append-only log with simple format is grep/sed friendly. |
| Free spec mutation won't cause scope creep | Challenged | Mitigated by event log + regression gate + growth gate. |
| Session resume from status.yaml is sufficient | Verified | OMC proves state files work. Stop hook auto-continue chains sessions. Single-operator model doesn't need event replay. |
| Project-scoped agents/rules improve execution quality | Reasonable | Core hypothesis. Need to validate that accumulated knowledge actually reduces errors in subsequent sprints. |
| Harness can distinguish when to create vs update project files | Verified | Clear taxonomy: persona→agent, procedure→skill, constraint→rule. 5-step Level-up flow (analyze→search refs→check existing→decide→create/update) prevents duplication. |
| Community reference collections are accessible at runtime | Reasonable | Level-up searches live via WebFetch/web search. Fallback: if fetch fails, create from scratch with notification. |
| Project-scoped agents/skills actually improve subsequent execution | Reasonable | Core hypothesis of the "gets smarter" value proposition. Requires measurement: do error rates decrease across sprints? |
| Agent-mediated merge conflict resolution produces correct results | Open | Need to test with realistic conflict scenarios. Fallback: fail-and-retry with sequential execution. |
| Notification hook event is available and reliable | Reasonable | Claude Code documents Notification as a hook event type. Need to verify delivery mechanism. |

## Context

Robro ("robot + bro") is a Claude Code plugin designed as a project companion — a coworker who works alongside you, not a tool you wield. Its planning pipeline (`/robro:idea` → `/robro:spec`) uses Socratic questioning and multi-agent review to produce thorough plans. The execution harness fills the explicit `(future: build)` gap, completing the pipeline from idea to working code.

The codebase has 7 agents, 2 skills, 6 hook scripts, and a status.yaml-driven state management pattern.

Key existing infrastructure:
- `drift-monitor.sh` already counts spec.yaml `passes: true/false` — ready for execution tracking
- `keyword-detector.sh` Tier 3 detects implementation keywords but only warns about missing spec
- `pipeline-guard.sh` needs a `build)` case for focused state injection
- `spec-gate.sh` behavior should change during build (validate against task, not warn)
- All hooks need `build` cases added to their skill switch statements

Reference plugin patterns adopted:
- **Ouroboros**: Evolutionary loop, 3-stage validation, 5-gate convergence, pathology detection, lateral thinking recovery, stateless stepping
- **Oh-my-claudecode**: Persistent-mode stop hook with circuit breakers, state file architecture, append-only progress log, project-memory detection, Ultrawork parallelism concepts
- **Hackathon learnings**: Complex harnesses win at scale, specs must evolve, multi-stage validation is mandatory

Robro's own contributions beyond references:
- **Sprint cycle naming** (Brief → Heads-down → Review → Retro → Level-up) reflecting the "robot + bro" companion identity
- **Self-evolving project agents, skills, and rules** with clear taxonomy (persona/procedure/constraint) and a 5-step Level-up flow that searches community references live at runtime, distinguishes create vs update, and follows Claude Code conventions
- **Unified status.yaml at plan root** covering the full idea → spec → build lifecycle
- **Project-aware JIT knowledge** that feeds into persistent project skills and rules in the target project's `.claude/`, not just ephemeral context — each sprint makes the project smarter
- **Stop hook auto-continue** with circuit breakers for resilient multi-hour autonomous execution
- **Structured retro report** (Broken Assumptions, Emerged Patterns, Knowledge Gaps, Proposed Mutations, Proposed Level-ups) that directly feeds Level-up decisions
- **Agent-mediated merge conflict resolution** for worktree-based parallelism

## Open Questions

(All resolved during interview rounds 1-24.)

## Key Research Findings

- **Ouroboros** (Q00/ouroboros): 3-stage validation pipeline (mechanical → semantic → consensus), 5 convergence gates, level-based parallelism (max 3), stateless `evolve_step()` for cross-session execution, lateral thinking personas for pathology recovery. Event sourcing with SQLite — too heavy for robro, but patterns are adoptable.

- **Oh-my-claudecode** (Yeachan-Heo/oh-my-claudecode): Persistent-mode stop hook with priority chain and circuit breakers, `.omc/state/` with session isolation and heartbeat, boulder.json for plan tracking, progress.txt append-only log, Ultrawork max 6 concurrent with model tier routing, project-memory.json for cross-session project knowledge, deepinit for AGENTS.md generation. Most mature reference for state management and project awareness.

- **Hackathon results**: Complex evolving-spec harnesses won (169K LOC in 12.8h vs simple fixed-spec loops failing at ~10K LOC). Specs must evolve during execution. Multi-stage validation mandatory. The harness-gap loop (regression → test → coverage growth) is powerful for quality accumulation.

- **Robro codebase**: Plan.md tasks are already TDD-ready with complete code, exact paths, verification commands. Hooks need minimal `build` cases. drift-monitor.sh already tracks spec.yaml passes. The infrastructure is pre-wired for execution.

- **Progress logging**: OMC's 4-layer system is the most relevant pattern. Robro's existing status.yaml extended with execution fields + build-progress.md is sufficient. No database needed.

- **Agent/skill design patterns** (ComposioHQ/awesome-claude-skills, wshobson/agents): Clear three-tier taxonomy — agents are personas (WHO), skills are knowledge packages (WHAT/HOW), rules are simple constraints. Agents define expertise boundaries and behavioral traits, never workflows. Skills define step-by-step procedures with gates and checklists, never personas. Good agents have activation triggers in description, explicit boundaries, output format specs. Good skills encode non-obvious knowledge with progressive disclosure (metadata → SKILL.md → references/). The wshobson collection (112 agents, 146 skills) favors specificity — 4 distinct reviewer types instead of one generic "reviewer". Both collections serve as reference catalogs for Level-up to search live at runtime before creating project-scoped files.
