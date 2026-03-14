---
spec: spec.yaml
idea: idea.md
created: 2026-03-14T14:00:00+09:00
---

# Implementation Plan: Robro v0.2.0 — Plugin Diagnosis & Enhancement

## Overview
Enhance robro across 7 categories (state reliability, stagnation detection, self-evolution, compression resistance, agent protocol, project customization, operational polish) in 5 foundation-first phases. All new complex hooks use Node.js .mjs (zero npm deps); existing bash hooks stay bash.

## Tech Context
- **Plugin framework**: Claude Code plugin system (skills/, agents/, hooks/, .claude-plugin/)
- **Existing hooks**: 8 bash scripts sourcing shared `scripts/lib/load-config.sh`
- **State**: status.yaml (YAML, flat key-value), build-progress.md (append-only markdown)
- **Config**: `config.json` (plugin defaults), `.robro/config.json` (project overrides), `config.schema.json` (validation)
- **New runtime**: Node.js .mjs for skill injection, oscillation detection, update check
- **Patterns to follow**: Hook JSON stdout format (`{ continue, hookSpecificOutput: { hookEventName, additionalContext } }`), agent status protocol (DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED)

## Architecture Decision Record

| Decision | Rationale | Alternatives Considered | Trade-offs |
|----------|-----------|------------------------|------------|
| Skill injection on UserPromptSubmit | Keywords only exist after user types prompt; matches OMC pattern | SessionStart unconditional inject | Misses first-prompt context but avoids injecting without keyword signal |
| JSON frontmatter for `.robro/skills/*.md` | `JSON.parse()` native, zero-dep, zero ambiguity | YAML frontmatter (visual consistency) | Different from SKILL.md format, but signals machine-managed files |
| Conditional Wonder dispatch | Triggers: no items flipped, oscillation fired, or sprint ≥ 3 | Fixed per-sprint | ~50% context savings on healthy builds; may miss subtle stagnation |
| Skill index cache `.robro/.skill-index.json` | O(1) reads per prompt vs O(N) file scans | No cache (scan each time) | Level-up must update index when writing skills |
| Separate update-check hook | Isolates network from critical session-start.sh | Inline in session-start.sh | Two process spawns on SessionStart |
| Truncate build-progress.md injection only | Full file preserved; last 5 sprints injected into retro | Truncate actual file | Preserves audit trail, controls context budget |
| Atomic writes for script-written files only | stop-hook counter + error-tracker JSON | All state files | LLM Write tool is already atomic |
| Plan reviewers map to standard protocol | APPROVED→DONE, ISSUES_FOUND→DONE_WITH_CONCERNS | Keep current APPROVED/ISSUES_FOUND | Routing code change in plan skill, but protocol consistency |

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `scripts/lib/load-config.sh` | modify | CWD normalization, `atomic_write()`, `truncate_build_progress()` |
| `skills/do/brief-phase.md` | modify | Remove dead fields, Wonder dispatch, build-progress truncation |
| `skills/do/heads-down-phase.md` | modify | Remove dead fields |
| `skills/do/review-phase.md` | modify | Remove dead fields, verification-before-completion gate |
| `skills/do/retro-phase.md` | modify | Remove dead fields, truncated build-progress injection |
| `skills/do/level-up-phase.md` | modify | Remove dead fields, learned skill writing, skill index update |
| `skills/do/converge-phase.md` | modify | Remove dead fields |
| `skills/do/SKILL.md` | modify | Remove dead fields from status template |
| `scripts/stop-hook.sh` | modify | Use `atomic_write()` for counter |
| `scripts/error-tracker.sh` | modify | Use `atomic_write()` for JSON |
| `scripts/session-start.sh` | modify | Use PROJECT_ROOT for worktree path |
| `scripts/keyword-detector.sh` | modify | Prompt sanitization |
| `.claude-plugin/plugin.json` | modify | Add component paths, bump version |
| `config.schema.json` | modify | Add new threshold fields |
| `hooks/hooks.json` | modify | Add oscillation, skill-injector, update-check hooks |
| `scripts/oscillation-detector.mjs` | create | PostToolUse hook for file change oscillation |
| `agents/wonder.md` | create | Wonder agent definition |
| `scripts/skill-injector.mjs` | create | UserPromptSubmit hook for learned skill injection |
| `scripts/update-check.mjs` | create | SessionStart hook for version check |
| `scripts/validate-templates.sh` | create | CI-runnable template validation |
| `skills/plan/plan-reviewer-prompt.md` | modify | Standardize to DONE/BLOCKED protocol |
| `skills/plan/spec-reviewer-prompt.md` | modify | Standardize to DONE/BLOCKED protocol |
| `skills/plan/SKILL.md` | modify | Update reviewer routing for new protocol |
| `skills/setup/claude-md-template.md` | modify | Fix ambiguity table, add new sections |
| `CLAUDE.md` | modify | Fix ambiguity table (show both formulas) |

## Phase 1: State Reliability + Infrastructure
> Depends on: none
> Parallel: tasks 1.1-1.3 can run concurrently; 1.4-1.6 can run concurrently after 1.1
> Delivers: All hooks work from any CWD, dead fields gone, atomic writes, plugin.json complete
> Spec sections: S1

