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

Before dispatching, read `skills/do/config-analysis-framework.md` and include its full content as CONFIG_ANALYSIS_FRAMEWORK in the payload.

Dispatch the **Retro Analyst** agent with `model: "{MODEL_CONFIG.retro-analyst}"`:

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
CONFIG_BASELINE:
  {structured baseline from brief phase with per-task relevance annotations}
CONFIG_ANALYSIS_FRAMEWORK:
  {full content of config-analysis-framework.md}
```

If CONFIG_BASELINE is not available in context (e.g., after context compression), read it from build-progress.md where the brief phase logged the annotated baseline.

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
5. **Configuration Suggestions**: Extract config effectiveness suggestions (Operation/Type/Target/Evidence/Proposed Action format) from the retro report's Configuration Effectiveness section and route them alongside Proposed Level-ups for level-up processing. Level-up handles ADD/UPDATE/REMOVE operations uniformly.

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
skill: do
sprint: {N}
phase: level-up
step: "1"
detail: "Applying spec mutations and project evolution"
next: "Apply proposed mutations, then execute 5-step level-up flow"
```
