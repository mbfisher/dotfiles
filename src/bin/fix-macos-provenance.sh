#!/bin/bash
# Fixes com.apple.provenance issues that cause nvim to crash on macOS 26+.
# macOS propagates this xattr to all files a process creates, so tainted terminals
# and editors produce tainted .so/.dylib files that fail code signature validation
# on dlopen, resulting in SIGKILL.
#
# Stripping the xattr alone isn't enough — Gatekeeper caches the rejection. We must
# also re-sign the binaries with `codesign --force --sign -` to clear the cache.
# See: https://github.com/astral-sh/uv/issues/16726
#
# For a permanent fix, add Ghostty to System Settings > Privacy & Security >
# Developer Tools. This prevents provenance propagation from Ghostty's process tree.
# See: https://github.com/ghostty-org/ghostty/discussions/4787
#
# Run this from Terminal.app (not Ghostty) if the process tree is tainted.
# See ~/.config/nvim/issues/001-macos-provenance-crash.md

set -e

TARGETS=(
  "/Applications/Ghostty.app"
  "/opt/homebrew/bin/nvim"
)

for target in "${TARGETS[@]}"; do
  if [ -e "$target" ] && xattr "$target" 2>/dev/null | grep -q com.apple.provenance; then
    echo "Stripping com.apple.provenance from $target"
    sudo xattr -r -d com.apple.provenance "$target"
  fi
done

# Re-sign tainted treesitter parsers — codesign --force clears Gatekeeper's cached
# rejection, which persists even after xattr removal.
PARSER_DIR="$HOME/.local/share/nvim/site/parser"
if ls "$PARSER_DIR"/*.so &>/dev/null; then
  if xattr "$PARSER_DIR"/*.so 2>/dev/null | grep -q com.apple.provenance; then
    echo "Stripping provenance and re-signing treesitter parsers"
    for so in "$PARSER_DIR"/*.so; do
      xattr -d com.apple.provenance "$so" 2>/dev/null
      codesign --force --sign - "$so"
    done
  fi
fi

# Re-sign tainted blink.cmp Rust binary
BLINK_DYLIB="$HOME/.local/share/nvim/lazy/blink.cmp/target/release/libblink_cmp_fuzzy.dylib"
if [ -f "$BLINK_DYLIB" ] && xattr "$BLINK_DYLIB" 2>/dev/null | grep -q com.apple.provenance; then
  echo "Stripping provenance and re-signing blink.cmp binary"
  xattr -d com.apple.provenance "$BLINK_DYLIB"
  codesign --force --sign - "$BLINK_DYLIB"
fi

echo "Done. Restart Ghostty and open nvim."
