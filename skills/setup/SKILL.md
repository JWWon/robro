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
{To be implemented in Task 3.3}

### Step 2: MCP/Skill Detection & Checklist
{To be implemented in Task 3.4}

### Step 3: .gitignore Configuration
{To be implemented in Task 3.5}

### Step 4: Completion Summary
Report all actions taken:
- CLAUDE.md: created/updated/unchanged
- MCPs/skills: installed count / already configured count / skipped count
- .gitignore: created/updated/unchanged
