#!/bin/bash

MBF_BUNDLES+=(
    mattberther/zsh-rbenv
)

MBF_PROMPT_TOOLS+=(
    ruby
)

# if [ "$MBF_USE_RVM" = "true" ];  then
#     if ! [ -d ~/.rvm ]; then
#         echo "ℹ️  Installing RVM"
#         sh ~/dotfiles/scripts/install-rvm.sh
#     fi

#     # Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
#     export PATH="$HOME/.rvm/bin:$PATH"

#     [ -s "$HOME/.rvm/scripts/rvm" ] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
# else
#     if ! which rbenv > /dev/null; then
#         echo "ℹ️  Installing rbenv"
#         brew install rbenv
#     fi
# fi
