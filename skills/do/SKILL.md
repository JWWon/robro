---
name: do
description: Autonomously implements plan.md through evolutionary sprint cycles. Dispatches builder agents for parallel TDD execution, runs 3-stage peer review, produces structured retros, and evolves project agents/skills/rules. Uses stop hook auto-continue for multi-session chaining. Use when plan.md and spec.yaml exist and implementation should begin.
argument-hint: "<plan directory or plan name>"
---

# Build — Autonomous Implementation via Evolutionary Sprints

You are acting as a **Builder Companion**. Your goal is to autonomously implement a plan.md by running evolutionary sprint cycles until all spec.yaml checklist items pass and the project converges.

**Input**: `$ARGUMENTS` — optional path to plan directory or plan name. If omitted, use the most recently modified plan directory under `docs/plans/` that has both plan.md and spec.yaml.

<Use_When>
- A plan.md and spec.yaml exist and implementation should begin
- User says "build", "implement", "ship it", "start building", "execute the plan"
- User wants autonomous code implementation with structured oversight
</Use_When>

<Do_Not_Use_When>
- No plan.md or spec.yaml exists — suggest /robro:plan first
- User wants to modify the plan — suggest /robro:plan --review
- User wants a single quick fix (just do it directly)
</Do_Not_Use_When>

## Hard Gate

<HARD_GATE>
Implementation happens ONLY through dispatched builder agents (inline or worktree-isolated) or Team teammates.
The do skill orchestrates — it never writes implementation code directly.
The do skill DOES write: status.yaml, build-progress.md, spec-mutations.log, spec.yaml mutations, and discussion/ files.
</HARD_GATE>

## Prerequisites

1. `plan.md` must exist with phased tasks and a File Map
2. `spec.yaml` must exist with checklist items (all `passes: false` initially)
3. If either is missing, suggest `/robro:plan` first

## Status Tracking

At every phase transition and within phases, update `{plan_dir}/status.yaml`:

```yaml
skill: do
step: "brief"
sprint: 1
phase: brief
detail: "Gathering context, planning parallel levels"
next: "Dispatch researcher pre-flight, scan project rules"
gate: "All 5 convergence gates pass"
attempt: 1
reinforcement_count: 0
```

This file drives the stop hook (auto-continue) and all pipeline hooks (session-start, pipeline-guard, pre-compact). Update it at EVERY transition.

## Sprint Lifecycle

Each sprint follows 6 phases. Read the detailed phase file for each phase's full instructions. The phase files are in `skills/do/` alongside this SKILL.md.

### Phase 1: Brief
Read `skills/do/brief-phase.md` for detailed instructions.

Summary:
- Read spec.yaml, identify items with `passes: false`
- Sprint 1 ONLY: dispatch Researcher for comprehensive brownfield pre-flight
- Scan existing project rules/agents in target project's `.claude/` directory
- Identify knowledge gaps, fetch JIT docs via context7/web search
- Analyze File Map, detect file overlaps, plan parallel execution levels
- Reset stop hook counter file
- Load model-config.yaml and select complexity tier for agent dispatch

### Phase 2: Heads-down
Read `skills/do/heads-down-phase.md` for detailed instructions.

Summary:
- For each level, use the execution path classified by Brief phase:
  - **Inline**: Dispatch builder agents without isolation (same-category, small, no file overlap)
  - **Isolated**: Dispatch builder agents with `isolation: "worktree"` (file overlap or larger scope). Squash merge + auto-cleanup after each.
  - **Teams**: Create team via TeamCreate for multi-topic coordination (max 5 teammates, non-overlapping file sets)
- After each level: run mechanical verification (build/test) on merged result
- Log task outcomes and execution path to build-progress.md

### Phase 3: Review
Read `skills/do/review-phase.md` for detailed instructions.

Summary:
- Dispatch reviewer agent for 3-stage pipeline
- Stage 1: Mechanical (build, lint, test, typecheck) — $0 cost, blocks if fails
- Stage 2: Semantic (intent alignment, pattern compliance, edge cases) — LLM cost
- Stage 3: Consensus (multi-agent: Architect + Critic + Reviewer) — only if semantic is AMBIGUOUS
- For items that pass all stages: mark as FLIP candidates
- For items that fail: log failures, they go back to builder next sprint

### Phase 4: Retro
Read `skills/do/retro-phase.md` for detailed instructions.

