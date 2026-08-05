#!/usr/bin/env bash
# Symlinks every config into $HOME, then installs the toolchain. Idempotent;
# safe to re-run. Rust tools are compiled from source with full optimizations
# (the pods are long-running, so build time is fine). Set SKIP_CARGO=1 to skip
# the compile-heavy steps.
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SUFFIX="bak.$(date +%Y%m%d%H%M%S)"

OS="$(uname -s)"
ARCH="$(uname -m)"

# Root of the dev layout (repos/ + workspaces/). Same default as ~/.profile;
# override per machine via the environment (e.g. WORKSPACE_ROOT=/workspace).
export WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/dev}"

info() { printf '%s\n' "$*"; }

link_path() {
  local source_path="$1"
  local target_path="$2"
  local target_dir

  target_dir="$(dirname "$target_path")"
  mkdir -p "$target_dir"

  if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$source_path" ]; then
    info "Already linked: $target_path"
    return 0
  fi

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    local backup_path="${target_path}.${BACKUP_SUFFIX}"
    info "Backing up $target_path to $backup_path"
    mv "$target_path" "$backup_path"
  fi

  ln -s "$source_path" "$target_path"
  info "Linked $target_path -> $source_path"
}

fetch() {
  # fetch <url> [output-file]; streams to stdout without an output file.
  if command -v curl >/dev/null 2>&1; then
    if [ $# -gt 1 ]; then curl -fsSL "$1" -o "$2"; else curl -fsSL "$1"; fi
  elif command -v wget >/dev/null 2>&1; then
    if [ $# -gt 1 ]; then wget -qO "$2" "$1"; else wget -qO- "$1"; fi
  else
    info "Install curl or wget, then rerun this script."
    return 1
  fi
}

# Normalize to the release-asset arch naming most projects use.
asset_arch() {
  case "$ARCH" in
    x86_64 | amd64) echo "x86_64" ;;
    aarch64 | arm64) echo "aarch64" ;;
    *) echo "$ARCH" ;;
  esac
}

# Some projects (fzf, most Go/via-GoReleaser tools) use amd64/arm64 instead.
go_asset_arch() {
  case "$ARCH" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *) echo "$ARCH" ;;
  esac
}

# --- toolchain ------------------------------------------------------------

