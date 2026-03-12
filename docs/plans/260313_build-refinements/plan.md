---
spec: spec.yaml
idea: idea.md
created: 2026-03-13T00:00:00Z
---

# Implementation Plan: Build Skill Refinements

## Overview
Surgical edits to the robro build skill introducing a 3-path execution model: inline builders (no isolation), worktree-isolated builders (via Agent tool dispatch-time `isolation` parameter), and Claude Code Teams (non-overlapping file sets for multi-topic coordination). Squash merge + auto-cleanup for the isolated path. Setup skill gains settings.json env var management.

## Tech Context
- **Plugin framework**: Claude Code plugin system with markdown agents (`agents/*.md`), markdown skills (`skills/*/SKILL.md`), shell hook scripts (`scripts/*.sh`)
- **Agent dispatch**: The `Agent` tool accepts `isolation: "worktree"` as a dispatch-time parameter — this enables dynamic per-dispatch isolation without agent frontmatter
- **Teams API**: Experimental Claude Code feature. `TeamCreate` + `TaskCreate` + `SendMessage`. Teammates are restricted to 20 tools (no Agent tool, no TeamCreate). Non-overlapping file assignments recommended.
- **Settings**: `.claude/settings.json` with `env` block for experimental feature flags. `jq` for safe merge. Claude Code auto-backs up config files.

## Architecture Decision Record
| Decision | Rationale | Alternatives Considered | Trade-offs |
| --- | --- | --- | --- |
| Remove `isolation: worktree` from builder.md frontmatter | Agent tool's dispatch-time `isolation` parameter enables per-dispatch choice. Frontmatter forces worktree on every dispatch. | Keep frontmatter + create second builder-inline.md | One agent file is simpler; dispatch-time parameter is more flexible |
| 3-path execution (inline, isolated, Teams) | Inline for speed on small tasks, isolated for parallel safety, Teams for multi-topic coordination | Agent-only (no Teams), Teams-first (no isolation) | More routing complexity but matches task characteristics precisely |
| Brief phase classifies execution path per level | Brief already has file-overlap detection (D9). Natural place to add path routing. | Heads-down decides dynamically | Brief pre-planning enables better resource allocation |
| Squash merge only for isolated path | Inline writes to working tree directly (no branches). Teams use non-overlapping files (no branches). Only isolated dispatches create worktree branches. | Squash merge for all paths | Matches where branches actually exist |
| Teams use non-overlapping file sets, not worktrees | Teammates lack the Agent tool — cannot spawn worktree-isolated subagents. EnterWorktree is for explicit user use. | Force EnterWorktree in teammate prompts | Non-overlapping is the official recommended pattern (OMC does this too) |
| Drop CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD | Not found in any official docs. Undocumented env var. | Add it anyway | Avoids setting unknown flags in user projects |

## File Map
| File | Action | Responsibility |
| --- | --- | --- |
| `agents/builder.md` | modify | Remove isolation frontmatter, update description and system prompt for dual-mode (inline or isolated) |
| `agents/conflict-resolver.md` | modify | Update description to reflect isolated-dispatch merge model instead of builder-frontmatter worktrees |
| `skills/build/heads-down-phase.md` | modify | Rewrite for 3-path execution: inline, isolated, Teams |
| `skills/build/brief-phase.md` | modify | Add execution path classification per level, stale worktree cleanup, remove "max worktrees" cap |
| `skills/build/SKILL.md` | modify | Update hard gate, Phase 2 summary for new execution model |
| `skills/setup/SKILL.md` | modify | Add settings.json env var management step |
| `scripts/pipeline-guard.sh` | modify | Update heads-down guidance text (line 102) |
| `CLAUDE.md` | modify | Update builder agent description (line 89) |
| `.claude/CLAUDE.md` | modify | Update builder and conflict-resolver agent descriptions (lines 101-104) |

## Phase 1: Core Agent Updates
> Depends on: none
> Parallel: tasks 1.1 and 1.2 can run concurrently
> Delivers: Builder agent works inline by default; conflict-resolver updated for new merge model
> Spec sections: S1, S3

