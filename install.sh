#!/bin/bash

echo "> Installing from Brewfile..."
brew bundle

./sync.sh
./config.sh
