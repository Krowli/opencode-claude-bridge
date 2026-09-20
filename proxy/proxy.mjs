#!/usr/bin/env bun
/**
 * Standalone Claude Agent SDK proxy for OpenCode V2.
 *
 * Bridges OpenAI-style POST /v1/chat/completions -> Claude Agent SDK ->
 * `claude` CLI (subscription OAuth). Accepts JSON and SSE streaming,
 * plus GET /v1/models and /health for probes.
 *
 * The proxy code comes from the pinned, audited copy of
 * @openchamber/opencode-claude@0.14.0 (vendored, no auto-updates).
 *
 * Auth note: `claude` 2.x stores OAuth in the macOS login keychain, so this
 * process must run inside the user's login session (spawned by the OpenCode
 * server via a plugin), NOT from launchd.
 */
import { homedir } from "node:os"

process.env.OPENCODE_CLAUDE_PROXY_PORT ??= "8787"
process.env.OPENCODE_CLAUDE_CWD ??= homedir()

const PORT = process.env.OPENCODE_CLAUDE_PROXY_PORT

// If a healthy proxy already listens on the pinned port (e.g. spawned by an
// earlier server instance that crashed), don't start a second listener —
// just exit. The existing instance keeps serving.
try {
  const res = await fetch(`http://127.0.0.1:${PORT}/health`, {
    signal: AbortSignal.timeout(1500),
  })
  if (res.ok) {
    const body = await res.json()
    if (body?.ok === true) {
      console.error(
        `[opencode-claude-proxy] already healthy on port ${PORT} — exiting`
      )
      process.exit(0)
    }
  }
} catch {}

const { startProxy, getClaudeProxyBaseUrl } = await import(
  "./node_modules/@openchamber/opencode-claude/dist/proxy.js"
)

const port = await startProxy()
console.error(`[opencode-claude-proxy] listening on ${getClaudeProxyBaseUrl()}`)

// Keep the Bun process alive (the HTTP listener alone does not hold the loop).
setInterval(() => {}, 1 << 30)