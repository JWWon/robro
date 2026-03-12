---
spec: spec.yaml
idea: idea.md
created: 2026-03-13T00:00:00Z
---

# Implementation Plan: Plugin Enhancements

## Overview

Enhance the robro plugin with a setup skill for project-level onboarding, a clean-memory skill for completed plan cleanup, open-source packaging (README + LICENSE), and a stricter ambiguity threshold (0.2→0.1). All new skills use `disable-model-invocation: true` to prevent auto-invocation.

## Tech Context

- **Plugin framework**: Claude Code plugin system with `skills/<name>/SKILL.md`, `agents/*.md`, and `hooks/*.json`
- **Skill frontmatter**: `name`, `description`, `argument-hint`, `disable-model-invocation` fields
- **MCP config locations**: `~/.claude.json` (user-level `mcpServers` key), `.mcp.json` (project-level)
- **MCP CLI**: `claude mcp add --scope project --transport stdio <name> -- <cmd> [args]`
- **Section management**: HTML comment delimiters `<!-- robro:managed:start -->...<!-- robro:managed:end -->`
- **Status.yaml**: Plan root (`docs/plans/*/status.yaml`), gitignored. Legacy plans may have it in `discussion/status.yaml`.

## Architecture Decision Record

| Decision | Rationale | Alternatives Considered | Trade-offs |
|---|---|---|---|
| MCP detection via `~/.claude.json` + `.mcp.json` file reads | Researcher confirmed MCPs stored here, not in `settings.json` | `claude mcp list` CLI | Direct file read is faster but format may change; CLI is stable but needs stdout parsing |
| Use `claude mcp add --scope project` for MCP install | Official CLI API; writes `.mcp.json` correctly | Direct `.mcp.json` file write | CLI is safer but requires shell execution; direct write risks format errors |
| Section delimiters: `<!-- robro:managed:start/end -->` | HTML comments invisible in rendered markdown, unique enough to avoid collisions | Markdown heading, YAML markers | More unique = less collision risk, but harder to hand-edit if needed |
| Clean-memory checks both status.yaml locations | Completed plan 260312 has status.yaml in `discussion/`, not plan root (legacy) | Migration step, heuristic | Adds fallback logic for a legacy edge case that phases out naturally |
| Cross-plan reads: `spec-mutations.log` + `spec.yaml` only | Committed, structured data sources. `discussion/` is gitignored and may not exist | Read all artifacts | Focused reading avoids missing-file issues; spec-mutations.log has richest pattern data |
| Fix reference plugin URLs | All 3 wrong: oh-my-claudecode→Yeachan-Heo, ouroboros→Q00, superpowers→obra | Keep as-is | Correct attribution required for open source |

## File Map

| File | Action | Responsibility |
|---|---|---|
| `skills/setup/SKILL.md` | create | Setup skill — CLAUDE.md section management, MCP/skill checklist, .gitignore |
| `skills/setup/claude-md-template.md` | create | Template content for the robro-managed CLAUDE.md section |
| `skills/clean-memory/SKILL.md` | create | Clean-memory skill — plan detection, cross-plan analysis, deletion |
| `README.md` | create | Open-source README with installation, pipeline, credits |
| `LICENSE` | create | MIT license |
| `.claude-plugin/plugin.json` | modify | Add license, repository, homepage fields |
| `skills/idea/SKILL.md` | modify | Update ambiguity threshold 0.2→0.1, ontologist 0.3→0.2 |
| `agents/critic.md` | modify | Update ambiguity threshold 0.2→0.1 |
| `agents/ontologist.md` | modify | Update ontologist threshold 0.3→0.2 |
| `CLAUDE.md` | modify | Update threshold refs 0.2→0.1, fix 3 reference plugin URLs |
| `.claude/CLAUDE.md` | modify | Update threshold ref 0.2→0.1 (1 occurrence) |

## Phase 1: Threshold & Attribution Fixes
> Depends on: none
> Parallel: tasks 1.1, 1.2, and 1.3 can run concurrently
> Delivers: Correct ambiguity thresholds and reference plugin URLs across all files
> Spec sections: S4, S5

