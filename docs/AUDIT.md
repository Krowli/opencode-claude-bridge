# Security audit — proxy (`proxy/lib`)

The proxy code lives in this repo (`proxy/lib/*.ts`, ~4 500 lines, run by Bun).
It was taken in as source from MIT-licensed code (notice kept in
`proxy/lib/LICENSE`, as the license requires) and is maintained here; nothing
is downloaded from that project at install or run time. Only the files the
proxy actually imports were taken — no OpenCode plugin, no CLI installer, no
CLI sign-in flow.

## Findings (2026-09-27)

| Check | Result |
| --- | --- |
| Network endpoints in code | None besides `http://127.0.0.1` (the proxy itself). Model traffic goes through the official Agent SDK → `claude` CLI. |
| Inbound requests | Bound to 127.0.0.1; requests with an `Origin` header or a non-loopback `Host` are refused (`isTrustedLocalRequest`), so a web page cannot spend the subscription via CSRF/DNS rebinding. |
| Credential access | None. Reads only Claude's session `.jsonl` file names under `~/.claude/projects` to decide whether a session can be resumed; never tokens. |
| Process spawning | The `claude` CLI via the Agent SDK; probes `claude --version`, `claude auth status --json`, `npm prefix -g` (to locate the CLI); Windows-only `taskkill` cleanup. |
| Claude Code tools | Built-in tools are never enabled (`tools: []`). Every tool call goes through OpenCode, which owns permissions. Chat turns do not load the user's MCP servers or claude.ai connectors. |
| eval / obfuscation / telemetry | None. base64 is used only for the effort header encoding. |
| Disk writes | `~/.local/share/opencode-claude/{sessions.json, rate-limit.json, models.json}` and `debug.log` when `OPENCODE_CLAUDE_DEBUG=1`. |
| Dependencies | Official only: `@anthropic-ai/claude-agent-sdk@0.3.224`, `zod@4.4.3`, exact pins + `package-lock.json`, installed with `npm ci`. |
| Auth hygiene | `auth-env.ts` strips `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` / `CLAUDE_CODE_OAUTH_TOKEN` from the child env to force subscription mode. |

`npm audit` on the proxy tree: **0 vulnerabilities**. Offline regression
suite: `cd proxy && bun test/run.ts` (runs in CI).

## OpenCode plugin SDK tree

`@opencode/plugin` (installed into `~/.config/opencode` so the plugin files
resolve their types/imports) pulled in `@opentelemetry/core 2.6.1`, affected by
GHSA-8988-4f7v-96qf (unbounded memory allocation in W3C Baggage propagation,
`< 2.8.0`), via `@opencode/plugin -> @opencode/util -> @effect/opentelemetry`.
`@opencode/util` pins those versions exactly, so `install.sh` force-upgrades
the OpenTelemetry packages through npm `overrides` (→ 2.11.0) and CI asserts
`core >= 2.8.0`. Practical exploitability here is near zero: loopback only,
tracing off by default.

## Outbound requests made by this repo's own code

- One unauthenticated GET to `api.github.com/repos/Krowli/opencode-claude-bridge/releases/latest`
  per OpenCode launch, from the update-notice TUI plugin. Nothing is sent
  besides that request. Delete `~/.config/opencode/plugins/opencode-claude-update`
  to turn it off.

No secrets in the repo or config (only the dummy `"apiKey": "claude-code-proxy"`).

## What this repo adds

- `proxy/proxy.mjs` — runner; exits when a healthy proxy already owns the
  port (no stacked listeners).
- `plugin/opencode-claude-proxy.ts` — V2 plugin: spawns the proxy from the
  server's user session (keychain access, fixes launchd "Not logged in") and
  tags every `claude-code` request with session, request kind, project
  directory and effort headers.
- `plugin/opencode-claude-update.tui.ts` — release update notice.
- Provider config with effort variants (`low … max`).
