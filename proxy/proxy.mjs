#!/usr/bin/env bun
/**
 * Standalone Claude Agent SDK proxy for OpenCode V2.
 *
 * Bridges OpenAI-style POST /v1/chat/completions -> Claude Agent SDK ->
 * `claude` CLI (subscription OAuth). Accepts JSON and SSE streaming,
 * plus GET /v1/models and /health for probes.
 *
 * The proxy code lives in ./lib (ours; originally derived from MIT-licensed
 * code, see lib/LICENSE). Only official dependencies: the Claude Agent SDK
 * and zod, pinned exactly in package.json + package-lock.json.
 *
 * Auth note: `claude` 2.x stores OAuth in the macOS login keychain, so this
 * process must run inside the user's login session (spawned by the OpenCode
 * server via a plugin), NOT from launchd.
 */
import { homedir } from "node:os"

process.env.OPENCODE_CLAUDE_PROXY_PORT ??= "8787"
// Claude runs in the project directory the plugin sends per request; this is
// only the fallback for requests without it (OPENCODE_CLAUDE_CWD would
// override the per-request directory, so it is not set here).
process.chdir(homedir())

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
  "./lib/proxy.ts"
)

const port = await startProxy()
console.error(`[opencode-claude-proxy] listening on ${getClaudeProxyBaseUrl()}`)

// Keep the Bun process alive (the HTTP listener alone does not hold the loop).
setInterval(() => {}, 1 << 30)