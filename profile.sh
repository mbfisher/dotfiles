#!/bin/bash

set -euxo pipefail

PROFILE=$1

if [ -f $PROFILE/brew-formula.txt ]; then
    cat $PROFILE/brew-formula.txt | xargs brew install
fi

if [ -f $PROFILE/brew-cask.txt ]; then
    cat $PROFILE/brew-cask.txt | xargs brew cask install
fi
