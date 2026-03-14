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
skill: do
step: 1
sprint: {N}
phase: brief
complexity: standard
branch: plan/{slug}
worktree: .claude/worktrees/{slug}
detail: "Reading current state"
next: "Identify remaining items and plan sprint scope"
gate: "All 5 convergence gates pass"
```

### 1.1. Load Model Configuration

Read the complexity tier and load model mappings for agent dispatch:

1. Read `meta.complexity` from spec.yaml. Expected values: `light`, `standard`, `complex`. Default to `standard` if missing.
2. Read `${CLAUDE_PLUGIN_ROOT}/config.json` to load the tier definitions.
3. Select the tier matching the complexity value.
3b. **Check for project config overrides**: Read `.robro/config.json` if it exists at the project root.
   - If `model_tiers.{complexity}` has agent-specific overrides, apply them on top of plugin defaults
   - If `agent_overrides` has entries, apply them with highest precedence (overrides both tier and plugin defaults)
   - Precedence order: agent_overrides > project config.json tier > plugin config.json tier
   - Example: If plugin config.json says `builder: sonnet` for standard tier, but project config.json has `agent_overrides.builder: "opus"`, use opus.
   - If project config.json is absent or has invalid JSON, silently use plugin defaults (no error).
4. Store the model mapping for use in all subsequent agent dispatches this sprint:
   ```
   MODEL_CONFIG:
     complexity: {tier name}
     builder: {model}
     reviewer: {model}
     architect: {model}
     critic: {model}
     researcher: {model}
     retro-analyst: {model}
     conflict-resolver: {model}
   ```
5. Log to build-progress.md: "Sprint {N}: Using {tier} complexity tier ({model} for builder, {model} for reviewer, ...)"

For every Agent() dispatch in Heads-down, Review, Retro, and Level-up phases, include `model: "{model from MODEL_CONFIG}"` based on the agent type being dispatched.

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

### 2. Sprint 1 Only: Researcher Pre-flight

On the very first sprint, dispatch the **Researcher** agent for comprehensive brownfield detection:

```
Agent(
  subagent_type: "robro:researcher",
  prompt: "Perform a comprehensive brownfield scan of this project. I need:
1. Tech stack: languages, frameworks, libraries with exact versions
2. Build/test/lint commands: How to build, test, lint, and typecheck this project
3. Existing conventions: naming patterns, file organization, error handling, logging
4. Existing .claude/ files: any agents, skills, rules already defined
5. CI/CD: pipeline config, deployment targets
6. Recent git activity: active branches, recent commit patterns
7. Dependencies: key external libraries and their current versions

Write findings to: {plan_dir}/research/brownfield-scan.md",
  model: "{MODEL_CONFIG.researcher}"
)
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

#### 3b. Produce Structured Configuration Baseline

After scanning `.claude/` files, produce a `CONFIG_BASELINE` structure capturing each configuration item's name, path, and coverage:

- For each agent in `.claude/agents/`: name, path, one-line coverage summary
- For each skill in `.claude/skills/`: name, path, one-line coverage summary
- For each rule in `.claude/rules/`: name, path, one-line coverage summary
- For each section in project CLAUDE.md: section heading, one-line coverage summary
- For each configured MCP in `.mcp.json`: name, one-line coverage summary

Example coverage summary: "github.md: commit conventions, branch workflow, gh CLI usage"

Read `skills/do/config-analysis-framework.md` for the full baseline format specification (CONFIG_BASELINE structure with `relevant_tasks` fields).

Store this baseline for use in step 5 (execution trace annotation) and later injection into the retro dispatch payload.

### 4. Identify Knowledge Gaps & Fetch JIT Knowledge

For each remaining task this sprint:
1. Scan the task description for library/framework references
2. For each external library referenced:
   - Call `resolve-library-id` with the library name
   - Call `query-docs` with the resolved ID and the specific API/pattern needed
3. If context7 doesn't have the library, use web search as fallback
4. Compile fetched knowledge into a JIT context bundle for builder agents

### 4.5. Wonder Phase (Conditional)

