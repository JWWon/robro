---
spec: spec.yaml
idea: idea.md
created: 2026-03-13T13:00:00Z
---

# Implementation Plan: Level-up Configuration Effectiveness & /robro:tune

## Overview
Enhance the build cycle's retro-analyst to perform structured configuration comparison (brief captures baseline → retro compares against sprint reality → level-up acts on richer proposals), and create a standalone `/robro:tune` skill for manual configuration audits — both sharing a single analysis framework reference document.

## Tech Context
This is a Claude Code plugin (all markdown files, no compiled code). Skills are `SKILL.md` files with YAML frontmatter. Agents are `.md` files with YAML frontmatter and a system prompt body. Hooks are shell scripts configured in `hooks/hooks.json`. "Testing" means structural verification: format correctness, reference integrity, convention compliance. The plugin version is 0.1.0.

## Architecture Decision Record
| Decision | Rationale | Alternatives Considered | Trade-offs |
|----------|-----------|------------------------|------------|
| Shared framework at `skills/build/config-analysis-framework.md` | Co-located with build phases; skill injects into dispatch payload | `agents/` or `docs/` location | Build-centric, but tune reads it fine from anywhere |
| Build skill injects framework into retro dispatch payload | Reliable — skill controls context, survives compression | Agent reads it directly via Read tool | Direct read risks agent skipping it |
| Execution trace piggybacks on brief step 5 | Zero overhead — annotate during existing parallel planning | Separate step or PostToolUse hooks | Estimate vs observed truth; sufficient for gap analysis |
| `/robro:tune` as new standalone skill | Clean separation: setup=install, tune=audit | Extend setup with `--audit` mode | Users learn which to use via `Do_Not_Use_When` blocks |
| MCP analysis in tune: detection only | Avoid overlap with setup's installation logic | Tune also installs | Installation stays in one place (setup) |
| Cap retro config suggestions at 5/sprint | Prevents level-up overload (each goes through 5-step flow) | No cap | Could slow level-up with many suggestions |

## File Map
| File | Action | Responsibility |
|------|--------|---------------|
| `skills/build/config-analysis-framework.md` | create | Shared analysis dimensions, comparison protocol, suggestion format |
| `skills/build/brief-phase.md` | modify | Add structured baseline to step 3; add execution trace annotations to step 5 |
| `agents/retro-analyst.md` | modify | Add Config Effectiveness Analysis section to protocol and output format |
| `skills/build/retro-phase.md` | modify | Enhance dispatch payload with baseline + framework reference |
| `skills/build/level-up-phase.md` | modify | Add REMOVE operation to Step e alongside existing CREATE/UPDATE |
| `skills/tune/SKILL.md` | create | Standalone configuration audit skill |
| `skills/build/SKILL.md` | modify | Update Retro and Level-up phase summaries to mention config effectiveness |
| `skills/setup/claude-md-template.md` | modify | Add /robro:tune to skills table |
| `CLAUDE.md` | modify | Add /robro:tune to Core Skills and Directory Structure |
| `README.md` | modify | Add /robro:tune to skills table |
| `scripts/keyword-detector.sh` | modify | Add tune keyword triggers |
| `.claude/CLAUDE.md` | modify | Add /robro:tune to managed section skills table |

## Phase 1: Shared Analysis Framework
> Depends on: none
> Parallel: single task
> Delivers: The reference document both retro-analyst and /robro:tune consume
> Spec sections: S1

