#!/usr/bin/env bash
# Sync version from plugin.json to marketplace.json
# Called by .githooks/pre-push or manually.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

PLUGIN_JSON="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
MARKETPLACE_JSON="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"

if [ ! -f "$PLUGIN_JSON" ]; then
  echo "Error: plugin.json not found at $PLUGIN_JSON" >&2
  exit 1
fi

if [ ! -f "$MARKETPLACE_JSON" ]; then
  echo "Error: marketplace.json not found at $MARKETPLACE_JSON" >&2
  exit 1
fi

PLUGIN_VERSION=$(jq -r '.version' "$PLUGIN_JSON")
MARKETPLACE_VERSION=$(jq -r '.plugins[0].version' "$MARKETPLACE_JSON")

if [ "$PLUGIN_VERSION" = "$MARKETPLACE_VERSION" ]; then
  exit 0
fi

jq --arg ver "$PLUGIN_VERSION" '.plugins[0].version = $ver' "$MARKETPLACE_JSON" > "${MARKETPLACE_JSON}.tmp"
mv "${MARKETPLACE_JSON}.tmp" "$MARKETPLACE_JSON"

echo "Synced marketplace.json version: ${MARKETPLACE_VERSION} -> ${PLUGIN_VERSION}"
git add "$MARKETPLACE_JSON" 2>/dev/null || true
