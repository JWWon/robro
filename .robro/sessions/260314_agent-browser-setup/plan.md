---
spec: spec.yaml
idea: idea.md
created: 2026-03-14T13:00:00Z
---

# Implementation Plan: Fix Agent-Browser Setup for Claude Code

## Overview
Update robro's setup skill to install agent-browser exclusively for Claude Code using `--agent claude-code` and auto-install the binary via a new shared package manager detection script.

## Tech Context
- **Plugin type**: Claude Code plugin — skills are instructional SKILL.md files, not executable code
- **Script conventions**: `#!/usr/bin/env bash`, `SCRIPT_DIR` pattern for path resolution, `${CLAUDE_PLUGIN_ROOT}` for plugin paths
- **Existing shared lib**: `scripts/lib/load-config.sh` (session/config utilities — NOT needed for this script)
- **Standalone scripts precedent**: `scripts/manage-claudemd.sh` and `scripts/sync-versions.sh` don't source shared libs
- **Package managers**: bun (`bun.lock`/`bun.lockb`), pnpm (`pnpm-lock.yaml`), yarn (`yarn.lock`), npm (`package-lock.json`)
- **Yarn Berry**: v2+ removed `yarn global add` — detect via `.yarnrc.yml`, fall back to npm for global installs
- **agent-browser install**: Idempotent — Rust source checks `if bin.exists() { return; }` before downloading Chrome

## Architecture Decision Record
| Decision | Rationale | Alternatives Considered | Trade-offs |
|----------|-----------|-------------------------|------------|
| Script outputs manager name only | Clean separation — caller maps name to command | Output full install command | Simpler script, caller must know mapping |
| Yarn Berry detection via `.yarnrc.yml` | `yarn global add` removed in v2+ | Ignore Berry | 4 extra lines prevents silent failure |
| Check both `bun.lock` and `bun.lockb` | Bun v1.2+ uses text format, older uses binary | Only check `bun.lock` | One extra line catches older projects |
| Always run `agent-browser install` | CLI is idempotent internally | Manual Chrome detection | Trust CLI, avoid coupling to internals |
| Binary fail → skip Chrome download | Chrome download requires the binary | Independent steps | Logical dependency respected |
| No-lockfile fallback: `npm` | Guaranteed by Node.js / Claude Code | Error out | Always produces a usable result |

## File Map
| File | Action | Responsibility |
|------|--------|---------------|
| `scripts/detect-pkg-manager.sh` | create | Shared utility: detect project package manager via lockfiles + CLI fallback |
| `skills/setup/SKILL.md` | modify | Fix skills add command, add binary install + Chrome download steps |

## Phase 1: Package Manager Detection Script
> Depends on: none
> Parallel: none (single task)
> Delivers: A standalone, tested `detect-pkg-manager.sh` script
> Spec sections: S1

### Task 1.1: Create detect-pkg-manager.sh
- **Files**: `scripts/detect-pkg-manager.sh`
- **Spec items**: C1, C2, C3, C4
- **Depends on**: none
- **Action**: Create `scripts/detect-pkg-manager.sh` with the following exact content:

```bash
#!/usr/bin/env bash
# Detect the project's package manager via lockfile presence, then CLI availability.
# Usage: detect-pkg-manager.sh [project_root]
# Output: one word to stdout — bun, pnpm, yarn, or npm
# Priority: bun > pnpm > yarn > npm (lockfile first, then CLI fallback)
# Standalone: does not depend on any other robro scripts.

set -euo pipefail

PROJECT_ROOT="${1:-.}"

# Phase 1: Lockfile detection (project-level signal)
if [ -f "${PROJECT_ROOT}/bun.lock" ] || [ -f "${PROJECT_ROOT}/bun.lockb" ]; then
  echo "bun"
  exit 0
fi

if [ -f "${PROJECT_ROOT}/pnpm-lock.yaml" ]; then
  echo "pnpm"
  exit 0
fi

if [ -f "${PROJECT_ROOT}/yarn.lock" ]; then
  echo "yarn"
  exit 0
fi

if [ -f "${PROJECT_ROOT}/package-lock.json" ]; then
  echo "npm"
  exit 0
fi

# Phase 2: CLI availability fallback (system-level signal)
if command -v bun >/dev/null 2>&1; then
  echo "bun"
  exit 0
fi

if command -v pnpm >/dev/null 2>&1; then
  echo "pnpm"
  exit 0
fi

if command -v yarn >/dev/null 2>&1; then
  echo "yarn"
  exit 0
fi

# Final fallback: npm (guaranteed by Node.js)
echo "npm"
```

