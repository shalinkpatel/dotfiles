. $HOME/.profile

# Brew (macOS only; no Homebrew on Linux pods)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
fi
