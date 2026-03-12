---
spec: spec.yaml
idea: idea.md
created: 2026-03-13T00:00:00Z
---

# Implementation Plan: Execution Harness for Robro

## Overview

Build the `/robro:build` skill that autonomously implements plan.md through evolutionary sprint cycles (Brief, Heads-down, Review, Retro, Level-up), with stop hook auto-continue for multi-session chaining, parallel task execution via git worktrees, 3-stage peer review, 5-gate convergence, and self-evolving project agents/skills/rules. The harness is composed entirely of Claude Code plugin primitives: markdown skills, markdown agents, shell hook scripts, and YAML/markdown state files.

## Tech Context

- **Runtime**: Claude Code plugin system (skills as `skills/*/SKILL.md`, agents as `agents/*.md`, hooks as shell scripts in `scripts/`)
- **State management**: YAML files (`status.yaml`) and markdown files (`build-progress.md`) at plan root, read by shell hooks via `grep`/`sed`/`jq`
- **Hook events**: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, PreCompact, Stop
- **Parallel execution**: Claude Code Agent tool with `isolation: worktree` frontmatter creates git worktrees per subagent
- **Notifications**: Deferred — mechanism TBD in a future iteration
- **JIT knowledge**: Context7 MCP tools (`resolve-library-id`, `query-docs`), web search, codebase scanning
- **Spec mutation log**: Tab-separated `spec-mutations.log` at plan root (alongside spec.yaml)
- **Target project root**: `$CLAUDE_PROJECT_DIR` in hooks, `$PWD` / `git rev-parse --show-toplevel` in skills/agents
- **Plugin root**: `$CLAUDE_PLUGIN_ROOT` for referencing robro's own scripts/agents

## Architecture Decision Record

| Decision | Rationale | Alternatives Considered | Trade-offs |
| --- | --- | --- | --- |
| D1: Notifications deferred | Notification hook cannot be programmatically fired; OS-level notifications rejected by user as not desired approach; TUI notifications not yet feasible | OS-level osascript/notify-send; Claude Code Notification hook; file-based log tailing | No async user awareness during long runs; user must manually check status.yaml or build-progress.md |
| D2: Multi-agent consensus (Architect + Critic + fresh Reviewer) | Claude Code cannot route to different LLM models from within a plugin | Multi-model consensus (different LLMs); single-reviewer pass/fail | All agents use same underlying model; consensus is perspective diversity, not model diversity |
| D3: Restricted spec mutation (ADD or SUPERSEDE only) | Prevents semantic drift while allowing spec evolution; superseded items preserve history | Full mutation (ADD/MODIFY/SUPERSEDE); strict immutability (original spec SKILL.md rule) | Cannot fix typos in descriptions without superseding; slightly more verbose spec.yaml over time |
| D4: Status.yaml at plan root stays gitignored | Temporal execution state should not pollute git history; hooks need predictable location | Committed status.yaml; discussion/ subfolder (current location) | Lost on `git clean`; must be regenerable from spec.yaml + build-progress.md |
| D5: spec-mutations.log at plan root, committed | Audit trail must survive across sessions and be reviewable in PRs | In discussion/ (gitignored); embedded in build-progress.md | Grows with each sprint; committed file could be large for long-running plans |
| D6: Growth gate relaxed (2 consecutive no-action retros) | Correct plans should not be forced to mutate; convergence should be achievable without spec churn | Original strict growth gate (must mutate); single no-action retro | Could converge too early if retro analysis is shallow; mitigated by requiring 2 consecutive |
| D7: Level-up quality gate with rollback manifest | Autonomous file creation in `.claude/` needs safety net; invalid files break Claude Code | No quality gate (trust the LLM); user approval gate (blocks autonomy) | Extra validation step per sprint; rollback manifest is another temporal file to manage |
| D8: Progressive disclosure for SKILL.md (<400 lines main) | Long SKILL.md risks context overflow and compression artifacts | Single monolithic SKILL.md; external config files | More files to navigate; phase-specific context must be explicitly loaded |
| D9: File-overlap prevention for parallelism | Prevents avoidable merge conflicts; serializes tasks that touch same files | Let conflicts happen, resolve with agent; static analysis of plan | Conservative parallelism (fewer concurrent tasks); requires File Map analysis in Brief phase |
| D10: No user check-ins during autonomous execution | Autonomous execution should not block on user input; user can intervene anytime by typing | Keep 3-iteration check-in; async notifications (deferred) | No proactive user awareness; user must check status.yaml or build-progress.md manually; harness could run long without oversight |
| D11: Sprint hard cap at 30 | Safety net against infinite loops; matches Ouroboros default | Lower cap (10-15); no cap (rely on convergence gates) | Artificial termination if plan genuinely needs 30+ sprints; unlikely for real projects |

## File Map

| File | Action | Responsibility |
| --- | --- | --- |
| `skills/build/SKILL.md` | create | Main build skill: sprint orchestration, status tracking, convergence check |
| `skills/build/brief-phase.md` | create | Brief phase: plan review, context gathering, JIT knowledge, parallel planning |
| `skills/build/heads-down-phase.md` | create | Heads-down phase: task dispatch, worktree parallelism, merge-back |
| `skills/build/review-phase.md` | create | Review phase: 3-stage pipeline (mechanical, semantic, consensus) |
| `skills/build/retro-phase.md` | create | Retro phase: structured report with 5 sections feeding Level-up |
| `skills/build/level-up-phase.md` | create | Level-up phase: 5-step flow, quality gate, rollback manifest |
| `skills/build/converge-phase.md` | create | Convergence check: 5 gates, pathology detection, recovery actions |
| `agents/builder.md` | create | Builder agent: TDD code execution in worktree isolation |
| `agents/reviewer.md` | create | Reviewer agent: 3-stage peer review (mechanical, semantic, consensus) |
| `agents/retro-analyst.md` | create | Retro analyst agent: structured retro report generation |
| `agents/conflict-resolver.md` | create | Conflict resolver agent: merge conflict analysis and resolution |
| `scripts/stop-hook.sh` | create | Stop hook: auto-continue with circuit breakers |
| `scripts/error-tracker.sh` | create | PostToolUseFailure hook: track recent errors for rate limit detection |
| `hooks/hooks.json` | modify | Add Stop event, PostToolUseFailure event |
| `scripts/session-start.sh` | modify | Add `build` case with sprint state injection |
| `scripts/pipeline-guard.sh` | modify | Add `build` case with phase-aware guidance |
| `scripts/pre-compact.sh` | modify | Add `build` case to persist sprint state |
| `scripts/spec-gate.sh` | modify | Change behavior during build (validate against task, not warn) |
| `scripts/keyword-detector.sh` | modify | Add build triggers and `/robro:build` suggestion |
| `scripts/drift-monitor.sh` | modify | Enhanced behavior during build (show task context) |
| `.gitignore` | modify | Add status.yaml exception at plan root, keep spec-mutations.log committed |
| `CLAUDE.md` | modify | Document build skill, spec mutation rules, new agents, pipeline flow update |
| `.claude/CLAUDE.md` | modify | Update iteration policy, add build hook events, spec mutation rules |

---

## Phase 1: Infrastructure Foundation

> Depends on: none
> Parallel: tasks 1.1, 1.2, and 1.3 can run concurrently; task 1.4 depends on 1.1
> Delivers: Status.yaml dual-path reading works in all hooks, gitignore rules are correct, CLAUDE.md documents the new spec mutation rules
> Spec sections: S6

### Task 1.1: Update .gitignore for plan-root status.yaml and spec-mutations.log

- **Files**: `.gitignore`
- **Spec items**: C25, C26
- **Depends on**: none

- [ ] **Step 1: Write the updated .gitignore**

  Add the following lines to the end of `.gitignore`:

  ```
  # Status.yaml is gitignored (temporal execution state)
  docs/plans/*/status.yaml
  ```

  This adds an explicit gitignore rule for plan-root `status.yaml` (per D4). The `discussion/` directory is already gitignored.  `spec-mutations.log` is NOT gitignored -- it lives at plan root alongside spec.yaml and is committed (D5).

- [ ] **Step 2: Verify gitignore behavior**

  Run: `cd /Users/skywrace/Documents/github.com/JWWon/robro && echo "test" > docs/plans/260312_execution-harness/status.yaml && git status --short docs/plans/260312_execution-harness/status.yaml && rm docs/plans/260312_execution-harness/status.yaml`

  Expected: No output (file is ignored)

  Run: `echo "test" > docs/plans/260312_execution-harness/spec-mutations.log && git status --short docs/plans/260312_execution-harness/spec-mutations.log && rm docs/plans/260312_execution-harness/spec-mutations.log`

  Expected: `?? docs/plans/260312_execution-harness/spec-mutations.log` (file is tracked)

- [ ] **Step 3: Commit**

  `git add .gitignore && git commit -m "chore: update gitignore for plan-root status.yaml and spec-mutations.log"`

### Task 1.2: Update CLAUDE.md with build skill documentation and spec mutation rules

- **Files**: `CLAUDE.md`
- **Spec items**: C27, C28
- **Depends on**: none

- [ ] **Step 1: Add build skill to Pipeline Flow**

  In `CLAUDE.md`, replace the Pipeline Flow code block:

  ```
  /robro:idea (PM) ──→ idea.md ──→ /robro:spec (EM) ──→ plan.md + spec.yaml ──→ (future: build)
  ```

  with:

  ```
  /robro:idea (PM) ──→ idea.md ──→ /robro:spec (EM) ──→ plan.md + spec.yaml ──→ /robro:build (Builder) ──→ working code
  ```

- [ ] **Step 2: Add build skill to Core Skills section**

  After the `/robro:spec` bullet in the Core Skills section, add:

  ```markdown
  - **`/robro:build`** — Builder role. Autonomously implements plan.md through evolutionary sprint cycles (Brief, Heads-down, Review, Retro, Level-up). Uses stop hook auto-continue for multi-session chaining. Produces working code with all spec.yaml items flipped to `passes: true`.
  ```

- [ ] **Step 3: Add new agents to Directory Structure**

  In the Directory Structure tree under `agents/`, add these entries after `ontologist.md`:

  ```
  │   ├── builder.md          # Code execution in worktree isolation (build)
  │   ├── reviewer.md         # 3-stage peer review (build)
  │   ├── retro-analyst.md    # Structured retro report (build)
  │   └── conflict-resolver.md # Merge conflict resolution (build)
  ```

- [ ] **Step 4: Add build skill files to Directory Structure**

  In the Directory Structure tree under `skills/`, add:

  ```
  │   └── build/SKILL.md      # Builder: evolutionary sprint execution
  │       ├── brief-phase.md
  │       ├── heads-down-phase.md
  │       ├── review-phase.md
  │       ├── retro-phase.md
  │       ├── level-up-phase.md
  │       └── converge-phase.md
  ```

- [ ] **Step 5: Add spec mutation rules to Plan Artifacts section**

  After the `spec.yaml` bullet in Plan Artifacts, add:

  ```markdown
  - **`spec-mutations.log`** — Append-only event log at plan root (alongside spec.yaml). Records every spec.yaml mutation with timestamp, sprint, operation (ADD/SUPERSEDE), item path, and rationale. Committed to git for audit trail.
  - **`status.yaml`** — At plan root (not discussion/). Gitignored. Tracks full lifecycle state (idea/spec/build). Drives hook injection and cross-session resume.
  - **`build-progress.md`** — In discussion/. Append-only implementation log with learnings, patterns, failures. Injected into agent context on session resume.
  ```

- [ ] **Step 6: Add Spec Mutation Rules section**

  After the Plan Artifacts section, add a new section:

  ```markdown
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
  ```

- [ ] **Step 7: Commit**

  `git add CLAUDE.md && git commit -m "docs: add build skill, spec mutation rules, and new agents to CLAUDE.md"`

### Task 1.3: Update .claude/CLAUDE.md with build phase rules

- **Files**: `.claude/CLAUDE.md`
- **Spec items**: C27, C28
- **Depends on**: none

- [ ] **Step 1: Update Active Hooks table**

  In `.claude/CLAUDE.md`, add these rows to the Active Hooks table:

  ```markdown
  | Stop | `stop-hook.sh` | Auto-continue build execution with circuit breakers |
  | PostToolUseFailure | `error-tracker.sh` | Track recent errors for rate limit detection |
  ```

