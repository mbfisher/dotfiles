#!/bin/bash

for FILE in $(./scripts/list.sh); do
    if [ ! -e ~/$FILE ]; then
        echo "Installing $FILE"
        ln -sf $PWD/src/$FILE ~/$FILE
    fi
done
