---
type: update
created: 2026-03-14T12:00:00Z
ambiguity_score: 0.10
status: ready
project_type: brownfield
dimensions:
  goal: 0.95
  constraints: 0.85
  criteria: 0.9
  context: 0.85
---

# Fix Agent-Browser Setup for Claude Code

## Goal
Update the robro setup skill to install agent-browser skills exclusively for Claude Code and auto-install the agent-browser binary using the project's detected package manager.

## Problem Statement
Running `npx skills add vercel-labs/agent-browser` during `/robro:setup` creates skill files in multiple directories (`.agents/`, `.cursor/`, etc.) for all detected AI agents, not just Claude Code's `.claude/skills/`. Users expect skills to be installed only in `.claude/skills/` at the project level. Additionally, the agent-browser binary itself is not installed by setup, making the skill non-functional without manual intervention.

## Users & Stakeholders
- **Robro users** running `/robro:setup` on new or existing projects — they get a clean, working agent-browser installation with no extra directories polluting their project.
- **Plugin maintainers** — the shared `detect-pkg-manager.sh` utility benefits future setup commands and hooks.

## Requirements

### Must Have
- Fix `npx skills add` command in setup skill: add `--agent claude-code -y` flags so skills install only to `.claude/skills/agent-browser/` with no interactive prompts
- Auto-install agent-browser binary using the project's detected package manager (skip if `which agent-browser` succeeds)
- Auto-run `agent-browser install` for Chrome download after binary install (skip if Chrome already present)
- Create `scripts/detect-pkg-manager.sh` as a shared shell utility:
  - Accepts project root path as argument
  - Checks lockfiles in priority order: `bun.lock` > `pnpm-lock.yaml` > `yarn.lock` > `package-lock.json`
  - Falls back to CLI availability check (`which bun`, `which pnpm`, `which yarn`)
  - Outputs one word to stdout: `bun`, `pnpm`, `yarn`, or `npm`
  - `npm` is the final fallback (guaranteed by Node.js/Claude Code)
- Warn and continue on partial failure — each sub-step (skill install, binary install, Chrome download) reports independently, failures don't block the rest of setup

### Should Have
- Update SKILL.md instructions to reference `detect-pkg-manager.sh` for future install commands that need the project's package manager
- Per-component install reporting: clear status for each sub-step (skill installed/skipped, binary installed/skipped, Chrome downloaded/skipped)

### Won't Have (Non-goals)
- Replace `npx` for one-shot package runners (MCP installs like `npx -y @upstash/context7-mcp@latest`, `npx skills add`) — `npx` is universally available via Node.js and appropriate for ephemeral execution
- Interactive package manager selection — detection is fully automatic
- Global scope for agent-browser skill — project-level only via `--agent claude-code` flag
- Support for non-Node.js package managers (pip, cargo, etc.) — out of scope

## Constraints
- Shell scripts must use `${CLAUDE_PLUGIN_ROOT}` for paths (plugin convention)
- Scripts must be executable (`chmod +x`) and pass `bash -n` syntax check
- Package manager detection uses lockfiles as primary signal (project-level), CLI availability as fallback (system-level)
- Detection priority when multiple lockfiles exist: bun > pnpm > yarn > npm (fastest-first)
- `detect-pkg-manager.sh` must be usable standalone (not dependent on other robro scripts)
- Global install command mapping: `bun add --global`, `pnpm add -g`, `yarn global add`, `npm install -g`

## Success Criteria
- `detect-pkg-manager.sh` returns the correct package manager when run in projects with bun.lock, pnpm-lock.yaml, yarn.lock, or package-lock.json
- Running `/robro:setup` in a bun project installs agent-browser via `bun add --global` (not `npm install -g`)
- After setup, `.claude/skills/agent-browser/SKILL.md` exists and NO `.agents/` directory is created
- `agent-browser --version` succeeds after setup completes
- Re-running setup when everything is already installed produces no changes (idempotent)

## Proposed Approach
Two deliverables, minimal scope:

**1. `scripts/detect-pkg-manager.sh`** (new file)
- Accepts project root path as `$1`
- Lockfile check: `bun.lock` → `pnpm-lock.yaml` → `yarn.lock` → `package-lock.json`
- CLI fallback: `which bun` → `which pnpm` → `which yarn` → default `npm`
- Outputs single word to stdout

**2. `skills/setup/SKILL.md`** (update existing)
- Fix skills add command: `npx skills add vercel-labs/agent-browser --skill agent-browser --agent claude-code -y`
- Add agent-browser binary install step after skill install:
  1. Source `detect-pkg-manager.sh` to get package manager
  2. Check `which agent-browser` — if missing, run `<pm> add --global agent-browser`
  3. Run `agent-browser install` if Chrome not yet downloaded
- Each sub-step reports independently; failures warn but don't block

This approach was chosen because it's the minimum change that solves all stated requirements. The detection script is decoupled from agent-browser so it can serve future setup commands.

## Assumptions Exposed
| Assumption | Status | Resolution |
|---|---|---|
| `skills` CLI `--agent claude-code` flag exists | Verified | Confirmed via `npx skills --help` and vercel-labs/skills source |
| `npx` is universally available in Claude Code | Verified | Claude Code is Node.js; npx ships with npm which ships with Node.js |
| `agent-browser install` downloads Chrome for Testing | Verified | Confirmed via agent-browser README and CLI docs |
| Lockfile names are stable across package managers | Verified | bun.lock, pnpm-lock.yaml, yarn.lock, package-lock.json are canonical |
| `bun add --global` is the correct global install command for bun | Verified | Confirmed via bun docs |

## Context
- **Existing setup skill**: `skills/setup/SKILL.md` already handles agent-browser as one of 4 recommended items (context7 MCP, grep MCP, github rule, agent-browser skill). The skill install command needs the `--agent claude-code -y` flags added.
- **Current agent-browser command**: `npx skills add vercel-labs/agent-browser --skill agent-browser` — missing `--agent` and `-y` flags.
- **skills CLI version**: 1.4.5 (available via npx, by Vercel Labs / rauchg)
- **agent-browser**: v latest, Rust-based headless browser CLI, 21k+ GitHub stars. Not currently installed on this system.
- **Package manager detection**: No existing detection utility in the robro codebase. This will be the first shared script for this purpose.

## Open Questions
- (none — ambiguity at threshold)

## Key Research Findings
- The `skills` CLI (npm: `skills`) is separate from `agent-browser`. It's a package manager for AI agent SKILL.md files supporting 35+ agents. The `--agent claude-code` flag targets only Claude Code's `.claude/skills/` directory.
- The agent-browser SKILL.md uses standard Claude Code frontmatter (`name`, `description`, `allowed-tools`) and is 100% compatible. It includes `references/` (7 files) and `templates/` (3 scripts) alongside SKILL.md.
- `npx` is a package runner, not a package manager — it works universally regardless of project tooling. Only global install commands need package manager detection.
- The agent-browser repo also ships as a Claude Code plugin (`.claude-plugin/marketplace.json`), but the skill-only path via `npx skills add` is lighter and preferred for setup.
