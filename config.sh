#!/bin/bash

# Disable macOS shortcuts that intercept keys before they reach terminal apps like nvim.
#
# Each `defaults write -dict-add` is followed by a `plutil -replace ... -bool false`. The dict-string syntax
# (`'{"enabled" = 0; ...}'`) stores `enabled` as <string>0</string>, not <false/>. Some shortcut IDs (e.g.
# 79/81 space movement) accept the string form, but the Dock checks Mission Control IDs (32/33) strictly
# and treats any non-empty string as truthy — so without the plutil coercion, Ctrl+Up still triggers
# Mission Control after logout. plutil rewrites the value as a proper boolean.

HOTKEYS=~/Library/Preferences/com.apple.symbolichotkeys.plist

# Ctrl+Space: Select previous input source
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 '{"enabled" = 0; "value" = {"parameters" = (32, 49, 262144); "type" = "standard"; }; }'
plutil -replace "AppleSymbolicHotKeys.60.enabled" -bool false "$HOTKEYS"
# Ctrl+Option+Space: Select next input source
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '{"enabled" = 0; "value" = {"parameters" = (32, 49, 786432); "type" = "standard"; }; }'
plutil -replace "AppleSymbolicHotKeys.61.enabled" -bool false "$HOTKEYS"
# Ctrl+Left: Move left a space
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 79 '{"enabled" = 0; "value" = {"parameters" = (65535, 123, 8650752); "type" = "standard"; }; }'
plutil -replace "AppleSymbolicHotKeys.79.enabled" -bool false "$HOTKEYS"
# Ctrl+Right: Move right a space
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 81 '{"enabled" = 0; "value" = {"parameters" = (65535, 124, 8650752); "type" = "standard"; }; }'
plutil -replace "AppleSymbolicHotKeys.81.enabled" -bool false "$HOTKEYS"
# Ctrl+Up: Mission Control
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 32 '{"enabled" = 0; "value" = {"parameters" = (65535, 126, 8650752); "type" = "standard"; }; }'
plutil -replace "AppleSymbolicHotKeys.32.enabled" -bool false "$HOTKEYS"
# Ctrl+Down: Application Windows
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 33 '{"enabled" = 0; "value" = {"parameters" = (65535, 125, 8650752); "type" = "standard"; }; }'
plutil -replace "AppleSymbolicHotKeys.33.enabled" -bool false "$HOTKEYS"

# Apply changes. activateSettings refreshes most prefs, but Mission Control bindings are owned by the Dock,
# which only re-reads the plist on launch — so killall Dock is required for IDs 32/33 to take effect now.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
killall Dock
