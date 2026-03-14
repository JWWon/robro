---
name: plan
description: Transforms product requirements (idea.md) into technical implementation plans and validation checklists. Use when an idea.md exists and needs engineering review, task breakdown, and validation checklists. Produces plan.md and spec.yaml.
argument-hint: "<plan directory or plan name>"
---

# Spec — Technical Specification & Implementation Plan

You are acting as an **Engineering Manager**. Your goal is to transform product requirements (idea.md) into a technically sound implementation plan (plan.md) and a validation-ready specification (spec.yaml) that serves as the source of truth for all testing and verification.

**Input**: `$ARGUMENTS` — optional path to plan directory or plan name. If omitted, use the most recently modified plan directory under `.robro/sessions/`.

<Use_When>
- An idea.md exists with status: ready and needs engineering review
- User says "spec", "plan this", "break this down", "create implementation plan"
- User wants technical validation before coding begins
- Requirements exist but need task breakdown and verification checklists
</Use_When>

<Do_Not_Use_When>
- No idea.md exists — suggest /robro:idea first
- User has a one-line fix with obvious implementation
- User wants to brainstorm (use /robro:idea instead)
</Do_Not_Use_When>

## Hard Gate

<HARD_GATE>
Do NOT write any implementation code during this skill. Your ONLY outputs are:
1. Research files (in `research/`)
2. Discussion logs (in `discussion/`)
3. `plan.md` — phased implementation task breakdown
4. `spec.yaml` — technical checklist and validation source of truth
</HARD_GATE>

## Mode Selection

Detect the appropriate mode based on input:

- **Standard mode** (default): Full pipeline — research → architect review → critic scoring → planning → spec generation → cross-validation → final review
- **Direct mode** (if `$ARGUMENTS` contains `--direct`): Skip extended research, generate plan and spec directly. Use when requirements are already very clear.

## Prerequisites

- `idea.md` must exist in the target plan directory with `status: ready`
- If `status: draft`, warn the user and suggest completing `/robro:idea` first
- If no idea.md found, suggest running `/robro:idea` first

## Pipeline Status Tracking

At every step transition, update `status.yaml` (at plan root, e.g. `.robro/sessions/YYMMDD_{slug}/status.yaml`) with your current position. This file drives the hook system — hooks read it to inject focused guidance that survives context compression.

```yaml
skill: plan
step: 4
complexity: ""
branch: ""
worktree: ""
detail: "ADR checkpoint — waiting for user approval"
next: "Present architecture decisions table to user via AskUserQuestion"
gate: "User approves ADR before plan generation"
```

Update at every step transition and within review loops (include iteration count in `detail`). Set `skill: none` when the skill completes.

## Model Configuration

The plan skill always uses the `standard` complexity tier for all agent dispatches. This balances thoroughness with cost. The model mappings for standard tier are defined in `config.json` at the plugin root.

If `.robro/config.json` exists in the project, check for `agent_overrides` that override the standard tier defaults. Precedence: agent_overrides > standard tier config > plugin config.json defaults.

## Workflow (Standard Mode)

### Step 1: Read & Internalize Requirements

Initialize `status.yaml` at the plan root immediately — hooks depend on this file:
```yaml
skill: plan
step: 1
complexity: ""
branch: ""
worktree: ""
detail: "Reading and internalizing requirements"
next: "Dispatch Researcher, Architect, and Critic for technical deep dive"
gate: "Architect APPROVED + Critic PASS, user approves ADR and plan"
```

1. Read `idea.md` thoroughly — internalize problem statement, requirements, constraints, success criteria, and proposed approach
2. Read all files in `research/` for existing context
3. Identify areas that need deeper technical investigation
4. **Scope check**: If idea.md covers multiple independent subsystems, suggest breaking into separate specs — one per subsystem

### Step 1.5: Create Plan Worktree

Create an isolated worktree for all plan and implementation work. This keeps main branch clean -- only the final squash merge commit lands on main.

