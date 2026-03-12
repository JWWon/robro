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