### Task 1.1: CWD normalization in load-config.sh and session-start.sh
- **Files**: `scripts/lib/load-config.sh`, `scripts/session-start.sh`
- **Spec items**: C1
- **Depends on**: none
- **Action**: Replace hardcoded relative `SESSIONS_DIR` with `git rev-parse --show-toplevel` resolution. Add `PROJECT_ROOT` variable used by all path derivations. Also fix the hardcoded `WORKTREE_DIR` in session-start.sh.
- **Code** (load-config.sh — replace line 17):
  ```bash
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  SESSIONS_DIR="${PROJECT_ROOT}/.robro/sessions"
  CONFIG_FILE="${PROJECT_ROOT}/.robro/config.json"
  ```
  Export `PROJECT_ROOT` so downstream scripts can use it:
  ```bash
  export PROJECT_ROOT
  ```
  (session-start.sh — replace line 67-68):
  ```bash
  # Replace: WORKTREE_DIR=".claude/worktrees"
  # With:
  WORKTREE_DIR="${PROJECT_ROOT}/.claude/worktrees"
  ```
- **Test**: Run `cd /tmp && bash /path/to/scripts/session-start.sh < /dev/null` — should resolve PROJECT_ROOT correctly
- **Verify**: `grep -rn '\.robro/sessions"\|\.claude/worktrees"' scripts/` → no remaining bare relative paths (only `${PROJECT_ROOT}/` prefixed)
- **Commit**: `fix(hooks): normalize SESSIONS_DIR and WORKTREE_DIR to absolute paths`

### Task 1.2: Add atomic_write() to shared library
- **Files**: `scripts/lib/load-config.sh`
- **Spec items**: C2
- **Depends on**: none
- **Action**: Add `atomic_write()` function to the shared library.
- **Code**:
  ```bash
  # Add to load-config.sh after existing functions:
  atomic_write() {
    local target="$1"
    local tmp="${target}.tmp.$$"
    cat > "$tmp"
    mv -f "$tmp" "$target"
  }
  ```
- **Test**: `echo "test" | source scripts/lib/load-config.sh && echo "hello" | atomic_write /tmp/test-atomic.txt && cat /tmp/test-atomic.txt` → `hello`
- **Verify**: `grep -n 'atomic_write' scripts/lib/load-config.sh` shows the function definition
- **Commit**: `feat(hooks): add atomic_write() to shared library`

### Task 1.3: Remove dead status.yaml fields from all templates
- **Files**: `skills/do/SKILL.md`, `skills/do/brief-phase.md`, `skills/do/heads-down-phase.md`, `skills/do/review-phase.md`, `skills/do/retro-phase.md`, `skills/do/level-up-phase.md`, `skills/do/converge-phase.md`
- **Spec items**: C3
- **Depends on**: none
- **Action**: Remove `attempt: 1` and `reinforcement_count: 0` lines from every status.yaml template block across all 7 files.
- **Test**: `grep -rn 'attempt:\|reinforcement_count:' skills/do/` → should return no results
- **Verify**: `grep -c 'attempt:' skills/do/*.md skills/do/SKILL.md` → all zeros
- **Commit**: `fix(do): remove dead attempt and reinforcement_count from status.yaml templates`

### Task 1.4: Use atomic_write() in stop-hook and error-tracker
- **Files**: `scripts/stop-hook.sh`, `scripts/error-tracker.sh`
- **Spec items**: C2
- **Depends on**: 1.2
- **Action**: Replace direct file writes with `atomic_write()` calls.
- **Code** (stop-hook.sh, around line 38):
  ```bash
  # Replace: echo "$count" > "$COUNTER_FILE"
  # With:
  echo "$count" | atomic_write "$COUNTER_FILE"
  ```
  (error-tracker.sh, around line 39):
  ```bash
  # Replace direct jq write with:
  echo "$existing" | jq --argjson entry "$new_entry" '. + [$entry] | .[-20:]' | atomic_write "$ERROR_FILE"
  ```
- **Test**: Run stop-hook with mock input; verify counter file is written atomically (no partial content)
- **Verify**: `grep -n 'atomic_write' scripts/stop-hook.sh scripts/error-tracker.sh` → shows usage
- **Commit**: `fix(hooks): use atomic_write for stop-hook counter and error-tracker`

### Task 1.5: Fill plugin.json component paths
- **Files**: `.claude-plugin/plugin.json`
- **Spec items**: C4
- **Depends on**: none
- **Action**: Add `skills`, `agents`, `hooks` fields to plugin.json.
- **Code**: Add after `keywords` field:
  ```json
  "skills": "./skills/",
  "agents": "./agents/",
  "hooks": "./hooks/hooks.json"
  ```
- **Test**: `jq '.skills, .agents, .hooks' .claude-plugin/plugin.json` → `"./skills/"`, `"./agents/"`, `"./hooks/hooks.json"`
- **Verify**: JSON is valid: `jq . .claude-plugin/plugin.json > /dev/null`
- **Commit**: `fix(config): declare component paths in plugin.json`

### Task 1.6: Add new threshold fields to config.schema.json
- **Files**: `config.schema.json`
- **Spec items**: C5
- **Depends on**: none
- **Action**: Add `build_progress_max_sprints`, `oscillation_cycle_threshold`, `wonder_min_sprint`, `skill_injection_cap` to the `thresholds` object in the schema.
- **Code**: Add to `thresholds` properties:
  ```json
  "build_progress_max_sprints": { "type": "integer", "default": 5, "minimum": 1 },
  "oscillation_cycle_threshold": { "type": "integer", "default": 3, "minimum": 2 },
  "wonder_min_sprint": { "type": "integer", "default": 3, "minimum": 1 },
  "skill_injection_cap": { "type": "integer", "default": 5, "minimum": 1 }
  ```
