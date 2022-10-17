# Set PATH, MANPATH, etc., for Homebrew.
eval "$(/opt/homebrew/bin/brew shellenv)"

# Improve Homebrew security
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS=--require-sha
export HOMEBREW_NO_ANALYTICS=1

if which pyenv > /dev/null; then eval "$(pyenv init --path)"; fi
if which rbenv > /dev/null; then eval "$(rbenv init - zsh)"; fi