- **Test**: Run the script in directories with different lockfiles:
  ```bash
  # Create temp dirs with lockfiles and verify detection
  TMPDIR=$(mktemp -d)
  touch "$TMPDIR/bun.lock" && [ "$(bash scripts/detect-pkg-manager.sh "$TMPDIR")" = "bun" ] && echo "PASS: bun.lock" || echo "FAIL: bun.lock"
  rm "$TMPDIR/bun.lock"
  touch "$TMPDIR/bun.lockb" && [ "$(bash scripts/detect-pkg-manager.sh "$TMPDIR")" = "bun" ] && echo "PASS: bun.lockb" || echo "FAIL: bun.lockb"
  rm "$TMPDIR/bun.lockb"
  touch "$TMPDIR/pnpm-lock.yaml" && [ "$(bash scripts/detect-pkg-manager.sh "$TMPDIR")" = "pnpm" ] && echo "PASS: pnpm" || echo "FAIL: pnpm"
  rm "$TMPDIR/pnpm-lock.yaml"
  touch "$TMPDIR/yarn.lock" && [ "$(bash scripts/detect-pkg-manager.sh "$TMPDIR")" = "yarn" ] && echo "PASS: yarn" || echo "FAIL: yarn"
  rm "$TMPDIR/yarn.lock"
  touch "$TMPDIR/package-lock.json" && [ "$(bash scripts/detect-pkg-manager.sh "$TMPDIR")" = "npm" ] && echo "PASS: npm" || echo "FAIL: npm"
  rm "$TMPDIR/package-lock.json"
  RESULT=$(bash scripts/detect-pkg-manager.sh "$TMPDIR") && [ -n "$RESULT" ] && echo "PASS: fallback ($RESULT)" || echo "FAIL: fallback"
  rm -rf "$TMPDIR"
  ```
- **Verify**: `bash -n scripts/detect-pkg-manager.sh` exits 0 (syntax check) AND `chmod +x scripts/detect-pkg-manager.sh` succeeds
- **Commit**: `feat(scripts): add detect-pkg-manager.sh shared utility`

## Phase 2: Update Setup Skill
> Depends on: Phase 1
> Parallel: none
> Delivers: Updated SKILL.md with Claude Code-only skill install + binary auto-install
> Spec sections: S2

