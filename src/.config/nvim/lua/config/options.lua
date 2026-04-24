-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Don't use system clipboard for all operations (we map yank specifically instead)
vim.opt.clipboard = ""

-- Allow project-local config files (.nvim.lua)
vim.opt.exrc = true

-- Auto-wrap text in comments as you type
vim.opt.textwidth = 120
vim.opt.formatoptions:append("c") -- Auto-wrap comments using textwidth
vim.opt.formatoptions:append("r") -- Continue comment leader on Enter
vim.opt.formatoptions:append("o") -- Continue comment leader on o/O
vim.opt.formatoptions:remove("t") -- Don't auto-wrap code/text, only comments
