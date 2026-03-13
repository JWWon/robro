# Level-up Phase — Detailed Instructions

The Level-up phase evolves the spec and the project's knowledge base. It applies spec mutations from the retro, flips passes for verified items, and creates or updates project-scoped agents, skills, and rules.

## Step-by-Step

### 1. Apply Spec Mutations (D3: ADD or SUPERSEDE only)

For each Proposed Mutation from the retro report:

#### ADD Operation
1. Generate a new C-id (next sequential number)
2. Add the item to spec.yaml with `passes: false`
3. Associate it with the correct section and phase
4. Append to `spec-mutations.log`:
   ```
   {ISO-timestamp}	SPRINT:{N}	ADD	checklist.{new-id}	"{description}"	REASON: {rationale from retro}
   ```

#### SUPERSEDE Operation
1. In spec.yaml, add to the original item: `status: superseded` and `superseded_by: {new-C-id}`
2. Add the replacement item with `passes: false`
3. Append to `spec-mutations.log`:
   ```
   {ISO-timestamp}	SPRINT:{N}	SUPERSEDE	checklist.{old-id}	"superseded_by: {new-id}"	REASON: {rationale}
   ```

#### Validation Rules
- Never ADD an item that duplicates an existing non-superseded item
- Never SUPERSEDE an already-superseded item
- Every ADD must reference an existing section (S-id)
- Log EVERY mutation — no silent changes

### 2. Flip Passes for Verified Items

For each flip candidate from the Review phase:
1. Change `passes: false` to `passes: true` in spec.yaml
2. Append to `spec-mutations.log`:
   ```
   {ISO-timestamp}	SPRINT:{N}	FLIP	checklist.{id}	passes:true	REASON: Passed 3-stage review
   ```

### 3. Execute 5-Step Level-up Flow

For each Proposed Level-up from the retro report:

#### Step a: Analyze
- Read the retro report's Emerged Patterns and Knowledge Gaps sections
- Determine what kind of knowledge this represents
- Is it a persona (WHO — expertise, behavior)? -> Agent candidate
- Is it a procedure (WHAT/HOW — steps, gates, checklists)? -> Skill candidate
- Is it a simple constraint (convention, fact)? -> Rule candidate

#### Step b: Search Community References
Search live at runtime for existing implementations:

Use WebSearch to find existing agents/skills that match the identified pattern:

```
WebSearch("site:github.com ComposioHQ/awesome-claude-skills {pattern_name}")
WebSearch("site:github.com wshobson/agents {pattern_name}")
WebSearch("{pattern_name} claude code agent OR skill")
```

If a result is found, use WebFetch to read the raw markdown:
```
WebFetch("https://raw.githubusercontent.com/{owner}/{repo}/main/{path_to_file}")
```

Parse the fetched content for: frontmatter structure, prompt patterns, workflow steps.

If a match is found: adapt the existing pattern rather than creating from scratch.
If search fails (network error, timeout): proceed to create from scratch and log the fallback to build-progress.md.

#### Step c: Check Existing Project Files
```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
# Check for overlapping agents
ls "$PROJECT_ROOT/.claude/agents/" 2>/dev/null
# Check for overlapping skills
ls "$PROJECT_ROOT/.claude/skills/" 2>/dev/null
# Check CLAUDE.md for existing rules
cat "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null | head -100
cat "$PROJECT_ROOT/.claude/CLAUDE.md" 2>/dev/null | head -100
```

If an existing file covers similar ground: UPDATE it rather than creating a duplicate.

#### Step d: Decide Type
Apply the taxonomy:
- **Agent** = Persona: Has expertise domain, behavioral traits, response methodology. Gets own context window. Is stateless. Description ends with activation trigger.
- **Skill** = Knowledge package: Step-by-step procedures, checklists, gates, anti-patterns. Encodes non-obvious knowledge. Owns workflows.
- **Rule** = Simple constraint: One-liner conventions. Added to CLAUDE.md or .claude/ rules.

#### Step e: Create OR Update

**For Agents** — create at `{PROJECT_ROOT}/.claude/agents/{name}.md`:
```markdown
---
name: {name}
description: {what it does}. Use PROACTIVELY for {activation trigger}.
---

{System prompt body with rules, protocol, and output format}
```

**For Skills** — create at `{PROJECT_ROOT}/.claude/skills/{name}/SKILL.md`:
```markdown
---
name: {name}
description: {when and why to use this skill}
---

{Structured workflow with steps, gates, and anti-patterns}
```

**For Rules** — append to `{PROJECT_ROOT}/CLAUDE.md` or `{PROJECT_ROOT}/.claude/CLAUDE.md`:
```markdown
## {Rule Category}
- {Convention or constraint}
```

**REMOVE** — If the proposal operation is REMOVE (stale or redundant configuration):
1. Verify the target file exists at the specified path
2. Read the file to confirm it matches the described identity (name, type, purpose)
3. Log the file's full content to build-progress.md (enables rollback if needed)
4. Delete the file
5. If the file was a skill directory (`SKILL.md` + supporting files), remove the entire directory
6. Log the removal: `REMOVED: {path} — {reason}`

### 4. Quality Gate (D7)

For every file created or updated:

1. **Convention validation**: Verify the file follows Claude Code plugin conventions:
   - Agents: YAML frontmatter with `name`, `description` + system prompt body
   - Skills: YAML frontmatter with `name`, `description` + SKILL.md format
   - Rules: Valid markdown appended to the right file
2. **Naming conflict check**: Ensure no naming collision with existing plugin files or built-in Claude Code commands
3. **Syntax check**: For markdown files, verify frontmatter is valid YAML

If validation fails: revert the file and log the failure.

### 5. Rollback Manifest (D7)

Maintain `discussion/levelup-manifest.yaml` tracking all level-up actions:

```yaml
sprint_1:
  - action: CREATE
    type: rule
    path: ".claude/CLAUDE.md"
    description: "Added API error wrapper convention"
    timestamp: "2026-03-13T14:30:00Z"
sprint_2:
  - action: UPDATE
    type: agent
    path: ".claude/agents/auth-specialist.md"
    description: "Enhanced with OAuth2 PKCE flow knowledge"
    timestamp: "2026-03-14T10:15:00Z"
  - action: CREATE
    type: skill
    path: ".claude/skills/drizzle-migration/SKILL.md"
    description: "Formalized Drizzle migration procedure"
    timestamp: "2026-03-14T10:20:00Z"
  - action: REMOVE
    path: ".claude/rules/legacy-api-wrapper.md"
    previous_content: "{full content of deleted file}"
    reason: "Rule superseded by error-handling agent; no longer referenced"
    timestamp: "2026-03-14T10:25:00Z"
```

This manifest enables rollback if created files cause issues.

### 6. Log and Transition

Append to build-progress.md:
```markdown
## Sprint {N} — Level-up — {timestamp}
- Mutations applied: {count} (ADD: {n}, SUPERSEDE: {n}, FLIP: {n})
- Level-ups: {count} (agent: {n}, skill: {n}, rule: {n}, removed: {n})
- Files: {list of created/updated/removed paths}
```

Update status.yaml:
```yaml
skill: do
sprint: {N}
phase: converge
step: "1"
detail: "Running convergence checks"
next: "Evaluate 5 convergence gates and pathology detection"
```
