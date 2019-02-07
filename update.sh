#!/bin/bash

ZSH_CUSTOM=~/.oh-my-zsh/custom

for DIR in ~/.oh-my-zsh $ZSH_CUSTOM/themes/spaceship-prompt; do
    echo "Updating $DIR"
    git --git-dir=$DIR/.git --work-tree $DIR pull origin master
done