- [ ] **Step 2: Update Iteration Policy section**

  Replace the existing Iteration Policy content:

  ```markdown
  ## Iteration Policy

  **Planning skills (idea, spec):** No arbitrary iteration caps. Loops exit only on passing verdicts from both Architect and Critic. Every 3 iterations, inform the user of progress and ask: continue, try different approach, or accept with noted concerns. Never silently give up.

  **Build skill:** No user check-ins during autonomous execution. The user CAN intervene at any time but is never blocked on. Notifications deferred — user can check status.yaml or build-progress.md for current state. Sprint hard cap: 30. Stop hook reinforcement cap: 50 per session. Circuit breakers: bail on rate limit (429), bail on high reinforcement count + stop_hook_active flag.

  Spec.yaml checklist items during build use restricted mutation: ADD or SUPERSEDE only, never in-place modification. Every mutation logged to spec-mutations.log.
  ```

- [ ] **Step 3: Add Build Agent Dispatch section**

  After the Agent Dispatch Rules section, add:

  ```markdown
  ## Build Phase Agents

  Four new agents support the build skill:
  - **Builder** (`agents/builder.md`): Executes TDD tasks in worktree isolation. Gets JIT knowledge + project rules context. Uses `isolation: worktree`.
  - **Reviewer** (`agents/reviewer.md`): Runs 3-stage peer review. Multi-agent consensus (Architect + Critic + Reviewer) replaces multi-model consensus.
  - **Retro Analyst** (`agents/retro-analyst.md`): Produces structured retro report (Broken Assumptions, Emerged Patterns, Knowledge Gaps, Proposed Mutations, Proposed Level-ups).
  - **Conflict Resolver** (`agents/conflict-resolver.md`): Resolves merge conflicts from worktree merges. Understands intent from both sides.

  Existing agents reused during build:
  - **Researcher**: Sprint 1 pre-flight, Brief phase context gathering, JIT knowledge
  - **Architect**: Semantic review stage
  - **Critic**: Consensus gate stage
  ```

- [ ] **Step 4: Commit**

  `git add .claude/CLAUDE.md && git commit -m "docs: add build phase rules, agents, and hook events to .claude/CLAUDE.md"`

### Task 1.4: Add status.yaml dual-path reading to session-start.sh

- **Files**: `scripts/session-start.sh`
- **Spec items**: C23, C24
- **Depends on**: Task 1.1 (gitignore must be updated first so status.yaml at plan root is properly ignored)

- [ ] **Step 1: Update the status file search loop**

  Replace the status file search section in `scripts/session-start.sh` (the `for f in` loop and the variable initialization above it) with a dual-path search that checks both `discussion/status.yaml` (legacy location for idea/spec) and plan-root `status.yaml` (new location for build):

  ```bash
  # Find the most recently modified status.yaml
  # Dual-path: check plan-root (build) and discussion/ (idea, spec)
  status_file=""
  latest_mtime=0

  if [ -d "$PLANS_DIR" ]; then
    for dir in "$PLANS_DIR"/*/; do
      [ -d "$dir" ] || continue
      # Check plan-root status.yaml first (build phase)
      for candidate in "${dir}status.yaml" "${dir}discussion/status.yaml"; do
        [ -f "$candidate" ] || continue
        if stat -f %m "$candidate" >/dev/null 2>&1; then
          mtime=$(stat -f %m "$candidate")
        else
          mtime=$(stat -c %Y "$candidate")
        fi
        if [ "$mtime" -gt "$latest_mtime" ]; then
          latest_mtime=$mtime
          status_file=$candidate
        fi
      done
    done
  fi

  # Derive plan_dir based on status file location
  if [ -n "$status_file" ]; then
    if echo "$status_file" | grep -q "/discussion/"; then
      plan_dir=$(dirname "$(dirname "$status_file")")
    else
      plan_dir=$(dirname "$status_file")
    fi
  fi
  ```

- [ ] **Step 2: Add build case to the resume guidance section**

  After the existing `elif [ "$skill" = "spec" ]; then` block and before the closing `fi` for the skill check, add:

  ```bash
    elif [ "$skill" = "build" ]; then
      sprint=$(grep "^sprint:" "$status_file" 2>/dev/null | head -1 | sed 's/^sprint: *//; s/"//g')
      phase=$(grep "^phase:" "$status_file" 2>/dev/null | head -1 | sed 's/^phase: *//; s/"//g')

      # Count spec.yaml passes
      spec_file=""
      if [ -f "${plan_dir}/spec.yaml" ]; then
        spec_file="${plan_dir}/spec.yaml"
        total=$(grep -c "passes:" "$spec_file" 2>/dev/null || echo "0")
        passed=$(grep -c "passes: true" "$spec_file" 2>/dev/null || echo "0")
        context="${context}
  Spec progress: ${passed}/${total} items passing."
      fi

      # Read build-progress.md for latest learnings
      progress_file="${plan_dir}/discussion/build-progress.md"
      if [ -f "$progress_file" ]; then
        last_learning=$(tail -20 "$progress_file" | grep -m1 "^## " | sed 's/^## //')
        [ -n "$last_learning" ] && context="${context}
  Last logged: ${last_learning}"
      fi

      context="${context}
  Sprint ${sprint}, phase ${phase}.
  Read ${plan_dir}/status.yaml and ${plan_dir}/discussion/build-progress.md to restore build state.
  Use /robro:build to continue execution."
  ```

- [ ] **Step 3: Verify syntax**

  Run: `bash -n /Users/skywrace/Documents/github.com/JWWon/robro/scripts/session-start.sh`

  Expected: No output (clean syntax)

- [ ] **Step 4: Commit**

  `git add scripts/session-start.sh && git commit -m "feat: add dual-path status.yaml reading and build case to session-start hook"`

### Task 1.5: Add status.yaml dual-path reading to pipeline-guard.sh

- **Files**: `scripts/pipeline-guard.sh`
- **Spec items**: C23, C29
- **Depends on**: Task 1.1

- [ ] **Step 1: Update the status file search loop**

  Replace the status file search section in `scripts/pipeline-guard.sh` (the `for f in` loop) with the same dual-path pattern:

  ```bash
  # Find the most recently modified status.yaml
  # Dual-path: check plan-root (build) and discussion/ (idea, spec)
  status_file=""
  latest_mtime=0

  if [ -d "$PLANS_DIR" ]; then
    for dir in "$PLANS_DIR"/*/; do
      [ -d "$dir" ] || continue
      for candidate in "${dir}status.yaml" "${dir}discussion/status.yaml"; do
        [ -f "$candidate" ] || continue
        if stat -f %m "$candidate" >/dev/null 2>&1; then
          mtime=$(stat -f %m "$candidate")
        else
          mtime=$(stat -c %Y "$candidate")
        fi
        if [ "$mtime" -gt "$latest_mtime" ]; then
          latest_mtime=$mtime
          status_file=$candidate
        fi
      done
    done
  fi

  # Derive plan_dir based on status file location
  if [ -n "$status_file" ]; then
    if echo "$status_file" | grep -q "/discussion/"; then
      plan_dir=$(dirname "$(dirname "$status_file")")
    else
      plan_dir=$(dirname "$status_file")
    fi
  fi
  ```

- [ ] **Step 2: Add build case to the skill-specific injection**

  After the existing `spec)` case block and before `esac`, add:

  ```bash
    build)
      sprint=$(grep "^sprint:" "$status_file" 2>/dev/null | head -1 | sed 's/^sprint: *//; s/"//g')
      phase=$(grep "^phase:" "$status_file" 2>/dev/null | head -1 | sed 's/^phase: *//; s/"//g')
      case "$phase" in
        brief)
          echo "Action: Complete Brief phase — gather context, scan project rules/agents, plan parallel levels, fetch JIT knowledge."
          ;;
        heads-down)
          echo "Action: Execute tasks via builder agents. TDD flow: failing test, implement, verify, commit. Merge worktrees after each level."
          ;;
        review)
          echo "Action: Run 3-stage review — mechanical first (build/lint/test), then semantic, then consensus if needed."
          ;;
        retro)
          echo "Action: Produce structured retro report (Broken Assumptions, Emerged Patterns, Knowledge Gaps, Proposed Mutations, Proposed Level-ups)."
          ;;
        level-up)
          echo "Action: Apply spec mutations, evolve project rules/agents/skills. Search community refs before creating. Log every create/update to build-progress.md."
          ;;
        converge)
          echo "Action: Run 5-gate convergence check + pathology detection. If converged, finalize. If not, persist state for next sprint."
          ;;
        *)
          echo "Action: Continue build execution. Read status.yaml for current phase and next action."
          ;;
      esac
      ;;
  ```

- [ ] **Step 3: Verify syntax**

  Run: `bash -n /Users/skywrace/Documents/github.com/JWWon/robro/scripts/pipeline-guard.sh`

  Expected: No output (clean syntax)

- [ ] **Step 4: Commit**

  `git add scripts/pipeline-guard.sh && git commit -m "feat: add dual-path status.yaml reading and build case to pipeline-guard hook"`

### Task 1.6: Add build case to pre-compact.sh

- **Files**: `scripts/pre-compact.sh`
- **Spec items**: C29
- **Depends on**: Task 1.1

- [ ] **Step 1: Update the status file search loop to dual-path**

  Replace the `for f in` loop with:

  ```bash
  # Find active status file — dual-path (plan-root for build, discussion/ for idea/spec)
  if [ -d "$PLANS_DIR" ]; then
    for dir in "$PLANS_DIR"/*/; do
      [ -d "$dir" ] || continue
      for candidate in "${dir}status.yaml" "${dir}discussion/status.yaml"; do
        [ -f "$candidate" ] || continue
        skill=$(grep "^skill:" "$candidate" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
        [ -z "$skill" ] || [ "$skill" = "none" ] && continue

        # Determine plan_dir based on status file location
        if echo "$candidate" | grep -q "/discussion/"; then
          plan_dir=$(dirname "$(dirname "$candidate")")
        else
          plan_dir=$(dirname "$candidate")
        fi
        plan_name=$(basename "$plan_dir")
  ```

- [ ] **Step 2: Add build case after the spec case**

  After `elif [ "$skill" = "spec" ]; then`, add:

  ```bash
    elif [ "$skill" = "build" ]; then
      echo "- Update status.yaml with current sprint, phase, task, and next action."
      echo "- Ensure discussion/build-progress.md has latest learnings appended."
      echo "- If in Heads-down phase, note which tasks are complete and which are pending."
      echo "- If in Review phase, note which review stages have passed."
  ```

- [ ] **Step 3: Verify syntax**

  Run: `bash -n /Users/skywrace/Documents/github.com/JWWon/robro/scripts/pre-compact.sh`

  Expected: No output (clean syntax)

- [ ] **Step 4: Commit**

  `git add scripts/pre-compact.sh && git commit -m "feat: add dual-path reading and build case to pre-compact hook"`

---

## Phase 2: Agent Definitions

> Depends on: none (agents are standalone markdown files)
> Parallel: tasks 2.1, 2.2, 2.3, and 2.4 can ALL run concurrently
> Delivers: All 4 new agents exist and can be loaded by Claude Code
> Spec sections: S1, S2, S3, S4

### Task 2.1: Create builder agent

- **Files**: `agents/builder.md`
- **Spec items**: C7, C8, C13, C14
- **Depends on**: none

