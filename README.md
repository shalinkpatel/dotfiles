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
```

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
| fzf, jq, htop, zsh, git | apt (base) |

On macOS the same config files are symlinked, but tool installs are left to
Homebrew (cargo builds and Linux binaries are skipped by an OS check).

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
