---
name: review
description: Flexible review skill for /robro:review. Detects what to review (plan, code, or bug), dispatches the appropriate agents, and presents a structured report with spec flip suggestions requiring user confirmation. Never auto-flips spec items.
disable-model-invocation: false
---

# /robro:review — Flexible Review

You are in the **Review** role. Your job is to detect what needs reviewing, dispatch agents, present findings, and suggest spec flips — but NEVER flip them without explicit user confirmation.

## Arguments

`$ARGUMENTS` may contain:
- A mode flag: `--plan`, `--code`, or `--bug`
- Free-form text (bug description, file path, or question)
- Nothing (auto-detect from context)

## Provider Forwarding

When dispatching agents (Reviewer, Architect, Critic, or any agent), check the conversation context for hook-injected provider availability. If `External advisors available:` appears in the current context, include it in the agent dispatch prompt under an `AVAILABLE_PROVIDERS:` key. This enables agents to consult external CLIs for complex second-opinions or cross-validation. If no provider context is present, omit the key — agents will skip their External CLI Advisory section.

## Step 0: Write initial status

Before doing anything else, write the status file for session resume:

```yaml
# .robro/sessions/{slug}/status-review.yaml
skill: review
step: 0
mode: detecting
detail: "Determining review mode"
next: "Detect mode from arguments and context"
```

Find the active session directory by looking for the most recently modified `plan.md` in `.robro/sessions/*/`.

## Step 1: Mode Detection

Determine the review mode using this **strict priority chain** (earlier rules win):

1. **Explicit flag** — If `$ARGUMENTS` contains `--plan`, `--code`, or `--bug`, use that mode.
2. **Bug keywords** — If `$ARGUMENTS` contains words like "bug", "error", "broken", "crash", "exception", "failing", "regression", use mode `bug`.
3. **Plan phase** — If no active `spec.yaml` exists but `plan.md` exists and is recent (mtime within 48h), use mode `plan`.
4. **Code diff** — If `git diff --stat HEAD` returns changed source files (non-docs, non-config), use mode `code`.
5. **Default** — If none of the above match, use mode `code` and note the fallback in the report.

Update status-review.yaml with the detected mode.

## Step 2: Gather Context

Run these reads in parallel:
- Read `plan.md` (if mode is `plan` or `code`)
- Read `spec.yaml` (if exists — for spec flip candidates)
- Run `git diff --stat HEAD` (if mode is `code` or `bug`) to get changed files
- Read `.robro/sessions/{slug}/discussion/build-progress.md` last 20 lines (if mode is `code`)

## Step 3: Dispatch Agents

### Mode: plan

Dispatch **Architect** and **Critic** agents in parallel:

```
Agent(
  subagent_type: "robro:architect",
  prompt: "REVIEW_TARGET: plan\nPLAN_FILE: {path}\nSPEC_FILE: {path or 'none'}\nFOCUS: Evaluate plan phasing, dependency ordering, feasibility, and spec coverage.",
  model: "opus"
)

Agent(
  subagent_type: "robro:critic",
  prompt: "REVIEW_TARGET: plan\nPLAN_FILE: {path}\nSPEC_FILE: {path or 'none'}\nFOCUS: Score ambiguity. Flag spec items without measurable acceptance criteria. Flag orphaned plan tasks.",
  model: "opus"
)
```

### Mode: code

Dispatch **Reviewer** agent with diff context:

```
Agent(
  subagent_type: "robro:reviewer",
  prompt: "REVIEW_TARGET: code\nCHANGED_FILES:\n{git diff --name-only HEAD}\nSPEC_FILE: {path or 'none'}\nFOCUS: Run 3-stage review pipeline. Generate ITEM_REVIEW blocks for spec items affected by changes.",
  model: "sonnet"
)
```

### Mode: bug

Dispatch **Architect** agent with bug description:

```
Agent(
  subagent_type: "robro:architect",
  prompt: "REVIEW_TARGET: bug\nBUG_DESCRIPTION: {$ARGUMENTS}\nCHANGED_FILES:\n{git diff --stat HEAD}\nFOCUS: Identify root cause. Check if recent changes introduced a regression. Suggest fix approach without writing code.",
  model: "opus"
)
```

## Step 4: Collect and Route Agent Output

Wait for all agents to complete. For each:
- **DONE** or **DONE_WITH_CONCERNS**: collect findings
- **NEEDS_CONTEXT**: provide missing context and re-dispatch once
- **BLOCKED**: note in report as "Agent blocked: {description}"

## Step 5: Generate Report

Present the report directly to the user (no subagent):

```
## /robro:review Report — {mode} mode — {timestamp}

### Mode detected: {plan|code|bug}
{If auto-detected: "Auto-detected from: {reason}"}

### Summary
{2-3 sentences of overall assessment}

### Findings
{Agent findings organized by severity: CRITICAL → MAJOR → MINOR}
{Each finding: file:line, description, suggested fix}

### Spec Coverage (if spec.yaml exists)
{List spec items affected by findings}
{For code mode: ITEM_REVIEW blocks from reviewer agent}

### Suggested Spec Flips
{List of spec items that evidence suggests should change passes: true→false (regression) or false→true (passing)}
{Format: "C{id}: {item description} — recommend passes: {value} because {evidence}"}

### Recommended Actions
{Prioritized list of next steps}
```

## Step 6: Spec Flip Confirmation (if suggestions exist)

This skill is **read-only with respect to spec.yaml** until the user explicitly confirms. NEVER auto-flip spec items without confirmation.

If the report contains any suggested spec flips, ask the user:

```
AskUserQuestion(
  question: "The review found {N} spec items that may need updating:\n\n{list each flip}\n\nShould I apply these spec flips now?"
  options: ["Apply all", "Skip flips"]
)
```

On "Apply all": apply all suggested flips to spec.yaml, appending each to `spec-mutations.log`:
```
{ISO-timestamp}	REVIEW	FLIP	{item-path}	{value}	REASON: {evidence from review}
```

On "Skip flips": note in report that flips were declined.

## Step 7: Finalize

Update status-review.yaml:
```yaml
skill: none
step: 7
mode: {detected mode}
detail: "Review complete"
next: "No pending actions"
```

## External CLI Advisory

If `AVAILABLE_PROVIDERS` appears in your input context, you may consult external AI CLI advisors. At most 2 external delegations per review session (parallel allowed). Present both provider outputs labeled: "[Codex] found..." / "[Gemini] suggests...". On failure, continue without advisory.

## Status Protocol

- **DONE**: Review complete, report presented.
- **DONE_WITH_CONCERNS**: Review complete but some agents returned DONE_WITH_CONCERNS.
- **NEEDS_CONTEXT**: Cannot determine what to review. Ask the user for clarification.
- **BLOCKED**: Cannot complete review. Describe the blocker.
