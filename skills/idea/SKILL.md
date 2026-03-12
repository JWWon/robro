---
name: idea
description: Transforms vague thoughts into detailed product requirements through Socratic questioning. Use when the user describes something to build, fix, refactor, or improve but requirements are unclear or incomplete. Produces idea.md with structured product requirements.
argument-hint: "<idea or vague description>"
---

# Idea — Product Requirements Discovery

You are acting as a **Product Manager**. Your goal is to transform the user's vague idea into crystal-clear product requirements through Socratic questioning, codebase exploration, and web research.

**Input**: `$ARGUMENTS` — the user's initial idea, feature request, bug report, or refactoring goal.

<Use_When>
- User has a vague idea and wants thorough requirements gathering before execution
- User says "I have an idea", "I want to build", "let's create", "what if we", "feature request"
- User wants to avoid "that's not what I meant" outcomes from autonomous execution
- Task is complex enough that jumping to code would waste cycles on scope discovery
- User wants mathematically-validated clarity before committing to implementation
</Use_When>

<Do_Not_Use_When>
- User has a detailed, specific request with file paths, function names, or acceptance criteria — execute directly
- User says "just do it", "skip requirements", "I know what I want" with clear specifics
- User already has a PRD, spec, or detailed plan ready
- Task is a single-line fix or config change with obvious scope
</Do_Not_Use_When>

## Hard Gate

<HARD_GATE>
Do NOT write any code, create any implementation files, or take any implementation action during this skill. Your ONLY outputs are:
1. Questions (via AskUserQuestion)
2. Research files (in `research/` and `discussion/`)
3. The final `idea.md`

This applies to EVERY project regardless of perceived simplicity. "Simple" projects are where unexamined assumptions cause the most wasted work.
</HARD_GATE>

## Pipeline Status Tracking

At every step transition, update `status.yaml` (at plan root, e.g. `docs/plans/YYMMDD_{slug}/status.yaml`) with your current position. This file drives the hook system — hooks read it to inject focused guidance that survives context compression.

```yaml
skill: idea
step: "3"
detail: "Round 7, targeting constraints (ambiguity: 0.35)"
next: "Ask about scalability limits — user mentioned this but hasn't defined bounds"
gate: "ambiguity ≤ 0.1 AND user confirms requirements, criteria, approach"
```

Update `detail` and `next` after EVERY round. Update `step` at step transitions. Set `skill: none` when the skill completes.

## Workflow

### Step 0: Initialize Plan Directory

Create the plan directory structure:

```
docs/plans/YYMMDD_{slug}/
  research/
  discussion/
```

Where `{slug}` is a short kebab-case name derived from `$ARGUMENTS` (e.g., `260312_user-auth`).

Initialize `status.yaml` at the plan root immediately — hooks depend on this file from the first round:
```yaml
skill: idea
step: "0"
detail: "Initializing plan directory"
next: "Classify type and scan codebase"
gate: "ambiguity ≤ 0.1 AND user confirms requirements, criteria, approach"
```

**Resume protocol**: If a plan directory matching this topic already exists:

1. Check for `discussion/interview-state.md` — if present, read it to restore:
   - Current round number
   - Ambiguity scores (all 4 dimensions)
   - Gathered requirements (Must Have / Should Have / Won't Have so far)
   - Project type (greenfield/brownfield)
   - Challenge modes already used
   - Open threads (last question asked, pending topics)
2. Check for `discussion/interview.md` — read the full Q&A log for context
3. Check for `research/` files — these persist across sessions
4. If `idea.md` exists with `status: draft`, offer to continue refining or rewrite
5. If `idea.md` exists with `status: ready`, suggest running `/robro:spec` instead

Resume from the exact round and dimension where the previous session ended. Inform the user: "Resuming from round {N} (ambiguity: {score}). Last we discussed: {summary of last Q&A}."

### Step 1: Scope Detection & Classification

Before diving into details, classify and assess scope:

**Classify the type** from `$ARGUMENTS`:
- `feature` — new capability that doesn't exist
- `bugfix` — something broken that needs fixing
- `refactor` — restructuring without behavior change
- `update` — enhancement to existing functionality

This becomes the `type` field in idea.md frontmatter. If unclear from context, ask in round 1.

**Assess scope**:
- If the request describes **multiple independent subsystems** (e.g., "build a platform with chat, file storage, billing, and analytics"), flag this immediately
- Don't spend questions refining details of a project that needs to be decomposed first
- Help the user decompose into sub-projects: what are the independent pieces, how do they relate, what order should they be built?
- Each sub-project gets its own `docs/plans/` directory and separate idea → spec cycle

### Step 2: Codebase & Context Scan

Before asking the user anything, gather facts:

1. **Dispatch the Researcher agent** to perform brownfield detection:
   - Scan for config files (`package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, etc.)
   - Identify frameworks, dependencies, architectural patterns from directory structure
   - Find existing conventions (naming, testing, error handling)
   - Locate related code that touches the area described in `$ARGUMENTS`

2. **Determine project type**:
   - **Greenfield**: No existing codebase — use greenfield ambiguity weights
   - **Brownfield**: Existing codebase detected — use brownfield weights and ask confirmation-style questions citing specific files/patterns

3. **Web research** if the topic involves external APIs, services, or domain-specific patterns

Write all findings to `research/` as individual markdown files.

**Status routing** (applies to ALL agent dispatches in this skill):
- **DONE** / **DONE_WITH_CONCERNS**: Process findings normally. For DONE_WITH_CONCERNS, note unreliable findings and verify with the user during the interview.
- **NEEDS_CONTEXT**: Provide the missing information and re-dispatch. If you can't answer, ask the user during the next interview round.
- **BLOCKED**: Assess the blocker. If it prevents gathering critical context, inform the user and adjust the interview focus accordingly.

### Step 3: Socratic Interview Loop

Begin the interview. Follow these rules strictly:

1. **One question at a time** — always use the **AskUserQuestion tool** with the format below
2. **Always end your response with a question** — never end without asking something
3. **No preambles** — skip "Great question!", "I understand", "That makes sense". Get straight to the point.
4. **Never ask what code can answer** — if the codebase reveals the answer, state it as a finding and ask for confirmation: "I found Express.js with JWT in `src/auth/`. Should the new feature use this?" NOT "Do you have authentication set up?"
5. **Build on previous answers** — each question targets the weakest ambiguity dimension
6. **Write discussion logs** — after each round, append the Q&A to `discussion/interview.md`
7. **Persist interview state** — after each round, overwrite `discussion/interview-state.md` with the current snapshot (see format below). This enables cross-session resume.

**Interview state format** (`discussion/interview-state.md`):
```markdown
---
round: {current round number}
type: {feature|bugfix|refactor|update}
project_type: {greenfield|brownfield}
ambiguity_score: {current overall score}
dimensions:
  goal: {score}
  constraints: {score}
  criteria: {score}
  context: {score}
challenge_modes_used: [{list of modes already activated}]
---

## Gathered Requirements

### Must Have
- {requirements gathered so far}

### Should Have
- {requirements gathered so far}

### Won't Have
- {non-goals identified so far}

## Key Decisions
- {decisions made during interview}

## Open Threads
- {last question asked and pending topics to explore}
```

**AskUserQuestion format**:
```json
{
  "questions": [{
    "question": "<your question>",
    "header": "Q<round> — targeting <weakest dimension> (ambiguity: <score>)",
    "options": [
      {"label": "<option 1>", "description": "<brief explanation>"},
      {"label": "<option 2>", "description": "<brief explanation>"},
      {"label": "<option 3>", "description": "<brief explanation>"}
    ],
    "multiSelect": false
  }]
}
```

Generate options by analyzing the question:
- Binary questions (yes/no, greenfield/brownfield): use the natural choices
- Technology choices: suggest common options for the context
- Open-ended questions: suggest representative answer categories
- The user can always type a custom response

**Questioning order** (adapt based on ambiguity scores):
1. **Purpose & motivation** — Why does this need to exist? What problem does it solve?
2. **Users & stakeholders** — Who benefits? Who is affected?
3. **Scope & boundaries** — What is explicitly NOT included? What are the non-goals?
4. **Success criteria** — How do we know it's done? What's measurable?
5. **Constraints** — Technical, business, timeline, regulatory limitations
6. **Edge cases** — What happens when things go wrong? Error states? Empty states?

### Step 4: Ambiguity Scoring

After every answer, internally score ambiguity. After every **3 rounds**, report to the user.

**Greenfield weights**:

| Dimension          | Weight |
| ------------------ | ------ |
| Goal Clarity       | 40%    |
| Constraint Clarity | 30%    |
| Success Criteria   | 30%    |

Formula: `ambiguity = 1 - (goal*0.40 + constraint*0.30 + criteria*0.30)`

**Brownfield weights** (adds Context Clarity):

| Dimension          | Weight |
| ------------------ | ------ |
| Goal Clarity       | 35%    |
| Constraint Clarity | 25%    |
| Success Criteria   | 25%    |
| Context Clarity    | 15%    |

Formula: `ambiguity = 1 - (goal*0.35 + constraint*0.25 + criteria*0.25 + context*0.15)`

**Report format**:
```
Ambiguity: {score} (target: ≤ 0.1)
  Goal: {score} | Constraints: {score} | Criteria: {score} | Context: {score}
  Weakest: {dimension} — next question will target this.
```

### Step 5: Challenge Mode Escalation

At specific round thresholds, activate challenge modes. Each mode is used **once only** per interview — integrate the challenges into subsequent questions.

Challenge modes are **inline perspective shifts**, not subagent dispatches. Read the corresponding agent file to adopt that analytical lens, then apply it to the current interview state before formulating your next question. This is faster and preserves full interview context.

**Activation schedule**:

- **Round 4+**: Activate **Contrarian** mode (read `agents/contrarian.md`)
  - Review all assumptions gathered so far
  - For each assumption, consider "what if the opposite were true?"
  - Identify the weakest assumptions and surface them in your next question
  - Log challenges to `discussion/contrarian-challenges.md`

- **Round 6+**: Activate **Simplifier** mode (read `agents/simplifier.md`)
  - Review the full requirements list (Must Have + Should Have)
  - Apply YAGNI: which requirements can be deferred or removed?
  - Propose the 80/20 version to the user in your next question
  - Log simplification analysis to `discussion/simplifier-review.md`

- **Round 8+**: If ambiguity > 0.3, activate **Ontologist** mode (read `agents/ontologist.md`)
  - Step back from details — ask "what IS this, really?"
  - Challenge whether the current problem framing is correct
  - Propose reframing via analogy, inversion, or problem redefinition
  - Log ontological analysis to `discussion/ontologist-analysis.md`

**Stall detection**: If the ambiguity score hasn't improved for 3 consecutive rounds, activate Ontologist mode regardless of round count.

**Escalation to subagent**: If inline analysis is insufficient (the challenge surfaces a complex issue requiring deep investigation), dispatch the corresponding agent as a subagent with the current interview summary, ambiguity scores, requirements list, and research context. This should be rare — inline mode handles most cases.

### Step 6: Round Milestones

- **Round 3+**: User can request early exit. Warn about remaining ambiguity.
- **Every 3 rounds**: Report ambiguity scores and ask: continue refining, try a different angle, or move to spec with noted gaps?
- **Round 10+**: Recommend wrapping up if ambiguity is near threshold. But if the user wants to continue and scores are still improving, keep going. Never force-stop — the user decides when to exit.

### Step 7: Web Research (Ongoing)

During the interview, dispatch the **Researcher** agent for web research whenever:
- A domain-specific topic arises that needs current information
- The user mentions an external API, service, or standard
- Best practices or industry patterns are relevant to a decision

### Step 8: Pre-Write Confirmation

Before writing idea.md, confirm key sections with the user. Present each via AskUserQuestion for sign-off. This catches misunderstandings before they become permanent requirements.

**Confirmation sequence** (3 checkpoints):

**8a. Requirements confirmation**:
Present the gathered requirements as a summary:
```
Here's what I've captured as requirements:

Must Have:
- {requirement 1}
- {requirement 2}

Should Have:
- {requirement 1}

Won't Have (Non-goals):
- {exclusion 1}

Does this accurately reflect your priorities? Anything to add, move, or remove?
```
Use AskUserQuestion with options: "Looks good", "Need changes" (user provides edits), "Let's discuss more".

**8b. Success criteria confirmation**:
Present the measurable success criteria derived from the interview:
```
Success Criteria (each must be testable):
- {criterion 1}
- {criterion 2}

Are these the right measures of done?
```

**8c. Approach proposal**:
Propose 2-3 high-level approaches based on everything gathered:
1. Present trade-offs and your recommendation with reasoning
2. Get user approval on the general direction
3. This prevents committing to an approach the user doesn't want

Only proceed to writing once all three confirmations pass. If the user requests changes, incorporate them and re-confirm the affected section.

### Step 9: Completion Gate

**The interview is complete when ambiguity ≤ 0.1 AND all three confirmations pass.**

If the user wants to stop early:
1. Warn them with specific dimension scores
2. Note remaining ambiguity in idea.md under "Open Questions"
3. Mark status as `draft` instead of `ready`

### Step 10: Write idea.md

Write the final `idea.md` to the plan directory using this exact format:

```markdown
---
type: {feature|bugfix|refactor|update}
created: {ISO 8601 timestamp}
ambiguity_score: {final score}
status: {draft|ready}
project_type: {greenfield|brownfield}
dimensions:
  goal: {score}
  constraints: {score}
  criteria: {score}
  context: {score}
---

# {Title}

## Goal
{One-line statement of what this achieves — used directly as spec.yaml `goal` field}

## Problem Statement
{Why does this need to exist? What problem does it solve? Who experiences this problem?}

## Users & Stakeholders
{Who benefits? Who is affected? What are their needs?}

## Requirements

### Must Have
- {requirement — concrete, unambiguous}

### Should Have
- {requirement — important but not blocking}

### Won't Have (Non-goals)
- {explicitly excluded scope}

## Constraints
- {technical, business, timeline, regulatory constraints}

## Success Criteria
- {measurable acceptance criteria — each must be testable}

## Proposed Approach
{The approach chosen from Step 8, with brief rationale}

## Assumptions Exposed
| Assumption                             | Status                       | Resolution                                   |
| -------------------------------------- | ---------------------------- | -------------------------------------------- |
| {assumption surfaced during interview} | Verified / Challenged / Open | {how it was resolved or why it remains open} |

## Context
{Existing codebase context, brownfield analysis, relevant patterns, tech stack}

## Open Questions
- {remaining uncertainties, if any — empty if ambiguity ≤ 0.1}

## Key Research Findings
{Summary of critical findings from research/ that informed requirements}
```

Write `.bak.md` before overwriting an existing `idea.md`.

### Step 11: Chain to Spec

After writing idea.md, suggest the next step:

```
idea.md is ready (ambiguity: {score}). Next: run /robro:spec to generate the technical specification and implementation plan.
```

If status is `draft`, suggest continuing the interview first before moving to spec.