### Task 1.1: Update ambiguity threshold from 0.2 to 0.1
- **Files**: `skills/idea/SKILL.md`, `agents/critic.md`, `CLAUDE.md`, `.claude/CLAUDE.md`
- **Spec items**: C13
- **Depends on**: none
- **Action**: Find all occurrences of the ambiguity threshold value `0.2` in these 4 files and replace with `0.1`. Specific locations:
  - `skills/idea/SKILL.md`: Lines containing `≤ 0.2` in gate conditions (2 occurrences in status.yaml examples), the target display `(target: ≤ 0.2)`, the completion gate condition `ambiguity ≤ 0.2 AND`, and the open questions reference `ambiguity ≤ 0.2`
  - `agents/critic.md`: The threshold statement `≤ 0.2 to pass`, PASS condition `≤ 0.2`, NEEDS_WORK condition `> 0.2`, ACCEPT_WITH_RESERVATIONS condition `≤ 0.2`
  - `CLAUDE.md`: The planning phase gate `ambiguity ≤ 0.2` and the idea skill description `≤ 0.2 threshold gate`
  - `.claude/CLAUDE.md`: The threshold table `ambiguity ≤ 0.2 to proceed`
- **Test**: After changes, grep for `0\.2` in these 4 files — should return zero matches for the threshold pattern (note: 0.25, 0.20 in formulas are different values and should NOT be changed)
- **Verify**: `grep -n '≤ 0\.2\|<= 0\.2\|> 0\.2' skills/idea/SKILL.md agents/critic.md CLAUDE.md .claude/CLAUDE.md` — should return only the formula lines (0.25, 0.35 weights), not threshold conditions
- **Commit**: `fix: tighten ambiguity threshold from 0.2 to 0.1`

### Task 1.2: Update ontologist activation threshold from 0.3 to 0.2
- **Files**: `skills/idea/SKILL.md`, `agents/ontologist.md`
- **Spec items**: C14
- **Depends on**: none
- **Action**: Update the ontologist activation condition (3 changes total):
  - `skills/idea/SKILL.md` line 260: Change `ambiguity > 0.3` to `ambiguity > 0.2` in the Step 5 Challenge Mode Escalation section (Round 8+ activation). Note: the Stall detection section (line 266) does NOT contain `0.3` — it uses a round-count condition, not a threshold condition.
  - `skills/idea/SKILL.md` line 46: Change example value `ambiguity: 0.35` to `ambiguity: 0.25` in the status.yaml YAML block — it illustrates "above ontologist activation threshold"
  - `agents/ontologist.md` line 3: Change `>0.3` to `>0.2` in the description frontmatter
- **Test**: Grep for `0\.3` in these 2 files — only formula weights (0.30, 0.35) should remain, not threshold conditions
- **Verify**: `grep -n 'ambiguity.*0\.3\|>0\.3\|> 0\.3' skills/idea/SKILL.md agents/ontologist.md` — should return empty
- **Commit**: `fix: adjust ontologist activation threshold from 0.3 to 0.2`

### Task 1.3: Fix reference plugin URLs
- **Files**: `CLAUDE.md` (root only — `.claude/CLAUDE.md` does not contain these references)
- **Spec items**: C15
- **Depends on**: none
- **Action**: Replace incorrect repository references in root `CLAUDE.md` (3 replacements on lines 26-28):
  - `nicobailon/oh-my-claudecode` → `Yeachan-Heo/oh-my-claudecode`
  - `dnakov/ouroboros` → `Q00/ouroboros`
  - `anthropics/claude-code-superpowers` → `obra/superpowers`
- **Test**: Grep for the old org names — should return zero matches
- **Verify**: `grep -rn 'nicobailon\|dnakov\|anthropics/claude-code-superpowers' CLAUDE.md .claude/CLAUDE.md` — should return empty
- **Commit**: `fix: correct reference plugin repository URLs`

## Phase 2: Open Source Packaging
> Depends on: Phase 1 (URLs must be correct for README credits)
> Parallel: tasks 2.1 and 2.2 can run concurrently; 2.3 depends on 2.2 for plugin.json version
> Delivers: README.md, LICENSE, updated plugin.json ready for open-source distribution
> Spec sections: S3

### Task 2.1: Create MIT LICENSE file
- **Files**: `LICENSE`
- **Spec items**: C11
- **Depends on**: none
- **Action**: Create a standard MIT LICENSE file at repo root. Copyright holder: JWWon. Year: 2025-present.
- **Test**: File exists and contains "MIT License" header
- **Verify**: `head -1 LICENSE` — should output "MIT License"
- **Commit**: `docs: add MIT license`

