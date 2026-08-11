-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Fall back to the LazyVim home screen (the snacks dashboard) whenever no work is left open, the same
-- as a fresh `nvim` with no file. Closing the last buffer used to leave an empty unnamed buffer, and —
-- if Claude Code or the shell terminal were open — nothing at all: the sidebar column filled the
-- screen with nowhere to open a file from, and neither terminal can be hidden to make room because
-- nvim won't close the last window (claudecode's hide is a no-op on E444, and snacks' fallback splits
-- and re-shows the same buffer). Recreating the window also drops you out of terminal insert mode.
local sidebar = require("util.sidebar")

--- The listed, named buffer used most recently, or nil when no real file is open at all. Terminals and
--- the dashboard are unlisted scratch buffers, and a fresh `:enew` buffer is listed but unnamed, so
--- "listed and named" is what counts as work in progress.
---@param skip integer? buffer to ignore — the one whose window just closed, since putting that back is
---       never what closing it meant
---@return integer?
local function last_used_file(skip)
  local best
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if info.name ~= "" and info.bufnr ~= skip and (not best or info.lastused > best.lastused) then
      best = info
    end
  end
  return best and best.bufnr
end

--- Show the home screen in `win`, taking over an empty throwaway buffer when that's what the window
--- holds (what nvim leaves behind after the last file is deleted). Otherwise that buffer would linger
--- in the bufferline as a stray [No Name] once the dashboard replaced it in the window.
---@param win integer
local function open_home_screen(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local throwaway = vim.bo[buf].buftype == "" and not vim.bo[buf].modified and vim.fn.bufname(buf) == ""
  -- Closing a diffview tab can land here before diffview's own teardown clears the 'winfixbuf' it
  -- sets on its panel windows (see diffview/ui/panel.lua), racing this against the buffer delete
  -- that triggered it. The home screen always gets to override, so clear it rather than fail.
  vim.wo[win].winfixbuf = false
  -- pcall because this runs from a scheduled callback: an error thrown there leaves nvim sitting on a
  -- hit-enter prompt with no way to type at it (same reasoning as util/sidebar.lua's ensure_leftmost).
  local ok, err = pcall(Snacks.dashboard.open, { win = win, buf = throwaway and buf or nil })
  if not ok then
    vim.notify("home screen: " .. tostring(err), vim.log.levels.WARN)
  end
end

--- Does `win` (non-floating) hold a panel rather than code? The two sidebar terminals, the <leader>e
--- explorer, a picker list — anything sharing the screen with the code window rather than being it.
--- Keyed off w:snacks_win, which every window snacks owns carries and a plain split never does: it has
--- to cover panels this config doesn't place itself, not just the sidebar. Recognising only the sidebar
--- put the home screen on top of the explorer, whose layout tore the window down again and re-triggered
--- this — an error loop that needed a force-quit. See issues/005, "the explorer is not the code window".
---@param win integer
---@return boolean
local function is_panel_win(win)
  if sidebar.is_sidebar_win(win) then
    return true
  end
  -- The dashboard is our own placeholder, not a panel: a file is meant to replace it.
  if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
    return false
  end
  return vim.w[win].snacks_win ~= nil
end

local home_group = vim.api.nvim_create_augroup("home_screen", { clear = true })

-- Skip everything below while quitting, so closing windows on the way out can't resurrect one.
local exiting = false
vim.api.nvim_create_autocmd("ExitPre", {
  group = home_group,
  callback = function()
    exiting = true
  end,
})

---@param closed_buf integer? buffer that was showing in the window that just closed
local function fill_empty_screen(closed_buf)
  if exiting or not package.loaded["snacks"] then
    return
  end
  -- Where code lives: a non-floating window that isn't a panel. Floats (pickers, lazygit,
  -- notifications) don't count as somewhere to open a file.
  local code_win, panels = nil, 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      if is_panel_win(win) then
        panels = panels + 1
      else
        code_win = code_win or win
      end
    end
  end
  local file = last_used_file(closed_buf)

  if code_win then
    -- A code window survives, so only step in once the last file is gone. Bailing out when it already
    -- holds the dashboard also stops the buffer takeover from re-triggering this.
    if file or vim.bo[vim.api.nvim_win_get_buf(code_win)].filetype == "snacks_dashboard" then
      return
    end
    open_home_screen(code_win)
    return
  end

  if panels == 0 then
    return
  end
  -- Nothing but panels left. Make room on the right, focused, and hand the column its width back.
  -- `vsplit` rather than `vnew`: vnew's empty buffer is listed, so it lingers in the bufferline as a
  -- stray [No Name] as soon as something replaces it in the window.
  vim.cmd("botright vsplit")
  code_win = vim.api.nvim_get_current_win()
  sidebar.restore_width()
  -- Files still open (the window was closed, not the buffers) means the home screen is the wrong
  -- answer: show the most recent one, so <S-h> / <S-l> can cycle from a real position again.
  if file then
    vim.api.nvim_win_set_buf(code_win, file)
  else
    open_home_screen(code_win)
  end
end

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout", "WinClosed" }, {
  group = home_group,
  callback = function(args)
    -- Never react to the dashboard's own buffer going away. It's bufhidden=wipe, so putting a second
    -- dashboard in a window wipes the first — reacting to that opens a third, and round it goes.
    if
      args.event ~= "WinClosed"
      and vim.api.nvim_buf_is_valid(args.buf)
      and vim.bo[args.buf].filetype == "snacks_dashboard"
    then
      return
    end
    -- The window is still in the layout during WinClosed, so read its buffer now; the check itself is
    -- scheduled because these events all fire while the buffer/window is still there to be counted.
    local win = args.event == "WinClosed" and tonumber(args.match)
    if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
      -- A float closing never takes the code window with it, and reacting to one broke glance.nvim's
      -- gd/gr peek: its list and preview are floats showing a real file buffer, so closing them (<CR>
      -- on a reference, q on a definition) passed that buffer as `closed_buf`. With the file you were
      -- looking at skipped, "no work left open" looked true and the home screen replaced it.
      return
    end
    local closed_buf = win and vim.api.nvim_win_get_buf(win) or nil
    vim.schedule(function()
      fill_empty_screen(closed_buf)
    end)
  end,
})

-- Hide diagnostics by default for markdown files.
-- Updated 2026-04-30 for nvim 0.12: vim.diagnostic.disable was removed (it
-- was deprecated in 0.10). The replacement is enable(false, filter).
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(args)
    vim.diagnostic.enable(false, { bufnr = args.buf })
  end,
})
