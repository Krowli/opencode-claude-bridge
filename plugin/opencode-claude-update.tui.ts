/**
 * Shows a toast in the OpenCode TUI when opencode-claude-bridge has new
 * commits on GitHub (new models, fixes). Checks once per OpenCode launch;
 * any network error is ignored.
 *
 * Only a type import: `@opencode/plugin/tui` pulls in @opentui at runtime,
 * and `Plugin.define` just returns its argument.
 *
 * The two constants below are filled in by `install.sh`.
 */
import type { Plugin } from "@opencode/plugin/tui"

// eslint-disable-next-line no-unused-vars
const INSTALLED_COMMIT = "__INSTALLED_COMMIT__"
// eslint-disable-next-line no-unused-vars
const REPO_DIR = "__REPO_DIR__"

const LATEST_URL =
  "https://api.github.com/repos/Krowli/opencode-claude-bridge/commits/main"

const plugin: Plugin.Definition = {
  id: "opencode.claude-update",

  setup(context) {
    fetch(LATEST_URL, {
      headers: { Accept: "application/vnd.github.sha" },
      signal: AbortSignal.timeout(5000),
    })
      .then((res) => (res.ok ? res.text() : ""))
      .then((latest) => {
        latest = latest.trim()
        if (!/^[0-9a-f]{40}$/.test(latest) || latest === INSTALLED_COMMIT) return
        context.ui.toast.show({
          title: "Claude bridge update available",
          message: `cd ${REPO_DIR} && git pull && bash install.sh — then restart OpenCode`,
          variant: "info",
          duration: 15000,
        })
      })
      .catch(() => {})
  },
}

export default plugin
