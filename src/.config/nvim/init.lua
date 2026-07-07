-- Observability for gopls/LSP debugging (2026-04-28). Loaded before lazy
-- so vim.lsp.set_log_level("DEBUG") is in effect before any LSP starts.
-- See lua/config/observability.lua and the gitignored design doc at
-- docs/superpowers/specs/2026-04-28-nvim-gopls-observability-design.md.
-- require("config.observability")

-- :PRComments loads the current branch's PR review comments into the quickfix list.
-- See lua/config/pr-comments.lua.
require("config.pr-comments")

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
