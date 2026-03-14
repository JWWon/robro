---
type: update
created: 2026-03-14T12:00:00Z
ambiguity_score: 0.09
status: ready
project_type: brownfield
dimensions:
  goal: 0.95
  constraints: 0.88
  criteria: 0.90
  context: 0.88
---

# Robro Customization Enhancements

## Goal
Restructure robro's session storage, configuration, and setup workflow to give users project-level control over model tiers, skill thresholds, and agent overrides — while enforcing proper agent usage across the pipeline.

## Problem Statement
Robro currently hardcodes session artifacts under `docs/plans/`, stores model configuration at the plugin level (not user-customizable), manages `.claude/CLAUDE.md` through inline skill instructions rather than a reusable script, has version tracking inconsistencies across 3 locations, and doesn't enforce that all configured agents are actually dispatched at their designated pipeline steps. Users cannot customize model tiers or thresholds per project.

## Users & Stakeholders
- **Plugin users**: Benefit from project-level config customization (model tiers, thresholds) and cleaner `.robro/` directory convention
- **Plugin developers**: Benefit from automated version sync, agent audit, and clearer CLAUDE.md management
- **CI/CD**: Lefthook hook ensures version consistency on tag push

## Requirements

### Must Have
- Move session artifacts from `docs/plans/` to `.robro/sessions/` across all skills, hooks, and scripts (14+ files). Clean break — no migration, no dual-path detection.
- Project-level `.robro/config.json` with `$schema` property: model tiers (light/standard/complex), skill thresholds (ambiguity_threshold, sprint_hard_cap), per-agent model overrides. Optional — plugin falls back to built-in defaults when absent.
- JSON Schema file (`config.schema.json`) at plugin root, documenting all fields with default values.
- New `scripts/manage-claudemd.sh` shell script for `.claude/CLAUDE.md` managed block management. Handles version detection, block replacement, and the new marker format.
- Version marker format change: `<!-- robro@{version}:managed:start -->` (was `<!-- robro:managed:start [VERSION] -->`).
- Update `/robro:setup` to invoke `manage-claudemd.sh` instead of inline CLAUDE.md management logic.
- `/robro:setup` configures `.gitignore` for `.robro/` patterns: `.robro/sessions/*/status.yaml`, `.robro/sessions/*/research/`, `.robro/sessions/*/discussion/`, `.robro/sessions/*/*.bak.*`, and `.claude/worktrees/`.
- plugin.json is the single version source of truth. `scripts/sync-versions.sh` syncs marketplace.json to match. Lefthook hook triggers sync on tag push.
- Full agent audit: add model-config entries for all 11 agents (4 missing: contrarian, simplifier, ontologist, planner). Create missing `plan-reviewer-prompt.md` and `spec-reviewer-prompt.md` files. Strengthen idea + plan skill instructions to explicitly mandate which agents to dispatch at each step.
- Lightweight agent enforcement hooks — validate instructions are followed when applicable, not per-dispatch tracking.

### Should Have
- Written version management rules in CLAUDE.md documenting the plugin.json → sync workflow
- `/robro:setup` offers to create `.robro/config.json` with documented defaults when absent
- Config defaults match current behavior exactly (ambiguity_threshold: 0.1, sprint_hard_cap: 30, current model-config.yaml tiers)

### Won't Have (Non-goals)
- Migration tooling from `docs/plans/` to `.robro/sessions/` — clean break
- Reinforcement cap in user-facing config — stays internal as a circuit breaker
- Heavy per-dispatch agent tracking hooks — lightweight enforcement only
- Dual-path detection (checking both old and new paths)
- Config for sessions directory path — hardcoded to `.robro/sessions/`

## Constraints
- Pure markdown/shell plugin — no TypeScript, no compiled artifacts, no databases
- All scripts must use `${CLAUDE_PLUGIN_ROOT}` for paths, never hardcode absolute paths
- Scripts receive JSON on stdin, use `jq` to extract fields
- Hook scripts must be executable (`chmod +x`) and pass `bash -n` syntax check
- Lefthook is already configured with protect-main hooks — new hooks must coexist
- Bun is the package manager (lefthook configured via bun)
- Existing `.claude/worktrees/` workflow must be preserved

