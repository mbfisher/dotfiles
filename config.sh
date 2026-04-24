#!/bin/bash

# Disable macOS shortcuts that intercept keys before they reach terminal apps like nvim
# Ctrl+Space: Select previous input source
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 '{"enabled" = 0; "value" = {"parameters" = (32, 49, 262144); "type" = "standard"; }; }'
# Ctrl+Option+Space: Select next input source
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '{"enabled" = 0; "value" = {"parameters" = (32, 49, 786432); "type" = "standard"; }; }'
# Ctrl+Left: Move left a space
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 79 '{"enabled" = 0; "value" = {"parameters" = (65535, 123, 8650752); "type" = "standard"; }; }'
# Ctrl+Right: Move right a space
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 81 '{"enabled" = 0; "value" = {"parameters" = (65535, 124, 8650752); "type" = "standard"; }; }'
# Ctrl+Up: Mission Control
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 32 '{"enabled" = 0; "value" = {"parameters" = (65535, 126, 8650752); "type" = "standard"; }; }'
# Ctrl+Down: Application Windows
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 33 '{"enabled" = 0; "value" = {"parameters" = (65535, 125, 8650752); "type" = "standard"; }; }'
# Apply changes without restarting
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
