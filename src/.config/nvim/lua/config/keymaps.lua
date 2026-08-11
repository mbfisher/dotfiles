-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Toggle comment with Cmd+/
vim.keymap.set("n", "<D-/>", "gcc", { remap = true, desc = "Toggle comment" })
vim.keymap.set("v", "<D-/>", "gc", { remap = true, desc = "Toggle comment" })

-- Yank to system clipboard (delete stays in vim register for dd+p line swapping)
vim.keymap.set({ "n", "v" }, "y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("n", "Y", '"+Y', { desc = "Yank to end of line to system clipboard" })
vim.keymap.set("n", "yy", '"+yy', { desc = "Yank line to system clipboard" })

-- Cmd+[ / Cmd+] to navigate jumplist (cursor position history)
-- Ghostty sends CSI u sequences for these; see ghostty/config
vim.keymap.set("n", "<D-[>", "<C-o>", { desc = "Jump to previous cursor position" })
vim.keymap.set("n", "<D-]>", "<C-i>", { desc = "Jump to next cursor position" })

-- Paste from system clipboard. If the clipboard holds an image, defer to img-clip.nvim
-- (writes image to disk + inserts a markdown link); otherwise fall back to "+p.
-- Without this, <leader>p in keymaps.lua wins over the plugin's lazy keys mapping and
-- pastes from the empty "+" register when an image is on the clipboard.
-- Guard the "+p fallback: if the register is empty, "+p throws E353 with a stack trace;
-- show a clean message instead so the user knows neither image nor text was available.
vim.keymap.set({ "n", "v" }, "<leader>p", function()
  local ok, img_clip = pcall(require, "img-clip")
  if ok and img_clip.paste_image() then
    return
  end
  if vim.fn.getreg("+") == "" then
    vim.notify("Clipboard is empty (no image, no text)", vim.log.levels.WARN)
    return
  end
  vim.cmd('normal! "+p')
end, { desc = "Paste from system clipboard (or image via img-clip)" })
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P', { desc = "Paste from system clipboard (before)" })

-- Yank current buffer path to system clipboard. LazyVim's <leader>f group
-- has no fy/fY out of the box; fill the gap rather than open a picker.
-- %:. forces relative-to-cwd — %  alone returns whatever the buffer was
-- opened with, which is often absolute (e.g. via Snacks picker).
vim.keymap.set("n", "<leader>fy", function()
  local p = vim.fn.expand("%:.")
  vim.fn.setreg("+", p)
  vim.notify(p)
end, { desc = "Yank relative path" })
vim.keymap.set("n", "<leader>fY", function()
  local p = vim.fn.expand("%:p")
  vim.fn.setreg("+", p)
  vim.notify(p)
end, { desc = "Yank absolute path" })

-- Toggle a persistent shell terminal in the LEFT SIDEBAR COLUMN, sharing it with the
-- Claude Code split (<C-;>): the shell takes the bottom half when Claude is open, the
-- full column height when it isn't. Layout and persistence details live in util/sidebar.
-- Overrides LazyVim's <C-/> (and <C-_>, what some terminals send for it), which opens
-- a bottom horizontal split — never wanted here. LazyVim's floating terminals are
-- untouched on <leader>ft / <leader>fT.
local sidebar = require("util.sidebar")
vim.keymap.set({ "n", "t" }, "<C-/>", sidebar.toggle_shell, { desc = "Terminal (left split)" })
vim.keymap.set({ "n", "t" }, "<C-_>", sidebar.toggle_shell, { desc = "which_key_ignore" })

-- Option+] / Option+[ cycle the left split (shell / Claude Code) through fixed widths:
-- 33-66 -> 50-50 (the default) -> 66-33. Steps clamp at each end rather than wrapping, so
-- holding one key can't overshoot back to the other extreme.
-- Took over from the zellij "Alt [" / "Alt ]" pane-resize binds — claude is an nvim window
-- now, not a zellij pane. Ghostty sends these as CSI u text (see ghostty/config) so they reach
-- nvim through zellij; mapped in terminal mode too, so they work while typing at the Claude prompt.
-- Both halves of the column share its width, so resizing either one resizes the column.
local sidebar_steps = { 0.33, 0.5, 0.66 }

---@param widen boolean true to widen the left split, false to narrow it
local function cycle_sidebar_width(widen)
  return function()
    local win = sidebar.win()
    if not win then
      return
    end
    -- Step to the next size PAST the current width rather than indexing a remembered step:
    -- after a manual drag to ~45% this lands on 50%, and it can't get out of sync with the
    -- window's real width. The 0.02 tolerance absorbs the ±1 column rounding, so a width
    -- that's already on a step steps off it instead of re-selecting itself.
    local frac = vim.api.nvim_win_get_width(win) / vim.o.columns
    local target = sidebar_steps[widen and #sidebar_steps or 1] -- clamp at the ends
    if widen then
      for _, step in ipairs(sidebar_steps) do
        if step > frac + 0.02 then
          target = step
          break
        end
      end
    else
      for i = #sidebar_steps, 1, -1 do
        if sidebar_steps[i] < frac - 0.02 then
          target = sidebar_steps[i]
          break
        end
      end
    end
    vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * target))
  end
