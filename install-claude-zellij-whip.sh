#!/bin/bash
# Install claude-zellij-whip: macOS notifications for Claude Code in Zellij
# that focus the correct terminal, tab, and pane when clicked.
# https://github.com/rvcas/claude-zellij-whip
set -euo pipefail

WHIP_REPO="https://github.com/rvcas/claude-zellij-whip"
ROOM_WASM_URL="https://github.com/rvcas/room/releases/latest/download/room.wasm"
ZELLIJ_PLUGINS_DIR="$HOME/.config/zellij/plugins"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
BUILD_DIR="$(mktemp -d)"

# The notification hook command that replaces terminal-notifier
WHIP_COMMAND='open ~/Applications/ClaudeZellijWhip.app --args notify --title '\''Claude Code'\'' --message '\''Waiting for your input'\'' --folder ${CLAUDE_PROJECT_DIR##*/}'

cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

# --- room plugin (pre-built WASM) ---
echo "> Installing room zellij plugin..."
mkdir -p "$ZELLIJ_PLUGINS_DIR"
if [ -f "$ZELLIJ_PLUGINS_DIR/room.wasm" ]; then
  echo "  room.wasm already exists, skipping (delete to re-download)"
else
  curl -fSL "$ROOM_WASM_URL" -o "$ZELLIJ_PLUGINS_DIR/room.wasm"
  echo "  Installed room.wasm"
fi

# --- ClaudeZellijWhip app ---
if [ -d "$HOME/Applications/ClaudeZellijWhip.app" ]; then
  echo "> ClaudeZellijWhip.app already installed, skipping (delete to reinstall)"
else
  echo "> Building ClaudeZellijWhip..."
  git clone --depth 1 "$WHIP_REPO" "$BUILD_DIR/claude-zellij-whip"
  cd "$BUILD_DIR/claude-zellij-whip"
  make install
  echo "  Installed to ~/Applications/ClaudeZellijWhip.app"
fi

# --- Terminal config (ghostty is the default, but be explicit) ---
CONFIG_DIR="$HOME/.config/claude-zellij-whip"
CONFIG_FILE="$CONFIG_DIR/config.toml"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "> Writing terminal config..."
  mkdir -p "$CONFIG_DIR"
  echo 'terminal = "ghostty"' > "$CONFIG_FILE"
  echo "  Created $CONFIG_FILE"
else
  echo "> Terminal config already exists at $CONFIG_FILE, skipping"
fi

# --- Claude Code notification hook ---
echo "> Configuring Claude Code notification hook..."
if [ ! -f "$CLAUDE_SETTINGS" ]; then
  echo "  Error: $CLAUDE_SETTINGS not found"
  exit 1
fi

# Check if the hook is already configured
if jq -e '.hooks.Notification[]?.hooks[]? | select(.command | contains("ClaudeZellijWhip"))' "$CLAUDE_SETTINGS" > /dev/null 2>&1; then
  echo "  Notification hook already configured, skipping"
else
  # Replace the entire Notification hooks array with the whip command
  jq --arg cmd "$WHIP_COMMAND" '
    .hooks.Notification = [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": $cmd
          }
        ]
      }
    ]
  ' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp"
  mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
  echo "  Updated notification hook in $CLAUDE_SETTINGS"
fi

echo ""
echo "Done!"
echo ""

# --- Test notification ---
read -rp "Send a test notification? [Y/n] " REPLY
REPLY="${REPLY:-Y}"
if [ "$REPLY" = "Y" ] || [ "$REPLY" = "y" ]; then
  open "$HOME/Applications/ClaudeZellijWhip.app" --args notify \
    --title "Claude Code" \
    --message "Test notification from install script" \
    --folder "dotfiles"
  echo "  Sent! You should see a notification."
fi