### Task 1.1: Create config-analysis-framework.md
- **Files**: `skills/build/config-analysis-framework.md`
- **Spec items**: C1, C2
- **Depends on**: none
- **Action**: Create the shared reference document defining:
  1. **Analysis dimensions** (5 categories):
     - Agents: What personas exist? Are they activated? Were they relevant?
     - Skills: What procedures are encoded? Were they used? Any gaps?
     - Rules: What conventions are enforced? Were they followed? Missing patterns?
     - CLAUDE.md: What project context is documented? Is it current? Gaps?
     - MCPs: What integrations exist? Were they needed? Any missing?
  2. **Baseline format** — structured YAML-like representation:
     ```
     CONFIG_BASELINE:
       agents:
         - name: "{name}"
           path: "{path}"
           covers: "{what patterns/expertise this agent provides}"
           relevant_tasks: ["{task IDs where this agent's domain applies}"]
       skills:
         - name: "{name}"
           path: "{path}"
           covers: "{what procedures this skill encodes}"
           relevant_tasks: ["{task IDs}"]
       rules:
         - name: "{name}"
           path: "{path}"
           covers: "{what conventions this rule enforces}"
           relevant_tasks: ["{task IDs}"]
       claude_md:
         - section: "{section heading}"
           covers: "{what context this section provides}"
           relevant_tasks: ["{task IDs}"]
       mcps:
         - name: "{name}"
           covers: "{what integration this provides}"
           relevant_tasks: ["{task IDs}"]
     ```
  3. **Comparison protocol** — how to compare baseline vs sprint reality:
     - For each baseline item: was it relevant? Was it sufficient? Evidence from sprint (file paths, error messages, builder outputs)
     - For patterns that emerged without coverage: what convention/rule/agent is missing? Evidence.
     - For items that were never relevant: is this stale config? Evidence.
  4. **Suggestion format** — actionable + evidence-based:
     ```
     | Operation | Type | Target | Evidence | Proposed Action |
     |-----------|------|--------|----------|-----------------|
     | ADD | rule | .claude/rules/{name}.md | Builders used 3 different error patterns in src/api/*.ts (sprint data: task 2.1 and 2.3) | Create rule enforcing withApiError() wrapper |
     | UPDATE | agent | .claude/agents/{name}.md | Agent X lacked OAuth2 PKCE knowledge needed for task 3.1 | Add PKCE flow to agent expertise |
     | REMOVE | rule | .claude/rules/{name}.md | Rule Y about import ordering is redundant with ESLint config at .eslintrc | Remove — linter handles this |
     ```
  5. **Cap rule**: Maximum 5 suggestions per analysis. Prioritize by evidence strength (number of occurrences, severity of impact).
  6. **No-gaps format**: When analysis finds no gaps, use compact format:
     ```
     ### Configuration Effectiveness
     No gaps identified. Baseline: {N} agents, {M} skills, {K} rules. All items were relevant during sprint.
     ```
  7. **Scope boundaries**: Suggestions target the project's `.claude/` directory and CLAUDE.md only. Never suggest changes to plugin-provided files (anything under `${CLAUDE_PLUGIN_ROOT}`).
- **Verify**: Read the created file and confirm it contains all 7 sections (dimensions, baseline format, comparison protocol, suggestion format, cap rule, no-gaps format, scope boundaries).
- **Commit**: `feat(config-analysis): create shared analysis framework reference document`

## Phase 2: Build Cycle Enhancement
> Depends on: Phase 1
> Parallel: Level 1 (tasks 2.1, 2.3, 2.5 — all different files); Level 2 (tasks 2.2, 2.4 — depend on 2.1 and 2.3 respectively)
> Delivers: Brief captures baseline, retro-analyst performs structured comparison, dispatch includes framework
> Spec sections: S2

### Task 2.1: Enhance brief-phase.md step 3 with structured baseline
- **Files**: `skills/build/brief-phase.md`
- **Spec items**: C3
- **Depends on**: Task 1.1
- **Action**: In the existing step 3 ("Scan Project Knowledge"), after the current `ls` and `cat` commands, add instructions to produce a structured configuration baseline following the format from `config-analysis-framework.md`. Specifically:
  1. After reading `.claude/` files, produce a `CONFIG_BASELINE` structure capturing: each agent's name, path, and coverage; each skill's name, path, and coverage; each rule file's name, path, and coverage; each CLAUDE.md section's heading and coverage; each configured MCP's name and coverage.
  2. For each item, summarize what it covers in one line (e.g., "github.md: commit conventions, branch workflow, gh CLI usage").
  3. Store this baseline in memory for use in step 5 (execution trace) and later injection into retro dispatch.
  4. Add a note: "Read `skills/build/config-analysis-framework.md` for the full baseline format specification."
- **Verify**: Read brief-phase.md and confirm step 3 now produces a structured CONFIG_BASELINE with coverage mapping.
- **Commit**: `feat(brief): add structured configuration baseline to step 3`

### Task 2.2: Add execution trace annotations to brief-phase.md step 5
- **Files**: `skills/build/brief-phase.md`
- **Spec items**: C4
- **Depends on**: Task 2.1
- **Action**: In step 5 ("Plan Parallel Execution Levels"), after grouping tasks into levels and classifying execution paths, add an annotation step:
  1. For each task in the sprint scope, cross-reference its description and files against the CONFIG_BASELINE items.
  2. Annotate each baseline item's `relevant_tasks` field with the task IDs where that config item's domain applies.
  3. This produces the execution trace: "rule X is relevant to tasks 2.1 and 2.3" or "agent Y's expertise applies to task 3.1."
  4. Include the annotated baseline in the level plan logged to build-progress.md.
  This piggybacks on step 5's existing task analysis — no separate pass needed.