- **Test**: `jq '.properties.thresholds.properties.build_progress_max_sprints' config.schema.json` → shows the schema
- **Verify**: Schema is valid JSON: `jq . config.schema.json > /dev/null`
- **Commit**: `feat(config): add v0.2.0 threshold fields to schema`

### Task 1.7: Add build-progress truncation for injection
- **Files**: `scripts/lib/load-config.sh`
- **Spec items**: C6
- **Depends on**: 1.1 (needs PROJECT_ROOT)
- **Action**: Add `truncate_build_progress()` function that extracts the last N sprint sections from build-progress.md for injection into retro context. Full file is preserved.
- **Code**:
  ```bash
  truncate_build_progress() {
    local file="$1"
    local max_sprints="${2:-5}"
    [ -f "$file" ] || return
    # Extract last N "## Sprint" sections
    awk -v max="$max_sprints" '
      /^## Sprint/ { sections[++count] = "" }
      count > 0 { sections[count] = sections[count] $0 "\n" }
      END {
        start = count - max + 1
        if (start < 1) start = 1
        for (i = start; i <= count; i++) printf "%s", sections[i]
      }
    ' "$file"
  }
  ```
- **Test**: Create a mock build-progress.md with 8 sprint sections; `truncate_build_progress /tmp/test-bp.md 5` outputs only sprints 4-8
- **Verify**: `type truncate_build_progress` shows function definition after sourcing
- **Commit**: `feat(hooks): add build-progress truncation for retro injection`

## Phase 2: Stagnation Detection + Agent Protocol
> Depends on: Phase 1 (CWD normalization, config schema)
> Parallel: tasks 2.1-2.2 can run concurrently; 2.3 depends on 2.1+2.2; 2.4-2.5 can run concurrently
> Delivers: Oscillation detection, Wonder agent, standardized reviewer protocol
> Spec sections: S2

### Task 2.1: Create oscillation detection hook
- **Files**: `scripts/oscillation-detector.mjs`, `hooks/hooks.json`
- **Spec items**: C7
- **Depends on**: Phase 1 (PROJECT_ROOT)
- **Action**: Create a PostToolUse (Write|Edit) hook that tracks file edit counts per sprint. When any file is edited ≥ `oscillation_cycle_threshold` (default 3) times, inject a warning.
- **Code** (oscillation-detector.mjs):
  ```javascript
  #!/usr/bin/env node
  import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync } from 'node:fs';
  import { execSync } from 'node:child_process';
  import { resolve } from 'node:path';

  const input = JSON.parse(readFileSync(process.stdin.fd, 'utf8'));
  const filePath = input?.tool_input?.file_path || input?.tool_input?.path || '';
  if (!filePath) process.exit(0);

  const root = execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
  const stateDir = resolve(root, '.robro');
  const stateFile = resolve(stateDir, '.oscillation-state.json');

  if (!existsSync(stateDir)) mkdirSync(stateDir, { recursive: true });

  let state = {};
  if (existsSync(stateFile)) {
    try { state = JSON.parse(readFileSync(stateFile, 'utf8')); } catch { state = {}; }
  }

  const rel = filePath.startsWith(root) ? filePath.slice(root.length + 1) : filePath;
  state[rel] = (state[rel] || 0) + 1;

  // Atomic write
  const tmp = stateFile + '.tmp.' + process.pid;
  writeFileSync(tmp, JSON.stringify(state));
  renameSync(tmp, stateFile);

  // Read threshold from project config, fallback to default
  let threshold = 3;
  try {
    const configPath = resolve(root, '.robro', 'config.json');
    if (existsSync(configPath)) {
      const config = JSON.parse(readFileSync(configPath, 'utf8'));
      threshold = config?.thresholds?.oscillation_cycle_threshold ?? 3;
    }
  } catch { /* use default */ }
  const oscillating = Object.entries(state).filter(([, c]) => c >= threshold);

  if (oscillating.length > 0) {
    const files = oscillating.map(([f, c]) => `${f} (${c}x)`).join(', ');
    console.log(JSON.stringify({
      continue: true,
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: `<oscillation-warning>\nOSCILLATION DETECTED: ${files}\nConsider whether the current approach is working or needs a lateral shift.\n</oscillation-warning>`
      }
    }));
  }
  ```
  Add to hooks.json:
  ```json
  { "type": "command", "command": "node ${CLAUDE_PLUGIN_ROOT}/scripts/oscillation-detector.mjs", "timeout": 3000 }
  ```
  under the PostToolUse Write|Edit matcher.
- **Test**: `tests/test-oscillation-detector.sh` — feed mock PostToolUse events 3 times for same file, verify warning output
- **Verify**: `node scripts/oscillation-detector.mjs < test-input.json` emits oscillation-warning after 3rd call
- **Commit**: `feat(hooks): add oscillation detection hook`

