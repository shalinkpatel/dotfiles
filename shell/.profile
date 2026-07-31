# ALIAS
alias ls="eza -l"

# PATH
export PATH="$PATH:$HOME/.local/bin"
export PATH="$HOME/.asdf/shims:$PATH"

# VARS
export EDITOR="hx"
# Model-performance dev pod name (no dots — k8s rejects them). Used by
# gpu-dev/runbooks/vultr-dev-env/{deploy,pod-ssh-setup}.sh
export MODEL_PERFORMANCE_USER="shalin"

# ENVS
. "$HOME/.cargo/env"

# Secrets live in ~/.profile.secret (gitignored). See .profile.secret.example.
[ -f "$HOME/.profile.secret" ] && . "$HOME/.profile.secret"
