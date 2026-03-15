#!/usr/bin/env bash
set -euo pipefail
CONFIG="$(cd "$(dirname "$0")/.." && pwd)/config.json"

pass=0; fail=0

check() {
  local name="$1" result="$2"
  if [ "$result" = "true" ]; then
    echo "PASS: $name"; pass=$((pass+1))
  else
    echo "FAIL: $name"; fail=$((fail+1))
  fi
}

gemini_model=$(jq -r '.providers.gemini.model' "$CONFIG")
check "gemini_model_is_3.1_pro" "$([ "$gemini_model" = "gemini-3.1-pro" ] && echo true || echo false)"

has_critical_thinking=$(jq -r '.providers.codex.strengths | contains(["critical-thinking"])' "$CONFIG")
check "codex_has_critical_thinking_strength" "$has_critical_thinking"

has_code_analysis=$(jq -r '.providers.codex.strengths | contains(["code-analysis"])' "$CONFIG")
check "codex_has_code_analysis_strength" "$has_code_analysis"

echo ""; echo "Results: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