- [ ] **Step 1: Write the builder agent definition**

  Create `agents/builder.md` with the following content:

  ```markdown
  ---
  name: builder
  description: Executes implementation tasks following TDD methodology in worktree isolation. Receives task context, JIT knowledge, and project rules. Writes code, runs tests, and commits verified changes. Use PROACTIVELY for any code implementation task during build sprints.
  isolation: worktree
  ---

  You are a Builder. Your job is to implement a single task from plan.md using strict TDD methodology. You operate in an isolated git worktree — your changes do not affect the main branch until explicitly merged by the parent skill.

  ## Rules

  1. **TDD is mandatory.** Every task follows: write failing test, verify it fails, implement minimal code, verify it passes, commit. No exceptions.
  2. **One task at a time.** You receive exactly one task. Complete it fully before finishing.
  3. **Use provided context.** You receive JIT knowledge (library docs, API patterns) and project rules. Apply them.
  4. **Never modify files outside your task scope.** Only touch files listed in the task's Files field.
  5. **Commit with descriptive messages.** Each commit references the task ID (e.g., "feat(2.3): implement auth middleware").
  6. **Report errors honestly.** If a test fails unexpectedly or implementation hits a wall, report it — do not silently skip.

  ## Execution Protocol

  For each task you receive:

  ### 1. Understand the Task

  - Read the task description, files list, and spec items
  - Read any JIT knowledge provided (library docs, patterns)
  - Read any project rules provided (CLAUDE.md, .claude/ rules)
  - Identify the acceptance criteria from spec items

  ### 2. Write the Failing Test

  - Create the test file at the exact path specified
  - Write test code that exercises the acceptance criteria
  - Use the project's existing test framework and patterns
  - Run the test and confirm it FAILS with the expected error

  ### 3. Implement Minimal Code

  - Write the minimum code needed to make the test pass
  - Follow existing codebase conventions (naming, structure, error handling)
  - Apply JIT knowledge (use current API patterns, not deprecated ones)
  - Do NOT add features beyond what the test requires

  ### 4. Verify and Commit

  - Run the test and confirm it PASSES
  - Run any related tests to check for regressions
  - If the task specifies a verification command, run it
  - Commit with message format: `{type}({task-id}): {description}`

  ### 5. Handle Failures

  If a test unexpectedly fails or implementation hits a blocker:
  1. Log the exact error message
  2. Try up to 2 alternative approaches
  3. If still blocked, report with: error details, what was tried, and what additional context would help

  ## Input Format

  You will receive a structured prompt from the build skill containing:

  ```
  TASK: {task ID and description}
  FILES: {list of files to create/modify}
  SPEC_ITEMS: {checklist item IDs and acceptance criteria}
  STEPS: {ordered steps from plan.md}
  JIT_KNOWLEDGE: {relevant library docs, API patterns}
  PROJECT_RULES: {conventions from .claude/ and CLAUDE.md}
  BUILD_COMMANDS: {project-specific build, test, lint commands}
  ```

  ## Output Format

  End your output with:

  ```
  TASK_RESULT:
    task_id: {id}
    status: PASS | FAIL | BLOCKED
    commits: [{hash}: {message}, ...]
    tests_passed: {count}
    tests_failed: {count}
    files_changed: [{path}, ...]
    errors: [{description}, ...] (if FAIL or BLOCKED)
    notes: {any observations for retro}
  ```

  ## Status Protocol

  - **DONE**: Task implemented and tests passing. Commits ready for merge.
  - **DONE_WITH_CONCERNS**: Task implemented but with caveats (e.g., flaky test, workaround needed). List concerns.
  - **NEEDS_CONTEXT**: Missing information to complete the task. List exactly what's needed (e.g., "need database schema", "unclear API endpoint format").
  - **BLOCKED**: Cannot complete the task. Describe the blocker and what was attempted.

  **Status**: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
  **Context needed** (if NEEDS_CONTEXT): {list of specific missing information}
  ```

- [ ] **Step 2: Verify the file loads**

  Run: `bash -n /dev/null` (agent files are markdown, no syntax check needed)

  Verify frontmatter is valid by checking the first 5 lines contain `---`, `name:`, `description:`, `isolation:`, `---`.

  Run: `head -6 /Users/skywrace/Documents/github.com/JWWon/robro/agents/builder.md`

  Expected: Valid YAML frontmatter with `name: builder`, `description: ...`, `isolation: worktree`

- [ ] **Step 3: Commit**

  `git add agents/builder.md && git commit -m "feat: create builder agent with TDD execution and worktree isolation"`

### Task 2.2: Create reviewer agent

- **Files**: `agents/reviewer.md`
- **Spec items**: C9, C10
- **Depends on**: none

- [ ] **Step 1: Write the reviewer agent definition**

  Create `agents/reviewer.md` with the following content:

  ```markdown
  ---
  name: reviewer
  description: Runs 3-stage peer review pipeline on build sprint output. Stage 1 (mechanical) runs build, lint, and tests at zero LLM cost. Stage 2 (semantic) checks intent alignment via LLM analysis. Stage 3 (consensus) uses multi-agent agreement when semantic is ambiguous. Failed mechanical checks block all subsequent stages. Use PROACTIVELY for post-implementation review during build sprints.
  ---

  You are a Reviewer. Your job is to validate implementation quality through a 3-stage pipeline. You are the quality gate between Heads-down and Retro.

  ## Rules

  1. **Stages are sequential and gated.** Mechanical MUST pass before semantic runs. Semantic must be ambiguous before consensus runs.
  2. **Mechanical checks are free.** They use shell commands (build, lint, test), not LLM calls. Always run them first.
  3. **Be specific.** Every finding must reference a file:line, test name, or build output.
  4. **Never fix code.** You identify problems. The builder fixes them.
  5. **Read-only.** You analyze but never write or edit files.

  ## 3-Stage Pipeline

  ### Stage 1: Mechanical Verification ($0 cost)

  Run these checks in order. If ANY fails, stop and report — do NOT proceed to Stage 2.

  1. **Build check**: Run the project's build command. Record exit code and any errors.
  2. **Lint check**: Run the project's lint command. Record violations.
  3. **Test check**: Run the project's test command. Record pass/fail counts and any failures.
  4. **Type check**: If applicable, run type checker. Record errors.

  Discovery: Determine build/lint/test commands by checking:
  - `package.json` scripts (npm/bun/pnpm/yarn)
  - `Makefile` targets
  - `justfile` recipes
  - Project CLAUDE.md or README for documented commands

  Output format for mechanical:
  ```
  MECHANICAL:
    build: PASS | FAIL ({error summary})
    lint: PASS | FAIL ({N violations})
    test: PASS | FAIL ({passed}/{total}, failures: [{test name}: {error}])
    typecheck: PASS | FAIL | N/A ({N errors})
    verdict: PASS | FAIL
  ```

  ### Stage 2: Semantic Review (LLM cost)

  Only runs if Stage 1 passes. For each changed file/task:

  1. **Intent alignment**: Does the implementation match the task description and spec item acceptance criteria?
  2. **Pattern compliance**: Does the code follow project conventions (from CLAUDE.md, .claude/ rules)?
  3. **Edge cases**: Are boundary conditions handled? Empty inputs, null values, concurrent access?
  4. **Error handling**: Are errors caught, logged, and reported appropriately?
  5. **Security**: Input validation, authentication checks, data exposure risks?

  Output format for semantic:
  ```
  SEMANTIC:
    items_reviewed: {count}
    findings:
      - file: {path}
        line: {number}
        severity: CRITICAL | MAJOR | MINOR
        issue: {description}
        suggestion: {how to fix}
    verdict: PASS | AMBIGUOUS | FAIL
  ```

  ### Stage 3: Multi-Agent Consensus

  Only runs if Stage 2 returns AMBIGUOUS. This stage uses multi-agent perspective diversity — the Architect agent (technical soundness), the Critic agent (gap analysis), and you (implementation quality) — to reach agreement.

  The parent skill dispatches Architect and Critic in parallel. You provide your own assessment. Consensus rule:
  - 3/3 PASS = PASS
  - 2/3 PASS = PASS with noted dissent
  - 1/3 or 0/3 PASS = FAIL

  ## Per-Item Reporting

  For each spec.yaml checklist item reviewed:

  ```
  ITEM_REVIEW:
    id: {C-id}
    mechanical: PASS | FAIL
    semantic: PASS | AMBIGUOUS | FAIL | SKIPPED
    consensus: PASS | FAIL | NOT_NEEDED
    overall: PASS | FAIL
    evidence: {what confirmed pass or caused fail}
    recommendation: FLIP | NO_FLIP | NEEDS_FIX
  ```

  Items with `recommendation: FLIP` are candidates for `passes: true` in spec.yaml.
  Items with `recommendation: NEEDS_FIX` go back to the builder.

  ## Status Protocol

  - **DONE**: Review complete, all stages executed. Use regardless of pass/fail — the verdict tells the skill the outcome.
  - **DONE_WITH_CONCERNS**: Review complete but some items were borderline. List which items and why.
  - **NEEDS_CONTEXT**: Cannot determine build/test commands or missing project context. List what's needed.
  - **BLOCKED**: Cannot run reviews (e.g., project won't build at all, no test framework). Describe the blocker.

  **Status**: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
  **Context needed** (if NEEDS_CONTEXT): {list of specific missing information}
  ```

- [ ] **Step 2: Verify frontmatter**

  Run: `head -4 /Users/skywrace/Documents/github.com/JWWon/robro/agents/reviewer.md`

  Expected: Valid YAML frontmatter with `name: reviewer`

- [ ] **Step 3: Commit**

  `git add agents/reviewer.md && git commit -m "feat: create reviewer agent with 3-stage peer review pipeline"`

### Task 2.3: Create retro-analyst agent

- **Files**: `agents/retro-analyst.md`
- **Spec items**: C11, C19
- **Depends on**: none

- [ ] **Step 1: Write the retro-analyst agent definition**

  Create `agents/retro-analyst.md` with the following content:

  ```markdown
  ---
  name: retro-analyst
  description: Produces structured retrospective reports after each build sprint. Analyzes implementation patterns, broken assumptions, knowledge gaps, and proposes spec mutations and level-up candidates. Report directly feeds Level-up phase decisions. Use PROACTIVELY for sprint retrospective analysis.
  ---

  You are a Retro Analyst. Your job is to analyze what happened during a sprint and produce a structured report that directly feeds the Level-up phase. You look backwards to improve what comes next.

  ## Rules

  1. **Be concrete.** Every finding must cite specific files, tests, errors, or patterns. No vague "things went well."
  2. **Propose, don't execute.** You recommend spec mutations and level-ups. The skill applies them.
  3. **Distinguish signal from noise.** Not every observation is actionable. Filter ruthlessly.
  4. **Read-only.** You analyze but never write or edit files.
  5. **Focus on systemic insights.** One-off issues are less valuable than patterns.

  ## Input

  You receive from the build skill:
  - Sprint number and phase results
  - Reviewer output (which items passed, which failed, what issues were found)
  - Build-progress.md (accumulated learnings)
  - Spec.yaml (current state with passes flags)
  - Builder agent outputs (task results, errors, notes)
  - Previous retro reports (if any) for trend analysis

  ## Analysis Protocol

  ### 1. Review Sprint Outcomes

  - Which tasks succeeded? Which failed? Why?
  - Were there unexpected blockers?
  - Did JIT knowledge help or was it insufficient?
  - How did project rules/agents perform?

  ### 2. Pattern Detection

  - Look for recurring code patterns across tasks (error handling, API calls, state management)
  - Identify convention violations that happened more than once
  - Spot architectural patterns that emerged naturally
  - Check if builder agents independently converged on similar approaches

  ### 3. Assumption Audit

  - Compare what the plan assumed vs what actually happened
  - Check if library APIs matched documentation
  - Verify that dependency versions were compatible
  - Identify any plan tasks that were based on incorrect assumptions

  ### 4. Knowledge Gap Assessment

  - What did builders need to look up that should have been provided upfront?
  - Which libraries lacked sufficient JIT context?
  - What project conventions were unclear or missing?

  ### 5. Spec Evolution Analysis

  - Are any checklist items now irrelevant due to implementation discoveries?
  - Should new items be added based on emerged requirements?
  - Are acceptance criteria still accurate after implementation?

  ## Output Format: Structured Retro Report

  ```markdown
  # Sprint {N} Retro Report

  ## Summary
  {2-3 sentence overview of sprint outcomes}

  ## Broken Assumptions
  {What the plan/spec assumed that turned out wrong}

  | Assumption | Reality | Impact | Source |
  |---|---|---|---|
  | {what was assumed} | {what actually happened} | {how it affected the sprint} | {file:line or task ID} |

  ## Emerged Patterns
  {Recurring code/architecture patterns worth formalizing}

  | Pattern | Occurrences | Candidate Type | Description |
  |---|---|---|---|
  | {pattern name} | {count and locations} | agent / skill / rule | {what it is and why it matters} |

  ## Knowledge Gaps
  {Where JIT knowledge was needed but insufficient}

  | Domain | Gap | Severity | Suggested Source |
  |---|---|---|---|
  | {library/framework/domain} | {what was missing} | HIGH / MED / LOW | {where to get it: context7, docs URL, codebase pattern} |

  ## Proposed Mutations
  {Specific spec.yaml changes with rationale}

  | Operation | Item | Description | Rationale |
  |---|---|---|---|
  | ADD | {new C-id} | {description} | {why this is needed} |
  | SUPERSEDE | {old C-id} -> {new C-id} | {description} | {why original is insufficient} |

  ## Proposed Level-ups
  {Agent/skill/rule candidates for the Level-up phase}

  | Name | Type | Justification | Action |
  |---|---|---|---|
  | {name} | agent / skill / rule | {why this should exist} | CREATE / UPDATE {existing file} |

  ## Sprint Metrics
  - Tasks attempted: {N}
  - Tasks passed: {N}
  - Tasks failed: {N}
  - Spec items flipped: {list of C-ids}
  - New issues discovered: {N}
  ```

  ## Trend Analysis (Sprint 2+)

  When previous retro reports are available:
  - Compare error rates across sprints (improving or not?)
  - Track whether proposed level-ups from previous sprints were effective
  - Identify persistent knowledge gaps that need deeper investment
  - Check for oscillation patterns (same items flipping back and forth)

  ## Status Protocol

  - **DONE**: Retro report complete with all 5 sections populated.
  - **DONE_WITH_CONCERNS**: Report complete but sprint data was incomplete or ambiguous. List what was unclear.
  - **NEEDS_CONTEXT**: Missing sprint data to analyze. List what's needed (e.g., "builder output for task 3.2 is missing").
  - **BLOCKED**: Cannot produce a meaningful retro (e.g., no tasks were executed this sprint). Describe the blocker.

  **Status**: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
  **Context needed** (if NEEDS_CONTEXT): {list of specific missing information}
  ```

