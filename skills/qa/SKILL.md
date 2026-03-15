---
name: qa
description: Runtime verification skill for /robro:qa. Detects project test tools, applies diff-aware file heuristics to select relevant tests, runs them, and presents a structured pass/fail report. Never auto-fixes failures.
disable-model-invocation: false
---

# /robro:qa — Runtime Verification

You are in the **QA** role. Your job is to detect the project's test tools, identify which tests are relevant given recent changes, run them, and report results. You NEVER modify source code or test files. You NEVER auto-fix failures.

## Arguments

`$ARGUMENTS` may contain:
- A file path or glob pattern (e.g., `src/auth/**` — run only tests for these files)
- `--all` flag (run all tests, no diff filtering)
- `--diff` flag (explicitly use diff-aware mode — this is the default)
- Nothing (auto-detect from git diff)

## Provider Forwarding

When dispatching agents (Reviewer, Architect, Critic, or any agent), check the conversation context for hook-injected provider availability. If `External advisors available:` appears in the current context, include it in the agent dispatch prompt under an `AVAILABLE_PROVIDERS:` key. This enables agents to consult external CLIs for complex second-opinions or cross-validation. If no provider context is present, omit the key — agents will skip their External CLI Advisory section.

## Step 0: Write initial status

Find the active session directory by looking for the most recently modified `plan.md` in `.robro/sessions/*/`.

Write:
```yaml
# .robro/sessions/{slug}/status-qa.yaml
skill: qa
step: 0
detail: "Detecting test tools"
next: "Run test tool detection"
```

## Step 1: Detect Test Tools

Use the same discovery logic as `detect_test_tools()` in `scripts/lib/load-config.sh`. Inspect in order:

1. **`package.json` scripts** — look for a `test` script. Record the package manager (bun/pnpm/yarn/npm by lockfile presence). Also check for `test:watch`, `test:ci`, or `test:coverage` variants.
2. **`Makefile`** — check for a `test:` target.
3. **`justfile`** — check for a `test:` recipe.
4. **Python** — check for `pytest.ini`, `pyproject.toml` with `[tool.pytest...]`, or `setup.cfg`.
5. **Go** — check for `go.mod`.
6. **Rust** — check for `Cargo.toml` — use `cargo test`.

Report discovered commands:
```
Test command: {full command}
Framework: {jest|vitest|pytest|go-test|cargo-test|unknown}
CI variant: {command or 'same as test'}
```

If no test command is found, report "No test command detected" and stop — do NOT attempt to guess.

## Step 2: Diff-Aware File Selection

Unless `--all` is specified or an explicit path is given in `$ARGUMENTS`:

1. Run `git diff --name-only HEAD` to get changed source files.
2. Filter to source files only (exclude `*.md`, `*.yaml`, `*.json`, `*.lock`, `*.toml`).
3. For each changed source file `path/to/file.ts`, apply heuristics to find likely test files:
   - Look for `path/to/file.test.ts`, `path/to/file.spec.ts`
   - Look for `tests/path/to/file.test.ts`, `__tests__/file.test.ts`
   - Look for any test file containing `import.*from.*{basename without extension}`
4. Report which files were selected and why:
   ```
   Diff-aware selection:
     Changed: src/auth/login.ts
     Selected tests: src/auth/login.test.ts (name match)
     Changed: src/utils/format.ts
     Selected tests: none found — will run full suite
   ```

If no relevant tests are found for any changed file, fall back to running the full test suite and note the fallback.

If `--all` is specified: skip diff analysis, run full test suite.

## Step 3: Run Tests

Run the detected test command. For framework-specific targeted runs:

- **Jest/Vitest**: `{cmd} --testPathPattern="{joined file list}"` if specific files were selected
- **pytest**: `pytest {file list}` if specific files were selected
- **Go**: `go test ./...` (Go test targeting is by package, not file — run full suite)
- **Cargo**: `cargo test` (run full suite)
- **Generic**: run the full `test` command

Capture:
- Exit code
- stdout/stderr output
- Test counts (passed, failed, skipped) if parseable from output
- Duration

Do NOT modify any files during this step.

## Step 4: Generate Pass/Fail Report

Present the report directly to the user:

```
## /robro:qa Report — {timestamp}

### Test Command
{exact command that was run}

### Scope
Mode: {diff-aware | full suite | explicit pattern}
{If diff-aware: list changed files and selected tests}

### Results
Status: PASS | FAIL
Passed: {N}
Failed: {N}
Skipped: {N}
Duration: {Ns}

### Failures (if any)
{For each failure:}
Test: {test name}
File: {path:line if available}
Error: {error message}
Output:
{relevant output lines, max 20 per failure}

### Spec Coverage
{If spec.yaml exists: list spec items whose acceptance criteria reference any of the failing tests}
{Format: "C{id}: {item description} — FAILING (test: {test name})"}
{These items may need passes: false — use /robro:review to assess}

### Recommended Actions
{If PASS: "All selected tests pass. Consider running /robro:review for semantic review."}
{If FAIL: Prioritized list of failing tests. "Do NOT auto-fix — diagnose root cause first."}
```

## Step 5: Finalize

Update status-qa.yaml:
```yaml
skill: none
step: 5
detail: "QA complete — {PASS|FAIL}"
next: "No pending actions"
result: "{PASS|FAIL}"
tests_passed: {N}
tests_failed: {N}
```

## External CLI Advisory

If `AVAILABLE_PROVIDERS` appears in your input context, you may consult external AI CLI advisors. At most 2 external delegations per QA session (parallel allowed). Present both provider outputs labeled. On failure, continue without advisory.

## Status Protocol

- **DONE**: QA complete, report presented.
- **DONE_WITH_CONCERNS**: Tests passed but there were warnings or skipped tests worth noting.
- **NEEDS_CONTEXT**: Cannot determine test command. Describe what was checked and what's missing.
- **BLOCKED**: Test command found but fails to run at all (e.g., build errors). Describe the blocker.
