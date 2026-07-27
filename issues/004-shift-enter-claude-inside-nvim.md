# Shift+Enter inserts no newline in Claude Code running inside nvim

**Date:** 2026-07-27
**Status:** Fixed in `src/.config/ghostty/config`
**Affects:** `src/.config/ghostty/config`, `src/.config/nvim/lua/plugins/claudecode.lua`

## Symptoms

After moving Claude Code inside nvim (claudecode.nvim, snacks terminal provider in a left
split), Shift+Enter no longer inserts a blank line at the Claude prompt — it either submits
the message or appears to do nothing. Shift+Enter worked fine in a bare Ghostty/zellij pane.

## Root cause

`src/.config/ghostty/config` had:

```
keybind = shift+enter=text:\n
```

That sends a literal `\n` — byte `0x0a`. In vim, `0x0a` **is** `<C-j>` / `<NL>`; they are the
same keycode, indistinguishable. LazyVim maps `<C-j>` in *terminal* mode for window navigation
(`nav_j`, in its snacks terminal spec), so nvim consumed the byte as "go to the window below"
and it never reached the Claude process.

Outside nvim nothing intercepted the byte, so Claude received `0x0a` and inserted a newline —
hence "works outside, broken inside".

## Fix

Comment out the Ghostty keybind and let Ghostty use its native kitty-keyboard encoding for
Shift+Enter, `ESC[13;2u` (CSI u). Verified end to end:

| Link in the chain | Verified behaviour |
|---|---|
| Bare `claude` CLI | Pushes `ESC[>1u` (kitty disambiguate) at startup; `ESC[13;2u` inserts a newline |
| zellij 0.43.1 | Pushes `ESC[>1u` upstream itself, so Ghostty enables CSI u encoding |
| zellij → pane | Forwards raw `ESC[13;2u` to panes that declare kitty support; downgrades to CR for those that don't |
| nvim | Decodes it to `<S-CR>`; claudecode.nvim's buffer-local `claude_new_line` mapping sends `\` + CR |

So one encoding serves both cases: Claude in a bare pane and Claude inside nvim.

`ESC\r` (meta+enter, what Claude's own `/terminal-setup` configures for iTerm2) also works in
both — it passes through nvim unmapped — but it needs a Ghostty keybind, so the native CSI u
path is preferred as it needs no config at all.

## Red herrings

- **"The plugin's `<S-CR>` mapping must be broken."** It was fine. Nothing was reaching it,
  because Ghostty never sent a shift-modified Enter in the first place.
- **"zellij eats kitty-protocol keys."** It doesn't — it negotiates upstream and forwards
  per-pane based on what each pane declared. The CSI u `text:` keybinds for Cmd+[ / Cmd+]
  elsewhere in the Ghostty config are needed because Ghostty consumes `super` for its own
  bindings, not because zellij mangles anything.

## Recurrence notes

Re-adding any `shift+enter=text:…` Ghostty keybind that emits `\n` will break this again.
The same `0x0a == <C-j>` collision applies to any terminal-mode key a terminal encodes as a
raw control byte — check `:tmap` / LazyVim's terminal keys before blaming the program inside.

To reproduce the diagnosis quickly: run the program in a pty and feed candidate byte
sequences, rendering the screen with `pyte` to see whether a newline landed.