1. **Save the current plan directory path** (e.g., `.robro/sessions/260313_worktree-workflow/`). You have already read idea.md and research files from here.

2. **Create worktree**:
   ```
   EnterWorktree(name: "{slug}")
   ```
   Where `{slug}` is the plan directory basename (e.g., `260313_worktree-workflow`). This creates `.claude/worktrees/{slug}/` and switches the session CWD to it.

   **Resume check**: If the worktree already exists (from a previous interrupted session), skip creation and just enter it.

3. **Rename branch** for clarity:
   ```bash
   git branch -m plan/{slug}
   ```

4. **Copy plan files from main to worktree**:
   ```bash
   # Copy the entire plan directory (including gitignored research/, discussion/)
   cp -r /path/to/main-repo/.robro/sessions/{slug}/ .robro/sessions/{slug}/
   ```
   The source path is the absolute path to the main repo's plan directory that you saved in step 1.

5. **Clean up main's working directory**:
   ```bash
   rm -rf /path/to/main-repo/.robro/sessions/{slug}/
   ```
   This prevents hooks from finding stale state when a session starts from the main repo.

6. **Update status.yaml** in the worktree:
   ```yaml
   skill: plan
   step: 2
   complexity: ""
   branch: plan/{slug}
   worktree: .claude/worktrees/{slug}
   detail: "Worktree created, starting technical deep dive"
   next: "Dispatch Researcher, Architect, and Critic"
   gate: "Architect APPROVED + Critic PASS, user approves ADR and plan"
   ```

All subsequent work (Steps 2-10) happens inside the worktree. Commits go to the `plan/{slug}` branch.

### Step 2: Technical Deep Dive

Dispatch agents in parallel:

Dispatch with explicit model parameters:
```
Agent(subagent_type: "robro:researcher", prompt: "...", model: "sonnet")
Agent(subagent_type: "robro:architect", prompt: "...", model: "opus")
Agent(subagent_type: "robro:critic", prompt: "...", model: "opus")
```
Standard tier: researcher=sonnet, architect=opus, critic=opus.

1. **Researcher** agent:
   - Deep-dive into technical approaches for each requirement
   - Verify library/framework compatibility with existing codebase
   - Research best practices for the specific problem domain
   - Check for known pitfalls, security concerns, performance patterns
   - Write findings to `research/`

2. **Architect** agent:
   - Review idea.md against the codebase for technical feasibility
   - Identify existing patterns to follow or extend
   - Evaluate the Proposed Approach from idea.md — confirm, refine, or suggest alternatives
   - Flag edge cases, security concerns, performance bottlenecks
   - **Must provide steelman antithesis** for every recommendation
   - **Must identify tradeoff tensions** (where optimizing one thing hurts another)

3. **Critic** agent (full multi-phase review):
   - Score ambiguity of the technical approach
   - Find gaps: missing error handling, undefined boundaries, conflicting requirements
   - Challenge assumptions about the technical approach
   - Provide multi-perspective analysis (Executor, Stakeholder, Skeptic)

After each agent returns, check its **Status** field first, then save its full output to `discussion/` as a markdown file (e.g., `discussion/architect-review.md`, `discussion/critic-assessment.md`). The agents themselves are read-only — you (the plan skill) handle all file writes.

**Status routing** (applies to ALL agent dispatches in this skill):
- **DONE** / **DONE_WITH_CONCERNS**: Process the agent's output normally. For DONE_WITH_CONCERNS, log the concerns in `discussion/` and carry them into Open Questions.
- **NEEDS_CONTEXT**: The agent needs more information. Either answer from your own context (idea.md, research/ files), dispatch a Researcher to gather the missing info, or escalate to the user. Re-dispatch the agent with the additional context.
- **BLOCKED**: The agent cannot complete its work. Assess the blocker — fix if possible, otherwise escalate to the user with the specific blocker description.