### Task 1.1: Update builder.md — remove worktree isolation, update for dual-mode
- **Files**: `agents/builder.md`
- **Spec items**: C1
- **Depends on**: none
- **Action**:
  1. Remove `isolation: worktree` from the YAML frontmatter (line 4)
  2. Update the `description` field to: `Executes implementation tasks following TDD methodology. Receives task context, JIT knowledge, and project rules. Writes code, runs tests, and commits verified changes. Use PROACTIVELY for any code implementation task during build sprints.`
  3. Replace line 7 system prompt text from `You are a Builder. Your job is to implement a single task from plan.md using strict TDD methodology. You operate in an isolated git worktree — your changes do not affect the main branch until explicitly merged by the parent skill.` to `You are a Builder. Your job is to implement a single task from plan.md using strict TDD methodology. You may operate either inline (directly on the working tree) or in a worktree-isolated environment — the build skill determines the execution mode at dispatch time.`
- **Test**: Read the file and verify: (a) no `isolation:` line in frontmatter, (b) description does not contain "worktree isolation", (c) system prompt references both inline and worktree modes
- **Verify**: `grep -c "isolation:" agents/builder.md` should output `0`
- **Commit**: `refactor(builder): remove forced worktree isolation, support dual-mode dispatch`

### Task 1.2: Update conflict-resolver.md — reflect new merge model
- **Files**: `agents/conflict-resolver.md`
- **Spec items**: C7
- **Depends on**: none
- **Action**:
  1. Update frontmatter `description` from `Resolves merge conflicts from parallel git worktree execution. Analyzes intent from both branches, understands task context, and produces clean resolutions. Falls back to sequential re-execution when automated resolution fails. Use PROACTIVELY for merge conflict resolution after worktree merges.` to `Resolves merge conflicts from parallel worktree-isolated agent dispatches. Analyzes intent from both branches, understands task context, and produces clean resolutions. Falls back to sequential re-execution when automated resolution fails. Use PROACTIVELY for merge conflict resolution after squash merges.`
  2. Update line 6 system prompt from `You are a Conflict Resolver. Your job is to resolve git merge conflicts that arise when merging parallel worktree branches back to the main branch. You understand the intent behind both sides of a conflict and produce a resolution that preserves both goals.` to `You are a Conflict Resolver. Your job is to resolve git merge conflicts that arise when squash-merging worktree branches (from isolated agent dispatches) back to the main branch. You understand the intent behind both sides of a conflict and produce a resolution that preserves both goals.`
- **Test**: Read the file. Description references "worktree-isolated agent dispatches" and "squash merges". System prompt references "squash-merging worktree branches".
- **Verify**: `grep -c "squash" agents/conflict-resolver.md` should output at least 2
- **Commit**: `refactor(conflict-resolver): update for squash merge model`

## Phase 2: Build Skill Phase Files
> Depends on: none
> Parallel: tasks 2.1, 2.2, and 2.3 can run concurrently
> Delivers: 3-path execution model in heads-down phase, updated level planning in brief phase, updated SKILL.md summary
> Spec sections: S1, S2

### Task 2.1: Rewrite heads-down-phase.md — 3-path execution model
- **Files**: `skills/build/heads-down-phase.md`
- **Spec items**: C2, C3, C4, C5, C6
- **Depends on**: none
- **Action**: Replace the entire file content with the following:

```markdown
# Heads-down Phase — Detailed Instructions

The Heads-down phase executes tasks through one of three execution paths per level, chosen during the Brief phase: **inline** (direct edits), **isolated** (worktree per agent), or **Teams** (multi-topic coordination).

## Execution Paths

### Path A: Inline (no isolation)

Used when: All tasks in the level are same-category, small-volume, and have no file overlap (classified by Brief phase).

#### a. Dispatch Inline Builders

For each task in the level, dispatch a **Builder** agent via the Agent tool **without** the `isolation` parameter:

```
Agent(
  subagent_type: "robro:builder",
  prompt: "<builder context below>",
  run_in_background: true
)
```

Builder context format:
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

Dispatch all tasks in the level simultaneously — no cap on inline agent count.

#### b. Collect Results

Wait for all builders to complete. For each builder, check Status:
- **DONE**: Task complete, changes committed on the working tree. Proceed.
- **DONE_WITH_CONCERNS**: Task complete with caveats. Log concerns in build-progress.md. Proceed.
- **NEEDS_CONTEXT**: Provide missing context and re-dispatch.
- **BLOCKED**: Log the blocker. Skip this task — it will be retried next sprint.

#### c. Post-Level Verification

After all inline builders complete, run a quick mechanical check:
```bash
{project build command}
{project test command}
```
If this fails, log the failure — the Review phase will catch it.

---

### Path B: Isolated Parallel (worktree per agent)

Used when: Tasks in the level have file overlap, or the level involves larger changes where isolation prevents interference.

#### a. Dispatch Isolated Builders

For each task, dispatch a **Builder** agent WITH the `isolation: "worktree"` parameter:

```
Agent(
  subagent_type: "robro:builder",
  prompt: "<builder context>",
  isolation: "worktree",
  run_in_background: true
)
```

Use the same builder context format as Path A. Dispatch all tasks in the level simultaneously.

#### b. Collect Results

Same status routing as Path A. For DONE/DONE_WITH_CONCERNS builders, their commits are on worktree branches (named `worktree-agent-{id}`).

#### c. Squash Merge + Cleanup

For each completed builder (status DONE or DONE_WITH_CONCERNS):

1. **Squash merge** the worktree branch:
   ```bash
   git merge --squash worktree-agent-{id}
   git commit -m "feat({task-id}): {task description}"
   ```

2. If merge succeeds, **immediately clean up**:
   ```bash
   git worktree remove .claude/worktrees/agent-{id}
   git branch -D worktree-agent-{id}
   ```

3. If **merge conflicts** arise, dispatch the **Conflict Resolver** agent:
   ```
   CONFLICT:
     base_branch: {current branch}
     branch_a: {previously merged branch}
     branch_b: worktree-agent-{id}
     task_a: {previously merged task description}
     task_b: {current task description}
     conflicting_files: {list from git status}
   ```

4. Check Conflict Resolver status:
   - **DONE**: Conflicts resolved. Complete the squash commit. Then clean up worktree + branch.
   - **BLOCKED**: Abort the merge (`git merge --abort`). Re-dispatch the builder inline (without isolation) on top of the current state — sequential fallback. Then clean up the stale worktree + branch.

5. After merging ALL branches in the level, run mechanical verification:
   ```bash
   {project build command}
   {project test command}
   ```

---

### Path C: Teams (multi-topic coordination)

Used when: Tasks in the level span multiple topics/sections and benefit from inter-agent coordination via messaging and shared task lists.

#### a. Create Team

```
TeamCreate(
  team_name: "sprint-{N}-level-{L}",
  description: "Sprint {N}, Level {L}: {brief description of topics}"
)
```

#### b. Create Tasks

For each task in the level:
```
TaskCreate(
  subject: "{task ID}: {description}",
  description: "FILES: {file list}\nSPEC_ITEMS: {C-ids}\nSTEPS:\n{steps from plan.md}\nJIT_KNOWLEDGE:\n{relevant docs}\nPROJECT_RULES:\n{conventions}\nBUILD_COMMANDS:\nbuild: {cmd}\ntest: {cmd}\nlint: {cmd}\n\nIMPORTANT: Only modify files listed in FILES. Message the team lead when done with your task result."
)
```

#### c. Spawn Teammates (max 5)

For each teammate needed (up to 5, or the number of tasks — whichever is smaller), use the **Task** tool (not TaskCreate — TaskCreate creates work items in the shared task list, while Task with `name` + `team_name` spawns a teammate instance):
```
Task(
  name: "builder-{N}",
  team_name: "sprint-{N}-level-{L}",
  prompt: "You are a builder on a team implementing plan tasks. Check TaskList for available tasks. Claim one with TaskUpdate, implement it following TDD, mark complete, then check for more. Message the team lead with your TASK_RESULT when done. Only modify files listed in your task — other teammates own other files.",
  model: "sonnet"
)
```

#### d. Monitor and Collect

Wait for teammates to complete. Monitor via:
1. **Direct messages** from teammates (automatic delivery)
2. **TaskList polling** to check task status
3. **TeammateIdle notifications** when teammates have no more work

Cross-validate completion signals — task status can lag.

#### e. Shutdown and Cleanup

```
SendMessage(type: "shutdown_request", recipient: "builder-1", content: "All tasks complete. Please shut down.")
# Repeat for each teammate
# Wait for shutdown_response with approve: true
TeamDelete()
```

#### f. Post-Level Verification

Run mechanical check on the working tree (teammates wrote directly):
```bash
{project build command}
{project test command}
```

---

## Log Progress

After each level completes, append to `build-progress.md`:
```markdown
## Sprint {N} — Heads-down Level {L} ({path}) — {timestamp}
- Execution path: {inline|isolated|teams}
- Task {id}: {PASS|FAIL|BLOCKED} — {brief summary}
- Merge conflicts: {count} ({resolved|fallback}) [isolated path only]
- Worktrees cleaned: {count} [isolated path only]
- Team: {team-name} ({N} teammates) [teams path only]
- Files changed: {count}
```

## Transition to Review

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

- **Test**: Read the file. Verify it contains all 3 paths (Path A, B, C), squash merge commands, cleanup commands, TeamCreate/TaskCreate/SendMessage usage, and no `--no-ff` references.
- **Verify**: `grep -c "git merge --squash" skills/build/heads-down-phase.md` ≥ 1 AND `grep -c "git merge --no-ff" skills/build/heads-down-phase.md` = 0
- **Commit**: `feat(heads-down): rewrite for 3-path execution — inline, isolated, Teams`

### Task 2.2: Update brief-phase.md — execution path classification + stale cleanup
- **Files**: `skills/build/brief-phase.md`
- **Spec items**: C2, C3, C4, C8
- **Depends on**: none
- **Action**:
  1. Add a new step between current step 1 and step 2: **"1.5. Clean Stale Worktrees"**:
     ```markdown
     ### 1.5. Clean Stale Worktrees

     Remove any worktrees and branches left over from previous sprints or crashed sessions:

     ```bash
     # List and remove stale agent worktrees
     for wt in $(git worktree list --porcelain | grep 'worktree.*\.claude/worktrees/agent-' | sed 's/worktree //'); do
       git worktree remove --force "$wt" 2>/dev/null
     done
     git worktree prune

     # Delete orphaned worktree branches
     git branch -l 'worktree-agent-*' | xargs -r git branch -D 2>/dev/null
     ```

     Log removals to build-progress.md.
     ```
  2. Replace step 5 "Plan Parallel Execution Levels" content. Replace line 79 (`3. Cap each level at 3-4 concurrent tasks (max worktrees)`) with the following expanded step:
     ```markdown
     3. **Classify execution path** for each level:
        - **Inline**: All tasks reference the same plan.md section, each task touches ≤3 files, AND no file overlaps between tasks in the level.
        - **Isolated**: Tasks have file overlaps between them, OR any single task touches >3 files.
        - **Teams**: Tasks span 3+ different plan.md sections or fundamentally different subsystems.
     4. Record the level plan with execution path in build-progress.md
     ```
- **Test**: Read the file. Verify stale worktree cleanup step exists, execution path classification logic exists (inline/isolated/Teams), and "max worktrees" cap is removed.
- **Verify**: `grep -c "max worktrees" skills/build/brief-phase.md` = 0 AND `grep -c "Classify execution path" skills/build/brief-phase.md` ≥ 1
- **Commit**: `feat(brief): add stale worktree cleanup and execution path classification`

### Task 2.3: Update SKILL.md — hard gate and Phase 2 summary
- **Files**: `skills/build/SKILL.md`
- **Spec items**: C2, C3
- **Depends on**: none
- **Action**:
  1. Replace the hard gate text (lines 27-31) from:
     ```
     <HARD_GATE>
     Implementation happens ONLY through dispatched builder agents in worktree isolation.
     The build skill orchestrates — it never writes implementation code directly.
     The build skill DOES write: status.yaml, build-progress.md, spec-mutations.log, spec.yaml mutations, and discussion/ files.
     </HARD_GATE>
     ```
     to:
     ```
     <HARD_GATE>
     Implementation happens ONLY through dispatched builder agents (inline or worktree-isolated) or Team teammates.
     The build skill orchestrates — it never writes implementation code directly.
     The build skill DOES write: status.yaml, build-progress.md, spec-mutations.log, spec.yaml mutations, and discussion/ files.
     </HARD_GATE>
     ```
  2. Replace Phase 2 summary (lines 75-81) from:
     ```
     Summary:
     - For each parallel level: dispatch builder agents (max 3-4 concurrent)
     - Each builder gets: task details, JIT knowledge, project rules, build commands
     - Builder agents use `isolation: worktree`
     - After each level: merge worktree branches back, resolve conflicts with conflict-resolver agent
     - After merge: run mechanical verification (build/test) on merged result
     - Log task outcomes to build-progress.md
     ```
     to:
     ```
     Summary:
     - For each level, use the execution path classified by Brief phase:
       - **Inline**: Dispatch builder agents without isolation (same-category, small, no file overlap)
       - **Isolated**: Dispatch builder agents with `isolation: "worktree"` (file overlap or larger scope). Squash merge + auto-cleanup after each.
       - **Teams**: Create team via TeamCreate for multi-topic coordination (max 5 teammates, non-overlapping file sets)
     - After each level: run mechanical verification (build/test) on merged result
     - Log task outcomes and execution path to build-progress.md
     ```
- **Test**: Read the file. Hard gate mentions "inline or worktree-isolated" and "Team teammates". Phase 2 summary describes all 3 paths.
- **Verify**: `grep -c "inline or worktree-isolated" skills/build/SKILL.md` ≥ 1
- **Commit**: `refactor(build-skill): update hard gate and phase 2 summary for 3-path model`

## Phase 3: Setup & Infrastructure
> Depends on: none
> Parallel: tasks 3.1 and 3.2 can run concurrently
> Delivers: Setup skill manages settings.json; pipeline-guard injects correct heads-down guidance
> Spec sections: S4, S5

### Task 3.1: Add settings.json step to setup SKILL.md
- **Files**: `skills/setup/SKILL.md`
- **Spec items**: C9
- **Depends on**: none
- **Action**: Add a new step between current Step 3 (.gitignore) and Step 4 (Completion Summary). The new step is "Step 3.5: Settings.json Configuration":

  Insert the following after the `### Step 3: .gitignore Configuration` section (before `### Step 4: Completion Summary`):

  ```markdown
  ### Step 3.5: Settings.json Configuration

  Configure `.claude/settings.json` to enable experimental features required by robro.

  #### 3.5a. Define Required Env Vars

  The setup skill ensures these env vars are present:

  | Env Var | Value | Purpose |
  |---------|-------|---------|
  | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `"1"` | Enable Claude Code Agent Teams for parallel execution |

  #### 3.5b. Check Existing Settings

  1. Use the Read tool to read `${PROJECT_ROOT}/.claude/settings.json`
  2. If the Read tool returns a "file does not exist" error, the file does not exist — proceed to 3.5c (create case)
  3. If the file exists, parse its JSON content and check if the `env` object contains the required key with the correct value

  #### 3.5c. Apply Settings

  **If `.claude/settings.json` does NOT exist**:

  Ensure the `.claude/` directory exists (use `mkdir -p`). Create the file with the Write tool:

  ```json
  {
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
    }
  }
  ```

  Report: **".claude/settings.json: created with Teams env var"**

  **If `.claude/settings.json` exists but is missing the env var**:

  Use the Edit tool to add the env var to the `env` block. If no `env` block exists, add one. Preserve all existing content.

  For example, if the file currently contains:
  ```json
  {
    "permissions": { "defaultMode": "plan" }
  }
  ```

  Update it to:
  ```json
  {
    "permissions": { "defaultMode": "plan" },
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
    }
  }
  ```

  Report: **".claude/settings.json: added Teams env var"**

  **If the env var already exists with the correct value**:

  Report: **".claude/settings.json: Teams already enabled — no changes"**

  #### 3.5d. Idempotency

  This step produces identical results on re-run:
  - If the env var already exists with value `"1"`, no changes are made
  - If the file has other env vars, they are preserved
  - If the file has other settings (permissions, hooks, etc.), they are preserved
  ```

  Also update Step 4 (Completion Summary) to include the settings.json status:
  ```
  - Settings.json: created/updated/unchanged
  ```

