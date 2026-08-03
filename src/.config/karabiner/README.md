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

## Why the M6 mouse is ignored

The two `is_pointing_device` entries for the Keychron M6 (vendor `13364`, products `53296` and `53286`) are set to
`"ignore": true`.

Karabiner is only needed for the keyboard ISO setting above — it does no pointer remapping at all. But every event from
a device Karabiner grabs is re-injected through the DriverKit virtual HID device, and for the mouse that added roughly
half a second of scroll latency. Ignoring it takes Karabiner out of the pointer path entirely while leaving the
keyboard fix intact.

The `is_game_pad` entries for the same product IDs are deliberately left alone — they aren't in the scroll path.

Careful: this directory is whole-entry symlinked and Karabiner-Elements rewrites `karabiner.json` from its GUI, so
toggling devices in Settings → Devices can silently flip these back. See `issues/006-karabiner-mouse-scroll-lag.md`.