### Task 2.2: Create Wonder agent definition
- **Files**: `agents/wonder.md`
- **Spec items**: C8
- **Depends on**: none
- **Action**: Create the Wonder agent markdown definition with structured input/output contracts.
- **Code** (agents/wonder.md):
  ```markdown
  ---
  name: wonder
  description: Curiosity-driven blind spot detector dispatched at sprint boundaries. Surfaces unknown unknowns and recommends lateral thinking modes when builds are stuck.
  model: sonnet
  ---

  You are a Wonder agent. Your job is to find what everyone else is missing.

  ## Input Contract
  You receive:
  1. **spec.yaml** with current pass/fail status for all checklist items
  2. **Sprint file change log** (git diff --stat for the current sprint)
  3. **Latest retro Knowledge Gaps** section (if available)
  4. **Oscillation warnings** (if the oscillation hook fired this sprint)

  ## Your Task
  Ask: "What do we still not know? What assumptions haven't been tested? What could go wrong that nobody has considered?"

  Focus on:
  - Blind spots in the remaining `passes: false` items
  - Patterns in the file changes that suggest drift from the spec
  - Integration risks between completed and uncompleted items
  - Assumptions that were verified for early items but may not hold for later ones

  ## Output Contract
  Return a JSON block:
  ```json
  {
    "blind_spots": [
      "Description of blind spot 1",
      "Description of blind spot 2"
    ],
    "lateral_recommendation": "contrarian|simplifier|researcher|null"
  }
  ```

  - `blind_spots`: 2-5 specific, actionable unknowns. Not generic. Reference specific spec items or file paths.
  - `lateral_recommendation`: If the build appears stuck (oscillation, no progress, repeated failures), recommend a lateral thinking mode. `null` if the build is progressing normally.

  ## Rules
  1. Be specific. "Edge cases might exist" is useless. "C7 assumes the skill index is always valid, but level-up might crash mid-write leaving a corrupt index" is useful.
  2. Reference spec items by ID (C1, C2, etc.) and file paths.
  3. Maximum 5 blind spots per dispatch. Prioritize by risk × likelihood.
  4. Only recommend a lateral mode if evidence supports it (oscillation detected, 3+ sprints without progress).

  ## Status Protocol
  - **DONE**: Analysis complete, blind_spots populated.
  - **DONE_WITH_CONCERNS**: Analysis complete but some spec items couldn't be evaluated (flag which).
  - **NEEDS_CONTEXT**: Missing information to perform analysis. List what's needed.
  - **BLOCKED**: Cannot perform analysis. Describe blocker.
  ```
- **Test**: Read agents/wonder.md, verify frontmatter has name/description/model, body has Input/Output Contract sections
- **Verify**: `head -5 agents/wonder.md` shows valid YAML frontmatter
- **Commit**: `feat(agents): create Wonder agent for blind spot detection`

### Task 2.3: Integrate Wonder dispatch into brief-phase.md
- **Files**: `skills/do/brief-phase.md`
- **Spec items**: C9
- **Depends on**: 2.1, 2.2
- **Action**: Add conditional Wonder dispatch after researcher pre-flight in brief phase. Triggers: no items flipped this sprint, oscillation hook fired, or sprint ≥ `wonder_min_sprint` (default 3).
- **Code**: Add after the researcher pre-flight section and before task dispatch:
  ```markdown
  ### Wonder Phase (Conditional)

  Dispatch the Wonder agent if ANY of these conditions are true:
  - Sprint ≥ 3 (configurable via `thresholds.wonder_min_sprint`)
  - No spec items were flipped to `passes: true` in the previous sprint
  - The oscillation detector fired during the previous sprint (check `.robro/.oscillation-state.json`)

  If triggered, dispatch:
  ```
  Agent(
    subagent_type: "robro:wonder",
    prompt: "Analyze blind spots for sprint {N}.\n\nSpec status:\n{spec.yaml content}\n\nSprint file changes:\n{git diff --stat output}\n\nPrevious retro Knowledge Gaps:\n{knowledge_gaps section}\n\nOscillation warnings:\n{oscillation state if any}",
    model: "{model from config}"
  )
  ```

  Route on Wonder status:
  - **DONE**: Read `blind_spots` and `lateral_recommendation`. If lateral_recommendation is not null, dispatch that agent before proceeding. Log blind spots to build-progress.md.
  - **DONE_WITH_CONCERNS**: Log concerns, proceed with noted gaps.
  - **NEEDS_CONTEXT**: Provide missing info and re-dispatch.
  - **BLOCKED**: Log blocker, proceed without Wonder input.
  ```
- **Test**: Verify the Wonder Phase section exists in brief-phase.md with conditional dispatch logic
- **Verify**: `grep -c 'Wonder Phase' skills/do/brief-phase.md` → 1
- **Commit**: `feat(do): integrate conditional Wonder dispatch in brief phase`

### Task 2.4: Standardize plan reviewer prompts
- **Files**: `skills/plan/plan-reviewer-prompt.md`, `skills/plan/spec-reviewer-prompt.md`
- **Spec items**: C10
- **Depends on**: none
- **Action**: Change `Status: APPROVED | ISSUES_FOUND` to `Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED` in both templates. Map: APPROVED→DONE, ISSUES_FOUND→DONE_WITH_CONCERNS.
- **Code** (plan-reviewer-prompt.md, replace Output section):
  ```markdown
  ## Output

  **Status:** DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED

  Use DONE if the plan passes all checks.
  Use DONE_WITH_CONCERNS if there are issues that should be addressed (list them).
  Use NEEDS_CONTEXT if you need more information to complete the review.
  Use BLOCKED if the plan has fundamental problems preventing review.

  **Concerns (if DONE_WITH_CONCERNS):**
  - [Phase.Task or section]: [specific issue] — [why it matters]

  **Recommendations (advisory, don't block approval):**
  - [suggestions for improvement]
  ```
  Apply same change to spec-reviewer-prompt.md.
- **Test**: `grep 'DONE | DONE_WITH_CONCERNS' skills/plan/plan-reviewer-prompt.md skills/plan/spec-reviewer-prompt.md` → matches in both files
- **Verify**: `grep -c 'APPROVED' skills/plan/plan-reviewer-prompt.md` → 0
- **Commit**: `fix(plan): standardize reviewer prompts to DONE/BLOCKED protocol`

