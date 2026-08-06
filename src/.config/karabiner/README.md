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

## Karabiner should grab keyboards only

The config lists no pointing devices at all. That is deliberate: Karabiner is needed only for the keyboard ISO setting
above and does no pointer remapping whatsoever. Every event from a device Karabiner grabs is re-injected through the
DriverKit virtual HID device, which costs latency — on the Keychron M6 it added roughly half a second of scroll lag for
no benefit.

The M6 entries (vendor `13364`, products `53296` and `53286`) previously sat here with `"ignore": true` to keep that
mouse out of the grab. They were removed once it became clear the M6 is never used on this machine.

**If you ever attach a mouse or trackball here, expect the lag to come back** — newly attached pointing devices default
to being grabbed, and there is no longer a rule pre-empting that. Fix it in Karabiner-Elements → Settings → Devices by
unticking the new pointing-device entry. See `issues/006-karabiner-mouse-scroll-lag.md`.

Careful: this directory is whole-entry symlinked and Karabiner-Elements rewrites `karabiner.json` from its GUI, so
device changes made in Settings land back in this repo and show up in `git status`.
