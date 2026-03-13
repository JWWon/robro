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
  model: "{MODEL_CONFIG.builder}",
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
  model: "{MODEL_CONFIG.builder}",
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
skill: do
sprint: {N}
phase: review
step: "1"
detail: "Starting 3-stage review pipeline"
next: "Run mechanical verification first"
```

Log transition to build-progress.md: "Heads-down complete. Starting Review."
