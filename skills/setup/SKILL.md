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
- User wants to build (use /robro:build instead)
</Do_Not_Use_When>

## Workflow

### Step 1: CLAUDE.md Section Management

Manage the robro-owned section inside `.claude/CLAUDE.md`. This section lives between HTML comment delimiters and is the only part of the file that robro reads or writes. All other content in the file is preserved untouched.

**Markers**: `<!-- robro:managed:start -->` and `<!-- robro:managed:end -->`

#### 1a. Load the template

Read the template content from the plugin's bundled file:

```
${CLAUDE_PLUGIN_ROOT}/skills/setup/claude-md-template.md
```

Use the Read tool to load this file. Store its content as `TEMPLATE_CONTENT` for comparison and insertion below.

#### 1b. Locate the project root and target file

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

The target file is `${PROJECT_ROOT}/.claude/CLAUDE.md`.

Check if the file exists using the Read tool. If the Read tool returns a "file does not exist" error, the file does not exist yet.

#### 1c. If `.claude/CLAUDE.md` does not exist

Create the `.claude/` directory if it does not already exist (use `mkdir -p`). Then create `.claude/CLAUDE.md` with the following content:

```
<!-- robro:managed:start -->
{TEMPLATE_CONTENT}
<!-- robro:managed:end -->
```

Report: **"Created new .claude/CLAUDE.md with robro section"**

Skip to Step 2.

#### 1d. If `.claude/CLAUDE.md` exists — find markers

Read the entire file content. Before searching for markers, identify any triple-backtick fenced code blocks (` ``` `) in the file. Markers that appear inside fenced code blocks must be ignored — they are documentation examples, not actual section delimiters.

Search the file content (outside of fenced code blocks) for `<!-- robro:managed:start -->`.

#### 1e. If no start marker found

The file exists but has no robro section yet. Append the robro section at the end of the file, preceded by a blank line:

```

<!-- robro:managed:start -->
{TEMPLATE_CONTENT}
<!-- robro:managed:end -->
```

Preserve all existing file content exactly as-is above the appended section.

Report: **"Added robro section to existing .claude/CLAUDE.md"**

Skip to Step 2.

#### 1f. If start marker found — check for end marker

Search (outside of fenced code blocks) for `<!-- robro:managed:end -->` after the start marker.

**If end marker is missing** (start marker exists without a matching end marker): Treat everything from the `<!-- robro:managed:start -->` line to the end of the file as the robro section. Replace from the start marker line to the end of the file with:

```
<!-- robro:managed:start -->
{TEMPLATE_CONTENT}
<!-- robro:managed:end -->
```

Report: **"Repaired robro section (missing end marker) in .claude/CLAUDE.md"**

Skip to Step 2.

#### 1g. If both markers found — check for duplicates

If multiple `<!-- robro:managed:start -->` / `<!-- robro:managed:end -->` pairs exist (outside of fenced code blocks), use the FIRST pair only. Warn the user:

> **Warning**: Found duplicate robro:managed marker pairs in .claude/CLAUDE.md. Using the first pair. Please manually remove the extra markers.

#### 1h. Compare and update

Extract the content between the first `<!-- robro:managed:start -->` and `<!-- robro:managed:end -->` markers. Compare it with `TEMPLATE_CONTENT`.

**If the existing content is identical to the template**: No changes needed.

Report: **"Robro section already current — no changes"**

Skip to Step 2.

**If the content differs**: Replace everything between the start and end markers (exclusive of the markers themselves) with `TEMPLATE_CONTENT`. Keep all content before the start marker and after the end marker untouched.

The updated block should be:

```
<!-- robro:managed:start -->
{TEMPLATE_CONTENT}
<!-- robro:managed:end -->
```

Report: **"Updated existing robro section in .claude/CLAUDE.md"**

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
2. Read `.mcp.json` at the project root (use the `PROJECT_ROOT` from Step 1b). Parse the JSON content and check if the `mcpServers` object contains a key matching the MCP name.
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
```bash
npx skills add vercel-labs/agent-browser --skill agent-browser
```

If the `npx skills add` command fails (non-zero exit code), report the error and provide manual install instructions as fallback:

> **agent-browser install failed.** You can install it manually:
> 1. Visit https://github.com/vercel-labs/agent-browser
> 2. Follow the installation instructions in the README
> 3. Or run: `claude plugin install agent-browser`

#### 2e. Report Results

After processing all items, report the summary:

**"{N} items installed, {M} already configured, {K} skipped by user"**

Where:
- N = number of items successfully installed in this step
- M = number of items that were already configured (detected in 2b)
- K = number of unconfigured items the user chose not to install (including "Skip all")

### Step 3: .gitignore Configuration
{To be implemented in Task 3.5}

### Step 4: Completion Summary
Report all actions taken:
- CLAUDE.md: created/updated/unchanged
- MCPs/skills: installed count / already configured count / skipped count
- .gitignore: created/updated/unchanged