### Step 3: Technical Review Loop

After processing statuses, route on the **Verdict** from Critic and Architect:

**Critic verdict:**
- **PASS**: Proceed to Step 4.
- **ACCEPT_WITH_RESERVATIONS**: Proceed, but carry all MAJOR findings into plan.md's Open Questions and spec.yaml's constraints. Log reservations in `discussion/`.
- **NEEDS_WORK**: Enter the revision loop below.
- **REJECT**: Stop immediately. Present the Critic's fundamental issues to the user. Do NOT proceed until the user confirms a revised direction or re-runs `/robro:idea`.

**Architect verdict:**
- **NEEDS_REVISION**: Enter the revision loop below, even if the Critic passed.

**Revision loop** (triggered by NEEDS_WORK or NEEDS_REVISION):

1. Identify the weakest dimensions from the Critic's assessment and/or the Architect's critical issues
2. Dispatch Researcher for targeted investigation on weak areas
3. Revise the technical approach based on findings
4. Re-run Architect + Critic review
5. Repeat until both pass — **iterate as many times as needed**

**Iteration policy**: There is no arbitrary cap. The loop exits only when the Critic returns PASS or ACCEPT_WITH_RESERVATIONS AND the Architect returns APPROVED or APPROVED_WITH_CONCERNS. After every 3 iterations, inform the user of progress and ask whether to continue iterating, try a different approach, or accept current state with noted concerns. Never silently give up.

### Step 3.5: User Checkpoint — Architecture Decisions

Before generating the plan, present the key technical decisions to the user for approval. These decisions shape the entire implementation — getting them wrong wastes all downstream work.

Present via AskUserQuestion:
```
Based on the technical deep dive, here are the key architecture decisions:

| Decision | Rationale | Alternatives | Trade-offs |
|----------|-----------|--------------|------------|
| {decision 1} | {why} | {alternatives} | {what we give up} |
| {decision 2} | ... | ... | ... |

Critic assessment: {verdict} (ambiguity: {score})
Key concerns: {top 2-3 concerns from Critic, if any}

Do these decisions align with your expectations?
```

Options: "Approve and proceed", "Need changes" (user provides direction), "Show me the full Architect and Critic reports".

If the user requests changes:
1. Revise the technical approach per their feedback
2. Re-run Architect + Critic on the revised approach
3. Re-present for approval

Only proceed to plan generation after user approves the technical direction.

### Step 4: Generate plan.md

Dispatch the **Planner** agent to create the implementation plan. Provide the Planner with: idea.md, all `research/` findings, the Architect's Tradeoff Analysis (for ADR), and the Critic's findings (for Pre-mortem). Handle the Planner's status per the status routing protocol above.

```
Agent(subagent_type: "robro:planner", prompt: "...", model: "sonnet")
```
Standard tier: planner=sonnet.

**Principle**: Assume the implementer has **zero codebase context**. Every task must be specific enough for an agent with no prior knowledge to execute correctly.

The plan must follow this exact format:

```markdown
---
spec: spec.yaml
idea: idea.md
created: {ISO 8601 timestamp}
---

# Implementation Plan: {name}

## Overview
{1-2 sentence summary of what will be built and the primary technical approach}

## Tech Context
{Relevant tech stack, frameworks, existing patterns to follow — enough for a newcomer to orient}

## Architecture Decision Record
| Decision   | Rationale | Alternatives Considered   | Trade-offs        |
| ---------- | --------- | ------------------------- | ----------------- |
| {decision} | {why}     | {what else was evaluated} | {what we give up} |

## File Map
| File           | Action         | Responsibility         |
| -------------- | -------------- | ---------------------- |
| `path/to/file` | create\|modify | {one-line description} |

## Phase 1: {milestone name}
> Depends on: none
> Parallel: tasks 1.1 and 1.2 can run concurrently
> Delivers: {what's working after this phase}
> Spec sections: S1, S2

### Task 1.1: {description}
- **Files**: `path/to/file.ts`
- **Spec items**: C1, C2
- **Depends on**: none
- **Action**: {exact what to do — complete code, not "add validation"}
- **Test**: {write the failing test first, then implement}
- **Verify**: {exact command with expected output}
- **Commit**: {commit message}

### Task 1.2: {description}
...

## Phase 2: {milestone name}
> Depends on: Phase 1
...

## Pre-mortem
| Failure Scenario      | Likelihood   | Impact       | Mitigation                  |
| --------------------- | ------------ | ------------ | --------------------------- |
| {what could go wrong} | Low/Med/High | Low/Med/High | {how to prevent or recover} |

## Open Questions
- {unresolved questions from any agent — tracked across the full pipeline}
```

