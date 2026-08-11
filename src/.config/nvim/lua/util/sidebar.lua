--- The left SIDEBAR COLUMN: a vertical split at column 0 shared by two terminals — Claude Code on
--- top (<C-;>) and the shell on the bottom (<C-/>). Each toggles independently; whichever is left
--- alone takes the full column height, and hiding both hands the width back to the code window. The
--- column also stays hard against the left edge when another left-hand split (the <leader>e explorer)
--- opens, so the order is always terminals | explorer | code.
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
--- placement is done here instead — see deregister() and without_equalize() for the other half of
--- that, snacks' stacking-related resize.
local M = {}

--- Default width of the column as a fraction of the screen. Option+[ / Option+] cycle it live
--- (33/50/66) via the keymaps in config/keymaps.lua.
M.width = 0.5

--- The sidebar column: whichever of our two terminals is currently visible. Identity via
--- claude_win()/shell_win() rather than "sits hard against column 0" geometry — diffview's file
--- panel pins itself to column 0 too, so with both terminals hidden the geometric check picked
--- IT instead, and callers (column_width() below, the Option+[ / Option+] resize keymap) went on
--- to treat its width as the sidebar's, handing Claude the panel's width on the next toggle.
---@return integer? win
function M.win()
  return M.claude_win() or M.shell_win()
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

--- Is `win` one of the two sidebar terminals? Identity, not geometry: anything automatic must not
--- mistake a plain code split that happens to sit at column 0 for the sidebar.
---@param win integer
---@return boolean
function M.is_sidebar_win(win)
  return win == M.shell_win() or win == M.claude_win()
end

--- Move `win` into a split of `target`, keeping terminal insert mode: win_splitmove keeps the window
--- and its job alive but leaves insert mode behind.
---@param win integer
---@param target integer
---@param opts { vertical: boolean, rightbelow: boolean }
local function move(win, target, opts)
  local insert = vim.fn.mode() == "t"
  vim.fn.win_splitmove(win, target, opts)
  if insert and vim.api.nvim_get_current_win() == win then
    vim.cmd.startinsert()
  end
end

--- Take our windows out of snacks' window bookkeeping, by stamping a position no other snacks window
--- uses. equalize() resizes every window whose w:snacks_win records the same relative + position, and
--- ANY other left-hand snacks split records `editor` + `left` too — notably the <leader>e explorer's
--- layout root box. It would then "equalize" the heights of windows that sit side by side, shrinking a
--- full-height one, which nvim answers by inflating 'cmdheight' into a dead band at the bottom of the
--- screen. Snacks re-stamps the var on every show (and claudecode re-stamps it by hand), so this has to
--- be re-applied every time we place a window. Keeps the id, which Snacks.win.zindex() reads.
---@param win integer
local function deregister(win)
  local var = vim.w[win].snacks_win or {}
  var.position, var.relative, var.stack = "sidebar", "sidebar", false
  vim.w[win].snacks_win = var
end

--- Settle a just-shown terminal into the column: half height above/below the other one if it's
--- open, full height otherwise, at the remembered column width either way.
---@param win integer the window that was just shown
---@param anchor integer? the other sidebar window, when it's open
---@param above boolean true to put `win` above `anchor`
---@param width integer column width in cells
local function place(win, anchor, above, width)
  deregister(win)
  if anchor and anchor ~= win then
    deregister(anchor)
    -- Equal starting columns mean they already share the column, so there's nothing to move —
    -- only sizes to fix up.
    if vim.api.nvim_win_get_position(win)[2] ~= vim.api.nvim_win_get_position(anchor)[2] then
      move(win, anchor, { vertical = false, rightbelow = not above })
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

-- Keep the column's PROPORTION across a screen resize (resizing the terminal, or moving the window
-- to another monitor). Nvim rescales window heights proportionally but hands the entire width
-- difference to the rightmost window, so the sidebar keeps its absolute column count: a 33% column on
-- a wide monitor becomes a 66% column on a laptop screen. Remember the fraction instead and re-apply
-- it. Note this deliberately does NOT change what a fresh open gets — close both terminals and the
-- column comes back at M.width, as before.
local fraction = M.width
local screen_columns = vim.o.columns

--- Re-apply the remembered fraction to the column. Called after a screen resize, and by anything else
--- that leaves the column at the wrong proportion (see config/autocmds.lua).
function M.restore_width()
  local win = M.win()
  if win then
    vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * fraction))
  end
end

