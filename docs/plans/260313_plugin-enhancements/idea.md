---
type: update
created: 2026-03-13T00:00:00Z
ambiguity_score: 0.13
status: ready
project_type: brownfield
dimensions:
  goal: 0.95
  constraints: 0.85
  criteria: 0.80
  context: 0.85
---

# Robro Plugin Enhancements: Setup, Clean-Memory, Open Source, Stricter Threshold

## Goal

Enhance the robro plugin with project-level setup automation, completed plan cleanup, open-source packaging, and a stricter ambiguity quality gate.

## Problem Statement

Robro currently has no onboarding experience — users must manually configure their project for robro compatibility (CLAUDE.md, .gitignore, recommended MCPs). Completed plans accumulate in `docs/plans/` with no cleanup mechanism, cluttering session-start output. The plugin lacks a README and license for open-source distribution. The ambiguity threshold (0.2) allows early exit before requirements are fully crystallized.

## Users & Stakeholders

- **Plugin users**: Developers using robro in their projects. They need frictionless setup and clean project state.
- **Plugin contributors**: Developers extending robro. They need README documentation and clear licensing.
- **The robro author**: Wants to open-source the plugin with proper attribution to inspired projects.

## Requirements

### Must Have

- **`/robro:setup` skill** (with `disable-model-invocation: true`) for project-level configuration:
  - Section-managed robro block in `.claude/CLAUDE.md` — create file if missing, update only the robro section if file exists. Delimited markers for idempotent updates.
  - Detect existing MCP/skill configurations in Claude settings. Present checklist of missing recommended items:
    - context7 (MCP) — replaces web search & web fetch for docs
    - grep (MCP) — replaces search and read codes from GitHub
    - github (rule) — guide for git and gh CLI usage
    - agent-browser (skill) — alternative to playwright (https://agent-browser.dev)
  - Only install items the user explicitly confirms from the checklist.
  - Configure `.gitignore` with robro plan temporal artifact rules (`docs/plans/*/research/`, `docs/plans/*/discussion/`, `docs/plans/*/status.yaml`, `docs/plans/*.bak.*`).
  - Re-running is idempotent — no duplicates, no unnecessary changes.

- **`/robro:clean-memory` skill** (with `disable-model-invocation: true`) to clean up completed plans:
  - Identify completed plans where `status.yaml` has `skill: none`.
  - Perform cross-plan pattern analysis before deletion — compare patterns ACROSS completed plans against current project rules, agents, and skills. Don't re-read individual plan artifacts (retro phase already handles per-plan analysis).
  - Present concrete improvement recommendations with user approval flow.
  - Require user confirmation per plan before deleting.
  - Delete entire plan directory (`docs/plans/YYMMDD_name/`). Committed artifacts (idea.md, plan.md, spec.yaml) are preserved in git history.

- **README.md** — standard GitHub open-source README:
  - What robro is (companion plugin, not tool)
  - Installation instructions
  - Pipeline overview (idea → spec → build)
  - Credits section with thanks to inspired plugins: oh-my-claudecode, ouroboros, superpowers

- **MIT LICENSE file** — standard MIT license text.

- **plugin.json metadata** — add `license`, `repository`, `homepage` fields for open-source distribution.

- **Ambiguity threshold change** — update from 0.2 to 0.1 across all references:
  - `skills/idea/SKILL.md` (6 occurrences)
  - `agents/critic.md` (4 occurrences)
  - `CLAUDE.md` (2 occurrences)
  - `.claude/CLAUDE.md` (1 occurrence)

- **Ontologist activation threshold** — update from 0.3 to 0.2 (proportional adjustment) in:
  - `skills/idea/SKILL.md`
  - `agents/ontologist.md`

### Should Have

- Setup detects project type/stack for context-aware CLAUDE.md section content.
- Clean-memory presents recommendations interactively with per-recommendation approval.

### Won't Have (Non-goals)

- Full project CLAUDE.md generation — robro manages only its own delimited section.
- Plan archiving — entire directories are deleted; git preserves history.
- Per-plan re-analysis in clean-memory — the build retro phase already handles that.
- README replacing or consolidating root CLAUDE.md — separate files for separate audiences.

## Constraints

- Both setup and clean-memory use `skills/<name>/SKILL.md` with `disable-model-invocation: true` to prevent auto-invocation while retaining directory structure for supporting files.
- The setup CLAUDE.md section must use delimited markers (e.g., `<!-- robro:start -->...<!-- robro:end -->`) for idempotent section management.
- MCP/skill detection reads from Claude's configuration files (`.claude/settings.json`, project-level settings).
- The 4 recommended MCPs/skills are a fixed list maintained in the skill file — updates ship with version bumps.
- Threshold changes must not affect existing completed plans (both score 0.08-0.09, well below 0.1).

## Success Criteria

1. `/robro:setup` on a fresh project creates `.claude/CLAUDE.md` with robro section; on existing project, updates only the robro section without touching other content.
2. `/robro:setup` re-run is idempotent — no duplicates, no changes if nothing new.
3. `/robro:setup` presents checklist of unconfigured MCPs/skills; only installs user-confirmed items.
4. `/robro:setup` adds `docs/plans/` temporal artifact rules to `.gitignore`.
5. `/robro:clean-memory` lists only plans where `status.yaml` has `skill: none`.
6. `/robro:clean-memory` shows cross-plan pattern insights before deletion.
7. `/robro:clean-memory` requires user confirmation per plan before deleting.
8. `README.md` present with installation, pipeline flow, and credits section.
9. `LICENSE` file present with MIT text.
10. `plugin.json` has `license`, `repository`, `homepage` fields.
11. All 13 ambiguity threshold references updated from 0.2 to 0.1.
12. Ontologist activation threshold updated from 0.3 to 0.2.

## Proposed Approach

Both `/robro:setup` and `/robro:clean-memory` are implemented as skills with `disable-model-invocation: true` in `skills/setup/SKILL.md` and `skills/clean-memory/SKILL.md`. This provides directory structure for supporting files (templates, reference configs) while preventing Claude from auto-invoking these imperative operations.

The setup skill manages a delimited section in `.claude/CLAUDE.md` using marker comments, making updates idempotent and non-destructive to existing content. MCP/skill detection reads Claude's settings files to determine what's already configured.

Clean-memory's cross-plan analysis complements (not duplicates) the build retro phase by focusing on aggregate patterns across all completed plans rather than per-plan artifact re-reading.

README.md and LICENSE are straightforward open-source packaging. The threshold changes are mechanical find-and-replace across known file locations.

## Assumptions Exposed

| Assumption | Status | Resolution |
|---|---|---|
| Commands are the legacy format in Claude Code | Verified | Using skills with `disable-model-invocation: true` instead — same UX, better structure |
| Claude settings files are readable for MCP detection | Open | `.claude/settings.json` and project-level settings need verification during spec |
| Ontologist threshold should scale proportionally with gate | Verified | User confirmed 0.3 → 0.2 (proportional to gate 0.2 → 0.1) |
| Cross-plan analysis provides value beyond per-plan retros | Verified | User confirmed — focus on aggregate patterns, not individual re-analysis |
| Delimited markers work for section management | Verified | Standard pattern used by oh-my-claudecode and similar tools |
| The 4 recommended MCPs/skills are stable enough to hardcode | Open | Acceptable risk — small list, version bumps handle changes |

## Context

Robro is a Claude Code plugin with 3 core skills (idea, spec, build), 11 agents, and 8 hook scripts. The plugin is at version 0.1.0 with one completed plan (`260312_execution-harness`). The codebase uses `docs/plans/` for plan artifacts with `.gitignore` rules for temporal files. There is no onboarding, no cleanup mechanism, and no open-source packaging.

Reference plugins that shaped robro's architecture:
- **oh-my-claudecode** (nicobailon/oh-my-claudecode) — state file pattern, CLAUDE.md template management
- **ouroboros** (dnakov/ouroboros) — iterative review loops, hook guardrails
- **superpowers** (anthropics/claude-code-superpowers) — structured agent status protocol

## Open Questions

None — all dimensions scored above threshold.

## Key Research Findings

- **13 hardcoded threshold references** across 4 files need updating (idea SKILL.md: 6, critic.md: 4, CLAUDE.md: 2, .claude/CLAUDE.md: 1).
- **Ontologist activation** (0.3) is in 2 files: `skills/idea/SKILL.md` and `agents/ontologist.md`.
- **No commands/ directory** exists — creating `skills/` entries with `disable-model-invocation: true` is the preferred approach.
- **plugin.json** lacks `license`, `repository`, `homepage` fields needed for open-source distribution.
- Existing completed plans (ambiguity scores 0.08-0.09) already pass the stricter 0.1 threshold.
