---
spec: spec.yaml
idea: idea.md
created: 2026-03-14T14:00:00Z
---

# Implementation Plan: Robro Customization Enhancements

## Overview

Restructure robro's session storage from `docs/plans/` to `.robro/sessions/`, add project-level configuration via `.robro/config.json` with JSON Schema validation, extract CLAUDE.md management into a reusable shell script, automate version sync between plugin.json and marketplace.json, and complete the agent audit with model-config entries and strengthened skill instructions.

## Tech Context

- Pure markdown/shell Claude Code plugin -- no TypeScript, no package.json, no compiled artifacts
- Scripts use `${CLAUDE_PLUGIN_ROOT}` for paths, receive JSON on stdin, parse with `jq`
- Hook scripts must be executable (`chmod +x`) and pass `bash -n` syntax check
- 8 shell scripts in `scripts/`, 5 skills in `skills/`, 11 agents in `agents/`
- Model configuration: `model-config.yaml` at plugin root with 3 tiers (light/standard/complex)
- Current version: plugin.json=0.1.2, marketplace.json=0.1.0 (drift exists)
- Worktree workflow: `.claude/worktrees/{slug}/` for branch isolation

## Architecture Decision Record

| Decision | Rationale | Alternatives Considered | Trade-offs |
|----------|-----------|------------------------|------------|
| Version sync via raw git hook (`.githooks/pre-push`) | Robro has no package.json/lefthook. Zero deps. Setup installs via `git config core.hooksPath .githooks` | lefthook (requires bun/npm), husky (requires package.json), manual process | `.githooks/` not shared via git clone -- needs setup step or documentation |
| Keep `model-config.yaml` as defaults source | config.json provides user overrides only. Brief phase reads YAML defaults, merges JSON overrides on top | Replace YAML entirely with JSON, embed defaults in schema | Users who don't create config.json get zero change in behavior |
| End marker stays `<!-- robro:managed:end -->` (no version) | Single version source in start marker. Simpler parsing. | Version in both markers (redundant), version in end only (fragile) | End marker alone can't tell you which version is installed |
| Shared config loader script `scripts/lib/load-config.sh` | Hook scripts source it for SESSIONS_DIR + config values. Avoids duplicating load logic in 8 scripts | Inline loading in each script, env vars from plugin.json | Extra file to maintain, but single source of truth for session path |
| Start marker format: `<!-- robro@{version}:managed:start -->` | Clean, parseable, grep-friendly. Version embedded in marker itself. | `<!-- robro:managed:start [VERSION] -->` (current, bracket parsing), `<!-- robro:managed:start version=X -->` (HTML-attr style) | Breaking change for existing managed blocks -- backward compat needed in manage-claudemd.sh |
| Plan skill uses `standard` tier for its own agent dispatches | Plan skill has no defined model tier -- standardizing on `standard` is balanced and predictable | Always use complex (wasteful for planning), always use light (too cheap for Architect/Critic) | May be suboptimal for very simple or very complex specs |

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `scripts/lib/load-config.sh` | create | Shared config loader -- exports SESSIONS_DIR, reads config.json |
| `scripts/session-start.sh` | modify | Replace PLANS_DIR with SESSIONS_DIR via load-config.sh |
| `scripts/pipeline-guard.sh` | modify | Replace PLANS_DIR with SESSIONS_DIR via load-config.sh |
| `scripts/error-tracker.sh` | modify | Replace PLANS_DIR with SESSIONS_DIR via load-config.sh |
| `scripts/pre-compact.sh` | modify | Replace PLANS_DIR with SESSIONS_DIR via load-config.sh |
| `scripts/stop-hook.sh` | modify | Replace PLANS_DIR with SESSIONS_DIR via load-config.sh, read sprint_hard_cap |
| `scripts/spec-gate.sh` | modify | Refactor inline `docs/plans` to use SESSIONS_DIR variable |
| `scripts/drift-monitor.sh` | modify | Refactor inline `docs/plans` to use SESSIONS_DIR variable |
| `scripts/keyword-detector.sh` | modify | Refactor inline `docs/plans` to use SESSIONS_DIR variable |
| `skills/idea/SKILL.md` | modify | Replace `docs/plans/` with `.robro/sessions/` |
| `skills/plan/SKILL.md` | modify | Replace `docs/plans/` with `.robro/sessions/`, add agent dispatch format |
| `skills/do/SKILL.md` | modify | Replace `docs/plans/` with `.robro/sessions/` |
| `skills/do/brief-phase.md` | modify | Add config.json override loading |
| `skills/tune/SKILL.md` | modify | Replace `docs/plans/` with `.robro/sessions/` |
| `skills/setup/SKILL.md` | modify | Replace .gitignore rules, invoke manage-claudemd.sh, offer config.json creation |
| `skills/setup/claude-md-template.md` | modify | Update `docs/plans/` references to `.robro/sessions/` |
| `config.schema.json` | create | JSON Schema for .robro/config.json |
| `model-config.yaml` | modify | Add 4 missing agent entries |
| `scripts/manage-claudemd.sh` | create | CLAUDE.md managed block management script |
| `scripts/sync-versions.sh` | create | Sync plugin.json version to marketplace.json |
| `.githooks/pre-push` | create | Trigger sync-versions.sh on push |
| `CLAUDE.md` | modify | Update path references, add version management rules |
| `.claude/CLAUDE.md` | modify | Updated automatically by manage-claudemd.sh (via setup) |
| `README.md` | modify | Update path references |
| `.gitignore` | modify | Update rules from `docs/plans/` to `.robro/` patterns |

## Phase 1: Foundation -- Shared Config Loader & Path Migration (Scripts)

> Depends on: none
> Parallel: tasks 1.1 and 1.2 can run concurrently; tasks 1.3-1.5 can run concurrently after 1.1
> Delivers: All 8 hook scripts use `.robro/sessions/` instead of `docs/plans/`
> Spec sections: S1

### Task 1.1: Create shared config loader script

- **Files**: `scripts/lib/load-config.sh`
- **Spec items**: C1, C2
- **Depends on**: none

- [ ] **Step 1: Create the lib directory**
  Run: `mkdir -p scripts/lib`

- [ ] **Step 2: Write the config loader script**

  Create `scripts/lib/load-config.sh`:

  ```bash
  #!/usr/bin/env bash
  # Shared config loader for robro hook scripts.
  # Source this file: source "${CLAUDE_PLUGIN_ROOT}/scripts/lib/load-config.sh"
  #
  # Exports:
  #   SESSIONS_DIR  — path to session artifacts (constant: .robro/sessions)
  #   CONFIG_FILE   — path to project config.json (.robro/config.json)
  #   robro_config  — function to read config values with defaults

  SESSIONS_DIR=".robro/sessions"
  CONFIG_FILE=".robro/config.json"

  # Read a value from .robro/config.json with a default fallback.
  # Usage: robro_config <jq_path> <default_value>
  # Example: robro_config '.thresholds.sprint_hard_cap' '30'
  robro_config() {
    local jq_path="$1"
    local default_val="$2"
    if [ -f "$CONFIG_FILE" ]; then
      local val
      val=$(jq -r "$jq_path // empty" "$CONFIG_FILE" 2>/dev/null)
      if [ -n "$val" ]; then
        echo "$val"
        return
      fi
    fi
    echo "$default_val"
  }
  ```

- [ ] **Step 3: Make the script executable**
  Run: `chmod +x scripts/lib/load-config.sh`

- [ ] **Step 4: Verify syntax**
  Run: `bash -n scripts/lib/load-config.sh`
  Expected: No output (exit code 0)

- [ ] **Step 5: Commit**
  `git add scripts/lib/load-config.sh && git commit -m "feat(scripts): create shared config loader (load-config.sh)"`

### Task 1.2: Refactor 3 scripts without PLANS_DIR variable (spec-gate.sh, drift-monitor.sh, keyword-detector.sh)

