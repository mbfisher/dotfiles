# Karabiner adds ~0.5s scroll latency to the Keychron M6 mouse

**Date:** 2026-08-03
**Status:** Fixed in `src/.config/karabiner/karabiner.json`
**Affects:** `src/.config/karabiner/karabiner.json`, `src/.config/karabiner/README.md`

## Symptoms

Two distinct faults, hit in sequence and easy to conflate:

1. **Jerky pointer** — cursor and scroll moved in visible jumps rather than smoothly.
2. **Laggy scroll** — after fixing (1), motion was smooth but every input landed roughly half a second late.

The second is the one this issue is about. Smooth-but-delayed is the signature that matters: dropped frames look
jerky, whereas a fixed delay with smooth interpolation means something is buffering events in the input path.

## Root cause

`karabiner.json` had `"ignore": false` on both `is_pointing_device` entries for the Keychron M6 (vendor `13364`,
products `53296` and `53286`), so Karabiner was grabbing the mouse.

Every event from a grabbed device is re-injected through the `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice` system
extension. That round trip costs latency, and the profile defined no `simple_modifications` or `complex_modifications`
whatsoever — so grabbing the mouse bought nothing and cost the delay. Karabiner is needed here only for
`"virtual_hid_keyboard": { "keyboard_type_v2": "iso" }`, which applies to the keyboard.

## Red herrings

- **`duetexpertd` spinning at ~76% CPU and WindowServer saturated at 33–70%.** This was real, and it was the cause of
  fault (1), the jerkiness. `sudo killall duetexpertd` plus quitting Firefox Developer Edition brought WindowServer
  back to 6–10%. But it did nothing for the latency — fixing it only made the separate second fault legible.
- **Bluetooth interference.** A Magic Mouse is paired over Bluetooth, which looked promising. Ruled out: WiFi was on
  5GHz channel 36 at -44 dBm, so it wasn't contending with 2.4GHz Bluetooth, and the laggy device was the USB Keychron.
- **Four processes named `2.1.220` burning ~26% CPU.** These are Claude Code's own `bg-pty-host` background hosts.
  Unrelated.
- **`log show` for HID/Karabiner subsystems.** Produced nothing — no timeouts, stalls or resets. The latency is
  by-design overhead of the grab, not an error condition, so it leaves no log trace. Absence of log lines is not
  evidence the input path is healthy.

## Fix

Set `"ignore": true` on both `is_pointing_device` entries. Karabiner reloads the file automatically; no restart or
re-login needed. The `is_game_pad` entries for the same product IDs were left alone — they aren't in the scroll path.

Equivalent GUI route: Karabiner-Elements → Settings → Devices → untick the pointing-device entries for vendor `13364`.

## Recurrence notes

`src/.config/karabiner` is a **whole-entry** symlink and Karabiner-Elements rewrites `karabiner.json` from its GUI.
Any device toggling in Settings → Devices can flip these flags back, and because the write lands inside the repo it
will show up in `git status` rather than being lost — check there first if the lag returns.

Newly attached pointing devices default to being grabbed, so a different mouse may present the same symptom with a new
`product_id`. The general rule for this setup: Karabiner should grab keyboards only.
