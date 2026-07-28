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

--- Is any real file still open? Terminals and the dashboard are unlisted scratch buffers, and a fresh
--- `:enew` buffer is listed but unnamed, so "listed and named" is what counts as work in progress.
---@return boolean
local function has_open_file()
  return vim.iter(vim.api.nvim_list_bufs()):any(function(buf)
    return vim.bo[buf].buflisted and vim.api.nvim_buf_get_name(buf) ~= ""
  end)
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

local function show_home_screen()
  if exiting or not package.loaded["snacks"] then
    return
  end
  -- Where code lives: a non-floating window that isn't part of the sidebar. Floats (pickers, lazygit,
  -- notifications) don't count as somewhere to open a file.
  local code_win, sidebar_wins = nil, 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      if sidebar.is_sidebar_win(win) then
        sidebar_wins = sidebar_wins + 1
      else
        code_win = code_win or win
      end
    end
  end

  if code_win then
    -- A code window survives, so only step in once the last file is gone. Bailing out when it already
    -- holds the dashboard also stops the buffer wipe below from re-triggering this.
    if has_open_file() or vim.bo[vim.api.nvim_win_get_buf(code_win)].filetype == "snacks_dashboard" then
      return
    end
  elseif sidebar_wins > 0 then
    -- Nothing but the sidebar left: make room on the right, focused, and hand the column its width back.
    vim.cmd("botright vnew")
    code_win = vim.api.nvim_get_current_win()
    sidebar.restore_width()
  else
    return
  end

  Snacks.dashboard.open({ win = code_win })
end

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout", "WinClosed" }, {
  group = home_group,
  -- Scheduled because these all fire while the buffer/window is still there to be counted.
  callback = function()
    vim.schedule(show_home_screen)
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
