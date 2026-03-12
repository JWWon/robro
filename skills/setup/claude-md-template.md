## Robro Plugin

Robro extends Claude Code with a structured planning and execution pipeline.

### Pipeline

```
/robro:idea (PM) → idea.md → /robro:spec (EM) → plan.md + spec.yaml → /robro:build (Builder) → working code
```

### Available Skills

| Skill | Role | Description |
|-------|------|-------------|
| `/robro:idea` | Product Manager | Socratic interview that transforms vague ideas into structured requirements (idea.md). Uses ambiguity scoring with ≤ 0.1 threshold. |
| `/robro:spec` | Engineering Manager | Converts idea.md into phased implementation plan (plan.md) and validation checklist (spec.yaml). Multi-agent review loop. |
| `/robro:build` | Builder | Autonomously implements plan.md through evolutionary sprint cycles. Dispatches builder agents, runs peer review, evolves project knowledge. |
| `/robro:setup` | Setup | Configures project for robro: CLAUDE.md section, MCP/skill recommendations, .gitignore rules. |
| `/robro:clean-memory` | Cleanup | Analyzes completed plans for patterns, recommends improvements, then deletes confirmed plans. |

### Plan Artifacts

Plans live in `docs/plans/YYMMDD_{name}/`:
- `idea.md` — Product requirements from /robro:idea
- `plan.md` — Phased implementation tasks from /robro:spec
- `spec.yaml` — Validation checklist (source of truth for testing)
- `status.yaml` — Pipeline state (drives hooks, gitignored)

### Key Rules

- **Skills orchestrate, agents execute.** Only skills interact with the user.
- **No code without a spec.** Implementation requires plan.md + spec.yaml.
- **Status.yaml drives hooks.** All pipeline state is persisted to status.yaml at plan root.
- **Quality-driven iteration.** Review loops exit on passing verdicts, not arbitrary caps.

### Resuming Interrupted Work

If a pipeline was interrupted, robro auto-detects the state on session start. Check `status.yaml` in the active plan directory for current position.
