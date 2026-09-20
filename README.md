# opencode-claude-bridge

Use your **Claude Max subscription** (Claude Code CLI) inside **OpenCode V2** —
no API key, no fork, no auto-updating third-party magic.

```
OpenCode V2 (provider "claude-code", openai-compatible)
  └─ plugin opencode.claude-proxy   (spawns the proxy in the user session)
       └─ bun proxy.mjs  (127.0.0.1:8787)
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
- **Pinned, local, auditable.** `@openchamber/opencode-claude@0.14.0` is pinned
  exactly — no silent supply-chain updates. See [docs/AUDIT.md](docs/AUDIT.md)
  for the line-by-line review we ran before first use.
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

1. Creates `~/.local/share/opencode-claude/` and installs the **pinned**
   `@openchamber/opencode-claude@0.14.0` there.
2. Installs `@opencode/plugin` (V2 SDK) into `~/.config/opencode/node_modules`
   so the plugin file can resolve `import { Plugin } from "@opencode/plugin"`.
3. Copies `proxy/proxy.mjs` and renders
   `plugin/opencode-claude-proxy.ts` (its paths are filled in) into
   `~/.config/opencode/plugins/`.
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
| `haiku`      | 200K    | cheap/fast                     |
| `claude-opus-4-8` / `claude-sonnet-4-6` | 1M | pinned explicit IDs |

Every model ships **effort variants** (`low … max`) that map to the
`x-opencode-claude-effort` header, controlling Claude's adaptive thinking.

## Repository layout

```
proxy/proxy.mjs                     # runner (our fork-less integration + fixes)
plugin/opencode-claude-proxy.ts     # V2 plugin: spawns the proxy, keychain-safe
config/opencode.claude-code.json    # provider block for opencode.jsonc
install.sh / uninstall.sh           # idempotent setup / teardown
scripts/smoke-test.sh               # end-to-end verification
docs/AUDIT.md                       # security review of the underlying package
```

## Security

- The proxy listens on **127.0.0.1** only; network egress from the bundled
  package is to Anthropic domains only.
- Credentials stay in the `claude` CLI's keychain store; nothing is copied to
  disk by this repo.
- Version pins mean the running code only changes when **you** update it.
- Third-party: the proxy runtime is MIT-licensed community software
  ([@openchamber/opencode-claude](https://github.com/openchamber/opencode-claude)).
  Using your subscription through it is a community-supported path via the
  official Anthropic Agent SDK — check Anthropic's terms for your use case.

## Uninstall

```bash
bash uninstall.sh
```

---

# Русский

Подключение **подписки Claude Max** к **OpenCode V2** через локальный прокси:
без API-ключа, без форка, с закреплёнными версиями.

## Установка

```bash
git clone https://github.com/Krowli/opencode-claude-bridge.git
cd opencode-claude-bridge
bash install.sh        # --dry-run — показать план; --no-config — не трогать конфиг
```

Скрипт идемпотентен и повторяет ровно то, что уже проверено на рабочей машине:
прокси в `~/.local/share/opencode-claude/` (пин `0.14.0`), V2-плагин в
`~/.config/opencode/plugins/`, провайдер `claude-code` в `opencode.jsonc`.

## Проверка

```bash
curl -s http://127.0.0.1:8787/health
bash scripts/smoke-test.sh
opencode run --model claude-code/sonnet "привет"
```

Модели: `sonnet`, `opus`, `fable`, `haiku` (у каждой варианты усиления
`low → max`). Выбор в TUI: `/models` → Claude Code.

## Почему так устроено

- **Авторизация** — только в официальном CLI `claude`; прокси креды не читает
  и не отправляет.
- **Не через launchd**: Claude Code 2.x хранит OAuth в macOS Keychain, а
  launchd-демоны изолированы от него. Плагин запускает прокси как дочерний
  процесс сервера OpenCode (пользовательская сессия → Keychain доступен).
- **Пин-версии**: никаких автообновлений и сюрпризов в будущем.
- Аудит кода: [docs/AUDIT.md](docs/AUDIT.md).

## Лицензия

MIT. Прокси-рантайм — `@openchamber/opencode-claude` (MIT) + официальный
Anthropic Claude Agent SDK.