- **Test**: Read the file. Verify Step 3.5 exists with settings.json logic. Completion summary mentions settings.json.
- **Verify**: `grep -c "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" skills/setup/SKILL.md` ≥ 1
- **Commit**: `feat(setup): add settings.json env var management for Teams`

### Task 3.2: Update pipeline-guard.sh — heads-down guidance text
- **Files**: `scripts/pipeline-guard.sh`
- **Spec items**: C10
- **Depends on**: none
- **Action**: Replace line 102 from:
  ```bash
  echo "Action: Execute tasks via builder agents. TDD flow: failing test, implement, verify, commit. Merge worktrees after each level."
  ```
  to:
  ```bash
  echo "Action: Execute tasks via builder agents (inline, isolated, or Teams per Brief classification). TDD flow: failing test, implement, verify, commit. Squash merge + cleanup for isolated path."
  ```
- **Test**: Read the file. Line 102 mentions "inline, isolated, or Teams" and "Squash merge".
- **Verify**: `grep -c "Squash merge" scripts/pipeline-guard.sh` ≥ 1
- **Commit**: `fix(pipeline-guard): update heads-down guidance for 3-path execution`

## Phase 4: Documentation Consistency
> Depends on: Phase 1 (needs to reference new agent descriptions)
> Parallel: tasks 4.1 and 4.2 can run concurrently
> Delivers: All documentation references updated for new execution model
> Spec sections: S5

