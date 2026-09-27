/**
 * Shows a toast in the OpenCode TUI when opencode-claude-bridge has a newer
 * GitHub release than the one installed. Checks once per OpenCode launch;
 * any network error is ignored.
 *
 * Only a type import: `@opencode/plugin/tui` pulls in @opentui at runtime,
 * and `Plugin.define` just returns its argument.
 *
 * The two constants below are filled in by `install.sh`.
 */
import type { Plugin } from "@opencode/plugin/tui"

// eslint-disable-next-line no-unused-vars
const INSTALLED_VERSION = "__INSTALLED_VERSION__"
// eslint-disable-next-line no-unused-vars
const REPO_DIR = "__REPO_DIR__"

const LATEST_URL =
  "https://api.github.com/repos/Krowli/opencode-claude-bridge/releases/latest"

/** "v1.2.3" -> [1, 2, 3]; anything else -> undefined. */
function parse(tag: string): number[] | undefined {
  const m = /^v?(\d+)\.(\d+)\.(\d+)$/.exec(tag.trim())
  return m ? m.slice(1).map(Number) : undefined
}

function isNewer(latest: number[], installed: number[] | undefined): boolean {
  if (!installed) return true
  for (let i = 0; i < 3; i++) {
    if (latest[i] !== installed[i]) return latest[i] > installed[i]
  }
  return false
}

const plugin: Plugin.Definition = {
  id: "opencode.claude-update",

  setup(context) {
    fetch(LATEST_URL, {
      headers: { Accept: "application/vnd.github+json" },
      signal: AbortSignal.timeout(5000),
    })
      .then((res) => (res.ok ? res.json() : undefined))
      .then((release) => {
        const tag = typeof release?.tag_name === "string" ? release.tag_name : ""
        const latest = parse(tag)
        if (!latest || !isNewer(latest, parse(INSTALLED_VERSION))) return
        context.ui.toast.show({
          title: `Claude bridge ${tag} available`,
          message: `cd ${REPO_DIR} && git pull && bash install.sh — then restart OpenCode`,
          variant: "info",
          duration: 15000,
        })
      })
      .catch(() => {})
  },
}

export default plugin
