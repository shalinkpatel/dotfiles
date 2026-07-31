# Bash interactive config for environments where zsh isn't the login shell
# (some pods/containers). Portable env + aliases live in ~/.profile; this
# adds the bash-specific tool init so the experience matches zsh.

# Portable env, PATH, aliases, secrets.
[ -f "$HOME/.profile" ] && . "$HOME/.profile"

# Only run the rest for interactive shells.
case $- in
  *i*) ;;
  *) return ;;
esac

# TOOLING — bash variants, guarded so missing tools never error.
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi
if command -v zmx >/dev/null 2>&1; then
  eval "$(zmx completions bash)"
fi

# COSMETIC
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
if command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi
