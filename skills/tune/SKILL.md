---
name: tune
description: "Audit and optimize project Claude Code configuration (agents, skills, rules, CLAUDE.md, MCPs). Use when you want to review your project setup for gaps, stale items, or improvement opportunities. Not for initial setup (use /robro:setup) or build-cycle analysis (happens automatically in /robro:build)."
disable-model-invocation: true
---

# Tune — Project Configuration Audit

You are auditing a project's Claude Code configuration for gaps, stale items, and improvement opportunities.

**Input**: No arguments needed. Operates on the current project.

<Use_When>
- User says "tune", "audit config", "optimize setup", "review configuration", "check my setup"
- User wants to review their project's Claude Code configuration for effectiveness
- User wants to identify gaps or redundancies in their .claude/ setup
</Use_When>

<Do_Not_Use_When>
- User wants initial setup — use /robro:setup instead
- User wants to build/implement features — use /robro:build instead
- User wants to clean up completed plans — use /robro:clean-memory instead
- A build is in progress and user hasn't acknowledged the warning
</Do_Not_Use_When>

## Workflow

### Step 0: Active-Build Guard

Check for active builds that could conflict:

1. Scan `docs/plans/*/status.yaml` for any file where `skill: build` is set
2. If found, warn via AskUserQuestion:
   "A build is in progress ({plan directory}). Running /robro:tune during a build may conflict with level-up changes. Continue anyway?"
   Options: "Continue anyway", "Cancel — I'll run tune after the build"
3. If user cancels, stop. If user continues, proceed with caution noted.

### Step 1: Load Analysis Framework

Read `${CLAUDE_PLUGIN_ROOT}/skills/build/config-analysis-framework.md` for:
- Analysis dimensions (what to check for each config category)
- CONFIG_BASELINE format specification
- Comparison protocol
- Suggestion format (Operation/Type/Target/Evidence/Proposed Action)
- Cap rule (max 5 suggestions)
- Scope boundaries (project .claude/ only, never plugin root)

### Step 2: Scan Project Configuration

Scan the project's configuration:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
ls "$PROJECT_ROOT/.claude/agents/" 2>/dev/null
ls "$PROJECT_ROOT/.claude/skills/" 2>/dev/null
ls "$PROJECT_ROOT/.claude/rules/" 2>/dev/null
cat "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null
cat "$PROJECT_ROOT/.claude/CLAUDE.md" 2>/dev/null
cat "$PROJECT_ROOT/.mcp.json" 2>/dev/null
```

Read each discovered file to understand its content.

### Step 3: Produce CONFIG_BASELINE

Using the framework's baseline format, create a CONFIG_BASELINE structure:
- For each agent: name, path, one-line coverage summary
- For each skill: name, path, one-line coverage summary
- For each rule: name, path, one-line coverage summary
- For each CLAUDE.md section: heading, one-line coverage summary
- For each MCP: name, one-line coverage summary

### Step 4: Analyze Codebase & Git History

Gather signals from the codebase and git history:

```bash
# Recent activity patterns
git log --oneline -50
# File change frequency
git diff --stat HEAD~20 2>/dev/null
```

- Scan source files for recurring patterns (error handling, API calls, state management)
- Identify conventions followed implicitly but not formalized as rules
- Look for repeated patterns that could benefit from agent expertise or skill procedures

### Step 5: Compare Baseline vs Reality

Using the framework's comparison protocol:
- For each baseline item: is it still relevant? Is it sufficient for the current codebase?
- For codebase patterns without config coverage: what's missing?
- For config items with no codebase relevance: are they stale?

### Step 6: Generate Suggestions

Using the framework's suggestion format, generate up to 5 suggestions prioritized by evidence strength.

Each suggestion follows the format:

| Operation | Type | Target | Evidence | Proposed Action |
|-----------|------|--------|----------|-----------------|

**Data source acknowledgment**: This analysis uses static codebase and git history. For deeper insights informed by actual execution data, run a `/robro:build` sprint — the retro phase performs sprint-informed configuration analysis automatically.

**Optional retro ingestion**: If `docs/plans/*/discussion/retro-sprint-*.md` files exist, offer to incorporate findings from past retros for richer analysis.

### Step 7: Present Findings

Present findings via AskUserQuestion with multiSelect:

```json
{
  "questions": [{
    "question": "Configuration Audit Results:\n\nBaseline: {N} agents, {M} skills, {K} rules, {L} CLAUDE.md sections, {P} MCPs\n\nSuggestions:\n1. [{OP} {type}] {target} — {evidence}\n2. [{OP} {type}] {target} — {evidence}\n...\n\nSelect suggestions to apply:",
    "header": "Tune Results",
    "options": [
      {"label": "Suggestion 1", "description": "{OP} {type}: {brief}"},
      {"label": "Suggestion 2", "description": "{OP} {type}: {brief}"},
      {"label": "Skip all", "description": "No changes needed right now"}
    ],
    "multiSelect": true
  }]
}
```

If analysis finds no configuration gaps, use the framework's no-gaps format:

```
### Configuration Effectiveness
No gaps identified. Baseline: {N} agents, {M} skills, {K} rules. All items were relevant.
```

### Step 8: Execute Selected Suggestions

For each selected suggestion:
- **ADD**: Create the new file with appropriate content
- **UPDATE**: Edit the existing file with the proposed changes
- **REMOVE**: Delete the file after confirming identity

Only execute suggestions the user selected. If user chose "Skip all", proceed to Step 9 without changes.

### Step 9: MCP Recommendations

For any MCP gaps identified, recommend `/robro:setup` for installation instead of installing directly. Tune detects; setup installs.