**Plan quality requirements**:
- Every task maps to spec.yaml checklist items (no orphans in either direction)
- Tasks are atomic: each step is one action (2-5 minutes) — write test, run test, implement, run test, commit
- Parallel execution opportunities are explicitly identified
- File paths are exact, not vague
- Verification steps are exact commands with expected output
- **TDD enforced**: Write the failing test → verify it fails → implement → verify it passes → commit
- Include complete code in tasks, not "similar to X" or "add validation"

### Step 5: Plan Review Loop

After generating plan.md, dispatch a **plan reviewer subagent** (see `plan-reviewer-prompt.md`):

Dispatch a general-purpose agent as plan reviewer (see `plan-reviewer-prompt.md`):
```
Agent(prompt: "{plan reviewer prompt from template}", model: "sonnet")
```

1. Reviewer checks: completeness, spec alignment, task atomicity, file structure, TDD compliance
2. If issues found: fix and re-dispatch reviewer
3. Repeat until approved — iterate as many times as needed. After every 3 iterations, inform the user of remaining issues and ask whether to continue or proceed with noted gaps.

### Step 5.5: User Checkpoint — Plan Review

After the automated review loop passes, present the plan summary to the user for feedback before generating the spec.

Present via AskUserQuestion:
```
Implementation plan is ready. Here's the summary:

- **{N} phases**, **{M} tasks**, estimated {X} atomic steps
- Phase 1: {name} — {delivers what}
- Phase 2: {name} — {delivers what}
- ...

Key decisions from ADR:
- {decision 1}: {rationale}

Top risks from pre-mortem:
- {risk 1}: {mitigation}

Open questions:
- {question 1}

Want to review the full plan before I generate the validation spec?
```

Options: "Approve and generate spec", "Show full plan.md", "Need changes" (user provides feedback).

If the user requests changes:
1. Revise plan.md per their feedback
2. Re-run plan reviewer
3. Re-present for approval

If the user asks to see the full plan, show the complete plan.md content and re-ask for approval.

### Step 6: Generate spec.yaml

Create the validation-ready specification. This file is the **source of truth** for determining whether the implementation is complete and correct. All test code, test plans, and validation must be derived from this file.

**Immutability rule**: Checklist items can NEVER be removed or have their `description`/`acceptance_criteria` edited after creation — only `passes` can be flipped from `false` to `true`.

Use this exact schema:

