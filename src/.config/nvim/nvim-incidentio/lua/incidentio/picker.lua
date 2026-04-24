-- Picker dispatch: resolves the configured backend and delegates to the adapter.
--
-- Public API (these are the functions users bind to keymaps):
--   picker.api_pick()               — open API browser picker
--   picker.events_pick(event_name)  — open event picker for a specific event
--   picker.events_pick_all()        — open browse-all-events picker
--   picker.events_pick_at_cursor()  — open event picker for event under cursor (convenience)
--
-- Adapter interface — each adapter module in pickers/ must export:
--   adapter.api_pick()
--   adapter.events_pick(event_name)
--   adapter.events_pick_all()

local M = {}

--- Resolve and return the picker adapter module.
--- Checks config.options.picker ("snacks", "telescope", or "auto") and
--- returns the corresponding incidentio.pickers.* module.
local function get_adapter()
  local config = require("incidentio.config")
  local picker = config.options.picker

  if picker == "auto" then
    if pcall(require, "snacks") then
      picker = "snacks"
    elseif pcall(require, "telescope") then
      picker = "telescope"
    end
  end

  if not picker or picker == "auto" then
    vim.notify(
      "nvim-incidentio: no supported picker found.\n"
        .. "Install snacks.nvim or telescope.nvim, or set picker in setup():\n"
        .. '  require("incidentio").setup({ picker = "snacks" })',
      vim.log.levels.ERROR
    )
    return nil
  end

  local ok, adapter = pcall(require, "incidentio.pickers." .. picker)
  if not ok then
    vim.notify(
      "nvim-incidentio: failed to load picker adapter '" .. picker .. "': " .. adapter,
      vim.log.levels.ERROR
    )
    return nil
  end

  return adapter
end

function M.api_pick()
  local adapter = get_adapter()
  if adapter then adapter.api_pick() end
end

function M.events_pick(event_name)
  local adapter = get_adapter()
  if adapter then adapter.events_pick(event_name) end
end

function M.events_pick_all()
  local adapter = get_adapter()
  if adapter then adapter.events_pick_all() end
end

--- Convenience: open the event picker for the event under the cursor.
--- Extracts the event name and delegates to events_pick(). Notifies if no
--- event name is found. Use this in keymaps to avoid boilerplate.
function M.events_pick_at_cursor()
  local name = require("incidentio.events").event_name_under_cursor()
  if not name or name == "" then
    vim.notify("No event name under cursor", vim.log.levels.WARN)
    return
  end
  M.events_pick(name)
end

return M
