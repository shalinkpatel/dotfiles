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
| zmx-picker (`zp`) | GitHub source tarball (shell script; needs fzf + zmx) |
| helix | GitHub release binary + runtime |
| fastfetch | GitHub `.deb` |
| uv, ruff, ty | uv installer + `uv tool` |
| claude | official installer (claude.ai/install.sh) |
| pi | config symlinked by install.sh; binary via npm (`npm i -g @earendil-works/pi-coding-agent`) |
| fzf, jq, htop, zsh, git | apt (base) |

On macOS the same config files are symlinked, but tool installs are left to
Homebrew (cargo builds and Linux binaries are skipped by an OS check).

## Pi (coding agent)

`pi/` mirrors the pi config layout and is symlinked into `$HOME` by
`install.sh`:

- `pi/.pi/agent/settings.json` — theme, default provider/model, enabled
  models, thinking level.
- `pi/.pi/agent/models.json` — custom providers (Baseten). The API key is
  referenced as `$BASETEN_API_KEY`, so it resolves from `~/.profile.secret`
  on each machine; no secrets live in this file.

Machine-local pi state is **not** symlinked or committed: `auth.json`
(OAuth tokens / API keys), `models-store.json` (remote model metadata cache),
and `sessions/`. Copy `pi/.pi/agent/auth.json.example` to
`~/.pi/agent/auth.json` and fill in credentials, or run `/login` in pi to
populate it. `~/.pi/agent/` is created on first pi run, so the symlinks
resolve even on a fresh machine.

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
