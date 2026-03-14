---
name: setup
description: Configure a project for robro — manages CLAUDE.md section, recommends MCPs/skills, configures .gitignore. Run this once when adding robro to a new project.
disable-model-invocation: true
argument-hint: "(no arguments needed)"
---

# Setup — Project Configuration for Robro

You are configuring a project to work with the robro plugin. This skill manages the robro-specific section in `.claude/CLAUDE.md`, detects and recommends MCP servers and skills, and configures `.gitignore` for plan artifacts.

**Input**: No arguments needed. Operates on the current project.

<Use_When>
- User says "setup", "configure robro", "set up this project for robro"
- A project is being onboarded to use robro for the first time
- User wants to update the robro configuration section
</Use_When>

<Do_Not_Use_When>
- User wants to start planning (use /robro:idea instead)
- User wants to build (use /robro:do instead)
</Do_Not_Use_When>

## Workflow

### Step 1: CLAUDE.md Section Management

Invoke the managed block script to create or update the robro section in `.claude/CLAUDE.md`:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/manage-claudemd.sh" "$PROJECT_ROOT"
```

The script handles all cases: file missing, no markers, version comparison, backward compatibility with the legacy `[VERSION]` bracket marker format, and code-block-aware marker detection. It outputs what action was taken.

New marker format:
- Start: `<!-- robro@{version}:managed:start -->`
- End: `<!-- robro:managed:end -->`

### Step 2: MCP/Skill Detection & Checklist

Detect which recommended MCP servers, rules, and skills are already configured, then present a checklist for the user to select what to install. Never re-install items that are already configured.

#### 2a. Define Recommended Items

The setup skill recommends these 4 items:

| Name | Type | Purpose |
|------|------|---------|
| context7 | MCP | Up-to-date library documentation lookup |
| grep | MCP | Search code on GitHub repositories |
| github | Rule | Guide for using git and gh CLI effectively |
| agent-browser | Skill | Browser automation for testing and scraping |

#### 2b. Detection Logic

For each item, determine whether it is already configured. An item is "configured" if it is detected by ANY of its detection paths — never re-install something that already exists.

**MCP detection (context7, grep)**:

1. Read `~/.claude.json` using the Read tool. Parse the JSON content and check if the `mcpServers` object contains a key matching the MCP name (e.g., `"context7"` or `"grep"`).
2. Read `.mcp.json` at the project root (use the `PROJECT_ROOT` from Step 1). Parse the JSON content and check if the `mcpServers` object contains a key matching the MCP name.
3. If the key exists in EITHER file, the MCP is **already configured** — skip it.
4. If the Read tool returns a "file does not exist" error for either file, treat that file as having no MCPs configured (do not error out — just continue to the next file).

**Rule detection (github)**:

1. Use the Glob tool to find all files matching `.claude/rules/*.md` in the project root.
2. For each found file, use the Grep tool to search its content for `git` or `github` (case-insensitive).
3. If ANY rule file contains git-related content (matches "git" or "github"), the github rule is **already configured** — skip it. This avoids creating duplicates when the user already has git conventions in a differently-named file (e.g., `.claude/rules/workflow.md` that mentions git).
4. If no `.claude/rules/` directory exists or no files match, or no files contain git-related content, the github rule is **not configured**.

**Skill detection (agent-browser)**:

1. Use the Glob tool to check if `.claude/skills/agent-browser/` directory exists (look for `.claude/skills/agent-browser/SKILL.md` or any file in that directory).
2. If not found, read `~/.claude/plugins/installed_plugins.json` and check if it contains an entry with `"agent-browser"` in it.
3. If EITHER check finds a match, agent-browser is **already configured** — skip it.
4. If the installed_plugins.json file does not exist, treat it as no plugins installed.

#### 2c. Present Checklist

Build a status summary of all 4 items and present it to the user. Use AskUserQuestion with multiSelect to let the user choose which unconfigured items to install.

Format the checklist like this:

```
Recommended MCP servers, rules, and skills for this project:

[already configured] context7 (MCP) — Up-to-date library docs
[not configured]     grep (MCP) — Search GitHub code
[not configured]     github (Rule) — Git/gh CLI guide
[already configured] agent-browser (Skill) — Browser automation

Select items to install (already-configured items are skipped automatically):
```

The AskUserQuestion options should include:
- Each **unconfigured** item as a selectable option (e.g., "grep (MCP)", "github (Rule)")
- A "Skip all" option to skip the entire step

If ALL items are already configured, skip AskUserQuestion entirely and report: **"All recommended items already configured — nothing to install"**. Proceed to Step 3.

#### 2d. Install Confirmed Items

For each item the user selected, execute the appropriate install action:

**MCP: context7**
```bash
claude mcp add --scope project context7 -- npx -y @upstash/context7-mcp@latest
```

**MCP: grep**
```bash
claude mcp add --scope project grep -- npx -y @anthropic-ai/grep-mcp
```

**Rule: github**

Create the file `.claude/rules/github.md` in the project root using the Write tool with the following content:

```markdown
# Git & GitHub CLI Guide

## Commit Conventions
- Write clear, descriptive commit messages
- Use conventional commits format: `type(scope): description`
- Common types: feat, fix, docs, chore, refactor, test
- Keep the first line under 72 characters

## Branch Workflow
- Create feature branches from main: `git checkout -b feat/description`
- Keep branches focused on a single change
- Rebase on main before merging to keep history clean

## GitHub CLI (gh)
- Create PRs: `gh pr create --title "..." --body "..."`
- Check PR status: `gh pr status`
- View PR checks: `gh pr checks`
- Merge PRs: `gh pr merge --squash`
- Create issues: `gh issue create --title "..." --body "..."`
- List issues: `gh issue list`

## Best Practices
- Pull before pushing: `git pull --rebase origin main`
- Review diffs before committing: `git diff --staged`
- Use `.gitignore` to exclude build artifacts, secrets, and IDE files
- Never commit secrets, API keys, or credentials
```

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

#### 2e. Report Results

After processing all items, report the summary:

**"{N} items installed, {M} already configured, {K} skipped by user"**

Where:
- N = number of items successfully installed in this step
- M = number of items that were already configured (detected in 2b)
- K = number of unconfigured items the user chose not to install (including "Skip all")

### Step 3: .gitignore Configuration

Configure `.gitignore` at the project root so that temporal plan artifacts are never committed to version control.

#### 3a. Define Rules

The following 5 rules must be present in the project's `.gitignore`:

```
# Robro temporal artifacts
.robro/sessions/*/research/
.robro/sessions/*/discussion/
.robro/sessions/*/status.yaml
.robro/sessions/*/*.bak.*
.claude/worktrees/
```

Store these 5 rule lines (not including the comment header) as `ROBRO_RULES` for comparison below:

1. `.robro/sessions/*/research/`
2. `.robro/sessions/*/discussion/`
3. `.robro/sessions/*/status.yaml`
4. `.robro/sessions/*/*.bak.*`
5. `.claude/worktrees/`

#### 3b. Check Existing .gitignore

1. Use the Read tool to read `${PROJECT_ROOT}/.gitignore` (using the `PROJECT_ROOT` from Step 1)
2. If the Read tool returns a "file does not exist" error, the file does not exist — proceed to 3c (create case)
3. If the file exists, read its full content. For each of the 5 rules in `ROBRO_RULES`, check whether the EXACT rule text appears as a line in the file (exact string match, trimming trailing whitespace)
4. Build a list of missing rules — rules that do NOT already appear in the file

#### 3c. Apply Missing Rules

**If `.gitignore` does NOT exist**: Create it with the Write tool containing the header comment and all 5 rules:

```
# Robro temporal artifacts
.robro/sessions/*/research/
.robro/sessions/*/discussion/
.robro/sessions/*/status.yaml
.robro/sessions/*/*.bak.*
.claude/worktrees/
```

Report: **".gitignore: created with 5 rules"**

**If `.gitignore` exists but is missing some rules**:

1. Check if the file content ends with a newline. If not, prepend a newline to the content you will append
2. Add a blank line separator
3. Add the `# Robro temporal artifacts` header comment ONLY if none of the 5 robro rules currently exist in the file (i.e., all 5 are missing). If some rules already exist, skip the header to avoid duplicate headers
4. Append only the missing rules, one per line
5. Use the Edit tool to append to the end of the file

Report: **".gitignore: added {N} missing rules"** (where N is the count of rules that were added)

**If all 5 rules already present**: No changes needed.

Report: **".gitignore: all robro rules already present — no changes"**

#### 3d. Idempotency

This step is designed to produce identical results on re-run:

- The exact string match in step 3b prevents duplicate rules from being added
- The header comment is only added when zero robro rules exist, preventing duplicate headers
- Running `/robro:setup` twice in succession produces identical `.gitignore` content
- Rules are compared as exact line matches, so partial matches or substrings do not cause false positives

### Step 3.5: Settings.json Configuration

Configure `.claude/settings.json` to enable experimental features required by robro.

#### 3.5a. Define Required Env Vars

The setup skill ensures these env vars are present:

| Env Var | Value | Purpose |
|---------|-------|---------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `"1"` | Enable Claude Code Agent Teams for parallel execution |

#### 3.5b. Check Existing Settings

1. Use the Read tool to read `${PROJECT_ROOT}/.claude/settings.json`
2. If the Read tool returns a "file does not exist" error, the file does not exist — proceed to 3.5c (create case)
3. If the file exists, parse its JSON content and check if the `env` object contains the required key with the correct value

#### 3.5c. Apply Settings

**If `.claude/settings.json` does NOT exist**:

Ensure the `.claude/` directory exists (use `mkdir -p`). Create the file with the Write tool:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Report: **".claude/settings.json: created with Teams env var"**

**If `.claude/settings.json` exists but is missing the env var**:

Use the Edit tool to add the env var to the `env` block. If no `env` block exists, add one. Preserve all existing content.

For example, if the file currently contains:
```json
{
  "permissions": { "defaultMode": "plan" }
}
```

Update it to:
```json
{
  "permissions": { "defaultMode": "plan" },
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Report: **".claude/settings.json: added Teams env var"**

**If the env var already exists with the correct value**:

Report: **".claude/settings.json: Teams already enabled — no changes"**

#### 3.5d. Idempotency

This step produces identical results on re-run:
- If the env var already exists with value `"1"`, no changes are made
- If the file has other env vars, they are preserved
- If the file has other settings (permissions, hooks, etc.), they are preserved

### Step 3.7: Config File Setup

#### 3.7a. Check for Existing Config

Check if `.robro/config.json` exists:
```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
ls "${PROJECT_ROOT}/.robro/config.json" 2>/dev/null
```

If the file exists, report: **".robro/config.json already exists — no changes"** and skip to Step 4.

#### 3.7b. Offer Config Creation

If the file does not exist, ask the user via AskUserQuestion:

"Would you like to create .robro/config.json for project-level customization? This file lets you override model tiers, thresholds, and per-agent model assignments. All fields are optional — omitted fields use built-in defaults."

Options: "Create with defaults", "Skip for now"

#### 3.7c. Create Config File

If the user chooses "Create with defaults":
```json
{
  "$schema": "https://raw.githubusercontent.com/JWWon/robro/main/config.schema.json"
}
```

Report: **".robro/config.json: created with schema reference"**

### Step 3.8: CLI Provider Detection

Detect and configure external AI CLI tools (Codex, Gemini) for advisory delegation.

#### 3.8a. Detect Installed CLIs

Check for each CLI binary:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
CODEX_FOUND=false
GEMINI_FOUND=false

if command -v codex &>/dev/null; then
  CODEX_FOUND=true
  CODEX_VERSION=$(codex --version 2>&1 | head -1)
fi

if command -v gemini &>/dev/null; then
  GEMINI_FOUND=true
  GEMINI_VERSION=$(gemini --version 2>&1 | head -1)
fi
```

If NEITHER CLI is found, report: **"No external CLI tools detected (codex, gemini) — skipping provider setup"** and skip to Step 4.

#### 3.8b. Check Gemini Auth Method

If Gemini CLI is found, check the authentication method:

```bash
GEMINI_SETTINGS="${HOME}/.gemini/settings.json"
if [ -f "$GEMINI_SETTINGS" ]; then
  AUTH_TYPE=$(jq -r '.security.auth.selectedType // "unknown"' "$GEMINI_SETTINGS" 2>/dev/null)
fi
```

If `AUTH_TYPE` contains "oauth" and the `GEMINI_API_KEY` environment variable is NOT set, display a warning:

> **Warning**: Gemini CLI is using OAuth authentication. For headless delegation (when robro agents call Gemini automatically), `GEMINI_API_KEY` environment variable is recommended. OAuth may fail in non-interactive mode. Set `GEMINI_API_KEY` in your shell profile or `.env` file.

This is advisory only — do not block provider setup.

#### 3.8c. Check Existing Provider Config

Read `.robro/config.json` and check if `providers` section already exists:

1. Use the Read tool to read `${PROJECT_ROOT}/.robro/config.json`
2. If the file exists and has a `providers` key, check if the detected CLIs are already configured
3. A provider is "already configured" if it has an entry in `providers` with any value for `enabled`
4. Build a list of providers that need configuration (detected but not yet configured)

If all detected providers are already configured, report: **"All detected CLI providers already configured — no changes"** and skip to Step 4.

#### 3.8d. Present Provider Checklist

Build a status summary and present via AskUserQuestion with multiSelect:

```
External CLI providers detected:

[detected]           codex ({version}) — Code review, security audit, verification
[detected]           gemini ({version}) — Multimodal analysis, large context, UI review
[not found]          codex — Not installed
[already configured] gemini — Already in .robro/config.json

Select providers to enable:
```

Options should include each **detected but not yet configured** provider. Include a "Skip all" option.

#### 3.8e. Discover Models & Write Provider Config

Before writing provider presets, dynamically discover the current best model for each selected provider from local CLI cache files. This ensures the config always uses up-to-date model names.

**Step 1: Discover Codex model** (if Codex was selected)

Read the Codex CLI model cache file, which is auto-maintained by the CLI on startup:

```bash
CODEX_MODEL=$(jq -r '[.models[] | select(.visibility == "list")] | sort_by(.priority) | .[0].slug' "${HOME}/.codex/models_cache.json" 2>/dev/null)
```

If the cache file doesn't exist or the jq command fails (empty result), fall back to the plugin default:
```bash
if [ -z "$CODEX_MODEL" ]; then
  CODEX_MODEL="gpt-5.4"
  echo "Warning: Could not read ~/.codex/models_cache.json — using fallback model gpt-5.4"
fi
```

Report: **"Codex model: {CODEX_MODEL} (from ~/.codex/models_cache.json)"** or **"Codex model: gpt-5.4 (fallback — cache not found)"**

**Step 2: Discover Gemini model** (if Gemini was selected)

Read the default model from the Gemini CLI's installed npm package source:

```bash
GEMINI_MODEL=$(node -e "import('@google/gemini-cli-core/dist/src/config/models.js').then(m => console.log(m.DEFAULT_GEMINI_MODEL))" 2>/dev/null)
```

If the node command fails (package not found or import error), fall back:
```bash
if [ -z "$GEMINI_MODEL" ]; then
  GEMINI_MODEL="gemini-2.5-pro"
  echo "Warning: Could not read @google/gemini-cli-core models — using fallback model gemini-2.5-pro"
fi
```

Report: **"Gemini model: {GEMINI_MODEL} (from @google/gemini-cli-core)"** or **"Gemini model: gemini-2.5-pro (fallback — package not found)"**

**Step 3: Write provider config**

For each selected provider, merge the configuration into `.robro/config.json`:

1. Read the existing `.robro/config.json` content
2. If no `providers` key exists, add it as an empty object
3. For each selected provider, add the preset configuration using the **discovered model**:

**Codex preset** (uses `CODEX_MODEL` from Step 1):
```json
{
  "enabled": true,
  "binary": "codex",
  "model": "{CODEX_MODEL}",
  "approval_mode": "full-auto",
  "sandbox": true,
  "strengths": ["code-review", "security-audit", "verification", "reasoning"],
  "timeout_ms": 300000
}
```

**Gemini preset** (uses `GEMINI_MODEL` from Step 2):
```json
{
  "enabled": true,
  "binary": "gemini",
  "model": "{GEMINI_MODEL}",
  "approval_mode": "yolo",
  "thinking_level": "auto",
  "strengths": ["multimodal", "large-context", "ui-analysis", "second-opinion"],
  "timeout_ms": 300000
}
```

4. Write the updated config back using the Edit tool (preserve all existing content)

Report: **"Providers configured: {N} enabled"** with the list of enabled providers and their discovered models.

#### 3.8f. Idempotency

This step produces identical results on re-run:
- Already-configured providers are detected and skipped
- Running setup twice does not create duplicate entries
- Provider config is merged into existing `.robro/config.json`, preserving other fields

### Step 4: Completion Summary
Report all actions taken:
- CLAUDE.md: created/updated/unchanged
- MCPs/skills: installed count / already configured count / skipped count
- .gitignore: created/updated/unchanged
- Settings.json: created/updated/unchanged
- Config.json: created/skipped/unchanged
- Providers: configured count / already configured count / skipped count
