--- The left SIDEBAR COLUMN: a vertical split at column 0 shared by two terminals — Claude Code on
--- top (<C-;>) and the shell on the bottom (<C-/>). Each toggles independently; whichever is left
--- alone takes the full column height, and hiding both hands the width back to the code window.
---
--- Both toggles live in this module rather than in config/keymaps.lua because claudecode.nvim's
--- keymap has to be declared in its own lazy `keys` spec (so the plugin loads on first press), and
--- the two toggles have to agree on the layout.
---
--- Why the windows are placed by hand: snacks' "terminal" style sets stack = true, which makes a
--- second split with the same position open perpendicular to the first — exactly this layout. But
--- claudecode.nvim's snacks provider hand-rolls its window recreate on show (a plain
--- `topleft <width>vsplit`, its cursor-drift workaround) and re-stamps w:snacks_win without the
--- `relative` / `stack` fields snacks' stacking check reads. So once Claude had been hidden even
--- once, snacks stopped recognising it as stackable, <C-/> opened a THIRD column, and the toggles
--- started closing the wrong window. Stacking is therefore switched off on both terminals
--- (win.stack = false here, snacks_win_opts.stack = false in plugins/claudecode.lua) and the
--- placement is done with win_splitmove() instead — see without_equalize() below for the other half
--- of that, snacks' stacking-related resize.
local M = {}

--- Default width of the column as a fraction of the screen. Option+[ / Option+] cycle it live
--- (33/50/66) via the keymaps in config/keymaps.lua.
M.width = 0.33

--- The sidebar column: whichever non-floating window sits hard against column 0 while something
--- else shares the row. Deliberately not keyed off snacks' window vars (see above), which also
--- means callers work from either side of the split.
---@return integer? win
function M.win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local floating = vim.api.nvim_win_get_config(win).relative ~= ""
    local at_left_edge = vim.api.nvim_win_get_position(win)[2] == 0
    if not floating and at_left_edge and vim.api.nvim_win_get_width(win) < vim.o.columns then
      return win
    end
  end
end

--- Current width of the column in cells, or the default when it isn't open. Captured before a
--- toggle and re-applied after, so a width cycled with Option+[ / Option+] survives showing or
--- hiding either terminal.
---@return integer
function M.column_width()
  local win = M.win()
  return win and vim.api.nvim_win_get_width(win) or math.floor(vim.o.columns * M.width)
end

--- Snacks keys terminals on cmd + cwd + env + count, so toggling with the same args reuses the
--- same shell instead of spawning a new one. cwd is pinned to the GLOBAL cwd (getcwd(-1)) rather
--- than LazyVim.root() so a buffer with a different project root can't silently create a second
--- terminal, and count is pinned so a stray v:count1 can't either.
---@return snacks.terminal.Opts
local function shell_opts()
  return {
    count = 1,
    cwd = vim.fn.getcwd(-1),
    win = { position = "left", width = M.width, stack = false },
  }
end

---@return integer? win window showing the shell terminal, if it's visible
function M.shell_win()
  local term = Snacks.terminal.get(nil, vim.tbl_extend("force", shell_opts(), { create = false }))
  if term and term:win_valid() then
    return term.win
  end
end