--- Keep the column hard against the left edge. Any other left-hand split — the <leader>e explorer, say
--- — also opens with `vertical topleft`, so whichever opened last takes column 0 and the explorer ends
--- up LEFT of the terminals. Wanted order is terminals | explorer | code, so move ours back.
local function ensure_leftmost()
  local claude, shell = M.claude_win(), M.shell_win()
  local top = claude or shell
  if not top then
    return
  end
  -- Only one column can start at column 0, so the first window found there identifies it.
  local leftmost
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" and vim.api.nvim_win_get_position(win)[2] == 0 then
      leftmost = win
      break
    end
  end
  if not leftmost or M.is_sidebar_win(leftmost) then
    return -- already ours
  end
  -- The intruder has taken its share out of the column, so re-apply the remembered fraction.
  local width = math.floor(vim.o.columns * fraction)
  -- `wincmd H` (make this the leftmost full-height column) rather than win_splitmove: moving a window
  -- into a split of the explorer's layout box aborts with E855, raised by the layout's own autocmds —
  -- and an error thrown inside a scheduled callback leaves nvim sitting on a hit-enter prompt with no
  -- way to type at it. Everything here is pcall'd for the same reason: a reshuffle that can't be done
  -- should leave the windows in the wrong order, never wedge the editor.
  local insert = vim.fn.mode() == "t"
  if not pcall(vim.api.nvim_win_call, top, function()
    vim.cmd("wincmd H")
  end) then
    return
  end
  if claude and shell then
    pcall(place, shell, claude, false, width) -- wincmd H moved only the top one; re-stack the other
  else
    deregister(top)
    pcall(vim.api.nvim_win_set_width, top, width)
  end
  if insert and vim.api.nvim_get_current_win() == top then
    vim.cmd.startinsert()
  end
end

--- Re-send `win`'s current size to the process running in it.
---
--- Opening the <leader>e explorer left Claude Code drawing its whole UI ~18 columns wide inside a
--- 100-column window: nvim's own geometry was right (the window reported the full column width) but the
--- child was still holding a stale, much narrower pty size, so it wrapped and truncated everything to
--- that. Nvim only pushes a size down the pty when the window size CHANGES, which is the only reason
--- Option+] appeared to fix it — any width change re-sent the size. The explorer's layout squeezes the
--- column on the way in and ensure_leftmost() puts the width back, and somewhere across those two the
--- pty misses the final size. jobresize() re-sends it without touching the layout, so there's no flicker
--- and no width to record.
---@param win integer?
local function resync_pty(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  local job = vim.b[vim.api.nvim_win_get_buf(win)].terminal_job_id
  if job then
    pcall(vim.fn.jobresize, job, vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win))
  end
end

local group = vim.api.nvim_create_augroup("sidebar_width", { clear = true })

-- Any width change records the new fraction — a toggle, the Option+[ / Option+] cycle, or a mouse
-- drag on the separator. Changes that come FROM a screen resize are skipped: the fraction worth
-- keeping is the one from before it, and 'columns' has already been updated by the time this fires.
vim.api.nvim_create_autocmd("WinResized", {
  group = group,
  callback = function()
    -- Scheduled, so it reads the size the column settled at rather than one from the middle of a
    -- reshuffle: anything that resizes our windows (the explorer, a picker, Option+z) usually does it in
    -- several steps, and ensure_leftmost() runs after this fires. A no-op when the pty already agrees.
    vim.schedule(function()
      resync_pty(M.claude_win())
      resync_pty(M.shell_win())
    end)

    local win = vim.o.columns == screen_columns and M.win()
    if win then
      local frac = vim.api.nvim_win_get_width(win) / vim.o.columns
      -- Ignore the extremes. Option+z (see config/keymaps.lua) maximises a window by squeezing every
      -- other one down to 'winminwidth', so a zoom would otherwise record a column of ~1 cell — or the
      -- whole screen, when it's the sidebar that's zoomed — and hand that back on the next toggle.
      -- Nothing between 10% and 90% is reachable except by deliberately asking for it.
      if frac > 0.1 and frac < 0.9 then
        fraction = frac
      end
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

vim.api.nvim_create_autocmd("WinNew", {
  group = group,
  -- Scheduled so the new window's layout has settled; a no-op once the column is leftmost already.
  callback = function()
    vim.schedule(ensure_leftmost)
  end,
})

--- Run `show`, then `settle` on the next tick, with snacks' equalize() suppressed in between.
---
--- Snacks.win:open_win() schedules self:equalize(), which resizes every window whose w:snacks_win
--- records the same relative + position — for us, both "left" terminals, since deregister() hasn't run
--- on the newly shown one yet. It fires while they are still side by side, each its own full-height
--- column, so it shrinks a full-height window; nvim can only absorb that by shrinking the topframe and
--- inflating 'cmdheight', which leaves a dead band at the bottom of the screen that survives closing
--- both terminals. equalize() exists to balance snacks' own stacking, which is switched off here, so it
--- has nothing to contribute. Patched on the class rather than the instance because claudecode.nvim
--- owns its terminal object and doesn't expose it; the patch only stands for the one tick that the
--- scheduled call lands in.
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
    -- Explicitly, not just via the WinNew autocmd: that fires (and is scheduled) before place() runs,
    -- when the column is still at column 0 and there is nothing to fix.
    ensure_leftmost()
  end)
end

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
      ensure_leftmost()
    end)
  end
end

return M
