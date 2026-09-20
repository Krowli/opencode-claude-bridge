# Security audit — @openchamber/opencode-claude@0.14.0

Reviewed the exact pinned version vendored by this repo (source read from the
npm cache, ~4 200 lines, `dist/*.js` + entry points). Context: the package is
community software, so we checked it line-by-line before wiring it to a paid
subscription.

## Findings

| Check | Result |
| --- | --- |
| Network endpoints in code | Only `http://127.0.0.1` (local proxy), `claude.ai/install.sh` and `claude.com` (official Anthropic). No third-party receivers. |
| Credential access | None. Does not read `~/.claude` credentials; only reads Claude's session `.jsonl` files (resume detection), never tokens. |
| Process spawning | Only the `claude` CLI via the official Agent SDK; a CLI installer (`npm i` / official install script) that runs only when the CLI is missing; a Windows `taskkill` cleanup. |
| eval / obfuscation / telemetry | None. Only base64 usage is the effort-level header encoding. |
| Disk writes | Only `~/.local/share/opencode-claude/{sessions.json, rate-limit.json}` + logs. |
| Dependencies | Official: `@anthropic-ai/claude-agent-sdk`, `zod`, `@opencode-ai/plugin` types. |
| Auth hygiene | `auth-env.js` strips `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` / `CLAUDE_CODE_OAUTH_TOKEN` from the child env to force subscription mode — stray keys cannot leak into the spawned CLI. |

## Verdict

Clean. No credential exfiltration, no unknown outbound traffic, no obfuscated
code. Residual, unavoidable risks of any npm software apply (maintainer trust,
dependency tree). Mitigations in this repo: exact version pin, local vendored
copy, no auto-updates.

## What this repo adds on top (our fixes)

- `proxy/proxy.mjs` — standalone runner; **duplicate-protection fix**: probes
  `/health` and exits when a healthy proxy already owns the pinned port.
- `plugin/opencode-claude-proxy.ts` — V2 plugin to spawn the proxy from the
  server's user session (fixes the "Not logged in" launchd/keychain issue).
- Provider config with effort variants (`x-opencode-claude-effort`).