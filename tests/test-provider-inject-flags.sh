#!/usr/bin/env bash
# Verify the codex template in provider-inject.sh contains both --sandbox and --ephemeral
set -euo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/provider-inject.sh"

if grep -q "\-\-sandbox" "$SCRIPT" && grep -q "\-\-ephemeral" "$SCRIPT"; then
  echo "PASS: codex template contains both --sandbox and --ephemeral"
  exit 0
else
  echo "FAIL: codex template missing --sandbox or --ephemeral"
  grep "codex" "$SCRIPT" || true
  exit 1
fi
