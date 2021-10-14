if ! which pyenv > /dev/null; then
    set -x
    brew install pyenv
    set +x
fi

# pyenv
log "init pyenv"
eval "$(pyenv init -)"
if which pyenv virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

MBF_PROMPT_TOOLS+=pyenv