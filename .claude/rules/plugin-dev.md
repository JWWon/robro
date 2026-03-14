# Plugin Development Conventions

## File Placement

| Component | Location | Example |
|-----------|----------|---------|
| Skills | `skills/<name>/SKILL.md` | `skills/idea/SKILL.md` |
| Agents | `agents/<name>.md` | `agents/builder.md` |
| Hook config | `hooks/hooks.json` | Single file, references scripts |
| Hook scripts | `scripts/<name>.sh` | `scripts/session-start.sh` |
| Plugin manifest | `.claude-plugin/plugin.json` | Only plugin.json + marketplace.json in .claude-plugin/ |
| Model config | `config.json` | Plugin root |
| Setup template | `skills/setup/claude-md-template.md` | Injected into user projects by /robro:setup |

## Script Requirements

- Hook scripts must be executable: `chmod +x scripts/*.sh`
- Scripts use `${CLAUDE_PLUGIN_ROOT}` for paths — never hardcode absolute paths
- Scripts receive JSON on stdin — use `jq` to extract fields
- All scripts must pass `bash -n` syntax check

## Test Files

- `tests/` contains verification scripts for setup skill and manual checks
- Build agents may create temporary test files during sprints — these are build artifacts, not permanent tests
- After a build converges, review `tests/` for stale agent-created files and remove them

## Two Contexts

This repo serves two roles:
- **Plugin source** — skills/, agents/, hooks/, scripts/ are the plugin that users install
- **Dev workspace** — .claude/, CLAUDE.md contain guidance for working ON this codebase

Root `CLAUDE.md` documents the plugin (what it does, how it works). `.claude/CLAUDE.md` has dev workflow (how to test, debug, reload) plus the robro:managed template block.
