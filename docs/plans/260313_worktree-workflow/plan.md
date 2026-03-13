---
type: update
created: 2026-03-13T00:00:00Z
phases: 6
tasks: 21
checklist_items: 24
complexity: complex
---

# Implementation Plan: Worktree-Based Workflow & Pipeline Refinement

## Overview

This plan refactors the robro plugin across six phases: (1) atomic rename of all skill references, (2) worktree lifecycle integration, (3) complexity-driven model configuration, (4) status.yaml/spec.yaml schema redesign, (5) converge-phase merge flow, and (6) cleanup/version bump. The approach is rename-first to establish a clean naming foundation, then layer features on top.

The plugin is a Claude Code extension consisting entirely of Markdown skill definitions, shell hook scripts, JSON configuration, and YAML state files. There is no compiled code, no test runner, and no build system. Verification is manual: reload the plugin, invoke skills, and inspect hook output.

## Tech Context

- **Language**: Shell (bash), Markdown, YAML, JSON -- no compiled languages
- **Testing**: No automated test framework. Verification is via `claude --plugin-dir .` and manual skill invocation, or shell script dry-runs with mock stdin JSON
- **Plugin system**: Claude Code plugins loaded from `.claude-plugin/plugin.json`. Skills at `skills/*/SKILL.md`, agents at `agents/*.md`, hooks via `hooks/hooks.json` pointing to `scripts/*.sh`
- **State management**: `status.yaml` (flat YAML, parsed by grep+sed in shell hooks) drives all hook injection. Lives at plan root, gitignored
- **Worktree tools**: `EnterWorktree(name)` creates `.claude/worktrees/{name}/` and switches CWD. `ExitWorktree("keep"|"discard")` returns to main repo. Agent tool has `isolation: "worktree"` for per-agent worktrees

## Architecture Decision Record

| Decision | Rationale | Alternatives Considered | Trade-offs |
|---|---|---|---|
| Merge approval in converge phase, not hook | Stop hooks can only return `{"decision":"block"}` or exit 0. They cannot use AskUserQuestion. No "PostStop" event exists. | Post-stop hook (impossible), separate merge skill | Merge logic is coupled to the do skill's converge phase instead of being a standalone hook |
| `EnterWorktree` + `git branch -m` for worktree creation | EnterWorktree properly resets CWD-dependent caches (system prompt, memory files). Branch rename gives desired `plan/{slug}` naming. | `git worktree add` via Bash only (no CWD cache reset), manual `cd` (incomplete state reset) | Brief auto-generated branch name appears momentarily before rename |
| `model-config.yaml` at plugin root for model tiers | Dedicated file is cleaner than plugin.json extensions or agent frontmatter. Shell scripts and skills can both read it. | Embed in plugin.json, per-agent frontmatter defaults, environment variables | One more file to maintain; must be read by skills at dispatch time |
| Single atomic commit for rename | Avoids inconsistent intermediate state where some files say "spec" and others say "plan". 27 files, ~100 references. | Incremental rename by category (skills first, then hooks, then docs) | Large diff in one commit; harder to review but safer for consistency |
| Thinking level deferred (platform limitation) | Claude Code Agent tool only exposes `model` parameter. No thinking level/budget parameter exists. | Attempt undocumented parameters, wait for platform update | "Should Have" requirement from idea.md is not implementable today |
| Clean-memory skill replaced by converge-phase cleanup | Worktree lifecycle handles cleanup naturally. Cross-plan pattern analysis was low-value for single plans. | Keep clean-memory alongside worktree, refactor it to work with worktrees | Loss of cross-plan pattern analysis capability; acceptable for pre-1.0 plugin |
| session-start.sh worktree scan for cross-session resume | Only session-start.sh needs worktree awareness. All other hooks work naturally via CWD when inside a worktree. | Status.yaml pointer pattern (requires modifying all 8 hooks), breadcrumb file | session-start.sh becomes slightly more complex; user must re-enter worktree manually |

## File Map

### Files to Create (New)
| File | Responsibility |
|---|---|
| `model-config.yaml` | Plugin-level model tier definitions (light/standard/complex) |
| `skills/plan/SKILL.md` | Renamed from `skills/spec/SKILL.md` with worktree creation logic added |
| `skills/do/SKILL.md` | Renamed from `skills/build/SKILL.md` with model dispatch + merge flow |
| `skills/do/brief-phase.md` | Renamed from `skills/build/brief-phase.md` with model config reading |
| `skills/do/heads-down-phase.md` | Renamed from `skills/build/heads-down-phase.md` |
| `skills/do/review-phase.md` | Renamed from `skills/build/review-phase.md` |
| `skills/do/retro-phase.md` | Renamed from `skills/build/retro-phase.md` |
| `skills/do/level-up-phase.md` | Renamed from `skills/build/level-up-phase.md` |
| `skills/do/converge-phase.md` | Renamed from `skills/build/converge-phase.md` with merge approval flow |
| `skills/do/config-analysis-framework.md` | Renamed from `skills/build/config-analysis-framework.md` |

### Files to Modify (Existing)
| File | Change |
|---|---|
| `scripts/session-start.sh` | Rename refs + worktree scan fallback |
| `scripts/keyword-detector.sh` | Rename refs (spec->plan, build->do) |
| `scripts/pipeline-guard.sh` | Rename refs |
| `scripts/spec-gate.sh` | Rename refs |
| `scripts/drift-monitor.sh` | Rename refs |
| `scripts/stop-hook.sh` | Rename refs |
| `scripts/pre-compact.sh` | Rename refs |
| `scripts/error-tracker.sh` | Rename refs |
| `skills/idea/SKILL.md` | Rename refs to plan/do skills |
| `skills/setup/SKILL.md` | Rename refs |
| `skills/setup/claude-md-template.md` | Rename refs in template content |
| `skills/tune/SKILL.md` | Rename refs |
| `agents/builder.md` | "build skill" -> "do skill" |
| `agents/retro-analyst.md` | "build skill" -> "do skill" |
| `CLAUDE.md` (root) | Full pipeline/skill reference updates |
| `.claude/CLAUDE.md` | Full pipeline/skill reference updates |
| `README.md` | Full pipeline/skill reference updates |
| `.claude-plugin/plugin.json` | Version bump 0.1.0 -> 0.1.1, keyword updates |
| `.gitignore` | Add `.claude/worktrees/` pattern |

### Files to Delete
| File | Reason |
|---|---|
| `skills/clean-memory/SKILL.md` | Replaced by worktree lifecycle cleanup in converge phase |
| `skills/spec/SKILL.md` | Moved to `skills/plan/SKILL.md` |
| `skills/build/` (entire directory) | Moved to `skills/do/` |

---

## Phase 1: Atomic Rename (spec->plan, build->do, remove clean-memory)
> Depends on: none
> Parallel: Tasks 1.1 and 1.2 can run concurrently. Tasks 1.3-1.7 can all run concurrently after 1.1+1.2 complete.
> Delivers: All skill names updated across the entire codebase. `/robro:plan` and `/robro:do` resolve correctly. clean-memory removed.
> Spec sections: S1 (Skill Renaming), S8 (Clean-memory Removal)