## Success Criteria
1. Zero `docs/plans/` references in runtime code (skills, hooks, scripts). Only allowed in migration docs/changelog.
2. `.robro/config.json` with `$schema` property works: model tiers, thresholds, per-agent overrides. Plugin runs correctly without it (built-in defaults).
3. `scripts/manage-claudemd.sh` creates/updates managed blocks with `<!-- robro@{version}:managed:start -->` format. Version read from plugin.json.
4. `/robro:setup` configures `.gitignore` for all `.robro/` patterns AND `.claude/worktrees/`.
5. `scripts/sync-versions.sh` syncs marketplace.json version to match plugin.json. Lefthook hook triggers on tag push.
6. All 11 agents have model-config entries. Missing prompt files created. Idea + plan skill instructions explicitly name which agents to dispatch at each step.
7. JSON Schema (`config.schema.json`) at plugin root validates config.json structure with documented defaults.

## Proposed Approach
**Bottom-up (5 phases):** Start with foundational changes, each independently testable:

1. **Path migration**: Replace `docs/plans/` with `.robro/sessions/` across all 14+ files. Shell scripts already use a `PLANS_DIR` variable — update that first, then skill markdown files.
2. **Config system**: Create `config.schema.json`, implement config loading in skills/scripts that reads `.robro/config.json` with fallback to built-in defaults. Replace plugin-level `model-config.yaml`.
3. **Setup script**: Create `manage-claudemd.sh` with new marker format. Update setup skill to invoke it. Add `.gitignore` rules for `.robro/` + `.claude/worktrees/`.
4. **Version sync**: Create `sync-versions.sh`. Configure lefthook hook for tag push events. Add version management rules to CLAUDE.md.
5. **Agent audit**: Fix missing files, add model-config entries, rewrite skill instructions for explicit agent dispatch, add lightweight enforcement hooks.

## Assumptions Exposed
| Assumption | Status | Resolution |
|---|---|---|
| `.robro/` hidden directory is appropriate for session artifacts | Verified | OMC uses `.omc/`, most content is gitignored anyway. User confirmed. |
| JSON is preferred over YAML for config | Verified | User chose JSON for native schema support. |
| Clean break is acceptable (no migration) | Verified | User explicitly chose no migration. |
| All 11 agents should have model-config entries | Verified | User chose full audit + fix. Challenge agents get entries for escalation-to-subagent case. |
| Reinforcement cap should stay internal | Verified | Simplifier challenge: users setting it high would burn tokens. User agreed. |
| Lefthook tag hook is worth the setup | Verified | Contrarian challenge raised friction concern. User confirmed — automation prevents the version drift already observed. |

## Context
Robro is a pure markdown/shell Claude Code plugin with 11 agents, 5 skills, and 7 hook scripts. The codebase currently hardcodes `docs/plans/` in 14+ files. Shell scripts use a `PLANS_DIR` variable (easy to update), but skill markdown embeds the path in prose.

Reference plugins:
- **oh-my-claudecode**: Uses `.omc/state/` with env vars for hook context, template variable substitution. Validated the dot-directory pattern.
- **ouroboros**: Event-sourced persistence, ontology similarity convergence, pathology detection. Validated iterative review loops and ambiguity scoring.

Version tracking has inconsistencies: plugin.json (0.1.2), marketplace.json (0.1.0), managed block (0.1.1). No automated sync exists.

## Open Questions
- None remaining.

## Key Research Findings
- `docs/plans/` is referenced in 14+ files (5 skills, 7 scripts, config/docs). Shell scripts use `PLANS_DIR` variable — parameterizable.
- 2 missing prompt files in plan skill (`plan-reviewer-prompt.md`, `spec-reviewer-prompt.md`) — dead references or intended as inline.
- 4 agents lack model-config entries (contrarian, simplifier, ontologist, planner) — rely on `default` tier.
- Version inconsistency across 3 locations with no sync mechanism.
- OMC's `.omc/` pattern validates the `.robro/` hidden directory approach.
- Setup skill's managed block management is well-structured but uses inline logic — ready to extract to a script.
