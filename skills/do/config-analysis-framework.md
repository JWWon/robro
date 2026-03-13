# Configuration Analysis Framework

Shared reference document for structured configuration effectiveness analysis. Consumed by the retro-analyst agent (during build sprints) and the `/robro:tune` skill (for standalone audits).

## 1. Analysis Dimensions

Five categories of project configuration to evaluate:

### Agents
- **What to check**: What personas exist in `.claude/agents/`? Are they activated (referenced by skills or auto-invoked)? Were they relevant to the tasks executed? Did their expertise match what builders needed?
- **Gap signals**: Builders repeatedly looked up domain knowledge that an agent should have provided. A builder needed expertise (e.g., OAuth2 PKCE, database migrations) that no existing agent covers.
- **Staleness signals**: An agent exists but was never relevant across multiple sprints. Its domain no longer applies to the project.

### Skills
- **What to check**: What procedures are encoded in `.claude/skills/`? Were they used during the sprint? Did they cover the workflows builders followed? Any implicit procedures that should be formalized?
- **Gap signals**: Builders followed a multi-step procedure repeatedly without a skill encoding it. A common workflow (e.g., "add a new API endpoint") has no corresponding skill.
- **Staleness signals**: A skill encodes a procedure for a deprecated tool or framework version.

### Rules
- **What to check**: What conventions are enforced in `.claude/rules/` and CLAUDE.md rule sections? Were they followed during implementation? Were violations caught? Are there implicit conventions not yet formalized?
- **Gap signals**: Builders used inconsistent patterns across tasks (e.g., 3 different error handling approaches). A convention emerged naturally but has no rule enforcing it.
- **Staleness signals**: A rule references a tool, library, or pattern no longer used in the project.

### CLAUDE.md
- **What to check**: What project context is documented in the project's `CLAUDE.md` and `.claude/CLAUDE.md`? Is the documented context current and accurate? Are there important project aspects not yet documented?
- **Gap signals**: Builders needed project context (architecture decisions, environment setup, key patterns) that was not in CLAUDE.md. New patterns established during implementation are not reflected.
- **Staleness signals**: CLAUDE.md describes patterns, dependencies, or architecture that no longer match the codebase.

### MCPs
- **What to check**: What MCP integrations are configured in `.mcp.json` or equivalent? Were they needed during the sprint? Are there missing integrations that would have helped?
- **Gap signals**: Builders needed external tool access (database, API, monitoring) that no configured MCP provides. Tasks required manual workarounds for missing integrations.
- **Staleness signals**: An MCP is configured but the service it connects to is no longer used.

## 2. Baseline Format

Capture the project's current configuration state using this structured format:

```yaml
CONFIG_BASELINE:
  agents:
    - name: "{name}"
      path: "{path}"
      covers: "{what patterns/expertise this agent provides}"
      relevant_tasks: ["{task IDs where this agent's domain applies}"]
  skills:
    - name: "{name}"
      path: "{path}"
      covers: "{what procedures this skill encodes}"
      relevant_tasks: ["{task IDs}"]
  rules:
    - name: "{name}"
      path: "{path}"
      covers: "{what conventions this rule enforces}"
      relevant_tasks: ["{task IDs}"]
  claude_md:
    - section: "{section heading}"
      covers: "{what context this section provides}"
      relevant_tasks: ["{task IDs}"]
  mcps:
    - name: "{name}"
      covers: "{what integration this provides}"
      relevant_tasks: ["{task IDs}"]
```

**Field descriptions**:
- `name`: Identifier from the file or config entry (e.g., "github" from `.claude/rules/github.md`)
- `path`: Relative path from project root (e.g., `.claude/rules/github.md`)
- `covers`: One-line summary of what this item provides (e.g., "commit conventions, branch workflow, gh CLI usage")
- `relevant_tasks`: Task IDs from the sprint where this item's domain applies. Populated during brief phase step 5 (execution trace annotation). Empty list `[]` if no tasks match.

**When to capture**: The brief phase captures this baseline at the start of each sprint. The `/robro:tune` skill captures it at the start of each audit.

## 3. Comparison Protocol

Compare the baseline against sprint reality (or codebase reality for `/robro:tune`) using three lenses:

### Lens A: Relevance and Sufficiency
For each baseline item:
1. **Was it relevant?** Did any task in the sprint touch its domain? Check the `relevant_tasks` field.
2. **Was it sufficient?** For relevant items, did it provide enough guidance? Look for:
   - Builder outputs that cite the item as helpful (sufficient)
   - Builder errors or repeated lookups in the item's domain (insufficient)
   - Convention violations in the item's domain (insufficient)
3. **Evidence**: Cite specific file paths, error messages, or builder task outputs.