install_rust() {
  if command -v cargo >/dev/null 2>&1; then
    info "cargo already installed: $(cargo --version 2>/dev/null || true)"
    return 0
  fi
  info "Installing rustup (stable)"
  fetch https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
  # shellcheck disable=SC1091
  [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
}

# compile_tool <crate> [bin-name]
# Full optimizations: release is cargo's default; opt-level=3 + lto squeeze it
# further. target-cpu=native lets rustc use the pod's actual instruction set.
compile_tool() {
  local crate="$1"
  local bin="${2:-$1}"

  if [ "$OS" != "Linux" ]; then
    info "Skipping cargo build of $crate on $OS (managed by Homebrew here)"
    return 0
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    info "cargo unavailable; skipping $crate"
    return 1
  fi
  if command -v "$bin" >/dev/null 2>&1; then
    info "$bin already installed"
    return 0
  fi

  info "Compiling $crate (release, lto, target-cpu=native) — this takes a while"
  RUSTFLAGS="-C target-cpu=native" \
    cargo install --locked "$crate" \
    --config profile.release.opt-level=3 \
    --config profile.release.lto=true \
    --config profile.release.codegen-units=1
}

install_zmx() {
  # No cargo build for zmx; use the official release binary.
  if command -v zmx >/dev/null 2>&1; then
    info "zmx already installed"
    return 0
  fi
  if [ "$OS" != "Linux" ]; then
    info "Skipping zmx binary install on $OS (use Homebrew)"
    return 0
  fi
  local version
  version="$(fetch https://api.github.com/repos/neurosnap/zmx/releases/latest | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
  if [ -z "$version" ]; then
    info "Could not resolve latest zmx version"
    return 1
  fi
  info "Installing zmx $version to ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  local tmp
  tmp="$(mktemp -d)"
  fetch "https://github.com/neurosnap/zmx/releases/download/v${version}/zmx-${version}-linux-$(asset_arch).tar.gz" "$tmp/zmx.tar.gz"
  tar -xzf "$tmp/zmx.tar.gz" -C "$tmp"
  # The tarball may nest the binary; find and install it.
  local binpath
  binpath="$(find "$tmp" -name zmx -type f | head -1)"
  if [ -n "$binpath" ]; then
    install -m 0755 "$binpath" "$HOME/.local/bin/zmx"
  else
    info "WARN: zmx binary not found in tarball"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

install_zmx_picker() {
  # zp is a plain shell script (fuzzy picker for zmx sessions/repos); the
  # formula just installs it from the source tarball. Depends on fzf + zmx
  # (already installed); fd speeds up repo scans. On macOS this is
  # `brew install EarthmanMuons/tap/zmx-picker`.
  if command -v zp >/dev/null 2>&1; then
    info "zmx-picker (zp) already installed"
    return 0
  fi
  if [ "$OS" != "Linux" ]; then
    info "Skipping zmx-picker install on $OS (use 'brew install EarthmanMuons/tap/zmx-picker')"
    return 0
  fi
  local version
  version="$(fetch https://api.github.com/repos/EarthmanMuons/zmx-picker/releases/latest | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
  if [ -z "$version" ]; then
    info "Could not resolve latest zmx-picker version"
    return 1
  fi
  info "Installing zmx-picker $version (zp) to ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  local tmp
  tmp="$(mktemp -d)"
  fetch "https://github.com/EarthmanMuons/zmx-picker/archive/refs/tags/v${version}.tar.gz" "$tmp/zp.tar.gz"
  tar -xzf "$tmp/zp.tar.gz" -C "$tmp"
  local binpath
  binpath="$(find "$tmp" -name zp -type f | head -1)"
  if [ -n "$binpath" ]; then
    install -m 0755 "$binpath" "$HOME/.local/bin/zp"
  else
    info "WARN: zp script not found in tarball"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

install_helix() {
  if command -v hx >/dev/null 2>&1; then
    info "helix already installed: $(hx --version 2>/dev/null | head -1)"
    return 0
  fi
  if [ "$OS" != "Linux" ]; then
    info "Skipping helix binary install on $OS (use Homebrew)"
    return 0
  fi
  local version
  version="$(fetch https://api.github.com/repos/helix-editor/helix/releases/latest | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
  if [ -z "$version" ]; then
    info "Could not resolve latest helix version"
    return 1
  fi
  info "Installing helix $version to ~/.local/opt/helix"
  mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
  local tmp
  tmp="$(mktemp -d)"
  fetch "https://github.com/helix-editor/helix/releases/download/${version}/helix-${version}-$(asset_arch)-linux.tar.xz" "$tmp/helix.tar.xz"
  rm -rf "$HOME/.local/opt/helix"
  tar -xJf "$tmp/helix.tar.xz" -C "$tmp"
  mv "$tmp/helix-${version}-$(asset_arch)-linux" "$HOME/.local/opt/helix"
  ln -sfn "$HOME/.local/opt/helix/hx" "$HOME/.local/bin/hx"
  # Runtime (themes + grammars) must sit next to the config.
  mkdir -p "$HOME/.config/helix"
  ln -sfn "$HOME/.local/opt/helix/runtime" "$HOME/.config/helix/runtime"
  rm -rf "$tmp"
}

install_claude() {
  # Native installer; works on macOS and Linux, lands in ~/.local/bin (already
  # on PATH via .profile). Idempotent — skips when claude is already present.
  if command -v claude >/dev/null 2>&1; then
    info "Claude Code already installed: $(claude --version 2>/dev/null || true)"
    return 0
  fi
  info "Installing Claude Code"
  fetch https://claude.ai/install.sh | bash
}

install_pi() {
  # Pi (coding agent) is an npm package. The official installer (pi.dev/install.sh)
  # is interactive, so install the package directly with npm. Needs node/npm:
  # present via Homebrew on macOS; on Linux pods, install via apt when missing.
  # Idempotent — skips when pi is already present.
  if command -v pi >/dev/null 2>&1; then
    info "pi already installed: $(pi --version 2>/dev/null | head -1 || true)"
    return 0
  fi
  if ! command -v npm >/dev/null 2>&1; then
    if [ "$OS" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then
      local sudo_cmd=""
      if [ "$(id -u)" != "0" ]; then
        command -v sudo >/dev/null 2>&1 && sudo_cmd="sudo" || { info "Skipping pi (need root for node install)"; return 1; }
      fi
      info "Installing nodejs + npm via apt"
      export DEBIAN_FRONTEND=noninteractive
      $sudo_cmd apt-get update -qq >/dev/null 2>&1 || true
      $sudo_cmd apt-get install -y -qq nodejs npm >/dev/null || { info "WARN: node install failed"; return 1; }
    else
      info "npm unavailable; skipping pi install"
      return 1
    fi
  fi
  info "Installing pi via npm"
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent || return 1
  if command -v pi >/dev/null 2>&1; then
    info "pi installed: $(pi --version 2>/dev/null | head -1 || true)"
  else
    info "WARN: pi installed but not on PATH"
  fi
}

install_fzf() {
  # The apt build of fzf is too old for --zsh/--bash and for zp's
  # --with-shell, so install a modern release binary on Linux. It lands in
  # ~/.local/bin, which .profile puts ahead of /usr/bin, so it shadows any
  # older system fzf. On macOS fzf comes from Homebrew.
  if [ "$OS" != "Linux" ]; then
    info "Skipping fzf binary install on $OS (use Homebrew)"
    return 0
  fi
  local want="0.74.1"
  if command -v fzf >/dev/null 2>&1; then
    local cur
    cur="$(fzf --version 2>/dev/null | awk '{print $1}')"
    if [ "$cur" = "$want" ] && [ "$(command -v fzf)" = "$HOME/.local/bin/fzf" ]; then
      info "fzf $cur already installed in ~/.local/bin"
      return 0
    fi
    info "Replacing system fzf ${cur:-unknown} with $want in ~/.local/bin"
  fi
  info "Installing fzf $want to ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  local tmp
  tmp="$(mktemp -d)"
  fetch "https://github.com/junegunn/fzf/releases/download/v${want}/fzf-${want}-linux_$(go_asset_arch).tar.gz" "$tmp/fzf.tar.gz"
  tar -xzf "$tmp/fzf.tar.gz" -C "$tmp" fzf
  install -m 0755 "$tmp/fzf" "$HOME/.local/bin/fzf"
  rm -rf "$tmp"
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    info "uv already installed"
    return 0
  fi
  info "Installing uv"
  fetch https://astral.sh/uv/install.sh | sh
}

install_fastfetch() {
  if command -v fastfetch >/dev/null 2>&1; then
    info "fastfetch already installed"
    return 0
  fi
  if [ "$OS" != "Linux" ] || ! command -v apt-get >/dev/null 2>&1; then
    info "Skipping fastfetch on $OS"
    return 0
  fi
  local sudo_cmd=""
  if [ "$(id -u)" != "0" ]; then
    command -v sudo >/dev/null 2>&1 && sudo_cmd="sudo" || { info "Skipping fastfetch (need root)"; return 0; }
  fi
  local version deb_arch
  version="$(fetch https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
  case "$ARCH" in
    x86_64 | amd64) deb_arch="amd64" ;;
    aarch64 | arm64) deb_arch="aarch64" ;;
    *) info "Unsupported arch for fastfetch: $ARCH"; return 1 ;;
  esac
  if [ -z "$version" ]; then
    info "Could not resolve latest fastfetch version"
    return 1
  fi
  info "Installing fastfetch $version (.deb)"
  local tmp
  tmp="$(mktemp -d)"
  fetch "https://github.com/fastfetch-cli/fastfetch/releases/download/${version}/fastfetch-linux-${deb_arch}.deb" "$tmp/fastfetch.deb"
  $sudo_cmd dpkg -i "$tmp/fastfetch.deb" >/dev/null 2>&1 || $sudo_cmd apt-get install -y -f -qq >/dev/null
  rm -rf "$tmp"
}

install_uv_tools() {
  if ! command -v uv >/dev/null 2>&1; then
    info "uv unavailable; skipping uv tools"
    return 1
  fi
  local tool
  for tool in ruff ty; do
    if command -v "$tool" >/dev/null 2>&1; then
      info "$tool already installed"
    else
      info "Installing $tool via uv"
      uv tool install "$tool" || info "WARN: uv tool install $tool failed"
    fi
  done
}

# --- main -----------------------------------------------------------------

main() {
  # Dev layout root — create the repos/ + workspaces/ roots so the convention
  # holds even before the shell config (which also defines WORKSPACE_ROOT) is live.
  mkdir -p "$WORKSPACE_ROOT/repos" "$WORKSPACE_ROOT/workspaces"

  # Shell — zsh is primary; .bashrc covers pods/containers that land in bash.
  link_path "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
  link_path "$DOTFILES_DIR/shell/.zshenv" "$HOME/.zshenv"
  link_path "$DOTFILES_DIR/shell/.zprofile" "$HOME/.zprofile"
  link_path "$DOTFILES_DIR/shell/.bashrc" "$HOME/.bashrc"
  link_path "$DOTFILES_DIR/shell/.profile" "$HOME/.profile"

  # Prompt + editors
  link_path "$DOTFILES_DIR/starship/.config/starship.toml" "$HOME/.config/starship.toml"
  link_path "$DOTFILES_DIR/helix/.config/helix/config.toml" "$HOME/.config/helix/config.toml"
  link_path "$DOTFILES_DIR/helix/.config/helix/languages.toml" "$HOME/.config/helix/languages.toml"

  # VCS
  link_path "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
  link_path "$DOTFILES_DIR/git/.config/git/ignore" "$HOME/.config/git/ignore"
  link_path "$DOTFILES_DIR/jj/.config/jj/config.toml" "$HOME/.config/jj/config.toml"

  # Zed is only relevant where a desktop runs it; harmless elsewhere.
  if [ "$OS" != "Linux" ]; then
    link_path "$DOTFILES_DIR/zed/.config/zed/settings.json" "$HOME/.config/zed/settings.json"
  fi

  # Pi (coding agent). settings.json and models.json are portable (the
  # Baseten API key is referenced via $BASETEN_API_KEY, which comes from
  # ~/.profile.secret). auth.json (OAuth tokens/API keys), models-store.json
  # (remote model cache) and sessions/ are machine-local and intentionally
  # not linked — see pi/.pi/agent/auth.json.example.
  link_path "$DOTFILES_DIR/pi/.pi/agent/settings.json" "$HOME/.pi/agent/settings.json"
  link_path "$DOTFILES_DIR/pi/.pi/agent/models.json" "$HOME/.pi/agent/models.json"

  # User-level agent instructions: one canonical AGENTS.md, symlinked into
  # every coding harness that reads it. Claude Code reads ~/.claude/AGENTS.md
  # (its CLAUDE.md imports it via "@AGENTS.md"); pi reads ~/.pi/agent/AGENTS.md.
  link_path "$DOTFILES_DIR/AGENTS.md" "$HOME/.claude/AGENTS.md"
  link_path "$DOTFILES_DIR/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"

  # Toolchain
  install_rust || info "WARN: rust install failed"
  install_uv || info "WARN: uv install failed"

  if [ "${SKIP_CARGO:-0}" != "1" ]; then
    compile_tool starship
    compile_tool eza
    compile_tool zoxide
    compile_tool ripgrep rg
    compile_tool fd-find fd
    compile_tool just
    compile_tool jj-cli jj
    compile_tool numbat-cli numbat
  else
    info "SKIP_CARGO=1: skipping cargo builds"
  fi

  install_fzf || info "WARN: fzf install failed"
  install_zmx || info "WARN: zmx install failed"
  install_zmx_picker || info "WARN: zmx-picker install failed"
  install_helix || info "WARN: helix install failed"
  install_fastfetch || info "WARN: fastfetch install failed"
  install_uv_tools || info "WARN: uv tools install failed"
  install_pi || info "WARN: pi install failed"
  install_claude || info "WARN: claude install failed"

  info ""
  info "Install complete."
  if [ ! -f "$HOME/.profile.secret" ]; then
    info "NOTE: $HOME/.profile.secret is missing. Copy your real secrets in:"
    info "      see $DOTFILES_DIR/shell/.profile.secret.example"
  fi
  info "Restart your shell to pick up the new config."
}

main "$@"
