#!/bin/bash

[ ! -d ~/.oh-my-zsh ] && sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

for FILE in $(./list.sh); do
    echo "Installing ~/$FILE"
    ln -sf $PWD/src/$FILE ~/$FILE
done