- **Verify**: Read brief-phase.md and confirm step 5 now annotates baseline items with relevant task IDs.
- **Commit**: `feat(brief): add execution trace annotations to step 5`

### Task 2.3: Add Config Effectiveness Analysis to retro-analyst.md
- **Files**: `agents/retro-analyst.md`
- **Spec items**: C5, C6, C7, C8
- **Depends on**: Task 1.1
- **Action**: Enhance the retro-analyst agent in three places:
  1. **Input section**: Add `CONFIG_BASELINE` and `CONFIG_ANALYSIS_FRAMEWORK` to the list of inputs received from the build skill. Describe: "The configuration baseline captured during Brief, with per-task relevance annotations, plus the shared analysis framework defining comparison protocol and suggestion format."
  2. **Analysis Protocol**: Add a new section 6 "Configuration Effectiveness Analysis":
     - Compare the baseline against sprint outcomes using the comparison protocol from the framework
     - For each baseline item: was it relevant? Was it sufficient? Cite evidence (files, errors, builder outputs)
     - Identify patterns that emerged without config coverage
     - Identify stale config items that were never relevant
     - Follow the suggestion format from the framework (operation, type, target, evidence, proposed action)
     - Cap at 5 suggestions, prioritized by evidence strength
     - This section is MANDATORY even when no gaps are found (use compact no-gaps format)
  3. **Output Format**: Add a new section to the structured retro report template:
     ```markdown
     ## Configuration Effectiveness
     {Analysis of configuration baseline vs sprint reality}

     | Operation | Type | Target | Evidence | Proposed Action |
     |-----------|------|--------|----------|-----------------|
     | {ADD/UPDATE/REMOVE} | {agent/skill/rule/claude_md/mcp} | {path} | {specific files, patterns, sprint data} | {concrete action} |

     **Baseline summary**: {N} agents, {M} skills, {K} rules analyzed. {X} relevant, {Y} gaps found.
     ```
     When no gaps: use the compact one-line format from the framework.
- **Verify**: Read retro-analyst.md and confirm: (a) input section lists CONFIG_BASELINE and CONFIG_ANALYSIS_FRAMEWORK, (b) analysis protocol has section 6 with mandatory language, (c) output format includes the Configuration Effectiveness table.
- **Commit**: `feat(retro-analyst): add mandatory Configuration Effectiveness Analysis section`

