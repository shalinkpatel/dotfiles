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
exports the same default so shells and agents see it. Workspaces are grouped
by session/feature under `$WORKSPACE_ROOT/workspaces/<feature>/<repo>` (see
AGENTS.md).

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
| erlang + elixir | precompiled (hex.pm OTP + elixir zip) |
| clojure | official CLI installer (`--prefix ~/.local`; needs JDK) |
| babashka | GitHub release binary |
| elixir-ls, clojure-lsp | GitHub release (LSPs; helix picks them up) |
| uv, ruff, ty | uv installer + `uv tool` |
| claude | official installer (claude.ai/install.sh) |
| pi | npm install via install.sh (`install_pi`); config symlinked |
| bun | official installer (bun.sh/install) into `~/.local/opt/bun` |
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
- `pi/.mcporter/mcporter.json` — mcporter config backing pi-fabric's `mcp.*`
  surface (same servers, mcporter schema; symlinked to `~/.mcporter/mcporter.json`).
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

### MCP servers (mcporter)

MCP servers are provided by mcporter, which backs pi-fabric's `mcp.*` surface
inside `fabric_exec` programs. The shared server config is
`pi/.mcporter/mcporter.json` (symlinked to `~/.mcporter/mcporter.json`);
mcporter also imports servers from Claude Code, Claude Desktop, Codex, and
other host configs. List what's available with `mcporter list`; authenticate
OAuth servers with `mcporter auth <server>`.

The 10 claude.ai servers (Baseten Docs, b10-mcp, Gmail, Google Calendar,
Google Drive, Linear, Excalidraw, Slack, Notion, Granola) use different auth
paths:

- Baseten Docs and Excalidraw work without a separate OAuth client.
- b10-mcp, Linear, Notion, and Granola support dynamic client registration;
  `mcporter auth <server>` completes the browser flow.
- Gmail, Google Calendar, Google Drive, and Slack require pre-registered OAuth
  clients configured via `~/.profile.secret` as described below.

##### Google OAuth (Gmail, Calendar, Drive)

Create one OAuth 2.0 **Desktop app** client in a Google Cloud project. Enable
the Gmail, Google Calendar, and Google Drive APIs and configure the consent
screen/test users as needed. mcporter uses the desktop loopback callback
`http://localhost:19876/callback` and requests these scopes separately:

- Gmail: `https://www.googleapis.com/auth/gmail.modify`
- Calendar: `https://www.googleapis.com/auth/calendar`
- Drive: `https://www.googleapis.com/auth/drive`

Copy the desktop client's ID and secret into `~/.profile.secret` as
`GOOGLE_MCP_OAUTH_CLIENT_ID` and `GOOGLE_MCP_OAUTH_CLIENT_SECRET`, then run
`mcporter auth gmail google-calendar google-drive` to cache tokens.

##### Slack OAuth

Create a Slack app in the target workspace. Add
`http://localhost:19876/callback` under **OAuth & Permissions > Redirect
URLs**, then add the User Token Scopes listed in `mcporter.json`'s
`slack.oauthScope`. Copy **Basic Information > App Credentials** into
`SLACK_MCP_OAUTH_CLIENT_ID` and `SLACK_MCP_OAUTH_CLIENT_SECRET` in
`~/.profile.secret`, then run `mcporter auth slack`.

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
