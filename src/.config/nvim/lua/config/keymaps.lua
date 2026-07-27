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

-- Toggle a persistent shell terminal in a LEFT VERTICAL split.
-- Overrides LazyVim's <C-/> (and <C-_>, what some terminals send for it), which opens
-- a bottom horizontal split — never wanted here. LazyVim's floating terminals are
-- untouched on <leader>ft / <leader>fT.
-- Persistence: Snacks keys terminals on cmd + cwd + env + count, so toggling with the
-- same args reuses the same shell instead of spawning a new one. cwd is pinned to the
-- GLOBAL cwd (getcwd(-1)) rather than LazyVim.root() so a buffer with a different
-- project root can't silently create a second terminal.
-- Note: snacks' "terminal" style sets stack = true, so this and the Claude Code split
-- (also position = "left") stack in the same left column rather than fighting over it.
local function shell_terminal()
  Snacks.terminal.toggle(nil, {
    cwd = vim.fn.getcwd(-1),
    win = { position = "left", width = 0.33 },
  })
end
vim.keymap.set({ "n", "t" }, "<C-/>", shell_terminal, { desc = "Terminal (left split)" })
vim.keymap.set({ "n", "t" }, "<C-_>", shell_terminal, { desc = "which_key_ignore" })

-- Option+] / Option+[ cycle the left split (shell / Claude Code) through fixed widths:
-- 33-66 (the default) -> 50-50 -> 66-33. Steps clamp at each end rather than wrapping, so
-- holding one key can't overshoot back to the other extreme.
-- Took over from the zellij "Alt [" / "Alt ]" pane-resize binds — claude is an nvim window
-- now, not a zellij pane. Ghostty sends these as CSI u text (see ghostty/config) so they reach
-- nvim through zellij; mapped in terminal mode too, so they work while typing at the Claude prompt.
local sidebar_steps = { 0.33, 0.5, 0.66 }

-- The left split is whichever non-floating window sits hard against column 0 while something
-- else shares the row. Deliberately not keyed off snacks' window vars: claudecode's provider
-- recreates its split window by hand (its cursor-drift workaround), so those vars aren't
-- dependable. This also means the cycle works from either side of the split.
local function sidebar_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local floating = vim.api.nvim_win_get_config(win).relative ~= ""
    local at_left_edge = vim.api.nvim_win_get_position(win)[2] == 0
    if not floating and at_left_edge and vim.api.nvim_win_get_width(win) < vim.o.columns then
      return win
    end
  end
end

---@param widen boolean true to widen the left split, false to narrow it
local function cycle_sidebar_width(widen)
  return function()
    local win = sidebar_win()
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

-- Horizontal mouse scroll (Magic Mouse, Keychron M6 horizontal wheel)
vim.keymap.set({ "n", "v" }, "<ScrollWheelLeft>", "3zh", { desc = "Scroll left" })
vim.keymap.set({ "n", "v" }, "<ScrollWheelRight>", "3zl", { desc = "Scroll right" })