Dispatch the Wonder agent if ANY of these conditions are true:
- Sprint >= 3 (configurable via `thresholds.wonder_min_sprint` in .robro/config.json, default 3)
- No spec items were flipped to `passes: true` in the previous sprint
- The oscillation detector fired during the previous sprint (check `.robro/.oscillation-state.json` — if it exists and has any entry with count >= threshold)

If none of these conditions are met, skip Wonder and proceed to step 5.

If triggered, dispatch:

```
Agent(
  subagent_type: "robro:wonder",
  prompt: "Analyze blind spots for sprint {N}.

Spec status:
{paste spec.yaml checklist section with current passes values}

Sprint file changes:
{output of: git diff --stat HEAD~{commits_this_sprint}}

Previous retro Knowledge Gaps:
{paste Knowledge Gaps section from discussion/retro-sprint-{N-1}.md, or 'N/A — first sprint'}

Oscillation warnings:
{paste .robro/.oscillation-state.json content if exists, or 'None'}",
  model: "{MODEL_CONFIG.wonder or MODEL_CONFIG.default}"
)
```

Route on Wonder status:
- **DONE**: Read `blind_spots` and `lateral_recommendation` from output.
  - If `lateral_recommendation` is not null, dispatch that challenge agent (contrarian, simplifier, or researcher) inline before proceeding to step 5. Log the lateral shift to build-progress.md.
  - Log all blind spots to build-progress.md under "### Wonder".
- **DONE_WITH_CONCERNS**: Log concerns, proceed with noted gaps.
- **NEEDS_CONTEXT**: Provide missing info and re-dispatch once.
- **BLOCKED**: Log blocker, proceed without Wonder input.

After Wonder completes (or is skipped), clear the oscillation state for the new sprint:
```bash
rm -f "${PROJECT_ROOT}/.robro/.oscillation-state.json"
```

### 5. Plan Parallel Execution Levels

Analyze the File Map from the Brief and task dependencies:

1. Group tasks that have no dependencies between each other into "levels"
2. **Critical — file overlap detection (D9)**: For tasks in the same level, check if they modify the same files. If they do, serialize them (move one to the next level).
3. **Classify execution path** for each level:
   - **Inline**: All tasks reference the same plan.md section, each task touches ≤3 files, AND no file overlaps between tasks in the level.
   - **Isolated**: Tasks have file overlaps between them, OR any single task touches >3 files.
   - **Teams**: Tasks span 3+ different plan.md sections or fundamentally different subsystems.
4. **Execution trace annotation**: Cross-reference each task in the sprint scope against CONFIG_BASELINE items. For each baseline item (agent, skill, rule, CLAUDE.md section, MCP), annotate its `relevant_tasks` field with task IDs where that item's domain applies. For example: "github.md rule → relevant to tasks 2.1, 2.3" or "auth-specialist agent → relevant to task 3.1". This piggybacks on the task analysis already being done — no separate pass needed.
5. Record the level plan with execution path in build-progress.md. Include the annotated CONFIG_BASELINE with relevant_tasks fields.

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
skill: do
step: 1
sprint: {N}
phase: heads-down
complexity: standard
branch: plan/{slug}
worktree: .claude/worktrees/{slug}
detail: "Starting Level 1 execution"
next: "Dispatch builder agents for Level 1 tasks"
gate: "All 5 convergence gates pass"
```

Log transition to build-progress.md: "Brief complete. Starting Heads-down."

## Rationalization Tables

These tables map common agent rationalizations to rebuttals. Review at the start of each sprint. These are compression-resistant — even if earlier context is compressed, this table remains visible.

| Rationalization | Rebuttal |
|----------------|----------|
| "This is a simple change, I don't need to run tests" | Every change needs test verification. Simple changes cause the worst bugs. |
| "I'll fix the tests later" | TDD is non-negotiable. Write the test FIRST. |
| "The spec item is basically passing" | `passes: false` means false. Flip it only after verification command succeeds. |
| "I should refactor this while I'm here" | Stay on task. Only modify files listed in the current task's spec items. |
| "The verification step isn't relevant for this change" | Verification-before-completion is mandatory. Run the exact command specified. |
| "I can skip the commit — I'll batch them later" | Commit after each task. Atomic commits enable rollback. |
| "This code is good enough" | Good enough is not verified. Run the test plan. Check the acceptance criteria. |
