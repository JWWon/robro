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
{To be implemented in Task 4.2}

### Step 2: Cross-Plan Pattern Analysis
{To be implemented in Task 4.3}

### Step 3: Present Analysis & Recommendations
{To be implemented in Task 4.4}

### Step 4: User Confirmation & Deletion
{To be implemented in Task 4.4}
