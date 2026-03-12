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
{To be implemented in Task 3.4}

### Step 3: .gitignore Configuration
{To be implemented in Task 3.5}

### Step 4: Completion Summary
Report all actions taken:
- CLAUDE.md: created/updated/unchanged
- MCPs/skills: installed count / already configured count / skipped count
- .gitignore: created/updated/unchanged