### Task 1.1: Rename skill directories (spec->plan, build->do)
- **Files**: `skills/spec/` -> `skills/plan/`, `skills/build/` -> `skills/do/`
- **Spec items**: C1, C2
- **Depends on**: none

- [ ] **Step 1: Create new directories and copy files**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  cp -r skills/spec skills/plan
  cp -r skills/build skills/do
  ```

- [ ] **Step 2: Update skill name in skills/plan/SKILL.md frontmatter**
  In `skills/plan/SKILL.md`, change line 2 from `name: spec` to `name: plan`. Change line 3 description to replace "Transforms product requirements (idea.md) into technical specifications and implementation plans" with "Transforms product requirements (idea.md) into technical implementation plans and validation checklists". Update all internal self-references:
  - Line 55: `skill: spec` -> `skill: plan`
  - Line 70: `skill: spec` -> `skill: plan`
  - Any line containing "the spec skill" -> "the plan skill"
  - **Do NOT rename the file `spec.yaml`** -- that is a file name, not a skill name

- [ ] **Step 3: Update skill name in skills/do/SKILL.md frontmatter**
  In `skills/do/SKILL.md`, change line 2 from `name: build` to `name: do`. Change line 3 description to replace "Autonomously implements plan.md through evolutionary sprint cycles" with the same text but update the `Use when` section from "Use when plan.md and spec.yaml exist and implementation should begin" to "Use when plan.md and spec.yaml exist and execution should begin".
  Update all internal references:
  - Line 20: `suggest /robro:spec first` -> `suggest /robro:plan first`
  - Line 21: `suggest /robro:spec --review` -> `suggest /robro:plan --review`
  - Line 37: `suggest '/robro:spec' first` -> `suggest '/robro:plan' first`
  - Line 44: `skill: build` -> `skill: do`
  - All `skills/build/` path references -> `skills/do/` (lines 59, 62, 73-95+)
  - All "build skill" self-references -> "do skill" (lines 28-30)
  - All `/robro:build` -> `/robro:do`

- [ ] **Step 4: Update all phase files in skills/do/**
  For each file in `skills/do/`:
  - `brief-phase.md`: line 16 `skill: build` -> `skill: do`, line 137 `skill: build` -> `skill: do`
  - `heads-down-phase.md`: line 203 `skill: build` -> `skill: do`
  - `review-phase.md`: line 92 `skill: build` -> `skill: do`
  - `retro-phase.md`: line 78 `skill: build` -> `skill: do`
  - `level-up-phase.md`: line 187 `skill: build` -> `skill: do`
  - `converge-phase.md`: line 110 `skill: build` -> `skill: do`

- [ ] **Step 5: Remove old directories**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  rm -rf skills/spec
  rm -rf skills/build
  ```

- [ ] **Step 6: Verify new skill directories exist with correct names**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  head -3 skills/plan/SKILL.md   # Should show "name: plan"
  head -3 skills/do/SKILL.md     # Should show "name: do"
  ls skills/do/                   # Should list all 8 files
  ls skills/plan/                 # Should list SKILL.md
  test ! -d skills/spec && echo "spec dir removed" || echo "ERROR: spec dir still exists"
  test ! -d skills/build && echo "build dir removed" || echo "ERROR: build dir still exists"
  ```

### Task 1.2: Delete clean-memory skill
- **Files**: `skills/clean-memory/SKILL.md`
- **Spec items**: C16
- **Depends on**: none

- [ ] **Step 1: Delete the clean-memory directory**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  rm -rf skills/clean-memory
  ```

- [ ] **Step 2: Verify deletion**
  ```bash
  test ! -d /Users/skywrace/Documents/github.com/JWWon/robro/skills/clean-memory && echo "PASS: clean-memory removed" || echo "FAIL"
  ```

### Task 1.3: Update all 8 hook scripts with renamed skill references
- **Files**: `scripts/session-start.sh`, `scripts/keyword-detector.sh`, `scripts/pipeline-guard.sh`, `scripts/spec-gate.sh`, `scripts/drift-monitor.sh`, `scripts/stop-hook.sh`, `scripts/pre-compact.sh`, `scripts/error-tracker.sh`
- **Spec items**: C3, C4
- **Depends on**: Task 1.1

- [ ] **Step 1: Update scripts/session-start.sh**
  Apply these exact changes:
  - Line 7: `/robro:spec (EM) | /robro:build (Builder)` -> `/robro:plan (EM) | /robro:do (Builder)`
  - Line 49: `elif [ "$skill" = "spec" ]` -> `elif [ "$skill" = "plan" ]`
  - Line 52: `elif [ "$skill" = "build" ]` -> `elif [ "$skill" = "do" ]`
  - Line 75: `/robro:build` -> `/robro:do`

- [ ] **Step 2: Update scripts/keyword-detector.sh**
  Apply these exact changes:
  - Line 31: `*"robro spec"*|*"robro:spec"*` -> `*"robro plan"*|*"robro:plan"*`
  - Line 32: `Use /robro:spec to generate technical spec` -> `Use /robro:plan to generate technical spec`
  - Line 35: `*"robro build"*|*"robro:build"*` -> `*"robro do"*|*"robro:do"*`
  - Line 36: `Use /robro:build to start autonomous implementation` -> `Use /robro:do to start autonomous execution`
  - Line 77 comment: `# Tier 2.5: Natural language triggers for /robro:spec` -> `# Tier 2.5: Natural language triggers for /robro:plan`
  - Line 88: `"spec this"` -> remove this entry (conflicts with "plan this" already on line 79). Delete the line.
  - Line 104: `/robro:spec to generate the technical spec` -> `/robro:plan to generate the technical spec`
  - Line 106: `/robro:spec for the technical plan` -> `/robro:plan for the technical plan`
  - Line 146: `/robro:build for structured autonomous implementation` -> `/robro:do for structured autonomous execution`
  - Line 148: `/robro:spec before implementing` -> `/robro:plan before implementing`

- [ ] **Step 3: Update scripts/pipeline-guard.sh**
  - Line 71: `suggest /robro:spec` -> `suggest /robro:plan`
  - Line 78: `spec)` -> `plan)`
  - Line 94: `build)` -> `do)`

- [ ] **Step 4: Update scripts/spec-gate.sh**
  - Line 43: `/robro:spec to create the technical spec` -> `/robro:plan to create the technical spec`
  - Line 57: `if [ "$build_skill" = "build" ]` -> `if [ "$build_skill" = "do" ]`

- [ ] **Step 5: Update scripts/drift-monitor.sh**
  - Line 64: `if [ "$build_skill" = "build" ]` -> `if [ "$build_skill" = "do" ]`

- [ ] **Step 6: Update scripts/stop-hook.sh**
  - Line 26: `[ "$skill" = "build" ]` -> `[ "$skill" = "do" ]`
  - Line 97: `/robro:build to resume` -> `/robro:do to resume`

