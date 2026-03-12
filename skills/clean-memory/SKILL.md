---
name: clean-memory
description: Clean up completed plans from docs/plans/. Analyzes cross-plan patterns, recommends improvements, then deletes confirmed plans. Run when completed plans accumulate.
disable-model-invocation: true
argument-hint: "(no arguments needed)"
---

# Clean Memory — Completed Plan Cleanup

You are cleaning up completed plans from the `docs/plans/` directory. This skill identifies completed plans, analyzes cross-plan patterns for improvement opportunities, and deletes plans after user confirmation.

**Input**: No arguments needed. Scans all plan directories.

<Use_When>
- User says "clean memory", "clean up plans", "remove completed plans"
- Completed plans are accumulating in docs/plans/
- User wants to analyze patterns across completed plans before cleanup
</Use_When>

<Do_Not_Use_When>
- User wants to start a new plan (use /robro:idea)
- A plan is actively being implemented (check status.yaml)
</Do_Not_Use_When>

## Workflow

### Step 1: Scan for Completed Plans

Discover all plan directories and determine which ones are completed.

#### 1a. Discover plan directories

Use the **Glob** tool to find all plan directories:

```
Glob pattern: docs/plans/*/
```

Each match is a plan directory (e.g., `docs/plans/260312_execution-harness/`).

#### 1b. Check each plan for completion

For each plan directory, apply the following checks **in order**. Stop at the first match.

**Primary check — plan-root status.yaml:**

Use the **Read** tool to read `{plan_dir}/status.yaml` (the current standard location at the plan root).

- If the file exists and contains `skill: none`, the plan is **completed**.
- If the file exists and contains any other `skill:` value (e.g., `skill: build`, `skill: spec`), the plan is **active** — skip it entirely.

**Legacy check — discussion/status.yaml:**

If no status.yaml exists at the plan root, use the **Read** tool to read `{plan_dir}/discussion/status.yaml` (the legacy location used by older plans).

- If this file exists and contains `skill: none`, the plan is **completed**. Record the completion source as "discussion/status.yaml (legacy)".
- If this file exists with any other `skill:` value, the plan is **active** — skip it.

**Heuristic fallback — spec.yaml analysis:**

If neither status.yaml location exists, check whether `{plan_dir}/spec.yaml` exists using the **Read** tool.

- If spec.yaml does not exist, skip the plan with a warning: `"Plan {name}: no status.yaml and no spec.yaml found — skipping"`
- If spec.yaml exists, parse the YAML and inspect all checklist items:
  - **Skip superseded items**: Any item with `status: superseded` is excluded from the completeness check.
  - **Check remaining items**: Every non-superseded item must have `passes: true`.
  - If ALL non-superseded items have `passes: true`, treat the plan as **completed** via heuristic. Record the completion source as "spec.yaml heuristic".
  - If any non-superseded item has `passes: false` (or no `passes` field), the plan is **incomplete** — skip it with a warning: `"Plan {name}: no status.yaml found and spec incomplete — skipping"`

#### 1c. Build completed plans metadata

For each completed plan, collect the following metadata:

- **Plan name**: Directory basename (e.g., `260312_execution-harness`)
- **Completion source**: One of:
  - `"plan-root status.yaml"` — found via primary check
  - `"discussion/status.yaml (legacy)"` — found via legacy check
  - `"spec.yaml heuristic"` — inferred from all items passing
- **Committed files present**: Use Glob/Read to check for existence of:
  - `idea.md`
  - `plan.md`
  - `spec.yaml`
  - `spec-mutations.log`
- **Gitignored files present**: Check for existence of:
  - `research/` directory
  - `discussion/` directory
  - `status.yaml` (at plan root)
  - `*.bak.*` files

#### 1d. Report results

**If no completed plans found:**

Inform the user: `"No completed plans found in docs/plans/."` and stop — do not proceed to Step 2.

**If completed plans found:**

Display a summary:

```
Found {N} completed plan(s):

1. {plan_name}
   - Completion source: {source}
   - Committed files: {list}
   - Gitignored files: {list}

2. ...
```

Then proceed to Step 2.

### Step 2: Cross-Plan Pattern Analysis
{To be implemented in Task 4.3}

### Step 3: Present Analysis & Recommendations
{To be implemented in Task 4.4}

### Step 4: User Confirmation & Deletion
{To be implemented in Task 4.4}