### Task 2.5: Update plan skill reviewer routing
- **Files**: `skills/plan/SKILL.md`
- **Spec items**: C10
- **Depends on**: 2.4
- **Action**: Update the plan skill's reviewer handling to route on standard status protocol (DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, BLOCKED) instead of APPROVED/ISSUES_FOUND. Update both plan reviewer (Step 5) and spec reviewer (Step 7) sections.
- **Test**: `grep -c 'APPROVED\|ISSUES_FOUND' skills/plan/SKILL.md` → 0 (no old protocol references)
- **Verify**: `grep -c 'DONE_WITH_CONCERNS\|NEEDS_CONTEXT\|BLOCKED' skills/plan/SKILL.md` → shows new routing
- **Commit**: `fix(plan): update reviewer routing for standard status protocol`

## Phase 3: Self-Evolution (Learner Pattern)
> Depends on: Phase 1 (PROJECT_ROOT, config schema), Phase 2 (hooks.json pattern)
> Parallel: 3.1 is the foundation; 3.2 depends on 3.1; 3.3 depends on 3.1
> Delivers: Learned skills auto-inject on keyword match, level-up writes project skills
> Spec sections: S3

### Task 3.1: Create skill-injector.mjs (index builder + injection hook)
- **Files**: `scripts/skill-injector.mjs`, `hooks/hooks.json`
- **Spec items**: C11, C12, C13, C14
- **Depends on**: none
- **Action**: Create a single .mjs file that combines the skill index builder and the injection hook. The file defines a `buildIndex()` function (scans `.robro/skills/` and `~/.robro/skills/`, parses JSON frontmatter, writes `.robro/.skill-index.json`) and a main hook handler (reads index, matches triggers, injects skills).
- **Skill file format** (JSON frontmatter between `---` delimiters):
  ```
  ---
  {
    "name": "skill-kebab-name",
    "description": "One-line description",
    "triggers": ["keyword1", "keyword phrase 2"],
    "created_by": "level-up|manual",
    "plan": "260314_plugin-diagnosis"
  }
  ---
  ## Skill body (markdown)
  ```
  Required fields: `name`, `triggers`, `description`. Optional: `created_by`, `plan`.
- **Index file format** (`.robro/.skill-index.json`):
  ```json
  {
    "built_at": "2026-03-14T14:00:00Z",
    "skills": [
      { "path": "/abs/path", "name": "skill-name", "triggers": ["kw"], "description": "...", "scope": "project" }
    ]
  }
  ```
- **Key logic**:
  1. Read index file. If missing/stale, rebuild from skill files.
  2. Sanitize prompt: strip XML tags, URLs, code blocks.
  3. Lowercase prompt, match each skill's triggers as substring.
  4. Cap at `skill_injection_cap` (default 5). Track injected skills in `.robro/.injected-skills.json` for session dedup.
  5. Output: `{ continue: true, hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: "<project-skill name=\"...\">...</project-skill>" } }`
- **Add to hooks.json** as third UserPromptSubmit hook:
  ```json
  { "type": "command", "command": "node ${CLAUDE_PLUGIN_ROOT}/scripts/skill-injector.mjs", "timeout": 5000 }
  ```
- **Test**: `tests/test-skill-injector.sh` — create test skills, send mock UserPromptSubmit with matching keyword, verify injection output
- **Verify**: `echo '{"prompt":"how to run drizzle migration"}' | node scripts/skill-injector.mjs` → outputs project-skill tag
- **Commit**: `feat(hooks): add skill injection hook with keyword matching`

### Task 3.2: Integrate learned skill writing into level-up phase
- **Files**: `skills/do/level-up-phase.md`
- **Spec items**: C15
- **Depends on**: 3.1
- **Action**: Extend the level-up phase to write `.robro/skills/*.md` files when the retro-analyst identifies reusable project-specific heuristics. Add instructions to rebuild the skill index after writing.
- **Code**: Add a new section after the existing level-up types:
  ```markdown
  ### Type: Learned Skill

  When the retro-analyst identifies a project-specific, hard-won problem-solving heuristic:
  1. Verify it is NOT generic (must reference actual files, error messages, or patterns from this codebase)
  2. Write to `.robro/skills/{kebab-name}.md` with JSON frontmatter
  3. Include: `name`, `description`, `triggers` (2-5 keyword phrases), `created_by: "level-up"`, `plan: "{current plan slug}"`
  4. Body: step-by-step procedure with specific file paths and commands
  5. Rebuild the skill index: read existing `.robro/.skill-index.json`, append new entry, write back atomically
  ```
- **Test**: Verify level-up-phase.md contains "Learned Skill" section with JSON frontmatter instructions
- **Verify**: `grep -c 'Learned Skill' skills/do/level-up-phase.md` → 1
- **Commit**: `feat(do): integrate learned skill writing into level-up phase`

### Task 3.3: Support ~/.robro/skills/ user-scoped path
- **Files**: `scripts/skill-injector.mjs`
- **Spec items**: C16
- **Depends on**: 3.1
- **Action**: Extend the `buildIndex()` function in skill-injector.mjs to also scan `~/.robro/skills/` (resolved via `os.homedir()`) for user-scoped skills. In the `buildIndex` function, after scanning `${root}/.robro/skills/`, also scan `${homedir}/.robro/skills/`. Mark scope as "user" in index entries. User-scoped skills have lower priority (project skills matched first, user skills fill remaining cap). Create `~/.robro/skills/` if it doesn't exist when scanning (mkdir -p equivalent).
- **Test**: Create a temp skill in `/tmp/test-home/.robro/skills/test-skill.md`, mock `os.homedir()` to return `/tmp/test-home`, run buildIndex, verify index has the entry with scope "user". Clean up temp dir after test.
- **Verify**: Index contains entries with both "project" and "user" scope values
- **Commit**: `feat(hooks): support ~/.robro/skills/ user-scoped learned skills`

