#!/bin/bash

for CONFIG in $(find src/.config -maxdepth 1 -mindepth 1 | sed 's|^src/.config/||'); do
  TARGET="$HOME/.config/$CONFIG"
  SOURCE="$PWD/src/.config/$CONFIG"

  if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$SOURCE" ]; then
    continue
  fi

  CONFIRM="Y"
  if [ -e "$TARGET" ]; then
    echo -n "$TARGET exists: overwrite [Y/n]: "
    read CONFIRM
  fi

  if [ "$CONFIRM" = "Y" ] || [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "" ]; then
    echo "Installing .config/$CONFIG"
    rm -rf "$TARGET"
    ln -sf $PWD/src/.config/$CONFIG ~/.config/$CONFIG
  fi
done

for FILE in $(find src -maxdepth 1 -mindepth 1 | sed 's|^src/||'); do
  if [ "$FILE" = ".config" ] || [ "$FILE" = "CLAUDE.md" ]; then
    continue
  fi

  TARGET="$HOME/$FILE"
  SOURCE="$PWD/src/$FILE"

  if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$SOURCE" ]; then
    continue
  fi

  CONFIRM="Y"
  if [ -e "$TARGET" ]; then
    echo -n "$TARGET exists: overwrite [Y/n]: "
    read CONFIRM
  fi

  if [ "$CONFIRM" = "Y" ] || [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "" ]; then
    echo "Installing $FILE"
    rm -rf "$TARGET"
    ln -sf $PWD/src/$FILE ~/$FILE
  fi
done