### Task 2.2: Update plugin.json metadata
- **Files**: `.claude-plugin/plugin.json`
- **Spec items**: C12
- **Depends on**: none
- **Action**: Add the following fields to plugin.json:
  ```json
  {
    "license": "MIT",
    "repository": "https://github.com/JWWon/robro",
    "homepage": "https://github.com/JWWon/robro"
  }
  ```
  Keep existing fields unchanged. Validate JSON syntax after editing.
- **Test**: JSON is valid and contains the new fields
- **Verify**: `cat .claude-plugin/plugin.json | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['license']=='MIT'; assert 'repository' in d; print('OK')"` — should print "OK"
- **Commit**: `chore: add license and repository to plugin.json`

### Task 2.3: Create README.md
- **Files**: `README.md`
- **Spec items**: C10
- **Depends on**: Task 1.3 (correct URLs for credits)
- **Action**: Create README.md at repo root with these sections:
  1. **Header**: Plugin name, tagline ("your project companion"), badges (MIT license)
  2. **What is robro?**: 2-3 sentences. Companion not tool, coworker vibe. Claude Code plugin that extends planning and execution.
  3. **Pipeline Overview**: Diagram of `/robro:idea` → `idea.md` → `/robro:spec` → `plan.md + spec.yaml` → `/robro:build` → working code
  4. **Skills**: Brief description of each skill (idea, spec, build, setup, clean-memory)
  5. **Installation**: `claude plugin install robro` or development setup with `claude --plugin-dir .`
  6. **Quick Start**: Example usage flow
  7. **Credits**: Thanks to inspired plugins with correct GitHub links:
     - oh-my-claudecode (Yeachan-Heo/oh-my-claudecode) — state file pattern, CLAUDE.md management
     - ouroboros (Q00/ouroboros) — iterative review loops, hook guardrails
     - superpowers (obra/superpowers) — structured agent status protocol
  8. **License**: MIT
- **Test**: File exists, contains all required sections
- **Verify**: `grep -c '## ' README.md` — should return 7+ (one per section)
- **Commit**: `docs: add README for open-source release`

## Phase 3: Setup Skill
> Depends on: Phase 1 (template needs correct threshold values)
> Parallel: tasks 3.1 and 3.2 can run concurrently; 3.3–3.5 are sequential
> Delivers: Working `/robro:setup` skill that configures projects for robro
> Spec sections: S1

### Task 3.1: Create setup skill directory and frontmatter
- **Files**: `skills/setup/SKILL.md`
- **Spec items**: C1 (partial)
- **Depends on**: none
- **Action**: Create `skills/setup/SKILL.md` with frontmatter:
  ```yaml
  ---
  name: setup
  description: Configure a project for robro — manages CLAUDE.md section, recommends MCPs/skills, configures .gitignore. Run this once when adding robro to a new project.
  disable-model-invocation: true
  argument-hint: "(no arguments needed)"
  ---
  ```
  Add skeleton structure with section headers for the full workflow:
  - Step 1: CLAUDE.md Section Management
  - Step 2: MCP/Skill Detection & Checklist
  - Step 3: .gitignore Configuration
  - Step 4: Completion Summary
- **Test**: File exists with valid YAML frontmatter
- **Verify**: `head -6 skills/setup/SKILL.md` — should show frontmatter with `disable-model-invocation: true`
- **Commit**: `feat: scaffold setup skill`

### Task 3.2: Create CLAUDE.md section template
- **Files**: `skills/setup/claude-md-template.md`
- **Spec items**: C1 (partial)
- **Depends on**: none
- **Action**: Create template content for the robro-managed section of `.claude/CLAUDE.md`. This is what gets injected between the `<!-- robro:managed:start -->` and `<!-- robro:managed:end -->` markers. Content should include:
  - Robro pipeline overview (idea → spec → build)
  - Available skills with descriptions
  - Plan artifacts location (`docs/plans/`)
  - How to resume interrupted pipelines
  - Key rules: skills orchestrate, agents execute; no code without spec; status.yaml drives hooks
  Keep it concise — this is a reference for Claude, not documentation for humans.