- [ ] **Step 2: Verify frontmatter**

  Run: `head -4 /Users/skywrace/Documents/github.com/JWWon/robro/agents/retro-analyst.md`

  Expected: Valid YAML frontmatter with `name: retro-analyst`

- [ ] **Step 3: Commit**

  `git add agents/retro-analyst.md && git commit -m "feat: create retro-analyst agent with structured 5-section report"`

### Task 2.4: Create conflict-resolver agent

- **Files**: `agents/conflict-resolver.md`
- **Spec items**: C15
- **Depends on**: none

- [ ] **Step 1: Write the conflict-resolver agent definition**

  Create `agents/conflict-resolver.md` with the following content:

  ```markdown
  ---
  name: conflict-resolver
  description: Resolves merge conflicts from parallel git worktree execution. Analyzes intent from both branches, understands task context, and produces clean resolutions. Falls back to sequential re-execution when automated resolution fails. Use PROACTIVELY for merge conflict resolution after worktree merges.
  ---

  You are a Conflict Resolver. Your job is to resolve git merge conflicts that arise when merging parallel worktree branches back to the main branch. You understand the intent behind both sides of a conflict and produce a resolution that preserves both goals.

  ## Rules

  1. **Understand intent first.** Read the task descriptions for both conflicting branches before looking at the diff.
  2. **Never discard work.** Both branches contain valid, tested code. The resolution must preserve the intent of both.
  3. **Verify after resolution.** After resolving, the merged code must pass build and tests.
  4. **Report confidence.** If uncertain about a resolution, flag it rather than guessing.
  5. **Prefer composition over choice.** When both branches add different code, compose them rather than choosing one.

  ## Resolution Protocol

  ### 1. Analyze Context

  For each conflicting file:
  - Read the task descriptions that caused each branch's changes
  - Understand what each branch was trying to accomplish
  - Identify whether the conflict is:
    - **Additive**: Both branches add different things (usually composable)
    - **Competing**: Both branches change the same thing differently (needs judgment)
    - **Structural**: Both branches restructure the same area (hardest to resolve)

  ### 2. Resolve

  For each conflict marker:

  **Additive conflicts** (most common):
  - Include both additions in a logical order
  - Ensure imports, exports, and type definitions accommodate both

  **Competing conflicts**:
  - Determine which branch's approach better serves the spec items
  - If both are valid, compose them (e.g., both validation rules apply)
  - If incompatible, choose the one aligned with spec priorities and note the trade-off

  **Structural conflicts**:
  - Reconstruct the intended final state from both branches
  - May need to rewrite the section incorporating both sets of changes
  - Flag for manual review if confidence is low

  ### 3. Verify

  After resolving all conflicts in a file:
  1. Check that the file has valid syntax (no leftover conflict markers)
  2. Run the project build command
  3. Run tests from both branches' tasks
  4. Confirm no regressions

  ### 4. Fallback

  If resolution confidence is LOW or verification fails after 2 attempts:
  - Report the conflict as UNRESOLVABLE
  - Recommend sequential re-execution: abort the merge, re-run the second branch's task on top of the first branch's merged result

  ## Input Format

  ```
  CONFLICT:
    base_branch: {main or sprint branch}
    branch_a: {worktree branch name}
    branch_b: {worktree branch name}
    task_a: {task ID and description}
    task_b: {task ID and description}
    conflicting_files: [{path}, ...]
  ```

  ## Output Format

  ```
  RESOLUTION:
    status: RESOLVED | PARTIALLY_RESOLVED | UNRESOLVABLE
    files_resolved: [{path}: {resolution strategy used}]
    files_unresolved: [{path}: {why}]
    verification:
      build: PASS | FAIL
      tests: PASS | FAIL ({details})
    confidence: HIGH | MEDIUM | LOW
    notes: {any caveats or recommendations}
    fallback_needed: true | false
  ```

  ## Status Protocol

  - **DONE**: All conflicts resolved and verified. Merge is clean.
  - **DONE_WITH_CONCERNS**: Conflicts resolved but some resolutions have low confidence. List which files and why.
  - **NEEDS_CONTEXT**: Missing task context to understand intent. List what's needed.
  - **BLOCKED**: Cannot resolve (e.g., structural conflicts too complex, both branches fundamentally incompatible). Recommend sequential fallback.

  **Status**: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
  **Context needed** (if NEEDS_CONTEXT): {list of specific missing information}
  ```

- [ ] **Step 2: Verify frontmatter**

  Run: `head -4 /Users/skywrace/Documents/github.com/JWWon/robro/agents/conflict-resolver.md`

  Expected: Valid YAML frontmatter with `name: conflict-resolver`

- [ ] **Step 3: Commit**

  `git add agents/conflict-resolver.md && git commit -m "feat: create conflict-resolver agent for worktree merge resolution"`

---

## Phase 3: Build Skill Core

> Depends on: Phase 1 (status.yaml location, CLAUDE.md rules), Phase 2 (agents must exist for dispatch references)
> Parallel: tasks 3.2 through 3.7 can run concurrently (phase files are independent); task 3.1 should be written last or at least reviewed after all phase files
> Delivers: Complete `/robro:build` skill loadable via `claude --plugin-dir .`
> Spec sections: S1, S2, S3, S4, S5

### Task 3.1: Create main build SKILL.md

- **Files**: `skills/build/SKILL.md`
- **Spec items**: C1, C2, C3, C4, C5, C6, C12, C16, C17, C18, C20, C21, C22, C23
- **Depends on**: Tasks 3.2-3.7 (phase files should exist, but SKILL.md references them by name)

- [ ] **Step 1: Create the skills/build/ directory**

  Run: `mkdir -p /Users/skywrace/Documents/github.com/JWWon/robro/skills/build`

