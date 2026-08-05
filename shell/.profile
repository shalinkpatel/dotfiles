# ALIAS
alias ls="eza -l"

# PATH — prepend so ~/.local/bin (our modern fzf, zmx, helix, claude) shadows
# any older system copies in /usr/bin, e.g. the apt fzf that's too old for
# --zsh/--with-shell.
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.asdf/shims:$PATH"

# VARS
export EDITOR="hx"
# Model-performance dev pod name (no dots — k8s rejects them). Used by
# gpu-dev/runbooks/vultr-dev-env/{deploy,pod-ssh-setup}.sh
export MODEL_PERFORMANCE_USER="shalin"
# Root of the dev layout: $WORKSPACE_ROOT/repos + $WORKSPACE_ROOT/workspaces.
# Defaults to $HOME/dev; override per machine (e.g. WORKSPACE_ROOT=/workspace
# on dev pods) via ~/.profile.secret or the container env.
export WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/dev}"

# ENVS
. "$HOME/.cargo/env"

# Secrets live in ~/.profile.secret (gitignored). See .profile.secret.example.
[ -f "$HOME/.profile.secret" ] && . "$HOME/.profile.secret"