### Lens B: Uncovered Patterns
For patterns that emerged during the sprint without configuration coverage:
1. **What convention, rule, or expertise is missing?** Identify the gap.
2. **How many times did it occur?** Count occurrences across tasks.
3. **What was the impact?** Did it cause errors, inconsistency, or wasted effort?
4. **Evidence**: Cite specific files, code patterns, or builder notes.

### Lens C: Stale Configuration
For baseline items that were never relevant:
1. **Was the item's domain exercised at all?** Check if any task touched related files or patterns.
2. **Is the item outdated?** Does it reference deprecated tools, removed files, or changed patterns?
3. **How long has it been irrelevant?** Check across previous sprint data if available.
4. **Evidence**: Cite the item's content vs current codebase state.

**Important**: Not every irrelevant item is stale. An agent for database migrations is not stale just because the current sprint did not touch migrations. Look for positive evidence of staleness (references to removed things), not merely absence of use.

## 4. Suggestion Format

Present findings as actionable, evidence-based suggestions:

| Operation | Type | Target | Evidence | Proposed Action |
|-----------|------|--------|----------|-----------------|
| ADD | rule | .claude/rules/{name}.md | Builders used 3 different error patterns in src/api/*.ts (sprint data: task 2.1 and 2.3) | Create rule enforcing withApiError() wrapper |
| UPDATE | agent | .claude/agents/{name}.md | Agent X lacked OAuth2 PKCE knowledge needed for task 3.1 | Add PKCE flow to agent expertise |
| REMOVE | rule | .claude/rules/{name}.md | Rule Y about import ordering is redundant with ESLint config at .eslintrc | Remove -- linter handles this |

**Column definitions**:
- **Operation**: `ADD` (create new config item), `UPDATE` (enhance existing item), `REMOVE` (delete stale/redundant item)
- **Type**: `agent`, `skill`, `rule`, `claude_md`, `mcp`
- **Target**: File path relative to project root, or MCP name for MCP suggestions
- **Evidence**: Concrete sprint/codebase data supporting the suggestion. Must include file paths, pattern counts, or error references. Never vague ("things could be better").
- **Proposed Action**: Specific action to take. For ADD: what the new file should contain. For UPDATE: what to change. For REMOVE: why it is safe to remove.

**For MCP suggestions**: Operation is always `ADD` (detection only). The Proposed Action should recommend running `/robro:setup` for installation rather than specifying installation steps.

## 5. Cap Rule

**Maximum 5 suggestions per analysis.** When more than 5 potential suggestions exist, prioritize by:

1. **Evidence strength**: Number of occurrences and tasks affected. A pattern appearing in 4 tasks ranks higher than one in 1 task.
2. **Impact severity**: Suggestions preventing errors or inconsistency rank higher than nice-to-haves.
3. **Actionability**: Suggestions with clear, concrete proposed actions rank higher than vague improvements.

Discard lower-priority suggestions entirely rather than including them as honorable mentions. The cap prevents level-up overload (each suggestion goes through the 5-step level-up flow including community reference search).

## 6. No-Gaps Format

When analysis finds no configuration gaps, use this compact format instead of the full suggestion table:

```markdown
### Configuration Effectiveness
No gaps identified. Baseline: {N} agents, {M} skills, {K} rules. All items were relevant during sprint.
```

This section is still **mandatory** in every retro report and every tune audit. The compact format signals that analysis was performed and found the configuration adequate -- not that analysis was skipped.

## 7. Scope Boundaries

**Suggestions target the project's `.claude/` directory and CLAUDE.md only.**

Specifically, suggestions may target:
- `{PROJECT_ROOT}/.claude/agents/*.md`
- `{PROJECT_ROOT}/.claude/skills/*/SKILL.md`
- `{PROJECT_ROOT}/.claude/rules/*.md`
- `{PROJECT_ROOT}/.claude/CLAUDE.md`
- `{PROJECT_ROOT}/CLAUDE.md`
- MCP configuration files (`.mcp.json` or equivalent) -- detection only, recommend `/robro:setup` for changes

**Never suggest changes to plugin-provided files.** Anything under `${CLAUDE_PLUGIN_ROOT}` (the robro plugin directory) is owned by the plugin and must not be modified by configuration analysis. This includes:
- Plugin agents (`${CLAUDE_PLUGIN_ROOT}/agents/`)
- Plugin skills (`${CLAUDE_PLUGIN_ROOT}/skills/`)
- Plugin hooks (`${CLAUDE_PLUGIN_ROOT}/hooks/`)
- Plugin scripts (`${CLAUDE_PLUGIN_ROOT}/scripts/`)

If analysis reveals a gap that only a plugin change could address, note it in the retro report as an observation but do not include it as an actionable suggestion.