---@return integer? win window showing the Claude Code terminal, if it's visible
function M.claude_win()
  local ok, terminal = pcall(require, "claudecode.terminal")
  if not ok then
    return
  end
  -- The buffer outlives a hide (that's what keeps the session alive), so a visible Claude means a
  -- window currently showing that buffer.
  local buf = terminal.get_active_terminal_bufnr()
  if not buf then
    return
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return win
    end
  end
end

--- Settle a just-shown terminal into the column: half height above/below the other one if it's
--- open, full height otherwise, at the remembered column width either way.
---@param win integer the window that was just shown
---@param anchor integer? the other sidebar window, when it's open
---@param above boolean true to put `win` above `anchor`
---@param width integer column width in cells
local function place(win, anchor, above, width)
  if anchor and anchor ~= win then
    -- Equal starting columns mean they already share the column, so there's nothing to move —
    -- only sizes to fix up.
    if vim.api.nvim_win_get_position(win)[2] ~= vim.api.nvim_win_get_position(anchor)[2] then
      -- win_splitmove keeps the window and its terminal job alive, but leaves terminal insert
      -- mode, so restore it when that's where we were.
      local insert = vim.fn.mode() == "t"
      vim.fn.win_splitmove(win, anchor, { vertical = false, rightbelow = not above })
      if insert and vim.api.nvim_get_current_win() == win then
        vim.cmd.startinsert()
      end
    end
    -- Half of the rows the two windows actually have between them, NOT half of vim.o.lines:
    -- asking for more rows than the column holds (winbars and the statusline take some) makes
    -- nvim shrink the topframe and inflate 'cmdheight' instead, leaving a dead band at the bottom
    -- of the screen that outlives both terminals.
    local rows = vim.api.nvim_win_get_height(win) + vim.api.nvim_win_get_height(anchor)
    vim.api.nvim_win_set_height(win, math.floor(rows / 2))
  end
  vim.api.nvim_win_set_width(win, width)
end

--- Run `show`, then `settle` on the next tick, with snacks' equalize() suppressed in between.
---
--- Snacks.win:open_win() schedules self:equalize(), which resizes every window whose w:snacks_win
--- records the same relative + position — for us, both "left" terminals. It fires while they are
--- still side by side, each its own full-height column, so it shrinks a full-height window; nvim
--- can only absorb that by shrinking the topframe and inflating 'cmdheight', which leaves a dead
--- band at the bottom of the screen that survives closing both terminals. equalize() exists to
--- balance snacks' own stacking, which is switched off here, so it has nothing to contribute.
--- Patched on the class rather than the instance because claudecode.nvim owns its terminal object
--- and doesn't expose it; the patch only stands for the one tick that the scheduled call lands in.
---@param show fun()
---@param settle fun()
local function without_equalize(show, settle)
  local win = require("snacks.win")
  local equalize = win.equalize
  win.equalize = function() end
  local ok, err = pcall(show)
  vim.schedule(function()
    win.equalize = equalize
    if ok then
      settle()
    else
      error(err)
    end
  end)
end

--- Toggle the shell terminal, stacked BELOW Claude Code when that's open.
function M.toggle_shell()
  local width = M.column_width()
  local term
  without_equalize(function()
    term = Snacks.terminal.toggle(nil, shell_opts())
  end, function()
    -- Nothing to do when that hid the terminal: nvim hands the space to whatever shares the column.
    if not (term and term:win_valid()) then
      return
    end
    place(term.win, M.claude_win(), false, width)
  end)
end

-- Keep the column's PROPORTION across a screen resize (resizing the terminal, or moving the window
-- to another monitor). Nvim rescales window heights proportionally but hands the entire width
-- difference to the rightmost window, so the sidebar keeps its absolute column count: a 33% column on
-- a wide monitor becomes a 66% column on a laptop screen. Remember the fraction instead and re-apply
-- it. Note this deliberately does NOT change what a fresh open gets — close both terminals and the
-- column comes back at M.width, as before.
local fraction = M.width
local screen_columns = vim.o.columns

--- Is `win` one of the two sidebar terminals? Identity, not geometry: anything automatic must not
--- mistake a plain code split that happens to sit at column 0 for the sidebar.
---@param win integer
---@return boolean
function M.is_sidebar_win(win)
  return win == M.shell_win() or win == M.claude_win()
end

--- The sidebar column, but only when one of our terminals is actually in it.
---@return integer? win
local function terminal_win()
  local win = M.win()
  if win and M.is_sidebar_win(win) then
    return win
  end
end

--- Re-apply the remembered fraction to the column. Called after a screen resize, and by anything else
--- that leaves the column at the wrong proportion (see config/autocmds.lua).
function M.restore_width()
  local win = terminal_win()
  if win then
    vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * fraction))
  end
end

local group = vim.api.nvim_create_augroup("sidebar_width", { clear = true })

-- Any width change records the new fraction — a toggle, the Option+[ / Option+] cycle, or a mouse
-- drag on the separator. Changes that come FROM a screen resize are skipped: the fraction worth
-- keeping is the one from before it, and 'columns' has already been updated by the time this fires.
vim.api.nvim_create_autocmd("WinResized", {
  group = group,
  callback = function()
    local win = vim.o.columns == screen_columns and terminal_win()
    if win then
      fraction = vim.api.nvim_win_get_width(win) / vim.o.columns
    end
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    screen_columns = vim.o.columns
    M.restore_width()
  end,
})

--- Run a ClaudeCode command and settle the split into the column, ABOVE the shell when that's open.
---@param cmd string an Ex command, e.g. "ClaudeCode" or "ClaudeCodeFocus"
---@return fun()
function M.claude(cmd)
  return function()
    local width = M.column_width()
    without_equalize(function()
      vim.cmd(cmd)
    end, function()
      local claude = M.claude_win()
      if not claude then
        return
      end
      place(claude, M.shell_win(), true, width)
    end)
  end
end

return M