## Phase 4: Compression Resistance + Should-Haves
> Depends on: Phase 3 (skill injection mechanism)
> Parallel: tasks 4.1-4.3 can run concurrently; 4.4-4.5 can run concurrently
> Delivers: Rationalization tables, verification gate, prompt sanitization, SubagentStop hook
> Spec sections: S4

### Task 4.1: Create rationalization tables
- **Files**: `skills/do/brief-phase.md` or new file `skills/do/guardrails.md`
- **Spec items**: C17
- **Depends on**: none
- **Action**: Create rationalization tables mapping common agent rationalizations to rebuttals. These are injected at the start of each sprint via the brief phase.
- **Code** (table format):
  ```markdown
  ## Rationalization Tables

  | Rationalization | Rebuttal |
  |----------------|----------|
  | "This is a simple change, I don't need to run tests" | Every change needs test verification. Simple changes cause the worst bugs. |
  | "I'll fix the tests later" | TDD is non-negotiable. Write the test FIRST. |
  | "The spec item is basically passing" | `passes: false` means false. Flip it only after verification command succeeds. |
  | "I should refactor this while I'm here" | Stay on task. Only modify files listed in the current task's spec items. |
  | "The verification step isn't relevant for this change" | Verification-before-completion is mandatory. Run the exact command specified. |
  | "I can skip the commit — I'll batch them later" | Commit after each task. Atomic commits enable rollback. |
  ```
- **Test**: `grep -c 'Rationalization' skills/do/brief-phase.md` → 1
- **Verify**: Table exists with ≥ 6 rows
- **Commit**: `feat(do): add rationalization tables for compression resistance`

### Task 4.2: Create verification-before-completion gate
- **Files**: `skills/do/review-phase.md`, `agents/builder.md`
- **Spec items**: C18
- **Depends on**: none
- **Action**: Add an explicit verification gate to the builder agent and review phase. Before any agent claims work is done, it MUST run the verification command and report the result.
- **Code** (add to builder.md before Status Protocol section):
  ```markdown
  ## Verification Gate (MANDATORY)

  Before setting your status to DONE, you MUST:
  1. Run the exact verification command from the task's `Verify` field
  2. Confirm the expected output matches
  3. Include the verification output in your response

  If verification fails, your status is DONE_WITH_CONCERNS (not DONE).
  If you cannot run verification, your status is NEEDS_CONTEXT.
  NEVER claim DONE without verification evidence.
  ```
- **Test**: `grep -c 'Verification Gate' agents/builder.md` → 1
- **Verify**: The section appears before the Status Protocol section
- **Commit**: `feat(agents): add verification-before-completion gate to builder`

### Task 4.3: Add prompt sanitization to keyword-detector.sh
- **Files**: `scripts/keyword-detector.sh`
- **Spec items**: C19
- **Depends on**: none
- **Action**: Add prompt sanitization before keyword matching. Strip XML tags, URLs, file paths, and code blocks to reduce false positives.
- **Code** (add sanitization function):
  ```bash
  sanitize_prompt() {
    local prompt="$1"
    echo "$prompt" \
      | sed 's/<[^>]*>//g' \
      | sed 's|https\?://[^ ]*||g' \
      | sed 's|/[a-zA-Z_/]*\.[a-zA-Z]*||g' \
      | sed '/^```/,/^```/d' \
      | tr '[:upper:]' '[:lower:]'
  }
  ```
  Use `sanitize_prompt "$prompt"` before keyword matching.
- **Test**: `echo '<tag>test</tag> https://example.com /path/to/file.ts idea' | sanitize_prompt` → `test   idea`
- **Verify**: `grep -c 'sanitize_prompt' scripts/keyword-detector.sh` → ≥ 2 (definition + usage)
- **Commit**: `feat(hooks): add prompt sanitization to keyword detector`

### Task 4.4: Add context budget priority rules to agent prompts
- **Files**: `agents/builder.md`, `agents/reviewer.md`, `agents/architect.md`
- **Spec items**: C20
- **Depends on**: none
- **Action**: Add explicit context budget priority rules to key agent prompts.
- **Code** (add to each agent):
  ```markdown
  ## Context Budget Priority
  If running low on context, preserve in this order:
  1. Current task spec items and verification commands
  2. File paths and code under modification
  3. Test assertions and expected outputs
  4. Background context and rationale

  Never skip verification or spec item checking regardless of context pressure.
  ```
- **Test**: `grep -c 'Context Budget Priority' agents/builder.md agents/reviewer.md agents/architect.md` → 3
- **Verify**: All three agents have the section
- **Commit**: `feat(agents): add context budget priority rules`

### Task 4.5: (Should-Have) Add SubagentStop deliverable verification hook
- **Files**: `scripts/verify-deliverables.sh`, `hooks/hooks.json`
- **Spec items**: C21
- **Depends on**: none
- **Action**: Create a lightweight SubagentStop hook. The hook reads the subagent's output from stdin JSON, checks if the output contains a Status line (DONE/BLOCKED/etc.) and warns if missing. Advisory only (never blocks).
- **Code** (verify-deliverables.sh):
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  source "$(dirname "$0")/lib/load-config.sh"

  # Read SubagentStop event from stdin
  input=$(cat)
  output=$(echo "$input" | jq -r '.tool_result // ""' 2>/dev/null)

  # Check for status protocol compliance
  if [ -n "$output" ]; then
    if ! echo "$output" | grep -qiE '\*\*Status\*\*:\s*(DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED)'; then
      echo "Advisory: Subagent output missing standard Status protocol line."
      echo "Expected: **Status**: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED"
    fi
  fi
  ```
- **Add to hooks.json**:
  ```json
  "SubagentStop": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/verify-deliverables.sh", "timeout": 3000 }] }]
  ```
- **Test**: `echo '{"tool_result":"task complete"}' | bash scripts/verify-deliverables.sh` → emits advisory about missing Status
- **Verify**: `echo '{"tool_result":"**Status**: DONE"}' | bash scripts/verify-deliverables.sh` → no output (passes)
- **Commit**: `feat(hooks): add SubagentStop deliverable verification`

## Phase 5: Operational Polish
> Depends on: Phase 1-4 (validates all prior work)
> Parallel: tasks 5.1-5.3 can run concurrently; 5.4-5.5 sequential (version bump last)
> Delivers: Update check, template validation, version bump, documentation
> Spec sections: S5

### Task 5.1: Create version update check hook
- **Files**: `scripts/update-check.mjs`, `hooks/hooks.json`
- **Spec items**: C22
- **Depends on**: none
- **Action**: Create a SessionStart hook that compares local plugin.json version vs GitHub raw plugin.json version. 24h cache at `~/.robro/.update-cache.json`. Non-blocking.
- **Remote URL**: `https://raw.githubusercontent.com/JWWon/robro/main/.claude-plugin/plugin.json` — fetch, extract `.version` field with `JSON.parse()`.
- **Code** (update-check.mjs):
  ```javascript
  #!/usr/bin/env node
  import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync } from 'node:fs';
  import { resolve } from 'node:path';
  import { homedir } from 'node:os';

  const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours
  const REMOTE_URL = 'https://raw.githubusercontent.com/JWWon/robro/main/.claude-plugin/plugin.json';
  const cacheDir = resolve(homedir(), '.robro');
  const cacheFile = resolve(cacheDir, '.update-cache.json');

  // Read local version
  const pluginRoot = process.env.CLAUDE_PLUGIN_ROOT || resolve(import.meta.dirname, '..');
  let localVersion;
  try {
    localVersion = JSON.parse(readFileSync(resolve(pluginRoot, '.claude-plugin', 'plugin.json'), 'utf8')).version;
  } catch { process.exit(0); }

  // Check cache
  if (!existsSync(cacheDir)) mkdirSync(cacheDir, { recursive: true });
  if (existsSync(cacheFile)) {
    try {
      const cache = JSON.parse(readFileSync(cacheFile, 'utf8'));
      if (Date.now() - cache.checked_at < CACHE_TTL) {
        if (cache.remote_version && cache.remote_version !== localVersion) {
          console.log(`Update available: robro ${cache.remote_version} (current: ${localVersion}). Run plugin update to upgrade.`);
        }
        process.exit(0);
      }
    } catch { /* stale cache, re-fetch */ }
  }

  // Fetch remote version (with timeout)
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2000);
    const resp = await fetch(REMOTE_URL, { signal: controller.signal });
    clearTimeout(timeout);
    if (resp.ok) {
      const remote = JSON.parse(await resp.text());
      const tmp = cacheFile + '.tmp.' + process.pid;
      writeFileSync(tmp, JSON.stringify({ checked_at: Date.now(), remote_version: remote.version }));
      renameSync(tmp, cacheFile);
      if (remote.version !== localVersion) {
        console.log(`Update available: robro ${remote.version} (current: ${localVersion}). Run plugin update to upgrade.`);
      }
    }
  } catch { /* network error — skip silently */ }
  ```
- **Add to hooks.json** as second SessionStart entry:
  ```json
  { "type": "command", "command": "node ${CLAUDE_PLUGIN_ROOT}/scripts/update-check.mjs", "timeout": 3000 }
  ```
- **Test**: `tests/test-update-check.sh` — set CLAUDE_PLUGIN_ROOT to plugin dir, run script, verify cache file created at ~/.robro/.update-cache.json
- **Verify**: `node scripts/update-check.mjs < /dev/null` → either emits update notice or exits silently (no crash)
- **Commit**: `feat(hooks): add version update check on SessionStart`