### Task 4.1: Update CLAUDE.md — builder description
- **Files**: `CLAUDE.md`
- **Spec items**: C11
- **Depends on**: none
- **Action**: Replace line 89 from:
  ```
  │   ├── builder.md           # Code execution in worktree isolation (build)
  ```
  to:
  ```
  │   ├── builder.md           # TDD code execution — inline or worktree-isolated (build)
  ```
- **Test**: Read the file. Line 89 says "inline or worktree-isolated".
- **Verify**: `grep "builder.md" CLAUDE.md | grep -c "inline"` ≥ 1
- **Commit**: `docs(CLAUDE.md): update builder description for dual-mode`

### Task 4.2: Update .claude/CLAUDE.md — builder and conflict-resolver descriptions
- **Files**: `.claude/CLAUDE.md`
- **Spec items**: C12
- **Depends on**: none
- **Action**:
  1. Replace the builder description (around line 101) from:
     ```
     - **Builder** (`agents/builder.md`): Executes TDD tasks in worktree isolation. Gets JIT knowledge + project rules context. Uses `isolation: worktree`.
     ```
     to:
     ```
     - **Builder** (`agents/builder.md`): Executes TDD tasks inline or in worktree isolation (determined at dispatch time via `isolation: "worktree"` parameter). Gets JIT knowledge + project rules context.
     ```
  2. Replace the conflict-resolver description (around line 104) from:
     ```
     - **Conflict Resolver** (`agents/conflict-resolver.md`): Resolves merge conflicts from worktree merges. Understands intent from both sides.
     ```
     to:
     ```
     - **Conflict Resolver** (`agents/conflict-resolver.md`): Resolves merge conflicts from squash merges of worktree-isolated agent dispatches. Understands intent from both sides.
     ```
