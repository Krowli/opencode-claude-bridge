#!/usr/bin/env bash
#
# opencode-claude-bridge — uninstaller
#
# Removes the proxy runtime and the OpenCode plugin. The provider entry
# in opencode.jsonc is left in place for you to remove manually.
#
# Usage: bash uninstall.sh [-y]
set -euo pipefail

PROXY_HOME="${PROXY_HOME:-$HOME/.local/share/opencode-claude}"
PLUGIN_DIR="${PLUGIN_DIR:-$HOME/.config/opencode/plugins}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/opencode}"

if [ "${1:-}" != "-y" ]; then
  read -r -p "Remove $PROXY_HOME and $PLUGIN_DIR/opencode-claude-proxy.ts? [y/N] " ans
  [[ "$ans" =~ ^[yY]$ ]] || { echo "aborted"; exit 0; }
fi

# Stop a running proxy (the plugin spawned it; send SIGTERM so it exits cleanly).
if pgrep -f "$PROXY_HOME/proxy.mjs" >/dev/null 2>&1; then
  pkill -f "$PROXY_HOME/proxy.mjs" 2>/dev/null || true
  sleep 1
fi

rm -rf "$PROXY_HOME"
rm -f "$PLUGIN_DIR/opencode-claude-proxy.ts"

echo "Removed. You can also drop provider 'claude-code' from $CONFIG_DIR/opencode.jsonc."