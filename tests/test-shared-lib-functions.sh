#!/usr/bin/env bash
# Test: atomic_write() and truncate_build_progress() in load-config.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILURES=0
PASSES=0

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $1"
  PASSES=$((PASSES + 1))
}

LOAD_CONFIG="$REPO_ROOT/scripts/lib/load-config.sh"

# ===========================================================================
# atomic_write() tests
# ===========================================================================

(
  source "$LOAD_CONFIG"
  if type atomic_write &>/dev/null; then
    echo "__RESULT__:atomic_write_exists:yes"
  else
    echo "__RESULT__:atomic_write_exists:no"
  fi
) | while IFS= read -r line; do
  case "$line" in
    *atomic_write_exists:yes) pass "atomic_write function exists" ;;
    *atomic_write_exists:no) fail "atomic_write function not found" ;;
  esac
done

# Test: atomic_write writes content correctly
TMPFILE="/tmp/test-aw-$$.txt"
(
  source "$LOAD_CONFIG"
  echo "hello world" | atomic_write "$TMPFILE"
)
if [ -f "$TMPFILE" ] && [ "$(cat "$TMPFILE")" = "hello world" ]; then
  pass "atomic_write writes content correctly"
else
  fail "atomic_write did not write expected content"
fi
rm -f "$TMPFILE"

# Test: atomic_write overwrites existing file
TMPFILE="/tmp/test-aw-overwrite-$$.txt"
echo "old content" > "$TMPFILE"
(
  source "$LOAD_CONFIG"
  echo "new content" | atomic_write "$TMPFILE"
)
if [ "$(cat "$TMPFILE")" = "new content" ]; then
  pass "atomic_write overwrites existing file"
else
  fail "atomic_write did not overwrite existing file"
fi
rm -f "$TMPFILE"

# Test: atomic_write leaves no temp file behind
TMPFILE="/tmp/test-aw-clean-$$.txt"
(
  source "$LOAD_CONFIG"
  echo "clean" | atomic_write "$TMPFILE"
)
# Check no .tmp.* files remain
if ls "${TMPFILE}.tmp."* 2>/dev/null; then
  fail "atomic_write left temp files behind"
else
  pass "atomic_write leaves no temp files behind"
fi
rm -f "$TMPFILE"

# ===========================================================================
# truncate_build_progress() tests
# ===========================================================================

(
  source "$LOAD_CONFIG"
  if type truncate_build_progress &>/dev/null; then
    echo "__RESULT__:truncate_exists:yes"
  else
    echo "__RESULT__:truncate_exists:no"
  fi
) | while IFS= read -r line; do
  case "$line" in
    *truncate_exists:yes) pass "truncate_build_progress function exists" ;;
    *truncate_exists:no) fail "truncate_build_progress function not found" ;;
  esac
done

# Create test build-progress with 8 sprints
BP_FILE="/tmp/test-bp-$$.md"
cat > "$BP_FILE" << 'BPEOF'
# Build Progress

## Sprint 1
Sprint 1 content line 1
Sprint 1 content line 2

## Sprint 2
Sprint 2 content

## Sprint 3
Sprint 3 content

## Sprint 4
Sprint 4 content

## Sprint 5
Sprint 5 content

## Sprint 6
Sprint 6 content

## Sprint 7
Sprint 7 content

## Sprint 8
Sprint 8 content
BPEOF

# Test: truncate to last 5 sprints
RESULT=$(source "$LOAD_CONFIG" && truncate_build_progress "$BP_FILE" 5)
if echo "$RESULT" | grep -q "## Sprint 4" && \
   echo "$RESULT" | grep -q "## Sprint 8" && \
   ! echo "$RESULT" | grep -q "## Sprint 3"; then
  pass "truncate_build_progress returns last 5 sprints"
else
  fail "truncate_build_progress did not return expected sprints. Got: $RESULT"
fi

# Test: truncate with fewer sprints than max returns all
RESULT=$(source "$LOAD_CONFIG" && truncate_build_progress "$BP_FILE" 20)
SPRINT_COUNT=$(echo "$RESULT" | grep -c "## Sprint" || true)
if [ "$SPRINT_COUNT" -eq 8 ]; then
  pass "truncate_build_progress returns all sprints when max > actual"
else
  fail "truncate_build_progress with max>actual returned $SPRINT_COUNT sprints, expected 8"
fi

# Test: truncate on nonexistent file returns silently (no crash, no output)
RESULT=$(source "$LOAD_CONFIG" && truncate_build_progress "/tmp/nonexistent-$$" 5 2>&1 || true)
if [ -z "$RESULT" ]; then
  pass "truncate_build_progress handles missing file gracefully"
else
  fail "truncate_build_progress produced unexpected output on missing file: $RESULT"
fi

# Test: original file is not modified
ORIGINAL_LINES=$(wc -l < "$BP_FILE")
source "$LOAD_CONFIG" && truncate_build_progress "$BP_FILE" 3 > /dev/null
AFTER_LINES=$(wc -l < "$BP_FILE")
if [ "$ORIGINAL_LINES" -eq "$AFTER_LINES" ]; then
  pass "truncate_build_progress does not modify original file"
else
  fail "truncate_build_progress modified the original file"
fi

rm -f "$BP_FILE"

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "Results: $PASSES passed, $FAILURES failed"
if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi
