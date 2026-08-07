# dotfiles

Shalin's shell environment for macOS and intertubin dev pods.

## How it works

intertubin clones this repo to `/root/dotfiles` on pod start and runs
`bootstrap.sh` (see the `REPO_FOR_DOTFILES` env var it sets). `bootstrap.sh`
installs base apt packages, switches the login shell to zsh, then runs
`install.sh`. Everything is idempotent and guarded so a failure never kills
the pod.

`install.sh` symlinks each config into `$HOME` and installs the toolchain.
Rust tools are compiled from source with full optimizations (release +
`opt-level=3` + `lto` + `target-cpu=native`) because the pods are
long-running — build time doesn't matter. Set `SKIP_CARGO=1` to skip the
compile-heavy steps.

## Layout

```
bootstrap.sh   entry point (apt base + chsh zsh + install.sh)
install.sh     symlinks + toolchain install, idempotent
shell/         .zshrc, .zshenv, .zprofile, .profile, secret template
starship/      prompt config (zmx session segment)
git/           .gitconfig + global ignore
jj/            jujutsu config
helix/         editor config + languages
zed/           zed settings (macOS only)
et/            etserver config (/etc/et.cfg on Linux)
pi/            pi (coding agent) settings
AGENTS.md      user-level agent instructions (harness-independent)
```

## Layout root

All repos and worktrees live under `$WORKSPACE_ROOT` (default `$HOME/dev`;
override per machine, e.g. `WORKSPACE_ROOT=/workspace` on dev pods, via
`~/.profile.secret` or the container env). `install.sh` creates
`$WORKSPACE_ROOT/repos` and `$WORKSPACE_ROOT/workspaces`; `~/.profile`
exports the same default so shells and agents see it.

## Tools

| Tool | Source on pod |
|---|---|
| eza, zoxide, starship, ripgrep, fd, just, jj, numbat | compiled via cargo (full opts) |
| zmx | GitHub release binary |
| jjui | GitHub release binary (TUI for jj) |
| zmx-picker (`zp`) | GitHub source tarball (shell script; needs fzf + zmx) |
| helix | GitHub release binary + runtime |
| fastfetch | GitHub `.deb` |
| et (Eternal Terminal) | source build (cmake -> `.deb`) |
| uv, ruff, ty | uv installer + `uv tool` |
| claude | official installer (claude.ai/install.sh) |
| pi | npm install via install.sh (`install_pi`); config symlinked |
| fzf, jq, htop, zsh, git | apt (base) |

On macOS the same config files are symlinked, but tool installs are left to
Homebrew (cargo builds and Linux binaries are skipped by an OS check).
Eternal Terminal is `brew install et` on macOS.

## Pi (coding agent)

`install.sh` installs the pi binary via npm (`install_pi`; needs node/npm,
installed via apt on Linux pods when missing) and symlinks its config into
`$HOME`. pi >= 0.83 needs Node >= 22.19 (it uses JSON import attributes) and
its dependencies (pi-fabric, mcporter) need >= 24, so on Linux pods
`install_pi` first runs `install_node`, which drops a Node 24 LTS binary from
nodejs.org into `~/.local/opt/node` (ahead of the apt 18.x); on macOS node
comes from Homebrew.

- `pi/.pi/agent/settings.json` — theme, default provider/model, enabled
  models, thinking level, and the installed-package manifest (`packages`).
- `pi/.pi/agent/models.json` — custom providers (Baseten). The API key is
  referenced as `$BASETEN_API_KEY`, so it resolves from `~/.profile.secret`
  on each machine; no secrets live in this file.
- `pi/.pi/agent/mcp.json` — MCP adapter config (host imports + servers).
- `pi/.pi/web-search.json` — web-search defaults: search provider and the
  curator workflow (`summary-review`, `auto-summary`, or `none`).

Machine-local pi state is **not** symlinked or committed: `auth.json`
(OAuth tokens / API keys), `models-store.json` (remote model metadata cache),
and `sessions/`. Copy `pi/.pi/agent/auth.json.example` to
`~/.pi/agent/auth.json` and fill in credentials, or run `/login` in pi to
populate it. `~/.pi/agent/` is created on first pi run, so the symlinks
resolve even on a fresh machine.

### Pi packages

`settings.json`'s `packages` key is the single source of truth for installed
pi packages (extensions, skills, prompt templates, themes). Because
`~/.pi/agent/settings.json` is symlinked into this repo:

- `pi install npm:...` / `pi install git:...` on any machine writes through
the symlink, so the package list lands in the repo as a git diff — commit it.
- On a fresh machine, pi auto-installs every package listed in settings on
startup (its resource loader resolves missing packages), so no extra setup is
needed after `install.sh`.
- `pi list` shows what's installed; `pi update --extensions` refreshes them.

Keep only `npm:`/`git:` sources in the shared manifest. Local-path packages
are stored relative to `~/.pi/agent` and are machine-specific — keep those
in project settings (`.pi/settings.json`) instead.