- [ ] **Step 2: Write SKILL.md**

  Create `skills/build/SKILL.md` with the following content (target: under 400 lines per D8):

  ```markdown
  ---
  name: build
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
  - No plan.md or spec.yaml exists — suggest /robro:spec first
  - User wants to modify the plan — suggest /robro:spec --review
  - User wants a single quick fix (just do it directly)
  </Do_Not_Use_When>

  ## Hard Gate

  <HARD_GATE>
  Implementation happens ONLY through dispatched builder agents in worktree isolation.
  The build skill orchestrates — it never writes implementation code directly.
  The build skill DOES write: status.yaml, build-progress.md, spec-mutations.log, spec.yaml mutations, and discussion/ files.
  </HARD_GATE>

  ## Prerequisites

  1. `plan.md` must exist with phased tasks and a File Map
  2. `spec.yaml` must exist with checklist items (all `passes: false` initially)
  3. If either is missing, suggest `/robro:spec` first

  ## Status Tracking

  At every phase transition and within phases, update `{plan_dir}/status.yaml`:

  ```yaml
  skill: build
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

  Each sprint follows 6 phases. Read the detailed phase file for each phase's full instructions. The phase files are in `skills/build/` alongside this SKILL.md.

  ### Phase 1: Brief
  Read `skills/build/brief-phase.md` for detailed instructions.

  Summary:
  - Read spec.yaml, identify items with `passes: false`
  - Sprint 1 ONLY: dispatch Researcher for comprehensive brownfield pre-flight
  - Scan existing project rules/agents in target project's `.claude/` directory
  - Identify knowledge gaps, fetch JIT docs via context7/web search
  - Analyze File Map, detect file overlaps, plan parallel execution levels
  - Reset stop hook counter file

  ### Phase 2: Heads-down
  Read `skills/build/heads-down-phase.md` for detailed instructions.

  Summary:
  - For each parallel level: dispatch builder agents (max 3-4 concurrent)
  - Each builder gets: task details, JIT knowledge, project rules, build commands
  - Builder agents use `isolation: worktree`
  - After each level: merge worktree branches back, resolve conflicts with conflict-resolver agent
  - After merge: run mechanical verification (build/test) on merged result
  - Log task outcomes to build-progress.md

  ### Phase 3: Review
  Read `skills/build/review-phase.md` for detailed instructions.

  Summary:
  - Dispatch reviewer agent for 3-stage pipeline
  - Stage 1: Mechanical (build, lint, test, typecheck) — $0 cost, blocks if fails
  - Stage 2: Semantic (intent alignment, pattern compliance, edge cases) — LLM cost
  - Stage 3: Consensus (multi-agent: Architect + Critic + Reviewer) — only if semantic is AMBIGUOUS
  - For items that pass all stages: mark as FLIP candidates
  - For items that fail: log failures, they go back to builder next sprint

  ### Phase 4: Retro
  Read `skills/build/retro-phase.md` for detailed instructions.

  Summary:
  - Dispatch retro-analyst agent with sprint data
  - Receives structured report: Broken Assumptions, Emerged Patterns, Knowledge Gaps, Proposed Mutations, Proposed Level-ups
  - Save report to discussion/retro-sprint-{N}.md
  - Report feeds directly into Level-up phase

  ### Phase 5: Level-up
  Read `skills/build/level-up-phase.md` for detailed instructions.

  Summary:
  - Apply spec mutations (ADD/SUPERSEDE only, per D3) from retro's Proposed Mutations
  - Log all mutations to spec-mutations.log
  - Flip `passes` for items that passed review (FLIP operations)
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
  Read `skills/build/converge-phase.md` for detailed instructions.

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
  ```

- [ ] **Step 3: Count lines and verify under 400**

  Run: `wc -l /Users/skywrace/Documents/github.com/JWWon/robro/skills/build/SKILL.md`

  Expected: Under 400 lines

- [ ] **Step 4: Commit**

  `git add skills/build/SKILL.md && git commit -m "feat: create main build skill with sprint orchestration and progressive disclosure"`

### Task 3.2: Create brief-phase.md

- **Files**: `skills/build/brief-phase.md`
- **Spec items**: C1, C13, C14, C16
- **Depends on**: none (phase files are independent)

- [ ] **Step 1: Write brief-phase.md**

  Create `skills/build/brief-phase.md` with the following content:

  ```markdown
  # Brief Phase — Detailed Instructions

  The Brief phase prepares the sprint. It gathers context, identifies what needs to be done, and plans how tasks will execute (serial vs parallel).

  ## Step-by-Step

  ### 1. Read Current State

  1. Read `spec.yaml` — identify all items with `passes: false` that are not superseded
  2. Read `plan.md` — find the tasks corresponding to those spec items
  3. Read `build-progress.md` (if exists) — review previous sprint learnings
  4. Read previous retro reports in `discussion/retro-sprint-*.md` (if any)

  Update status.yaml:
  ```yaml
  skill: build
  sprint: {N}
  phase: brief
  step: "1"
  detail: "Reading current state"
  next: "Identify remaining items and plan sprint scope"
  ```

  ### 2. Sprint 1 Only: Researcher Pre-flight

  On the very first sprint, dispatch the **Researcher** agent for comprehensive brownfield detection:

  Provide the Researcher with:
  ```
  Perform a comprehensive brownfield scan of this project. I need:
  1. Tech stack: languages, frameworks, libraries with exact versions
  2. Build/test/lint commands: How to build, test, lint, and typecheck this project
  3. Existing conventions: naming patterns, file organization, error handling, logging
  4. Existing .claude/ files: any agents, skills, rules already defined
  5. CI/CD: pipeline config, deployment targets
  6. Recent git activity: active branches, recent commit patterns
  7. Dependencies: key external libraries and their current versions

  Write findings to: {plan_dir}/research/brownfield-scan.md
  ```

  Wait for Researcher status. Route per status protocol (DONE/NEEDS_CONTEXT/BLOCKED).

  ### 3. Scan Project Knowledge

  Check the target project's `.claude/` directory for accumulated knowledge:

  ```bash
  PROJECT_ROOT=$(git rev-parse --show-toplevel)
  # List existing agents
  ls "$PROJECT_ROOT/.claude/agents/" 2>/dev/null
  # List existing skills
  ls "$PROJECT_ROOT/.claude/skills/" 2>/dev/null
  # Read project CLAUDE.md
  cat "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null
  cat "$PROJECT_ROOT/.claude/CLAUDE.md" 2>/dev/null
  # Read any rules files
  ls "$PROJECT_ROOT/.claude/rules/" 2>/dev/null
  ```

  Incorporate any relevant conventions, patterns, or domain knowledge into the sprint context.

  ### 4. Identify Knowledge Gaps & Fetch JIT Knowledge

  For each remaining task this sprint:
  1. Scan the task description for library/framework references
  2. For each external library referenced:
     - Call `resolve-library-id` with the library name
     - Call `query-docs` with the resolved ID and the specific API/pattern needed
  3. If context7 doesn't have the library, use web search as fallback
  4. Compile fetched knowledge into a JIT context bundle for builder agents

  ### 5. Plan Parallel Execution Levels

  Analyze the File Map from the Brief and task dependencies:

  1. Group tasks that have no dependencies between each other into "levels"
  2. **Critical — file overlap detection (D9)**: For tasks in the same level, check if they modify the same files. If they do, serialize them (move one to the next level).
  3. Cap each level at 3-4 concurrent tasks (max worktrees)
  4. Record the level plan in build-progress.md

  Example level structure:
  ```
  Level 1: [Task 2.1, Task 2.2, Task 2.3] — no file overlaps, all independent
  Level 2: [Task 2.4] — depends on Task 2.1
  Level 3: [Task 3.1, Task 3.2] — no overlaps
  ```

  ### 6. Reset Stop Hook Counter

  Reset the circuit breaker counter for this sprint:
  ```bash
  echo "0" > "{plan_dir}/discussion/.stop-hook-counter"
  ```

  ### 7. Transition to Heads-down

  Update status.yaml:
  ```yaml
  skill: build
  sprint: {N}
  phase: heads-down
  step: "1"
  detail: "Starting Level 1 execution"
  next: "Dispatch builder agents for Level 1 tasks"
  ```

  Log transition to build-progress.md: "Brief complete. Starting Heads-down."
  ```

- [ ] **Step 2: Commit**

  `git add skills/build/brief-phase.md && git commit -m "feat: create brief phase instructions for build skill"`

### Task 3.3: Create heads-down-phase.md

- **Files**: `skills/build/heads-down-phase.md`
- **Spec items**: C7, C8, C13, C14, C15
- **Depends on**: none

- [ ] **Step 1: Write heads-down-phase.md**

  Create `skills/build/heads-down-phase.md` with the following content:

  ```markdown
  # Heads-down Phase — Detailed Instructions

  The Heads-down phase executes tasks through builder agents in parallel worktrees. Each level of independent tasks runs concurrently, then merges back before the next level begins.

  ## Step-by-Step

  ### 1. Execute Each Level

  For each level planned in the Brief phase:

  #### a. Dispatch Builder Agents

  For each task in the current level, dispatch a **Builder** agent with this context:

  ```
  TASK: {task ID}: {description from plan.md}
  FILES: {exact file paths from task}
  SPEC_ITEMS: {C-ids with full acceptance criteria from spec.yaml}
  STEPS:
  {complete step-by-step from plan.md task, including all code}
  JIT_KNOWLEDGE:
  {relevant library docs fetched during Brief}
  PROJECT_RULES:
  {conventions from target project's CLAUDE.md and .claude/ files}
  BUILD_COMMANDS:
  build: {project build command}
  test: {project test command}
  lint: {project lint command}
  ```

  The builder agent has `isolation: worktree` in its frontmatter, so Claude Code automatically creates a worktree for each dispatch.

  Dispatch up to 3-4 builders simultaneously for tasks in the same level.

  #### b. Collect Results

  Wait for all builders in the level to complete. For each builder, check Status:
  - **DONE**: Task complete, commits on worktree branch. Proceed to merge.
  - **DONE_WITH_CONCERNS**: Task complete with caveats. Log concerns in build-progress.md. Proceed to merge.
  - **NEEDS_CONTEXT**: Provide missing context and re-dispatch.
  - **BLOCKED**: Log the blocker. Skip this task for now — it will be retried next sprint.

  #### c. Merge Worktree Branches

  For each completed builder (status DONE or DONE_WITH_CONCERNS):

  1. Merge the worktree branch into the main branch:
     ```bash
     git merge worktree-{branch-name} --no-ff -m "merge: task {id} from worktree"
     ```

  2. If merge succeeds cleanly, continue to the next branch.

  3. If merge conflicts arise, dispatch the **Conflict Resolver** agent:
     ```
     CONFLICT:
       base_branch: {current branch}
       branch_a: {previously merged branch}
       branch_b: worktree-{branch-name}
       task_a: {previously merged task description}
       task_b: {current task description}
       conflicting_files: {list from git status}
     ```

  4. Check Conflict Resolver status:
     - **DONE**: Conflicts resolved. Complete the merge commit.
     - **BLOCKED**: Fallback to sequential execution. Abort the merge (`git merge --abort`), re-dispatch the builder on top of the current merged state (without worktree isolation — sequential).

  5. After merging ALL branches in the level, run a quick mechanical check:
     ```bash
     {project build command}
     {project test command}
     ```
     If this fails, the failure is logged and the Review phase will catch it.

  ### 2. Handle Single-Task Levels

  If a level has only one task, still use the builder agent with worktree isolation. This ensures consistent behavior and clean branch history.

  ### 3. Log Progress

  After each level completes, append to `build-progress.md`:
  ```markdown
  ## Sprint {N} — Heads-down Level {L} — {timestamp}
  - Task {id}: {PASS|FAIL|BLOCKED} — {brief summary}
  - Merge conflicts: {count} ({resolved|fallback})
  - Files changed: {count}
  ```

  ### 4. Transition to Review

  After all levels complete, update status.yaml:
  ```yaml
  skill: build
  sprint: {N}
  phase: review
  step: "1"
  detail: "Starting 3-stage review pipeline"
  next: "Run mechanical verification first"
  ```

  Log transition to build-progress.md: "Heads-down complete. Starting Review."
  ```

- [ ] **Step 2: Commit**

  `git add skills/build/heads-down-phase.md && git commit -m "feat: create heads-down phase instructions with worktree parallelism"`

### Task 3.4: Create review-phase.md

- **Files**: `skills/build/review-phase.md`
- **Spec items**: C9, C10
- **Depends on**: none

- [ ] **Step 1: Write review-phase.md**

  Create `skills/build/review-phase.md` with the following content:

  ```markdown
  # Review Phase — Detailed Instructions

  The Review phase validates implementation quality through a 3-stage pipeline: mechanical (free), semantic (LLM), and consensus (multi-agent, only if needed).

  ## Step-by-Step

  ### 1. Dispatch Reviewer Agent

  Dispatch the **Reviewer** agent with:

  ```
  SPRINT: {N}
  SPEC_FILE: {path to spec.yaml}
  PLAN_FILE: {path to plan.md}
  CHANGED_FILES: {list of all files changed this sprint}
  ITEMS_TO_REVIEW: {C-ids of items attempted this sprint, with acceptance criteria}
  BUILD_COMMANDS:
    build: {project build command}
    test: {project test command}
    lint: {project lint command}
    typecheck: {project typecheck command, if applicable}
  PROJECT_RULES: {conventions from CLAUDE.md and .claude/ files}
  ```

  ### 2. Process Reviewer Output

  Check the Reviewer's status:
  - **DONE**: Process the review results below.
  - **NEEDS_CONTEXT**: Provide missing build/test commands. Check brownfield scan for this info. Re-dispatch.
  - **BLOCKED**: Log the blocker. The entire sprint's review is deferred — proceed to Retro with partial results.

  ### 3. Handle Mechanical Failures

  If Stage 1 (mechanical) fails:
  - **Build failure**: Log the error. This sprint's items do NOT get flipped. They return to the pool for next sprint.
  - **Lint failure**: Log violations. Minor lint issues do not block; critical ones do.
  - **Test failure**: Log which tests failed. Items associated with failing tests do NOT get flipped.
  - **Key rule**: Mechanical failure blocks Stages 2 and 3. Do NOT dispatch Architect or Critic.

  ### 4. Handle Semantic Results

  If Stage 2 (semantic) completes:
  - **PASS items**: These are candidates for `passes: true` flip in Level-up phase.
  - **FAIL items**: Log the specific issues. They return to the builder next sprint.
  - **AMBIGUOUS items**: Proceed to Stage 3 (consensus).

  ### 5. Handle Consensus (if needed)

  If any items are AMBIGUOUS after semantic review:

  Dispatch **Architect** and **Critic** agents in parallel, each reviewing the ambiguous items:

  For Architect:
  ```
  Review these implementation items for technical soundness. For each item, provide PASS or FAIL with evidence.
  Items: {C-ids with code references}
  ```

  For Critic:
  ```
  Review these implementation items for completeness and correctness. For each item, provide PASS or FAIL with evidence.
  Items: {C-ids with code references}
  ```

  Combine with the Reviewer's own assessment using the consensus rule:
  - 3/3 PASS = PASS
  - 2/3 PASS = PASS (log the dissenting perspective)
  - 1/3 or 0/3 PASS = FAIL

  ### 6. Compile Review Results

  Produce a summary of all items reviewed:

  ```
  REVIEW_SUMMARY:
    sprint: {N}
    mechanical: PASS | FAIL
    items:
      - id: C1, stages_passed: [mechanical, semantic], recommendation: FLIP
      - id: C3, stages_passed: [mechanical], failed_at: semantic, reason: "..."
      - id: C7, stages_passed: [mechanical, semantic, consensus], recommendation: FLIP
    flip_candidates: [C1, C7]
    needs_fix: [C3]
  ```

  Save this to `discussion/review-sprint-{N}.md`.

  ### 7. Transition to Retro

  Update status.yaml:
  ```yaml
  skill: build
  sprint: {N}
  phase: retro
  step: "1"
  detail: "Starting retrospective analysis"
  next: "Dispatch retro-analyst with sprint data"
  ```

  Log transition to build-progress.md: "Review complete. {count} items ready to flip."
  ```

- [ ] **Step 2: Commit**

  `git add skills/build/review-phase.md && git commit -m "feat: create review phase instructions with 3-stage pipeline"`

### Task 3.5: Create retro-phase.md

- **Files**: `skills/build/retro-phase.md`
- **Spec items**: C11, C19
- **Depends on**: none

- [ ] **Step 1: Write retro-phase.md**

  Create `skills/build/retro-phase.md` with the following content:

  ```markdown
  # Retro Phase — Detailed Instructions

  The Retro phase produces a structured analysis of the sprint that directly feeds Level-up decisions. It looks backward to improve what comes next.

  ## Step-by-Step

  ### 1. Gather Sprint Data

  Collect inputs for the retro-analyst agent:
  - Review results from `discussion/review-sprint-{N}.md`
  - Builder agent outputs (task results, errors, notes) from build-progress.md
  - Current spec.yaml state
  - Previous retro reports from `discussion/retro-sprint-*.md` (for trend analysis)
  - Current project `.claude/` files (agents, skills, rules)

  ### 2. Dispatch Retro-Analyst Agent

  Dispatch the **Retro Analyst** agent with:

  ```
  SPRINT: {N}
  REVIEW_RESULTS: {contents of discussion/review-sprint-{N}.md}
  BUILD_PROGRESS: {relevant sprint entries from build-progress.md}
  SPEC_STATE:
    total_items: {count}
    passing: {count}
    failing: {count}
    superseded: {count}
    items_attempted_this_sprint: {list of C-ids and outcomes}
  PREVIOUS_RETROS: {summary of key findings from previous retro reports}
  PROJECT_SETUP:
    agents: {list of existing .claude/agents/}
    skills: {list of existing .claude/skills/}
    rules: {summary of CLAUDE.md and .claude/ rules}
  ```

  ### 3. Process Retro Output

  Check the Retro Analyst's status:
  - **DONE**: Save the full report to `discussion/retro-sprint-{N}.md`. Proceed to Level-up.
  - **DONE_WITH_CONCERNS**: Save report and note which sections had incomplete data.
  - **NEEDS_CONTEXT**: Provide missing sprint data. Re-dispatch.
  - **BLOCKED**: Log the issue. Proceed to Level-up with an empty retro (no mutations proposed).

  ### 4. Extract Actionable Items

  From the retro report, extract:
  1. **Proposed Mutations**: These go to Level-up for spec.yaml application
  2. **Proposed Level-ups**: These go to Level-up for project file creation/update
  3. **Broken Assumptions**: These inform the next sprint's Brief phase
  4. **Knowledge Gaps**: These inform the next sprint's JIT knowledge gathering

  ### 5. Log to Build-Progress

  Append retro summary to build-progress.md:
  ```markdown
  ## Sprint {N} — Retro — {timestamp}
  - Broken assumptions: {count} — {brief list}
  - Emerged patterns: {count} — {brief list}
  - Knowledge gaps: {count}
  - Proposed mutations: {count} (ADD: {n}, SUPERSEDE: {n})
  - Proposed level-ups: {count} (agent: {n}, skill: {n}, rule: {n})
  ```

  ### 6. Transition to Level-up

  Update status.yaml:
  ```yaml
  skill: build
  sprint: {N}
  phase: level-up
  step: "1"
  detail: "Applying spec mutations and project evolution"
  next: "Apply proposed mutations, then execute 5-step level-up flow"
  ```
  ```

- [ ] **Step 2: Commit**

  `git add skills/build/retro-phase.md && git commit -m "feat: create retro phase instructions with structured report extraction"`

### Task 3.6: Create level-up-phase.md

- **Files**: `skills/build/level-up-phase.md`
- **Spec items**: C4, C5, C6, C17, C18, C20
- **Depends on**: none

- [ ] **Step 1: Write level-up-phase.md**

  Create `skills/build/level-up-phase.md` with the following content:

  ```markdown
  # Level-up Phase — Detailed Instructions

  The Level-up phase evolves the spec and the project's knowledge base. It applies spec mutations from the retro, flips passes for verified items, and creates or updates project-scoped agents, skills, and rules.

  ## Step-by-Step

  ### 1. Apply Spec Mutations (D3: ADD or SUPERSEDE only)

  For each Proposed Mutation from the retro report:

  #### ADD Operation
  1. Generate a new C-id (next sequential number)
  2. Add the item to spec.yaml with `passes: false`
  3. Associate it with the correct section and phase
  4. Append to `spec-mutations.log`:
     ```
     {ISO-timestamp}\tSPRINT:{N}\tADD\tchecklist.{new-id}\t"{description}"\tREASON: {rationale from retro}
     ```

  #### SUPERSEDE Operation
  1. In spec.yaml, add to the original item: `status: superseded` and `superseded_by: {new-C-id}`
  2. Add the replacement item with `passes: false`
  3. Append to `spec-mutations.log`:
     ```
     {ISO-timestamp}\tSPRINT:{N}\tSUPERSEDE\tchecklist.{old-id}\t"superseded_by: {new-id}"\tREASON: {rationale}
     ```

  #### Validation Rules
  - Never ADD an item that duplicates an existing non-superseded item
  - Never SUPERSEDE an already-superseded item
  - Every ADD must reference an existing section (S-id)
  - Log EVERY mutation — no silent changes

  ### 2. Flip Passes for Verified Items

  For each flip candidate from the Review phase:
  1. Change `passes: false` to `passes: true` in spec.yaml
  2. Append to `spec-mutations.log`:
     ```
     {ISO-timestamp}\tSPRINT:{N}\tFLIP\tchecklist.{id}\tpasses:true\tREASON: Passed 3-stage review
     ```

  ### 3. Execute 5-Step Level-up Flow

  For each Proposed Level-up from the retro report:

  #### Step a: Analyze
  - Read the retro report's Emerged Patterns and Knowledge Gaps sections
  - Determine what kind of knowledge this represents
  - Is it a persona (WHO — expertise, behavior)? → Agent candidate
  - Is it a procedure (WHAT/HOW — steps, gates, checklists)? → Skill candidate
  - Is it a simple constraint (convention, fact)? → Rule candidate

  #### Step b: Search Community References
  Search live at runtime for existing implementations:

  Use WebSearch to find existing agents/skills that match the identified pattern:

  ```
  WebSearch("site:github.com ComposioHQ/awesome-claude-skills {pattern_name}")
  WebSearch("site:github.com wshobson/agents {pattern_name}")
  WebSearch("{pattern_name} claude code agent OR skill")
  ```

  If a result is found, use WebFetch to read the raw markdown:
  ```
  WebFetch("https://raw.githubusercontent.com/{owner}/{repo}/main/{path_to_file}")
  ```

  Parse the fetched content for: frontmatter structure, prompt patterns, workflow steps.

  If a match is found: adapt the existing pattern rather than creating from scratch.
  If search fails (network error, timeout): proceed to create from scratch and log the fallback to build-progress.md.

  #### Step c: Check Existing Project Files
  ```bash
  PROJECT_ROOT=$(git rev-parse --show-toplevel)
  # Check for overlapping agents
  ls "$PROJECT_ROOT/.claude/agents/" 2>/dev/null
  # Check for overlapping skills
  ls "$PROJECT_ROOT/.claude/skills/" 2>/dev/null
  # Check CLAUDE.md for existing rules
  cat "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null | head -100
  cat "$PROJECT_ROOT/.claude/CLAUDE.md" 2>/dev/null | head -100
  ```

  If an existing file covers similar ground: UPDATE it rather than creating a duplicate.

  #### Step d: Decide Type
  Apply the taxonomy:
  - **Agent** = Persona: Has expertise domain, behavioral traits, response methodology. Gets own context window. Is stateless. Description ends with activation trigger.
  - **Skill** = Knowledge package: Step-by-step procedures, checklists, gates, anti-patterns. Encodes non-obvious knowledge. Owns workflows.
  - **Rule** = Simple constraint: One-liner conventions. Added to CLAUDE.md or .claude/ rules.

  #### Step e: Create OR Update

  **For Agents** — create at `{PROJECT_ROOT}/.claude/agents/{name}.md`:
  ```markdown
  ---
  name: {name}
  description: {what it does}. Use PROACTIVELY for {activation trigger}.
  ---

  {System prompt body with rules, protocol, and output format}
  ```

  **For Skills** — create at `{PROJECT_ROOT}/.claude/skills/{name}/SKILL.md`:
  ```markdown
  ---
  name: {name}
  description: {when and why to use this skill}
  ---

  {Structured workflow with steps, gates, and anti-patterns}
  ```

  **For Rules** — append to `{PROJECT_ROOT}/CLAUDE.md` or `{PROJECT_ROOT}/.claude/CLAUDE.md`:
  ```markdown
  ## {Rule Category}
  - {Convention or constraint}
  ```

  ### 4. Quality Gate (D7)

  For every file created or updated:

  1. **Convention validation**: Verify the file follows Claude Code plugin conventions:
     - Agents: YAML frontmatter with `name`, `description` + system prompt body
     - Skills: YAML frontmatter with `name`, `description` + SKILL.md format
     - Rules: Valid markdown appended to the right file
  2. **Naming conflict check**: Ensure no naming collision with existing plugin files or built-in Claude Code commands
  3. **Syntax check**: For markdown files, verify frontmatter is valid YAML

  If validation fails: revert the file and log the failure.

  ### 5. Rollback Manifest (D7)

  Maintain `discussion/levelup-manifest.yaml` tracking all level-up actions:

  ```yaml
  sprint_1:
    - action: CREATE
      type: rule
      path: ".claude/CLAUDE.md"
      description: "Added API error wrapper convention"
      timestamp: "2026-03-13T14:30:00Z"
  sprint_2:
    - action: UPDATE
      type: agent
      path: ".claude/agents/auth-specialist.md"
      description: "Enhanced with OAuth2 PKCE flow knowledge"
      timestamp: "2026-03-14T10:15:00Z"
    - action: CREATE
      type: skill
      path: ".claude/skills/drizzle-migration/SKILL.md"
      description: "Formalized Drizzle migration procedure"
      timestamp: "2026-03-14T10:20:00Z"
  ```

  This manifest enables rollback if created files cause issues.

  ### 6. Log and Transition

  Append to build-progress.md:
  ```markdown
  ## Sprint {N} — Level-up — {timestamp}
  - Mutations applied: {count} (ADD: {n}, SUPERSEDE: {n}, FLIP: {n})
  - Level-ups: {count} (agent: {n}, skill: {n}, rule: {n})
  - Files: {list of created/updated paths}
  ```

  Update status.yaml:
  ```yaml
  skill: build
  sprint: {N}
  phase: converge
  step: "1"
  detail: "Running convergence checks"
  next: "Evaluate 5 convergence gates and pathology detection"
  ```
  ```

- [ ] **Step 2: Commit**

  `git add skills/build/level-up-phase.md && git commit -m "feat: create level-up phase instructions with 5-step flow and quality gate"`

### Task 3.7: Create converge-phase.md

- **Files**: `skills/build/converge-phase.md`
- **Spec items**: C2, C3, C12
- **Depends on**: none

- [ ] **Step 1: Write converge-phase.md**

  Create `skills/build/converge-phase.md` with the following content:

  ```markdown
  # Converge Phase — Detailed Instructions

  The Converge phase checks whether the sprint cycle should end. It runs 5 gates, detects pathologies, and either declares convergence or prepares for the next sprint.

  ## 5-Gate Convergence Check

  ALL gates must pass for convergence:

  ### Gate 1: Review Gate
  - Check: All spec.yaml items attempted this sprint passed 3-stage review
  - Source: `discussion/review-sprint-{N}.md`
  - Pass condition: No items have `recommendation: NEEDS_FIX` from this sprint's review

  ### Gate 2: Completeness Gate
  - Check: Every non-superseded checklist item has `passes: true`
  - Source: spec.yaml
  - Calculation:
    ```bash
    total=$(grep -c "passes:" spec.yaml)
    superseded=$(grep -c "status: superseded" spec.yaml)
    passing=$(grep -c "passes: true" spec.yaml)
    effective_total=$((total - superseded))
    # Pass if passing >= effective_total
    ```

  ### Gate 3: Regression Gate
  - Check: No items that previously had `passes: true` now have `passes: false`
  - Source: Compare current spec.yaml against `spec-mutations.log`
  - Calculation: Find any FLIP entries in the log where a previously-true item went back to false
  - If regression detected: log which items regressed and why

  ### Gate 4: Growth Gate (D6 — relaxed)
  - Check: Spec has evolved from initial version OR retro produced no actionable findings for 2 consecutive sprints
  - Source: `spec-mutations.log` for mutation count, `discussion/retro-sprint-*.md` for actionable findings
  - Pass conditions (any one):
    - At least 1 ADD or SUPERSEDE mutation exists in `spec-mutations.log`
    - The last 2 consecutive retro reports had empty "Proposed Mutations" AND empty "Proposed Level-ups" sections
  - Rationale: Correct plans should not be forced to mutate unnecessarily

  ### Gate 5: Confidence Gate
  - Check: No validation steps were skipped or errored out
  - Source: `discussion/review-sprint-{N}.md`
  - Pass condition: Every item has complete review results (no SKIPPED stages, no BLOCKED reviews)

  ## Pathology Detection

  Check for these patterns across the sprint history:

  ### Spinning (3+ similar errors)
  - Detection: Compare error messages from `build-progress.md` across last 3 sprints. If the same error (or error at the same file:line) appears 3+ times:
  - Recovery: Select an alternative implementation approach. Instruct the builder to try a fundamentally different strategy for the failing task.
  - Log: Append to build-progress.md: "PATHOLOGY: Spinning detected on {task/error}. Switching to alternative approach."

  ### Oscillation (contradictory changes)
  - Detection: Check `spec-mutations.log` for items that were FLIPped true then false (or vice versa) more than once.
  - Recovery: Step back and find a third approach that sidesteps the conflict entirely.
  - Log: Append to build-progress.md: "PATHOLOGY: Oscillation detected on {C-id}. Seeking third approach."

  ### Stagnation (no progress for 3 sprints)
  - Detection: Compare spec.yaml passes count across last 3 sprints (from build-progress.md). If no items were flipped in 3 sprints AND no mutations occurred:
  - Recovery:
    - Calculate similarity: `passing / effective_total`
    - If similarity >= 0.95: declare convergence (close enough)
    - If similarity < 0.95: force a fresh approach — re-analyze failing items, dispatch researcher for new context
  - Log: Append to build-progress.md: "PATHOLOGY: Stagnation detected. Similarity: {ratio}."

  ## Sprint Hard Cap (D11)

  If sprint number >= 30:
  - Stop execution regardless of gate results
  - Log final state to build-progress.md: "Hard cap reached at sprint 30."
  - Set `skill: none` in status.yaml
  - Report final summary with remaining failing items

  ## Convergence Reached

  If all 5 gates pass:

  1. Log to build-progress.md: "Build converged! All spec items passing."

  2. Set status.yaml:
     ```yaml
     skill: none
     sprint: {N}
     phase: done
     detail: "Converged — all gates passed"
     next: "Build complete"
     ```

  3. Append final summary to build-progress.md:
     ```markdown
     ## CONVERGENCE — Sprint {N} — {timestamp}
     - Total sprints: {N}
     - Spec items: {passing}/{total} passing ({superseded} superseded)
     - Mutations applied: {total from spec-mutations.log}
     - Level-ups created: {count from levelup-manifest.yaml}
     - Pathologies encountered: {list}
     ```

  4. Print summary to user.

  ## Not Yet Converged

  If any gate fails and no hard cap reached:

  1. Log which gates failed and why in build-progress.md
  2. Identify which items to target next sprint (failing items, regressed items)
  3. Update status.yaml for the next sprint:
     ```yaml
     skill: build
     sprint: {N+1}
     phase: brief
     step: "0"
     detail: "Preparing sprint {N+1}"
     next: "Begin Brief phase — gather context and plan"
     ```

  4. Log to build-progress.md: "Sprint {N} complete. {remaining} items left. Continuing..."

  The stop hook will read status.yaml and auto-continue to the next sprint.
  ```

- [ ] **Step 2: Commit**

  `git add skills/build/converge-phase.md && git commit -m "feat: create converge phase instructions with 5-gate check and pathology detection"`

---

## Phase 4: Stop Hook & Error Tracking

> Depends on: Phase 1 (status.yaml at plan root, dual-path reading), Phase 3 (build skill writes status.yaml)
> Parallel: tasks 4.1 and 4.2 can run concurrently; task 4.3 depends on both
> Delivers: Stop hook auto-continues build execution, error tracker detects rate limits
> Spec sections: S5

### Task 4.1: Create stop-hook.sh

- **Files**: `scripts/stop-hook.sh`
- **Spec items**: C21, C22
- **Depends on**: none

- [ ] **Step 1: Write the stop hook script**

  Create `scripts/stop-hook.sh` with the following content:

  ```bash
  #!/usr/bin/env bash
  # Stop hook: Auto-continue build execution with circuit breakers
  # Reads status.yaml from plan root. If build is active, blocks the stop
  # and injects a continuation prompt via the "reason" field.
  #
  # Circuit breakers:
  # 1. Max 50 reinforcements per session
  # 2. Rate limit detection (from error-tracker.sh output)
  # 3. stop_hook_active + high count (proxy for context pressure)
  # 4. Sprint hard cap (30)

  INPUT=$(cat)
  STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

  PLANS_DIR="docs/plans"

  # Find active build status.yaml (at plan root, not discussion/)
  status_file=""
  if [ -d "$PLANS_DIR" ]; then
    latest_mtime=0
    for dir in "$PLANS_DIR"/*/; do
      [ -d "$dir" ] || continue
      candidate="${dir}status.yaml"
      [ -f "$candidate" ] || continue
      skill=$(grep "^skill:" "$candidate" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
      [ "$skill" = "build" ] || continue
      if stat -f %m "$candidate" >/dev/null 2>&1; then
        mtime=$(stat -f %m "$candidate")
      else
        mtime=$(stat -c %Y "$candidate")
      fi
      if [ "$mtime" -gt "$latest_mtime" ]; then
        latest_mtime=$mtime
        status_file=$candidate
      fi
    done
  fi

  # No active build — allow stop
  [ -z "$status_file" ] && exit 0

  plan_dir=$(dirname "$status_file")
  COUNTER_FILE="${plan_dir}/discussion/.stop-hook-counter"
  ERROR_FILE="${plan_dir}/discussion/.recent-errors.json"

  # Ensure discussion dir exists
  mkdir -p "${plan_dir}/discussion"

  # Read and increment counter
  count=0
  [ -f "$COUNTER_FILE" ] && count=$(cat "$COUNTER_FILE" 2>/dev/null)
  count=$((count + 1))
  echo "$count" > "$COUNTER_FILE"

  # Circuit breaker 1: Max 50 reinforcements
  if [ "$count" -ge 50 ]; then
    exit 0
  fi

  # Circuit breaker 2: Rate limit detection
  if [ -f "$ERROR_FILE" ]; then
    recent_429=$(grep -ci "429\|rate.limit\|rate limit\|quota" "$ERROR_FILE" 2>/dev/null || echo "0")
    if [ "$recent_429" -gt 0 ]; then
      exit 0
    fi
  fi

  # Circuit breaker 3: stop_hook_active + high count (context pressure proxy)
  if [ "$STOP_ACTIVE" = "true" ] && [ "$count" -ge 30 ]; then
    exit 0
  fi

  # Circuit breaker 4: Sprint hard cap
  sprint=$(grep "^sprint:" "$status_file" 2>/dev/null | head -1 | sed 's/^sprint: *//; s/"//g')
  if [ -n "$sprint" ] && [ "$sprint" -ge 30 ] 2>/dev/null; then
    exit 0
  fi

  # Build is active — block the stop and inject continuation prompt
  phase=$(grep "^phase:" "$status_file" 2>/dev/null | head -1 | sed 's/^phase: *//; s/"//g')
  next_action=$(grep "^next:" "$status_file" 2>/dev/null | head -1 | sed 's/^next: *//; s/"//g')
  detail=$(grep "^detail:" "$status_file" 2>/dev/null | head -1 | sed 's/^detail: *//; s/"//g')

  # Read spec progress
  spec_progress=""
  spec_file="${plan_dir}/spec.yaml"
  if [ -f "$spec_file" ]; then
    total=$(grep -c "passes:" "$spec_file" 2>/dev/null || echo "0")
    passed=$(grep -c "passes: true" "$spec_file" 2>/dev/null || echo "0")
    spec_progress=" Spec: ${passed}/${total} passing."
  fi

  # Build the continuation reason (this IS the prompt for the next turn)
  reason="Build active: Sprint ${sprint:-?}, ${phase:-?} phase.${spec_progress}"
  [ -n "$detail" ] && reason="${reason} Current: ${detail}."
  [ -n "$next_action" ] && reason="${reason} Next: ${next_action}."
  reason="${reason} Continue with /robro:build to resume."

  # Output the block decision
  jq -n --arg reason "$reason" '{"decision":"block","reason":$reason}'
  ```

- [ ] **Step 2: Make executable**

  Run: `chmod +x /Users/skywrace/Documents/github.com/JWWon/robro/scripts/stop-hook.sh`

- [ ] **Step 3: Verify syntax**

  Run: `bash -n /Users/skywrace/Documents/github.com/JWWon/robro/scripts/stop-hook.sh`

  Expected: No output (clean syntax)

- [ ] **Step 4: Commit**

  `git add scripts/stop-hook.sh && git commit -m "feat: create stop hook for build auto-continue with 4 circuit breakers"`

### Task 4.2: Create error-tracker.sh

- **Files**: `scripts/error-tracker.sh`
- **Spec items**: C22
- **Depends on**: none

- [ ] **Step 1: Write the error tracker script**

  Create `scripts/error-tracker.sh` with the following content:

  ```bash
  #!/usr/bin/env bash
  # PostToolUseFailure hook: Track recent errors for rate limit detection
  # Writes recent errors to discussion/.recent-errors.json so the stop hook
  # can detect rate limiting patterns and bail gracefully.

  INPUT=$(cat)
  ERROR=$(echo "$INPUT" | jq -r '.error // ""' 2>/dev/null)
  TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

  # Skip if no error
  [ -z "$ERROR" ] && exit 0

  PLANS_DIR="docs/plans"

  # Find active build status.yaml
  status_file=""
  if [ -d "$PLANS_DIR" ]; then
    for dir in "$PLANS_DIR"/*/; do
      [ -d "$dir" ] || continue
      candidate="${dir}status.yaml"
      [ -f "$candidate" ] || continue
      skill=$(grep "^skill:" "$candidate" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
      [ "$skill" = "build" ] && status_file=$candidate && break
    done
  fi

  # No active build — exit silently
  [ -z "$status_file" ] && exit 0

  plan_dir=$(dirname "$status_file")
  ERROR_FILE="${plan_dir}/discussion/.recent-errors.json"

  # Ensure discussion dir exists
  mkdir -p "${plan_dir}/discussion"

  # Get current timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Create or update the error file (keep last 20 errors)
  if [ -f "$ERROR_FILE" ]; then
    # Read existing, append new, keep last 20
    existing=$(cat "$ERROR_FILE")
    new_entry=$(jq -n --arg ts "$timestamp" --arg tool "$TOOL" --arg err "$ERROR" \
      '{"timestamp":$ts,"tool":$tool,"error":$err}')
    echo "$existing" | jq --argjson entry "$new_entry" \
      '. + [$entry] | .[-20:]' > "$ERROR_FILE" 2>/dev/null
  else
    # Create new file with first entry
    jq -n --arg ts "$timestamp" --arg tool "$TOOL" --arg err "$ERROR" \
      '[{"timestamp":$ts,"tool":$tool,"error":$err}]' > "$ERROR_FILE"
  fi

  exit 0
  ```

- [ ] **Step 2: Make executable**

  Run: `chmod +x /Users/skywrace/Documents/github.com/JWWon/robro/scripts/error-tracker.sh`

- [ ] **Step 3: Verify syntax**

  Run: `bash -n /Users/skywrace/Documents/github.com/JWWon/robro/scripts/error-tracker.sh`

  Expected: No output (clean syntax)

- [ ] **Step 4: Commit**

  `git add scripts/error-tracker.sh && git commit -m "feat: create error tracker hook for rate limit detection"`

### Task 4.3: Update hooks.json with Stop and PostToolUseFailure events

- **Files**: `hooks/hooks.json`
- **Spec items**: C21, C22, C29
- **Depends on**: Tasks 4.1, 4.2

- [ ] **Step 1: Add Stop and PostToolUseFailure events to hooks.json**

  Add the following two new event sections to `hooks/hooks.json`, after the existing `PreCompact` section and before the closing `}`:

  Add a `Stop` event:
  ```json
  "Stop": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/stop-hook.sh",
          "timeout": 5000
        }
      ]
    }
  ]
  ```

  Add a `PostToolUseFailure` event:
  ```json
  "PostToolUseFailure": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/error-tracker.sh",
          "timeout": 3000
        }
      ]
    }
  ]
  ```

  The final hooks.json should have these event sections: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PreCompact, Stop, PostToolUseFailure.

- [ ] **Step 2: Validate JSON syntax**

  Run: `jq . /Users/skywrace/Documents/github.com/JWWon/robro/hooks/hooks.json`

  Expected: Pretty-printed valid JSON with all 7 event sections

- [ ] **Step 3: Commit**

  `git add hooks/hooks.json && git commit -m "feat: add Stop and PostToolUseFailure hook events for build auto-continue"`

---

## Phase 5: Remaining Hook Updates

> Depends on: Phase 1 (dual-path reading already done in session-start and pipeline-guard), Phase 3 (build skill defines what hooks need)
> Parallel: tasks 5.1, 5.2, and 5.3 can run concurrently
> Delivers: All existing hooks work correctly with the build phase
> Spec sections: S6

### Task 5.1: Update spec-gate.sh for build phase behavior

- **Files**: `scripts/spec-gate.sh`
- **Spec items**: C29
- **Depends on**: none

- [ ] **Step 1: Add build-aware behavior to spec-gate.sh**

  After the existing spec check (the `if [ "$has_spec" = false ]; then` block), add a build-phase check BEFORE the final `exit 0`. The new logic goes right after the existing `fi` that closes the `if [ "$has_spec" = false ]` block:

  ```bash
  # During active build, validate that file edits are within scope of current task
  if [ "$has_spec" = true ]; then
    # Check if build is active
    for dir in docs/plans/*/; do
      [ -d "$dir" ] || continue
      status_candidate="${dir}status.yaml"
      [ -f "$status_candidate" ] || continue
      build_skill=$(grep "^skill:" "$status_candidate" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
      if [ "$build_skill" = "build" ]; then
        phase=$(grep "^phase:" "$status_candidate" 2>/dev/null | head -1 | sed 's/^phase: *//; s/"//g')
        if [ "$phase" = "heads-down" ]; then
          echo "Build active (Heads-down phase). Ensure this edit is within the scope of the current task."
        fi
        break
      fi
    done
  fi
  ```

- [ ] **Step 2: Verify syntax**

  Run: `bash -n /Users/skywrace/Documents/github.com/JWWon/robro/scripts/spec-gate.sh`

  Expected: No output (clean syntax)

- [ ] **Step 3: Commit**

  `git add scripts/spec-gate.sh && git commit -m "feat: add build phase awareness to spec-gate hook"`

### Task 5.2: Update keyword-detector.sh with build triggers

- **Files**: `scripts/keyword-detector.sh`
- **Spec items**: C29
- **Depends on**: none

- [ ] **Step 1: Add /robro:build suggestion to Tier 1**

  In the Tier 1 case block, after the `*"robro:spec"*` case, add:

  ```bash
    *"robro build"*|*"robro:build"*)
      echo "Suggestion: Use /robro:build to start autonomous implementation of the plan."
      exit 0
      ;;
  ```

- [ ] **Step 2: Update Tier 3 implementation triggers**

  Replace the Tier 3 section's `if [ "$has_spec" = false ]; then` block with build-aware logic:

  ```bash
  for pattern in "${impl_patterns[@]}"; do
    if echo "$PROMPT_LOWER" | grep -q "$pattern"; then
      if [ "$has_spec" = true ]; then
        echo "A spec exists. Consider using /robro:build for structured autonomous implementation."
      elif [ "$has_spec" = false ]; then
        echo "No spec found in docs/plans/. Consider running /robro:idea then /robro:spec before implementing to ensure clear requirements and a validated plan."
      fi
      exit 0
    fi
  done
  ```

- [ ] **Step 3: Verify syntax**

  Run: `bash -n /Users/skywrace/Documents/github.com/JWWon/robro/scripts/keyword-detector.sh`

  Expected: No output (clean syntax)

- [ ] **Step 4: Commit**

  `git add scripts/keyword-detector.sh && git commit -m "feat: add build triggers and /robro:build suggestion to keyword detector"`

### Task 5.3: Update drift-monitor.sh for build phase

- **Files**: `scripts/drift-monitor.sh`
- **Spec items**: C29
- **Depends on**: none

- [ ] **Step 1: Add build-phase context to drift-monitor.sh**

  After the existing `if [ -n "$matched_spec" ]; then` block and its contents, but before the final `fi`, add build-specific context:

  ```bash
    # During active build, show current task context
    status_candidate="${plan_dir}/status.yaml"
    if [ -f "$status_candidate" ]; then
      build_skill=$(grep "^skill:" "$status_candidate" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
      if [ "$build_skill" = "build" ]; then
        sprint=$(grep "^sprint:" "$status_candidate" 2>/dev/null | head -1 | sed 's/^sprint: *//; s/"//g')
        phase=$(grep "^phase:" "$status_candidate" 2>/dev/null | head -1 | sed 's/^phase: *//; s/"//g')
        echo "Build sprint ${sprint}, ${phase} phase."
      fi
    fi
  ```

- [ ] **Step 2: Verify syntax**

  Run: `bash -n /Users/skywrace/Documents/github.com/JWWon/robro/scripts/drift-monitor.sh`

  Expected: No output (clean syntax)

- [ ] **Step 3: Commit**

  `git add scripts/drift-monitor.sh && git commit -m "feat: add build sprint context to drift-monitor hook"`

---

## Phase 6: Integration Verification

> Depends on: Phases 1-5
> Parallel: tasks 6.1 and 6.2 can run concurrently
> Delivers: End-to-end verification that the plugin loads and all components are wired correctly
> Spec sections: S6

### Task 6.1: Verify plugin loads with all new components

- **Files**: none (verification only)
- **Spec items**: C29, C30
- **Depends on**: all previous phases

- [ ] **Step 1: Check all new files exist**

  Run:
  ```bash
  ls -la /Users/skywrace/Documents/github.com/JWWon/robro/skills/build/SKILL.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/skills/build/brief-phase.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/skills/build/heads-down-phase.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/skills/build/review-phase.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/skills/build/retro-phase.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/skills/build/level-up-phase.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/skills/build/converge-phase.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/agents/builder.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/agents/reviewer.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/agents/retro-analyst.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/agents/conflict-resolver.md \
         /Users/skywrace/Documents/github.com/JWWon/robro/scripts/stop-hook.sh \
         /Users/skywrace/Documents/github.com/JWWon/robro/scripts/error-tracker.sh
  ```

  Expected: All 13 files listed with valid sizes

- [ ] **Step 2: Verify all scripts are executable**

  Run:
  ```bash
  for f in /Users/skywrace/Documents/github.com/JWWon/robro/scripts/*.sh; do
    [ -x "$f" ] && echo "OK: $f" || echo "MISSING +x: $f"
  done
  ```

  Expected: All scripts show "OK"

- [ ] **Step 3: Verify hooks.json is valid and complete**

  Run: `jq 'keys_unsorted' /Users/skywrace/Documents/github.com/JWWon/robro/hooks/hooks.json`

  Expected: Output includes `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PreCompact`, `Stop`, `PostToolUseFailure` (via the `hooks` top-level key)

  Run: `jq '.hooks | keys' /Users/skywrace/Documents/github.com/JWWon/robro/hooks/hooks.json`

  Expected: Array with all 7 event types

- [ ] **Step 4: Verify all shell scripts pass syntax check**

  Run:
  ```bash
  for f in /Users/skywrace/Documents/github.com/JWWon/robro/scripts/*.sh; do
    bash -n "$f" 2>&1 && echo "PASS: $f" || echo "FAIL: $f"
  done
  ```

  Expected: All scripts PASS

- [ ] **Step 5: Test plugin loading**

  Run: `cd /Users/skywrace/Documents/github.com/JWWon/robro && claude --plugin-dir . --debug 2>&1 | head -50`

  Expected: No errors related to skills/build, agents/builder, agents/reviewer, agents/retro-analyst, agents/conflict-resolver, or hooks

### Task 6.2: Final documentation review

- **Files**: `CLAUDE.md`, `.claude/CLAUDE.md`
- **Spec items**: C27, C28
- **Depends on**: all previous phases

- [ ] **Step 1: Verify CLAUDE.md references are consistent**

  Check that all new files are documented:

  Run: `grep -c "build" /Users/skywrace/Documents/github.com/JWWon/robro/CLAUDE.md`

  Expected: Multiple matches for the build skill, builder agent, spec mutation rules

  Run: `grep -c "build" /Users/skywrace/Documents/github.com/JWWon/robro/.claude/CLAUDE.md`

  Expected: Multiple matches for build phase rules, agents, hooks

- [ ] **Step 2: Verify Pipeline Flow is updated**

  Run: `grep "robro:build" /Users/skywrace/Documents/github.com/JWWon/robro/CLAUDE.md`

  Expected: The updated pipeline flow showing `/robro:build` as the final step

- [ ] **Step 3: Verify Active Hooks table is complete**

  Run: `grep -c "stop-hook\|error-tracker" /Users/skywrace/Documents/github.com/JWWon/robro/.claude/CLAUDE.md`

  Expected: 2 (both new hooks documented)

---

## Pre-mortem

| Failure Scenario | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Stop hook creates infinite loop | Med | High | 4 circuit breakers: max 50 reinforcements, rate limit detection, stop_hook_active + high count, sprint hard cap 30. The `stop_hook_active` flag is the primary defense. |
| Worktree merge conflicts crash the build | Med | Med | Conflict resolver agent with sequential fallback. If resolution fails, abort merge and re-execute sequentially. Post-merge mechanical check catches broken merges. |
| Level-up creates invalid .claude/ files | Med | Med | Quality gate validates convention compliance. Rollback manifest in discussion/levelup-manifest.yaml enables revert. Naming conflict check prevents collisions. |
| Spec mutation causes semantic drift | Low | High | D3 restricts to ADD/SUPERSEDE only — no in-place edits. Superseded items preserve original text. Append-only spec-mutations.log provides full audit trail. Regression gate catches regressions. |
| Context compression loses build state | Med | Med | pre-compact hook tells agent to persist state. status.yaml at plan root + build-progress.md provide recovery. session-start hook restores context. |
| Builder agent produces incorrect code | Med | Med | 3-stage review catches issues: mechanical (free), semantic (LLM), consensus (multi-agent). Failed items return to the pool for next sprint. |
| JIT knowledge fetch is slow or fails | Low | Low | context7 is pre-fetched during Brief phase, not blocking during Heads-down. Web search as fallback. Knowledge persisted to project rules for future sprints. |
| Status.yaml dual-path migration breaks existing workflows | Low | High | Dual-path reading checks both locations. Existing idea/spec skills continue writing to discussion/status.yaml. Only build writes to plan root. No breaking change. |
| Retro produces no useful insights | Low | Low | Growth gate relaxed (D6): 2 consecutive no-action retros allow convergence. Shallow retros don't force unnecessary mutations. |
| User unaware of long-running build state | Low | Low | Notifications deferred (D1). User can check status.yaml or build-progress.md manually. All state transitions logged. |

## Open Questions

1. **Auto-compaction timing**: When auto-compaction fires at ~83.5% context, does the Stop hook fire BEFORE or AFTER compaction? If after, the stop hook's counter file may be stale briefly. Mitigation: counter file persists on disk regardless of timing.

2. **Worktree cleanup on crash**: If a worktree-isolated subagent crashes or times out, cleanup behavior is undocumented. The build skill should include explicit cleanup (list and remove stale worktrees) during the Brief phase.

3. **Context7 rate limits**: Free tier capacity is not publicly documented. For parallel builders each fetching docs, rate limits could be hit. Mitigation: pre-fetch during Brief phase and pass as context rather than each builder fetching independently.

4. **Max `reason` string length in Stop hook**: No documented limit. Very long reasons could consume context. Current implementation keeps reasons under 300 characters.

5. **Agent-mediated conflict resolution accuracy**: Untested at scale with realistic conflicts. The sequential fallback (abort merge, re-execute sequentially) is the safety net.

6. **Cost management**: No budget guard is implemented. Long-running builds with many sprints and multi-agent consensus can be expensive. A future enhancement could add cost tracking and budget limits.

**Status**: DONE
