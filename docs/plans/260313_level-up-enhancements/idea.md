---
type: update
created: 2026-03-13T12:00:00Z
ambiguity_score: 0.09
status: ready
project_type: brownfield
dimensions:
  goal: 0.97
  constraints: 0.92
  criteria: 0.82
  context: 0.90
---

# Level-up Configuration Effectiveness & /robro:tune Skill

## Goal
Make the build cycle's level-up phase produce actionable, evidence-based project configuration suggestions by enhancing the retro-analyst's comparison capabilities, and provide a standalone `/robro:tune` skill for manual configuration audits — both sharing a single analysis framework.

## Problem Statement
The level-up phase currently only acts on "Proposed Level-ups" from the retro-analyst. The retro-analyst receives a flat list of existing `.claude/` files (PROJECT_SETUP) and is asked "How did project rules/agents perform?" — but there's no structured framework for comparing what configuration existed vs what was actually needed during the sprint. If the retro doesn't explicitly propose level-ups, the level-up phase does nothing. This makes the self-correction loop reactive (waits for the retro to mention something) rather than proactive (systematically identifying configuration gaps).

Additionally, there's no way to trigger this analysis outside of a build cycle. Users who want to audit and optimize their project's Claude Code setup (CLAUDE.md, rules, agents, skills, MCPs) have no skill that covers the full scope.

## Users & Stakeholders
- **Plugin users running /robro:build**: Get smarter retro reports with explicit configuration gap analysis and actionable suggestions that flow through the existing level-up mechanism.
- **Plugin users not in a build cycle**: Get a standalone `/robro:tune` skill for on-demand project configuration audits with the same analysis quality.

## Requirements

### Must Have
- Brief phase captures a structured configuration baseline: what exists, what each item covers (coverage mapping), and which items are relevant per task (execution trace)
- Retro-analyst has a mandatory "Configuration Effectiveness Analysis" section comparing baseline vs sprint reality — present in every retro report even when the answer is "no gaps found"
- Retro suggestions are actionable + evidence-based: cite specific files/patterns from the sprint, propose a concrete action (create/update/remove at specific path with specific content direction)
- Full lifecycle: retro can suggest adding new configuration, updating existing configuration, OR removing/consolidating unnecessary configuration
- All configuration in scope: agents, skills, rules, CLAUDE.md sections (full `.claude/` footprint plus project CLAUDE.md)
- Signal level: sprint outcome + execution trace (brief tags relevant config per task). No additional PostToolUse hooks needed
- Independent per sprint — no cross-sprint trending (that's clean-memory's responsibility)
- New `/robro:tune` skill for standalone configuration audit using codebase + git history analysis
- `/robro:tune` presents findings, asks user to select which to apply (AskUserQuestion), then executes selected changes
- Shared analysis framework (reference document) between retro-analyst and `/robro:tune` to minimize duplication

### Won't Have (Non-goals)
- No new build phases — the fix enhances existing phases (brief + retro)
- No changes to level-up phase itself — richer retro proposals flow through the existing mechanism
- No PostToolUse-level hook tracking
- No cross-sprint trending in retro (clean-memory's job)
- No clean-memory rename (separate concern)
- No changes to `/robro:setup` skill

## Constraints
- This is a Claude Code plugin — testing means structural verification (format correctness), not automated tests
- The analysis framework must work for both build-cycle context (sprint data) and standalone context (codebase + git history)
- The shared reference document must be readable by both the retro-analyst agent and the /robro:tune skill without redundancy
- Configuration suggestions depend on LLM quality — the framework defines the structure and protocol, not the content

## Success Criteria
1. `brief-phase.md` includes a step that outputs a structured configuration baseline with coverage mapping
2. `retro-analyst.md` has a "Configuration Effectiveness Analysis" section in both its analysis protocol and output format
3. `retro-phase.md` dispatch payload includes configuration baseline data
4. Retro-analyst output format includes actionable suggestions with evidence fields (files, patterns, proposed action, lifecycle operation)
5. The Config Effectiveness section is always present in example output (even when verdict is "no gaps")
6. `/robro:tune` skill exists at `skills/tune/SKILL.md` with codebase + git history analysis flow
7. `/robro:tune` uses AskUserQuestion for user confirmation before executing changes
8. Analysis framework (comparison dimensions, output format) is consistent between retro-analyst and `/robro:tune`

## Proposed Approach
Create a shared reference document (`skills/build/config-analysis-framework.md`) that defines the analysis dimensions, comparison protocol, and output format. Both the retro-analyst agent and `/robro:tune` skill reference this file. Changes to the framework propagate to both consumers.

Files to modify:
1. **`skills/build/brief-phase.md`** — Add step 3.5 (or enhance step 3) to capture structured configuration baseline with coverage mapping and per-task relevance tagging
2. **`agents/retro-analyst.md`** — Add "Configuration Effectiveness Analysis" to analysis protocol (section 5 or new section 6) and output format. Reference the shared framework document
3. **`skills/build/retro-phase.md`** — Enhance dispatch payload to include configuration baseline data alongside existing PROJECT_SETUP
4. **`skills/build/config-analysis-framework.md`** — New shared reference defining analysis dimensions, comparison protocol, suggestion format
5. **`skills/tune/SKILL.md`** — New standalone skill for manual configuration audit

## Assumptions Exposed
| Assumption | Status | Resolution |
|---|---|---|
| The retro-analyst can produce better proposals with structured input | Verified | Reference plugins (ouroboros Wonder/Reflect) show structured comparison produces better mutations |
| Brief phase is the right place for the baseline | Verified | Brief already scans `.claude/` in step 3 — this is a natural extension |
| Level-up doesn't need changes | Verified | It already acts on retro proposals — richer proposals flow through existing mechanism |
| Shared reference document avoids duplication | Verified (assumption) | DRY principle — single source of truth for analysis framework |
| Codebase + git history is sufficient data source for /robro:tune | Verified | Researcher pre-flight uses similar data sources successfully |

## Context
This is a brownfield update to the robro Claude Code plugin. The build skill's sprint lifecycle (Brief → Heads-down → Review → Retro → Level-up → Converge) is established and working. The level-up phase already creates agents, skills, and rules in the project's `.claude/` directory — this capability is unique among Claude Code plugins (verified via research of oh-my-claudecode, ouroboros, superpowers). The enhancement makes the upstream data flow (retro) smarter so level-up produces better results.

Reference plugin patterns informing this design:
- **oh-my-claudecode**: project-memory system learns passively from tool execution. We adopt the concept of structured baseline tracking (similar to ProjectMemory schema) without the PostToolUse hook complexity.
- **ouroboros**: Wonder/Reflect cycle provides structured before/after comparison with mutation proposals. We adopt the structured comparison protocol for the retro-analyst.
- **superpowers**: TDD for skills and rationalization prevention. We adopt the principle of evidence-based suggestions grounded in specific execution findings.

## Open Questions
- (None — ambiguity ≤ 0.1)

## Key Research Findings
- No reference plugin generates project-scoped agents/skills/rules from execution findings — this is robro's unique capability
- oh-my-claudecode's project-memory tracks hot paths, commands, and conventions automatically but never synthesizes new artifacts
- ouroboros's Wonder/Reflect cycle is the closest analog to structured before/after comparison — it identifies gaps and proposes concrete mutations
- superpowers demonstrates that untested skills are unreliable, but testing plugin skills requires manual walkthroughs
- The retro-analyst already receives PROJECT_SETUP and asks about rule/agent performance, but lacks a structured comparison framework — the gap is in protocol, not plumbing
