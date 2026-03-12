# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

Robro is a Claude Code plugin that transforms a simple agent into your project companion. It extends Claude Code with custom skills, agents, hooks, and MCP servers.

## Plugin Configuration

The plugin manifest lives at `.claude-plugin/plugin.json`. This is the only file that belongs inside `.claude-plugin/` — all other directories (skills, agents, commands, hooks) go at the plugin root.

### plugin.json Schema

```json
{
  "name": "robro",                          // Required. Unique ID, used as skill namespace (e.g. /robro:skill-name)
  "description": "...",                     // Shown in plugin manager
  "version": "1.0.0",                      // Semver. Bump to trigger updates for installed users
  "author": { "name": "", "email": "", "url": "" },
  "homepage": "https://...",
  "repository": "https://...",
  "license": "MIT",
  "keywords": ["tag1", "tag2"],
  // Component path overrides (supplement defaults, don't replace):
  "commands": "./custom/commands/",         // string | array
  "agents": "./custom/agents/",            // string | array
  "skills": "./custom/skills/",            // string | array
  "hooks": "./config/hooks.json",          // string | array | inline object
  "mcpServers": "./mcp-config.json",       // string | array | inline object
  "lspServers": "./.lsp.json",             // string | array | inline object
  "outputStyles": "./styles/"              // string | array
}
```

### Directory Structure

```
robro/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest (only this goes here)
├── commands/                # Slash command markdown files
├── skills/                  # Agent skills (name/SKILL.md structure)
├── agents/                  # Subagent markdown definitions
├── hooks/
│   └── hooks.json           # Event handler config
├── .mcp.json                # MCP server definitions
├── .lsp.json                # LSP server configurations
├── settings.json            # Default settings (only "agent" key supported)
└── scripts/                 # Hook and utility scripts
```

### Key Concepts

- **Skills** (`skills/<name>/SKILL.md`): Model-invoked capabilities. Claude auto-uses them based on task context. Invoked as `/robro:<skill-name>`.
- **Commands** (`commands/*.md`): User-invoked slash commands. Legacy location — prefer `skills/` for new work.
- **Agents** (`agents/*.md`): Subagents with frontmatter (`name`, `description`) and a system prompt body.
- **Hooks** (`hooks/hooks.json`): Event handlers for `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, etc. Types: `command`, `prompt`, `agent`.
- **MCP servers** (`.mcp.json`): External tool integrations, auto-started when plugin is enabled.
- **LSP servers** (`.lsp.json`): Language server configs for code intelligence.
- **`${CLAUDE_PLUGIN_ROOT}`**: Environment variable resolving to plugin install path. Use in hooks, MCP configs, and scripts.

### Testing

```bash
# Load plugin locally for development
claude --plugin-dir .

# Load multiple plugins
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two

# Reload after changes (inside Claude Code TUI)
/reload-plugins

# Debug plugin loading issues
claude --debug
```

### Distribution

- Version with semver. Users won't see changes unless version is bumped.
- Submit to official marketplace at claude.ai/settings/plugins/submit or platform.claude.com/plugins/submit.
- Install scopes: `user` (default, global), `project` (shared via VCS), `local` (gitignored).