### MCP servers (pi-mcp-adapter)

`pi-mcp-adapter` gives pi access to MCP servers without burning context: one
proxy tool, lazy server startup, on-demand discovery. It's installed as a
package (see `packages` above) and reads standard MCP configs plus
host-specific ones:

- `pi/.pi/agent/mcp.json` is symlinked to `~/.pi/agent/mcp.json` and carries
  the `imports` list — which host configs pi adopts (currently `claude-code`,
  `claude-desktop`, `codex`). So MCP servers you configure in Claude Code
  (`~/.claude.json`), Claude Desktop, or Codex are automatically available to
  pi. Run `pi-mcp-adapter init` to re-scan and update the imports.
- Shared global servers go in `~/.config/mcp/mcp.json` (highest precedence,
  tool-agnostic); project servers go in `.mcp.json`. See the adapter's README
  for the full precedence order.
- Keep credentials out of committed MCP configs — reference them via env vars
  (e.g. from `~/.profile.secret`), never inline tokens.

#### Synced claude.ai MCP servers

`mcp.json` includes the 10 claude.ai MCP servers you use (synced from
`claude mcp list`): Baseten Docs, b10-mcp, Gmail, Google Calendar, Google
Drive, Linear, Excalidraw, Slack, Notion, Granola.

The providers use different authentication paths:

- Baseten Docs and Excalidraw work without a separate OAuth client.
- b10-mcp, Linear, Notion, and Granola support dynamic client registration;
  authenticate in pi via `/mcp` and the adapter stores tokens in the OS
  keychain. Live read-only calls have been verified for all four.
- Gmail, Google Calendar, Google Drive, and Slack do not support dynamic
  client registration. They require pre-registered OAuth clients configured
  via `~/.profile.secret` as described below.

##### Google OAuth (Gmail, Calendar, Drive)

Create one OAuth 2.0 **Desktop app** client in a Google Cloud project. Enable
the Gmail, Google Calendar, and Google Drive APIs and configure the consent
screen/test users as needed. The adapter uses the desktop loopback callback
`http://localhost:19876/callback` and requests these scopes separately:

- Gmail: `https://www.googleapis.com/auth/gmail.modify`
- Calendar: `https://www.googleapis.com/auth/calendar`
- Drive: `https://www.googleapis.com/auth/drive`

Copy the desktop client's ID and secret into `~/.profile.secret` as
`GOOGLE_MCP_OAUTH_CLIENT_ID` and `GOOGLE_MCP_OAUTH_CLIENT_SECRET`. Start a
fresh shell (or source `~/.profile`), restart pi, then authenticate each
Google server through `/mcp`. The config requests offline access and explicit
consent so refresh tokens are returned.

##### Slack OAuth

Create a Slack app in the target workspace. Add
`http://localhost:19876/callback` under **OAuth & Permissions > Redirect
URLs**, then add the User Token Scopes listed in `mcp.json`'s
`slack.oauth.scope`. Copy **Basic Information > App Credentials** into
`SLACK_MCP_OAUTH_CLIENT_ID` and `SLACK_MCP_OAUTH_CLIENT_SECRET` in
`~/.profile.secret`. Start a fresh shell, restart pi, then authenticate Slack
through `/mcp`. An administrator may need to approve the app for the Baseten
workspace.

##### b10-mcp

b10-mcp is behind claude.ai's proxy (`baseten.runlayer.com`). It uses standard
MCP OAuth with PKCE and dynamic client registration; the raw claude.ai access
token is not accepted directly. pi-mcp-adapter completes the browser flow and
stores a server-scoped access/refresh token in the OS keychain. This path has
been verified with a live `list_folders` call.

## AGENTS.md (user-level agent instructions)

`AGENTS.md` at the repo root is the single canonical copy of the user-level
agent instructions (repo/workspace workflow + writing tropes), independent
of any coding harness. `install.sh` symlinks it into every harness that reads
it:

- `~/.claude/AGENTS.md` — Claude Code (`~/.claude/CLAUDE.md` imports it via
  `@AGENTS.md`).
- `~/.pi/agent/AGENTS.md` — pi global instructions.

Edit the one file; all harnesses pick it up on the next install. (Because it
lives at the repo root, it also loads as project context when working inside
the dotfiles repo itself.)

## Secrets

`BASETEN_API_KEY` and anything sensitive goes in `~/.profile.secret`, which
`~/.profile` sources at the end. That file is gitignored — copy
`shell/.profile.secret.example` to `$HOME/.profile.secret` and fill it in.
It is never committed.

## First-time setup on a pod

The pod runs as root with `$HOME=/root` on a persistent hostPath volume, so
this only needs to happen once:

```
intertubin pods create --dotfiles shalinkpatel/dotfiles
# then drop your real secrets in:
cp shell/.profile.secret.example ~/.profile.secret && $EDITOR ~/.profile.secret
```
