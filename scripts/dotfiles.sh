#!/bin/bash

for DOTFILE in $(find src -type f -maxdepth 1 | cut -sd / -f 2-); do
    ln -vs $PWD/src/$DOTFILE ~/$DOTFILE
done

mkdir -p ~/.config
for CONFIG_DIR in $(find src/.config -type d -mindepth 1 -maxdepth 1 | cut -sd / -f 3-); do
    ln -vs $PWD/src/.config/$CONFIG_DIR ~/.config/$CONFIG_DIR
done
