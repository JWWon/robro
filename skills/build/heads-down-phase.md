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
