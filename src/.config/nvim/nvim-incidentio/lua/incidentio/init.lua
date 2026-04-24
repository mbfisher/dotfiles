-- nvim-incidentio: Neovim plugins for working at incident.io.
--
-- Provides:
--   - API navigation: browse and jump between Goa design/impl (api_picker)
--   - Event references: find all publishers/subscribers of a domain event (event_picker)

local M = {}

function M.setup()
  local api_picker = require("incidentio.api_picker")
  local event_picker = require("incidentio.event_picker")

  -- nf-md-fire in orange, used for all which-key menu items in this plugin
  local icon = { icon = "󰈸", color = "orange" }

  -- Register keymaps with icons via which-key (handles both the mapping and display)
  local wk_ok, wk = pcall(require, "which-key")
  if wk_ok then
    wk.add({
      { "<leader>sA", function() api_picker.pick() end, icon = icon, desc = "APIs" },
      -- Browse all events: search by name across definitions, publishers, and subscribers
      { "<leader>sE", function() event_picker.pick_all() end, icon = icon, desc = "Events" },
      { "gA", function() api_picker.goto_counterpart() end, icon = icon, desc = "Goto API design/impl" },
      -- Cursor-scoped: opens picker pre-filtered to the event under cursor
      { "gE", function() event_picker.pick() end, icon = icon, desc = "Event publishers/subscribers" },
    })
  end
end

return M
