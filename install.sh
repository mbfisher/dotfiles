#!/bin/bash

git submodules update

if ! which brew; then
    echo "Installing homebrew"
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo -e "\nInstalling Homebrew packages"
./scripts/brew.sh

echo -e "\nInstalling Spaceship"
npm install -g spaceship-prompt

if ! ls -l ~/Library/Fonts | grep -i powerline > /dev/null; then
    echo -e "\nInstalling Powerline Fonts"
    [ ! -d /tmp/powerline-fonts ] && git clone https://github.com/powerline/fonts.git --depth=1 /tmp/powerline-fonts
    /tmp/powerline-fonts/install.sh
fi

if [ ! -d ~/.oh-my-zsh ]; then
    echo -e "\nInstalling Oh My Zsh"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
else
    echo -e "\nUpdating Oh My Zsh"
    cd ~/.oh-my-zsh
    git fetch
    git reset --hard origin/master
    cd -
fi

ZSH_CUSTOM=~/.oh-my-zsh/custom

if [ ! -f ${ZSH_CUSTOM} ]; then
    echo -e "\nInstalling Spaceship"
    git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship"
    ln -s "$ZSH_CUSTOM/themes/spaceship/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
else
    echo -e "\nUpdating Spaceship"
    cd "$ZSH_CUSTOM/themes/spaceship"
    git fetch
    git reset --hard origin/master
    cd -
fi

echo -e "\nConfiguring iTerm"
defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "$PWD/iterm2"
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

echo -e "\nInstalling dotfiles"
./scripts/dotfiles.sh
