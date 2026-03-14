#!/usr/bin/env bash
# Detect the project's package manager via lockfile presence, then CLI availability.
# Usage: detect-pkg-manager.sh [project_root]
# Output: one word to stdout — bun, pnpm, yarn, or npm
# Priority: bun > pnpm > yarn > npm (lockfile first, then CLI fallback)
# Standalone: does not depend on any other robro scripts.

set -euo pipefail

PROJECT_ROOT="${1:-.}"

# Phase 1: Lockfile detection (project-level signal)
if [ -f "${PROJECT_ROOT}/bun.lock" ] || [ -f "${PROJECT_ROOT}/bun.lockb" ]; then
  echo "bun"
  exit 0
fi

if [ -f "${PROJECT_ROOT}/pnpm-lock.yaml" ]; then
  echo "pnpm"
  exit 0
fi

if [ -f "${PROJECT_ROOT}/yarn.lock" ]; then
  echo "yarn"
  exit 0
fi

if [ -f "${PROJECT_ROOT}/package-lock.json" ]; then
  echo "npm"
  exit 0
fi

# Phase 2: CLI availability fallback (system-level signal)
if command -v bun >/dev/null 2>&1; then
  echo "bun"
  exit 0
fi

if command -v pnpm >/dev/null 2>&1; then
  echo "pnpm"
  exit 0
fi

if command -v yarn >/dev/null 2>&1; then
  echo "yarn"
  exit 0
fi

# Final fallback: npm (guaranteed by Node.js)
echo "npm"
