#!/usr/bin/env bash
#
# opencode-claude-bridge — installer
#
# Connects your Claude Max subscription (Claude Code CLI) to OpenCode V2
# through a local proxy. Everything is pinned and stays local — no
# auto-updates, no API key, credentials never leave the `claude` CLI.
#
# Usage:
#   bash install.sh                full install (defaults)
#   bash install.sh --dry-run      print the plan, change nothing
#   bash install.sh --no-config    do not touch opencode.jsonc
#
# Overrides (environment variables):
#   PROXY_HOME      where the proxy + pinned npm package live (default: ~/.local/share/opencode-claude)
#   CONFIG_DIR      OpenCode config directory (default: ~/.config/opencode)
#   PLUGIN_DIR      OpenCode plugins directory (default: $CONFIG_DIR/plugins)
#   OPENCODE_CONFIG path to opencode.jsonc (default: $CONFIG_DIR/opencode.jsonc)
#   BUN_BIN         Bun executable (default: resolved via command -v)
#   VERSION         pin of @openchamber/opencode-claude (default: 0.14.0)
#   PLUGIN_SDK      pin of @opencode/plugin (default: 2.0.10)
#
set -euo pipefail

HOME_dir="${HOME:?HOME is not set}"
PROXY_HOME="${PROXY_HOME:-$HOME_dir/.local/share/opencode-claude}"
CONFIG_DIR="${CONFIG_DIR:-$HOME_dir/.config/opencode}"
PLUGIN_DIR="${PLUGIN_DIR:-$CONFIG_DIR/plugins}"
OPENCODE_CONFIG="${OPENCODE_CONFIG:-$CONFIG_DIR/opencode.jsonc}"
BUN_BIN="${BUN_BIN:-$(command -v bun || true)}"
VERSION="${VERSION:-0.14.0}"
PLUGIN_SDK="${PLUGIN_SDK:-2.0.10}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
DO_CONFIG=1

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-config) DO_CONFIG=0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

c_grn=$'\033[32m'; c_yel=$'\033[33m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_rst=$'\033[0m'
say()  { printf '%s%s%s\n' "$c_grn" "$*" "$c_rst"; }
warn() { printf '%s%s%s\n' "$c_yel" "$*" "$c_rst" >&2; }
die()  { printf '%s%s%s\n' "$c_red" "$*" "$c_rst" >&2; exit 1; }

install_file() { # src dst
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%sdry-run:%s cp %s -> %s\n' "$c_dim" "$c_rst" "$1" "$2"
  else
    cp "$1" "$2"
  fi
}

emit() { # dst  ; payload on stdin
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%sdry-run:%s write %s\n' "$c_dim" "$c_rst" "$1"
    return 0
  fi
  cat > "$1"
}

npm_in() { # dir [extra args...]
  local dir="$1"; shift
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%sdry-run:%s (cd %s && npm install %s)\n' "$c_dim" "$c_rst" "$dir" "$*"
  else
    ( cd "$dir" && npm install "$@" --no-audit --no-fund )
  fi
}

# --- preflight -------------------------------------------------------------
[ -n "$BUN_BIN" ] || die "Bun not found. Install it: curl -fsSL https://bun.sh/install | bash"
if ! command -v claude >/dev/null 2>&1; then
  warn "claude CLI is not on PATH. Install Claude Code and sign in with: claude auth login"
elif [ "$DRY_RUN" -eq 0 ]; then
  if echo "$(claude auth status 2>/dev/null || true)" | grep -q '"loggedIn"[[:space:]]*:[[:space:]]*false'; then
    warn "claude reports: not logged in. Run: claude auth login"
  else
    say "claude auth: OK (subscription found)"
  fi
fi

# --- 1/4 proxy runtime (pinned npm package) --------------------------------
say ""
say "1/4  proxy runtime -> $PROXY_HOME  (@openchamber/opencode-claude@$VERSION, pinned)"
mkdir -p "$PROXY_HOME"
emit "$PROXY_HOME/package.json" <<EOF
{
  "name": "opencode-claude-proxy",
  "private": true,
  "dependencies": {
    "@openchamber/opencode-claude": "$VERSION"
  }
}
EOF
npm_in "$PROXY_HOME"

# --- 2/4 plugin SDK (needed to resolve 'import { Plugin } from "@opencode/plugin"')
say "2/4  plugin SDK -> $CONFIG_DIR/node_modules  (@opencode/plugin@$PLUGIN_SDK)"
mkdir -p "$CONFIG_DIR"
npm_in "$CONFIG_DIR" "@opencode/plugin@$PLUGIN_SDK"

# --- 3/4 integration files -------------------------------------------------
say "3/4  integration files"
install_file "$SCRIPT_DIR/proxy/proxy.mjs" "$PROXY_HOME/proxy.mjs"
[ "$DRY_RUN" -eq 1 ] || chmod +x "$PROXY_HOME/proxy.mjs"
mkdir -p "$PLUGIN_DIR"
sed -e "s|__PROXY_HOME__|$PROXY_HOME|g" -e "s|__BUN_BIN__|$BUN_BIN|g" \
  "$SCRIPT_DIR/plugin/opencode-claude-proxy.ts" \
  | emit "$PLUGIN_DIR/opencode-claude-proxy.ts"

# --- 4/4 provider config ---------------------------------------------------
if [ "$DO_CONFIG" -eq 1 ]; then
  say "4/4  provider 'claude-code' -> $OPENCODE_CONFIG"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%sdry-run:%s merge config/opencode.claude-code.json into %s\n' "$c_dim" "$c_rst" "$OPENCODE_CONFIG"
  else
    if node - "$OPENCODE_CONFIG" "$SCRIPT_DIR/config/opencode.claude-code.json" <<'NODE'
const fs = require("node:fs");
const [cfgPath, provPath] = process.argv.slice(2);
const source = fs.existsSync(cfgPath) ? fs.readFileSync(cfgPath, "utf8") : "{}";
// JSONC with comments cannot be safely rewritten -> ask the user to merge manually.
const body = source.replace(/"(?:\\.|[^"\\])*"/g, "");
if (/\/\/|\/\*/.test(body)) {
  console.error("merge_manual");
  process.exit(2);
}
const cfg = JSON.parse(source);
cfg.providers = cfg.providers || {};
if (cfg.providers["claude-code"]) {
  console.log("provider 'claude-code' already present — nothing to do");
  process.exit(0);
}
Object.assign(cfg.providers, JSON.parse(fs.readFileSync(provPath, "utf8")));
fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + "\n");
console.log("merged provider 'claude-code' into " + cfgPath);
NODE
    then
      :
    else
      warn "opencode.jsonc has comments (JSONC) — cannot merge automatically."
      warn "Add config/opencode.claude-code.json into providers manually, then restart."
    fi
  fi
else
  say "4/4  config merge skipped (--no-config). Merge config/opencode.claude-code.json manually."
fi

# --- summary ---------------------------------------------------------------
say ""
say "done. Next steps:"
echo "  1. Restart OpenCode (or wait for the config watcher to reload the plugin)."
echo "  2. Verify:  curl -s http://127.0.0.1:8787/health"
echo "  3. Smoke:   bash $SCRIPT_DIR/scripts/smoke-test.sh"
echo "  4. Try:     opencode run --model claude-code/sonnet \"hello\""
echo "Models: sonnet, opus, fable, haiku (each with effort variants low -> max)."