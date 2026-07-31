# COMP SYS
autoload -Uz compinit
compinit

# TOOLING
source <(fzf --zsh)
eval "$(zoxide init zsh)"
eval "$(zmx completions zsh)"

# COSMETIC
eval "$(starship init zsh)"
fastfetch