### Task 2.1: Replace agent-browser block in SKILL.md
- **Files**: `skills/setup/SKILL.md`
- **Spec items**: C5, C6, C7, C8, C9
- **Depends on**: Phase 1 (detect-pkg-manager.sh must exist)
- **Action**: In `skills/setup/SKILL.md`, find and replace the entire agent-browser block. The old block starts at line 152 with `**Skill: agent-browser**` and ends at line 163 with `> 3. Or run: \`claude plugin install agent-browser\``. Replace this exact text:

  ```
  **Skill: agent-browser**
  ```bash
  npx skills add vercel-labs/agent-browser --skill agent-browser
  ```

  If the `npx skills add` command fails (non-zero exit code), report the error and provide manual install instructions as fallback:

  > **agent-browser install failed.** You can install it manually:
  > 1. Visit https://github.com/vercel-labs/agent-browser
  > 2. Follow the installation instructions in the README
  > 3. Or run: `claude plugin install agent-browser`
  ```

  With the following new block:

  ````markdown
  **Skill: agent-browser**

  Agent-browser installation has 3 sub-steps: skill install, binary install, and Chrome download. Each reports independently; failures warn but don't block the rest of setup.

  **Sub-step 1: Install the skill (Claude Code only)**
  ```bash
  npx skills add vercel-labs/agent-browser --skill agent-browser --agent claude-code -y
  ```

  If the `npx skills add` command fails (non-zero exit code), report the error and provide manual install instructions as fallback:

  > **agent-browser skill install failed.** You can install it manually:
  > 1. Visit https://github.com/vercel-labs/agent-browser
  > 2. Follow the installation instructions in the README
  > 3. Or run: `npx skills add vercel-labs/agent-browser --skill agent-browser --agent claude-code -y`

  **Sub-step 2: Install the binary**

  First, check if agent-browser is already installed:
  ```bash
  which agent-browser
  ```

  If `which agent-browser` succeeds (exit code 0), skip to sub-step 3.

  If not installed, detect the project's package manager:
  ```bash
  PKG_MANAGER=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-pkg-manager.sh" "$PROJECT_ROOT")
  ```

  Then install the binary globally using the detected package manager. The install command varies per manager:

  | Package Manager | Install Command |
  |----------------|----------------|
  | bun | `bun add -g agent-browser` |
  | pnpm | `pnpm add -g agent-browser` |
  | yarn | Check if `.yarnrc.yml` exists in `$PROJECT_ROOT`. If YES (Yarn Berry): use `npm install -g agent-browser` instead (Yarn Berry removed `global add`). If NO (Yarn Classic): use `yarn global add agent-browser`. |
  | npm | `npm install -g agent-browser` |

  If the binary install fails, report the error and provide manual instructions:

  > **agent-browser binary install failed.** Install manually: `npm install -g agent-browser`

  If the binary install fails, skip sub-step 3 (Chrome download requires the binary).

  **Sub-step 3: Download Chrome**

  Run the Chrome download (this command is idempotent — it checks if Chrome is already present and skips if so):
  ```bash
  agent-browser install
  ```

  If the Chrome download fails, warn but don't block:

  > **Chrome download failed.** Run `agent-browser install` manually when you have internet access.

  **Reporting**: After all sub-steps, report the status of each:
  - Skill: installed / already configured / failed
  - Binary: installed / already installed / failed
  - Chrome: downloaded / already present / failed / skipped (binary not installed)
  ````

- **Test**: Read the updated SKILL.md and verify:
  1. The `--agent claude-code -y` flags are present
  2. The `detect-pkg-manager.sh` reference uses `${CLAUDE_PLUGIN_ROOT}`
  3. All 4 package managers have install commands
  4. Yarn Berry detection is documented
  5. Error cascade: binary fail → skip Chrome
  6. Per-component reporting section exists
  7. No old fallback text remains (no `claude plugin install agent-browser`)
- **Verify**: Run all of these (each should output PASS):
  ```bash
  grep -q '\-\-agent claude-code -y' skills/setup/SKILL.md && echo "PASS: flags" || echo "FAIL: flags"
  grep -q 'detect-pkg-manager.sh' skills/setup/SKILL.md && echo "PASS: script ref" || echo "FAIL: script ref"
  grep -q 'bun add -g' skills/setup/SKILL.md && echo "PASS: bun cmd" || echo "FAIL: bun cmd"
  grep -q '.yarnrc.yml' skills/setup/SKILL.md && echo "PASS: yarn berry" || echo "FAIL: yarn berry"
  grep -q 'skip sub-step 3' skills/setup/SKILL.md && echo "PASS: error cascade" || echo "FAIL: error cascade"
  ! grep -q 'claude plugin install agent-browser' skills/setup/SKILL.md && echo "PASS: old fallback removed" || echo "FAIL: old fallback remains"
  ```
- **Commit**: `feat(setup): replace agent-browser block with Claude Code-only install + binary auto-install`

## Pre-mortem
| Failure Scenario | Likelihood | Impact | Mitigation |
|------------------|-----------|--------|------------|
| `npx skills` CLI changes `--agent` flag | Low | High | Version-pinned in idea research (v1.4.5). SKILL.md has fallback instructions. |
| Global install fails (permissions) | Medium | Low | Warn-and-continue + manual install instructions. Most dev envs use nvm/fnm. |
| Chrome download timeout on slow networks | Medium | Low | `agent-browser install` is idempotent — user can re-run later. |
| Multiple lockfiles confuse detection | Low | Low | Priority order (bun > pnpm > yarn > npm) resolves deterministically. |
| Yarn Berry user hits `yarn global add` | Medium | Medium | `.yarnrc.yml` check falls back to npm. Documented in SKILL.md. |
| `bun.lockb` not recognized | Low | Low | Script checks both `bun.lock` and `bun.lockb`. |

## Open Questions
- None. All concerns from Architect and Critic reviews resolved by Researcher findings.
