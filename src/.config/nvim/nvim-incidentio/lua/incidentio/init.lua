-- nvim-incidentio: Neovim plugins for working at incident.io.
--
-- Provides:
--   - API navigation: browse and jump between Goa design/impl
--   - Event references: find all publishers/subscribers of a domain event
--
-- Picker backends: snacks.nvim (recommended, async) or telescope.nvim (sync).
-- Detects automatically, or set opts.picker = "snacks" | "telescope".
--
-- This plugin does not register keymaps. See README.md for recommended keymap setup.

local M = {}

function M.setup(opts)
  require("incidentio.config").setup(opts)
end

return M
