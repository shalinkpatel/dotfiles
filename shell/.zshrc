# Zsh-only interactive config. (.profile holds the portable bits and is
# sourced by both bash and zsh via .zshenv / .bashrc.)

# COMP SYS
autoload -Uz compinit
compinit

# TOOLING — only init each tool if it's actually installed, so a partially
# provisioned box never errors on startup.
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
if command -v zmx >/dev/null 2>&1; then
  eval "$(zmx completions zsh)"
fi

# COSMETIC
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
if command -v fastfetch >/dev/null 2>&1 && [[ -o interactive ]]; then
  fastfetch
fi