Summary:
- Dispatch retro-analyst agent with sprint data, CONFIG_BASELINE, and CONFIG_ANALYSIS_FRAMEWORK
- Receives structured report: Broken Assumptions, Emerged Patterns, Knowledge Gaps, Proposed Mutations, Proposed Level-ups, Configuration Effectiveness
- Includes mandatory Configuration Effectiveness Analysis comparing project config baseline against sprint reality
- Save report to discussion/retro-sprint-{N}.md
- Report feeds directly into Level-up phase

### Phase 5: Level-up
Read `skills/do/level-up-phase.md` for detailed instructions.

Summary:
- Apply spec mutations (ADD/SUPERSEDE only, per D3) from retro's Proposed Mutations
- Log all mutations to spec-mutations.log
- Flip `passes` for items that passed review (FLIP operations)
- Process configuration suggestions from retro's Config Effectiveness section alongside Proposed Level-ups
- Execute 5-step level-up flow for Proposed Level-ups:
  1. Analyze emerged patterns and knowledge gaps
  2. Search community references live (ComposioHQ/awesome-claude-skills, wshobson/agents)
  3. Check existing project `.claude/` files for overlap
  4. Decide: agent (persona) vs skill (procedure) vs rule (constraint)
  5. Create OR update in target project's `.claude/` directory
- Quality gate: validate files against Claude Code conventions, check naming conflicts
- Maintain rollback manifest at discussion/levelup-manifest.yaml
- Log every create/update action to build-progress.md

### Phase 6: Converge
Read `skills/do/converge-phase.md` for detailed instructions.

Summary:
Run 5-gate convergence check:
1. **Review gate**: All items passed 3-stage review
2. **Completeness gate**: Every non-superseded item has `passes: true`
3. **Regression gate**: No previously-passing items regressed to `false`
4. **Growth gate**: Spec evolved OR 2 consecutive retros with no actionable findings (D6)
5. **Confidence gate**: No skipped or failed validation steps

Pathology detection:
- **Spinning**: 3+ similar errors across sprints — try alternative approach
- **Oscillation**: Contradictory changes — step back, find third way
- **Stagnation**: No mutations for 3 sprints — if similarity >= 0.95 declare convergence, else force fresh approach

Hard cap: 30 sprints (D11).

If converged: set `skill: none`, log final summary to build-progress.md.
If not converged: persist state, update status.yaml for next sprint. The stop hook auto-continues.

## Cross-Session Resume

When resuming (detected by session-start hook reading status.yaml):
1. Read status.yaml for sprint number, phase, and next action
2. Read spec.yaml for current passes count
3. Read build-progress.md for accumulated learnings
4. Read discussion/retro-sprint-*.md for trend data
5. Scan target project's `.claude/` for any new rules/agents from previous level-ups
6. Resume at the exact phase indicated in status.yaml

## Build-Progress.md Format

Append to `discussion/build-progress.md` at each phase:

```markdown
## Sprint {N} — {phase} — {ISO timestamp}

{Phase-specific log entry. Examples:}

### Brief
- Target items: C1, C3, C7 (passes: false)
- JIT knowledge fetched for: react-query, drizzle-orm
- Parallel levels planned: Level 1 (tasks 1.1, 1.2), Level 2 (task 1.3)

### Heads-down
- Task 1.1: PASS — auth middleware implemented
- Task 1.2: FAIL — database migration syntax error, retried with fix
- Merge conflicts: 1 (resolved by conflict-resolver in auth/config.ts)

### Review
- Mechanical: PASS (build OK, 47/47 tests, 0 lint errors)
- Semantic: PASS for C1, AMBIGUOUS for C3
- Consensus: C3 — 2/3 PASS (Architect dissent: edge case in error handling)

### Retro
- Broken assumptions: Drizzle migration API changed in v0.32
- Emerged pattern: All API routes use same error wrapper — candidate for rule
- Proposed mutations: ADD C15 (rate limit validation)

### Level-up
- RULE added to .claude/CLAUDE.md: "Use withApiError() wrapper for all API routes"
- SUPERSEDED C5 -> C16 (refined auth flow after discovering Better Auth v2 API)
- spec-mutations.log: 2 entries appended

### Converge
- Review: PASS | Completeness: 8/12 | Regression: PASS | Growth: PASS | Confidence: PASS
- Not converged — 4 items remaining. Next sprint targets: C3, C9, C10, C11
```
