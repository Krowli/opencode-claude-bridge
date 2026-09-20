#!/usr/bin/env bash
#
# opencode-claude-bridge — smoke test
#
# 1) health probe, 2) model list, 3) one real completion (spawns the claude
# CLI, may take ~30s on first call).
#
# Usage: bash scripts/smoke-test.sh   (PORT=8787 by default)
set -euo pipefail

PORT="${PORT:-8787}"
BASE="http://127.0.0.1:$PORT"

echo "== 1/3 health =="
curl -sf --max-time 5 "$BASE/health" || { echo "proxy not reachable — is OpenCode running?"; exit 1; }
echo

echo "== 2/3 models =="
curl -sf --max-time 5 "$BASE/v1/models" | head -c 400
echo
echo

echo "== 3/3 real completion (model=sonnet) =="
curl -sfN --max-time 180 "$BASE/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"sonnet","messages":[{"role":"user","content":"Reply with exactly two words: proxy works"}]}' \
  | head -c 600
echo