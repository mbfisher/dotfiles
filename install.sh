#!/bin/bash

if ! which gfind >/dev/null; then
    echo "Install findutils!"
    echo "brew install findutils"
    exit 1
fi

if ! ls -l ~/Library/Fonts | grep -i powerline > /dev/null; then
    echo "Installing Powerline Fonts"
    [ ! -d /tmp/powerline-fonts ] && git clone https://github.com/powerline/fonts.git --depth=1 /tmp/powerline-fonts
    /tmp/powerline-fonts/install.sh
fi

if [ ! -d ~/.oh-my-zsh ]; then
    echo "Installing Oh My Zsh & Spaceship"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
    ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi

for FILE in $(./list.sh); do
    echo "Installing ~/$FILE"
    ln -sf $PWD/src/$FILE ~/$FILE
done
