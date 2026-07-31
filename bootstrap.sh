#!/usr/bin/env bash
# Entry point run by intertubin on first pod start (and safe to re-run by hand).
# Installs base packages, makes zsh the login shell, then delegates to
# install.sh. Every step is guarded so a failure never kills the pod.
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then
  SUDO=""
  if [ "$(id -u)" != "0" ]; then
    command -v sudo >/dev/null 2>&1 && SUDO="sudo"
  fi
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update -qq || true
  # pkg-config + libssl-dev + build-essential give cargo a linker and the
  # native deps some crates need. fzf is deliberately NOT here — the apt
  # build is too old for --zsh/--bash/--with-shell; install.sh puts a modern
  # fzf in ~/.local/bin (which precedes /usr/bin on PATH).
  $SUDO apt-get install -y -qq \
    git curl wget unzip zsh jq htop \
    build-essential pkg-config libssl-dev ca-certificates \
    >/dev/null || echo "WARN: base package install incomplete"

  # Land ssh sessions in zsh.
  if command -v zsh >/dev/null 2>&1 && command -v chsh >/dev/null 2>&1; then
    $SUDO chsh -s "$(command -v zsh)" "$(whoami)" 2>/dev/null \
      || echo "WARN: could not change login shell to zsh"
  fi
fi

bash "$DOTFILES_DIR/install.sh"
