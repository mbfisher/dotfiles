#!/bin/bash

set -e

brew bundle

chsh -s /bin/zsh
curl -LSs git.io/antigen >~/.antigen.zsh
curl https://mise.run | sh

echo "Installing dotfiles"
./scripts/dotfiles.sh
