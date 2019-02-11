#!/bin/bash

set -e

if [ ! -d /Library/Developer/CommandLineTools ]; then
    echo "⏱  Installing command line tools"
    xcode-select --install
    sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg -target /
fi

if ! which brew > /dev/null; then
    echo "⏱  Installing homebrew"
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo -e "⏱  Installing Homebrew packages"
# ./scripts/brew.sh

git submodule update

if ! ls -l ~/Library/Fonts | grep -i powerline > /dev/null; then
    echo "⏱  Installing Powerline Fonts"
    [ ! -d /tmp/powerline-fonts ] && git clone https://github.com/powerline/fonts.git --depth=1 /tmp/powerline-fonts
    /tmp/powerline-fonts/install.sh
fi

echo "⏱  Installing Antigen"
curl -LSs git.io/antigen > ~/.antigen.zsh

echo "⏱  Configuring iTerm"
defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "$PWD/iterm2"
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

echo "⏱  Installing dotfiles"
./scripts/dotfiles.sh