- [ ] **Step 7: Update scripts/pre-compact.sh**
  - Line 24: `elif [ "$skill" = "spec" ]` -> `elif [ "$skill" = "plan" ]`
  - Line 27: `elif [ "$skill" = "build" ]` -> `elif [ "$skill" = "do" ]`

- [ ] **Step 8: Update scripts/error-tracker.sh**
  - Line 23: `[ "$skill" = "build" ]` -> `[ "$skill" = "do" ]`

- [ ] **Step 9: Verify all hook scripts have no remaining old references**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  grep -rn '"spec"' scripts/ | grep -v "spec.yaml" | grep -v "spec " | grep -v "# spec"
  grep -rn '"build"' scripts/
  grep -rn '/robro:spec' scripts/
  grep -rn '/robro:build' scripts/
  # All four commands should return empty (no matches)
  ```

### Task 1.4: Update remaining skill files with renamed references
- **Files**: `skills/idea/SKILL.md`, `skills/setup/SKILL.md`, `skills/setup/claude-md-template.md`, `skills/tune/SKILL.md`
- **Spec items**: C3
- **Depends on**: Task 1.1

- [ ] **Step 1: Update skills/idea/SKILL.md**
  - Line 88: `suggest running '/robro:spec'` -> `suggest running '/robro:plan'`
  - Line 406: `run /robro:spec` -> `run /robro:plan`

- [ ] **Step 2: Update skills/setup/SKILL.md**
  - Line 22: `use /robro:build instead` -> `use /robro:do instead`

- [ ] **Step 3: Update skills/setup/claude-md-template.md**
  This is the template that `/robro:setup` writes into projects' `.claude/CLAUDE.md`. Apply:
  - Line 8: `/robro:spec (EM)` -> `/robro:plan (EM)`, `/robro:build (Builder)` -> `/robro:do (Builder)`
  - Line 16: `/robro:spec` row -> `/robro:plan` with description "Converts idea.md into phased implementation plan..."
  - Line 17: `/robro:build` row -> `/robro:do` with description "Autonomously executes plan.md through evolutionary sprint cycles..."
  - Line 19: Remove the `/robro:clean-memory` row entirely
  - Line 26: `from /robro:spec` -> `from /robro:plan`
  - Line 48: `/robro:spec` -> `/robro:plan`
  - Line 50: `/robro:build` -> `/robro:do`, update "Build" context references
  - Remove any remaining `/robro:clean-memory` references

- [ ] **Step 4: Update skills/tune/SKILL.md**
  - Line 3: `happens automatically in /robro:build` -> `happens automatically in /robro:do`
  - Line 21: `use /robro:build instead` -> `use /robro:do instead`
  - Line 22: Remove the line referencing `/robro:clean-memory` ("User wants to clean up completed plans — use /robro:clean-memory instead")
  - Line 32: `skill: build` -> `skill: do`
  - Line 40: `skills/build/config-analysis-framework.md` -> `skills/do/config-analysis-framework.md`
  - Line 104: `run a '/robro:build' sprint` -> `run a '/robro:do' sprint`

- [ ] **Step 5: Verify no old skill name references remain in skills/**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  grep -rn '/robro:spec' skills/ | grep -v 'spec.yaml'
  grep -rn '/robro:build' skills/
  grep -rn '/robro:clean-memory' skills/
  # All three should return empty
  ```

### Task 1.5: Update agent files with renamed references
- **Files**: `agents/builder.md`, `agents/retro-analyst.md`
- **Spec items**: C3
- **Depends on**: none

- [ ] **Step 1: Update agents/builder.md**
  - Line 6: "the build skill determines the execution mode" -> "the do skill determines the execution mode"

- [ ] **Step 2: Update agents/retro-analyst.md**
  - Line 18: "the build skill" -> "the do skill"