```yaml
meta:
  id: "{plan_directory_name}"
  idea: idea.md
  plan: plan.md
  created: "{ISO 8601 timestamp}"
  updated: "{ISO 8601 timestamp}"
  ambiguity_score: {final critic score}
  complexity: "{light|standard|complex}"

goal: "{copied from idea.md ## Goal section — must match exactly}"

constraints:
  - "{constraint from idea.md}"

non_goals:
  - "{explicitly excluded from idea.md Won't Have section}"

context:
  type: "{greenfield|brownfield}"
  tech_stack:
    - "{framework/library}"
  existing_patterns:
    - "{pattern discovered by researcher}"
  key_files:
    - "{important existing files}"

architecture_decisions:
  - decision: "{what was decided}"
    rationale: "{why}"
    alternatives: ["{other options considered}"]

sections:
  - id: S1
    name: "{section name}"
    description: "{what this covers}"
    requirements:
      - "{requirement from idea.md}"

checklist:
  - id: C1
    section: S1
    phase: 1
    task: "1.1"
    description: "{what to verify}"
    acceptance_criteria: "{measurable criteria — copied or derived from idea.md success criteria}"
    test_type: "{unit|integration|e2e|manual}"
    test_plan: |
      1. {setup step}
      2. {action step}
      3. {assertion — expected result}
    passes: false

  - id: C2
    section: S1
    phase: 1
    task: "1.2"
    description: "{what to verify}"
    acceptance_criteria: "{measurable criteria}"
    test_type: "{unit|integration|e2e|manual}"
    test_plan: |
      1. {setup step}
      2. {action step}
      3. {assertion — expected result}
    passes: false
```

**Complexity assignment**: Read the `complexity` field from idea.md frontmatter. If not present, assess based on:
- **light**: Single file change, config update, simple bugfix. 1-3 spec items.
- **standard**: Multi-file feature, moderate scope. 4-15 spec items.
- **complex**: Cross-cutting change, multiple subsystems, architectural impact. 15+ spec items.
Record the complexity in spec.yaml's `meta.complexity` field. The do skill reads this to select agent models.

**spec.yaml quality requirements**:
- Every idea.md "Must Have" requirement maps to at least one checklist item
- Every checklist item has a concrete, executable `test_plan`
- `test_type` indicates how to verify (unit test, integration test, e2e test, or manual check)
- `phase` and `task` fields create a bidirectional link to plan.md
- All `passes` values start as `false` — flipped to `true` only when verified during implementation
- `architecture_decisions` mirrors the ADR table in plan.md for machine readability

### Step 7: Spec Review Loop

After generating spec.yaml, dispatch a **spec reviewer subagent** (see `spec-reviewer-prompt.md`):

```
Agent(prompt: "{spec reviewer prompt from template}", model: "sonnet")
```

1. Reviewer checks: completeness, internal consistency, checklist coverage, test plan executability
2. If issues found: fix and re-dispatch reviewer
3. Repeat until approved — iterate as many times as needed. After every 3 iterations, inform the user of remaining issues and ask whether to continue or proceed with noted gaps.

### Step 8: Cross-Validation

After both files pass their review loops, validate consistency:

1. **Every plan.md task references valid spec.yaml checklist IDs**
2. **Every spec.yaml checklist item is covered by at least one plan.md task**
3. **Every idea.md "Must Have" requirement appears in spec.yaml sections**
4. **spec.yaml `goal` matches idea.md `## Goal` section exactly**
5. **spec.yaml `non_goals` match idea.md `### Won't Have` items**
6. **Phase ordering in plan.md is consistent with spec.yaml phase references**
7. **File paths in plan.md File Map match files referenced in tasks**
8. **ADR in plan.md matches architecture_decisions in spec.yaml**

If inconsistencies found, fix them before finalizing.

### Step 9: Final Review

Dispatch **Architect** + **Critic** for final review of both plan.md and spec.yaml together:

```
Agent(subagent_type: "robro:architect", prompt: "Final review...", model: "opus")
Agent(subagent_type: "robro:critic", prompt: "Final review...", model: "opus")
```

- Architect: verify technical soundness of the complete plan + spec pair
- Critic: verify completeness, internal consistency, and multi-perspective soundness

If either returns issues, revise and re-validate. Write `.bak` files before overwriting.

### Step 10: Completion

After writing both files:

```
spec.yaml and plan.md are ready in .robro/sessions/{directory}/.
- {N} phases, {M} tasks, {K} checklist items
- Ambiguity score: {score}
- All checklist items start as passes: false

To begin implementation, use plan.md for task ordering and spec.yaml for validation.
Agents should flip spec.yaml checklist items to passes: true only after verification.
```
