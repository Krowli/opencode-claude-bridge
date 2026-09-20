/**
 * Runs the Claude subscription proxy as a child of the OpenCode server.
 *
 * The proxy bridges OpenAI-compatible requests (provider `claude-code`) to
 * the Claude Agent SDK -> `claude` CLI using the user's Claude Max
 * subscription (OAuth in the macOS keychain).
 *
 * It MUST live in the user's login session for keychain access — launchd
 * cannot read the login keychain ("Not logged in"). Spawning it from the
 * OpenCode server (a user-session process) gives it that access, and the
 * server restarts it automatically on every launch.
 *
 * The two constants below are filled in by `install.sh`.
 */
import { Plugin } from "@opencode/plugin"
import { spawn } from "node:child_process"
import { openSync } from "node:fs"

// eslint-disable-next-line no-unused-vars
const PROXY_HOME = "__PROXY_HOME__"
// eslint-disable-next-line no-unused-vars
const BUN_BIN = "__BUN_BIN__"

export default Plugin.define({
  id: "opencode.claude-proxy",

  setup() {
    const out = openSync(`${PROXY_HOME}/proxy.out.log`, "a")
    const err = openSync(`${PROXY_HOME}/proxy.err.log`, "a")

    const child = spawn(BUN_BIN, [`${PROXY_HOME}/proxy.mjs`], {
      cwd: PROXY_HOME,
      // New process group + session: survives abrupt server exits, keeps
      // the user login session (keychain access intact).
      detached: true,
      stdio: ["ignore", out, err],
    })
    child.unref()

    return () => {
      try {
        child.kill("SIGTERM")
      } catch {}
    }
  },
})