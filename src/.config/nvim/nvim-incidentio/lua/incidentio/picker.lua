-- Picker dispatch: resolves the configured backend and delegates to the adapter.
--
-- Public API (these are the functions users bind to keymaps):
--   picker.api_pick()              — open API browser picker
--   picker.events_pick()           — open event picker (browse all events)
--   picker.events_pick_at_cursor() — same picker, pre-filtered to event under cursor
--
-- Adapter interface — each adapter module in pickers/ must export:
--   adapter.api_pick()
--   adapter.events_pick(pick_opts?) — pick_opts.pattern (snacks) or .default_text (telescope)
--   adapter.events_pick_all()       — calls events_pick() with no opts

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

function M.events_pick()
  local adapter = get_adapter()
  if adapter then adapter.events_pick() end
end

function M.events_pick_all()
  local adapter = get_adapter()
  if adapter then adapter.events_pick_all() end
end

--- Convenience: open the event picker with the event under the cursor pre-filled.
--- Extracts the event name and opens the same async picker as events_pick(),
--- but with the search pre-populated. Notifies if no event name is found.
function M.events_pick_at_cursor()
  local name = require("incidentio.events").event_name_under_cursor()
  if not name or name == "" then
    vim.notify("No event name under cursor", vim.log.levels.WARN)
    return
  end
  local adapter = get_adapter()
  if adapter then adapter.events_pick({ pattern = name }) end
end

return M