- **Test**: File exists and contains pipeline overview content
- **Verify**: `grep -c 'robro' skills/setup/claude-md-template.md` — should return 3+
- **Commit**: `feat: add CLAUDE.md section template for setup skill`

### Task 3.3: Write SKILL.md — CLAUDE.md section management workflow
- **Files**: `skills/setup/SKILL.md`
- **Spec items**: C1, C2, C5
- **Depends on**: Task 3.1, Task 3.2
- **Action**: Write the Step 1 section of SKILL.md with the full CLAUDE.md management workflow:
  1. Read the template from `claude-md-template.md` (reference via `skills/setup/claude-md-template.md`)
  2. Check if `.claude/CLAUDE.md` exists in the target project
  3. If file exists: search for `<!-- robro:managed:start -->` marker
     - If marker found: replace content between start and end markers with template
     - If marker not found: append template wrapped in markers at end of file
  4. If file does not exist: create `.claude/` directory and `.claude/CLAUDE.md` with template wrapped in markers
  5. Edge case rules:
     - If start marker exists without end marker: treat everything after start as robro section, replace with template + end marker
     - If multiple marker pairs: use first pair only, warn user about duplicates
     - Markers inside triple-backtick fenced code blocks: ignore (they're documentation, not actual markers)
  6. Report what was done: "Created new .claude/CLAUDE.md with robro section" or "Updated existing robro section in .claude/CLAUDE.md"
- **Test**: Skill contains section management logic with all edge cases
- **Verify**: `grep -c 'robro:managed' skills/setup/SKILL.md` — should return 4+ (start marker, end marker, detection, edge cases)
- **Commit**: `feat: add CLAUDE.md section management to setup skill`

### Task 3.4: Write SKILL.md — MCP/skill detection and checklist
- **Files**: `skills/setup/SKILL.md`
- **Spec items**: C3, C5
- **Depends on**: Task 3.3
- **Action**: Write the Step 2 section of SKILL.md with MCP/skill detection:
  1. Define the recommended items list (hardcoded, 4 items):
     ```
     | Name | Type | Purpose | Detection | Install Command |
     |------|------|---------|-----------|-----------------|
     | context7 | MCP | Up-to-date library docs | Check ~/.claude.json and .mcp.json for "context7" key | claude mcp add --scope project context7 -- npx -y @anthropic-ai/context7-mcp |
     | grep | MCP | Search GitHub code | Check ~/.claude.json and .mcp.json for "grep" key | claude mcp add --scope project grep -- npx -y @anthropic-ai/grep-mcp |
     | github | Rule | Git and gh CLI guide | Glob `.claude/rules/` for any file mentioning git/github (by filename or content grep). If ANY git-related rule exists, skip. | Create `.claude/rules/github.md` with git/gh CLI guidance |
     | agent-browser | Skill | Browser automation | Glob `.claude/skills/agent-browser/` directory OR check `~/.claude/plugins/installed_plugins.json` for "agent-browser" entry | `npx skills add vercel-labs/agent-browser --skill agent-browser` |
     ```
  2. Detection logic per item type:
     - **MCP servers**: Read `~/.claude.json` (check `mcpServers` object for key name) AND read `.mcp.json` at project root (same structure). If key exists in either, item is configured.
     - **Rules**: Glob `.claude/rules/*.md`, then grep each for "git" or "github" keywords. If ANY rule file contains git-related content, the github rule is considered configured. This avoids creating duplicates when the user already has git conventions in a differently-named file.
     - **Skills**: Check for `.claude/skills/{name}/SKILL.md` directory OR search `~/.claude/plugins/installed_plugins.json` for the plugin name. Either match = configured.
  3. Present checklist via AskUserQuestion with multiSelect:
     - Show each unconfigured item with description
     - Already-configured items shown as "(already configured)" and not selectable
     - User selects which to install
  4. For each confirmed item: execute the install command
  5. Report results
- **Test**: Skill contains detection logic for all 4 items and correct install commands
- **Verify**: `grep -c 'claude mcp add\|npx skills add' skills/setup/SKILL.md` — should return 3+ (2 MCPs + 1 skill install)
- **Commit**: `feat: add MCP/skill detection and checklist to setup skill`

### Task 3.5: Write SKILL.md — .gitignore configuration
- **Files**: `skills/setup/SKILL.md`
- **Spec items**: C4, C5
- **Depends on**: Task 3.4
- **Action**: Write the Step 3 section of SKILL.md with .gitignore management:
  1. Define the gitignore rules to add:
     ```
     # Robro plan artifacts (temporal)
     docs/plans/*/research/
     docs/plans/*/discussion/
     docs/plans/*/status.yaml
     docs/plans/*.bak.md
     docs/plans/*.bak.yaml
     ```
  2. Check if `.gitignore` exists in the target project
  3. If exists: read content, check for each rule individually (idempotent — don't add duplicates)
  4. If not exists: create with the rules
  5. Append only missing rules with the `# Robro plan artifacts (temporal)` header comment
  6. Also write the Step 4 completion summary that reports all actions taken
- **Test**: Skill contains gitignore rules and idempotency check logic
- **Verify**: `grep -c 'docs/plans' skills/setup/SKILL.md` — should return 5+ (one per gitignore rule)
- **Commit**: `feat: add .gitignore configuration to setup skill`

## Phase 4: Clean-Memory Skill
> Depends on: Phase 1 (threshold fixes ensure consistent codebase)
> Parallel: tasks 4.1 and 4.2 are sequential; 4.3 and 4.4 are sequential after 4.2
> Delivers: Working `/robro:clean-memory` skill that cleans up completed plans
> Spec sections: S2

### Task 4.1: Create clean-memory skill directory and frontmatter
- **Files**: `skills/clean-memory/SKILL.md`
- **Spec items**: C6 (partial)
- **Depends on**: none
- **Action**: Create `skills/clean-memory/SKILL.md` with frontmatter:
  ```yaml
  ---
  name: clean-memory
  description: Clean up completed plans from docs/plans/. Analyzes cross-plan patterns, recommends improvements, then deletes confirmed plans. Run when completed plans accumulate.
  disable-model-invocation: true
  argument-hint: "(no arguments needed)"
  ---
  ```
  Add skeleton structure:
  - Step 1: Scan for Completed Plans
  - Step 2: Cross-Plan Pattern Analysis
  - Step 3: Present Analysis & Recommendations
  - Step 4: User Confirmation & Deletion
- **Test**: File exists with valid YAML frontmatter
- **Verify**: `head -6 skills/clean-memory/SKILL.md` — should show frontmatter with `disable-model-invocation: true`
- **Commit**: `feat: scaffold clean-memory skill`

### Task 4.2: Write SKILL.md — plan completion detection
- **Files**: `skills/clean-memory/SKILL.md`
- **Spec items**: C6
- **Depends on**: Task 4.1
- **Action**: Write the Step 1 section with plan completion detection:
  1. Scan `docs/plans/*/` for plan directories
  2. For each directory, check for completion by examining status.yaml:
     - First check `{plan_dir}/status.yaml` (plan root — current standard)
     - If not found, check `{plan_dir}/discussion/status.yaml` (legacy location)
     - Read the `skill` field — if `skill: none`, the plan is completed
  3. If neither status.yaml exists:
     - Check if `spec.yaml` exists in the plan directory
     - If spec.yaml exists and ALL non-superseded checklist items have `passes: true`, treat as completed
     - Otherwise, treat as unknown/active — skip with a warning
  4. Build a list of completed plans with metadata:
     - Plan name (directory basename)
     - Completion status source (plan-root status.yaml, discussion/ status.yaml, or heuristic)
     - Committed artifacts present (idea.md, plan.md, spec.yaml, spec-mutations.log)
     - Gitignored artifacts present (research/, discussion/, status.yaml)
  5. If no completed plans found, inform user and exit
- **Test**: Skill contains dual-path status.yaml detection and heuristic fallback
- **Verify**: `grep -c 'status.yaml\|discussion/' skills/clean-memory/SKILL.md` — should return 4+
- **Commit**: `feat: add plan completion detection to clean-memory skill`

### Task 4.3: Write SKILL.md — cross-plan pattern analysis
- **Files**: `skills/clean-memory/SKILL.md`
- **Spec items**: C7
- **Depends on**: Task 4.2
- **Action**: Write the Step 2 section with cross-plan analysis:
  1. For each completed plan, read committed data sources:
     - `spec-mutations.log` — parse TSV format, extract ADD/SUPERSEDE/FLIP operations
     - `spec.yaml` — extract section names, checklist item categories, final pass/fail state
  2. Aggregate patterns across all completed plans:
     - **Recurring mutation types**: Which categories of spec items get ADDed or SUPERSEDEd most? (evidence of initial spec weakness)
     - **Common section patterns**: Which spec sections appear across multiple plans?
     - **Build velocity**: Total checklist items vs items that passed vs items superseded
  3. Compare aggregated patterns against current project state:
     - Read existing agents (`agents/*.md`) — are there gaps the mutations suggest?
     - Read existing skills — do patterns suggest new skills needed?
     - Read CLAUDE.md — do patterns suggest additional rules?
  4. Generate improvement recommendations:
     - Each recommendation has: what to change, why (evidence from patterns), and priority (based on recurrence)
  5. If only 1 completed plan exists: note that cross-plan comparison is limited, provide per-plan summary instead
- **Test**: Skill contains spec-mutations.log parsing and cross-plan comparison logic
- **Verify**: `grep -c 'spec-mutations.log\|cross-plan\|recommendation' skills/clean-memory/SKILL.md` — should return 5+
- **Commit**: `feat: add cross-plan pattern analysis to clean-memory skill`

### Task 4.4: Write SKILL.md — user confirmation and deletion
- **Files**: `skills/clean-memory/SKILL.md`
- **Spec items**: C8, C9
- **Depends on**: Task 4.3
- **Action**: Write Steps 3 and 4 of SKILL.md:
  **Step 3: Present Analysis & Recommendations**
  1. Display the cross-plan analysis summary
  2. Present each recommendation via AskUserQuestion:
     - Option to apply recommendation, skip, or discuss further
  3. Apply confirmed recommendations (e.g., update CLAUDE.md, create rule files)

  **Step 4: User Confirmation & Deletion**
  1. For each completed plan, present via AskUserQuestion:
     ```
     Plan: {plan_name}
     Committed files (preserved in git): idea.md, plan.md, spec.yaml
     Gitignored files (PERMANENTLY DELETED): {list of research/, discussion/, status.yaml files}

     Delete this plan directory?
     ```
     Options: "Delete", "Keep", "Delete all remaining"
  2. For confirmed deletions: use Bash tool to `rm -rf docs/plans/{plan_name}/`
  3. After all deletions: report summary of what was deleted and what was kept
  4. If recommendations were applied, suggest committing changes
- **Test**: Skill contains per-plan confirmation with clear permanent deletion warning
- **Verify**: `grep -c 'PERMANENTLY\|AskUserQuestion\|rm -rf' skills/clean-memory/SKILL.md` — should return 3+
- **Commit**: `feat: add user confirmation and deletion to clean-memory skill`

## Pre-mortem

| Failure Scenario | Likelihood | Impact | Mitigation |
|---|---|---|---|
| MCP config format changes between Claude Code versions | Medium | Medium | Using CLI (`claude mcp add`) instead of direct file writes reduces this risk |
| Section markers in CLAUDE.md get corrupted by user edits | Low | Medium | Edge case handling: start-without-end, multiple pairs, markers in code blocks |
| Cross-plan analysis produces generic/unhelpful recommendations | Medium | Low | Scoped to structured data (spec-mutations.log, spec.yaml) rather than free-text analysis |
| User accidentally deletes plans with uncommitted changes | Low | High | Per-plan confirmation with explicit list of what will be permanently lost |
| Reference plugin URLs change again after correction | Low | Low | Version bumps handle distribution; URLs are in committed files |
| `npx skills add` command unavailable in some environments | Medium | Low | Setup skill presents the command but lets user handle execution |
| Threshold change makes interviews frustratingly long | Low | Medium | Existing plans scored 0.08-0.09 naturally; stall detection provides safety valve |

## Open Questions

- **Cross-plan analysis storage**: Display + user-approved actions (default). Writing to MEMORY.md deferred to future enhancement.
- **Version bump**: Stay at 0.1.0 for initial open-source release. Bump to 1.0.0 when all 3 core skills are battle-tested.
- **Setup self-detection**: Not needed for v1. If run inside robro repo, the skill will detect existing `.claude/CLAUDE.md` and update the section — which is harmless.
- **`npx skills add` availability**: Setup skill wraps the command in a try/catch pattern. If the command fails, report the error and provide manual install instructions as fallback.
