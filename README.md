# opencode-claude-bridge

[![CI](https://github.com/Krowli/opencode-claude-bridge/actions/workflows/ci.yml/badge.svg)](https://github.com/Krowli/opencode-claude-bridge/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Krowli/opencode-claude-bridge)](https://github.com/Krowli/opencode-claude-bridge/releases/latest)
[![License: MIT](https://img.shields.io/github/license/Krowli/opencode-claude-bridge)](LICENSE)
[![OpenCode V2](https://img.shields.io/badge/OpenCode-V2-black)](https://opencode.ai)
[![Bun](https://img.shields.io/badge/runtime-Bun-f9f1e1?logo=bun&logoColor=black)](https://bun.sh)
[![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey?logo=apple)](#requirements)

Use your **Claude Max subscription** (Claude Code CLI) inside **OpenCode V2** —
no API key, no third-party packages at runtime, no auto-updates.

> [!WARNING]
> **Personal project, use at your own risk.** Anthropic's Agent SDK docs say:
> *"Unless previously approved, Anthropic does not allow third party developers
> to offer claude.ai login or rate limits for their products, including agents
> built on the Claude Agent SDK."*
> ([source](https://code.claude.com/docs/en/agent-sdk/overview)). This repo is
> not affiliated with or approved by Anthropic or OpenCode. It is published
> as-is for the author's own use; if you run it, you accept any consequences
> for your Claude account yourself. Fork it and change it as you like.

```
OpenCode V2 (provider "claude-code", openai-compatible)
  └─ plugin opencode.claude-proxy   (spawns the proxy, tags each request)
       └─ bun proxy.mjs → proxy/lib  (127.0.0.1:8787)
            └─ Claude Agent SDK → claude CLI (subscription OAuth)
```

## Why this layout

- **Subscription, not API billing.** Auth lives entirely inside the official
  `claude` CLI. The proxy never reads, copies or sends your credentials, and
  it even strips `ANTHROPIC_*` env vars from the spawned child.
- **Not launchd.** Claude Code 2.x stores OAuth in the macOS login keychain;
  launchd jobs can't read it ("Not logged in"). The plugin spawns the proxy as
  a child of the OpenCode **server** (a user-session process), which has
  keychain access and restarts it on every OpenCode launch.
- **Our code, pinned deps.** The proxy lives in this repo (`proxy/lib`). Its
  only dependencies are the official Claude Agent SDK and `zod`, pinned
  exactly with a lockfile. See [docs/AUDIT.md](docs/AUDIT.md).
- **Duplicate-safe.** If a healthy proxy already listens on `:8787` (e.g. after
  a server crash), a newly spawned instance checks `/health` and exits instead
  of stacking zombie listeners.

## Requirements

- OpenCode **V2** (plugin API v2; this repo does not target OpenCode V1)
- [Claude Code CLI](https://claude.com/cli) signed in with a subscription:
  `claude auth login`
- [Bun](https://bun.sh) (`curl -fsSL https://bun.sh/install | bash`)
- macOS (for the keychain assumption; other platforms may work via
  `CLAUDE_CODE_OAUTH_TOKEN`, untested)

## Install

```bash
git clone https://github.com/Krowli/opencode-claude-bridge.git
cd opencode-claude-bridge
bash install.sh          # --dry-run to preview, --no-config to skip config
```

`install.sh` (idempotent) does four things:

1. Copies the proxy (`proxy/proxy.mjs`, `proxy/lib`) to
   `~/.local/share/opencode-claude/`, installs its pinned dependencies with
   `npm ci`, and stops a running old proxy.
2. Installs `@opencode/plugin` (V2 SDK) into `~/.config/opencode/node_modules`
   so the plugin file can resolve `import { Plugin } from "@opencode/plugin"`.
3. Renders `plugin/opencode-claude-proxy.ts` and the update notice
   `plugin/opencode-claude-update.tui.ts` into `~/.config/opencode/plugins/`.
4. Merges the `claude-code` provider
   ([config/opencode.claude-code.json](config/opencode.claude-code.json)) into
   `~/.config/opencode/opencode.jsonc`. If your config is JSONC with comments,
   it prints the snippet and you merge it manually.

After that, **restart OpenCode** (or let the config watcher reload the plugin),
then verify:

```bash
curl -s http://127.0.0.1:8787/health           # {"ok":true,"provider":"claude-code",...}
bash scripts/smoke-test.sh                      # health + models + one real completion
opencode run --model claude-code/sonnet "hello"
```

Pick models in the TUI with `/models` → **Claude Code**.

## Models & effort variants

| Model        | Context | Notes                          |
| ------------ | ------- | ------------------------------ |
| `sonnet`     | 1M      | default, best speed/quality    |
| `opus`       | 1M      | strongest reasoning            |
| `fable`      | 1M      | alias → current flagship       |
| `haiku`      | 200K    | cheap/fast, no effort variants |
| `claude-opus-5-5[1m]` / `claude-fable-5-1[1m]` | 1M | Opus 5.5 / Fable 5.1 |
| `claude-opus-4-8` / `claude-sonnet-4-6` | 1M | pinned explicit IDs |

Models ship **effort variants** (`low … max`, e.g. `claude-code/sonnet#high`);
the plugin sends the chosen one to the proxy, which sets Claude's thinking effort.

## Updating

```bash
cd opencode-claude-bridge && git pull && bash install.sh   # then restart OpenCode
```

The installer adds new models to your `claude-code` provider, refreshes their
variants and keeps your other edits. When a newer
[release](https://github.com/Krowli/opencode-claude-bridge/releases) exists,
OpenCode shows a toast with that command on launch (the TUI plugin
`plugins/opencode-claude-update/tui.ts` asks `api.github.com` for the latest
release; nothing else is sent). Delete that folder to turn it off.

Publishing an update (maintainer): push to `main`, then
`gh release create vX.Y.Z --generate-notes`.

## Repository layout

```
proxy/proxy.mjs                     # runner
proxy/lib/                          # the proxy (OpenAI-compatible -> Agent SDK)
proxy/test/                         # offline regression suite: cd proxy && bun test/run.ts
plugin/opencode-claude-proxy.ts     # V2 plugin: spawns the proxy, request headers
plugin/opencode-claude-update.tui.ts # release update notice (TUI toast)
config/opencode.claude-code.json    # provider block for opencode.jsonc
install.sh / uninstall.sh           # idempotent setup / teardown
scripts/smoke-test.sh               # end-to-end verification
docs/AUDIT.md                       # security review
```

## Security

- The proxy listens on **127.0.0.1** only and refuses browser-originated
  requests; model traffic goes only through the official Agent SDK.
- Credentials stay in the `claude` CLI's keychain store; nothing is copied to
  disk by this repo.
- Version pins mean the running code only changes when **you** update it.
- See the warning at the top: this use of a subscription is not approved by
  Anthropic.

## Uninstall

```bash
bash uninstall.sh
```

## License

MIT (see [LICENSE](LICENSE)). `proxy/lib` includes MIT-licensed code; its
notice is in [proxy/lib/LICENSE](proxy/lib/LICENSE).
