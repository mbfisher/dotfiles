if which pyenv > /dev/null; then eval "$(pyenv init --path)"; fi
if which rbenv > /dev/null; then eval "$(rbenv init - zsh)"; fi

# Improve Homebrew security
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS=--require-sha
export HOMEBREW_NO_ANALYTICS=1