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
   skill: do
   sprint: {N+1}
   phase: brief
   step: "0"
   detail: "Preparing sprint {N+1}"
   next: "Begin Brief phase — gather context and plan"
   ```

4. Log to build-progress.md: "Sprint {N} complete. {remaining} items left. Continuing..."

The stop hook will read status.yaml and auto-continue to the next sprint.