end
vim.keymap.set({ "n", "t" }, "<M-]>", cycle_sidebar_width(true), { desc = "Widen left split" })
vim.keymap.set({ "n", "t" }, "<M-[>", cycle_sidebar_width(false), { desc = "Narrow left split" })

-- Option+z fullscreens the focused nvim window, one level down from zellij's own Alt+z
-- (ToggleFocusFullscreen). Zellij binds it in every mode except "locked", so Ctrl+g then Option+z
-- forwards the same keypress here: one key zooms whatever is actually in front of you, a zellij pane
-- or an nvim window. Mapped in terminal mode too, so it works from the Claude prompt.
--
-- Deliberately NOT LazyVim's <leader>wm (Snacks zen zoom): that re-shows the buffer in a full-screen
-- FLOAT, and a float holding the Claude terminal buffer makes util/sidebar's window lookups match it —
-- claude_win() finds the float, and the WinNew that opening it fires sends ensure_leftmost() at a
-- window that can't be moved. Maximising in place leaves the real split layout alone, so winrestcmd()
-- puts every window back at the exact size it had, sidebar width included.
---@type { cmd: string, wins: integer, winbars: table<integer, string> }? state from before the zoom
local zoom
local function toggle_zoom()
  local wins = #vim.api.nvim_tabpage_list_wins(0)
  if zoom then
    -- winrestcmd() addresses windows by number, so it only means what it said while the layout is
    -- unchanged. If something opened or closed while zoomed, drop the state rather than resizing the
    -- wrong windows — the next press just zooms again from here.
    for win, winbar in pairs(zoom.winbars) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_option_value("winbar", winbar, { win = win })
      end
    end
    if zoom.wins == wins then
      vim.cmd(zoom.cmd)
    end
    zoom = nil
  elseif wins > 1 and vim.api.nvim_win_get_config(0).relative == "" then
    zoom = { cmd = vim.fn.winrestcmd(), wins = wins, winbars = {} }
    -- Squeezed windows keep drawing two things a zero height/width can't take away: their winbar (a
    -- screen row of its own — the snacks terminals title theirs, so stacking Claude over the shell left
    -- a "term://…/bin/zsh" strip across the bottom) and their separator line. Clear the winbars, keep
    -- the separators — the frame around a maximised window is a useful reminder that it's zoomed.
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local winbar = vim.api.nvim_get_option_value("winbar", { win = win })
      if win ~= vim.api.nvim_get_current_win() and winbar ~= "" then
        zoom.winbars[win] = winbar
        vim.api.nvim_set_option_value("winbar", "", { win = win })
      end
    end
    -- LazyVim sets winminwidth = 5, so maximising otherwise left a 5-column strip of the neighbour
    -- still rendering its content. Drop both floors for the resize only — the sizes stick once they're
    -- put back.
    local minwidth, minheight = vim.o.winminwidth, vim.o.winminheight
    vim.o.winminwidth, vim.o.winminheight = 0, 0
    vim.cmd.wincmd("_")
    vim.cmd.wincmd("|")
    vim.o.winminwidth, vim.o.winminheight = minwidth, minheight
  end
  -- wincmd drops terminal insert mode, same as util/sidebar's move().
  if vim.fn.mode() == "t" then
    vim.cmd.startinsert()
  end
end
vim.keymap.set({ "n", "t" }, "<M-z>", toggle_zoom, { desc = "Zoom window (toggle)" })

-- Horizontal mouse scroll (Magic Mouse, Keychron M6 horizontal wheel).
--
-- These DON'T fire in my normal setup, and it isn't nvim's fault: zellij drops horizontal wheel
-- events instead of forwarding them to the pane, so <ScrollWheelLeft>/<ScrollWheelRight> never
-- reach nvim through ghostty > zellij > nvim. See zellij-org/zellij#4628; the fix (PR #4860) is
-- still open and unmerged as of 0.44.3. Keep the maps — they work in a bare ghostty pane, and
-- they'll start working inside zellij the moment that PR lands.
vim.keymap.set({ "n", "v" }, "<ScrollWheelLeft>", "3zh", { desc = "Scroll left" })
vim.keymap.set({ "n", "v" }, "<ScrollWheelRight>", "3zl", { desc = "Scroll right" })
