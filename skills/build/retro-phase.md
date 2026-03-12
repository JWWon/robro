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
