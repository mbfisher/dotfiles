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

### Third cause: snacks' `equalize()` inflates `cmdheight`

Once both terminals could be open at once, stacking them left a **dead band at the bottom of the
screen** — nvim's content stopped about a third of the way down, statusline included, and it stayed
that way after closing both terminals.

That band is the command line. `Snacks.win:open_win()` ends with
`vim.schedule(function() self:equalize() end)`, and `equalize()` resizes the height of every window
whose `w:snacks_win` records the same `relative` + `position` — i.e. both "left" terminals. It fires
while they are still **side by side**, each a full-height column of its own, so it shrinks a
full-height window. nvim can't take those rows from a sibling (there isn't one vertically), so it
shrinks the topframe and grows `'cmdheight'` instead, and that sticks:

```
C-; claude alone      cmdheight=1   claude 66x58 | code 133x58
C-/ shell -> stacked  cmdheight=26  claude 66x2  | shell 66x30 | code 133x33
hide shell            cmdheight=26  <- outlives the terminals
```

Two fixes in `util/sidebar.lua`:

- `without_equalize()` suppresses `Snacks.win.equalize` for the single tick the scheduled call lands
  in. It's patched on the class, not the instance, because claudecode.nvim owns its terminal object
  and only exposes it through a `_get_terminal_for_test` helper. `equalize()` exists to balance
  snacks' own stacking, which is off here, so nothing is lost.
- `place()` sizes the window to half of the rows the two windows actually have between them, rather
  than half of `vim.o.lines`. Asking for more rows than the column holds (winbars and the statusline
  take some) triggers the same topframe shrink.

**This class of bug is invisible to `nvim --headless`** — with no UI attached there is no real grid,
so the topframe never shrinks and `cmdheight` stays 1. It only reproduces with a UI on a pty of known
size (`scratchpad/pty_run.py` in the session that fixed this drove nvim on a 200x60 pty and logged
`vim.o.lines` / `cmdheight` / window rects after each toggle). Test geometry changes that way.

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

## Related: the sidebar can't be the last window

Closing the last code window while the sidebar was open used to be a dead end. The column filled the
screen, and neither terminal could be hidden to make room, because nvim refuses to close the last
window: claudecode's `cc_hide` pcalls `nvim_win_close` and treats the E444 failure as a no-op, and
snacks' `close()` catches E444 by splitting and closing again, which just leaves the same terminal
buffer on screen. Being stuck in terminal insert mode made it worse — there was nowhere to go.

`config/autocmds.lua` now handles both halves of that. When only sidebar windows remain it creates a
window on the right; what goes in it depends on whether any work is left open — the most recently used
listed file if there is one, the LazyVim home screen (`Snacks.dashboard.open`) if there isn't. The home
screen is also what replaces the last deleted buffer in an existing code window.
`util/sidebar.lua` exposes `is_sidebar_win()` and `restore_width()` for the sidebar-specific parts.

Two mistakes worth not repeating, both from the first attempt:

- It opened the home screen whenever the code *window* was gone, even with files still open. The
  dashboard buffer is `buflisted = false`, so bufferline could not locate a current position and
  `<S-h>` / `<S-l>` silently stopped cycling. Show a file when there is one.
- It made the window with `:vnew`, whose empty buffer **is** listed, so it lingered in the bufferline
  as a stray `[No Name]` the moment the dashboard replaced it in the window. Use `:vsplit` and set the
  buffer, and when the home screen lands in a window already holding a throwaway empty buffer (what
  nvim leaves after the last file is deleted), pass that buffer to `Snacks.dashboard.open` as its own
  so it gets taken over rather than orphaned.

## Keeping the buffer tabs off the sidebar

bufferline's tabline is inherently full width, so the buffer tabs ran across the top of the sidebar as
well as the code window. `plugins/bufferline.lua` adds an `offsets` entry for `filetype =
"snacks_terminal"`, which reserves the left portion of the tabline and paints it in that window's own
background — the same mechanism LazyVim uses for the snacks explorer (`snacks_layout_box`). One entry
covers all three layouts, because bufferline reads the width from the topmost window of a split column
(`is_valid_layout` handles the `{'col', {'leaf'}, {'leaf'}}` case explicitly).

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
