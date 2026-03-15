#!/usr/bin/env bash
# Shared config loader for robro hook scripts.
# Source this file: source "${SCRIPT_DIR}/lib/load-config.sh"
#
# Constants:
#   SESSIONS_DIR  — path to session artifacts (.robro/sessions)
#   CONFIG_FILE   — path to project config.json (.robro/config.json)
#
# Functions:
#   robro_config          — read config values with defaults
#   get_mtime             — cross-platform file modification time
#   status_field          — extract field from simple YAML file
#   find_latest_session   — find most recent session file, optionally filtered
#   spec_counts           — count spec.yaml items (total passed superseded)
#   has_artifact          — check if any session has a specific file
#   robro_providers       — enumerate enabled+installed external CLI providers

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
export PROJECT_ROOT
SESSIONS_DIR="${PROJECT_ROOT}/.robro/sessions"
CONFIG_FILE="${PROJECT_ROOT}/.robro/config.json"

# Read a value from .robro/config.json with a default fallback.
# Usage: robro_config <jq_path> <default_value>
robro_config() {
  local jq_path="$1"
  local default_val="$2"
  if [ -f "$CONFIG_FILE" ]; then
    local val
    val=$(jq -r "$jq_path // empty" "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$val" ]; then
      echo "$val"
      return
    fi
  fi
  echo "$default_val"
}

# Cross-platform file modification time (epoch seconds).
get_mtime() {
  if stat -f %m "$1" >/dev/null 2>&1; then
    stat -f %m "$1"
  else
    stat -c %Y "$1"
  fi
}

# Extract a field value from a simple YAML file (top-level scalar fields only).
# Usage: skill=$(status_field "$file" "skill")
status_field() {
  grep "^${2}:" "$1" 2>/dev/null | head -1 | sed "s/^${2}: *//; s/\"//g"
}

# Find most recent file with given name in sessions dir.
# Optional filter: only return files where a YAML field matches a value.
# Usage: find_latest_session "status.yaml"
#        find_latest_session "status.yaml" "skill" "do"
find_latest_session() {
  local filename="$1" filter_field="${2:-}" filter_value="${3:-}"
  local latest_mtime=0 result=""

  [ -d "$SESSIONS_DIR" ] || return 1

  for dir in "$SESSIONS_DIR"/*/; do
    [ -d "$dir" ] || continue
    local candidate="${dir}${filename}"
    [ -f "$candidate" ] || continue

    if [ -n "$filter_field" ]; then
      local val
      val=$(status_field "$candidate" "$filter_field")
      [ "$val" = "$filter_value" ] || continue
    fi

    local mtime
    mtime=$(get_mtime "$candidate")
    if [ "$mtime" -gt "$latest_mtime" ]; then
      latest_mtime=$mtime
      result=$candidate
    fi
  done

  [ -n "$result" ] && echo "$result"
}

# Find the most recent per-workflow status file for a given skill name.
# Per-workflow files are named "status-{skill}.yaml" at session root.
# Usage: find_workflow_status "do"
#        find_workflow_status "review"
find_workflow_status() {
  local skill="$1"
  find_latest_session "status-${skill}.yaml"
}

# Detect the project test command by inspecting common config files.
# Checks package.json scripts, Makefile, justfile, and language-specific files.
# Outputs lines of "key:value" pairs, e.g. "npm:npm test" and "framework:jest"
# Returns exit code 1 if no test command is found.
detect_test_tools() {
  local project_root
  project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

  # 1. Check package.json (highest priority — most projects use it)
  local pkg_json="${project_root}/package.json"
  if [ -f "$pkg_json" ]; then
    local test_script
    test_script=$(jq -r '.scripts.test // empty' "$pkg_json" 2>/dev/null)
    if [ -n "$test_script" ]; then
      # Detect package manager
      local pm="npm"
      [ -f "${project_root}/bun.lockb" ] || [ -f "${project_root}/bun.lock" ] && pm="bun"
      [ -f "${project_root}/pnpm-lock.yaml" ] && pm="pnpm"
      [ -f "${project_root}/yarn.lock" ] && pm="yarn"
      echo "${pm}:${pm} test"

      # Detect test framework for reporting
      if echo "$test_script" | grep -qiE "jest|vitest|mocha|jasmine"; then
        local framework
        framework=$(echo "$test_script" | grep -oiE "jest|vitest|mocha|jasmine" | head -1 | tr '[:upper:]' '[:lower:]')
        echo "framework:${framework}"
      fi
      return 0
    fi
  fi

  # 2. Check Makefile for a "test" target
  if [ -f "${project_root}/Makefile" ]; then
    if grep -q "^test:" "${project_root}/Makefile" 2>/dev/null; then
      echo "make:make test"
      return 0
    fi
  fi

  # 3. Check justfile for a "test" recipe
  if [ -f "${project_root}/justfile" ]; then
    if grep -q "^test:" "${project_root}/justfile" 2>/dev/null; then
      echo "just:just test"
      return 0
    fi
  fi

  # 4. Check for Python test runners
  if [ -f "${project_root}/pytest.ini" ] || [ -f "${project_root}/pyproject.toml" ]; then
    if command -v pytest > /dev/null 2>&1; then
      echo "pytest:pytest"
      echo "framework:pytest"
      return 0
    fi
  fi

  # 5. Check for Go tests
  if [ -f "${project_root}/go.mod" ]; then
    echo "go:go test ./..."
    echo "framework:go-test"
    return 0
  fi

  # 6. Check for Rust tests
  if [ -f "${project_root}/Cargo.toml" ]; then
    echo "cargo:cargo test"
    echo "framework:cargo-test"
    return 0
  fi

  # No test command found
  return 1
}

# Count spec.yaml items. Echoes "total passed superseded".
# Usage: read total passed superseded <<< "$(spec_counts "$spec_file")"
spec_counts() {
  local total passed superseded
  total=$(grep -c "passes:" "$1" 2>/dev/null || echo "0")
  passed=$(grep -c "passes: true" "$1" 2>/dev/null || echo "0")
  superseded=$(grep -c "status: superseded" "$1" 2>/dev/null || echo "0")
  echo "$total $passed $superseded"
}

# Check if any session has a specific artifact file.
# Usage: if has_artifact "spec.yaml"; then ...
has_artifact() {
  [ -d "$SESSIONS_DIR" ] || return 1
  for dir in "$SESSIONS_DIR"/*/; do
    [ -f "${dir}${1}" ] && return 0
  done
  return 1
}

# Enumerate enabled external CLI providers whose binaries are on PATH.
# Reads from .robro/config.json first, falls back to plugin config.json.
# Outputs one line per available provider: "name:model:timeout_ms"
# Usage: while IFS=: read -r name model timeout_ms; do ...; done < <(robro_providers)
robro_providers() {
  local config_sources=("$CONFIG_FILE")
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/config.json" ] && \
    config_sources+=("${CLAUDE_PLUGIN_ROOT}/config.json")

  local providers_json=""
  for src in "${config_sources[@]}"; do
    [ -f "$src" ] || continue
    providers_json=$(jq -r '.providers // empty' "$src" 2>/dev/null)
    [ -n "$providers_json" ] && break
  done

  [ -z "$providers_json" ] && return 0

  echo "$providers_json" | jq -r '
    to_entries[]
    | select(.value.enabled == true)
    | "\(.key):\(.value.binary // .key):\(.value.model // ""):\(.value.timeout_ms // 300000)"
  ' 2>/dev/null | while IFS=: read -r name binary model timeout_ms; do
    command -v "$binary" > /dev/null 2>&1 && echo "${name}:${model}:${timeout_ms}"
  done
}

# Atomic file write: write stdin to temp file, then rename.
# Usage: echo "content" | atomic_write "/path/to/file"
atomic_write() {
  local target="$1"
  local tmp="${target}.tmp.$$"
  cat > "$tmp"
  mv -f "$tmp" "$target"
}

# Extract last N sprint sections from build-progress.md for injection.
# Full file is preserved on disk — only the output is truncated.
# Usage: truncate_build_progress "/path/to/build-progress.md" 5
truncate_build_progress() {
  local file="$1"
  local max_sprints="${2:-5}"
  [ -f "$file" ] || return
  awk -v max="$max_sprints" '
    /^## Sprint/ { sections[++count] = "" }
    count > 0 { sections[count] = sections[count] $0 "\n" }
    END {
      start = count - max + 1
      if (start < 1) start = 1
      for (i = start; i <= count; i++) printf "%s", sections[i]
    }
  ' "$file"
}
