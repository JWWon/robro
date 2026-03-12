# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Workflow

```bash
# Test the plugin during development
claude --plugin-dir .

# Debug loading issues
claude --debug
```

After making changes to skills, commands, agents, or hooks, run `/reload-plugins` inside the TUI to pick up updates. LSP server config changes require a full restart.

## Architecture Rules

- `.claude-plugin/` contains **only** `plugin.json`. Never put commands, agents, skills, or hooks inside it.
- All component paths in `plugin.json` must be relative and start with `./`.
- Hook scripts must be executable (`chmod +x`) and use `${CLAUDE_PLUGIN_ROOT}` for paths.
- Hooks receive input as JSON on stdin — use `jq` to extract fields.
- Installed plugins are cached at `~/.claude/plugins/cache`. Paths that traverse outside the plugin root (`../`) won't resolve after installation.
- If the plugin needs external files, symlink them into the plugin directory (symlinks are honored during cache copy).

## Skill Authoring

Skills use `skills/<name>/SKILL.md` with frontmatter:

```yaml
---
name: skill-name
description: When and why Claude should use this skill
---
```

- `$ARGUMENTS` placeholder captures user input after the skill name.
- Skills can include supporting files (scripts, references) alongside SKILL.md.
- `disable-model-invocation: true` in frontmatter makes a skill user-only (not auto-invoked).

## Agent Authoring

Agents use `agents/<name>.md` with frontmatter:

```yaml
---
name: agent-name
description: What this agent does and when to invoke it
---
```

The body is the agent's system prompt. Agents appear in `/agents` and can be auto-invoked by Claude.

## Hook Events

Available events (case-sensitive): `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `UserPromptSubmit`, `Notification`, `Stop`, `SubagentStart`, `SubagentStop`, `SessionStart`, `SessionEnd`, `TeammateIdle`, `TaskCompleted`, `PreCompact`.

Hook types: `command` (shell), `prompt` (LLM eval), `agent` (agentic verifier).