- **Test**: Read the file. Builder description mentions "inline or in worktree isolation" and "dispatch time". Conflict-resolver mentions "squash merges".
- **Verify**: `grep -c "dispatch time" .claude/CLAUDE.md` ≥ 1
- **Commit**: `docs(.claude/CLAUDE.md): update agent descriptions for new execution model`

## Pre-mortem
| Failure Scenario | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Inline parallel builders race on git index lock | Low | Med | Claude Code likely serializes git operations per working tree. If encountered, route level to isolated path. |
| Teams API changes or breaks (experimental) | Med | Med | Teams path is one of 3 options. Isolated path provides the same parallelism with worktree safety. |
| Brief phase misclassifies execution path | Med | Low | Misclassification produces suboptimal but correct results — inline tasks that should be isolated just risk merge issues, caught by mechanical verification. |
| Squash merge loses debugging granularity | Low | Low | build-progress.md logs per-task outcomes. Individual commits preserved in spec-mutations.log. |
| Stale worktree cleanup deletes active worktree | Low | High | Cleanup runs at sprint START (Brief phase), before any new dispatches. Active worktrees only exist during heads-down. |

## Open Questions
- Whether Claude Code serializes git tool calls across parallel non-worktree Agent dispatches (affects inline path safety)
- Exact behavior of `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` — dropped from scope but may be needed for future plugin CLAUDE.md sharing