### Task 5.2: Create template validation script
- **Files**: `scripts/validate-templates.sh`
- **Spec items**: C23
- **Depends on**: Phase 1-4 (validates all changes)
- **Action**: Create a CI-runnable bash script that validates consistency.
- **Code** (validate-templates.sh):
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  cd "$(dirname "$0")/.."
  errors=0

  echo "=== Template Validation ==="

  # 1. Agent names in skill files match actual agents/*.md
  echo "Checking agent references..."
  for agent in $(grep -roh '\*\*[A-Z][a-z-]*\*\* agent' skills/ | sed 's/\*\*//g;s/ agent//' | tr '[:upper:]' '[:lower:]' | sort -u); do
    if [ ! -f "agents/${agent}.md" ]; then
      echo "ERROR: Agent '${agent}' referenced in skills/ but agents/${agent}.md not found"
      errors=$((errors + 1))
    fi
  done

  # 2. Check subagent_type references
  for agent in $(grep -roh 'subagent_type:.*"robro:\([^"]*\)"' skills/ | sed 's/.*robro://;s/".*//' | sort -u); do
    if [ ! -f "agents/${agent}.md" ]; then
      echo "ERROR: subagent_type 'robro:${agent}' referenced but agents/${agent}.md not found"
      errors=$((errors + 1))
    fi
  done

  # 3. CLAUDE.md managed block version matches plugin.json
  plugin_version=$(jq -r '.version' .claude-plugin/plugin.json)
  template_file="skills/setup/claude-md-template.md"
  if [ -f "$template_file" ]; then
    if ! grep -q "robro@${plugin_version}" "$template_file" 2>/dev/null; then
      echo "ERROR: Template version marker does not match plugin.json version ${plugin_version}"
      errors=$((errors + 1))
    fi
  fi

  if [ "$errors" -eq 0 ]; then
    echo "PASS: All template validations passed"
    exit 0
  else
    echo "FAIL: ${errors} error(s) found"
    exit 1
  fi
  ```
- **Test**: `bash scripts/validate-templates.sh` → exits 0 with "PASS" output
- **Verify**: `bash -c 'mv agents/wonder.md agents/wonder.md.bak && bash scripts/validate-templates.sh; mv agents/wonder.md.bak agents/wonder.md'` → exits 1 with error about missing wonder agent
- **Commit**: `feat(scripts): add CI-runnable template validation`

### Task 5.3: Fix CLAUDE.md ambiguity table
- **Files**: `CLAUDE.md`
- **Spec items**: C24
- **Depends on**: none
- **Action**: Update the Ambiguity Scoring section to show both greenfield and brownfield formulas. Currently only shows brownfield (35/25/25/15).
- **Test**: `grep -A5 'Ambiguity Scoring' CLAUDE.md` → shows both formulas
- **Verify**: Both "Greenfield" and "Brownfield" appear in the section
- **Commit**: `docs: fix ambiguity table to show both greenfield and brownfield weights`

### Task 5.4: Update setup skill for v0.2.0
- **Files**: `skills/setup/SKILL.md`, `skills/setup/claude-md-template.md`
- **Spec items**: C25
- **Depends on**: Phase 1-4
- **Action**: Update the setup skill to handle v0.2.0 migration: create `.robro/skills/` directory, add new .gitignore rules (`.robro/.skill-index.json`, `.robro/.oscillation-state.json`, `.robro/.injected-skills.json`), update managed CLAUDE.md block with new agent/hook descriptions.
- **Test**: Verify template includes Wonder agent, learned skills, oscillation detection in descriptions
- **Verify**: `grep 'wonder\|skill-injector\|oscillation' skills/setup/claude-md-template.md` → matches
- **Commit**: `feat(setup): update for v0.2.0 migration path`

### Task 5.5: Version bump and breaking changes documentation
- **Files**: `.claude-plugin/plugin.json`
- **Spec items**: C26
- **Depends on**: all prior tasks
- **Action**: Bump version to `0.2.0` in plugin.json. The `sync-versions.sh` pre-push hook will sync to marketplace.json.
- **Breaking changes to document**:
  - `status.yaml` schema: `attempt` and `reinforcement_count` fields removed
  - `SESSIONS_DIR` now resolves to absolute path (no behavioral change if hooks ran from project root)
  - Plan reviewers use DONE/BLOCKED protocol instead of APPROVED/ISSUES_FOUND
  - New `.robro/` directories: `skills/`, new state files (`.skill-index.json`, `.oscillation-state.json`)
  - New hooks: oscillation-detector, skill-injector, update-check, verify-deliverables
  - Node.js required for new hooks
- **Test**: `jq -r '.version' .claude-plugin/plugin.json` → `0.2.0`
- **Verify**: `bash scripts/sync-versions.sh && jq -r '.version' .claude-plugin/marketplace.json` → `0.2.0`
- **Commit**: `chore: bump version to 0.2.0`

## Pre-mortem

| Failure Scenario | Likelihood | Impact | Mitigation |
|-----------------|-----------|--------|------------|
| JSON frontmatter parsing fails for edge-case skill files | Low | Medium — skill not injected | Strict schema enforcement by level-up; manual skills documented |
| Oscillation detector state file grows unbounded | Medium | Low — disk space only | Reset state at sprint boundaries (brief phase clears `.oscillation-state.json`) |
| Skill injection adds latency to every prompt | Low | Medium — slower UX | Index cache approach; 5000ms timeout; graceful degradation on timeout |
| Update check blocks session start on slow network | Low | High — delays every session | Separate hook entry with 3000ms timeout; failure = silent skip |
| Wonder agent produces generic/useless blind spots | Medium | Low — wasted tokens only | Conditional dispatch (skip healthy sprints); specific input contract |
| Level-up writes stale skills from old plans | Medium | Medium — irrelevant context injected | `plan` field in frontmatter; future: prune skills from inactive plans |
| Plan reviewer routing breaks during protocol transition | Low | Medium — review loop fails | Map APPROVED→DONE, ISSUES_FOUND→DONE_WITH_CONCERNS; test both paths |
| Node.js not available (non-standard environment) | Very Low | High — 3 hooks fail | Claude Code IS Node.js; add graceful check in .mjs scripts |

## Open Questions
- Should oscillation state reset at sprint boundaries or persist across sprints? (Pre-mortem suggests reset; implement as brief-phase clearing `.oscillation-state.json`)
- Should learned skills have an expiration mechanism (e.g., TTL based on plan activity)?
- Does the Claude Code plugin marketplace validate `skills`/`agents`/`hooks` paths in plugin.json?
