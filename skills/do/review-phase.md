# Review Phase — Detailed Instructions

The Review phase validates implementation quality through a 3-stage pipeline: mechanical (free), semantic (LLM), and consensus (multi-agent, only if needed).

## Step-by-Step

### 1. Dispatch Reviewer Agent

Dispatch the **Reviewer** agent with `model: "{MODEL_CONFIG.reviewer}"`:

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

Dispatch **Architect** (with `model: "{MODEL_CONFIG.architect}"`) and **Critic** (with `model: "{MODEL_CONFIG.critic}"`) agents in parallel, each reviewing the ambiguous items:

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
skill: do
sprint: {N}
phase: retro
step: "1"
detail: "Starting retrospective analysis"
next: "Dispatch retro-analyst with sprint data"
```

Log transition to build-progress.md: "Review complete. {count} items ready to flip."