- [ ] **Step 3: Verify no old references remain in agents/**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  grep -rn 'build skill' agents/
  grep -rn '/robro:build' agents/
  grep -rn '/robro:spec' agents/ | grep -v 'spec.yaml'
  # All three should return empty
  ```

### Task 1.6: Update all three documentation files
- **Files**: `CLAUDE.md` (root), `.claude/CLAUDE.md`, `README.md`
- **Spec items**: C3, C16
- **Depends on**: Task 1.2

- [ ] **Step 1: Update CLAUDE.md (root)**
  Apply all changes from the rename impact inventory research/13. Key changes:
  - Pipeline flow diagram: `/robro:spec (EM)` -> `/robro:plan (EM)`, `/robro:build (Builder)` -> `/robro:do (Builder)`
  - Directory structure section: `skills/spec/` -> `skills/plan/`, `skills/build/` -> `skills/do/`
  - Core Skills descriptions: rename `/robro:spec` entry to `/robro:plan`, `/robro:build` to `/robro:do`
  - Remove `/robro:clean-memory` from the skill list
  - All "During `/robro:build`" -> "During `/robro:do`"
  - All "from `/robro:spec`" -> "from `/robro:plan`"
  - Update agent table: Builder agent "Used By" column: "build" -> "do"
  - Update Spec Mutation Rules header: "During `/robro:build`" -> "During `/robro:do`"
  - Update Iteration Policy references
  - Update Hooks table references
  - Update skill count: "6 skills" -> "5 skills", list becomes "(idea, plan, do, setup, tune)"
  - `skills/build/config-analysis-framework.md` -> `skills/do/config-analysis-framework.md`

- [ ] **Step 2: Update .claude/CLAUDE.md**
  Apply all changes:
  - Pipeline flow line: `/robro:spec (EM)` -> `/robro:plan (EM)`, `/robro:build (Builder)` -> `/robro:do (Builder)`
  - Skills table: rename `/robro:spec` -> `/robro:plan`, `/robro:build` -> `/robro:do`
  - Remove `/robro:clean-memory` row from skills table
  - Plan artifacts: `from /robro:spec` -> `from /robro:plan`
  - Iteration policy: `/robro:spec` -> `/robro:plan`, `/robro:build` -> `/robro:do`
  - Build agents table: update "Builder" row's context if needed
  - Do Not Use When in setup skill reference: `/robro:build` -> `/robro:do`

- [ ] **Step 3: Update README.md**
  Apply all changes:
  - Pipeline diagram: `/robro:spec` -> `/robro:plan`, `/robro:build` -> `/robro:do`
  - Skills table: rename rows, remove `/robro:clean-memory` row
  - "What just happened?" details section: `/robro:spec` -> `/robro:plan`, `/robro:build` -> `/robro:do`
  - Agent dispatch mapping: `/robro:spec` -> `/robro:plan`, `/robro:build` -> `/robro:do`
  - Stage table: rename "Spec" to "Plan", "Build" to "Do"

- [ ] **Step 4: Verify no old references remain in documentation**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  grep -rn '/robro:spec' CLAUDE.md .claude/CLAUDE.md README.md | grep -v 'spec.yaml'
  grep -rn '/robro:build' CLAUDE.md .claude/CLAUDE.md README.md
  grep -rn '/robro:clean-memory' CLAUDE.md .claude/CLAUDE.md README.md
  # All three should return empty
  ```

### Task 1.7: Update plugin.json keywords
- **Files**: `.claude-plugin/plugin.json`
- **Spec items**: C17
- **Depends on**: none

- [ ] **Step 1: Update keywords array**
  In `.claude-plugin/plugin.json`, change line 11:
  ```json
  "keywords": ["planning", "plan", "requirements", "idea", "do", "implementation"],
  ```

- [ ] **Step 2: Verify**
  ```bash
  cat /Users/skywrace/Documents/github.com/JWWon/robro/.claude-plugin/plugin.json
  # Should show updated keywords, version still 0.1.0 (bumped in Phase 6)
  ```

### Task 1.8: Commit the atomic rename
- **Files**: All files from Tasks 1.1-1.7
- **Spec items**: C1, C2, C3, C4, C16
- **Depends on**: Tasks 1.1-1.7

- [ ] **Step 1: Stage and commit**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  git add -A
  git status  # Review: should show ~27 files changed
  git commit -m "refactor: rename spec->plan, build->do, remove clean-memory

  Pipeline becomes: /robro:idea -> /robro:plan -> /robro:do
  - Rename skills/spec/ to skills/plan/
  - Rename skills/build/ to skills/do/
  - Delete skills/clean-memory/
  - Update all 8 hook scripts
  - Update all skill, agent, and documentation references
  - Update plugin.json keywords"
  ```

---

## Phase 2: Worktree Lifecycle
> Depends on: Phase 1
> Parallel: Tasks 2.1 and 2.2 can run concurrently. Task 2.3 depends on both.
> Delivers: Plan skill creates worktree at start. Idea skill stays on main. session-start.sh detects worktree plans for cross-session resume.
> Spec sections: S2 (Worktree Lifecycle), S7 (Cross-session Resume)

### Task 2.1: Add .gitignore entry for worktree directory
- **Files**: `.gitignore`
- **Spec items**: C6
- **Depends on**: none

- [ ] **Step 1: Add worktree gitignore pattern**
  Append to `.gitignore` after the existing plan artifact rules:
  ```
  # Worktree directories
  .claude/worktrees/
  ```

- [ ] **Step 2: Verify**
  ```bash
  grep -n "worktrees" /Users/skywrace/Documents/github.com/JWWon/robro/.gitignore
  # Should show the new line
  ```

- [ ] **Step 3: Commit**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  git add .gitignore
  git commit -m "chore: gitignore .claude/worktrees/ directory"
  ```

### Task 2.2: Add worktree creation logic to plan skill
- **Files**: `skills/plan/SKILL.md`
- **Spec items**: C5, C6, C7
- **Depends on**: Phase 1

- [ ] **Step 1: Read current skills/plan/SKILL.md to identify insertion point**
  Read the file. The worktree creation logic goes into the workflow section, immediately after Step 1 (Read & Internalize Requirements) and before Step 2 (Technical Deep Dive). The idea is: the plan skill first reads idea.md on main, then creates the worktree, copies files, and continues work in the worktree.

- [ ] **Step 2: Add new Step 1.5 "Create Plan Worktree" section**
  After the existing Step 1 block (which reads idea.md and initializes status.yaml), insert a new section. Find the line that says `### Step 2: Technical Deep Dive` and insert before it:

  ```markdown
  ### Step 1.5: Create Plan Worktree

  Create an isolated worktree for all plan and implementation work. This keeps main branch clean -- only the final squash merge commit lands on main.

  1. **Save the current plan directory path** (e.g., `docs/plans/260313_worktree-workflow/`). You have already read idea.md and research files from here.

  2. **Create worktree**:
     ```
     EnterWorktree(name: "{slug}")
     ```
     Where `{slug}` is the plan directory basename (e.g., `260313_worktree-workflow`). This creates `.claude/worktrees/{slug}/` and switches the session CWD to it.

     **Resume check**: If the worktree already exists (from a previous interrupted session), skip creation and just enter it.

  3. **Rename branch** for clarity:
     ```bash
     git branch -m plan/{slug}
     ```

  4. **Copy plan files from main to worktree**:
     ```bash
     # Copy the entire plan directory (including gitignored research/, discussion/)
     cp -r /path/to/main-repo/docs/plans/{slug}/ docs/plans/{slug}/
     ```
     The source path is the absolute path to the main repo's plan directory that you saved in step 1.

  5. **Clean up main's working directory**:
     ```bash
     rm -rf /path/to/main-repo/docs/plans/{slug}/
     ```
     This prevents hooks from finding stale state when a session starts from the main repo.

  6. **Update status.yaml** in the worktree:
     ```yaml
     skill: plan
     step: 2
     branch: plan/{slug}
     worktree: .claude/worktrees/{slug}
     detail: "Worktree created, starting technical deep dive"
     next: "Dispatch Researcher, Architect, and Critic"
     gate: "Architect APPROVED + Critic PASS, user approves ADR and plan"
     ```

  All subsequent work (Steps 2-10) happens inside the worktree. Commits go to the `plan/{slug}` branch.
  ```

- [ ] **Step 3: Verify the insertion**
  Read `skills/plan/SKILL.md` and confirm Step 1.5 appears between Step 1 and Step 2. Confirm no duplicate sections.

### Task 2.3: Add worktree scan to session-start.sh for cross-session resume
- **Files**: `scripts/session-start.sh`
- **Spec items**: C7
- **Depends on**: Task 2.1

- [ ] **Step 1: Read current session-start.sh**
  Read the file to identify where to add the worktree scan block.

- [ ] **Step 2: Add worktree scan fallback**
  After the existing `fi` that closes the `if [ -n "$status_file" ]` block (around line 81), and before the "List all plans briefly" section (around line 83), insert:

  ```bash
  # If no active status found in docs/plans/, check worktrees for active plans
  if [ -z "$status_file" ] || [ "$skill" = "none" ] || [ -z "$skill" ]; then
    WORKTREE_DIR=".claude/worktrees"
    if [ -d "$WORKTREE_DIR" ]; then
      for wt_dir in "$WORKTREE_DIR"/*/; do
        [ -d "$wt_dir" ] || continue
        for plan_dir in "${wt_dir}docs/plans"/*/; do
          [ -d "$plan_dir" ] || continue
          candidate="${plan_dir}status.yaml"
          [ -f "$candidate" ] || continue
          wt_skill=$(grep "^skill:" "$candidate" 2>/dev/null | head -1 | sed 's/^skill: *//; s/"//g')
          [ -z "$wt_skill" ] || [ "$wt_skill" = "none" ] && continue
          wt_name=$(basename "$wt_dir")
          wt_step=$(grep "^step:" "$candidate" 2>/dev/null | head -1 | sed 's/^step: *//; s/"//g')
          wt_detail=$(grep "^detail:" "$candidate" 2>/dev/null | head -1 | sed 's/^detail: *//; s/"//g')
          context="${context}

  WORKTREE RESUME: Plan '$(basename "$plan_dir")' is active in worktree '${wt_name}'.
  Skill: /robro:${wt_skill}, step ${wt_step} (${wt_detail})
  To resume: Run EnterWorktree(name: \"${wt_name}\") to switch to the worktree."
          break 2
        done
      done
    fi
  fi
  ```

- [ ] **Step 3: Verify the script is syntactically valid**
  ```bash
  bash -n /Users/skywrace/Documents/github.com/JWWon/robro/scripts/session-start.sh
  echo $?  # Should be 0
  ```

- [ ] **Step 4: Commit**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  git add skills/plan/SKILL.md scripts/session-start.sh .gitignore
  git commit -m "feat: add worktree lifecycle to plan skill and session resume

  - Plan skill creates worktree at Step 1.5 via EnterWorktree
  - Copies plan files from main, cleans up main's working dir
  - session-start.sh scans .claude/worktrees/ for cross-session resume
  - .gitignore excludes .claude/worktrees/"
  ```

---

## Phase 3: Complexity-Driven Model Configuration
> Depends on: Phase 1
> Parallel: Tasks 3.1 and 3.2 can run concurrently. Task 3.3 depends on 3.1.
> Delivers: model-config.yaml defines 3 tiers. Do skill reads it at Brief phase and dispatches agents with tier-appropriate models. spec.yaml gains complexity field.
> Spec sections: S3 (Complexity Tiers), S4 (Model Config), S5 (spec.yaml complexity)

### Task 3.1: Create model-config.yaml at plugin root
- **Files**: `model-config.yaml` (new)
- **Spec items**: C10, C11
- **Depends on**: none

- [ ] **Step 1: Create the model config file**
  Create `model-config.yaml` at the plugin root (`/Users/skywrace/Documents/github.com/JWWon/robro/model-config.yaml`) with the following content:

  ```yaml
  # Model configuration per complexity tier
  # Read by /robro:do at Brief phase to determine agent dispatch models
  # Tiers: light (fast/cheap), standard (balanced), complex (thorough)
  #
  # Agent tool model values: haiku, sonnet, opus
  # Researcher and retro-analyst are capped at sonnet (never opus)
  # -- they gather/summarize, they don't make architectural decisions

  tiers:
    light:
      default: haiku
      builder: haiku
      reviewer: sonnet
      architect: sonnet
      critic: sonnet
      researcher: haiku
      retro-analyst: haiku
    standard:
      default: sonnet
      builder: sonnet
      reviewer: sonnet
      architect: opus
      critic: opus
      researcher: sonnet
      retro-analyst: sonnet
    complex:
      default: opus
      builder: opus
      reviewer: opus
      architect: opus
      critic: opus
      researcher: sonnet
      retro-analyst: sonnet
  ```

- [ ] **Step 2: Verify the file is valid YAML**
  ```bash
  python3 -c "import yaml; yaml.safe_load(open('/Users/skywrace/Documents/github.com/JWWon/robro/model-config.yaml'))" && echo "VALID" || echo "INVALID"
  ```

### Task 3.2: Add complexity field to spec.yaml schema in plan skill
- **Files**: `skills/plan/SKILL.md`
- **Spec items**: C12
- **Depends on**: Phase 1

- [ ] **Step 1: Read current plan skill to find spec.yaml generation section**
  Read `skills/plan/SKILL.md` and locate the section where spec.yaml is generated (Step 7 or Step 8 area, the "Generate spec.yaml" section).

- [ ] **Step 2: Add complexity field to the spec.yaml meta section**
  In the spec.yaml template/schema section of the plan skill, add `complexity` to the metadata block. Find the `meta:` section in the spec.yaml template and add after the existing fields:

  ```yaml
  meta:
    goal: "{from idea.md}"
    constraints: "{from idea.md}"
    tech_stack: "{detected or from idea.md}"
    complexity: "{light|standard|complex}"  # From idea.md frontmatter, confirmed/adjusted by plan skill
  ```

  Also add a note to the plan skill's Step 7 instructions explaining:
  ```markdown
  **Complexity assignment**: Read the `complexity` field from idea.md frontmatter. If not present, assess based on:
  - **light**: Single file change, config update, simple bugfix. 1-3 spec items.
  - **standard**: Multi-file feature, moderate scope. 4-15 spec items.
  - **complex**: Cross-cutting change, multiple subsystems, architectural impact. 15+ spec items.
  Record the complexity in spec.yaml's `meta.complexity` field. The do skill reads this to select agent models.
  ```

- [ ] **Step 3: Verify the change**
  Read `skills/plan/SKILL.md` and confirm the complexity field appears in the spec.yaml template.

### Task 3.3: Add model config reading to do skill Brief phase
- **Files**: `skills/do/brief-phase.md`, `skills/do/SKILL.md`
- **Spec items**: C10, C11, C13
- **Depends on**: Task 3.1

- [ ] **Step 1: Read current brief-phase.md**
  Read `skills/do/brief-phase.md` to find the right insertion point (after "Read Current State" and before the researcher pre-flight).

- [ ] **Step 2: Add model config reading step to brief-phase.md**
  After the "### 1. Read Current State" section and before "### 1.5. Clean Stale Worktrees", insert a new section:

  ```markdown
  ### 1.1. Load Model Configuration

  Read the complexity tier and load model mappings for agent dispatch:

  1. Read `meta.complexity` from spec.yaml. Expected values: `light`, `standard`, `complex`. Default to `standard` if missing.
  2. Read `${CLAUDE_PLUGIN_ROOT}/model-config.yaml` to load the tier definitions.
  3. Select the tier matching the complexity value.
  4. Store the model mapping for use in all subsequent agent dispatches this sprint:
     ```
     MODEL_CONFIG:
       complexity: {tier name}
       builder: {model}
       reviewer: {model}
       architect: {model}
       critic: {model}
       researcher: {model}
       retro-analyst: {model}
     ```
  5. Log to build-progress.md: "Sprint {N}: Using {tier} complexity tier ({model} for builder, {model} for reviewer, ...)"

  For every Agent() dispatch in Heads-down, Review, Retro, and Level-up phases, include `model: "{model from MODEL_CONFIG}"` based on the agent type being dispatched.
  ```

- [ ] **Step 3: Update SKILL.md to reference model config**
  In `skills/do/SKILL.md`, add a brief note in the "### Phase 1: Brief" summary section, after "Reset stop hook counter file":
  ```markdown
  - Load model-config.yaml and select complexity tier for agent dispatch
  ```

- [ ] **Step 4: Update heads-down-phase.md agent dispatch examples**
  In `skills/do/heads-down-phase.md`, update the Agent() dispatch examples to include the model parameter. For example, in the inline builder dispatch example, change:
  ```
  Agent(
    subagent_type: "robro:builder",
    prompt: "<builder context below>",
    run_in_background: true
  )
  ```
  to:
  ```
  Agent(
    subagent_type: "robro:builder",
    prompt: "<builder context below>",
    model: "{MODEL_CONFIG.builder}",
    run_in_background: true
  )
  ```

  Apply the same pattern to the isolated builder dispatch and the reviewer dispatch in review-phase.md, retro-analyst dispatch in retro-phase.md, and architect/critic dispatches wherever they appear.

- [ ] **Step 5: Commit**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  git add model-config.yaml skills/plan/SKILL.md skills/do/brief-phase.md skills/do/SKILL.md skills/do/heads-down-phase.md skills/do/review-phase.md skills/do/retro-phase.md
  git commit -m "feat: add 3-tier complexity model config for agent dispatch

  - Create model-config.yaml with light/standard/complex tiers
  - Plan skill writes complexity to spec.yaml meta section
  - Do skill Brief phase reads model config and selects tier
  - All agent dispatches include model parameter from tier config
  - Researcher and retro-analyst capped at sonnet (never opus)"
  ```

---

## Phase 4: Status.yaml Schema Redesign
> Depends on: Phase 1
> Parallel: Tasks 4.1 and 4.2 can run concurrently.
> Delivers: status.yaml uses typed fields (numeric ambiguity, integer steps, structured detail). All skills and hooks produce/consume the new schema.
> Spec sections: S6 (Status.yaml Schema)

### Task 4.1: Update status.yaml schema in all skill files
- **Files**: `skills/idea/SKILL.md`, `skills/plan/SKILL.md`, `skills/do/SKILL.md`, `skills/do/brief-phase.md`, `skills/do/converge-phase.md`
- **Spec items**: C14, C15
- **Depends on**: Phase 1

- [ ] **Step 1: Define the new schema**
  The new status.yaml schema uses typed fields. All fields are flat (no nesting -- hooks parse with grep+sed). The new schema:

  ```yaml
  # Flat YAML only. Hooks parse with grep+sed. No nested structures.
  skill: plan              # idea | plan | do | none
  step: 4                  # Integer (was string "3.5" -- now use integers only)
  sprint: 1                # Integer, only used during do skill
  phase: brief             # brief | heads-down | review | retro | level-up | converge
  ambiguity: 0.08          # Float 0.0-1.0, only used during idea skill
  complexity: standard      # light | standard | complex, from spec.yaml
  branch: plan/260313_foo  # Branch name when in worktree
  worktree: .claude/worktrees/260313_foo  # Worktree path (empty on main)
  detail: "Generating plan.md"  # Current activity
  next: "Run plan reviewer"     # Next action
  gate: "All review loops pass" # Exit condition
  attempt: 1               # Integer, retry count for current step
  reinforcement_count: 0   # Integer, stop hook counter
  ```

- [ ] **Step 2: Update skills/idea/SKILL.md status.yaml templates**
  Find all status.yaml template blocks in idea/SKILL.md and update them:
  - Replace `step: "0"` with `step: 0` (remove quotes, integer)
  - Replace `step: "3"` with `step: 3` (remove quotes)
  - Add `ambiguity: 0.0` field where appropriate
  - Add `complexity: ""` as empty placeholder
  - Add `branch: ""` and `worktree: ""` as empty placeholders
  - Ensure all templates match the new schema

- [ ] **Step 3: Update skills/plan/SKILL.md status.yaml templates**
  Find all status.yaml template blocks in plan/SKILL.md and update:
  - Replace `step: "1"` with `step: 1`, `step: "3.5"` with `step: 4` (renumber to integers)
  - Add `complexity: ""` field
  - Add `branch: ""` and `worktree: ""` fields
  - The Step 1.5 section (from Task 2.2) already has `branch:` and `worktree:` -- ensure consistency

- [ ] **Step 4: Update skills/do/SKILL.md status.yaml templates**
  Find the status.yaml template in do/SKILL.md and update:
  - Replace `step: "brief"` with `step: 1` (phase field already carries the phase name)
  - Add `complexity: standard` field
  - Add `branch: plan/{slug}` and `worktree: .claude/worktrees/{slug}` fields
  - Ensure `sprint:`, `phase:`, `attempt:`, `reinforcement_count:` are present

- [ ] **Step 5: Update skills/do/brief-phase.md and converge-phase.md status templates**
  In brief-phase.md: update all `skill: do` template blocks to use integer steps and include all new fields.
  In converge-phase.md: update the convergence-reached and not-yet-converged templates to include the new fields.

- [ ] **Step 6: Verify no quoted step values remain in skill files**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  grep -rn 'step: "' skills/
  # Should return empty (no quoted step values)
  ```

### Task 4.2: Verify hook scripts are compatible with new schema
- **Files**: All 8 scripts in `scripts/`
- **Spec items**: C14, C15
- **Depends on**: Phase 1

- [ ] **Step 1: Review all grep patterns in hook scripts**
  The hooks parse status.yaml with patterns like:
  ```bash
  skill=$(grep "^skill:" "$candidate" | head -1 | sed 's/^skill: *//; s/"//g')
  ```
  The `sed 's/"//g'` strip already handles both quoted and unquoted values. Since we are moving FROM quoted strings TO plain values, the grep+sed patterns remain compatible.

  Verify by running each grep pattern against a sample new-schema status.yaml:
  ```bash
  cat > /tmp/test-status.yaml << 'EOF'
  skill: do
  step: 4
  sprint: 2
  phase: heads-down
  ambiguity: 0.08
  complexity: standard
  branch: plan/260313_test
  worktree: .claude/worktrees/260313_test
  detail: "Implementing task 2.3"
  next: "Run tests"
  gate: "All 5 gates pass"
  attempt: 1
  reinforcement_count: 3
  EOF

  # Test each field extraction
  grep "^skill:" /tmp/test-status.yaml | head -1 | sed 's/^skill: *//; s/"//g'
  grep "^step:" /tmp/test-status.yaml | head -1 | sed 's/^step: *//; s/"//g'
  grep "^sprint:" /tmp/test-status.yaml | head -1 | sed 's/^sprint: *//; s/"//g'
  grep "^phase:" /tmp/test-status.yaml | head -1 | sed 's/^phase: *//; s/"//g'
  grep "^detail:" /tmp/test-status.yaml | head -1 | sed 's/^detail: *//; s/"//g'
  grep "^next:" /tmp/test-status.yaml | head -1 | sed 's/^next: *//; s/"//g'
  # All should return clean values without quotes
  ```

- [ ] **Step 2: Confirm no hook changes needed**
  The grep+sed patterns in all 8 hooks are forward-compatible with the new schema. The key insight is that `sed 's/"//g'` strips quotes if present and is a no-op if absent. No hook scripts need modification for schema compatibility.

- [ ] **Step 3: Commit schema changes**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  git add skills/idea/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md skills/do/brief-phase.md skills/do/converge-phase.md
  git commit -m "feat: redesign status.yaml schema with typed fields

  - Integer step numbers (no more quoted strings or floats)
  - Numeric ambiguity score field
  - New fields: complexity, branch, worktree, attempt, reinforcement_count
  - All fields remain flat YAML (grep+sed compatible)
  - Hook scripts require zero changes (sed quote-strip is forward-compatible)"
  ```

---

## Phase 5: Converge Phase Merge Flow
> Depends on: Phase 2
> Parallel: Tasks 5.1 and 5.2 must be sequential.
> Delivers: After all gates pass in converge, user is prompted for merge approval. On approval: ExitWorktree, squash merge to main, worktree/branch cleanup.
> Spec sections: S9 (Squash Merge), S10 (Converge Merge Approval)

### Task 5.1: Add merge approval flow to converge-phase.md
- **Files**: `skills/do/converge-phase.md`
- **Spec items**: C8, C9, C18, C19
- **Depends on**: Phase 2

- [ ] **Step 1: Read current converge-phase.md**
  Read `skills/do/converge-phase.md` to understand the current convergence-reached section.

- [ ] **Step 2: Replace the "Convergence Reached" section**
  Find the `## Convergence Reached` section (starts around line 77) and replace it entirely with:

  ```markdown
  ## Convergence Reached

  If all 5 gates pass:

  1. Log to build-progress.md: "Build converged! All spec items passing."

  2. Append final summary to build-progress.md:
     ```markdown
     ## CONVERGENCE — Sprint {N} — {timestamp}
     - Total sprints: {N}
     - Spec items: {passing}/{total} passing ({superseded} superseded)
     - Mutations applied: {total from spec-mutations.log}
     - Level-ups created: {count from levelup-manifest.yaml}
     - Pathologies encountered: {list}
     ```

  3. **Present merge summary and ask for approval** via AskUserQuestion:
     ```
     Build converged! All spec.yaml items passing.

     Summary:
     - Sprints: {N}
     - Spec items: {passing}/{total} ({superseded} superseded)
     - Branch: plan/{slug}
     - Commits on branch: {count from git log main..HEAD --oneline}

     Merge to main via squash merge?

     Options:
     - "Merge" — squash merge to main, delete worktree and branch
     - "Keep" — stay in worktree for manual review before merging
     - "Discard" — delete worktree and branch without merging
     ```

  4. **Handle user response**:

     **If "Merge"**:
     a. Exit the worktree:
        ```
        ExitWorktree(action: "keep")
        ```
        This returns the session to the main repo. The worktree remains on disk for the merge.

     b. Squash merge:
        ```bash
        git merge --squash plan/{slug}
        git commit -m "feat({slug}): {one-line description from idea.md goal}"
        ```
        If merge conflicts occur, present them to the user via AskUserQuestion. Do NOT auto-resolve -- let the user decide.

     c. Clean up worktree and branch:
        ```bash
        git worktree remove .claude/worktrees/{slug}
        git branch -D plan/{slug}
        ```

     d. Set final status:
        ```yaml
        skill: none
        sprint: {N}
        phase: done
        detail: "Converged and merged to main"
        next: "Build complete"
        ```

     e. Print final message:
        ```
        Merged to main: feat({slug}): {description}
        Worktree and branch cleaned up.
        ```

     **If "Keep"**:
     - Set status.yaml:
       ```yaml
       skill: none
       sprint: {N}
       phase: done
       detail: "Converged — kept in worktree for manual review"
       next: "Manual merge when ready"
       ```
     - Print: "Staying in worktree. To merge later: exit the worktree, run `git merge --squash plan/{slug}`, then clean up with `git worktree remove .claude/worktrees/{slug} && git branch -D plan/{slug}`."

     **If "Discard"**:
     a. Exit the worktree:
        ```
        ExitWorktree(action: "discard")
        ```
     b. Clean up:
        ```bash
        git branch -D plan/{slug}
        ```
     c. Set status: `skill: none`, `detail: "Discarded"`
  ```

- [ ] **Step 3: Also update the "Sprint Hard Cap" section**
  Find the `## Sprint Hard Cap (D11)` section and update it to include worktree-aware exit:

  Replace "Set `skill: none` in status.yaml" with:
  ```markdown
  - Present to user via AskUserQuestion: "Sprint hard cap (30) reached with {remaining} failing items. Options: Merge partial progress | Keep in worktree | Discard"
  - Handle response the same as the convergence merge flow above
  ```

- [ ] **Step 4: Verify the file is coherent**
  Read the full `skills/do/converge-phase.md` and confirm:
  - 5-gate check is unchanged
  - Pathology detection is unchanged
  - Convergence Reached now includes merge approval via AskUserQuestion
  - Sprint Hard Cap includes merge option
  - Not Yet Converged section is unchanged

- [ ] **Step 5: Commit**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  git add skills/do/converge-phase.md
  git commit -m "feat: add merge approval flow to converge phase

  - AskUserQuestion for merge/keep/discard after convergence
  - ExitWorktree + squash merge + cleanup on merge approval
  - Merge conflicts presented to user (no auto-resolve)
  - Sprint hard cap also offers merge option"
  ```

### Task 5.2: Update do skill SKILL.md to document merge flow
- **Files**: `skills/do/SKILL.md`
- **Spec items**: C8, C18
- **Depends on**: Task 5.1

- [ ] **Step 1: Read current do/SKILL.md converge phase summary**
  Read `skills/do/SKILL.md` and find the "### Phase 6: Converge" section.

- [ ] **Step 2: Update the converge phase summary**
  Update the existing converge summary to include the merge flow:
  ```markdown
  ### Phase 6: Converge
  Read `skills/do/converge-phase.md` for detailed instructions.

  Summary:
  - Run 5-gate convergence check (Review, Completeness, Regression, Growth, Confidence)
  - Detect pathologies (Spinning, Oscillation, Stagnation)
  - If converged: present merge summary to user via AskUserQuestion
    - "Merge": ExitWorktree, squash merge to main, delete worktree/branch
    - "Keep": Stay in worktree for manual review
    - "Discard": Delete worktree/branch without merging
  - If not converged: prepare next sprint, continue
  - Sprint hard cap at 30 also triggers merge decision
  ```

- [ ] **Step 3: Commit**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  git add skills/do/SKILL.md
  git commit -m "docs: update do skill converge summary with merge flow"
  ```

---

## Phase 6: Documentation, Version Bump & Thinking Level Documentation
> Depends on: Phases 1-5
> Parallel: Tasks 6.1, 6.2, and 6.3 can all run concurrently.
> Delivers: Plugin version 0.1.1. All documentation reflects new workflow. Thinking level limitation documented. Clean final state.
> Spec sections: S11 (Plugin Version), S12 (Thinking Level), S13 (Documentation)

### Task 6.1: Bump plugin version to 0.1.1
- **Files**: `.claude-plugin/plugin.json`
- **Spec items**: C17
- **Depends on**: Phase 5

- [ ] **Step 1: Update version in plugin.json**
  Change line 4 of `.claude-plugin/plugin.json`:
  ```json
  "version": "0.1.1",
  ```

- [ ] **Step 2: Verify**
  ```bash
  grep '"version"' /Users/skywrace/Documents/github.com/JWWon/robro/.claude-plugin/plugin.json
  # Should show "version": "0.1.1"
  ```

### Task 6.2: Document thinking level limitation
- **Files**: `CLAUDE.md` (root)
- **Spec items**: C20
- **Depends on**: Phase 1

- [ ] **Step 1: Add thinking level note**
  In `CLAUDE.md` (root), find the "Key Concepts" section or a suitable location near the model config documentation. Add:

  ```markdown
  ### Known Limitations

  - **Thinking level control**: The Claude Code Agent tool only exposes a `model` parameter (haiku/sonnet/opus). There is no thinking level or thinking budget parameter. Model selection is the only available compute control for agent dispatch. This is a platform limitation as of 2026-03.
  ```

### Task 6.3: Update documentation with worktree workflow details
- **Files**: `CLAUDE.md` (root), `.claude/CLAUDE.md`, `README.md`
- **Spec items**: C21, C22, C23, C24
- **Depends on**: Phase 5

- [ ] **Step 1: Update CLAUDE.md (root) with worktree workflow**
  Add a new section after "Plan Artifacts" documenting the worktree workflow:

  ```markdown
  ### Worktree Workflow

  Each plan cycle uses a git worktree for branch isolation:

  1. `/robro:idea` works on **main** (creates `docs/plans/{slug}/`, makes no commits)
  2. `/robro:plan` creates a worktree at `.claude/worktrees/{slug}/` via `EnterWorktree`, copies plan files, and works on branch `plan/{slug}`
  3. `/robro:do` works inside the worktree, commits freely to the plan branch
  4. Converge phase: after all gates pass, user approves squash merge to main

  Result: exactly one squash-merge commit per plan cycle on main. Clean git history.

  Cross-session resume: If a session starts from main while a worktree is active, `session-start.sh` detects it and prompts `EnterWorktree(name: "{slug}")`.
  ```

  Also add a brief note about model-config.yaml:
  ```markdown
  ### Model Configuration

  `model-config.yaml` at plugin root defines 3 complexity tiers (light/standard/complex) mapping agent roles to models (haiku/sonnet/opus). The do skill reads complexity from spec.yaml and dispatches agents with the appropriate model.
  ```

- [ ] **Step 2: Update .claude/CLAUDE.md with worktree and model references**
  Add the same worktree workflow summary to the `.claude/CLAUDE.md` template file. Update the hooks table to mention worktree detection in SessionStart.

- [ ] **Step 3: Update README.md**
  In the "Pipeline" section, add a note about clean git history:
  ```markdown
  Each plan cycle produces exactly **one squash-merge commit** on main, thanks to git worktree isolation. All intermediate work happens on a `plan/{slug}` branch in a dedicated worktree.
  ```

  In the "How It Works" section, add a brief "Worktree isolation" subsection:
  ```markdown
  ### Worktree isolation

  Plan and build work happens in an isolated git worktree (`.claude/worktrees/{slug}/`), keeping your main branch clean. When the build converges, you approve a squash merge that produces a single commit on main.
  ```

  Update the "Skills" table to reflect the new names (already done in Phase 1, but verify the descriptions now mention worktree behavior).

- [ ] **Step 4: Add versioning note to CLAUDE.md**
  In the root CLAUDE.md, add a brief note in the Plugin Configuration section:

  ```markdown
  ### Versioning

  Version follows semver in `.claude-plugin/plugin.json`. Bump the version when releasing changes to installed users. Current: 0.1.1.
  ```

- [ ] **Step 5: Commit all documentation updates**
  ```bash
  cd /Users/skywrace/Documents/github.com/JWWon/robro
  git add CLAUDE.md .claude/CLAUDE.md README.md .claude-plugin/plugin.json
  git commit -m "docs: update all docs with worktree workflow, model config, version 0.1.1

  - Document worktree lifecycle in CLAUDE.md, .claude/CLAUDE.md, README.md
  - Document model-config.yaml and complexity tiers
  - Document thinking level limitation (platform constraint)
  - Add versioning note
  - Bump plugin version to 0.1.1"
  ```

---

## Pre-mortem

| Failure Scenario | Likelihood | Impact | Mitigation |
|---|---|---|---|
| EnterWorktree cannot re-enter an existing worktree from a previous session | Medium | High | session-start.sh already instructs to use EnterWorktree. If it fails, fall back to `cd` to the worktree path. Document both approaches in the plan skill. |
| Squash merge from converge phase has conflicts | Medium | Medium | Conflicts are presented to user via AskUserQuestion (not auto-resolved). User resolves manually. This is the architect's R6 recommendation. |
| Hook scripts break because of schema changes | Low | High | Phase 4 Task 4.2 verifies all grep+sed patterns against new schema. The `sed 's/"//g'` strip is forward-compatible. |
| Agent worktree isolation (per-agent) breaks inside plan worktree | Low | Medium | Research confirmed git-level mechanics work. If Claude Code runtime places agent worktrees incorrectly, fall back to inline execution (Path A). |
| "spec this" keyword trigger removal causes usability regression | Low | Low | "plan this" already exists as a trigger. Users can also say "spec this" and get no suggestion, but they can always invoke `/robro:plan` directly. |
| Clean-memory removal leaves no way to clean up old plans | Low | Low | Users can manually `rm -rf docs/plans/{name}/`. The worktree lifecycle handles cleanup for new plans. Old plans stay as-is (accepted clean break). |
| Plugin version bump breaks existing installations | Low | Low | Pre-1.0 plugin. No backward compatibility guarantees. Users re-run `/robro:setup` to get updated CLAUDE.md sections. |
| Rename misses a reference somewhere | Medium | Medium | Verification steps (grep for old names) at the end of each task catch missed references. The atomic commit approach means no inconsistent intermediate state. |

## Open Questions

1. **EnterWorktree re-entry behavior**: Can `EnterWorktree(name: "existing-slug")` resume a worktree from a previous session? The tool description says it "creates" a worktree. If it fails for existing worktrees, `cd` is the fallback. Must be tested during implementation.

2. **Agent `isolation: "worktree"` inside plan worktrees**: Git-level mechanics are confirmed working (research/15), but the Claude Code runtime behavior has not been tested in a live session. If agent worktrees fail inside plan worktrees, fall back to inline execution.

3. **CWD cache reset without EnterWorktree**: If the fallback `cd` approach is needed for cross-session resume, Claude Code's system prompt sections and memory files may not fully update. Severity unknown.

4. **Complexity assessment accuracy**: The plan skill estimates complexity (light/standard/complex). If it over- or under-estimates, agent models are suboptimal. Mitigation: the do skill can override at Brief phase if evidence suggests a different tier.

5. **idea.md complexity field**: The idea skill currently does not write a `complexity` field to idea.md frontmatter. The plan skill must infer it or the idea skill must be updated. This plan assumes the plan skill infers complexity and writes it to spec.yaml -- no idea skill changes needed.
