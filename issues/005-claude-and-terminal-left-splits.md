# Claude Code and the shell terminal open a third split, and toggles close the wrong window

**Date:** 2026-07-28
**Status:** Fixed in `src/.config/nvim/lua/util/sidebar.lua`
**Affects:** `src/.config/nvim/lua/util/sidebar.lua`, `src/.config/nvim/lua/config/keymaps.lua`,
`src/.config/nvim/lua/plugins/claudecode.lua`, `src/.config/ghostty/config`

## Symptoms

With Claude Code running as an nvim split (claudecode.nvim, snacks provider, `split_side = "left"`)
and the `<C-/>` shell terminal also configured as a left split:

- Opening one while the other was visible gave **three** side-by-side splits (code + shell + Claude)
  instead of them sharing the left column.
- With all three open, `<C-/>` closed the **Claude** window rather than the shell.
- Toggling either one repeatedly walked the layout into states that needed manual `:q` to escape.

## Root cause

Snacks' `terminal` window style sets `stack = true`. When a second split opens with the same
`position`, `Snacks.win:open_win()` looks for an existing window whose `w:snacks_win` records the
same `relative` **and** `position` **and** `stack == true`; on a match it opens the new window
*perpendicular* to that one (`relative = "win"`, `position = "bottom"`) — i.e. the two terminals
share the left column, which is the wanted layout.

claudecode.nvim's snacks provider breaks that bookkeeping. It does not let snacks hide/show its
window (snacks closes and recreates it, which climbs Claude's cursor one row per toggle — its
issues #240/#183). Instead `cc_show()` recreates the split by hand with a plain
`topleft <width>vsplit` and re-stamps `w:snacks_win` as `{ id, position }` only —
`reapply_snacks_window_state()` drops `relative` and `stack`.

So the *first* open stacked, but after Claude had been hidden even once, snacks no longer recognised
its window as stackable and opened a whole new column. The wrong-window closes came from the same
place: `Snacks.win:hide()` closes `self.win`, and the two terminals' recorded windows no longer
matched what was on screen.

### Second cause: LazyVim's buffer-local `<C-/>`

Even with the placement fixed, `<C-/>` pressed while focused in the Claude Code split still *closed
Claude* instead of opening the shell below it. LazyVim adds two **buffer-local** terminal-mode keys to
every snacks terminal window (`lazyvim/plugins/util.lua`, in `opts.terminal.win.keys`):

```lua
hide_slash      = { "<C-/>", "hide", desc = "Hide Terminal", mode = "t" },
hide_underscore = { "<c-_>", "hide", desc = "which_key_ignore", mode = "t" },
```

Claude Code is a snacks terminal, so it got them too, and a buffer-local mapping always beats the
global one — `<C-/>` inside Claude meant "hide *this* window". Fixed by disabling both in
`plugins/snacks.lua` (`terminal.win.keys.hide_slash = false`, same for `hide_underscore`); snacks
skips any key whose spec is falsy. The global keymaps then own both keys from anywhere: `<C-/>` is
always the shell, `<C-;>` always Claude.

## Red herrings

- It looks like a `position`/`split_side` mismatch. Both were already `"left"`; the position was
  never the problem.
- `equalize()` looks like the culprit for the odd sizes. It filters on the same `w:snacks_win`
  fields, so with Claude's window mis-stamped it silently no-ops instead of misbehaving.

## Fix

Stop relying on snacks' stacking and place the two windows explicitly, in
`src/.config/nvim/lua/util/sidebar.lua`:

- `stack = false` on both terminals (`win.stack` for the shell, `terminal.snacks_win_opts.stack` for
  claudecode) so each opens as its own left column deterministically.
- After a show, `win_splitmove()` the new window into the existing one's column — Claude above, shell
  below — then size it to half the screen height at the remembered column width. Deferred with
  `vim.schedule()` so it lands after snacks' own scheduled `equalize()`.
- A hide is left alone: nvim gives the freed rows to whatever still shares the column, so the
  survivor goes full height by itself.

Toggling is symmetric and independent: `<C-/>` for the shell, `<C-;>` for Claude, both mapped in
normal **and terminal** mode so they work from inside either terminal (a `<leader>` sequence can't —
at the Claude prompt it just goes to Claude). `<C-;>` needs a Ghostty bind to survive zellij:

```
keybind = ctrl+semicolon=text:\x1b[59;5u
```

## Recurrence notes

- The trigger is claudecode.nvim's hand-rolled window recreate. If a future version stops doing that
  (its cursor-drift workaround), snacks' native stacking could take over again — but note snacks
  stacks the *newer* window below the older one, so Claude would land under the shell rather than
  above it.
- `util/sidebar.lua` finds the column geometrically (non-floating window at column 0 with something
  sharing its row) rather than through `w:snacks_win`, precisely because those vars are not
  dependable. Keep it that way.
- Verified end to end headless against the real provider (`terminal_cmd` stubbed with `cat`): every
  show/hide order keeps exactly one left column, the survivor at full height, and a width cycled with
  Option+[ / Option+] persists across toggles.
