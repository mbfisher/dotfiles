# Karabiner Configuration

## Why Karabiner is needed

The Keychron K3 Max connects through the Dell U2723QE monitor's KVM, which presents the keyboard to macOS as ANSI layout instead of ISO.

The key setting in `karabiner.json` is:

```json
"virtual_hid_keyboard": { "keyboard_type_v2": "iso" }
```

This makes Karabiner's virtual keyboard output as ISO, so macOS correctly interprets the keycodes.

**Without Karabiner running**, the key left of Z produces § instead of `.

**With Karabiner running**, the keys work correctly - no remapping needed, just the ISO virtual keyboard setting.