- **Files**: `scripts/spec-gate.sh`, `scripts/drift-monitor.sh`, `scripts/keyword-detector.sh`
- **Spec items**: C1
- **Depends on**: none (these scripts don't yet use load-config.sh -- this task introduces the SESSIONS_DIR variable via sourcing)

This task refactors the 3 scripts that have inline `docs/plans` occurrences (no PLANS_DIR variable) to source load-config.sh and use SESSIONS_DIR.

- [ ] **Step 1: Refactor spec-gate.sh**

  In `scripts/spec-gate.sh`, add the config loader source after the INPUT parsing (line 6), and replace all 6 inline `docs/plans` references with `$SESSIONS_DIR`:

  After line 5 (`FILE_PATH=...`), add:
  ```bash
  # Load shared config
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/load-config.sh"
  ```

  Then replace every literal `docs/plans` with `$SESSIONS_DIR`:
  - Line 27: `if [ -d "docs/plans" ]` -> `if [ -d "$SESSIONS_DIR" ]`
  - Line 28: `for dir in docs/plans/*/` -> `for dir in "$SESSIONS_DIR"/*/`
  - Line 36: `if [ -d "docs/plans" ]` -> `if [ -d "$SESSIONS_DIR" ]`
  - Line 37: `for dir in docs/plans/*/` -> `for dir in "$SESSIONS_DIR"/*/`
  - Line 52: `for dir in docs/plans/*/` -> `for dir in "$SESSIONS_DIR"/*/`
  - Line 148 (keyword-detector warning text): update the user-facing message

- [ ] **Step 2: Refactor drift-monitor.sh**

  In `scripts/drift-monitor.sh`, add the config loader source after the INPUT parsing, and replace all 4 inline `docs/plans` references with `$SESSIONS_DIR`:

  After line 9 (`[ -z "$FILE_PATH" ] && exit 0`), add:
  ```bash
  # Load shared config
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/load-config.sh"
  ```

  Then replace every literal `docs/plans` with `$SESSIONS_DIR`:
  - Line 20: `if [ -d "docs/plans" ]` -> `if [ -d "$SESSIONS_DIR" ]`
  - Line 21: `for plan in docs/plans/*/plan.md` -> `for plan in "$SESSIONS_DIR"/*/plan.md`
  - Line 32: `if [ -z "$matched_spec" ] && [ -d "docs/plans" ]` -> `if [ -z "$matched_spec" ] && [ -d "$SESSIONS_DIR" ]`
  - Line 34: `for spec in docs/plans/*/spec.yaml` -> `for spec in "$SESSIONS_DIR"/*/spec.yaml`

- [ ] **Step 3: Refactor keyword-detector.sh**

  In `scripts/keyword-detector.sh`, add the config loader source after the PROMPT_LOWER line, and replace all 6 inline `docs/plans` references with `$SESSIONS_DIR`:

  After line 9 (`PROMPT_LOWER=...`), add:
  ```bash
  # Load shared config
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/load-config.sh"
  ```

  Then replace every literal `docs/plans` with `$SESSIONS_DIR`:
  - Line 19: `if [ -d "docs/plans" ]` -> `if [ -d "$SESSIONS_DIR" ]`
  - Line 20: `for dir in docs/plans/*/` -> `for dir in "$SESSIONS_DIR"/*/`
  - Line 98: `if [ -d "docs/plans" ]` -> `if [ -d "$SESSIONS_DIR" ]`
  - Line 99: `for dir in docs/plans/*/` -> `for dir in "$SESSIONS_DIR"/*/`
  - Line 148: `"No spec found in docs/plans/"` -> `"No spec found."` (remove path from user message)
  - All other inline references

- [ ] **Step 4: Verify all 3 scripts pass syntax check**
  Run: `bash -n scripts/spec-gate.sh && bash -n scripts/drift-monitor.sh && bash -n scripts/keyword-detector.sh`
  Expected: No output (exit code 0)

- [ ] **Step 5: Verify no remaining `docs/plans` references**
  Run: `grep -n 'docs/plans' scripts/spec-gate.sh scripts/drift-monitor.sh scripts/keyword-detector.sh`
  Expected: No matches

- [ ] **Step 6: Commit**
  `git add scripts/spec-gate.sh scripts/drift-monitor.sh scripts/keyword-detector.sh && git commit -m "refactor(scripts): replace inline docs/plans with SESSIONS_DIR in 3 scripts"`

### Task 1.3: Migrate 5 scripts with PLANS_DIR variable to load-config.sh

- **Files**: `scripts/session-start.sh`, `scripts/pipeline-guard.sh`, `scripts/error-tracker.sh`, `scripts/pre-compact.sh`, `scripts/stop-hook.sh`
- **Spec items**: C1
- **Depends on**: Task 1.1

- [ ] **Step 1: Update session-start.sh**

  Replace line 5 (`PLANS_DIR="docs/plans"`) with:
  ```bash
  # Load shared config
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/load-config.sh"
  ```

  Then replace all `$PLANS_DIR` with `$SESSIONS_DIR` throughout the file. Also update line 89's hardcoded worktree fallback path `${wt_dir}docs/plans` to `${wt_dir}.robro/sessions`.

- [ ] **Step 2: Update pipeline-guard.sh**

  Replace line 14 (`PLANS_DIR="docs/plans"`) with:
  ```bash
  # Load shared config
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/load-config.sh"
  ```

  Replace all `$PLANS_DIR` with `$SESSIONS_DIR`.

- [ ] **Step 3: Update error-tracker.sh**

  Replace line 13 (`PLANS_DIR="docs/plans"`) with:
  ```bash
  # Load shared config
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/load-config.sh"
  ```

  Replace all `$PLANS_DIR` with `$SESSIONS_DIR`.

- [ ] **Step 4: Update pre-compact.sh**

  Replace line 5 (`PLANS_DIR="docs/plans"`) with:
  ```bash
  # Load shared config
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/load-config.sh"
  ```

  Replace all `$PLANS_DIR` with `$SESSIONS_DIR`.

- [ ] **Step 5: Update stop-hook.sh**

  Replace line 15 (`PLANS_DIR="docs/plans"`) with:
  ```bash
  # Load shared config
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/load-config.sh"
  ```

  Replace all `$PLANS_DIR` with `$SESSIONS_DIR`.

- [ ] **Step 6: Verify all 5 scripts pass syntax check**
  Run: `bash -n scripts/session-start.sh && bash -n scripts/pipeline-guard.sh && bash -n scripts/error-tracker.sh && bash -n scripts/pre-compact.sh && bash -n scripts/stop-hook.sh`
  Expected: No output (exit code 0)

- [ ] **Step 7: Verify no remaining `docs/plans` references in any script**
  Run: `grep -rn 'docs/plans' scripts/`
  Expected: No matches

- [ ] **Step 8: Commit**
  `git add scripts/session-start.sh scripts/pipeline-guard.sh scripts/error-tracker.sh scripts/pre-compact.sh scripts/stop-hook.sh && git commit -m "refactor(scripts): migrate 5 PLANS_DIR scripts to shared config loader"`

### Task 1.4: Update .gitignore rules

- **Files**: `.gitignore`
- **Spec items**: C1, C4
- **Depends on**: none

- [ ] **Step 1: Replace docs/plans/ rules with .robro/ rules**

  In `.gitignore`, replace the current plan artifact section:

  ```
  # Plan artifacts — temporal working files
  docs/plans/*/research/
  docs/plans/*/discussion/
  docs/plans/*.bak.md
  docs/plans/*.bak.yaml

  # Status.yaml is gitignored (temporal execution state)
  docs/plans/*/status.yaml
  ```

  With:

  ```
  # Robro session artifacts (temporal)
  .robro/sessions/*/research/
  .robro/sessions/*/discussion/
  .robro/sessions/*/status.yaml
  .robro/sessions/*/*.bak.*
  ```

  Keep the existing worktree rule (`# Worktree directories` / `.claude/worktrees/`) unchanged.

- [ ] **Step 2: Verify no docs/plans references remain**
  Run: `grep 'docs/plans' .gitignore`
  Expected: No matches

- [ ] **Step 3: Commit**
  `git add .gitignore && git commit -m "chore(gitignore): update rules from docs/plans/ to .robro/sessions/"`

### Task 1.5: Verify zero docs/plans references in all scripts

- **Files**: none (verification only)
- **Spec items**: C1
- **Depends on**: Tasks 1.2, 1.3

- [ ] **Step 1: Run full grep across all scripts**
  Run: `grep -rn 'docs/plans' scripts/`
  Expected: No matches (exit code 1)

- [ ] **Step 2: Run bash -n on all scripts**
  Run: `for f in scripts/*.sh scripts/lib/*.sh; do bash -n "$f" || echo "FAIL: $f"; done`
  Expected: No FAIL lines

## Phase 2: Path Migration -- Skills & Documentation

> Depends on: Phase 1
> Parallel: tasks 2.1-2.4 can all run concurrently; task 2.5 runs after 2.1-2.4
> Delivers: Zero `docs/plans/` references in any runtime file (skills, scripts, config, docs)
> Spec sections: S1

### Task 2.1: Update idea skill path references

- **Files**: `skills/idea/SKILL.md`
- **Spec items**: C1
- **Depends on**: none

- [ ] **Step 1: Replace all 3 `docs/plans/` occurrences**

  In `skills/idea/SKILL.md`:
  - Line 41 (`docs/plans/YYMMDD_{slug}/status.yaml`): Replace `docs/plans/` with `.robro/sessions/`
  - Line 64 (`docs/plans/YYMMDD_{slug}/`): Replace `docs/plans/` with `.robro/sessions/`
  - Line 116 (`docs/plans/` directory): Replace `docs/plans/` with `.robro/sessions/`

- [ ] **Step 2: Verify no remaining references**
  Run: `grep -n 'docs/plans' skills/idea/SKILL.md`
  Expected: No matches

- [ ] **Step 3: Commit**
  `git add skills/idea/SKILL.md && git commit -m "refactor(idea): update path references to .robro/sessions/"`

### Task 2.2: Update plan skill path references

- **Files**: `skills/plan/SKILL.md`
- **Spec items**: C1
- **Depends on**: none

- [ ] **Step 1: Replace all 6 `docs/plans/` occurrences**

  In `skills/plan/SKILL.md`:
  - Line 11 (`docs/plans/`): Replace with `.robro/sessions/`
  - Line 51 (`docs/plans/YYMMDD_{slug}/status.yaml`): Replace with `.robro/sessions/`
  - Line 91 (same pattern): Replace with `.robro/sessions/`
  - Line 109 (same pattern): Replace with `.robro/sessions/`
  - Line 115 (same pattern): Replace with `.robro/sessions/`
  - Line 457 (`docs/plans/{directory}`): Replace with `.robro/sessions/{directory}`

- [ ] **Step 2: Verify no remaining references**
  Run: `grep -n 'docs/plans' skills/plan/SKILL.md`
  Expected: No matches

- [ ] **Step 3: Commit**
  `git add skills/plan/SKILL.md && git commit -m "refactor(plan): update path references to .robro/sessions/"`

### Task 2.3: Update do and tune skill path references

- **Files**: `skills/do/SKILL.md`, `skills/tune/SKILL.md`
- **Spec items**: C1
- **Depends on**: none

- [ ] **Step 1: Update do skill**

  In `skills/do/SKILL.md`, line 11: Replace `docs/plans/` with `.robro/sessions/`.

- [ ] **Step 2: Update tune skill**

  In `skills/tune/SKILL.md`:
  - Line 31 (`docs/plans/*/status.yaml`): Replace `docs/plans/` with `.robro/sessions/`
  - Line 105 (`docs/plans/*/discussion/retro-sprint-*.md`): Replace `docs/plans/` with `.robro/sessions/`

- [ ] **Step 3: Verify no remaining references**
  Run: `grep -n 'docs/plans' skills/do/SKILL.md skills/tune/SKILL.md`
  Expected: No matches

- [ ] **Step 4: Commit**
  `git add skills/do/SKILL.md skills/tune/SKILL.md && git commit -m "refactor(do,tune): update path references to .robro/sessions/"`

### Task 2.4: Update documentation path references

- **Files**: `CLAUDE.md`, `README.md`, `skills/setup/claude-md-template.md`
- **Spec items**: C1
- **Depends on**: none

- [ ] **Step 1: Update CLAUDE.md**

  Replace all 4 `docs/plans/` references with `.robro/sessions/`:
  - Line 17 (status.yaml path): `docs/plans/*/status.yaml` -> `.robro/sessions/*/status.yaml`
  - Line 107 (directory structure): `docs/plans/` -> `.robro/sessions/`
  - Line 128 (plan artifacts section): `docs/plans/YYMMDD_{name}/` -> `.robro/sessions/YYMMDD_{name}/`
  - Line 143 (worktree workflow): `docs/plans/{slug}/` -> `.robro/sessions/{slug}/`

- [ ] **Step 2: Update README.md**

  Replace all 2 `docs/plans/` references with `.robro/sessions/`:
  - Line 151 (plan artifacts section): `docs/plans/YYMMDD_{name}/` -> `.robro/sessions/YYMMDD_{name}/`
  - Line 184 (requirements section): `docs/plans/` -> `.robro/sessions/`

- [ ] **Step 3: Update claude-md-template.md**

  Replace the 1 `docs/plans/` reference with `.robro/sessions/`:
  - Line 23 (`Plans live in docs/plans/YYMMDD_{name}/`): Replace with `Plans live in .robro/sessions/YYMMDD_{name}/`

- [ ] **Step 4: Verify no remaining references in runtime files**
  Run: `grep -rn 'docs/plans' CLAUDE.md README.md skills/setup/claude-md-template.md`
  Expected: No matches

- [ ] **Step 5: Commit**
  `git add CLAUDE.md README.md skills/setup/claude-md-template.md && git commit -m "docs: update all path references from docs/plans/ to .robro/sessions/"`

### Task 2.5: Full codebase verification of zero docs/plans references

- **Files**: none (verification only)
- **Spec items**: C1
- **Depends on**: Tasks 2.1, 2.2, 2.3, 2.4

- [ ] **Step 1: Run full grep across all runtime files**
  Run: `grep -rn 'docs/plans' scripts/ skills/ CLAUDE.md README.md .claude/CLAUDE.md .gitignore --include='*.sh' --include='*.md' --include='*.yaml' --include='*.json' | grep -v 'idea.md' | grep -v 'plan.md'`
  Expected: No matches (only hits should be inside the plan's own idea.md/plan.md which are artifacts, not runtime code)

  Note: `.claude/CLAUDE.md` still has `docs/plans/` in the managed block -- this will be updated by manage-claudemd.sh in Phase 3 when the template is re-applied. This is expected.

## Phase 3: Config System

> Depends on: Phase 1 (load-config.sh must exist)
> Parallel: tasks 3.1 and 3.2 can run concurrently; task 3.3 depends on 3.1
> Delivers: JSON Schema at plugin root, model-config.yaml with all 11 agents, config loading in brief phase
> Spec sections: S2, S6

### Task 3.1: Create JSON Schema for config.json

- **Files**: `config.schema.json`
- **Spec items**: C7
- **Depends on**: none

- [ ] **Step 1: Write the JSON Schema file**

  Create `config.schema.json` at the plugin root:

  ```json
  {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://github.com/JWWon/robro/config.schema.json",
    "title": "Robro Project Configuration",
    "description": "Project-level configuration for the robro Claude Code plugin. All fields are optional -- omitted fields use built-in defaults from model-config.yaml.",
    "type": "object",
    "additionalProperties": false,
    "$defs": {
      "model": {
        "type": "string",
        "enum": ["haiku", "sonnet", "opus"],
        "description": "Claude model tier for agent dispatch"
      },
      "model_capped": {
        "type": "string",
        "enum": ["haiku", "sonnet"],
        "description": "Claude model tier capped at sonnet (for researcher, retro-analyst, conflict-resolver)"
      }
    },
    "properties": {
      "$schema": {
        "type": "string",
        "description": "Path to this schema file for editor validation"
      },
      "model_tiers": {
        "type": "object",
        "description": "Override model assignments per complexity tier. Unspecified agents use model-config.yaml defaults.",
        "additionalProperties": false,
        "properties": {
          "light": { "$ref": "#/$defs/tier_config" },
          "standard": { "$ref": "#/$defs/tier_config" },
          "complex": { "$ref": "#/$defs/tier_config" }
        }
      },
      "thresholds": {
        "type": "object",
        "description": "Override skill thresholds",
        "additionalProperties": false,
        "properties": {
          "ambiguity_threshold": {
            "type": "number",
            "minimum": 0,
            "maximum": 1,
            "default": 0.1,
            "description": "Ambiguity score threshold for idea completion gate (default: 0.1)"
          },
          "sprint_hard_cap": {
            "type": "integer",
            "minimum": 1,
            "maximum": 100,
            "default": 30,
            "description": "Maximum number of sprints before forcing convergence (default: 30)"
          },
          "plan_max_iterations": {
            "type": "integer",
            "minimum": 0,
            "default": 0,
            "description": "Maximum plan review iterations (0 = no cap, quality-driven exit). Default: 0"
          }
        }
      },
      "agent_overrides": {
        "type": "object",
        "description": "Per-agent model override. Highest precedence -- overrides tier config and model-config.yaml defaults.",
        "additionalProperties": false,
        "properties": {
          "builder": { "$ref": "#/$defs/model" },
          "reviewer": { "$ref": "#/$defs/model" },
          "architect": { "$ref": "#/$defs/model" },
          "critic": { "$ref": "#/$defs/model" },
          "researcher": { "$ref": "#/$defs/model_capped" },
          "retro-analyst": { "$ref": "#/$defs/model_capped" },
          "conflict-resolver": { "$ref": "#/$defs/model_capped" },
          "planner": { "$ref": "#/$defs/model" },
          "contrarian": { "$ref": "#/$defs/model" },
          "simplifier": { "$ref": "#/$defs/model" },
          "ontologist": { "$ref": "#/$defs/model" }
        }
      }
    },
    "$defs_extra": {
      "tier_config": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "default": { "$ref": "#/$defs/model" },
          "builder": { "$ref": "#/$defs/model" },
          "reviewer": { "$ref": "#/$defs/model" },
          "architect": { "$ref": "#/$defs/model" },
          "critic": { "$ref": "#/$defs/model" },
          "researcher": { "$ref": "#/$defs/model_capped" },
          "retro-analyst": { "$ref": "#/$defs/model_capped" },
          "conflict-resolver": { "$ref": "#/$defs/model_capped" },
          "planner": { "$ref": "#/$defs/model" },
          "contrarian": { "$ref": "#/$defs/model" },
          "simplifier": { "$ref": "#/$defs/model" },
          "ontologist": { "$ref": "#/$defs/model" }
        }
      }
    }
  }
  ```

  **Note**: The `$defs_extra` block must be merged into `$defs` so that `tier_config` is referenceable. The final schema should have `tier_config` inside `$defs` alongside `model` and `model_capped`. The above is split for readability -- the actual file must nest `tier_config` inside `$defs`.

- [ ] **Step 2: Validate the schema is valid JSON**
  Run: `jq . config.schema.json > /dev/null`
  Expected: Exit code 0

- [ ] **Step 3: Commit**
  `git add config.schema.json && git commit -m "feat(config): create JSON Schema for .robro/config.json"`

### Task 3.2: Add missing agents to model-config.yaml

- **Files**: `model-config.yaml`
- **Spec items**: C6
- **Depends on**: none

- [ ] **Step 1: Add 4 missing agent entries**

  In `model-config.yaml`, add entries for planner, contrarian, simplifier, and ontologist to each tier. These agents follow the same pattern as the existing ones (not capped at sonnet since they make architectural decisions):

  Under `light:` section, after `conflict-resolver: haiku`, add:
  ```yaml
      planner: haiku
      contrarian: haiku
      simplifier: haiku
      ontologist: haiku
  ```

  Under `standard:` section, after `conflict-resolver: sonnet`, add:
  ```yaml
      planner: sonnet
      contrarian: sonnet
      simplifier: sonnet
      ontologist: sonnet
  ```

  Under `complex:` section, after `conflict-resolver: sonnet`, add:
  ```yaml
      planner: opus
      contrarian: opus
      simplifier: opus
      ontologist: opus
  ```

- [ ] **Step 2: Verify the file is valid YAML**
  Run: `python3 -c "import yaml; yaml.safe_load(open('model-config.yaml'))"`
  Expected: Exit code 0

- [ ] **Step 3: Verify all 11 agents have entries in each tier**
  Run: `python3 -c "import yaml; d=yaml.safe_load(open('model-config.yaml')); [print(f'{t}: {len(d[\"tiers\"][t])} agents') for t in d['tiers']]"`
  Expected: Each tier shows 12 entries (11 agents + 1 default)

- [ ] **Step 4: Commit**
  `git add model-config.yaml && git commit -m "feat(config): add 4 missing agents to model-config.yaml (planner, contrarian, simplifier, ontologist)"`

### Task 3.3: Update brief-phase.md for config.json override loading

- **Files**: `skills/do/brief-phase.md`
- **Spec items**: C2, C6
- **Depends on**: Task 3.1

- [ ] **Step 1: Add config.json override instructions**

  In `skills/do/brief-phase.md`, after section "### 1.1. Load Model Configuration" step 3 ("Select the tier matching the complexity value"), add a new step between current steps 3 and 4:

  ```markdown
  3b. **Check for project config overrides**: Read `.robro/config.json` if it exists.
     - If `model_tiers.{complexity}` has agent-specific overrides, apply them on top of YAML defaults
     - If `agent_overrides` has entries, apply them with highest precedence (overrides both tier config and YAML)
     - Precedence order: agent_overrides > config.json tier > model-config.yaml tier
     - Example: If model-config.yaml says `builder: sonnet` for standard tier, but config.json has `agent_overrides.builder: "opus"`, use opus.
  ```

- [ ] **Step 2: Verify the file is well-formed markdown**
  Run: `head -5 skills/do/brief-phase.md`
  Expected: Shows the markdown header

- [ ] **Step 3: Commit**
  `git add skills/do/brief-phase.md && git commit -m "feat(do): add config.json override loading to brief phase"`

### Task 3.4: Update stop-hook.sh to read sprint_hard_cap from config

- **Files**: `scripts/stop-hook.sh`
- **Spec items**: C2
- **Depends on**: Task 1.3 (stop-hook.sh already sources load-config.sh)

- [ ] **Step 1: Replace hardcoded sprint cap with config value**

  In `scripts/stop-hook.sh`, after the line that sources load-config.sh, add:
  ```bash
  SPRINT_HARD_CAP=$(robro_config '.thresholds.sprint_hard_cap' '30')
  ```

  Then replace the hardcoded `30` in the sprint cap check (line 75):
  - Old: `if [ -n "$sprint" ] && [ "$sprint" -ge 30 ] 2>/dev/null; then`
  - New: `if [ -n "$sprint" ] && [ "$sprint" -ge "$SPRINT_HARD_CAP" ] 2>/dev/null; then`

- [ ] **Step 2: Verify syntax**
  Run: `bash -n scripts/stop-hook.sh`
  Expected: No output (exit code 0)

- [ ] **Step 3: Commit**
  `git add scripts/stop-hook.sh && git commit -m "feat(stop-hook): read sprint_hard_cap from config.json with fallback to 30"`

## Phase 4: Setup Overhaul -- manage-claudemd.sh & Setup Skill

> Depends on: Phase 2 (path references updated in setup skill), Phase 3 (config.schema.json exists)
> Parallel: tasks 4.1 and 4.2 can run concurrently; task 4.3 depends on 4.1
> Delivers: manage-claudemd.sh with new marker format, setup skill invokes the script, .gitignore rules for .robro/ patterns
> Spec sections: S3, S4

### Task 4.1: Create manage-claudemd.sh

- **Files**: `scripts/manage-claudemd.sh`
- **Spec items**: C3
- **Depends on**: none

- [ ] **Step 1: Write the manage-claudemd.sh script**

  Create `scripts/manage-claudemd.sh`:

  ```bash
  #!/usr/bin/env bash
  # Manage the robro-owned section in .claude/CLAUDE.md
  # Usage: manage-claudemd.sh <project_root>
  #
  # Reads version from plugin.json, template from claude-md-template.md.
  # Handles 6 cases: file missing, no markers, start only, both (same version),
  # both (different version), duplicates.
  # Backward compat: detects both old format and new format.
  # Code-block-aware: skips markers inside triple-backtick fenced blocks.
  #
  # New markers:
  #   <!-- robro@{version}:managed:start -->
  #   <!-- robro:managed:end -->

  set -euo pipefail

  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
  PROJECT_ROOT="${1:-.}"

  # Read version from plugin.json
  VERSION=$(jq -r '.version' "${PLUGIN_ROOT}/.claude-plugin/plugin.json")
  if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
    echo "Error: Could not read version from plugin.json" >&2
    exit 1
  fi

  # Read template
  TEMPLATE_FILE="${PLUGIN_ROOT}/skills/setup/claude-md-template.md"
  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found: $TEMPLATE_FILE" >&2
    exit 1
  fi
  TEMPLATE=$(cat "$TEMPLATE_FILE")

  TARGET_DIR="${PROJECT_ROOT}/.claude"
  TARGET_FILE="${TARGET_DIR}/CLAUDE.md"

  START_MARKER="<!-- robro@${VERSION}:managed:start -->"
  END_MARKER="<!-- robro:managed:end -->"

  MANAGED_BLOCK="${START_MARKER}
  ${TEMPLATE}
  ${END_MARKER}"

  # Case 1: File does not exist
  if [ ! -f "$TARGET_FILE" ]; then
    mkdir -p "$TARGET_DIR"
    echo "$MANAGED_BLOCK" > "$TARGET_FILE"
    echo "Created new .claude/CLAUDE.md with robro section (v${VERSION})"
    exit 0
  fi

  # File exists -- read it
  CONTENT=$(cat "$TARGET_FILE")

  # Build a version of content with code blocks masked for marker detection.
  # We replace lines inside fenced code blocks with placeholder lines so
  # markers inside code blocks are not detected.
  MASKED_CONTENT=$(awk '
    /^```/ { in_fence = !in_fence }
    in_fence { print "###FENCED###"; next }
    { print }
  ' "$TARGET_FILE")

  # Detect start marker (both old and new format) outside code blocks
  # Old format: <!-- robro:managed:start [VERSION] -->
  # New format: <!-- robro@VERSION:managed:start -->
  START_LINE=$(echo "$MASKED_CONTENT" | grep -n 'robro[@:]managed:start\|robro:managed:start' | head -1 | cut -d: -f1)

  # Case 2: No start marker found
  if [ -z "$START_LINE" ]; then
    # Append to end of file
    if [ -n "$CONTENT" ] && [ "$(echo "$CONTENT" | tail -c 1)" != "" ]; then
      # File doesn't end with newline
      printf '\n\n%s\n' "$MANAGED_BLOCK" >> "$TARGET_FILE"
    else
      printf '\n%s\n' "$MANAGED_BLOCK" >> "$TARGET_FILE"
    fi
    echo "Added robro section to existing .claude/CLAUDE.md (v${VERSION})"
    exit 0
  fi

  # Start marker found -- detect end marker
  END_LINE=$(echo "$MASKED_CONTENT" | tail -n +"$START_LINE" | grep -n 'robro:managed:end' | head -1 | cut -d: -f1)

  # Extract version from existing start marker
  EXISTING_START=$(sed -n "${START_LINE}p" "$TARGET_FILE")
  EXISTING_VERSION=""

  # Try new format: <!-- robro@VERSION:managed:start -->
  if echo "$EXISTING_START" | grep -q 'robro@[^:]*:managed:start'; then
    EXISTING_VERSION=$(echo "$EXISTING_START" | sed 's/.*robro@\([^:]*\):managed:start.*/\1/')
  # Try old format: <!-- robro:managed:start [VERSION] -->
  elif echo "$EXISTING_START" | grep -q 'robro:managed:start \['; then
    EXISTING_VERSION=$(echo "$EXISTING_START" | sed 's/.*\[\([^]]*\)\].*/\1/')
  fi

  [ -z "$EXISTING_VERSION" ] && EXISTING_VERSION="0.0.0"

  # Case 3: Start marker found, no end marker
  if [ -z "$END_LINE" ]; then
    # Replace from start marker to end of file
    BEFORE=$(head -n $((START_LINE - 1)) "$TARGET_FILE")
    if [ -n "$BEFORE" ]; then
      printf '%s\n%s\n' "$BEFORE" "$MANAGED_BLOCK" > "$TARGET_FILE"
    else
      echo "$MANAGED_BLOCK" > "$TARGET_FILE"
    fi
    echo "Repaired robro section (missing end marker) in .claude/CLAUDE.md (v${EXISTING_VERSION} -> v${VERSION})"
    exit 0
  fi

  # Both markers found
  ACTUAL_END_LINE=$((START_LINE + END_LINE - 1))

  # Check for duplicates
  MARKER_COUNT=$(echo "$MASKED_CONTENT" | grep -c 'robro[@:]managed:start\|robro:managed:start' || true)
  if [ "$MARKER_COUNT" -gt 1 ]; then
    echo "Warning: Found duplicate robro:managed marker pairs in .claude/CLAUDE.md. Using the first pair. Please manually remove the extra markers." >&2
  fi

  # Case 4: Both markers found, same version
  if [ "$EXISTING_VERSION" = "$VERSION" ]; then
    echo "Robro section already current (v${VERSION}) -- no changes"
    exit 0
  fi

  # Case 5: Both markers found, different version -- replace block
  BEFORE=$(head -n $((START_LINE - 1)) "$TARGET_FILE")
  TOTAL_LINES=$(wc -l < "$TARGET_FILE")
  AFTER=""
  if [ "$ACTUAL_END_LINE" -lt "$TOTAL_LINES" ]; then
    AFTER=$(tail -n $((TOTAL_LINES - ACTUAL_END_LINE)) "$TARGET_FILE")
  fi

  {
    [ -n "$BEFORE" ] && printf '%s\n' "$BEFORE"
    printf '%s\n' "$MANAGED_BLOCK"
    [ -n "$AFTER" ] && printf '%s\n' "$AFTER"
  } > "$TARGET_FILE"

  echo "Updated robro section (v${EXISTING_VERSION} -> v${VERSION}) in .claude/CLAUDE.md"
  ```

- [ ] **Step 2: Make executable**
  Run: `chmod +x scripts/manage-claudemd.sh`

- [ ] **Step 3: Verify syntax**
  Run: `bash -n scripts/manage-claudemd.sh`
  Expected: No output (exit code 0)

- [ ] **Step 4: Commit**
  `git add scripts/manage-claudemd.sh && git commit -m "feat(scripts): create manage-claudemd.sh for managed block management"`

### Task 4.2: Update setup skill .gitignore rules

- **Files**: `skills/setup/SKILL.md`
- **Spec items**: C4
- **Depends on**: none

- [ ] **Step 1: Replace .gitignore rules section**

  In `skills/setup/SKILL.md`, replace the entire Step 3 .gitignore section. The 5 rules change from `docs/plans/` patterns to `.robro/` patterns plus `.claude/worktrees/`:

  Replace the `ROBRO_RULES` definition (around lines 288-303) with:

  ```markdown
  The following 5 rules must be present in the project's `.gitignore`:

  ```
  # Robro session artifacts (temporal)
  .robro/sessions/*/research/
  .robro/sessions/*/discussion/
  .robro/sessions/*/status.yaml
  .robro/sessions/*/*.bak.*
  .claude/worktrees/
  ```

  Store these 5 rule lines (not including the comment header) as `ROBRO_RULES`:

  1. `.robro/sessions/*/research/`
  2. `.robro/sessions/*/discussion/`
  3. `.robro/sessions/*/status.yaml`
  4. `.robro/sessions/*/*.bak.*`
  5. `.claude/worktrees/`
  ```

  Also update the "create case" block (around line 316) and the report message to match.

- [ ] **Step 2: Verify the SKILL.md still has valid structure**
  Run: `head -5 skills/setup/SKILL.md`
  Expected: Shows the frontmatter

- [ ] **Step 3: Commit**
  `git add skills/setup/SKILL.md && git commit -m "feat(setup): update .gitignore rules to .robro/sessions/ patterns"`

### Task 4.3: Update setup skill to invoke manage-claudemd.sh and offer config.json

- **Files**: `skills/setup/SKILL.md`
- **Spec items**: C3, C4, C2
- **Depends on**: Task 4.1 (manage-claudemd.sh must exist), Task 4.2

- [ ] **Step 1: Replace Step 1 (CLAUDE.md management) with script invocation**

  In `skills/setup/SKILL.md`, replace the entire Step 1 section (from "### Step 1: CLAUDE.md Section Management" through "Skip to Step 2" at the end of section 1h) with:

  ```markdown
  ### Step 1: CLAUDE.md Section Management

  Invoke the managed block script to create or update the robro section in `.claude/CLAUDE.md`:

  ```bash
  PROJECT_ROOT=$(git rev-parse --show-toplevel)
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/manage-claudemd.sh" "$PROJECT_ROOT"
  ```

  The script handles all cases: file missing, no markers, version comparison, backward compatibility with old marker format, and code-block-aware marker detection. Report whatever the script outputs.
  ```

- [ ] **Step 2: Add config.json creation step after Step 3.5**

  After the existing Step 3.5 (Settings.json Configuration), add a new Step 3.7:

  ```markdown
  ### Step 3.7: Config File Setup

  Offer to create `.robro/config.json` if it does not exist.

  #### 3.7a. Check for Existing Config

  Check if `.robro/config.json` exists at the project root:
  ```bash
  PROJECT_ROOT=$(git rev-parse --show-toplevel)
  ls "${PROJECT_ROOT}/.robro/config.json" 2>/dev/null
  ```

  If the file exists, report: **".robro/config.json already exists -- no changes"** and skip to Step 4.

  #### 3.7b. Offer Config Creation

  If the file does not exist, ask the user via AskUserQuestion:

  ```
  Would you like to create .robro/config.json for project-level customization?

  This file lets you override:
  - Model tiers (which Claude model each agent uses per complexity level)
  - Thresholds (ambiguity threshold, sprint hard cap)
  - Per-agent model overrides (highest precedence)

  All fields are optional -- omitted fields use built-in defaults.
  ```

  Options: "Create with defaults", "Skip for now"

  #### 3.7c. Create Config File

  If the user chooses "Create with defaults", create `.robro/config.json`:

  ```json
  {
    "$schema": "https://raw.githubusercontent.com/JWWon/robro/main/config.schema.json"
  }
  ```

  The empty config (with only `$schema`) means all defaults from model-config.yaml are used. Users can add overrides as needed.

  Report: **".robro/config.json: created with schema reference"**
  ```

- [ ] **Step 3: Update Step 4 completion summary**

  In the Step 4 completion summary, add a line for config.json:
  ```markdown
  - Config.json: created/unchanged
  ```

- [ ] **Step 4: Commit**
  `git add skills/setup/SKILL.md && git commit -m "feat(setup): invoke manage-claudemd.sh, offer config.json creation"`

### Task 4.4: Update setup skill marker format references

- **Files**: `skills/setup/SKILL.md`
- **Spec items**: C3
- **Depends on**: Task 4.3

- [ ] **Step 1: Verify old marker references are removed**

  Since Task 4.3 replaced Step 1 entirely, verify no old-format markers remain in the skill:
  Run: `grep -n 'robro:managed:start \[' skills/setup/SKILL.md`
  Expected: No matches (all old-format marker references should be gone since Step 1 now delegates to the script)

- [ ] **Step 2: Update the marker format description at the top of Step 1**

  If any preamble text in the setup skill still mentions the old marker format, update it. The new marker format is:
  - Start: `<!-- robro@{version}:managed:start -->`
  - End: `<!-- robro:managed:end -->`

- [ ] **Step 3: Commit**
  `git add skills/setup/SKILL.md && git commit -m "chore(setup): verify marker format updated to robro@version style"`

## Phase 5: Version Sync

> Depends on: Phase 2 (CLAUDE.md path references updated)
> Parallel: tasks 5.1 and 5.2 can run concurrently; task 5.3 depends on both
> Delivers: Automated version sync from plugin.json to marketplace.json via git hook
> Spec sections: S5

### Task 5.1: Create sync-versions.sh

- **Files**: `scripts/sync-versions.sh`
- **Spec items**: C5
- **Depends on**: none

- [ ] **Step 1: Write the sync-versions.sh script**

  Create `scripts/sync-versions.sh`:

  ```bash
  #!/usr/bin/env bash
  # Sync version from plugin.json to marketplace.json
  # Called by .githooks/pre-push or manually.
  #
  # Reads version from .claude-plugin/plugin.json
  # Updates .claude-plugin/marketplace.json plugins[0].version to match
  # If versions already match, exits silently.

  set -euo pipefail

  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

  PLUGIN_JSON="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
  MARKETPLACE_JSON="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"

  if [ ! -f "$PLUGIN_JSON" ]; then
    echo "Error: plugin.json not found at $PLUGIN_JSON" >&2
    exit 1
  fi

  if [ ! -f "$MARKETPLACE_JSON" ]; then
    echo "Error: marketplace.json not found at $MARKETPLACE_JSON" >&2
    exit 1
  fi

  PLUGIN_VERSION=$(jq -r '.version' "$PLUGIN_JSON")
  MARKETPLACE_VERSION=$(jq -r '.plugins[0].version' "$MARKETPLACE_JSON")

  if [ "$PLUGIN_VERSION" = "$MARKETPLACE_VERSION" ]; then
    exit 0
  fi

  # Update marketplace.json
  jq --arg ver "$PLUGIN_VERSION" '.plugins[0].version = $ver' "$MARKETPLACE_JSON" > "${MARKETPLACE_JSON}.tmp"
  mv "${MARKETPLACE_JSON}.tmp" "$MARKETPLACE_JSON"

  echo "Synced marketplace.json version: ${MARKETPLACE_VERSION} -> ${PLUGIN_VERSION}"

  # Stage the change so it's included in the push
  git add "$MARKETPLACE_JSON" 2>/dev/null || true
  ```

- [ ] **Step 2: Make executable**
  Run: `chmod +x scripts/sync-versions.sh`

- [ ] **Step 3: Verify syntax**
  Run: `bash -n scripts/sync-versions.sh`
  Expected: No output (exit code 0)

- [ ] **Step 4: Test the script directly**
  Run: `CLAUDE_PLUGIN_ROOT=. bash scripts/sync-versions.sh`
  Expected: Outputs "Synced marketplace.json version: 0.1.0 -> 0.1.2" (since current versions differ)

- [ ] **Step 5: Verify marketplace.json was updated**
  Run: `jq '.plugins[0].version' .claude-plugin/marketplace.json`
  Expected: `"0.1.2"`

- [ ] **Step 6: Commit**
  `git add scripts/sync-versions.sh .claude-plugin/marketplace.json && git commit -m "feat(scripts): create sync-versions.sh and sync marketplace.json to 0.1.2"`

### Task 5.2: Create .githooks/pre-push

- **Files**: `.githooks/pre-push`
- **Spec items**: C5
- **Depends on**: none

- [ ] **Step 1: Create .githooks directory and pre-push hook**

  Run: `mkdir -p .githooks`

  Create `.githooks/pre-push`:

  ```bash
  #!/usr/bin/env bash
  # Pre-push hook: sync versions before pushing
  # Install: git config core.hooksPath .githooks

  HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
  REPO_ROOT="$(cd "$HOOK_DIR/.." && pwd)"

  # Run version sync
  CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "${REPO_ROOT}/scripts/sync-versions.sh"
  ```

- [ ] **Step 2: Make executable**
  Run: `chmod +x .githooks/pre-push`

- [ ] **Step 3: Verify syntax**
  Run: `bash -n .githooks/pre-push`
  Expected: No output (exit code 0)

- [ ] **Step 4: Commit**
  `git add .githooks/pre-push && git commit -m "feat(hooks): add pre-push git hook for version sync"`

### Task 5.3: Add version management rules to CLAUDE.md

- **Files**: `CLAUDE.md`
- **Spec items**: C5
- **Depends on**: Tasks 5.1, 5.2

- [ ] **Step 1: Add version management section**

  In `CLAUDE.md`, within the `## Development` section, after the existing `### Versioning` subsection (line 213), append:

  ```markdown

  #### Version Sync

  plugin.json is the single source of truth for the version number. marketplace.json is synced automatically:

  - `scripts/sync-versions.sh` copies the version from plugin.json to marketplace.json
  - `.githooks/pre-push` triggers the sync before every push
  - Setup: `git config core.hooksPath .githooks` (run once per clone)

  When bumping the version:
  1. Update `version` in `.claude-plugin/plugin.json` only
  2. The pre-push hook syncs marketplace.json automatically
  3. After squash merge to main: `git tag v{version} && git push origin v{version}`
  ```

- [ ] **Step 2: Configure git hooks path for development**
  Run: `git config core.hooksPath .githooks`

- [ ] **Step 3: Commit**
  `git add CLAUDE.md && git commit -m "docs: add version management rules and configure git hooks path"`

## Phase 6: Agent Audit -- Model Config & Skill Instructions

> Depends on: Phase 3 (model-config.yaml updated with all 11 agents)
> Parallel: tasks 6.1 and 6.2 can run concurrently; task 6.3 depends on both
> Delivers: Idea and plan skills explicitly name which agents to dispatch at each step with model parameter format
> Spec sections: S6

### Task 6.1: Strengthen idea skill agent dispatch instructions

- **Files**: `skills/idea/SKILL.md`
- **Spec items**: C6
- **Depends on**: none

- [ ] **Step 1: Add Agent() dispatch format to Step 2 (Researcher dispatch)**

  In `skills/idea/SKILL.md`, after the Step 2 heading "### Step 2: Codebase & Context Scan", within point 1 ("Dispatch the Researcher agent"), add explicit dispatch format:

  ```markdown
  Dispatch the Researcher agent with explicit model parameter:
  ```
  Agent(
    subagent_type: "robro:researcher",
    prompt: "Perform brownfield detection: scan for config files, frameworks, conventions, related code for '{topic}'...",
    model: "sonnet"
  )
  ```
  The idea skill always uses `standard` tier for agent dispatch. Researcher maps to `sonnet` in the standard tier.
  ```

- [ ] **Step 2: Add escalation dispatch format to Step 5 (Challenge modes)**

  In `skills/idea/SKILL.md`, within Step 5's "Escalation to subagent" paragraph, add explicit dispatch format:

  ```markdown
  When escalating to a subagent, use the standard tier model:
  ```
  Agent(
    subagent_type: "robro:contrarian",  // or simplifier, ontologist
    prompt: "Review the current interview state and challenge assumptions. Interview summary: {summary}. Ambiguity scores: {scores}. Requirements: {requirements}. Research context: {context}.",
    model: "sonnet"
  )
  ```
  Challenge agents (contrarian, simplifier, ontologist) map to `sonnet` in the standard tier.
  ```

- [ ] **Step 3: Add dispatch format to Step 7 (Web research)**

  In `skills/idea/SKILL.md`, within Step 7 "Web Research", add:

  ```markdown
  ```
  Agent(
    subagent_type: "robro:researcher",
    prompt: "Research {topic}: current best practices, API documentation, known pitfalls...",
    model: "sonnet"
  )
  ```
  ```

- [ ] **Step 4: Commit**
  `git add skills/idea/SKILL.md && git commit -m "feat(idea): add explicit Agent() dispatch format with model parameters"`

### Task 6.2: Strengthen plan skill agent dispatch instructions

- **Files**: `skills/plan/SKILL.md`
- **Spec items**: C6
- **Depends on**: none

- [ ] **Step 1: Add tier declaration at skill level**

  In `skills/plan/SKILL.md`, before the "## Workflow" section, add:

  ```markdown
  ## Model Configuration

  The plan skill always uses the `standard` complexity tier for all agent dispatches. This balances thoroughness with cost. The model mappings for standard tier are defined in `model-config.yaml` at the plugin root.

  If `.robro/config.json` exists in the project, check for `agent_overrides` that override the standard tier defaults. Precedence: agent_overrides > standard tier config > model-config.yaml defaults.
  ```

- [ ] **Step 2: Add Agent() dispatch format to Step 2 (Technical Deep Dive)**

  In `skills/plan/SKILL.md`, within Step 2, add explicit dispatch format for each agent:

  ```markdown
  Dispatch agents in parallel with explicit model parameters:

  ```
  Agent(
    subagent_type: "robro:researcher",
    prompt: "Deep-dive into technical approaches for: {requirements}. Verify library compatibility. Research best practices. Write findings to research/.",
    model: "sonnet"
  )

  Agent(
    subagent_type: "robro:architect",
    prompt: "Review idea.md against the codebase for technical feasibility. Evaluate the Proposed Approach. Flag edge cases, security concerns, performance bottlenecks. Provide steelman antithesis for each recommendation.",
    model: "opus"
  )

  Agent(
    subagent_type: "robro:critic",
    prompt: "Score ambiguity of the technical approach. Find gaps in error handling, boundaries, conflicting requirements. Provide multi-perspective analysis (Executor, Stakeholder, Skeptic).",
    model: "opus"
  )
  ```

  Standard tier mappings: researcher=sonnet, architect=opus, critic=opus.
  ```

- [ ] **Step 3: Add dispatch format to Step 4 (Planner dispatch)**

  In `skills/plan/SKILL.md`, within Step 4, add:

  ```markdown
  ```
  Agent(
    subagent_type: "robro:planner",
    prompt: "Create the implementation plan from idea.md, research findings, Architect's Tradeoff Analysis (for ADR), and Critic's findings (for Pre-mortem). Follow the exact plan.md format specified. Assume the implementer has zero codebase context.",
    model: "sonnet"
  )
  ```

  Standard tier: planner=sonnet.
  ```

- [ ] **Step 4: Add dispatch format to Step 5 (Plan review)**

  In `skills/plan/SKILL.md`, within Step 5, clarify:

  ```markdown
  Dispatch a general-purpose agent as the plan reviewer (see `plan-reviewer-prompt.md` for the prompt template):

  ```
  Agent(
    prompt: "{plan reviewer prompt from template}",
    model: "sonnet"
  )
  ```
  ```

- [ ] **Step 5: Add dispatch format to Step 7 (Spec review)**

  Similarly for Step 7:

  ```markdown
  ```
  Agent(
    prompt: "{spec reviewer prompt from template}",
    model: "sonnet"
  )
  ```
  ```

- [ ] **Step 6: Add dispatch format to Step 9 (Final review)**

  In Step 9:

  ```markdown
  ```
  Agent(
    subagent_type: "robro:architect",
    prompt: "Final review of plan.md + spec.yaml pair for technical soundness...",
    model: "opus"
  )

  Agent(
    subagent_type: "robro:critic",
    prompt: "Final review of plan.md + spec.yaml pair for completeness and consistency...",
    model: "opus"
  )
  ```
  ```

- [ ] **Step 7: Commit**
  `git add skills/plan/SKILL.md && git commit -m "feat(plan): add explicit Agent() dispatch format with model parameters for all steps"`

### Task 6.3: Final agent audit verification

- **Files**: none (verification only)
- **Spec items**: C6
- **Depends on**: Tasks 6.1, 6.2, 3.2

- [ ] **Step 1: Verify all 11 agents in model-config.yaml**
  Run: `python3 -c "import yaml; d=yaml.safe_load(open('model-config.yaml')); agents=set(); [agents.update(d['tiers'][t].keys()) for t in d['tiers']]; agents.discard('default'); print(f'{len(agents)} agents:', sorted(agents))"`
  Expected: `11 agents: ['architect', 'builder', 'conflict-resolver', 'contrarian', 'critic', 'ontologist', 'planner', 'researcher', 'retro-analyst', 'reviewer', 'simplifier']`

- [ ] **Step 2: Verify plan-reviewer-prompt.md and spec-reviewer-prompt.md exist**
  Run: `ls skills/plan/plan-reviewer-prompt.md skills/plan/spec-reviewer-prompt.md`
  Expected: Both files listed

- [ ] **Step 3: Verify idea skill has Agent() dispatch examples**
  Run: `grep -c 'subagent_type\|Agent(' skills/idea/SKILL.md`
  Expected: At least 3 matches (Steps 2, 5, 7)

- [ ] **Step 4: Verify plan skill has Agent() dispatch examples**
  Run: `grep -c 'subagent_type\|Agent(' skills/plan/SKILL.md`
  Expected: At least 5 matches (Steps 2, 4, 5, 7, 9)

## Phase 7: Integration & Final Validation

> Depends on: Phases 1-6
> Parallel: tasks 7.1 and 7.2 can run concurrently; task 7.3 depends on both
> Delivers: All spec.yaml checklist items verified, complete integration
> Spec sections: S1-S6

### Task 7.1: Update .claude/CLAUDE.md managed block via manage-claudemd.sh

- **Files**: `.claude/CLAUDE.md`
- **Spec items**: C3
- **Depends on**: Phase 4 (manage-claudemd.sh exists), Phase 2 (template updated)

- [ ] **Step 1: Run manage-claudemd.sh on the robro project itself**
  Run: `CLAUDE_PLUGIN_ROOT=. bash scripts/manage-claudemd.sh .`
  Expected: Output like "Updated robro section (v0.1.1 -> v0.1.2) in .claude/CLAUDE.md"

- [ ] **Step 2: Verify the new marker format in .claude/CLAUDE.md**
  Run: `grep 'robro@' .claude/CLAUDE.md`
  Expected: `<!-- robro@0.1.2:managed:start -->`

- [ ] **Step 3: Verify .robro/sessions references in managed block**
  Run: `grep -c 'docs/plans' .claude/CLAUDE.md`
  Expected: 0 (zero references to old path)

- [ ] **Step 4: Commit**
  `git add .claude/CLAUDE.md && git commit -m "chore: update managed block via manage-claudemd.sh (v0.1.2, new marker format)"`

### Task 7.2: Full docs/plans reference scan

- **Files**: none (verification only)
- **Spec items**: C1
- **Depends on**: all previous phases

- [ ] **Step 1: Run exhaustive grep across entire codebase**
  Run: `grep -rn 'docs/plans' --include='*.sh' --include='*.md' --include='*.yaml' --include='*.json' . | grep -v '.git/' | grep -v 'node_modules' | grep -v 'idea.md' | grep -v 'plan.md'`
  Expected: No matches in runtime code. The only acceptable hits are inside the plan's own artifacts (idea.md, plan.md) which reference the migration history.

- [ ] **Step 2: Run bash -n on all shell scripts**
  Run: `find scripts/ .githooks/ -name '*.sh' -o -name 'pre-push' | xargs -I{} bash -n {}`
  Expected: No errors

### Task 7.3: End-to-end validation checklist

- **Files**: none (verification only)
- **Spec items**: C1, C2, C3, C4, C5, C6, C7
- **Depends on**: Tasks 7.1, 7.2

- [ ] **Step 1: C1 -- Zero docs/plans references**
  Run: `grep -rn 'docs/plans' scripts/ skills/ CLAUDE.md README.md .claude/CLAUDE.md .gitignore hooks/ config.schema.json model-config.yaml`
  Expected: No matches

- [ ] **Step 2: C2 -- Config system works with and without config.json**
  Run: `source scripts/lib/load-config.sh && robro_config '.thresholds.sprint_hard_cap' '30'`
  Expected: `30` (default, since no .robro/config.json exists in plugin repo)

- [ ] **Step 3: C3 -- manage-claudemd.sh uses new marker format**
  Run: `grep 'robro@' scripts/manage-claudemd.sh`
  Expected: Contains `robro@${VERSION}:managed:start`

- [ ] **Step 4: C4 -- .gitignore has .robro/ patterns**
  Run: `grep '.robro/' .gitignore`
  Expected: 4 lines matching `.robro/sessions/` patterns

- [ ] **Step 5: C5 -- Version sync works**
  Run: `diff <(jq -r '.version' .claude-plugin/plugin.json) <(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)`
  Expected: No diff (versions match)

- [ ] **Step 6: C6 -- All 11 agents in model-config.yaml**
  Run: `python3 -c "import yaml; d=yaml.safe_load(open('model-config.yaml')); print(len([k for k in d['tiers']['standard'] if k != 'default']))"`
  Expected: `11`

- [ ] **Step 7: C7 -- JSON Schema is valid**
  Run: `jq . config.schema.json > /dev/null && echo OK`
  Expected: `OK`

## Pre-mortem

| Failure Scenario | Likelihood | Impact | Mitigation |
|------------------|------------|--------|------------|
| 3 scripts without PLANS_DIR need more invasive refactoring than expected | Med | Med | Task 1.2 tackles these first; isolated changes per script with syntax verification |
| manage-claudemd.sh code-block-aware detection has edge cases | Med | Low | awk-based fenced block masking is robust; test with actual .claude/CLAUDE.md which has code blocks with markers inside |
| Config loading via jq fails when config.json has syntax errors | Low | Med | `robro_config` function uses `2>/dev/null` and falls back to default on any jq error |
| Backward compat for old marker format breaks detection | Med | Med | Script explicitly handles both old (`robro:managed:start [VERSION]`) and new (`robro@VERSION:managed:start`) formats |
| `.githooks/` not shared via git clone | High | Low | Documented in CLAUDE.md; setup skill could run `git config core.hooksPath .githooks` |
| Path migration misses an occurrence in a file not tracked | Low | High | Task 2.5 and 7.2 run exhaustive grep; spec-gate C1 requires zero matches |
| model-config.yaml changes cause existing builds to break | Low | Low | Only adding new entries (planner, contrarian, simplifier, ontologist); existing entries unchanged |

## Open Questions

- Should `manage-claudemd.sh` be run automatically on SessionStart to keep the managed block current? Currently requires manual `/robro:setup` invocation. Decided: no auto-run for now -- setup is intentional.
- Should `.githooks/pre-push` also validate that CLAUDE.md markers use the correct version? Decided: out of scope -- version sync only covers plugin.json/marketplace.json.