### Task 2.4: Enhance retro-phase.md dispatch payload
- **Files**: `skills/build/retro-phase.md`
- **Spec items**: C9, C18
- **Depends on**: Tasks 1.1, 2.1, 2.3
- **Action**: In step 2 ("Dispatch Retro-Analyst Agent"), enhance the dispatch payload:
  1. Before dispatching, add an explicit instruction: "Read `skills/build/config-analysis-framework.md` and include its full content in the dispatch payload under `CONFIG_ANALYSIS_FRAMEWORK:`."
  2. Add `CONFIG_BASELINE` to the dispatch payload (from the brief phase's structured baseline, including execution trace annotations).
  3. The enhanced payload should look like:
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
  4. In step 4 ("Extract Actionable Items"), add: "5. **Configuration Suggestions**: Extract config effectiveness suggestions (Operation/Type/Target/Evidence/Proposed Action format) and route them alongside Proposed Level-ups for level-up processing. Level-up handles ADD/UPDATE/REMOVE operations uniformly."
  5. Add a note to step 2: "If CONFIG_BASELINE is not available in context (e.g., after context compression), read it from build-progress.md where the brief phase logged the annotated baseline."
- **Verify**: Read retro-phase.md and confirm: (a) dispatch payload includes CONFIG_BASELINE and CONFIG_ANALYSIS_FRAMEWORK, (b) step 4 extracts Configuration Suggestions.
- **Commit**: `feat(retro-phase): enhance dispatch with config baseline and analysis framework`

### Task 2.5: Add REMOVE operation to level-up-phase.md Step e
- **Files**: `skills/build/level-up-phase.md`
- **Spec items**: C19
- **Depends on**: Task 1.1
- **Action**: In level-up-phase.md Step e (currently handles CREATE and UPDATE), add a third operation path for REMOVE:
  1. After the existing CREATE and UPDATE clauses, add a REMOVE clause:
     - If the proposal operation is REMOVE: verify the target file exists, read it to confirm identity, delete the file, log the removal in build-progress.md.
  2. For REMOVE operations, log the file's full content to build-progress.md before deletion (enables rollback). Also update the rollback manifest example in level-up's Section 5 to include a REMOVE entry.
  3. This is a single clause alongside existing logic — no restructuring of the 5-step flow.
  4. The retro-analyst's Configuration Effectiveness suggestions route through level-up's existing 5-step flow. For REMOVE operations, steps a-d will naturally pass through quickly; the substantive work happens in Step e.
- **Verify**: Read level-up-phase.md and confirm Step e handles REMOVE alongside CREATE and UPDATE.
- **Commit**: `feat(level-up): add REMOVE operation path to Step e`

## Phase 3: /robro:tune Skill
> Depends on: Phase 1
> Parallel: can run concurrently with Phase 2
> Delivers: Standalone configuration audit skill
> Spec sections: S3

### Task 3.1: Create skills/tune/SKILL.md
- **Files**: `skills/tune/SKILL.md`
- **Spec items**: C10, C11, C12, C13
- **Depends on**: Task 1.1
- **Action**: Create the standalone configuration audit skill with:
  1. **Frontmatter**: name: tune, description: "Audit and optimize project Claude Code configuration (agents, skills, rules, CLAUDE.md, MCPs). Use when you want to review your project setup for gaps, stale items, or improvement opportunities. Not for initial setup (use /robro:setup) or build-cycle analysis (happens automatically in /robro:build).", disable-model-invocation: true
  2. **Use_When / Do_Not_Use_When**: Use when user says "tune", "audit config", "optimize setup", "review configuration". Don't use when they want initial setup (use /robro:setup), build-cycle (use /robro:build), or plan cleanup (use /robro:clean-memory).
  3. **Active-build guard**: Check status.yaml in all plan directories. If any shows an active build phase, warn: "A build is in progress. Running /robro:tune during a build may conflict with level-up changes. Continue anyway?"
  4. **Workflow**:
     - Step 1: Read `config-analysis-framework.md` for analysis protocol
     - Step 2: Scan project configuration (all .claude/ files, CLAUDE.md, .mcp.json)
     - Step 3: Produce CONFIG_BASELINE using the framework's format
     - Step 4: Analyze codebase + git history for patterns:
       - Run `git log --oneline -50` for recent activity patterns
       - Run `git diff --stat HEAD~20` for file change frequency
       - Scan source files for recurring patterns (error handling, API calls, state management)
       - Identify conventions followed implicitly but not formalized
     - Step 5: Compare baseline vs codebase reality using the framework's comparison protocol
     - Step 6: Generate suggestions using the framework's suggestion format (max 5)
     - Step 7: Present findings via AskUserQuestion with multiSelect:
       ```
       Configuration Audit Results:

       Baseline: {N} agents, {M} skills, {K} rules, {L} CLAUDE.md sections, {P} MCPs

       Suggestions:
       1. [ADD rule] .claude/rules/{name}.md — {evidence}
       2. [UPDATE agent] .claude/agents/{name}.md — {evidence}
       3. [REMOVE rule] .claude/rules/{name}.md — {evidence}

       Select suggestions to apply:
       ```
     - Step 8: Execute selected suggestions (create/update/remove files)
     - Step 9: For MCP gaps, recommend `/robro:setup` for installation instead of installing directly
  5. **Data source acknowledgment**: Include a note: "This analysis uses static codebase and git history. For deeper insights informed by actual execution data, run a /robro:build sprint — the retro phase performs sprint-informed configuration analysis automatically."
  6. **Optional retro ingestion**: If `docs/plans/*/discussion/retro-sprint-*.md` files exist, offer to incorporate findings from past retros for richer analysis.
- **Verify**: Read the created skill and confirm: (a) frontmatter is valid YAML with name/description, (b) references config-analysis-framework.md, (c) has active-build guard, (d) uses AskUserQuestion for confirmation, (e) has Do_Not_Use_When block differentiating from setup/build/clean-memory.
- **Commit**: `feat(tune): create standalone configuration audit skill`

## Phase 4: Integration & Documentation
> Depends on: Phases 2, 3
> Parallel: tasks 4.1-4.3 can run concurrently; task 4.5 runs after 4.3
> Delivers: Updated documentation, keyword detection, managed section
> Spec sections: S4

### Task 4.1: Update build SKILL.md summaries
- **Files**: `skills/build/SKILL.md`
- **Spec items**: C14
- **Depends on**: Tasks 2.3, 2.4
- **Action**: Update two phase summaries in the build SKILL.md:
  1. In Phase 4 (Retro) summary: Add "Includes mandatory Configuration Effectiveness Analysis comparing project config baseline against sprint reality"
  2. In Phase 5 (Level-up) summary: Add "Processes configuration suggestions from retro's Config Effectiveness section alongside Proposed Level-ups"
- **Verify**: Read SKILL.md and confirm both summaries mention config effectiveness.
- **Commit**: `docs(build): update retro and level-up summaries for config effectiveness`

### Task 4.2: Add tune keyword triggers to keyword-detector.sh
- **Files**: `scripts/keyword-detector.sh`
- **Spec items**: C15
- **Depends on**: Task 3.1
- **Action**: Add two new sections to the keyword detector:
  1. **Tier 1**: Add case for `*"robro tune"*|*"robro:tune"*` → "Suggestion: Use /robro:tune to audit and optimize your project's Claude Code configuration."
  2. **Tier 2**: Add tune_patterns array with natural language triggers:
     ```bash
     tune_patterns=(
       "audit config"
       "review config"
       "optimize setup"
       "tune setup"
       "check my setup"
       "improve config"
       "configuration audit"
       "check configuration"
     )
     ```
     With suggestion: "Consider using /robro:tune to audit your project's Claude Code configuration for gaps and improvements."
- **Verify**: Read keyword-detector.sh and confirm both Tier 1 case and Tier 2 pattern array exist for tune.
- **Commit**: `feat(hooks): add tune keyword triggers to keyword detector`

### Task 4.3: Update documentation files
- **Files**: `skills/setup/claude-md-template.md`, `CLAUDE.md`, `README.md`
- **Spec items**: C16
- **Depends on**: Task 3.1
- **Action**:
  1. In `skills/setup/claude-md-template.md`: Add a row to the Available Skills table:
     `| /robro:tune | Configuration | Audits and optimizes project Claude Code configuration (agents, skills, rules, CLAUDE.md, MCPs). Codebase + git history analysis. |`
  2. In root `CLAUDE.md`: Add `/robro:tune` to the Core Skills list and update the Directory Structure to include `skills/tune/SKILL.md`.
  3. In `README.md`: Add `/robro:tune` to the Skills table with description.
- **Verify**: Grep all three files for "robro:tune" and confirm presence.
- **Commit**: `docs: add /robro:tune to skills tables and directory structure`

### Task 4.4: Update .claude/CLAUDE.md managed section
- **Files**: `.claude/CLAUDE.md`
- **Spec items**: C17
- **Depends on**: Task 4.3
- **Action**: The `.claude/CLAUDE.md` file contains the robro managed section (between `<!-- robro:managed:start -->` and `<!-- robro:managed:end -->` markers). This section is generated from the template at `skills/setup/claude-md-template.md`. Since Task 4.3 updates the template, the managed section in this repo's own `.claude/CLAUDE.md` should also be updated to match.
  1. Find the `<!-- robro:managed:start -->` and `<!-- robro:managed:end -->` markers (ignoring any markers inside fenced code blocks).
  2. In the Available Skills table between these markers, add a row:
     `| /robro:tune | Configuration | Audits and optimizes project Claude Code configuration (agents, skills, rules, CLAUDE.md, MCPs). Codebase + git history analysis. |`
  3. Place the row after the existing `/robro:clean-memory` entry (or last skill row if ordering differs).
- **Verify**: Read `.claude/CLAUDE.md` and confirm /robro:tune appears in the skills table.
- **Commit**: `docs(.claude): add /robro:tune to managed section`

## Pre-mortem
| Failure Scenario | Likelihood | Impact | Mitigation |
|-----------------|------------|--------|------------|
| Retro-analyst ignores Config Effectiveness section despite being mandatory | Med | Med | The "mandatory even when no gaps" language forces the section. Framework injected in dispatch payload ensures the agent has the protocol. |
| Config baseline adds too many tokens to retro dispatch | Low | Med | Baseline is a compact summary (one line per item). For projects with <20 config items, this is minimal. |
| /robro:tune and /robro:setup confusion | Med | Low | Clear Do_Not_Use_When blocks in both skills. Setup mentions tune as next step. |
| Shared framework document gets stale | Low | Med | Single file, two consumers. Any update propagates to both automatically. |
| Level-up overwhelmed by too many config suggestions | Low | Med | Cap at 5 suggestions per sprint. Level-up already processes suggestions sequentially. |

## Open Questions
- Should /robro:tune be added to the setup skill's completion summary as a suggestion? (Low priority — can be added later)
