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
